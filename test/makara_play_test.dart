import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Makarayız sync, combo breaks, and ramps after tutorial', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    AudioManager().isMuted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (call) async => null,
      )
      ..setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (call) async => null,
      )
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async => null);

    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final key = GlobalKey<MakarayizScreenState>();
    await tester.pumpWidget(
      wrapWithL10n(
        TickerMode(enabled: false, child: MakarayizScreen(key: key)),
      ),
    );
    await tester.pump();

    final state = key.currentState!;
    expect(state.debugBeatMs, 950);
    expect(state.debugWindowMs, 280);

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
    expect(state.debugScore, greaterThan(0));

    final missed = state.debugNotes
        .where((note) => note.hitMs > state.debugNow)
        .reduce((a, b) => a.hitMs < b.hitMs ? a : b);
    state.advance(missed.hitMs - state.debugNow);
    state.tryHit((missed.lane + 1) % 3);
    await tester.pump();
    expect(state.debugCombo, 0);
    // Yanlış şerit: can kaybı yok (yalnız kombo kırılır + nota kaybolur).
    expect(state.debugLives, 3);
    expect(state.debugBreakText, 'KOMBO KIRILDI · YANLIŞ ŞERİT');
    expect(find.text('KOMBO KIRILDI · YANLIŞ ŞERİT'), findsOneWidget);

    while (state.debugNow < 14900) {
      final next = state.debugNotes.toList()
        ..sort((a, b) => a.hitMs.compareTo(b.hitMs));
      if (next.isEmpty) {
        state.advance(16);
      } else if (next.first.hitMs > 14900) {
        state.advance(14900 - state.debugNow);
      } else {
        state.advance(next.first.hitMs - state.debugNow);
        state.tryHit(next.first.lane);
      }
    }
    expect(state.debugBeatMs, 950);
    expect(state.debugWindowMs, 280);

    while (state.debugNow < 45000 && state.debugAlive) {
      final next =
          state.debugNotes.where((note) => note.hitMs > state.debugNow).toList()
            ..sort((a, b) => a.hitMs.compareTo(b.hitMs));
      if (next.isEmpty) {
        state.advance(16);
      } else if (next.first.hitMs > 45000) {
        // Son notanın ötesine taşmadan tam 45. sn'de dur: beat/pencere
        // ölçümü rampa 0.5'te yapılır (yukarıdaki 14900 kelepçesiyle
        // aynı desen; taşma rampayı 0.5'in üstüne iterdi).
        state.advance(45000 - state.debugNow);
      } else {
        state.advance(next.first.hitMs - state.debugNow);
        state.tryHit(next.first.lane);
      }
    }

    expect(state.debugAlive, isTrue);
    expect(state.debugNow, greaterThanOrEqualTo(45000));
    // 45. sn (rampa 0.5): beat lerp(950,600,0.5) = 775,
    // pencere lerp(280,190,0.5) = 235.
    expect(state.debugBeatMs, closeTo(775, 0.1));
    expect(state.debugWindowMs, closeTo(235, 0.1));
    expect(state.debugCombo, greaterThan(20));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
