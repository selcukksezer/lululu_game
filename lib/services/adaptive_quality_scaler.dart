import 'dart:math' as math;
import 'dart:ui' show FrameTiming, PlatformDispatcher;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Mobile-first adaptive quality: Eco → Low → Medium → High → Ultra.
/// Scales particle caps, shadow quality, physics sub-steps, and draw resolution
/// for 60Hz and 120Hz ProMotion displays while maintaining a <2ms overhead budget.
class AdaptiveQualityScaler {
  AdaptiveQualityScaler._();
  static final AdaptiveQualityScaler instance = AdaptiveQualityScaler._();

  static const int targetFps = 60;
  static const int proMotionFps = 120;
  static const double hysteresisSeconds = 5;
  static const double downgradeMs = 22; // ~45 FPS P95 on 60Hz
  static const double upgradeMs = 14; // headroom toward 70 FPS on 60Hz
  static const double proMotionDowngradeMs = 11.5; // ~87 FPS P95 on 120Hz
  static const double proMotionUpgradeMs = 7.2; // <8.33ms frame budget on 120Hz

  /// Hard <2.0ms per-frame budget for adaptive scaler & auxiliary work.
  static const double maxFrameBudgetMs = 1.95;
  double frameBudgetMs = 1.8;

  QualityTier _currentTier = QualityTier.medium;
  double dynamicResolutionScale = 1;
  int recommendedPoolWarmPerTier = 4;
  int maxActiveParticles = 64;
  double particleScale = 1;
  double drawScale = 1;
  bool shadowsEnabled = true;

  /// Dynamic shadow quality tier (0 = off, 1 = soft low, 2 = medium, 3 = high).
  int shadowQuality = 1;
  double shadowBlurRadius = 6;

  /// Dynamic Verlet physics sub-steps per frame (scaled for 60Hz / 120Hz ProMotion).
  int physicsSubSteps = 4;

  /// Detected display refresh rate (60Hz standard, 120Hz ProMotion).
  int displayRefreshRateHz = 60;
  bool get isProMotion => displayRefreshRateHz >= 110;

  double lastP95FrameMs = 0;
  double lastBuildMs = 0;
  double lastRasterMs = 0;
  double lastOverheadMs = 0;
  bool get budgetRespected => lastOverheadMs < 2.0 && frameBudgetMs < 2.0;

  final List<double> _frameSamples = List<double>.filled(64, 0);
  int _sampleIndex = 0;
  int _sampleCount = 0;
  DateTime _lastTierChange = DateTime.fromMillisecondsSinceEpoch(0);
  bool _timingsAttached = false;

  final List<void Function(QualityTier)> _listeners = [];

  QualityTier get currentTier => _currentTier;

  void addTierListener(void Function(QualityTier) listener) {
    _listeners.add(listener);
  }

  void removeTierListener(void Function(QualityTier) listener) {
    _listeners.remove(listener);
  }

  /// Detects initial tier from RAM (MB). Unknown / null → Medium.
  QualityTier detectInitialTier({int? systemMemoryMb}) {
    final ram = systemMemoryMb;
    if (ram == null || ram <= 0) return QualityTier.medium;
    if (ram <= 2048) return QualityTier.eco;
    if (ram <= 2560) return QualityTier.low;
    if (ram <= 4096) return QualityTier.medium;
    if (ram <= 8192) return QualityTier.high;
    return QualityTier.ultra;
  }

  /// Detects display refresh rate (60Hz vs 120Hz ProMotion) from PlatformDispatcher.
  int detectRefreshRateHz() {
    try {
      final views = PlatformDispatcher.instance.views;
      if (views.isNotEmpty) {
        final rate = views.first.display.refreshRate;
        if (rate >= 110) return 120;
        if (rate >= 85) return 90;
        if (rate > 0) return rate.round();
      }
      final implicitRate =
          PlatformDispatcher.instance.implicitView?.display.refreshRate ?? 60.0;
      if (implicitRate >= 110) return 120;
      if (implicitRate > 0) return implicitRate.round();
    } catch (_) {
      // Fallback to 60Hz when PlatformDispatcher display is unavailable.
    }
    return 60;
  }

