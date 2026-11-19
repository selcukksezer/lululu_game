import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

// Diğer modlarda hamlesiz-çıkış enerji iadesi — Stack Drop örneği:
// `StackDropScreen(energyConsumed: true)` ile açılan oturumda hiç hamle
// yapılmadan gerçek rota çıkışı (pop) yapılırsa 1 enerji iade edilir
// (lib/modes/stack_drop_screen.dart:24-34 parametre, 681-691
// `_maybeRefundEnergy`, 703-708 `PopScope`). İade `dispose` içinde
// DEĞİLDİR (aynı dosya:200-208); hamle bayrağı `_moveMade` bırakma
// anında kurulur (aynı dosya:432-436).
//
// Desen `test/energy_refund_test.dart` (Suika) ile aynıdır, tek fark:
// Suika iadesi `dispose` ile tetiklenir, Stack iadesi yalnız gerçek
// `pop` ile tetiklenir — bu yüzden testler rotayı itip pop ile
// çıkarır. Terlik Tap'te aynı sözleşme vardır
// (lib/modes/terlik_tap_screen.dart:625-638) ama bu dosyada kapsanmaz.
//
// 7B (N7) NOTU: N7 (6D) hamleli turda çıkışa onay diyaloğu ekledi;
// bu yüzden hamleli test artık "pop = anında çıkış" kodlamaz —
// diyalog + İptal (kalır, iade yok) + Çık (çıkar, iade yok) yolunu
// doğrular. Hamlesiz çıkış N7'de de anındadır ve 1 enerji iade
// edilir. Çıkış tetiklemesi `tester.pageBack()` DEĞİLDİR: bu SDK'da
// sayfada `CupertinoNavigationBarBackButton` yoktur, `pageBack`
// her zaman düşer (6D notu); üretimdeki gibi
// `Navigator.maybePop` kullanılır (responsive_modes_n7_6d_test
// deseni). Üretim davranışı değişikliği YOK — yalnız test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

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
    // fontsChange teardown tahliyesi (6D deseni): geç gelen
    // `fontsChange` bildiriminin bıraktığı transient callback
    // `postTest`'ten önce işletilir.
    addTearDown(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
        await binding.pump();
      }
    });
  }

  /// Font-change transient callback'lerini tahliye eder (6D deseni).
  Future<void> flushFontCallbacks(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> openStack(
    WidgetTester tester, {
    required bool energyConsumed,
  }) async {
    setViewport(tester);
    await pumpWithL10n(
      tester,
      Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => StackDropScreen(
                    energyConsumed: energyConsumed,
                  ),
                ),
              ),
              child: const Text('OPEN_STACK'),
            ),
          ),
        ),
      ),
      theme: buildLululuTheme(),
    );
    await tester.tap(find.text('OPEN_STACK'));
    await tester.pump();
    await pumpFrames(tester, 100);
  }

  /// Çıkış isteği: üretimdeki gibi `Navigator.maybePop` (6D deseni).
  /// `tester.pageBack()` bu SDK'da `CupertinoNavigationBarBackButton`
  /// bulamadığı için kullanılmaz.
  Future<void> requestPop(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(StackDropScreen))).maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> popStack(WidgetTester tester) async {
    await requestPop(tester);
    await pumpFrames(tester, 50);
    expect(find.text('OPEN_STACK'), findsOneWidget);
  }

  Finder dialogTitle() => find.text('Turdan çıkılsın mı?');
  Finder dialogCancel() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('İptal'),
  );
  Finder dialogConfirm() =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Çık'));

  testWidgets('hamlesiz pop çıkışında 1 enerji iade edilir', (tester) async {
    await openStack(tester, energyConsumed: true);
    expect(EnergyService.instance.energy, 3);

    // N7: hamlesiz çıkış hâlâ anındadır (diyalog yok) + 1 iade.
    await popStack(tester);

    expect(EnergyService.instance.energy, 4);
    expect(EnergyService.instance.energyNotifier.value, 4);
    await flushFontCallbacks(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('energyConsumed false ise pop çıkışında iade yapılmaz',
      (tester) async {
    await openStack(tester, energyConsumed: false);

    await popStack(tester);

    expect(EnergyService.instance.energy, 3);
    await flushFontCallbacks(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'hamle yapıldıysa pop önce diyalog gösterir, Çık iadesiz çıkar',
      (tester) async {
    await openStack(tester, energyConsumed: true);
    // stack_play_test ile aynı kanıtlanmış desen: sahneye dokunuş dilim
    // bırakır (`_drop` bırakma anında `_moveMade` kurar).
    await tester.tapAt(const Offset(187, 350));
    await pumpFrames(tester, 500);

    // N7 (6D): hamleli turda pop anında çıkmaz — onay diyaloğu açılır,
    // İptal oyunda bırakır (iade yok), Çık iadesiz çıkar. Eski test
    // "pop = anında çıkış, iade yok" kodluyordu; o davranış N7 ile
    // bilinçli olarak değişti.
    await requestPop(tester);
    expect(dialogTitle(), findsOneWidget);
    expect(find.text('OPEN_STACK'), findsNothing);
    expect(EnergyService.instance.energy, 3);
    await tester.tap(dialogCancel());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(dialogTitle(), findsNothing);
    expect(find.byType(StackDropScreen), findsOneWidget);
    expect(EnergyService.instance.energy, 3);

    await requestPop(tester);
    expect(dialogTitle(), findsOneWidget);
    await tester.tap(dialogConfirm());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await pumpFrames(tester, 50);
    expect(find.text('OPEN_STACK'), findsOneWidget);

    expect(EnergyService.instance.energy, 3);
    await flushFontCallbacks(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pop olmadan kaldırma (dispose) iade yapmaz', (tester) async {
    setViewport(tester);
    await pumpWithL10n(
      tester,
      const StackDropScreen(energyConsumed: true),
      theme: buildLululuTheme(),
    );
    await pumpFrames(tester, 100);
    expect(EnergyService.instance.energy, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(EnergyService.instance.energy, 3);
    await flushFontCallbacks(tester);
    expect(tester.takeException(), isNull);
  });
}
