import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'navigation/game_routes.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/adaptive_quality_scaler.dart';
import 'services/app_lifecycle_guard.dart';
import 'services/audio_manager.dart';
import 'services/auth_service.dart';
import 'services/campaign_progression_service.dart';
import 'services/chat_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/daily_challenge_service.dart';
import 'services/energy_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/firebase_options.dart';
import 'services/iap_service.dart';
import 'services/leaderboard_service.dart';
import 'services/progress_manager.dart';
import 'services/zero_jank_preloader.dart';
import 'theme/lululu_theme.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Madde 53 [P1]: ImageCache üst sınırları — HD görseller tam
      // çözünürlükte decode edilip sınırsız tutulmasın. Sayı sınırı
      // Flutter varsayılanı 1000'den 100'e çekildi; bayt sınırı 100 MB
      // olarak açıkça sabitlendi.
      imageCache.maximumSize = 100;
      imageCache.maximumSizeBytes = 100 << 20; // 100 MB
      _installGlobalErrorHandlers();
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

      // Yaşam döngüsü koruması: arka plan/ön plan geçişleri en baştan
      // dinlenir (gözlemci initialize() içinde eşzamanlı bağlanır).
      unawaited(AppLifecycleGuard.instance.initialize());

      // Madde 54 [P1]: bootstrap() yerine initialize(). RAM değeri
      // pubspec'te device_info_plus vb. bağımlılık olmadığı için
      // temin edilemiyor; null → Medium başlangıç katmanı (mevcut
      // davranışla aynı). TODO(W6-1): RAM okuyan bağımlılık
      // eklendiğinde gerçek toplam RAM (MB) buraya bağlanacak; yeni
      // bağımlılık eklenmeden bu TODO kapatılmamalı.
      AdaptiveQualityScaler.instance.initialize(totalRamMb: null);
      unawaited(ZeroJankPreloader.instance.start());
      AudioManager().initialize();

      // Paint immediately — never sit on white native splash waiting for I/O.
      runApp(const _BootApp());
    },
    (Object error, StackTrace stack) {
      // Yakalanamayan asenkron hata: kaydet, çökertme.
      debugPrint('[lululu] yakalanamayan hata (zone): $error\n$stack');
    },
  );
}

