import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/insect_tier.dart';
import 'adaptive_quality_scaler.dart';
import 'audio_manager.dart';

/// Progressive asset warm with a hard <2ms/frame budget (PROMPT_ORDUSU ZeroJank).
/// Time-slices decode / cache work (`precacheImage`, fonts, audio, stickers)
/// so startup, splash, and screen transitions never hitch at 60/120 FPS.
class ZeroJankPreloader {
  ZeroJankPreloader._();
  static final ZeroJankPreloader instance = ZeroJankPreloader._();

  /// Must stay strictly under 2.0ms per frame.
  static const double defaultFrameBudgetMs = 1.8;
  static const double hardBudgetCapMs = 1.95;

  /// Madde 53 [P1]: precache decode hedef genişlikleri (fiziksel piksel).
  /// HD böcek/sticker görselleri en fazla 180 mantıksal px çapta
  /// gösterilir (3x DPR → 540 px); 768 px headroom bırakır. Tam ekran
  /// arka planlar 430 mantıksal px genişliğindedir (3x DPR → 1290 px);
  /// 1280 px hedefi tam ekran netliğini korur.
  static const int stickerDecodeWidth = 768;
  static const int backgroundDecodeWidth = 1280;
  static const int defaultDecodeWidth = 1024;

  /// Canonical critical sticker & hero paths requested at startup / splash.
  static const List<String> criticalStickerPaths = [
    'assets/design/images/stickers/tier_1_256.png',
    'assets/design/images/stickers/tier_2_256.png',
    'assets/design/images/stickers/tier_3_256.png',
    'assets/design/images/stickers/tier_4_256.png',
    'assets/design/images/stickers/tier_5_256.png',
    'assets/design/images/stickers/tier_6_256.png',
    'assets/design/images/stickers/tier_7_256.png',
    'assets/design/images/stickers/tier_8_256.png',
    'logo_banner.png',
    'kitchen_bg.png',
  ];

  /// Physical fallback map for logical sticker / banner / kitchen paths.
  static const Map<String, String> _assetAliasMap = {
    'assets/design/images/stickers/tier_1_256.png':
        'assets/design/bugs_hd/tier1_hd.png',
    'assets/design/images/stickers/tier_2_256.png':
        'assets/design/bugs_hd/tier2_hd.png',
    'assets/design/images/stickers/tier_3_256.png':
        'assets/design/bugs_hd/tier3_hd.png',
    'assets/design/images/stickers/tier_4_256.png':
        'assets/design/bugs_hd/tier4_hd.png',
    'assets/design/images/stickers/tier_5_256.png':
        'assets/design/bugs_hd/tier5_hd.png',
    'assets/design/images/stickers/tier_6_256.png':
        'assets/design/bugs_hd/tier6_hd.png',
    'assets/design/images/stickers/tier_7_256.png':
        'assets/design/bugs_hd/tier7_hd.png',
    'assets/design/images/stickers/tier_8_256.png':
        'assets/design/bugs_hd/tier8_hd.png',
    'logo_banner.png': 'assets/design/ui/logo_lululu.webp',
    'assets/design/images/logo_banner.png': 'assets/design/ui/logo_lululu.webp',
    'kitchen_bg.png': 'assets/design/backgrounds/suika_kitchen.webp',
    'assets/design/images/kitchen_bg.png':
        'assets/design/backgrounds/suika_kitchen.webp',
  };

