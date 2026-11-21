import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/screens/tasks_screen.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/widgets/coin_fly.dart';
import 'package:lululu_game/widgets/top_bar.dart';

import 'test_helpers.dart';

// 12N coin uçuşu (brif 12N-coin-fly):
// * Ödül claim'i uçuşu tetikler; üst bar sayısı uçuş bitmeden artmaz,
//   varışta artar (bekleyen tutar görüntüden düşülür).
// * Ödeme değişmez: bakiye (ProgressManager.coins) claim anında artar,
//   yalnız GÖRÜNEN sayı varışı bekler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    ProgressManager.instance.coins = 1000;
    ProgressManager.instance.dailyTaskProgress['play'] = 3;
    ProgressManager.instance.dailyTaskProgress['merge'] = 0;
    ProgressManager.instance.dailyTaskProgress['video'] = 0;
    ProgressManager.instance.dailyTaskProgress['combo'] = 0;
    ProgressManager.instance.claimedDailyTasks.clear();
    CoinFlyService.instance.debugReset();
  });

  tearDown(() {
    CoinFlyService.instance.debugReset();
  });

  Future<void> setSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  /// Repo deseni (hub_daily_challenge_notify_3h_test `tearDownTree`):
  /// ağaç sökülmeden önce saat 6 sn ilerletilir — bekleyen snackbar /
  /// uçuş animasyonu bitsin, yoksa binding'de bekleyen kare geri
  /// çağrısı kalıyor. Söküldükten sonra yalnız sıfır-süreli pump
  /// yapılır (söküm SONRASI saat ilerletmek gecikmiş bildirimi yeniden
  /// ateşler). `pumpAndSettle` KULLANILMAZ (sonuç ekranında çerçeve
  /// üreten animasyonlarla takılıp dakikalarca döner).
  ///
  /// Ek: GoogleFonts font yüklemesi GERÇEK-zamanlı 'fontsChange'
  /// bildirimi gönderir (sahte saatten bağımsız); bildirim son
  /// pump'tan sonra gelirse postTest "animation still running" diye
  /// düşer. `runAsync` ile gerçek-zamanlı bekleme + pump, geç gelen
  /// bildirimin geri çağrısını tüketir.
  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  group('CoinFlyService', () {
    testWidgets('uçuş bekleyen tutarı artırır, süre dolunca indirir',
        (tester) async {
      await setSurface(tester);
      await pumpWithL10n(
        tester,
        const SizedBox.shrink(key: Key('coin_fly_12n_host')),
      );
      final service = CoinFlyService.instance;
      final context =
          tester.element(find.byKey(const Key('coin_fly_12n_host')));

      expect(service.pendingCoins, 0);
      expect(service.landings, 0);
      service.fly(
        context: context,
        from: const Offset(215, 500),
        amount: 150,
      );
      await tester.pump();
      expect(service.pendingCoins, 150);
      expect(service.landings, 0);

      // Süre (750 ms) dolmadan varış yok.
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.pendingCoins, 150);
      expect(service.landings, 0);

      // Süre dolunca varış: bekleyen sıfırlanır, varış sayacı artar.
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.pendingCoins, 0);
      expect(service.landings, 1);

      await tearDownTree(tester);
    });

    testWidgets('üst üste binen uçuşlar bağımsız tamamlanır', (tester) async {
      await setSurface(tester);
      await pumpWithL10n(
        tester,
        const SizedBox.shrink(key: Key('coin_fly_12n_host')),
      );
      final service = CoinFlyService.instance;
      final context =
          tester.element(find.byKey(const Key('coin_fly_12n_host')));

      service.fly(
        context: context,
        from: const Offset(100, 500),
        amount: 100,
      );
      service.fly(
        context: context,
        from: const Offset(300, 500),
        amount: 200,
      );
      await tester.pump();
      expect(service.pendingCoins, 300);
      await tester.pump(const Duration(milliseconds: 800));
      expect(service.pendingCoins, 0);
      expect(service.landings, 2);

      await tearDownTree(tester);
    });

    testWidgets('sıfır ve negatif tutar uçuş başlatmaz', (tester) async {
      await setSurface(tester);
      await pumpWithL10n(
        tester,
        const SizedBox.shrink(key: Key('coin_fly_12n_host')),
      );
      final service = CoinFlyService.instance;
      final context =
          tester.element(find.byKey(const Key('coin_fly_12n_host')));

      expect(
        service.fly(context: context, from: Offset.zero, amount: 0),
        isNull,
      );
      expect(
        service.fly(context: context, from: Offset.zero, amount: -50),
        isNull,
      );
      expect(service.pendingCoins, 0);
      expect(service.landings, 0);

      await tearDownTree(tester);
    });

    testWidgets('iptal edilen uçuş bekleyen tutarı geri alır', (
      tester,
    ) async {
      await setSurface(tester);
      await pumpWithL10n(
        tester,
        const SizedBox.shrink(key: Key('coin_fly_12n_host')),
      );
      final service = CoinFlyService.instance;
      final context =
          tester.element(find.byKey(const Key('coin_fly_12n_host')));

      final handle = service.fly(
        context: context,
        from: Offset.zero,
        amount: 120,
      );
      expect(handle, isNotNull);
      expect(service.pendingCoins, 120);

      handle!.cancel();
      expect(service.pendingCoins, 0);
      expect(service.landings, 0);

      // Süre geçse bile iptal edilmiş uçuş varmaz.
      await tester.pump(const Duration(seconds: 2));
      expect(service.pendingCoins, 0);
      expect(service.landings, 0);

      await tearDownTree(tester);
    });
  });

  group('LululuTopBar görünüm ertelemesi', () {
    testWidgets('sayı uçuş bitmeden artmaz, varışta artar', (tester) async {
      await setSurface(tester);
      await pumpWithL10n(tester, const LululuTopBar());
      await tester.pump();

      // Ödeme yapıldı (bakiye 1150) ama uçuş başladı: görünür sayı eski.
      ProgressManager.instance.coins = 1150;
      final context = tester.element(find.byType(LululuTopBar));
      CoinFlyService.instance.fly(
        context: context,
        from: const Offset(215, 500),
        amount: 150,
      );
      await tester.pump();
      expect(find.text('1.000'), findsOneWidget);
      expect(find.text('1.150'), findsNothing);

      // Varışta sayı artar.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(find.text('1.150'), findsOneWidget);
      expect(find.text('1.000'), findsNothing);

      await tearDownTree(tester);
    });

    testWidgets('coin hedefi kaydolur ve dispose’da silinir', (tester) async {
      await setSurface(tester);
      await pumpWithL10n(tester, const LululuTopBar());
      await tester.pump();
      final target = CoinFlyService.instance.targetCenter;
      expect(target, isNotNull);
      // Hedef, üst bardaki coin simgesinin merkezidir: test ortamında
      // bar ekran ortasında durur, o yüzden simgenin kendi merkeziyle
      // karşılaştırılır (üretimde bar ekranın üstündedir).
      final coinFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/design/ui/icon_coin_exact.png',
      );
      expect(coinFinder, findsOneWidget);
      expect(target, tester.getCenter(coinFinder));

      await tearDownTree(tester);
      expect(CoinFlyService.instance.targetCenter, isNull);
    });
  });

  group('TasksScreen claim uçuşu', () {
    testWidgets('görev ödülü uçuşu tetikler; sayı varışta artar',
        (tester) async {
      await setSurface(tester);
      await pumpWithL10n(tester, const TasksScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 'play3' görevi tamam (3/3), ödül alınabilir durumda.
      expect(find.text('ÖDÜLÜ AL'), findsWidgets);

      // İlk ödül düğmesine dokun (play3: 150 coin).
      await tester.tap(find.text('ÖDÜLÜ AL').first);
      await tester.pump();
      // Async claim (prefs yazımı) tamamlansın.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Ödeme yapıldı ama uçuş sürüyor: başlık sayısı eski değerde.
      expect(ProgressManager.instance.coins, 1150);
      expect(CoinFlyService.instance.pendingCoins, 150);
      expect(find.text('1.000'), findsOneWidget);
      expect(find.text('1.150'), findsNothing);

      // Varış: sayı artar.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(CoinFlyService.instance.pendingCoins, 0);
      expect(find.text('1.150'), findsOneWidget);

      await tearDownTree(tester);
    });
  });

  group('GameResultScreen uçuşu', () {
    testWidgets('sonuç kazancı sandıktan uçar; bakiye iki kez artmaz',
        (tester) async {
      await setSurface(tester);
      // Çağırıcı ödedi (bakiye zaten 1050); ekran tekrar ödemez.
      ProgressManager.instance.coins = 1050;
      await pumpWithL10n(
        tester,
        const GameResultScreen(
          score: 500,
          coins: 50,
          stars: 2,
          coinsAwardedByCaller: true,
        ),
      );
      await tester.pump();
      expect(ProgressManager.instance.coins, 1050);
      expect(CoinFlyService.instance.pendingCoins, 0);

      // 350 ms gecikme + uçuş başlangıcı: bekleyen tutar 50 olur.
      await tester.pump(const Duration(milliseconds: 400));
      expect(CoinFlyService.instance.pendingCoins, 50);
      expect(ProgressManager.instance.coins, 1050);

      // Varış: bekleyen sıfırlanır, bakiye değişmez (çift ödeme yok).
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(CoinFlyService.instance.pendingCoins, 0);
      expect(ProgressManager.instance.coins, 1050);
      expect(CoinFlyService.instance.landings, 1);

      await tearDownTree(tester);
    });

    testWidgets('sıfır coin sonuç ekranında uçuş başlatmaz', (tester) async {
      await setSurface(tester);
      await pumpWithL10n(
        tester,
        const GameResultScreen(
          score: 0,
          coins: 0,
          stars: 0,
          coinsAwardedByCaller: true,
          won: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(CoinFlyService.instance.pendingCoins, 0);
      expect(CoinFlyService.instance.landings, 0);

      await tearDownTree(tester);
    });
  });
}
