import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';

/// Tasarim §4A / refs 2.png & 8.png — blur backdrop + neon-glow detail card.
Future<void> showItemDetailPopup(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String description,
  required Color rarityGlow,
  required Widget art,
  List<PopupAction> actions = const [],
  String? rarityLabel,
  String? valueLabel,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'item-detail',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim, secondary) {
      return ItemDetailPopup(
        title: title,
        subtitle: subtitle,
        description: description,
        rarityGlow: rarityGlow,
        art: art,
        actions: actions,
        rarityLabel: rarityLabel,
        valueLabel: valueLabel,
      );
    },
    transitionBuilder: (ctx, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: curved, child: child),
      );
    },
  );
}

class PopupAction {
  const PopupAction({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool enabled;
}

class ItemDetailPopup extends StatelessWidget {
  const ItemDetailPopup({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.rarityGlow,
    required this.art,
    this.actions = const [],
    this.rarityLabel,
    this.valueLabel,
  });

  final String title;
  final String subtitle;
  final String description;
  final Color rarityGlow;
  final Widget art;
  final List<PopupAction> actions;
  final String? rarityLabel;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: LululuColors.carbonVoid.withValues(alpha: 0.45),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        LululuColors.spaceNavy,
                        LululuColors.carbonVoid,
                      ],
                    ),
                    border: Border.all(
                      color: rarityGlow.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: rarityGlow.withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _DotMeshPainter()),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 96, height: 96, child: art),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'EŞYA ADI',
                                          style: GoogleFonts.exo2(
                                            fontSize: 10,
                                            letterSpacing: 1.2,
                                            color: LululuColors.mutedTitanium,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          title,
                                          style: GoogleFonts.exo2(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: LululuColors.ink,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          rarityLabel ?? subtitle,
                                          style: GoogleFonts.exo2(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: rarityGlow,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                description,
                                style: GoogleFonts.exo2(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: LululuColors.mutedTitanium,
                                ),
                              ),
                              if (valueLabel != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  valueLabel!,
                                  style: GoogleFonts.exo2(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: LululuColors.liquidGold,
                                  ),
                                ),
                              ],
                              if (actions.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final a in actions)
                                      _ActionChip(action: a),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _ActionChip extends StatefulWidget {
  const _ActionChip({required this.action});

  final PopupAction action;

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final bg = !a.enabled
        ? LululuColors.darkObsidian
        : a.primary
            ? LululuColors.liquidGold
            : LululuColors.darkObsidian;
    final fg = !a.enabled
        ? LululuColors.mutedTitanium
        : a.primary
            ? LululuColors.carbonVoid
            : LululuColors.ink;

    return GestureDetector(
      onTapDown: a.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: a.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: a.enabled
          ? () {
              a.onTap();
              Navigator.of(context).maybePop();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: a.primary
                  ? LululuColors.warningSolar.withValues(alpha: 0.6)
                  : LululuColors.mutedTitanium.withValues(alpha: 0.35),
            ),
            boxShadow: a.primary && a.enabled
                ? [
                    BoxShadow(
                      color: LululuColors.liquidGold.withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            a.label,
            style: GoogleFonts.exo2(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

class _DotMeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 14.0;
    final paint = Paint()..color = LululuColors.dotMesh(opacity: 0.08);
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.05, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
