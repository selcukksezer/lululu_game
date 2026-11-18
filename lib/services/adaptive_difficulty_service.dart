import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 11 oyun modunun her biri için referans skor ve refleks hızı (ms) taban
/// değerlerini tanımlayan yapılandırma.
@immutable
class GameModeBaselineConfig {
  const GameModeBaselineConfig({
    required this.modeId,
    required this.displayName,
    required this.targetScore,
    required this.targetReflexMs,
    this.minReflexMs = 120.0,
    this.maxReflexMs = 2500.0,
  });

  final String modeId;
  final String displayName;
  final double targetScore;
  final double targetReflexMs;
  final double minReflexMs;
  final double maxReflexMs;
}

/// Tek bir maçın performans kaydını temsil eden değişmez (immutable) veri modeli.
@immutable
class MatchPerformanceSample {
  const MatchPerformanceSample({
    required this.modeId,
    required this.score,
    required this.won,
    required this.reflexMs,
    required this.durationSeconds,
    required this.timestampMs,
  });

  final String modeId;
  final int score;
  final bool won;
  final double reflexMs;
  final int durationSeconds;
  final int timestampMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'modeId': modeId,
        'score': score,
        'won': won,
        'reflexMs': reflexMs,
        'durationSeconds': durationSeconds,
        'timestampMs': timestampMs,
      };

  factory MatchPerformanceSample.fromJson(Map<String, dynamic> json) {
    final rawScore = (json['score'] as num?)?.toDouble() ?? 0.0;
    final rawReflex = (json['reflexMs'] as num?)?.toDouble() ?? 600.0;
    final rawDuration = (json['durationSeconds'] as num?)?.toDouble() ?? 30.0;
    final rawTs = (json['timestampMs'] as num?)?.toInt() ?? 0;

    return MatchPerformanceSample(
      modeId: (json['modeId'] as String?) ?? 'suika',
      score: rawScore.isFinite && rawScore >= 0 ? rawScore.round() : 0,
      won: json['won'] == true,
      reflexMs: rawReflex.isFinite && rawReflex > 0
          ? rawReflex.clamp(120.0, 5000.0)
          : 600.0,
      durationSeconds: rawDuration.isFinite && rawDuration >= 1
          ? rawDuration.round().clamp(1, 7200)
          : 30,
      timestampMs: rawTs < 0 ? 0 : rawTs,
    );
  }
}

/// Bir oyun modundaki oyuncu performans istatistiklerinin anlık özeti.
@immutable
class ModePerformanceStats {
  const ModePerformanceStats({
    required this.modeId,
    required this.matchesPlayed,
    required this.winStreak,
    required this.lossStreak,
    required this.averageScore,
    required this.averageReflexMs,
    required this.recentWinRate,
    required this.recentSamples,
  });

  final String modeId;
  final int matchesPlayed;
  final int winStreak;
  final int lossStreak;
  final double averageScore;
  final double averageReflexMs;
  final double recentWinRate;
  final List<MatchPerformanceSample> recentSamples;
}

/// [AdaptiveDifficultyService] tarafından bir oyun modu için hesaplanan
/// deterministik zorluk ve destek profili.
@immutable
class AdaptiveDifficultyProfile {
  const AdaptiveDifficultyProfile({
    required this.modeId,
    required this.isMercyBoostActive,
    required this.speedMultiplier,
    required this.spawnFavorability,
    required this.bonusStartingBoosters,
    required this.skillScoreBonusMultiplier,
    required this.winStreak,
    required this.lossStreak,
    required this.averageScore,
    required this.averageReflexMs,
    required this.difficultyTierLabel,
  });

  /// Kanonik oyun modu kimliği (`suika`, `grid2048`, `balloon`, `match3`,
  /// `connect`, `stack`, `terlik`, `yuva`, `osmantus`, `scream`, `makara`).
  final String modeId;

  /// Üst üste 3 veya daha fazla yenilgide (`lossStreak >= 3`) aktifleşen
  /// Merhamet Desteği (Mercy Boost) durumu.
  final bool isMercyBoostActive;

  /// Düşman, engel veya akış hızı çarpanı (`0.88`..`1.35`).
  /// - Merhamet Desteğinde `%12` yumuşatılır (`0.88`).
  /// - Kazanma serisinde kademeli olarak `1.35` tavanına kadar hızlanır.
  final double speedMultiplier;

