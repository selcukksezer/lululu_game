import 'dart:async';

import 'package:flutter/material.dart';

import '../models/campaign_level.dart';
import '../models/lululu_game_mode.dart';
import '../modes/balloon_pop_screen.dart';
import '../modes/connect_pop_screen.dart';
import '../modes/makarayiz_screen.dart';
import '../modes/match3_screen.dart';
import '../modes/osmantus_screen.dart';
import '../modes/scream_roach_screen.dart';
import '../modes/stack_drop_screen.dart';
import '../modes/terlik_tap_screen.dart';
import '../modes/yuva_defense_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/campaign_map_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/game_screen.dart';
import '../screens/grid_2048_screen.dart';
import '../screens/home_shell.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/modes_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/online_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/result_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/studio_screens.dart';
import '../screens/tasks_screen.dart';
import '../screens/tiers_screen.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/zero_jank_preloader.dart';
import '../theme/lululu_theme.dart';
import '../widgets/energy_empty_popup.dart';
import '../widgets/shop_dialog.dart';

/// Stops game SFX/voice when the pushed game route leaves the tree.
class GameAudioGate extends StatefulWidget {
  const GameAudioGate({super.key, required this.child});

  final Widget child;

  @override
  State<GameAudioGate> createState() => _GameAudioGateState();
}

class _GameAudioGateState extends State<GameAudioGate> {
  @override
  void dispose() {
    // Fire-and-forget: route pop must mute immediately even if await races.
    AudioManager().stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: widget.child);
}

/// Canonical enum of the 11 playable LÜLÜLÜ arcade game modes.
/// Kept in `game_routes.dart` for full compatibility across legacy and new callers.
enum GameModeKind {
  suika,
  grid2048,
  balloon,
  match3,
  connect,
  stack,
  terlikTap,
  yuvaDefense,
  osmantus,
  screamRoach,
  makarayiz,
}

/// Authoritative registry and zero-jank router for all 18 main screens and
/// 11 game modes matching `gotoScreen(name)` / `data-goto` in `LÜLÜLÜ UI/UX Tasarım.html`.
abstract final class LululuRoutes {
  static const String splash = 'splash';
  static const String hub = 'hub';
  static const String modes = 'modes';
  static const String game = 'game';
  static const String result = 'result';
  static const String shop = 'shop';
  static const String scores = 'scores';
  static const String tasks = 'tasks';
  static const String profile = 'profile';
  static const String account = 'account';
  static const String online = 'online';
  static const String chat = 'chat';
  static const String tiers = 'tiers';
  static const String studioWatch = 'studio-watch';
  static const String studioCreate = 'studio-create';
  static const String studioUpload = 'studio-upload';
  static const String studioGif = 'studio-gif';
  static const String studioDownloads = 'studio-downloads';

  /// All 18 primary screen IDs from the HTML prototype `NAVDEF`.
  static const List<String> mainScreens = [
    splash,
    hub,
    modes,
    game,
    result,
    shop,
    scores,
    tasks,
    profile,
    account,
    online,
    chat,
    tiers,
    studioWatch,
    studioCreate,
    studioUpload,
    studioGif,
    studioDownloads,
  ];

  /// Maps HTML `go` keys and enum names to [GameModeKind] across all 11 modes.
  static const Map<String, GameModeKind> modeAliases = {
    'suika': GameModeKind.suika,
    'game': GameModeKind.suika,
    'grid2048': GameModeKind.grid2048,
    'm2048': GameModeKind.grid2048,
    '2048': GameModeKind.grid2048,
    'balloon': GameModeKind.balloon,
    'balon': GameModeKind.balloon,
    'match3': GameModeKind.match3,
    'connect': GameModeKind.connect,
    'bagla': GameModeKind.connect,
    'stack': GameModeKind.stack,
    'terlikTap': GameModeKind.terlikTap,
    'terlik': GameModeKind.terlikTap,
    'yuvaDefense': GameModeKind.yuvaDefense,
    'yuva': GameModeKind.yuvaDefense,
    'osmantus': GameModeKind.osmantus,
    'screamRoach': GameModeKind.screamRoach,
    'ciglik': GameModeKind.screamRoach,
    'makarayiz': GameModeKind.makarayiz,
    'makara': GameModeKind.makarayiz,
  };

