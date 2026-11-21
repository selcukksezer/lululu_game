import 'dart:ui' show Locale;

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

  // --- English (EN) counterparts: pure additions, TR defaults untouched. ---
  // `title`/`bossName`/`bossSpecialHazard` keep returning Turkish; screens
  // migrate to the `*For(Locale)` accessors in a later wave. Proper names
  // (Osman, Muzaffer, Diva) stay identical inside the EN strings. Unknown
  // chapter indexes fall back to the Turkish value. No AppLocalizations
  // import: these are pure `Locale`-parameterized accessors, so no cycle.
  String get titleEn {
    switch (chapterIndex) {
      case 1:
        return 'Kitchen Counter Raid';
      case 2:
        return 'Pantry and Provisions Jar';
      case 3:
        return 'Bathroom Drain Labyrinth';
      case 4:
        return 'Basement Darkness';
      case 5:
        return 'Oven-Fire Square';
      case 6:
        return 'Attic Storm';
      case 7:
        return 'Sewer Kingdom';
      case 8:
        return "Osman's Golden Palace";
      default:
        return title;
    }
  }

  String titleFor(Locale locale) =>
      locale.languageCode == 'en' ? titleEn : title;

  String get bossNameEn {
    switch (chapterIndex) {
      case 1:
        return 'Slippered Chef Muzaffer';
      case 2:
        return 'Pickle King Mr. Jar';
      case 3:
        return 'Foam Diva Shampooella';
      case 4:
        return 'Dark Coal-Cellar Baron';
      case 5:
        return 'Scorching Coil Dragon';
      case 6:
        return 'Roof-Tile Storm Captain';
      case 7:
        return 'Toxic Manhole Marshal';
      case 8:
        return 'Emperor Golden Osman';
      default:
        return bossName;
    }
  }

  String bossNameFor(Locale locale) =>
      locale.languageCode == 'en' ? bossNameEn : bossName;

  String get bossSpecialHazardEn {
    switch (chapterIndex) {
      case 1:
        return 'Boiling Kettle Steam & Rolling-Pin Barrier';
      case 2:
        return 'Sticky Jam Drops & Salt-Shaker Trap';
      case 3:
        return 'Slippery Soap Foam & Drain Vortex';
      case 4:
        return 'Pitch-Black Fog Curtain & Rusty Pipe Barrier';
      case 5:
        return 'Flaming Tray Wave & Thermal Air Current';
      case 6:
        return 'Lightning Strikes & Reverse-Wind Drift';
      case 7:
        return 'Radioactive Neon Wave & Iron Grate Trap';
      case 8:
        return 'Royal Golden Slipper Rain & Laser Shield';
      default:
        return bossSpecialHazard;
    }
  }

  String bossSpecialHazardFor(Locale locale) => locale.languageCode == 'en'
      ? bossSpecialHazardEn
      : bossSpecialHazard;
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

  /// Zorluk arttıkça üst kademe (fan/dansçı) düşürme olasılığını kısan
  /// ölçek: zorluk 1'de 1.0 (taban dağılım), zorluk 10'da 0.55.
  /// Kampanya düşürme dağılımı bu ölçeği okur; arcade kullanmaz.
  double get highTierDropScale {
    final d = difficulty.isNaN ? 1.0 : difficulty.clamp(1.0, 10.0).toDouble();
    return 1.0 - ((d - 1.0) / 9.0) * 0.45;
  }

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

  // --- English (EN) counterparts: pure additions, TR defaults untouched. ---
  // `chapterName`/`title`/`objectiveDescription`/`obstacleLabel` keep
  // returning Turkish; screens migrate to the `*For(Locale)` accessors in a
  // later wave. `titleEn` mirrors the generator: 'Level <id>: <subtitle>' with
  // the subtitle taken from the EN subtitle map by legacy chapter (1..4) and
  // slot inside the chapter. `objectiveDescriptionEn` uses the target tier's
  // EN name. Boss EN values resolve through the themed chapter and stay null
  // exactly when the Turkish value is null. No AppLocalizations import.
  String get chapterNameEn =>
      CampaignDatabase.getThemedChapter(chapterIndex).titleEn;

  String chapterNameFor(Locale locale) =>
      locale.languageCode == 'en' ? chapterNameEn : chapterName;

  String get themedChapterTitleEn => chapterNameEn;

  String themedChapterTitleFor(Locale locale) => locale.languageCode == 'en'
      ? themedChapterTitleEn
      : themedChapterTitle;

  String get titleEn {
    final subtitlesEn =
        CampaignDatabase._chapterSubtitlesEn[chapter] ?? const <String>[];
    final slot = (id - 1) % CampaignDatabase.levelsPerChapter;
    final subtitleEn = slot < subtitlesEn.length
        ? subtitlesEn[slot]
        : '$chapterNameEn #${slot + 1}';
    return 'Level $id: $subtitleEn';
  }

  String titleFor(Locale locale) =>
      locale.languageCode == 'en' ? titleEn : title;

  String get objectiveDescriptionEn {
    switch (objectiveType) {
      case ObjectiveType.mergeTargetTier:
        return 'Hatch a ${targetTier?.nameEn ?? "Bug"} in $allowedMoves shots!';
      case ObjectiveType.reachScore:
        return 'Reach $targetScore points in $allowedMoves shots!';
      case ObjectiveType.survivalTimer:
        return 'Survive $timeLimitSeconds seconds without overflowing!';
    }
  }

  String objectiveDescriptionFor(Locale locale) => locale.languageCode == 'en'
      ? objectiveDescriptionEn
      : objectiveDescription;

  String get obstacleLabelEn =>
      hasObstacles ? 'Arena obstacles active' : 'Open arena';

  String obstacleLabelFor(Locale locale) =>
      locale.languageCode == 'en' ? obstacleLabelEn : obstacleLabel;

  String? get bossNameEn => bossName == null
      ? null
      : CampaignDatabase.getThemedChapter(chapterIndex).bossNameEn;

  String? bossNameFor(Locale locale) =>
      locale.languageCode == 'en' ? bossNameEn : bossName;

  String? get bossSpecialHazardEn => bossSpecialHazard == null
      ? null
      : CampaignDatabase.getThemedChapter(chapterIndex).bossSpecialHazardEn;

  String? bossSpecialHazardFor(Locale locale) => locale.languageCode == 'en'
      ? bossSpecialHazardEn
      : bossSpecialHazard;
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

  /// English counterparts of [_chapterSubtitles], same keys and same order
  /// (4 legacy chapters x 20 level subtitles). Proper names (Diva, Kongo,
  /// Pikomotions) stay identical. Read only by [CampaignLevel.titleEn].
  static const Map<int, List<String>> _chapterSubtitlesEn = {
    1: [
      'Counter Warm-Up',
      'Crumb Hunt',
      'Pot Clatter',
      'Jar Siege',
      'Kettle Storm',
      'Bread Basket Raid',
      'Dish Foam',
      'Spice Rack',
      'Cutting Board Duel',
      'Head Chef Trial',
      'Midnight Snack',
      'Fridge Shadow',
      'Oven Heat',
      'Pan Slide',
      'Sink Vortex',
      'Rolling-Pin Barrier',
      'Pantry Labyrinth',
      'Salt-Shaker Trap',
      'Counter Derby',
      'Kitchen King Finale',
    ],
    2: [
      'Mansion Entrance',
      'Golden Chandelier',
      'Red Carpet',
      'Diamond Mirror',
      'Silk Curtain',
      'VIP Steam Room',
      'Marble Pool',
      'Foam Party',
      'Stage Lights',
      'Diva Crown Trial',
      'Velvet Armchair',
      'Crystal Candelabra',
      'Jacuzzi Wave',
      'Perfume Cloud',
      'Robe Fashion Show',
      'Silver Tray',
      'Terrace Gala',
      'Backstage Chaos',
      'Royal Suite',
      'Diva Mansion Finale',
    ],
    3: [
      'Camera Rolling',
      'First Reel Shoot',
      'Mic Check',
      'Ring Light',
      'Trend Alert',
      'Livestream Raid',
      'Editing Desk',
      'Green Screen',
      'Studio Spotlights',
      'Viral Explosion',
      'Remix Booth',
      'Comment Rain',
      'Algorithm Master',
      'Dance Choreography',
      'Studio Marathon',
      'Grand Premiere',
      'Million Views',
      'Backstage Storm',
      'Golden Plaque',
      'Pikomotions Season Finale',
    ],
    4: [
      'Invasion Begins',
      'Kongo Vanguard',
      'Heat Wave',
      'Workshop Raid',
      'Night Siege',
      'Siren Sounds',
      'Armored Line',
      'Great Migration',
      'Lightning Line',
      'Commander Headquarters',
      'Dark Corridor',
      'Steel Barricade',
      'Chaos Circle',
      'Elite Guards',
      'Last Stand',
      'Eye of the Storm',
      'Kongo Victory',
      'Sage Council',
      'Evolution Summit',
      'Great Kongo Emperor',
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

        final bool isBoss = levelId % 10 == 0;
        // Boss seviyesi gerçek bir boss hedefidir: hayatta kalma değil,
        // yükseltilmiş yıldız eşikli skor hedefi + HUD'da boss göstergesi.
        final ObjectiveType type = isBoss
            ? ObjectiveType.reachScore
            : _objectiveForSlot(i);
        final InsectTier? targetTier = type == ObjectiveType.mergeTargetTier
            ? _mergeTierForChapter(ch.$1, i)
            : null;

        final int targetScore = 1000 + (levelId * 125) + (ch.$1 * 220);
        final int moves = type == ObjectiveType.survivalTimer || isBoss
            ? 40 + (i ~/ 2)
            : 18 + (i % 10) + ch.$1;
        final int timeLimit = type == ObjectiveType.survivalTimer
            ? 45 + (i * 3) + (ch.$1 * 5)
            : 0;
        final bool obstacles = i >= 12 || i == 10 || (i % 7 == 0 && i > 5);

        // 12Q-stars — zorlaşan eşikler (eski: skor 0.7/1.0/1.4×hedef,
        // survival 12/18/26×süre, boss 1.0/1.3/1.7×hedef):
        // hedefi tutturmak artık yalnız 1 yıldız verir; 2 yıldız
        // hedefin üstünü, 3 yıldız hedefin çok üstünü ister. Bölüm
        // ilerledikçe s2/s3 çarpanı büyür (bölüm başına +0.05/+0.10).
        // Boss'ta geçiş hedefte kalır (1.0×): boss zaferi birleşme
        // anında hedef tutunca tetiklendiği için s1 > hedef olsaydı
        // hedefi kıl payı tutturan zafer 0 yıldız gösterirdi.
        final double s2Mult = 1.2 + 0.05 * (ch.$1 - 1);
        final double s3Mult = 1.8 + 0.1 * (ch.$1 - 1);
        final int s1 = isBoss
            ? targetScore
            : type == ObjectiveType.survivalTimer
                ? (timeLimit * 14)
                : (targetScore * 0.85).round();
        final int s2 = isBoss
            ? (targetScore * 1.5).round()
            : type == ObjectiveType.survivalTimer
                ? (timeLimit * 21)
                : (targetScore * s2Mult).round();
        final int s3 = isBoss
            ? (targetScore * 2.0).round()
            : type == ObjectiveType.survivalTimer
                ? (timeLimit * (30 + 2 * (ch.$1 - 1)))
                : (targetScore * s3Mult).round();

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
