import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/modes/yuva_defense_screen.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/services/adaptive_quality_scaler.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'pixel_perfect_test.dart' show loadCustomFonts, safePrimeAssets;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    await loadCustomFonts();
    Animate.defaultDuration = Duration.zero;
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({
      'LululuOnboardingDoneV1': true,
      'LululuCoinBalance': 12450,
      'LululuEnergyCount': 21,
      'LululuDiamondBalance': 86,
      'lululu_coins': 12450,
    });
    await ProgressManager().load();
    ProgressManager().coins = 12450;
    await LeaderboardService.instance.ensureLoaded();
    AdaptiveQualityScaler.instance.bootstrap(forceTier: QualityTier.medium);
  });

  Future<void> captureLiveScreen({
    required WidgetTester tester,
    required Widget widget,
    required String outputPath,
    int tickFrames = 6,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: SizedBox(
          width: 430,
          height: 932,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildLululuTheme(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(430, 932),
                devicePixelRatio: 1.0,
                padding: EdgeInsets.only(top: 35.4, bottom: 24),
                viewPadding: EdgeInsets.only(top: 35.4, bottom: 24),
              ),
              child: widget,
            ),
          ),
        ),
      ),
    );

    await safePrimeAssets(tester);
    for (var i = 0; i < tickFrames; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File(outputPath);
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(pngBytes);
      image.dispose();
    });

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('Live Hub', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const HomeShell(),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_hub.png',
    );
  });

  testWidgets('Live Balon', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const BalloonPopScreen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_balon.png',
    );
  });

  testWidgets('Live Match3', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const Match3Screen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_match3.png',
    );
  });

  testWidgets('Live Bagla', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const ConnectPopScreen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_bagla.png',
    );
  });

  testWidgets('Live Terlik', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const TerlikTapScreen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_terlik.png',
    );
  });

  testWidgets('Live Yuva', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const YuvaDefenseScreen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_yuva.png',
    );
  });

  testWidgets('Live Ciglik', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const ScreamRoachScreen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_ciglik.png',
    );
  });

  testWidgets('Live Suika', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: GameScreen(
        level: CampaignDatabase.kitchenLevel1,
        arcade: true,
        prototypeVisualState: false,
      ),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_suika.png',
    );
  });

  testWidgets('Live 2048', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const Grid2048Screen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_2048.png',
    );
  });

  testWidgets('Live Stack', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const StackDropScreen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_stack.png',
    );
  });

  testWidgets('Live Osmantus', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const OsmantusScreen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_osmantus.png',
    );
  });

  testWidgets('Live Makarayiz', (tester) async {
    await captureLiveScreen(
      tester: tester,
      widget: const MakarayizScreen(prototypeVisualState: false),
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/live_makarayiz.png',
    );
  });
}
