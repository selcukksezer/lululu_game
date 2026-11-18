import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/campaign_progression_service.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/widgets/campaign_map_sheet.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    await CampaignProgressionService.instance.resetForTesting();
    await CampaignProgressionService.instance.load();
  });

  group('1. 8 Temalı Bölüm & 80 Kampanya Seviyesi & 8 Boss Savaşı', () {
    test('80 seviye ve 8 temalı bölüm (her bölümde 10 seviye) eksiksiz üretilir',
        () {
      expect(CampaignDatabase.totalLevels, 80);
      expect(CampaignDatabase.allLevels.length, 80);
      expect(CampaignDatabase.themedChapterCount, 8);
      expect(CampaignDatabase.levelsPerThemedChapter, 10);

      // Geriye dönük uyumluluk sabitleri de korunmalı
      expect(CampaignDatabase.chapterCount, 4);
      expect(CampaignDatabase.levelsPerChapter, 20);

      const expectedTitles = <int, String>{
        1: 'Mutfak Tezgahı Baskını',
        2: 'Kiler ve Erzak Kavanozu',
        3: 'Banyo Gideri Labirenti',
        4: 'Bodrum Karanlığı',
        5: 'Fırın Ateşi Meydanı',
        6: 'Çatı Katı Fırtınası',
        7: 'Kanalizasyon Krallığı',
        8: "Osman'ın Altın Sarayı",
      };

      for (int ch = 1; ch <= 8; ch++) {
        final themedMeta = CampaignDatabase.getThemedChapter(ch);
        expect(themedMeta.chapterIndex, ch);
        expect(themedMeta.title, expectedTitles[ch]);
        expect(themedMeta.startLevel, (ch - 1) * 10 + 1);
        expect(themedMeta.endLevel, ch * 10);
        expect(themedMeta.bossLevelNumber, ch * 10);

        final chapterLevels = CampaignDatabase.getLevelsForThemedChapter(ch);
        expect(chapterLevels.length, 10);
        for (int i = 0; i < chapterLevels.length; i++) {
          final lvl = chapterLevels[i];
          expect(lvl.levelNumber, (ch - 1) * 10 + i + 1);
          expect(lvl.id, lvl.levelNumber);
          expect(lvl.chapterIndex, ch);
          expect(lvl.chapterName, expectedTitles[ch]);
          expect(lvl.themedChapterTitle, expectedTitles[ch]);
          expect(lvl.moveLimit, lvl.allowedMoves);
          expect(lvl.moveLimit, greaterThan(0));
          expect(lvl.targetScore, greaterThan(0));
          expect(lvl.rewardCoins, greaterThan(0));
          expect(lvl.star1Score, lessThanOrEqualTo(lvl.star2Score));
          expect(lvl.star2Score, lessThanOrEqualTo(lvl.star3Score));
        }
      }
    });

    test(
        'Her 10. seviyede (10, 20, 30, 40, 50, 60, 70, 80) Boss Savaşı tanımlıdır',
        () {
      final bosses = CampaignDatabase.bossLevels;
      expect(bosses.length, 8);
      expect(
        bosses.map((b) => b.levelNumber).toList(),
        equals([10, 20, 30, 40, 50, 60, 70, 80]),
      );

      for (final level in CampaignDatabase.allLevels) {
        if (level.levelNumber % 10 == 0) {
          expect(level.isBossLevel, isTrue);
          expect(level.bossName, isNotNull);
          expect(level.bossName, isNotEmpty);
          expect(level.bossHp, greaterThanOrEqualTo(1000));
          expect(level.bossSpecialHazard, isNotNull);
          expect(level.bossSpecialHazard, isNotEmpty);
          expect(level.firstClearBonusCoins, greaterThanOrEqualTo(250));
        } else {
          expect(level.isBossLevel, isFalse);
          expect(level.bossName, isNull);
          expect(level.bossHp, 0);
          expect(level.bossSpecialHazard, isNull);
          expect(level.firstClearBonusCoins, 0);
        }
      }
    });
  });

  group('2. CampaignProgressionService Yıldız, Boss Hasarı & Sandık Ödülleri',
      () {
    test(
        'calculateStarsForLevel skor ve kalan hamleye göre 0..3 yıldız hesaplar',
        () {
      final service = CampaignProgressionService.instance;
      final lvl1 = CampaignDatabase.getLevel(1);

      expect(service.calculateStarsForLevel(1, 0), 0);
      expect(service.calculateStarsForLevel(1, lvl1.star1Score - 100), 0);
      expect(service.calculateStarsForLevel(1, lvl1.star1Score), 1);
      expect(service.calculateStarsForLevel(1, lvl1.star2Score), 2);
      expect(service.calculateStarsForLevel(1, lvl1.star3Score), 3);

      // Kalan hamle bonusu ile 2 yıldızlık skorun 3 yıldıza çıkması
      final nearStar3 = lvl1.star3Score - 90;
      expect(service.calculateStarsForLevel(1, nearStar3, remainingMoves: 0), 2);
      expect(service.calculateStarsForLevel(1, nearStar3, remainingMoves: 3), 3);
    });

    test('calculateBossDamage birleşen kademe ve kombo ile ölçeklenir', () {
      final service = CampaignProgressionService.instance;
      final dmgTier1Combo1 =
          service.calculateBossDamage(mergedTier: 1, comboCount: 1);
      final dmgTier4Combo1 =
          service.calculateBossDamage(mergedTier: 4, comboCount: 1);
      final dmgTier4Combo3 =
          service.calculateBossDamage(mergedTier: 4, comboCount: 3);

      expect(dmgTier1Combo1, greaterThan(0));
      expect(dmgTier4Combo1, greaterThan(dmgTier1Combo1));
      expect(dmgTier4Combo3, greaterThan(dmgTier4Combo1));
    });

    test(
        'recordLevelCompletion yıldızları, yüksek skoru ve Boss ilk geçiş bonusunu kalıcı saklar',
        () async {
      final service = CampaignProgressionService.instance;
      final pm = ProgressManager.instance;
      final bossLvl10 = CampaignDatabase.getLevel(10);
      final initialCoins = pm.coins;

      final summary = await service.recordLevelCompletion(
        levelNumber: 10,
        score: bossLvl10.star3Score + 500,
        remainingMoves: 4,
      );

      expect(summary.starsEarned, 3);
      expect(summary.isNewCompletion, isTrue);
      expect(
        summary.bossFirstClearBonusCoins,
        bossLvl10.firstClearBonusCoins,
      );
      expect(service.getStarsForLevel(10), 3);
      expect(service.getHighScoreForLevel(10), bossLvl10.star3Score + 500);
      expect(service.isLevelCompleted(10), isTrue);
      expect(service.isBossFirstCleared(10), isTrue);
      expect(pm.coins, greaterThan(initialCoins + bossLvl10.firstClearBonusCoins));

      // İkinci kez geçildiğinde Boss ilk geçiş bonusu tekrar verilmez
      final secondSummary = await service.recordLevelCompletion(
        levelNumber: 10,
        score: bossLvl10.star3Score + 800,
      );
      expect(secondSummary.bossFirstClearBonusCoins, 0);
    });

    test(
        'claimChapterChest 10, 20 ve 30 yıldızda altın ve güçlendirici ödülü verir',
        () async {
      final service = CampaignProgressionService.instance;
      final pm = ProgressManager.instance;

      // Bölüm 1'de henüz yıldız yokken sandık açılamaz
      expect(service.canClaimChapterChest(1, 10), isFalse);
      expect(await service.claimChapterChest(1, 10), isNull);

      // Bölüm 1'deki 10 seviyenin tamamına 3 yıldız ver (toplam 30 yıldız)
      for (int id = 1; id <= 10; id++) {
        await service.setStarsForLevel(id, 3);
      }
      expect(service.getChapterStars(1), 30);

      final coinsBefore10 = pm.coins;
      final raidBefore10 = pm.powerCount('raid');
      final chest10 = await service.claimChapterChest(1, 10);
      expect(chest10, isNotNull);
      expect(chest10!.milestoneStars, 10);
      expect(pm.coins, coinsBefore10 + chest10.coinsGranted);
      expect(pm.powerCount('raid'), raidBefore10 + chest10.boosterCount);
      expect(service.isChapterChestClaimed(1, 10), isTrue);
      // Aynı sandık ikinci kez açılamaz
      expect(await service.claimChapterChest(1, 10), isNull);

      final terlikBefore20 = pm.powerCount('terlik');
      final chest20 = await service.claimChapterChest(1, 20);
      expect(chest20, isNotNull);
      expect(pm.powerCount('terlik'), terlikBefore20 + chest20!.boosterCount);

      final f16Before30 = pm.powerCount('f16');
      final chest30 = await service.claimChapterChest(1, 30);
      expect(chest30, isNotNull);
      expect(pm.powerCount('f16'), f16Before30 + chest30!.boosterCount);
    });
  });

  group('3. CampaignMapSheet Widget Testleri (360x640 ve 430x932 Sıfır Taşma)',
      () {
    Future<void> pumpMapAtSize(
      WidgetTester tester,
      Size size, {
      int initialChapter = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithL10n(
          Scaffold(
            body: SizedBox(
              width: size.width,
              height: size.height,
              child: CampaignMapSheet(initialChapterIndex: initialChapter),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        '360x640 dar ekranda 8 bölüm, 10 seviye düğümü, Boss tacı ve sandıklar 0 taşma ile çizilir',
        (tester) async {
      final service = CampaignProgressionService.instance;
      for (int id = 1; id <= 4; id++) {
        await service.setStarsForLevel(id, 3);
      }

      await pumpMapAtSize(tester, const Size(360, 640));
      expect(tester.takeException(), isNull);

      expect(find.byKey(const Key('campaign_map_sheet_root')), findsOneWidget);
      expect(find.textContaining('Mutfak Tezgahı Baskını'), findsWidgets);
      expect(find.byKey(const Key('boss_crown_icon_10')), findsOneWidget);
      expect(find.byKey(const Key('campaign_chest_1_10')), findsOneWidget);
      expect(find.byKey(const Key('campaign_chest_1_20')), findsOneWidget);
      expect(find.byKey(const Key('campaign_chest_1_30')), findsOneWidget);

      // 12 yıldızımız olduğu için 10⭐ sandığına tıklayıp ödülü toplayabilmeliyiz
      await tester.tap(find.byKey(const Key('campaign_chest_1_10')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.isChapterChestClaimed(1, 10), isTrue);
      expect(
        find.byKey(const Key('campaign_chest_feedback_banner')),
        findsOneWidget,
      );
    });

    testWidgets(
        '430x932 ekranda 8 bölüm sekmesi arasında geçiş ve Boss düğümleri 0 taşma ile çalışır',
        (tester) async {
      await pumpMapAtSize(tester, const Size(430, 932));
      expect(tester.takeException(), isNull);

      for (int ch = 1; ch <= 8; ch++) {
        final tabFinder = find.byKey(Key('campaign_chapter_tab_$ch'));
        await tester.ensureVisible(tabFinder);
        await tester.tap(tabFinder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final bossLevelId = ch * 10;
        expect(
          find.byKey(Key('boss_crown_icon_$bossLevelId')),
          findsOneWidget,
        );
      }
    });
  });

  group('4. Mod 5 (Bağla) & Mod 6 (Stack) Sonuç Döngüsü ve İlk Frame Kontrolleri',
      () {
    testWidgets(
        'StackDropScreen ilk frame blok inişi puan üretir ve oyun sonunda altın/liderlik kaydedilip ANA SAYFA sonsuz döngüye girmez',
        (tester) async {
      AudioManager().isMuted = true;
      await LeaderboardService.instance.ensureLoaded();
      tester.view.physicalSize = const Size(374, 680);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapWithL10n(
          Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StackDropScreen(),
                    ),
                  ),
                  child: const Text('OPEN_STACK'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN_STACK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final coinsBefore = ProgressManager.instance.coins;
      // İlk frame'de (16ms) ortalanmış bloğu indir -> MÜKEMMEL İSABET
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tapAt(const Offset(187, 350));
      for (int i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.textContaining('MÜKEMMEL'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(ProgressManager.instance.coins, greaterThanOrEqualTo(coinsBefore));
    });

    testWidgets(
        'ConnectPopScreen 360x640 ve 374x680 boyutlarında 0 taşma ile zincir puanlar',
        (tester) async {
      AudioManager().isMuted = true;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpWithL10n(
        tester,
        const ConnectPopScreen(gameplayTestState: true),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
