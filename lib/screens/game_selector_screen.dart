import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lululu_game_mode.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';
import '../widgets/sticker_image.dart';
import '../widgets/top_bar.dart';
import 'modes_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
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
      title: 'VİDEO İZLE',
      subtitle: 'Böcek klipleri ve rekorlar',
      icon: Icons.play_circle_fill_rounded,
      gradient: [Color(0xFFF4538B), LululuColors.cyberFuchsia],
    ),
    _StudioCard(
      title: 'VİDEO YAP',
      subtitle: 'Kırp, yazı ve sticker ekle',
      icon: Icons.auto_fix_high_rounded,
      gradient: [Color(0xFF9B5DE5), Color(0xFF7C3AED)],
    ),
    _StudioCard(
      title: 'YÜKLE',
      subtitle: 'Klibini herkesle paylaş',
      icon: Icons.cloud_upload_rounded,
      gradient: [Color(0xFFFF8A5C), LululuColors.coralFlare],
    ),
    _StudioCard(
      title: 'GIF OLUŞTUR',
      subtitle: 'Böceğini hareketlendir',
      icon: Icons.gif_box_rounded,
      gradient: [Color(0xFF37E08B), Color(0xFF12B76A)],
    ),
    _StudioCard(
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

  void _openStudio(_StudioCard card) {
    AudioManager().playPop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _StudioMockPage(card: card),
      ),
    );
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
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: LululuSectionHeader(
                  title: 'GÜNLÜK GÖREVLER',
                  actionLabel: 'TÜMÜNÜ GÖR',
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

// ─── Stüdyo ──────────────────────────────────────────────────────────────────

class _StudioCard {
  const _StudioCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

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

class _StudioMockPage extends StatelessWidget {
  const _StudioMockPage({required this.card});

  final _StudioCard card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        title: Text(
          card.title,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: card.gradient,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  card.icon,
                  color: LululuColors.paper,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                card.title,
                style: GoogleFonts.exo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.inkDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stüdyo yakında burada — bu ekran yer tutucu.',
                textAlign: TextAlign.center,
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  color: LululuColors.mutedTitanium,
                ),
              ),
            ],
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
