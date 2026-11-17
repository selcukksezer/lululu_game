import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'bug_video_service.dart';
import 'chat_service.dart';
import 'energy_service.dart';
import 'firebase_bootstrap.dart';
import 'leaderboard_service.dart';
import 'progress_manager.dart';

/// Bulut yazımının neden reddedildiğini tipli olarak taşır.
///
/// Çağrı noktaları (başka dosyalarda) `CloudSyncService.lastFailure` /
/// `flushPendingDetailed()` üzerinden okuyup kullanıcıya görünür hata
/// gösterebilir; `flushPending()` int sözleşmesi bozulmadan korunur.
enum CloudSyncFailureKind {
  /// Firestore kuralları yazımı reddetti (`permission-denied`).
  permissionDenied,

  /// Ağ/Firestore erişilemez durumda.
  unavailable,

  /// Payload istemci tarafında kural sınırlarına uymuyor; yazım denenmedi.
  invalidPayload,

  /// Sınıflandırılamayan hata.
  unknown,
}

/// Tipli senkron hatası: kullanıcıya gösterilecek Türkçe mesaj + hata türü.
class CloudSyncFailure {
  const CloudSyncFailure({
    required this.kind,
    required this.message,
    this.details,
  });

  final CloudSyncFailureKind kind;

  /// Kullanıcıya gösterilebilir Türkçe mesaj (ham hata metni içermez).
  final String message;

  /// Tanı amaçlı ham detay (log için; kullanıcı arayüzüne verilmez).
  final String? details;

  @override
  String toString() => 'CloudSyncFailure($kind): $message';
}

/// `flushPendingDetailed()` sonucu: başarıda yazılan paket sayısı, reddedilişte
/// tipli hata. Kuyruk, reddedilişte korunur (bir sonraki flush tekrar dener).
class CloudSyncFlushResult {
  const CloudSyncFlushResult._({
    required this.success,
    required this.flushedCount,
    this.failure,
  });

  const CloudSyncFlushResult.success(int flushedCount)
      : this._(success: true, flushedCount: flushedCount);

  const CloudSyncFlushResult.failure(CloudSyncFailure failure)
      : this._(success: false, flushedCount: 0, failure: failure);

  final bool success;
  final int flushedCount;
  final CloudSyncFailure? failure;
}

/// Online sync — Firestore when Firebase ready; else durable local queue
/// with HMAC-SHA256 integrity verification and anti-cheat bounds enforcement.
///
/// Sınırlar `firestore.rules` ile birebir tutulur: kural değişirse bu
/// dosyadaki sabitler de değişmelidir (bkz. aşağıdaki sabitlerin yorumları).
class CloudSyncService extends ChangeNotifier {
  CloudSyncService._();
  static final instance = CloudSyncService._();

  static const _queueKey = 'LululuCloudQueueV1';
  static const _signedQueueKey = 'LululuCloudSignedQueueV1';
  static const _integritySecret = 'lululu_cloud_integrity_v2_hmac_key_2026';

  /// Anti-cheat bounds — `firestore.rules` ile BİREBİR.
  ///
  /// * Skor: rules `score 0..500000` (hem `scores/.../modes` hem profil
  ///   `bestOverallScore`). [ProgressManager.modeScoreCeilings] tavanları
  ///   (tek kaynak; [LeaderboardService] delege eder) da bu sınırın
  ///   altında kalmak zorundadır.
  /// * Coin: rules `coins 0..10000000` mutlak tavan; İLK yazımda
  ///   `coins <= 50000`, her güncellemede artış `<= 50000` (ayrı sabitler).
  /// * Görünen ad: rules `displayName 1..32`.
  /// * Enerji: rules `energy 0..100` (EnergyService zaten 30'da kelepçeler).
  ///
  /// Skor tavanı TEK KAYNAK [ProgressManager.maxValidModeScore] (S1#35):
  /// bu sabit yalnızca takma addır, kendi `500000` kopyasını tutmaz.
  /// Mod bazlı tavanlar [modeScoreCeilings] / [ceilingForMode], mod bazlı
  /// doğrulama [isScoreValidForMode] üzerinden aynı kaynağa delege edilir.
  /// Bu dosyadaki rules doğrulayıcıları ile eski/uzak veri okuma yolları
  /// BİLİNÇLİ olarak mutlak sınırı kullanır (bkz. [isValidScore]): rules
  /// her mod için `0..500000` kabul eder ve tek-tavan döneminde
  /// kaydedilmiş eski skorlar mod tavanının üstünde olabilir.
  static const int maxValidModeScore = ProgressManager.maxValidModeScore;

  /// Mod bazlı skor tavanları — TEK KAYNAK
  /// [ProgressManager.modeScoreCeilings] (S1#35). Bu sınıf tabloyu
  /// delege eder, kendi kopyasını tutmaz ([LeaderboardService] ile aynı
  /// kalıp). Tavan değişmezleri tablonun başındaki belgede yazılıdır.
  static const Map<String, int> modeScoreCeilings =
      ProgressManager.modeScoreCeilings;
  static const int maxValidCoins = 10000000;

  /// İlk profil yazımında (create) rules `coins <= 50000` ister.
  static const int maxCoinsOnCreate = 50000;

  /// Her profil güncellemesinde (update) rules coin artışını `<= 50000`
  /// ile sınırlar (azalış sınırsız). [flushPendingDetailed] her flush'ta
  /// uzaktan bakiyeyi ön-okuyup [convergedCoinsForFlush] ile en fazla bu
  /// kadar artış yazar; kalan fark sonraki flush'larda yakınsar.
  static const int maxCoinIncreasePerUpdate = 50000;

  /// Rules `displayName 1..32` — bkz. [sanitizeDisplayName].
  static const int maxDisplayNameLength = 32;
  static const int maxValidEnergy = 100;
  static const int maxValidBoosterCount = 9999;
  static const int maxValidTier = 20;
  static const int maxValidStreak = 3650;
  static const int maxValidStars = ProgressManager.maxCampaignLevels * 3;

