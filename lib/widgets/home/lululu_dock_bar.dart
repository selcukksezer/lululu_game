import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/lululu_theme.dart';

/// Sözleşme: bu isimler değişmez.
enum LululuDockTab { home, modes, family, shop, scores }

/// Floating hap dock.
/// - Arkası tamamen şeffaf: altında beyaz zemin bandı yok; home_shell
///   `extendBody: true` + Stack ile bunu içeriğin üstüne yerleştirir.
/// - Aktif sekmede altın→mercan→fuşya gradyanlı kayan gösterge.
/// - Aktif ikon yukarı zıplar (flutter_animate).
class LululuDockBar extends StatelessWidget {
  const LululuDockBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final LululuDockTab selected;
  final ValueChanged<LululuDockTab> onSelect;

  static const _tabs = LululuDockTab.values;

  static String _label(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => 'ANA SAYFA',
        LululuDockTab.modes => 'MODLAR',
        LululuDockTab.family => 'AİLEM',
        LululuDockTab.shop => 'MAĞAZA',
        LululuDockTab.scores => 'SKORLAR',
      };

  static IconData _icon(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => Icons.home_rounded,
        LululuDockTab.modes => Icons.videogame_asset_rounded,
        LululuDockTab.family => Icons.bug_report_rounded,
        LululuDockTab.shop => Icons.shopping_bag_rounded,
        LululuDockTab.scores => Icons.emoji_events_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // Arkada beyaz band YOK — sadece floating hap, dışı şeffaf.
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / _tabs.length;
            return Stack(
              children: [
                // Dock gövdesi: yüzen koyu hap.
                Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: LululuColors.spaceNavy
                        .withValues(alpha: 0.92),
                    borderRadius:
                        BorderRadius.circular(LululuRadii.dock),
                    border: Border.all(
                      color: LululuColors.liquidGold
                          .withValues(alpha: 0.35),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: LululuColors.carbonVoid
                            .withValues(alpha: 0.45),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
                // Kayan gradyan gösterge (altın→mercan→fuşya).
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  left: tabWidth * selected.index + 6,
                  top: 8,
                  bottom: 8,
                  width: tabWidth - 12,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          LululuColors.liquidGold,
                          LululuColors.coralFlare,
                          LululuColors.cyberFuchsia,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: LululuColors.cyberFuchsia
                              .withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sekmeler.
                SizedBox(
                  height: 68,
                  child: Row(
                    children: [
                      for (final tab in _tabs)
                        _DockItem(
                          tab: tab,
                          active: tab == selected,
                          width: tabWidth,
                          onTap: () => onSelect(tab),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.tab,
    required this.active,
    required this.width,
    required this.onTap,
  });

  final LululuDockTab tab;
  final bool active;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = LululuDockBar._label(tab);
    final icon = LululuDockBar._icon(tab);

    Widget iconWidget = Icon(
      icon,
      size: 24,
      color: active ? LululuColors.carbonVoid : LululuColors.mutedTitanium,
    );

    // Aktif ikon yukarı zıplar (seçim değişince animasyon tekrar oynar).
    if (active) {
      iconWidget = iconWidget
          .animate(key: ValueKey('dock-jump-$tab'))
          .moveY(
            begin: 8,
            end: -2,
            duration: 220.ms,
            curve: Curves.easeOutBack,
          );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: GoogleFonts.exo2(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: active
                    ? LululuColors.carbonVoid
                    : LululuColors.mutedTitanium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
