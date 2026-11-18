import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/mode_bonus_bar.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

// Osmantuş mikrofon iadesi: `_useMic` kalkan aktifken `false` döner
// (lib/modes/osmantus_screen.dart:419-430) ve MİKROFON düğmesi
// `stockBonusWithResult` ile bağlıdır (aynı dosya:1002-1010), yani
// `false` dönen etki `ProgressManager.refundPower` ile iade edilir
// (lib/widgets/mode_bonus_bar.dart:267-296).
//
// Widget testi donmuş saatle (`clockForTesting: () => 0`) koşar: gerçek
// saatle kaçan vuruş kalkanı tüketir (`_miss`, osmantus_screen.dart:293),
// donmuş saatte ıska olmaz ve kalkan ikinci/üçüncü dokunuşta da aktiftir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    await loadTestFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
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

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    await ProgressManager.instance.setPowerCount('mic', 3);
  });

  testWidgets('kalkan aktifken ikinci MİKROFON dokunuşu stok iade eder',
      (tester) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager.instance;
    expect(pm.powerCount('mic'), 3);

    await tester.pumpWidget(
      wrapWithL10n(
        OsmantusScreen(clockForTesting: () => 0),
        theme: buildLululuTheme(),
      ),
    );
    await tester.pump();
    expect(find.text('MİKROFON'), findsOneWidget);

    // İlk dokunuş: kalkan kurulur, 1 stok tüketilir.
    await tester.tap(find.text('MİKROFON'));
    await tester.pump();
    expect(pm.powerCount('mic'), 2);
    expect(find.text('MİKROFON KALKANI!'), findsOneWidget);

    // İkinci dokunuş: `_useMic` false döner, tüketilen stok iade edilir.
    await tester.tap(find.text('MİKROFON'));
    await tester.pump();
    expect(pm.powerCount('mic'), 2);
    expect(find.text('MİKROFON KALKANI!'), findsOneWidget);

    // Üçüncü dokunuş da aynı: kalkan hâlâ aktif, stok değişmez.
    await tester.tap(find.text('MİKROFON'));
    await tester.pump();
    expect(pm.powerCount('mic'), 2);
    expect(find.text('MİKROFON KALKANI!'), findsOneWidget);

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  group('stockBonusWithResult iade sözleşmesi', () {
    test('effect true ise stok 1 azalır', () async {
      final pm = ProgressManager.instance;
      await pm.setPowerCount('mic', 2);
      final bonus = stockBonusWithResult(
        id: 'mic',
        label: 'MİKROFON',
        asset: 'assets/icons2/star.png',
        effect: () => true,
      );

      expect(bonus.count, 2);
      expect(bonus.onTap, isNotNull);
      bonus.onTap!();

      expect(pm.powerCount('mic'), 1);
    });

    test('effect false ise tüketilen stok iade edilir', () async {
      final pm = ProgressManager.instance;
      await pm.setPowerCount('mic', 2);
      var calls = 0;
      final bonus = stockBonusWithResult(
        id: 'mic',
        label: 'MİKROFON',
        asset: 'assets/icons2/star.png',
        effect: () {
          calls++;
          return false;
        },
      );

      bonus.onTap!();

      expect(calls, 1);
      expect(pm.powerCount('mic'), 2);
    });

    test('stok 0 ise onTap null olur ve effect çalışmaz', () async {
      final pm = ProgressManager.instance;
      await pm.setPowerCount('mic', 0);
      var calls = 0;
      final bonus = stockBonusWithResult(
        id: 'mic',
        label: 'MİKROFON',
        asset: 'assets/icons2/star.png',
        effect: () {
          calls++;
          return true;
        },
      );

      expect(bonus.count, 0);
      expect(bonus.onTap, isNull);
      expect(calls, 0);
      expect(pm.powerCount('mic'), 0);
    });

    test('canApply false ise stok tüketilmez ve effect çalışmaz', () async {
      final pm = ProgressManager.instance;
      await pm.setPowerCount('mic', 2);
      var calls = 0;
      final bonus = stockBonusWithResult(
        id: 'mic',
        label: 'MİKROFON',
        asset: 'assets/icons2/star.png',
        effect: () {
          calls++;
          return true;
        },
        canApply: () => false,
      );

      expect(bonus.onTap, isNotNull);
      bonus.onTap!();

      expect(calls, 0);
      expect(pm.powerCount('mic'), 2);
    });
  });
}
