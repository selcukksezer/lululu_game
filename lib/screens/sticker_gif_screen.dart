import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/sticker_gif_catalog.dart';
import '../theme/lululu_theme.dart';
import '../widgets/dot_scaffold.dart';
import '../widgets/sticker_image.dart';

/// Böcek çıkartması / GIF ara + indir + paylaş.
class StickerGifScreen extends StatefulWidget {
  const StickerGifScreen({super.key});

  @override
  State<StickerGifScreen> createState() => _StickerGifScreenState();
}

class _StickerGifScreenState extends State<StickerGifScreen> {
  final _query = TextEditingController();
  String? _busyId;
  String? _status;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _download(StickerGifItem item) async {
    setState(() {
      _busyId = item.id;
      _status = null;
    });
    try {
      final path = await StickerGifCatalog.instance.downloadAndShare(item);
      if (!mounted) return;
      setState(() => _status = 'İndirildi · $path');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = StickerGifCatalog.instance.search(_query.text);

    return DotScaffold(
      appBar: AppBar(
        title: Text(
          'Çıkartma / GIF',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: LululuColors.ink),
              decoration: InputDecoration(
                hintText: 'Ara: osmantuş, kongo, gif…',
                hintStyle: const TextStyle(color: LululuColors.mutedTitanium),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: LululuColors.liquidGold),
                filled: true,
                fillColor: LululuColors.darkObsidian,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LululuRadii.pill),
                  borderSide: BorderSide(
                    color: LululuColors.cyberFuchsia.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _status!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.exo2(
                  fontSize: 11,
                  color: LululuColors.toxicNeon,
                ),
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final item = list[i];
                final busy = _busyId == item.id;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(LululuRadii.card),
                    gradient: LululuGradients.navyToCarbon,
                    border: Border.all(
                      color: LululuColors.liquidGold.withValues(alpha: 0.35),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Expanded(
                        child: StickerImage(
                          assetPath: item.assetPath,
                          size: 96,
                        ),
                      ),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontWeight: FontWeight.w800,
                          color: LululuColors.ink,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        item.remoteGifUrl != null ? 'GIF' : 'PNG',
                        style: GoogleFonts.exo2(
                          fontSize: 10,
                          color: LululuColors.mutedTitanium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: FilledButton(
                          onPressed: busy ? null : () => _download(item),
                          style: FilledButton.styleFrom(
                            backgroundColor: LululuColors.liquidGold,
                            foregroundColor: LululuColors.carbonVoid,
                          ),
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'İNDİR',
                                  style: GoogleFonts.exo2(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
