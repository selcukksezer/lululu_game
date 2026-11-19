import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Çığlık: tap flaps immediately and tutorial runs safely', (
    tester,
  ) async {
    // 12T: ekran `initState`'te `ProgressManager().load()` çağırır —
    // mock'suz `SharedPreferences.getInstance()` MissingPluginException
    // fırlatır; ayrıca GoogleFonts ağdan çekmesin (geç tamamlanan
    // yazı tipi bildirimi postTest denetimine takılır).
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

    await tester.pumpWidget(wrapWithL10n(const ScreamRoachScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('SKOR'), findsOneWidget);
    expect(find.textContaining('İLK 15 SN YAVAŞ'), findsOneWidget);
    expect(find.byTooltip('Bağırarak zıplamayı aç'), findsOneWidget);

    for (var i = 0; i < 24; i++) {
      await tester.tapAt(const Offset(190, 390));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
