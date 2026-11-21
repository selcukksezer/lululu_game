import 'dart:io';

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
import 'package:lululu_game/screens/auth_screen.dart';
import 'package:lululu_game/screens/chat_screen.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/leaderboard_screen.dart';
import 'package:lululu_game/screens/modes_screen.dart';
import 'package:lululu_game/screens/online_screen.dart';
import 'package:lululu_game/screens/profile_screen.dart';
import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/screens/splash_screen.dart';
import 'package:lululu_game/screens/studio_screens.dart';
import 'package:lululu_game/screens/tasks_screen.dart';
import 'package:lululu_game/screens/tiers_screen.dart';
import 'package:lululu_game/services/adaptive_quality_scaler.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/shop_dialog.dart';

import 'test_helpers.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceSizes = <String, Size>{
    '360x640 (Android Küçük)': Size(360, 640),
    '375x667 (iPhone SE / 8)': Size(375, 667),
    '390x844 (iPhone 14)': Size(390, 844),
    '393x852 (iPhone 15/16)': Size(393, 852),
    '412x915 (Android Büyük)': Size(412, 915),
    '430x932 (iPhone 16 Pro Max)': Size(430, 932),
  };

  final screens = <String, Widget Function()>{
    // Ana Ekranlar
    'splash': () => SplashScreen(onDone: () {}),
    'hub': () => const HomeShell(),
    'modes': () => const ModesScreen(),
    'result': () => const GameResultScreen(
          score: 1741,
          bestScore: 4820,
          bestCombo: 6,
          merges: 18,
          coins: 0,
          stars: 2,
        ),
    'shop': () => const ShopScreen(embedded: true),
    'scores': () => const LeaderboardScreen(),
    'tasks': () => const TasksScreen(),
    'profile': () => const ProfileScreen(),
    'tiers': () => const TiersScreen(),
    'studio-watch': () => const StudioWatchScreen(),
    'studio-create': () => const StudioCreateScreen(),
    'studio-upload': () => const StudioUploadScreen(),
    'studio-gif': () => const StudioGifScreen(),
    'studio-downloads': () => const StudioDownloadsScreen(),
    'account': () => const AuthScreen(),
    'online': () => const OnlineScreen(),
    'chat': () => const ChatScreen(),
    // 11 Oyun Modu
    'game (suika)': () => GameScreen(
          level: CampaignDatabase.kitchenLevel1,
          arcade: true,
        ),
    'm2048': () => const Grid2048Screen(),
    'balon': () => const BalloonPopScreen(),
    'match3': () => const Match3Screen(),
    'bagla': () => const ConnectPopScreen(),
    'stack': () => const StackDropScreen(),
    'terlik': () => const TerlikTapScreen(),
    'yuva': () => const YuvaDefenseScreen(),
    'osmantus': () => const OsmantusScreen(),
    'ciglik': () => const ScreamRoachScreen(),
    'makara': () => const MakarayizScreen(),
  };

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
      'LululuCoinBalance': 12450,
      'LululuEnergyCount': 5,
      'LululuDiamondBalance': 86,
      'LululuAuthV1':
          '{"uid":"apple-123","displayName":"Apple Oyuncu","provider":"apple"}',
      'lululu_coins': 12450,
    });
    await ProgressManager().load();
    await LeaderboardService.instance.ensureLoaded();
    AdaptiveQualityScaler.instance.bootstrap(forceTier: QualityTier.medium);
  });

  for (final deviceEntry in deviceSizes.entries) {
    final deviceLabel = deviceEntry.key;
    final size = deviceEntry.value;

    group('Responsive Check [$deviceLabel]', () {
      for (final screenEntry in screens.entries) {
        final screenName = screenEntry.key;
        final builder = screenEntry.value;

        testWidgets('$screenName renders without overflow or exception at $deviceLabel', (
          WidgetTester tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final flutterErrors = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (FlutterErrorDetails details) {
            final msg = details.exceptionAsString();
            if (msg.contains('Unable to load asset')) {
              return;
            }
            flutterErrors.add(msg);
          };

          // Madde 68: GERÇEK boyut + 1.0 yazı ölçeği, FittedBox yok.
          // Eski harness (max(430,932) + FittedBox scaleDown + 0.85)
          // küçük ekran taşmalarını maskeliyordu; ekranlar gerçek
          // viewport'ta, gerçek ölçekte kurulur. Yeni taşma bulunursa
          // bu test kırmızıya döner — düzeltme lib tarafında yapılır.
          try {
            await tester.pumpWidget(
              wrapWithL10n(
                MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    devicePixelRatio: 1.0,
                    textScaler: const TextScaler.linear(1.0),
                    padding: const EdgeInsets.only(top: 35.4, bottom: 24),
                    viewPadding: const EdgeInsets.only(top: 35.4, bottom: 24),
                  ),
                  child: TickerMode(
                    enabled: false,
                    child: builder(),
                  ),
                ),
                debugShowCheckedModeBanner: false,
                theme: buildLululuTheme(),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));

            final pendingEx = tester.takeException();
            if (pendingEx != null) {
              flutterErrors.add(pendingEx.toString());
            }

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 200));
          } finally {
            FlutterError.onError = prevOnError;
          }

          expect(
            flutterErrors,
            isEmpty,
            reason:
                'Screen "$screenName" at $deviceLabel had errors/overflows:\n'
                '${flutterErrors.join('\n---\n')}',
          );
        });
      }
    });
  }
}
