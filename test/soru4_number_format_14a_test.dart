import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_localizations.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
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
}
