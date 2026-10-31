import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/lululu_game_mode.dart';
import '../../services/progress_manager.dart';
import '../../theme/lululu_theme.dart';
import '../sticker_image.dart';

/// Vivid hero play card on white hub.
class FeaturedModeBanner extends StatefulWidget {
  const FeaturedModeBanner({
    super.key,
    required this.mode,
    required this.onPlay,
  });

  final LululuGameMode mode;
  final VoidCallback onPlay;

  @override
  State<FeaturedModeBanner> createState() => _FeaturedModeBannerState();
}

class _FeaturedModeBannerState extends State<FeaturedModeBanner> {
  bool _pressed = false;
  Timer? _tick;
  int _secs = 0;

  @override
  void initState() {
    super.initState();
    _secs = ProgressManager().secondsUntilMidnight();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs = ProgressManager().secondsUntilMidnight());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _clock {
    final h = (_secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((_secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPlay,
      child: AnimatedScale(
        scale: _pressed ? LululuMotion.pressScale : 1,
        duration: LululuMotion.pressDuration,
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LululuGradients.paperHero,
            boxShadow: [
              BoxShadow(
                color: LululuColors.cyberFuchsia.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: LululuColors.paper.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ÖNE ÇIKAN · ${mode.badge ?? 'HOT'}',
                          style: GoogleFonts.exo2(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: LululuColors.cyberFuchsia,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        mode.title,
                        style: GoogleFonts.exo2(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          color: LululuColors.paper,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mode.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.exo2(
                          fontSize: 12,
                          height: 1.3,
                          color: LululuColors.paper.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bugün bitiş · $_clock',
                        style: GoogleFonts.exo2(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: LululuColors.warningSolar,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: LululuMotion.minTap,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: LululuColors.paper,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'HEMEN OYNA',
                          style: GoogleFonts.exo2(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: LululuColors.cyberFuchsia,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                StickerImage(assetPath: mode.stickerAsset, size: 108),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
