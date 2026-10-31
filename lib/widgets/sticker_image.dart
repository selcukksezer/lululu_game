import 'package:flutter/material.dart';

/// Tier sticker with transparent silhouette — [BoxFit.contain], no circular clip.
class StickerImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final Color? backgroundColor;

  const StickerImage({
    super.key,
    required this.assetPath,
    double? width,
    double? height,
    double? size,
    this.borderColor,
    this.borderWidth = 0,
    this.boxShadow,
    this.backgroundColor,
  })  : width = width ?? size,
        height = height ?? size;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );

    if (borderColor == null &&
        borderWidth <= 0 &&
        boxShadow == null &&
        backgroundColor == null) {
      return image;
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: borderWidth > 0 && borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
        boxShadow: boxShadow,
      ),
      alignment: Alignment.center,
      child: image,
    );
  }
}