  /// Call once at app start. Optional [systemMemoryMb] for Eco on ≤2 GB devices.
  void bootstrap({
    int? systemMemoryMb,
    QualityTier? forceTier,
    bool attachTimings = true,
  }) {
    frameBudgetMs = frameBudgetMs.clamp(0.25, maxFrameBudgetMs);
    displayRefreshRateHz = detectRefreshRateHz();
    applyTier(
      forceTier ?? detectInitialTier(systemMemoryMb: systemMemoryMb),
      force: true,
    );
    if (attachTimings && !_isTestBinding()) {
      attachTimingsCallback();
    }
  }

  /// Preferred startup entry point: pick the initial tier from total device
  /// RAM when the caller can supply it.
  ///
  /// - `initialize(totalRamMb: 2048)` → starts at [QualityTier.eco] (≤2 GB),
  ///   `3072` → [QualityTier.low], `4096` → [QualityTier.medium], `8192` →
  ///   [QualityTier.high], above that → [QualityTier.ultra] (see
  ///   [detectInitialTier] for the exact thresholds).
  /// - `initialize()` / `initialize(totalRamMb: null)` → existing behaviour:
  ///   unknown RAM starts at [QualityTier.medium], exactly like [bootstrap]
  ///   with no arguments.
  ///
  /// The RAM value itself is obtained by the caller (e.g. via
  /// `device_info_plus` on the platform side); this file performs no platform
  /// lookup. Wiring in `main.dart` is a Wave 3 step — call example:
  /// ```dart
  /// AdaptiveQualityScaler.instance.initialize(totalRamMb: totalRamMb);
  /// ```
  /// [bootstrap] remains available for tests and for callers that need
  /// [QualityTier] forcing or timings control.
  void initialize({int? totalRamMb}) {
    bootstrap(systemMemoryMb: totalRamMb);
  }

  bool _isTestBinding() {
    try {
      final typeName = WidgetsBinding.instance.runtimeType.toString();
      return typeName.contains('Test') || typeName.contains('Automated');
    } catch (_) {
      return true;
    }
  }

  /// Attaches [SchedulerBinding.instance.addTimingsCallback] to monitor real
  /// UI + raster frame durations on 60Hz and 120Hz ProMotion displays.
  void attachTimingsCallback() {
    if (_timingsAttached) return;
    try {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
      _timingsAttached = true;
    } catch (_) {
      _timingsAttached = false;
    }
  }

  /// Detaches the frame timings listener if attached.
  void detachTimingsCallback() {
    if (!_timingsAttached) return;
    try {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    } catch (_) {}
    _timingsAttached = false;
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return;
    final sw = Stopwatch()..start();

    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalMs = timing.totalSpan.inMicroseconds / 1000.0;
      lastBuildMs = buildMs;
      lastRasterMs = rasterMs;

      // Infer 120Hz ProMotion if sustained frames complete well under 9ms vsync cadence.
      if (totalMs > 0 && totalMs < 9.0 && displayRefreshRateHz < 120) {
        final detected = detectRefreshRateHz();
        if (detected >= 110) {
          displayRefreshRateHz = 120;
          _updateProMotionScaling(_currentTier);
        }
      }

      recordFrameMs(totalMs > 0 ? totalMs : (buildMs + rasterMs));

      if (sw.elapsedMicroseconds / 1000.0 >= frameBudgetMs) {
        break;
      }
    }

