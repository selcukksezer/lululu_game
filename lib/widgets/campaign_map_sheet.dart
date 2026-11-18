import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/campaign_level.dart';
import '../services/audio_manager.dart';
import '../services/campaign_progression_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';

/// 8 temalı bölümü, 80 seviye düğümünü (kilitli, açık, 1-3 yıldızlı, Boss tacı ikonlu)
/// ve bölüm yıldız sandıklarını (`10, 20, 30` yıldız) gösteren etkileşimli kampanya haritası modalı.
class CampaignMapSheet extends StatefulWidget {
  final int initialChapterIndex;
  final ValueChanged<CampaignLevel>? onSelectLevel;

  const CampaignMapSheet({
    super.key,
    this.initialChapterIndex = 1,
    this.onSelectLevel,
  });

  /// Etkileşimli kampanya haritasını alt modal olarak açar.
  static Future<CampaignLevel?> show(
    BuildContext context, {
    int initialChapterIndex = 1,
    ValueChanged<CampaignLevel>? onSelectLevel,
  }) {
    return showModalBottomSheet<CampaignLevel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: CampaignMapSheet(
          initialChapterIndex: initialChapterIndex,
          onSelectLevel: onSelectLevel,
        ),
      ),
    );
  }

  @override
  State<CampaignMapSheet> createState() => _CampaignMapSheetState();
}

class _CampaignMapSheetState extends State<CampaignMapSheet> {
  final CampaignProgressionService _progression =
      CampaignProgressionService.instance;
  final ProgressManager _progress = ProgressManager.instance;

  late int _selectedChapterIndex;
  String? _chestFeedbackBanner;
  _FeedbackTone _chestFeedbackTone = _FeedbackTone.success;

  static const List<Color> _chapterAccents = [
    LululuColors.coralFlare,
    LululuColors.orange,
    LululuColors.cyberFuchsia,
    LululuColors.mutedTitanium,
    LululuColors.mysticRuby,
    LululuColors.liquidGold,
    LululuColors.toxicNeon,
    LululuColors.warningSolar,
  ];

  /// Sandık ödülü güçlendirici anahtarlarının büyük harfli görünen adları.
  /// Dart'ın toUpperCase() 'terlik' → 'TERLIK' üretir (doğrusu 'TERLİK');
  /// bilinen anahtarlar bu eşlemeden alınır, bilinmeyen değerde
  /// toUpperCase() yedeğine düşülür.
  static const Map<String, String> _boosterDisplayNames = {
    'terlik': 'TERLİK',
    'raid': 'RAID',
    'f16': 'F16',
  };

  @override
  void initState() {
    super.initState();
    _selectedChapterIndex = widget.initialChapterIndex.clamp(
      1,
      CampaignDatabase.themedChapterCount,
    );
    _progression.addListener(_onProgressionChanged);
    _progress.addListener(_onProgressionChanged);
  }

  @override
  void dispose() {
    _progression.removeListener(_onProgressionChanged);
    _progress.removeListener(_onProgressionChanged);
    super.dispose();
  }

  void _onProgressionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Color _accentForChapter(int chapterIndex) {
    final idx = (chapterIndex - 1).clamp(0, _chapterAccents.length - 1);
    return _chapterAccents[idx];
  }

  Future<void> _handleClaimChest(int chapterIndex, int milestoneStars) async {
    ChapterChestReward? reward;
    try {
      reward = await _progression.claimChapterChest(
        chapterIndex,
        milestoneStars,
      );
    } catch (_) {
      reward = null;
    }
    if (!mounted) return;
    if (reward != null) {
      // K3a/S11: sandık talebi başarısında tek ses (playWin); dokunuş
      // sesi ayrı çalınmaz (çift ses yok).
      AudioManager().playWin();
      setState(() {
        _chestFeedbackTone = _FeedbackTone.success;
        _chestFeedbackBanner = context.l10n.chestUnlockedToast(
          milestoneStars,
          reward!.coinsGranted,
          reward.boosterCount,
          _boosterDisplayNames[reward.boosterKey] ??
              reward.boosterKey.toUpperCase(),
        );
      });
    } else {
      // Sandık açılamadı (null/hata): sessiz boşluk yerine görünür banner.
      setState(() {
        _chestFeedbackTone = _FeedbackTone.error;
        _chestFeedbackBanner = context.l10n.chestClaimFailed;
      });
    }
  }

