import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/bonus_fx.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockAudio() {
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  }

  Future<void> pumpSteps(
    WidgetTester tester, {
    int count = 10,
    Duration step = const Duration(milliseconds: 100),
  }) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  group('12S F16 flyover — Suika entegrasyonu', () {
    testWidgets('Suika AYDINLAT dugmesi jet ucusunu tetikler', (
      tester,
    ) async {
      mockAudio();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(debugResetF16FlyoverGuard);

      await pumpWithL10n(
        tester,
        GameScreen(level: CampaignDatabase.kitchenLevel1, arcade: true),
        debugShowCheckedModeBanner: false,
        theme: buildLululuTheme(),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('AYDINLAT'), findsOneWidget);

      await tester.tap(find.text('AYDINLAT'));
      await tester.pump();
      expect(find.byKey(const Key('f16-flyover-jet')), findsOneWidget);

      await pumpSteps(tester, count: 20);
      expect(find.byKey(const Key('f16-flyover-jet')), findsNothing);
      expect(tester.takeException(), isNull);

      // Sistem-yazıtipi bildirimi gerçek-zamanlı gelir: sahte saatli
      // pump'lar onu yakalayamaz (12P deseni) — gerçek kısa bekleme +
      // pump, dispose anında bekleyen kare geri-çağrısı kalmasın diye.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
