import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/physics/physics_engine.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/services/adaptive_quality_scaler.dart';
import 'package:lululu_game/services/cloud_sync_service.dart';
import 'package:lululu_game/services/firebase_bootstrap.dart';
import 'package:lululu_game/services/firebase_options.dart';
import 'package:lululu_game/services/iap_service.dart';
import 'package:lululu_game/services/zero_jank_preloader.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

String _trUpper(String input) {
  return input
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .replaceAll('ğ', 'Ğ')
      .replaceAll('ü', 'Ü')
      .replaceAll('ş', 'Ş')
      .replaceAll('ö', 'Ö')
      .replaceAll('ç', 'Ç')
      .toUpperCase();
}

Finder _findTitleCaseInsensitive(String title) {
  final upperTr = _trUpper(title);
  final upperAscii = title.toUpperCase();
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = widget.data;
    if (data == null) return false;
    final dataUpperTr = _trUpper(data);
    return data == title ||
        data == upperTr ||
        data == upperAscii ||
        dataUpperTr == upperTr ||
        dataUpperTr.contains(upperTr);
  });
}

Future<void> _loadTestFonts() async {
  final fontMap = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Bold.ttf',
      'assets/fonts/Baloo2-ExtraBold.ttf',
      'assets/fonts/Baloo2-SemiBold.ttf',
      'assets/fonts/Baloo2-Medium.ttf',
    ],
    'Bangers': ['assets/fonts/Bangers-Regular.ttf'],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
      'assets/fonts/Nunito-SemiBold.ttf',
      'assets/fonts/Nunito-Black.ttf',
    ],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Bold.ttf',
      'assets/fonts/Exo2-ExtraBold.ttf',
      'assets/fonts/Exo2-SemiBold.ttf',
      'assets/fonts/Exo2-Black.ttf',
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    await _loadTestFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    AdaptiveQualityScaler.instance.bootstrap(forceTier: QualityTier.medium);
  });

  testWidgets('LululuApp boots HomeShell with dock and GameSelector', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'LululuOnboardingDoneV1': true});
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLululuTheme(),
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(430, 932),
            devicePixelRatio: 1.0,
            textScaler: TextScaler.linear(0.85),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HomeShell(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(GameSelectorScreen), findsOneWidget);
    expect(find.text('ANA SAYFA'), findsWidgets);
    expect(find.text('SKORLAR'), findsWidgets);
    expect(find.textContaining('ÖDÜL'), findsWidgets);

    // Scroll down in CustomScrollView to reveal STÜDYO section
    await tester.scrollUntilVisible(find.textContaining('STÜDYO'), 300);
    expect(find.textContaining('STÜDYO'), findsWidgets);

    // Drain ZeroJank / animate timers so binding invariants pass.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  test('ZeroJankPreloader exposes <2ms frame budget API', () {
    expect(ZeroJankPreloader.defaultFrameBudgetMs, lessThan(2.0));
    expect(ZeroJankPreloader.hardBudgetCapMs, lessThan(2.0));
    expect(ZeroJankPreloader.instance.frameBudgetMs, lessThan(2.0));
  });

  test('AdaptiveQualityScaler maps Eco→Ultra particle and draw scales', () {
    final scaler = AdaptiveQualityScaler.instance;
    scaler.setTier(QualityTier.eco);
    expect(scaler.particleScale, lessThan(1.0));
    expect(scaler.drawScale, 0.5);
    expect(scaler.maxActiveParticles, 16);

    scaler.setTier(QualityTier.ultra);
    expect(scaler.particleScale, greaterThanOrEqualTo(1.0));
    expect(scaler.drawScale, 1.0);
    expect(scaler.maxActiveParticles, 128);

    expect(scaler.detectInitialTier(systemMemoryMb: 2048), QualityTier.eco);
    expect(scaler.detectInitialTier(systemMemoryMb: 8192), QualityTier.high);
  });

  test('Campaign Level Database generates 80 levels across 4 chapters', () {
    expect(CampaignDatabase.allLevels.length, 80);
    expect(CampaignDatabase.chapterCount, 4);
    expect(CampaignDatabase.levelsPerChapter, 20);
    expect(CampaignDatabase.getLevelsForChapter(1).length, 20);
    expect(CampaignDatabase.getLevelsForChapter(2).length, 20);
    expect(CampaignDatabase.getLevelsForChapter(3).length, 20);
    expect(CampaignDatabase.getLevelsForChapter(4).length, 20);
    expect(CampaignDatabase.getLevel(1).squareArena, isFalse);
    expect(CampaignDatabase.getLevel(21).squareArena, isTrue);
  });

  test('Physics engine merges identical insect tiers', () {
    final engine = CircularPhysicsEngine(
      arenaCenter: const Offset(200, 200),
      arenaRadius: 150,
    );

    engine.addBody(InsectTier.cone, 200, 200);
    engine.addBody(InsectTier.cone, 201, 201);

    expect(engine.bodies.length, 2);

    final merged = engine.update(0.016);

    expect(merged.length, 1);
    expect(merged.first.tier, InsectTier.helmet);
    expect(engine.bodies.length, 1);
    expect(engine.bodies.first.tier, InsectTier.helmet);
    expect(engine.bodies.first.mergeSquash, 1);

    engine.update(0.016);
    expect(engine.bodies.first.mergeSquash, lessThan(1));
    expect(engine.bodies.first.mergeSquash, greaterThan(0));
  });

  test('Square arena physics uses its full rectangular bounds', () {
    final engine = CircularPhysicsEngine(
      arenaCenter: const Offset(100, 250),
      arenaRadius: 100,
      arenaWidth: 200,
      arenaHeight: 480,
      squareArena: true,
    );

    expect(engine.arenaBounds, const Rect.fromLTRB(0, 10, 200, 490));
    expect(engine.dangerY, 20);
    expect(engine.predictRestY(100, 12), 474);
  });

  test('a bug landing on another slides sideways', () {
    final engine = CircularPhysicsEngine(
      arenaCenter: const Offset(200, 400),
      arenaRadius: 180,
    );
    engine.addBody(InsectTier.helmet, 200, 320);
    engine.addBody(InsectTier.cone, 202, 250);
    for (final body in engine.bodies) {
      body.spawnScale = 1;
    }

    for (var i = 0; i < 120; i++) {
      engine.update(0.016);
    }

    final upper = engine.bodies.reduce((a, b) => a.y < b.y ? a : b);
    final lower = engine.bodies.reduce((a, b) => a.y > b.y ? a : b);
    expect((upper.x - lower.x).abs(), greaterThan(6));
  });

  test(
    'Insect Tier hierarchy consists of 13 tiers with correct progression',
    () {
      expect(InsectTier.values.length, 13);
      expect(InsectTier.cone.nextTier, InsectTier.helmet);
      expect(InsectTier.helmet.nextTier, InsectTier.fan);
      expect(InsectTier.fan.nextTier, InsectTier.dancer);
      expect(InsectTier.dancer.nextTier, InsectTier.diva);
      expect(InsectTier.diva.nextTier, InsectTier.can);
      expect(InsectTier.can.nextTier, InsectTier.kongo);
      expect(InsectTier.kongo.nextTier, InsectTier.bed);
      expect(InsectTier.bed.nextTier, InsectTier.milli);
      expect(InsectTier.milli.nextTier, InsectTier.pinkJacket);
      expect(InsectTier.pinkJacket.nextTier, InsectTier.whiteGhost);
      expect(InsectTier.whiteGhost.nextTier, InsectTier.greyShirt);
      expect(InsectTier.greyShirt.nextTier, InsectTier.pinkRobe);
      expect(InsectTier.pinkRobe.nextTier, isNull);
    },
  );

  testWidgets('six play modes mount with readable rules', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> mount(Widget home, String title) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLululuTheme(),
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(430, 932),
              devicePixelRatio: 1.0,
              textScaler: TextScaler.linear(0.85),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: home,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final ex = tester.takeException();
      expect(ex, isNull, reason: title);
      expect(_findTitleCaseInsensitive(title), findsWidgets);
    }

    await mount(const BalloonPopScreen(), 'Balon Patlat');
    await mount(const Match3Screen(), 'Match 3');
    await mount(const ConnectPopScreen(), 'Bağla Patlat');
    await mount(const StackDropScreen(), 'Stack Drop');
    await mount(const Grid2048Screen(), '2048 Grid');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLululuTheme(),
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(430, 932),
            devicePixelRatio: 1.0,
            textScaler: TextScaler.linear(0.85),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: GameScreen(level: CampaignDatabase.kitchenLevel1, arcade: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull, reason: 'GameScreen');
    expect(find.byType(GameScreen), findsOneWidget);
    await tester.tap(find.text('?').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_findTitleCaseInsensitive('Suika Arena'), findsWidgets);
    await tester.tap(find.text('ANLADIM'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('viral modes mount Osmantus Scream Terlik', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> mount(Widget home, String title) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLululuTheme(),
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(430, 932),
              devicePixelRatio: 1.0,
              textScaler: TextScaler.linear(0.85),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: home,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull, reason: title);
      expect(_findTitleCaseInsensitive(title), findsWidgets);
    }

    await mount(const OsmantusScreen(), 'Osmantuş');
    await mount(const ScreamRoachScreen(), 'Çığlık Böcek');
    await mount(const TerlikTapScreen(), 'Terlik Tap');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  test('Firebase options gate + cloud/IAP services boot offline', () async {
    expect(DefaultFirebaseOptions.isConfigured, isFalse);
    final ok = await FirebaseBootstrap.ensureInitialized();
    expect(ok, isFalse);
    await CloudSyncService.instance.ensureLoaded();
    expect(CloudSyncService.instance.status, isNotEmpty);
    await IapService.instance.ensureLoaded();
    expect(IapService.packs.length, 3);
    final bought = await IapService.instance.purchase('coins_small');
    expect(bought, isTrue);
  });
}
