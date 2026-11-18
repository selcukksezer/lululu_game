import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/hb_overlay.dart';

// W57-1: `HbOverlay` çıkarma kilidi (W55-2).
//
// `HbOverlay` (`#hbOverlay`, kalp kırılma animasyonu + `-1 ENERJİ` etiketi)
// `lib/widgets/daily_reward_dialog.dart` dosyasından
// `lib/widgets/hb_overlay.dart` dosyasına taşındı; hub
// (`lib/screens/game_selector_screen.dart`) yeni dosyayı import ediyor ve
// `_launchMode` içinde `HbOverlay.play(context)` çağırıyor. Ölü günlük
// ödül diyaloğu fonksiyonu silindi.
//
// Bu dosya taşımayı üç düzeyde kilitler:
// 1. Widget düzeyi: `HbOverlay` pump edilir; etiket, iki yarım kalp
//    görseli ve parametre yansıması doğrulanır.
// 2. API düzeyi: `HbOverlay.play` imzası (adlandırılmış `tagText` /
//    `duration`) ve kurucu varsayılanları kilitlenir. Ölü sembole bu
//    dosyada hiç değinilmez; derleme, adın hiçbir yerde çözülmediğini
//    zaten kanıtlar.
// 3. Hub bağlantısı: bu dosya hub dosyasını import eder; hub'ın
//    `hb_overlay.dart` importu kaldırılır/bozulursa hub derlenemez ve bu
//    test dosyası da derlenemez. Hub ayrıca pump edilip temiz render
//    olduğu doğrulanır.
//
// HUB PUMP SINIRI (gerekçe): `HbOverlay` hub'ın build ağacında statik
// olarak hiç bulunmaz — yalnız `_launchMode` içindeki `HbOverlay.play`
// çağrısıyla `OverlayEntry` olarak eklenir; `play` ise test bağlamında
// (`WidgetsBinding` tipi `Test` içeriyorsa) erken döner. Bu yüzden hub
// pump'ında `find.byType(HbOverlay)` aramak, bağlantı doğru olsa bile
// her zaman boş döner; hub testi bu yüzden varlık iddiası taşımaz,
// yalnız derleme + temiz render kilididir. `HbOverlay` davranışı
// widget-düzeyi testlerde kilitlenir.
//
// DOSYA OKUMA YOK: hiçbir test kaynak dosya okumaz; tüm kilitler
// derleme + pump düzeyindedir.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pumpOverlay(
    WidgetTester tester, {
    bool visible = false,
    String tagText = '-1 ENERJİ',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HbOverlay(visible: visible, tagText: tagText),
      ),
    );
    await tester.pump();
  }

  group('HbOverlay render (widget düzeyi)', () {
    testWidgets('visible=true: varsayılan etiket + iki yarım kalp çizer',
        (tester) async {
      await pumpOverlay(tester, visible: true);

      final overlayFinder = find.byType(HbOverlay);
      expect(overlayFinder, findsOneWidget);
      expect(find.text('-1 ENERJİ'), findsOneWidget);

      // İki yarım kalp: aynı kalp görselinin iki ClipRect'li yarısı.
      final images = tester
          .widgetList<Image>(
            find.descendant(
              of: overlayFinder,
              matching: find.byType(Image),
            ),
          )
          .toList();
      expect(images.length, 2);
      for (final image in images) {
        expect(image.image, isA<AssetImage>());
        expect(
          (image.image as AssetImage).assetName,
          'assets/design/ui/icon_heart_exact.png',
        );
        expect(image.width, 132);
        expect(image.height, 132);
      }
      expect(
        find.descendant(
          of: overlayFinder,
          matching: find.byType(ClipRect),
        ),
        findsNWidgets(2),
      );

      // Dokunmaları geçirir: etiketin atası IgnorePointer'dır.
      expect(
        find.ancestor(
          of: find.text('-1 ENERJİ'),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );

      // Koyu bordo kaplama rengi.
      expect(
        find.descendant(
          of: overlayFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.color == const Color(0x597A082E),
          ),
        ),
        findsOneWidget,
      );

      // Etiket tipografisi.
      final tag = tester.widget<Text>(find.text('-1 ENERJİ'));
      expect(tag.style?.fontSize, 32);
      expect(tag.style?.fontWeight, FontWeight.w800);
      expect(tag.style?.color, Colors.white);
      expect(tag.style?.letterSpacing, 1.2);

      expect(tester.takeException(), isNull);
    });

    testWidgets('visible=false (varsayılan): hiçbir şey çizmez',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: HbOverlay()),
      );
      await tester.pump();

      final overlayFinder = find.byType(HbOverlay);
      expect(overlayFinder, findsOneWidget);
      final overlay = tester.widget<HbOverlay>(overlayFinder);
      expect(overlay.visible, isFalse);
      expect(overlay.tagText, '-1 ENERJİ');
      expect(find.text('-1 ENERJİ'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('özel tagText görüntüye yansır, varsayılan görünmez',
        (tester) async {
      await pumpOverlay(tester, visible: true, tagText: '-2 ENERJİ');
      expect(find.text('-2 ENERJİ'), findsOneWidget);
      expect(find.text('-1 ENERJİ'), findsNothing);
      final overlay = tester.widget<HbOverlay>(find.byType(HbOverlay));
      expect(overlay.tagText, '-2 ENERJİ');
      expect(overlay.visible, isTrue);
    });

    testWidgets('visible değişimi etiketi gösterip gizler', (tester) async {
      await pumpOverlay(tester, visible: false);
      expect(find.text('-1 ENERJİ'), findsNothing);

      await pumpOverlay(tester, visible: true);
      expect(find.text('-1 ENERJİ'), findsOneWidget);

      await pumpOverlay(tester, visible: false);
      expect(find.text('-1 ENERJİ'), findsNothing);
    });
  });

  group('HbOverlay.play API kilidi', () {
    testWidgets(
        'play test ortamında erken döner, overlay eklemez, hata vermez',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      // Varsayılan argümanlar + adlandırılmış tagText/duration: imza kilidi.
      await HbOverlay.play(captured);
      await HbOverlay.play(
        captured,
        tagText: '-3 ENERJİ',
        duration: const Duration(milliseconds: 10),
      );
      await tester.pump();

      // Test koruması: play erken döner, ağaca OverlayEntry eklenmez.
      expect(find.byType(HbOverlay), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('HbOverlay kurucu varsayılanları (derleme kilidi)', () {
    test('const kurucu varsayılanları ve StatelessWidget türü kilitli', () {
      const overlay = HbOverlay();
      expect(overlay, isA<StatelessWidget>());
      expect(overlay.visible, isFalse);
      expect(overlay.tagText, '-1 ENERJİ');

      const custom = HbOverlay(visible: true, tagText: 'X');
      expect(custom.visible, isTrue);
      expect(custom.tagText, 'X');
    });
  });

  group('hub bağlantısı (W55-2 çıkarma kilidi)', () {
    testWidgets('hub yeni hb_overlay importuyla temiz render olur',
        (tester) async {
      // Kurulum: test/hub_catalog_test.dart deseninin aynısı.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLululuTheme(),
          home: const Scaffold(body: GameSelectorScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(GameSelectorScreen), findsOneWidget);

      // flutter_animate zamanlayıcı bırakır — ağacı sök, bağlam temiz kalsın.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