  void _handleNodeTap(CampaignLevel level) {
    // S11: düğüm dokunuşu tek katman ses (kilitli/açık ayrımı yok).
    AudioManager().playPop();
    if (!_progression.isLevelUnlocked(level.id)) {
      // Kilitli düğüm: kilit sebebini banner'da göster.
      final previousLevel = level.id > 1 ? level.id - 1 : 1;
      setState(() {
        _chestFeedbackTone = _FeedbackTone.warning;
        _chestFeedbackBanner =
            context.l10n.levelLockedMessage(previousLevel);
      });
      return;
    }
    if (widget.onSelectLevel != null) {
      widget.onSelectLevel!(level);
      return;
    }
    Navigator.of(context).maybePop(level);
  }

  @override
  Widget build(BuildContext context) {
    final chapterMeta =
        CampaignDatabase.getThemedChapter(_selectedChapterIndex);
    final chapterLevels =
        CampaignDatabase.getLevelsForThemedChapter(_selectedChapterIndex);
    final chapterStars = _progression.getChapterStars(_selectedChapterIndex);
    final totalStars = _progression.totalCampaignStars;
    final accent = _accentForChapter(_selectedChapterIndex);
    final bossLevel = chapterLevels.lastWhere(
      (l) => l.isBossLevel,
      orElse: () => chapterLevels.last,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 380 || constraints.maxHeight < 680;
        final pad = compact ? 10.0 : 14.0;

        return Container(
          key: const Key('campaign_map_sheet_root'),
          decoration: BoxDecoration(
            gradient: LululuGradients.carbonToNavy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(
              color: LululuColors.liquidGold.withValues(alpha: 0.75),
              width: 1.8,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 8, pad, pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            LululuColors.mutedTitanium.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  _buildHeaderRow(
                    totalStars: totalStars,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  _buildChapterSelectorBar(compact: compact),
                  SizedBox(height: compact ? 6 : 8),
                  _buildChapterHeroBanner(
                    chapterMeta: chapterMeta,
                    bossLevel: bossLevel,
                    chapterStars: chapterStars,
                    accent: accent,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  _buildChestBar(
                    chapterIndex: _selectedChapterIndex,
                    chapterStars: chapterStars,
                    accent: accent,
                    compact: compact,
                  ),
                  if (_chestFeedbackBanner != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      key: const Key('campaign_chest_feedback_banner'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _chestFeedbackTone.color
                            .withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _chestFeedbackTone.color
                              .withValues(alpha: 0.65),
                        ),
                      ),
                      child: Text(
                        _chestFeedbackBanner!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _chestFeedbackTone.color,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: compact ? 6 : 10),
                  Expanded(
                    child: _buildLevelsGrid(
                      levels: chapterLevels,
                      accent: accent,
                      compact: compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderRow({
    required int totalStars,
    required bool compact,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.campaignSheetTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w900,
                        color: LululuColors.liquidGold,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      context.l10n.campaignSheetSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 9.5 : 10.5,
                        fontWeight: FontWeight.w600,
                        color: LululuColors.mutedTitanium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: LululuColors.carbonVoid.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: LululuColors.liquidGold.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⭐', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 3),
              Text(
                '$totalStars/${CampaignDatabase.totalLevels * 3}',
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.warningSolar,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: LululuColors.carbonVoid.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: LululuColors.liquidGold.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 3),
              Text(
                '${_progress.coins}',
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.liquidGold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChapterSelectorBar({required bool compact}) {
    return Wrap(
      key: const Key('campaign_chapter_tabs_list'),
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 5,
      children: [
        for (final ch in CampaignDatabase.themedChapters)
          Builder(
            builder: (context) {
              final selected = ch.chapterIndex == _selectedChapterIndex;
              final chStars = _progression.getChapterStars(ch.chapterIndex);
              final accent = _accentForChapter(ch.chapterIndex);

              return Semantics(
                button: true,
                label: context.l10n.chapterTabLabel(ch.chapterIndex, chStars),
                selected: selected,
                child: GestureDetector(
                  key: Key('campaign_chapter_tab_${ch.chapterIndex}'),
                  onTap: () {
                    AudioManager().playPop();
                    setState(() {
                      _selectedChapterIndex = ch.chapterIndex;
                      _chestFeedbackBanner = null;
                      _chestFeedbackTone = _FeedbackTone.success;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 6 : 8,
                      vertical: compact ? 3 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: 0.24)
                          : LululuColors.darkObsidian.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? LululuColors.liquidGold
                            : LululuColors.mutedTitanium.withValues(alpha: 0.3),
                        width: selected ? 1.6 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ch.iconEmoji,
                          style: TextStyle(fontSize: compact ? 10 : 11.5),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          context.l10n.chapterBadgeLabel(ch.chapterIndex),
                          style: TextStyle(
                            fontSize: compact ? 9.5 : 10.5,
                            fontWeight:
                                selected ? FontWeight.w900 : FontWeight.w700,
                            color: selected
                                ? LululuColors.cream
                                : LululuColors.mutedTitanium,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$chStars/30⭐',
                          style: TextStyle(
                            fontSize: compact ? 8.5 : 9.5,
                            fontWeight: FontWeight.w800,
                            color: LululuColors.liquidGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildChapterHeroBanner({
    required CampaignThemedChapter chapterMeta,
    required CampaignLevel bossLevel,
    required int chapterStars,
    required Color accent,
    required bool compact,
  }) {
    return Container(
      key: Key('campaign_chapter_banner_${chapterMeta.chapterIndex}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: LululuColors.darkObsidian.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Text(
            chapterMeta.iconEmoji,
            style: TextStyle(fontSize: compact ? 20 : 24),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.chapterBannerTitle(chapterMeta.chapterIndex, chapterMeta.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11.5 : 13,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.cream,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.bossBannerLine(bossLevel.id, chapterMeta.bossName, chapterMeta.bossHp, chapterMeta.bossSpecialHazard),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w700,
                    color: LululuColors.warningSolar,
                  ),
                ),
                // K3b (salt-görünüm): boss ilk geçiş bonusu tutarı.
                // Ödeme mantığı değişmez; bonus alındıysa gösterilmez.
                if (bossLevel.isBossLevel &&
                    !_progression.isBossFirstCleared(bossLevel.id)) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.bossFirstClearBonus(
                      bossLevel.firstClearBonusCoins,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w700,
                      color: LululuColors.cyberFuchsia,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: LululuColors.carbonVoid.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Text(
              context.l10n.levelRangeShort(chapterMeta.startLevel, chapterMeta.endLevel),
              style: TextStyle(
                fontSize: compact ? 9.5 : 10.5,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChestBar({
    required int chapterIndex,
    required int chapterStars,
    required Color accent,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: LululuColors.carbonVoid.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: LululuColors.liquidGold.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0;
              i < CampaignProgressionService.validChestMilestones.length;
              i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _buildMilestoneChestTile(
                chapterIndex: chapterIndex,
                milestoneStars:
                    CampaignProgressionService.validChestMilestones[i],
                chapterStars: chapterStars,
                compact: compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestoneChestTile({
    required int chapterIndex,
    required int milestoneStars,
    required int chapterStars,
    required bool compact,
  }) {
    final claimed = _progression.isChapterChestClaimed(
      chapterIndex,
      milestoneStars,
    );
    final claimable = _progression.canClaimChapterChest(
      chapterIndex,
      milestoneStars,
    );
    final reward = _progression.previewChapterChestReward(
      chapterIndex,
      milestoneStars,
    );

    final Color borderColor = claimed
        ? LululuColors.toxicNeon
        : claimable
            ? LululuColors.liquidGold
            : LululuColors.mutedTitanium.withValues(alpha: 0.35);

    return Semantics(
      button: true,
      enabled: claimable,
      label: context.l10n.chestClaimLabel(milestoneStars, claimed ? 'claimed' : claimable ? 'claimable' : 'locked'),
      child: GestureDetector(
        key: Key('campaign_chest_${chapterIndex}_$milestoneStars'),
        onTap:
            claimable ? () => _handleClaimChest(chapterIndex, milestoneStars) : null,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 7,
            vertical: compact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: claimable
                ? LululuColors.liquidGold.withValues(alpha: 0.18)
                : claimed
                    ? LululuColors.toxicNeon.withValues(alpha: 0.12)
                    : LululuColors.darkObsidian.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: claimable ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                claimed
                    ? '✅'
                    : claimable
                        ? '🎁'
                        : '🔒',
                style: TextStyle(fontSize: compact ? 11 : 13),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.chestStarsLabel(milestoneStars),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 9 : 10,
                        fontWeight: FontWeight.w900,
                        color: claimable
                            ? LululuColors.warningSolar
                            : claimed
                                ? LululuColors.toxicNeon
                                : LululuColors.cream,
                      ),
                    ),
                    Text(
                      claimed
                          ? context.l10n.claimedPlain
                          : context.l10n.chestRewardLine(reward.coinsGranted, reward.boosterCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 8 : 8.5,
                        fontWeight: FontWeight.w700,
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

  Widget _buildLevelsGrid({
    required List<CampaignLevel> levels,
    required Color accent,
    required bool compact,
  }) {
    return GridView.builder(
      key: Key('campaign_levels_grid_$_selectedChapterIndex'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 2 : 4,
        vertical: 2,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: compact ? 6 : 8,
        mainAxisSpacing: compact ? 6 : 8,
        childAspectRatio: compact ? 0.78 : 0.84,
      ),
      itemCount: levels.length,
      itemBuilder: (context, idx) {
        final level = levels[idx];
        final unlocked = _progression.isLevelUnlocked(level.id);
        final stars = _progression.getStarsForLevel(level.id);

        return _CampaignLevelNodeCard(
          key: Key('campaign_level_node_${level.id}'),
          level: level,
          isUnlocked: unlocked,
          stars: stars,
          accent: accent,
          compact: compact,
          onTap: () => _handleNodeTap(level),
        );
      },
    );
  }
}

/// Geri bildirim banner'ının tonu: sandık başarısı yeşil, kilit
/// sebebi amber, sandık hatası kırmızı.
enum _FeedbackTone {
  success(LululuColors.toxicNeon),
  warning(LululuColors.warningSolar),
  error(LululuColors.coralFlare);

  const _FeedbackTone(this.color);
  final Color color;
}

class _CampaignLevelNodeCard extends StatelessWidget {
  final CampaignLevel level;
  final bool isUnlocked;
  final int stars;
  final Color accent;
  final bool compact;
  final VoidCallback? onTap;

  const _CampaignLevelNodeCard({
    super.key,
    required this.level,
    required this.isUnlocked,
    required this.stars,
    required this.accent,
    required this.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isBoss = level.isBossLevel;
    final Color borderColor = !isUnlocked
        ? LululuColors.mutedTitanium.withValues(alpha: 0.25)
        : isBoss
            ? LululuColors.cyberFuchsia
            : stars >= 3
                ? LululuColors.warningSolar
                : accent.withValues(alpha: 0.85);

    return Semantics(
      button: true,
      label: context.l10n.levelTileLabel(level.id, stars, !isUnlocked),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          decoration: BoxDecoration(
            gradient: !isUnlocked
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [LululuColors.darkObsidian, LululuColors.carbonVoid],
                  )
                : isBoss
                    ? LululuGradients.rubyToFuchsia
                    : stars > 0
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withValues(alpha: 0.45),
                              LululuColors.spaceNavy,
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              LululuColors.spaceNavy,
                              LululuColors.darkObsidian,
                            ],
                          ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: isBoss ? 1.8 : 1.2,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isBoss)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        key: Key('boss_crown_icon_${level.id}'),
                        size: compact ? 11 : 12,
                        color: LululuColors.warningSolar,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        context.l10n.bossShort,
                        style: TextStyle(
                          fontSize: compact ? 7.5 : 8,
                          fontWeight: FontWeight.w900,
                          color: LululuColors.warningSolar,
                        ),
                      ),
                    ],
                  ),
                if (!isUnlocked)
                  Icon(
                    Icons.lock_rounded,
                    key: Key('level_lock_icon_${level.id}'),
                    size: compact ? 13 : 15,
                    color: LululuColors.mutedTitanium.withValues(alpha: 0.65),
                  ),
                Text(
                  '${level.id}',
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w900,
                    color: isUnlocked
                        ? LululuColors.cream
                        : LululuColors.mutedTitanium.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (starIdx) {
                    final filled = isUnlocked && starIdx < stars;
                    return Icon(
                      filled ? Icons.star_rounded : Icons.star_border_rounded,
                      size: compact ? 9.5 : 10.5,
                      color: filled
                          ? LululuColors.warningSolar
                          : LululuColors.mutedTitanium.withValues(alpha: 0.45),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
