import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/achievement_pass_service.dart';
import '../services/progress_manager.dart';

/// Yeni bir başarım açıldığında ekranın üstünden kayarak gelen altın çerçeveli bildirim banner'ı.
class AchievementToastBanner extends StatefulWidget {
  final AchievementDefinition? achievement;
  final VoidCallback? onDismissed;
  final Duration displayDuration;

  const AchievementToastBanner({
    super.key,
    this.achievement,
    this.onDismissed,
    this.displayDuration = const Duration(milliseconds: 3500),
  });

  @override
  State<AchievementToastBanner> createState() => _AchievementToastBannerState();
}

class _AchievementToastBannerState extends State<AchievementToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _syncVisibility();
  }

  @override
  void didUpdateWidget(covariant AchievementToastBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.achievement?.id != widget.achievement?.id) {
      _syncVisibility();
    }
  }

  void _syncVisibility() {
    final active =
        widget.achievement ?? AchievementPassService.instance.activeToastNotifier.value;
    if (active != null) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse();
    }
  }

  void _handleDismiss() {
    if (widget.onDismissed != null) {
      widget.onDismissed!();
    } else {
      AchievementPassService.instance.dismissActiveToast();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AchievementDefinition?>(
      valueListenable: AchievementPassService.instance.activeToastNotifier,
      builder: (context, listenedAchievement, _) {
        final item = widget.achievement ?? listenedAchievement;
        if (item == null) {
          return const SizedBox.shrink();
        }
        if (!_controller.isAnimating && _controller.value == 0) {
          _controller.forward();
        }
        return SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      key: Key('achievement_toast_${item.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2B1C08),
                            Color(0xFF432C0D),
                            Color(0xFF261706),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFD54F),
                          width: 2.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x88000000),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0x33FFD54F),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFFD54F),
                                width: 1.4,
                              ),
                            ),
                            child: Text(
                              item.iconEmoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        context.l10n.achievementUnlockedTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.7,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0x33FFA000),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          context.l10n.achievementRewardLine(item.coinReward, item.seasonXpReward),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFFFECB3),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (item.rewardTitle.isNotEmpty)
                                  Text(
                                    context.l10n.titleRewardLine(item.rewardTitle),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFFFCC80),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('achievement_toast_close_btn'),
                            tooltip: context.l10n.closeLabel,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFFFFD54F),
                              size: 18,
                            ),
                            onPressed: _handleDismiss,
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
    );
  }
}

/// 30 Başarım + 20 Kademeli "Lülülü Sezon Bileti" görünümü (360x640..430x932 sıfır taşma).
class AchievementPassSheet extends StatefulWidget {
  final int initialTabIndex;

