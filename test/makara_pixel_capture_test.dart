import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

Future<void> _loadCaptureFonts() async {
  const fontFiles = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Bold.ttf',
      'assets/fonts/Baloo2-ExtraBold.ttf',
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

  testWidgets('capture makara fixture at 374x680', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadCaptureFonts();
    ProgressManager().coins = 12450;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeMakarayiz,
      1760,
    );

    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: wrapWithL10n(
          const TickerMode(
            enabled: false,
            child: MakarayizScreen(prototypeVisualState: true),
          ),
          debugShowCheckedModeBanner: false,
          theme: buildLululuTheme(),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(MakarayizScreen));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/design/backgrounds/makarayiz_stage.webp'),
        context,
      );
      for (final asset in [
        'assets/design/ui/icon_coin.png',
        'assets/icons/health.png',
        'assets/icons2/back-prototype.png',
        'assets/icons2/boot.png',
        'assets/icons2/boom.png',
        'assets/icons2/yuva-title-prototype.png',
        'assets/icons2/yuva-nest-prototype.png',
        'assets/icons2/yuva-slipper-prototype.png',
        'assets/icons2/premium_token.png',
        'assets/icons2/shield.png',
        'assets/powerup_terlik.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          context,
          onError: (exception, stackTrace) {},
        );
      }
      for (final asset in [
        for (var t = 1; t <= 8; t++) 'assets/design/bugs_hd/tier${t}_hd.png',
        'assets/design/bugs_new/tier9_hd.png',
      ]) {
        await precacheImage(AssetImage(asset), context, onError: (e, s) {});
      }
    });
    await tester.pump();

    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw StateError('Yuva pixel capture returned no image.');
      }
      File(
        'makara_pixel_capture_current.png',
      ).writeAsBytesSync(Uint8List.sublistView(png));
      image.dispose();
    });
    // Madde 99: yakalama dosyası doğrulanır (varlık + boyut + PNG imzası).
    final captureFile = File('makara_pixel_capture_current.png');
    expect(captureFile.existsSync(), isTrue);
    final captureBytes = captureFile.readAsBytesSync();
    expect(captureBytes.length, greaterThan(8));
    expect(
      captureBytes.sublist(0, 8),
      const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
