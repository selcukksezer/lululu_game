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
import '../screens/bug_video_hub_screen.dart';
import '../screens/campaign_map_screen.dart';
import '../screens/chat_lobby_screen.dart';
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
import '../screens/sticker_gif_screen.dart';
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

/// Energy gate for named-route game opens (B4).
///
/// [LululuRoutes.resolveScreen] is a synchronous pure resolver and cannot
/// consume energy, so [LululuRoutes.onGenerateRoute] wraps every mode
/// route in this gate: deep links and `pushNamed` go through the same
/// single gate as [openGameMode] — one [EnergyService.tryConsume] call —
/// and the game widget is built with `energyConsumed: true`, so a
/// move-less early exit refunds exactly that one unit. No double
/// consumption: this gate and [openGameMode] are alternative entries,
/// never stacked ([goTo] routes mode names through [openGameMode] and
/// never through [LululuRoutes.onGenerateRoute]).
class _EnergyGatedGameMode extends StatefulWidget {
  const _EnergyGatedGameMode({required this.kind});

  final GameModeKind kind;

  @override
  State<_EnergyGatedGameMode> createState() => _EnergyGatedGameModeState();
}

class _EnergyGatedGameModeState extends State<_EnergyGatedGameMode> {
  bool _admitted = false;
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_attemptEntry());
  }

  @override
  void dispose() {
    // Tüketim tamamlandı ama oyun hiç gösterilmeden rota atıldıysa
    // 1 enerjiyi iade et — mod ekranlarının hamlesiz-çıkış iadesiyle
    // aynı sözleşme. (Oyun gösterildiyse iade mod ekranına aittir.)
    if (_consumed && !_admitted) {
      EnergyService.instance.addEnergy(1);
    }
    super.dispose();
  }

  Future<void> _attemptEntry() async {
    final ok = await EnergyService.instance.tryConsume();
    if (!mounted) {
      // Ağaçtan atıldık (dispose çoktan geçti): tüketim yapıldıysa
      // iade burada yapılır, yoksa enerji oyunsuz harcanır.
      if (ok) EnergyService.instance.addEnergy(1);
      return;
    }
    if (!ok) {
      await showEnergyEmptyPopup(context);
      if (!mounted) return;
      // Popup başka bir rotaya gitmediyse kapıyı kapat: geride rota
      // varsa geri dön, yoksa (derin bağlantıyla ilk rota) hub'a geç.
      if (ModalRoute.of(context)?.isCurrent != true) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        await navigator.pushReplacement(
          LululuRoutes.buildZeroJankRoute<void>(
            child: const HomeShell(),
            routeName: LululuRoutes.hub,
          ),
        );
      }
      return;
    }
    _consumed = true;
    setState(() => _admitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_admitted) {
      return const Scaffold(
        backgroundColor: LululuColors.carbonVoid,
        body: Center(
          child: CircularProgressIndicator(color: LululuColors.liquidGold),
        ),
      );
    }
    return GameAudioGate(
      child: LululuRoutes.buildGameModeWidget(
        widget.kind,
        energyConsumed: true,
      ),
    );
  }
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

