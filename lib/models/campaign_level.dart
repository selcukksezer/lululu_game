import 'insect_tier.dart';

enum ObjectiveType {
  reachScore,
  mergeTargetTier,
  survivalTimer,
}

/// 8 temalı kampanya bölümü (her bölümde 10 seviye, toplam 80 seviye).
class CampaignThemedChapter {
  final int chapterIndex;
  final String title;
  final String iconEmoji;
  final int startLevel;
  final int endLevel;
  final int bossLevelNumber;
  final String bossName;
  final int bossHp;
  final String bossSpecialHazard;
  final int firstClearBonusCoins;
  final String backgroundPath;

  const CampaignThemedChapter({
    required this.chapterIndex,
    required this.title,
    required this.iconEmoji,
    required this.startLevel,
    required this.endLevel,
    required this.bossLevelNumber,
    required this.bossName,
    required this.bossHp,
    required this.bossSpecialHazard,
    required this.firstClearBonusCoins,
    required this.backgroundPath,
  });
}

class CampaignLevel {
  final int id;
  final int chapter;
  final int chapterIndex;
  final String chapterName;
  final String themedChapterTitle;
  final String title;
  final ObjectiveType objectiveType;
  final int targetScore;
  final InsectTier? targetTier;
  final int allowedMoves;
  final int timeLimitSeconds;
  final int star1Score;
  final int star2Score;
  final int star3Score;
  final int rewardCoins;
  final double difficulty;
  final bool isBossLevel;
  final String? bossName;
  final int bossHp;
  final String? bossSpecialHazard;
  final int firstClearBonusCoins;
  final String backgroundPath;
  final bool hasObstacles;

  /// Even chapters use a square bin. Odd chapters keep the round bowl.
  final bool squareArena;

  const CampaignLevel({
    required this.id,
    required this.chapter,
    int? chapterIndex,
    required this.chapterName,
    String? themedChapterTitle,
    required this.title,
    required this.objectiveType,
    required this.targetScore,
    this.targetTier,
    required this.allowedMoves,
    this.timeLimitSeconds = 0,
    required this.star1Score,
    required this.star2Score,
    required this.star3Score,
    this.rewardCoins = 100,
    this.difficulty = 1.0,
    this.isBossLevel = false,
    this.bossName,
    this.bossHp = 0,
    this.bossSpecialHazard,
    this.firstClearBonusCoins = 0,
    this.backgroundPath = 'assets/images/bg_kitchen_counter.png',
    this.hasObstacles = false,
    this.squareArena = false,
  })  : chapterIndex = chapterIndex ?? (((id - 1) ~/ 10) + 1),
        themedChapterTitle = themedChapterTitle ?? chapterName;

  /// Geriye dönük uyumlu seviye numarası (`id` alias).
  int get levelNumber => id;

  /// Geriye dönük uyumlu hamle sınırı (`allowedMoves` alias).
  int get moveLimit => allowedMoves;

  bool get isSurvival => objectiveType == ObjectiveType.survivalTimer;

  String get obstacleLabel =>
      hasObstacles ? 'Arena engelleri aktif' : 'Açık arena';

  String get objectiveDescription {
    switch (objectiveType) {
      case ObjectiveType.mergeTargetTier:
        return '$allowedMoves atışta ${targetTier?.name ?? "Böcek"} çıkar!';
      case ObjectiveType.reachScore:
        return '$allowedMoves atışta $targetScore puana ulaş!';
      case ObjectiveType.survivalTimer:
        return '$timeLimitSeconds saniye boyunca taşmadan hayatta kal!';
    }
  }
}

class CampaignDatabase {
  static const int totalLevels = 80;

  /// Geriye dönük 4 bölge sabiti (`store_readiness_test` ve `widget_test` uyumu).
  static const int chapterCount = 4;
  static const int levelsPerChapter = 20;

  /// 8 temalı bölüm sistemi (Chapter 1..8, her bölümde 10 seviye).
  static const int themedChapterCount = 8;
  static const int levelsPerThemedChapter = 10;

