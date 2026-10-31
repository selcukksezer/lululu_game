import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../models/insect_tier.dart';
import 'adaptive_quality_scaler.dart';

/// Progressive asset warm with a hard &lt;2ms/frame budget (PROMPT_ORDUSU ZeroJank).
/// Time-slices decode / cache work so the first frames never hitch.
class ZeroJankPreloader {
  ZeroJankPreloader._();
  static final ZeroJankPreloader instance = ZeroJankPreloader._();

  /// Must stay strictly under 2.0ms per frame.
  static const double defaultFrameBudgetMs = 1.8;
  static const double hardBudgetCapMs = 1.95;

  double frameBudgetMs = defaultFrameBudgetMs;
  bool yieldOnTouch = true;

  bool isWarming = false;
  double progress01 = 0;
  double lastSliceMs = 0;
  double maxSliceMs = 0;
  bool get budgetRespected => maxSliceMs < 2.0;

  final Queue<FutureOr<void> Function()> _work = Queue();
  int _totalJobs = 0;
  int _doneJobs = 0;
  bool _schedulerAttached = false;
  bool _pointerDown = false;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);
  final Duration _touchCooldown = const Duration(milliseconds: 120);

  VoidCallback? onWarmupComplete;

  /// Enqueues sticker + optional extra asset warm jobs and starts the frame drain.
  Future<void> start({
    List<String>? extraAssetPaths,
    bool autoEnqueueStickers = true,
  }) async {
    frameBudgetMs = frameBudgetMs.clamp(0.25, hardBudgetCapMs);
    maxSliceMs = 0;
    if (autoEnqueueStickers) {
      enqueueStickerWarmup();
    }
    for (final path in extraAssetPaths ?? const <String>[]) {
      final captured = path;
      enqueue(() => _warmAssetBytes(captured));
    }
    _attachScheduler();
  }

  /// Builds time-sliced jobs that decode each insect sticker under the frame budget.
  void enqueueStickerWarmup({int? warmPerTierOverride}) {
    final perTier = warmPerTierOverride ??
        AdaptiveQualityScaler.instance.recommendedPoolWarmPerTier;
    final warmCount = perTier.clamp(1, 8);

    for (final tier in InsectTier.values) {
      for (var i = 0; i < warmCount; i++) {
        final path = tier.assetPath;
        enqueue(() => _warmAssetBytes(path));
      }
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
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    SchedulerBinding.instance.scheduleFrame();
  }

  void detachScheduler() {
    // Persistent callbacks cannot be removed; flag stops drain work.
    _schedulerAttached = false;
    isWarming = false;
  }

  void _onFrame(Duration _) {
    if (!_schedulerAttached) return;
    if (_work.isEmpty) {
      if (isWarming) {
        isWarming = false;
        progress01 = 1;
        onWarmupComplete?.call();
      }
      return;
    }

    if (yieldOnTouch) {
      final cool =
          DateTime.now().difference(_lastTouch) < _touchCooldown;
      if (_pointerDown || cool) {
        SchedulerBinding.instance.scheduleFrame();
        return;
      }
    }

    unawaited(_drainBudget());
  }

  Future<void> _drainBudget() async {
    isWarming = true;
    final watch = Stopwatch()..start();
    final budget = frameBudgetMs;

    while (_work.isNotEmpty && watch.elapsedMicroseconds / 1000.0 < budget) {
      final job = _work.removeFirst();
      try {
        await job();
      } catch (e, st) {
        debugPrint('[ZeroJankPreloader] job failed: $e\n$st');
      }
      _doneJobs++;
      if (_totalJobs > 0) {
        progress01 = (_doneJobs / _totalJobs).clamp(0.0, 1.0);
      }
    }

    watch.stop();
    lastSliceMs = watch.elapsedMicroseconds / 1000.0;
    if (lastSliceMs > maxSliceMs) maxSliceMs = lastSliceMs;

    if (_work.isNotEmpty) {
      SchedulerBinding.instance.scheduleFrame();
    } else {
      isWarming = false;
      progress01 = 1;
      onWarmupComplete?.call();
    }
  }

  Future<void> _warmAssetBytes(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    frame.image.dispose();
  }
}
