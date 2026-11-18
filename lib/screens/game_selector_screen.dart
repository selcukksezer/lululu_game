import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/lululu_game_mode.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';
import '../services/chat_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/energy_service.dart';
import '../services/friend_invite_service.dart';
import '../services/leaderboard_service.dart';
import '../services/online_notify_service.dart';
import '../services/progress_manager.dart';
import '../services/zero_jank_preloader.dart';
import '../theme/lululu_theme.dart';
import '../widgets/energy_empty_popup.dart';
import '../widgets/hb_overlay.dart';
import '../widgets/top_bar.dart';
import 'chat_screen.dart';
import 'modes_screen.dart';
import 'online_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'studio_screens.dart';
import 'tasks_screen.dart';

String _leaderboardIdFor(GameModeKind kind) => switch (kind) {
  GameModeKind.suika => 'suika',
  GameModeKind.grid2048 => 'grid2048',
  GameModeKind.balloon => 'balloon',
  GameModeKind.match3 => 'match3',
  GameModeKind.connect => 'connect',
  GameModeKind.stack => 'stack',
  GameModeKind.terlikTap => 'terlik',
  GameModeKind.osmantus => 'osmantus',
  GameModeKind.screamRoach => 'scream',
  GameModeKind.makarayiz => 'makarayiz',
  GameModeKind.yuvaDefense => 'yuva',
};

String _sanitizeStickerAsset(String path) {
  if (path.contains('sticker_tier1_baby.png')) {
    return 'assets/images/stickers/sticker_tier1_cone.png';
  }
  return path;
}

/// ANA SAYFA (`#scr-hub`) — HTML prototype ve `reference-spec.json` ile 1:1 piksel uyumlu.
class GameSelectorScreen extends StatefulWidget {
  const GameSelectorScreen({
    super.key,
    this.onOpenMap,
    this.onOpenBoard,
    this.onOpenChat,
    this.onOpenAuth,
    this.onOpenShop,
  });

  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenBoard;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenAuth;
  final VoidCallback? onOpenShop;

  @override
  State<GameSelectorScreen> createState() => _GameSelectorScreenState();
}

class _GameSelectorScreenState extends State<GameSelectorScreen> {
  // Yalnız oturum-içi/uçuş-sırası koruma: kalıcı talep durumu
  // ProgressManager.canClaimDailyGiftBox'tan türetilir.
  bool _dailyRewardClaimed = false;
  bool _dailyEnergyClaimed = false;
  bool _dailyChallengeClaiming = false;

  @override
  void initState() {
    super.initState();
    unawaited(DailyChallengeService.instance.ensureLoaded());
    unawaited(OnlineNotifyService.instance.ensureLoaded());
  }

  void _openProfile() {
    AudioManager().playPop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
  }

  void _openSettings() {
    AudioManager().playPop();
    SettingsScreen.show(context);
  }