  /// Converts [LululuGameModeId] to [GameModeKind].
  static GameModeKind fromModeId(LululuGameModeId id) => switch (id) {
    LululuGameModeId.suikaArena => GameModeKind.suika,
    LululuGameModeId.grid2048 => GameModeKind.grid2048,
    LululuGameModeId.bubblePop => GameModeKind.balloon,
    LululuGameModeId.match3 => GameModeKind.match3,
    LululuGameModeId.connectBlast => GameModeKind.connect,
    LululuGameModeId.stackDrop => GameModeKind.stack,
    LululuGameModeId.terlikTap => GameModeKind.terlikTap,
    LululuGameModeId.yuvaDefense => GameModeKind.yuvaDefense,
    LululuGameModeId.osmantus => GameModeKind.osmantus,
    LululuGameModeId.screamBug => GameModeKind.screamRoach,
    LululuGameModeId.makarayiz => GameModeKind.makarayiz,
  };

  /// Builds the widget for any of the 11 [GameModeKind] arcade modes.
  ///
  /// [energyConsumed] yalnız [openGameMode] tarafından `true` geçilir:
  /// giriş enerjisi gerçekten tüketildi demektir. Bayrak, 11 mod
  /// ekranının tümüne geçirilir; bu ekranlar hiç hamle yapılmadan
  /// çıkılırsa enerjiyi iade eder. Doğrudan rota çözümleme
  /// ([resolveScreen]) enerji tüketmez, varsayılan `false` kalır.
  static Widget buildGameModeWidget(
    GameModeKind kind, {
    bool energyConsumed = false,
  }) {
    // `energyConsumed` çalışma anı değeri olduğu için hiçbir dal
    // `const` kurulamaz; `const` kalkması derleme gereğidir,
    // davranış değişikliği değildir.
    return switch (kind) {
      GameModeKind.suika => GameScreen(
        level: CampaignDatabase.kitchenLevel1,
        arcade: true,
        energyConsumed: energyConsumed,
      ),
      GameModeKind.grid2048 =>
        Grid2048Screen(energyConsumed: energyConsumed),
      GameModeKind.balloon =>
        BalloonPopScreen(energyConsumed: energyConsumed),
      GameModeKind.match3 => Match3Screen(energyConsumed: energyConsumed),
      GameModeKind.connect =>
        ConnectPopScreen(energyConsumed: energyConsumed),
      GameModeKind.stack => StackDropScreen(energyConsumed: energyConsumed),
      GameModeKind.osmantus => OsmantusScreen(energyConsumed: energyConsumed),
      GameModeKind.screamRoach =>
        ScreamRoachScreen(energyConsumed: energyConsumed),
      GameModeKind.makarayiz =>
        MakarayizScreen(energyConsumed: energyConsumed),
      GameModeKind.terlikTap =>
        TerlikTapScreen(energyConsumed: energyConsumed),
      GameModeKind.yuvaDefense =>
        YuvaDefenseScreen(energyConsumed: energyConsumed),
    };
  }

