import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/score_share_card.dart';
import '../theme/lululu_theme.dart';

/// Shared play chrome: dot mesh, score pills, blur result sheet.
class ArcadeScreen extends StatelessWidget {
  const ArcadeScreen({
    super.key,
    required this.title,
    required this.hint,
    required this.score,
    required this.best,
    required this.child,
    this.statLabel,
    this.statValue,
    this.onRestart,
    this.overlay,
    this.footer,
  });

  final String title;
  final String hint;
  final int score;
  final int best;
  final Widget child;
  final String? statLabel;
  final String? statValue;
  final VoidCallback? onRestart;
  final Widget? overlay;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LululuColors.carbonVoid,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: ArcadeDotPainter()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Geri',
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        color: LululuColors.liquidGold,
                        constraints: const BoxConstraints(
                          minWidth: LululuMotion.minTap,
                          minHeight: LululuMotion.minTap,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.exo2(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                                color: LululuColors.liquidGold,
                              ),
                            ),
                            Text(
                              hint,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.exo2(
                                fontSize: 11,
                                height: 1.25,
                                color: LululuColors.mutedTitanium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onRestart != null)
                        IconButton(
                          onPressed: onRestart,
                          icon: const Icon(Icons.refresh_rounded),
                          color: LululuColors.liquidGold,
                          constraints: const BoxConstraints(
                            minWidth: LululuMotion.minTap,
                            minHeight: LululuMotion.minTap,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(child: ArcadeStat(label: 'SKOR', value: '$score')),
                      const SizedBox(width: 8),
                      Expanded(child: ArcadeStat(label: 'REKOR', value: '$best')),
                      if (statLabel != null && statValue != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ArcadeStat(
                            label: statLabel!,
                            value: statValue!,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Column(
                        children: [
                          Expanded(child: child),
                          if (footer != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: footer,
                            ),
                        ],
                      ),
                      // Overlay covers play+footer only — header back stays tappable.
                      ?overlay,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ArcadeStat extends StatelessWidget {
  const ArcadeStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LululuColors.spaceNavy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: LululuColors.liquidGold.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.exo2(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: LululuColors.mutedTitanium,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.exo2(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: LululuColors.liquidGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArcadeButton extends StatefulWidget {
  const ArcadeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? LululuMotion.pressScale : 1,
        duration: LululuMotion.pressDuration,
        curve: LululuMotion.elastic,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LululuMotion.minTap),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: widget.primary
                  ? LululuGradients.fuchsiaToGold
                  : const LinearGradient(
                      colors: [
                        LululuColors.darkObsidian,
                        LululuColors.spaceNavy,
                      ],
                    ),
              border: Border.all(
                color: widget.primary
                    ? LululuColors.liquidGold.withValues(alpha: 0.7)
                    : LululuColors.cyberFuchsia.withValues(alpha: 0.45),
              ),
              boxShadow: widget.primary
                  ? [
                      BoxShadow(
                        color: LululuColors.liquidGold.withValues(alpha: 0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                widget.label,
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: widget.primary
                      ? LululuColors.carbonVoid
                      : LululuColors.liquidGold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArcadeResultOverlay extends StatelessWidget {
  const ArcadeResultOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.score,
    required this.won,
    required this.retryLabel,
    required this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
    this.modeTitle,
    this.best,
    this.shareLine,
    this.showShare = true,
  });

  final String title;
  final String message;
  final int score;
  final bool won;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  /// Paylaşım kartı başlığı (mod adı). Boşsa [title] kullanılır.
  final String? modeTitle;
  final int? best;
  final String? shareLine;
  final bool showShare;

  static DateTime? _lastShareAt;

  @override
  Widget build(BuildContext context) {
    final glow = won ? LululuColors.liquidGold : LululuColors.mysticRuby;
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: LululuColors.carbonVoid.withValues(alpha: 0.55),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: LululuColors.spaceNavy,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: glow.withValues(alpha: 0.85), width: 1.4),
                  boxShadow: [
                    BoxShadow(color: glow.withValues(alpha: 0.35), blurRadius: 28),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: glow,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 13,
                          height: 1.3,
                          color: LululuColors.mutedTitanium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$score',
                        style: GoogleFonts.exo2(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: LululuColors.liquidGold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ArcadeButton(
                              label: secondaryLabel ?? 'HUB',
                              primary: false,
                              onPressed: onSecondary ??
                                  () => Navigator.maybePop(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ArcadeButton(
                              label: retryLabel,
                              onPressed: onRetry,
                            ),
                          ),
                        ],
                      ),
                      // Share last — top placement was easy to misfire with game taps.
                      if (showShare) ...[
                        const SizedBox(height: 10),
                        ArcadeButton(
                          label: 'PAYLAŞ KART',
                          primary: false,
                          onPressed: () {
                            final now = DateTime.now();
                            final last = _lastShareAt;
                            if (last != null &&
                                now.difference(last) <
                                    const Duration(milliseconds: 900)) {
                              return;
                            }
                            _lastShareAt = now;
                            unawaited(
                              ScoreShareCard.instance.share(
                                modeTitle: modeTitle ?? title,
                                score: score,
                                best: best,
                                line: shareLine ?? message,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ArcadeDotPainter extends CustomPainter {
  const ArcadeDotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [LululuColors.carbonVoid, LululuColors.spaceNavy],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, base);

    const step = 14.0;
    final dot = Paint()..color = LululuColors.dotMesh(opacity: 0.08);
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.05, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
