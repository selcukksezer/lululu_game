import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/progress_manager.dart';
import 'home/lululu_dock_bar.dart';

export 'home/lululu_dock_bar.dart' show LululuDockTab, LululuDockBar;

/// Alt Gezinme Çubuğu (`GameBottomNav`) — [ProgressManager] ile tam senkronize,
/// `320x568`..`430x932` tüm ekran boyutlarında sıfır taşma (`overflow`) ile
/// çalışan kapsül dock bileşeni.
class GameBottomNav extends StatefulWidget {
  final LululuDockTab selectedTab;
  final ValueChanged<LululuDockTab>? onTabSelected;
  final int? currentIndex;
  final ValueChanged<int>? onIndexChanged;

  const GameBottomNav({
    super.key,
    this.selectedTab = LululuDockTab.home,
    this.onTabSelected,
    this.currentIndex,
    this.onIndexChanged,
  });

  @override
  State<GameBottomNav> createState() => _GameBottomNavState();
}

class _GameBottomNavState extends State<GameBottomNav> {
  final ProgressManager _progress = ProgressManager.instance;

  static const List<LululuDockTab> _tabs = LululuDockTab.values;

  @override
  void initState() {
    super.initState();
    _progress.addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    _progress.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  LululuDockTab get _effectiveTab {
    final idx = widget.currentIndex;
    if (idx != null && idx >= 0 && idx < _tabs.length) {
      return _tabs[idx];
    }
    return widget.selectedTab;
  }

  void _handleSelect(LululuDockTab tab) {
    widget.onTabSelected?.call(tab);
    widget.onIndexChanged?.call(tab.index);
  }

  static String _label(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => 'ANA SAYFA',
        LululuDockTab.modes => 'MODLAR',
        LululuDockTab.family => 'AİLEM',
        LululuDockTab.shop => 'MAĞAZA',
        LululuDockTab.scores => 'SKORLAR',
      };

  static String _assetIcon(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => 'assets/design/ui/icons2/home.png',
        LululuDockTab.modes => 'assets/design/ui/icons2/target.png',
        LululuDockTab.family => 'assets/design/ui/icons2/paw.png',
        LululuDockTab.shop => 'assets/design/ui/icons2/cart.png',
        LululuDockTab.scores => 'assets/design/ui/icons2/trophy.png',
      };

  bool _hasBadge(LululuDockTab tab) {
    switch (tab) {
      case LululuDockTab.home:
        return _progress.canClaimDailyGiftBox;
      case LululuDockTab.shop:
        return _progress.canClaimShopChest;
      case LululuDockTab.family:
        return _progress.maxUnlockedTier >= 8;
      case LululuDockTab.modes:
      case LululuDockTab.scores:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = _effectiveTab;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: Container(
            width: double.infinity,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 3),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.72],
                colors: [
                  Color(0xFF2A3042),
                  Color(0xFF080B12),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x7A080B12),
                  blurRadius: 38,
                  offset: Offset(0, 22),
                ),
                BoxShadow(
                  color: Color(0x47080B12),
                  blurRadius: 0,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final usableWidth =
                    (constraints.maxWidth - 14.0).clamp(100.0, 410.0);
                final tabWidth = usableWidth / _tabs.length;

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      left: 7.0 + (activeTab.index * tabWidth),
                      top: 7.0,
                      width: tabWidth,
                      height: 64.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.94),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.40, 0.74, 1.0],
                            colors: [
                              Color(0xFFFFD34D),
                              Color(0xFFFFB800),
                              Color(0xFFFF6B35),
                              Color(0xFFE01E5A),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              blurRadius: 0,
                              offset: Offset(0, 5),
                            ),
                            BoxShadow(
                              color: Color(0x47E01E5A),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(7),
                      child: Row(
                        children: [
                          for (final tab in _tabs)
                            Expanded(
                              child: SizedBox(
                                height: 64,
                                child: _BottomNavButton(
                                  label: _label(tab),
                                  iconAsset: _assetIcon(tab),
                                  active: tab == activeTab,
                                  showBadge: _hasBadge(tab),
                                  onTap: () => _handleSelect(tab),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavButton extends StatelessWidget {
  final String label;
  final String iconAsset;
  final bool active;
  final bool showBadge;
  final VoidCallback onTap;

  const _BottomNavButton({
    required this.label,
    required this.iconAsset,
    required this.active,
    required this.showBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.translate(
              offset: Offset(0, active ? -4 : 0),
              child: Transform.scale(
                scale: active ? 1.06 : 1.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.09),
                        border: Border.all(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.18),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        iconAsset,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.star_rounded,
                          size: 24,
                          color: active
                              ? const Color(0xFF141B2A)
                              : Colors.white70,
                        ),
                      ),
                    ),
                    if (showBadge)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF66),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF080B12),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.baloo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.66),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
