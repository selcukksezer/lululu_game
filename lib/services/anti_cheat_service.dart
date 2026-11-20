import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// 11 oyun modunun her biri için tavan skor ve saniye başına maksimum puan
/// sınırlarını tanımlayan güvenlik politikası.
@immutable
class GameModeScorePolicy {
  const GameModeScorePolicy({
    required this.modeId,
    required this.maxPossibleScore,
    required this.maxPointsPerSecond,
    this.minDurationSeconds = 1,
  });

  final String modeId;
  final int maxPossibleScore;
  final int maxPointsPerSecond;
  final int minDurationSeconds;
}

/// [AntiCheatService.validateGameScore] tarafından döndürülen denetim sonucu.
@immutable
class ScoreValidationResult {
  const ScoreValidationResult({
    required this.isValid,
    required this.sanitizedScore,
    required this.reason,
    required this.mode,
    required this.maxPossibleScore,
    required this.maxPointsPerSecond,
  });

  final bool isValid;
  final int sanitizedScore;
  final String reason;
  final String mode;
  final int maxPossibleScore;
  final int maxPointsPerSecond;

  @override
  String toString() =>
      'ScoreValidationResult(mode: $mode, isValid: $isValid, '
      'sanitizedScore: $sanitizedScore, reason: $reason)';
}

/// Ekonomi (altın/enerji) değişim denetimi sonucu.
@immutable
class EconomyValidationResult {
  const EconomyValidationResult({
    required this.isValid,
    required this.sanitizedDelta,
    required this.sanitizedBalance,
    required this.reason,
  });

  final bool isValid;
  final int sanitizedDelta;
  final int sanitizedBalance;
  final String reason;

  @override
  String toString() =>
      'EconomyValidationResult(isValid: $isValid, '
      'sanitizedDelta: $sanitizedDelta, sanitizedBalance: $sanitizedBalance, '
      'reason: $reason)';
}

/// Kimlik bilgileri (kullanıcı adı, e-posta, şifre) doğrulama sonucu.
@immutable
class CredentialValidationResult {
  const CredentialValidationResult({
    required this.isValid,
    required this.sanitizedUsername,
    required this.sanitizedEmail,
    required this.reason,
    this.errors = const <String>[],
  });

  final bool isValid;
  final String sanitizedUsername;
  final String sanitizedEmail;
  final String reason;
  final List<String> errors;

  @override
  String toString() =>
      'CredentialValidationResult(isValid: $isValid, '
      'username: $sanitizedUsername, email: $sanitizedEmail, reason: $reason)';
}

/// Hile Kontrolü (Anti-Cheat) & Güvenlik Kalkanı Motoru.
///
/// Sorumluluklar:
/// 1. **Kriptografik Durum İmzası (HMAC-SHA256 State Integrity):**
///    Yerel (`SharedPreferences`) ve bulut kayıtlarındaki `coins`, `energy`,
///    `highScore`, `modeHighScores`, `unlockedTiers` ve `powerCounts`
///    verilerinin dışarıdan değiştirilmesini tespit eder.
/// 2. **11 Oyun Modu İçin Skor & Süre Tutarlılık Denetimi:**
///    Her oyun modu için `maxPossibleScore`, `maxPointsPerSecond` ve
///    negatif/NaN/aşırı skor kontrolü yapar.
/// 3. **Ekonomi & Ödül Replay/Sömürü Koruması:**
///    Tek seferde kazanılabilecek maksimum altın/enerji sınırı, negatif değer
///    enjeksiyonu engeli, monotonik süre ve tekil işlem ID (`nonce`/`claimId`)
///    doğrulaması sağlar.
/// 4. **Girdi Güvenliği & XSS/Enjeksiyon/Küfür Koruması:**
///    Kullanıcı adı, e-posta, sohbet mesajı ve video başlıklarında
///    HTML/Script/SQL/NoSQL kontrol karakterlerini temizler, küfür filtreler
///    ve şifre güvenliğini denetler.
///
/// Sınır: Bu denetimlerin tamamı istemci içindedir. İstemcide saklanan sır
/// sır değildir: `_deriveDefaultSecretKey` içindeki sabit, uygulamayı
/// söken herkes tarafından çıkarılabilir ve HMAC imzası yeniden
/// üretilebilir. Buradaki HMAC yalnızca kazara bozulma / basit dış
/// müdahale izi sayılır; gerçek hile koruması değildir.
/// TODO(sunucu doğrulaması, bu gece kapsam dışı): Skor ve durum
/// kabulleri sunucu tarafında, sunucuda tutulan sırla doğrulanmalıdır.
/// Sunucu doğrulaması gelene kadar imza hatası skoru/durumu sessizce
/// kabul ettirmez: [verifyStateSignature] hata durumunda `false` döner
/// ve başarısızlık kayda geçer; çağıranlar bu sonucu yok saymamalıdır.
class AntiCheatService {
  AntiCheatService({String? secretKey})
      : _secretKey = secretKey ?? _deriveDefaultSecretKey();

