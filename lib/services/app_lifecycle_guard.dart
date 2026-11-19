import 'dart:async';

import 'package:flutter/widgets.dart';

import 'audio_manager.dart';
import 'cloud_sync_service.dart';
import 'game_telemetry_service.dart';
import 'progress_manager.dart';

// Not (2026-11-19): Dört tercihli ayar grubu kaldırıldı; bu dosya
// yalnız yaşam döngüsü bekçisidir.

/// Uygulama Yaşam Döngüsü ve Çağrı Kesintisi Koruması.
///
/// Sorumluluklar:
/// 1. `WidgetsBindingObserver` üzerinden `AppLifecycleState` değişimlerini
///    (`paused`, `inactive`, `hidden`, `detached`, `resumed`) izler.
/// 2. Oyun arka plana atıldığında veya telefon çağrısı kesintisi geldiğinde:
///    - `AudioManager` seslerini güvenli şekilde duraklatır (`onAppPaused`),
///    - Aktif oyun moduna otomatik duraklatma (`shouldAutoPauseGame = true`)
///      sinyali gönderir,
///    - `CloudSyncService` ve `ProgressManager` durumunu kaybetmemek için
///      senkronize eder.
/// 3. Uygulama tekrar öne geldiğinde (`AppLifecycleState.resumed`):
///    - Ses durumunu önceki kullanıcı tercihlerine göre geri yükler (`onAppResumed`),
///    - Arka planda geçen oturum süresini ve saat bütünlüğünü doğrular.
class AppLifecycleGuard extends ChangeNotifier with WidgetsBindingObserver {
  AppLifecycleGuard._internal();

  static final AppLifecycleGuard instance = AppLifecycleGuard._internal();
  factory AppLifecycleGuard() => instance;

  /// Maksimum kesintisiz arka plan oturum süresi (varsayılan 6 saat).
  static const Duration maxValidBackgroundDuration = Duration(hours: 6);

  AppLifecycleState _currentState = AppLifecycleState.resumed;
  bool _isAttached = false;
  bool _shouldAutoPauseGame = false;
  bool _isAudioPausedByLifecycle = false;
  bool _wasAudioMutedBeforePause = false;
  bool _wasSfxEnabledBeforePause = true;

  DateTime _sessionStartedAt = DateTime.now();
  DateTime? _lastPausedAt;
  DateTime? _lastResumedAt;
  Duration _lastBackgroundDuration = Duration.zero;
  bool _isSessionValid = true;
  String _lastSessionValidationReason = 'ok';
  int _pauseCount = 0;
  int _resumeCount = 0;
  int _syncTriggerCount = 0;

  /// Güncel uygulama yaşam döngüsü durumu.
  AppLifecycleState get currentState => _currentState;

  /// `WidgetsBinding` gözlemcisinin bağlı olup olmadığı.
  ///
  /// Bağlama `main.dart` içinde `initialize()` ile yapılır; bu getter
  /// bağlamanın gerçekleştiğini okuyarak doğrulamayı sağlar.
  bool get isAttached => _isAttached;

  /// Aktif oyun modunun otomatik duraklatılması gerekip gerekmediği.
  bool get shouldAutoPauseGame => _shouldAutoPauseGame;
  set shouldAutoPauseGame(bool value) {
    if (_shouldAutoPauseGame != value) {
      _shouldAutoPauseGame = value;
      notifyListeners();
    }
  }

  /// Seslerin yaşam döngüsü koruması tarafından geçici olarak duraklatılıp duraklatılmadığı.
  bool get isAudioPausedByLifecycle => _isAudioPausedByLifecycle;

  /// Uygulamanın şu an arka planda veya kesintide olup olmadığı.
  bool get isInBackground =>
      _currentState == AppLifecycleState.paused ||
      _currentState == AppLifecycleState.inactive ||
      _currentState == AppLifecycleState.hidden ||
      _currentState == AppLifecycleState.detached;

  /// Oturum başlangıç zamanı.
  DateTime get sessionStartedAt => _sessionStartedAt;

  /// Son arka plana geçiş zamanı.
  DateTime? get lastPausedAt => _lastPausedAt;

