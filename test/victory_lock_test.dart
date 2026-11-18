import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/progress_manager.dart';

// Zafer-kilit sözleşmesi (S1#23 yan etkisi):
// `recordLevelResult` kilit açmayı yıldızdan değil `victory` bilgisinden
// okur — lib/services/progress_manager.dart:1088 (imza),
// 1107-1109 (`shouldUnlock = victory ?? (earnedStars > 0)`).
// `victory` üç durumludur: true = 0 yıldızda bile açar, false = yıldızlı
// sonuçta bile açmaz, null (verilmezse) = eski davranış (yıldız > 0 açar).
// Yıldız/coin/yüksek skor kaydı zafer bilgisinden bağımsız aynen yapılır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
  });

  test('victory:true ile 0 yıldızlı sonuç kilit açar', () async {
    final pm = ProgressManager.instance;
    final coinsBefore = pm.coins;
    expect(pm.unlockedLevel, 1);

    await pm.recordLevelResult(
      levelId: 1,
      score: 250,
      stars: 0,
      victory: true,
    );

    expect(pm.unlockedLevel, 2);
    expect(pm.isLevelUnlocked(2), isTrue);
    expect(pm.getStarCount(1), 0);
    expect(pm.coins, coinsBefore);
    expect(pm.getHighScore(1), 250);
  });

  test('victory:false ile yıldızlı sonuç kilit açmaz ama kayıt yapılır',
      () async {
    final pm = ProgressManager.instance;
    final coinsBefore = pm.coins;

    await pm.recordLevelResult(
      levelId: 1,
      score: 400,
      stars: 3,
      victory: false,
    );

    expect(pm.unlockedLevel, 1);
    expect(pm.isLevelUnlocked(2), isFalse);
    expect(pm.getStarCount(1), 3);
    expect(pm.coins, coinsBefore + 150);
    expect(pm.getHighScore(1), 400);
  });

  test('victory verilmezse yıldızlı sonuç kilit açar (eski davranış)',
      () async {
    final pm = ProgressManager.instance;
    final coinsBefore = pm.coins;

    await pm.recordLevelResult(levelId: 1, score: 100, stars: 2);

    expect(pm.unlockedLevel, 2);
    expect(pm.isLevelUnlocked(2), isTrue);
    expect(pm.getStarCount(1), 2);
    expect(pm.coins, coinsBefore + 100);
  });

  test('victory verilmezse 0 yıldızlı sonuç kilit açmaz (eski davranış)',
      () async {
    final pm = ProgressManager.instance;
    final coinsBefore = pm.coins;

    await pm.recordLevelResult(levelId: 1, score: 100, stars: 0);

    expect(pm.unlockedLevel, 1);
    expect(pm.isLevelUnlocked(2), isFalse);
    expect(pm.getStarCount(1), 0);
    expect(pm.coins, coinsBefore);
    expect(pm.getHighScore(1), 100);
  });

  test('victory:true sınır-dışı seviyede kilidi ilerletmez', () async {
    final pm = ProgressManager.instance;
    pm.unlockedLevel = 3;

    await pm.recordLevelResult(
      levelId: 1,
      score: 100,
      stars: 0,
      victory: true,
    );

    expect(pm.unlockedLevel, 3);
    expect(pm.isLevelUnlocked(3), isTrue);
    expect(pm.isLevelUnlocked(4), isFalse);
  });

  test('victory:true tavanda (80) kilidi aşmaz', () async {
    final pm = ProgressManager.instance;
    pm.unlockedLevel = ProgressManager.maxCampaignLevels;

    await pm.recordLevelResult(
      levelId: ProgressManager.maxCampaignLevels,
      score: 100,
      stars: 0,
      victory: true,
    );

    expect(pm.unlockedLevel, ProgressManager.maxCampaignLevels);
    expect(
      pm.isLevelUnlocked(ProgressManager.maxCampaignLevels),
      isTrue,
    );
    expect(pm.getHighScore(ProgressManager.maxCampaignLevels), 100);
  });

  test('yenilgi kaydı yıldızı düşürmez ve tekrar coin ödemez', () async {
    final pm = ProgressManager.instance;
    final coinsBefore = pm.coins;

    await pm.recordLevelResult(
      levelId: 1,
      score: 100,
      stars: 3,
      victory: true,
    );
    expect(pm.unlockedLevel, 2);
    expect(pm.coins, coinsBefore + 150);

    await pm.recordLevelResult(
      levelId: 1,
      score: 500,
      stars: 1,
      victory: false,
    );

    expect(pm.getStarCount(1), 3);
    expect(pm.coins, coinsBefore + 150);
    expect(pm.getHighScore(1), 500);
    expect(pm.unlockedLevel, 2);
  });
}
