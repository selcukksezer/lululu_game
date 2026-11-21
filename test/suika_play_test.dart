import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
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
  });

  testWidgets('Suika accepts drops and shows combo and next-piece feedback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 6D/7B deseni (stack_kat15_6g_test ile aynı): GoogleFonts'un tembel
    // yüklemesi `fontsChange` bildirimi bırakır; bildirim gövdenin son
    // pump'ından sonra gelirse `postTest` değişmez denetimine takılır
    // ("animation is still running"). Üretim kodu hatası değildir.
    addTearDown(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
        await binding.pump();
      }
    });

    await pumpWithL10n(
      tester,
      GameScreen(
        level: CampaignDatabase.kitchenLevel1,
        arcade: true,
      ),
      debugShowCheckedModeBanner: false,
      theme: buildLululuTheme(),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('SIRADAKİ'), findsOneWidget);

    for (var drop = 0; drop < 6; drop++) {
      await tester.tapAt(Offset(82 + (drop * 39) % 205, 250));
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    expect(find.text('SKOR'), findsOneWidget);
    expect(find.text('SIRADAKİ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
