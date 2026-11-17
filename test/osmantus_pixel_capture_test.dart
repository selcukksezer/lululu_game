import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

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

  testWidgets('capture Osmantuş at 374x680 for pixel audit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadCaptureFonts();
    ProgressManager().coins = 12450;
    ProgressManager().extraPowers.addAll({'dik': 1, 'ring': 2, 'mic': 3});

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
          home: const TickerMode(
            enabled: false,
            child: OsmantusScreen(prototypeVisualState: true),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(OsmantusScreen));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/design/backgrounds/terlik_livingroom.webp'),
        context,
      );
      for (final asset in [
        'assets/design/backgrounds/osmantus_mansion.webp',
        'assets/design/ui/icon_coin.png',
        'assets/icons2/back-prototype.png',
        'assets/icons2/fist.png',
        'assets/icons2/wheel.png',
        'assets/icons2/star.png',
        'assets/images/stickers/osmantus_kisi_a.png',
        'assets/images/stickers/osmantus_kisi_b.png',
        for (var n = 1; n <= 7; n++) 'assets/images/stickers/osman_$n.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          context,
          onError: (exception, stackTrace) {},
        );
      }
    });
    await tester.pump();

    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw StateError('Osmantus pixel capture returned no image.');
      }
      File(
        'build/osmantus-fixture-current-v8.png',
      ).writeAsBytesSync(Uint8List.sublistView(png));
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
