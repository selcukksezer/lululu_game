import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/widgets/sticker_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    AudioManager().isMuted = true;
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

  test('tutorial gives slower emergence and longer target windows', () {
    expect(TerlikTapPacing.spawnInterval(0), 1.15);
    expect(TerlikTapPacing.spawnInterval(14.9), 1.15);
    expect(TerlikTapPacing.targetVisibleSeconds(14.9), 1.8);
    expect(TerlikTapPacing.spawnInterval(16), lessThan(1.15));
    expect(TerlikTapPacing.targetVisibleSeconds(16), lessThan(1.8));
    expect(TerlikTapPacing.spawnInterval(200), 0.58);
  });

  testWidgets('players can hit a mole and miss penalty is clear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: TerlikTapScreen(initialTargetForTesting: true)),
    );
    await tester.pump();

    final bugFinder = find.byType(StickerImage).first;
    expect(bugFinder, findsOneWidget);
    final bugKey =
        tester.widget<StickerImage>(bugFinder).key! as ValueKey<String>;
    final hitHole = int.parse(bugKey.value.split('-').last);
    await tester.tap(bugFinder);
    await tester.pump();
    expect(find.textContaining('COMBO X1'), findsWidgets);
    expect(find.textContaining('VURUŞ 1'), findsOneWidget);

    final emptyHoles = List<int>.generate(
      9,
      (index) => index,
    ).where((index) => index != hitHole).take(3);
    for (final hole in emptyHoles) {
      await tester.tap(find.byKey(ValueKey<String>('terlik-hole-$hole')));
      await tester.pump();
    }
    expect(find.textContaining('BOŞA VURDUN'), findsOneWidget);
    expect(find.textContaining('KOMBO KIRILDI'), findsWidgets);
    expect(find.textContaining('-1 CAN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
