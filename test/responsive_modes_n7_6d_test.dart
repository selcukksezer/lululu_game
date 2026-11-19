import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_en.dart';
import 'package:lululu_game/l10n/app_tr.dart';
import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/modes/yuva_defense_screen.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/arcade_chrome.dart';
import 'package:lululu_game/widgets/sticker_image.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

// 6D — Faz 3 telefon uyumu (A7/A7b mod bulguları) + N7 oyun-içi çıkış onayı.
//
// BÖLÜM 1 (düzen): F-06/F-10 (connect başlığı), F-07(a)/F-08 (stack
// başlığı), F-07(b) BİTİR koruma testi (piksel ölçümüyle çürütüldü:
// düğme 360 px'te 304→352 aralığında ekran içinde; bu test o durumu
// kilitler), F-11 (yuva/çığlık 430 başlık kelime düşürme), F-12
// (makara 360 başlığı), F-05 (balon ipucu şeridi — statik ellipsis,
// kayan yazı değil).
//
// BÖLÜM 2 (N7): 11 modda hamleli + enerjili turda geri/çıkış onay
// diyaloğu gösterir (vazgeç → kalır, onayla → çıkar, iade yok);
// hamlesiz çıkış anındadır ve 1 enerji iade edilir (S6 aynen).
// `tester.pageBack()` bu SDK'da Cupertino geri düğmesi bulamadığı
// için (baz: 6 önceden-var hata) çıkış üretimdeki gibi
// `Navigator.maybePop` ile tetiklenir (global_notify_test deseni).
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
    // Teardown flake tahliyesi: ilk kez kullanılan bir font varyantı
    // `fontsChange` bildirimi gönderir; bildirim test gövdesinin son
    // pump'ından sonra gelirse `RelayoutWhenSystemFontsChangeMixin`
    // callback'i `postTest` değişmez denetimine takılır ("animation is
    // still running" — bazda suika iade testindeki flake ile aynı
    // yığın). `addTearDown` gövde içinden kaydedildiği için
    // `postTest`'ten ÖNCE çalışır (widget_tester.dart'ta postTest
    // gövde başında kaydedilir, tearDown'lar LIFO çalışır); ağaç
    // `_postTestMessage` ile değiştirilmişken bekleyen frame
    // callback'ini işletir. Callback detached-güvenlidir (attached
    // değilse no-op).
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

  /// Font-change transient callback'lerini tahliye eder: ilk kez
  /// kullanılan bir font ailesi/ağırlığı `fontsChange` bildirimi
  /// gönderir; bildirim son pump'tan sonra gelirse teardown'da
  /// "animation is still running" hatası verir (bazda suika
  /// iade testinde görülen flake ile aynı yığın). Sınırlı kare
  /// pompalayarak bekleyen frame callback'lerinin çalışmasına
  /// fırsat verir; oyun döngüsü süren modlarda bile sonludur.
  Future<void> flushFontCallbacks(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  bool exceedsMaxLines(WidgetTester tester, Finder finder) {
    final ro = tester.renderObject<RenderParagraph>(finder);
    return ro.didExceedMaxLines;
  }

  /// Başlık metninin FittedBox ölçeği: boyalı genişlik / doğal genişlik.
  /// 1.0 = tam boy; 0.6 altı okunamaz kabul edilir.
  double titleScale(
    WidgetTester tester,
    Finder f,
    String text,
    double fontSize,
  ) {
    final style = GoogleFonts.baloo2(
      fontSize: fontSize,
      height: 1.05,
      letterSpacing: 0.2,
      fontWeight: FontWeight.w800,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return tester.getRect(f).width / tp.size.width;
  }

  Future<void> pumpArcade(
    WidgetTester tester, {
    required String title,
    String? tag,
  }) async {
    await pumpWithL10n(
      tester,
      ArcadeScreen(
        title: title,
        hint: 'kural metni',
        score: 0,
        best: 0,
        tag: tag,
        statLabel: 'KAT',
        statValue: '12',
        onRestart: () {},
        onPausePressed: () {},
        child: const SizedBox.expand(),
      ),
      debugShowCheckedModeBanner: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('BÖLÜM 1 — mod başlıkları ve BİTİR (A7/A7b)', () {
    testWidgets('font ısınması: ilk pump Baloo 2 metrikleriyle yerleşir', (
      tester,
    ) async {
      setViewport(tester, 430, 932);
      await pumpArcade(tester, title: 'Stack Drop', tag: 'KULE');
      expect(find.text('STACK DROP'), findsOneWidget);
    });

    for (final vp in [(360.0, 640.0), (390.0, 844.0), (430.0, 932.0)]) {
      testWidgets('F-06/F-10 connect başlığı tam: ${vp.$1}x${vp.$2}', (
        tester,
      ) async {
        setViewport(tester, vp.$1, vp.$2);
        await pumpArcade(tester, title: 'Bağla Patlat', tag: 'ZİNCİR');
        final f = find.text('BAĞLA PATLAT');
        expect(f, findsOneWidget);
        expect(exceedsMaxLines(tester, f), isFalse);
        final rect = tester.getRect(f);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(vp.$1));
        // 7A: 390 px'te ölçek 0.499, etkin boyut ~10.0px idi (20 px taban
        // + en uzun başlık; coin 12.450 ile). Düzeltme: başlık çipi iç
        // boşluğu 10→6 + coin hapı daraltması (simge 25→20) başlığa
        // ~17px kazandırdı — ölçek 0.626, etkin boyut 12.51px.
        // Eşik: ölçek ≥0.6 (okunabilirlik tabanı) VE etkin boyut ≥12px.
        // Taban yazı boyutu düşürülmedi: ölçeği şişirir ama etkin
        // boyutu değiştirmez, okunabilirliğe katkısı yoktur.
        final scale = titleScale(
          tester,
          f,
          'BAĞLA PATLAT',
          vp.$1 < 372 ? 16 : 20,
        );
        expect(scale, greaterThanOrEqualTo(0.6));
        expect(
          scale * (vp.$1 < 372 ? 16 : 20),
          greaterThanOrEqualTo(12),
          reason: 'connect başlığı etkin boyutu <12px @${vp.$1}',
        );
        await flushFontCallbacks(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('F-07(a)/F-08 stack başlığı tam: ${vp.$1}x${vp.$2}', (
        tester,
      ) async {
        setViewport(tester, vp.$1, vp.$2);
        await pumpArcade(tester, title: 'Stack Drop', tag: 'KULE');
        final f = find.text('STACK DROP');
        expect(f, findsOneWidget);
        expect(exceedsMaxLines(tester, f), isFalse);
        final rect = tester.getRect(f);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(vp.$1));
        expect(
          titleScale(tester, f, 'STACK DROP', vp.$1 < 372 ? 16 : 20),
          greaterThanOrEqualTo(0.6),
        );
        await flushFontCallbacks(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('F-07(b) BİTİR ekran içinde, >=44px: ${vp.$1}x${vp.$2}', (
        tester,
      ) async {
        setViewport(tester, vp.$1, vp.$2);
        await pumpArcade(tester, title: 'Stack Drop', tag: 'KULE');
        final sem = find.bySemanticsLabel('Bitir');
        expect(sem, findsOneWidget);
        final rect = tester.getRect(sem);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(vp.$1));
        expect(rect.width, greaterThanOrEqualTo(44));
        expect(rect.height, greaterThanOrEqualTo(44));
        await flushFontCallbacks(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('F-11 yuva başlığı 430da tam (kelime düşürme yok)', (
      tester,
    ) async {
      setViewport(tester, 430, 932);
      await pumpWithL10n(
        tester,
        const YuvaDefenseScreen(),
        debugShowCheckedModeBanner: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // İki eşleşme var: biri 0 boyutlu görünmez erişilebilirlik metni,
      // diğeri başlık. Görünür olanı sonuncusudur.
      final all = find.text('YUVA SAVUNMASI');
      expect(all, findsNWidgets(2));
      final f = all.last;
      expect(tester.getRect(f).width, greaterThan(0));
      expect(exceedsMaxLines(tester, f), isFalse);
      expect(tester.widget<Text>(f).softWrap, isFalse);
      final rect = tester.getRect(f);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(430));
      await flushFontCallbacks(tester);
    });

    testWidgets('F-11 çığlık başlığı 430da tam (kelime düşürme yok)', (
      tester,
    ) async {
      setViewport(tester, 430, 932);
      await pumpWithL10n(
        tester,
        const ScreamRoachScreen(),
        debugShowCheckedModeBanner: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final f = find.text('ÇIĞLIK BÖCEK');
      expect(f, findsOneWidget);
      expect(exceedsMaxLines(tester, f), isFalse);
      expect(tester.widget<Text>(f).softWrap, isFalse);
      final rect = tester.getRect(f);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(430));
      await flushFontCallbacks(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('F-11 çığlık başlığı 360ta tam (ArcadeScreen dalı)', (
      tester,
    ) async {
      setViewport(tester, 360, 640);
      await pumpWithL10n(
        tester,
        const ScreamRoachScreen(),
        debugShowCheckedModeBanner: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final f = find.text('ÇIĞLIK BÖCEK');
      expect(f, findsOneWidget);
      expect(exceedsMaxLines(tester, f), isFalse);
      await flushFontCallbacks(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('F-12 makara başlığı 360ta tam', (tester) async {
      setViewport(tester, 360, 640);
      await pumpWithL10n(
        tester,
        const MakarayizScreen(),
        debugShowCheckedModeBanner: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final f = find.text('MAKARAYIZ');
      expect(f, findsOneWidget);
      expect(exceedsMaxLines(tester, f), isFalse);
      expect(tester.widget<Text>(f).softWrap, isFalse);
      final rect = tester.getRect(f);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      await flushFontCallbacks(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('F-12 makara başlığı 430ta tam (geniş dal)', (tester) async {
      setViewport(tester, 430, 932);
      await pumpWithL10n(
        tester,
        const MakarayizScreen(),
        debugShowCheckedModeBanner: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final f = find.text('MAKARAYIZ');
      expect(f, findsOneWidget);
      expect(exceedsMaxLines(tester, f), isFalse);
      await flushFontCallbacks(tester);
      expect(tester.takeException(), isNull);
    });

    for (final vp in [(360.0, 640.0), (390.0, 844.0)]) {
      testWidgets('F-05 balon ipucu şeridi tam: ${vp.$1}x${vp.$2}', (
        tester,
      ) async {
        setViewport(tester, vp.$1, vp.$2);
        await pumpWithL10n(
          tester,
          const BalloonPopScreen(),
          debugShowCheckedModeBanner: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final f = find.textContaining('süzülüyor');
        expect(f, findsOneWidget);
        expect(exceedsMaxLines(tester, f), isFalse);
        expect(tester.widget<Text>(f).data, contains('8 atışta sıra iner'));
        final rect = tester.getRect(f);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(vp.$1));
        await flushFontCallbacks(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ---- N7 yardımcıları ----

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
              child: const Text('OPEN_MODE_6D'),
            ),
          ),
        ),
      ),
      theme: buildLululuTheme(),
      debugShowCheckedModeBanner: false,
    );
    await tester.tap(find.text('OPEN_MODE_6D'));
    await tester.pump();
    await pumpFrames(tester, 100);
  }

  Finder dialogTitle() => find.text('Turdan çıkılsın mı?');
  Finder dialogBody() =>
      find.text('Çıkarsan bu tur ve harcanan enerji kaybolur.');
  Finder dialogCancel() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.text('İptal'),
  );
  Finder dialogConfirm() =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Çık'));

  Future<void> requestPop(WidgetTester tester, Finder modeFinder) async {
    Navigator.of(tester.element(modeFinder)).maybePop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapDialogButton(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> expectHomeAfterPop(WidgetTester tester) async {
    await pumpFrames(tester, 300);
    expect(find.text('OPEN_MODE_6D'), findsOneWidget);
    expect(dialogTitle(), findsNothing);
  }

  void expectNoUnexpectedError(WidgetTester tester) {
    expect(tester.takeException(), isNull);
  }

  /// Terlik'te bilinen önceden-var 91 px taşma hariç hata yok
  /// (pause_behavior_test ile aynı dar tolerans).
  void expectNoErrorExceptTerlikOverflow(WidgetTester tester) {
    final error = tester.takeException();
    expect(
      error == null || error.toString().contains('overflowed by 91 pixels'),
      isTrue,
      reason: 'Beklenmeyen hata: $error',
    );
  }

  group('BÖLÜM 2 — N7 çıkış onayı (hamleli tur)', () {
    testWidgets('balon: diyalog + vazgeç kalır + onayla çıkar, iade yok', (
      tester,
    ) async {
      await openMode(tester, const BalloonPopScreen(energyConsumed: true));
      final mode = find.byType(BalloonPopScreen);
      expect(mode, findsOneWidget);
      // Hamle: 2 atış (balloon_play_test deseni).
      for (var i = 0; i < 2; i++) {
        await tester.tapAt(Offset(100.0 + i * 40, 300));
        await pumpFrames(tester, 960);
      }
      // SÜRE ilerlediğini gör, sonra diyalog açıkken donduğunu doğrula.
      await pumpFrames(tester, 1000);
      final timeBefore = tester
          .widgetList<Text>(find.textContaining(RegExp(r'^\d:\d\d$')))
          .first
          .data!;
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      expect(dialogBody(), findsOneWidget);
      // Balonda iki DURAKLATILDI metni var (11 px durum + 24 px kaplama).
      expect(find.text('DURAKLATILDI'), findsWidgets);
      await pumpFrames(tester, 2000);
      expect(
        find.text(timeBefore),
        findsOneWidget,
        reason: 'Diyalog açıkken oyun saati donmalı',
      );
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      expect(find.text('DURAKLATILDI'), findsNothing);
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('connect: diyalog + vazgeç kalır + onayla çıkar, iade yok', (
      tester,
    ) async {
      await openMode(
        tester,
        const ConnectPopScreen(gameplayTestState: true, energyConsumed: true),
      );
      final mode = find.byType(ConnectPopScreen);
      expect(mode, findsOneWidget);
      // Hamle: bagla_play_test ile aynı deterministik zincir.
      final board = tester.getRect(
        find.byKey(const ValueKey('connect-pop-board')),
      );
      const gap = 5.0;
      final cell = (board.width - gap * 5) / 6;
      final stride = cell + gap;
      Offset centerOf(int row, int column) => Offset(
        board.left + column * stride + cell / 2,
        board.top + row * stride + cell / 2,
      );
      final gesture = await tester.startGesture(centerOf(1, 1));
      var previous = centerOf(1, 1);
      for (final point in const [(1, 2), (2, 2), (2, 3), (3, 3)]) {
        final next = centerOf(point.$1, point.$2);
        await gesture.moveTo(Offset.lerp(previous, next, 0.5)!);
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.moveTo(next);
        await tester.pump(const Duration(milliseconds: 16));
        previous = next;
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 150));
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      expect(find.text('DURAKLATILDI'), findsNothing);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('match3: diyalog + vazgeç kalır + onayla çıkar, iade yok', (
      tester,
    ) async {
      await openMode(tester, const Match3Screen(energyConsumed: true));
      final mode = find.byType(Match3Screen);
      expect(mode, findsOneWidget);
      // Hamle: match3_play_test deseni (takas denemesi hamledir).
      for (var i = 0; i < 3; i++) {
        final y = 230.0 + (i % 6) * 34;
        await tester.dragFrom(
          Offset(70.0 + (i % 5) * 34, y),
          const Offset(34, 0),
        );
        await pumpFrames(tester, 320);
      }
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('makara: diyalog + vazgeç kalır + onayla çıkar, iade yok', (
      tester,
    ) async {
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
      // Hamle: makara_play_test deseni (durum API'si ile nota vuruşu).
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
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('osmantus: diyalog + vazgeç kalır + onayla çıkar, iade yok', (
      tester,
    ) async {
      await openMode(tester, const OsmantusScreen(energyConsumed: true));
      final mode = find.byType(OsmantusScreen);
      expect(mode, findsOneWidget);
      // Hamle: osmantus_play_test deseni (sahne merkezine dokunuş).
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
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });
  });

  group('BÖLÜM 2 — N7 çıkış onayı (hamleli tur, devam)', () {
    testWidgets('çığlık dar: diyalog + vazgeç kalır + onayla çıkar', (
      tester,
    ) async {
      await openMode(tester, const ScreamRoachScreen(energyConsumed: true));
      final mode = find.byType(ScreamRoachScreen);
      expect(mode, findsOneWidget);
      // Hamle: ciglik_play_test deseni (dokunuşla zıplama).
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(const Offset(190, 390));
        await tester.pump(const Duration(milliseconds: 120));
      }
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('çığlık geniş (430): ikinci PopScope dalında da diyalog', (
      tester,
    ) async {
      await openMode(
        tester,
        const ScreamRoachScreen(energyConsumed: true),
        w: 430,
        h: 932,
      );
      final mode = find.byType(ScreamRoachScreen);
      expect(mode, findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tapAt(const Offset(215, 500));
        await tester.pump(const Duration(milliseconds: 120));
      }
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('stack: diyalog + vazgeç kalır + onayla çıkar, iade yok', (
      tester,
    ) async {
      await openMode(tester, const StackDropScreen(energyConsumed: true));
      final mode = find.byType(StackDropScreen);
      expect(mode, findsOneWidget);
      // Hamle: other_modes_energy_refund_test deseni (dilim bırakma).
      await tester.tapAt(const Offset(187, 350));
      await pumpFrames(tester, 500);
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      expect(find.text('DURAKLATILDI'), findsNothing);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('terlik: diyalog açıkken böcek donar, vazgeç/onayla', (
      tester,
    ) async {
      await openMode(
        tester,
        const TerlikTapScreen(
          energyConsumed: true,
          initialTargetForTesting: true,
        ),
      );
      final mode = find.byType(TerlikTapScreen);
      expect(mode, findsOneWidget);
      // Hamle: terlik_energy_refund_test deseni (gerçek vuruş).
      final bugFinder = find.byType(StickerImage).first;
      expect(bugFinder, findsOneWidget);
      await tester.tap(bugFinder);
      await tester.pump();
      expect(find.textContaining('VURUŞ 1'), findsOneWidget);
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      // Böcek ömrünün (1.8 sn) çok üstünde süre: diyalog açıkken ıska yok.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('KAÇAN 0!'), findsOneWidget);
      expect(find.textContaining('KAÇTI'), findsNothing);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoErrorExceptTerlikOverflow(tester);
    });

    testWidgets('yuva: diyalog + vazgeç kalır + onayla çıkar, iade yok', (
      tester,
    ) async {
      await openMode(tester, const YuvaDefenseScreen(energyConsumed: true));
      final mode = find.byType(YuvaDefenseScreen);
      expect(mode, findsOneWidget);
      // Hamle: arena dokunuşu (`_tapArena` hamle sayar).
      await pumpFrames(tester, 500);
      await tester.tapAt(const Offset(187, 340));
      await tester.pump();
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
    });

    testWidgets('2048: diyalog + vazgeç kalır + onayla çıkar, iade yok', (
      tester,
    ) async {
      await openMode(
        tester,
        const Grid2048Screen(energyConsumed: true),
        w: 430,
        h: 932,
      );
      final mode = find.byType(Grid2048Screen);
      expect(mode, findsOneWidget);
      // Hamle: all_modes_play_test deseni (kaydırma).
      await tester.dragFrom(const Offset(215, 420), const Offset(-140, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      expect(find.text('OYUN DURAKLATILDI'), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      expect(find.text('OYUN DURAKLATILDI'), findsNothing);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('2048: ekrandaki Geri düğmesi de onaydan geçer', (
      tester,
    ) async {
      await openMode(
        tester,
        const Grid2048Screen(energyConsumed: true),
        w: 430,
        h: 932,
      );
      final mode = find.byType(Grid2048Screen);
      expect(mode, findsOneWidget);
      await tester.dragFrom(const Offset(215, 420), const Offset(-140, 0));
      await tester.pump(const Duration(milliseconds: 50));
      // `_handleBack` (maybePop) yolu: `pop()` vetoyu atlardı.
      await tester.tap(find.bySemanticsLabel('Geri'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(dialogTitle(), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(mode, findsOneWidget);
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('suika: diyalog + vazgeç kalır + onayla çıkar, iade yok', (
      tester,
    ) async {
      await openMode(
        tester,
        GameScreen(
          level: CampaignDatabase.kitchenLevel1,
          arcade: true,
          energyConsumed: true,
        ),
      );
      final mode = find.byType(GameScreen);
      expect(mode, findsOneWidget);
      // Hamle: energy_refund_test deseni (iki düşürme).
      await tester.tapAt(const Offset(120, 250));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(250, 250));
      await tester.pump(const Duration(milliseconds: 400));
      await requestPop(tester, mode);
      expect(dialogTitle(), findsOneWidget);
      expect(find.text('OYUN DURAKLATILDI'), findsOneWidget);
      await tapDialogButton(tester, dialogCancel());
      expect(dialogTitle(), findsNothing);
      expect(mode, findsOneWidget);
      await requestPop(tester, mode);
      await tapDialogButton(tester, dialogConfirm());
      await expectHomeAfterPop(tester);
      expect(EnergyService.instance.energy, 3);
      await flushFontCallbacks(tester);
    });
  });

  group('BÖLÜM 2 — N7 hamlesiz çıkış (anında + iade)', () {
    Future<void> expectInstantExitWithRefund(
      WidgetTester tester,
      Widget modeWidget,
      Finder modeFinder, {
      double w = 374,
      double h = 680,
    }) async {
      await openMode(tester, modeWidget, w: w, h: h);
      expect(modeFinder, findsOneWidget);
      expect(EnergyService.instance.energy, 3);
      await requestPop(tester, modeFinder);
      expect(dialogTitle(), findsNothing);
      expect(find.text('OPEN_MODE_6D'), findsOneWidget);
      expect(EnergyService.instance.energy, 4);
      await flushFontCallbacks(tester);
    }

    testWidgets('balon hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const BalloonPopScreen(energyConsumed: true),
        find.byType(BalloonPopScreen),
      );
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('connect hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const ConnectPopScreen(gameplayTestState: true, energyConsumed: true),
        find.byType(ConnectPopScreen),
      );
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('match3 hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const Match3Screen(energyConsumed: true),
        find.byType(Match3Screen),
      );
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('makara hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const TickerMode(
          enabled: false,
          child: MakarayizScreen(energyConsumed: true),
        ),
        find.byType(MakarayizScreen),
      );
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('osmantus hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const OsmantusScreen(energyConsumed: true),
        find.byType(OsmantusScreen),
      );
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('çığlık hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const ScreamRoachScreen(energyConsumed: true),
        find.byType(ScreamRoachScreen),
      );
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('stack hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const StackDropScreen(energyConsumed: true),
        find.byType(StackDropScreen),
      );
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('terlik hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const TerlikTapScreen(energyConsumed: true),
        find.byType(TerlikTapScreen),
      );
      await flushFontCallbacks(tester);
      expectNoErrorExceptTerlikOverflow(tester);
    });

    testWidgets('yuva hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const YuvaDefenseScreen(energyConsumed: true),
        find.byType(YuvaDefenseScreen),
      );
    });

    testWidgets('2048 hamlesiz: anında çık + iade', (tester) async {
      await expectInstantExitWithRefund(
        tester,
        const Grid2048Screen(energyConsumed: true),
        find.byType(Grid2048Screen),
        w: 430,
        h: 932,
      );
      await flushFontCallbacks(tester);
      expectNoUnexpectedError(tester);
    });

    testWidgets('suika hamlesiz: anında çık + iade (dispose yolu)', (
      tester,
    ) async {
      await expectInstantExitWithRefund(
        tester,
        GameScreen(
          level: CampaignDatabase.kitchenLevel1,
          arcade: true,
          energyConsumed: true,
        ),
        find.byType(GameScreen),
      );
    });
  });

  test('N7 l10n: yeni anahtarların TR/EN karşılıkları', () {
    final tr = AppLocalizationsTr();
    final en = AppLocalizationsEn();
    expect(tr.exitRoundConfirmTitle, 'Turdan çıkılsın mı?');
    expect(
      tr.exitRoundConfirmBody,
      'Çıkarsan bu tur ve harcanan enerji kaybolur.',
    );
    expect(en.exitRoundConfirmTitle, 'Leave this round?');
    expect(
      en.exitRoundConfirmBody,
      'If you leave, this round and the spent energy will be lost.',
    );
  });
}
