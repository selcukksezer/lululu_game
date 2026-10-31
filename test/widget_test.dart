import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/main.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    AdaptiveQualityScaler.instance.bootstrap(forceTier: QualityTier.medium);
  });

  testWidgets('LululuApp boots HomeShell with dock and GameSelector',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'LululuOnboardingDoneV1': true,
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLululuTheme(),
        home: const HomeShell(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(GameSelectorScreen), findsOneWidget);
    expect(find.text('ANA SAYFA'), findsOneWidget);
    expect(find.textContaining('STÜDYO'), findsWidgets);
    expect(find.text('SKORLAR'), findsOneWidget);
    expect(find.textContaining('GÜNLÜK'), findsWidgets);

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

  test('Insect Tier hierarchy consists of 8 tiers with correct progression', () {
    expect(InsectTier.values.length, 8);
    expect(InsectTier.cone.nextTier, InsectTier.helmet);
    expect(InsectTier.helmet.nextTier, InsectTier.fan);
    expect(InsectTier.fan.nextTier, InsectTier.dancer);
    expect(InsectTier.dancer.nextTier, InsectTier.diva);
    expect(InsectTier.diva.nextTier, InsectTier.can);
    expect(InsectTier.can.nextTier, InsectTier.kongo);
    expect(InsectTier.kongo.nextTier, InsectTier.bed);
    expect(InsectTier.bed.nextTier, isNull);
  });

  testWidgets('six play modes mount with readable rules', (tester) async {
    Future<void> mount(Widget home, String title) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildLululuTheme(), home: home),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final ex = tester.takeException();
      debugPrint('MODE $title => $ex');
      expect(ex, isNull, reason: title);
      expect(find.text(title), findsOneWidget);
    }

    await mount(const BalloonPopScreen(), 'BALON PATLAT');
    await mount(const Match3Screen(), 'MATCH 3');
    await mount(const ConnectPopScreen(), 'BAĞLA PATLAT');
    await mount(const StackDropScreen(), 'STACK DROP');
    await mount(const Grid2048Screen(), '2048 GRID');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLululuTheme(),
        home: GameScreen(level: CampaignDatabase.kitchenLevel1, arcade: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull, reason: 'GameScreen');
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('viral modes mount Osmantus Scream Terlik', (tester) async {
    Future<void> mount(Widget home, String title) async {
      await tester.pumpWidget(
        MaterialApp(theme: buildLululuTheme(), home: home),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull, reason: title);
      expect(find.text(title), findsOneWidget);
    }

    await mount(const OsmantusScreen(), 'OSMANTUŞ');
    await mount(const ScreamRoachScreen(), 'ÇIĞLIK BÖCEK');
    await mount(const TerlikTapScreen(), 'TERLİK TAP');

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
