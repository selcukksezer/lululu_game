import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/modes/yuva_defense_screen.dart';
import 'package:lululu_game/navigation/game_routes.dart';
import 'package:lululu_game/screens/campaign_map_screen.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/modes_screen.dart';
import 'package:lululu_game/screens/onboarding_screen.dart';
import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/screens/settings_screen.dart';
import 'package:lululu_game/screens/splash_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

// W20-3 TESTS-4: rota normalizasyonu + bilinmeyen-rota yedeği. Kaynak:
// lib/navigation/game_routes.dart — `_normalizeRouteName` (:197, ÖZEL),
// `resolveScreen` (:219), `onGenerateRoute` (:345), `onUnknownRoute`
// (:372). `_normalizeRouteName` bu kitaptan doğrudan çağrılamaz; tüm
// normalizasyon iddiaları herkese açık `resolveScreen`/`onGenerateRoute`
// davranışı üzerinden denetlenir. `main.dart:318` yalnız
// `onGenerateRoute` bağlar; `onUnknownRoute` bağlanmamıştır ama aynı
// yedeği bağımsız kanca olarak sunar.
//
// NOT (normalize düzeltmesi sonrası güncel): `_normalizeRouteName`
// baştaki `#` ve `/` karakterlerinin herhangi bir karışımını tek
// seferde söker; `/#/game` `game` ile aynı çözülür ve oyun açılır.
// Boş normalize olan adlarda `onGenerateRoute` rota adını `''`
// bırakır (yedek `hub` adını yalnız `resolveScreen` null
// döndüğünde kullanır).

