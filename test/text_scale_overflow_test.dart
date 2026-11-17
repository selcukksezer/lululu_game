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
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/screens/campaign_map_screen.dart';
import 'package:lululu_game/screens/chat_lobby_screen.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/leaderboard_screen.dart';
import 'package:lululu_game/screens/modes_screen.dart';
import 'package:lululu_game/screens/profile_screen.dart';
import 'package:lululu_game/screens/settings_screen.dart';
import 'package:lululu_game/screens/tasks_screen.dart';
import 'package:lululu_game/services/adaptive_quality_scaler.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

// Madde 74 [P1]: 1.3x sistem yazı boyutu (erişilebilirlik) taşma denetimi.
// Kritik ekranlar gerçek boyut + TextScaler 1.3 ile kurulur; FittedBox /
// küçültme maskesi YOKTUR. Taşma bulan test kırmızıya döner — düzeltme
// lib tarafında yapılır (bu dosya yalnız denetler).

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

  const deviceSizes = <String, Size>{
    '360x640 (Android Küçük)': Size(360, 640),
    '430x932 (iPhone 16 Pro Max)': Size(430, 932),
  };

  final screens = <String, Widget Function()>{
    'hub': () => const HomeShell(),
    'modes': () => const ModesScreen(),
    'game (suika)': () => GameScreen(
          level: CampaignDatabase.kitchenLevel1,
          arcade: true,
        ),
    'balon': () => const BalloonPopScreen(),
    'match3': () => const Match3Screen(),
    'stack': () => const StackDropScreen(),
    'terlik': () => const TerlikTapScreen(),
    'scores': () => const LeaderboardScreen(),
    'tasks': () => const TasksScreen(),
    'profile': () => const ProfileScreen(),
    'settings': () => const SettingsScreen(),
    'campaign': () => const CampaignMapScreen(),
    'chat-lobby': () => const ChatLobbyScreen(),
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

    group('TextScaler 1.3 [$deviceLabel]', () {
      for (final screenEntry in screens.entries) {
        final screenName = screenEntry.key;
        final builder = screenEntry.value;

        testWidgets('$screenName renders without overflow at 1.3x text scale ($deviceLabel)', (
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

          try {
            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildLululuTheme(),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    devicePixelRatio: 1.0,
                    textScaler: const TextScaler.linear(1.3),
                    padding: const EdgeInsets.only(top: 35.4, bottom: 24),
                    viewPadding: const EdgeInsets.only(top: 35.4, bottom: 24),
                  ),
                  child: TickerMode(
                    enabled: false,
                    child: builder(),
                  ),
                ),
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
                'Screen "$screenName" at $deviceLabel with 1.3x text scale had errors/overflows:\n'
                '${flutterErrors.join('\n---\n')}',
          );
        });
      }
    });
  }
}