/// Authoritative registry and zero-jank router for all 21 named screens
/// (18 primary + settings, campaign, onboarding) and 11 game modes
/// matching `gotoScreen(name)` / `data-goto` in `LÜLÜLÜ UI/UX Tasarım.html`.
/// 12D1: +3 ölü-UI rotası (chat-lobby, bug-video-hub, sticker-gif) —
/// `mainScreens` 18'de kalır (route_fallback_test), yalnız
/// [resolveScreen] çözer.
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
  static const String chatLobby = 'chat-lobby';
  static const String bugVideoHub = 'bug-video-hub';
  static const String stickerGif = 'sticker-gif';
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
  /// [energyConsumed] yalnız [openGameMode] ve isimli-rota enerji kapısı
  /// (`_EnergyGatedGameMode`) tarafından `true` geçilir:
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

  /// Resolves any of the 21 named screens or 11 game modes by route name.
  ///
  /// Saf çözümleyicidir: enerji kontrolü yapmaz (B4 kapısı
  /// [onGenerateRoute] / [goTo] / [openGameMode] içindedir) ve çağrıcı
  /// verisi (`RouteSettings.arguments`) okumaz — sonuç rotası da dahil
  /// hiçbir rota skor/modeId parametresi kabul etmez (B5); gerçek
  /// sonuç akışı `finishRun`/`showGameResult` üzerinden yürür.
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
        // Prototip önizleme: sabit varsayılanlarla kurulur (skor 2346,
        // 0 coin, ödeme yok); rota üzerinden skor geçirilemez (B5).
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
      case chatLobby:
        return const ChatLobbyScreen();
      case bugVideoHub:
        return const BugVideoHubScreen();
      case stickerGif:
        return const StickerGifScreen();
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

  /// Hook for `MaterialApp.onGenerateRoute` supporting all 21 named screens & 11 modes.
  ///
  /// Mod rotaları enerji kapısından geçer (B4): [modeAliases] ile
  /// eşleşen adlar oyun ekranını doğrudan değil, tek tüketim yapan
  /// `_EnergyGatedGameMode` kapısıyla açar.
  ///
  /// Bilinmeyen rota yedeği: [resolveScreen] tanımsız bir isim için
  /// `null` dönerse boş sayfa / çökme yerine ana sayfa ([HomeShell])
  /// açılır ve debug kaydı düşülür. `main.dart` yalnızca
  /// `onGenerateRoute` bağladığı için yedek burada uygulanır;
  /// [onUnknownRoute] aynı yedeği `MaterialApp.onUnknownRoute`
  /// bağlanırsa da sunar.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? hub;
    final normalized = _normalizeRouteName(name);
    // B4: isimli rotayla açılan mod, openGameMode ile aynı enerji
    // kapısından geçer. resolveScreen eşzamanlı saf çözümleyicidir
    // (sözleşmesi route_fallback_test ile sabittir); kapı burada
    // uygulanır, oyun ekranı tüketim SONRASINDA energyConsumed: true
    // ile kurulur.
    final modeKind = modeAliases[normalized];
    if (modeKind != null) {
      return buildZeroJankRoute<dynamic>(
        child: _EnergyGatedGameMode(kind: modeKind),
        routeName: normalized,
        duration: const Duration(milliseconds: 340),
        reverseDuration: LululuMotion.screenReverseDuration,
        scaleTransition: true,
      );
    }
    // 6I: isimli-rota splash'i — `resolveScreen('splash')` bağlamsız
    // çağrılırsa `onDone` ölü doğar (`context == null` → hiçbir yere
    // gitmez) ve `_finish` tek-atımlık kilidi (`_notified`) tükendiği
    // için splash %101 "BAŞLIYOR!"da kalıcı donar (GEÇ de aynı kilide
    // takılır). Splash `Builder` altında kurulur: `onDone` canlı,
    // bağlı bir Navigator bağlamı alır ve hub'a geçiş çalışır.
    // `goTo` ile bağlamlı çözülen splash (`resolveScreen` + context)
    // aynen durur; bu dal yalnız `onGenerateRoute` yolunu kapsar.
    if (normalized == splash) {
      return buildZeroJankRoute<dynamic>(
        child: Builder(
          builder: (context) => SplashScreen(
            onDone: () {
              if (context.mounted) {
                goTo(context, hub, replace: true);
              }
            },
          ),
        ),
        routeName: normalized,
        duration: LululuMotion.screenTransitionDuration,
        reverseDuration: LululuMotion.screenReverseDuration,
      );
    }
    final screen = resolveScreen(name);
    if (screen == null) {
      debugPrint('[LululuRoutes] bilinmeyen rota: "$name" -> ana sayfa (hub)');
      return buildZeroJankRoute<dynamic>(
        child: const HomeShell(),
        routeName: hub,
      );
    }
    return buildZeroJankRoute<dynamic>(
      child: screen,
      routeName: normalized,
      duration: LululuMotion.screenTransitionDuration,
      reverseDuration: LululuMotion.screenReverseDuration,
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
/// zero-jank navigation across all 21 named screens and 11 game modes.
///
/// Mod adları daima [openGameMode] kapısından geçer (B4: tek enerji
/// tüketimi); bilinmeyen adlar sessizce yok sayılmaz, ana sayfa
/// yedeğine düşer (B30a — [LululuRoutes.onGenerateRoute] ile aynı).
///
/// N4: `replace: true` ile hub'a (`hub` veya boş ad) gidildiğinde
/// yığın tek [HomeShell] rotasına indirilir (`pushAndRemoveUntil`):
/// bağımsız ekrandaki dock'tan hub'a dönüldüğünde altta eski shell
/// kalmaz, geri tuşu eski shell'e dönmez. Hub-dışı hedeflerde
/// `replace` davranışı değişmez (yalnız üst rota değişir).
Future<void> goTo(
  BuildContext context,
  String target, {
  bool replace = false,
  @Deprecated(
    'B4: mod açılışları daima enerji kapısından geçer; bu bayrak '
    'artık davranışı değiştirmez.',
  )
  bool checkEnergyForModes = false,
}) async {
  ZeroJankPreloader.instance.notePointerDown();
  final normalized = LululuRoutes._normalizeRouteName(target);

  if (normalized == 'settings') {
    await SettingsScreen.show(context);
    return;
  }

  final modeKind = LululuRoutes.modeAliases[normalized];
  if (modeKind != null) {
    // B4: kısayol/mod adıyla açılan oyun daima openGameMode kapısından
    // geçer — tek tüketim, enerji yoksa oyun açılmaz.
    // checkEnergyForModes bayrağı artık okunmaz (yalnız kaynak
    // uyumluluğu için durur).
    await openGameMode(context, modeKind);
    return;
  }

  final widget = LululuRoutes.resolveScreen(normalized, context: context);
  if (widget == null) {
    // B30a: bilinmeyen rota onGenerateRoute yedeğiyle aynı davranır —
    // ana sayfaya düşer (sessiz yok sayma yok).
    debugPrint(
      '[LululuRoutes] goTo: bilinmeyen rota "$target" -> ana sayfa (hub)',
    );
    if (!context.mounted) return;
    final fallbackRoute = LululuRoutes.buildZeroJankRoute<void>(
      child: const HomeShell(),
      routeName: LululuRoutes.hub,
    );
    if (replace) {
      // N4: hub yedeği yığını tek HomeShell'e indirir (bkz. goTo
      // dokümanı); altta eski shell kalmaz.
      await Navigator.of(context).pushAndRemoveUntil(
        fallbackRoute,
        (_) => false,
      );
    } else {
      await Navigator.of(context).push(fallbackRoute);
    }
    return;
  }
  if (!context.mounted) return;

  final route = LululuRoutes.buildZeroJankRoute<void>(
    child: widget,
    routeName: normalized,
    scaleTransition: modeKind != null,
  );

  if (replace) {
    // N4: hub hedefi (`hub` veya boş ad — ikisi de HomeShell çözer)
    // yığını tek shell rotasına indirir; hub-dışı hedeflerde yalnız
    // üst rota değişir (önceki davranış).
    if (normalized == LululuRoutes.hub || normalized.isEmpty) {
      await Navigator.of(context).pushAndRemoveUntil(route, (_) => false);
    } else {
      await Navigator.of(context).pushReplacement(route);
    }
  } else {
    await Navigator.of(context).push(route);
  }
}

/// Tek enerji kapısından oyun açar (B4): 1 enerji tüketir, enerji
/// yoksa enerji-boş popup'ı gösterip oyunu açmaz. [goTo] mod adlarını
/// buraya yönlendirir; isimli rota açılışlarında aynı kapı
/// [LululuRoutes.onGenerateRoute] içindeki `_EnergyGatedGameMode`
/// tarafından uygulanır. Tüketim her girişte tam bir kez yapılır;
/// oyun ekranı `energyConsumed: true` ile kurulur.
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

