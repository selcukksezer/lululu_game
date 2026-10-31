import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lululu_game_mode.dart';
import '../navigation/game_routes.dart';
import '../services/auth_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/shop_dialog.dart';
import '../widgets/sticker_image.dart';
import 'auth_screen.dart';
import 'sticker_gif_screen.dart';

enum _ModeFilter { all, arcade, viral }

/// Ana sayfa — ui-design-brain: restraint, tek hero CTA, 8px grid, beyaz canvas.
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
  _ModeFilter _filter = _ModeFilter.all;

  static const _viralKinds = {
    GameModeKind.osmantus,
    GameModeKind.screamRoach,
    GameModeKind.makarayiz,
    GameModeKind.terlikTap,
  };

  List<LululuGameMode> _filtered(List<LululuGameMode> modes) {
    return switch (_filter) {
      _ModeFilter.all => modes,
      _ModeFilter.arcade =>
        modes.where((m) => !_viralKinds.contains(m.kind)).toList(),
      _ModeFilter.viral =>
        modes.where((m) => _viralKinds.contains(m.kind)).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressManager();
    final featured = LululuGameMode.featuredMode;
    final modes = List<LululuGameMode>.of(LululuGameMode.catalog);
    final shown = _filtered(modes);
    final openShop = widget.onOpenShop ?? () => ShopDialog.show(context);
    final openAuth = widget.onOpenAuth ?? () => AuthScreen.open(context);

    return ListenableBuilder(
      listenable: Listenable.merge([progress, AuthService.instance]),
      builder: (context, _) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // —— Header ——
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _Header(
                  progress: progress,
                  onShop: openShop,
                  onProfile: openAuth,
                ),
              ),
            ),

            // —— Hero (one composition, one CTA) ——
            SoftSlideIn(
              index: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _HeroPlay(
                  mode: featured,
                  onPlay: () => openGameMode(context, featured.kind),
                ),
              ),
            ),

            // —— Vault strip (compact metric, not a second hero) ——
            SoftSlideIn(
              index: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _VaultStrip(
                  progress: progress,
                  onShop: openShop,
                ),
              ),
            ),

            // —— Button group: secondary destinations ——
            SoftSlideIn(
              index: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _ActionGroup(
                  onMap: widget.onOpenMap ?? () {},
                  onBoard: widget.onOpenBoard ?? () {},
                  onShop: openShop,
                  onGif: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StickerGifScreen(),
                    ),
                  ),
                ),
              ),
            ),

            // —— Section + segmented filter ——
            SoftSlideIn(
              index: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oyunlar',
                      style: GoogleFonts.exo2(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: LululuColors.inkDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arcade ve viral modlar',
                      style: GoogleFonts.exo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: LululuColors.mutedTitanium,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SegmentedFilter(
                      selected: _filter,
                      onSelect: (f) => setState(() => _filter = f),
                    ),
                  ],
                ),
              ),
            ),

            // —— Mode grid ——
            if (shown.isEmpty)
              SoftSlideIn(
                index: 4,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 120),
                  child: _EmptyModes(),
                ),
              )
            else
              SoftSlideIn(
                index: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 420;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: shown.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: wide ? 3 : 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: wide ? 0.78 : 0.8,
                        ),
                        itemBuilder: (context, i) {
                          final mode = shown[i];
                          return _ModeCard(
                            mode: mode,
                            index: i,
                            onTap: () => openGameMode(context, mode.kind),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── SoftSlideIn as Sliver ───────────────────────────────────────────────────

class SoftSlideIn extends StatelessWidget {
  const SoftSlideIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + index * 60),
        curve: Curves.easeOutCubic,
        builder: (context, t, c) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 14),
            child: c,
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.progress,
    required this.onShop,
    required this.onProfile,
  });

  final ProgressManager progress;
  final VoidCallback onShop;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final name = auth.isSignedIn ? auth.displayName : 'Giriş yap';
    final level = progress.unlockedLevel.clamp(1, 80);
    final xp = (progress.totalStars * 37) % 2000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LÜLÜLÜ',
          style: GoogleFonts.exo2(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 3.2,
            color: LululuColors.mutedTitanium,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricChip(
                icon: Icons.star_rounded,
                iconColor: LululuColors.liquidGold,
                value: _fmt(progress.totalStars),
                label: 'Yıldız',
              ),
            ),
            const SizedBox(width: 10),
            _AvatarButton(
              name: name,
              level: level,
              xp: xp,
              signedIn: auth.isSignedIn,
              onTap: onProfile,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Press(
                onTap: onShop,
                child: _MetricChip(
                  icon: Icons.diamond_rounded,
                  iconColor: LululuColors.cyberFuchsia,
                  value: _fmt(progress.coins),
                  label: 'Coin',
                  trailing: Icons.add_rounded,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LululuColors.paperSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LululuColors.mutedTitanium.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.inkDark,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Icon(trailing, size: 18, color: LululuColors.mutedTitanium),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.name,
    required this.level,
    required this.xp,
    required this.signedIn,
    required this.onTap,
  });

  final String name;
  final int level;
  final int xp;
  final bool signedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = (xp / 2000).clamp(0.0, 1.0);
    return _Press(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LululuColors.inkDark,
                border: Border.all(color: LululuColors.liquidGold, width: 2),
              ),
              child: Icon(
                signedIn ? Icons.person_rounded : Icons.login_rounded,
                color: LululuColors.paper,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.exo2(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: LululuColors.inkDark,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: t,
                minHeight: 4,
                backgroundColor:
                    LululuColors.mutedTitanium.withValues(alpha: 0.2),
                color: LululuColors.liquidGold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Sv $level',
              style: GoogleFonts.exo2(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: LululuColors.mutedTitanium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroPlay extends StatefulWidget {
  const _HeroPlay({required this.mode, required this.onPlay});

  final LululuGameMode mode;
  final VoidCallback onPlay;

  @override
  State<_HeroPlay> createState() => _HeroPlayState();
}

class _HeroPlayState extends State<_HeroPlay> {
  Timer? _tick;
  int _secs = 0;

  @override
  void initState() {
    super.initState();
    _secs = ProgressManager().secondsUntilMidnight();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs = ProgressManager().secondsUntilMidnight());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _clock {
    final h = (_secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((_secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    return _Press(
      onTap: widget.onPlay,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 16 / 11,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LululuGradients.paperHero),
              ),
              CustomPaint(
                painter: _DotsPainter(
                  color: LululuColors.paper.withValues(alpha: 0.12),
                ),
              ),
              Positioned(
                right: -8,
                bottom: -16,
                child: StickerImage(
                  assetPath: mode.stickerAsset,
                  width: 150,
                  height: 150,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 100, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mode.badge != null)
                      _Badge(label: mode.badge!, tone: _BadgeTone.dark),
                    const Spacer(),
                    Text(
                      mode.title,
                      style: GoogleFonts.exo2(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.6,
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
                        color: LululuColors.paper.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: LululuColors.inkDark,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Hemen oyna',
                            style: GoogleFonts.exo2(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: LululuColors.liquidGold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: LululuColors.paper.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _clock,
                          style: GoogleFonts.exo2(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: LululuColors.paper,
                          ),
                        ),
                      ],
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

// ─── Vault strip ─────────────────────────────────────────────────────────────

class _VaultStrip extends StatelessWidget {
  const _VaultStrip({required this.progress, required this.onShop});

  final ProgressManager progress;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: LululuColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: LululuColors.liquidGold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: LululuColors.liquidGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: LululuColors.liquidGold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kasa',
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
                Text(
                  _fmt(progress.inventoryValue),
                  style: GoogleFonts.exo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.inkDark,
                  ),
                ),
                Text(
                  'T${progress.slipperCount} · S${progress.sprayCount} · L${progress.aydinlatCount}',
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
              ],
            ),
          ),
          _Press(
            onTap: onShop,
            child: Text(
              'Dükkan',
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: LululuColors.cyberFuchsia,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: LululuColors.cyberFuchsia,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ─── Action group ────────────────────────────────────────────────────────────

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({
    required this.onMap,
    required this.onBoard,
    required this.onShop,
    required this.onGif,
  });

  final VoidCallback onMap;
  final VoidCallback onBoard;
  final VoidCallback onShop;
  final VoidCallback onGif;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SecondaryAction(
            label: 'Harita',
            icon: Icons.map_rounded,
            primary: true,
            onTap: onMap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SecondaryAction(
            label: 'Sıra',
            icon: Icons.emoji_events_outlined,
            onTap: onBoard,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SecondaryAction(
            label: 'GIF',
            icon: Icons.gif_box_outlined,
            onTap: onGif,
          ),
        ),
      ],
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return _Press(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? LululuColors.inkDark : LululuColors.paperSoft,
          borderRadius: BorderRadius.circular(14),
          border: primary
              ? null
              : Border.all(
                  color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: primary
                  ? LululuColors.liquidGold
                  : LululuColors.inkDark,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: primary
                    ? LululuColors.paper
                    : LululuColors.inkDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Segmented filter ────────────────────────────────────────────────────────

class _SegmentedFilter extends StatelessWidget {
  const _SegmentedFilter({
    required this.selected,
    required this.onSelect,
  });

  final _ModeFilter selected;
  final ValueChanged<_ModeFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = const [
      (_ModeFilter.all, 'Tümü'),
      (_ModeFilter.arcade, 'Arcade'),
      (_ModeFilter.viral, 'Viral'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LululuColors.paperSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _Press(
                onTap: () => onSelect(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  constraints: const BoxConstraints(minHeight: 40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == item.$1
                        ? LululuColors.paper
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: selected == item.$1
                        ? [
                            BoxShadow(
                              color: LululuColors.inkDark
                                  .withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    item.$2,
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: selected == item.$1
                          ? LululuColors.inkDark
                          : LululuColors.mutedTitanium,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Mode card ───────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.index,
    required this.onTap,
  });

  final LululuGameMode mode;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: mode.title,
      identifier: 'mode_${mode.kind.name}',
      child: _Press(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: LululuColors.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: LululuColors.mutedTitanium.withValues(alpha: 0.28),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotsPainter(
                    color: LululuColors.mutedTitanium.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (mode.badge != null)
                          _Badge(
                            label: mode.badge!,
                            tone: _BadgeTone.accent,
                            accent: mode.accent,
                          ),
                        const Spacer(),
                        Icon(
                          Icons.play_arrow_rounded,
                          color: mode.accent,
                          size: 22,
                        ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: StickerImage(
                          assetPath: mode.stickerAsset,
                          width: 68,
                          height: 68,
                        ),
                      ),
                    ),
                    Text(
                      mode.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: LululuColors.inkDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: LululuColors.mutedTitanium,
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

class _EmptyModes extends StatelessWidget {
  const _EmptyModes();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: LululuColors.paperSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.sports_esports_outlined,
            size: 40,
            color: LululuColors.mutedTitanium,
          ),
          const SizedBox(height: 12),
          Text(
            'Bu filtrede oyun yok',
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: LululuColors.inkDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tümü sekmesine dön',
            style: GoogleFonts.exo2(
              fontSize: 13,
              color: LululuColors.mutedTitanium,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared ──────────────────────────────────────────────────────────────────

enum _BadgeTone { dark, accent }

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.tone,
    this.accent,
  });

  final String label;
  final _BadgeTone tone;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _BadgeTone.dark
        ? LululuColors.inkDark.withValues(alpha: 0.35)
        : (accent ?? LululuColors.liquidGold).withValues(alpha: 0.14);
    final fg = tone == _BadgeTone.dark
        ? LululuColors.paper
        : (accent ?? LululuColors.liquidGold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.exo2(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _Press extends StatefulWidget {
  const _Press({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? LululuMotion.pressScale : 1,
        duration: LululuMotion.pressDuration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 16.0;
    for (double y = 6; y < size.height; y += step) {
      for (double x = 6; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.15, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) =>
      oldDelegate.color != color;
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}