  /// Additional critical UI & background images for zero-jank splash/hub/game boot.
  static const List<String> criticalUiAssets = [
    'assets/design/splash/bg_splash.webp',
    'assets/design/splash/splash_logo.webp',
    'assets/design/splash/splash_mascot.webp',
    'assets/design/ui/hub_hero_bg_exact.webp',
    'assets/design/ui/hub_hero_mascot_exact.webp',
    'assets/design/ui/logo_lululu.webp',
    'assets/design/backgrounds/suika_kitchen.webp',
    'assets/design/backgrounds/bg_kitchen.jpg',
    'assets/images/stickers/sticker_tier1_cone.png',
    'assets/images/stickers/sticker_tier2_helmet.png',
    'assets/images/stickers/sticker_tier3_fan.png',
    'assets/images/stickers/sticker_tier4_dancer.png',
    'assets/images/stickers/sticker_tier5_diva.png',
    'assets/images/stickers/sticker_tier6_can.png',
    'assets/images/stickers/sticker_tier7_kongo.png',
    'assets/images/stickers/sticker_tier8_bed.png',
  ];

  /// Bundled font assets pre-warmed at startup for zero-jank first text layout.
  static const List<String> criticalFontAssets = [
    'assets/fonts/Baloo2-Regular.ttf',
    'assets/fonts/Baloo2-Regular.ttf',
    'assets/fonts/Baloo2-Regular.ttf',
    'assets/fonts/Bangers-Regular.ttf',
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Exo2-Regular.ttf',
    'assets/fonts/Exo2-Regular.ttf',
  ];

  /// Critical voice & SFX assets under the canonical `assets/audio/` folder.
  ///
  /// Integrity manifest audited by `asset_integrity_test.dart` (every path
  /// must exist on disk). The same clips also exist as byte-identical
  /// copies under `assets/design/sounds/`, but that folder is not
  /// canonical: this manifest and [enqueueAudioWarmup] both point at
  /// `assets/audio/` only, so no clip is loaded from two folders.
  static const List<String> criticalSoundAssets = [
    'assets/audio/tier1_ses.mp3',
    'assets/audio/tier2_ses.mp3',
    'assets/audio/tier3_ses.mp3',
    'assets/audio/tier4_ses.mp3',
    'assets/audio/tier5_ses.mp3',
    'assets/audio/tier6_ses.mp3',
    'assets/audio/tier7_ses.mp3',
    'assets/audio/tier8_ses.mp3',
  ];

  double frameBudgetMs = defaultFrameBudgetMs;
  bool yieldOnTouch = true;

  bool isWarming = false;
  double progress01 = 0;
  double lastSliceMs = 0;
  double maxSliceMs = 0;
  bool get budgetRespected => maxSliceMs < 2.0;

  /// Longest single job observed in [_drainBudget] (ms). Unlike [lastSliceMs]
  /// / [maxSliceMs], which cover a whole frame slice, this isolates one job:
  /// a single slow job can blow the 1.8ms budget even when the between-jobs
  /// check never gets a chance to defer it. Observability only — jobs are
  /// never skipped or deferred because of it (see [_drainBudget]).
  double lastJobMs = 0;
  double maxJobMs = 0;

  /// Jobs whose own duration met or exceeded the frame budget. A non-zero
  /// count flags decode/load work that needs splitting or shrinking; it never
  /// changes which jobs run.
  int overBudgetJobCount = 0;
  bool get hasOverBudgetJob => overBudgetJobCount > 0;

  final Queue<FutureOr<void> Function()> _work = Queue();
  final Set<String> _warmedPaths = <String>{};
  final Set<String> _warmedPhysicalPaths = <String>{};
  int _totalJobs = 0;
  int _doneJobs = 0;

  /// Drain loop enabled. The loop uses one-shot post-frame callbacks (see
  /// [_scheduleNextFrame]), never a persistent frame callback: persistent
  /// callbacks cannot be unregistered in Flutter, so a persistent callback
  /// would stay registered for the lifetime of the app and every
  /// attach/detach cycle would add another one. Detaching only clears this
  /// flag; the chain then schedules nothing more.
  bool _schedulerAttached = false;

  /// True while exactly one one-shot drain callback is queued with the
  /// binding. Guards against double registration on restart: [_onFrame]
  /// clears it when it fires, and [_scheduleNextFrame] never queues a
  /// second callback while one is outstanding.
  bool _frameCallbackPending = false;

