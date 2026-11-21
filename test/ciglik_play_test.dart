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

  // Semantik etiketi (`find.bySemanticsLabel`) için tek handle —
  // test başına `addTearDown` ile dispose, çerçevenin test-sonu
  // denetiminden sonra koştuğu için "handle active" hatası verir;
  // repo deseni (`shop_confirm_test.dart`) `setUpAll`/`tearDownAll`.
  late SemanticsHandle semanticsHandle;
  setUpAll(() {
    semanticsHandle = TestWidgetsFlutterBinding.instance.ensureSemantics();
  });
  tearDownAll(() {
    semanticsHandle.dispose();
  });

  // 12T: ekran `initState`'te `ProgressManager().load()` çağırır —
  // mock'suz `SharedPreferences.getInstance()` MissingPluginException
  // fırlatır; ayrıca GoogleFonts ağdan çekmesin (geç tamamlanan
  // yazı tipi bildirimi postTest denetimine takılır).
  Future<void> pumpScreamScreen(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = size;
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
  }

  // Dalga 17 Düzeltme 3 — flap kanıtı: `_scream` çalışırsa `_hint`
  // '... · spam x<n>' olur ve `Semantics(label: _hint)` düğümüne
  // yansır. Girdisiz oyunda seri 0 kalır, ipucu ölüm/boşta metnidir;
  // bu bulgu tap'ın gerçekten kanat çırptığını kanıtlar.
  void expectFlapped() {
    expect(find.bySemanticsLabel(RegExp(r'spam x\d+')), findsOneWidget);
  }

  testWidgets('Çığlık: tap flaps immediately and tutorial runs safely', (
    tester,
  ) async {
    await pumpScreamScreen(tester, const Size(374, 680));

    expect(find.text('SKOR'), findsOneWidget);
    expect(find.textContaining('İLK 15 SN YAVAŞ'), findsOneWidget);
    expect(find.byTooltip('Bağırarak zıplamayı aç'), findsOneWidget);

    for (var i = 0; i < 24; i++) {
      await tester.tapAt(const Offset(190, 390));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
    }

    // Dalga 17 Düzeltme 3: 24 tap sonrası seri > 0 olmalı — tap
    // girdisi `_scream`'e ulaştı, böcek kanat çırptı.
    expectFlapped();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Çığlık: wide viewport tap flaps (Dalga 17 Düzeltme 3)', (
    tester,
  ) async {
    // 1280x800: geniş düzen — ilk kapı eskiden arena genişliğinin
    // %56'sında (~700 px, ~10 sn) doğuyordu; artık ~220 px.
    await pumpScreamScreen(tester, const Size(1280, 800));

    expect(find.byTooltip('Bağırarak zıplamayı aç'), findsOneWidget);

    // Ekran ortası sahnenin içindedir (başlık/HUD üstte, dock altta).
    for (var i = 0; i < 8; i++) {
      await tester.tapAt(const Offset(640, 400));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
    }

    // Tap girdisi ham `Listener` yolundan `_scream`'e ulaştı.
    expectFlapped();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