  /// Uygun böcek/taş dağılımı olasılık çarpanı (`0.85`..`1.25`).
  /// - Merhamet Desteğinde `1.15`..`1.25` aralığına çıkarak oyuncuya daha
  ///   uygun taş/böcek kombinasyonları sunar.
  /// - Yüksek kazanma serisinde `0.85` tabanına doğru dengelenir.
  final double spawnFavorability;

  /// Maç başında oyuncuya verilen ekstra yardımcı güçlendirici sayısı (`0`..`2`).
  /// - Merhamet Desteği aktifken (`lossStreak >= 3`) en az `+1` güçlendirici sağlar.
  final int bonusStartingBoosters;

  /// Ustalık Skor Çarpanı (`1.0`..`1.5`).
  /// - Kazanma serisi, yüksek ortalama skor ve hızlı refleks ile `1.5x`
  ///   tavanına kadar artar.
  final double skillScoreBonusMultiplier;

  final int winStreak;
  final int lossStreak;
  final double averageScore;
  final double averageReflexMs;
  final String difficultyTierLabel;

  @override
  String toString() =>
      'AdaptiveDifficultyProfile(mode: $modeId, mercy: $isMercyBoostActive, '
      'speed: ${speedMultiplier.toStringAsFixed(2)}, '
      'favorability: ${spawnFavorability.toStringAsFixed(2)}, '
      'boosters: +$bonusStartingBoosters, '
      'skillBonus: ${skillScoreBonusMultiplier.toStringAsFixed(2)}x, '
      'winStreak: $winStreak, lossStreak: $lossStreak)';
}

/// 11 Oyun Modu İçin Akıllı Adaptif Zorluk (Dynamic Difficulty Adjustment - DDA) Motoru.
///
/// Sorumluluklar:
/// 1. Oyuncunun 11 oyun modundaki (`suika`, `grid2048`, `balloon`, `match3`,
///    `connect`, `stack`, `terlik`, `yuva`, `osmantus`, `scream`, `makara`)
///    son maç sonuçlarını, kazanma/kaybetme serisini (`winStreak`, `lossStreak`),
///    ortalama skorunu ve refleks hızını analiz eder.
/// 2. Üst üste 3+ yenilgide **Merhamet Desteği (Mercy Boost)** devreye girer:
///    düşman/engel hızını `%12` yumuşatır (`speedMultiplier = 0.88`),
///    başlangıçta `+1` yardımcı güçlendirici (`bonusStartingBoosters >= 1`) ve
///    daha uygun böcek/taş dağılımı (`spawnFavorability`: `0.85`..`1.25`) sağlar.
/// 3. Üst üste kazanma serisinde ise akıcı biçimde tempo
///    (`speedMultiplier`: `0.88`..`1.35`) ve **Ustalık Skor Çarpanı
///    (`skillScoreBonusMultiplier`: `1.0`..`1.5x`)** sunar.
/// 4. Tüm hesaplamalar deterministik sınırlar (`clamp`) içinde çalışır; hiçbir
///    koşulda `NaN`, `Infinity` veya negatif değer üretmez.
class AdaptiveDifficultyService {
  AdaptiveDifficultyService({int maxHistoryPerMode = 15})
      : maxHistoryPerMode = maxHistoryPerMode.clamp(3, 50);

  static final AdaptiveDifficultyService instance = AdaptiveDifficultyService();

  static const String _prefsStorageKey = 'lululu_adaptive_difficulty_v1';

  /// Merhamet Desteği (Mercy Boost) için gereken minimum ardışık yenilgi sayısı.
  static const int mercyLossStreakThreshold = 3;

  /// Merhamet Desteğinde düşman/engel hızını %12 yumuşatan çarpan (`1.0 - 0.12 = 0.88`).
  static const double minSpeedMultiplier = 0.88;

  /// Maksimum tempo hız çarpanı.
  static const double maxSpeedMultiplier = 1.35;

  /// Minimum taş/böcek dağılım uygunluğu sınırı.
  static const double minSpawnFavorability = 0.85;

  /// Maksimum taş/böcek dağılım uygunluğu sınırı.
  static const double maxSpawnFavorability = 1.25;

  /// Minimum ustalık skor çarpanı.
  static const double minSkillScoreMultiplier = 1.0;