  static const List<CampaignThemedChapter> themedChapters = [
    CampaignThemedChapter(
      chapterIndex: 1,
      title: 'Mutfak Tezgahı Baskını',
      iconEmoji: '🍳',
      startLevel: 1,
      endLevel: 10,
      bossLevelNumber: 10,
      bossName: 'Şef Terlikli Muzaffer',
      bossHp: 1200,
      bossSpecialHazard: 'Kaynar Çaydanlık Buharı & Merdane Bariyeri',
      firstClearBonusCoins: 250,
      backgroundPath: 'assets/images/bg_kitchen_counter.png',
    ),
    CampaignThemedChapter(
      chapterIndex: 2,
      title: 'Kiler ve Erzak Kavanozu',
      iconEmoji: '🫙',
      startLevel: 11,
      endLevel: 20,
      bossLevelNumber: 20,
      bossName: 'Turşu Kralı Kavanoz Bey',
      bossHp: 1850,
      bossSpecialHazard: 'Yapışkan Reçel Damlaları & Tuzluk Tuzağı',
      firstClearBonusCoins: 350,
      backgroundPath: 'assets/images/bg_kitchen_counter.png',
    ),
    CampaignThemedChapter(
      chapterIndex: 3,
      title: 'Banyo Gideri Labirenti',
      iconEmoji: '🛁',
      startLevel: 21,
      endLevel: 30,
      bossLevelNumber: 30,
      bossName: 'Köpük Divası Şampuanella',
      bossHp: 2600,
      bossSpecialHazard: 'Kaygan Sabun Köpüğü & Gider Girdabı',
      firstClearBonusCoins: 450,
      backgroundPath: 'assets/images/bg_diva_mansion.png',
    ),
    CampaignThemedChapter(
      chapterIndex: 4,
      title: 'Bodrum Karanlığı',
      iconEmoji: '🔦',
      startLevel: 31,
      endLevel: 40,
      bossLevelNumber: 40,
      bossName: 'Karanlık Kömürlük Baronu',
      bossHp: 3500,
      bossSpecialHazard: 'Zifiri Sis Perdesi & Paslı Boru Engeli',
      firstClearBonusCoins: 600,
      backgroundPath: 'assets/images/bg_diva_mansion.png',
    ),
    CampaignThemedChapter(
      chapterIndex: 5,
      title: 'Fırın Ateşi Meydanı',
      iconEmoji: '🔥',
      startLevel: 41,
      endLevel: 50,
      bossLevelNumber: 50,
      bossName: 'Kızgın Rezistans Ejderi',
      bossHp: 4600,
      bossSpecialHazard: 'Alevli Tepsi Dalgası & Termal Hava Akımı',
      firstClearBonusCoins: 750,
      backgroundPath: 'assets/images/bg_diva_mansion.png',
    ),
    CampaignThemedChapter(
      chapterIndex: 6,
      title: 'Çatı Katı Fırtınası',
      iconEmoji: '⛈️',
      startLevel: 51,
      endLevel: 60,
      bossLevelNumber: 60,
      bossName: 'Kiremit Fırtınası Kaptanı',
      bossHp: 5800,
      bossSpecialHazard: 'Şimşek Çarpması & Ters Rüzgar Savrulması',
      firstClearBonusCoins: 900,
      backgroundPath: 'assets/images/bg_diva_mansion.png',
    ),
    CampaignThemedChapter(
      chapterIndex: 7,
      title: 'Kanalizasyon Krallığı',
      iconEmoji: '🧪',
      startLevel: 61,
      endLevel: 70,
      bossLevelNumber: 70,
      bossName: 'Toksik Rögar Mareşali',
      bossHp: 7200,
      bossSpecialHazard: 'Radyoaktif Neon Dalga & Demir Izgara Kapanı',
      firstClearBonusCoins: 1100,
      backgroundPath: 'assets/images/bg_kitchen_counter.png',
    ),
    CampaignThemedChapter(
      chapterIndex: 8,
      title: "Osman'ın Altın Sarayı",
      iconEmoji: '👑',
      startLevel: 71,
      endLevel: 80,
      bossLevelNumber: 80,
      bossName: 'İmparator Altın Osman',
      bossHp: 9500,
      bossSpecialHazard: 'Kraliyet Altın Terlik Yağmuru & Lazer Kalkanı',
      firstClearBonusCoins: 1500,
      backgroundPath: 'assets/images/bg_kitchen_counter.png',
    ),
  ];

