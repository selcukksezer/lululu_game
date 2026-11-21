import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/services/campaign_progression_service.dart';
import 'package:lululu_game/services/finish_run.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

import 'test_helpers.dart';

// 5B — sonuç ekranında ilk-tamamlama ekstraları (salt-görünüm):
// `recordLevelCompletion` özetinden türetilir
// (`coinsAwarded` − yıldız ödemesi; boss kısmı
// `bossFirstClearBonusCoins` alanından), ödeme hesabı yeniden yapılmaz.
// Ödeme yolu değişmez: tek `recordLevelCompletion` çağrısı, aynı
// argümanlar; bant ödeme yapmaz ve coin hapına eklenmez.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
    await ProgressManager.instance.load();
    await CampaignProgressionService.instance.resetForTesting();
    await CampaignProgressionService.instance.load();
    ProgressManager.instance.coins = 1000;
  });

  group('FirstClearExtras.fromSummary türetme', () {
    test('ilk tamamlama (boss değil): ekstralar seviye ödülüne eşittir', () {
      // Seviye 1: yıldız ödemesi 150 + taban ödül 93 = 243.
      final extras = FirstClearExtras.fromSummary(
        coinsAwarded: 243,
        bossFirstClearBonusCoins: 0,
        starCoins: 150,
      );
      expect(extras.levelRewardCoins, 93);
      expect(extras.bossBonusCoins, 0);
      expect(extras.total, 93);
      expect(extras.isEmpty, isFalse);
      expect(extras.isNotEmpty, isTrue);
    });

    test('boss ilk geçişi: taban ödül + boss bonusu ayrışır', () {
      // Seviye 10: yıldız 150 + taban 285 + boss 250 = 685.
      final extras = FirstClearExtras.fromSummary(
        coinsAwarded: 685,
        bossFirstClearBonusCoins: 250,
        starCoins: 150,
      );
      expect(extras.levelRewardCoins, 285);
      expect(extras.bossBonusCoins, 250);
      expect(extras.total, 535);
    });

    test('tekrar tamamlama: yıldız ödemesinden fazlası yoksa bant boştur',
        () {
      final sameStars = FirstClearExtras.fromSummary(
        coinsAwarded: 0,
        bossFirstClearBonusCoins: 0,
        starCoins: 0,
      );
      expect(sameStars.isEmpty, isTrue);
      expect(sameStars.total, 0);

      final newStars = FirstClearExtras.fromSummary(
        coinsAwarded: 50,
        bossFirstClearBonusCoins: 0,
        starCoins: 50,
      );
      expect(newStars.isEmpty, isTrue);
    });

    test('tekrar tamamlamada ilk boss geçişi: yalnız boss satırı', () {
      final extras = FirstClearExtras.fromSummary(
        coinsAwarded: 250,
        bossFirstClearBonusCoins: 250,
        starCoins: 0,
      );
      expect(extras.levelRewardCoins, 0);
      expect(extras.bossBonusCoins, 250);
      expect(extras.isNotEmpty, isTrue);
    });

    test('savunmacı kısma: negatif ve tutarsız girdiler taşmaz', () {
      final negative = FirstClearExtras.fromSummary(
        coinsAwarded: 10,
        bossFirstClearBonusCoins: 0,
        starCoins: 150,
      );
      expect(negative.isEmpty, isTrue);

      final bossOverflow = FirstClearExtras.fromSummary(
        coinsAwarded: 200,
        bossFirstClearBonusCoins: 500,
        starCoins: 150,
      );
      expect(bossOverflow.levelRewardCoins, 0);
      expect(bossOverflow.bossBonusCoins, 50);
      expect(bossOverflow.total, 50);

      final allNegative = FirstClearExtras.fromSummary(
        coinsAwarded: -5,
        bossFirstClearBonusCoins: -10,
        starCoins: -20,
      );
      expect(allNegative.isEmpty, isTrue);
    });
  });

  group('GameResultScreen ekstralar bandı', () {
    Future<void> pumpResult(
      WidgetTester tester, {
      FirstClearExtras extras = const FirstClearExtras(),
      Locale locale = const Locale('tr'),
    }) async {
      // Telefon görünümü: sonuç ekranı 800x600 varsayılan görünümde
      // taşar (finish_run_leaderboard_2c_test.dart deseni).
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpWithL10n(
        tester,
        GameResultScreen(
          score: 2000,
          coins: 150,
          stars: 3,
          firstClearExtras: extras,
        ),
        locale: locale,
      );
      await tester.pump();
      // flutter_animate tek-atımlık efektleri (maskot/sandık, ~550ms)
      // bitsin: süreli pump olmadan sıfır-süreli yeniden-başlatma
      // zamanlayıcıları ağaç kaldırılırken beklemede kalır ve test
      // "Timer is still pending" ile düşer.
      await tester.pump(const Duration(seconds: 2));
    }

    /// Ağacı kaldırıp bekleyen kare geri çağrılarını boşaltır: motorun
    /// 'fontsChange' bildirimi gerçek zamanlı gelir (shop_confirm_test
    /// deseni) — FakeAsync dışında bekleyip bildirimin gelmesini
    /// sağla, sonra ağacı kaldırıp planlanan geri çağrıyı pompalarla
    /// akıt; yoksa test sonu denetimi "animation is still running"
    /// ile düşer.
    Future<void> disposeResult(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump();
    }

    testWidgets('iki satır gösterilir, coin hapı yalnız skor tutarıdır',
        (tester) async {
      await pumpResult(
        tester,
        extras: const FirstClearExtras(
          levelRewardCoins: 93,
          bossBonusCoins: 250,
        ),
      );
      expect(find.byKey(const Key('result_first_clear_extras')), findsOneWidget);
      expect(find.text('Ödül: +93 COIN'), findsOneWidget);
      expect(find.text('Boss ilk geçiş bonusu: +250 COIN'), findsOneWidget);
      // Coin hapı ekstraları içermez: yalnız `coins` (150) gösterilir.
      expect(find.text('+150'), findsOneWidget);
      // Bant ödeme yapmaz.
      expect(ProgressManager.instance.coins, 1000);

      await disposeResult(tester);
    });

    testWidgets('boş ekstralarda bant çizilmez (diğer çağırıcılar aynen)',
        (tester) async {
      await pumpResult(tester);
      expect(find.byKey(const Key('result_first_clear_extras')), findsNothing);
      expect(find.textContaining('Ödül:'), findsNothing);
      expect(find.textContaining('Boss ilk geçiş'), findsNothing);
      expect(ProgressManager.instance.coins, 1000);

      await disposeResult(tester);
    });

    testWidgets('yalnız seviye ödülü: boss satırı çizilmez', (tester) async {
      await pumpResult(
        tester,
        extras: const FirstClearExtras(levelRewardCoins: 93),
      );
      expect(find.byKey(const Key('result_first_clear_extras')), findsOneWidget);
      expect(find.text('Ödül: +93 COIN'), findsOneWidget);
      expect(find.textContaining('Boss ilk geçiş'), findsNothing);

      await disposeResult(tester);
    });

    testWidgets('yalnız boss bonusu: ödül satırı çizilmez', (tester) async {
      await pumpResult(
        tester,
        extras: const FirstClearExtras(bossBonusCoins: 250),
      );
      expect(find.byKey(const Key('result_first_clear_extras')), findsOneWidget);
      expect(find.text('Boss ilk geçiş bonusu: +250 COIN'), findsOneWidget);
      expect(find.textContaining('Ödül:'), findsNothing);

      await disposeResult(tester);
    });

    testWidgets('EN dilinde mevcut anahtarların EN karşılıkları gösterilir',
        (tester) async {
      await pumpResult(
        tester,
        extras: const FirstClearExtras(
          levelRewardCoins: 93,
          bossBonusCoins: 250,
        ),
        locale: const Locale('en'),
      );
      expect(find.text('Reward: +93 COIN'), findsOneWidget);
      expect(find.text('Boss first-clear bonus: +250 COIN'), findsOneWidget);

      await disposeResult(tester);
    });
  });

  group('finishRun + özet akışı (game_screen zafer kablolaması)', () {
    /// `game_screen.dart::_triggerVictory` settle kablolamasının birebir
    /// aynısı: kayıt-öncesi yıldız okuma, tek `recordLevelCompletion`
    /// çağrısı, özetten türetme, `awaitSettle: false` + getter.
    Future<bool> Function(BuildContext) victoryRun({
      required int levelId,
      required int score,
      required int stars,
      required String idempotencyKey,
    }) {
      return (context) {
        final pm = ProgressManager.instance;
        final previousStars = pm.getStarCount(levelId);
        final starGain = max(0, stars - previousStars);
        final starCoins = starGain * 50;
        final earnedCoins = ResultScoring.coinsFor(score);
        final totalCoins = max(earnedCoins, starCoins);
        final extraCoins = earnedCoins - starCoins;
        var capturedExtras = const FirstClearExtras();
        return finishRun(
          context,
          score: score,
          best: 0,
          coins: totalCoins,
          stars: stars,
          bestScore: score,
          bestCombo: 1,
          merges: 0,
          modeScoreId: LeaderboardService.modeSuika,
          idempotencyKey: idempotencyKey,
          awaitSettle: false,
          firstClearExtras: () => capturedExtras,
          settle: () async {
            final summary = await CampaignProgressionService.instance
                .recordLevelCompletion(
              levelNumber: levelId,
              score: score,
              explicitStars: stars,
              victory: true,
            );
            capturedExtras = FirstClearExtras.fromSummary(
              coinsAwarded: summary.coinsAwarded,
              bossFirstClearBonusCoins: summary.bossFirstClearBonusCoins,
              starCoins: starCoins,
            );
            if (extraCoins > 0) {
              await pm.addCoins(extraCoins);
            }
          },
        );
      };
    }

    Future<Future<bool>?> pumpAndRun(
      WidgetTester tester,
      Future<bool> Function(BuildContext) run,
    ) async {
      Future<bool>? pending;
      // Telefon görünümü: sonuç ekranı 800x600 varsayılan görünümde
      // taşar, ANA SAYFA ekran dışında kalır, dokunma ıskalar ve
      // `await pending` asılır (finish_run_leaderboard_2c_test.dart
      // deseni).
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpWithL10n(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                pending = run(context);
              },
              child: const Text('TURU BITIR'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('TURU BITIR'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return pending;
    }

    Future<void> dismissResult(WidgetTester tester) async {
      await tester.tap(find.text('ANA SAYFA'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('ilk tamamlama: bant gösterilir, ödeme tam bir kez yapılır',
        (tester) async {
      final level1 = CampaignDatabase.getLevel(1);
      expect(level1.rewardCoins, 93);

      final pending = await pumpAndRun(
        tester,
        victoryRun(
          levelId: 1,
          score: 2000,
          stars: 3,
          idempotencyKey: 'test-5b:1',
        ),
      );
      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);
      expect(find.byKey(const Key('result_first_clear_extras')), findsOneWidget);
      expect(find.text('Ödül: +93 COIN'), findsOneWidget);
      expect(find.textContaining('Boss ilk geçiş'), findsNothing);
      // Tek ödeme: yıldız 150 + taban 93 = 243; varsayılan ödeme ve
      // çift ödeme yok, bant ayrıca ödemez.
      expect(ProgressManager.instance.coins, 1243);

      await dismissResult(tester);
      expect(ProgressManager.instance.coins, 1243);
      expect(await pending, isFalse);
    });

    testWidgets('tekrar tamamlama: bant yoktur, yalnız skor-fark coini ödenir',
        (tester) async {
      final first = await pumpAndRun(
        tester,
        victoryRun(
          levelId: 1,
          score: 2000,
          stars: 3,
          idempotencyKey: 'test-5b:repeat-1',
        ),
      );
      expect(find.byKey(const Key('result_first_clear_extras')), findsOneWidget);
      expect(ProgressManager.instance.coins, 1243);
      await dismissResult(tester);
      expect(await first, isFalse);

      final second = await pumpAndRun(
        tester,
        victoryRun(
          levelId: 1,
          score: 2000,
          stars: 3,
          idempotencyKey: 'test-5b:repeat-2',
        ),
      );
      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);
      expect(find.byKey(const Key('result_first_clear_extras')), findsNothing);
      // Tekrarda ilk-tamamlama ekstrası ödenmez (bant yok); bakiyedeki
      // +20, önceden var olan skor-fark ödemesidir: yıldız artışı 0
      // olduğundan extraCoins = earnedCoins (2000 skor → 20 coin).
      expect(ProgressManager.instance.coins, 1263);

      await dismissResult(tester);
      expect(ProgressManager.instance.coins, 1263);
      expect(await second, isFalse);
    });

    testWidgets('boss ilk geçişi: iki satır + tek ödeme', (tester) async {
      final boss10 = CampaignDatabase.getLevel(10);
      expect(boss10.rewardCoins, 285);
      expect(boss10.firstClearBonusCoins, 250);

      final pending = await pumpAndRun(
        tester,
        victoryRun(
          levelId: 10,
          // Skor 2000: Suika ustası başarım eşiğinin (2500, +350 coin)
          // altında tutulur ki kampanya ödemesi (685) başarım
          // ödemesinden yalıtılmış ölçülsün.
          score: 2000,
          stars: 3,
          idempotencyKey: 'test-5b:boss-1',
        ),
      );
      expect(find.byKey(const Key('result_first_clear_extras')), findsOneWidget);
      expect(find.text('Ödül: +285 COIN'), findsOneWidget);
      expect(find.text('Boss ilk geçiş bonusu: +250 COIN'), findsOneWidget);
      // Tek ödeme: yıldız 150 + taban 285 + boss 250 = 685.
      expect(ProgressManager.instance.coins, 1685);

      await dismissResult(tester);
      expect(ProgressManager.instance.coins, 1685);
      expect(await pending, isFalse);
    });

    testWidgets('getter verilmezse bant yoktur, ödeme yine tek olur',
        (tester) async {
      Future<bool>? pending;
      // Telefon görünümü (yukarıdaki pumpAndRun ile aynı gerekçe:
      // 800x600'de ANA SAYFA ekran dışında kalır, dokunma ıskalar).
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpWithL10n(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                pending = finishRun(
                  context,
                  score: 2000,
                  best: 0,
                  coins: 150,
                  stars: 3,
                  settle: () async {
                    await CampaignProgressionService.instance
                        .recordLevelCompletion(
                      levelNumber: 1,
                      score: 2000,
                      explicitStars: 3,
                      victory: true,
                    );
                  },
                );
              },
              child: const Text('TURU BITIR'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('TURU BITIR'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);
      expect(find.byKey(const Key('result_first_clear_extras')), findsNothing);
      expect(ProgressManager.instance.coins, 1243);

      await dismissResult(tester);
      expect(ProgressManager.instance.coins, 1243);
      expect(await pending, isFalse);
    });
  });
}
