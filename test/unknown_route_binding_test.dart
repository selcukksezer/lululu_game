import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/navigation/game_routes.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/modes_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

// W34-1: `onUnknownRoute` BAĞLANTI testi — MaterialApp düzeyinde.
//
// `lib/main.dart:318-319` (W31-2) üretim bağlantısı:
//   onGenerateRoute: LululuRoutes.onGenerateRoute,
//   onUnknownRoute: LululuRoutes.onUnknownRoute,
// Bu dosya o bağlantının İKİ kanca birlikte bağlıyken doğru çalıştığını
// korur: bilinmeyen rota hub'a düşer, bilinen rota kendi ekranını açar.
//
// ÇAKIŞMA İNCELEMESİ (`test/route_fallback_test.dart`, okundu):
// - Doğrudan `onUnknownRoute(...)` çağrı testi YAZILMADI: 'onUnknownRoute
//   yedeği' grubundaki 'onUnknownRoute her girişte hub rotası döner'
//   testi aynı iddiaları kapsıyor (hub adı + PageRouteBuilder).
// - `onGenerateRoute`-yalnız widget testi var ('bilinmeyen ilk rota...',
//   '/boyle-bir-rota-yok'): bu dosya HER testte iki kancayı birlikte bağlar.
// - `onUnknownRoute`-yalnız widget testi var (`onGenerateRoute: (_) =>
//   null`, '/yok'): bu dosya `onGenerateRoute`'u asla null'a çevirmez.
// - `pushNamed` testi var ama `onGenerateRoute`-yalnız + `home: Builder`
//   kurulumuyla: buradaki `pushNamed` testi üretim bağlantısı +
//   `initialRoute: '/modes'` kurulumunu kullanır.
// - '/modes' MaterialApp düzeyinde hiçbir mevcut testte pump edilmiyor
//   (yalnız `resolveScreen` düzeyinde kapsanıyor).

/// Son itilen rotayı kaydeden gözlemci: rota adını MaterialApp
/// düzeyinde (gerçek Navigator üzerinden) okumak için.
class _RecordingObserver extends RouteObserver<Route<dynamic>> {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
    super.didPush(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('onUnknownRoute üretim bağlantısı (MaterialApp)', () {
    setUpAll(() async {
      for (final channel in [
        'xyz.luan/audioplayers.global',
        'xyz.luan/audioplayers',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          MethodChannel(channel),
          (call) async => null,
        );
      }
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    setUp(() async {
      AudioManager().isMuted = true;
      SharedPreferences.setMockInitialValues({});
      await ProgressManager.instance.load();
      await EnergyService.instance.load();
    });

    /// `main.dart`'taki üretim bağlantısının aynısı: iki kanca birlikte.
    /// (`route_fallback_test.dart`'taki `pumpInitialRoute` deseninden;
    /// burada kancalar sabit, değişken yalnız `initialRoute`.)
    Future<void> pumpProductionWiring(
      WidgetTester tester,
      String initialRoute, {
      GlobalKey<NavigatorState>? navigatorKey,
      NavigatorObserver? observer,
    }) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: observer == null ? const [] : [observer],
          theme: buildLululuTheme(),
          onGenerateRoute: LululuRoutes.onGenerateRoute,
          onUnknownRoute: LululuRoutes.onUnknownRoute,
          initialRoute: initialRoute,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> tearDownTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    testWidgets(
        'bilinmeyen ilk rota üretim bağlantısıyla hub ekranını açar',
        (tester) async {
      await pumpProductionWiring(tester, '/definitely-not-a-route-xyz');
      expect(find.byType(HomeShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets(
        'bilinen rota (/modes) Modes ekranını açar, hub yedeğine düşmez',
        (tester) async {
      final observer = _RecordingObserver();
      await pumpProductionWiring(tester, '/modes', observer: observer);
      expect(find.byType(ModesScreen), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      // Yedeğe düşseydi rota adı hub olurdu; bilinen ad kendi adını taşır.
      expect(observer.lastPushed?.settings.name, LululuRoutes.modes);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets('pushNamed ile bilinmeyen rota üretim bağlantısıyla hub açar',
        (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await pumpProductionWiring(
        tester,
        '/modes',
        navigatorKey: navigatorKey,
      );
      expect(find.byType(ModesScreen), findsOneWidget);
      unawaited(
        navigatorKey.currentState!.pushNamed('/definitely-not-a-route-xyz'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HomeShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets('bilinmeyen rota üretim bağlantısıyla hub rota adını taşır',
        (tester) async {
      final observer = _RecordingObserver();
      await pumpProductionWiring(
        tester,
        '/definitely-not-a-route-xyz',
        observer: observer,
      );
      expect(find.byType(HomeShell), findsOneWidget);
      expect(observer.lastPushed, isNotNull);
      expect(observer.lastPushed!.settings.name, LululuRoutes.hub);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });
  });
}
