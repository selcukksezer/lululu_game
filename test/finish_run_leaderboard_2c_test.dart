import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/cloud_sync_service.dart';
import 'package:lululu_game/services/daily_challenge_service.dart';
import 'package:lululu_game/services/finish_run.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

import 'test_helpers.dart';

// Dalga 2C bulguları (K2/Y1/Y2/Y3/O6/O7/B8/F10-kuralı):
// `finish_run.dart` + `leaderboard_service.dart` düzeltmelerinin
// regresyon testleri.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await LeaderboardService.instance.load();
    await ProgressManager.instance.load();
    ProgressManager.instance.coins = 1000;
    ProgressManager.instance.modeHighScores.clear();
    CloudSyncService.instance.pending.clear();
  });

  group('F10-kuralı: skor>0 ise en az 1 coin (varsayılan)', () {
    testWidgets('skor 100 altında varsayılan ödeme 1 coindir', (
      tester,
    ) async {
      final host = _RunHost();
      await host.pump(
        tester,
        (context) => finishRun(context, score: 50, best: 0),
      );
      await host.tap(tester);

      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);
      expect(ProgressManager.instance.coins, 1001);

      await host.dismiss(tester);
      expect(await host.pending, isFalse);
    });

    testWidgets('skor 0 ise varsayılan ödeme 0 coindir', (tester) async {
      final host = _RunHost();
      await host.pump(
        tester,
        (context) => finishRun(context, score: 0, best: 0),
      );
      await host.tap(tester);

      expect(find.text('ANA SAYFA'), findsOneWidget);
      expect(ProgressManager.instance.coins, 1000);

      await host.dismiss(tester);
      expect(await host.pending, isFalse);
    });

    testWidgets('açık coin tutarı aynen ödenir (F10 yalnız varsayılan)',
        (tester) async {
      final host = _RunHost();
      await host.pump(
        tester,
        (context) => finishRun(context, score: 500, best: 0, coins: 0),
      );
      await host.tap(tester);

      expect(ProgressManager.instance.coins, 1000);

      await host.dismiss(tester);
      expect(await host.pending, isFalse);
    });
  });

  group('Y1/B8: settle adım yalıtımı', () {
    testWidgets('ödeme adımı hata verse bile kayıtlar ve diyalog çalışır',
        (tester) async {
      final playBefore = ProgressManager.instance.getTaskProgress('play');
      final host = _RunHost();
      await host.pump(
        tester,
        (context) => finishRun(
          context,
          score: 500,
          best: 0,
          modeScoreId: 'balloon_pop',
          settle: () async {
            throw StateError('ödeme hatası');
          },
        ),
      );
      await host.tap(tester);

      // Diyalog gösterildi, sonraki adımlar kaydedildi.
      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);
      expect(
        ProgressManager.instance.getModeHighScore('balloon_pop'),
        500,
      );
      expect(
        ProgressManager.instance.getTaskProgress('play'),
        playBefore + 1,
      );
      // Hata veren settle ödeme yapmadı.
      expect(ProgressManager.instance.coins, 1000);

      await host.dismiss(tester);
      expect(await host.pending, isFalse);
    });
  });

  group('Y2: geçerlilik ödeme öncesinde', () {
    testWidgets('stillValid false ise özel settle hiç çalışmaz',
        (tester) async {
      var settleCalls = 0;
      final host = _RunHost();
      await host.pump(
        tester,
        (context) => finishRun(
          context,
          score: 500,
          best: 0,
          settle: () async {
            settleCalls++;
            await ProgressManager.instance.addCoins(7);
          },
          stillValid: () => false,
        ),
      );
      await host.tap(tester);

      expect(settleCalls, 0);
      expect(ProgressManager.instance.coins, 1000);
      expect(find.text('SEVİYE TAMAM!'), findsNothing);
      expect(await host.pending, isFalse);
    });
  });

  group('Y3: idempotency anahtarı', () {
    testWidgets('aynı anahtarla ikinci çağrı ödemez, farklı anahtar öder',
        (tester) async {
      var currentKey = 'y3-run-1';
      final host = _RunHost();
      await host.pump(
        tester,
        (context) => finishRun(
          context,
          score: 500,
          best: 0,
          idempotencyKey: currentKey,
        ),
      );

      await host.tap(tester);
      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);
      expect(ProgressManager.instance.coins, 1005);
      await host.dismiss(tester);
      expect(await host.pending, isFalse);

      // Aynı anahtar: ödeme yok, diyalog yok.
      await host.tap(tester);
      expect(find.text('SEVİYE TAMAM!'), findsNothing);
      expect(ProgressManager.instance.coins, 1005);
      expect(await host.pending, isFalse);

      // Farklı anahtar: ayrı tur, ödeme yapılır.
      currentKey = 'y3-run-2';
      await host.tap(tester);
      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);
      expect(ProgressManager.instance.coins, 1010);
      await host.dismiss(tester);
      expect(await host.pending, isFalse);
    });
  });

  group('K2: tahta yüklemesi PM skorlarını silmez', () {
    test('boş tahta yüklemesi PM skorlarını korur', () async {
      final pm = ProgressManager.instance;
      pm.modeHighScores['suika'] = 5000;
      pm.modeHighScores['grid_2048'] = 3000;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LeaderboardService.prefsKey,
        jsonEncode({'modes': <dynamic>[]}),
      );

      await LeaderboardService.instance.load();

      expect(pm.getModeHighScore('suika'), 5000);
      expect(pm.getModeHighScore('grid_2048'), 3000);
    });

    test('tahta skoru yüksekse PM güncellenir, düşükse PM korunur',
        () async {
      final auth = AuthService.instance;
      final uid = auth.playerId;
      final pm = ProgressManager.instance;
      pm.modeHighScores['suika'] = 5000;
      pm.modeHighScores['grid_2048'] = 5000;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LeaderboardService.prefsKey,
        jsonEncode({
          'modes': [
            {
              'modeId': 'suika',
              'bestScore': 6000,
              'top': [
                {
                  'modeId': 'suika',
                  'playerId': uid,
                  'playerName': auth.displayName,
                  'score': 6000,
                  'utcTicks': 1,
                  'isLocalPlayer': true,
                  'country': 'TR',
                },
              ],
            },
            {
              'modeId': 'grid_2048',
              'bestScore': 100,
              'top': [
                {
                  'modeId': 'grid_2048',
                  'playerId': uid,
                  'playerName': auth.displayName,
                  'score': 100,
                  'utcTicks': 1,
                  'isLocalPlayer': true,
                  'country': 'TR',
                },
              ],
            },
          ],
        }),
      );

      await LeaderboardService.instance.load();

      expect(pm.getModeHighScore('suika'), 6000);
      expect(pm.getModeHighScore('grid_2048'), 5000);
      expect(LeaderboardService.instance.getBest('suika'), 6000);
    });
  });

  group('O6: bozuk tahta ayrıştırması', () {
    test('bozuk kayıt/tahta atlanır, sağlam kayıtlar korunur', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LeaderboardService.prefsKey,
        jsonEncode({
          'modes': [
            {
              'modeId': 'suika',
              'bestScore': 1500,
              'top': [
                {
                  'modeId': 'suika',
                  'playerId': 'p1',
                  'playerName': 'Oyuncu1',
                  'score': 1500,
                  'utcTicks': 1,
                  'isLocalPlayer': false,
                  'country': 'TR',
                },
                'BOZUK-KAYIT',
                {
                  'modeId': 'suika',
                  'playerId': 'p2',
                  'playerName': 'Oyuncu2',
                  'score': 'metin-skor',
                  'utcTicks': 1,
                  'isLocalPlayer': false,
                  'country': 'TR',
                },
              ],
            },
            'BOZUK-TAHTA',
            {
              'modeId': 'grid_2048',
              'bestScore': 2000,
              'top': [
                {
                  'modeId': 'grid_2048',
                  'playerId': 'p1',
                  'playerName': 'Oyuncu1',
                  'score': 2000,
                  'utcTicks': 1,
                  'isLocalPlayer': false,
                  'country': 'TR',
                },
              ],
            },
          ],
        }),
      );

      await LeaderboardService.instance.load();

      final suika = LeaderboardService.instance.getTop('suika');
      expect(suika.length, 1);
      expect(suika.first.score, 1500);
      expect(LeaderboardService.instance.getTop('grid_2048').length, 1);
    });

    test('bütünüyle bozuk JSON yedeklenir, boş tahtayla devam edilir',
        () async {
      const raw = '{bozuk json,,,';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LeaderboardService.prefsKey, raw);

      await LeaderboardService.instance.load();

      expect(LeaderboardService.instance.getTop('suika'), isEmpty);
      expect(
        prefs.getString(LeaderboardService.corruptBackupPrefsKey),
        raw,
      );
    });

    test('yanlış şekilli JSON yedeklenir', () async {
      const raw = '[{"modeId":"suika"}]';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LeaderboardService.prefsKey, raw);

      await LeaderboardService.instance.load();

      expect(LeaderboardService.instance.getTop('suika'), isEmpty);
      expect(
        prefs.getString(LeaderboardService.corruptBackupPrefsKey),
        raw,
      );
    });
  });

  group('O7: yan etkiler yalnız tahta değişince', () {
    test('iyileştirmeyen gönderim görev/kuyruk tetiklemez', () async {
      final board = LeaderboardService.instance;
      final daily = DailyChallengeService.instance;
      final cloud = CloudSyncService.instance;
      await daily.ensureLoaded();
      daily.modeId = LeaderboardService.modeSuika;
      daily.targetScore = 1000;
      daily.completedToday = false;

      final first = await board.submitScore(LeaderboardService.modeSuika, 1500);
      expect(first, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(daily.completedToday, isTrue);
      expect(cloud.pending.length, 1);

      daily.completedToday = false;
      cloud.pending.clear();
      final second =
          await board.submitScore(LeaderboardService.modeSuika, 1500);
      expect(second, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(daily.completedToday, isFalse);
      expect(cloud.pending, isEmpty);
      expect(board.getTop(LeaderboardService.modeSuika).length, 1);
    });
  });
}

/// `finishRun` akışını bir düğmeyle tetikleyen test ana ekranı.
class _RunHost {
  Future<bool>? pending;

  Future<void> pump(
    WidgetTester tester,
    Future<bool> Function(BuildContext context) run,
  ) async {
    // Sonuç ekranı 800x600 varsayılan görünümde taşar (ANA SAYFA
    // düğmesi ekran dışında kalır, dokunma ıskalar); telefon
    // görünümü (430x932) kullanılır.
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
  }
}
