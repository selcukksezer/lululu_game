import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/progress_manager.dart';
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

  testWidgets('capture match3 at 374x680 for pixel audit', (tester) async {
    await loadAppFonts();
    await _loadCaptureFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    final progress = ProgressManager();
    progress.coins = 12450;
    progress.extraPowers
      ..['hammer'] = 3
      ..['bomb3'] = 2
      ..['hunter'] = 1;
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
            child: Match3Screen(prototypeVisualState: true),
          ),
        ),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(Match3Screen));
    await tester.runAsync(() async {
      for (final asset in [
        'assets/design/backgrounds/match3_lab.webp',
        'assets/icons2/boom.png',
        'assets/design/icons/extra_icons/All_Icons/hammer.png',
        'assets/design/icons/extra_icons/All_Icons/explosion.png',
        'assets/design/icons/extra_icons/All_Icons/blue_diamond.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
          context,
          onError: (exception, stackTrace) {},
        );
      }
      for (var tier = 1; tier <= 5; tier++) {
        await precacheImage(
          AssetImage('assets/design/bugs_hd/tier${tier}_hd.png'),
          context,
          onError: (exception, stackTrace) {},
        );
      }
    });
    await tester.pump();
    expect(tester.takeException(), isNull);

    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Match 3 pixel capture returned no image.');
      }
      File(
        'match3_capture_current.png',
      ).writeAsBytesSync(Uint8List.sublistView(bytes));
      image.dispose();
    });
    // Madde 99: yakalama dosyası doğrulanır (varlık + boyut + PNG imzası).
    final captureFile = File('match3_capture_current.png');
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
