import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_manager.dart';
import 'cloud_sync_service.dart';
import 'game_telemetry_service.dart';
import 'progress_manager.dart';

/// Erişilebilirlik Ayarları (`AccessibilityPreferences`).
///
/// Desteklenen kalıcı seçenekler:
/// - [reducedMotion]: Azaltılmış Hareket (sarsıntı, yoğun parçacık ve animasyonları azaltır)
/// - [highContrast]: Yüksek Kontrast (kenarlık ve metin kontrastını güçlendirir)
/// - [colorblindAssist]: Renk Körlüğü Sembol Desteği (böcek/balon/taş tiplerine ek sembol/etiket sağlar)
/// - [largeTouchTargets]: Büyük Dokunma Hedefi (buton ve etkileşim alanlarını büyütür)
@immutable
class AccessibilityPreferences {
  const AccessibilityPreferences({
    this.reducedMotion = false,
    this.highContrast = false,
    this.colorblindAssist = false,
    this.largeTouchTargets = false,
  });

  static const String keyReducedMotion = 'lululu_a11y_reduced_motion';
  static const String keyHighContrast = 'lululu_a11y_high_contrast';
  static const String keyColorblindAssist = 'lululu_a11y_colorblind_assist';
  static const String keyLargeTouchTargets = 'lululu_a11y_large_touch_targets';
  static const String keyBundleJson = 'lululu_a11y_preferences_v1';

  final bool reducedMotion;
  final bool highContrast;
  final bool colorblindAssist;
  final bool largeTouchTargets;

  /// Dokunma hedefleri için çarpan (`largeTouchTargets` aktifken `1.25`, değilse `1.0`).
  double get touchTargetScale => largeTouchTargets ? 1.25 : 1.0;

  /// Minimum dokunma alanı boyutu (`largeTouchTargets` aktifken `56.0`, değilse `48.0`).
  double get minTouchTargetSize => largeTouchTargets ? 56.0 : 48.0;

  /// Animasyon süresi ölçeği (`reducedMotion` aktifken `0.25`, değilse `1.0`).
  double get animationDurationScale => reducedMotion ? 0.25 : 1.0;

  /// Herhangi bir erişilebilirlik modunun açık olup olmadığı.
  bool get hasAnyEnabled =>
      reducedMotion || highContrast || colorblindAssist || largeTouchTargets;

  AccessibilityPreferences copyWith({
    bool? reducedMotion,
    bool? highContrast,
    bool? colorblindAssist,
    bool? largeTouchTargets,
  }) {
    return AccessibilityPreferences(
      reducedMotion: reducedMotion ?? this.reducedMotion,
      highContrast: highContrast ?? this.highContrast,
      colorblindAssist: colorblindAssist ?? this.colorblindAssist,
      largeTouchTargets: largeTouchTargets ?? this.largeTouchTargets,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'reducedMotion': reducedMotion,
        'highContrast': highContrast,
        'colorblindAssist': colorblindAssist,
        'largeTouchTargets': largeTouchTargets,
      };

  factory AccessibilityPreferences.fromJson(Map<String, Object?> json) {
    return AccessibilityPreferences(
      reducedMotion: json['reducedMotion'] == true,
      highContrast: json['highContrast'] == true,
      colorblindAssist: json['colorblindAssist'] == true,
      largeTouchTargets: json['largeTouchTargets'] == true,
    );
  }

  /// `SharedPreferences` üzerinden erişilebilirlik tercihlerini yükler.
  static Future<AccessibilityPreferences> load([
    SharedPreferences? providedPrefs,
  ]) async {
    final prefs = providedPrefs ?? await SharedPreferences.getInstance();
    final hasIndividualKeys = prefs.containsKey(keyReducedMotion) ||
        prefs.containsKey(keyHighContrast) ||
        prefs.containsKey(keyColorblindAssist) ||
        prefs.containsKey(keyLargeTouchTargets);

    if (hasIndividualKeys) {
      return AccessibilityPreferences(
        reducedMotion: prefs.getBool(keyReducedMotion) ?? false,
        highContrast: prefs.getBool(keyHighContrast) ?? false,
        colorblindAssist: prefs.getBool(keyColorblindAssist) ?? false,
        largeTouchTargets: prefs.getBool(keyLargeTouchTargets) ?? false,
      );
    }

    final rawJson = prefs.getString(keyBundleJson);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is Map<String, Object?>) {
          return AccessibilityPreferences.fromJson(decoded);
        }
        if (decoded is Map) {
          return AccessibilityPreferences.fromJson(
            decoded.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      } catch (_) {}
    }

    return const AccessibilityPreferences();
  }

  /// Erişilebilirlik tercihlerini `SharedPreferences` içine kalıcı olarak yazar.
  Future<void> save([SharedPreferences? providedPrefs]) async {
    final prefs = providedPrefs ?? await SharedPreferences.getInstance();
    await prefs.setBool(keyReducedMotion, reducedMotion);
    await prefs.setBool(keyHighContrast, highContrast);
    await prefs.setBool(keyColorblindAssist, colorblindAssist);
    await prefs.setBool(keyLargeTouchTargets, largeTouchTargets);
    await prefs.setString(keyBundleJson, jsonEncode(toJson()));
  }

