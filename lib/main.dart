import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/adaptive_quality_scaler.dart';
import 'services/audio_manager.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/daily_challenge_service.dart';
import 'services/energy_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/iap_service.dart';
import 'services/leaderboard_service.dart';
import 'services/progress_manager.dart';
import 'services/zero_jank_preloader.dart';
import 'theme/lululu_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  AdaptiveQualityScaler.instance.bootstrap();
  unawaited(ZeroJankPreloader.instance.start());
  AudioManager().initialize();

  // Paint immediately — never sit on white native splash waiting for I/O.
  runApp(const _BootApp());
}

class _BootApp extends StatefulWidget {
  const _BootApp();

  @override
  State<_BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<_BootApp> {
  Widget? _home;
  String? _bootError;
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    // Splash önce gösterilir; onDone → mevcut _boot akışı başlar.
  }

  void _onSplashDone() {
    setState(() => _splashDone = true);
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await ProgressManager().load().timeout(const Duration(seconds: 3));
      await FirebaseBootstrap.ensureInitialized()
          .timeout(const Duration(seconds: 4));
      await AuthService.instance.load().timeout(const Duration(seconds: 3));
      unawaited(EnergyService.instance.load());
      unawaited(ChatService.instance.ensureLoaded());
      unawaited(LeaderboardService.instance.ensureLoaded());
      unawaited(DailyChallengeService.instance.ensureLoaded());
      unawaited(CloudSyncService.instance.ensureLoaded());
      unawaited(IapService.instance.ensureLoaded());
      final onboardingDone = await OnboardingScreen.isDone()
          .timeout(const Duration(seconds: 2), onTimeout: () => true);
      if (!mounted) return;
      setState(() {
        _home = onboardingDone
            ? const HomeShell()
            : const OnboardingScreen();
      });
    } catch (e, st) {
      debugPrint('[lululu] boot fallback: $e\n$st');
      if (!mounted) return;
      setState(() {
        _bootError = '$e';
        _home = const HomeShell();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Önce animasyonlu açılış; bitince mevcut boot akışı.
    if (!_splashDone) {
      return MaterialApp(
        title: 'Lülülü Hamamböceği',
        debugShowCheckedModeBanner: false,
        theme: buildLululuTheme(),
        home: SplashScreen(onDone: _onSplashDone),
      );
    }
    return MaterialApp(
      title: 'Lülülü Hamamböceği',
      debugShowCheckedModeBanner: false,
      theme: buildLululuTheme(),
      home: _home ??
          Scaffold(
            backgroundColor: LululuColors.carbonVoid,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: LululuColors.liquidGold,
                  ),
                  if (_bootError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Yükleniyor…',
                      style: TextStyle(color: LululuColors.mutedTitanium),
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }
}
