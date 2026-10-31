import 'package:flutter/material.dart';
import '../theme/lululu_theme.dart';

/// Kenney rectangle depth-gradient button with press scale micro-interaction.
class KenneyButton extends StatefulWidget {
  const KenneyButton({
    super.key,
    required this.label,
    this.onPressed,
    this.minHeight = 48,
    this.primary = true,
    this.palette = KenneyPalette.yellow,
    this.doubleResolution = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double minHeight;
  final bool primary;
  final KenneyPalette palette;
  final bool doubleResolution;

  @override
  State<KenneyButton> createState() => _KenneyButtonState();
}

class _KenneyButtonState extends State<KenneyButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled
          ? (_) {
              _setPressed(false);
              widget.onPressed!();
            }
          : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.55,
          duration: const Duration(milliseconds: 150),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.minHeight,
              minWidth: 88,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: widget.primary
                    ? LululuGradients.fuchsiaToGold
                    : const LinearGradient(
                        colors: [
                          LululuColors.darkObsidian,
                          LululuColors.spaceNavy,
                        ],
                      ),
                border: Border.all(
                  color: widget.primary
                      ? LululuColors.liquidGold.withValues(alpha: 0.8)
                      : LululuColors.cyberFuchsia.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Center(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      decoration: TextDecoration.none,
                      color: widget.primary
                          ? LululuColors.carbonVoid
                          : LululuColors.liquidGold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