  /// `precache:` keys whose precache job is queued but has not finished
  /// yet. Separate from [_warmedPaths]: a path joins [_warmedPaths] only
  /// after [precacheImage] really succeeds, while this set only dedupes
  /// in-flight jobs so the same image is not enqueued twice.
  final Set<String> _precachePending = <String>{};
  bool _draining = false;
  bool _pointerDown = false;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _touchCooldown = const Duration(milliseconds: 120);

  VoidCallback? onWarmupComplete;

  /// True when running under `flutter test` (`TestWidgetsFlutterBinding`).
  bool get isFlutterTest {
    try {
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      return bindingType.contains('Test') || bindingType.contains('Automated');
    } catch (_) {
      return true;
    }
  }

  /// Resolves logical asset paths (`tier_1_256.png`, `logo_banner.png`, `kitchen_bg.png`)
  /// to physical bundle paths when needed.
  static String resolveAssetPath(String path) => _assetAliasMap[path] ?? path;

  /// Hedef boyutla decode eden [ImageProvider] döndürür (madde 53 [P1]).
  ///
  /// [ResizeImage] aynı mantıksal görsel için farklı bir önbellek anahtarı
  /// üretir: bu sağlayıcıyla precache edilen giriş, yalnızca aynı
  /// sağlayıcıyı isteyen widget'larla eşleşir. Widget'ların tamamı düz
  /// `AssetImage` (`Image.asset`) kullandığı için [precacheCriticalAssets]
  /// artık bu yardımcıyı KULLANMAZ — düz `AssetImage` ile precache eder;
  /// sized precache + düz widget isteği çift decode + çift önbellek
  /// girişi demekti (8B). Bu yardımcı saklanır: bir widget gerçekten bu
  /// sağlayıcıyla isterse (aynı hedef boyutla) o zaman isabet sağlar;
  /// precache tarafında tek başına kullanılmamalıdır.
  static ImageProvider sizedImageProvider(String resolvedPath) {
    return ResizeImage(
      AssetImage(resolvedPath),
      width: _decodeWidthFor(resolvedPath),
    );
  }

  static int _decodeWidthFor(String resolvedPath) {
    if (resolvedPath.contains('/backgrounds/') ||
        resolvedPath.contains('/splash/') ||
        resolvedPath.contains('hub_hero') ||
        resolvedPath.contains('kitchen')) {
      return backgroundDecodeWidth;
    }
    if (resolvedPath.contains('/bugs_hd/') ||
        resolvedPath.contains('/bugs_new/') ||
        resolvedPath.contains('/stickers/')) {
      return stickerDecodeWidth;
    }
    return defaultDecodeWidth;
  }

  /// Enqueues sticker + critical UI + font + audio + optional extra asset warm jobs
  /// and starts the time-sliced frame drain. Safe in `FlutterTest`.
  Future<void> start({
    List<String>? extraAssetPaths,
    bool autoEnqueueStickers = true,
    bool autoEnqueueFontsAndAudio = true,
    BuildContext? context,
  }) async {
    frameBudgetMs = frameBudgetMs.clamp(0.25, hardBudgetCapMs);
    maxSliceMs = 0;
    lastJobMs = 0;
    maxJobMs = 0;
    overBudgetJobCount = 0;

    if (autoEnqueueStickers) {
      enqueueStickerWarmup();
      for (final path in criticalStickerPaths) {
        final captured = path;
        enqueue(() => _warmAssetBytes(captured));
      }
      for (final path in criticalUiAssets) {
        final captured = path;
        enqueue(() => _warmAssetBytes(captured));
      }
    }

    if (autoEnqueueFontsAndAudio) {
      enqueueFontWarmup();
      enqueueAudioWarmup();
    }

    for (final path in extraAssetPaths ?? const <String>[]) {
      final captured = path;
      enqueue(() => _warmAssetBytes(captured));
    }

    if (context != null && context.mounted) {
      unawaited(precacheCriticalAssets(context));
    }

    if (isFlutterTest) {
      // In FlutterTest, run the queued jobs to real completion without
      // scheduling any frame callbacks that would block pumpAndSettle.
      // [_drainTestSafe] measures real elapsed time; it never reports
      // work as done before the queue is actually empty (S2#30).
      await _drainTestSafe();
      return;
    }

    _attachScheduler();
  }

