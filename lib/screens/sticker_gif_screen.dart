import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';
import '../widgets/dot_scaffold.dart';
import '../widgets/lululu_press.dart';

/// STÜDYO → GIF OLUŞTUR — prototip birebir.
///
/// Kare seçimi (3 böcek) + Metin & Hız + GIF OLUŞTUR.
class StickerGifScreen extends StatefulWidget {
  const StickerGifScreen({super.key});

  @override
  State<StickerGifScreen> createState() => _StickerGifScreenState();
}

class _StickerGifScreenState extends State<StickerGifScreen> {
  static const _frames = <_GifFrame>[
    _GifFrame(
      name: 'Pijamalı Dansçı',
      asset: 'assets/design/bugs_hd/tier4_hd.png',
    ),
    _GifFrame(
      name: 'Hamam Diva',
      asset: 'assets/design/bugs_hd/tier5_hd.png',
    ),
    _GifFrame(
      name: 'Kongo Lideri',
      asset: 'assets/design/bugs_hd/tier7_hd.png',
    ),
  ];

  static const _speeds = ['Yavaş', 'Normal', 'Hızlı'];

  final _selected = <int>{0, 1, 2};
  final _captionCtrl = TextEditingController(text: 'DANS ZAMANI!');
  int _speed = 1;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DotScaffold(
      appBar: AppBar(
        title: Text(
          'GIF OLUŞTUR',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Önizleme.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LululuRadii.card),
              gradient: LululuGradients.navyToCarbon,
              border: Border.all(
                color: LululuColors.liquidGold.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: LululuColors.cyberFuchsia,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'GIF',
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: LululuColors.paper,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: _selected.isEmpty
                      ? const SizedBox.shrink()
                      : Image.asset(
                          _frames[_selected.first].asset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.bug_report_rounded,
                            size: 72,
                            color: LululuColors.paper,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  _captionCtrl.text.isEmpty
                      ? 'DANS ZAMANI!'
                      : _captionCtrl.text,
                  style: GoogleFonts.bangers(
                    fontSize: 30,
                    letterSpacing: 1.2,
                    color: LululuColors.liquidGold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kareleri Seç',
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: LululuColors.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _frames.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < _frames.length - 1 ? 8 : 0,
                    ),
                    child: _FrameCard(
                      frame: _frames[i],
                      selected: _selected.contains(i),
                      onTap: () => setState(() {
                        if (_selected.contains(i)) {
                          _selected.remove(i);
                        } else {
                          _selected.add(i);
                        }
                      }),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Seçili kareler önizlemede sırayla oynar.',
            style: GoogleFonts.exo2(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Metin & Hız',
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: LululuColors.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _captionCtrl,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.exo2(
              fontWeight: FontWeight.w800,
              color: LululuColors.inkDark,
            ),
            decoration: InputDecoration(
              hintText: 'DANS ZAMANI!',
              filled: true,
              fillColor: LululuColors.paper,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < _speeds.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < _speeds.length - 1 ? 8 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () => setState(() => _speed = i),
                      child: Container(
                        height: LululuMotion.minTap,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _speed == i
                              ? LululuColors.liquidGold
                              : LululuColors.darkObsidian,
                        ),
                        child: Text(
                          _speeds[i],
                          style: GoogleFonts.exo2(
                            fontWeight: FontWeight.w900,
                            color: _speed == i
                                ? LululuColors.carbonVoid
                                : LululuColors.mutedTitanium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => _toast(
                      'GIF oluşturuldu · ${_selected.length} kare · ${_speeds[_speed]}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: LululuColors.toxicNeon,
                foregroundColor: LululuColors.carbonVoid,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Text(
                'GIF OLUŞTUR',
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GifFrame {
  const _GifFrame({required this.name, required this.asset});

  final String name;
  final String asset;
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.frame,
    required this.selected,
    required this.onTap,
  });

  final _GifFrame frame;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: LululuColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? LululuColors.liquidGold
                : LululuColors.mutedTitanium.withValues(alpha: 0.3),
            width: selected ? 3 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 72,
              child: Image.asset(
                frame.asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.bug_report_rounded,
                  size: 48,
                  color: LululuColors.mutedTitanium,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              frame.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.exo2(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: selected
                    ? LululuColors.inkDark
                    : LululuColors.mutedTitanium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