/// 20 takma adın beklenen oyun ekranı tipi (`modeAliases`, :123).
const _aliasChildTypes = <String, Type>{
  'suika': GameScreen,
  'game': GameScreen,
  'grid2048': Grid2048Screen,
  'm2048': Grid2048Screen,
  '2048': Grid2048Screen,
  'balloon': BalloonPopScreen,
  'balon': BalloonPopScreen,
  'match3': Match3Screen,
  'connect': ConnectPopScreen,
  'bagla': ConnectPopScreen,
  'stack': StackDropScreen,
  'terlikTap': TerlikTapScreen,
  'terlik': TerlikTapScreen,
  'yuvaDefense': YuvaDefenseScreen,
  'yuva': YuvaDefenseScreen,
  'osmantus': OsmantusScreen,
  'screamRoach': ScreamRoachScreen,
  'ciglik': ScreamRoachScreen,
  'makarayiz': MakarayizScreen,
  'makara': MakarayizScreen,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalize: resolveScreen üzerinden', () {
    test('18 ana ekran adı + 3 ek ekran çözülür', () {
      expect(LululuRoutes.mainScreens.length, 18);
      for (final name in LululuRoutes.mainScreens) {
        expect(
          LululuRoutes.resolveScreen(name),
          isNotNull,
          reason: 'çözülmedi: $name',
        );
      }
      // `mainScreens` dışında kalan 3 ek durum da çözülür (:267-272).
      expect(LululuRoutes.resolveScreen('settings'), isA<SettingsScreen>());
      expect(LululuRoutes.resolveScreen('campaign'), isA<CampaignMapScreen>());
      expect(
        LululuRoutes.resolveScreen('onboarding'),
        isA<OnboardingScreen>(),
      );
      // Tip nokta kontrolleri.
      expect(LululuRoutes.resolveScreen('hub'), isA<HomeShell>());
      expect(LululuRoutes.resolveScreen('modes'), isA<ModesScreen>());
      expect(LululuRoutes.resolveScreen('result'), isA<GameResultScreen>());
      expect(LululuRoutes.resolveScreen('splash'), isA<SplashScreen>());
    });

    test('derin bağlantı varyantları aynı ekrana çözülür', () {
      const gameVariants = [
        'game',
        '/game',
        '///game',
        '#/game',
        '#/game/',
        'game/',
        'game///',
        '  game  ',
        '/game/',
        'game?level=1',
        '/game?level=1',
        '#/game?level=1',
        'game#bolum',
        'game?level=1#frag',
        '/game#x',
        'game?level=1&mode=arcade',
      ];
      for (final variant in gameVariants) {
        final widget = LululuRoutes.resolveScreen(variant);
        expect(widget, isA<GameAudioGate>(), reason: variant);
        expect(
          (widget as GameAudioGate).child,
          isA<GameScreen>(),
          reason: variant,
        );
      }

      const modesVariants = [
        'modes',
        '/modes',
        '#/modes',
        'modes?tab=1',
        'modes/',
        'modes#alt',
      ];
      for (final variant in modesVariants) {
        expect(
          LululuRoutes.resolveScreen(variant),
          isA<ModesScreen>(),
          reason: variant,
        );
      }

      const terlikVariants = [
        'terlikTap',
        '/terlikTap',
        'terlikTap?x=1',
        '#/terlikTap',
        'terlikTap/',
      ];
      for (final variant in terlikVariants) {
        final widget = LululuRoutes.resolveScreen(variant);
        expect(widget, isA<GameAudioGate>(), reason: variant);
        expect(
          (widget as GameAudioGate).child,
          isA<TerlikTapScreen>(),
          reason: variant,
        );
      }
    });

    test("'/#/..' biçimi game ile aynı çözülür (önek karışımı tek seferde sökülür)",
        () {
      // İz: '/#/game' -> baştaki '#/' karışımı tek seferde sökülür
      // -> 'game' -> oyun ekranı. '#/game' ile aynı çözülür.
      for (final variant in [
        '/#/game',
        '/#/game/',
        '/#/game?level=1',
      ]) {
        final widget = LululuRoutes.resolveScreen(variant);
        expect(widget, isA<GameAudioGate>(), reason: variant);
        expect(
          (widget as GameAudioGate).child,
          isA<GameScreen>(),
          reason: variant,
        );
      }
      expect(
        LululuRoutes.resolveScreen('/#/modes'),
        isA<ModesScreen>(),
        reason: '/#/modes',
      );
      final terlikWidget = LululuRoutes.resolveScreen('/#/terlikTap');
      expect(terlikWidget, isA<GameAudioGate>(), reason: '/#/terlikTap');
      expect(
        (terlikWidget as GameAudioGate).child,
        isA<TerlikTapScreen>(),
        reason: '/#/terlikTap',
      );
      expect(
        LululuRoutes.resolveScreen('#/game'),
        isA<GameAudioGate>(),
        reason: '#/game game çözmelidir',
      );
    });

    test('boş veya yalnızca ayraç içeren adlar hub olur', () {
      for (final variant in ['', '   ', '/', '///', '#', '/#', '#/', '  /  ', '?x=1']) {
        expect(
          LululuRoutes.resolveScreen(variant),
          isA<HomeShell>(),
          reason: variant,
        );
      }
    });

    test('rota adları büyük/küçük harfe duyarlıdır', () {
      for (final variant in [
        'GAME',
        'Game',
        'MODES',
        'Modes',
        'TerlikTap',
        'HUB',
        'Hub',
        'SETTINGS',
      ]) {
        expect(
          LululuRoutes.resolveScreen(variant),
          isNull,
          reason: 'büyük/küçük harf farkı çözülmemeli: $variant',
        );
      }
      expect(
        LululuRoutes.resolveScreen('terlikTap'),
        isA<GameAudioGate>(),
      );
      expect(LululuRoutes.resolveScreen('game'), isA<GameAudioGate>());
    });

    test('bilinmeyen adlarda resolveScreen null döner', () {
      for (final name in [
        'bilinmeyen',
        'game2',
        'hub2',
        'modesx',
        'settingsx',
        'xyz',
        'frag',
        'foo-bar',
        'result2',
        'game-resultx',
      ]) {
        expect(LululuRoutes.resolveScreen(name), isNull, reason: name);
      }
    });

    test('20 mod takma adının tamamı oyun ekranına çözülür', () {
      expect(LululuRoutes.modeAliases.length, 20);
      expect(_aliasChildTypes.length, 20);
      expect(
        LululuRoutes.modeAliases.keys.toSet(),
        _aliasChildTypes.keys.toSet(),
      );
      for (final entry in _aliasChildTypes.entries) {
        final widget = LululuRoutes.resolveScreen(entry.key);
        expect(widget, isA<GameAudioGate>(), reason: entry.key);
        expect(
          (widget as GameAudioGate).child.runtimeType,
          entry.value,
          reason: entry.key,
        );
      }
    });

    test("'-result' son eki her zaman sonuç ekranına çözülür", () {
      for (final name in [
        'suika-result',
        'game-result',
        'bilinmeyen-result',
        'x-result',
      ]) {
        expect(
          LululuRoutes.resolveScreen(name),
          isA<GameResultScreen>(),
          reason: name,
        );
      }
    });
  });

  group('onGenerateRoute yedeği', () {
    test('bilinmeyen rota hub rotasına düşer', () {
      for (final name in [
        'bilinmeyen',
        '/bilinmeyen',
        'GAME',
        'game2',
        '  yok  ',
        'modesx?tab=1',
      ]) {
        final route =
            LululuRoutes.onGenerateRoute(RouteSettings(name: name));
        expect(route, isNotNull, reason: name);
        expect(route!.settings.name, LululuRoutes.hub, reason: name);
        expect(route, isA<PageRouteBuilder>(), reason: name);
      }
    });

    test('adsız rota hub olur (settings.name ?? hub)', () {
      final route = LululuRoutes.onGenerateRoute(const RouteSettings());
      expect(route, isNotNull);
      expect(route!.settings.name, LululuRoutes.hub);
    });

    test('boş normalize olan adlar hub ekranını boş rota adıyla döner', () {
      // `resolveScreen('')` hub döndürdüğü için yedek dalına girilmez;
      // rota adı normalize edilmiş boş ad olarak kalır (:345-364).
      for (final name in ['', '   ', '/']) {
        final route =
            LululuRoutes.onGenerateRoute(RouteSettings(name: name));
        expect(route, isNotNull, reason: name);
        expect(route!.settings.name, '', reason: name);
      }
    });

    test('bilinen rota kendi normalize adıyla döner', () {
      expect(
        LululuRoutes.onGenerateRoute(const RouteSettings(name: 'modes'))!
            .settings
            .name,
        'modes',
      );
      expect(
        LululuRoutes.onGenerateRoute(
          const RouteSettings(name: '/game?level=1'),
        )!.settings.name,
        'game',
      );
      expect(
        LululuRoutes.onGenerateRoute(const RouteSettings(name: '#/modes'))!
            .settings
            .name,
        'modes',
      );
      expect(
        LululuRoutes.onGenerateRoute(const RouteSettings(name: 'hub'))!
            .settings
            .name,
        'hub',
      );
      expect(
        LululuRoutes.onGenerateRoute(
          const RouteSettings(name: 'settings'),
        )!.settings.name,
        'settings',
      );
      expect(
        LululuRoutes.onGenerateRoute(
          const RouteSettings(name: 'terlikTap'),
        )!.settings.name,
        'terlikTap',
      );
    });

    test('mod rotaları 340ms, ekran ve yedek rotalar standart süre alır', () {
      final modeRoute = LululuRoutes.onGenerateRoute(
        const RouteSettings(name: 'terlikTap'),
      ) as PageRouteBuilder;
      expect(
        modeRoute.transitionDuration,
        const Duration(milliseconds: 340),
      );
      final screenRoute = LululuRoutes.onGenerateRoute(
        const RouteSettings(name: 'modes'),
      ) as PageRouteBuilder;
      expect(
        screenRoute.transitionDuration,
        LululuMotion.screenTransitionDuration,
      );
      final fallbackRoute = LululuRoutes.onGenerateRoute(
        const RouteSettings(name: 'yok-boyle-rota'),
      ) as PageRouteBuilder;
      expect(
        fallbackRoute.transitionDuration,
        LululuMotion.screenTransitionDuration,
      );
    });
  });

  group('onUnknownRoute yedeği', () {
    test('onUnknownRoute her girişte hub rotası döner', () {
      for (final name in ['bilinmeyen', '/yok', 'GAME', null]) {
        final route = LululuRoutes.onUnknownRoute(RouteSettings(name: name));
        expect(route.settings.name, LululuRoutes.hub, reason: '$name');
        expect(route, isA<PageRouteBuilder>(), reason: '$name');
      }
    });
  });

  group('bilinmeyen-rota yedeği (widget)', () {
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

    Future<void> pumpInitialRoute(
      WidgetTester tester,
      String initialRoute, {
      RouteFactory? onGenerateRoute,
      RouteFactory? onUnknownRoute,
    }) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLululuTheme(),
          onGenerateRoute: onGenerateRoute ?? LululuRoutes.onGenerateRoute,
          onUnknownRoute: onUnknownRoute,
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

    testWidgets('bilinmeyen ilk rota ana sayfayı (HomeShell) açar',
        (tester) async {
      await pumpInitialRoute(tester, '/boyle-bir-rota-yok');
      expect(find.byType(HomeShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets("'/#/game' ilk rotası oyun ekranını (GameScreen) açar",
        (tester) async {
      await pumpInitialRoute(tester, '/#/game');
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets(
        'onUnknownRoute bağlandığında bilinmeyen rota ana sayfayı açar',
        (tester) async {
      await pumpInitialRoute(
        tester,
        '/yok',
        onGenerateRoute: (_) => null,
        onUnknownRoute: LululuRoutes.onUnknownRoute,
      );
      expect(find.byType(HomeShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets('pushNamed ile bilinmeyen rota ana sayfaya düşer',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLululuTheme(),
          onGenerateRoute: LululuRoutes.onGenerateRoute,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/yok-123'),
                child: const Text('GIT'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('GIT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HomeShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });
  });
}
