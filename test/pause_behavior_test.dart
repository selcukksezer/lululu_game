import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/widgets/sticker_image.dart';

// Madde 37 (Terlik Tap, gerçek zamanlı mod): `_togglePause` duraklatmada
// 16 ms'lik oyun zamanlayıcısını durdurur (`_stopLoop`), devamda yeniden
// kurar (`_startLoop`); `_tick` ayrıca `_paused` korumasına sahiptir
// (lib/modes/terlik_tap_screen.dart).
//
// Gözlem: böcek ömrü eğitim evresinde 1.8 sn'dir
// (`TerlikTapPacing.targetVisibleSeconds`). Zamanlayıcı dururken 5 sn
// pompalansa bile ıska sayılmaz (`KAÇAN 0!` kalır, `KAÇTI` görünmez);
// devamdan sonra aynı böceğin süresi dolar ve ıska sayılır.
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

  Future<void> pumpTerlik(WidgetTester tester) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: TerlikTapScreen(initialTargetForTesting: true)),
    );
    await tester.pump();
  }

  testWidgets('duraklatmada oyun saati durur, devamda kaldığı yerden işler', (
    tester,
  ) async {
    await pumpTerlik(tester);
    expect(find.text('KAÇAN 0!'), findsOneWidget);
    expect(find.textContaining('KAÇTI'), findsNothing);
    expect(find.text('DURAKLATILDI'), findsNothing);

    // Duraklat: kaplama görünür.
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('DURAKLATILDI'), findsOneWidget);
    expect(find.text('DEVAM'), findsOneWidget);

    // Böcek ömrünün (1.8 sn) çok üstünde süre pompalansa bile ıska
    // sayılmaz: zamanlayıcı durdu, böcek süresi dondu.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('DURAKLATILDI'), findsOneWidget);
    expect(find.text('KAÇAN 0!'), findsOneWidget);
    expect(find.textContaining('KAÇTI'), findsNothing);

    // Devam: kaplama kalkar, saat kaldığı yerden işler; donmuş böceğin
    // kalan ömrü dolar ve ıska sayılır.
    await tester.tap(find.text('DEVAM'));
    await tester.pump();
    expect(find.text('DURAKLATILDI'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('KAÇAN 0!'), findsNothing);
    expect(find.textContaining('KAÇTI'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('duraklatma kaplaması dokunuşları yutar, böcek ezilmez', (
    tester,
  ) async {
    await pumpTerlik(tester);
    expect(find.text('VURUŞ 0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('DURAKLATILDI'), findsOneWidget);

    // Kaplama tam ekran ve opak dokunuş yutucudur: böceğin üstüne
    // dokunmak vuruş sayılmaz.
    await tester.tap(find.byType(StickerImage).first);
    await tester.pump();
    expect(find.text('VURUŞ 0'), findsOneWidget);
    expect(find.text('KAÇAN 0!'), findsOneWidget);

    // Devamdan sonra aynı böcek ezilebilir (girdi geri gelir).
    await tester.tap(find.text('DEVAM'));
    await tester.pump();
    await tester.tap(find.byType(StickerImage).first);
    await tester.pump();
    expect(find.textContaining('VURUŞ 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
