import 'dart:math' as math;

/// Mobile-first adaptive quality: Eco → Low → Medium → High → Ultra.
/// Scales particle caps and draw resolution for ≤2 GB RAM devices (Eco).
class AdaptiveQualityScaler {
  AdaptiveQualityScaler._();
  static final AdaptiveQualityScaler instance = AdaptiveQualityScaler._();

  static const int targetFps = 60;
  static const double hysteresisSeconds = 5;
  static const double downgradeMs = 22; // ~45 FPS P95
  static const double upgradeMs = 14; // headroom toward 70 FPS

  QualityTier _currentTier = QualityTier.medium;
  double dynamicResolutionScale = 1;
  int recommendedPoolWarmPerTier = 4;
  int maxActiveParticles = 64;
  double particleScale = 1;
  double drawScale = 1;
  bool shadowsEnabled = true;
  double lastP95FrameMs = 0;

  final List<double> _frameSamples = List<double>.filled(64, 0);
  int _sampleIndex = 0;
  int _sampleCount = 0;
  DateTime _lastTierChange = DateTime.fromMillisecondsSinceEpoch(0);

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

  /// Call once at app start. Optional [systemMemoryMb] for Eco on ≤2 GB devices.
  void bootstrap({int? systemMemoryMb, QualityTier? forceTier}) {
    applyTier(
      forceTier ?? detectInitialTier(systemMemoryMb: systemMemoryMb),
      force: true,
    );
  }

  void setTier(QualityTier tier) => applyTier(tier, force: true);

  /// Feed unscaled frame duration in milliseconds (e.g. from a ticker).
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

    if (p95 > downgradeMs && _currentTier.index > QualityTier.eco.index) {
      applyTier(QualityTier.values[_currentTier.index - 1], force: false);
    } else if (p95 < upgradeMs &&
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
      case QualityTier.low:
        dynamicResolutionScale = 0.75;
        recommendedPoolWarmPerTier = 3;
        maxActiveParticles = 32;
        particleScale = 0.65;
        drawScale = 0.75;
        shadowsEnabled = false;
      case QualityTier.medium:
        dynamicResolutionScale = 0.85;
        recommendedPoolWarmPerTier = 4;
        maxActiveParticles = 64;
        particleScale = 0.85;
        drawScale = 0.85;
        shadowsEnabled = true;
      case QualityTier.high:
        dynamicResolutionScale = 1;
        recommendedPoolWarmPerTier = 6;
        maxActiveParticles = 96;
        particleScale = 1;
        drawScale = 1;
        shadowsEnabled = true;
      case QualityTier.ultra:
        dynamicResolutionScale = 1;
        recommendedPoolWarmPerTier = 8;
        maxActiveParticles = 128;
        particleScale = 1.15;
        drawScale = 1;
        shadowsEnabled = true;
    }

    for (final listener in List.of(_listeners)) {
      listener(_currentTier);
    }
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
