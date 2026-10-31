import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';

/// Basınca yaylanan (scale) dokunma kapsayıcısı. Kritik aksiyonlar için
/// min dokunma alanı [LululuMotion.minTap] ile birlikte kullanılır.
class LululuPress extends StatefulWidget {
  const LululuPress({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior = HitTestBehavior.opaque,
  });

  final VoidCallback onTap;
  final Widget child;
  final HitTestBehavior behavior;

  @override
  State<LululuPress> createState() => _LululuPressState();
}

class _LululuPressState extends State<LululuPress> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
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

/// Hub/meta kartları için parlak çizgi-film başlık stili.
class LululuSectionHeader extends StatelessWidget {
  const LululuSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.exo2(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: LululuColors.inkDark,
            ),
          ),
        ),
        if (actionLabel != null)
          LululuPress(
            onTap: onAction ?? () {},
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                actionLabel!,
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.cyberFuchsia,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