  /// Son öne geliş zamanı.
  DateTime? get lastResumedAt => _lastResumedAt;

  /// Son arka planda kalma süresi.
  Duration get lastBackgroundDuration => _lastBackgroundDuration;

  /// Toplam aktif oturum süresi.
  Duration get activeSessionDuration {
    final diff = DateTime.now().difference(_sessionStartedAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Oturum süresinin ve saat bütünlüğünün geçerli olup olmadığı.
  bool get isSessionValid => _isSessionValid;

  /// Son oturum doğrulama sonucu açıklaması.
  String get lastSessionValidationReason => _lastSessionValidationReason;

  /// Arka plana geçiş / duraklatma sayacı.
  int get pauseCount => _pauseCount;

  /// Öne geliş / devam etme sayacı.
  int get resumeCount => _resumeCount;

  /// Arka plana geçişte tetiklenen toplam senkronizasyon sayısı.
  int get syncTriggerCount => _syncTriggerCount;

  /// `WidgetsBinding` gözlemcisini bağlar.
  Future<void> initialize() async {
    attachObserver();
  }

  /// `WidgetsBinding.instance` üzerine gözlemci olarak kaydolur.
  void attachObserver() {
    if (_isAttached) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _isAttached = true;
    } catch (_) {}
  }

  /// `WidgetsBinding.instance` üzerindeki gözlemci kaydını kaldırır.
  void detachObserver() {
    if (!_isAttached) return;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _isAttached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Aynı durumun tekrar bildirimi gerçek geçiş değildir: yinelenen
    // çağrılar duraklatma sayacını, ses kesintisini ve senkronu
    // tekrar tetiklemesin diye önceki durumla karşılaştırılır.
    if (state == _currentState) return;
    _currentState = state;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(onAppPaused(reason: 'lifecycle_${state.name}'));
        break;
      case AppLifecycleState.inactive:
        // Geçici kesinti (bildirim gölgesi, çağrı arayüzü, odak kaybı):
        // oyun duraklatılmaz, ses kesilmez; yalnızca durum güncellenir.
        // Gerçek arka plan geçişinde ardından gelen paused/detached
        // duraklatmayı tetikler; telefon kesintisi ise
        // onPhoneCallInterrupted üzerinden ayrıca duraklatır.
        notifyListeners();
        break;
      case AppLifecycleState.resumed:
        unawaited(onAppResumed());
        break;
    }
  }

  /// Gelen telefon araması veya sistem ses kesintisinde çağrılır.
  Future<void> onPhoneCallInterrupted() async {
    _currentState = AppLifecycleState.inactive;
    await onAppPaused(reason: 'phone_call_interruption');
  }