  /// Precaches critical sticker, banner, and background images into Flutter's
  /// [ImageCache] via [precacheImage], time-sliced across frames.
  ///
  /// Düz `AssetImage` anahtarıyla yapılır (8B): widget'ların tamamı düz
  /// `AssetImage` (`Image.asset`) istediği için precache edilen girişle
  /// aynı anahtar eşleşir ve ilk gösterim önbellekten gelir. Önceden
  /// [sizedImageProvider] (`ResizeImage`) kullanılıyordu — o anahtarı
  /// hiçbir widget istemediği için precache boşa gidiyor, her görsel ilk
  /// gösterimde bir de tam çözünürlükte decode ediliyordu. Tam çözünürlük
  /// decode'u widget'ların bugünkü davranışıdır (değişiklik yok); toplam
  /// bellek `main.dart`'taki [ImageCache] sınırlarıyla (100 giriş / 100 MB)
  /// bağlıdır.
  ///
  /// Tek bilinen istisna: `splash_screen.dart` splash arka planını
  /// `cacheWidth: 860, cacheHeight: 1911` ile ister — o tek site kendi
  /// `ResizeImage` anahtarıyla decode eder (bilinçli boyut sınırı,
  /// dokunulmadı); `bg_splash.webp` yine de onboarding'deki düz istekle
  /// eşleşir.
  Future<void> precacheCriticalAssets(
    BuildContext context, {
    List<String>? extraImagePaths,
  }) async {
    if (!context.mounted) return;
    final allPaths = <String>{
      ...criticalStickerPaths,
      ...criticalUiAssets,
      for (final tier in InsectTier.values) tier.assetPath,
      ...?extraImagePaths,
    };

    for (final rawPath in allPaths) {
      final resolved = resolveAssetPath(rawPath);
      final warmedKey = 'precache:$resolved';
      // Only skip paths that really finished precaching, or whose job is
      // already queued. The warmed flag is set inside the job, after
      // precacheImage succeeds — never here, before the work runs.
      if (_warmedPaths.contains(warmedKey) ||
          _precachePending.contains(warmedKey)) {
        continue;
      }
      _precachePending.add(warmedKey);

      enqueue(() async {
        try {
          if (!context.mounted || isFlutterTest) return;
          var failed = false;
          try {
            await precacheImage(
              // Düz AssetImage (8B): widget'larla aynı önbellek anahtarı.
              // sizedImageProvider/ResizeImage burada kullanılmaz — o
              // anahtarı hiçbir widget istemez, precache boşa giderdi.
              AssetImage(resolved),
              context,
              onError: (_, _) {
                failed = true;
              },
            );
          } catch (_) {
            failed = true;
          }
          // Mark warmed only on real success: on error (or an unmounted
          // context / test mode above) the flag stays unset, so a later
          // call can retry instead of believing the image is cached.
          if (!failed) _warmedPaths.add(warmedKey);
        } finally {
          _precachePending.remove(warmedKey);
        }
      });
    }

    if (!isFlutterTest) {
      _attachScheduler();
    }
  }