  /// Renk körlüğü desteği için böcek/taş tier'ına (`1..13`) karşılık gelen sembol etiketi.
  String symbolForTier(int tier) {
    const symbols = <String>[
      '●', // 1
      '▲', // 2
      '■', // 3
      '◆', // 4
      '★', // 5
      '✦', // 6
      '⬢', // 7
      '♛', // 8
      '❖', // 9
      '✪', // 10
      '⚡', // 11
      '☀️', // 12
      '👑', // 13
    ];
    final idx = (tier - 1).clamp(0, symbols.length - 1);
    return symbols[idx];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccessibilityPreferences &&
          reducedMotion == other.reducedMotion &&
          highContrast == other.highContrast &&
          colorblindAssist == other.colorblindAssist &&
          largeTouchTargets == other.largeTouchTargets;

  @override
  int get hashCode => Object.hash(
        reducedMotion,
        highContrast,
        colorblindAssist,
        largeTouchTargets,
      );

  @override
  String toString() =>
      'AccessibilityPreferences(reducedMotion: $reducedMotion, '
      'highContrast: $highContrast, colorblindAssist: $colorblindAssist, '
      'largeTouchTargets: $largeTouchTargets)';
}

/// Uygulama Yaşam Döngüsü, Çağrı Kesintisi & Erişilebilirlik Koruması.
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
/// 4. `AccessibilityPreferences` (`reducedMotion`, `highContrast`,
///    `colorblindAssist`, `largeTouchTargets`) tercihlerini `SharedPreferences`
///    ile kalıcı olarak yönetir.
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

  AccessibilityPreferences _accessibility = const AccessibilityPreferences();

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

  /// Güncel erişilebilirlik tercihleri.
  AccessibilityPreferences get accessibility => _accessibility;

  /// Kısa erişilebilirlik getter'ları.
  bool get reducedMotion => _accessibility.reducedMotion;
  bool get highContrast => _accessibility.highContrast;
  bool get colorblindAssist => _accessibility.colorblindAssist;
  bool get largeTouchTargets => _accessibility.largeTouchTargets;

  /// `WidgetsBinding` gözlemcisini bağlar ve erişilebilirlik ayarlarını yükler.
  Future<void> initialize() async {
    attachObserver();
    await loadAccessibilityPreferences();
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
    _currentState = state;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(onAppPaused(reason: 'lifecycle_${state.name}'));
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

  // ---------------------------------------------------------------------------
  // ERİŞİLEBİLİRLİK TERCİHLERİ YÖNETİMİ
  // ---------------------------------------------------------------------------

  /// `SharedPreferences` içinden erişilebilirlik tercihlerini yükler.
  Future<AccessibilityPreferences> loadAccessibilityPreferences([
    SharedPreferences? providedPrefs,
  ]) async {
    _accessibility = await AccessibilityPreferences.load(providedPrefs);
    notifyListeners();
    return _accessibility;
  }

  /// Tüm erişilebilirlik tercihlerini tek seferde günceller ve kalıcı kaydeder.
  Future<void> updateAccessibilityPreferences(
    AccessibilityPreferences next, [
    SharedPreferences? providedPrefs,
  ]) async {
    _accessibility = next;
    await _accessibility.save(providedPrefs);
    GameTelemetryService.instance.recordBreadcrumb(
      'accessibility',
      'preferences_updated',
      meta: _accessibility.toJson(),
    );
    notifyListeners();
  }

  /// Azaltılmış Hareket (`reducedMotion`) ayarını günceller.
  Future<void> setReducedMotion(bool enabled) async {
    await updateAccessibilityPreferences(
      _accessibility.copyWith(reducedMotion: enabled),
    );
  }

  /// Yüksek Kontrast (`highContrast`) ayarını günceller.
  Future<void> setHighContrast(bool enabled) async {
    await updateAccessibilityPreferences(
      _accessibility.copyWith(highContrast: enabled),
    );
  }

  /// Renk Körlüğü Sembol Desteği (`colorblindAssist`) ayarını günceller.
  Future<void> setColorblindAssist(bool enabled) async {
    await updateAccessibilityPreferences(
      _accessibility.copyWith(colorblindAssist: enabled),
    );
  }

  /// Büyük Dokunma Hedefi (`largeTouchTargets`) ayarını günceller.
  Future<void> setLargeTouchTargets(bool enabled) async {
    await updateAccessibilityPreferences(
      _accessibility.copyWith(largeTouchTargets: enabled),
    );
  }

  /// Testler için yaşam döngüsü ve erişilebilirlik durumunu sıfırlar.
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
    _accessibility = const AccessibilityPreferences();
    notifyListeners();
  }
}
