// 6I: TEKRAR OYNA → donmuş splash/onboarding (A8d G44) gerileme testleri.
//
// KÖK NEDEN (kodda pinlendi):
// 1. `LululuRoutes.onGenerateRoute`, `resolveScreen('splash')`i BAĞLAMSIZ
//    çağırıyordu; rota splash'inin `onDone`'u (`context == null` →
//    hiçbir şey yapma) ölü doğuyordu. `_finish` tek-atımlık `_notified`
//    kilidini tüketince splash %101 "BAŞLIYOR!"da kalıcı donuyor, GEÇ
//    de aynı kilide takılıyordu. Düzeltme: `onGenerateRoute` splash
//    rotasını `Builder` altında kurar, `onDone` canlı Navigator
//    bağlamı alır (`lib/navigation/game_routes.dart`).
// 2. Yükleme %101 gösteriyordu: `2.4`'lük adımlar `100.8`'de durur,
//    `'%${_progress.round()}'` → `%101`. Düzeltme: ilerleme `100.0`'da
//    kelepçelenir (`lib/screens/splash_screen.dart`).
// 3. GEÇ hapı PageView'UN ALTINDA çiziliyordu: Stack isabet sırası
//    sondan başa olduğundan PageView (y 0-810) hapın dokunuşunu
//    yutuyor, `_skipToEnd` hiç ateşlenmiyordu (minimal repro:
//    PageView üstü hapta 0 dokunma, alt düğmede 1 dokunma).
//    Düzeltme: hap PageView'UN ÜSTÜNE alındı (görsel değişmez;
//    köşede çakışan içerik yok).
// 4. TEKRAR OYNA'nın kendisi kodda doğrudur: `showGameResult` `true`
//    döner, 9 mod da yerinde yeniden başlatır (`_reset`/`_restart`),
//    hiçbir yere gezinmez. Canlıdaki 12/12 "onboarding" gözlemi
//    koordinat ıskasıydı: 430x932 sonuç ekranında TEKRAR OYNA
//    y 808-859, ANA SAYFA y 868-920 aralığındadır (m07/m12/q03 PIL
//    ölçümü); denetim (115,885) ile ANA SAYFA'ya basmış, oyun rotası
//    kapanınca altta hiç tamamlanmamış splash rotası görünmüştür.
//    Bu dosya gerçek TEKRAR OYNA düğmesine basar ve yerinde yeni tur
//    açıldığını kilitler.
//
// KAPSAM: yalnız bu akış (splash rota + sonuç→tekrar). Skor/kayıt/
// ödül akışına dokunulmaz; l10n anahtarı eklenmez.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_localizations.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/navigation/game_routes.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/onboarding_screen.dart';
import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/screens/splash_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
    GoogleFonts.config.allowRuntimeFetching = false;
    // Gerçek fontlar (responsive_screens_test deseni): yedek font
    // ölçüleriyle splash sayfa 1 testte 20 px taşar; üretim
    // ölçüleriyle taşma yoktur.
    await loadAppFonts();
    await _loadCustomFonts();
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await LeaderboardService.instance.load();
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
  });

  Future<void> pumpApp(WidgetTester tester, String initialRoute) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLululuTheme(),
        locale: const Locale('tr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: AppLocalizations.localeResolutionCallback,
        onGenerateRoute: LululuRoutes.onGenerateRoute,
        initialRoute: initialRoute,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pumpSteps(
    WidgetTester tester, {
    int count = 10,
    Duration step = const Duration(milliseconds: 100),
  }) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// Düğme metnine basar: metin kendisi isabet hedefi değildir
  /// (üstteki GestureDetector/LululuPress alır); `warnIfMissed`
  /// yalnız bu bilinen uyarıyı susturur, dokunma aynı merkeze gider.
  Future<void> tapText(WidgetTester tester, String label) async {
    await tester.tap(find.text(label), warnIfMissed: false);
  }

  group('6I (b+c): isimli-rota splash akışı', () {
    testWidgets('GEÇ hapı rota splash\'ini kapatıp hub\'a gider', (
      tester,
    ) async {
      await pumpApp(tester, '/splash');
      expect(find.byType(SplashScreen), findsOneWidget);

      // GEÇ hapının gerçek merkezi (~373,68); denetimdeki (372,37)
      // hapın 7 px üstüne düşer ve hiçbir şey yapmaz — tester
      // düğmenin merkezine basar.
      await tapText(tester, 'GEÇ ›');
      await pumpSteps(
        tester,
        count: 6,
        step: const Duration(milliseconds: 300),
      );

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets(
      'BAŞLA yüklemesi %100\'de tamamlanır, %101 hiç görünmez, hub açılır',
      (tester) async {
        await pumpApp(tester, '/splash');
        expect(find.byType(SplashScreen), findsOneWidget);

        // Sayfa 1 → 2 → 3 (DEVAM, 320 ms sayfa geçişi). Sayfa animasyonu
        // ilk pompada ticker'ı başlatır (değer 0), ikincide ilerletir;
        // tek pompa sayfayı 0'da bırakır — iki pompa gerekir.
        await tapText(tester, 'DEVAM ›');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));
        await tapText(tester, 'DEVAM ›');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 400));
        // Sayfa 3: alt düğme artık BAŞLA'dır; yüklemeyi başlatır.
        expect(find.text('BAŞLA ›'), findsOneWidget);
        await tapText(tester, 'BAŞLA ›');

        // Yükleme 42×40 ms + 700 ms bitiş gecikmesi + 280 ms geçiş:
        // sahte-zaman adımlarında ilerlet, her adımda %101 yokluğunu
        // denetle (düzeltme öncesi %101 kalıcı donardı).
        for (var i = 0; i < 15; i++) {
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('%101'), findsNothing);
        }

        expect(find.byType(HomeShell), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.text('BAŞLIYOR!'), findsNothing);
        expect(tester.takeException(), isNull);
        await tearDownTree(tester);
      },
    );
  });

  group('6I (a): TEKRAR OYNA yerinde yeni tur açar', () {
    testWidgets(
      'match3: BİTİR → sonuç → TEKRAR OYNA → taze tahta (splash/onboarding yok)',
      (tester) async {
        // Giriş enerjisi kapısı 1 enerji ister; boş prefs varsayılanı
        // 5'tir, yine de doldur (diğer testlerden sızan tüketime karşı).
        EnergyService.instance.addEnergy(5);
        await pumpApp(tester, '/match3');
        for (
          var i = 0;
          i < 10 && find.byType(Match3Screen).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(find.byType(Match3Screen), findsOneWidget);

        // Hamlesiz BİTİR (skor 0) → sonuç ekranı (kayıp başlığı).
        await tapText(tester, 'BİTİR');
        await pumpSteps(tester);
        expect(find.byType(GameResultScreen), findsOneWidget);
        expect(find.text('OYUN BİTTİ!'), findsOneWidget);

        // Gerçek TEKRAR OYNA düğmesi (y 808-859); denetimdeki (115,885)
        // ANA SAYFA'ya düşerdi — bu test düğme metnine basar.
        await tapText(tester, 'TEKRAR OYNA');
        await pumpSteps(tester);

        expect(find.byType(Match3Screen), findsOneWidget);
        expect(find.byType(GameResultScreen), findsNothing);
        expect(find.byType(SplashScreen), findsNothing);
        expect(find.byType(OnboardingScreen), findsNothing);

        // Yeni tur canlıdır ve yeniden bitirilebilir (bayat tur değil).
        await tapText(tester, 'BİTİR');
        await pumpSteps(tester);
        expect(find.byType(GameResultScreen), findsOneWidget);
        expect(find.text('OYUN BİTTİ!'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tearDownTree(tester);
      },
    );
  });
}

/// Üretim fontlarını test ortamına yükler
/// (responsive_screens_test.dart ile aynı harita).
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
}
