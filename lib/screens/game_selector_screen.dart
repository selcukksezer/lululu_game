import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lululu_game_mode.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/ad_mock.dart';
import '../widgets/daily_reward_dialog.dart';
import '../widgets/lululu_press.dart';
import '../widgets/sticker_image.dart';
import '../widgets/top_bar.dart';
import 'bug_video_hub_screen.dart';
import 'chat_lobby_screen.dart';
import 'modes_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'sticker_gif_screen.dart';
import 'studio_downloads_screen.dart';
import 'studio_upload_screen.dart';
import 'tasks_screen.dart';

/// ANA SAYFA sekmesi — açık tema hub.
///
/// Hero (LÜLÜLÜ + HEMEN OYNA) → STÜDYO bloğu → GÜNLÜK GÖREVLER özeti →
/// 10 modun kart listesi. Üst bar `LululuTopBar` (ayrı dosya).
class GameSelectorScreen extends StatefulWidget {
  const GameSelectorScreen({
    super.key,
    this.onOpenMap,
    this.onOpenBoard,
    this.onOpenChat,
    this.onOpenAuth,
    this.onOpenShop,
  });

  // home_shell.dart geriye uyumluluğu için opsiyonel tutuldu.
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenBoard;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenAuth;
  final VoidCallback? onOpenShop;

  @override
  State<GameSelectorScreen> createState() => _GameSelectorScreenState();
}

class _GameSelectorScreenState extends State<GameSelectorScreen> {
  static const _studioCards = <_StudioCard>[
    _StudioCard(
      action: _StudioAction.watch,
      title: 'VİDEO İZLE',
      subtitle: 'Böcek klipleri ve rekorlar',
      icon: Icons.play_circle_fill_rounded,
      gradient: [Color(0xFFF4538B), LululuColors.cyberFuchsia],
    ),
    _StudioCard(
      action: _StudioAction.create,
      title: 'VİDEO YAP',
      subtitle: 'Kırp, yazı ve sticker ekle',
      icon: Icons.auto_fix_high_rounded,
      gradient: [Color(0xFF9B5DE5), Color(0xFF7C3AED)],
    ),
    _StudioCard(
      action: _StudioAction.upload,
      title: 'YÜKLE',
      subtitle: 'Klibini herkesle paylaş',
      icon: Icons.cloud_upload_rounded,
      gradient: [Color(0xFFFF8A5C), LululuColors.coralFlare],
    ),
    _StudioCard(
      action: _StudioAction.gif,
      title: 'GIF OLUŞTUR',
      subtitle: 'Böceğini hareketlendir',
      icon: Icons.gif_box_rounded,
      gradient: [Color(0xFF37E08B), Color(0xFF12B76A)],
    ),
    _StudioCard(
      action: _StudioAction.downloads,
      title: 'İNDİRİLENLER',
      subtitle: 'Çevrimdışı arşivin',
      icon: Icons.download_rounded,
      gradient: [Color(0xFFFFCF3F), LululuColors.liquidGold],
    ),
  ];

  // Hub özetiyle birebir aynı başlıklar (tasks_screen.dart'taki mock set).
  static const _taskSummaries = <_TaskSummary>[
    _TaskSummary(title: '3 OYUN OYNA', progress: 1, target: 3),
    _TaskSummary(title: '5 BİRLEŞTİRME YAP', progress: 3, target: 5),
    _TaskSummary(title: '1 VİDEO İZLE', progress: 1, target: 1),
    _TaskSummary(title: 'X4 KOMBO YAP', progress: 2, target: 4),
  ];

