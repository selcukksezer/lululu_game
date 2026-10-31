import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';

/// STÜDYO → İNDİRİLENLER — prototip mock'u (scr-studio-downloads).
///
/// Depolama özeti + 4 öğelik liste. Tamamen mock içerik.
class StudioDownloadsScreen extends StatelessWidget {
  const StudioDownloadsScreen({super.key});

  static const _items = <_DownloadItem>[
    _DownloadItem(
      name: 'birlesme_rekoru.mp4',
      meta: '84,2 MB · Bugün 09:12',
      isGif: false,
    ),
    _DownloadItem(
      name: 'kapi7_rehberi.mp4',
      meta: '156,8 MB · Dün 21:40',
      isGif: false,
    ),
    _DownloadItem(
      name: 'dans_zamani.gif',
      meta: '6,4 MB · 28 Ekim',
      isGif: true,
    ),
    _DownloadItem(
      name: 'hamam_diva_klip.mp4',
      meta: '42,1 MB · 25 Ekim',
      isGif: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        title: Text(
          'İNDİRİLENLER',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LululuGradients.elevatedCard,
              borderRadius: BorderRadius.circular(LululuRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEPOLAMA',
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: LululuColors.liquidGold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '1,24 GB',
                      style: GoogleFonts.exo2(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: LululuColors.paper,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'kullanıldı · 4 GB toplam · 4 öğe',
                        style: GoogleFonts.exo2(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: LululuColors.mutedTitanium,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 1.24 / 4,
                    minHeight: 10,
                    backgroundColor: LululuColors.paper
                        .withValues(alpha: 0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(
                      LululuColors.liquidGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final item in _items) ...[
            _DownloadRow(item: item),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DownloadItem {
  const _DownloadItem({
    required this.name,
    required this.meta,
    required this.isGif,
  });

  final String name;
  final String meta;
  final bool isGif;
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.item});

  final _DownloadItem item;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: () {},
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: LululuColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (item.isGif
                        ? LululuColors.toxicNeon
                        : LululuColors.cyberFuchsia)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.isGif
                    ? Icons.gif_box_rounded
                    : Icons.play_circle_fill_rounded,
                color: item.isGif
                    ? LululuColors.toxicNeon
                    : LululuColors.cyberFuchsia,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: LululuColors.inkDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LululuColors.mutedTitanium,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.download_done_rounded,
              color: LululuColors.mutedTitanium,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}
