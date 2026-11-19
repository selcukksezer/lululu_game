import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

Future<void> _loadCaptureFonts() async {
  const fontFiles = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
    ],
    'Bangers': ['assets/fonts/Bangers-Regular.ttf'],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
    ],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
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

  testWidgets('capture ciglik at 374x680 for pixel audit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AudioManager().isMuted = true;
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
    await loadAppFonts();
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadCaptureFonts();
    ProgressManager().coins = 12450;
    ProgressManager().extraPowers
      ..['jump'] = 3
      ..['shield'] = 2
      ..['nitro'] = 1;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeScream,
      2105,
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
            child: ScreamRoachScreen(prototypeVisualState: true),
          ),
          theme: buildLululuTheme(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(ScreamRoachScreen));
    await tester.runAsync(() async {
      for (final asset in [
        'assets/scream_sky.webp',
        'assets/obstacles/obstacle-pipes.webp',
        'assets/obstacles/obstacle-spikes.webp',
        'assets/obstacles/obstacle-bush.webp',
        'assets/design/ui/icon_coin.png',
        'assets/icons2/back-prototype.png',
        'assets/icons2/boot.png',
        'assets/icons2/shield.png',
        'assets/icons2/potion_speed.png',
        'assets/bugs/tier7_hd.png',
      ]) {
        await precacheImage(
          AssetImage(asset),
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
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw StateError('Çığlık pixel capture returned no image.');
      }
      final capture = File('build/ciglik-prototype-capture.png');
      capture.parent.createSync(recursive: true);
      capture.writeAsBytesSync(png.buffer.asUint8List());
      image.dispose();
    });
    // Madde 99: yakalama dosyası doğrulanır (varlık + boyut + PNG imzası).
    final captureFile = File('build/ciglik-prototype-capture.png');
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
