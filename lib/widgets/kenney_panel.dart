import 'package:flutter/material.dart';
import '../theme/lululu_theme.dart';

/// Nine-sliced Kenney rectangle chrome for HUD panels and modals.
class KenneyPanel extends StatelessWidget {
  const KenneyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.palette = KenneyPalette.yellow,
    this.flat = false,
    this.centerSlice = const Rect.fromLTWH(24, 24, 4, 4),
  });

  final Widget child;
  final EdgeInsets padding;
  final KenneyPalette palette;
  final bool flat;
  final Rect centerSlice;

  String get asset => flat
      ? LululuKenneyAssets.buttonRectDepthFlat(palette)
      : LululuKenneyAssets.buttonRectDepthBorder(palette);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(asset),
                centerSlice: centerSlice,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    );
  }
}