  void _openProfile() {
    AudioManager().playPop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
    );
  }

  void _openSettings() {
    AudioManager().playPop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  void _openTasks() {
    AudioManager().playPop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TasksScreen()),
    );
  }

  void _openModes() {
    AudioManager().playPop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModesScreen()),
    );
  }

  void _openChat() {
    AudioManager().playPop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChatLobbyScreen()),
    );
  }

  void _openStudio(_StudioCard card) {
    AudioManager().playPop();
    late final Widget page;
    switch (card.action) {
      case _StudioAction.watch:
        page = const BugVideoHubScreen(initial: BugVideoTab.watch);
      case _StudioAction.create:
        page = const BugVideoHubScreen(initial: BugVideoTab.create);
      case _StudioAction.upload:
        page = const StudioUploadScreen();
      case _StudioAction.gif:
        page = const StickerGifScreen();
      case _StudioAction.downloads:
        page = const StudioDownloadsScreen();
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _rewardSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// AL · 500 — doğrudan 500 coin verir.
  Future<void> _claimDailyCoins() async {
    AudioManager().playWin();
    await ProgressManager().addCoins(500);
    if (!mounted) return;
    _rewardSnack('500 COİN ALINDI');
  }

  /// REKLAM → 2X · 1.000 — reklam izletip 1000 coin verir.
  Future<void> _claimDailyDouble() async {
    final watched = await showRewardedAdMock(
      context,
      rewardLabel: '1.000 COİN',
    );
    if (!watched) return;
    AudioManager().playWin();
    await ProgressManager().addCoins(1000);
    if (!mounted) return;
    _rewardSnack('1.000 COİN ALINDI');
  }

  /// ENERJİ AL · +5 — reklamla +5 enerji verir.
  Future<void> _claimDailyEnergy() async {
    final watched = await showRewardedAdMock(
      context,
      rewardLabel: '+5 ENERJİ',
    );
    if (!watched) return;
    AudioManager().playWin();
    EnergyService.instance.addEnergy(5);
    if (!mounted) return;
    _rewardSnack('+5 ENERJİ ALINDI');
  }

  @override
  Widget build(BuildContext context) {
    final featured = LululuGameMode.featuredMode;
    final modes = LululuGameMode.catalog;

    return Scaffold(
      backgroundColor: LululuColors.paper,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: LululuTopBar(
                  light: true,
                  onProfileTap: _openProfile,
                  onSettingsTap: _openSettings,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _HeroPlay(
                  mode: featured,
                  onPlay: _openModes,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _OnlineSoonBlock(
                  onNotify: () {
                    AudioManager().playPop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Bildirimler açılınca haber vereceğiz',
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ChatCard(onTap: _openChat),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 0, 12),
                child: Text(
                  'STÜDYO',
                  style: GoogleFonts.exo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: LululuColors.inkDark,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _studioCards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final card = _studioCards[i];
                    return _StudioTile(
                      card: card,
                      onTap: () => _openStudio(card),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _DailyRewardSection(
                  onHeaderTap: () => showDailyRewardDialog(context),
                  onClaimCoins: _claimDailyCoins,
                  onClaimDouble: _claimDailyDouble,
                  onClaimEnergy: _claimDailyEnergy,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: LululuSectionHeader(
                  title: 'GÜNLÜK GÖREVLER',
                  subtitle: 'Görevleri bitir, ödülü kap!',
                  actionLabel: 'Tümü →',
                  onAction: _openTasks,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: LululuColors.paperSoft,
                    borderRadius:
                        BorderRadius.circular(LululuRadii.card),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _taskSummaries.length; i++) ...[
                        _TaskSummaryRow(summary: _taskSummaries[i]),
                        if (i < _taskSummaries.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: LululuSectionHeader(
                  title: 'OYUN MODLARI',
                  actionLabel: 'TÜMÜ',
                  onAction: _openModes,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final mode = modes[i];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      i == modes.length - 1 ? 120 : 10,
                    ),
                    child: _ModeRow(
                      mode: mode,
                      onTap: () {
                        AudioManager().playPop();
                        openGameMode(context, mode.kind);
                      },
                    ),
                  );
                },
                childCount: modes.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroPlay extends StatelessWidget {
  const _HeroPlay({required this.mode, required this.onPlay});

  final LululuGameMode mode;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onPlay,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 16 / 11,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration:
                    BoxDecoration(gradient: LululuGradients.paperHero),
              ),
              Positioned(
                right: -10,
                bottom: -18,
                child: StickerImage(
                  assetPath: mode.stickerAsset,
                  width: 150,
                  height: 150,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 110, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LÜLÜLÜ',
                      style: GoogleFonts.bangers(
                        fontSize: 40,
                        letterSpacing: 2,
                        color: LululuColors.paper,
                      ),
                    ),
                    Text(
                      mode.title,
                      style: GoogleFonts.exo2(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: LululuColors.paper,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mode.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        color:
                            LululuColors.paper.withValues(alpha: 0.92),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 22),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: LululuColors.inkDark,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'HEMEN OYNA',
                        style: GoogleFonts.exo2(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: LululuColors.liquidGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Online Mod Yakında ──────────────────────────────────────────────────────

class _OnlineSoonBlock extends StatelessWidget {
  const _OnlineSoonBlock({required this.onNotify});

  final VoidCallback onNotify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LululuColors.paperSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LululuColors.mutedTitanium.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: LululuColors.carbonVoid.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Kilitli böcek görseli (gerçek asset, gri ton).
          Stack(
            alignment: Alignment.center,
            children: [
              ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.saturation,
                ),
                child: StickerImage(
                  assetPath: 'assets/design/bugs_hd/tier8_hd.png',
                  width: 76,
                  height: 76,
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LululuColors.carbonVoid
                      .withValues(alpha: 0.72),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: LululuColors.liquidGold,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ONLİNE MOD',
                      style: GoogleFonts.exo2(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: LululuColors.inkDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: LululuColors.liquidGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'YAKINDA',
                        style: GoogleFonts.exo2(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: LululuColors.carbonVoid,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Çok yakında arkadaşlarınla çevrimiçi oyna!',
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
                const SizedBox(height: 10),
                LululuPress(
                  onTap: onNotify,
                  child: Container(
                    constraints:
                        const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: LululuColors.inkDark,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'HABERDAR ET',
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: LululuColors.liquidGold,
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
}

// ─── Sohbet kartı ────────────────────────────────────────────────────────────

class _ChatCard extends StatelessWidget {
  const _ChatCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LululuColors.cyberFuchsia,
              Color(0xFF9B5DE5),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: LululuColors.cyberFuchsia
                  .withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            StickerImage(
              assetPath: 'assets/design/bugs_hd/tier4_hd.png',
              width: 56,
              height: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOHBET',
                    style: GoogleFonts.exo2(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: LululuColors.paper,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lobide muhabbet et, rekorları konuş',
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          LululuColors.paper.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: LululuColors.toxicNeon
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: LululuColors.toxicNeon,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '5 ÇEVRİMİÇİ',
                    style: GoogleFonts.exo2(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.paper,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: LululuColors.paper,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stüdyo ──────────────────────────────────────────────────────────────────

enum _StudioAction { watch, create, upload, gif, downloads }

class _StudioCard {
  const _StudioCard({
    required this.action,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final _StudioAction action;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
}

class _StudioTile extends StatelessWidget {
  const _StudioTile({required this.card, required this.onTap});

  final _StudioCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LululuColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: card.gradient,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(card.icon, color: LululuColors.paper, size: 22),
            ),
            const Spacer(),
            Text(
              card.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.exo2(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: LululuColors.inkDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              card.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.exo2(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: LululuColors.mutedTitanium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Günlük Ödül ─────────────────────────────────────────────────────────────

/// Prototip (scr-hub) içeriği: "Günlük Ödül · 3. gün · 500 coin seni bekliyor".
///
/// Başlığa dokununca [showDailyRewardDialog] açılır (içeriği başka ekip
/// üyesi hizalıyor); butonlar hub tarafında ödülü verir:
/// AL → +500 coin, REKLAM → reklam sonrası +1000 coin, ENERJİ → +5 enerji.
class _DailyRewardSection extends StatelessWidget {
  const _DailyRewardSection({
    required this.onHeaderTap,
    required this.onClaimCoins,
    required this.onClaimDouble,
    required this.onClaimEnergy,
  });

  final VoidCallback onHeaderTap;
  final VoidCallback onClaimCoins;
  final VoidCallback onClaimDouble;
  final VoidCallback onClaimEnergy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LululuGradients.warmFeature,
        borderRadius: BorderRadius.circular(LululuRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LululuPress(
            onTap: onHeaderTap,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    gradient: LululuGradients.fuchsiaToGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: LululuColors.paper,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GÜNLÜK ÖDÜL',
                        style: GoogleFonts.exo2(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: LululuColors.paper,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '3. gün · 500 coin seni bekliyor',
                        style: GoogleFonts.exo2(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              LululuColors.paper.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: LululuColors.paper,
                  size: 26,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DailyRewardButton(
                  label: 'AL · 500',
                  background: LululuColors.paper,
                  foreground: LululuColors.cyberFuchsia,
                  onTap: onClaimCoins,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DailyRewardButton(
                  label: 'REKLAM → 2X · 1.000',
                  background: LululuColors.inkDark,
                  foreground: LululuColors.liquidGold,
                  onTap: onClaimDouble,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DailyRewardButton(
                  label: 'ENERJİ AL · +5',
                  background: LululuColors.toxicNeon,
                  foreground: LululuColors.carbonVoid,
                  onTap: onClaimEnergy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyRewardButton extends StatelessWidget {
  const _DailyRewardButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minHeight: LululuMotion.minTap,
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.exo2(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            height: 1.15,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

// ─── Görev özeti ─────────────────────────────────────────────────────────────

class _TaskSummary {
  const _TaskSummary({
    required this.title,
    required this.progress,
    required this.target,
  });

  final String title;
  final int progress;
  final int target;
}

class _TaskSummaryRow extends StatelessWidget {
  const _TaskSummaryRow({required this.summary});

  final _TaskSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = (summary.progress / summary.target).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary.title,
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: LululuColors.inkDark,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: t,
                  minHeight: 8,
                  backgroundColor:
                      LululuColors.mutedTitanium.withValues(alpha: 0.18),
                  color: LululuColors.cyberFuchsia,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${summary.progress}/${summary.target}',
          style: GoogleFonts.exo2(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: LululuColors.mutedTitanium,
          ),
        ),
      ],
    );
  }
}

// ─── Mod satırı ──────────────────────────────────────────────────────────────

class _ModeRow extends StatelessWidget {
  const _ModeRow({required this.mode, required this.onTap});

  final LululuGameMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: LululuColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: mode.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: StickerImage(
                  assetPath: mode.stickerAsset,
                  width: 44,
                  height: 44,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.exo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: LululuColors.inkDark,
                          ),
                        ),
                      ),
                      if (mode.badge != null)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: mode.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            mode.badge!,
                            style: GoogleFonts.exo2(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: mode.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: LululuColors.mutedTitanium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.play_circle_fill_rounded,
              color: LululuColors.cyberFuchsia,
              size: 34,
            ),
          ],
        ),
      ),
    );
  }
}
