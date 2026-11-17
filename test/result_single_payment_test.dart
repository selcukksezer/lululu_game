import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/services/finish_run.dart';
import 'package:lululu_game/services/progress_manager.dart';

// ÖDEME SÖZLEŞMESİ (S1#49, lib/services/finish_run.dart + sonuç ekranı):
// tur ödülünü TEK noktadan `finishRun` öder; sonuç ekranı
// `coinsAwardedByCaller` varsayılanı (`true`) ile tekrar ödemez.
// `settle` veren çağırıcı ödemeyi yalnızca o kapama içinde yapar,
// yardımcı ayrıca ödemez. Bu dosya sözleşmenin iki ucunu da kapsar:
// `finishRun` birleşik akışı + sonuç ekranının kendi ödeme davranışı
// + skor→coin formülü.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    ProgressManager.instance.coins = 1000;
  });

  Future<void> pumpResult(
    WidgetTester tester, {
    required int coins,
    required bool coinsAwardedByCaller,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameResultScreen(
          score: 500,
          coins: coins,
          stars: 2,
          coinsAwardedByCaller: coinsAwardedByCaller,
        ),
      ),
    );
    await tester.pump();
  }

  group('ResultScoring.coinsFor', () {
    test('skor 100 altında coin vermez', () {
      expect(ResultScoring.coinsFor(0), 0);
      expect(ResultScoring.coinsFor(99), 0);
    });

    test('her 100 skor 1 coin eder', () {
      expect(ResultScoring.coinsFor(100), 1);
      expect(ResultScoring.coinsFor(250), 2);
      expect(ResultScoring.coinsFor(10000), 100);
    });

    test('negatif skor coin vermez', () {
      expect(ResultScoring.coinsFor(-50), 0);
    });
  });

  testWidgets('çağırıcı ödediğinde sonuç ekranı tekrar ödemez', (
    tester,
  ) async {
    await pumpResult(tester, coins: 50, coinsAwardedByCaller: true);
    expect(ProgressManager.instance.coins, 1000);

    // Yeniden çizim (aynı State) de ödeme yapmaz: çift ödeme yok.
    await pumpResult(tester, coins: 50, coinsAwardedByCaller: true);
    expect(ProgressManager.instance.coins, 1000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('coinsAwardedByCaller false ise tam bir kez öder', (
    tester,
  ) async {
    await pumpResult(tester, coins: 50, coinsAwardedByCaller: false);
    expect(ProgressManager.instance.coins, 1050);

    // Yeniden çizim ikinci ödeme yapmaz.
    await pumpResult(tester, coins: 50, coinsAwardedByCaller: false);
    expect(ProgressManager.instance.coins, 1050);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('sıfır coin ödemesi bakiyeyi değiştirmez', (tester) async {
    await pumpResult(tester, coins: 0, coinsAwardedByCaller: false);
    expect(ProgressManager.instance.coins, 1000);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  group('finishRun tek-ödeme akışı', () {
    Future<void> pumpHost(
      WidgetTester tester,
      Future<bool> Function(BuildContext context) run,
    ) async {
      Future<bool>? pending;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  pending = run(context);
                },
                child: const Text('TURU BITIR'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('TURU BITIR'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Bekleyen gelecek, çağıran testte kapatılır (sonuç ekranı
      // kapatılınca tamamlanır); burada yalnız akış ilerletilir.
      _pendingRun = pending;
    }

    Future<void> dismissResult(WidgetTester tester) async {
      await tester.tap(find.text('ANA SAYFA'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('varsayılan ödeme tam bir kez yapılır, ekran tekrar ödemez', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context) => finishRun(context, score: 500, best: 0),
      );
      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);
      expect(ProgressManager.instance.coins, 1005);

      await dismissResult(tester);

      expect(find.text('SEVİYE TAMAM!'), findsNothing);
      expect(ProgressManager.instance.coins, 1005);
      expect(await _pendingRun, isFalse);
    });

    testWidgets('açık coin tutarı aynen bir kez ödenir', (tester) async {
      await pumpHost(
        tester,
        (context) => finishRun(context, score: 500, best: 0, coins: 40),
      );
      expect(ProgressManager.instance.coins, 1040);

      await dismissResult(tester);

      expect(ProgressManager.instance.coins, 1040);
      expect(await _pendingRun, isFalse);
    });

    testWidgets('özel settle varsayılan ödemenin yerini alır, çift ödeme yok',
        (tester) async {
      var settleCalls = 0;
      await pumpHost(
        tester,
        (context) => finishRun(
          context,
          score: 500,
          best: 0,
          settle: () async {
            settleCalls++;
            await ProgressManager.instance.addCoins(7);
          },
        ),
      );
      expect(settleCalls, 1);
      // Yalnız settle'ın 7 coini var; varsayılan 5 coin ayrıca ödenmedi.
      expect(ProgressManager.instance.coins, 1007);

      await dismissResult(tester);

      expect(settleCalls, 1);
      expect(ProgressManager.instance.coins, 1007);
      expect(await _pendingRun, isFalse);
    });

    testWidgets('stillValid false ise ekran açılmaz ama ödeme yapılmıştır',
        (tester) async {
      await pumpHost(
        tester,
        (context) => finishRun(
          context,
          score: 500,
          best: 0,
          stillValid: () => false,
        ),
      );

      expect(find.text('SEVİYE TAMAM!'), findsNothing);
      expect(ProgressManager.instance.coins, 1005);
      expect(await _pendingRun, isFalse);
    });
  });
}

/// Son `pumpHost` çağrısının bekleyen `finishRun` geleceği. Test
/// başına tek akış çalıştırıldığı için paylaşılan tek yuva yeterlidir.
Future<bool>? _pendingRun;
