import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/campaign_level.dart';
import 'progress_manager.dart';

/// Bölüm yıldız sandığı ödül özeti.
class ChapterChestReward {
  final int chapterIndex;
  final int milestoneStars;
  final int coinsGranted;
  final String boosterKey;
  final int boosterCount;

  const ChapterChestReward({
    required this.chapterIndex,
    required this.milestoneStars,
    required this.coinsGranted,
    required this.boosterKey,
    required this.boosterCount,
  });
}

/// Seviye tamamlanma sonucu özeti.
class LevelCompletionSummary {
  final int levelNumber;
  final int starsEarned;
  final int previousStars;
  final int bestScore;
  final int coinsAwarded;
  final int bossFirstClearBonusCoins;
  final bool isNewCompletion;

  const LevelCompletionSummary({
    required this.levelNumber,
    required this.starsEarned,
    required this.previousStars,
    required this.bestScore,
    required this.coinsAwarded,
    required this.bossFirstClearBonusCoins,
    required this.isNewCompletion,
  });
}

/// 80 seviyeli kampanya, 8 temalı bölüm, yıldız sandıkları ve Boss savaşları ilerleme servisi.
class CampaignProgressionService extends ChangeNotifier {
  static final CampaignProgressionService _instance =
      CampaignProgressionService._internal();
  factory CampaignProgressionService() => _instance;
  static CampaignProgressionService get instance => _instance;
  CampaignProgressionService._internal();

  static const String _starsPrefKey = 'lululu_campaign_stars_v2';
  static const String _scoresPrefKey = 'lululu_campaign_scores_v2';
  static const String _completedPrefKey = 'lululu_campaign_completed_v2';
  static const String _bossClearedPrefKey = 'lululu_campaign_boss_cleared_v2';
  static const String _claimedChestsPrefKey = 'lululu_campaign_chests_v2';

  static const List<int> validChestMilestones = [10, 20, 30];

  final Map<int, int> _levelStars = <int, int>{};
  final Map<int, int> _levelHighScores = <int, int>{};
  final Set<int> _completedLevels = <int>{};
  final Set<int> _bossFirstClearedLevels = <int>{};
  final Set<String> _claimedChapterChests = <String>{};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Kalıcı kampanya verilerini `SharedPreferences` ve `ProgressManager.instance` üzerinden yükler.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final pm = ProgressManager.instance;

    _levelStars.clear();
    _levelHighScores.clear();
    _completedLevels.clear();
    _bossFirstClearedLevels.clear();
    _claimedChapterChests.clear();

