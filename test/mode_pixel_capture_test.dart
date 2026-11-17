import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

Future<void> _loadCaptureFonts() async {
  const fontFiles = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Bold.ttf',
      'assets/fonts/Baloo2-ExtraBold.ttf',
    ],
    'Bangers': ['assets/fonts/Bangers-Regular.ttf'],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Bold.ttf',
      'assets/fonts/Exo2-ExtraBold.ttf',
    ],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
    ],
  };
  for (final entry in fontFiles.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    await _loadCaptureFonts();
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
  });

  final screens = <String, Widget Function()>{
    'suika': () => GameScreen(
      level: CampaignDatabase.kitchenLevel1,
      arcade: true,
    ),
    'balon': () => const BalloonPopScreen(),
    'match3': () => const Match3Screen(),
    'bagla': () => const ConnectPopScreen(),
    'stack': () => const StackDropScreen(),
    'terlik': () => const TerlikTapScreen(),
    'osmantus': () => const OsmantusScreen(),
    'ciglik': () => const ScreamRoachScreen(),
    'makara': () => const MakarayizScreen(),
  };

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final entry in screens.entries) {
    testWidgets('capture ${entry.key} at 374x680 for pixel audit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(374, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildLululuTheme(),
            home: TickerMode(
              enabled: false,
              child: entry.value(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump();
      final context = tester.element(find.byType(RepaintBoundary).first);
      final imageElements = find.byType(Image, skipOffstage: false).evaluate();
      await tester.runAsync(() async {
        for (final tier in InsectTier.values) {
          await precacheImage(AssetImage(tier.assetPath), context);
        }
        for (final element in imageElements) {
          final image = element.widget as Image;
          if (image.image is AssetImage) {
            await precacheImage(image.image, element);
          }
        }
      });
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${entry.key} threw');

      final boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) {
          throw StateError('${entry.key} pixel capture returned no image.');
        }
        File('/tmp/lululu-mode-${entry.key}-current.png')
            .writeAsBytesSync(Uint8List.sublistView(bytes));
        image.dispose();
      });
      // Madde 99: yakalama dosyası doğrulanır (varlık + boyut + PNG imzası).
      final captureFile = File('/tmp/lululu-mode-${entry.key}-current.png');
      expect(captureFile.existsSync(), isTrue);
      final captureBytes = captureFile.readAsBytesSync();
      expect(captureBytes.length, greaterThan(8));
      expect(
        captureBytes.sublist(0, 8),
        const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
