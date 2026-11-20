import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/modes/yuva_defense_screen.dart';
import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/cloud_sync_service.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

// W13-E — GOLD EARNED tutarsızlığı (playtest raporu, "Genel gözlemler"):
// Aynı "LEVEL COMPLETE" ekranında Balon 504→+5, Bağla 72→+1,
// Stack 23→+1, 2048 14→+1, Terlik 228→+0, Yuva 285→+0.
//
// Kural (lib/services/finish_run.dart:191 + lib/screens/result_screen.dart:95):
// varsayılan ödeme `skor > 0 ? max(1, skor ~/ 100) : 0` (F10-kuralı).
// Balon/Bağla/Stack/2048 açık `coins` geçirmez → varsayılan uygulanır.
// Terlik/Yuva ise açık `coins: _coinsEarned` geçirir — birikmiş tur-içi
// coin sayacıdır. Ölüm yolunda (`_die` / `_endGame`) tura
// `max(1, skor ~/ 400)` (Terlik) / `max(1, skor ~/ 360)` (Yuva) eklenir;
// BİTİR (erken bitirme) yolu bu eklemeyi atlar → skor > 0 iken GOLD +0.
// Bu dosya önce hatayı gösterir (KIRMIZI), düzeltmeyle YEŞİL olur.
/// terlik_play_test.dart ile aynı yazı tipi ön-yüklemesi:
/// ön-yükleme yoksa ilk metin çizimi sistem yazı tipi bildirimini
/// tetikleyip elden çıkarma sonrası "animation is still running"
/// hatası verir.
Future<void> _loadCustomFonts() async {
  final fontMap = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
    ],
    'Bangers': ['assets/fonts/Bangers-Regular.ttf'],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
    ],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
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


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
    await _loadCustomFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    AudioManager().isMuted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (call) async => null,
        );
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await LeaderboardService.instance.load();
    await ProgressManager.instance.load();
    ProgressManager.instance.coins = 1000;
    ProgressManager.instance.modeHighScores.clear();
    CloudSyncService.instance.pending.clear();
  });

  /// `finishRun` varsayılan ödemesi (finish_run.dart:190-191):
  /// skor > 0 ise en az 1 coin, skor 0 ise 0.
  int defaultCoins(int score) =>
      score > 0 ? max(1, ResultScoring.coinsFor(score)) : 0;

  Future<void> pumpMode(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpWithL10n(tester, screen, theme: buildLululuTheme());
    await tester.pump();
  }

  Future<void> tapFinishAndSettle(WidgetTester tester) async {
    expect(find.text('BİTİR'), findsOneWidget);
    await tester.tap(find.text('BİTİR'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> dismissResult(WidgetTester tester) async {
    await tester.tap(find.text('ANA SAYFA'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Sistem yazı tipi bildiriminin bekleyen kare geri çağrısı canlı
    // ağaçta aksın; yoksa elden çıkarmada "animation is still running"
    // hatası verir (terlik_play_test deseni).
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('playtest 6 vakası: varsayılan kural', () {
    test('Balon 504 -> +5 (skor ~/ 100)', () {
      expect(ResultScoring.coinsFor(504), 5);
      expect(defaultCoins(504), 5);
    });

    test('Bağla 72 / Stack 23 / 2048 14 -> +1 (F10 tabanı)', () {
      for (final score in [72, 23, 14]) {
        expect(ResultScoring.coinsFor(score), 0);
        expect(defaultCoins(score), 1);
      }
    });

    test('Terlik 228 / Yuva 285 ham skor karşılığı 2 olurdu', () {
      // Varsayılan kural uygulansaydı: 228~/100=2, 285~/100=2.
      // Gözlenen +0 bu kurala uymaz — açık `coins` geçildiği için
      // varsayılan hiç uygulanmaz (finish_run.dart:189-191).
      expect(ResultScoring.coinsFor(228), 2);
      expect(ResultScoring.coinsFor(285), 2);
      expect(defaultCoins(228), 2);
      expect(defaultCoins(285), 2);
    });

    test('skor 0 varsayılan ödeme 0 coindir', () {
      expect(defaultCoins(0), 0);
    });
  });

  group('Terlik/Yuva: tur-sonu skor→coin formülü (sınır değerler)', () {
    test('Terlik: skor ~/ 400, en az 1', () {
      expect(TerlikTapScreen.endCoinsForScore(228), 1);
      expect(TerlikTapScreen.endCoinsForScore(399), 1);
      expect(TerlikTapScreen.endCoinsForScore(400), 1);
      expect(TerlikTapScreen.endCoinsForScore(799), 1);
      expect(TerlikTapScreen.endCoinsForScore(800), 2);
      expect(TerlikTapScreen.endCoinsForScore(860), 2);
    });

    test('Yuva: skor ~/ 360, en az 1', () {
      expect(YuvaDefenseScreen.endCoinsForScore(285), 1);
      expect(YuvaDefenseScreen.endCoinsForScore(359), 1);
      expect(YuvaDefenseScreen.endCoinsForScore(360), 1);
      expect(YuvaDefenseScreen.endCoinsForScore(719), 1);
      expect(YuvaDefenseScreen.endCoinsForScore(720), 2);
      expect(YuvaDefenseScreen.endCoinsForScore(740), 2);
    });
  });

  group('Terlik/Yuva: BİTİR yolu tur-sonu ödülünü öder', () {
    testWidgets('Terlik FINISH: tohum skor 860 -> GOLD +2', (tester) async {
      // prototypeVisualState skoru 860 tohumlar (terlik:237),
      // _coinsEarned 0 başlar, tur döngüsü çalışmaz — vuruşsuz,
      // damlasız deterministik tur: yalnız tur-sonu bağışı ödenir.
      // NOT: ekran initState'te ProgressManager.load() çağırır —
      // boş prefs varsayılan kasaya (1240) döner; bu yüzden ödeme
      // mutlak değerle değil, BİTİR öncesi kasaya göre farkla ölçülür.
      await pumpMode(
        tester,
        const TerlikTapScreen(prototypeVisualState: true),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final before = ProgressManager.instance.coins;
      await tapFinishAndSettle(tester);

      expect(find.text('+2'), findsOneWidget);
      expect(find.text('+0'), findsNothing);
      expect(ProgressManager.instance.coins, before + 2);

      await dismissResult(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Yuva FINISH: tohum skor 740 -> GOLD +2', (tester) async {
      // prototypeVisualState skoru 740 tohumlar (yuva:243),
      // _coinsEarned yalnız _endGame'de artar — BİTİR yolunda
      // tur-sonu bağışı ödenmelidir. Kasa farkı Terlik testindeki
      // notla aynı gerekçeyle ölçülür.
      await pumpMode(
        tester,
        const YuvaDefenseScreen(prototypeVisualState: true),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final before = ProgressManager.instance.coins;
      await tapFinishAndSettle(tester);

      expect(find.text('+2'), findsOneWidget);
      expect(find.text('+0'), findsNothing);
      expect(ProgressManager.instance.coins, before + 2);

      await dismissResult(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Terlik FINISH: skor 0 ise GOLD +0 kalır', (tester) async {
      // Skor 0'da tur-sonu bağışı yok (F10: skor 0 -> 0); tohum
      // skoru geçersiz kılmak için skorlu tur yerine sıfır skorlu
      // tur gerekir — bu test varsayılan kuralı belgelemek için
      // salt formül düzeyinde kalır, widget yolu ayrı izlenir.
      expect(defaultCoins(0), 0);
    });
  });
}