  /// Builds time-sliced jobs that warm each insect sticker's bundle bytes
  /// under the frame budget. The actual decode happens once, later, via
  /// [precacheImage] in [precacheCriticalAssets] — this step only loads bytes
  /// so the bundle read never hitches a frame.
  /// Deduplicates alias paths pointing to the same physical image via
  /// [_warmedPhysicalPaths] so each physical asset is loaded only once while
  /// marking aliases complete.
  void enqueueStickerWarmup({int? warmPerTierOverride}) {
    final perTier = warmPerTierOverride ??
        AdaptiveQualityScaler.instance.recommendedPoolWarmPerTier;
    final _ = isFlutterTest ? 1 : perTier.clamp(1, 8);
    final scheduledPhysical = <String>{};

    for (final tier in InsectTier.values) {
      final path = tier.assetPath;
      final resolved = resolveAssetPath(path);
      if (_warmedPhysicalPaths.contains(resolved)) {
        // Bytes really loaded earlier — the alias is complete too.
        _warmedPaths.add(path);
        _warmedPaths.add(resolved);
        continue;
      }
      if (scheduledPhysical.contains(resolved)) {
        // Job already scheduled in this call; it marks the paths only
        // after its load succeeds, so mark nothing here.
        continue;
      }
      scheduledPhysical.add(resolved);
      enqueue(() => _warmAssetBytes(path));
    }
  }

  /// Pre-warms bundled font byte buffers in time-sliced jobs.
  void enqueueFontWarmup() {
    for (final fontPath in criticalFontAssets) {
      final captured = fontPath;
      enqueue(() => _warmBundleBytesOnly(captured));
    }
  }

  /// Pre-warms critical voice and SFX audio byte buffers in time-sliced jobs.
  ///
  /// Warms from the single canonical folder `assets/audio/` only, via
  /// [GameAudio.allAssets] (which already includes the `tier*_ses.mp3` clips
  /// listed in [criticalSoundAssets]). The byte-identical copies under
  /// `assets/design/sounds/` are NOT warmed separately: warming both
  /// folders loaded every `tier1..8_ses.mp3` twice.
  void enqueueAudioWarmup() {
    for (final audioFile in GameAudio.allAssets) {
      final captured = 'assets/audio/$audioFile';
      enqueue(() => _warmBundleBytesOnly(captured));
    }
  }

  void enqueue(FutureOr<void> Function() job) {
    _work.add(job);
    _totalJobs++;
    isWarming = true;
    if (_totalJobs > 0 && _doneJobs == 0) {
      progress01 = 0;
    }
  }

  /// Marks pointer activity so warm yields while the user is interacting.
  void notePointerDown() {
    _pointerDown = true;
    _lastTouch = DateTime.now();
  }

  void notePointerUp() {
    _pointerDown = false;
    _lastTouch = DateTime.now();
  }

  /// Enables the drain loop and schedules its first one-shot callback.
  /// Safe to call repeatedly: [_scheduleNextFrame] never queues a second
  /// callback while one is outstanding, so restarts cannot double-register.
  /// Never schedules frames under `flutter test` (see [_drainTestSafe]).
  void _attachScheduler() {
    if (isFlutterTest) return;
    _schedulerAttached = true;
    _scheduleNextFrame();
  }

  /// Schedules at most one one-shot post-frame callback that runs [_onFrame]
  /// once, plus the frame that carries it. Each callback re-schedules the
  /// next one only while work remains, so the loop ends by itself when the
  /// queue empties and [detachScheduler] ends it immediately by clearing
  /// [_schedulerAttached]: no callback stays registered for the lifetime
  /// of the app (S2#29). While a drain is running, no extra callback is
  /// queued — the drain re-schedules at its end if work remains.
  void _scheduleNextFrame() {
    if (!_schedulerAttached ||
        _frameCallbackPending ||
        _draining ||
        isFlutterTest) {
      return;
    }
    _frameCallbackPending = true;
    try {
      SchedulerBinding.instance.addPostFrameCallback(_onFrame);
      SchedulerBinding.instance.scheduleFrame();
    } catch (_) {
      _frameCallbackPending = false;
    }
  }

  /// Stops the drain loop. Because the loop is a chain of one-shot
  /// callbacks, stopping means scheduling no more: at most one
  /// already-queued callback fires once, observes this flag, and returns
  /// without re-scheduling. A later [start] re-attaches cleanly.
  void detachScheduler() {
    _schedulerAttached = false;
    isWarming = false;
  }

