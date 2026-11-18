import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_tr.dart';
import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/finish_run.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

import 'test_helpers.dart';

// S7 (koordinatör takibi): finishRun, playTask adımında
// recordTaskProgressDetailed kullanır; bu turda yeni tamamlanan görev
// varsa sonuç ekranı kapandıktan sonra görev başlıklı snackbar gösterir
// (ödül Görevler ekranından alınır, burada ödenmez).
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
  });

  Future<void> seedPlay(int n) async {
    for (var i = 0; i < n; i++) {
      await ProgressManager.instance.recordTaskProgress('play');
    }
    expect(ProgressManager.instance.getTaskProgress('play'), n);
  }

  group('S7 — görev-tamamlanma bildirimi', () {
    testWidgets('eşik bu turda aşılırsa sonuç sonrası snackbar görünür',
        (tester) async {
      await seedPlay(2);
      final l10n = AppLocalizationsTr();
      final expected = l10n.taskCompletedSnack(l10n.taskPlay3Games);

      final host = _RunHostS7();
      await host.pump(
        tester,
        (context) => finishRun(context, score: 50, best: 0),
      );
      await host.tap(tester);

      expect(find.text('SEVİYE TAMAM!'), findsOneWidget);

      await host.dismiss(tester);
      expect(await host.pending, isFalse);
      expect(find.text(expected), findsOneWidget);
    });

    testWidgets('eşik aşılmazsa bildirim yok', (tester) async {
      await seedPlay(1);
      final l10n = AppLocalizationsTr();

      final host = _RunHostS7();
      await host.pump(
        tester,
        (context) => finishRun(context, score: 50, best: 0),
      );
      await host.tap(tester);
      await host.dismiss(tester);

      expect(await host.pending, isFalse);
      expect(
        find.text(l10n.taskCompletedSnack(l10n.taskPlay3Games)),
        findsNothing,
      );
    });

    testWidgets('talep edilmiş görev tekrar bildirilmez', (tester) async {
      await seedPlay(2);
      final l10n = AppLocalizationsTr();
      final expected = l10n.taskCompletedSnack(l10n.taskPlay3Games);

      final host = _RunHostS7();
      await host.pump(
        tester,
        (context) => finishRun(context, score: 50, best: 0),
      );
      await host.tap(tester);
      await host.dismiss(tester);
      expect(find.text(expected), findsOneWidget);

      // Ödül talep edilir, sonra bir tur daha oynanır: bildirim yok.
      final claimed = await ProgressManager.instance.claimDailyTaskReward(
        'play',
        target: 3,
        coinReward: 150,
      );
      expect(claimed, isTrue);

      // İlk snackbar'ın süresi dolsun: ekranda kalırsa ikinci sonuç
      // sayfasının altındaki ANA SAYFA düğmesini kapatır, dokunma ıskalar
      // ve test asılır (varsayılan snackbar süresi 4 sn).
      await tester.pump(const Duration(seconds: 5));
      // Kapanış animasyonu da bitsin (snackbar, ters animasyon
      // tamamlanmadan ağaçtan kalkmaz).
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text(expected), findsNothing);

      final host2 = _RunHostS7();
      await host2.pump(
        tester,
        (context) => finishRun(context, score: 50, best: 0),
      );
      await host2.tap(tester);
      await host2.dismiss(tester);
      expect(await host2.pending, isFalse);
      expect(find.text(expected), findsNothing);
    });

    testWidgets('awaitSettle=false yolunda da bildirim çalışır',
        (tester) async {
      await seedPlay(2);
      final l10n = AppLocalizationsTr();
      final expected = l10n.taskCompletedSnack(l10n.taskPlay3Games);

      final host = _RunHostS7();
      await host.pump(
        tester,
        (context) => finishRun(
          context,
          score: 50,
          best: 0,
          awaitSettle: false,
        ),
      );
      await host.tap(tester);
      await host.dismiss(tester);

      expect(await host.pending, isFalse);
      expect(find.text(expected), findsOneWidget);
    });
  });
}

/// `finishRun` akışını bir düğmeyle tetikleyen test ana ekranı
/// (finish_run_leaderboard_2c_test deseni).
class _RunHostS7 {
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
  }
}
