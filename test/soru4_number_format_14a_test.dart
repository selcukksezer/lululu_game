import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_localizations.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/utils/number_format.dart';
import 'package:lululu_game/widgets/home/vault_top_hud.dart';

// 14A — Soru 4: EN'de TR sayı biçimi (1.240) yerine EN biçimi (1,240).
//
// Kanonik yardımcılar (lib/utils/number_format.dart) birim testleriyle,
// çevrilen çağrı yerlerindeki ifade (skor + coin + arcade) sonda
// (probe) widget'ıyla, K kısaltması (TR '1,2 B', EN '1.2K') ise gerçek
// VaultTopHud widget'ıyla doğrulanır.

/// Çevrilen çağrı yerlerindeki ifadenin aynısı: skor + coin + arcade.
class _ProbeNumbers extends StatelessWidget {
  const _ProbeNumbers({
    required this.score,
    required this.coins,
    required this.best,
  });

  final int score;
  final int coins;
  final int best;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return Column(
      children: [
        Text('skor:${formatGroupedInt(score, languageCode)}'),
        Text('coin:${formatGroupedInt(coins, languageCode)}'),
        Text('arcade:${formatGroupedInt(best, languageCode)}'),
      ],
    );
  }
}

Widget _buildTestApp(Locale locale, Widget home) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    localeResolutionCallback: AppLocalizations.localeResolutionCallback,
    home: Scaffold(body: home),
  );
}

/// Telefon yüzeyi (430x932, coin_fly deseni): oyun ekranları telefon
/// ölçüsünde çizilir; varsayılan 800x600 yüzeyde Osmantus sütunu taşar.
Future<void> _setPhoneSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Hafif ağaç sökme: ağaç sökülür, gerçek 1 sn beklenir, pompalanır.
/// Ticker'lı ekranlarda bekleyen geri çağrı kalmasın diye.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(seconds: 1));
  });
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

/// Sonuç ekranı sökme (coin_fly `tearDownTree` deseni): saat 6 sn
/// ilerletilir — flutter_animate sıfır-süreli zamanlayıcısı + CoinFly
/// gecikmesi ağaç sökülmeden bitsin — sonra sökülüp gerçek 1 sn
/// beklenir; yoksa test sonu denetimi bekleyen zamanlayıcıyla düşer.
Future<void> _disposeResultTree(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(seconds: 1));
  });
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

