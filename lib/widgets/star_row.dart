import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../theme/lululu_theme.dart';

/// Level / rating stars using 3D design star assets (`res_star.png` / `icon_star.webp`)
/// with fallback to Kenney star sprites.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.filledCount,
    this.max = 3,
    this.size = 28,
    this.middleSize,
    this.gap = 6,
    this.filledPalette = KenneyPalette.yellow,
    this.emptyPalette = KenneyPalette.grey,
    this.doubleResolution = false,
    this.use3dAsset = true,
    this.elevateMiddle = false,
    this.withDropShadow = false,
  })  : assert(filledCount >= 0),
        assert(max > 0),
        assert(filledCount <= max);

  final int filledCount;
  final int max;
  final double size;
  final double? middleSize;
  final double gap;
  final KenneyPalette filledPalette;
  final KenneyPalette emptyPalette;
  final bool doubleResolution;
  final bool use3dAsset;
  final bool elevateMiddle;
  final bool withDropShadow;

  // CSS: filter: grayscale(1) brightness(.55)
  static const List<double> _missedStarColorMatrix = <double>[
    0.11693, 0.39336, 0.03971, 0, 0,
    0.11693, 0.39336, 0.03971, 0, 0,
    0.11693, 0.39336, 0.03971, 0, 0,
    0,       0,       0,       1, 0,
  ];

  Widget _buildFallbackStar(bool filled, double starSize) {
    final asset = filled
        ? LululuKenneyAssets.starFilled(
            filledPalette,
            doubleResolution: doubleResolution,
          )
        : LululuKenneyAssets.starOutline(
            emptyPalette,
            doubleResolution: doubleResolution,
          );
    return Image.asset(
      asset,
      width: starSize,
      height: starSize,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        filled ? Icons.star : Icons.star_border,
        size: starSize,
        color: filled ? LululuColors.liquidGold : LululuColors.mutedTitanium,
      ),
    );
  }

  Widget _buildStarImage(bool filled, double starSize, {Color? color}) {
    if (!use3dAsset) {
      return _buildFallbackStar(filled, starSize);
    }
    return Image.asset(
      'assets/design/ui/res_star.png',
      width: starSize,
      height: starSize,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: color != null ? BlendMode.srcIn : null,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => Image.asset(
        'assets/design/icon_star.webp',
        width: starSize,
        height: starSize,
        fit: BoxFit.contain,
        color: color,
        colorBlendMode: color != null ? BlendMode.srcIn : null,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _buildFallbackStar(filled, starSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          elevateMiddle ? CrossAxisAlignment.end : CrossAxisAlignment.center,
      children: List.generate(max, (index) {
        final filled = index < filledCount;
        final isMiddle = elevateMiddle && max == 3 && index == 1;
        final starSize = isMiddle
            ? (middleSize ?? (size == 46 ? 54.0 : size * (54.0 / 46.0)))
            : size;

        Widget star = _buildStarImage(filled, starSize);

        if (withDropShadow && use3dAsset) {
          // CSS: filter: drop-shadow(0 6px 10px rgba(0,0,0,.45))
          star = Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(0, 6),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: _buildStarImage(
                    filled,
                    starSize,
                    color: const Color(0x73000000),
                  ),
                ),
              ),
              star,
            ],
          );
        }

        if (!filled && use3dAsset) {
          star = Opacity(
            opacity: 0.55,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(_missedStarColorMatrix),
              child: star,
            ),
          );
        }

        if (isMiddle) {
          star = Transform.translate(
            offset: const Offset(0, -8),
            child: star,
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 0 : gap / 2,
            right: index == max - 1 ? 0 : gap / 2,
          ),
          child: SizedBox(
            width: starSize,
            height: starSize,
            child: Center(child: star),
          ),
        );
      }),
    );
  }
}
