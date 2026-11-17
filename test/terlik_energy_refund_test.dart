import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/widgets/sticker_image.dart';

// Terlik Tap hamlesiz-çıkış enerji iadesi — Stack Drop deseninin aynısı
// (`test/other_modes_energy_refund_test.dart`): rotayı it, `pageBack`
// ile çık, enerji sayımını doğrula. İade `dispose` içinde DEĞİLDİR
// (lib/modes/terlik_tap_screen.dart:257-264); yalnız gerçek rota
// çıkışında (`PopScope`, aynı dosya:1163-1169) ve Geri düğmesinde
// (aynı dosya:1254-1257) çağrılan `_refundEnergyIfNoHit` (aynı
// dosya:616-638) ile tetiklenir.
//
// Terlik'in Stack deseninden farkları (koddan okundu, uydurma değil):
// 1. Hamle bayrağı `_hasHit` yalnız GERÇEK vuruşta kurulur: böcek ezme
//    (:699), tuzak (:683), ilaçla temizlik (:981). Boş deliğe dokunuş
//    yalnız kombo kırar (:668-676) ve iade hakkını bitirmez — bu
//    yüzden "hamle" testi boş dokunuşla değil, böcek vuruşuyla yapılır.
// 2. İade koşulu daha geniştir: `energyConsumed` + `_hasHit` false +
//    `_runEnded` false + `_economySettled` false + `_alive` (:625-633).
//    Stack'te karşılık: `_moveMade` + faz + sonuç bayrağı.
// 3. İKİ çağrı noktası vardır (PopScope + Geri düğmesi); çift-iade
//    koruması `_energyRefunded` bayrağıdır (:151, :635-637). Stack'te
//    tek çağrı noktası (PopScope) vardır.
// 4. `_hasHit` / `_runEnded` `_restart`'ta SIFIRLANMAZ (:142-149):
//    iade kararı oturum düzeyindedir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
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
    await EnergyService.instance.load();
    EnergyService.instance.energy = 3;
  });

  Future<void> pumpFrames(WidgetTester tester, int milliseconds) async {
    final frames = (milliseconds / 16).ceil();
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  void setViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openTerlik(
    WidgetTester tester, {
    required bool energyConsumed,
    bool initialTargetForTesting = false,
  }) async {
    setViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TerlikTapScreen(
                      energyConsumed: energyConsumed,
                      initialTargetForTesting: initialTargetForTesting,
                    ),
                  ),
                ),
                child: const Text('OPEN_TERLIK'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN_TERLIK'));
    await tester.pump();
    await pumpFrames(tester, 100);
  }

  Future<void> popTerlik(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pump();
    await pumpFrames(tester, 50);
    expect(find.text('OPEN_TERLIK'), findsOneWidget);
  }

  testWidgets('hamlesiz pop çıkışında 1 enerji iade edilir', (tester) async {
    await openTerlik(tester, energyConsumed: true);
    expect(EnergyService.instance.energy, 3);

    await popTerlik(tester);

    expect(EnergyService.instance.energy, 4);
    expect(EnergyService.instance.energyNotifier.value, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('energyConsumed false ise pop çıkışında iade yapılmaz',
      (tester) async {
    await openTerlik(tester, energyConsumed: false);

    await popTerlik(tester);

    expect(EnergyService.instance.energy, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gerçek vuruş yapıldıysa pop çıkışında iade yapılmaz',
      (tester) async {
    await openTerlik(
      tester,
      energyConsumed: true,
      initialTargetForTesting: true,
    );
    // terlik_play_test ile aynı kanıtlanmış desen: ilk hedefe dokunuş
    // `_tapHole` ile `_hasHit` kurar (:699). Tuzak bu aşamada imkânsız
    // (_spawn tuzak için skor >= 220 ister, :421-424), o yüzden vuruş
    // kanıtı COMBO/VURUŞ metnidir; tuzak da vursaydı _hasHit yine
    // kurulurdu (:683) ve beklenti aynı olurdu.
    final bugFinder = find.byType(StickerImage).first;
    expect(bugFinder, findsOneWidget);
    await tester.tap(bugFinder);
    await tester.pump();
    expect(find.textContaining('COMBO X1'), findsWidgets);
    expect(find.textContaining('VURUŞ 1'), findsOneWidget);

    await popTerlik(tester);

    expect(EnergyService.instance.energy, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pop olmadan kaldırma (dispose) iade yapmaz', (tester) async {
    setViewport(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: TerlikTapScreen(energyConsumed: true),
      ),
    );
    await pumpFrames(tester, 100);
    expect(EnergyService.instance.energy, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(EnergyService.instance.energy, 3);
    expect(tester.takeException(), isNull);
  });
}