/// Teardown flake tahliyesi (suika_best_hud_6e / 12I deseni):
/// font yüklemeden kalan transient callback test sonunda ağaç
/// çözülmüşken patlamasın diye teardown'da tüketilir.
void _registerFontCallbackDrain() {
  addTearDown(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
      await binding.pump();
    }
  });
}

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
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
  });

  group('formatGroupedInt', () {
    test('TR binlik ayırıcı noktadır', () {
      expect(formatGroupedInt(1240, 'tr'), '1.240');
      expect(formatGroupedInt(1234567, 'tr'), '1.234.567');
      expect(formatGroupedInt(1000, 'tr'), '1.000');
      expect(formatGroupedInt(999, 'tr'), '999');
      expect(formatGroupedInt(0, 'tr'), '0');
      expect(formatGroupedInt(-1240, 'tr'), '-1.240');
    });

    test('EN binlik ayırıcı virgüldür', () {
      expect(formatGroupedInt(1240, 'en'), '1,240');
      expect(formatGroupedInt(1234567, 'en'), '1,234,567');
      expect(formatGroupedInt(1000, 'en'), '1,000');
      expect(formatGroupedInt(999, 'en'), '999');
      expect(formatGroupedInt(0, 'en'), '0');
      expect(formatGroupedInt(-1240, 'en'), '-1,240');
    });
  });

  group('formatDecimal', () {
    test('TR ondalık ayırıcı virgüldür', () {
      expect(formatDecimal(1.2, 1, 'tr'), '1,2');
      expect(formatDecimal(12.5, 1, 'tr'), '12,5');
    });

    test('EN ondalık ayırıcı noktadır', () {
      expect(formatDecimal(1.2, 1, 'en'), '1.2');
      expect(formatDecimal(12.5, 1, 'en'), '12.5');
    });
  });

  group('çağrı yeri ifadesi (skor + coin + arcade)', () {
    testWidgets('TR: 1.240', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('tr'),
          const _ProbeNumbers(score: 1240, coins: 1240, best: 1234567),
        ),
      );
      await tester.pump();
      expect(find.text('skor:1.240'), findsOneWidget);
      expect(find.text('coin:1.240'), findsOneWidget);
      expect(find.text('arcade:1.234.567'), findsOneWidget);
    });

    testWidgets('EN: 1,240', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('en'),
          const _ProbeNumbers(score: 1240, coins: 1240, best: 1234567),
        ),
      );
      await tester.pump();
      expect(find.text('skor:1,240'), findsOneWidget);
      expect(find.text('coin:1,240'), findsOneWidget);
      expect(find.text('arcade:1,234,567'), findsOneWidget);
    });
  });

  group('VaultTopHud K kısaltması', () {
    testWidgets('TR: 1240 coin -> 1,2 B', (tester) async {
      _registerFontCallbackDrain();
      ProgressManager.instance.coins = 1240;
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('tr'),
          VaultTopHud(progress: ProgressManager.instance),
        ),
      );
      await tester.pump();
      expect(find.text('1,2 B'), findsOneWidget);
      expect(find.text('1.2K'), findsNothing);
    });

    testWidgets('EN: 1240 coin -> 1.2K', (tester) async {
      _registerFontCallbackDrain();
      ProgressManager.instance.coins = 1240;
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('en'),
          VaultTopHud(progress: ProgressManager.instance),
        ),
      );
      await tester.pump();
      expect(find.text('1.2K'), findsOneWidget);
      expect(find.text('1,2 B'), findsNothing);
    });

    testWidgets('TR: 12500 coin -> 12,5 B; EN: 12.5K', (tester) async {
      _registerFontCallbackDrain();
      ProgressManager.instance.coins = 12500;
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('tr'),
          VaultTopHud(progress: ProgressManager.instance),
        ),
      );
      await tester.pump();
      expect(find.text('12,5 B'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestApp(
          const Locale('en'),
          VaultTopHud(progress: ProgressManager.instance),
        ),
      );
      await tester.pump();
      expect(find.text('12.5K'), findsOneWidget);
    });

    testWidgets('1000 altı coin kısaltılmaz', (tester) async {
      _registerFontCallbackDrain();
      ProgressManager.instance.coins = 999;
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('tr'),
          VaultTopHud(progress: ProgressManager.instance),
        ),
      );
      await tester.pump();
      expect(find.text('999'), findsOneWidget);
    });
  });

  group('Dalga 14A2 — Soru 4 takip (makara/osmantus/çığlık/sonuç)', () {
    testWidgets('Makara prototip TR: coin 12.450, skor 1.105, rekor 1.760', (
      tester,
    ) async {
      _registerFontCallbackDrain();
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('tr'),
          const MakarayizScreen(prototypeVisualState: true),
        ),
      );
      await tester.pump();
      expect(find.text('12.450'), findsOneWidget);
      expect(find.text('1.105'), findsOneWidget);
      expect(find.text('1.760'), findsOneWidget);
    });

    testWidgets('Makara prototip EN: coin 12,450, skor 1,105, rekor 1,760', (
      tester,
    ) async {
      _registerFontCallbackDrain();
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('en'),
          const MakarayizScreen(prototypeVisualState: true),
        ),
      );
      await tester.pump();
      expect(find.text('12,450'), findsOneWidget);
      expect(find.text('1,105'), findsOneWidget);
      expect(find.text('1,760'), findsOneWidget);
    });

    testWidgets('Osmantus coin TR: 1240 -> 1.240', (tester) async {
      _registerFontCallbackDrain();
      await _setPhoneSurface(tester);
      ProgressManager.instance.coins = 1240;
      await tester.pumpWidget(
        _buildTestApp(const Locale('tr'), const OsmantusScreen()),
      );
      await tester.pump();
      expect(find.text('1.240'), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets('Osmantus coin EN: 1240 -> 1,240', (tester) async {
      _registerFontCallbackDrain();
      await _setPhoneSurface(tester);
      ProgressManager.instance.coins = 1240;
      await tester.pumpWidget(
        _buildTestApp(const Locale('en'), const OsmantusScreen()),
      );
      await tester.pump();
      expect(find.text('1,240'), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets('Osmantus prototip vitrin sabiti dile bakmaz: 12.450', (
      tester,
    ) async {
      _registerFontCallbackDrain();
      await _setPhoneSurface(tester);
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('en'),
          const OsmantusScreen(prototypeVisualState: true),
        ),
      );
      await tester.pump();
      expect(find.text('12.450'), findsOneWidget);
      expect(find.text('12,450'), findsNothing);
      await _disposeTree(tester);
    });

    testWidgets('Çığlık prototip TR: coin 12.450, skor 1.320, rekor 2.105', (
      tester,
    ) async {
      _registerFontCallbackDrain();
      await _setPhoneSurface(tester);
      // Rekor tohumu (ciglik_pixel_capture deseni): prototip _best'i
      // `max(_best, 2105)` yapar ama `_loadBest` tahtadaki değerle
      // ezer — tahta 2105 olmazsa rekor 0'a döner.
      await LeaderboardService.instance.ensureLoaded();
      await LeaderboardService.instance.submitScore(
        LeaderboardService.modeScream,
        2105,
      );
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('tr'),
          const TickerMode(
            enabled: false,
            child: ScreamRoachScreen(prototypeVisualState: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('12.450'), findsOneWidget);
      expect(find.text('1.320'), findsOneWidget);
      expect(find.text('2.105'), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets('Çığlık prototip EN: coin 12,450, skor 1,320, rekor 2,105', (
      tester,
    ) async {
      _registerFontCallbackDrain();
      await _setPhoneSurface(tester);
      await LeaderboardService.instance.ensureLoaded();
      await LeaderboardService.instance.submitScore(
        LeaderboardService.modeScream,
        2105,
      );
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('en'),
          const TickerMode(
            enabled: false,
            child: ScreamRoachScreen(prototypeVisualState: true),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('1,320'), findsOneWidget);
      expect(find.text('2,105'), findsOneWidget);
      expect(find.text('12,450'), findsOneWidget);
      await _disposeTree(tester);
    });

    testWidgets('Sonuç ekranı TR: skor 1.240, rekor 1.234.567', (tester) async {
      _registerFontCallbackDrain();
      await _setPhoneSurface(tester);
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('tr'),
          const GameResultScreen(score: 1240, bestScore: 1234567),
        ),
      );
      await tester.pump();
      expect(find.text('1.240'), findsOneWidget);
      expect(find.text('1.234.567'), findsOneWidget);
      await _disposeResultTree(tester);
    });

    testWidgets('Sonuç ekranı EN: skor 1,240, rekor 1,234,567', (tester) async {
      _registerFontCallbackDrain();
      await _setPhoneSurface(tester);
      await tester.pumpWidget(
        _buildTestApp(
          const Locale('en'),
          const GameResultScreen(score: 1240, bestScore: 1234567),
        ),
      );
      await tester.pump();
      expect(find.text('1,240'), findsOneWidget);
      expect(find.text('1,234,567'), findsOneWidget);
      await _disposeResultTree(tester);
    });
  });
}
