import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';

import 'test_helpers.dart';

/// 12P-makara: video kanıtlı donma + erken bitiş + giriş regresyonları.
///
/// Video zaman çizelgesi (16 sn): ~8. sn'de 2. can gider, ~9. sn'de
/// isabet (+110, x1), ~10. sn'de 3. can gider ve ekran DONAR
/// (notalar, skor, "KAÇIRDIN" takılı kalır); ~14. sn'de Selçuk
/// BİTİR'e basınca "SEVİYE TAMAM!" açılır. Kök neden: canlar
/// `advance()` içindeki kaçan-nota yolunda bitince `_gameOver`
/// çalışır ama sonuç yalnız dış `build()` içindeki
/// `_edgeShowResult` kenarından açılır; `advance()` yalnız
/// `_tickNotifier` bildirir, dış `build()` çalışmaz — sonuç ekranı
/// hiç açılmaz, `_alive == false` olduğu için `_onTick` erken döner
/// ve oyun sonsuza dek donar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GlobalKey<MakarayizScreenState>> pumpMakara(
    WidgetTester tester,
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
    return key;
  }

  testWidgets('12P-1: advance yolunda canlar bitince sonuc ekrani kendiliginden acilir',
      (tester) async {
    final key = await pumpMakara(tester);
    final state = key.currentState!;
    expect(state.debugLives, 3);

    // Hic vurmadan ilerle: notalar beat cizgisini gecer; 2 kacan nota
    // 1 can goturur (kare basina en fazla 1 can) — 3 can 6 kacan
    // notada biter. Acilis lutfu ilk 4 notayi affeder (hitMs <= ~5400).
    var guard = 0;
    while (state.debugAlive && guard < 2000) {
      state.advance(50);
      guard++;
    }
    expect(state.debugAlive, isFalse);
    expect(state.debugLives, 0);

    // Hicbir dokunus yok: sonuc ekrani kendiliginden acilmali.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('OYUN BİTTİ!'), findsOneWidget);
    expect(find.text('Makara bitti. Yeniden çek!'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Sonuc ekrani gecis animasyonu + bekleyen zamanlayicilar
    // bitsin; sonuc ekranini kendi dugmesiyle kapat (S7 deseni).
    // 374x680 gorunumde ANA SAYFA ekran disinda kalir: once
    // gorunur yap (kaydir), sonra dokun.
    await tester.ensureVisible(find.text('ANA SAYFA'));
    await tester.pump();
    await tester.tap(find.text('ANA SAYFA'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Sistem-yazitipi bildirimi gercek-zamanli gelir: sahte saatli
    // pump'lar onu yakalayamaz; dispose aninda bekleyen kare
    // geri-cagrisi kalmasin diye gercek kisa bekleme + pump.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('12P-2: BITIR tek dokunusla bitirmez, onay ister; onayda kayip basligi gosterir',
      (tester) async {
    final key = await pumpMakara(tester);
    final state = key.currentState!;

    // Bir isabet al ki skor > 0 olsun (erken-bitir "kazandi" sayilmamali).
    while (state.debugScore == 0) {
      final notes = state.debugNotes.toList()
        ..sort((a, b) => a.hitMs.compareTo(b.hitMs));
      if (notes.isEmpty) {
        state.advance(16);
      } else {
        state.advance(notes.first.hitMs - state.debugNow);
        state.tryHit(notes.first.lane);
      }
    }
    expect(state.debugScore, greaterThan(0));
    expect(state.debugAlive, isTrue);

    await tester.tap(find.text('BİTİR'));
    await tester.pump();
    // Onay diyalogu acildi, tur henuz bitmedi.
    expect(find.text('Turu bitirilsin mi?'), findsOneWidget);
    expect(state.debugAlive, isTrue);

    await tester.tap(find.text('İptal'));
    await tester.pump();
    expect(find.text('Turu bitirilsin mi?'), findsNothing);
    expect(state.debugAlive, isTrue);

    await tester.tap(find.text('BİTİR'));
    await tester.pump();
    await tester.tap(find.text('Onayla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    // Skor > 0 olsa bile erken bitirme "SEVİYE TAMAM!" degildir.
    expect(find.text('SEVİYE TAMAM!'), findsNothing);
    expect(find.text('OYUN BİTTİ!'), findsOneWidget);
    expect(find.text('Turu erken bitirdin.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('ANA SAYFA'));
    await tester.pump();
    await tester.tap(find.text('ANA SAYFA'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('12P-3: dondurma yalniz guckle olur ve suresi biter',
      (tester) async {
    final key = await pumpMakara(tester);
    final state = key.currentState!;

    // Bekleyen zamanlayicilar (ProgressManager yuklemesi) aksin.
    await tester.pump(const Duration(milliseconds: 100));

    // Guç kullanilmadan notalar zamanla ilerler.
    state.advance(1000);
    final firstNow = state.debugNow;
    expect(firstNow, 1000);

    // Dondurma gucunu test yolundan uygula: notalar 8 sn donar.
    state.debugApplyFreeze(8000);
    final notesBefore = state.debugNotes.toList();
    expect(notesBefore, isNotEmpty);
    final frozenHit = notesBefore.first.hitMs;
    state.advance(4000);
    // Nota hitMs'i donma kadar ileri kaydi: gorunur konum degismedi.
    final notesDuring = state.debugNotes.toList();
    expect(notesDuring.first.hitMs, frozenHit + 4000);
    expect(state.debugNow, 5000);

    // Sure bitince notalar yeniden ilerler.
    state.advance(4000);
    state.advance(100);
    final notesAfter = state.debugNotes.toList();
    expect(notesAfter.first.hitMs, frozenHit + 8000);
    // Donma bitti: yeni advance'ta hitMs kaymaz, _now yaklasir.
    final hitBefore = notesAfter.first.hitMs;
    state.advance(100);
    expect(state.debugNotes.first.hitMs, hitBefore);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('12P-4: sahne girisi yumusak olur ve her turda tekrarlar',
      (tester) async {
    final key = await pumpMakara(tester);
    final state = key.currentState!;

    final entrance = find.byType(TweenAnimationBuilder<double>);
    expect(entrance, findsOneWidget);
    expect(
      tester.widget<TweenAnimationBuilder<double>>(entrance).duration,
      const Duration(milliseconds: 600),
    );
    final firstRound = state.debugRoundId;
    expect(firstRound, greaterThan(0));

    // Yeniden baslatma giris animasyonunu tekrarlatir.
    state.debugRestart();
    await tester.pump();
    expect(state.debugRoundId, firstRound + 1);
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('MAKARA %0 DOLDU'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('12P-5: biten canlar sahnede gorunur kalir (bos kalp silik degil)',
      (tester) async {
    final key = await pumpMakara(tester);
    final state = key.currentState!;

    // 1 can kaybettir: 2 kacan nota gerekir (2 iska = 1 can);
    // sahnede 3 kalp simgesi de gorunur olmali.
    var guard = 0;
    while (state.debugLives == 3 && guard < 2000) {
      state.advance(50);
      guard++;
    }
    expect(state.debugLives, 2);
    await tester.pump();
    // Dolu + bos 3 kalp: hepsi ayni glif, bos olanlar soluk renkte.
    expect(find.text('♥'), findsNWidgets(3));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