  static const Map<int, List<String>> _chapterSubtitles = {
    1: [
      'Tezgah Isınması',
      'Kırıntı Avı',
      'Tencere Tıkırtısı',
      'Kavanoz Kuşatması',
      'Çaydanlık Fırtınası',
      'Ekmek Sepeti Baskını',
      'Bulaşık Köpüğü',
      'Baharat Rafı',
      'Kesme Tahtası Düellosu',
      'Mutfak Şefi Sınavı',
      'Gece Yarısı Atıştırması',
      'Buzdolabı Gölgesi',
      'Fırın Sıcağı',
      'Tava Kaydırağı',
      'Lavabo Girdabı',
      'Merdane Engeli',
      'Kiler Labirenti',
      'Tuzluk Tuzağı',
      'Tezgah Derbisi',
      'Mutfak Kralı Finali',
    ],
    2: [
      'Malikane Girişi',
      'Altın Avize',
      'Kırmızı Halı',
      'Pırlanta Ayna',
      'İpek Perde',
      'VIP Buhar Odası',
      'Mermer Havuz',
      'Köpük Partisi',
      'Sahne Işıkları',
      'Diva Tacı Sınavı',
      'Kadife Koltuk',
      'Kristal Şamdan',
      'Jakuzi Dalgası',
      'Parfüm Bulutu',
      'Bornoz Defilesi',
      'Gümüş Tepsi',
      'Teras Galası',
      'Kuliste Kaos',
      'Kraliyet Süiti',
      'Diva Malikanesi Finali',
    ],
    3: [
      'Kamera Motor',
      'İlk Reel Çekimi',
      'Mikrofon Testi',
      'Ring Işığı',
      'Trend Alarmı',
      'Canlı Yayın Baskını',
      'Montaj Masası',
      'Yeşil Perde',
      'Stüdyo Spotları',
      'Viral Patlama',
      'Remix Kabini',
      'Yorum Yağmuru',
      'Algoritma Ustası',
      'Dans Koreografisi',
      'Stüdyo Maratonu',
      'Büyük Prömiyer',
      'Milyon İzlenme',
      'Kulis Fırtınası',
      'Altın Plaket',
      'Pikomotions Sezon Finali',
    ],
    4: [
      'İstila Başlangıcı',
      'Kongo Öncüleri',
      'Sıcak Dalga',
      'Tamirhane Baskını',
      'Gece Kuşatması',
      'Siren Sesleri',
      'Zırhlı Hat',
      'Büyük Göç',
      'Şimşek Hattı',
      'Komutan Karargahı',
      'Karanlık Koridor',
      'Çelik Barikat',
      'Kaos Çemberi',
      'Elit Muhafızlar',
      'Son Savunma',
      'Fırtına Gözü',
      'Kongo Zaferi',
      'Bilge Konseyi',
      'Evrim Zirvesi',
      'Büyük Kongo İmparatoru',
    ],
  };

  static final List<CampaignLevel> allLevels = _generateAllLevels();

  /// Chapter 1 (Mutfak Tezgahı Baskını), first level — default Suika / hub entry.
  static CampaignLevel get kitchenLevel1 => getLevel(1);

  static CampaignLevel getLevel(int id) {
    if (id < 1) return allLevels.first;
    if (id > allLevels.length) return allLevels.last;
    return allLevels[id - 1];
  }

  /// Geriye dönük 4 bölge sorgusu (`chapter` 1..4 -> 20'şer seviye).
  static List<CampaignLevel> getLevelsForChapter(int chapter) {
    return allLevels.where((l) => l.chapter == chapter).toList();
  }

  /// 8 temalı bölüm sorgusu (`chapterIndex` 1..8 -> 10'ar seviye).
  static List<CampaignLevel> getLevelsForThemedChapter(int chapterIndex) {
    final safeIdx = chapterIndex.clamp(1, themedChapterCount);
    return allLevels.where((l) => l.chapterIndex == safeIdx).toList();
  }

  /// Bölüm indeksine (1..8) göre temalı bölüm bilgisini döndürür.
  static CampaignThemedChapter getThemedChapter(int chapterIndex) {
    final safeIdx = chapterIndex.clamp(1, themedChapterCount);
    return themedChapters[safeIdx - 1];
  }

  /// 8 Boss seviyesini (`10, 20, 30, 40, 50, 60, 70, 80`) döndürür.
  static List<CampaignLevel> get bossLevels =>
      allLevels.where((l) => l.isBossLevel).toList();