  static final AntiCheatService instance = AntiCheatService();

  final String _secretKey;

  /// Tek seferde kazanılabilecek maksimum altın miktarı (ödül/paket tavanı).
  static const int maxSingleCoinGrant = 5000;

  /// Tek seferde harcanabilecek maksimum altın miktarı.
  static const int maxSingleCoinSpend = 50000;

  /// Maksimum toplam altın kasası tavanı.
  static const int maxCoinBalanceCap = 9999999;

  /// Maksimum enerji tavanı.
  static const int maxEnergyCap = 30;

  /// Tek seferde eklenebilecek maksimum enerji miktarı.
  static const int maxSingleEnergyGrant = 30;

  /// Durum bütünlüğü imzasına dahil edilen çekirdek alanlar.
  static const List<String> integrityStateFields = <String>[
    'coins',
    'energy',
    'highScore',
    'modeHighScores',
    'unlockedTiers',
    'powerCounts',
  ];

  /// 11 oyun modu için skor ve hız tavan politikaları.
  /// `maxPossibleScore` değerleri `ProgressManager.modeScoreCeilings` (S1#35
  /// tek kaynak, firestore.rules ile uyumlu) ile BİREBİR aynı olmalıdır:
  /// daha düşük bir AntiCheat tavanı, oyunun kendi tavanına kadar meşru
  /// skorları sessizce reddeder. Tavan değişirse iki yer birlikte güncellenir
  /// (bkz. anticheat_binding_12c1_test.dart — tavan hizalama testi).
  static const Map<String, GameModeScorePolicy> modePolicies =
      <String, GameModeScorePolicy>{
    'suika': GameModeScorePolicy(
      modeId: 'suika',
      maxPossibleScore: 250000,
      maxPointsPerSecond: 1200,
      minDurationSeconds: 2,
    ),
    'grid2048': GameModeScorePolicy(
      modeId: 'grid2048',
      maxPossibleScore: 500000,
      maxPointsPerSecond: 1800,
      minDurationSeconds: 2,
    ),
    'balloon': GameModeScorePolicy(
      modeId: 'balloon',
      maxPossibleScore: 150000,
      maxPointsPerSecond: 900,
      minDurationSeconds: 2,
    ),
    'match3': GameModeScorePolicy(
      modeId: 'match3',
      maxPossibleScore: 300000,
      maxPointsPerSecond: 1000,
      minDurationSeconds: 2,
    ),
    'connect': GameModeScorePolicy(
      modeId: 'connect',
      maxPossibleScore: 250000,
      maxPointsPerSecond: 950,
      minDurationSeconds: 2,
    ),
    'stack': GameModeScorePolicy(
      modeId: 'stack',
      maxPossibleScore: 150000,
      maxPointsPerSecond: 750,
      minDurationSeconds: 2,
    ),
    'terlikTap': GameModeScorePolicy(
      modeId: 'terlikTap',
      maxPossibleScore: 150000,
      maxPointsPerSecond: 850,
      minDurationSeconds: 2,
    ),
    'yuvaDefense': GameModeScorePolicy(
      modeId: 'yuvaDefense',
      maxPossibleScore: 200000,
      maxPointsPerSecond: 950,
      minDurationSeconds: 2,
    ),
    'osmantus': GameModeScorePolicy(
      modeId: 'osmantus',
      maxPossibleScore: 200000,
      maxPointsPerSecond: 900,
      minDurationSeconds: 2,
    ),
    'screamRoach': GameModeScorePolicy(
      modeId: 'screamRoach',
      maxPossibleScore: 150000,
      maxPointsPerSecond: 800,
      minDurationSeconds: 2,
    ),
    'makarayiz': GameModeScorePolicy(
      modeId: 'makarayiz',
      maxPossibleScore: 200000,
      maxPointsPerSecond: 850,
      minDurationSeconds: 2,
    ),
  };

  /// Ödül tiplerine göre varsayılan bekleme süreleri (cooldown).
  static const Map<String, Duration> defaultRewardCooldowns =
      <String, Duration>{
    'daily_reward': Duration(hours: 20),
    'daily_gift_box': Duration(hours: 20),
    'daily_shop_chest': Duration(hours: 20),
    'daily_energy': Duration(minutes: 15),
    'rewarded_ad': Duration(seconds: 25),
    'arcade_drop': Duration(seconds: 5),
  };

  /// Türkçe ve İngilizce temel küfür/hakaret kara listesi (normalize edilmiş).
  static const List<String> _profanityList = <String>[
    'amk',
    'aq',
    'sikik',
    'siktir',
    'orospu',
    'pic',
    'piç',
    'yarrak',
    'gavat',
    'ibne',
    'kahpe',
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'bastard',
    'dick',
    'cunt',
  ];

  /// Tekrar saldırılarını (replay attack) önlemek için kullanılan tekil işlem
  /// ID (`nonce` / `claimId`) kayıt defteri.
  final Set<String> _consumedClaimIds = <String>{};

