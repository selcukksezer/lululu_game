import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/sticker_image.dart';

import 'test_helpers.dart';

/// terlik_play_test.dart ile aynı yazı tipi ön-yüklemesi: ön-yükleme
/// yoksa ilk metin çizimi sistem yazı tipi bildirimini tetikleyip
/// elden çıkarma sonrası "animation is still running" hatası verir.
Future<void> _loadCustomFonts() async {
  final fontMap = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Bold.ttf',
      'assets/fonts/Baloo2-ExtraBold.ttf',
      'assets/fonts/Baloo2-SemiBold.ttf',
      'assets/fonts/Baloo2-Medium.ttf',
    ],
    'Bangers': ['assets/fonts/Bangers-Regular.ttf'],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
      'assets/fonts/Nunito-SemiBold.ttf',
      'assets/fonts/Nunito-Black.ttf',
    ],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Bold.ttf',
      'assets/fonts/Exo2-ExtraBold.ttf',
      'assets/fonts/Exo2-SemiBold.ttf',
      'assets/fonts/Exo2-Black.ttf',
    ],
  };

  for (final entry in fontMap.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }

  for (final w in FontWeight.values) {
    GoogleFonts.baloo2(fontWeight: w);
    GoogleFonts.nunito(fontWeight: w);
    GoogleFonts.bangers(fontWeight: w);
    GoogleFonts.exo2(fontWeight: w);
  }
  await GoogleFonts.pendingFonts();
}

/// HUD'daki etiketli istatistiğin (SKOR / REKOR) değer metnini okur:
/// etiketin en yakın Column atasındaki Text'lerin sonuncusu değerdir
/// (terlik + makara `_stat` düzeni: etiket, boşluk, değer).
String _hudValue(WidgetTester tester, String label) {
  final labelElement = tester.element(find.text(label));
  Widget? statColumn;
  labelElement.visitAncestorElements((ancestor) {
    if (ancestor.widget is Column) {
      statColumn = ancestor.widget;
      return false;
    }
    return true;
  });
  final texts = tester.widgetList<Text>(
    find.descendant(
      of: find.byWidget(statColumn!),
      matching: find.byType(Text),
    ),
  );
  return texts.last.data!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
    await _loadCustomFonts();
  });

  setUp(() {
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
  });

  testWidgets('6H G32: rapid taps keep floating texts capped and banner clear',
      (tester) async {
    // 430×932 (spray testiyle aynı): 374×680'de ızgara arenaya sığmayıp
    // alt sıra hücre merkezleri dokunuş almıyor; bu testin konusu FX
    // kapağı olduğu için geniş görünüm kullanılır.
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpWithL10n(
      tester,
      const TerlikTapScreen(initialTargetForTesting: true),
      theme: buildLululuTheme(),
    );
    await tester.pump();

    // Önce gerçek bir vuruş: canlı hedefe basılır.
    final bugFinder = find.byType(StickerImage).first;
    expect(bugFinder, findsOneWidget);
    final hitHole = int.parse(
      (tester.widget<StickerImage>(bugFinder).key! as ValueKey<String>)
          .value
          .split('-')
          .last,
    );
    await tester.tap(bugFinder);
    await tester.pump();

    // Sonra 12 hızlı boş vuruş — her biri "KOMBO KIRILDI" FX'i iter.
    // Süre ilerletilmez (Timer.periodic sahte-zamanda durur), yani hiçbir
    // FX solup kaybolmaz: sayımdaki fark yalnız kapak (cap) etkisidir.
    var tapped = 0;
    for (var hole = 0; hole < 9 && tapped < 12; hole++) {
      if (hole == hitHole) continue;
      for (var rep = 0; rep < 2 && tapped < 12; rep++) {
        await tester.tap(find.byKey(ValueKey<String>('terlik-hole-$hole')));
        await tester.pump();
        tapped++;
      }
    }
    expect(tapped, 12);

    // Düzeltme öncesi: 12 FX üst üste. Düzeltme sonrası: en fazla 6.
    final fx = find.text('KOMBO KIRILDI');
    expect(fx, findsNWidgets(6));

    // Pankart görünür kalır ve hiçbir FX onunla çakışmaz.
    final banner = find.text('DELİKTEN ÇIKANI ANINDA EZ!');
    expect(banner, findsOneWidget);
    final bannerRect = tester.getRect(banner);
    for (final element in fx.evaluate()) {
      final fxRect = tester.getRect(find.byWidget(element.widget));
      expect(
        fxRect.overlaps(bannerRect),
        isFalse,
        reason: 'FX pankartı kapatıyor: $fxRect vs $bannerRect',
      );
    }
    expect(tester.takeException(), isNull);
    // terlik_play_test (spray) deseni: elden çıkarmadan önce bekleyen
    // kare geri çağrılarının / zamanlayıcıların canlı ağaçta akmasını
    // sağla — yoksa Flutter 3.50'de "Timer still pending" /
    // "animation still running" değişmezlik hatası verir.
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('6H G33: terlik REKOR HUD skorla birlikte canlı güncellenir',
      (tester) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpWithL10n(
      tester,
      const TerlikTapScreen(initialTargetForTesting: true),
      theme: buildLululuTheme(),
    );
    await tester.pump();

    // Taze turda REKOR 0'dır (kayıtlı rekor yok).
    expect(_hudValue(tester, 'SKOR'), '0');
    expect(_hudValue(tester, 'REKOR'), '0');

    final bugFinder = find.byType(StickerImage).first;
    await tester.tap(bugFinder);
    await tester.pump();

    // Düzeltme öncesi: SKOR artar ama REKOR 0 kalır (yalnız `_die`'de
    // eşitlenirdi). Düzeltme sonrası: REKOR, SKOR'a canlı eşitlenir.
    final score = _hudValue(tester, 'SKOR');
    expect(score, isNot('0'));
    expect(_hudValue(tester, 'REKOR'), score);
    expect(tester.takeException(), isNull);
    // terlik_play_test (spray) deseni: elden çıkarmadan önce bekleyen
    // kare geri çağrılarının / zamanlayıcıların canlı ağaçta akmasını
    // sağla — yoksa Flutter 3.50'de "Timer still pending" /
    // "animation still running" değişmezlik hatası verir.
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('6H G33: makara REKOR HUD skorla birlikte canlı güncellenir',
      (tester) async {
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
    expect(state.debugScore, 0);
    expect(state.debugBest, 0);
    expect(_hudValue(tester, 'SKOR'), '0');
    expect(_hudValue(tester, 'REKOR'), '0');

    // İlk notayı tam zamanında vur: skor 110 olur
    // (60 + kombo 10 + mükemmel 40).
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
    await tester.pump();

    // Düzeltme öncesi: skor 110 ama REKOR 0 kalır (yalnız `_gameOver`'da
    // eşitlenirdi). Düzeltme sonrası: REKOR, SKOR'a canlı eşitlenir.
    expect(state.debugScore, 110);
    expect(state.debugBest, 110);
    expect(_hudValue(tester, 'SKOR'), '110');
    expect(_hudValue(tester, 'REKOR'), '110');
    expect(tester.takeException(), isNull);
    // terlik_play_test (spray) deseni: elden çıkarmadan önce bekleyen
    // kare geri çağrılarının / zamanlayıcıların canlı ağaçta akmasını
    // sağla — yoksa Flutter 3.50'de "Timer still pending" /
    // "animation still running" değişmezlik hatası verir.
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
