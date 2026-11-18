import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';

/// Basınca yaylanan (scale) dokunma kapsayıcısı. Kritik aksiyonlar için
/// min dokunma alanı [LululuMotion.minTap] ile birlikte kullanılır.
///
/// Erişilebilirlik: her [LululuPress] bir düğme olarak duyurulur
/// ([Semantics] ile `button` + `enabled`); görünür yazısı olmayan
/// düğmelerde [semanticLabel] verilmelidir.
class LululuPress extends StatefulWidget {
  const LululuPress({
    super.key,
    required this.onTap,
    required this.child,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
    this.enabled = true,
  });

  final VoidCallback onTap;
  final Widget child;
  final HitTestBehavior behavior;

  /// Ekran okuyucunun duyuracağı düğme etiketi. Verilmezse yalnızca
  /// düğme rolü duyurulur; alt öğedeki yazı ayrıca okunur.
  final String? semanticLabel;

  /// `false` ise dokunma (ve basma animasyonu) devre dışıdır ve
  /// düğme erişilebilirlik ağacında devre dışı görünür.
  final bool enabled;

  @override
  State<LululuPress> createState() => _LululuPressState();
}

class _LululuPressState extends State<LululuPress> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _down ? LululuMotion.pressScale : 1,
          duration: LululuMotion.pressDuration,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Hub/meta kartları için parlak çizgi-film başlık stili.
class LululuSectionHeader extends StatelessWidget {
  const LululuSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                semanticLabel: actionLabel,
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
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: LululuColors.mutedTitanium,
              ),
            ),
          ),
      ],
    );
  }
}
