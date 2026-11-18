import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/modes/yuva_defense_screen.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/services/adaptive_quality_scaler.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/arcade_chrome.dart';
import 'package:lululu_game/widgets/sticker_image.dart';

import 'test_helpers.dart';

Future<void> _loadCustomFonts() async {
  final fontMap = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Bold.ttf',
      'assets/fonts/Baloo2-ExtraBold.ttf',
      'assets/fonts/Baloo2-SemiBold.ttf',
      'assets/fonts/Baloo2-Medium.ttf',
    ],
    'Bangers': [
      'assets/fonts/Bangers-Regular.ttf',
    ],
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    await _loadCustomFonts();
    Animate.defaultDuration = Duration.zero;
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({
      'LululuOnboardingDoneV1': true,
      'lululu_coins': 12450,
      'lululu_spray': 3,
      'lululu_slipper': 5,
      'lululu_aydinlat': 2,
    });
    await ProgressManager().load();
    await LeaderboardService.instance.ensureLoaded();
    AdaptiveQualityScaler.instance.bootstrap(forceTier: QualityTier.medium);
  });

  Widget wrapPlayable(Widget home) {
    return wrapWithL10n(
      home,
      debugShowCheckedModeBanner: false,
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
  }

  int readArcadeScore(WidgetTester tester) {
    final stats = tester.widgetList<ArcadeStat>(find.byType(ArcadeStat));
    if (stats.isNotEmpty) {
      final raw = stats.first.value.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(raw) ?? 0;
      if (parsed > 0) return parsed;
    }
    final skorFinder = find.text('SKOR');
    for (final element in skorFinder.evaluate()) {
      final colFinder = find.ancestor(
        of: find.byElementPredicate((e) => identical(e, element)),
        matching: find.byType(Column),
      );
      if (colFinder.evaluate().isEmpty) continue;
      final texts = tester.widgetList<Text>(
        find.descendant(of: colFinder.first, matching: find.byType(Text)),
      );
      for (final t in texts) {
        final data = t.data;
        if (data == null || data == 'SKOR') continue;
        final digits = data.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          final val = int.tryParse(digits);
          if (val != null) return val;
        }
      }
    }
    return 0;
  }

  testWidgets('1. Suika (GameScreen): opens, drops & merges to score, 3 boosters respond', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    pm.sprayCount = 3;
    pm.slipperCount = 5;
    pm.aydinlatCount = 2;

    await tester.pumpWidget(
      wrapPlayable(
        GameScreen(
          level: CampaignDatabase.kitchenLevel1,
          arcade: true,
          prototypeVisualState: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('RAİD SPREYİ'), findsOneWidget);
    expect(find.text('SARSINTI'), findsOneWidget);
    expect(find.text('AYDINLAT'), findsOneWidget);

    // Drop multiple insects at same X to trigger merges and score
    for (var drop = 0; drop < 6; drop++) {
      await tester.tapAt(const Offset(215, 260));
      for (var frame = 0; frame < 55; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // Booster miktarları: her booster öncesi skoru oku, artışı delta
    // olarak ölç (birleşme skoru taban çizgisini kirletmesin).
    // Formüller (game_screen.dart): Terlik sabit +250 (:1016);
    // Raid buharlaşan başına +300, en fazla 2 böcek (:1035-1036);
    // Aydınlat ilk dalga böcek başına +180, en fazla 3 böcek (:966-968),
    // gecikmeli dalga temizlenen başına +350, tek kullanım tavanı 2000
    // (:987-993, tavan _aydinlatScoreCap = 2000). Gecikmeli dalga 480 ms
    // Timer içinde çalışır — 320 ms pompa yetmez, tek 600 ms pompa
    // gerekir. Her ölçümde tap sonrası yalnız 1 kare (16 ms) pompalanır:
    // booster skoru tap anında senkron yazılır; fazladan kareler savurma
    // itkisinin tetikleyebileceği birleşme skorunu delta'ya katar.
    final scoreBeforeBoosters = readArcadeScore(tester);

    // SARSINTI (Terlik): sabit +250.
    await tester.tap(find.text('SARSINTI'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(pm.slipperCount, lessThan(5));
    final slipDelta = readArcadeScore(tester) - scoreBeforeBoosters;
    expect(slipDelta, 250);

    // RAİD SPREYİ: buharlaşan (tier <= 3) başına +300, en fazla 2 böcek.
    // Düşürme kademeleri rastgele (+ aynı X'te birleşme tahtayı
    // seyreltebilir) olduğundan buharlaşan sayısı dışarıdan gözlenemez;
    // miktar kuantum + aralık olarak doğrulanır: {300, 600}.
    final scoreBeforeSpray = readArcadeScore(tester);
    await tester.tap(find.text('RAİD SPREYİ'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(pm.sprayCount, lessThan(3));
    final sprayDelta = readArcadeScore(tester) - scoreBeforeSpray;
    expect(sprayDelta, greaterThanOrEqualTo(300));
    expect(sprayDelta, lessThanOrEqualTo(600));
    expect(sprayDelta % 300, 0);

    // AYDINLAT: ilk dalga böcek başına +180 (en fazla 3 böcek).
    // İlk dalga öncesi tahtada en fazla 5 böcek vardır
    // (6 düşürme − Terlik 1 − Raid ≤ 2), o yüzden ilk dalga ≤ 540.
    final scoreBeforeAydinlat = readArcadeScore(tester);
    await tester.tap(find.text('AYDINLAT'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(pm.aydinlatCount, lessThan(2));
    final initialDelta = readArcadeScore(tester) - scoreBeforeAydinlat;
    expect(initialDelta, greaterThanOrEqualTo(0));
    expect(initialDelta, lessThanOrEqualTo(540));
    expect(initialDelta % 180, 0);

    // Gecikmeli dalga: 480 ms Timer — tek 600 ms pompa ile tetiklenir
    // (eski 20×16 ms = 320 ms pompa hiç işletmezdi). Tek pompa, fizik
    // adımını dt kelepçesi (33 ms) sayesinde ~2 sabit adımda tutar.
    // İlk dalga sonrası tahtada en fazla 2 böcek kalır → gecikmeli
    // temizlenen ≤ 1 → gecikmeli dalga ≤ 350 ve 2000 tavanı hiç
    // devreye girmez (2000 − ilk dalga ≥ 1460 > 350).
    await tester.pump(const Duration(milliseconds: 600));
    final delayedDelta =
        readArcadeScore(tester) - scoreBeforeAydinlat - initialDelta;
    expect(delayedDelta, greaterThanOrEqualTo(0));
    expect(delayedDelta, lessThanOrEqualTo(350));
    expect(delayedDelta % 350, 0);

    // Tek kullanım tavanı: ilk + gecikmeli toplam 2000'i aşamaz.
    expect(initialDelta + delayedDelta, lessThanOrEqualTo(2000));
    expect(readArcadeScore(tester), greaterThan(0));

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('2. 2048 Grid (m2048): opens, swipes & boosters produce score', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    await tester.pumpWidget(
      wrapPlayable(const Grid2048Screen(prototypeVisualState: false)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Grid2048Screen), findsOneWidget);
    expect(find.text('GERİ AL'), findsOneWidget);
    expect(find.text('KARIŞTIR'), findsOneWidget);
    expect(find.text('ÇİFTLEŞTİR'), findsOneWidget);

    final center = const Offset(215, 420);
    final offsets = const [
      Offset(-140, 0),
      Offset(0, -140),
    ];
    for (var i = 0; i < offsets.length; i++) {
      await tester.dragFrom(center, offsets[i]);
      await tester.pump(const Duration(milliseconds: 50));
    }

    int power2048(String baseKey, String altKey) =>
        pm.powerCount(baseKey) + (pm.extraPowers[altKey] ?? 0);

    final beforeUndo = power2048('undo', 'undo2048');
    await tester.tap(find.text('GERİ AL'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(power2048('undo', 'undo2048'), lessThan(beforeUndo));

    final beforeShuffle = power2048('shuffle', 'shuffle2048');
    await tester.tap(find.text('KARIŞTIR'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(power2048('shuffle', 'shuffle2048'), lessThan(beforeShuffle));

    final beforePair = power2048('pair', 'pair2048');
    await tester.tap(find.text('ÇİFTLEŞTİR'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(power2048('pair', 'pair2048'), lessThan(beforePair));

    expect(readArcadeScore(tester), greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('3. Balon Patlat (balon): opens, fires shots, 3 boosters respond and score > 0', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    await tester.pumpWidget(
      wrapPlayable(const BalloonPopScreen(prototypeVisualState: false)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(BalloonPopScreen), findsOneWidget);
    expect(find.text('ÜÇLÜ OK'), findsOneWidget);
    expect(find.text('BOMBA'), findsOneWidget);
    expect(find.text('YAVAŞLAT'), findsOneWidget);

    // Fire 2 shots (avoid 4th shot _descend() into danger row before boosters)
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(Offset(140.0 + i * 45, 220));
      for (var f = 0; f < 45; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // Trigger all 3 boosters
    final beforeTriple = pm.powerCount('triple');
    await tester.tap(find.text('ÜÇLÜ OK'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(pm.powerCount('triple'), beforeTriple - 1);

    final beforeSlow = pm.powerCount('slowb');
    await tester.tap(find.text('YAVAŞLAT'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(pm.powerCount('slowb'), beforeSlow - 1);

    final beforeBomb = pm.powerCount('bombb');
    await tester.tap(find.text('BOMBA'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(pm.powerCount('bombb'), beforeBomb - 1);

    expect(readArcadeScore(tester), greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('4. Match 3 (match3): opens, swipes tiles, 3 boosters respond and score > 0', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    await tester.pumpWidget(
      wrapPlayable(const Match3Screen(prototypeVisualState: false)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Match3Screen), findsOneWidget);
    expect(find.text('ÇEKİÇ'), findsOneWidget);
    expect(find.text('BOMBA'), findsOneWidget);
    expect(find.text('AVCI'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.dragFrom(Offset(110.0 + i * 34, 300), const Offset(34, 0));
      for (var f = 0; f < 30; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    final beforeHammer = pm.powerCount('hammer');
    await tester.tap(find.text('ÇEKİÇ'));
    for (var f = 0; f < 30; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(pm.powerCount('hammer'), beforeHammer - 1);

    final beforeBomb = pm.powerCount('bomb3');
    await tester.tap(find.text('BOMBA'));
    for (var f = 0; f < 30; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(pm.powerCount('bomb3'), beforeBomb - 1);

    final beforeHunter = pm.powerCount('hunter');
    await tester.tap(find.text('AVCI'));
    for (var f = 0; f < 30; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(pm.powerCount('hunter'), beforeHunter - 1);

    expect(readArcadeScore(tester), greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('5. Bağla Patlat (bagla): opens, draws chain to score, 3 boosters respond', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    await tester.pumpWidget(
      wrapPlayable(
        const ConnectPopScreen(
          prototypeVisualState: false,
          gameplayTestState: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ConnectPopScreen), findsOneWidget);
    expect(find.text('ZİNCİR +'), findsOneWidget);
    expect(find.text('YILDIRIM'), findsOneWidget);
    expect(find.text('MIKNATIS'), findsOneWidget);

    final board = tester.getRect(
      find.byKey(const ValueKey('connect-pop-board')),
    );
    const gap = 5.0;
    final cell = (board.width - gap * 5) / 6;
    final stride = cell + gap;
    Offset centerOf(int row, int column) => Offset(
          board.left + column * stride + cell / 2,
          board.top + row * stride + cell / 2,
        );
    final gesture = await tester.startGesture(centerOf(1, 1));
    var previous = centerOf(1, 1);
    for (final point in const [(1, 2), (2, 2), (2, 3), (3, 3)]) {
      final next = centerOf(point.$1, point.$2);
      await gesture.moveTo(Offset.lerp(previous, next, 0.5)!);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(next);
      await tester.pump(const Duration(milliseconds: 16));
      previous = next;
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 150));

    expect(readArcadeScore(tester), greaterThanOrEqualTo(744));

    final beforeChain = pm.powerCount('chain');
    await tester.tap(find.text('ZİNCİR +'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(pm.powerCount('chain'), beforeChain - 1);

    final beforeBolt = pm.powerCount('bolt');
    await tester.tap(find.text('YILDIRIM'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(pm.powerCount('bolt'), beforeBolt - 1);

    final beforeMagnet = pm.powerCount('magnet');
    await tester.tap(find.text('MIKNATIS'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(pm.powerCount('magnet'), beforeMagnet - 1);

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('6. Stack Drop (stack): opens, drops slabs to score, 3 boosters respond', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    await tester.pumpWidget(
      wrapPlayable(const StackDropScreen(prototypeVisualState: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(StackDropScreen), findsOneWidget);
    expect(find.text('DONDUR'), findsOneWidget);
    expect(find.text('GENİŞLET'), findsOneWidget);
    expect(find.text('YAVAŞLAT'), findsOneWidget);

    await tester.tapAt(const Offset(215, 420));
    for (var f = 0; f < 65; f++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(readArcadeScore(tester), greaterThan(0));

    final beforeFreeze = pm.powerCount('freeze');
    await tester.tap(find.text('DONDUR'));
    await tester.pump(const Duration(milliseconds: 32));
    expect(pm.powerCount('freeze'), beforeFreeze - 1);

    final beforeWiden = pm.powerCount('widen');
    await tester.tap(find.text('GENİŞLET'));
    await tester.pump(const Duration(milliseconds: 32));
    expect(pm.powerCount('widen'), beforeWiden - 1);

    final beforeSlows = pm.powerCount('slows');
    await tester.tap(find.text('YAVAŞLAT'));
    await tester.pump(const Duration(milliseconds: 32));
    expect(pm.powerCount('slows'), beforeSlows - 1);

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('7. Terlik Tap (terlik): opens, hits target to score, 3 boosters respond', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    await tester.pumpWidget(
      wrapPlayable(
        const TerlikTapScreen(
          prototypeVisualState: false,
          initialTargetForTesting: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(TerlikTapScreen), findsOneWidget);
    expect(find.text('ÇİFT TERLİK'), findsOneWidget);
    expect(find.text('ALTIN TERLİK'), findsOneWidget);
    expect(find.text('İLAÇ'), findsOneWidget);

    final bugFinder = find.byType(StickerImage).first;
    expect(bugFinder, findsOneWidget);
    final holeGesture = find.ancestor(
      of: bugFinder,
      matching: find.byType(GestureDetector),
    ).first;
    await tester.tap(holeGesture);
    await tester.pump(const Duration(milliseconds: 50));
    expect(readArcadeScore(tester), greaterThan(0));

    final beforeDbl = pm.powerCount('dblslip');
    await tester.tap(find.text('ÇİFT TERLİK'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(pm.powerCount('dblslip'), beforeDbl - 1);

    final beforeGold = pm.powerCount('goldslip');
    await tester.tap(find.text('ALTIN TERLİK'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(pm.powerCount('goldslip'), beforeGold - 1);

    final beforeSpray = pm.powerCount('spraybug');
    await tester.tap(find.text('İLAÇ'));
    await tester.pump(const Duration(milliseconds: 50));
    // B13: tek hedef ezildikten sonra tahta boştur — İLAÇ boş tahtada
    // stok tüketmez (iade yolu; hedef üretmek için böcek doğurulmaz).
    // Canlı hedefte tüketim terlik_play_test.dart'taki sprey testinde.
    expect(pm.powerCount('spraybug'), beforeSpray);

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('8. Yuva Savunması (yuva): opens, hits approaching bug to score, 3 boosters visible & interactive', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapPlayable(const YuvaDefenseScreen(prototypeVisualState: false)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(YuvaDefenseScreen), findsOneWidget);
    expect(find.text('ÇİFT TERLİK'), findsOneWidget);
    expect(find.text('ALTIN TERLİK'), findsOneWidget);
    expect(find.text('KALKAN'), findsOneWidget);

    for (var f = 0; f < 6; f++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    final bugImages = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('assets/bugs/tier'),
    );
    if (bugImages.evaluate().isNotEmpty) {
      await tester.tapAt(tester.getCenter(bugImages.first));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Tap the 3 booster slots in footer (which also smash nearest bugs and boost score)
    await tester.tap(find.text('ÇİFT TERLİK'));
    await tester.pump(const Duration(milliseconds: 32));
    await tester.tap(find.text('ALTIN TERLİK'));
    await tester.pump(const Duration(milliseconds: 32));
    await tester.tap(find.text('KALKAN'));
    await tester.pump(const Duration(milliseconds: 32));

    expect(readArcadeScore(tester), greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('9. Osmantuş (osmantus): opens, taps on beat to score, 3 boosters respond', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    var nowMs = 0;
    await tester.pumpWidget(
      wrapPlayable(
        OsmantusScreen(
          prototypeVisualState: false,
          clockForTesting: () => nowMs,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(OsmantusScreen), findsOneWidget);
    expect(find.text('DIKKIŞ'), findsOneWidget);
    expect(find.text('HALKA +'), findsOneWidget);
    expect(find.text('MİKROFON'), findsOneWidget);

    nowMs = 1600;
    await tester.pump();
    await tester.tap(find.text('İKİLİ TUŞ'));
    await tester.pump();
    expect(find.text('x1'), findsOneWidget);
    expect(readArcadeScore(tester), greaterThan(0));

    final beforeDik = pm.powerCount('dik');
    await tester.tap(find.text('DIKKIŞ'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(pm.powerCount('dik'), beforeDik - 1);

    final beforeRing = pm.powerCount('ring');
    await tester.tap(find.text('HALKA +'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(pm.powerCount('ring'), beforeRing - 1);

    final beforeMic = pm.powerCount('mic');
    await tester.tap(find.text('MİKROFON'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(pm.powerCount('mic'), beforeMic - 1);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('10. Çığlık Böcek (ciglik): opens, flaps through gate to score, 3 boosters respond', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    await tester.pumpWidget(
      wrapPlayable(const ScreamRoachScreen(prototypeVisualState: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(ScreamRoachScreen), findsOneWidget);
    expect(find.text('ZIPLAMA'), findsOneWidget);
    expect(find.text('KALKAN'), findsOneWidget);
    expect(find.text('NİTRO'), findsOneWidget);

    final beforeJump = pm.powerCount('jump');
    await tester.tap(find.text('ZIPLAMA'));
    await tester.pump(const Duration(milliseconds: 32));
    expect(pm.powerCount('jump'), beforeJump - 1);

    final beforeShield = pm.powerCount('shield');
    await tester.tap(find.text('KALKAN'));
    await tester.pump(const Duration(milliseconds: 32));
    expect(pm.powerCount('shield'), beforeShield - 1);

    final beforeNitro = pm.powerCount('nitro');
    await tester.tap(find.text('NİTRO'));
    await tester.pump(const Duration(milliseconds: 32));
    expect(pm.powerCount('nitro'), beforeNitro - 1);

    // Steer the roach toward the first gate's gapCenter and advance frames until it passes and scores
    final pipeFinder = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('obstacle-pipes'),
    );
    final bugFinder = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.contains('assets/bugs/tier'),
    );

    for (var frame = 0; frame < 360; frame++) {
      if (frame % 4 == 0 &&
          pipeFinder.evaluate().isNotEmpty &&
          bugFinder.evaluate().isNotEmpty) {
        final gateCenterY = tester.getRect(pipeFinder.first).center.dy;
        final bugHitboxCenterY = tester.getRect(bugFinder.first).top + 43;
        if (bugHitboxCenterY > gateCenterY - 6) {
          await tester.tapAt(const Offset(215, 420));
        }
      }
      await tester.pump(const Duration(milliseconds: 16));
      if (readArcadeScore(tester) > 0) break;
    }

    expect(readArcadeScore(tester), greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('11. Makarayız (makara): opens, hits notes to score, 3 boosters respond', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pm = ProgressManager();
    final key = GlobalKey<MakarayizScreenState>();
    await tester.pumpWidget(
      wrapPlayable(
        TickerMode(
          enabled: false,
          child: MakarayizScreen(key: key, prototypeVisualState: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MakarayizScreen), findsOneWidget);
    expect(find.text('BEAT DONDUR'), findsOneWidget);
    expect(find.text('OTO MAKARA'), findsOneWidget);
    expect(find.text('PUAN X2'), findsOneWidget);

    final state = key.currentState!;
    state.advance(200);
    final notes = state.debugNotes.toList()
      ..sort((a, b) => a.hitMs.compareTo(b.hitMs));
    final firstNote = notes.first;
    state.advance(max(0, firstNote.hitMs - state.debugNow));
    state.tryHit(firstNote.lane);
    await tester.pump();
    expect(state.debugScore, greaterThan(0));

    final beforeBeat = pm.powerCount('beat');
    await tester.tap(find.text('BEAT DONDUR'));
    await tester.pump();
    expect(pm.powerCount('beat'), beforeBeat - 1);

    final beforeAuto = pm.powerCount('auto');
    await tester.tap(find.text('OTO MAKARA'));
    await tester.pump();
    expect(pm.powerCount('auto'), beforeAuto - 1);

    final beforeX2 = pm.powerCount('x2');
    await tester.tap(find.text('PUAN X2'));
    await tester.pump();
    expect(pm.powerCount('x2'), beforeX2 - 1);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  });
}