  /// Rota adını tek biçimde normalize eder: boşlukları atar, baştaki
  /// `#` ve `/` karakterlerinin herhangi bir karışımını tek seferde
  /// düşürür (`/game`, `#/game`, `/#/game`, `///game` hepsi `game`
  /// olur), sorgu/parça eklerini (`game?level=1`, `game#...`) ve
  /// sondaki eğik çizgileri (`game/`) temizler; böylece derin
  /// bağlantı varyantları (`/#/game/`, `/#/game?level=1`) tam `game`
  /// ile aynı çözülür. Büyük/küçük harf korunur: `terlikTap` gibi
  /// takma adlar büyük/küçük harfe duyarlıdır.
  static String _normalizeRouteName(String rawName) {
    var normalized = rawName.trim();
    normalized = normalized.replaceFirst(RegExp(r'^[#/]+'), '');
    final queryIndex = normalized.indexOf('?');
    if (queryIndex >= 0) normalized = normalized.substring(0, queryIndex);
    final fragmentIndex = normalized.indexOf('#');
    if (fragmentIndex >= 0) {
      normalized = normalized.substring(0, fragmentIndex);
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.trim();
  }

  /// Resolves any of the 18 main screens or 11 game modes by route name.
  ///
  /// Bilinmeyen isimlerde `null` döner; bilinmeyen-rota yedeği
  /// (ana sayfaya düşme) [onGenerateRoute] içindedir.
  static Widget? resolveScreen(String rawName, {BuildContext? context}) {
    final normalized = _normalizeRouteName(rawName);
    switch (normalized) {
      case splash:
        return SplashScreen(
          onDone: () {
            if (context != null && context.mounted) {
              goTo(context, hub, replace: true);
            }
          },
        );
      case '':
      case hub:
        return const HomeShell();
      case modes:
        return const ModesScreen();
      case game:
        return GameAudioGate(
          child: buildGameModeWidget(GameModeKind.suika),
        );
      case result:
        return const GameResultScreen();
      case shop:
        return const ShopScreen();
      case scores:
        return const LeaderboardScreen();
      case tasks:
        return const TasksScreen();
      case profile:
        return const ProfileScreen();
      case account:
        return const AuthScreen();
      case online:
        return const OnlineScreen();
      case chat:
        return const ChatScreen();
      case tiers:
        return const TiersScreen();
      case studioWatch:
        return const StudioWatchScreen();
      case studioCreate:
        return const StudioCreateScreen();
      case studioUpload:
        return const StudioUploadScreen();
      case studioGif:
        return const StudioGifScreen();
      case studioDownloads:
        return const StudioDownloadsScreen();
      case 'settings':
        return const SettingsScreen();
      case 'campaign':
        return const CampaignMapScreen();
      case 'onboarding':
        return const OnboardingScreen();
      default:
        // Also support `<mode>-result` from HTML prototype
        if (normalized.endsWith('-result')) {
          return const GameResultScreen();
        }
        final mode = modeAliases[normalized];
        if (mode != null) {
          return GameAudioGate(child: buildGameModeWidget(mode));
        }
        return null;
    }
  }

  static final CurveTween _scaleCurveTween = CurveTween(
    curve: Curves.easeOutBack,
  );
  static final CurveTween _fadeOutCubicTween = CurveTween(
    curve: Curves.easeOutCubic,
  );
  static final CurveTween _smoothOutTween = CurveTween(
    curve: LululuMotion.smoothOut,
  );
  static final Tween<double> _scaleTween = Tween<double>(begin: 0.94, end: 1);
  static final Tween<Offset> _slideTween = Tween<Offset>(
    begin: const Offset(0.035, 0),
    end: Offset.zero,
  );

  /// Zero-jank hardware-accelerated route transition (60/120 FPS safe).
  static PageRouteBuilder<T> buildZeroJankRoute<T>({
    required Widget child,
    String? routeName,
    Duration duration = LululuMotion.screenTransitionDuration,
    Duration reverseDuration = LululuMotion.screenReverseDuration,
    bool scaleTransition = false,
  }) {
    return PageRouteBuilder<T>(
      settings: routeName != null ? RouteSettings(name: routeName) : null,
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
      pageBuilder: (_, _, _) => RepaintBoundary(child: child),
      transitionsBuilder: (_, anim, _, page) {
        if (scaleTransition) {
          final curved = anim.drive(_scaleCurveTween);
          return FadeTransition(
            opacity: anim.drive(_fadeOutCubicTween),
            child: ScaleTransition(
              scale: _scaleTween.animate(curved),
              child: page,
            ),
          );
        }
        final curved = anim.drive(_smoothOutTween);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: _slideTween.animate(curved),
            child: page,
          ),
        );
      },
    );
  }

  /// Hook for `MaterialApp.onGenerateRoute` supporting all 18 screens & 11 modes.
  ///
  /// Bilinmeyen rota yedeği: [resolveScreen] tanımsız bir isim için
  /// `null` dönerse boş sayfa / çökme yerine ana sayfa ([HomeShell])
  /// açılır ve debug kaydı düşülür. `main.dart` yalnızca
  /// `onGenerateRoute` bağladığı için yedek burada uygulanır;
  /// [onUnknownRoute] aynı yedeği `MaterialApp.onUnknownRoute`
  /// bağlanırsa da sunar.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? hub;
    final screen = resolveScreen(name);
    if (screen == null) {
      debugPrint('[LululuRoutes] bilinmeyen rota: "$name" -> ana sayfa (hub)');
      return buildZeroJankRoute<dynamic>(
        child: const HomeShell(),
        routeName: hub,
      );
    }
    final normalized = _normalizeRouteName(name);
    final isMode = modeAliases.containsKey(normalized);
    return buildZeroJankRoute<dynamic>(
      child: screen,
      routeName: normalized,
      duration: isMode
          ? const Duration(milliseconds: 340)
          : LululuMotion.screenTransitionDuration,
      reverseDuration: LululuMotion.screenReverseDuration,
      scaleTransition: isMode,
    );
  }

  /// Hook for `MaterialApp.onUnknownRoute`: tanımsız rota gelirse ana
  /// sayfayı ([HomeShell]) açar ve debug kaydı düşer. [onGenerateRoute]
  /// zaten aynı yedeği uyguladığı için bağlanması zorunlu değildir;
  /// bağlanırsa davranış aynıdır.
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    debugPrint(
      '[LululuRoutes] bilinmeyen rota (onUnknownRoute): '
      '"${settings.name}" -> ana sayfa (hub)',
    );
    return buildZeroJankRoute<dynamic>(
      child: const HomeShell(),
      routeName: hub,
    );
  }
}