  /// Ödül kanallarına göre son başarılı talep zamanı (monotonik milisaniye).
  final Map<String, int> _lastRewardClaimMs = <String, int>{};

  /// Ödül kanallarında gözlemlenen en yüksek zaman damgası (saat geri alma
  /// hilesine karşı monotonik sınır).
  final Map<String, int> _highestObservedTimestampMs = <String, int>{};

  /// İmza doğrulama başarısızlıkları (yalnızca bellek içi kayıt; kalıcı
  /// depolama yok). İmza hatası skoru/durumu kabul ettirmez; her ret
  /// burada sayılır ve son neden saklanır.
  int _signatureVerificationFailures = 0;
  String? _lastSignatureFailureReason;

  /// Bu oturumda kaydedilen imza doğrulama başarısızlığı sayısı.
  int get signatureVerificationFailures => _signatureVerificationFailures;

  /// Son imza doğrulama başarısızlığının nedeni (`null` = başarısızlık yok).
  String? get lastSignatureFailureReason => _lastSignatureFailureReason;

  void _recordSignatureFailure(String reason) {
    _signatureVerificationFailures++;
    _lastSignatureFailureReason = reason;
    debugPrint('[lululu] AntiCheat: imza doğrulama reddedildi ($reason)');
  }

  /// İmza başarısızlık kaydını sıfırlar (test / oturum sıfırlama için).
  void resetSignatureFailureRecord() {
    _signatureVerificationFailures = 0;
    _lastSignatureFailureReason = null;
  }

  static String _deriveDefaultSecretKey() {
    // UYARI: Bu XOR gizleme güvenlik sağlamaz; istemcide saklanan sır sır
    // değildir ve ikili dosyadan çıkarılabilir. Sabiti "güçlendirmeye"
    // (daha karmaşık gizleme, ek karıştırma) çalışma: gerçek düzeltme
    // sunucu tarafı doğrulamadır (bkz. sınıf dokümantasyonundaki TODO).
    // Sabit string yerine parçalı XOR + tuz birleşimiyle çalışma zamanında üretilir.
    const mask = 0x5A;
    const obfuscated = <int>[
      0x16, 0x0F, 0x16, 0x0F, 0x16, 0x0F, 0x05, 0x1B, // LULULU_A
      0x14, 0x0E, 0x13, 0x05, 0x19, 0x12, 0x1F, 0x1B, // NTI_CHEA
      0x0E, 0x05, 0x12, 0x17, 0x1B, 0x19, 0x05, 0x0C, // T_HMAC_V
      0x68, 0x6A, 0x68, 0x6C, // 2026
    ];
    final chars = obfuscated.map((b) => b ^ mask).toList(growable: false);
    return '${String.fromCharCodes(chars)}::v1_shield_key';
  }

  // ---------------------------------------------------------------------------
  // 1. KRİPTOGRAFİK DURUM İMZASI (HMAC-SHA256 STATE INTEGRITY)
  // ---------------------------------------------------------------------------

  /// Oyun durum verisini (`coins`, `energy`, `highScore`, `modeHighScores`,
  /// `unlockedTiers`, `powerCounts` ve diğer alanlar) deterministik olarak
  /// kanonik JSON'a dönüştürür ve HMAC-SHA256 imzasını üretir.
  ///
  /// Yalnızca imza ÜRETİR; doğrulama için tek nokta
  /// [verifyStateSignature]'dır. İmza üretmek bir skoru/durumu kabul
  /// etmek değildir.
  String computeStateSignature(Map<String, dynamic> payload) {
    final sanitizedPayload = Map<String, dynamic>.from(payload)
      ..remove('signature')
      ..remove('_signature');
    final canonicalJson = jsonEncode(_canonicalizeValue(sanitizedPayload));
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmac.convert(utf8.encode(canonicalJson));
    return digest.toString();
  }

  /// Verilen durum verisinin (`payload`) HMAC-SHA256 imzasını sabit zamanlı
  /// (constant-time) karşılaştırma ile doğrular.
  ///
  /// İmza doğrulamanın TEK noktasıdır: bütün çağıranlar bu metodu
  /// kullanır, kendi karşılaştırmasını yapmaz. Hata durumunda (biçim
  /// bozukluğu, eşleşmeme, istisna) `false` döner — skor/durum sessizce
  /// kabul edilmez — ve ret kayda geçer (bkz.
  /// [signatureVerificationFailures]). İstisna fırlatmaz.
  bool verifyStateSignature(Map<String, dynamic> payload, String signature) {
    try {
      final trimmedSig = signature.trim().toLowerCase();
      if (trimmedSig.length != 64 ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(trimmedSig)) {
        _recordSignatureFailure('invalid_signature_format');
        return false;
      }
      final expected = computeStateSignature(payload).toLowerCase();
      final matches = _constantTimeEquals(expected, trimmedSig);
      if (!matches) {
        _recordSignatureFailure('signature_mismatch');
      }
      return matches;
    } catch (e) {
      // Fail-closed: doğrulama hesaplanamadıysa kabul etme, reddet ve kaydet.
      _recordSignatureFailure('signature_verification_error');
      debugPrint('[lululu] AntiCheat: imza doğrulama hatası: $e');
      return false;
    }
  }