  const AchievementPassSheet({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AchievementPassSheet> createState() => _AchievementPassSheetState();
}

class _AchievementPassSheetState extends State<AchievementPassSheet> {
  late int _tabIndex;
  AchievementCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final service = AchievementPassService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([service, ProgressManager.instance]),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
            return Container(
              key: const Key('achievement_pass_sheet'),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A1228),
                    Color(0xFF110B1B),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(service, compact: compact),
                      const SizedBox(height: 8),
                      _buildSeasonProgressCard(service, compact: compact),
                      const SizedBox(height: 8),
                      _buildTabSwitcher(service, compact: compact),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _tabIndex == 0
                            ? _buildAchievementsView(service, compact: compact)
                            : _buildSeasonPassView(service, compact: compact),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(AchievementPassService service, {required bool compact}) {
    final unlockedCount = service.unlockedAchievementIds.length;
    final totalCount = AchievementPassService.all30Achievements.length;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0x33FFD54F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD54F)),
          ),
          child: const Text('🏆', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.masteryPassTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 14 : 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                context.l10n.masteryHeaderLine(service.selectedTitle, unlockedCount, totalCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFCC80),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x33FFA000),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFB300)),
          ),
          child: Text(
            '${ProgressManager.instance.coins} 🪙',
            style: const TextStyle(
              color: Color(0xFFFFECB3),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonProgressCard(
    AchievementPassService service, {
    required bool compact,
  }) {
    final tier = service.currentPassTier;
    final xp = service.seasonXp;
    final nextXp = service.nextTierRequiredXp;
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFF251A3A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5E438A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.seasonTierLine(tier, xp, nextXp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Semantics(
                button: true,
                label: service.hasGoldPass ? context.l10n.goldPassActive : context.l10n.goldPassOpen,
                child: GestureDetector(
                  key: const Key('gold_pass_toggle_btn'),
                  onTap: () {
                    if (!service.hasGoldPass) {
                      service.activateGoldPass();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: service.hasGoldPass
                            ? const [Color(0xFFFFD54F), Color(0xFFFF8F00)]
                            : const [Color(0xFF4A3B63), Color(0xFF33264A)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      service.hasGoldPass ? context.l10n.goldPassActive : context.l10n.goldPassOpen,
                      style: TextStyle(
                        color: service.hasGoldPass
                            ? const Color(0xFF261600)
                            : const Color(0xFFFFD54F),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: service.nextTierProgress,
              minHeight: 7,
              backgroundColor: const Color(0xFF140D21),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFCA28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(
    AchievementPassService service, {
    required bool compact,
  }) {
    return Row(
      children: [
        Expanded(
          child: _TabButton(
            key: const Key('tab_achievements_btn'),
            label:
                context.l10n.achievementsCountLine(service.unlockedAchievementIds.length),
            selected: _tabIndex == 0,
            onTap: () => setState(() => _tabIndex = 0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabButton(
            key: const Key('tab_season_pass_btn'),
            label: context.l10n.passTierLabel(service.currentPassTier),
            selected: _tabIndex == 1,
            onTap: () => setState(() => _tabIndex = 1),
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsView(
    AchievementPassService service, {
    required bool compact,
  }) {
    final items = _selectedCategory == null
        ? AchievementPassService.all30Achievements
        : service.achievementsByCategory(_selectedCategory!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _CategoryChip(
                label: context.l10n.allAchievementsLabel,
                selected: _selectedCategory == null,
                onTap: () => setState(() => _selectedCategory = null),
              ),
              for (final cat in AchievementCategory.values)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _CategoryChip(
                    key: Key('cat_chip_${cat.name}'),
                    label: '${cat.iconEmoji} ${cat.titleTr}',
                    selected: _selectedCategory == cat,
                    onTap: () => setState(() => _selectedCategory = cat),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            key: const Key('achievements_list_view'),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final def = items[index];
              final unlocked = service.isAchievementUnlocked(def.id);
              final progress = service.getAchievementProgress(def.id);
              final ratio = service.getAchievementProgressRatio(def.id);
              return Container(
                key: Key('ach_item_${def.id}'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: unlocked
                      ? const Color(0xFF2C2312)
                      : const Color(0xFF1E1630),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: unlocked
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFF3E2E5C),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: unlocked
                            ? const Color(0x33FFD54F)
                            : const Color(0xFF140E20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        def.iconEmoji,
                        style: const TextStyle(fontSize: 19),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  def.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.achievementRewardCompact(def.coinReward, def.seasonXpReward),
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            def.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB3A4CC),
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 5,
                                    backgroundColor: const Color(0xFF120C1D),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      unlocked
                                          ? const Color(0xFF66BB6A)
                                          : const Color(0xFFFFB300),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                unlocked
                                    ? context.l10n.unlockedShort
                                    : '$progress/${def.targetValue}',
                                style: TextStyle(
                                  color: unlocked
                                      ? const Color(0xFF81C784)
                                      : const Color(0xFFD1C4E9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonPassView(
    AchievementPassService service, {
    required bool compact,
  }) {
    final tiers = AchievementPassService.all20PassTiers;
    return ListView.separated(
      key: const Key('season_pass_list_view'),
      itemCount: tiers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final tierDef = tiers[index];
        final unlocked = service.seasonXp >= tierDef.requiredXp;
        final freeClaimed =
            service.isPassTierClaimed(tierDef.tier, goldTrack: false);
        final goldClaimed =
            service.isPassTierClaimed(tierDef.tier, goldTrack: true);
        final canClaimFree =
            service.canClaimPassTierReward(tierDef.tier, goldTrack: false);
        final canClaimGold =
            service.canClaimPassTierReward(tierDef.tier, goldTrack: true);

        return Container(
          key: Key('pass_tier_row_${tierDef.tier}'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: unlocked
                ? const Color(0xFF241B38)
                : const Color(0xFF181126),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unlocked
                  ? const Color(0xFFFFCA28)
                  : const Color(0xFF362850),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 42 : 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unlocked
                      ? const Color(0x33FFD54F)
                      : const Color(0xFF120C1D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${tierDef.tier}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${tierDef.requiredXp}XP',
                      style: const TextStyle(
                        color: Color(0xFFFFCC80),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PassRewardTrackTile(
                  trackKey: Key('pass_free_btn_${tierDef.tier}'),
                  trackTitle: context.l10n.freeTrackTitle,
                  reward: tierDef.freeReward,
                  claimed: freeClaimed,
                  canClaim: canClaimFree,
                  isGold: false,
                  onTap: () => service.claimPassTierReward(
                    tierDef.tier,
                    goldTrack: false,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PassRewardTrackTile(
                  trackKey: Key('pass_gold_btn_${tierDef.tier}'),
                  trackTitle: context.l10n.goldPassTitle,
                  reward: tierDef.goldReward,
                  claimed: goldClaimed,
                  canClaim: canClaimGold,
                  isGold: true,
                  onTap: () => service.claimPassTierReward(
                    tierDef.tier,
                    goldTrack: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFB300) : const Color(0xFF241938),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected ? const Color(0xFFFFE082) : const Color(0xFF473568),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? const Color(0xFF231400) : Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF5E35B1) : const Color(0xFF231934),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected ? const Color(0xFFD1C4E9) : const Color(0xFF453263),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    );
  }
}

class _PassRewardTrackTile extends StatelessWidget {
  final Key trackKey;
  final String trackTitle;
  final SeasonPassReward reward;
  final bool claimed;
  final bool canClaim;
  final bool isGold;
  final VoidCallback onTap;

  const _PassRewardTrackTile({
    required this.trackKey,
    required this.trackTitle,
    required this.reward,
    required this.claimed,
    required this.canClaim,
    required this.isGold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: canClaim,
      label: canClaim ? "$trackTitle, ${reward.label}, ${context.l10n.claimReward}" : "$trackTitle, ${reward.label}",
      child: GestureDetector(
        key: trackKey,
        onTap: canClaim ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isGold ? const Color(0xFF2E2210) : const Color(0xFF1D152E),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: canClaim
                  ? const Color(0xFF66BB6A)
                  : (isGold
                      ? const Color(0xFFFFB300)
                      : const Color(0xFF47366B)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(reward.iconEmoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trackTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isGold
                            ? const Color(0xFFFFD54F)
                            : const Color(0xFFB39DDB),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                reward.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: claimed
                      ? const Color(0xFF2E4A31)
                      : (canClaim
                          ? const Color(0xFF43A047)
                          : const Color(0xFF2A203B)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  claimed ? context.l10n.claimedShort : (canClaim ? context.l10n.collectButton : context.l10n.lockedLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    );
  }
}
