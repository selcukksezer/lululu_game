// W13-F: Liste "Best" tohumları + Osmanthus/Makara öğreticisi.
//
// Alt görev 1 — Liste "Best"i yalnız gerçek skordan alır
// (`ProgressManager.getModeBestScore` → `modeHighScores`); katalog
// tohumu (`defaultBestScore`: 4820/5940/…) artık listede görünmez,
// hiç oynanmamış modda '—' gösterilir (playtest §4).
//
// Yıldızlar bu değişiklikten etkilenmez: `ResultScoring.starsForMode`
// sabit `threeStarScore` çıtasına bakar, kişisel best'e değil
// (12Q-stars); ilk turda düşük skor rekor kırsa bile 3 yıldız vermez.
//
// Alt görev 2 — Öğretim/geri bildirim (mekanik değişmez):
// * Osmantuş: `_hint` yalnız Semantics etiketindeydi; bant boşken
//   bant satırında görünür olur (boşta "Halka yeşilken BİR KEZ
//   dokun!", çok erken basışta "Bekle, halka yeşile dönsün."). Isınma
//   turunda (ilk 15 sn) erken/kaçan vuruş can kaybettirmez.
// * Makarayız: `hint` chrome'a geçiriliyor ama hiç çizilmiyordu;
//   HUD altında görünür ipucu satırı eklendi. Şeritte nota yokken
//   dokunuş tamamen sessizdi — artık "BEAT ÇİZGİSİNDE BAS!" ipucu
//   verir (skor/can/kombo değişmez).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/lululu_game_mode.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/screens/modes_screen.dart';
import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    await loadTestFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
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

  setUp(() {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    // Singleton harita testler arasında yaşar — her test taze başlar.
    ProgressManager.instance.modeHighScores.clear();
  });

  group('W13-F liste Best: yalnız gerçek skor', () {
    Future<void> pumpModes(WidgetTester tester) async {
      tester.view.physicalSize = const Size(374, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Teardown flake tahliyesi (suika_best_hud_6e / 12I deseni):
      // font yüklemeden kalan transient callback + PM async yüklemesi.
      addTearDown(() async {
        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
          await binding.pump();
        }
      });
      await pumpWithL10n(
        tester,
        const ModesScreen(),
        debugShowCheckedModeBanner: false,
        theme: buildLululuTheme(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('hiç oynanmamış modda tohum Best görünmez, hepsi —', (
      tester,
    ) async {
      await pumpModes(tester);
      // 11 satırın tamamı "Rekor —" gösterir.
      expect(find.textContaining('Rekor —'), findsNWidgets(11));
      // Katalog tohumları listede yoktur ('Rekor ' önekiyle aranır:
      // coin hapı da sayı gösterir, ör. varsayılan 1.240).
      for (final seed in ['4.820', '5.940', '3.260', '2.870', '1.540',
          '1.150', '1.240', '2.105', '1.760']) {
        expect(find.textContaining('Rekor $seed'), findsNothing, reason: seed);
      }
    });

    testWidgets('kaydedilen gerçek skor listede görünür, gerisi —', (
      tester,
    ) async {
      expect(
        await ProgressManager.instance.recordModeScore('suika', 4820),
        isTrue,
      );
      expect(
        await ProgressManager.instance.recordModeScore('match3', 250),
        isTrue,
      );
      await pumpModes(tester);
      // Suika'da 4820 tohumla aynı sayı — ama artık kayıttan geliyor;
      // ayırt edici kanıt Match3: tohum 5.940 yerine gerçek 250.
      expect(find.textContaining('Rekor 4.820'), findsOneWidget);
      expect(find.textContaining('Rekor 250'), findsOneWidget);
      expect(find.textContaining('Rekor 5.940'), findsNothing);
      expect(find.textContaining('Rekor —'), findsNWidgets(9));
    });
  });

  group('W13-F yıldızlar bestten bağımsız (liste değişimi bozmaz)', () {
    test('ilk turda düşük skor rekor kırsa bile 3 yıldız vermez', () {
      // best 0 iken 100 puan rekor kırar (isNewRecord true) ama
      // yıldız çıta (suika 4820) bazlıdır: 1 yıldız.
      expect(ResultScoring.isNewRecord(score: 100, best: 0), isTrue);
      expect(
        ResultScoring.starsForMode(score: 100, modeScoreId: 'suika'),
        1,
      );
      expect(
        ResultScoring.starsForMode(score: 0, modeScoreId: 'suika'),
        0,
      );
      expect(
        ResultScoring.starsForMode(score: 4820, modeScoreId: 'suika'),
        3,
      );
      expect(
        ResultScoring.starsForMode(score: 2892, modeScoreId: 'suika'),
        2,
      );
      expect(
        ResultScoring.starsForMode(score: 110, modeScoreId: 'makarayiz'),
        1,
      );
      expect(
        ResultScoring.starsForMode(score: 1760, modeScoreId: 'makarayiz'),
        3,
      );
      expect(
        ResultScoring.starsForMode(score: 12480, modeScoreId: 'grid_2048'),
        3,
      );
    });

    test('üç yıldız çıtaları katalogda aynen durur', () {
      expect(
        LululuGameMode.byId(LululuGameModeId.suikaArena).threeStarScore,
        4820,
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.grid2048).threeStarScore,
        12480,
      );
      expect(
        LululuGameMode.byId(LululuGameModeId.makarayiz).threeStarScore,
        1760,
      );
    });
  });

  group('W13-F Osmantuş öğreticisi', () {
    Future<Offset> pumpOsmantus(WidgetTester tester, int Function() clock) async {
      tester.view.physicalSize = const Size(374, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
          await binding.pump();
        }
      });
      await pumpWithL10n(
        tester,
        OsmantusScreen(clockForTesting: clock),
        theme: buildLululuTheme(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final stage = find.byWidgetPredicate(
        (widget) => widget is Listener && widget.onPointerDown != null,
      );
      final stageRects = List.generate(
        stage.evaluate().length,
        (index) => tester.getRect(stage.at(index)),
      );
      final stageRect = stageRects.firstWhere(
        (rect) => rect.top > 100 && rect.bottom < 600 && rect.width > 300,
      );
      return stageRect.center;
    }

    testWidgets('ilk turda ipucu görünür: halka yeşilken BİR KEZ dokun', (
      tester,
    ) async {
      var nowMs = 0;
      await pumpOsmantus(tester, () => nowMs);
      expect(find.text('Halka yeşilken BİR KEZ dokun!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('çok erken basışta yönlü geri bildirim görünür', (
      tester,
    ) async {
      var nowMs = 0;
      final point = await pumpOsmantus(tester, () => nowMs);
      // İlk vuruş 1600 ms'de, pencere ±260 ms; 1000 ms'de basış
      // pencerenin çok öncesindedir (delta -600 < -260*1.2).
      nowMs = 1000;
      await tester.pump();
      await tester.tapAt(point);
      await tester.pump();
      expect(find.text('Bekle, halka yeşile dönsün.'), findsOneWidget);
      expect(find.text('ERKEN BASTIN'), findsNothing);
      expect(find.textContaining('KOMBO BOZULDU'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('ısınma turunda 3 erken vuruş can kaybettirmez', (
      tester,
    ) async {
      var nowMs = 0;
      final point = await pumpOsmantus(tester, () => nowMs);
      // 3 vuruş aralığı: 1600 / 2734 / 3868 ms (DDA 0.97 ile); her birinden
      // 300 ms önce basış tuzak bandına düşer (delta -300, bant [-321.6, -268)).
      for (final tapMs in [1300, 2434, 3568]) {
        nowMs = tapMs;
        await tester.pump();
        await tester.tapAt(point);
        await tester.pump();
        expect(find.text('ERKEN BASTIN'), findsOneWidget);
        // Bir sonraki vuruşa ilerlet (ıskalanan vuruş bandı yeniler).
        nowMs = tapMs + 400;
        await tester.pump();
      }
      // 3 can olsaydı oyun bitmişti; 4. vuruşta (4900 ms, tam zamanında)
      // isabet alınır — ısınma turu can kaybettirmedi.
      nowMs = 4900;
      await tester.pump();
      await tester.tapAt(point);
      await tester.pump();
      expect(find.text('x1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('W13-F Makara öğreticisi', () {
    Future<GlobalKey<MakarayizScreenState>> pumpMakara(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(374, 680);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
          await binding.pump();
        }
      });
      final key = GlobalKey<MakarayizScreenState>();
      await tester.pumpWidget(
        wrapWithL10n(
          TickerMode(enabled: false, child: MakarayizScreen(key: key)),
        ),
      );
      await tester.pump();
      // PM async yüklemesinin sıfır-süreli coin timer'ını akıt.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      return key;
    }

    testWidgets('ilk turda ipucu görünür: nota çizgideyken dokun', (
      tester,
    ) async {
      final key = await pumpMakara(tester);
      final state = key.currentState!;
      expect(state.debugHint, contains('Nota beat çizgisine gelince'));
      expect(
        find.text('Nota beat çizgisine gelince şeride dokun ya da kaydır.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('şeritte nota yokken dokunuş sessiz kalmaz', (
      tester,
    ) async {
      final key = await pumpMakara(tester);
      final state = key.currentState!;
      expect(state.debugNotes, isEmpty);
      state.tryHit(0);
      // Mekanik aynen: skor/can/kombo/ıska değişmez, yalnız ipucu.
      expect(state.debugScore, 0);
      expect(state.debugLives, 3);
      expect(state.debugMisses, 0);
      expect(state.debugHint, 'BEAT ÇİZGİSİNDE BAS!');
      await tester.pump();
      expect(find.text('BEAT ÇİZGİSİNDE BAS!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('erken dokunuşta pencere bilgisi görünür, can gitmez', (
      tester,
    ) async {
      final key = await pumpMakara(tester);
      final state = key.currentState!;
      while (state.debugNotes.isEmpty) {
        state.advance(16);
      }
      final notes = state.debugNotes.toList()
        ..sort((a, b) => a.hitMs.compareTo(b.hitMs));
      final first = notes.first;
      // Nota ~1000 ms uzaktayken (pencere ±280 ms) kendi şeridine bas.
      state.advance(max(0, first.hitMs - 1000 - state.debugNow));
      state.tryHit(first.lane);
      expect(state.debugHint, contains('ERKEN DOKUNDUN'));
      expect(state.debugHint, contains('±280 ms'));
      expect(state.debugLives, 3);
      expect(state.debugMisses, 1);
      await tester.pump();
      expect(find.text('ERKEN DOKUNDUN'), findsOneWidget);
      expect(
        find.textContaining('vuruş penceresi: ±280 ms'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('doğru vuruş hâlâ skor verir (mekanik değişmedi)', (
      tester,
    ) async {
      final key = await pumpMakara(tester);
      final state = key.currentState!;
      while (state.debugNotes.isEmpty) {
        state.advance(16);
      }
      final notes = state.debugNotes.toList()
        ..sort((a, b) => a.hitMs.compareTo(b.hitMs));
      final first = notes.first;
      state.advance(max(0, first.hitMs - state.debugNow));
      state.tryHit(first.lane);
      expect(state.debugCombo, 1);
      expect(state.debugScore, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