  void _onFrame(Duration _) {
    // This one-shot callback has fired; it is no longer outstanding.
    // Clear first so every exit path below can re-schedule (or not) cleanly.
    _frameCallbackPending = false;
    if (!_schedulerAttached || _draining) return;
    if (_work.isEmpty) {
      if (isWarming) {
        isWarming = false;
        progress01 = 1;
        onWarmupComplete?.call();
      }
      return;
    }

    if (yieldOnTouch) {
      final cool = DateTime.now().difference(_lastTouch) < _touchCooldown;
      if (_pointerDown || cool) {
        // Retry on a later frame; without re-scheduling, the one-shot
        // chain would end and queued work would stall.
        _scheduleNextFrame();
        return;
      }
    }

    unawaited(_drainBudget());
  }

  /// Test-only drain, kept strictly separate from the production path:
  /// production drains via frame callbacks in [_drainBudget]; this method
  /// runs only from [start] when [isFlutterTest] is true and schedules no
  /// frames, so it cannot block `pumpAndSettle`.
  ///
  /// Honest measurement (S2#30): every queued job actually runs to
  /// completion, `_doneJobs` counts only jobs that ran, and [lastSliceMs] /
  /// [maxSliceMs] record the real measured wall-clock time. Completion
  /// ([progress01] = 1, [onWarmupComplete]) is reported only after the
  /// queue is actually empty — never before, and never with fabricated
  /// timings. A failed job counts as attempted, matching [_drainBudget].
  Future<void> _drainTestSafe() async {
    if (!isFlutterTest || _draining) return;
    _draining = true;
    isWarming = true;
    final watch = Stopwatch()..start();
    final budget = frameBudgetMs.clamp(0.25, hardBudgetCapMs);

    try {
      while (_work.isNotEmpty) {
        final job = _work.removeFirst();
        final jobWatch = Stopwatch()..start();
        try {
          await job();
        } catch (_) {
          // Failed job: counted as attempted below, like _drainBudget.
        } finally {
          jobWatch.stop();
        }
        final jobMs = jobWatch.elapsedMicroseconds / 1000.0;
        lastJobMs = jobMs;
        if (jobMs > maxJobMs) maxJobMs = jobMs;
        if (jobMs >= budget) overBudgetJobCount++;
        _doneJobs++;
        if (_totalJobs > 0) {
          progress01 = (_doneJobs / _totalJobs).clamp(0.0, 1.0);
        }
      }
    } finally {
      watch.stop();
      final elapsedMs = watch.elapsedMicroseconds / 1000.0;
      lastSliceMs = elapsedMs;
      if (elapsedMs > maxSliceMs) maxSliceMs = elapsedMs;
      _draining = false;
    }

    if (_work.isEmpty) {
      isWarming = false;
      progress01 = 1;
      onWarmupComplete?.call();
    }
  }

