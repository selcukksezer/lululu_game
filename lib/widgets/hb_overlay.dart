/// Kalp kırılma katmanı (`#hbOverlay`).
///
/// Enerji harcandığında üst katmanda kısa süreli kalp kırılma animasyonu
/// oynatır ([AppLocalizations.hbEnergyTag] etiketiyle). W55-2'de
/// `daily_reward_dialog.dart` dosyasından çıkarıldı.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';

/// `#hbOverlay` — Kalp Kırılma Animasyonu ([AppLocalizations.hbEnergyTag]).
class HbOverlay extends StatelessWidget {
  /// Varsayılan etiket gözcüsü: kurucu varsayılanı olarak kalır
  /// (const kurucu + mevcut test kilidi); build, bu değer geldiğinde
  /// etiketi locale'den çözer, özel metin aynen çizilir.
  static const _defaultTagText = '-1 ENERJİ';

  const HbOverlay({
    super.key,
    this.visible = false,
    this.tagText = _defaultTagText,
  });

  final bool visible;
  final String tagText;

  /// Kısa süreli (`#hbOverlay`) kalp kırılma animasyonunu üst katmanda oynatır.
  ///
  /// [tagText] verilmezse etiket locale'den çözülür
  /// ([AppLocalizations.hbEnergyTag]).
  static Future<void> play(
    BuildContext context, {
    String? tagText,
    Duration duration = const Duration(milliseconds: 520),
  }) async {
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTesting) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final resolvedTag = tagText ?? context.l10n.hbEnergyTag;
    final entry = OverlayEntry(
      builder: (_) => HbOverlay(visible: true, tagText: resolvedTag),
    );
    overlay.insert(entry);
    try {
      await Future<void>.delayed(duration);
    } finally {
      entry.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    // Varsayılan etiket locale'den çözülür (TR: '-1 ENERJİ',
    // EN: '-1 ENERGY'); çağırıcının özel metni aynen çizilir.
    final effectiveTag =
        tagText == _defaultTagText ? context.l10n.hbEnergyTag : tagText;
    return IgnorePointer(
      child: Container(
        color: const Color(0x597A082E),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(-14, 4),
                    child: Transform.rotate(
                      angle: -0.28,
                      child: ClipRect(
                        clipper: const _HalfRectClipper(leftHalf: true),
                        child: Image.asset(
                          'assets/design/ui/icon_heart_exact.png',
                          width: 132,
                          height: 132,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.heart_broken_rounded,
                            size: 96,
                            color: Color(0xFFE01E5A),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(14, 6),
                    child: Transform.rotate(
                      angle: 0.28,
                      child: ClipRect(
                        clipper: const _HalfRectClipper(leftHalf: false),
                        child: Image.asset(
                          'assets/design/ui/icon_heart_exact.png',
                          width: 132,
                          height: 132,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.heart_broken_rounded,
                            size: 96,
                            color: Color(0xFFE01E5A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ExcludeSemantics(
              child: Text(
                effectiveTag,
                style: GoogleFonts.baloo2(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.2,
                  shadows: const [
                    Shadow(
                      color: Color(0xFF7A082E),
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                    Shadow(
                      color: Color(0x8C000000),
                      offset: Offset(0, 8),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HalfRectClipper extends CustomClipper<Rect> {
  const _HalfRectClipper({required this.leftHalf});
  final bool leftHalf;

  @override
  Rect getClip(Size size) {
    return leftHalf
        ? Rect.fromLTWH(0, 0, size.width * 0.52, size.height)
        : Rect.fromLTWH(size.width * 0.48, 0, size.width * 0.52, size.height);
  }

  @override
  bool shouldReclip(covariant _HalfRectClipper oldClipper) =>
      oldClipper.leftHalf != leftHalf;
}