/// Flutter equivalent of HTML `gotoScreen(name)` / `goTo(name)` for smooth,
/// zero-jank navigation across all 18 main screens and 11 game modes.
Future<void> goTo(
  BuildContext context,
  String target, {
  bool replace = false,
  bool checkEnergyForModes = false,
}) async {
  ZeroJankPreloader.instance.notePointerDown();
  final normalized = LululuRoutes._normalizeRouteName(target);

  if (normalized == 'settings') {
    await SettingsScreen.show(context);
    return;
  }

  final modeKind = LululuRoutes.modeAliases[normalized];
  if (modeKind != null && checkEnergyForModes) {
    await openGameMode(context, modeKind);
    return;
  }

  final widget = LululuRoutes.resolveScreen(normalized, context: context);
  if (widget == null) {
    // Bilinmeyen isim: gezinme yok (mevcut davranış), yalnız debug kaydı.
    debugPrint('[LululuRoutes] goTo: bilinmeyen rota "$target" (yok sayıldı)');
    return;
  }
  if (!context.mounted) return;

  final route = LululuRoutes.buildZeroJankRoute<void>(
    child: widget,
    routeName: normalized,
    scaleTransition: modeKind != null,
  );

  if (replace) {
    await Navigator.of(context).pushReplacement(route);
  } else {
    await Navigator.of(context).push(route);
  }
}

Future<void> openGameMode(BuildContext context, GameModeKind kind) async {
  ZeroJankPreloader.instance.notePointerDown();

  // Enerji yoksa oyun açılmasın — popup göster, geri dön.
  final ok = await EnergyService.instance.tryConsume();
  if (!ok) {
    if (context.mounted) {
      await showEnergyEmptyPopup(context);
    }
    return;
  }

  // 'play' görevi GİRİŞTE kaydedilmez: her mod bitirme noktasında (sonuç
  // sunumu) zaten kaydediyor — girişteki kayıt çift sayımdı (madde 35).
  // Girişte tüketilen enerji, hiç hamle yapmadan çıkan oyuncuya bayrağı
  // kabul eden mod ekranı tarafından iade edilir (energyConsumed bayrağı).
  final child = LululuRoutes.buildGameModeWidget(kind, energyConsumed: true);

  if (!context.mounted) return;
  await Navigator.of(context).push(
    LululuRoutes.buildZeroJankRoute<void>(
      child: GameAudioGate(child: child),
      routeName: kind.name,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 220),
      scaleTransition: true,
    ),
  );
}

