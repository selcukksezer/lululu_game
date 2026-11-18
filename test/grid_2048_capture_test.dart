import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture 2048 screen for local pixel audit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: wrapWithL10n(
          const Grid2048Screen(prototypeVisualState: true),
          theme: buildLululuTheme(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final image = await (key.currentContext!.findRenderObject()
            as RenderRepaintBoundary)
        .toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('/tmp/lululu-2048-current.png')
        .writeAsBytesSync(Uint8List.sublistView(data!));
    // Madde 99: yakalama dosyası doğrulanır (varlık + boyut + PNG imzası).
    final captureFile = File('/tmp/lululu-2048-current.png');
    expect(captureFile.existsSync(), isTrue);
    final captureBytes = captureFile.readAsBytesSync();
    expect(captureBytes.length, greaterThan(8));
    expect(
      captureBytes.sublist(0, 8),
      const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    );
  });
}
