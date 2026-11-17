import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'audio_manager.dart';
import 'haptic_service.dart';

/// Kombo basamağına göre Türkçe viral anons, renk, ölçek ve sarsıntı profili.
@immutable
class ComboAnnouncementTier {
  const ComboAnnouncementTier({
    required this.minCombo,
    required this.maxCombo,
    required this.title,
    required this.color,
    required this.scaleMultiplier,
    required this.scoreMultiplier,
    required this.shakeIntensity,
  });

  final int minCombo;
  final int? maxCombo;
  final String title;
  final Color color;
  final double scaleMultiplier;
  final double scoreMultiplier;
  final double shakeIntensity;

  bool matches(int combo) {
    if (combo < minCombo) return false;
    if (maxCombo != null && combo > maxCombo!) return false;
    return true;
  }
}

/// Türkçe Viral Kombo Anons, Sönümlü Harmonik Ekran Sarsıntısı ve
/// Ses/Haptic Orkestratörü (`ComboJuiceService`).
class ComboJuiceService extends ChangeNotifier {
  ComboJuiceService({
    this.comboWindowMs = defaultComboWindowMs,
    AudioManager? audioManager,
    HapticService? hapticService,
  })  : _audioManager = audioManager ?? AudioManager.instance,
        _hapticService = hapticService ?? HapticService.instance;

  static final ComboJuiceService instance = ComboJuiceService();

  /// Kombo zincirinin kırılmadan devam edebileceği maksimum süre (ms).
  static const int defaultComboWindowMs = 2800;

  /// Minimum ve maksimum skor/kombo çarpan sınırları (`1.0` .. `3.5x`).
  static const double minComboMultiplier = 1.0;
  static const double maxComboMultiplier = 3.5;

  /// Türkçe viral kombo basamak tablosu:
  /// - `2x`: `"İKİLİ KOMBO!"` (`#FFD54F`)
  /// - `3x`: `"ÜÇLÜ PATLAMA!"` (`#FF9800`)
  /// - `4x`: `"HARİKA EZİŞ!"` (`#FF5722`)
  /// - `5x-6x`: `"EFSANE LÜLÜLÜ!"` (`#E040FB`)
  /// - `7x-9x`: `"OSMAN ÇILDIRDI!"` (`#00E5FF`)
  /// - `10x+`: `"MAKARA KOPTU! ULTRA KOMBO!"` (`#FF1744`)
  static const List<ComboAnnouncementTier> tiers = <ComboAnnouncementTier>[
    ComboAnnouncementTier(
      minCombo: 2,
      maxCombo: 2,
      title: 'İKİLİ KOMBO!',
      color: Color(0xFFFFD54F),
      scaleMultiplier: 1.12,
      scoreMultiplier: 1.25,
      shakeIntensity: 4.5,
    ),
    ComboAnnouncementTier(
      minCombo: 3,
      maxCombo: 3,
      title: 'ÜÇLÜ PATLAMA!',
      color: Color(0xFFFF9800),
      scaleMultiplier: 1.22,
      scoreMultiplier: 1.55,
      shakeIntensity: 6.5,
    ),
    ComboAnnouncementTier(
      minCombo: 4,
      maxCombo: 4,
      title: 'HARİKA EZİŞ!',
      color: Color(0xFFFF5722),
      scaleMultiplier: 1.32,
      scoreMultiplier: 1.85,
      shakeIntensity: 8.5,
    ),
    ComboAnnouncementTier(
      minCombo: 5,
      maxCombo: 6,
      title: 'EFSANE LÜLÜLÜ!',
      color: Color(0xFFE040FB),
      scaleMultiplier: 1.45,
      scoreMultiplier: 2.25,
      shakeIntensity: 11.0,
    ),
    ComboAnnouncementTier(
      minCombo: 7,
      maxCombo: 9,
      title: 'OSMAN ÇILDIRDI!',
      color: Color(0xFF00E5FF),
      scaleMultiplier: 1.60,
      scoreMultiplier: 2.85,
      shakeIntensity: 14.0,
    ),
    ComboAnnouncementTier(
      minCombo: 10,
      maxCombo: null,
      title: 'MAKARA KOPTU! ULTRA KOMBO!',
      color: Color(0xFFFF1744),
      scaleMultiplier: 1.80,
      scoreMultiplier: 3.50,
      shakeIntensity: 18.0,
    ),
  ];

  final int comboWindowMs;
  final AudioManager _audioManager;
  final HapticService _hapticService;

