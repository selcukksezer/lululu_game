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
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadAppFonts();
    for (final ch in ['xyz.luan/audioplayers.global', 'xyz.luan/audioplayers']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(ch), (call) async => null);
    }
  });

  testWidgets('capture suika proto at 374x680 for pixel audit', (tester) async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: wrapWithL10n(
          TickerMode(
            enabled: false,
            child: GameScreen(
              level: CampaignDatabase.kitchenLevel1,
              arcade: true,
              prototypeVisualState: true,
            ),
          ),
          debugShowCheckedModeBanner: false,
          theme: buildLululuTheme(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final ctx = tester.element(find.byType(RepaintBoundary).first);
    await tester.runAsync(() async {
      for (final t in InsectTier.values) {
        await precacheImage(AssetImage(t.assetPath), ctx);
      }
      for (final e in find.byType(Image, skipOffstage: false).evaluate()) {
        final img = e.widget as Image;
        if (img.image is AssetImage) await precacheImage(img.image, e);
      }
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('suika-proto-current.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    // Madde 99: yakalama dosyası doğrulanır (varlık + boyut + PNG imzası).
    final captureFile = File('suika-proto-current.png');
    expect(captureFile.existsSync(), isTrue);
    final captureBytes = captureFile.readAsBytesSync();
    expect(captureBytes.length, greaterThan(8));
    expect(
      captureBytes.sublist(0, 8),
      const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    );
  });
}