  /// Uygulama arka plana atıldığında veya telefon çaldığında:
  /// 1. `AudioManager` seslerini güvenli şekilde duraklatır,
  /// 2. `shouldAutoPauseGame = true` sinyali gönderir,
  /// 3. `CloudSyncService` ve `ProgressManager` durumunu senkronize eder.
  Future<void> onAppPaused({
    String reason = 'app_paused',
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    _lastPausedAt = now;
    _shouldAutoPauseGame = true;
    _pauseCount++;

    // 1. AudioManager seslerini güvenli şekilde duraklat
    final audio = AudioManager.instance;
    if (!_isAudioPausedByLifecycle) {
      _wasAudioMutedBeforePause = audio.isMuted;
      _wasSfxEnabledBeforePause = audio.sfxEnabled;
      _isAudioPausedByLifecycle = true;
    }
    audio.isMuted = true;
    await audio.stopAll();

    // 2. CloudSyncService ve ProgressManager durumunu senkronize et
    await _synchronizeGameStateOnPause();

    // 3. Telemetri breadcrumb kaydı düş
    GameTelemetryService.instance.recordBreadcrumb(
      'lifecycle',
      'app_paused',
      meta: <String, Object?>{
        'reason': reason,
        'state': _currentState.name,
        'pauseCount': _pauseCount,
        'shouldAutoPauseGame': _shouldAutoPauseGame,
      },
      timestamp: now,
    );

    notifyListeners();
  }

  /// Uygulama tekrar öne geldiğinde (`AppLifecycleState.resumed`):
  /// 1. Ses durumunu geri yükler,
  /// 2. Oturum süresini ve saat bütünlüğünü doğrular.
  Future<void> onAppResumed({
    DateTime? timestamp,
    bool clearAutoPause = false,
  }) async {
    final now = timestamp ?? DateTime.now();
    _currentState = AppLifecycleState.resumed;
    _lastResumedAt = now;
    _resumeCount++;

    // 1. Oturum süresini ve arka plan süresini doğrula
    _validateSessionOnResume(now);
    // Duraklatma zaman damgası tüketildi: sonraki bir resumed (ör. geçici
    // inactive sonrası) bayat damgayla sahte 'session_expired' üretmesin.
    _lastPausedAt = null;

    // 2. Ses durumunu geri yükle
    final audio = AudioManager.instance;
    if (_isAudioPausedByLifecycle) {
      audio.isMuted = _wasAudioMutedBeforePause;
      if (_wasSfxEnabledBeforePause != audio.sfxEnabled) {
        audio.sfxEnabled = _wasSfxEnabledBeforePause;
      }
      _isAudioPausedByLifecycle = false;
    }

    if (clearAutoPause) {
      _shouldAutoPauseGame = false;
    }

    GameTelemetryService.instance.recordBreadcrumb(
      'lifecycle',
      'app_resumed',
      meta: <String, Object?>{
        'resumeCount': _resumeCount,
        'backgroundMs': _lastBackgroundDuration.inMilliseconds,
        'isSessionValid': _isSessionValid,
        'validationReason': _lastSessionValidationReason,
      },
      timestamp: now,
    );

    notifyListeners();
  }

  /// Aktif oyun ekranı duraklatma menüsünü gösterdiğinde veya oyuncu
  /// "Devam Et" dediğinde otomatik duraklatma bayrağını temizler.
  void acknowledgeAutoPause() {
    if (_shouldAutoPauseGame) {
      _shouldAutoPauseGame = false;
      notifyListeners();
    }
  }

  void _validateSessionOnResume(DateTime resumedAt) {
    final pausedAt = _lastPausedAt;
    if (pausedAt == null) {
      _lastBackgroundDuration = Duration.zero;
      _isSessionValid = true;
      _lastSessionValidationReason = 'ok';
      return;
    }

    final diff = resumedAt.difference(pausedAt);
    if (diff.isNegative) {
      // Cihaz saati geri alınmış (clock rollback / anti-cheat uyarısı)
      _lastBackgroundDuration = Duration.zero;
      _isSessionValid = false;
      _lastSessionValidationReason = 'clock_rollback_detected';
      return;
    }

    _lastBackgroundDuration = diff;
    if (diff > maxValidBackgroundDuration) {
      _isSessionValid = false;
      _lastSessionValidationReason = 'session_expired';
      _sessionStartedAt = resumedAt;
      return;
    }

    _isSessionValid = true;
    _lastSessionValidationReason = 'ok';
  }

  Future<void> _synchronizeGameStateOnPause() async {
    _syncTriggerCount++;
    try {
      await ProgressManager.instance.persistBoosters();
    } catch (_) {}
    try {
      await CloudSyncService.instance.enqueueProgressPush();
    } catch (_) {}
  }

  /// Testler için yaşam döngüsü durumunu sıfırlar.
  void resetForTesting() {
    _currentState = AppLifecycleState.resumed;
    _shouldAutoPauseGame = false;
    _isAudioPausedByLifecycle = false;
    _wasAudioMutedBeforePause = false;
    _wasSfxEnabledBeforePause = true;
    _sessionStartedAt = DateTime.now();
    _lastPausedAt = null;
    _lastResumedAt = null;
    _lastBackgroundDuration = Duration.zero;
    _isSessionValid = true;
    _lastSessionValidationReason = 'ok';
    _pauseCount = 0;
    _resumeCount = 0;
    _syncTriggerCount = 0;
    notifyListeners();
  }
}