  static List<CampaignLevel> _generateAllLevels() {
    final List<CampaignLevel> list = [];
    const chapters = [
      (1, 'Mutfak Tezgahı', 'assets/images/bg_kitchen_counter.png'),
      (2, 'Diva Malikanesi', 'assets/images/bg_diva_mansion.png'),
      (3, 'Pikomotions Sahnesi', 'assets/images/bg_diva_mansion.png'),
      (4, 'Kongo İstilası', 'assets/images/bg_kitchen_counter.png'),
    ];

    int levelId = 1;
    for (final ch in chapters) {
      final subtitles = _chapterSubtitles[ch.$1] ?? const <String>[];
      for (int i = 1; i <= levelsPerChapter; i++) {
        final int themedIdx = ((levelId - 1) ~/ levelsPerThemedChapter) + 1;
        final CampaignThemedChapter themedMeta = getThemedChapter(themedIdx);

        final ObjectiveType type = _objectiveForSlot(i);
        final InsectTier? targetTier = type == ObjectiveType.mergeTargetTier
            ? _mergeTierForChapter(ch.$1, i)
            : null;

        final int targetScore = 1000 + (levelId * 125) + (ch.$1 * 220);
        final int moves = type == ObjectiveType.survivalTimer
            ? 40 + (i ~/ 2)
            : 18 + (i % 10) + ch.$1;
        final int timeLimit = type == ObjectiveType.survivalTimer
            ? 45 + (i * 3) + (ch.$1 * 5)
            : 0;
        final bool obstacles = i >= 12 || i == 10 || (i % 7 == 0 && i > 5);
        final bool isBoss = levelId % 10 == 0;

        final int s1 = type == ObjectiveType.survivalTimer
            ? (timeLimit * 12)
            : (targetScore * 0.7).round();
        final int s2 = type == ObjectiveType.survivalTimer
            ? (timeLimit * 18)
            : targetScore;
        final int s3 = type == ObjectiveType.survivalTimer
            ? (timeLimit * 26)
            : (targetScore * 1.4).round();

        final int rewardCoins =
            60 + (levelId * 8) + (ch.$1 * 25) + (isBoss ? 120 : 0);
        final double difficulty =
            (1.0 + ((levelId - 1) / (totalLevels - 1)) * 9.0)
                .clamp(1.0, 10.0);
        final String subtitle = (i - 1 < subtitles.length)
            ? subtitles[i - 1]
            : '${themedMeta.title} #$i';

        list.add(CampaignLevel(
          id: levelId,
          chapter: ch.$1,
          chapterIndex: themedIdx,
          chapterName: themedMeta.title,
          themedChapterTitle: themedMeta.title,
          title: 'Bölüm $levelId: $subtitle',
          objectiveType: type,
          targetScore: targetScore,
          targetTier: targetTier,
          allowedMoves: moves,
          timeLimitSeconds: timeLimit,
          star1Score: s1,
          star2Score: s2,
          star3Score: s3,
          rewardCoins: rewardCoins,
          difficulty: difficulty,
          isBossLevel: isBoss,
          bossName: isBoss ? themedMeta.bossName : null,
          bossHp: isBoss ? themedMeta.bossHp : 0,
          bossSpecialHazard: isBoss ? themedMeta.bossSpecialHazard : null,
          firstClearBonusCoins: isBoss ? themedMeta.firstClearBonusCoins : 0,
          backgroundPath: ch.$3,
          hasObstacles: obstacles,
          squareArena: ch.$1.isEven,
        ));
        levelId++;
      }
    }
    assert(list.length == totalLevels);
    return list;
  }

  /// Slot pattern inside each 20-level chapter: score / merge / survival mix.
  static ObjectiveType _objectiveForSlot(int slotInChapter) {
    if (slotInChapter % 5 == 0) return ObjectiveType.survivalTimer;
    if (slotInChapter % 3 == 0) return ObjectiveType.mergeTargetTier;
    return ObjectiveType.reachScore;
  }

  static InsectTier _mergeTierForChapter(int chapter, int slot) {
    switch (chapter) {
      case 1:
        return slot >= 15 ? InsectTier.dancer : InsectTier.fan;
      case 2:
        if (slot >= 18) return InsectTier.can;
        return slot >= 12 ? InsectTier.diva : InsectTier.dancer;
      case 3:
        if (slot >= 18) return InsectTier.kongo;
        return slot >= 12 ? InsectTier.can : InsectTier.diva;
      default:
        return slot >= 15 ? InsectTier.bed : InsectTier.kongo;
    }
  }
}