  int _comboCount = 0;
  int _maxCombo = 0;
  int? _lastHitTimestampMs;
  double _activeShakeIntensity = 0.0;
  int _shakeTriggerVersion = 0;

  int get comboCount => _comboCount;
  int get currentCombo => _comboCount;
  int get maxCombo => _maxCombo;
  int? get lastHitTimestampMs => _lastHitTimestampMs;
  bool get isComboActive => _comboCount >= 2;
  double get activeShakeIntensity => _activeShakeIntensity;
  int get shakeTriggerVersion => _shakeTriggerVersion;

  /// Aktif kombo basamağı (`combo >= 2` ise ilgili `ComboAnnouncementTier`, aksi halde `null`).
  ComboAnnouncementTier? get activeTier => tierForCombo(_comboCount);

  /// Aktif kombo anons başlığı (`combo < 2` ise `null`).
  String? get currentTitle => titleForCombo(_comboCount);

  /// Aktif kombo anons rengi.
  Color get currentColor => colorForCombo(_comboCount);

  /// Aktif kombo görsel ölçek çarpanı (`1.0` .. `1.80`).
  double get currentScale => scaleForCombo(_comboCount);

  /// Aktif kombo puan çarpanı (`1.0` .. `3.5x`).
  double get comboMultiplier => multiplierForCombo(_comboCount);

  /// Verilen `combo` sayısına karşılık gelen `ComboAnnouncementTier` nesnesini döndürür.
  static ComboAnnouncementTier? tierForCombo(int combo) {
    if (combo < 2) return null;
    for (final tier in tiers) {
      if (tier.matches(combo)) return tier;
    }
    return tiers.last;
  }

  /// Verilen `combo` sayısına karşılık gelen Türkçe viral anons başlığını döndürür.
  static String? titleForCombo(int combo) => tierForCombo(combo)?.title;

  /// Verilen `combo` sayısına karşılık gelen vurgu rengini döndürür.
  static Color colorForCombo(int combo) =>
      tierForCombo(combo)?.color ?? const Color(0xFFFFD54F);

  /// Verilen `combo` sayısına karşılık gelen UI ölçek çarpanını döndürür.
  static double scaleForCombo(int combo) =>
      tierForCombo(combo)?.scaleMultiplier ?? 1.0;

  /// Verilen `combo` sayısına göre `1.0` ile `3.5x` arasında kombo puan çarpanı hesaplar.
  static double multiplierForCombo(int combo) {
    if (combo <= 1) return minComboMultiplier;
    if (combo >= 10) return maxComboMultiplier;
    final raw = 1.0 + (combo - 1) * (2.5 / 9.0);
    return double.parse(
      raw.clamp(minComboMultiplier, maxComboMultiplier).toStringAsFixed(2),
    );
  }

  /// Verilen `combo` için önerilen kamera sarsıntı şiddetini döndürür.
  static double shakeIntensityForCombo(int combo) =>
      tierForCombo(combo)?.shakeIntensity ?? 0.0;

  /// Sönümlü harmonik kamera sarsıntısı (damped harmonic screen shake) vektörü:
  /// `progress` `0.0` ile `1.0` arasında ilerlerken üstel sönümlü (`e^(-4.8 * t)`)
  /// sinüs/kosinüs salınımı üretir. Başlangıç (`<= 0`) ve bitiş (`>= 1`) anlarında
  /// tam `Offset.zero` döner.
  Offset computeShakeOffset(
    double progress, {
    double intensity = 8.0,
  }) {
    return computeDampedShakeOffset(progress, intensity: intensity);
  }

  /// Statik yardımcı: Sönümlü harmonik kamera sarsıntısı vektörü.
  static Offset computeDampedShakeOffset(
    double progress, {
    double intensity = 8.0,
  }) {
    if (intensity <= 0.0 || progress <= 0.0 || progress >= 1.0) {
      return Offset.zero;
    }
    final t = progress.clamp(0.0, 1.0);
    // Üstel sönüm zarfı + sınırda sıfırlama çarpanı (1 - t)
    final envelope = math.exp(-4.8 * t) * (1.0 - t);
    // İki dik eksende farklı açısal frekanslarla doğal 2B kamera sarsıntısı
    const omegaX = 8.0 * math.pi; // 4 tam salınım
    const omegaY = 6.0 * math.pi; // 3 tam salınım
    final dx = intensity * envelope * math.sin(omegaX * t);
    final dy = intensity * 0.78 * envelope * math.cos(omegaY * t);
    return Offset(dx, dy);
  }

