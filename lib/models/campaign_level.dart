import 'insect_tier.dart';

enum ObjectiveType {
  reachScore,
  mergeTargetTier,
  survivalTimer,
}

class CampaignLevel {
  final int id;
  final int chapter;
  final String chapterName;
  final String title;
  final ObjectiveType objectiveType;
  final int targetScore;
  final InsectTier? targetTier;
  final int allowedMoves;
  final int timeLimitSeconds;
  final int star1Score;
  final int star2Score;
  final int star3Score;
  final String backgroundPath;
  final bool hasObstacles;

  /// Even chapters use a square bin. Odd chapters keep the round bowl.
  final bool squareArena;

  const CampaignLevel({
    required this.id,
    required this.chapter,
    required this.chapterName,
    required this.title,
    required this.objectiveType,
    required this.targetScore,
    this.targetTier,
    required this.allowedMoves,
    this.timeLimitSeconds = 0,
    required this.star1Score,
    required this.star2Score,
    required this.star3Score,
    this.backgroundPath = 'assets/images/bg_kitchen_counter.png',
    this.hasObstacles = false,
    this.squareArena = false,
  });

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
  static const int chapterCount = 4;
  static const int levelsPerChapter = 20;

  static final List<CampaignLevel> allLevels = _generateAllLevels();

  /// Chapter 1 (Mutfak Tezgahı), first level — default Suika / hub entry.
  static CampaignLevel get kitchenLevel1 => getLevel(1);

  static CampaignLevel getLevel(int id) {
    if (id < 1) return allLevels.first;
    if (id > allLevels.length) return allLevels.last;
    return allLevels[id - 1];
  }

  static List<CampaignLevel> getLevelsForChapter(int chapter) {
    return allLevels.where((l) => l.chapter == chapter).toList();
  }

  static List<CampaignLevel> _generateAllLevels() {
    final List<CampaignLevel> list = [];
    final chapters = [
      (1, 'Mutfak Tezgahı', 'assets/images/bg_kitchen_counter.png'),
      (2, 'Diva Malikanesi', 'assets/images/bg_diva_mansion.png'),
      (3, 'Pikomotions Sahnesi', 'assets/images/bg_diva_mansion.png'),
      (4, 'Kongo İstilası', 'assets/images/bg_kitchen_counter.png'),
    ];

    int levelId = 1;
    for (final ch in chapters) {
      for (int i = 1; i <= levelsPerChapter; i++) {
        final ObjectiveType type = _objectiveForSlot(i);
        final InsectTier? targetTier = type == ObjectiveType.mergeTargetTier
            ? _mergeTierForChapter(ch.$1, i)
            : null;

        final int targetScore = 1000 + (levelId * 120) + (ch.$1 * 200);
        final int moves = type == ObjectiveType.survivalTimer
            ? 40 + (i ~/ 2)
            : 18 + (i % 10) + ch.$1;
        final int timeLimit = type == ObjectiveType.survivalTimer
            ? 45 + (i * 3) + (ch.$1 * 5)
            : 0;
        final bool obstacles = i >= 12 || i == 10 || (i % 7 == 0 && i > 5);

        final int s1 = type == ObjectiveType.survivalTimer
            ? (timeLimit * 12)
            : (targetScore * 0.7).round();
        final int s2 = type == ObjectiveType.survivalTimer
            ? (timeLimit * 18)
            : targetScore;
        final int s3 = type == ObjectiveType.survivalTimer
            ? (timeLimit * 26)
            : (targetScore * 1.4).round();

        list.add(CampaignLevel(
          id: levelId,
          chapter: ch.$1,
          chapterName: ch.$2,
          title: 'Bölüm $levelId: ${ch.$2} #$i',
          objectiveType: type,
          targetScore: targetScore,
          targetTier: targetTier,
          allowedMoves: moves,
          timeLimitSeconds: timeLimit,
          star1Score: s1,
          star2Score: s2,
          star3Score: s3,
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
        return slot >= 15 ? InsectTier.diva : InsectTier.dancer;
      case 3:
        return slot >= 15 ? InsectTier.kongo : InsectTier.diva;
      default:
        return InsectTier.kongo;
    }
  }
}
