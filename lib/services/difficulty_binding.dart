import 'dart:async';

import 'package:flutter/foundation.dart';

import 'adaptive_difficulty_service.dart';

/// Ölü [AdaptiveDifficultyService] motorunu oyun akışına bağlayan ince
/// katman (12C1).
///
/// Sorumlulukları:
/// * [ensureLoaded]: kalıcı DDA geçmişini açılışta bir kez yükler
///   (`SharedPreferences` anahtarı `lululu_adaptive_difficulty_v1` —
///   anahtar servisin kendi sabitidir, başka servisle çakışmaz).
/// * [cachedProfileForMode]: mod başlangıcında senkron okunabilen profil
///   (yükleme bitmediyse tarafsız varsayılanlar — hız 1.0).
/// * [recordRun]: her mod bitişinde performans örneği kaydeder ve
///   profili kalıcı yazar.
///
/// Skor çarpanı ([AdaptiveDifficultyProfile.skillScoreBonusMultiplier])
/// bilinçli olarak BURADA skora uygulanmaz: çarpanlı skor AntiCheat
/// tavanlarıyla çakışır (meşru skor reddedilir). Profilin hıza ve
/// doğuş dağılımına etkisi mod ekranlarındaki kullanım noktalarındadır.
class DifficultyBinding {
  DifficultyBinding._();

  static final DifficultyBinding instance = DifficultyBinding._();

  final AdaptiveDifficultyService _service = AdaptiveDifficultyService.instance;

  bool _loadStarted = false;
  Future<void>? _loadFuture;

  /// Kalıcı DDA geçmişini yükler (tek-uçuş korumalı). Hata boot'u
  /// düşürmez: varsayılan profillerle devam edilir.
  Future<void> ensureLoaded() async {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    if (_loadStarted) return;
    _loadStarted = true;
    final future = _service.loadFromPreferences().catchError((Object e) {
      debugPrint('[lululu] DifficultyBinding: DDA geçmişi yüklenemedi: $e');
    });
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  /// Mod başlangıcında senkron profil okuma. Yükleme henüz bitmediyse
  /// tarafsız profil döner (hız çarpanı 1.0, merhamet kapalı).
  AdaptiveDifficultyProfile cachedProfileForMode(String mode) {
    return _service.getProfileForMode(mode);
  }

  /// Mod başlangıcında asenkron profil okuma (yüklemeyi bekler).
  Future<AdaptiveDifficultyProfile> profileForMode(String mode) async {
    await ensureLoaded();
    return _service.getProfileForMode(mode);
  }

  /// Bir mod bitişini kaydeder ve profili kalıcı yazar. Hata fırlatmaz:
  /// kayıt başarısızlığı tur akışını bozamaz.
  Future<void> recordRun({
    required String mode,
    required int score,
    required bool won,
    Duration? elapsed,
    double? reflexMs,
  }) async {
    try {
      await ensureLoaded();
      _service.recordMatchResult(
        mode: mode,
        score: score,
        won: won,
        reflexMs: reflexMs,
        durationSeconds: elapsed?.inSeconds,
      );
      await _service.saveToPreferences();
    } catch (e) {
      debugPrint('[lululu] DifficultyBinding: tur kaydı yazılamadı: $e');
    }
  }

  /// Test / oturum sıfırlama için bellek-içi yükleme bayrağını sıfırlar.
  @visibleForTesting
  void resetForTesting() {
    _loadStarted = false;
    _loadFuture = null;
  }
}
