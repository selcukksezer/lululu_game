import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/campaign_map_screen.dart';
import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/campaign_progression_service.dart';
import 'package:lululu_game/services/daily_challenge_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/online_notify_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

/// 6C deseni: gerçek fontlar setUpAll'da yüklenir — ilk widget
/// testinde font yükleme bildirimi (sistem-fontu transient callback)
/// sökümde asılı kalıp scheduler hatasına yol açmasın.
Future<void> _loadCustomFonts() async {
  final fontMap = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
    ],
    'Bangers': [
      'assets/fonts/Bangers-Regular.ttf',
    ],
    'Nunito': [
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

// Dalga 12B — Kampanya tek yüzeyi: hub kartı -> 80 seviyeli harita ->
// seviye dokunuşu (başlangıç modalı) -> geri düğmesi -> hub.
// Sheet kaldırıldı; tek yüzey CampaignMapScreen'dir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadCustomFonts();
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
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    ProgressManager.instance.coins = 1000;
    ProgressManager.instance.modeHighScores.clear();
    await CampaignProgressionService.instance.resetForTesting();
    await CampaignProgressionService.instance.load();
    await EnergyService.instance.load();
    await DailyChallengeService.instance.load();
    await OnlineNotifyService.instance.load();
  });

  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapWithL10n(
        const Scaffold(body: GameSelectorScreen()),
        theme: buildLululuTheme(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Sliver içeriği görünüm dışındayken ağaçta yoktur: bulunana dek
  /// sürükleyerek kaydır (hub_catalog_test deseni), sonra görünür kıl.
  Future<void> scrollToFinder(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 16 && finder.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -280),
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    // Boş ağaçta drenaj: sistem-fontu transient callback'i test
    // sonunda asılı kalıp scheduler hatasına yol açabiliyor
    // (campaign_progression_test K3a testinde aynı dalgalanma);
    // ağaç boşken pumpAndSettle anında durulur.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
  }

  testWidgets('hub kampanya kartı haritayı açar, geri düğmesi hub\'a döner',
      (tester) async {
    await pumpHub(tester);
    expect(find.byType(GameSelectorScreen), findsOneWidget);

    final entry = find.byKey(const Key('hub_campaign_entry'));
    await scrollToFinder(tester, entry);
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    expect(find.byType(CampaignMapScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    expect(find.byType(CampaignMapScreen), findsNothing);
    expect(find.byType(GameSelectorScreen), findsOneWidget);

    await tearDownTree(tester);
  });

  testWidgets(
      'haritada seviye dokunuşu başlangıç modalını açar, geri düğmesi önceki ekrana döner',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                key: const Key('flow_home_open'),
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CampaignMapScreen(),
                  ),
                ),
                child: const Text('OPEN_MAP'),
              ),
            ),
          ),
        ),
        theme: buildLululuTheme(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const Key('flow_home_open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CampaignMapScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 1. seviye açık: dokunuş başlangıç modalını açar (oyun başlamaz,
    // enerji tüketilmez — OYNA'ya basılmadı).
    await tester.tap(
      find.descendant(
        of: find.byType(GridView),
        matching: find.text('1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('BÖLÜM 1'), findsOneWidget);

    // Modalı perdeye dokunarak kapat.
    await tester.tapAt(const Offset(215, 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('BÖLÜM 1'), findsNothing);

    // Geri düğmesi haritadan çıkar, önceki ekrana döner.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byType(CampaignMapScreen), findsNothing);
    expect(find.byKey(const Key('flow_home_open')), findsOneWidget);

    await tearDownTree(tester);
  });
}