  /// Rules `total11ModesScore 0..5500000`.
  static const int maxTotal11ModesScore = 5500000;

  /// Rules `extraPowers` en fazla 40 anahtar.
  static const int maxExtraPowerEntries = 40;

  /// Rules `unlockedTiers` en fazla 16 öğe.
  static const int maxUnlockedTiersEntries = 16;

  bool onlineEnabled = false;
  String status = 'Yerel · bulut kuyruğu hazır';
  final List<String> pending = [];

  CloudSyncFailure? _lastFailure;

  /// Son senkron reddinin tipli hatası (`null` ise son flush başarılı ya da
  /// hiç denenmedi). Kullanıcı arayüzü bu alanı okuyup görünür hata gösterir.
  CloudSyncFailure? get lastFailure => _lastFailure;

  /// Kullanıcıya gösterilebilir son senkron hata mesajı (`null` ise hata yok).
  String? get lastErrorMessage => _lastFailure?.message;
  bool get firebaseReady => FirebaseBootstrap.ready;
  bool get isAvailable => FirebaseBootstrap.isAvailable;

  /// Constant-time string comparison for integrity hashes.
  static bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    var diff = aBytes.length ^ bBytes.length;
    final maxLen = max(aBytes.length, bBytes.length);
    for (var i = 0; i < maxLen; i++) {
      final byteA = i < aBytes.length ? aBytes[i] : 0;
      final byteB = i < bBytes.length ? bBytes[i] : 0;
      diff |= byteA ^ byteB;
    }
    return diff == 0;
  }

  /// Canonical JSON serializer (sorted keys, skips transient `updatedAt` and `integrityHash`).
  static Object? _canonicalize(Object? value) {
    if (value == null || value is num || value is String || value is bool) {
      return value;
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList();
    }
    if (value is Map) {
      final sortedKeys = value.keys
          .map((k) => k.toString())
          .where((k) => k != 'integrityHash' && k != 'updatedAt')
          .toList()
        ..sort();
      final result = <String, Object?>{};
      for (final k in sortedKeys) {
        final v = value[k];
        if (v is FieldValue) continue;
        result[k] = _canonicalize(v);
      }
      return result;
    }
    return value.toString();
  }

  /// Computes deterministic HMAC-SHA256 `integrityHash` for a cloud or offline payload.
  String computeIntegrityHash(Map<String, dynamic> payload) {
    final canonical = _canonicalize(payload);
    final encoded = jsonEncode(canonical);
    final hmac = Hmac(sha256, utf8.encode(_integritySecret));
    return hmac.convert(utf8.encode(encoded)).toString();
  }

  /// Verifies the `integrityHash` of a payload in constant time.
  bool verifyIntegrityHash(
    Map<String, dynamic> payload, {
    bool allowUnsignedLegacy = false,
  }) {
    final rawSig = payload['integrityHash'];
    if (rawSig is! String || rawSig.isEmpty) {
      return allowUnsignedLegacy;
    }
    final expected = computeIntegrityHash(payload);
    return _constantTimeEquals(rawSig, expected);
  }

  /// Returns true if [score] is within valid anti-cheat bounds.
  ///
  /// Rules-level check: absolute ceiling [maxValidModeScore] (single
  /// source [ProgressManager.maxValidModeScore], `firestore.rules`
  /// `score 0..500000` for every mode). Deliberately NOT per-mode:
  /// legacy scores recorded in the single-ceiling era may exceed a
  /// mode ceiling, and rules accept them; per-mode ceilings are
  /// enforced at write time ([ProgressManager.recordModeScore] /
  /// `LeaderboardService.submitScore`). For the stricter per-mode
  /// check use [isScoreValidForMode] / [isValidScoreForMode].
  static bool isValidScore(num? score) {
    if (score == null || score.isNaN || score.isInfinite) return false;
    final intVal = score.toInt();
    return intVal > 0 && intVal <= maxValidModeScore;
  }

  /// Validates and clamps a mode score; returns 0 if negative or above [maxValidModeScore].
  ///
  /// Absolute-ceiling variant of [sanitizeModeScoreForMode]; see
  /// [isValidScore] for why the rules-level ceiling applies here.
  static int sanitizeModeScore(num? rawScore) {
    if (!isValidScore(rawScore)) return 0;
    return rawScore!.toInt().clamp(0, maxValidModeScore);
  }

  /// Verilen mod için geçerli üst skor sınırını döner (her zaman ≤ 500.000,
  /// rules skor sınırıyla uyumlu). [ProgressManager.ceilingForMode] delege
  /// edilir; bilinmeyen modda [maxValidModeScore] varsayılan tavandır.
  static int ceilingForMode(String modeId) =>
      ProgressManager.ceilingForMode(modeId);

  /// Skorun pozitif ve modun anti-cheat tavanı içinde olup olmadığını doğrular.
  /// [ProgressManager.isScoreValidForMode] delege edilir. Boş mod reddedilir;
  /// bilinmeyen modda varsayılan tavan (500.000) uygulanır.
  ///
  /// Bu doğrulama, [isValidScore] kontrolünden KATIDIR (mod tavanları
  /// 150.000–500.000 arasıdır): yeni veri yazımında kullanılır; eski/uzak
  /// veri okuma ve rules doğrulama yolları mutlak sınırda kalır.
  static bool isScoreValidForMode(String modeId, int score) =>
      ProgressManager.isScoreValidForMode(modeId, score);

  /// [isScoreValidForMode] yönteminin `num?` kabul eden karşılığı: `null`,
  /// NaN ve sonsuz reddedilir, geçerli sayı `int`e çevrilip tek kaynağa
  /// delege edilir. Mod bilgisi olan yeni doğrulama çağrıları bunu kullanır.
  static bool isValidScoreForMode(String modeId, num? score) {
    if (score == null || score.isNaN || score.isInfinite) return false;
    return ProgressManager.isScoreValidForMode(modeId, score.toInt());
  }

  /// Mod bazlı tavana göre doğrular ve kelepçeler; geçersizse 0 döner.
  /// [isValidScoreForMode] üzerinden tek kaynağa bağlıdır.
  /// [sanitizeModeScore] mutlak tavan varyantıdır; bu yöntem mod bilgisi
  /// varken daha katıdır.
  static int sanitizeModeScoreForMode(String modeId, num? rawScore) {
    if (!isValidScoreForMode(modeId, rawScore)) return 0;
    return rawScore!.toInt().clamp(0, ceilingForMode(modeId));
  }

  /// Rules `displayName 1..32` ile uyumlu görünen ad üretir: kontrol
  /// karakterlerini atar, kırpar, 32 karaktere kelepçeler, boşsa 'Oyuncu'
  /// döner. Profil ve skor payload'ları ile uzaktan ad gösterimi tek elden
  /// buradan geçer.
  static String sanitizeDisplayName(String? rawName) {
    final safe = (rawName ?? '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (safe.isEmpty) return 'Oyuncu';
    return safe.length > maxDisplayNameLength
        ? safe.substring(0, maxDisplayNameLength)
        : safe;
  }

  /// Validates and clamps a non-negative integer within `[minVal, maxVal]`.
  /// Rejects negative or excessive numbers when [rejectOutOfBounds] is true.
  static int? _validateBoundedInt(
    Object? raw, {
    required int minVal,
    required int maxVal,
    bool rejectOutOfBounds = false,
  }) {
    if (raw is! num || raw.isNaN || raw.isInfinite) return null;
    final val = raw.toInt();
    if (rejectOutOfBounds && (val < minVal || val > maxVal)) {
      return null;
    }
    return val.clamp(minVal, maxVal);
  }

  /// Builds a sanitized, bounds-clamped, and HMAC-signed player profile payload.
  Map<String, dynamic> buildSignedProfilePayload({
    String? uid,
    String? displayName,
  }) {
    final pm = ProgressManager();
    final board = LeaderboardService.instance;
    final resolvedUid = uid ?? AuthService.instance.playerId;
    final rawName = displayName ?? AuthService.instance.displayName;
    final clampedName = sanitizeDisplayName(rawName);

    final safeCoins = pm.coins.clamp(0, maxValidCoins);
    final safeEnergy = EnergyService.instance.energy.clamp(0, maxValidEnergy);
    final safeLevel =
        pm.unlockedLevel.clamp(1, ProgressManager.maxCampaignLevels);
    final safeStars = pm.totalStars.clamp(0, maxValidStars);
    final safeF16 = pm.f16Count.clamp(0, maxValidBoosterCount);
    final safeRaid = pm.raidCount.clamp(0, maxValidBoosterCount);
    final safeTerlik = pm.terlikCount.clamp(0, maxValidBoosterCount);
    final safeStreak = pm.streak.clamp(1, maxValidStreak);

    final safeTiers = pm.unlockedTiers
        .where((t) => t >= 1 && t <= maxValidTier)
        .toSet()
      ..add(1);
    final sortedTiers = safeTiers.toList()..sort();
    // Rules: unlockedTiers en fazla 16 öğe. Aşılırsa Tier 1 + en yüksek
    // 15 tier korunur (yerel veri etkilenmez, yalnız payload kısalır).
    final cappedTiers = sortedTiers.length > maxUnlockedTiersEntries
        ? (<int>{
            1,
            ...sortedTiers.sublist(
              sortedTiers.length - (maxUnlockedTiersEntries - 1),
            ),
          }.toList()
          ..sort())
        : sortedTiers;

    final safeExtraPowers = <String, int>{};
    final sortedPowerKeys = pm.extraPowers.keys.toList()..sort();
    // Rules: extraPowers en fazla 40 anahtar; alfabetik ilk 40 korunur.
    for (final k in sortedPowerKeys.take(maxExtraPowerEntries)) {
      final v = pm.extraPowers[k] ?? 0;
      if (v > 0) {
        safeExtraPowers[k] = v.clamp(0, maxValidBoosterCount);
      }
    }

    final safeModeScores = <String, int>{};
    var computedTotal11 = 0;
    var computedBestOverall = 0;
    for (final modeId in LeaderboardService.allModeIds) {
      final best = max(
        sanitizeModeScore(board.getBest(modeId)),
        sanitizeModeScore(pm.getModeHighScore(modeId)),
      );
      safeModeScores[modeId] = best;
      computedTotal11 += best;
      if (best > computedBestOverall) {
        computedBestOverall = best;
      }
    }

    final payload = <String, dynamic>{
      'uid': resolvedUid,
      'displayName': clampedName,
      'country': 'TR',
      'coins': safeCoins,
      'energy': safeEnergy,
      'unlockedLevel': safeLevel,
      'totalStars': safeStars,
      'total11ModesScore':
          computedTotal11.clamp(0, maxTotal11ModesScore),
      'bestOverallScore': computedBestOverall.clamp(0, maxValidModeScore),
      'f16Count': safeF16,
      'raidCount': safeRaid,
      'terlikCount': safeTerlik,
      'extraPowers': safeExtraPowers,
      'streak': safeStreak,
      'unlockedTiers': cappedTiers,
      'modeHighScores': safeModeScores,
    };
    payload['integrityHash'] = computeIntegrityHash(payload);
    return payload;
  }

  /// Builds a sanitized, bounds-validated, and HMAC-signed mode score payload.
  Map<String, dynamic>? buildSignedModeScorePayload({
    required String uid,
    required String modeId,
    required int score,
    required String displayName,
    String country = 'TR',
  }) {
    final canonicalMode = LeaderboardService.normalizeModeId(modeId);
    if (canonicalMode.isEmpty || !isValidScore(score)) {
      return null;
    }
    final safeScore = sanitizeModeScore(score);
    final payload = <String, dynamic>{
      'uid': uid,
      'modeId': canonicalMode,
      'score': safeScore,
      'displayName': sanitizeDisplayName(displayName),
      'country': country,
    };
    payload['integrityHash'] = computeIntegrityHash(payload);
    return payload;
  }

  /// Profil payload'unun `firestore.rules` sınırlarına uyup uymadığını
  /// denetler; boş liste = uygun. Uzaktan durum gerektiren koşullar (coin
  /// artış sınırı, ilk-yazım sınırı) burada denetlenemez; onları
  /// [flushPendingDetailed] ön-okuma + [convergedCoinsForFlush]
  /// yakınsamasıyla çözer (kural reddi yerine kademeli yazım).
  static List<String> validateProfilePayloadForRules(
    Map<String, dynamic> payload,
  ) {
    final violations = <String>[];

    void checkInt(String field, int minVal, int maxVal) {
      final v = payload[field];
      if (v == null) return;
      if (v is! int || v < minVal || v > maxVal) {
        violations.add('$field $minVal..$maxVal aralığında olmalı');
      }
    }

    final name = payload['displayName'];
    if (name is! String || name.isEmpty || name.length > maxDisplayNameLength) {
      violations.add('displayName 1..$maxDisplayNameLength karakter olmalı');
    }
    final coins = payload['coins'];
    if (coins is! int || coins < 0 || coins > maxValidCoins) {
      violations.add('coins 0..$maxValidCoins aralığında olmalı');
    }
    checkInt('energy', 0, maxValidEnergy);
    checkInt('unlockedLevel', 1, ProgressManager.maxCampaignLevels);
    checkInt('totalStars', 0, maxValidStars);
    checkInt('total11ModesScore', 0, maxTotal11ModesScore);
    checkInt('bestOverallScore', 0, maxValidModeScore);
    checkInt('f16Count', 0, maxValidBoosterCount);
    checkInt('raidCount', 0, maxValidBoosterCount);
    checkInt('terlikCount', 0, maxValidBoosterCount);
    checkInt('streak', 0, maxValidStreak);
    final tiers = payload['unlockedTiers'];
    if (tiers is List && tiers.length > maxUnlockedTiersEntries) {
      violations.add('unlockedTiers en fazla $maxUnlockedTiersEntries öğe olmalı');
    }
    final powers = payload['extraPowers'];
    if (powers is Map && powers.length > maxExtraPowerEntries) {
      violations.add('extraPowers en fazla $maxExtraPowerEntries anahtar olmalı');
    }
    final modeScores = payload['modeHighScores'];
    if (modeScores is Map) {
      if (modeScores.length > 16) {
        violations.add('modeHighScores en fazla 16 anahtar olmalı');
      }
      for (final entry in modeScores.entries) {
        final v = entry.value;
        if (v is! int || v < 0 || v > maxValidModeScore) {
          violations.add('modeHighScores[${entry.key}] 0..$maxValidModeScore olmalı');
        }
      }
    }
    final hash = payload['integrityHash'];
    if (hash != null && (hash is! String || hash.length != 64)) {
      violations.add('integrityHash 64 karakter olmalı');
    }
    final country = payload['country'];
    if (country != null &&
        (country is! String || country.length < 2 || country.length > 8)) {
      violations.add('country 2..8 karakter olmalı');
    }
    return violations;
  }

  /// Mod skoru payload'unun `firestore.rules` sınırlarına uyup uymadığını
  /// denetler; boş liste = uygun. Skor azalmazlığı (update'te eski skordan
  /// düşük olamaz) uzaktan durum gerektirir, burada denetlenemez.
  static List<String> validateModeScorePayloadForRules(
    Map<String, dynamic> payload,
  ) {
    final violations = <String>[];
    final modeId = payload['modeId'];
    // Rules isValidModeId: 11 mod + 'total_11' + 'overall'.
    final validModeIds = <String>{
      ...LeaderboardService.allModeIds,
      'total_11',
      'overall',
    };
    if (modeId is! String || !validModeIds.contains(modeId)) {
      violations.add('modeId geçerli bir mod olmalı');
    }
    final score = payload['score'];
    if (score is! int || score < 0 || score > maxValidModeScore) {
      violations.add('score 0..$maxValidModeScore aralığında olmalı');
    }
    final name = payload['displayName'];
    if (name is! String || name.isEmpty || name.length > maxDisplayNameLength) {
      violations.add('displayName 1..$maxDisplayNameLength karakter olmalı');
    }
    final hash = payload['integrityHash'];
    if (hash != null && (hash is! String || hash.length != 64)) {
      violations.add('integrityHash 64 karakter olmalı');
    }
    return violations;
  }

  /// Tek flush'ta yazılabilecek coin değerini hesaplar (yakınsama adımı).
  ///
  /// `firestore.rules`: ilk yazımda (create) `coins <= 50000`, her
  /// güncellemede artış `<= 50000` (azalış sınırsız). Yerel bakiye
  /// uzaktakinden 50000'den fazla fazlaysa tam bakiyenin yazımı her
  /// seferinde reddedilir ve kuyruk hiç boşalmaz; bu yüzden her flush
  /// en fazla bir adım yazar, kalan fark sonraki flush'larda yazılır.
  ///
  /// * [remoteCoins] `null` ise uzakta profil yok sayılır (create):
  ///   yazım [maxCoinsOnCreate] ile sınırlanır.
  /// * Aksi hâlde yazım `remoteCoins + [maxCoinIncreasePerUpdate]` ile
  ///   sınırlanır; yerel bakiye bu sınırın altındaysa aynen yazılır
  ///   (azalış ve eşitlik her zaman yazılır).
  ///
  /// Dönen değer her zaman `0..[maxValidCoins]` aralığında bir `int`'tir;
  /// bu yüzden yakınsanmış payload ayrıca doğrulanmaya gerek duymaz
  /// (diğer alanlar [validateProfilePayloadForRules] ile önceden
  /// denetlenmiş olur, yeni anahtar eklenmez, imza yeniden hesaplanır).
  static int convergedCoinsForFlush({
    required int localCoins,
    required int? remoteCoins,
  }) {
    final safeLocal = localCoins < 0
        ? 0
        : (localCoins > maxValidCoins ? maxValidCoins : localCoins);
    if (remoteCoins == null) {
      return safeLocal < maxCoinsOnCreate ? safeLocal : maxCoinsOnCreate;
    }
    final safeRemote = remoteCoins < 0
        ? 0
        : (remoteCoins > maxValidCoins ? maxValidCoins : remoteCoins);
    final cap = safeRemote + maxCoinIncreasePerUpdate;
    return safeLocal < cap ? safeLocal : cap;
  }

  /// Validates and conflict-free merges a remote/offline profile snapshot into
  /// [ProgressManager] and [LeaderboardService]. Returns false if rejected by
  /// integrity verification or anti-cheat bounds checks.
  Future<bool> applyVerifiedProfileSnapshot(
    Map<String, dynamic> data, {
    bool allowUnsignedLegacy = false,
  }) async {
    if (!verifyIntegrityHash(data, allowUnsignedLegacy: allowUnsignedLegacy)) {
      debugPrint('[lululu] CloudSync rejected profile: invalid integrityHash');
      return false;
    }

    // Reject payloads containing explicitly negative or absurdly inflated numbers
    final coinsVal = _validateBoundedInt(
      data['coins'],
      minVal: 0,
      maxVal: maxValidCoins,
      rejectOutOfBounds: true,
    );
    if (data.containsKey('coins') && coinsVal == null) {
      return false;
    }

    final energyVal = _validateBoundedInt(
      data['energy'],
      minVal: 0,
      maxVal: maxValidEnergy,
      rejectOutOfBounds: true,
    );
    if (data.containsKey('energy') && energyVal == null) {
      return false;
    }

    final levelVal = _validateBoundedInt(
      data['unlockedLevel'],
      minVal: 1,
      maxVal: ProgressManager.maxCampaignLevels,
      rejectOutOfBounds: true,
    );
    if (data.containsKey('unlockedLevel') && levelVal == null) {
      return false;
    }

    final f16Val = _validateBoundedInt(
      data['f16Count'],
      minVal: 0,
      maxVal: maxValidBoosterCount,
      rejectOutOfBounds: true,
    );
    final raidVal = _validateBoundedInt(
      data['raidCount'],
      minVal: 0,
      maxVal: maxValidBoosterCount,
      rejectOutOfBounds: true,
    );
    final terlikVal = _validateBoundedInt(
      data['terlikCount'],
      minVal: 0,
      maxVal: maxValidBoosterCount,
      rejectOutOfBounds: true,
    );
    if ((data.containsKey('f16Count') && f16Val == null) ||
        (data.containsKey('raidCount') && raidVal == null) ||
        (data.containsKey('terlikCount') && terlikVal == null)) {
      return false;
    }

    final pm = ProgressManager();
    if (coinsVal != null) {
      pm.coins = max(pm.coins, coinsVal).clamp(0, maxValidCoins);
    }
    if (energyVal != null) {
      final mergedEnergy =
          max(EnergyService.instance.energy, energyVal).clamp(0, maxValidEnergy);
      EnergyService.instance.energy = mergedEnergy;
    }
    if (levelVal != null) {
      pm.unlockedLevel = max(pm.unlockedLevel, levelVal)
          .clamp(1, ProgressManager.maxCampaignLevels);
    }
    if (f16Val != null) {
      pm.f16Count = max(pm.f16Count, f16Val).clamp(0, maxValidBoosterCount);
    }
    if (raidVal != null) {
      pm.raidCount = max(pm.raidCount, raidVal).clamp(0, maxValidBoosterCount);
    }
    if (terlikVal != null) {
      pm.terlikCount =
          max(pm.terlikCount, terlikVal).clamp(0, maxValidBoosterCount);
    }

    final streakVal = _validateBoundedInt(
      data['streak'],
      minVal: 1,
      maxVal: maxValidStreak,
    );
    if (streakVal != null) {
      pm.streak = max(pm.streak, streakVal).clamp(1, maxValidStreak);
    }

    final rawTiers = data['unlockedTiers'];
    if (rawTiers is Iterable) {
      for (final t in rawTiers) {
        final parsed = t is num ? t.toInt() : int.tryParse(t.toString());
        if (parsed != null && parsed >= 1 && parsed <= maxValidTier) {
          pm.unlockedTiers.add(parsed);
        }
      }
      pm.unlockedTiers.add(1);
    }

    final rawPowers = data['extraPowers'];
    if (rawPowers is Map) {
      rawPowers.forEach((k, v) {
        final bounded = _validateBoundedInt(
          v,
          minVal: 0,
          maxVal: maxValidBoosterCount,
          rejectOutOfBounds: true,
        );
        if (bounded != null) {
          final key = k.toString();
          pm.extraPowers[key] =
              max(pm.extraPowers[key] ?? 0, bounded).clamp(0, maxValidBoosterCount);
        }
      });
    }

    final rawModeScores = data['modeHighScores'];
    if (rawModeScores is Map) {
      for (final entry in rawModeScores.entries) {
        final modeId = LeaderboardService.normalizeModeId(entry.key.toString());
        final rawSc = entry.value;
        if (rawSc is num && isValidScore(rawSc)) {
          final sc = sanitizeModeScore(rawSc);
          if (sc > (pm.modeHighScores[modeId] ?? 0)) {
            pm.modeHighScores[modeId] = sc;
          }
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_coins', pm.coins);
    await prefs.setInt('LululuCoinBalance', pm.coins);
    await prefs.setInt('lululu_unlocked_level', pm.unlockedLevel);
    await prefs.setInt('lululu_spray', pm.sprayCount);
    await prefs.setInt('lululu_raid', pm.sprayCount);
    await prefs.setInt('lululu_slipper', pm.slipperCount);
    await prefs.setInt('lululu_terlik', pm.slipperCount);
    await prefs.setInt('lululu_aydinlat', pm.aydinlatCount);
    await prefs.setInt('lululu_f16', pm.aydinlatCount);
    await prefs.setInt('lululu_daily_streak', pm.streak);
    await prefs.setStringList(
      'lululu_unlocked_tiers',
      pm.unlockedTiers.map((e) => e.toString()).toList(),
    );
    await prefs.setString('lululu_extra_powers', jsonEncode(pm.extraPowers));
    await prefs.setString(
      'lululu_mode_high_scores',
      jsonEncode(pm.modeHighScores),
    );
    return true;
  }

  Map<String, dynamic> _buildSignedQueueEnvelope(String itemTag) {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final profile = buildSignedProfilePayload();
    final envelope = <String, dynamic>{
      'tag': itemTag,
      'timestamp': nowMs,
      'uid': AuthService.instance.playerId,
      'profile': profile,
    };
    envelope['integrityHash'] = computeIntegrityHash(envelope);
    return envelope;
  }

  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? const [];
    final signedRaw = prefs.getStringList(_signedQueueKey) ?? const [];

    final verifiedTags = <String>[];
    final validSignedRaw = <String>[];

    if (signedRaw.isNotEmpty) {
      for (final itemJson in signedRaw) {
        try {
          final decoded = jsonDecode(itemJson) as Map<String, dynamic>;
          if (!verifyIntegrityHash(decoded)) {
            debugPrint('[lululu] Dropping tampered offline queue item');
            continue;
          }
          final profileMap = decoded['profile'];
          if (profileMap is Map<String, dynamic>) {
            if (!verifyIntegrityHash(profileMap)) {
              debugPrint('[lululu] Dropping tampered offline profile snapshot');
              continue;
            }
          }
          final tag = decoded['tag'] as String? ?? '';
          if (tag.isNotEmpty) {
            verifiedTags.add(tag);
            validSignedRaw.add(itemJson);
          }
        } catch (_) {}
      }
      if (validSignedRaw.length != signedRaw.length) {
        await prefs.setStringList(_signedQueueKey, validSignedRaw);
        await prefs.setStringList(_queueKey, verifiedTags);
      }
    }

    pending
      ..clear()
      ..addAll(signedRaw.isNotEmpty ? verifiedTags : raw);
    status = FirebaseBootstrap.ready
        ? 'Online hazır · ${pending.length} bekleyen'
        : FirebaseBootstrap.playerStatus;
    notifyListeners();
  }

  Future<void> _persistQueue({String? addedTag}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_queueKey, List<String>.from(pending));
    if (pending.isEmpty) {
      await prefs.remove(_signedQueueKey);
      return;
    }
    if (addedTag != null) {
      final existing =
          List<String>.from(prefs.getStringList(_signedQueueKey) ?? const []);
      final envelope = _buildSignedQueueEnvelope(addedTag);
      existing.add(jsonEncode(envelope));
      await prefs.setStringList(_signedQueueKey, existing);
    }
  }

  Future<void> enqueueLeaderboardPush() async {
    await LeaderboardService.instance.ensureLoaded();
    final tag = 'leaderboard:${DateTime.now().millisecondsSinceEpoch}';
    pending.add(tag);
    status = onlineEnabled
        ? 'Sıralama gönderiliyor…'
        : 'Sıralama kuyrukta (online kapalı)';
    await _persistQueue(addedTag: tag);
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  Future<void> enqueueProgressPush() async {
    final tag = 'progress:${DateTime.now().millisecondsSinceEpoch}';
    pending.add(tag);
    status = onlineEnabled
        ? 'İlerleme senkronize ediliyor…'
        : 'İlerleme kuyrukta (online kapalı)';
    await _persistQueue(addedTag: tag);
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  Future<void> enqueueChatPush() async {
    await ChatService.instance.ensureLoaded();
    final tag = 'chat:${DateTime.now().millisecondsSinceEpoch}';
    pending.add(tag);
    status = onlineEnabled ? 'Sohbet sync…' : 'Sohbet kuyrukta (online kapalı)';
    await _persistQueue(addedTag: tag);
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  Future<void> enqueueVideoFeedPush() async {
    await BugVideoService.instance.ensureLoaded();
    final tag = 'videos:${DateTime.now().millisecondsSinceEpoch}';
    pending.add(tag);
    status = onlineEnabled
        ? 'Video feed sync…'
        : 'Video feed kuyrukta (online kapalı)';
    await _persistQueue(addedTag: tag);
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  Future<void> enableOnlineWhenSignedIn() async {
    await AuthService.instance.ensureLoaded();
    await FirebaseBootstrap.ensureInitialized();
    onlineEnabled = AuthService.instance.isSignedIn &&
        !(AuthService.instance.user?.isGuest ?? true);
    status = onlineEnabled
        ? (FirebaseBootstrap.ready
            ? 'Bağlı · senkron açık'
            : 'Hesap var · Firebase bekleniyor (kuyruk aktif)')
        : 'Misafir / yerel — online kapalı';
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  /// Verifies and merges any signed offline snapshots before flushing.
  Future<void> _reconcileOfflineSignedQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final signedRaw = prefs.getStringList(_signedQueueKey) ?? const [];
    if (signedRaw.isEmpty) return;

    final currentUid = AuthService.instance.playerId;
    for (final itemJson in signedRaw) {
      try {
        final decoded = jsonDecode(itemJson) as Map<String, dynamic>;
        if (!verifyIntegrityHash(decoded)) continue;
        final itemUid = decoded['uid'] as String? ?? '';
        final isCompatibleUser = itemUid == currentUid ||
            itemUid == 'guest_local' ||
            itemUid.startsWith('guest_');
        if (!isCompatibleUser) continue;

        final profile = decoded['profile'];
        if (profile is Map<String, dynamic>) {
          await applyVerifiedProfileSnapshot(profile);
        }
      } catch (_) {}
    }
  }

  /// Push queued leaderboard bests and player progress to Firestore.
  ///
  /// Reddedilen yazım tipli sonuç olarak döner: kural ihlali
  /// ([CloudSyncFailureKind.permissionDenied] / `invalidPayload`) durumunda
  /// kuyruk korunur, [lastFailure] ve [status] kullanıcıya gösterilebilir
  /// Türkçe mesajla güncellenir. Çağrı noktaları (başka dosyalarda) bu
  /// sonucu okuyup görünür hata göstermelidir — bkz. rapor.
  ///
  /// Coin yakınsaması: yazımdan önce uzaktan bakiye ön-okunur ve profil
  /// her flush'ta en fazla +50000 artışla yazılır
  /// ([convergedCoinsForFlush]); kalan fark varsa kuyruk korunur ve
  /// [status] kalan coin miktarını söyler, fark sonraki flush'larda
  /// yazılır. Kural değişikliği yapılmaz.
  ///
  /// Çevrimdışı flush (Firebase hazır değil): kuyruk KORUNUR ve tipli
  /// `unavailable` hatası döner (S2#17); [status] "kuyrukta bekliyor"
  /// der. Eski "Yerel flush" davranışı paketleri hiç yazmadan temizleyip
  /// başarı izlenimi veriyordu.
  Future<CloudSyncFlushResult> flushPendingDetailed() async {
    if (!onlineEnabled) return const CloudSyncFlushResult.success(0);
    await AuthService.instance.ensureLoaded();
    await _reconcileOfflineSignedQueue();
    final uid = AuthService.instance.playerId;
    final name = AuthService.instance.displayName;
    var flushed = 0;
    // Bu flush'ta yazılamayıp sonraya kalan coin farkı (0 ise tam yazım).
    var remainingCoinDelta = 0;

    if (FirebaseBootstrap.ready) {
      try {
        final db = FirebaseFirestore.instance;
        final bests = LeaderboardService.instance.getAllModeBests();
        final signedScores = <Map<String, dynamic>>[];
        for (final b in bests) {
          final signedScore = buildSignedModeScorePayload(
            uid: uid,
            modeId: b.modeId,
            score: b.best,
            displayName: name,
          );
          if (signedScore == null) continue;
          signedScores.add(signedScore);
        }
        final signedProfile = buildSignedProfilePayload(
          uid: uid,
          displayName: name,
        );
        // Ön denetim: kural sınırlarına uymayan payload yazımı denenmez.
        final violations = [
          ...validateProfilePayloadForRules(signedProfile),
          for (final s in signedScores) ...validateModeScorePayloadForRules(s),
        ];
        if (violations.isNotEmpty) {
          final failure = CloudSyncFailure(
            kind: CloudSyncFailureKind.invalidPayload,
            message: 'Senkron reddedildi: kayıt kurallara uymuyor. '
                'Kuyruk korundu, tekrar denenecek.',
            details: violations.join('; '),
          );
          _lastFailure = failure;
          status = 'Sync reddedildi · ${failure.message}';
          debugPrint('[lululu] CloudSync pre-flight reddi: ${failure.details}');
          notifyListeners();
          return CloudSyncFlushResult.failure(failure);
        }
        // Coin yakınsaması: uzaktan bakiyeyi ön-oku; bu flush'ta en fazla
        // +50000 artış yaz (kural: create <= 50000, update artışı
        // <= 50000). Ön-okuma hatası aşağıdaki catch ile tipli hataya
        // dönüşür, kuyruk korunur.
        final profile = db.collection('players').doc(uid);
        final remoteSnap = await profile.get();
        final remoteData = remoteSnap.data();
        int? remoteCoins;
        if (remoteSnap.exists && remoteData != null) {
          final rawRemoteCoins = remoteData['coins'];
          remoteCoins = rawRemoteCoins is int
              ? rawRemoteCoins
              : (rawRemoteCoins is num ? rawRemoteCoins.toInt() : 0);
        }
        var effectiveProfile = signedProfile;
        // Ön denetim geçti: coins int'tir.
        final localCoins = signedProfile['coins'] as int;
        final convergedCoins = convergedCoinsForFlush(
          localCoins: localCoins,
          remoteCoins: remoteCoins,
        );
        if (convergedCoins < localCoins) {
          effectiveProfile = <String, dynamic>{
            ...signedProfile,
            'coins': convergedCoins,
          };
          // Coin değiştiği için bütünlük imzası yeniden hesaplanır
          // (computeIntegrityHash eski imzayı yok sayar; yeni anahtar yok).
          effectiveProfile['integrityHash'] =
              computeIntegrityHash(effectiveProfile);
          remainingCoinDelta = localCoins - convergedCoins;
          debugPrint(
            '[lululu] CloudSync coin yakınsaması: yerel=$localCoins '
            'uzak=${remoteCoins ?? 'yok'} yazılan=$convergedCoins '
            'kalan=$remainingCoinDelta',
          );
        }
        final batch = db.batch();
        for (final signedScore in signedScores) {
          final ref = db
              .collection('scores')
              .doc(uid)
              .collection('modes')
              .doc(signedScore['modeId'] as String);
          batch.set(
            ref,
            {
              ...signedScore,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          flushed++;
        }
        batch.set(
          profile,
          {
            ...effectiveProfile,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        await batch.commit();
        await _pullRemoteBests(uid);
        await _pullRemoteProfile(uid);
      } catch (e) {
        final failure = _failureFromFlushError(e);
        _lastFailure = failure;
        status = 'Sync reddedildi · ${failure.message}';
        debugPrint('[lululu] CloudSync flush reddi: ${failure.details}');
        notifyListeners();
        return CloudSyncFlushResult.failure(failure);
      }
    } else {
      // Çevrimdışı (S2#17): Firebase hazır değilken flush başarı SAYILMAZ.
      // Kuyruk korunur; paketler bir sonraki flush'ta tekrar denenir.
      // Eski davranış ("Yerel flush") kuyruğu temizleyip paketleri hiç
      // buluta yazmadan kaybediyordu.
      final queued = pending.length;
      if (queued == 0) {
        _lastFailure = null;
        status = 'Firebase hazır değil · kuyruk boş';
        notifyListeners();
        return const CloudSyncFlushResult.success(0);
      }
      final failure = CloudSyncFailure(
        kind: CloudSyncFailureKind.unavailable,
        message: 'Buluta ulaşılamadı. $queued paket kuyrukta bekliyor, '
            'tekrar denenecek.',
        details: 'FirebaseBootstrap.ready=false; offline flush, kuyruk korundu',
      );
      _lastFailure = failure;
      status = 'Çevrimdışı · $queued paket kuyrukta bekliyor';
      debugPrint('[lululu] CloudSync çevrimdışı flush: kuyruk korundu '
          '($queued paket)');
      notifyListeners();
      return CloudSyncFlushResult.failure(failure);
    }

    final n = pending.length;
    _lastFailure = null;
    if (remainingCoinDelta > 0) {
      // Kısmi yazım: bu flush bir yakınsama adımı yazdı; kalan fark
      // sonraki flush'larda yazılır. Kuyruk korunur (kalan, yerel coin
      // bakiyesinde durur; her flush payload'u yeniden kurar).
      status = 'Kısmi senkron · $remainingCoinDelta coin kaldı · '
          '$n paket kuyrukta (sonraki flush devam edecek)';
      notifyListeners();
      return CloudSyncFlushResult.success(n);
    }
    pending.clear();
    await _persistQueue();
    // Buraya yalnız Firebase hazır yolundan gelinir (çevrimdışı yol
    // yukarıda erken döner); kuyruk gerçekten yazıldıktan sonra temizlenir.
    status = 'Flush tamam · $flushed skor · $n paket';
    notifyListeners();
    return CloudSyncFlushResult.success(n);
  }

  /// [flushPendingDetailed] hatasını tipli [CloudSyncFailure]e çevirir.
  /// `code` alanı dinamik okunur (FirebaseException tipine bağımlı olmadan).
  CloudSyncFailure _failureFromFlushError(Object error) {
    String? code;
    try {
      final dynamic errorWithCode = error;
      final rawCode = errorWithCode.code;
      if (rawCode is String && rawCode.isNotEmpty) code = rawCode;
    } catch (_) {}
    final details = error.toString();
    switch (code) {
      case 'permission-denied':
        return CloudSyncFailure(
          kind: CloudSyncFailureKind.permissionDenied,
          message: 'Bulut kaydı reddedildi (yetki/kural). '
              'Kuyruk korundu, tekrar denenecek.',
          details: details,
        );
      case 'unavailable':
      case 'deadline-exceeded':
      case 'cancelled':
        return CloudSyncFailure(
          kind: CloudSyncFailureKind.unavailable,
          message: 'Buluta ulaşılamadı. Kuyruk korundu, tekrar denenecek.',
          details: details,
        );
      default:
        return CloudSyncFailure(
          kind: CloudSyncFailureKind.unknown,
          message: 'Senkron hatası. Kuyruk korundu, tekrar denenecek.',
          details: details,
        );
    }
  }

  /// Back-compat wrapper: yazılan paket sayısını döner, reddedilişte 0.
  /// Reddin nedenini görmek için [flushPendingDetailed] / [lastFailure] kullanılır.
  Future<int> flushPending() async {
    final result = await flushPendingDetailed();
    return result.flushedCount;
  }

  Future<void> _pullRemoteBests(String uid) async {
    if (!FirebaseBootstrap.ready) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('scores')
          .doc(uid)
          .collection('modes')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (!verifyIntegrityHash(data, allowUnsignedLegacy: true)) {
          debugPrint('[lululu] Rejected tampered remote score for ${doc.id}');
          continue;
        }
        final rawScore = data['score'] as num?;
        if (!isValidScore(rawScore)) continue;
        final safeScore = sanitizeModeScore(rawScore);
        if (safeScore > 0) {
          await LeaderboardService.instance.submitScore(doc.id, safeScore);
        }
      }
    } catch (e) {
      debugPrint('[lululu] pull remote bests: $e');
    }
  }

  Future<void> _pullRemoteProfile(String uid) async {
    if (!FirebaseBootstrap.ready) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('players')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null || data.isEmpty) return;
      await applyVerifiedProfileSnapshot(data, allowUnsignedLegacy: true);
    } catch (e) {
      debugPrint('[lululu] pull remote profile: $e');
    }
  }

  /// Global top for a mode from Firestore collectionGroup.
  Future<List<({String playerId, String name, int score})>> fetchGlobalTop(
    String modeId, {
    int limit = 20,
  }) async {
    if (!FirebaseBootstrap.ready) return const [];
    try {
      final safeLimit = limit.clamp(1, 100);
      final q = await FirebaseFirestore.instance
          .collectionGroup('modes')
          .where('modeId', isEqualTo: modeId)
          .orderBy('score', descending: true)
          .limit(safeLimit)
          .get();
      final results = <({String playerId, String name, int score})>[];
      for (final d in q.docs) {
        final data = d.data();
        if (!verifyIntegrityHash(data, allowUnsignedLegacy: true)) {
          continue;
        }
        final rawScore = data['score'] as num?;
        if (!isValidScore(rawScore)) continue;
        final safeScore = sanitizeModeScore(rawScore);
        // Path: scores/{uid}/modes/{modeId}
        final uid = d.reference.parent.parent?.id ?? '';
        final rawName = (data['displayName'] as String?) ?? 'Oyuncu';
        results.add((
          playerId: uid,
          name: sanitizeDisplayName(rawName),
          score: safeScore,
        ));
      }
      return results;
    } catch (e) {
      debugPrint('[lululu] fetchGlobalTop: $e');
      return const [];
    }
  }
}
