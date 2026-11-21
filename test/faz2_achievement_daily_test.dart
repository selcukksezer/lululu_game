import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/achievement_pass_service.dart';
import 'package:lululu_game/services/daily_challenge_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/finish_run.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/widgets/achievement_toast_overlay.dart';

import 'test_helpers.dart';

// FAZ 2 Dalga 3A: K1a (finishRun başarım/pass bağlama), K1b (boot
// yükleme kapısı — servis tarafı: uçuş koruması + senkron
// idempotency), K1c (sheet talep bildirimi), K2a (daily claim API).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
    await ProgressManager.instance.load();
    ProgressManager.instance.coins = 1000;
    ProgressManager.instance.modeHighScores.clear();
    await EnergyService.instance.load();
    await AchievementPassService.instance.resetForTesting();
    await AchievementPassService.instance.load();
    await DailyChallengeService.instance.load();
  });

  group('K2a — claimDailyChallengeReward', () {
    test('tamamlanmamış günde talep false döner, ödeme yapmaz', () async {
      final daily = DailyChallengeService.instance;
      expect(daily.completedToday, isFalse);
      final claimed = await daily.claimDailyChallengeReward();
      expect(claimed, isFalse);
      expect(ProgressManager.instance.coins, 1000);
      expect(daily.lastClaimDay, isNull);
      expect(daily.canClaimToday, isTrue);
    });

    test('tamamlanmış günde talep öder, canClaimToday false olur', () async {
      final daily = DailyChallengeService.instance;
      final completed = await daily.tryCompleteWithScore(
        daily.modeId,
        daily.targetScore,
      );
      expect(completed, isTrue);
      // Seri sıfırdan başlar: 40 + 1*15 + 80 (tamamlama bonusu) = 135.
      expect(daily.nextClaimRewardCoins, 135);
      final claimed = await daily.claimDailyChallengeReward();
      expect(claimed, isTrue);
      expect(ProgressManager.instance.coins, 1135);
      expect(daily.streak, 1);
      expect(daily.canClaimToday, isFalse);
    });

    test('çift talep engellenir (ardışık + eşzamanlı)', () async {
      final daily = DailyChallengeService.instance;
      await daily.tryCompleteWithScore(daily.modeId, daily.targetScore);
      expect(await daily.claimDailyChallengeReward(), isTrue);
      expect(await daily.claimDailyChallengeReward(), isFalse);
      expect(ProgressManager.instance.coins, 1135);

      // Eşzamanlı çift talep: biri kazanır, diğeri false döner.
      final results = await Future.wait([
        daily.claimDailyChallengeReward(),
        daily.claimDailyChallengeReward(),
      ]);
      expect(results, everyElement(isFalse));
      expect(ProgressManager.instance.coins, 1135);
    });

    test('talep kalıcıdır: yeniden yüklemede lastClaimDay + streak korunur',
        () async {
      final daily = DailyChallengeService.instance;
      await daily.tryCompleteWithScore(daily.modeId, daily.targetScore);
      expect(await daily.claimDailyChallengeReward(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final today = DailyChallengeService.dayKeyFor(DateTime.now());
      expect(prefs.getString('LululuDailyV1_lastClaim'), today);
      expect(prefs.getInt('LululuDailyV1_streak'), 1);

      await daily.load();
      expect(daily.lastClaimDay, today);
      expect(daily.streak, 1);
      expect(daily.canClaimToday, isFalse);
      expect(await daily.claimDailyChallengeReward(), isFalse);
    });

    test('son talep dünse seri devam eder (3 → 4, ödül 180)', () async {
      final daily = DailyChallengeService.instance;
      final today = DailyChallengeService.dayKeyFor(DateTime.now());
      final yesterday = DailyChallengeService.dayKeyFor(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'LululuDailyV1_day': today,
        'LululuDailyV1_streak': 3,
        'LululuDailyV1_lastClaim': yesterday,
      });
      await daily.load();
      expect(daily.streak, 3);
      expect(daily.lastClaimDay, yesterday);

      await daily.tryCompleteWithScore(daily.modeId, daily.targetScore);
      expect(daily.nextClaimRewardCoins, 40 + 4 * 15 + 80);
      expect(await daily.claimDailyChallengeReward(), isTrue);
      expect(daily.streak, 4);
      expect(ProgressManager.instance.coins, 1180);
    });

    test('son talep 2 gün önceyse seri sıfırlanır (5 → 1, ödül 135)',
        () async {
      final daily = DailyChallengeService.instance;
      final today = DailyChallengeService.dayKeyFor(DateTime.now());
      final twoDaysAgo = DailyChallengeService.dayKeyFor(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'LululuDailyV1_day': today,
        'LululuDailyV1_streak': 5,
        'LululuDailyV1_lastClaim': twoDaysAgo,
      });
      await daily.load();

      await daily.tryCompleteWithScore(daily.modeId, daily.targetScore);
      expect(await daily.claimDailyChallengeReward(), isTrue);
      expect(daily.streak, 1);
      expect(ProgressManager.instance.coins, 1135);
    });

    test('dayKeyFor saf yardımcı: mevcut sıfır-doldurmasız biçimi korur',
        () {
      expect(
        DailyChallengeService.dayKeyFor(DateTime(2026, 1, 5)),
        '2026-1-5',
      );
      expect(
        DailyChallengeService.dayKeyFor(DateTime(2026, 11, 18)),
        '2026-11-18',
      );
    });
  });

  group('K1a — evaluateModeScore mod-kimlik eşleşmesi', () {
    test('11 kanonik kimlik + takma adlar doğru başarımları açar', () async {
      final service = AchievementPassService.instance;
      const targets = <String, String>{
        'suika': 'mode_suika_master',
        'grid_2048': 'mode_2048_master',
        'balloon_pop': 'mode_balloon_master',
        'match3': 'mode_match3_master',
        'connect_pop': 'mode_connect_master',
        'stack_drop': 'mode_stack_master',
        'terlik_tap': 'mode_terlik_master',
        'yuva_defense': 'mode_yuva_master',
        'osmantus': 'mode_osmantus_master',
        'scream_roach': 'mode_scream_master',
        'makarayiz': 'mode_makarayiz_master',
      };
      for (final entry in targets.entries) {
        final def = service.getDefinition(entry.value)!;
        final unlocked = await service.evaluateModeScore(
          entry.key,
          def.targetValue,
        );
        expect(unlocked, isTrue, reason: entry.key);
        expect(service.isAchievementUnlocked(entry.value), isTrue);
      }
      expect(service.isAchievementUnlocked('mode_suika_master'), isTrue);
    });

    test('takma adlar (grid2048/2048/balloon) normalize edilir', () async {
      final service = AchievementPassService.instance;
      expect(await service.evaluateModeScore('grid2048', 2048), isTrue);
      expect(service.isAchievementUnlocked('mode_2048_master'), isTrue);
      expect(await service.evaluateModeScore('balloon', 1500), isTrue);
      expect(service.isAchievementUnlocked('mode_balloon_master'), isTrue);
      expect(await service.evaluateModeScore('bilinmeyen_mod', 99999), isFalse);
    });
  });

  group('K1b — load uçuş koruması + senkron idempotency', () {
    test('eşzamanlı load/ensureLoaded çağrıları tek yüklemeyi paylaşır',
        () async {
      final service = AchievementPassService.instance;
      await service.unlockAchievement('merge_first');
      await Future.wait([
        service.load(),
        service.load(),
        service.ensureLoaded(),
      ]);
      expect(service.isLoaded, isTrue);
      expect(service.isAchievementUnlocked('merge_first'), isTrue);
    });

    test('syncWithProgressManager idempotenttir: ikinci çağrı ödül vermez',
        () async {
      final service = AchievementPassService.instance;
      final pm = ProgressManager.instance;
      await pm.recordModeScore('suika', 3000);
      pm.coins = 10000;

      final first = await service.syncWithProgressManager();
      // W13-D: mode_suika_master + eco_10000_coins — eco_all_33_boosters
      // ARTIK tohum stoklarıyla açılmaz (taze PM'de kazanılan güç yok).
      expect(first, 2);
      expect(service.isAchievementUnlocked('mode_suika_master'), isTrue);
      expect(service.isAchievementUnlocked('eco_10000_coins'), isTrue);
      expect(service.isAchievementUnlocked('eco_all_33_boosters'), isFalse);
      final coinsAfterFirst = pm.coins;
      expect(coinsAfterFirst, 10000 + 350 + 1000);

      final second = await service.syncWithProgressManager();
      expect(second, 0);
      expect(pm.coins, coinsAfterFirst);

      // 33 güç türü de kazanılınca üçüncü senkron başarımı açar.
      for (final key in ProgressManager.all33PowerKeys) {
        await pm.addPower(key);
      }
      final third = await service.syncWithProgressManager();
      expect(third, 1);
      expect(service.isAchievementUnlocked('eco_all_33_boosters'), isTrue);
      expect(pm.coins, coinsAfterFirst + 1500);
    });
  });

  group('K1a — finishRun achievements adımı', () {
    testWidgets('tur sonu ustalık başarımını açar + tur XP verir',
        (tester) async {
      final host = _RunHost();
      await host.pump(
        tester,
        (context) => finishRun(
          context,
          score: 2100,
          best: 0,
          coins: 0,
          stars: 2,
          modeScoreId: 'terlik_tap',
        ),
      );
      await host.tap(tester);

      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);
      final service = AchievementPassService.instance;
      expect(service.isAchievementUnlocked('mode_terlik_master'), isTrue);
      // 175 (başarım XP) + 20 (tur XP: 10 + 5*2 yıldız).
      expect(service.seasonXp, 195);
      // Ödeme 0; yalnız başarım ödülü (400 coin).
      expect(ProgressManager.instance.coins, 1400);

      await host.dismiss(tester);
      expect(await host.pending, isFalse);
    });

    testWidgets('skor 0 ise tur XP verilmez', (tester) async {
      final host = _RunHost();
      await host.pump(
        tester,
        (context) => finishRun(
          context,
          score: 0,
          best: 0,
          modeScoreId: 'terlik_tap',
        ),
      );
      await host.tap(tester);

      expect(AchievementPassService.instance.seasonXp, 0);
      expect(
        AchievementPassService.instance.isAchievementUnlocked(
          'mode_terlik_master',
        ),
        isFalse,
      );

      await host.dismiss(tester);
      expect(await host.pending, isFalse);
    });
  });

  group('K1c — sheet talep bildirimi (S3)', () {
    testWidgets('kademe talebi başarıda ses + snackbar gösterir',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final service = AchievementPassService.instance;
      await service.addSeasonXp(120, reason: 's3_test');

      await pumpWithL10n(
        tester,
        const Scaffold(body: AchievementPassSheet()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab_season_pass_btn')));
      await tester.pumpAndSettle();
      final freeBtn = find.byKey(const Key('pass_free_btn_1'));
      await tester.ensureVisible(freeBtn);
      await tester.pumpAndSettle();
      final coinsBefore = ProgressManager.instance.coins;
      await tester.tap(freeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(ProgressManager.instance.coins, coinsBefore + 150);
      expect(service.isPassTierClaimed(1), isTrue);
      expect(find.text('150 Altın alındı!'), findsOneWidget);

      // _RunHost.dismiss ile aynı teardown koruması (geç font
      // yüklemesinin engine mesajı).
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
    });
  });
}

/// `finishRun` akışını bir düğmeyle tetikleyen test ana ekranı
/// (finish_run_leaderboard_2c_test.dart `_RunHost` deseninin aynısı).
class _RunHost {
  Future<bool>? pending;

  Future<void> pump(
    WidgetTester tester,
    Future<bool> Function(BuildContext context) run,
  ) async {
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
  }

  Future<void> tap(WidgetTester tester) async {
    await tester.tap(find.text('TURU BITIR'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> dismiss(WidgetTester tester) async {
    await tester.tap(find.text('ANA SAYFA'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Sistem fontu mesajının bıraktığı geçici kare geri çağrısını
    // sökümden önce tüket (yoksa teardown "animation is still
    // running" ile düşer — 2C testlerinde de görülen ortam etkisi;
    // geç font yüklemesinin engine mesajı gerçek zaman ister).
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }
}
