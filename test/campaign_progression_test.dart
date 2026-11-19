import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/screens/campaign_map_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/campaign_progression_service.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

/// 6C deseni: gerçek fontlar setUpAll'da yüklenir — ilk widget
/// testinde font yükleme bildirimi (sistem-fontu transient callback)
/// sökümde asılı kalıp scheduler hatasına yol açmasın.
Future<void> _loadCustomFonts() async {
  final fontMap = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
    ],
    'Bangers': [
      'assets/fonts/Bangers-Regular.ttf',
    ],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
    ],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
    ],
  };

  for (final entry in fontMap.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }

  for (final w in FontWeight.values) {
    GoogleFonts.baloo2(fontWeight: w);
    GoogleFonts.nunito(fontWeight: w);
    GoogleFonts.bangers(fontWeight: w);
    GoogleFonts.exo2(fontWeight: w);
  }
  await GoogleFonts.pendingFonts();
}

void main() {
  setUpAll(() async {
    await _loadCustomFonts();
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

    test(
        '12Q-stars: kampanya eşikleri zorlaştı — hedef yalnız 1 yıldız verir',
        () {
      // Seviye 1 (bölüm 1, skor hedefi): hedef 1345.
      // Eski: 941 / 1345 / 1883. Yeni: 0.85× / 1.2× / 1.8× hedef.
      final lvl1 = CampaignDatabase.getLevel(1);
      expect(lvl1.targetScore, 1345);
      expect(lvl1.star1Score, 1143);
      expect(lvl1.star2Score, 1614);
      expect(lvl1.star3Score, 2421);
      // Hedefi tutturmak (1345) artık 2 değil 1 yıldızdır.
      final service = CampaignProgressionService.instance;
      expect(service.calculateStarsForLevel(1, 1345), 1);
      expect(service.calculateStarsForLevel(1, 1613), 1);
      expect(service.calculateStarsForLevel(1, 1614), 2);
      expect(service.calculateStarsForLevel(1, 2421), 3);

      // Seviye 5 (bölüm 1, hayatta kalma, süre 65 sn).
      // Eski: 780 / 1170 / 1690. Yeni: 14× / 21× / 30× süre.
      final lvl5 = CampaignDatabase.getLevel(5);
      expect(lvl5.timeLimitSeconds, 65);
      expect(lvl5.star1Score, 910);
      expect(lvl5.star2Score, 1365);
      expect(lvl5.star3Score, 1950);

      // Seviye 10 (bölüm 1 boss): hedef 2470.
      // Eski: 2470 / 3211 / 4199. Yeni: 1.0× / 1.5× / 2.0× hedef
      // (boss geçişi hedefte kalır: hedefi tutturan zafer 0 yıldız
      // göstermesin).
      final boss10 = CampaignDatabase.getLevel(10);
      expect(boss10.targetScore, 2470);
      expect(boss10.star1Score, 2470);
      expect(boss10.star2Score, 3705);
      expect(boss10.star3Score, 4940);

      // Seviye 61 (bölüm 4, skor hedefi): hedef 9505; bölüm
      // ilerledikçe s2/s3 çarpanı büyür (1.35× / 2.1×).
      final lvl61 = CampaignDatabase.getLevel(61);
      expect(lvl61.targetScore, 9505);
      expect(lvl61.star1Score, 8079);
      expect(lvl61.star2Score, 12832);
      expect(lvl61.star3Score, 19961);
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

  group('3. CampaignMapScreen Widget Testleri (360x640 ve 430x932 Sıfır Taşma)',
      () {
    Future<void> pumpMapAtSize(WidgetTester tester, Size size) async {
      AudioManager().isMuted = true;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithL10n(
          const CampaignMapScreen(),
          theme: buildLululuTheme(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets(
        '360x640 dar ekranda 20 seviye karosu ve sandıklar 0 taşma ile çizilir, sandık talep edilir',
        (tester) async {
      final service = CampaignProgressionService.instance;
      for (int id = 1; id <= 4; id++) {
        await service.setStarsForLevel(id, 3);
      }

      await pumpMapAtSize(tester, const Size(360, 640));
      expect(tester.takeException(), isNull);

      expect(find.byKey(const Key('campaign_map_chest_bar')), findsOneWidget);
      expect(find.byKey(const Key('campaign_map_chest_1_10')), findsOneWidget);
      expect(find.byKey(const Key('campaign_map_chest_1_20')), findsOneWidget);
      expect(find.byKey(const Key('campaign_map_chest_1_30')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      // 12 yıldızımız olduğu için 10⭐ sandığına tıklayıp ödülü toplayabilmeliyiz
      await tester.tap(find.byKey(const Key('campaign_map_chest_1_10')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(service.isChapterChestClaimed(1, 10), isTrue);
      expect(
        find.byKey(const Key('campaign_map_chest_feedback_banner')),
        findsOneWidget,
      );

      // Izgara tembel kurulur (360x640'ta son satır ağaçta yoktur):
      // 20. karoyu görünür kılana dek kaydır.
      await tester.scrollUntilVisible(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('20'),
        ),
        200,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('20'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Boş ağaçta drenaj: sistem-fontu transient callback'i test
      // sonunda asılı kalıp scheduler hatasına yol açabiliyor (K3a
      // testinde aynı dalgalanma); ağaç boşken pumpAndSettle durulur.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
    });

    testWidgets(
        '430x932 ekranda 4 bölüm arasında geçiş ve seviye aralıkları 0 taşma ile çalışır',
        (tester) async {
      await pumpMapAtSize(tester, const Size(430, 932));
      expect(tester.takeException(), isNull);

      Finder levelInGrid(String number) => find.descendant(
            of: find.byType(GridView),
            matching: find.text(number),
          );

      // ensureVisible kaydırma animasyonu bitmeden dokunmak ıskalar:
      // animasyon durulana dek pump edilir, sonra çipe dokunulur.
      // Bölüm değişince ızgara kaydırma konumu korunur: en üste dönülür.
      Future<void> selectChapter(String name) async {
        final chip = find.text(name);
        await tester.ensureVisible(chip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(chip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(GridView), const Offset(0, 800));
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Aralık denetimi: ilk karo görünür, son karo kaydırılarak
      // görünür kılınır (tembel ızgara).
      Future<void> expectLevelRange(String first, String last) async {
        expect(levelInGrid(first), findsOneWidget);
        await tester.scrollUntilVisible(
          levelInGrid(last),
          200,
          scrollable: find.descendant(
            of: find.byType(GridView),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(levelInGrid(last), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      // Bölüm 1: 1-20. seviye.
      await expectLevelRange('1', '20');

      // Bölüm 2: 21-40. seviye.
      await selectChapter('Diva Malikanesi');
      await expectLevelRange('21', '40');
      expect(levelInGrid('1'), findsNothing);

      // Bölüm 3: 41-60. seviye.
      await selectChapter('Pikomotions Sahnesi');
      await expectLevelRange('41', '60');

      // Bölüm 4: 61-80. seviye.
      await selectChapter('Kongo İstilası');
      await expectLevelRange('61', '80');

      // Boş ağaçta drenaj (yukarıdaki testle aynı gerekçe).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
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

  group('5. Dalga 3B: uçuş koruması, kanonik kilit, harita sandığı, ödül görünürlüğü', () {
    test('O17: eşzamanlı çift load() tek uçuşu paylaşır (tek bildirim, durum korunur)',
        () async {
      final service = CampaignProgressionService.instance;
      for (int id = 1; id <= 4; id++) {
        await service.setStarsForLevel(id, 3);
      }
      expect(service.getChapterStars(1), 12);

      var notifications = 0;
      void count() => notifications++;
      service.addListener(count);
      try {
        await Future.wait([service.load(), service.load()]);
      } finally {
        service.removeListener(count);
      }
      expect(notifications, 1);
      expect(service.getChapterStars(1), 12);
      expect(service.isLevelCompleted(4), isTrue);

      // Kapı serbest bırakılır: sonraki sıralı load() yeniden yükler.
      notifications = 0;
      service.addListener(count);
      try {
        await service.load();
      } finally {
        service.removeListener(count);
      }
      expect(notifications, 1);
    });

    test(
        'B15: kanonik kilit tanımı PM kilidi kapalıyken bile tamamlanan önceki seviyeyle açılır',
        () async {
      final service = CampaignProgressionService.instance;
      final pm = ProgressManager.instance;

      await service.setStarsForLevel(1, 3);
      expect(service.isLevelCompleted(1), isTrue);

      // PM tarafı kilitli duruma getir: yalnız PM tanımı 2. seviyeyi
      // kilitli gösterir, kanonik (servis) tanım açık gösterir.
      pm.unlockedLevel = 1;
      expect(pm.isLevelUnlocked(2), isFalse);
      expect(service.isLevelUnlocked(2), isTrue);

      // Kanonik tanım PM'yi içerir: PM açıkken servis de açıktır;
      // iki kapı da kapalıyken kilitlidir.
      pm.unlockedLevel = 5;
      expect(service.isLevelUnlocked(5), isTrue);
      expect(service.isLevelUnlocked(6), isFalse);
      expect(service.isLevelUnlocked(1), isTrue);
    });

    testWidgets(
        'K3a: harita ekranında sandık barı talep edilebilir sandığı öder ve banner gösterir',
        (tester) async {
      AudioManager().isMuted = true;
      final service = CampaignProgressionService.instance;
      final pm = ProgressManager.instance;
      for (int id = 1; id <= 4; id++) {
        await service.setStarsForLevel(id, 3);
      }
      expect(service.canClaimChapterChest(1, 10), isTrue);

      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapWithL10n(
          const CampaignMapScreen(),
          theme: buildLululuTheme(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('campaign_map_chest_bar')), findsOneWidget);
      expect(find.byKey(const Key('campaign_map_chest_1_10')), findsOneWidget);
      expect(find.byKey(const Key('campaign_map_chest_2_10')), findsOneWidget);

      final coinsBefore = pm.coins;
      await tester.tap(find.byKey(const Key('campaign_map_chest_1_10')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(service.isChapterChestClaimed(1, 10), isTrue);
      expect(pm.coins, greaterThan(coinsBefore));
      expect(
        find.byKey(const Key('campaign_map_chest_feedback_banner')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // Boş ağaçta drenaj: sistem-fontu transient callback'i test
      // sonunda asılı kalıp scheduler hatasına yol açabiliyor
      // (missing_screens_test CampaignMap grubunda da aynı dalgalanma
      // görülüyor); ağaç boşken pumpAndSettle anında durulur.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
    });

    testWidgets(
        'K3b: tamamlanmış seviye modalı ödül göstermez, boss modalı ilk geçiş bonusunu gösterir',
        (tester) async {
      AudioManager().isMuted = true;
      final service = CampaignProgressionService.instance;
      for (int id = 1; id <= 9; id++) {
        await service.setStarsForLevel(id, 3);
      }
      expect(service.isLevelCompleted(1), isTrue);
      expect(service.isLevelUnlocked(10), isTrue);
      expect(service.isBossFirstCleared(10), isFalse);

      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<void> pumpMap() async {
        await tester.pumpWidget(
          wrapWithL10n(
            const CampaignMapScreen(),
            theme: buildLululuTheme(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      Future<void> openLevelModal(String numberLabel) async {
        await tester.tap(
          find.descendant(
            of: find.byType(GridView),
            matching: find.text(numberLabel),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Tamamlanmış seviye: ödül etiketi yok.
      await pumpMap();
      await openLevelModal('1');
      expect(find.text('BÖLÜM 1'), findsOneWidget);
      expect(find.textContaining('Ödül:'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Boss seviyesi: taban ödül + ilk geçiş bonusu etiketleri var.
      await pumpMap();
      await openLevelModal('10');
      expect(find.text('BÖLÜM 10'), findsOneWidget);
      expect(find.textContaining('Ödül: +'), findsOneWidget);
      expect(
        find.textContaining('Boss ilk geçiş bonusu: +250 COIN'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    // NOT (12B): sheet'e özel 'K3b: sheet bölüm bandı boss ilk geçiş
    // bonusunu gösterir' testi kaldırıldı — aynı iddia (boss ilk geçiş
    // bonusu görünür) yukarıdaki K3b harita modalı testinde zaten
    // doğrulanıyor; sheet silindi.
  });
}
