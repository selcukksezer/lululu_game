import 'package:flutter/material.dart';
import '../theme/lululu_theme.dart';

/// Level / rating stars using Kenney star sprites.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.filledCount,
    this.max = 3,
    this.size = 28,
    this.filledPalette = KenneyPalette.yellow,
    this.emptyPalette = KenneyPalette.grey,
    this.doubleResolution = false,
  })  : assert(filledCount >= 0),
        assert(max > 0),
        assert(filledCount <= max);

  final int filledCount;
  final int max;
  final double size;
  final KenneyPalette filledPalette;
  final KenneyPalette emptyPalette;
  final bool doubleResolution;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (index) {
        final filled = index < filledCount;
        final asset = filled
            ? LululuKenneyAssets.starFilled(
                filledPalette,
                doubleResolution: doubleResolution,
              )
            : LululuKenneyAssets.starOutline(
                emptyPalette,
                doubleResolution: doubleResolution,
              );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              filled ? Icons.star : Icons.star_border,
              size: size,
              color: filled
                  ? LululuColors.liquidGold
                  : LululuColors.mutedTitanium,
            ),
          ),
        );
      }),
    );
  }
}
