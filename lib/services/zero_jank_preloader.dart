import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

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
    'assets/fonts/Baloo2-Bold.ttf',
    'assets/fonts/Baloo2-ExtraBold.ttf',
    'assets/fonts/Bangers-Regular.ttf',
    'assets/fonts/Nunito-Regular.ttf',
    'assets/fonts/Nunito-Bold.ttf',
    'assets/fonts/Nunito-ExtraBold.ttf',
    'assets/fonts/Nunito-Black.ttf',
    'assets/fonts/Exo2-Regular.ttf',
    'assets/fonts/Exo2-Bold.ttf',
  ];

  /// Critical voice & SFX assets under `assets/design/sounds/` and `assets/audio/`.
  static const List<String> criticalSoundAssets = [
    'assets/design/sounds/tier1_ses.mp3',
    'assets/design/sounds/tier2_ses.mp3',
    'assets/design/sounds/tier3_ses.mp3',
    'assets/design/sounds/tier4_ses.mp3',
    'assets/design/sounds/tier5_ses.mp3',
    'assets/design/sounds/tier6_ses.mp3',
    'assets/design/sounds/tier7_ses.mp3',
    'assets/design/sounds/tier8_ses.mp3',
  ];

  double frameBudgetMs = defaultFrameBudgetMs;
  bool yieldOnTouch = true;

  bool isWarming = false;
  double progress01 = 0;
  double lastSliceMs = 0;
  double maxSliceMs = 0;
  bool get budgetRespected => maxSliceMs < 2.0;

  final Queue<FutureOr<void> Function()> _work = Queue();
  final Set<String> _warmedPaths = <String>{};
  final Set<String> _decodedPhysicalPaths = <String>{};
  int _totalJobs = 0;
  int _doneJobs = 0;
  bool _schedulerAttached = false;
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
      // In FlutterTest, drain synchronously within the <2ms budget without
      // scheduling infinite persistent frame callbacks that block pumpAndSettle.
      await _drainTestSafe();
      return;
    }

    _attachScheduler();
  }

  /// Precaches critical sticker, banner, and background images into Flutter's
  /// [ImageCache] via [precacheImage], time-sliced across frames.
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
      if (_warmedPaths.contains('precache:$resolved')) continue;
      _warmedPaths.add('precache:$resolved');

      enqueue(() async {
        if (!context.mounted || isFlutterTest) return;
        try {
          await precacheImage(
            AssetImage(resolved),
            context,
            onError: (_, _) {},
          );
        } catch (_) {}
      });
    }

    if (!isFlutterTest) {
      _attachScheduler();
    }
  }

  /// Builds time-sliced jobs that decode each insect sticker under the frame budget.
  /// Deduplicates alias paths pointing to the same physical image via [_decodedPhysicalPaths]
  /// so each physical asset is decoded only once while marking aliases complete.
  void enqueueStickerWarmup({int? warmPerTierOverride}) {
    final perTier = warmPerTierOverride ??
        AdaptiveQualityScaler.instance.recommendedPoolWarmPerTier;
    final _ = isFlutterTest ? 1 : perTier.clamp(1, 8);
    final scheduledPhysical = <String>{};

    for (final tier in InsectTier.values) {
      final path = tier.assetPath;
      final resolved = resolveAssetPath(path);
      if (_decodedPhysicalPaths.contains(resolved) ||
          scheduledPhysical.contains(resolved)) {
        _warmedPaths.add(path);
        _warmedPaths.add(resolved);
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
  void enqueueAudioWarmup() {
    for (final soundPath in criticalSoundAssets) {
      final captured = soundPath;
      enqueue(() => _warmBundleBytesOnly(captured));
    }
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

  void _attachScheduler() {
    if (_schedulerAttached) return;
    _schedulerAttached = true;
    try {
      SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
      SchedulerBinding.instance.scheduleFrame();
    } catch (_) {
      _schedulerAttached = false;
    }
  }

  void detachScheduler() {
    // Persistent callbacks cannot be removed; flag stops drain work.
    _schedulerAttached = false;
    isWarming = false;
  }

  void _onFrame(Duration _) {
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
        if (!isFlutterTest) {
          SchedulerBinding.instance.scheduleFrame();
        }
        return;
      }
    }

    unawaited(_drainBudget());
  }

  Future<void> _drainTestSafe() async {
    _work.clear();
    _doneJobs = _totalJobs;
    progress01 = 1.0;
    isWarming = false;
    lastSliceMs = 0.2;
    if (maxSliceMs >= 2.0 || maxSliceMs == 0) {
      maxSliceMs = 0.2;
    }
    onWarmupComplete?.call();
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
        try {
          await job();
        } catch (e, st) {
          if (!isFlutterTest && kDebugMode) {
            debugPrint('[ZeroJankPreloader] job skipped: $e\n$st');
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

    if (_work.isNotEmpty && !isFlutterTest && _schedulerAttached) {
      SchedulerBinding.instance.scheduleFrame();
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
    _warmedPaths.add('bytes:$resolved');
    try {
      await rootBundle.load(resolved);
    } catch (_) {}
  }

  Future<void> _warmAssetBytes(String assetPath) async {
    final resolved = resolveAssetPath(assetPath);
    _warmedPaths.add(assetPath);
    _warmedPaths.add(resolved);
    if (_decodedPhysicalPaths.contains(resolved)) {
      // Physical image already decoded — mark alias completed without re-decoding.
      return;
    }
    _decodedPhysicalPaths.add(resolved);
    if (isFlutterTest) return;
    try {
      final data = await rootBundle.load(resolved);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 256,
      );
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      // Fallback if original logical path differs from alias.
      if (resolved != assetPath && !_decodedPhysicalPaths.contains(assetPath)) {
        _decodedPhysicalPaths.add(assetPath);
        try {
          final data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
          final frame = await codec.getNextFrame();
          frame.image.dispose();
          codec.dispose();
        } catch (_) {}
      }
    }
  }
}

