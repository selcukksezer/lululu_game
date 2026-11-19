import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/sticker_image.dart';

import 'test_helpers.dart';

/// all_modes_play_test.dart ile aynı yazı tipi ön-yüklemesi: ön-yükleme
/// yoksa ilk metin çizimi sistem yazı tipi bildirimini tetikleyip
/// elden çıkarma sonrası "animation is still running" hatası verir.
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

  setUp(() {
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
  });

  test('tutorial gives slower emergence and longer target windows', () {
    expect(TerlikTapPacing.spawnInterval(0), 1.15);
    expect(TerlikTapPacing.spawnInterval(14.9), 1.15);
    expect(TerlikTapPacing.targetVisibleSeconds(14.9), 1.8);
    expect(TerlikTapPacing.spawnInterval(16), lessThan(1.15));
    expect(TerlikTapPacing.targetVisibleSeconds(16), lessThan(1.8));
    expect(TerlikTapPacing.spawnInterval(200), 0.58);
  });

  testWidgets('players can hit a mole and miss penalty is clear', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpWithL10n(
      tester,
      const TerlikTapScreen(initialTargetForTesting: true),
    );
    await tester.pump();

    final bugFinder = find.byType(StickerImage).first;
    expect(bugFinder, findsOneWidget);
    final bugKey =
        tester.widget<StickerImage>(bugFinder).key! as ValueKey<String>;
    final hitHole = int.parse(bugKey.value.split('-').last);
    await tester.tap(bugFinder);
    await tester.pump();
    expect(find.textContaining('COMBO X1'), findsWidgets);
    expect(find.textContaining('VURUŞ 1'), findsOneWidget);

    final emptyHoles = List<int>.generate(
      9,
      (index) => index,
    ).where((index) => index != hitHole).take(3);
    for (final hole in emptyHoles) {
      await tester.tap(find.byKey(ValueKey<String>('terlik-hole-$hole')));
      await tester.pump();
    }
    expect(find.textContaining('BOŞA VURDUN'), findsOneWidget);
    expect(find.textContaining('KOMBO KIRILDI'), findsWidgets);
    // Boş vuruş artık can götürmüyor (yalnızca kombo kırıyor):
    // 3 boş vuruştan sonra '-1 CAN' görünmemeli.
    expect(find.textContaining('-1 CAN'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('spray consumes stock while a live target exists (B13)', (
    tester,
  ) async {
    // all_modes montaj koşulları (430×932 + 0.85 yazı ölçeği): 374px
    // genişlikte bilinen 91px taşma bu testin konusu değildir.
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'lululu_spray': 3});
    await ProgressManager().load();
    final pm = ProgressManager();

    await pumpWithL10n(
      tester,
      const TerlikTapScreen(initialTargetForTesting: true),
      theme: buildLululuTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(430, 932),
          devicePixelRatio: 1.0,
          textScaler: const TextScaler.linear(0.85),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('İLAÇ'), findsOneWidget);
    expect(find.byType(StickerImage), findsWidgets);
    final before = pm.powerCount('spraybug');
    expect(before, greaterThan(0));
    await tester.tap(find.text('İLAÇ'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(pm.powerCount('spraybug'), before - 1);
    expect(tester.takeException(), isNull);
    // all_modes deseni: elden çıkarmadan önce bekleyen kare
    // geri çağrılarının (sistem yazı tipi bildirimi) canlı ağaçta
    // akmasını sağla — yoksa "animation still running" hatası verir.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