  /// Çekirdek ekonomi/ilerleme alanlarından standart bir durum paketi oluşturur.
  Map<String, dynamic> buildStatePayload({
    required int coins,
    required int energy,
    required int highScore,
    required Map<String, int> modeHighScores,
    required Iterable<int> unlockedTiers,
    required Map<String, int> powerCounts,
  }) {
    final normalizedModes = <String, int>{};
    modeHighScores.forEach((key, value) {
      normalizedModes[normalizeModeKey(key)] = value;
    });
    final sortedTiers = unlockedTiers.toSet().toList()..sort();
    return <String, dynamic>{
      'coins': coins,
      'energy': energy,
      'highScore': highScore,
      'modeHighScores': normalizedModes,
      'unlockedTiers': sortedTiers,
      'powerCounts': Map<String, int>.from(powerCounts),
    };
  }

  /// İç içe Map, List ve Set yapılarını deterministik (anahtarları alfabetik
  /// sıralı) forma dönüştürür.
  static Object? _canonicalizeValue(Object? value) {
    if (value == null || value is bool || value is String) {
      return value;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      if (value.isNaN || value.isInfinite) {
        return 'INVALID_NUM';
      }
      if (value == value.roundToDouble()) {
        return value.toInt();
      }
      return value;
    }
    if (value is Map) {
      final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
      final result = <String, Object?>{};
      for (final key in sortedKeys) {
        final rawVal = value[key] ?? value[int.tryParse(key)];
        result[key] = _canonicalizeValue(rawVal);
      }
      return result;
    }
    if (value is Set) {
      final normalizedList = value.map(_canonicalizeValue).toList();
      normalizedList.sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
      return normalizedList;
    }
    if (value is Iterable) {
      return value.map(_canonicalizeValue).toList(growable: false);
    }
    return value.toString();
  }

  /// Zamanlama saldırılarına (timing attack) karşı sabit süreli dizi karşılaştırması.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ---------------------------------------------------------------------------
  // 2. 11 OYUN MODU İÇİN SKOR & SÜRE TUTARLILIK DENETİMİ
  // ---------------------------------------------------------------------------

  /// Farklı yazım biçimlerini (`grid_2048`, `grid2048`, `balloon_pop`,
  /// `balloon`, `terlik_tap`, `terlikTap` vb.) 11 kanonik oyun modu anahtarına
  /// eşler. Tanınmayan modlar için `null` döner.
  static String? tryResolveModeKey(String rawMode) {
    final cleaned = rawMode.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    switch (cleaned) {
      case 'suika':
        return 'suika';
      case 'grid2048':
      case 'grid_2048':
      case '2048':
        return 'grid2048';
      case 'balloon':
      case 'balloon_pop':
      case 'balon':
        return 'balloon';
      case 'match3':
      case 'match_3':
        return 'match3';
      case 'connect':
      case 'connect_pop':
      case 'bagla':
        return 'connect';
      case 'stack':
      case 'stack_drop':
        return 'stack';
      case 'terliktap':
      case 'terlik_tap':
      case 'terlik':
        return 'terlikTap';
      case 'yuvadefense':
      case 'yuva_defense':
      case 'yuva':
        return 'yuvaDefense';
      case 'osmantus':
        return 'osmantus';
      case 'screamroach':
      case 'scream_roach':
      case 'scream':
      case 'ciglik':
        return 'screamRoach';
      case 'makarayiz':
      case 'makara':
        return 'makarayiz';
      default:
        return null;
    }
  }

  /// Mod adını kanonik anahtara dönüştürür; bilinmiyorsa küçük harf döner.
  static String normalizeModeKey(String rawMode) =>
      tryResolveModeKey(rawMode) ?? rawMode.trim().toLowerCase();

