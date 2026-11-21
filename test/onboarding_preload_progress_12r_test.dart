// 12R — Tanıtım çubuğu + ön-yükleme zaman aşımı davranış kilitleri.
//
// KÖK NEDENLER (kodda pinlendi):
// 1. `OnboardingScreen._progress` `0.78` sabitiydi; hiçbir iş ilerlemeyi
//    güncellemiyordu — çubuk ilk kareden DOKUN VE BAŞLA dokunuşuna kadar
//    %78'de takılı görünüyordu (canlıda 45+ sn "donuyor" izlenimi;
//    iPhone'da da aynı, çünkü bar platforma değil sabite bağlıydı).
//    Düzeltme: çubuk `ZeroJankPreloader.progressNotifier`dan okur.
// 2. `ZeroJankPreloader` kuyruğundaki tek bir iş asla dönmezse
//    (`rootBundle.load` / `precacheImage` takılması — iOS Safari'de
//    olası) kuyruk ve ilerleme sonsuza kadar kilitleniyordu: işlerde
//    zaman aşımı yoktu. Düzeltme: her iş `jobTimeout` (15 sn) ile
//    çalışır; süre dolan iş denendi sayılır, kuyruk ilerler.
// 3. `web/index.html` salt Flutter şablonuydu: motor ilk kareyi
//    boyayana kadar (~20 sn) bembeyaz ekran, yükleme göstergesi yok.
//    Düzeltme: koyu zemin + dönen gösterge, ilk karede kalkar
//    (bu dosya HTML'i test etmez; Playwright karesiyle kanıtlanır).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_localizations.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/onboarding_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/zero_jank_preloader.dart';
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
    // Gerçek fontlar (replay_onboarding_6i_test deseni): yedek font
    // ölçüleriyle tanıtım sayfası testte taşar; üretim ölçüleriyle
    // taşma yoktur.
    await loadAppFonts();
    await _loadCustomFonts();
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpOnboarding(
    WidgetTester tester, {
    double progress = 0.0,
  }) async {
    ZeroJankPreloader.instance.progress01 = progress;
    ZeroJankPreloader.instance.progressNotifier.value = progress;
    // iPhone genişliği (390x844), dokunmatik varsayılan.
    tester.view.physicalSize = const Size(390, 844);
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
        home: const OnboardingScreen(),
      ),
    );
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  group('12R: ön-yükleme zaman aşımı', () {
    test('asla dönmeyen iş kuyruğu kilitlemez, ilerleme 1.0 olur',
        () async {
      final preloader = ZeroJankPreloader.instance;
      final previousTimeout = preloader.jobTimeout;
      preloader.jobTimeout = const Duration(milliseconds: 50);
      try {
        // iOS Safari'de takılan yüklemeyi temsil eder: hiç bitmez.
        preloader.enqueue(() => Completer<void>().future);
        preloader.enqueue(() async {});
        await preloader.start();
        expect(preloader.progress01, 1.0);
        expect(preloader.progressNotifier.value, 1.0);
        expect(preloader.isWarming, isFalse);
      } finally {
        preloader.jobTimeout = previousTimeout;
      }
    });

    test('ilerleme bildirimi progress01 ile aynı değeri taşır', () async {
      final preloader = ZeroJankPreloader.instance;
      await preloader.start();
      expect(preloader.progress01, 1.0);
      expect(preloader.progressNotifier.value, preloader.progress01);
    });
  });

  group('12R: tanıtım çubuğu gerçek ilerlemeyi gösterir', () {
    testWidgets('çubuk %78 sabitinde değil, gerçek ilerlemede durur',
        (tester) async {
      await pumpOnboarding(tester, progress: 0.42);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('%42'), findsOneWidget);
      expect(find.text('%78'), findsNothing);
      expect(
        find.text('Böcek sesleri ve 11 oyun sahnesi hazırlanıyor...'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ilerleme değişince çubuk canlanır', (tester) async {
      await pumpOnboarding(tester, progress: 0.3);
      expect(find.text('%30'), findsOneWidget);
      ZeroJankPreloader.instance.progressNotifier.value = 0.9;
      await tester.pump();
      expect(find.text('%90'), findsOneWidget);
      expect(find.text('%30'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ilerleme %100 olunca etiket hazırlanıyor değil başlıyor olur',
        (tester) async {
      await pumpOnboarding(tester, progress: 1.0);
      expect(find.text('%100'), findsOneWidget);
      expect(find.text('BAŞLIYOR!'), findsOneWidget);
      expect(
        find.text('Böcek sesleri ve 11 oyun sahnesi hazırlanıyor...'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('DOKUN VE BAŞLA ana ekrana gider', (tester) async {
      await pumpOnboarding(tester, progress: 1.0);
      await tester.tap(find.text('DOKUN VE BAŞLA!'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Gerçek fontları kaydeder (replay_onboarding_6i_test deseni).
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
}
