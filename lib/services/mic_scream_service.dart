import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

/// Tekil desibel ve normalize ses gücü okuması.
class ScreamReading {
  const ScreamReading({
    required this.decibel,
    required this.maxDecibel,
    required this.normalizedPower,
    required this.triggeredScream,
    required this.isSimulated,
    required this.timestamp,
  });

  /// Ortalama desibel değeri (örn. 35..95 dB).
  final double decibel;

  /// Tepe desibel değeri.
  final double maxDecibel;

  /// `0.0`..`1.0` aralığında normalize edilmiş ses gücü.
  final double normalizedPower;

  /// Bu okumanın zıplama / çığlık eşiğini tetikleyip tetiklemediği.
  final bool triggeredScream;

  /// Gerçek mikrofon yerine dokunmatik / simüle dalga kaynağından mı geldiği.
  final bool isSimulated;

  final DateTime timestamp;
}

/// Çığlık Böcek Desibel & Ses Algılama Motoru.
///
/// - Gerçek cihazda `Permission.microphone` ve `NoiseMeter` ile dB + `0.0..1.0`
///   normalize ses gücü üretir.
/// - İzin verilmediğinde, masaüstünde, simülatörde veya widget testlerinde
///   otomatik olarak dokunmatik / simüle desibel dalgası fallback moduna geçer.
/// - Timer ve stream aboneliklerini %100 güvenli biçimde temizler (zero timer leak).
class MicScreamService extends ChangeNotifier {
  MicScreamService._();
  static MicScreamService _instance = MicScreamService._();
  static MicScreamService get instance =>
      _instance._disposed ? (_instance = MicScreamService._()) : _instance;
  factory MicScreamService() => instance;

  static const double minDecibel = 32.0;
  static const double maxDecibel = 96.0;
  static const double defaultThresholdDb = 64.0;
  static const double rearmHysteresisDb = 8.0;
  static const Duration triggerCooldown = Duration(milliseconds: 220);

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  Timer? _fallbackWaveTimer;
  final StreamController<ScreamReading> _readingController =
      StreamController<ScreamReading>.broadcast();

  /// 12C2: duraklatma/devam (`pauseListening`/`resumeListening`)
  /// için saklanan tetik geri çağrısı ve yedek-dalga bayrağı.
  void Function(ScreamReading reading)? _onScreamTriggered;
  bool _periodicFallbackWave = false;
  bool _paused = false;

  final ValueNotifier<double> decibelNotifier =
      ValueNotifier<double>(minDecibel);
  final ValueNotifier<double> powerNotifier = ValueNotifier<double>(0.0);

  double _currentDb = minDecibel;
  double _peakDb = minDecibel;
  double _normalizedPower = 0.0;
  double _thresholdDb = defaultThresholdDb;
  double _simulatedPhase = 0.0;

  bool _isListening = false;
  bool _isFallbackMode = false;
  bool _permissionGranted = false;
  bool _permissionPermanentlyDenied = false;
  bool _voiceArmed = true;
  bool _disposed = false;
  DateTime _lastTriggerAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _statusMessage = 'Dokun veya mikrofonu açıp bağırarak zıpla.';

  /// Son ölçülen desibel (`minDecibel`..`maxDecibel`).
  double get currentDb => _currentDb;

  /// Son ölçülen tepe desibel.
  double get peakDb => _peakDb;

  /// `0.0`..`1.0` arası normalize ses gücü.
  double get normalizedPower => _normalizedPower;

  /// Çığlık tetikleme eşiği (varsayılan 64.0 dB).
  double get thresholdDb => _thresholdDb;
  set thresholdDb(double value) {
    _thresholdDb = value.clamp(42.0, 90.0);
    notifyListeners();
  }

  bool get isListening => _isListening;
  bool get isFallbackMode => _isFallbackMode;

  /// Dinleme duraklatıldı mı (`pauseListening` kondu, `resumeListening`
  /// henüz çağrılmadı)? Duraklatmada abonelik kapalıdır ama
  /// `_isListening` true kalır; devam, izni yeniden istemeden
  /// kaldığı yerden açılır.
  bool get isPaused => _paused;
  bool get permissionGranted => _permissionGranted;
  bool get permissionPermanentlyDenied => _permissionPermanentlyDenied;
  String get statusMessage => _statusMessage;

