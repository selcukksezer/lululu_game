import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';

/// 1:1 Pixel-Perfect `#infoOverlay` (`.info-card`) popup matching `LÜLÜLÜ UI:UX Tasarım.html`.
Future<void> showItemDetailPopup(
  BuildContext context, {
  String badge = '',
  Color badgeColor = const Color(0xFF121826),
  required String title,
  String subtitle = '',
  required String description,
  Widget? visual,
  String? footerHint,
  List<MapEntry<String, String>>? stats,
  String? boldLead,
}) {
  AudioManager().playPop();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xB805070C),
    useSafeArea: false,
    builder: (_) => ItemDetailPopup(
      badge: badge,
      badgeColor: badgeColor,
      title: title,
      subtitle: subtitle,
      description: description,
      visual: visual,
      footerHint: footerHint,
      stats: stats,
      boldLead: boldLead,
    ),
  );
}

/// Opens the `#infoOverlay` "Nasıl Oynanır?" dialog matching the prototype.
Future<void> showHowToPlayOverlay(
  BuildContext context, {
  String? modeTitle,
  String? body,
}) {
  final effectiveTitle = (modeTitle != null && modeTitle.trim().isNotEmpty)
      ? '${modeTitle.trim()} — Nasıl Oynanır?'
      : 'SUİKA ARENA — NASIL OYNANIR?';
  final effectiveBody = body ??
      '<b>Suika Arena:</b> Alana dokun — sıradaki böcek tam oraya düşer. Aynı tier iki böcek çarpışınca bir üst tier doğar, skor katlanır. Yığın kırmızı tehlike çizgisini aşarsa oyun biter. Güçlendiriciler: Raid Spreyi küçük böcekleri temizler, Sarsıntı yığını yeniden yerleştirir, Aydınlat Hele! ise F16 ile gelip alanı bombalar.';
  return showItemDetailPopup(
    context,
    title: effectiveTitle,
    description: effectiveBody,
  );
}

/// Compatibility helper for `showLululuHowToPlayModal` calls across the app.
Future<void> showLululuHowToPlayModal(
  BuildContext context, {
  String title = 'SUİKA ARENA — NASIL OYNANIR?',
  String? modeTitle,
  String? body,
  String? description,
}) {
  final effectiveTitle = (modeTitle != null && modeTitle.trim().isNotEmpty)
      ? '${modeTitle.trim()} — Nasıl Oynanır?'
      : title;
  final effectiveBody = body ??
      description ??
      '<b>Suika Arena:</b> Alana dokun — sıradaki böcek tam oraya düşer. Aynı tier iki böcek çarpışınca bir üst tier doğar, skor katlanır. Yığın kırmızı tehlike çizgisini aşarsa oyun biter. Güçlendiriciler: Raid Spreyi küçük böcekleri temizler, Sarsıntı yığını yeniden yerleştirir, Aydınlat Hele! ise F16 ile gelip alanı bombalar.';
  return showItemDetailPopup(
    context,
    title: effectiveTitle,
    description: effectiveBody,
  );
}

/// Centered `.info-card` inside `#infoOverlay` (`Alignment.center`, `padding: 26px`).
class ItemDetailPopup extends StatelessWidget {
  const ItemDetailPopup({
    super.key,
    this.badge = '',
    this.badgeColor = const Color(0xFF121826),
    required this.title,
    this.subtitle = '',
    required this.description,
    this.visual,
    this.footerHint,
    this.stats,
    this.boldLead,
    this.onClose,
  });

  final String badge;
  final Color badgeColor;
  final String title;
  final String subtitle;
  final String description;
  final Widget? visual;
  final String? footerHint;
  final List<MapEntry<String, String>>? stats;
  final String? boldLead;
  final VoidCallback? onClose;

  List<TextSpan> _buildBodySpans(String rawText) {
    final spans = <TextSpan>[];
    if (boldLead != null && boldLead!.trim().isNotEmpty) {
      spans.add(
        TextSpan(
          text: '${boldLead!.trim()} ',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.55,
          ),
        ),
      );
    }

    var cursor = 0;
    while (cursor < rawText.length) {
      final openIdx = rawText.indexOf('<b>', cursor);
      if (openIdx < 0) {
        spans.add(TextSpan(text: rawText.substring(cursor)));
        break;
      }
      if (openIdx > cursor) {
        spans.add(TextSpan(text: rawText.substring(cursor, openIdx)));
      }
      final contentStart = openIdx + 3;
      final closeIdx = rawText.indexOf('</b>', contentStart);
      if (closeIdx < 0) {
        spans.add(TextSpan(text: rawText.substring(contentStart)));
        break;
      }
      final boldContent = rawText.substring(contentStart, closeIdx);
      if (boldContent.isNotEmpty) {
        spans.add(
          TextSpan(
            text: boldContent,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.55,
            ),
          ),
        );
      }
      cursor = closeIdx + 4;
    }

    return spans;
  }

  static String _toTurkishUpper(String input) {
    return input
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ş', 'Ş')
        .replaceAll('ö', 'Ö')
        .replaceAll('ç', 'Ç')
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AudioManager().playPop();
        if (onClose != null) {
          onClose!();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 378),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121826),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0x73FFB800),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80000000),
                        offset: Offset(0, 18),
                        blurRadius: 40,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // `h3#infoTitle`
                      Text(
                        _toTurkishUpper(title),
                        style: GoogleFonts.baloo2(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFB800),
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // `p#infoBody`
                      Flexible(
                        child: SingleChildScrollView(
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD8E0EE),
                                height: 1.55,
                              ),
                              children: _buildBodySpans(description),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // `#btnCloseInfo` (.btn)
                      GestureDetector(
                        onTap: () {
                          AudioManager().playPop();
                          if (onClose != null) {
                            onClose!();
                          } else if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.0, 0.55, 1.0],
                              colors: [
                                Color(0xFFFFCF3F),
                                Color(0xFFFFB800),
                                Color(0xFFF59E00),
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFFB97A00),
                                offset: Offset(0, 5),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: Color(0x47000000),
                                offset: Offset(0, 10),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'ANLADIM',
                            style: GoogleFonts.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.36,
                              height: 1.0,
                              shadows: const [
                                Shadow(
                                  color: Color(0x59784000),
                                  offset: Offset(0, 1),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
