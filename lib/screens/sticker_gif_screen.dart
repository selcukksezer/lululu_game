import 'package:flutter/material.dart';

import 'studio_screens.dart';

/// Böcek çıkartması / GIF — Pixel-perfect Böcek Stüdyo GIF ekranına yönlendirir.
class StickerGifScreen extends StatelessWidget {
  const StickerGifScreen({
    super.key,
    this.showDock = false,
    this.prototypeVisualState = true,
  });

  final bool showDock;
  final bool prototypeVisualState;

  @override
  Widget build(BuildContext context) {
    return StudioGifScreen(
      showDock: showDock,
      prototypeVisualState: prototypeVisualState,
    );
  }
}