  /// Zaman aşımını kontrol eder; `comboWindowMs` (2800ms) aşılmışsa komboyu sıfırlar.
  bool checkTimeout({int? nowMs}) {
    if (_comboCount == 0 || _lastHitTimestampMs == null) return false;
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (currentMs - _lastHitTimestampMs! > comboWindowMs) {
      reset();
      return true;
    }
    return false;
  }

  /// Yeni bir böcek birleşimi veya vuruş kaydeder.
  /// `comboWindowMs` (2800ms) içinde gerçekleşirse komboyu artırır, aksi halde `1` yapar.
  int registerMerge({
    int tier = 1,
    int? nowMs,
    bool triggerFeedback = true,
  }) {
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    if (_lastHitTimestampMs != null &&
        currentMs - _lastHitTimestampMs! <= comboWindowMs) {
      _comboCount += 1;
    } else {
      _comboCount = 1;
    }
    _lastHitTimestampMs = currentMs;
    if (_comboCount > _maxCombo) {
      _maxCombo = _comboCount;
    }

    if (_comboCount >= 2) {
      _activeShakeIntensity = shakeIntensityForCombo(_comboCount);
      _shakeTriggerVersion++;
    } else {
      _activeShakeIntensity = 0.0;
    }

    if (triggerFeedback) {
      _triggerAudioAndHaptics(tier: tier, combo: _comboCount);
    }

    notifyListeners();
    return _comboCount;
  }

  void _triggerAudioAndHaptics({required int tier, required int combo}) {
    unawaited(
      _audioManager.playMerge(
        tierNumber: tier.clamp(1, 13),
        comboCount: combo,
      ),
    );
    if (combo >= 2) {
      unawaited(_hapticService.onCombo(combo));
    }
  }

  /// Kombo sayacını ve aktif sarsıntıyı sıfırlar.
  void reset() {
    if (_comboCount == 0 &&
        _lastHitTimestampMs == null &&
        _activeShakeIntensity == 0.0) {
      return;
    }
    _comboCount = 0;
    _lastHitTimestampMs = null;
    _activeShakeIntensity = 0.0;
    notifyListeners();
  }
}

/// `ComboJuiceService` ile senkronize çalışan, sönümlü harmonik kamera sarsıntısını
/// (`computeShakeOffset`) 60/120Hz `RepaintBoundary` izolasyonuyla uygulayan sarmalayıcı widget.
class ScreenShakeWrapper extends StatefulWidget {
  const ScreenShakeWrapper({
    super.key,
    required this.child,
    this.service,
    this.duration = const Duration(milliseconds: 380),
    this.defaultIntensity = 8.0,
    this.enabled = true,
  });

  final Widget child;
  final ComboJuiceService? service;
  final Duration duration;
  final double defaultIntensity;
  final bool enabled;

  @override
  State<ScreenShakeWrapper> createState() => ScreenShakeWrapperState();
}

class ScreenShakeWrapperState extends State<ScreenShakeWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ComboJuiceService get _service => widget.service ?? ComboJuiceService.instance;
  int _lastHandledVersion = 0;
  double _currentIntensity = 8.0;

  @override
  void initState() {
    super.initState();
    _currentIntensity = widget.defaultIntensity;
    _lastHandledVersion = _service.shakeTriggerVersion;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _service.addListener(_onServiceChanged);
  }

  @override
  void didUpdateWidget(covariant ScreenShakeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldService = oldWidget.service ?? ComboJuiceService.instance;
    final newService = widget.service ?? ComboJuiceService.instance;
    if (oldService != newService) {
      oldService.removeListener(_onServiceChanged);
      _lastHandledVersion = newService.shakeTriggerVersion;
      newService.addListener(_onServiceChanged);
    }
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
  }

  void _onServiceChanged() {
    if (!widget.enabled) return;
    if (_service.shakeTriggerVersion != _lastHandledVersion) {
      _lastHandledVersion = _service.shakeTriggerVersion;
      final intensity = _service.activeShakeIntensity > 0
          ? _service.activeShakeIntensity
          : widget.defaultIntensity;
      shake(intensity: intensity);
    }
  }

  /// Programatik olarak sarsıntıyı başlatır.
  void shake({double? intensity}) {
    if (!widget.enabled) return;
    _currentIntensity = intensity ?? widget.defaultIntensity;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    } else {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final offset = (_controller.isAnimating && progress > 0 && progress < 1)
              ? _service.computeShakeOffset(
                  progress,
                  intensity: _currentIntensity,
                )
              : Offset.zero;
          return Transform.translate(
            offset: offset,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
