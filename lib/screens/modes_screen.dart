import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/lululu_game_mode.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';
import '../widgets/sticker_image.dart';

/// 10 modun grid listesi. Karta dokununca ilgili oyun açılır.
class ModesScreen extends StatelessWidget {
  const ModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modes = LululuGameMode.catalog;
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        title: Text(
          'OYUN MODLARI',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
        itemCount: modes.length,
        itemBuilder: (context, i) => _ModeCard(mode: modes[i]),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});

  final LululuGameMode mode;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: () {
        AudioManager().playPop();
        openGameMode(context, mode.kind);
      },
      child: Container(
        decoration: BoxDecoration(
          color: LululuColors.paper,
          borderRadius: BorderRadius.circular(LululuRadii.card),
          border: Border.all(
            color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      mode.accent.withValues(alpha: 0.1),
                      LululuColors.paper,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
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
                            color: mode.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            mode.badge!,
                            style: GoogleFonts.exo2(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: mode.accent,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Icon(
                        Icons.play_circle_fill_rounded,
                        color: mode.accent,
                        size: 26,
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: StickerImage(
                        assetPath: mode.stickerAsset,
                        width: 76,
                        height: 76,
                      ),
                    ),
                  ),
                  Text(
                    mode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.inkDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    mode.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: LululuColors.mutedTitanium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
