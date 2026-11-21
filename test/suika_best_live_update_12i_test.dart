// test/suika_best_live_update_12i_test.dart — 12I: Suika rekoru canlı + açılışta.
//
// Bulgular (video + kod izi):
// 1. Birleşme yolunda `_bestScore` güncellenmiyordu — yalnız güçlendirme
//    yolları ve oyun-sonu gönderim güncelliyordu. Düzeltme: her skor
//    artışında (birleşme, Hışır, Aydınlat ilk ödül, Sprey) rekor da büyür
//    (2048 deseni; kalıcı yazım oyun sonunda aynen kalır).
// 2. Açılışta REKOR 0: tahta varsa `getBest` PM yedeğini okumaz; tahta
//    `bestScore`'u kimlik eşleşmesi kaçırırsa 0 döner. Düzeltme: `_loadBest`
//    PM haritasındaki kalıcı rekoru hızlı yoldan gösterir, liderlik
//    değişimlerini dinleyip tazeler.
// 3. Skorun üstüne yazılma şüphesi ÇÜRÜTÜLDÜ: `_score` yalnız `+=` ve
//    `= 0` ile yazılır (game_screen.dart grep ile doğrulandı).
//
// Test sırası önemlidir (singleton'lar dosya içinde yaşar): önce birleşme
// testi (küçük tohum rekor), sonra tahta/PM uyumsuzluğu, sonra dinleyici.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
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

  /// HUD kutusundaki değer: etiket Text'inden yukarı çıkılıp en yakın ata
  /// Column bulunur, içindeki ilk iki Text (etiket + değer) okunur.
  String hudBoxValue(WidgetTester tester, String label) {
    expect(find.text(label), findsOneWidget);
    final labelElement = tester.element(find.text(label));
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
    expect(
      texts.length,
      greaterThanOrEqualTo(2),
      reason: '$label kutusu: etiket + değer',
    );
    expect(texts.first, label);
    return texts[1];
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
    // Teardown flake tahliyesi (suika_best_hud_6e deseni).
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
    // _loadBest async yüklemeleri bitsin.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'birleşmede skor rekoru geçince REKOR canlı güncellenir',
    (tester) async {
    // Tohum rekor 1: herhangi bir birleşme puanı rekoru geçer.
    expect(
      await ProgressManager.instance.recordModeScore('suika', 1),
      isTrue,
    );
    await pumpSuika(tester, arcade: true, width: 374, height: 680);
    expect(hudBoxValue(tester, 'REKOR'), '1');
    expect(hudBoxValue(tester, 'SKOR'), '0');

    // Aynı x'e 16 düşürme: aynı kademe böcekler üst üste binip birleşir.
    for (var drop = 0; drop < 16; drop++) {
      await tester.tapAt(const Offset(187, 250));
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    // Son birleşmeler yerleşsin.
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final skor = hudBoxValue(tester, 'SKOR');
    final rekor = hudBoxValue(tester, 'REKOR');
    expect(skor, isNot('0'), reason: 'birleşme skoru oluşmadı');
    expect(
      rekor,
      skor,
      reason: 'rekor birleşmede skorla birlikte canlı büyümeli',
    );
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets(
    'tahta bestScore 0 iken PM rekoru açılışta hemen görünür',
    (tester) async {
      // Tahta: suika kaydı BAŞKA bir oyuncu kimliğinde (9859 puan) —
      // yeniden bağlama o anki `guest_local` kimliğiyle eşleşmez,
      // tahta bestScore 0 olur; PM haritasında ise 9859 kalıcıdır.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'LululuLeaderboardV3': jsonEncode(<String, Object>{
          'modes': <Object>[
            <String, Object>{
              'modeId': 'suika',
              'bestScore': 9859,
              'top': <Object>[
                <String, Object>{
                  'modeId': 'suika',
                  'playerId': 'anon-uid-xyz',
                  'playerName': 'Misafir',
                  'score': 9859,
                  'utcTicks': 1700000000000,
                  'isLocalPlayer': false,
                  'country': 'TR',
                },
              ],
            },
          ],
        }),
      });
      // Singleton tahtayı kalıcı hâlden zorla yeniden oku (önceki test
      // `ensureLoaded` kapısını zaten açtı).
      await LeaderboardService.instance.load();
      expect(
        LeaderboardService.instance.getBest(
          LeaderboardService.modeSuika,
        ),
        0,
        reason: 'kurulum: kimlik eşleşmezken tahta bestScore 0 olmalı',
      );
      expect(
        await ProgressManager.instance.recordModeScore('suika', 9859),
        isTrue,
      );

      await pumpSuika(tester, arcade: true, width: 374, height: 680);
      expect(hudBoxValue(tester, 'REKOR'), '9.859');
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets('liderlik bildirimi sonrası rekor tazelenir', (tester) async {
    await pumpSuika(tester, arcade: true, width: 374, height: 680);
    expect(hudBoxValue(tester, 'REKOR'), '9.859');

    // PM rekoru büyür ama ekran PM'i dinlemez; liderlik servisi
    // bildirince ekran iki kaynaktaki büyük değeri okuyup tazeler.
    expect(
      await ProgressManager.instance.recordModeScore('suika', 12000),
      isTrue,
    );
    LeaderboardService.instance.notifyListeners();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(hudBoxValue(tester, 'REKOR'), '12.000');
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