  void _openTasks() {
    AudioManager().playPop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TasksScreen()));
  }

  void _openModes() {
    AudioManager().playPop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ModesScreen()));
  }

  Future<void> _launchMode(GameModeKind kind) async {
    AudioManager().playPop();
    ZeroJankPreloader.instance.notePointerDown();
    // B31 — sıralama: enerji ÖNCE tüketilir, kalp kırılma overlay'i
    // YALNIZ başarılı tüketimden sonra oynatılır. Tüketim burada
    // yapıldığı için gezinme openGameMode'un tüketimsiz eşdeğeridir
    // (aynı widget + aynı zero-jank rota + GameAudioGate); enerji
    // yoksa aynı boş-enerji popup'ı gösterilir, overlay oynatılmaz.
    final consumed = await EnergyService.instance.tryConsume();
    if (!consumed) {
      if (mounted) {
        await showEnergyEmptyPopup(context);
      }
      return;
    }
    if (!mounted) return;
    await HbOverlay.play(context);
    if (!mounted) return;
    final child = LululuRoutes.buildGameModeWidget(kind, energyConsumed: true);
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

  void _playSuika() {
    _launchMode(GameModeKind.suika);
  }

  Future<void> _claimDailyReward() async {
    final pm = ProgressManager.instance;
    // Kalıcı koruma: bugün zaten talep edildiyse dokunma hiçbir şey
    // yapmaz — ödeme yok, ses yok, snackbar yok. _dailyRewardClaimed
    // yalnız oturum-içi/uçuş-sırası korumadır.
    if (_dailyRewardClaimed || !pm.canClaimDailyGiftBox) return;
    setState(() => _dailyRewardClaimed = true);
    final reward = await pm.claimDailyGiftBox();
    // claimDailyGiftBox aynı gün tekrarında null döner: yarış
    // durumunda da ses/snackbar verilmez.
    if (reward == null) return;
    AudioManager().playWin();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.dailyRewardClaimedSnack)),
      );
    }
  }

  /// Ödüllü reklam SDK'sı kurulu değil: reklam gösterilemez, ödül
  /// verilmez. Gerçek SDK eklendiğinde reklam dalları gerçek reklam
  /// akışına bağlanmalıdır; sahte (mock) reklamla ödül verilmez (madde 4).
  void _showRewardsComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.rewardedAdsComingSoon),
      ),
    );
  }

  Future<void> _claimDoubleDailyReward() async {
    _showRewardsComingSoon();
  }

  Future<void> _claimDailyEnergy() async {
    final pm = ProgressManager.instance;
    if (!_dailyEnergyClaimed && pm.canClaimDailyFreeEnergy) {
      setState(() => _dailyEnergyClaimed = true);
      final granted = await pm.claimDailyFreeEnergy(amount: 5);
      if (!granted) {
        // K13 — fallback KALDIRILDI: claim reddedildiyse (yarışta
        // başka talep önce davrandıysa) enerji EKLENMEZ; kullanıcıya
        // görünür "bugün alındı" bildirimi gösterilir, oturum bayrağı
        // geri alınır ki kalıcı durum tek doğruluk kaynağı kalsın.
        if (mounted) {
          setState(() => _dailyEnergyClaimed = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.dailyEnergyAlreadyClaimedSnack),
            ),
          );
        }
        return;
      }
      AudioManager().playWin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dailyEnergyClaimedSnack),
          ),
        );
      }
      return;
    }

    // Ücretsiz hak tükendi: reklam dalı ödül vermez, bilgi gösterir.
    if (!mounted) return;
    _showRewardsComingSoon();
  }

  /// K2-UI — günlük challenge ödül talebi. Kapı HER İKİ koşulu da
  /// denetler: `canClaimToday` yalnız `lastClaimDay`'e bakar
  /// (tamamlanmamış günde de true döner), o yüzden `completedToday`
  /// ayrıca şarttır. Ödül, talep ÖNCESİ okunur (talep sonrası
  /// `nextClaimRewardCoins` değişir).
  Future<void> _claimDailyChallenge() async {
    final daily = DailyChallengeService.instance;
    if (_dailyChallengeClaiming ||
        !daily.completedToday ||
        !daily.canClaimToday) {
      return;
    }
    setState(() => _dailyChallengeClaiming = true);
    final reward = daily.nextClaimRewardCoins;
    final ok = await daily.claimDailyChallengeReward();
    if (!mounted) return;
    setState(() => _dailyChallengeClaiming = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorGeneric)),
      );
      return;
    }
    AudioManager().playWin();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.dailyChallengeClaimedSnack(reward)),
      ),
    );
  }

  /// B7/K19 — hub "Haberdar Et" düğmesi: [OnlineNotifyService] tek
  /// kaynaktır; Online ekranıyla aynı tercihi okuyup yazar. Bildirim
  /// gönderilmez, yalnız tercih saklanır (push altyapısı yok).
  Future<void> _toggleOnlineNotify() async {
    AudioManager().playPop();
    final subscribed = await OnlineNotifyService.instance.toggle();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          subscribed
              ? context.l10n.onlineNotifySignupSnack
              : context.l10n.onlineNotifyRemovedSnack,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF141B2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  /// K3-giriş — kampanya haritası girişi: harita kendi akışıyla açılır;
  /// enerji/kilit mantığı haritanın kendisindedir, bypass yok.
  Future<void> _openCampaign() async {
    AudioManager().playPop();
    await goTo(context, 'campaign');
  }

  /// K17-hub — davet paylaşımı; profil ekranındaki desenin aynısı:
  /// servis `Future<void>` döner, sheet'in kapatılması hata sayılmaz,
  /// yalnız istisnada hata bildirimi gösterilir. Redeem akışı YOKTUR
  /// (karar bekliyor).
  Future<void> _shareInvite() async {
    AudioManager().playPop();
    try {
      await FriendInviteService.instance.shareInvite();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileInviteFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topPad = MediaQuery.paddingOf(context).top;
    final hasHostStatusBar = topPad > 0;
    final statusBarHeight = hasHostStatusBar ? topPad : 35.4;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          // .statusbar (y: 0..35.4 in headless golden test; SafeArea top inset on real device)
          SizedBox(
            height: statusBarHeight,
            width: double.infinity,
            child: hasHostStatusBar
                ? const SizedBox.shrink()
                : _buildStatusBar(),
          ),
          // .pillbar (y: 35.4..91.4, height: 56, padding: 8.6px 8px 3.4px -> top=44.0 integer!)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8.6, 8, 3.4),
            child: LululuTopBar(
              light: true,
              onProfileTap: _openProfile,
              onSettingsTap: _openSettings,
              onShopTap: widget.onOpenShop,
            ),
          ),
          // .scroll (y: 91.4..932)
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // Hero Play Card (.hub-hero: margin 10px 12px 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: _buildHeroCard(),
                  ),
                ),

                // Günlük Ödül + Online Mod (CSS position:relative on .daily paints shadow over .online-card)
                SliverToBoxAdapter(
                  child: Column(
                    verticalDirection: VerticalDirection.up,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: _buildOnlineCard(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: _buildDailyCard(),
                      ),
                    ],
                  ),
                ),

                // Sohbet Card (.chat-card: margin 8px 12px 4px -> collapses with next 8px top)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _buildChatCard(),
                  ),
                ),

                // Günlük Görevler Card (.hub-tasks: margin 8px 12px 4px)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: _buildTasksCard(),
                  ),
                ),

                // Günlük Challenge kartı (K2-UI)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: _buildDailyChallengeCard(),
                  ),
                ),

                // Kampanya + davet girişleri (K3-giriş / K17-hub)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        Expanded(child: _buildCampaignEntryCard()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInviteEntryCard()),
                      ],
                    ),
                  ),
                ),

                // Section Header: Oyun Modları (.sec-head: padding 18px 16px 8px)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.modesTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF141B2A),
                              height: 1.12,
                            ),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n.seeAllButton,
                          child: GestureDetector(
                            onTap: _openModes,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              l10n.seeAllArrow,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFE01E5A),
                                height: 1.55,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Mode Grid (.mode-grid: 2x2 grid of 4 featured modes, padding 2px 12px 6px, gap 12px)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                    child: _buildModeGrid(),
                  ),
                ),

                // Section Header: Stüdyo (.sec-head: padding 18px 16px 8px)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Text(
                      l10n.studioTitle,
                      style: GoogleFonts.baloo2(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF141B2A),
                        height: 1.12,
                      ),
                    ),
                  ),
                ),

                // Studio Horizontal Strip (.studio-strip: padding 4px 12px 12px, gap 10px)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 146.3,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      children: [
                        _buildStudioCard(
                          title: l10n.studioWatchTitle,
                          subtitle: l10n.studioWatchSubtitle,
                          icon: Icons.play_arrow_rounded,
                          gradient: const [
                            Color(0xFFF4538B),
                            Color(0xFFE01E5A),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const StudioWatchScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildStudioCard(
                          title: l10n.studioCreateTitle,
                          subtitle: l10n.studioCreateSubtitle,
                          icon: Icons.edit_rounded,
                          gradient: const [
                            Color(0xFF9B5DE5),
                            Color(0xFF7C3AED),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const StudioCreateScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildStudioCard(
                          title: l10n.studioUploadTitle,
                          subtitle: l10n.studioUploadSubtitle,
                          icon: Icons.upload_rounded,
                          gradient: const [
                            Color(0xFFFF8A5C),
                            Color(0xFFFF6B35),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const StudioUploadScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildStudioCard(
                          title: l10n.studioGifTitle,
                          subtitle: l10n.studioGifSubtitle,
                          icon: Icons.gif_box_outlined,
                          gradient: const [
                            Color(0xFF37E08B),
                            Color(0xFF12B76A),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const StudioGifScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildStudioCard(
                          title: l10n.studioDownloadsTitle,
                          subtitle: l10n.studioDownloadsSubtitle,
                          icon: Icons.download_rounded,
                          iconColor: const Color(0xFF4A2E00),
                          gradient: const [
                            Color(0xFFFFCF3F),
                            Color(0xFFFFB800),
                          ],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const StudioDownloadsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '09:41',
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF141B2A),
              height: 1.55,
            ),
          ),
          const SizedBox(
            width: 55,
            height: 15,
            child: CustomPaint(painter: _StatusBarIconsPainter()),
          ),
        ],
      ),
    );
  }

  // Hero Card (Suika Arena) — .hub-hero (x:12, y:101.4, w:406).
  // Yükseklik sabit değil: kullanılabilir genişlikten prototip oranıyla
  // (406 genişlikte 373.6 yükseklik) türetilir ve tam piksele yuvarlanır.
  // Maskot yüksekliği de bu toplamdan içerik payları çıkarılarak hesaplanır.
  Widget _buildHeroCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final l10n = context.l10n;
        final cardWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 406.0;
        final cardHeight = (cardWidth * 3736 / 4060).roundToDouble();
        // İçerik payları: üst+alt padding 16+16, ara boşluk 12, OYNA düğmesi 52.
        final mascotHeight = cardHeight - 96;
        return CustomPaint(
      painter: const _RealBoxShadowPainter(
        radius: 26,
        shadows: [
          BoxShadow(
            color: Color(0x40E01E5A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/design/ui/hub_hero_bg_exact.webp',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/design/ui/hub_hero_bg.webp',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.34, 1.0],
                    colors: [Color(0x00E01E5A), Color(0x8C7A082E)],
                  ),
                ),
              ),
            ),
            // HOT badge (x: 21.2 - 12 = 9.2, y: 109.9 - 101.4 = 8.5, rotated -6deg)
            Positioned(
              left: 9.2,
              top: 8.5,
              child: Transform.rotate(
                angle: -0.1047, // -6 degrees
                child: CustomPaint(
                  painter: const _RealBoxShadowPainter(
                    radius: 999,
                    shadows: [
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE01E5A),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.badgeHot,
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.66,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Content + Mascot + Play Button inside padding 16
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: 0,
                          bottom: 0,
                          width: 104,
                          height: mascotHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: Transform.translate(
                                  offset: const Offset(0, 8),
                                  child: ImageFiltered(
                                    imageFilter: ui.ImageFilter.blur(
                                      sigmaX: 6,
                                      sigmaY: 6,
                                      tileMode: TileMode.decal,
                                    ),
                                    child: ColorFiltered(
                                      colorFilter: const ColorFilter.mode(
                                        Color(0x59000000),
                                        BlendMode.srcIn,
                                      ),
                                      child: Image.asset(
                                        'assets/design/ui/hub_hero_mascot_exact.webp',
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomCenter,
                                        errorBuilder: (_, error, _) {
                                          // Sessiz boşluk yerine yer tutucu
                                          // + hata kaydı (gölge katmanı:
                                          // dış ColorFiltered siyah siluete
                                          // çevirir, blur uygular).
                                          debugPrint(
                                            '[GameSelector] Hub maskot '
                                            'gölgesi yüklenemedi: '
                                            'assets/design/ui/hub_hero_mascot_exact.webp'
                                            '($error)',
                                          );
                                          return Container(
                                            color: Colors.black,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/design/ui/hub_hero_mascot_exact.webp',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                  errorBuilder: (_, _, _) => Image.asset(
                                    'assets/design/ui/hub_hero_mascot.webp',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 90,
                          bottom: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Transform.translate(
                                offset: const Offset(0.5, -1.0),
                                child: Text(
                                  l10n.suikaArenaTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.0,
                                    color: Colors.white,
                                    height: 1.12,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0x737A082E),
                                        offset: Offset(0, 3),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.heroSubtitleLine1,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.0,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  height: 1.55,
                                ),
                              ),
                              Text(
                                l10n.heroSubtitleLine2,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.0,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: l10n.playNow,
                    child: GestureDetector(
                      onTap: _playSuika,
                      behavior: HitTestBehavior.opaque,
                      child: CustomPaint(
                        painter: const _RealBoxShadowPainter(
                          radius: 18,
                          shadows: [
                            BoxShadow(
                              color: Color(0x47000000),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Color(0xFF066C3C),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF37E08B),
                                Color(0xFF12B76A),
                                Color(0xFF0A9553),
                              ],
                              stops: [0.0, 0.55, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/design/ui/hub_hero_play_exact.png',
                              width: 23,
                              height: 23,
                              errorBuilder: (_, _, _) => Image.asset(
                                'assets/design/ui/hub_hero_play_ic.png',
                                width: 23,
                                height: 23,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.playNow,
                              style: GoogleFonts.baloo2(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.35,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x73066C3C),
                                    offset: Offset(0, 2),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                  ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
      },
    );
  }

  // Daily Card — .daily (x:12, y:483, w:406)
  Widget _buildDailyCard() {
    final l10n = context.l10n;
    return CustomPaint(
      painter: const _RealBoxShadowPainter(
        radius: 22,
        shadows: [
          BoxShadow(
            color: Color(0x4D7C3AED),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      // Yükseklik sabiti yok: kart, içerik (üst bölüm + boşluklar +
      // düğmeler) kadar yer kaplar; Column kısıttan türetir.
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-1.0167, -0.9529),
            end: Alignment(1.0167, 0.9529),
            colors: [Color(0xFF7C3AED), Color(0xFFE01E5A), Color(0xFFFF6B35)],
            stops: [0.0, 0.6, 1.0],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // .daily-top (height: 120.4 — altyazı 2 satıra sarabilir)
            SizedBox(
              height: 120.4,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/design/ui/icon_calendar_exact.png',
                    width: 76,
                    height: 76,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.calendar_today_rounded,
                      color: LululuColors.liquidGold,
                      size: 76,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24.3),
                        Text(
                          l10n.dailyRewardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.baloo2(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.0,
                            color: Colors.white,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 26.3),
                        ListenableBuilder(
                          listenable: ProgressManager.instance,
                          builder: (context, _) {
                            final streak =
                                ProgressManager.instance.dailyStreak;
                            final subtitle =
                                context.l10n.dailyRewardSubtitleStreak(
                                  streak,
                                );
                            return Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.0,
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.55,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // .daily-btns top row (height: 48)
            Row(
              children: [
                Expanded(
                  flex: 180,
                  child: ListenableBuilder(
                    listenable: ProgressManager.instance,
                    builder: (context, _) {
                      // Talep durumu kalıcı kaynaktan türetilir: prefs'teki
                      // lastStreakClaimDay bugünse düğme talep-edilmiş
                      // görünür (yeniden başlatmada da). Dosyadaki görev
                      // kartıyla aynı yerel ListenableBuilder deseni.
                      final claimed =
                          _dailyRewardClaimed ||
                          !ProgressManager.instance.canClaimDailyGiftBox;
                      return Semantics(
                        button: true,
                        enabled: !claimed,
                        label: claimed ? l10n.claimedShort : l10n.claim500,
                        child: GestureDetector(
                          onTap: claimed ? null : _claimDailyReward,
                      child: CustomPaint(
                        painter: const _RealBoxShadowPainter(
                          radius: 14,
                          shadows: [
                            BoxShadow(
                              color: Color(0x47000000),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Color(0xFFB97A00),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: claimed
                                ? null
                                : const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFFFD34D),
                                      Color(0xFFFFB800),
                                      Color(0xFFF59E00),
                                    ],
                                    stops: [0.0, 0.55, 1.0],
                                  ),
                            color: claimed
                                ? const Color(0xFFE2E6EE)
                                : null,
                            borderRadius: BorderRadius.circular(14),
                          ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Transform.translate(
                          offset: const Offset(0, -1),
                          child: Text(
                            claimed ? l10n.claimedShort : l10n.claim500,
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.45,
                              color: claimed
                                  ? const Color(0xFF8E9CAE)
                                  : Colors.white,
                              shadows: claimed
                                  ? null
                                  : const [
                                      Shadow(
                                        color: Color(0x59784000),
                                        offset: Offset(0, 2),
                                        blurRadius: 0,
                                      ),
                                    ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                      ),
                      );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 184,
                child: Semantics(
                  button: true,
                  label: l10n.doubleRewardLabel,
                  child: GestureDetector(
                    onTap: _claimDoubleDailyReward,
                    child: CustomPaint(
                      painter: const _CssBottomShadowPainter(
                        radius: 14,
                        offsetY: 4,
                        shadowColor: Color(0x73000000),
                        insetStrokeColor: Color(0x85FFB800),
                        outerBorderWidth: 2.0,
                      ),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x8C080B12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFFB800),
                            width: 2.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Transform.translate(
                          offset: const Offset(0.5, 0.5),
                          child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 58.6,
                              height: 19,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  l10n.comingSoon,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: GoogleFonts.baloo2(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.6,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '2X',
                              style: GoogleFonts.baloo2(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.39,
                              ),
                            ),
                          ],
                        ),
                        ),
                      ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // #dailyEnergy button (height: 48)
          Semantics(
            button: true,
            label: l10n.claimEnergy5,
            child: GestureDetector(
              onTap: _claimDailyEnergy,
              child: CustomPaint(
                painter: const _RealBoxShadowPainter(
                  radius: 14,
                  shadows: [
                    BoxShadow(
                      color: Color(0x47000000),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Color(0xFF066C3C),
                      offset: Offset(0, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF37E08B),
                        Color(0xFF12B76A),
                        Color(0xFF0A9553),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/design/ui/icon_energy_bolt_exact.png',
                          width: 23,
                          height: 23,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/design/ui/icon_heart_exact.png',
                            width: 23,
                            height: 23,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.claimEnergy5,
                          style: GoogleFonts.baloo2(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.39,
                            shadows: const [
                              Shadow(
                                color: Color(0x73066C3C),
                                offset: Offset(0, 2),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // Online Mod Card — .online-card (x:12, y:741.1, w:406, h:183.5)
  Widget _buildOnlineCard() {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.onlineModeTitle,
      child: GestureDetector(
        onTap: () {
          AudioManager().playPop();
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const OnlineScreen()));
        },
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: const _RealBoxShadowPainter(
            radius: 22,
            shadows: [
              BoxShadow(
                color: Color(0x14141B2A),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
              BoxShadow(
                color: Color(0x14141B2A),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Container(
            height: 187.5,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 91.5,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Opacity(
                              opacity: 0.75,
                              child: ColorFiltered(
                                colorFilter: const ColorFilter.matrix(<double>[
                                  0.3086, 0.5180, 0.0609, 0, 0, //
                                  0.1806, 0.6460, 0.0609, 0, 0, //
                                  0.1806, 0.5180, 0.1889, 0, 0, //
                                  0, 0, 0, 1, 0, //
                                ]),
                                child: Image.asset(
                                  'assets/design/ui/online_locked_bug_exact.webp',
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Image.asset(
                                    'assets/design/ui/online_locked_bug.webp',
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -4,
                              bottom: -4,
                              child: CustomPaint(
                                painter: const _RealBoxShadowPainter(
                                  radius: 15,
                                  shadows: [
                                    BoxShadow(
                                      color: Color(0x4D000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF141B2A),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CustomPaint(painter: _LockIconPainter()),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 70.5,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Sabit 110px kaldırıldı: başlık, rozetle kalan
                                  // alanı paylaşır; EN/TR başlık kesilmez.
                                  Flexible(
                                    child: Transform.translate(
                                      offset: const Offset(0, -1),
                                      child: Text(
                                        l10n.onlineModeTitle,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.baloo2(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.05,
                                          color: const Color(0xFF141B2A),
                                          height: 1.05,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Transform.rotate(
                                    angle: -0.05236, // -3deg
                                    child: CustomPaint(
                                      painter: const _RealBoxShadowPainter(
                                        radius: 999,
                                        shadows: [
                                          BoxShadow(
                                            color: Color(0x2E000000),
                                            blurRadius: 5,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB800),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          l10n.comingSoon,
                                          style: GoogleFonts.baloo2(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF4A2E00),
                                            letterSpacing: 0.66,
                                            height: 1.55,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, 3.8),
                              child: Text(
                                l10n.onlineModeSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.04,
                                  color: const Color(0xFF66738A),
                                  height: 1.38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListenableBuilder(
                  listenable: OnlineNotifyService.instance,
                  builder: (context, _) {
                    final subscribed =
                        OnlineNotifyService.instance.isSubscribed;
                    return Semantics(
                      button: true,
                      label: subscribed ? l10n.notifyOnLabel : l10n.notifyMe,
                      child: GestureDetector(
                    onTap: _toggleOnlineNotify,
                    behavior: HitTestBehavior.opaque,
                    child: CustomPaint(
                      painter: const _RealBoxShadowPainter(
                        radius: 14,
                        shadows: [
                          BoxShadow(
                            color: Color(0x38000000),
                            blurRadius: 14,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Color(0x8C000000),
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141B2A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/design/ui/icon_bell_exact.png',
                            width: 21,
                            height: 21,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.notifications_active_rounded,
                              color: Color(0xFFFF6B35),
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            subscribed ? l10n.notifyOnCaps : l10n.notifyMe,
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFF6B35),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                  ),
                    );
                  },
                ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // Sohbet kartı rozet etiketi; null ise rozet gizlidir (W14-1).
  //
  // Sayaç kanal başına ChatService.unreadProbeLimit (10) ile sınırlı
  // olduğundan, herhangi bir kanal sınırdaysa toplam bir alt sınırdır
  // ve "N+" gösterilir; aksi hâlde kesin toplam yazılır. LululuDockBar
  // rozetiyle aynı kural — oradaki rozet görünmez katmanda kalır.
  static String? _chatUnreadBadgeLabel() {
    final total = ChatService.instance.totalUnreadCount;
    if (total <= 0) return null;
    final capped = ChatService.instance.unreadCounts.values
        .any((count) => count >= ChatService.unreadProbeLimit);
    return capped ? '$total+' : '$total';
  }

  // Chat Card — .chat-card (x:12, y:932.6, w:406, h:126.5)
  //
  // W14-1: kartın sağ üst köşesinde toplam okunmamış rozeti. Rozet
  // kartın üstüne binen bir katmandır (Stack + Clip.none); kartın
  // ölçüsü/yerleşimi değişmez, sayı 0 ise hiç çizilmez. Karta
  // dokununca açılan ChatScreen initState'te okundu işaretler; burada
  // tekrar işaretleme yapılmaz.
  Widget _buildChatCard() {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: ChatService.instance,
      builder: (context, _) {
        final badgeLabel = _chatUnreadBadgeLabel();
        return Semantics(
          button: true,
          label: badgeLabel != null ? l10n.dockUnreadLabel(l10n.chatTitle, badgeLabel) : l10n.chatTitle,
          child: GestureDetector(
            onTap: () {
              AudioManager().playPop();
              Navigator.of(
                context,
              ).push(
                MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
          height: 126.5,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF4538B), Color(0xFF9B5DE5), Color(0xFF7C3AED)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B5DE5).withValues(alpha: 0.32),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -6,
                bottom: -24,
                child: Opacity(
                  opacity: 0.16,
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    size: 76,
                    color: Colors.white,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 70.5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.chatTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.05,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF080B12).withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF37E08B),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x2037E08B),
                                      blurRadius: 0,
                                      spreadRadius: 4.9,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.onlineCount5,
                                style: GoogleFonts.baloo2(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.chatSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.92),
                      height: 1.38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
                if (badgeLabel != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Semantics(
                      label: context.l10n.chatBadgeUnreadLabel(badgeLabel),
                      child: Container(
                        height: 22,
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE52E2E),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          badgeLabel,
                          style: GoogleFonts.baloo2(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Daily Tasks Preview Card — .hub-tasks
  Widget _buildTasksCard() {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14141B2A),
            offset: Offset(0, 6),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x14141B2A),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 80.9,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/design/ui/hub_12_img.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.emoji_events_rounded,
                    color: LululuColors.liquidGold,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dailyTasksTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF141B2A),
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.hubTasksSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF66738A),
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: l10n.seeAllButton,
                  child: GestureDetector(
                    onTap: _openTasks,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFB97A00),
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        l10n.seeAllButton,
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4A2E00),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: ProgressManager.instance,
            builder: (context, _) {
              final pm = ProgressManager.instance;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTaskItem(
                    title: l10n.taskPlay3Games,
                    current: pm.getTaskProgress('play').clamp(0, 3),
                    target: 3,
                    iconAsset: 'assets/design/ui/hub_13_img.png',
                  ),
                  _buildTaskItem(
                    title: l10n.taskMerge5,
                    current: pm.getTaskProgress('merge').clamp(0, 5),
                    target: 5,
                    iconAsset: 'assets/design/ui/hub_14_img.png',
                  ),
                  _buildTaskItem(
                    title: l10n.taskWatch1Video,
                    current: pm.getTaskProgress('video').clamp(0, 1),
                    target: 1,
                    iconAsset: 'assets/design/ui/hub_15_img.png',
                  ),
                  _buildTaskItem(
                    title: l10n.taskCombo4,
                    current: pm.getTaskProgress('combo').clamp(0, 4),
                    target: 4,
                    iconAsset: 'assets/design/ui/hub_16_img.png',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem({
    required String title,
    required int current,
    required int target,
    required String iconAsset,
  }) {
    final t = (current / target).clamp(0.0, 1.0);
    return Container(
      height: 59,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFEDF0F6), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              iconAsset,
              width: 27,
              height: 27,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.check_circle_outline_rounded,
                size: 24,
                color: Color(0xFFE01E5A),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF141B2A),
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$current',
                            style: GoogleFonts.baloo2(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF141B2A),
                            ),
                          ),
                          TextSpan(
                            text: '/$target',
                            style: GoogleFonts.baloo2(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF66738A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF0F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: t,
                    heightFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFFE01E5A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Günlük Challenge kartı (K2-UI): DailyChallengeService tek kaynaktır;
  // ListenableBuilder ile talep/tamamlanma değişince kart güncellenir.
  // Talep kapısı HER İKİ koşulu denetler: canClaimToday yalnız
  // lastClaimDay'e bakar, completedToday ayrıca şarttır (3A kodu).
  Widget _buildDailyChallengeCard() {
    return ListenableBuilder(
      listenable: DailyChallengeService.instance,
      builder: (context, _) {
        final l10n = context.l10n;
        final daily = DailyChallengeService.instance;
        final claimed = !daily.canClaimToday;
        final claimable = daily.completedToday && daily.canClaimToday;
        final best = daily.bestTowardTarget;
        final target = daily.targetScore;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14141B2A),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Color(0x14141B2A),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment(-0.34, -0.94),
                        end: Alignment(0.34, 0.94),
                        colors: [Color(0xFFFFCF3F), Color(0xFFFFB800)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/icons2/trophy.png',
                      width: 27,
                      height: 27,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.emoji_events_rounded,
                        size: 27,
                        color: Color(0xFF4A2E00),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dailyChallengeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.baloo2(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF141B2A),
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.dailyChallengeHeadline(
                            daily.modeLabel,
                            daily.targetScore,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF66738A),
                            height: 1.38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    enabled: claimable && !_dailyChallengeClaiming,
                    label: claimed ? l10n.claimedShort : l10n.claimReward,
                    child: GestureDetector(
                      key: const Key('daily_challenge_claim_hub'),
                      onTap: claimable && !_dailyChallengeClaiming
                          ? _claimDailyChallenge
                          : null,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          gradient: claimable
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF37E08B),
                                    Color(0xFF12B76A),
                                  ],
                                )
                              : null,
                          color: claimable ? null : const Color(0xFFE2E6EE),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: claimable
                              ? const [
                                  BoxShadow(
                                    color: Color(0xFF066C3C),
                                    offset: Offset(0, 3),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            claimed ? l10n.claimedShort : l10n.claimReward,
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: claimable
                                  ? Colors.white
                                  : const Color(0xFF8E9CAE),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF0F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: daily.progressTowardTarget,
                  heightFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0xFFE01E5A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '$best / $target',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF141B2A),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      l10n.rewardCoins(daily.nextClaimRewardCoins),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF8A6D00),
                      ),
                    ),
                  ),
                ],
              ),
              if (!claimed && !daily.completedToday) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.dailyChallengeHint,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF66738A),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Kampanya haritası girişi (K3-giriş): mevcut hub kart deseninde;
  // harita kendi akışıyla açılır, enerji/kilit mantığı bypass edilmez.
  Widget _buildCampaignEntryCard() {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.campaignMapTitle,
      child: GestureDetector(
        key: const Key('hub_campaign_entry'),
        onTap: _openCampaign,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14141B2A),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Color(0x14141B2A),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF4538B), Color(0xFFE01E5A)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.map_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.campaignMapTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF141B2A),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.campaignHubSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF66738A),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Davet girişi (K17-hub): profil satırıyla aynı başlık/alt yazı;
  // paylaşım FriendInviteService.shareInvite() ile yapılır.
  Widget _buildInviteEntryCard() {
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.profileInviteRowTitle,
      child: GestureDetector(
        key: const Key('hub_invite_entry'),
        onTap: _shareInvite,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14141B2A),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Color(0x14141B2A),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF9B5DE5), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.group_add_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.profileInviteRowTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.baloo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF141B2A),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.profileInviteRowSub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF66738A),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2x2 Mode Grid (#hubModes) matching reference-spec.json
  Widget _buildModeGrid() {
    final l10n = context.l10n;
    final modes = LululuGameMode.catalog;
    final items = <_HubModeData>[
      _HubModeData(
        mode: modes[0],
        title: l10n.suikaArenaTitle,
        subtitle: l10n.suikaArenaSubtitle,
        badge: l10n.badgeHot,
        badgeBg: const Color(0xFFE01E5A),
        badgeFg: Colors.white,
        artBg: const Color(0xFFFFE9C9),
        bugAsset: 'assets/design/ui/hub_6_mascot.webp',
        defaultBest: '4.820',
      ),
      _HubModeData(
        mode: modes[1],
        title: l10n.grid2048Title,
        subtitle: l10n.grid2048Subtitle,
        badge: '2048',
        badgeBg: const Color(0xFFFFB800),
        badgeFg: const Color(0xFF4A2E00),
        artBg: const Color(0xFFFFF0D6),
        bugAsset: _sanitizeStickerAsset(modes[1].stickerAsset),
        defaultBest: '12.480',
      ),
      _HubModeData(
        mode: modes[2],
        title: l10n.balloonPopTitle,
        subtitle: l10n.balloonPopSubtitle,
        badge: l10n.badgeBonus,
        badgeBg: const Color(0xFFFF6B35),
        badgeFg: Colors.white,
        artBg: const Color(0xFFFFE3D6),
        bugAsset: 'assets/design/ui/hub_6_mascot.webp',
        defaultBest: '3.260',
      ),
      _HubModeData(
        mode: modes[3],
        title: l10n.match3Title,
        subtitle: l10n.match3Subtitle,
        badge: l10n.badgeNeon,
        badgeBg: const Color(0xFF00C853),
        badgeFg: const Color(0xFF04140A),
        artBg: const Color(0xFFDFF7EA),
        bugAsset: _sanitizeStickerAsset(modes[3].stickerAsset),
        defaultBest: '5.940',
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildModeCard(items[0])),
            const SizedBox(width: 12),
            Expanded(child: _buildModeCard(items[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildModeCard(items[2])),
            const SizedBox(width: 12),
            Expanded(child: _buildModeCard(items[3])),
          ],
        ),
      ],
    );
  }

  Widget _buildModeCard(_HubModeData item) {
    final l10n = context.l10n;
    final kind = LululuRoutes.fromModeId(item.mode.id);
    final bestVal = LeaderboardService.instance.getBest(
      _leaderboardIdFor(kind),
    );
    final bestText = bestVal > 0 ? '$bestVal' : item.defaultBest;

    return Semantics(
      button: true,
      label: l10n.modeOpenLabel(item.title, item.subtitle, bestText),
      child: GestureDetector(
        onTap: () => _launchMode(kind),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 205,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14141B2A),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Color(0x14141B2A),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // .art (height: 74, borderRadius: 16, marginBottom: 9)
                  Container(
                    height: 74,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: item.artBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          _sanitizeStickerAsset(item.bugAsset),
                          height: 74,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Image.asset(
                            'assets/images/stickers/sticker_tier1_cone.png',
                            height: 64,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Positioned(
                          right: 6,
                          bottom: 5,
                          child: Image.asset(
                            'assets/design/ui/hub_15_img.png',
                            width: 33,
                            height: 33,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.play_circle_fill_rounded,
                              size: 33,
                              color: Color(0xFFE01E5A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF141B2A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF66738A),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Image.asset(
                        'assets/design/ui/hub_19_img.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.emoji_events_rounded,
                          size: 18,
                          color: Color(0xFF8A6D00),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          l10n.recordWithValue(bestText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF8A6D00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: -3,
                top: -3,
                child: Transform.rotate(
                  angle: -0.1047,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: item.badgeBg,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      item.badge,
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: item.badgeFg,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Studio Card — .studio-card (w: 106, h: 130.3, r: 20)
  Widget _buildStudioCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return Semantics(
      button: true,
      label: '$title: $subtitle',
      child: GestureDetector(
        onTap: () {
          AudioManager().playPop();
          onTap();
        },
        child: Container(
          width: 106,
          height: 130.3,
          padding: const EdgeInsets.fromLTRB(8, 13, 8, 11),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14141B2A),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Color(0x14141B2A),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2E000000),
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 29),
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF141B2A),
                    height: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF66738A),
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubModeData {
  const _HubModeData({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeBg,
    required this.badgeFg,
    required this.artBg,
    required this.bugAsset,
    required this.defaultBest,
  });

  final LululuGameMode mode;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeBg;
  final Color badgeFg;
  final Color artBg;
  final String bugAsset;
  final String defaultBest;
}

class _StatusBarIconsPainter extends CustomPainter {
  const _StatusBarIconsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFF141B2A);
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Signal bars (0..15, 0..15) based on viewBox 0 0 24 24
    const s = 15.0 / 24.0;
    canvas.drawRect(
      const Rect.fromLTWH(2 * s, 17 * s, 3 * s, 4 * s),
      fillPaint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(7.5 * s, 13 * s, 3 * s, 8 * s),
      fillPaint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(13 * s, 9 * s, 3 * s, 12 * s),
      fillPaint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(18.5 * s, 5 * s, 3 * s, 16 * s),
      fillPaint,
    );

    // 2. Wifi icon (x offset 20, 0..15)
    canvas.save();
    canvas.translate(20, 0);
    final wifiStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round;
    final wifiPath = Path()
      ..moveTo(4 * s, 10.5 * s)
      ..quadraticBezierTo(12 * s, 4.5 * s, 20 * s, 10.5 * s)
      ..moveTo(7 * s, 14 * s)
      ..quadraticBezierTo(12 * s, 10.2 * s, 17 * s, 14 * s);
    canvas.drawPath(wifiPath, wifiStroke);
    canvas.drawCircle(Offset(12 * s, 17.6 * s), 1.4 * s, fillPaint);
    canvas.restore();

    // 3. Battery icon (x offset 40, 0..15)
    canvas.save();
    canvas.translate(40, 0);
    final batStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.5 * s, 8 * s, 17 * s, 9 * s),
        const Radius.circular(2.5 * s),
      ),
      batStroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.5 * s, 10 * s, 10 * s, 5 * s),
        const Radius.circular(1.0 * s),
      ),
      fillPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CssBottomShadowPainter extends CustomPainter {
  const _CssBottomShadowPainter({
    required this.radius,
    required this.offsetY,
    required this.shadowColor,
    this.insetStrokeColor,
    this.outerBorderWidth = 2.0,
  });

  final double radius;
  final double offsetY;
  final Color shadowColor;
  final Color? insetStrokeColor;
  final double outerBorderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final baseRRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final shiftedRRect = baseRRect.shift(Offset(0, offsetY));
    final shadowPath = Path.combine(
      PathOperation.difference,
      Path()..addRRect(shiftedRRect),
      Path()..addRRect(baseRRect),
    );
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = shadowColor
        ..style = PaintingStyle.fill,
    );

    if (insetStrokeColor != null) {
      final insetRect = (Offset.zero & size).deflate(outerBorderWidth + 0.5);
      final insetRRect = RRect.fromRectAndRadius(
        insetRect,
        Radius.circular((radius - outerBorderWidth - 0.5).clamp(0.0, radius)),
      );
      canvas.drawRRect(
        insetRRect,
        Paint()
          ..color = insetStrokeColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CssBottomShadowPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.offsetY != offsetY ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.insetStrokeColor != insetStrokeColor;
}

class _LockIconPainter extends CustomPainter {
  const _LockIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0xFFFFCF3F);
    final s = size.width / 24.0;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * s
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5 * s, 10.5 * s, 14 * s, 9.5 * s),
        Radius.circular(2.5 * s),
      ),
      fillPaint,
    );

    final shackle = Path()
      ..moveTo(8 * s, 10.5 * s)
      ..lineTo(8 * s, 7.8 * s)
      ..arcToPoint(
        Offset(16 * s, 7.8 * s),
        radius: Radius.circular(4 * s),
        clockwise: true,
      )
      ..lineTo(16 * s, 10.5 * s);
    canvas.drawPath(shackle, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RealBoxShadowPainter extends CustomPainter {
  const _RealBoxShadowPainter({
    required this.radius,
    required this.shadows,
  });

  final double radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (final s in shadows) {
      final spreadRect = rect.inflate(s.spreadRadius).shift(s.offset);
      final rrect = RRect.fromRectAndRadius(
        spreadRect,
        Radius.circular((radius + s.spreadRadius).clamp(0.0, 999.0)),
      );
      final paint = Paint()..color = s.color;
      if (s.blurRadius > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma);
      }
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RealBoxShadowPainter oldDelegate) => false;
}