  /// Maksimum ustalık skor çarpanı.
  static const double maxSkillScoreMultiplier = 1.5;

  /// Her bir oyun modu için tutulan maksimum son maç sayısı.
  final int maxHistoryPerMode;

  /// 11 resmi oyun modunun kanonik anahtar listesi.
  static const List<String> supportedModes = <String>[
    'suika',
    'grid2048',
    'balloon',
    'match3',
    'connect',
    'stack',
    'terlik',
    'yuva',
    'osmantus',
    'scream',
    'makara',
  ];

  /// 11 oyun modunun her biri için referans hedef skor ve refleks süreleri.
  static const Map<String, GameModeBaselineConfig> modeBaselines =
      <String, GameModeBaselineConfig>{
    'suika': GameModeBaselineConfig(
      modeId: 'suika',
      displayName: 'Suika Kavanoz Birleşimi',
      targetScore: 3500.0,
      targetReflexMs: 550.0,
    ),
    'grid2048': GameModeBaselineConfig(
      modeId: 'grid2048',
      displayName: '2048 Böcek Izgarası',
      targetScore: 6000.0,
      targetReflexMs: 520.0,
    ),
    'balloon': GameModeBaselineConfig(
      modeId: 'balloon',
      displayName: 'Balon Patlatma',
      targetScore: 2200.0,
      targetReflexMs: 380.0,
    ),
    'match3': GameModeBaselineConfig(
      modeId: 'match3',
      displayName: '3\'lü Eşleştirme',
      targetScore: 4000.0,
      targetReflexMs: 500.0,
    ),
    'connect': GameModeBaselineConfig(
      modeId: 'connect',
      displayName: 'Çizgiyle Bağla',
      targetScore: 3600.0,
      targetReflexMs: 480.0,
    ),
    'stack': GameModeBaselineConfig(
      modeId: 'stack',
      displayName: 'Kule İstifleme',
      targetScore: 1800.0,
      targetReflexMs: 340.0,
    ),
    'terlik': GameModeBaselineConfig(
      modeId: 'terlik',
      displayName: 'Terlik Şaplağı',
      targetScore: 2500.0,
      targetReflexMs: 310.0,
    ),
    'yuva': GameModeBaselineConfig(
      modeId: 'yuva',
      displayName: 'Yuva Savunması',
      targetScore: 3200.0,
      targetReflexMs: 360.0,
    ),
    'osmantus': GameModeBaselineConfig(
      modeId: 'osmantus',
      displayName: 'Osmantuş Ritim',
      targetScore: 3000.0,
      targetReflexMs: 330.0,
    ),
    'scream': GameModeBaselineConfig(
      modeId: 'scream',
      displayName: 'Çığlık Koşusu',
      targetScore: 2400.0,
      targetReflexMs: 400.0,
    ),
    'makara': GameModeBaselineConfig(
      modeId: 'makara',
      displayName: 'Makarayız Ritim',
      targetScore: 2800.0,
      targetReflexMs: 350.0,
    ),
  };

  final Map<String, List<MatchPerformanceSample>> _historyByMode =
      <String, List<MatchPerformanceSample>>{};
  final Map<String, int> _winStreakByMode = <String, int>{};
  final Map<String, int> _lossStreakByMode = <String, int>{};