    sw.stop();
    lastOverheadMs = sw.elapsedMicroseconds / 1000.0;
  }

  void setTier(QualityTier tier) => applyTier(tier, force: true);

  /// Feed unscaled frame duration in milliseconds (e.g. from a ticker or FrameTiming).
  void recordFrameMs(double dtMs) {
    _frameSamples[_sampleIndex] = dtMs;
    _sampleIndex = (_sampleIndex + 1) % _frameSamples.length;
    if (_sampleCount < _frameSamples.length) _sampleCount++;

    if (_sampleCount < 16) return;
    final elapsed =
        DateTime.now().difference(_lastTierChange).inMilliseconds / 1000.0;
    if (elapsed < hysteresisSeconds) return;

    final p95 = _estimateP95();
    lastP95FrameMs = p95;

    final downThreshold = isProMotion ? proMotionDowngradeMs : downgradeMs;
    final upThreshold = isProMotion ? proMotionUpgradeMs : upgradeMs;

    if (p95 > downThreshold && _currentTier.index > QualityTier.eco.index) {
      applyTier(QualityTier.values[_currentTier.index - 1], force: false);
    } else if (p95 < upThreshold &&
        _currentTier.index < QualityTier.ultra.index) {
      applyTier(QualityTier.values[_currentTier.index + 1], force: false);
    }
  }

  void applyTier(QualityTier tier, {required bool force}) {
    if (!force && tier == _currentTier) return;

    _currentTier = tier;
    _lastTierChange = DateTime.now();

    switch (tier) {
      case QualityTier.eco:
        dynamicResolutionScale = 0.5;
        recommendedPoolWarmPerTier = 2;
        maxActiveParticles = 16;
        particleScale = 0.45;
        drawScale = 0.5;
        shadowsEnabled = false;
        shadowQuality = 0;
        shadowBlurRadius = 0;
        physicsSubSteps = 2;
      case QualityTier.low:
        dynamicResolutionScale = 0.75;
        recommendedPoolWarmPerTier = 3;
        maxActiveParticles = 32;
        particleScale = 0.65;
        drawScale = 0.75;
        shadowsEnabled = false;
        shadowQuality = 0;
        shadowBlurRadius = 0;
        physicsSubSteps = 3;
      case QualityTier.medium:
        dynamicResolutionScale = 0.85;
        recommendedPoolWarmPerTier = 4;
        maxActiveParticles = 64;
        particleScale = 0.85;
        drawScale = 0.85;
        shadowsEnabled = true;
        shadowQuality = 1;
        shadowBlurRadius = 4;
        physicsSubSteps = 4;
      case QualityTier.high:
        dynamicResolutionScale = 1;
        recommendedPoolWarmPerTier = 6;
        maxActiveParticles = 96;
        particleScale = 1;
        drawScale = 1;
        shadowsEnabled = true;
        shadowQuality = 2;
        shadowBlurRadius = 8;
        physicsSubSteps = 6;
      case QualityTier.ultra:
        dynamicResolutionScale = 1;
        recommendedPoolWarmPerTier = 8;
        maxActiveParticles = 128;
        particleScale = 1.15;
        drawScale = 1;
        shadowsEnabled = true;
        shadowQuality = 3;
        shadowBlurRadius = 12;
        physicsSubSteps = 8;
    }

    _updateProMotionScaling(tier);

    for (final listener in List.of(_listeners)) {
      try {
        listener(_currentTier);
      } catch (e) {
        // Bir dinleyicinin hatası diğer dinleyicileri engellemesin.
        debugPrint('[AdaptiveQualityScaler] tier listener failed: $e');
      }
    }
  }

  void _updateProMotionScaling(QualityTier tier) {
    if (!isProMotion) return;
    // On 120Hz ProMotion (8.33ms frame budget), physics runs twice as often per
    // second, so we balance sub-steps per frame to keep physics <1.5ms/frame.
    switch (tier) {
      case QualityTier.eco:
        physicsSubSteps = 2;
      case QualityTier.low:
        physicsSubSteps = 2;
      case QualityTier.medium:
        physicsSubSteps = 3;
      case QualityTier.high:
        physicsSubSteps = 4;
      case QualityTier.ultra:
        physicsSubSteps = 6;
    }
  }

  /// Recommended physics sub-steps for a given frame delta time [dtSeconds].
  int recommendedSubStepsForDt(double dtSeconds) {
    if (dtSeconds <= 0.009) {
      // ~120Hz frame
      return math.max(2, (physicsSubSteps * 0.75).round());
    }
    if (dtSeconds > 0.020) {
      // Frame spike guard: cap sub-steps so we never spiral into death-jank.
      return math.min(physicsSubSteps, 4);
    }
    return physicsSubSteps;
  }

  double _estimateP95() {
    final n = _sampleCount;
    final sorted = _frameSamples.sublist(0, n)..sort();
    final idx = math.max(0, math.min(n - 1, (n * 0.95).ceil() - 1));
    return sorted[idx];
  }
}

enum QualityTier {
  eco,
  low,
  medium,
  high,
  ultra,
}

