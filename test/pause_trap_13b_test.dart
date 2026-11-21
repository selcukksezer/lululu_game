import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/yuva_defense_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';

import 'test_helpers.dart';

// W13-B — Duraklatma tuzağı (playtest §10/§11):
// Çığlık Böcek ve Makarayız'da ⏸ → PAUSED/DURAKLATILDI overlay +
// CONTINUE; CONTINUE'ye basınca overlay kapanmıyor, FINISH overlay
// arkasında ölü kalıyor (canlı kareler bayt bayt aynı).
//
// NOT: Match 3'teki `_busy` koruması bu iki dosyada YOK
// (grep: `_busy` 0 eşleşme) — kök neden başka yerde aranır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  Future<void> pump430(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapWithL10n(child, locale: const Locale('en')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // ciglik_play_test ile aynı kapanış: sistem-font bildirimi sonrası
  // bekleyen kare geri çağrısı dispose'a takılmasın.
  Future<void> tearDownClean(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  // Ortak akış: ⏸ → overlay → CONTINUE → overlay kalkmalı.
  Future<void> expectPauseResume(
    WidgetTester tester,
    String pausedTitle,
  ) async {
    expect(find.byIcon(Icons.pause_rounded), findsWidgets);
    await tester.tap(find.byIcon(Icons.pause_rounded).first);
    await tester.pump();
    expect(find.text(pausedTitle), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    expect(find.text(pausedTitle), findsNothing);
    expect(find.text('CONTINUE'), findsNothing);
  }

  testWidgets('W13-B Çığlık Böcek: CONTINUE overlayi kapatır', (tester) async {
    await pump430(tester, const ScreamRoachScreen());
    expect(find.byIcon(Icons.pause_rounded), findsWidgets);

    // Duraklat: overlay açılır.
    await tester.tap(find.byIcon(Icons.pause_rounded).first);
    await tester.pump();
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);

    // Devam: overlay kapanmalı, oyun kaldığı yerden sürmeli.
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    expect(find.text('PAUSED'), findsNothing);
    expect(find.text('CONTINUE'), findsNothing);

    // ciglik_play_test ile aynı kapanış: sistem-font bildirimi
    // sonrası bekleyen kare geri çağrısı dispose'a takılmasın.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('W13-B Makarayız: CONTINUE overlayi kapatır', (tester) async {
    await pump430(tester, const MakarayizScreen());
    expect(find.byIcon(Icons.pause_rounded), findsWidgets);

    // Duraklat: overlay açılır (başlık TR sabit yazılmıştır).
    await tester.tap(find.byIcon(Icons.pause_rounded).first);
    await tester.pump();
    expect(find.text('DURAKLATILDI'), findsOneWidget);
    expect(find.text('CONTINUE'), findsOneWidget);

    // Devam: overlay kapanmalı.
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    expect(find.text('DURAKLATILDI'), findsNothing);
    expect(find.text('CONTINUE'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  // ---- TARAMA: kalan modlar (Terlik pause_behavior_test ile kanıtlı,
  // 2048'de duraklatma düğmesi yok) ----

  testWidgets('W13-B tarama Bağla Patlat: CONTINUE overlayi kapatır', (
    tester,
  ) async {
    // ŞÜPHE: connect_pop_screen.dart:763 `_togglePause` Match3'teki
    // gibi `_ended || _busy` korumasına sahip. `_busy` yalnız zincir
    // temizleme animasyonu boyunca true (647) ve `finally` ile
    // temizlenir (879) + sıfırlamada false (389); kalıcı takılma yolu
    // yok — bu test canlı kanıtı verir.
    await pump430(
      tester,
      const ConnectPopScreen(gameplayTestState: true),
    );
    await expectPauseResume(tester, 'DURAKLATILDI');
    await tearDownClean(tester);
  });

  testWidgets('W13-B tarama Balon Patlat: CONTINUE overlayi kapatır', (
    tester,
  ) async {
    await pump430(tester, const BalloonPopScreen());
    await expectPauseResume(tester, 'DURAKLATILDI');
    await tearDownClean(tester);
  });

  testWidgets('W13-B tarama Yuva Savunması: CONTINUE overlayi kapatır', (
    tester,
  ) async {
    await pump430(tester, const YuvaDefenseScreen());
    await expectPauseResume(tester, 'PAUSED');
    await tearDownClean(tester);
  });

  testWidgets('W13-B tarama Osmantuş: CONTINUE overlayi kapatır', (
    tester,
  ) async {
    var nowMs = 0;
    await pump430(tester, OsmantusScreen(clockForTesting: () => nowMs));
    await expectPauseResume(tester, 'DURAKLATILDI');
    await tearDownClean(tester);
  });
}
