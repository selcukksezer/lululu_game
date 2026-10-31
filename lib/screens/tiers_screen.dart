import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';

/// "AİLEM" sekmesi — 13 tier'ın evrim kartları.
/// 1-8: enum'dan isim + skor, görsel assets/design/bugs_hd.
/// 9-13: mock veri, görsel assets/design/bugs_new. İlk 8 açık, gerisi kilitli.
class TiersScreen extends StatelessWidget {
  const TiersScreen({super.key});

  static const _extraTiers = <_TierInfo>[
    _TierInfo(name: 'MİLLÎ FORMALI', score: 3200, tier: 9),
    _TierInfo(name: 'PEMBE CEKETLİ', score: 6400, tier: 10),
    _TierInfo(name: 'BEYAZ HAYALET', score: 12800, tier: 11),
    _TierInfo(name: 'GRİ TİŞÖRTLÜ', score: 25600, tier: 12),
    _TierInfo(name: 'PEMBE BORNOZLU', score: 51200, tier: 13),
  ];

  List<_TierInfo> get _all {
    final list = <_TierInfo>[
      for (final t in InsectTier.values)
        _TierInfo(
          name: _upperTr(t.name),
          score: t.scoreValue,
          tier: t.tier,
          replik: t.viralReplik,
        ),
      ..._extraTiers,
    ];
    return list;
  }

  /// Türkçe büyük harf (i → İ, ı → I).
  String _upperTr(String s) => s
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .replaceAll('ü', 'Ü')
      .replaceAll('ö', 'Ö')
      .replaceAll('ç', 'Ç')
      .replaceAll('ş', 'Ş')
      .replaceAll('ğ', 'Ğ')
      .toUpperCase();

  String _imageFor(int tier) => tier <= 8
      ? 'assets/design/bugs_hd/tier${tier}_hd.png'
      : 'assets/design/bugs_new/tier${tier}_hd.png';

  void _onTap(BuildContext context, _TierInfo info) {
    final voice = GameAudio.voiceForTier(info.tier);
    if (voice != null) {
      AudioManager().playSfx(voice);
    } else {
      AudioManager().playPop();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          info.replik != null
              ? '${info.name}: "${info.replik}"'
              : '${info.name} — skor ${info.score}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiers = _all;
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        title: Text(
          'BÖCEK AİLESİ',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'İki aynı tier çarpışır, bir üst tier doğar. Zincirin sonu: Pembe Bornozlu. Bir böceğe dokun — sesini duy, repliğini gör.',
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: LululuColors.mutedTitanium,
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: tiers.length,
              itemBuilder: (context, i) {
                final info = tiers[i];
                final locked = info.tier > 8;
                return _TierCard(
                  info: info,
                  imagePath: _imageFor(info.tier),
                  locked: locked,
                  onTap: () => _onTap(context, info),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TierInfo {
  const _TierInfo({
    required this.name,
    required this.score,
    required this.tier,
    this.replik,
  });

  final String name;
  final int score;
  final int tier;
  final String? replik;
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.info,
    required this.imagePath,
    required this.locked,
    required this.onTap,
  });

  final _TierInfo info;
  final String imagePath;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      imagePath,
      width: 92,
      height: 92,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(
        Icons.bug_report_rounded,
        size: 64,
        color: LululuColors.mutedTitanium,
      ),
    );
    return LululuPress(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: LululuColors.paper,
          borderRadius: BorderRadius.circular(LululuRadii.card),
          border: Border.all(
            color: locked
                ? LululuColors.mutedTitanium.withValues(alpha: 0.25)
                : LululuColors.liquidGold.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: locked
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                Colors.grey,
                                BlendMode.saturation,
                              ),
                              child: image,
                            )
                          : image,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.inkDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${info.score} SKOR',
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: LululuColors.mutedTitanium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: locked
                          ? LululuColors.mutedTitanium.withValues(alpha: 0.15)
                          : LululuColors.toxicNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      locked ? 'KİLİTLİ' : 'AÇIK',
                      style: GoogleFonts.exo2(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: locked
                            ? LululuColors.mutedTitanium
                            : LululuColors.toxicNeon,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (locked)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: LululuColors.inkDark.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: LululuColors.paper,
                    size: 16,
                  ),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: LululuColors.inkDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'T${info.tier}',
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.liquidGold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
