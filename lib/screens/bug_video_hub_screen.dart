import 'package:flutter/material.dart';

import 'studio_screens.dart';

enum BugVideoTab { watch, create }

/// Böcek videosu izle / yap — Pixel-perfect Böcek Stüdyo ekranlarına yönlendirir.
class BugVideoHubScreen extends StatelessWidget {
  const BugVideoHubScreen({
    super.key,
    this.initial = BugVideoTab.watch,
    this.showDock = false,
    this.prototypeVisualState = true,
  });

  final BugVideoTab initial;
  final bool showDock;
  final bool prototypeVisualState;

  @override
  Widget build(BuildContext context) {
    return initial == BugVideoTab.watch
        ? StudioWatchScreen(
            showDock: showDock,
            prototypeVisualState: prototypeVisualState,
          )
        : StudioCreateScreen(
            showDock: showDock,
            prototypeVisualState: prototypeVisualState,
          );
  }
}
