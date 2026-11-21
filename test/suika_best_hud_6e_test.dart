// test/suika_best_hud_6e_test.dart — 6E: Suika sahte-rekor HUD düzeltmesi.
//
// Bulgu: taze profilde Suika HUD'ı SKOR 0 iken REKOR 4.820 gösteriyordu
// (ResultScoring.defaultBestScore yedeği). Düzeltme: game_screen.dart'taki
// 3 HUD noktasında da yedek kaldırıldı — gerçek en iyi skor yoksa REKOR 0.
// Kayıt yolu (recordLevelResult / recordModeScore / LeaderboardService)
// etkilenmez; yalnız görünen değer değişir.
//
// Kapsam: 3 HUD çeşidi (arcade / compact / geniş) + kayıtlı best > 0 durumu.
// REKOR değeri, etiketle aynı Column içindeki değer Text'inden okunur
// (SKOR kutusundaki '0' ile karışmaması için).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestFonts);

  setUp(() {
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
  });

  /// REKOR kutusunda görünen değer: etiket Text'inden yukarı çıkılıp
  /// en yakın ata Column bulunur, içindeki iki Text (etiket + değer)
  /// toplanır. SKOR kutusundaki değerle karışmaz — kapsam yalnız bu Column.
  String rekorDisplayedValue(WidgetTester tester) {
    expect(find.text('REKOR'), findsOneWidget);
    final labelElement = tester.element(find.text('REKOR'));
    Element? columnElement;
    labelElement.visitAncestorElements((ancestor) {
      if (ancestor.widget is Column) {
        columnElement = ancestor;
        return false; // en yakın ata Column bulundu, dur
      }
      return true;
    });
    expect(columnElement, isNotNull);
    final texts = <String>[];
    void collect(Element element) {
      final widget = element.widget;
      if (widget is Text && widget.data != null) {
        texts.add(widget.data!);
      }
      element.visitChildElements(collect);
    }

    columnElement!.visitChildElements(collect);
    expect(texts, hasLength(2), reason: 'REKOR kutusu: etiket + değer');
    expect(texts.first, 'REKOR');
    return texts.last;
  }

  Future<void> pumpSuika(
    WidgetTester tester, {
    required bool arcade,
    required double width,
    required double height,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Teardown flake tahliyesi (responsive_modes_n7_6d deseni): ilk kez
    // kullanılan bir font varyantı `fontsChange` bildirimi gönderir;
    // bildirim test gövdesinin son pump'ından sonra gelirse
    // `RelayoutWhenSystemFontsChangeMixin` callback'i `postTest`
    // denetimine takılır ("animation is still running"). addTearDown
    // `postTest`'ten ÖNCE çalışır; bekleyen frame callback'ini işletir.
    addTearDown(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
        await binding.pump();
      }
    });

    await pumpWithL10n(
      tester,
      GameScreen(level: CampaignDatabase.kitchenLevel1, arcade: arcade),
      debugShowCheckedModeBanner: false,
      theme: buildLululuTheme(),
    );
    // _loadBest async: taze profilde 0 zaten başlangıç değeridir;
    // kayıtlı best durumunda da yüklemenin bitmesi beklenir.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectFreshBestZero(WidgetTester tester) {
    expect(rekorDisplayedValue(tester), '0');
    expect(find.text('4820'), findsNothing);
    expect(find.text('4.820'), findsNothing);
  }

  group('6E taze profil: Suika HUD REKOR 0', () {
    testWidgets('arcade HUD: REKOR 0 (tohum 4.820 yok)', (tester) async {
      await pumpSuika(tester, arcade: true, width: 374, height: 680);
      expectFreshBestZero(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact HUD (dar ekran): REKOR 0', (tester) async {
      await pumpSuika(tester, arcade: false, width: 390, height: 844);
      expectFreshBestZero(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('geniş HUD: REKOR 0', (tester) async {
      await pumpSuika(tester, arcade: false, width: 500, height: 900);
      expectFreshBestZero(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('6E kayıtlı best > 0: gerçek değer görünür', () {
    testWidgets('arcade HUD: best 3000 -> "3.000"', (tester) async {
      expect(
        await ProgressManager.instance.recordModeScore('suika', 3000),
        isTrue,
      );
      await pumpSuika(tester, arcade: true, width: 374, height: 680);
      expect(rekorDisplayedValue(tester), '3.000');
      expect(find.text('4.820'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact HUD: best 4500 -> "4500"', (tester) async {
      // 4500: önceki test 3000 kaydetti (ProgressManager singleton);
      // recordModeScore eşit/küçük skorda false döner, o yüzden farklı
      // ve daha büyük bir değerle tohumlanır.
      expect(
        await ProgressManager.instance.recordModeScore('suika', 4500),
        isTrue,
      );
      await pumpSuika(tester, arcade: false, width: 390, height: 844);
      expect(rekorDisplayedValue(tester), '4500');
      expect(find.text('4.820'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
