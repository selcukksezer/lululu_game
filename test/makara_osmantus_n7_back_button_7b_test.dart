import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

// 7B — Faz 3 6D bayrağı: Makara/Osmantus N7 çıkışı 6D'de yalnız
// kod-parite + `Navigator.maybePop` tetiklemeli widget testiyle
// doğrulanmıştı (responsive_modes_n7_6d_test.dart). Bu dosya eksik
// halkayı kapatır: EKRANDAKİ Geri düğmesine dokunuş → onay diyaloğu
// → İptal (oyun sürer) / Çık (iade yok + kapanış) yolları ile
// hamlesiz Geri dokunuşunda anında çıkış + 1 enerji iadesi.
// Geri düğmesi her iki modda da başlıkta `goBackLabel` ('Geri')
// anlamsal etiketli yuvarlak düğmedir ve `Navigator.maybePop`
// çağırır; PopScope/N7 mantığı üretim kodunda aynen korunur.
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

  void setViewport(WidgetTester tester, double w, double h) {
    tester.view.physicalSize = Size(w, h);
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

  Future<void> pumpFrames(WidgetTester tester, int milliseconds) async {
    final frames = (milliseconds / 16).ceil();
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> flushFontCallbacks(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> openMode(
    WidgetTester tester,
    Widget mode, {
    double w = 374,
    double h = 680,
  }) async {
    setViewport(tester, w, h);
    await pumpWithL10n(
      tester,
      Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(
                ctx,
              ).push(MaterialPageRoute<void>(builder: (_) => mode)),
              child: const Text('OPEN_MODE_7B'),
            ),
          ),
        ),
      ),
      theme: buildLululuTheme(),
      debugShowCheckedModeBanner: false,
    );
    await tester.tap(find.text('OPEN_MODE_7B'));
    await tester.pump();
    await pumpFrames(tester, 100);
  }

  Finder dialogTitle() => find.text('Turdan çıkılsın mı?');
  Finder dialogCancel() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('İptal'),
  );
  Finder dialogConfirm() =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Çık'));

  /// Ekrandaki Geri düğmesine dokun (başlık düğmesi, `goBackLabel`).
  Future<void> tapBackButton(WidgetTester tester) async {
    final back = find.bySemanticsLabel('Geri');
    expect(back, findsOneWidget);
    await tester.tap(back);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapDialogButton(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> expectHomeAfterExit(WidgetTester tester) async {
    await pumpFrames(tester, 300);
    expect(find.text('OPEN_MODE_7B'), findsOneWidget);
    expect(dialogTitle(), findsNothing);
  }

  void expectNoUnexpectedError(WidgetTester tester) {
    expect(tester.takeException(), isNull);
  }

  group('7B — N7 Geri düğmesi (hamleli tur)', () {
    testWidgets('makara: Geri → diyalog → İptal kalır → Geri → Çık, iade yok',
        (tester) async {
      final key = GlobalKey<MakarayizScreenState>();
      await openMode(
        tester,
        TickerMode(
          enabled: false,
          child: MakarayizScreen(key: key, energyConsumed: true),
        ),
      );
      final mode = find.byType(MakarayizScreen);
      expect(mode, findsOneWidget);
      // Hamle: 6D deseni (durum API'si ile iki nota vuruşu).
      final state = key.currentState!;
      void hitNextNote() {
        while (true) {
          final notes = state.debugNotes.toList()
            ..sort((a, b) => a.hitMs.compareTo(b.hitMs));
          if (notes.isEmpty) {
            state.advance(16);
            continue;
          }
          final note = notes.first;
          state.advance(max(0, note.hitMs - state.debugNow));
          state.tryHit(note.lane);
          return;
        }
      }

      hitNextNote();
      hitNextNote();
      expect(state.debugCombo, 2);
      await tester.pump();

      await tapBackButton(tester);
      expect(dialogTitle(), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      await tapBackButton(tester);
      expect(dialogTitle(), findsOneWidget);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterExit(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets(
        'osmantus: Geri → diyalog → İptal kalır → Geri → Çık, iade yok',
        (tester) async {
      await openMode(tester, const OsmantusScreen(energyConsumed: true));
      final mode = find.byType(OsmantusScreen);
      expect(mode, findsOneWidget);
      // Hamle: 6D deseni (sahne merkezine dokunuş).
      final stage = find.byWidgetPredicate(
        (widget) => widget is Listener && widget.onPointerDown != null,
      );
      final stageRect =
          List.generate(
            stage.evaluate().length,
            (index) => tester.getRect(stage.at(index)),
          ).firstWhere(
            (rect) => rect.top > 100 && rect.bottom < 600 && rect.width > 300,
          );
      await tester.tapAt(stageRect.center);
      await tester.pump();

      await tapBackButton(tester);
      expect(dialogTitle(), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      await tapBackButton(tester);
      expect(dialogTitle(), findsOneWidget);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterExit(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });
  });

  group('7B — N7 Geri düğmesi (hamlesiz tur)', () {
    testWidgets('makara hamlesiz: Geri anında çıkar + iade', (tester) async {
      await openMode(
        tester,
        const TickerMode(
          enabled: false,
          child: MakarayizScreen(energyConsumed: true),
        ),
      );
      expect(find.byType(MakarayizScreen), findsOneWidget);
      expect(EnergyService.instance.energy, 3);
      await tapBackButton(tester);
      expect(dialogTitle(), findsNothing);
      expect(find.text('OPEN_MODE_7B'), findsOneWidget);
      expect(EnergyService.instance.energy, 4);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('osmantus hamlesiz: Geri anında çıkar + iade', (tester) async {
      await openMode(tester, const OsmantusScreen(energyConsumed: true));
      expect(find.byType(OsmantusScreen), findsOneWidget);
      expect(EnergyService.instance.energy, 3);
      await tapBackButton(tester);
      expect(dialogTitle(), findsNothing);
      expect(find.text('OPEN_MODE_7B'), findsOneWidget);
      expect(EnergyService.instance.energy, 4);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });
  });
}
