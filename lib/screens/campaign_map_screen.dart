import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/campaign_level.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arena_prop_glb.dart';
import '../widgets/dot_background.dart';
import '../widgets/energy_empty_popup.dart';
import '../widgets/shop_dialog.dart';
import 'game_screen.dart';
import 'grid_2048_screen.dart';

class CampaignMapScreen extends StatefulWidget {
  const CampaignMapScreen({super.key});

  @override
  State<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends State<CampaignMapScreen> {
  final progress = ProgressManager();
  int _selectedChapter = 1;
  bool _isStartingLevel = false;

  /// 4 regions × 20 levels = 80. Colors from LululuColors only.
  /// Chapter names are localized (getter, not const: context.l10n is runtime).
  List<(int, String, String, Color)> get _chapters => [
    (1, context.l10n.campaignChapter1, '🍳', LululuColors.coralFlare),
    (2, context.l10n.campaignChapter2, '👑', LululuColors.liquidGold),
    (3, context.l10n.campaignChapter3, '🎬', LululuColors.cyberFuchsia),
    (4, context.l10n.campaignChapter4, '⚡', LululuColors.toxicNeon),
  ];

  @override
  void initState() {
    super.initState();
    progress.addListener(_onProgressUpdated);
  }

  @override
  void dispose() {
    progress.removeListener(_onProgressUpdated);
    super.dispose();
  }

  void _onProgressUpdated() {
    if (mounted) setState(() {});
  }

  String _chapterBackground(int chapter) {
    switch (chapter) {
      case 2:
      case 3:
        return 'assets/design/backgrounds/osmantus_mansion.webp';
      default:
        return 'assets/design/backgrounds/suika_kitchen.webp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = CampaignDatabase.getLevelsForChapter(_selectedChapter);

    return Scaffold(
      backgroundColor: LululuColors.carbonVoid,
      body: DotBackground(
        gradient: LululuGradients.carbonToNavy,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.14,
                child: Image.asset(
                  _chapterBackground(_selectedChapter),
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, _) {
                    debugPrint(
                      '[CampaignMap] Bölüm arka planı yüklenemedi: '
                      '${_chapterBackground(_selectedChapter)} ($error)',
                    );
                    return Container(
                      color: LululuColors.spaceNavy,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: LululuColors.mutedTitanium,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: ArenaPropGlb(
                  kind: _selectedChapter <= 2
                      ? ArenaPropKind.bee
                      : ArenaPropKind.bee,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 10),
                  _buildModeSwitcherBanner(),
                  const SizedBox(height: 10),
                  _buildChapterSelector(),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _buildLevelsGrid(levels),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitcherBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: LululuColors.liquidGold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LululuColors.liquidGold, width: 2),
              ),
              child: Center(
                child: Text(
                  context.l10n.campaignSuikaHeader,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.liquidGold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              label: context.l10n.play2048Label,
              child: GestureDetector(
                onTap: _open2048,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LululuGradients.fuchsiaToGold,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: LululuColors.coralFlare.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        context.l10n.campaign2048Header,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: LululuColors.carbonVoid,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: LululuColors.carbonVoid,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// B17-geri: kampanya haritası hub menüsüne bağlı değildir (bağlantı
  /// kararı bekliyor — bu düğme bağlantı yapmaz, yalnız gezinir):
  /// geride rota varsa geri döner, yoksa hub yedeğine gider.
  Future<void> _goBack() async {
    AudioManager().playPop();
    final popped = await Navigator.of(context).maybePop();
    if (!popped && mounted) {
      await goTo(context, LululuRoutes.hub, replace: true);
    }
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: context.l10n.goBackLabel,
                  child: GestureDetector(
                    onTap: _goBack,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: LululuColors.carbonVoid.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: LululuColors.liquidGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: LululuColors.liquidGold,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset('assets/design/bugs_hd/tier1_hd.png', width: 34, height: 34),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LÜLÜLÜ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: LululuColors.liquidGold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        context.l10n.campaignMapTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: LululuColors.mutedTitanium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: LululuColors.carbonVoid.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: LululuColors.liquidGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '${progress.totalStars}/${CampaignDatabase.totalLevels * 3}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: LululuColors.warningSolar,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: LululuColors.carbonVoid.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: LululuColors.liquidGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 4),
                    Text(
                      '${progress.coins}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: LululuColors.liquidGold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: context.l10n.navShop,
                child: IconButton(
                  tooltip: context.l10n.navShop,
                  icon: const Icon(
                    Icons.storefront,
                    color: LululuColors.liquidGold,
                    size: 26,
                  ),
                  onPressed: () => ShopDialog.show(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterSelector() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _chapters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final ch = _chapters[idx];
          final isSelected = ch.$1 == _selectedChapter;
          return Semantics(
            button: true,
            label: context.l10n.chapterLabel(ch.$1),
            selected: isSelected,
            child: GestureDetector(
              onTap: () => setState(() => _selectedChapter = ch.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ch.$4
                      : LululuColors.darkObsidian.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? LululuColors.liquidGold
                        : LululuColors.mutedTitanium.withValues(alpha: 0.6),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: ch.$4.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Text(ch.$3, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      ch.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w900 : FontWeight.w600,
                        color: isSelected
                            ? LululuColors.carbonVoid
                            : LululuColors.mutedTitanium,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      () {
                        final levels =
                            CampaignDatabase.getLevelsForChapter(ch.$1);
                        var earned = 0;
                        for (final l in levels) {
                          earned += progress.getStarCount(l.id);
                        }
                        final maxStars = levels.length * 3;
                        return '$earned/$maxStars';
                      }(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? LululuColors.carbonVoid.withValues(alpha: 0.75)
                            : LululuColors.liquidGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLevelsGrid(List<CampaignLevel> levels) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: levels.length,
      itemBuilder: (context, idx) {
        final level = levels[idx];
        final isUnlocked = progress.isLevelUnlocked(level.id);
        final stars = progress.getStarCount(level.id);
        final isFrontier = isUnlocked && level.id == progress.unlockedLevel;

        return _LevelMapTile(
          level: level,
          isUnlocked: isUnlocked,
          stars: stars,
          isFrontier: isFrontier,
          onTap: isUnlocked ? () => _showLevelStartModal(level) : null,
        );
      },
    );
  }

  /// 2048 girişini enerji kapısından geçirerek açar.
  ///
  /// [_startLevel] ile aynı kapı: [EnergyService.tryConsume] başarısızsa
  /// enerji-boş popup'ı gösterilir ve 2048 açılmaz.
  Future<void> _open2048() async {
    if (_isStartingLevel) return;
    _isStartingLevel = true;
    try {
      final ok = await EnergyService.instance.tryConsume();
      if (!mounted) return;
      if (!ok) {
        await showEnergyEmptyPopup(context);
        return;
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          // K11: enerji yukarıda tüketildi — bayrak true geçilir ki hiç
          // hamle yapılmadan çıkılırsa enerji iade edilsin.
          builder: (_) => const GameAudioGate(
            child: Grid2048Screen(energyConsumed: true),
          ),
        ),
      );
    } finally {
      _isStartingLevel = false;
    }
  }

  /// Kampanya bölümünü enerji kapısından geçirerek başlatır.
  ///
  /// [openGameMode] seviye parametresi almadığı için (her zaman
  /// `kitchenLevel1` + arcade açar) kapı burada
  /// [EnergyService.tryConsume] ile uygulanır. Enerji yoksa bölüm
  /// açılmaz: enerji-boş popup'ı gösterilir ve bölüm seçim sayfası
  /// açık kalır. Girişte günlük "oyna" ilerlemesi kaydedilmez:
  /// ilerleme yalnızca oyun sonu uzlaşmasıyla yazılır.
  Future<void> _startLevel(
    CampaignLevel level,
    BuildContext sheetContext,
  ) async {
    if (_isStartingLevel) return;
    _isStartingLevel = true;
    try {
      final ok = await EnergyService.instance.tryConsume();
      if (!mounted) return;
      if (!ok) {
        if (sheetContext.mounted) {
          await showEnergyEmptyPopup(sheetContext);
        }
        return;
      }
      if (!mounted) return;
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameAudioGate(
            // K11: enerji yukarıda tüketildi — bayrak true geçilir ki
            // hiç hamle yapılmadan çıkılırsa enerji iade edilsin.
            child: GameScreen(level: level, energyConsumed: true),
          ),
        ),
      );
    } finally {
      _isStartingLevel = false;
    }
  }

  void _showLevelStartModal(CampaignLevel level) {
    showModalBottomSheet(
      context: context,
      backgroundColor: LululuColors.carbonVoid.withValues(alpha: 0),
      isScrollControlled: true,
      builder: (context) {
        // Alt çentik / ana ekran göstergesi payı: OYNA düğmesi
        // ekranın alt kenarına dayanmasın.
        final locale = Localizations.localeOf(context);
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: LululuColors.spaceNavy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: LululuColors.liquidGold.withValues(alpha: 0.85),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: LululuColors.carbonVoid.withValues(alpha: 0.85),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: LululuColors.mutedTitanium.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.chapterLabelCaps(level.id),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.liquidGold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                level.chapterNameFor(locale),
                style: const TextStyle(
                  fontSize: 14,
                  color: LululuColors.mutedTitanium,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LululuColors.carbonVoid.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: LululuColors.mutedTitanium.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      context.l10n.levelGoalTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: LululuColors.liquidGold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      level.objectiveDescriptionFor(locale),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: LululuColors.warningSolar,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _ObjectiveChip(
                          icon: level.isSurvival
                              ? Icons.timer_outlined
                              : Icons.sports_esports_outlined,
                          label: level.isSurvival
                              ? context.l10n.secondsLabel(level.timeLimitSeconds)
                              : context.l10n.movesLabel(level.allowedMoves),
                          accent: LululuColors.liquidGold,
                        ),
                        if (!level.isSurvival)
                          _ObjectiveChip(
                            icon: Icons.flag_outlined,
                            label: context.l10n.pointsLabel(level.targetScore),
                            accent: LululuColors.coralFlare,
                          ),
                        if (level.objectiveType ==
                            ObjectiveType.mergeTargetTier)
                          _ObjectiveChip(
                            icon: Icons.merge_type,
                            label: level.targetTier?.nameFor(locale) ?? context.l10n.bareTierLabel,
                            accent: LululuColors.cyberFuchsia,
                          ),
                        _ObjectiveChip(
                          icon: level.hasObstacles
                              ? Icons.block
                              : Icons.check_circle_outline,
                          label: level.obstacleLabelFor(locale),
                          accent: level.hasObstacles
                              ? LululuColors.mysticRuby
                              : LululuColors.toxicNeon,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _startLevel(level, context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LululuColors.liquidGold,
                    foregroundColor: LululuColors.carbonVoid,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 32),
                      SizedBox(width: 8),
                      Text(
                        context.l10n.play,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
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
}

class _ObjectiveChip extends StatelessWidget {
  const _ObjectiveChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelMapTile extends StatefulWidget {
  const _LevelMapTile({
    required this.level,
    required this.isUnlocked,
    required this.stars,
    required this.isFrontier,
    required this.onTap,
  });

  final CampaignLevel level;
  final bool isUnlocked;
  final int stars;
  final bool isFrontier;
  final VoidCallback? onTap;

  @override
  State<_LevelMapTile> createState() => _LevelMapTileState();
}

class _LevelMapTileState extends State<_LevelMapTile> {
  double _pressScale = 1;

  void _setPressed(bool pressed) {
    if (widget.onTap == null) return;
    setState(() => _pressScale = pressed ? 0.92 : 1);
  }

  BoxDecoration _cardDecoration() {
    if (!widget.isUnlocked) {
      return BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LululuColors.darkObsidian, LululuColors.carbonVoid],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: LululuColors.mutedTitanium.withValues(alpha: 0.22),
        ),
      );
    }

    final played = widget.stars > 0;
    final perfect = widget.stars >= 3;

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: played
            ? const [LululuColors.liquidGold, LululuColors.coralFlare]
            : widget.isFrontier
                ? [
                    LululuColors.cyberFuchsia.withValues(alpha: 0.9),
                    LululuColors.liquidGold,
                  ]
                : const [LululuColors.spaceNavy, LululuColors.darkObsidian],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: perfect
            ? LululuColors.warningSolar
            : widget.isFrontier
                ? LululuColors.cyberFuchsia
                : LululuColors.liquidGold.withValues(alpha: played ? 1 : 0.55),
        width: widget.isFrontier || perfect ? 2.5 : 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: (widget.isFrontier
                  ? LululuColors.cyberFuchsia
                  : LululuColors.liquidGold)
              .withValues(
                alpha: widget.isFrontier ? 0.42 : (played ? 0.32 : 0.12),
              ),
          blurRadius: widget.isFrontier ? 14 : 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _kenneyStar({
    required bool filled,
    required KenneyPalette palette,
    double size = 13,
  }) {
    final path = filled
        ? LululuKenneyAssets.starFilled(palette)
        : LululuKenneyAssets.starOutline(palette);
    return Image.asset(
      path,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Icon(
        filled ? Icons.star_rounded : Icons.star_outline_rounded,
        size: size,
        color: filled ? LululuColors.liquidGold : LululuColors.mutedTitanium,
      ),
    );
  }

  Widget _buildStarRow() {
    final palette =
        widget.isUnlocked ? KenneyPalette.yellow : KenneyPalette.blue;
    final starSize = widget.isUnlocked ? 13.0 : 10.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final filled = widget.isUnlocked && i < widget.stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Opacity(
            opacity: widget.isUnlocked ? (filled ? 1 : 0.5) : 0.28,
            child: _kenneyStar(
              filled: filled,
              palette: palette,
              size: starSize,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildModifierDots() {
    if (!widget.isUnlocked) return const SizedBox.shrink();
    final chips = <Widget>[];
    if (widget.level.isSurvival) {
      chips.add(
        Icon(
          Icons.timer,
          size: 9,
          color: LululuColors.warningSolar.withValues(alpha: 0.95),
        ),
      );
    }
    if (widget.level.hasObstacles) {
      chips.add(
        Icon(
          Icons.block,
          size: 9,
          color: LululuColors.mysticRuby.withValues(alpha: 0.95),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            chips[i],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.levelTileLabel(widget.level.id, widget.stars, !widget.isUnlocked),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: _pressScale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: _cardDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            LululuColors.mutedTitanium.withValues(alpha: 0),
                            LululuColors.mutedTitanium.withValues(
                              alpha: widget.isUnlocked ? 0.45 : 0.12,
                            ),
                            LululuColors.mutedTitanium.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.isUnlocked) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: LululuColors.carbonVoid.withValues(
                                alpha: 0.32,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: LululuColors.mutedTitanium.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                            child: Text(
                              '${widget.level.id}',
                              style: TextStyle(
                                fontSize: widget.isFrontier ? 20 : 18,
                                fontWeight: FontWeight.w900,
                                color: LululuColors.warningSolar,
                                shadows: [
                                  Shadow(
                                    color: LululuColors.carbonVoid.withValues(
                                      alpha: 0.45,
                                    ),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (widget.isFrontier) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: LululuColors.cyberFuchsia.withValues(
                                  alpha: 0.35,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                context.l10n.upNextLabel,
                                style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: LululuColors.warningSolar,
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          Icon(
                            Icons.lock_rounded,
                            color: LululuColors.mutedTitanium.withValues(
                              alpha: 0.55,
                            ),
                            size: 26,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.level.id}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: LululuColors.mutedTitanium.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        _buildStarRow(),
                        _buildModifierDots(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