    final starsRaw = prefs.getString(_starsPrefKey);
    if (starsRaw != null && starsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(starsRaw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null && id >= 1 && id <= CampaignDatabase.totalLevels) {
            final s = (v as num).toInt().clamp(0, 3);
            if (s > 0) {
              _levelStars[id] = s;
              _completedLevels.add(id);
            }
          }
        });
      } catch (_) {}
    }

    final scoresRaw = prefs.getString(_scoresPrefKey);
    if (scoresRaw != null && scoresRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(scoresRaw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          final id = int.tryParse(k);
          if (id != null && id >= 1 && id <= CampaignDatabase.totalLevels) {
            final sc = (v as num).toInt();
            if (sc > 0) {
              _levelHighScores[id] = sc;
            }
          }
        });
      } catch (_) {}
    }

    final completedList = prefs.getStringList(_completedPrefKey);
    if (completedList != null) {
      for (final item in completedList) {
        final id = int.tryParse(item);
        if (id != null && id >= 1 && id <= CampaignDatabase.totalLevels) {
          _completedLevels.add(id);
        }
      }
    }

    final bossClearedList = prefs.getStringList(_bossClearedPrefKey);
    if (bossClearedList != null) {
      for (final item in bossClearedList) {
        final id = int.tryParse(item);
        if (id != null && id >= 1 && id <= CampaignDatabase.totalLevels) {
          _bossFirstClearedLevels.add(id);
        }
      }
    }

    final chestsList = prefs.getStringList(_claimedChestsPrefKey);
    if (chestsList != null) {
      _claimedChapterChests.addAll(chestsList);
    }

    // ProgressManager.instance ile çift yönlü senkronizasyon
    for (int id = 1; id <= CampaignDatabase.totalLevels; id++) {
      final pmStars = pm.getStarCount(id).clamp(0, 3);
      final localStars = _levelStars[id] ?? 0;
      if (pmStars > localStars) {
        _levelStars[id] = pmStars;
        if (pmStars > 0) _completedLevels.add(id);
      }

      final pmScore = pm.getHighScore(id);
      final localScore = _levelHighScores[id] ?? 0;
      if (pmScore > localScore) {
        _levelHighScores[id] = pmScore;
      }
    }

    _loaded = true;
    await _persistToPrefs(prefs);
    notifyListeners();
  }

  /// Test ve sıfırlama senaryoları için bellek ve tercihleri temizler.
  Future<void> resetForTesting() async {
    _levelStars.clear();
    _levelHighScores.clear();
    _completedLevels.clear();
    _bossFirstClearedLevels.clear();
    _claimedChapterChests.clear();
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_starsPrefKey);
    await prefs.remove(_scoresPrefKey);
    await prefs.remove(_completedPrefKey);
    await prefs.remove(_bossClearedPrefKey);
    await prefs.remove(_claimedChestsPrefKey);
    notifyListeners();
  }

  /// Seviye için kazanılan yıldız sayısını (`0..3`) döndürür.
  int getStarsForLevel(int levelNumber) {
    final safeId = levelNumber.clamp(1, CampaignDatabase.totalLevels);
    final local = _levelStars[safeId] ?? 0;
    final pmStars = ProgressManager.instance.getStarCount(safeId).clamp(0, 3);
    return local >= pmStars ? local : pmStars;
  }

  /// Seviye için kaydedilen en yüksek skoru döndürür.
  int getHighScoreForLevel(int levelNumber) {
    final safeId = levelNumber.clamp(1, CampaignDatabase.totalLevels);
    final local = _levelHighScores[safeId] ?? 0;
    final pmScore = ProgressManager.instance.getHighScore(safeId);
    return local >= pmScore ? local : pmScore;
  }

  /// Seviyenin tamamlanıp tamamlanmadığını döndürür.
  bool isLevelCompleted(int levelNumber) {
    if (levelNumber < 1 || levelNumber > CampaignDatabase.totalLevels) {
      return false;
    }
    return _completedLevels.contains(levelNumber) ||
        getStarsForLevel(levelNumber) > 0;
  }

  /// Seviyenin kilitli olup olmadığını kontrol eder.
  bool isLevelUnlocked(int levelNumber) {
    if (levelNumber < 1 || levelNumber > CampaignDatabase.totalLevels) {
      return false;
    }
    if (levelNumber == 1) return true;
    return ProgressManager.instance.isLevelUnlocked(levelNumber) ||
        isLevelCompleted(levelNumber - 1);
  }

  /// Boss seviyesinin ilk geçiş ödülünün alınıp alınmadığını döndürür.
  bool isBossFirstCleared(int levelNumber) {
    return _bossFirstClearedLevels.contains(levelNumber);
  }

  /// Belirli bir temalı bölümdeki (`1..8`) toplam yıldız sayısını (`0..30`) hesaplar.
  int getChapterStars(int chapterIndex) {
    final levels = CampaignDatabase.getLevelsForThemedChapter(chapterIndex);
    var sum = 0;
    for (final level in levels) {
      sum += getStarsForLevel(level.id);
    }
    return sum.clamp(0, CampaignDatabase.levelsPerThemedChapter * 3);
  }

  /// Tüm 80 seviyedeki toplam yıldız sayısını (`0..240`) döndürür.
  int get totalCampaignStars {
    var sum = 0;
    for (int id = 1; id <= CampaignDatabase.totalLevels; id++) {
      sum += getStarsForLevel(id);
    }
    return sum;
  }

  /// Skor ve kalan hamle/süreye göre `0..3` yıldız hesaplar.
  ///
  /// Kalan her hamle (`remainingMoves > 0`), efektif değerlendirme skoruna
  /// `remainingMoves * 45` puan katkı sağlar.
  int calculateStarsForLevel(
    int levelNumber,
    int score, {
    int remainingMoves = 0,
  }) {
    if (score <= 0) return 0;
    final level = CampaignDatabase.getLevel(levelNumber);
    final safeRemaining = remainingMoves < 0 ? 0 : remainingMoves;
    final effectiveScore = score + (safeRemaining * 45);

    if (effectiveScore >= level.star3Score) {
      return 3;
    }
    if (effectiveScore >= level.star2Score) {
      return 2;
    }
    if (effectiveScore >= level.star1Score) {
      return 1;
    }
    return 0;
  }

  /// Boss savaşı hasar hesaplama yardımcısı.
  ///
  /// Birleştirilen böcek kademesi (`mergedTier >= 1`) ve kombo sayısına (`comboCount >= 1`)
  /// göre deterministik Boss hasarı üretir.
  int calculateBossDamage({
    required int mergedTier,
    required int comboCount,
  }) {
    final safeTier = mergedTier.clamp(1, 13);
    final safeCombo = comboCount.clamp(1, 50);
    final baseDamage = safeTier * 40 + (safeTier * safeTier * 8);
    final comboMultiplier = 1.0 + ((safeCombo - 1) * 0.25);
    return (baseDamage * comboMultiplier).round();
  }

  /// Seviye tamamlandığında yıldız, en yüksek skor ve tamamlanma durumunu
  /// `SharedPreferences` ve `ProgressManager.instance` ile senkronize ederek kaydeder.
  ///
  /// Tamamlanma, yıldızdan değil zaferden okunur (S1#23 yan etkisi):
  /// [victory] `true` ise 0 yıldızlı zafer de tamamlanma sayılır (sonraki
  /// seviye açılır, ilk geçiş ödülleri verilir, önceki yıldız ezilmez);
  /// `false` ise yalnız yüksek skor güncellenir, kilit açılmaz ve
  /// tamamlanma işaretlenmez. [victory] verilmezse (`null`, varsayılan)
  /// eski davranış korunur: tamamlanma yıldız > 0 ile eşdeğerdir.
  Future<LevelCompletionSummary> recordLevelCompletion({
    required int levelNumber,
    required int score,
    int remainingMoves = 0,
    int? explicitStars,
    bool? victory,
  }) async {
    final safeId = levelNumber.clamp(1, CampaignDatabase.totalLevels);
    final level = CampaignDatabase.getLevel(safeId);
    final calculatedStars = explicitStars != null
        ? explicitStars.clamp(0, 3)
        : calculateStarsForLevel(
            safeId,
            score,
            remainingMoves: remainingMoves,
          );

    final prevStars = getStarsForLevel(safeId);
    final prevScore = getHighScoreForLevel(safeId);
    final wasCompleted = isLevelCompleted(safeId);

    final nextStars = calculatedStars > prevStars ? calculatedStars : prevStars;
    final nextScore = score > prevScore ? score : prevScore;

    // Zafer bilgisi verilmezse eski kural aynen korunur: tamamlanma = yıldız > 0.
    final completed = victory ?? (calculatedStars > 0);

    _levelHighScores[safeId] = nextScore;

    int coinsAwarded = 0;
    int bossBonus = 0;

    if (completed) {
      // Yıldız haritası yalnız yıldız kazanıldığında yazılır: 0 yıldızlı
      // zafer önceki yıldızı ezmez.
      if (calculatedStars > 0) {
        _levelStars[safeId] = nextStars;
      }
      _completedLevels.add(safeId);

      // ProgressManager.recordLevelResult starGain*50 altin verir ve sonraki seviyeyi acar
      final coinsBefore = ProgressManager.instance.coins;
      await ProgressManager.instance.recordLevelResult(
        levelId: safeId,
        score: nextScore,
        stars: calculatedStars,
        victory: true,
      );
      coinsAwarded += (ProgressManager.instance.coins - coinsBefore);

      // İlk kez tamamlanan seviyede seviye taban ödülü + Boss ilk geçiş bonusu
      if (!wasCompleted) {
        await ProgressManager.instance.addCoins(level.rewardCoins);
        coinsAwarded += level.rewardCoins;
      }

      if (level.isBossLevel &&
          !_bossFirstClearedLevels.contains(safeId) &&
          level.firstClearBonusCoins > 0) {
        _bossFirstClearedLevels.add(safeId);
        bossBonus = level.firstClearBonusCoins;
        await ProgressManager.instance.addCoins(bossBonus);
        coinsAwarded += bossBonus;
      }
    } else if (score > prevScore) {
      // Yenilgi / tamamlanmama: yalnız yüksek skor güncellenir, kilit açılmaz.
      await ProgressManager.instance.recordLevelResult(
        levelId: safeId,
        score: nextScore,
        stars: 0,
        victory: false,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await _persistToPrefs(prefs);
    notifyListeners();

    return LevelCompletionSummary(
      levelNumber: safeId,
      starsEarned: calculatedStars,
      previousStars: prevStars,
      bestScore: nextScore,
      coinsAwarded: coinsAwarded,
      bossFirstClearBonusCoins: bossBonus,
      isNewCompletion: !wasCompleted && completed,
    );
  }

  static String _chestKey(int chapterIndex, int milestoneStars) =>
      'ch_${chapterIndex}_stars_$milestoneStars';

  /// Bölüm sandığının daha önce açılıp açılmadığını döndürür.
  bool isChapterChestClaimed(int chapterIndex, int milestoneStars) {
    return _claimedChapterChests.contains(
      _chestKey(chapterIndex, milestoneStars),
    );
  }

  /// Bölüm sandığının şu an açılabilir olup olmadığını döndürür (`10, 20, 30` yıldız).
  bool canClaimChapterChest(int chapterIndex, int milestoneStars) {
    if (chapterIndex < 1 ||
        chapterIndex > CampaignDatabase.themedChapterCount) {
      return false;
    }
    if (!validChestMilestones.contains(milestoneStars)) {
      return false;
    }
    if (isChapterChestClaimed(chapterIndex, milestoneStars)) {
      return false;
    }
    return getChapterStars(chapterIndex) >= milestoneStars;
  }

  /// Belirli bir bölüm (`1..8`) ve yıldız eşiği (`10, 20, 30`) için sandık ödül tanımını döndürür.
  ChapterChestReward previewChapterChestReward(
    int chapterIndex,
    int milestoneStars,
  ) {
    final safeCh = chapterIndex.clamp(1, CampaignDatabase.themedChapterCount);
    switch (milestoneStars) {
      case 10:
        return ChapterChestReward(
          chapterIndex: safeCh,
          milestoneStars: 10,
          coinsGranted: 150 + (safeCh * 25),
          boosterKey: 'raid',
          boosterCount: 1,
        );
      case 20:
        return ChapterChestReward(
          chapterIndex: safeCh,
          milestoneStars: 20,
          coinsGranted: 300 + (safeCh * 40),
          boosterKey: 'terlik',
          boosterCount: 2,
        );
      case 30:
      default:
        return ChapterChestReward(
          chapterIndex: safeCh,
          milestoneStars: 30,
          coinsGranted: 600 + (safeCh * 75),
          boosterKey: 'f16',
          boosterCount: 2,
        );
    }
  }

  /// Bölümde `10, 20, 30` yıldız toplandığında açılan **Bölüm Yıldız Sandığı** ödülünü verir.
  ///
  /// Altın ödülünü `ProgressManager.instance.addCoins` ve güçlendirici ödülünü
  /// `ProgressManager.instance.incrementPowerCount` üzerinden kalıcı olarak ekler.
  Future<ChapterChestReward?> claimChapterChest(
    int chapterIndex,
    int milestoneStars,
  ) async {
    if (!canClaimChapterChest(chapterIndex, milestoneStars)) {
      return null;
    }

    final reward = previewChapterChestReward(chapterIndex, milestoneStars);
    final key = _chestKey(chapterIndex, milestoneStars);
    _claimedChapterChests.add(key);

    await ProgressManager.instance.addCoins(reward.coinsGranted);
    await ProgressManager.instance.incrementPowerCount(
      reward.boosterKey,
      reward.boosterCount,
    );

    final prefs = await SharedPreferences.getInstance();
    await _persistToPrefs(prefs);
    notifyListeners();
    return reward;
  }

  /// Test veya senaryo kurulumları için belirli bir seviyeye doğrudan yıldız atar.
  Future<void> setStarsForLevel(
    int levelNumber,
    int stars, {
    int? score,
  }) async {
    final safeId = levelNumber.clamp(1, CampaignDatabase.totalLevels);
    final safeStars = stars.clamp(0, 3);
    final level = CampaignDatabase.getLevel(safeId);
    final resolvedScore = score ??
        (safeStars == 3
            ? level.star3Score
            : safeStars == 2
                ? level.star2Score
                : safeStars == 1
                    ? level.star1Score
                    : 0);

    _levelStars[safeId] = safeStars;
    if (safeStars > 0) {
      _completedLevels.add(safeId);
    }
    if (resolvedScore > (_levelHighScores[safeId] ?? 0)) {
      _levelHighScores[safeId] = resolvedScore;
    }

    await ProgressManager.instance.recordLevelResult(
      levelId: safeId,
      score: resolvedScore,
      stars: safeStars,
    );

    final prefs = await SharedPreferences.getInstance();
    await _persistToPrefs(prefs);
    notifyListeners();
  }

  Future<void> _persistToPrefs(SharedPreferences prefs) async {
    final starsJson = _levelStars.map((k, v) => MapEntry(k.toString(), v));
    final scoresJson =
        _levelHighScores.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString(_starsPrefKey, jsonEncode(starsJson));
    await prefs.setString(_scoresPrefKey, jsonEncode(scoresJson));
    await prefs.setStringList(
      _completedPrefKey,
      _completedLevels.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      _bossClearedPrefKey,
      _bossFirstClearedLevels.map((e) => e.toString()).toList(),
    );
    await prefs.setStringList(
      _claimedChestsPrefKey,
      _claimedChapterChests.toList(),
    );
  }
}
