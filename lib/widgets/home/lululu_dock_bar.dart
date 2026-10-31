import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/lululu_theme.dart';

enum LululuDockTab { home, board, chat, map, shop }

/// Floating dock. [light] = white hub companion bar.
class LululuDockBar extends StatelessWidget {
  const LululuDockBar({
    super.key,
    required this.selected,
    required this.onSelect,
    this.light = false,
  });

  final LululuDockTab selected;
  final ValueChanged<LululuDockTab> onSelect;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: light ? LululuColors.paper : LululuColors.spaceNavy,
          borderRadius: BorderRadius.circular(LululuRadii.dock),
          border: Border.all(
            color: light
                ? LululuColors.cyberFuchsia.withValues(alpha: 0.35)
                : LululuColors.liquidGold.withValues(alpha: 0.32),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: (light
                      ? LululuColors.cyberFuchsia
                      : LululuColors.carbonVoid)
                  .withValues(alpha: light ? 0.12 : 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DockItem(
                  tab: LululuDockTab.home,
                  selected: selected,
                  icon: Icons.home_rounded,
                  label: 'Ana',
                  activeGlow: LululuColors.toxicNeon,
                  light: light,
                  onTap: () => onSelect(LululuDockTab.home),
                ),
                _DockItem(
                  tab: LululuDockTab.board,
                  selected: selected,
                  icon: Icons.emoji_events_rounded,
                  label: 'Sıralama',
                  activeGlow: LululuColors.liquidGold,
                  light: light,
                  onTap: () => onSelect(LululuDockTab.board),
                ),
                _DockItem(
                  tab: LululuDockTab.chat,
                  selected: selected,
                  icon: Icons.chat_bubble_rounded,
                  label: 'Sohbet',
                  activeGlow: LululuColors.cyberFuchsia,
                  light: light,
                  onTap: () => onSelect(LululuDockTab.chat),
                ),
                _DockItem(
                  tab: LululuDockTab.map,
                  selected: selected,
                  icon: Icons.map_rounded,
                  label: 'Harita',
                  activeGlow: LululuColors.coralFlare,
                  light: light,
                  onTap: () => onSelect(LululuDockTab.map),
                ),
                _DockItem(
                  tab: LululuDockTab.shop,
                  selected: selected,
                  icon: Icons.shopping_bag_rounded,
                  label: 'Dükkan',
                  activeGlow: LululuColors.warningSolar,
                  light: light,
                  onTap: () => onSelect(LululuDockTab.shop),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatefulWidget {
  const _DockItem({
    required this.tab,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.activeGlow,
    required this.light,
  });

  final LululuDockTab tab;
  final LululuDockTab selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color activeGlow;
  final bool light;

  @override
  State<_DockItem> createState() => _DockItemState();
}

class _DockItemState extends State<_DockItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.tab == widget.selected;
    final idle = widget.light
        ? LululuColors.mutedTitanium
        : LululuColors.mutedTitanium;
    final glow = active ? widget.activeGlow : idle;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? LululuMotion.pressScale : 1,
        duration: LululuMotion.pressDuration,
        curve: Curves.easeOutCubic,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: LululuMotion.minTap,
            minHeight: LululuMotion.minTap,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: active
                  ? widget.activeGlow.withValues(alpha: widget.light ? 0.14 : 0.2)
                  : Colors.transparent,
              border: Border.all(
                color: active
                    ? glow.withValues(alpha: 0.9)
                    : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: glow, size: 22),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  style: GoogleFonts.exo2(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? (widget.light
                            ? LululuColors.inkDark
                            : glow)
                        : idle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
