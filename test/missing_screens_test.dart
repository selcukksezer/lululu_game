import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/campaign_map_screen.dart';
import 'package:lululu_game/screens/chat_lobby_screen.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/onboarding_screen.dart';
import 'package:lululu_game/screens/settings_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

// Madde 99 [P1]: widget testi olmayan 4 ekranın kurulum + temel
// etkileşim testleri. SAVUNMACI yazıldı: ekranlar başka ajanlarca da
// düzenleniyor; çekirdek öğelerin varlığı ve temel etkileşim denetlenir,
// değişebilecek pazarlama metinleri kilitlenmez.

// 12D1: 6C deseni — gerçek fontlar setUpAll'da yüklenir; yoksa ilk
// widget testinde font yükleme bildirimi (sistem-fontu transient
// callback) sökümde asılı kalıp scheduler hatasına yol açar. Bu
// dosyadaki Settings/Onboarding/ChatLobby-mount testleri HEAD'de de
// aynı hatayla düşüyordu (baz karşılaştırmasıyla doğrulandı).
// (test/campaign_hub_flow_test.dart `_loadCustomFonts` ile aynı.)
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

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    wrapWithL10n(screen, theme: buildLululuTheme()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

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
    SharedPreferences.setMockInitialValues({});
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
  });

  group('Settings', () {
    testWidgets('mounts with title and core toggle rows', (tester) async {
      await _pumpScreen(tester, const SettingsScreen());
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('AYARLAR'), findsOneWidget);
      // Çekirdek anahtar satırları mevcut.
      expect(find.text('Ses Efektleri'), findsOneWidget);
      expect(find.text('Titreşim'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('extended options variant mounts without errors', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        const SettingsScreen(showExtendedOptions: true),
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('Onboarding', () {
    testWidgets('mounts with pager and primary actions', (tester) async {
      await _pumpScreen(tester, const OnboardingScreen());
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(PageView), findsWidgets);
      expect(find.text('SONRAKİ ADIM →'), findsOneWidget);
      expect(find.text('Atla'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('next button advances the pager', (tester) async {
      await _pumpScreen(tester, const OnboardingScreen());
      await tester.tap(find.text('SONRAKİ ADIM →'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final pager = tester.widget<PageView>(find.byType(PageView).first);
      expect(pager.controller, isNotNull);
      expect(pager.controller!.page, greaterThan(0.5));
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('skip finishes onboarding and opens the hub', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _pumpScreen(tester, const OnboardingScreen());
      await tester.tap(find.text('Atla'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(OnboardingScreen.prefsKey), isTrue);
      expect(find.byType(HomeShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('ChatLobby', () {
    testWidgets('mounts with composer and send action', (tester) async {
      await _pumpScreen(tester, const ChatLobbyScreen());
      expect(find.byType(ChatLobbyScreen), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('sending a message shows it and clears the composer', (
      tester,
    ) async {
      await _pumpScreen(tester, const ChatLobbyScreen());
      const message = 'merhaba test 123';
      await tester.enterText(find.byType(TextField), message);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 12D1: gönderim ChatService üzerinden gider; şart onayı yoksa
      // önce şart diyaloğu açılır — kabulde gönderim bir kez tekrar
      // denenir ve mesaj servisten okunarak görünür.
      expect(find.text('Sohbet kuralları'), findsOneWidget);
      await tester.tap(find.text('Kabul ediyorum'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(message), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text ?? '', isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('CampaignMap', () {
    testWidgets('mounts with chapter selector and level grid', (tester) async {
      await _pumpScreen(tester, const CampaignMapScreen());
      expect(find.byType(CampaignMapScreen), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      // Taze kayıtta yalnız 1. bölüm açık: ızgarada '1' numaralı karo var.
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('switching chapter swaps the level grid', (tester) async {
      await _pumpScreen(tester, const CampaignMapScreen());
      // 2. bölüm çipi (👑 rozeti) — bölüm adı metnine bağlanılmaz.
      await tester.tap(find.text('👑'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(GridView), findsOneWidget);
      // 2. bölümün tüm seviyeleri kilitli: ızgarada numaralı karo kalmaz.
      expect(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('1'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('tapping the open level shows its start sheet', (tester) async {
      await _pumpScreen(tester, const CampaignMapScreen());
      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.text('1'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('BÖLÜM 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
