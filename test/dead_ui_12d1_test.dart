import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_localizations.dart';
import 'package:lululu_game/navigation/game_routes.dart';
import 'package:lululu_game/screens/bug_video_hub_screen.dart';
import 'package:lululu_game/screens/chat_lobby_screen.dart';
import 'package:lululu_game/screens/chat_screen.dart';
import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/screens/online_screen.dart';
import 'package:lululu_game/screens/sticker_gif_screen.dart';
import 'package:lululu_game/screens/studio_screens.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/chat_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

// 12D1 — Ölü UI'yı canlandır: ChatLobby + BugVideoHub + StickerGif.
// Rota çözümü, rota üzerinden açılış, geri dönüş, gerçek veri
// görünürlüğü ve görünür giriş noktaları denetlenir.

Future<void> _pumpRouteProbe(
  WidgetTester tester,
  String routeName,
) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback:
          AppLocalizations.localeResolutionCallback,
      theme: buildLululuTheme(),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed(routeName),
              child: const Text('ANA SAYFA'),
            ),
          ),
        ),
      ),
      onGenerateRoute: LululuRoutes.onGenerateRoute,
    ),
  );
  await tester.pump();
  await tester.tap(find.text('ANA SAYFA'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback:
          AppLocalizations.localeResolutionCallback,
      theme: buildLululuTheme(),
      home: screen,
      onGenerateRoute: LululuRoutes.onGenerateRoute,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// 6C deseni: gerçek fontlar setUpAll'da yüklenir — ilk widget
/// testinde font yükleme bildirimi (sistem-fontu transient callback)
/// sökümde asılı kalıp scheduler hatasına yol açmasın.
/// (test/campaign_hub_flow_test.dart `_loadCustomFonts` ile aynı.)
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

/// Test sonu boşaltma (missing_screens_test düzeni): bekleyen
/// kareleri çalıştırıp ağacı küçültür — rota geçişi sonrası
/// zamanlayıcı kalıntısı test sonu hatası vermez.
Future<void> _finish(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
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
    // text_scale_overflow_test ile aynı: sistem-fontu değişim
    // mesajını yut — aksi hâlde rota geçişli testlerde
    // "animation is still running" zamanlayıcı hatası verir.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    await ChatService.instance.clearLocalData();
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
  });

  group('12D1 rotalar', () {
    test('üç rota da doğru ekrana çözülür', () {
      expect(
        LululuRoutes.resolveScreen(LululuRoutes.chatLobby),
        isA<ChatLobbyScreen>(),
      );
      expect(
        LululuRoutes.resolveScreen(LululuRoutes.bugVideoHub),
        isA<BugVideoHubScreen>(),
      );
      expect(
        LululuRoutes.resolveScreen(LululuRoutes.stickerGif),
        isA<StickerGifScreen>(),
      );
      // Derin bağlantı varyantları da aynı ekrana çözülür.
      expect(
        LululuRoutes.resolveScreen('/chat-lobby'),
        isA<ChatLobbyScreen>(),
      );
      expect(
        LululuRoutes.resolveScreen('bug-video-hub/'),
        isA<BugVideoHubScreen>(),
      );
    });
  });

  group('12D1 ChatLobby rota üzerinden', () {
    testWidgets('açılır, gerçek veri görünür, geri döner', (
      tester,
    ) async {
      await _pumpRouteProbe(tester, LululuRoutes.chatLobby);
      expect(find.byType(ChatLobbyScreen), findsOneWidget);
      expect(find.text('Sohbet Lobisi'), findsOneWidget);
      // Servis tohum akışı: sahte mock metinler değil, ChatService
      // varsayılan akışındaki gerçek tohum mesajlar.
      expect(
        find.text('Genel Lobi sohbetine hoş geldin! Kombolarını paylaş.'),
        findsOneWidget,
      );
      // Oyuncu satırı: tohum akışındaki gerçek yazarlar (her yazar
      // hem oyuncu satırında hem mesaj balonunda görünür: 2 kez).
      expect(find.text('Kongo Lideri'), findsNWidgets(2));
      expect(find.text('Hamam Diva'), findsNWidgets(2));
      // Mock oyuncular artık yok.
      expect(find.text('HamamCan_34'), findsNothing);
      expect(find.text('MakaraMehmet'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      // Geri düğmesi ana sayfaya döner.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ANA SAYFA'), findsOneWidget);
      expect(find.byType(ChatLobbyScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('gönderim şart diyaloğundan geçip servise yazar', (
      tester,
    ) async {
      await _pumpRouteProbe(tester, LululuRoutes.chatLobby);
      const message = 'lobi test 12d1';
      await tester.enterText(find.byType(TextField), message);
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Sohbet kuralları'), findsOneWidget);
      await tester.tap(find.text('Kabul ediyorum'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(message), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text ?? '', isEmpty);
      // Mesaj serviste kalıcıdır (yerel liste değil).
      expect(
        ChatService.instance.hasUserMessages(ChatChannel.lobby),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('kanal değişimi mesajları servisten yeniler', (
      tester,
    ) async {
      await _pumpRouteProbe(tester, LululuRoutes.chatLobby);
      // Klan kanalı tohum akışı lobi tohumundan farklıdır.
      await tester.tap(find.text('Takım & Klan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text(
          'Lonca turnuvası cumartesi 20.00\'da. Herkes arenada olsun!',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Genel Lobi sohbetine hoş geldin! Kombolarını paylaş.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });

  group('12D1 BugVideoHub rota üzerinden', () {
    testWidgets('izle sekmesi StudioWatchScreen açar, geri döner', (
      tester,
    ) async {
      await _pumpRouteProbe(tester, LululuRoutes.bugVideoHub);
      expect(find.byType(BugVideoHubScreen), findsOneWidget);
      expect(find.byType(StudioWatchScreen), findsOneWidget);
      // Gerçek video listesi (stüdyo izle akışındaki kartlar) görünür:
      // başlık hem öne çıkan kartta hem listede geçer (2 kez).
      expect(
        find.text('Böcek Birleştirme Rekoru! 51.200 Puan'),
        findsNWidgets(2),
      );
      // Stüdyo geri düğmesi (özel görsel düğme — pageBack
      // BackButton arar, burada yok; Semantics etiketiyle dokunulur).
      await tester.tap(find.bySemanticsLabel('Geri'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ANA SAYFA'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    // 12D1 notu: StudioCreateScreen'deki Slider, semantics açıkken
    // framework assertion'ı patlatır (önceden var olan sorun —
    // responsive_screens_test studio-create de HEAD'de aynı
    // hatayla düşer). Bu test yalnız hub yönlendirmesini denetler;
    // semantics kapalı koşulur.
    testWidgets('yap sekmesi StudioCreateScreen açar', (tester) async {
      await _pumpScreen(
        tester,
        const BugVideoHubScreen(initial: BugVideoTab.create),
      );
      expect(find.byType(StudioCreateScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    }, semanticsEnabled: false);
  });

  group('12D1 StickerGif rota üzerinden', () {
    testWidgets('StudioGifScreen açar, geri döner', (tester) async {
      await _pumpRouteProbe(tester, LululuRoutes.stickerGif);
      expect(find.byType(StickerGifScreen), findsOneWidget);
      expect(find.byType(StudioGifScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Geri'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('ANA SAYFA'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });

  group('12D1 görünür giriş noktaları', () {
    testWidgets('ChatScreen başlığındaki lobi düğmesi lobiyi açar', (
      tester,
    ) async {
      await _pumpScreen(tester, const ChatScreen());
      expect(find.byType(ChatScreen), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Sohbet Lobisi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ChatLobbyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('OnlineScreen lobi kartı lobiyi açar', (tester) async {
      await _pumpScreen(tester, const OnlineScreen());
      expect(find.byType(OnlineScreen), findsOneWidget);
      await tester.tap(find.text('Sohbet Lobisi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ChatLobbyScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets('ana sayfa stüdyo şeridi hub ekranlarını açar', (
      tester,
    ) async {
      await _pumpScreen(tester, const GameSelectorScreen());
      // Video İzle kartı -> BugVideoHub (izle). Kaydırılabilir açıkça
      // verilir: varsayılan `find.byType(Scrollable)` şerit kurulunca
      // 2 eşleşir (dikey + yatay).
      await tester.scrollUntilVisible(
        find.text('VİDEO İZLE'),
        200,
        scrollable: find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('VİDEO İZLE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BugVideoHubScreen), findsOneWidget);
      expect(find.byType(StudioWatchScreen), findsOneWidget);
      // Geri düğmesi yalnız açılan stüdyo ekranında aranır (alttaki
      // ana sayfa ağacında da 'Geri' etiketli düğme olabilir).
      await tester.tap(
        find.descendant(
          of: find.byType(StudioWatchScreen),
          matching: find.bySemanticsLabel('Geri'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // GIF kartı -> StickerGif (yatay şerit ListView'de kaydırılır).
      await tester.scrollUntilVisible(
        find.text('GIF OLUŞTUR'),
        200,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('GIF OLUŞTUR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StickerGifScreen), findsOneWidget);
      expect(find.byType(StudioGifScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });
  });
}
