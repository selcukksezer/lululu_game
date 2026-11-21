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
    // Dalga 17: tam çözünürlük decode'u engellemek için boyutlu istek —
    // tier PNG'ler 874×2333–1408×1760; decode genişliği gösterim
    // boyutundan (x cihaz piksel oranı) türetilir, 96–512 arası kelepçeli
    // (nota ~39 px → ~96 px; 108 px banner → DPR ile ~280 px, yumuşama yok).
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = width != null
        ? (width! * dpr).round().clamp(96, 512)
        : 96;
    final cacheHeight = width != null && height != null && width! > 0
        ? (cacheW * height! / width!).round().clamp(1, 512)
        : cacheW;
    final image = Image.asset(
      assetPath,
      width: width,
      height: height,
      cacheWidth: cacheW,
      cacheHeight: cacheHeight,
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