  Stream<ScreamReading> get readings => _readingController.stream;

  /// Ham dB değerini `0.0`..`1.0` aralığına normalize eder.
  static double normalizeDb(
    double db, {
    double floorDb = minDecibel,
    double ceilingDb = maxDecibel,
  }) {
    if (db.isNaN || db.isInfinite) return 0.0;
    final span = math.max(1.0, ceilingDb - floorDb);
    return ((db - floorDb) / span).clamp(0.0, 1.0);
  }

  /// Normalize gücü (`0.0`..`1.0`) eşdeğer dB değerine dönüştürür.
  static double dbFromPower(
    double power, {
    double floorDb = minDecibel,
    double ceilingDb = maxDecibel,
  }) {
    final p = power.clamp(0.0, 1.0);
    return floorDb + p * (ceilingDb - floorDb);
  }

  bool get _isTestOrDesktopEnvironment {
    try {
      if (Zone.current[#test.declarer] != null) return true;
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      if (bindingType.contains('TestWidgetsFlutterBinding') ||
          bindingType.contains('AutomatedTestWidgetsFlutterBinding') ||
          bindingType.contains('LiveTestWidgetsFlutterBinding')) {
        return true;
      }
    } catch (_) {
      return true;
    }
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  bool get _isAutomatedTest {
    try {
      if (Zone.current[#test.declarer] != null) return true;
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      return bindingType.contains('TestWidgetsFlutterBinding') ||
          bindingType.contains('AutomatedTestWidgetsFlutterBinding');
    } catch (_) {
      return true;
    }
  }

  /// Mikrofon dinlemesini açar/kapatır.
  Future<bool> toggleListening({
    void Function(ScreamReading reading)? onScreamTriggered,
  }) async {
    if (_isListening) {
      await stopListening();
      return false;
    }
    return startListening(onScreamTriggered: onScreamTriggered);
  }

  /// Gerçek mikrofonu başlatır; izin yoksa veya masaüstü/test ortamındaysa
  /// çökmeden simüle/dokunmatik fallback modunu devreye alır.
  Future<bool> startListening({
    void Function(ScreamReading reading)? onScreamTriggered,
    bool enablePeriodicFallbackWave = false,
  }) async {
    await stopListening();
    // 12C2: duraklatma/devam için saklanır (yeniden abonelikte
    // aynı geri çağrı + yedek-dalga ayarı kullanılır).
    _onScreamTriggered = onScreamTriggered;
    _periodicFallbackWave = enablePeriodicFallbackWave;

    if (_isTestOrDesktopEnvironment) {
      _activateFallback(
        reason: 'Simüle ses / dokunmatik çığlık modu aktif.',
        enablePeriodicWave: enablePeriodicFallbackWave && !_isAutomatedTest,
        onScreamTriggered: onScreamTriggered,
      );
      return true;
    }

    PermissionStatus status;
    try {
      status = await Permission.microphone.request();
    } catch (_) {
      _activateFallback(
        reason: 'Mikrofon erişimi kullanılamıyor · dokunarak zıplayabilirsin.',
        enablePeriodicWave: enablePeriodicFallbackWave && !_isAutomatedTest,
        onScreamTriggered: onScreamTriggered,
      );
      return true;
    }

    _permissionGranted = status.isGranted;
    _permissionPermanentlyDenied = status.isPermanentlyDenied;

    if (!status.isGranted) {
      _activateFallback(
        reason: status.isPermanentlyDenied
            ? 'Ses kontrolü için Ayarlar’dan mikrofon izni ver · dokunmatik aktif.'
            : 'Ses izni verilmedi · dokunarak zıplayabilirsin.',
        enablePeriodicWave: enablePeriodicFallbackWave && !_isAutomatedTest,
        onScreamTriggered: onScreamTriggered,
      );
      return false;
    }

    if (!_startNoiseSubscription(onScreamTriggered)) {
      _activateFallback(
        reason: 'Mikrofon başlatılamadı · dokunmatik çığlık aktif.',
        enablePeriodicWave: enablePeriodicFallbackWave && !_isAutomatedTest,
        onScreamTriggered: onScreamTriggered,
      );
      return false;
    }
    _isListening = true;
    _isFallbackMode = false;
    _voiceArmed = true;
    _statusMessage = 'Mikrofon aktif · bağırarak zıpla!';
    notifyListeners();
    return true;
  }

  /// `NoiseMeter` akışını açar; açılmazsa `false` döner (çağrıcı
  /// yedek moda düşer). Abonelik hem `startListening` hem de
  /// `resumeListening` tarafından kullanılır.
  bool _startNoiseSubscription(
    void Function(ScreamReading reading)? onScreamTriggered,
  ) {
    try {
      _noiseMeter ??= NoiseMeter();
      _noiseSubscription = _noiseMeter!.noise.listen(
        (NoiseReading reading) {
          _handleRawDecibel(
            meanDb: reading.meanDecibel,
            maxDb: reading.maxDecibel,
            isSimulated: false,
            onScreamTriggered: onScreamTriggered,
          );
        },
        onError: (Object _) {
          _activateFallback(
            reason: 'Mikrofon akışı kesildi · dokunmatik çığlık aktif.',
            enablePeriodicWave: false,
            onScreamTriggered: onScreamTriggered,
          );
        },
        cancelOnError: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Dinlemeyi askıya alır (arka plan / duraklatma / diyalog):
  /// abonelik + yedek-dalga zamanlayıcısı kapanır, `_isListening`
  /// true kalır; izin yeniden istenmez.
  void pauseListening() {
    if (!_isListening || _paused) return;
    _paused = true;
    _fallbackWaveTimer?.cancel();
    _fallbackWaveTimer = null;
    unawaited(_noiseSubscription?.cancel() ?? Future<void>.value());
    _noiseSubscription = null;
    notifyListeners();
  }

  /// Askıdaki dinlemeyi kaldığı yerden devam ettirir: gerçek
  /// mikrofonda yeniden abone olur, yedek modda yedek-dalga
  /// zamanlayıcısını yeniden kurar. Yeniden abonelik olmazsa
  /// yedek moda düşer.
  Future<void> resumeListening() async {
    if (!_isListening || !_paused) return;
    _paused = false;
    if (_isFallbackMode) {
      if (_periodicFallbackWave && !_isAutomatedTest) {
        _fallbackWaveTimer = Timer.periodic(
          const Duration(milliseconds: 80),
          (_) {
            stepSimulation(0.08, onScreamTriggered: _onScreamTriggered);
          },
        );
      }
      notifyListeners();
      return;
    }
    if (!_startNoiseSubscription(_onScreamTriggered)) {
      _activateFallback(
        reason: 'Mikrofon akışı kesildi · dokunmatik çığlık aktif.',
        enablePeriodicWave: false,
        onScreamTriggered: _onScreamTriggered,
      );
    } else {
      notifyListeners();
    }
  }

  void _activateFallback({
    required String reason,
    required bool enablePeriodicWave,
    void Function(ScreamReading reading)? onScreamTriggered,
  }) {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _fallbackWaveTimer?.cancel();
    _fallbackWaveTimer = null;

    _isListening = true;
    _isFallbackMode = true;
    _voiceArmed = true;
    _statusMessage = reason;

    if (enablePeriodicWave && !_isAutomatedTest) {
      _fallbackWaveTimer = Timer.periodic(
        const Duration(milliseconds: 80),
        (_) {
          stepSimulation(0.08, onScreamTriggered: onScreamTriggered);
        },
      );
    }

    notifyListeners();
  }

  /// Dokunma veya buton ile çığlık/desibel darbesi üretir (her ortamda %100 güvenli).
  ScreamReading triggerTouchScream({
    double intensity = 0.85,
    void Function(ScreamReading reading)? onScreamTriggered,
  }) {
    final clampedIntensity = intensity.clamp(0.25, 1.0);
    final simulatedDb = math.max(
      _thresholdDb + 4.0,
      dbFromPower(clampedIntensity),
    );
    _voiceArmed = true;
    return _handleRawDecibel(
      meanDb: simulatedDb,
      maxDb: math.min(maxDecibel, simulatedDb + 4.5),
      isSimulated: true,
      forceTrigger: true,
      onScreamTriggered: onScreamTriggered,
    );
  }

  /// Oyun döngüsünden (`Ticker` / `_onTick`) çağrılabilen timer'sız simüle ses dalgası adımı.
  ScreamReading stepSimulation(
    double dtSeconds, {
    bool screamPulse = false,
    void Function(ScreamReading reading)? onScreamTriggered,
  }) {
    final dt = dtSeconds.clamp(0.0, 0.1);
    _simulatedPhase = (_simulatedPhase + dt * 3.2) % (math.pi * 2);

    final double targetDb;
    if (screamPulse) {
      targetDb = _thresholdDb + 12.0;
    } else {
      final wave = (math.sin(_simulatedPhase) * 0.5 + 0.5);
      targetDb = minDecibel + wave * 14.0;
    }

    return _handleRawDecibel(
      meanDb: targetDb,
      maxDb: targetDb + 2.5,
      isSimulated: true,
      forceTrigger: screamPulse,
      onScreamTriggered: onScreamTriggered,
    );
  }

  ScreamReading _handleRawDecibel({
    required double meanDb,
    required double maxDb,
    required bool isSimulated,
    bool forceTrigger = false,
    void Function(ScreamReading reading)? onScreamTriggered,
  }) {
    final cleanMean = (meanDb.isNaN || meanDb.isInfinite)
        ? minDecibel
        : meanDb.clamp(minDecibel, maxDecibel);
    final cleanMax = (maxDb.isNaN || maxDb.isInfinite)
        ? cleanMean
        : maxDb.clamp(cleanMean, maxDecibel);

    _currentDb = cleanMean;
    _peakDb = math.max(_peakDb * 0.92, cleanMax);
    _normalizedPower = normalizeDb(cleanMean);

    decibelNotifier.value = _currentDb;
    powerNotifier.value = _normalizedPower;

    if (cleanMean < _thresholdDb - rearmHysteresisDb) {
      _voiceArmed = true;
    }

    final now = DateTime.now();
    var triggered = false;
    final cooldownElapsed = now.difference(_lastTriggerAt) >= triggerCooldown;

    if ((forceTrigger || (cleanMean >= _thresholdDb && _voiceArmed)) &&
        cooldownElapsed) {
      _lastTriggerAt = now;
      _voiceArmed = false;
      triggered = true;
    }

    final reading = ScreamReading(
      decibel: _currentDb,
      maxDecibel: _peakDb,
      normalizedPower: _normalizedPower,
      triggeredScream: triggered,
      isSimulated: isSimulated,
      timestamp: now,
    );

    if (!_readingController.isClosed) {
      _readingController.add(reading);
    }
    if (triggered && onScreamTriggered != null) {
      onScreamTriggered(reading);
    }
    notifyListeners();
    return reading;
  }

  /// Tüm mikrofon aboneliklerini ve simülasyon zamanlayıcılarını sızıntısız durdurur.
  Future<void> stopListening() async {
    _fallbackWaveTimer?.cancel();
    _fallbackWaveTimer = null;
    _paused = false;
    _onScreamTriggered = null;
    _periodicFallbackWave = false;

    final sub = _noiseSubscription;
    _noiseSubscription = null;
    if (sub != null) {
      try {
        await sub.cancel();
      } catch (_) {}
    }

    _isListening = false;
    _isFallbackMode = false;
    _currentDb = minDecibel;
    _normalizedPower = 0.0;
    decibelNotifier.value = minDecibel;
    powerNotifier.value = 0.0;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _fallbackWaveTimer?.cancel();
    _fallbackWaveTimer = null;
    unawaited(_noiseSubscription?.cancel() ?? Future<void>.value());
    _noiseSubscription = null;
    super.dispose();
  }
}