  /// Belirtilen oyun modu için skor ve oynama süresi tutarlılığını denetler.
  ///
  /// Kontroller:
  /// - Modun 11 resmi oyun modundan biri olup olmadığı
  /// - `NaN`, `Infinity` veya negatif skor enjeksiyonu
  /// - Modun maksimum tavan skoru (`maxPossibleScore`)
  /// - Oynama süresine göre saniye başına maksimum puan (`maxPointsPerSecond`)
  /// - 0 veya negatif sürede yüksek skor hilesi (instant-win exploit)
  ScoreValidationResult validateGameScore(
    String mode,
    num score, {
    Duration? elapsed,
    num? elapsedSeconds,
    int? durationSeconds,
    int? previousHighScore,
  }) {
    final canonicalMode = tryResolveModeKey(mode);
    if (canonicalMode == null) {
      return ScoreValidationResult(
        isValid: false,
        sanitizedScore: 0,
        reason: 'unknown_game_mode',
        mode: mode.trim(),
        maxPossibleScore: 0,
        maxPointsPerSecond: 0,
      );
    }

    final policy = modePolicies[canonicalMode]!;

    // NaN / Infinity kontrolü
    if (score is double && (score.isNaN || score.isInfinite)) {
      return ScoreValidationResult(
        isValid: false,
        sanitizedScore: 0,
        reason: 'non_finite_score',
        mode: canonicalMode,
        maxPossibleScore: policy.maxPossibleScore,
        maxPointsPerSecond: policy.maxPointsPerSecond,
      );
    }

    // Negatif skor kontrolü
    if (score < 0) {
      return ScoreValidationResult(
        isValid: false,
        sanitizedScore: 0,
        reason: 'negative_score',
        mode: canonicalMode,
        maxPossibleScore: policy.maxPossibleScore,
        maxPointsPerSecond: policy.maxPointsPerSecond,
      );
    }

    final intScore = score.floor();

    // Sıfır skor her zaman geçerli ve zararsızdır.
    if (intScore == 0) {
      return ScoreValidationResult(
        isValid: true,
        sanitizedScore: 0,
        reason: 'ok',
        mode: canonicalMode,
        maxPossibleScore: policy.maxPossibleScore,
        maxPointsPerSecond: policy.maxPointsPerSecond,
      );
    }

    // Süre çözümlemesi (varsa)
    double? resolvedSeconds;
    if (elapsed != null) {
      resolvedSeconds = elapsed.inMilliseconds / 1000.0;
    } else if (elapsedSeconds != null) {
      if (elapsedSeconds is double &&
          (elapsedSeconds.isNaN || elapsedSeconds.isInfinite)) {
        return ScoreValidationResult(
          isValid: false,
          sanitizedScore: 0,
          reason: 'invalid_elapsed_time',
          mode: canonicalMode,
          maxPossibleScore: policy.maxPossibleScore,
          maxPointsPerSecond: policy.maxPointsPerSecond,
        );
      }
      resolvedSeconds = elapsedSeconds.toDouble();
    } else if (durationSeconds != null) {
      resolvedSeconds = durationSeconds.toDouble();
    }

    // Süre verilmişse hız ve minimum süre kontrolü
    if (resolvedSeconds != null) {
      if (resolvedSeconds <= 0) {
        return ScoreValidationResult(
          isValid: false,
          sanitizedScore: 0,
          reason: 'zero_or_negative_duration',
          mode: canonicalMode,
          maxPossibleScore: policy.maxPossibleScore,
          maxPointsPerSecond: policy.maxPointsPerSecond,
        );
      }

      if (resolvedSeconds < policy.minDurationSeconds &&
          intScore > policy.maxPointsPerSecond) {
        final cappedByMinTime =
            (resolvedSeconds * policy.maxPointsPerSecond).floor().clamp(
                  0,
                  policy.maxPossibleScore,
                );
        return ScoreValidationResult(
          isValid: false,
          sanitizedScore: cappedByMinTime,
          reason: 'duration_too_short_for_score',
          mode: canonicalMode,
          maxPossibleScore: policy.maxPossibleScore,
          maxPointsPerSecond: policy.maxPointsPerSecond,
        );
      }

      final maxAllowedForDuration =
          (resolvedSeconds * policy.maxPointsPerSecond).ceil();
      if (intScore > maxAllowedForDuration) {
        final clamped = maxAllowedForDuration.clamp(0, policy.maxPossibleScore);
        return ScoreValidationResult(
          isValid: false,
          sanitizedScore: clamped,
          reason: 'exceeds_max_points_per_second',
          mode: canonicalMode,
          maxPossibleScore: policy.maxPossibleScore,
          maxPointsPerSecond: policy.maxPointsPerSecond,
        );
      }
    }

    // Tavan skor (maxPossibleScore) kontrolü
    if (intScore > policy.maxPossibleScore) {
      return ScoreValidationResult(
        isValid: false,
        sanitizedScore: policy.maxPossibleScore,
        reason: 'exceeds_max_possible_score',
        mode: canonicalMode,
        maxPossibleScore: policy.maxPossibleScore,
        maxPointsPerSecond: policy.maxPointsPerSecond,
      );
    }

    return ScoreValidationResult(
      isValid: true,
      sanitizedScore: intScore,
      reason: 'ok',
      mode: canonicalMode,
      maxPossibleScore: policy.maxPossibleScore,
      maxPointsPerSecond: policy.maxPointsPerSecond,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. EKONOMİ & ÖDÜL REPLAY/SÖMÜRÜ KORUMASI
  // ---------------------------------------------------------------------------

  /// Altın (coin) artış/azalış işlemini denetler.
  ///
  /// - `allowSpend: false` (varsayılan: ödül/kazanç modu) iken negatif veya 0
  ///   delta enjeksiyonunu reddeder.
  /// - Tek seferde kazanılabilecek maksimum altın sınırını (`maxGrant`) aşan
  ///   değerleri reddeder ve güvenli tavana kırpar.
  /// - Harcama modunda (`allowSpend: true`) bakiyenin negatife düşmesini veya
  ///   aşırı harcamayı engeller.
  EconomyValidationResult validateCoinDelta(
    num delta, {
    int currentBalance = 0,
    bool allowSpend = false,
    int maxGrant = maxSingleCoinGrant,
    int maxSpend = maxSingleCoinSpend,
  }) {
    final safeCurrent = currentBalance.clamp(0, maxCoinBalanceCap);

    if (delta is double && (delta.isNaN || delta.isInfinite)) {
      return EconomyValidationResult(
        isValid: false,
        sanitizedDelta: 0,
        sanitizedBalance: safeCurrent,
        reason: 'non_finite_coin_delta',
      );
    }

    final intDelta = delta.round();

    if (intDelta == 0) {
      return EconomyValidationResult(
        isValid: false,
        sanitizedDelta: 0,
        sanitizedBalance: safeCurrent,
        reason: 'zero_coin_delta',
      );
    }

    if (intDelta < 0) {
      if (!allowSpend) {
        return EconomyValidationResult(
          isValid: false,
          sanitizedDelta: 0,
          sanitizedBalance: safeCurrent,
          reason: 'negative_coin_injection_blocked',
        );
      }
      final spendAmount = -intDelta;
      if (spendAmount > maxSpend) {
        return EconomyValidationResult(
          isValid: false,
          sanitizedDelta: 0,
          sanitizedBalance: safeCurrent,
          reason: 'exceeds_max_single_coin_spend',
        );
      }
      if (spendAmount > safeCurrent) {
        return EconomyValidationResult(
          isValid: false,
          sanitizedDelta: 0,
          sanitizedBalance: safeCurrent,
          reason: 'insufficient_coin_balance',
        );
      }
      return EconomyValidationResult(
        isValid: true,
        sanitizedDelta: intDelta,
        sanitizedBalance: safeCurrent + intDelta,
        reason: 'ok',
      );
    }

    // Pozitif altın kazanımı
    if (intDelta > maxGrant) {
      final clampedBalance =
          (safeCurrent + maxGrant).clamp(0, maxCoinBalanceCap);
      return EconomyValidationResult(
        isValid: false,
        sanitizedDelta: maxGrant,
        sanitizedBalance: clampedBalance,
        reason: 'exceeds_max_single_coin_grant',
      );
    }

    if (safeCurrent + intDelta > maxCoinBalanceCap) {
      final allowedDelta = maxCoinBalanceCap - safeCurrent;
      return EconomyValidationResult(
        isValid: false,
        sanitizedDelta: allowedDelta,
        sanitizedBalance: maxCoinBalanceCap,
        reason: 'exceeds_max_coin_balance_cap',
      );
    }

    return EconomyValidationResult(
      isValid: true,
      sanitizedDelta: intDelta,
      sanitizedBalance: safeCurrent + intDelta,
      reason: 'ok',
    );
  }

  /// Enerji değişimini denetler; negatif enerji enjeksiyonunu ve maksimum
  /// enerji tavanı (`maxEnergyCap = 30`) aşımını engeller.
  EconomyValidationResult validateEnergyDelta(
    num delta, {
    int currentEnergy = 5,
    bool allowConsume = false,
    int maxGrant = maxSingleEnergyGrant,
  }) {
    final safeCurrent = currentEnergy.clamp(0, maxEnergyCap);

    if (delta is double && (delta.isNaN || delta.isInfinite)) {
      return EconomyValidationResult(
        isValid: false,
        sanitizedDelta: 0,
        sanitizedBalance: safeCurrent,
        reason: 'non_finite_energy_delta',
      );
    }

    final intDelta = delta.round();

    if (intDelta <= 0 && !allowConsume) {
      return EconomyValidationResult(
        isValid: false,
        sanitizedDelta: 0,
        sanitizedBalance: safeCurrent,
        reason: 'negative_or_zero_energy_injection_blocked',
      );
    }

    if (intDelta < 0 && allowConsume) {
      final consume = -intDelta;
      if (consume > safeCurrent) {
        return EconomyValidationResult(
          isValid: false,
          sanitizedDelta: 0,
          sanitizedBalance: safeCurrent,
          reason: 'insufficient_energy',
        );
      }
      return EconomyValidationResult(
        isValid: true,
        sanitizedDelta: intDelta,
        sanitizedBalance: safeCurrent + intDelta,
        reason: 'ok',
      );
    }

    if (intDelta > maxGrant) {
      return EconomyValidationResult(
        isValid: false,
        sanitizedDelta: maxGrant.clamp(0, maxEnergyCap - safeCurrent),
        sanitizedBalance: (safeCurrent + maxGrant).clamp(0, maxEnergyCap),
        reason: 'exceeds_max_single_energy_grant',
      );
    }

    final nextEnergy = (safeCurrent + intDelta).clamp(0, maxEnergyCap);
    return EconomyValidationResult(
      isValid: true,
      sanitizedDelta: nextEnergy - safeCurrent,
      sanitizedBalance: nextEnergy,
      reason: 'ok',
    );
  }

  /// Günlük Ödül, Günlük Enerji, Ödüllü Reklam vb. ödül taleplerinde:
  /// 1. Tekil işlem ID (`nonce` / `claimId`) tekrarını (replay attack) engeller.
  /// 2. Cihaz saatinin geri alınmasını (clock rollback) tespit eder.
  /// 3. Belirtilen `cooldown` süresi dolmadan art arda ödül alınmasını engeller.
  ///
  /// Başarılı doğrulamada (`recordClaim: true` ise) işlemi atomik olarak kaydeder.
  bool canClaimCooldownReward(
    String rewardType, {
    String? claimId,
    String? nonce,
    Duration? cooldown,
    DateTime? now,
    int? nowMs,
    int? lastClaimMs,
    bool recordClaim = true,
  }) {
    final normalizedType = rewardType.trim().toLowerCase();
    if (normalizedType.isEmpty) return false;

    final effectiveClaimId = (claimId ?? nonce)?.trim();
    if (effectiveClaimId != null) {
      if (effectiveClaimId.isEmpty || effectiveClaimId.length > 128) {
        return false;
      }
      // Aynı nonce / claimId daha önce kullanıldıysa kesinlikle reddet (replay attack)!
      if (_consumedClaimIds.contains(effectiveClaimId)) {
        return false;
      }
    }

    final currentMs =
        nowMs ?? (now ?? DateTime.now()).millisecondsSinceEpoch;
    final effectiveCooldown = cooldown ??
        defaultRewardCooldowns[normalizedType] ??
        const Duration(minutes: 5);

    // Monotonik zaman kontrolü: cihaz saati geri alınmışsa reddet!
    final highestSeen = _highestObservedTimestampMs[normalizedType];
    if (highestSeen != null && currentMs < highestSeen) {
      return false;
    }

    final previousClaimMs =
        lastClaimMs ?? _lastRewardClaimMs[normalizedType];
    if (previousClaimMs != null) {
      final elapsedMs = currentMs - previousClaimMs;
      if (elapsedMs < effectiveCooldown.inMilliseconds) {
        return false;
      }
    }

    if (recordClaim) {
      if (effectiveClaimId != null) {
        _consumedClaimIds.add(effectiveClaimId);
      }
      _lastRewardClaimMs[normalizedType] = currentMs;
      if (highestSeen == null || currentMs > highestSeen) {
        _highestObservedTimestampMs[normalizedType] = currentMs;
      }
    }

    return true;
  }

  /// Testler veya oturum sıfırlama için replay/cooldown geçmişini temizler.
  void resetRewardHistory() {
    _consumedClaimIds.clear();
    _lastRewardClaimMs.clear();
    _highestObservedTimestampMs.clear();
  }

  // ---------------------------------------------------------------------------
  // 4. GİRDİ GÜVENLİĞİ & XSS / ENJEKSİYON / KÜFÜR KORUMASI
  // ---------------------------------------------------------------------------

  /// Kullanıcı adı, sohbet mesajı, e-posta veya video başlıklarındaki:
  /// - HTML / `<script>` / `<iframe>` / event handler (`onerror=`, `onload=`)
  ///   ve `javascript:` / `data:` URI XSS vektörlerini,
  /// - SQL enjeksiyon kalıplarını (`DROP TABLE`, `UNION SELECT`, `' OR 1=1`, `--`),
  /// - NoSQL operatör enjeksiyonlarını (`$where`, `$gt`, `$ne`, `$regex`),
  /// - ASCII/Unicode görünmez kontrol karakterlerini (`\x00`..`\x1F`, `\x7F`),
  /// - Küfür ve argo ifadeleri (`maskProfanity: true` ise `***` ile)
  /// temizler ve `maxLength` sınırına kırpar.
  String sanitizeUserInput(
    String rawInput, {
    int maxLength = 140,
    bool maskProfanity = true,
    bool allowSpaces = true,
  }) {
    if (rawInput.isEmpty || maxLength <= 0) return '';

    var cleaned = rawInput;

    // 1. Null byte ve görünmez ASCII/Unicode kontrol karakterlerini kaldır
    cleaned = cleaned.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u200B-\u200F\u202A-\u202E\uFEFF]'),
      '',
    );

    // 2. <script>...</script>, <style>...</style>, <iframe>...</iframe> bloklarını tamamen sil
    cleaned = cleaned.replaceAll(
      RegExp(
        r'<\s*(script|style|iframe|object|embed|svg|math)[^>]*>[\s\S]*?<\s*/\s*\1\s*>',
        caseSensitive: false,
      ),
      '',
    );

    // 3. Kalan tüm HTML/XML etiketlerini kaldır
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');

    // 4. Tehlikeli protokol ve inline event handler kalıplarını temizle
    cleaned = cleaned.replaceAll(
      RegExp(r'(javascript|vbscript|data)\s*:', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bon[a-z]+\s*=', caseSensitive: false),
      '',
    );

    // 5. SQL enjeksiyon kalıplarını temizle
    cleaned = cleaned.replaceAll(
      RegExp(
        r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|EXEC|TRUNCATE)\b\s+(TABLE|FROM|INTO|ALL|SELECT)?)|('+\s*(OR|AND)\s+'?\d+'?\s*=\s*'?\d+'?)|(--|/\*|\*/|;)",
        caseSensitive: false,
      ),
      '',
    );

    // 6. NoSQL ($ne, $gt, $where, $regex vb.) ve tehlikeli kabuk/kontrol sembollerini kaldır
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\$(where|gt|gte|lt|lte|ne|nin|in|regex|expr|function)\b',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp("[<>\"'`\\\\{};\$]"), '');

    // 7. Küfür filtresi
    if (maskProfanity) {
      for (final word in _profanityList) {
        final pattern = RegExp(
          '(^|[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ])(${RegExp.escape(word)})(?=\$|[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ])',
          caseSensitive: false,
        );
        cleaned = cleaned.replaceAllMapped(
          pattern,
          (m) => '${m.group(1)}***',
        );
      }
    }

    // 8. Boşluk normalizasyonu
    if (allowSpaces) {
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    } else {
      cleaned = cleaned.replaceAll(RegExp(r'\s+'), '').trim();
    }

    // 9. Maksimum uzunluk sınırı
    if (cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength).trim();
    }

    return cleaned;
  }

  /// Kullanıcı adı, e-posta ve şifre bilgilerini güvenlik ve format açısından
  /// doğrular.
  CredentialValidationResult validateCredentials({
    String? username,
    String? email,
    required String password,
    int minUsernameLength = 3,
    int maxUsernameLength = 20,
    int minPasswordLength = 6,
    int maxPasswordLength = 128,
  }) {
    final errors = <String>[];

    // 1. Kullanıcı adı kontrolü (verilmişse veya e-posta yoksa zorunlu)
    var cleanUsername = '';
    if (username != null && username.trim().isNotEmpty) {
      final rawUser = username.trim();
      if (_containsInjectionOrControlChars(rawUser)) {
        errors.add('username_contains_unsafe_characters');
      }
      cleanUsername = sanitizeUserInput(
        rawUser.toLowerCase(),
        maxLength: maxUsernameLength,
        allowSpaces: false,
      ).replaceAll(RegExp(r'[^a-z0-9_]'), '');

      if (cleanUsername != rawUser.toLowerCase()) {
        errors.add('username_invalid_format');
      }
      if (cleanUsername.length < minUsernameLength) {
        errors.add('username_too_short');
      }
      if (rawUser.length > maxUsernameLength) {
        errors.add('username_too_long');
      }
      if (_containsProfanity(rawUser)) {
        errors.add('username_contains_profanity');
      }
    } else if (email == null || email.trim().isEmpty) {
      errors.add('username_or_email_required');
    }

    // 2. E-posta kontrolü (verilmişse)
    var cleanEmail = '';
    if (email != null && email.trim().isNotEmpty) {
      final rawEmail = email.trim().toLowerCase();
      if (_containsInjectionOrControlChars(rawEmail) || rawEmail.length > 254) {
        errors.add('email_unsafe_or_too_long');
      }
      final emailRegex = RegExp(
        r'^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$',
      );
      if (!emailRegex.hasMatch(rawEmail)) {
        errors.add('email_invalid_format');
      } else {
        cleanEmail = rawEmail;
      }
    }

    // 3. Şifre güvenliği kontrolü
    if (password.isEmpty) {
      errors.add('password_empty');
    } else {
      if (password.length < minPasswordLength) {
        errors.add('password_too_short');
      }
      if (password.length > maxPasswordLength) {
        errors.add('password_too_long');
      }
      if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(password)) {
        errors.add('password_contains_control_chars');
      }
      final weakPasswords = <String>{
        '123456',
        '12345678',
        'password',
        'qwerty',
        '000000',
        '111111',
        'lululu',
      };
      if (weakPasswords.contains(password.toLowerCase())) {
        errors.add('password_too_common');
      }
    }

    final isValid = errors.isEmpty;
    return CredentialValidationResult(
      isValid: isValid,
      sanitizedUsername: cleanUsername,
      sanitizedEmail: cleanEmail,
      reason: isValid ? 'ok' : errors.first,
      errors: List<String>.unmodifiable(errors),
    );
  }

  static bool _containsInjectionOrControlChars(String value) {
    if (RegExp(r'[\x00-\x1F\x7F<>\"' "'" r'`\\{};\$]').hasMatch(value)) {
      return true;
    }
    if (RegExp(
      r'<\s*script|javascript:|--|\b(DROP|SELECT|UNION|INSERT|DELETE)\b',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }
    return false;
  }

  static bool _containsProfanity(String value) {
    final lower = value.toLowerCase();
    for (final word in _profanityList) {
      if (lower.contains(word)) {
        return true;
      }
    }
    return false;
  }
}