/// Global hata yakalama: Flutter çerçeve hataları ve yakalanamayan asenkron
/// hatalar kaydedilir; hatalı alt ağaç yerine zarif yer tutucu gösterilir.
/// Çökme yerine kayıt + zarif davranış (madde 64).
void _installGlobalErrorHandlers() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint(
      '[lululu] FlutterError: ${details.exceptionAsString()}',
    );
    previousOnError?.call(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError =
      (Object error, StackTrace stack) {
    debugPrint('[lululu] yakalanamayan asenkron hata: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint(
      '[lululu] ErrorWidget: ${details.exceptionAsString()}',
    );
    // ErrorWidget.builder'a BuildContext ulaşmaz; cihaz diline göre
    // tablo doğrudan çözümlenir (uygulamanın dil seçimiyle aynı kural:
    // EN ise EN, diğer dillerde TR).
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: LululuColors.carbonVoid,
        child: Center(
          child: Text(
            AppLocalizations.lookup(
              WidgetsBinding.instance.platformDispatcher.locale,
            ).errorGeneric,
            style: const TextStyle(color: LululuColors.mutedTitanium),
          ),
        ),
      ),
    );
  };
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
  bool _onboardingTimedOut = false;
  bool _booting = false;
  // S2#8 devamı (W13-3): AudioManager.dispose() çağrı noktası tekrar
  // koruması — dispose() idempotent'tır, bu bayrak çağrı tarafını da
  // çift-çağrıya karşı güvenli kılar.
  bool _audioManagerDisposed = false;

  @override
  void initState() {
    super.initState();
    // Firebase hazır olunca bekleyen bulut kuyruğunu boşalt (madde 47).
    // ValueNotifier aynı değerde bildirim göndermez; dinleyici yalnızca
    // false→true geçişinde tetiklenir.
    FirebaseBootstrap.availableNotifier.addListener(
      _onFirebaseAvailabilityChanged,
    );
    // Splash sırasında kritik görselleri <2ms frame bütçesiyle precacheImage'e al.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ZeroJankPreloader.instance.precacheCriticalAssets(context));
    });
  }

  @override
  void dispose() {
    FirebaseBootstrap.availableNotifier.removeListener(
      _onFirebaseAvailabilityChanged,
    );
    // S2#8 devamı (W13-3): AudioManager singleton havuzunu yalnızca
    // kök widget sökülürken bırak. Pause/resume yollarına bağlanmaz:
    // arka plan geçişlerini AppLifecycleGuard stopAll + sessize alma
    // ile yönetir ve detached bu kod tabanında duraklatma sayılır
    // (resumed'da ses geri yüklenir). Kök dispose'u oyun sırasında
    // hiç tetiklenmez, bu yüzden ses yanlışlıkla kesilmez.
    if (!_audioManagerDisposed) {
      _audioManagerDisposed = true;
      AudioManager.instance.dispose();
    }
    super.dispose();
  }

  void _onFirebaseAvailabilityChanged() {
    if (!FirebaseBootstrap.availableNotifier.value) return;
    unawaited(_flushQueueAfterLoad());
  }

  /// Dinleyici tetikli flush kuyruk yüklenmeden çalışmasın: önce
  /// `ensureLoaded()` (paylaşımlı; `_boot()`'taki çağrıyla aynı
  /// yükleme), sonra flush. Kuyruk yüklenmeden yapılan flush boş
  /// kuyrukla çalışır ve `ensureLoaded()` ile yarışırdı (R5).
  Future<void> _flushQueueAfterLoad() async {
    await CloudSyncService.instance.ensureLoaded();
    await CloudSyncService.instance.flushPending();
  }

  void _onSplashDone() {
    setState(() => _splashDone = true);
    unawaited(_boot());
  }

  /// Firebase başlatma: tek deneme + yalnızca yapılandırılmışken gecikmeli
  /// bir yeniden deneme. Yapılandırılmamış (yerel) modda boot geciktirilmez.
  Future<bool> _ensureFirebaseWithRetry() async {
    bool ready = false;
    try {
      ready = await FirebaseBootstrap.ensureInitialized()
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[lululu] Firebase ilk deneme başarısız: $e');
      ready = false;
    }
    if (!ready && DefaultFirebaseOptions.isConfigured) {
      await Future.delayed(const Duration(seconds: 2));
      if (FirebaseBootstrap.ready) return true;
      try {
        ready = await FirebaseBootstrap.ensureInitialized()
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[lululu] Firebase yeniden deneme başarısız: $e');
        ready = false;
      }
    }
    return ready;
  }

  Future<void> _boot() async {
    if (_booting) return;
    _booting = true;
    if (mounted) {
      setState(() {
        _bootError = null;
        _onboardingTimedOut = false;
        _home = null;
      });
    }
    try {
      await ProgressManager().load().timeout(const Duration(seconds: 3));
      // Kampanya ilerlemesi (sandık/boss kayıtları) PM senkronu gerektirir:
      // PM yüklenmeden önce çağrılmamalı (W55-4 / R1).
      await CampaignProgressionService.instance
          .load()
          .timeout(const Duration(seconds: 3));
      final firebaseReady = await _ensureFirebaseWithRetry();
      await AuthService.instance.load().timeout(const Duration(seconds: 3));
      // Yükleme yarışı (şüphe 1): enerji boot'ta beklenir; bekletilmeyen
      // load() bulut birleştirmenin erken yazısını ezebilirdi.
      await EnergyService.instance.load();
      unawaited(ChatService.instance.ensureLoaded());
      unawaited(LeaderboardService.instance.ensureLoaded());
      unawaited(DailyChallengeService.instance.ensureLoaded());
      // Kuyruk belleğe yüklendikten sonra, Firebase hazırsa boşalt.
      await CloudSyncService.instance.ensureLoaded();
      if (firebaseReady) {
        unawaited(CloudSyncService.instance.flushPending());
      }
      unawaited(IapService.instance.ensureLoaded());
      final bool onboardingDone;
      try {
        onboardingDone = await OnboardingScreen.isDone()
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // Sessizce "tamam" sayma: yeniden deneme ekranı göster (madde 66).
        debugPrint(
          '[lululu] onboarding durumu zaman aşımı — yeniden deneme sunuluyor',
        );
        if (!mounted) return;
        setState(() => _onboardingTimedOut = true);
        return;
      }
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
    } finally {
      _booting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget activeChild;
    final String switcherKey;
    if (!_splashDone) {
      switcherKey = 'splash';
      activeChild = SplashScreen(
        key: const ValueKey('scr-splash'),
        onDone: _onSplashDone,
      );
    } else if (_onboardingTimedOut) {
      switcherKey = 'onboarding-timeout';
      activeChild = _buildOnboardingTimeoutScreen();
    } else if (_home == null) {
      switcherKey = 'boot-loading';
      activeChild = Scaffold(
        key: const ValueKey('scr-boot-loading'),
        backgroundColor: LululuColors.carbonVoid,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: LululuColors.liquidGold,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.loading,
                style: const TextStyle(color: LululuColors.mutedTitanium),
              ),
            ],
          ),
        ),
      );
    } else if (_bootError != null) {
      switcherKey = 'home-with-warning';
      activeChild = _buildHomeWithBootWarning(_home!);
    } else {
      switcherKey = 'home';
      activeChild = _home!;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ZeroJankPreloader.instance.notePointerDown(),
      onPointerUp: (_) => ZeroJankPreloader.instance.notePointerUp(),
      onPointerCancel: (_) => ZeroJankPreloader.instance.notePointerUp(),
      child: MaterialApp(
        // S2#46: marka adı tek biçim — AndroidManifest, Info.plist ve
        // web/index.html ile aynı: 'LÜLÜLÜ'.
        title: 'LÜLÜLÜ',
        debugShowCheckedModeBanner: false,
        theme: buildLululuTheme(),
        // Madde 95 [P1]: yerelleştirme altyapısı — EN + TR. Dil cihaz
        // dilinden alınır; desteklenmeyen dilde varsayılan TR'dir
        // (AppLocalizations.localeResolutionCallback).
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback:
            AppLocalizations.localeResolutionCallback,
        onGenerateRoute: LululuRoutes.onGenerateRoute,
        onUnknownRoute: LululuRoutes.onUnknownRoute,
        home: AnimatedSwitcher(
          duration: LululuMotion.screenTransitionDuration,
          switchInCurve: LululuMotion.smoothOut,
          switchOutCurve: Curves.easeInCubic,
          child: RepaintBoundary(
            key: ValueKey<String>(switcherKey),
            child: activeChild,
          ),
        ),
      ),
    );
  }

  /// Onboarding durumu zaman aşımında: sessizce atlama, yeniden dene.
  /// Kullanıcı isterse açık seçimle ana ekrana devam edebilir (madde 66).
  Widget _buildOnboardingTimeoutScreen() {
    return Scaffold(
      key: const ValueKey('scr-onboarding-timeout'),
      backgroundColor: LululuColors.carbonVoid,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: LululuColors.liquidGold,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.welcomeStatusReadFail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: LululuColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.welcomeSkipFail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: LululuColors.mutedTitanium),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => unawaited(_boot()),
                  child: Text(context.l10n.retry),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _onboardingTimedOut = false;
                      _home = const HomeShell();
                    });
                  },
                  child: Text(context.l10n.continueToHomeAnyway),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Boot hatasını görünür uyarı bandına bağlar: ana ekranın üstünde
  /// hata metni + yeniden deneme + kapatma (madde 66).
  Widget _buildHomeWithBootWarning(Widget home) {
    final bootError = _bootError;
    if (bootError == null) return home;
    return Column(
      children: [
        Material(
          color: LululuColors.darkObsidian,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: LululuColors.liquidGold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.l10n.offlineWarning,
                          style: const TextStyle(
                            color: LululuColors.cream,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bootError,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LululuColors.mutedTitanium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => unawaited(_boot()),
                    child: Text(context.l10n.retry),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: LululuColors.mutedTitanium,
                    tooltip: context.l10n.closeLabel,
                    onPressed: () => setState(() => _bootError = null),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: home),
      ],
    );
  }
}
