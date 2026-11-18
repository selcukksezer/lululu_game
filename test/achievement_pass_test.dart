import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/achievement_pass_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/widgets/achievement_toast_overlay.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
    await AchievementPassService.instance.resetForTesting();
    await AchievementPassService.instance.load();
  });

  group('AchievementPassService — 30 Başarım & Ustalık Sistemi', () {
    test('5 kategori altında tam 30 özgün Türkçe başarım tanımlı olmalı', () {
      final all = AchievementPassService.all30Achievements;
      expect(all.length, 30);

      final ids = all.map((a) => a.id).toSet();
      expect(ids.length, 30);

      final service = AchievementPassService.instance;
      expect(
        service
            .achievementsByCategory(AchievementCategory.mergeMaster)
            .length,
        6,
      );
      expect(
        service
            .achievementsByCategory(AchievementCategory.modeChampion)
            .length,
        11,
      );
      expect(
        service
            .achievementsByCategory(AchievementCategory.comboReflex)
            .length,
        5,
      );
      expect(
        service
            .achievementsByCategory(AchievementCategory.studioDirector)
            .length,
        4,
      );
      expect(
        service
            .achievementsByCategory(AchievementCategory.economyCollection)
            .length,
        4,
      );
    });

    test(
      '30 başarımın tamamı açılabilmeli, altın + Sezon XP + özel unvanlar vermeli ve çift ödülü engellemeli',
      () async {
        final service = AchievementPassService.instance;
        final pm = ProgressManager.instance;
        final initialCoins = pm.coins;

        var expectedCoins = initialCoins;
        var expectedXp = 0;

        for (final def in AchievementPassService.all30Achievements) {
          final unlockedFirst = await service.unlockAchievement(def.id);
          expect(unlockedFirst, isTrue, reason: '${def.id} ilk kez açılmalı');
          expectedCoins += def.coinReward;
          expectedXp += def.seasonXpReward;

          // Çift ödül engelleme kontrolü
          final unlockedSecond = await service.unlockAchievement(def.id);
          expect(
            unlockedSecond,
            isFalse,
            reason: '${def.id} ikinci kez ödül vermemeli',
          );
        }

        expect(service.unlockedAchievementIds.length, 30);
        expect(pm.coins, expectedCoins);
        expect(service.seasonXp, expectedXp);
        expect(service.unlockedTitles, contains('Terlik Nişancısı'));
        expect(service.unlockedTitles, contains("Osman'ın Sağ Kolu"));
        expect(service.unlockedTitles, contains('Lülülü İmparatoru'));

        // Kalıcılık kontrolü
        await service.load();
        expect(service.unlockedAchievementIds.length, 30);
        expect(service.seasonXp, expectedXp);
      },
    );

    test('recordProgress ve evaluateModeScore hedefe ulaşınca başarımı açmalı',
        () async {
      final service = AchievementPassService.instance;

      final step1 = await service.recordProgress('combo_5x', delta: 3);
      expect(step1, isFalse);
      expect(service.getAchievementProgress('combo_5x'), 3);

      final step2 = await service.recordProgress('combo_5x', delta: 2);
      expect(step2, isTrue);
      expect(service.isAchievementUnlocked('combo_5x'), isTrue);

      final modeUnlocked = await service.evaluateModeScore('terlik_tap', 2100);
      expect(modeUnlocked, isTrue);
      expect(service.isAchievementUnlocked('mode_terlik_master'), isTrue);
      expect(service.unlockedTitles, contains('Terlik Nişancısı'));
    });
  });

  group('AchievementPassService — 20 Kademeli Lülülü Sezon Bileti', () {
    test(
      '1..20 kademeli XP tablosu, Ücretsiz Hat ve Altın Bilet ödülleri + çift talep koruması çalışmalı',
      () async {
        final service = AchievementPassService.instance;
        final pm = ProgressManager.instance;

        expect(AchievementPassService.all20PassTiers.length, 20);
        expect(service.currentPassTier, 0);

        // Kademe 1 için 100 XP ekle
        await service.addSeasonXp(120, reason: 'test_match');
        expect(service.currentPassTier, 1);
        // Negatif XP koruması kontrolü
        await service.addSeasonXp(-500, reason: 'negative_xp_attempt');
        expect(service.seasonXp, 120);
        expect(service.canClaimPassTierReward(1, goldTrack: false), isTrue);
        expect(service.canClaimPassTierReward(1, goldTrack: true), isFalse);

        final coinsBefore = pm.coins;
        final freeClaim1 =
            await service.claimPassTierReward(1, goldTrack: false);
        expect(freeClaim1, isTrue);
        expect(pm.coins, coinsBefore + 150);

        // Çift talep (double-claim) engellenmeli
        final freeClaimDuplicate =
            await service.claimPassTierReward(1, goldTrack: false);
        expect(freeClaimDuplicate, isFalse);
        expect(pm.coins, coinsBefore + 150);

        // Altın Bilet aktif edilince Gold Track ödülü alınabilmeli
        await service.activateGoldPass();
        expect(service.hasGoldPass, isTrue);
        final slipperBefore = pm.slipperCount;
        final goldClaim1 =
            await service.claimPassTierReward(1, goldTrack: true);
        expect(goldClaim1, isTrue);
        expect(pm.slipperCount, slipperBefore + 2);
        expect(
          await service.claimPassTierReward(1, goldTrack: true),
          isFalse,
        );

        // Tier 20 (7700 XP) 33 güçlendirici paketini vermeli
        await service.addSeasonXp(8000, reason: 'season_max');
        expect(service.currentPassTier, 20);

        final undoBefore = pm.powerCount('undo');
        final x2Before = pm.powerCount('x2');
        final claimed20Free =
            await service.claimPassTierReward(20, goldTrack: false);
        expect(claimed20Free, isTrue);
        expect(pm.powerCount('undo'), undoBefore + 1);
        expect(pm.powerCount('x2'), x2Before + 1);
        expect(service.unlockedTitles, contains('Lülülü Pass Mezunu'));
      },
    );
  });

  group('Widget Testleri — AchievementToastBanner & AchievementPassSheet', () {
    testWidgets(
      'AchievementToastBanner açılan başarımı gösterir ve kapatılabilir',
      (tester) async {
        final service = AchievementPassService.instance;
        await service.unlockAchievement('merge_tier_13');

        await tester.pumpWidget(
          wrapWithL10n(
            const Scaffold(
              body: Stack(
                children: [
                  AchievementToastBanner(),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('BAŞARIM AÇILDI!'), findsOneWidget);
        expect(find.text('Makara Efsanesi Tier 13'), findsOneWidget);
        expect(find.textContaining('Lülülü İmparatoru'), findsOneWidget);

        await tester.tap(find.byKey(const Key('achievement_toast_close_btn')));
        await tester.pumpAndSettle();
        expect(service.activeToastNotifier.value, isNull);
      },
    );

    testWidgets(
      'AchievementPassSheet 360x640 ve 430x932 ekranlarda sıfır taşma ile 30 başarım ve 20 kademeyi gösterir',
      (tester) async {
        final service = AchievementPassService.instance;
        await service.addSeasonXp(300, reason: 'ui_test');

        for (final size in const [Size(360, 640), Size(430, 932)]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpWidget(
            wrapWithL10n(
              const Scaffold(
                body: AchievementPassSheet(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('achievement_pass_sheet')), findsOneWidget);
          expect(find.text('USTALIK & LÜLÜLÜ PASS'), findsOneWidget);

          // Sezon Bileti sekmesine geç
          await tester.tap(find.byKey(const Key('tab_season_pass_btn')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('season_pass_list_view')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('pass_tier_row_1')), findsOneWidget);

          // Başarımlar sekmesine geri dön
          await tester.tap(find.byKey(const Key('tab_achievements_btn')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('achievements_list_view')),
            findsOneWidget,
          );
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}