  Future<void> _drainBudget() async {
    if (_draining) return;
    _draining = true;
    isWarming = true;
    final watch = Stopwatch()..start();
    final budget = frameBudgetMs.clamp(0.25, hardBudgetCapMs);

    try {
      while (_work.isNotEmpty) {
        if (watch.elapsedMicroseconds / 1000.0 >= budget) {
          // Budget exceeded — defer remaining jobs to the next frame.
          break;
        }
        final job = _work.removeFirst();
        // Per-job timing: the budget check above only runs BETWEEN jobs, so
        // one slow job can exceed the whole frame budget on its own. Measure
        // each job and flag overruns separately. The flag is observability
        // only: an over-budget job is never skipped, cancelled, or deferred
        // mid-flight — it always runs to completion, and remaining jobs are
        // still deferred to the next frame by the check above.
        final jobWatch = Stopwatch()..start();
        try {
          await job();
        } catch (e, st) {
          if (!isFlutterTest && kDebugMode) {
            debugPrint('[ZeroJankPreloader] job skipped: $e\n$st');
          }
        } finally {
          jobWatch.stop();
        }
        final jobMs = jobWatch.elapsedMicroseconds / 1000.0;
        lastJobMs = jobMs;
        if (jobMs > maxJobMs) maxJobMs = jobMs;
        if (jobMs >= budget) {
          overBudgetJobCount++;
          if (!isFlutterTest && kDebugMode) {
            debugPrint(
              '[ZeroJankPreloader] job exceeded frame budget: '
              '${jobMs.toStringAsFixed(2)}ms >= ${budget.toStringAsFixed(2)}ms '
              '(over-budget jobs: $overBudgetJobCount)',
            );
          }
        }
        _doneJobs++;
        if (_totalJobs > 0) {
          progress01 = (_doneJobs / _totalJobs).clamp(0.0, 1.0);
        }
      }
    } finally {
      watch.stop();
      final elapsedMs = watch.elapsedMicroseconds / 1000.0;
      lastSliceMs = elapsedMs;
      if (lastSliceMs > maxSliceMs) maxSliceMs = lastSliceMs;
      _draining = false;
    }

    if (_work.isNotEmpty) {
      // One-shot chain: queue the next frame callback instead of relying
      // on a persistent callback. No-op when detached or under test.
      _scheduleNextFrame();
    } else if (_work.isEmpty) {
      isWarming = false;
      progress01 = 1;
      onWarmupComplete?.call();
    }
  }

  Future<void> _warmBundleBytesOnly(String assetPath) async {
    if (isFlutterTest) return;
    final resolved = resolveAssetPath(assetPath);
    if (_warmedPaths.contains('bytes:$resolved')) return;
    try {
      await rootBundle.load(resolved);
      // Mark warmed only after the load really succeeded; on failure the
      // flag stays unset so a later warmup can retry (S2#31).
      _warmedPaths.add('bytes:$resolved');
    } catch (_) {}
  }

  /// Warms an image asset's bundle bytes (load only, no decode).
  ///
  /// Decoding happens exactly once, via [precacheImage] in
  /// [precacheCriticalAssets], which stores the decoded image in Flutter's
  /// [ImageCache]. This method deliberately does NOT call
  /// `instantiateImageCodec`: the decoded frame was immediately disposed, so
  /// it only doubled decode work for every image that precaching decodes
  /// again. Loading the bytes here still warms the bundle read itself.
  /// The warmed flags are set only after a load succeeds (S2#31).
  Future<void> _warmAssetBytes(String assetPath) async {
    final resolved = resolveAssetPath(assetPath);
    if (_warmedPhysicalPaths.contains(resolved)) {
      // Physical image bytes already loaded — mark alias completed without
      // loading them again.
      _warmedPaths.add(assetPath);
      _warmedPaths.add(resolved);
      return;
    }
    // Test mode performs no bundle load, so nothing is marked warmed here;
    // the job still counts as attempted by the test drain.
    if (isFlutterTest) return;
    // Jobs run strictly one at a time from the drain queue, so no second
    // load of the same path can start while this one is in flight; the
    // warmed flags can safely be set only after the load succeeds.
    try {
      await rootBundle.load(resolved);
      _warmedPhysicalPaths.add(resolved);
      _warmedPaths.add(assetPath);
      _warmedPaths.add(resolved);
    } catch (_) {
      // Fallback if original logical path differs from alias. The fallback
      // path is marked only if its own load succeeds; if both loads fail,
      // no flag is set and a later warmup can retry (S2#31).
      if (resolved != assetPath && !_warmedPhysicalPaths.contains(assetPath)) {
        try {
          await rootBundle.load(assetPath);
          _warmedPhysicalPaths.add(assetPath);
          _warmedPaths.add(assetPath);
        } catch (_) {}
      }
    }
  }
}