  /// Farklı yazım biçimlerini (`terlikTap`, `terlik_tap`, `terlik`,
  /// `yuvaDefense`, `screamRoach`, `makarayiz`, `grid_2048` vb.) 11 kanonik
  /// DDA mod anahtarına dönüştürür. Tanınmayan modlar için `null` döner.
  static String? tryResolveModeKey(String rawMode) {
    final cleaned =
        rawMode.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
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
      case 'terlik':
      case 'terliktap':
      case 'terlik_tap':
        return 'terlik';
      case 'yuva':
      case 'yuvadefense':
      case 'yuva_defense':
        return 'yuva';
      case 'osmantus':
        return 'osmantus';
      case 'scream':
      case 'screamroach':
      case 'scream_roach':
      case 'ciglik':
        return 'scream';
      case 'makara':
      case 'makarayiz':
        return 'makara';
      default:
        return null;
    }
  }

  /// Mod anahtarını kanonik isme çözümler; bilinmiyorsa varsayılan olarak `'suika'` döner.
  static String resolveModeKey(String rawMode) =>
      tryResolveModeKey(rawMode) ?? 'suika';

  /// Sayısal bir girdiyi `NaN`, `Infinity` ve sınır dışı değerlere karşı
  /// güvenli biçimde temizler.
  static double _sanitizeDouble(
    num? value, {
    required double fallback,
    required double min,
    required double max,
  }) {
    if (value == null) return fallback.clamp(min, max);
    final d = value.toDouble();
    if (d.isNaN || d.isInfinite) {
      return fallback.clamp(min, max);
    }
    return d.clamp(min, max);
  }

  static int _sanitizeNonNegativeInt(num? value, {int max = 1000000}) {
    if (value == null) return 0;
    final d = value.toDouble();
    if (d.isNaN || d.isInfinite || d <= 0) {
      return 0;
    }
    return d.round().clamp(0, max);
  }

  /// Bir maç sonucunu kaydeder, serileri (`winStreak` / `lossStreak`) günceller
  /// ve o mod için yeni [AdaptiveDifficultyProfile] değerini döndürür.
  AdaptiveDifficultyProfile recordMatchResult({
    required String mode,
    required num score,
    required bool won,
    num? reflexMs,
    num? durationSeconds,
    int? timestampMs,
  }) {
    final canonicalMode = resolveModeKey(mode);
    final baseline = modeBaselines[canonicalMode]!;

    final safeScore = _sanitizeNonNegativeInt(score, max: 10000000);
    final safeReflexMs = _sanitizeDouble(
      reflexMs,
      fallback: baseline.targetReflexMs,
      min: baseline.minReflexMs,
      max: baseline.maxReflexMs,
    );
    final safeDuration = _sanitizeNonNegativeInt(
      durationSeconds ?? 30,
      max: 7200,
    ).clamp(1, 7200);
    final safeTimestamp = timestampMs != null && timestampMs > 0
        ? timestampMs
        : DateTime.now().millisecondsSinceEpoch;

    final sample = MatchPerformanceSample(
      modeId: canonicalMode,
      score: safeScore,
      won: won,
      reflexMs: safeReflexMs,
      durationSeconds: safeDuration,
      timestampMs: safeTimestamp,
    );

    final list = _historyByMode.putIfAbsent(
      canonicalMode,
      () => <MatchPerformanceSample>[],
    );
    list.add(sample);
    if (list.length > maxHistoryPerMode) {
      list.removeRange(0, list.length - maxHistoryPerMode);
    }

    if (won) {
      _winStreakByMode[canonicalMode] =
          ((_winStreakByMode[canonicalMode] ?? 0) + 1).clamp(0, 999);
      _lossStreakByMode[canonicalMode] = 0;
    } else {
      _lossStreakByMode[canonicalMode] =
          ((_lossStreakByMode[canonicalMode] ?? 0) + 1).clamp(0, 999);
      _winStreakByMode[canonicalMode] = 0;
    }

    return getProfileForMode(canonicalMode);
  }

  /// Belirtilen oyun modunun anlık performans istatistiklerini döndürür.
  ModePerformanceStats getStatsForMode(String mode) {
    final canonicalMode = resolveModeKey(mode);
    final baseline = modeBaselines[canonicalMode]!;
    final samples = _historyByMode[canonicalMode] ?? const <MatchPerformanceSample>[];
    final winStreak = (_winStreakByMode[canonicalMode] ?? 0).clamp(0, 999);
    final lossStreak = (_lossStreakByMode[canonicalMode] ?? 0).clamp(0, 999);

    if (samples.isEmpty) {
      return ModePerformanceStats(
        modeId: canonicalMode,
        matchesPlayed: 0,
        winStreak: winStreak,
        lossStreak: lossStreak,
        averageScore: 0.0,
        averageReflexMs: baseline.targetReflexMs,
        recentWinRate: 0.5,
        recentSamples: const <MatchPerformanceSample>[],
      );
    }

    var totalScore = 0.0;
    var totalReflex = 0.0;
    var wins = 0;
    for (final s in samples) {
      totalScore += s.score;
      totalReflex += s.reflexMs;
      if (s.won) wins++;
    }

    final avgScore = _sanitizeDouble(
      totalScore / samples.length,
      fallback: 0.0,
      min: 0.0,
      max: 10000000.0,
    );
    final avgReflex = _sanitizeDouble(
      totalReflex / samples.length,
      fallback: baseline.targetReflexMs,
      min: baseline.minReflexMs,
      max: baseline.maxReflexMs,
    );
    final winRate = _sanitizeDouble(
      wins / samples.length,
      fallback: 0.5,
      min: 0.0,
      max: 1.0,
    );

    return ModePerformanceStats(
      modeId: canonicalMode,
      matchesPlayed: samples.length,
      winStreak: winStreak,
      lossStreak: lossStreak,
      averageScore: avgScore,
      averageReflexMs: avgReflex,
      recentWinRate: winRate,
      recentSamples: List<MatchPerformanceSample>.unmodifiable(samples),
    );
  }

  /// Kayıtlı geçmiş üzerinden belirtilen oyun modunun adaptif zorluk profilini
  /// döndürür.
  AdaptiveDifficultyProfile getProfileForMode(String mode) {
    final stats = getStatsForMode(mode);
    return evaluateDifficulty(
      mode: stats.modeId,
      winStreak: stats.winStreak,
      lossStreak: stats.lossStreak,
      averageScore: stats.averageScore,
      averageReflexMs: stats.averageReflexMs,
    );
  }

  /// 11 oyun modunun tamamı için güncel zorluk profillerini harita olarak döndürür.
  Map<String, AdaptiveDifficultyProfile> getAllModeProfiles() {
    final result = <String, AdaptiveDifficultyProfile>{};
    for (final mode in supportedModes) {
      result[mode] = getProfileForMode(mode);
    }
    return Map<String, AdaptiveDifficultyProfile>.unmodifiable(result);
  }

  /// Verilen parametrelerle deterministik olarak [AdaptiveDifficultyProfile]
  /// hesaplar.
  ///
  /// Kurallar:
  /// - Üst üste 3+ yenilgide (`lossStreak >= 3`) **Merhamet Desteği (Mercy Boost)**:
  ///   - Düşman/engel hızı `%12` yumuşatılır (`speedMultiplier = 0.88`).
  ///   - Başlangıçta `+1` yardımcı güçlendirici (`bonusStartingBoosters = 1`,
  ///     5+ yenilgide bile deterministik sınır içinde `+1` veya `+2`).
  ///   - Daha uygun böcek/taş dağılımı (`spawnFavorability`: `1.15`..`1.25`).
  ///   - Ustalık skor çarpanı tabanda (`1.0`) kalır.
  /// - Üst üste kazanma serisinde (`winStreak > 0`):
  ///   - Tempo (`speedMultiplier`) `0.88`..`1.35` aralığında akıcı biçimde artar.
  ///   - Ustalık Skor Çarpanı (`skillScoreBonusMultiplier`) `1.0`..`1.5`
  ///     aralığında yükselir.
  ///   - `spawnFavorability` `0.85`..`1.0` aralığında dengelenir.
  AdaptiveDifficultyProfile evaluateDifficulty({
    required String mode,
    int? winStreak,
    int? lossStreak,
    num? averageScore,
    num? averageReflexMs,
  }) {
    final canonicalMode = resolveModeKey(mode);
    final baseline = modeBaselines[canonicalMode]!;

    final safeWinStreak = _sanitizeNonNegativeInt(winStreak, max: 999);
    final safeLossStreak = _sanitizeNonNegativeInt(lossStreak, max: 999);
    final safeAvgScore = _sanitizeDouble(
      averageScore,
      fallback: 0.0,
      min: 0.0,
      max: 10000000.0,
    );
    final safeAvgReflexMs = _sanitizeDouble(
      averageReflexMs,
      fallback: baseline.targetReflexMs,
      min: baseline.minReflexMs,
      max: baseline.maxReflexMs,
    );

    // Normalize edilmiş skor oranı (0.0 .. 2.0)
    final scoreRatio = _sanitizeDouble(
      safeAvgScore / baseline.targetScore,
      fallback: 0.0,
      min: 0.0,
      max: 2.0,
    );

    // Normalize edilmiş refleks çevikliği (0.0 = yavaş, 1.0 = çok hızlı)
    final reflexAgility = _sanitizeDouble(
      (baseline.targetReflexMs - safeAvgReflexMs) /
          (baseline.targetReflexMs - baseline.minReflexMs),
      fallback: 0.0,
      min: -0.5,
      max: 1.0,
    );

    final isMercy = safeLossStreak >= mercyLossStreakThreshold;

    double speedMultiplier;
    double spawnFavorability;
    int bonusBoosters;
    double skillScoreBonus;
    String tierLabel;

    if (isMercy) {
      // Merhamet Desteği (Mercy Boost):
      // Düşman/engel hızı %12 yumuşatılır (1.0 - 0.12 = 0.88).
      speedMultiplier = minSpeedMultiplier;
      // Taş/böcek dağılımı oyuncunun lehine artırılır (1.15 .. 1.25).
      final extraLoss = (safeLossStreak - mercyLossStreakThreshold).clamp(0, 5);
      spawnFavorability = (1.15 + extraLoss * 0.02)
          .clamp(minSpawnFavorability, maxSpawnFavorability);
      // Başlangıçta +1 yardımcı güçlendirici verilir.
      bonusBoosters = 1;
      skillScoreBonus = minSkillScoreMultiplier;
      tierLabel = 'mercy';
    } else if (safeLossStreak > 0 && safeWinStreak == 0) {
      // 1 veya 2 yenilgi: hafif yumuşatma, henüz tam Mercy Boost değil
      final mildSoftening = safeLossStreak * 0.04; // 0.04 veya 0.08
      speedMultiplier = (1.0 - mildSoftening)
          .clamp(minSpeedMultiplier, maxSpeedMultiplier);
      spawnFavorability = (1.0 + safeLossStreak * 0.05)
          .clamp(minSpawnFavorability, maxSpawnFavorability);
      bonusBoosters = 0;
      skillScoreBonus = minSkillScoreMultiplier;
      tierLabel = 'balanced';
    } else if (safeWinStreak > 0) {
      // Kazanma serisi: akıcı tempo artışı ve Ustalık Skor Çarpanı (1.0 .. 1.5x)
      final streakFactor = (safeWinStreak / 10.0).clamp(0.0, 1.0);
      final skillFactor =
          ((scoreRatio * 0.5) + (reflexAgility.clamp(0.0, 1.0) * 0.5))
              .clamp(0.0, 1.0);

      final rawSpeed = 1.0 + (streakFactor * 0.25) + (skillFactor * 0.10);
      speedMultiplier =
          rawSpeed.clamp(minSpeedMultiplier, maxSpeedMultiplier);

      final rawFavorability =
          1.0 - (streakFactor * 0.10) - (skillFactor * 0.05);
      spawnFavorability = rawFavorability.clamp(
        minSpawnFavorability,
        maxSpawnFavorability,
      );

      final rawSkillBonus =
          1.0 + (safeWinStreak * 0.06) + (skillFactor * 0.14);
      skillScoreBonus = rawSkillBonus.clamp(
        minSkillScoreMultiplier,
        maxSkillScoreMultiplier,
      );

      bonusBoosters = 0;
      tierLabel = speedMultiplier >= 1.22 ? 'master' : 'skilled';
    } else {
      // Nötr başlangıç durumu (winStreak == 0 && lossStreak == 0)
      final mildSkill = (scoreRatio - 1.0).clamp(-0.2, 0.4) * 0.15;
      speedMultiplier =
          (1.0 + mildSkill).clamp(minSpeedMultiplier, maxSpeedMultiplier);
      spawnFavorability = 1.0.clamp(minSpawnFavorability, maxSpawnFavorability);
      bonusBoosters = 0;
      skillScoreBonus = (1.0 + (scoreRatio > 1.0 ? (scoreRatio - 1.0) * 0.1 : 0.0))
          .clamp(minSkillScoreMultiplier, maxSkillScoreMultiplier);
      tierLabel = 'balanced';
    }

    // Son güvenlik kalkanı: tüm değerlerin sonlu (finite), pozitif ve aralıkta olduğunu doğrula.
    final finalSpeed = _sanitizeDouble(
      speedMultiplier,
      fallback: 1.0,
      min: minSpeedMultiplier,
      max: maxSpeedMultiplier,
    );
    final finalFavorability = _sanitizeDouble(
      spawnFavorability,
      fallback: 1.0,
      min: minSpawnFavorability,
      max: maxSpawnFavorability,
    );
    final finalSkillBonus = _sanitizeDouble(
      skillScoreBonus,
      fallback: 1.0,
      min: minSkillScoreMultiplier,
      max: maxSkillScoreMultiplier,
    );
    final finalBoosters = bonusBoosters.clamp(0, 2);

    return AdaptiveDifficultyProfile(
      modeId: canonicalMode,
      isMercyBoostActive: isMercy,
      speedMultiplier: finalSpeed,
      spawnFavorability: finalFavorability,
      bonusStartingBoosters: finalBoosters,
      skillScoreBonusMultiplier: finalSkillBonus,
      winStreak: safeWinStreak,
      lossStreak: safeLossStreak,
      averageScore: safeAvgScore,
      averageReflexMs: safeAvgReflexMs,
      difficultyTierLabel: tierLabel,
    );
  }

  /// Belirli bir oyun modunun DDA geçmişini ve serilerini sıfırlar.
  void resetMode(String mode) {
    final canonicalMode = resolveModeKey(mode);
    _historyByMode.remove(canonicalMode);
    _winStreakByMode.remove(canonicalMode);
    _lossStreakByMode.remove(canonicalMode);
  }

  /// Tüm oyun modlarının DDA geçmişini sıfırlar.
  void resetAll() {
    _historyByMode.clear();
    _winStreakByMode.clear();
    _lossStreakByMode.clear();
  }

  /// Hesap silme için yerel zorluk geçmişinin tamamını temizler
  /// (hesap-silme, yerel-temizlik): bellek-içi geçmiş/seriler
  /// [resetAll] ile sıfırlanır, `lululu_adaptive_difficulty_v1`
  /// anahtarı prefs'ten kaldırılır. [resetAll] bilerek senkron
  /// bırakıldı — [loadFromJson] içinden çağrılır; prefs silmesi
  /// yalnız bu metotta yapılır.
  Future<void> clearLocalData() async {
    resetAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsStorageKey);
  }

  /// Durumu JSON haritasına dönüştürür.
  Map<String, dynamic> toJson() {
    final historyJson = <String, dynamic>{};
    _historyByMode.forEach((mode, samples) {
      historyJson[mode] = samples.map((s) => s.toJson()).toList(growable: false);
    });
    return <String, dynamic>{
      'winStreaks': Map<String, int>.from(_winStreakByMode),
      'lossStreaks': Map<String, int>.from(_lossStreakByMode),
      'history': historyJson,
    };
  }

  /// JSON haritasından durumu geri yükler.
  void loadFromJson(Map<String, dynamic> data) {
    resetAll();
    final rawWinStreaks = data['winStreaks'];
    if (rawWinStreaks is Map) {
      rawWinStreaks.forEach((key, value) {
        final mode = tryResolveModeKey(key.toString());
        if (mode != null && value is num) {
          _winStreakByMode[mode] = _sanitizeNonNegativeInt(value, max: 999);
        }
      });
    }
    final rawLossStreaks = data['lossStreaks'];
    if (rawLossStreaks is Map) {
      rawLossStreaks.forEach((key, value) {
        final mode = tryResolveModeKey(key.toString());
        if (mode != null && value is num) {
          _lossStreakByMode[mode] = _sanitizeNonNegativeInt(value, max: 999);
        }
      });
    }
    final rawHistory = data['history'];
    if (rawHistory is Map) {
      rawHistory.forEach((key, value) {
        final mode = tryResolveModeKey(key.toString());
        if (mode != null && value is Iterable) {
          final parsed = <MatchPerformanceSample>[];
          for (final item in value) {
            if (item is Map<String, dynamic>) {
              parsed.add(MatchPerformanceSample.fromJson(item));
            } else if (item is Map) {
              parsed.add(
                MatchPerformanceSample.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              );
            }
          }
          if (parsed.length > maxHistoryPerMode) {
            parsed.removeRange(0, parsed.length - maxHistoryPerMode);
          }
          _historyByMode[mode] = parsed;
        }
      });
    }
  }

  /// Yerel depolamaya (`SharedPreferences`) kaydeder.
  Future<void> saveToPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsStorageKey, jsonEncode(toJson()));
  }

  /// Yerel depolamadan (`SharedPreferences`) yükler.
  Future<void> loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        loadFromJson(decoded);
      }
    } catch (_) {
      // Bozuk veri durumunda güvenli varsayılanlarla devam et.
    }
  }
}
