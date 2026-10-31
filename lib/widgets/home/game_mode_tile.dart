import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/lululu_game_mode.dart';
import '../../theme/lululu_theme.dart';
import '../sticker_image.dart';

/// Bright mode card on white canvas.
class GameModeTile extends StatefulWidget {
  const GameModeTile({
    super.key,
    required this.mode,
    required this.onTap,
    required this.index,
  });

  final LululuGameMode mode;
  final VoidCallback onTap;
  final int index;

  @override
  State<GameModeTile> createState() => _GameModeTileState();
}

class _GameModeTileState extends State<GameModeTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    return Semantics(
      button: true,
      label: mode.title,
      identifier: 'mode_${mode.kind.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? LululuMotion.pressScale : 1,
          duration: LululuMotion.pressDuration,
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              color: LululuColors.paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: mode.accent.withValues(alpha: 0.75),
                width: 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: mode.accent.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (mode.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: mode.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          mode.badge!,
                          style: GoogleFonts.exo2(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: mode.accent,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      Icons.play_circle_filled_rounded,
                      color: mode.accent,
                      size: 22,
                    ),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: mode.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: StickerImage(
                      assetPath: mode.stickerAsset,
                      size: 68,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  mode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.inkDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mode.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    height: 1.2,
                    color: LululuColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
