import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpFrames(WidgetTester tester, int milliseconds) async {
    final frames = (milliseconds / 16).ceil();
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AudioManager().isMuted = true;
    GoogleFonts.config.allowRuntimeFetching = false;
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

  testWidgets('Stack Drop starts gently and reports timed drops', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: buildLululuTheme(), home: StackDropScreen()),
    );
    await pumpFrames(tester, 16);
    await tester.tap(find.text('?'));
    await tester.pump();
    expect(
      find.textContaining('İlk 15 saniye öğretici tempoda'),
      findsOneWidget,
    );
    await tester.tap(find.text('ANLADIM'));
    await tester.pump();

    await tester.tapAt(const Offset(187, 350));
    await pumpFrames(tester, 500);
    expect(
      find.textContaining('MÜKEMMEL'),
      findsOneWidget,
      reason: 'A centered early drop should receive clear perfect feedback.',
    );
    expect(tester.takeException(), isNull);

    for (var drop = 0; drop < 4; drop++) {
      await pumpFrames(tester, 16);
      await tester.tapAt(const Offset(187, 350));
      await pumpFrames(tester, 500);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
