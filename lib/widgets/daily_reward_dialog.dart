import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import 'lululu_press.dart';

/// 7 günlük ödül takvimi & Günlük Hediye Kutusu + `#hbOverlay` kalp kırılma katmanı.
Future<void> showDailyRewardDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const DailyRewardDialog(),
  );
}

/// `#hbOverlay` — Kalp Kırılma Animasyonu (`-1 ENERJİ`).
class HbOverlay extends StatelessWidget {
  const HbOverlay({
    super.key,
    this.visible = false,
    this.tagText = '-1 ENERJİ',
  });

  final bool visible;
  final String tagText;

  /// Kısa süreli (`#hbOverlay`) kalp kırılma animasyonunu üst katmanda oynatır.
  static Future<void> play(
    BuildContext context, {
    String tagText = '-1 ENERJİ',
    Duration duration = const Duration(milliseconds: 520),
  }) async {
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTesting) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => HbOverlay(visible: true, tagText: tagText),
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
                          'assets/design/ui/icon_heart_exact.webp',
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
                          'assets/design/ui/icon_heart_exact.webp',
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
            Text(
              tagText,
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

class _DayReward {
  const _DayReward({
    required this.day,
    required this.label,
    required this.asset,
    required this.fallbackIcon,
  });

  final int day;
  final String label;
  final String asset;
  final IconData fallbackIcon;
}

class DailyRewardDialog extends StatefulWidget {
  const DailyRewardDialog({super.key});

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<DailyRewardDialog> {
  static const int _today = 3;
  bool _claimed = false;

  static const _rewards = <_DayReward>[
    _DayReward(
      day: 1,
      label: '+100 COİN',
      asset: 'assets/design/ui/icon_coin_exact.webp',
      fallbackIcon: Icons.monetization_on_rounded,
    ),
    _DayReward(
      day: 2,
      label: '+250 COİN',
      asset: 'assets/design/ui/icon_coin_exact.webp',
      fallbackIcon: Icons.monetization_on_rounded,
    ),
    _DayReward(
      day: 3,
      label: '+500 COİN',
      asset: 'assets/design/ui/icon_calendar_exact.webp',
      fallbackIcon: Icons.card_giftcard_rounded,
    ),
    _DayReward(
      day: 4,
      label: '+5 ENERJİ',
      asset: 'assets/design/ui/icon_heart_exact.webp',
      fallbackIcon: Icons.favorite_rounded,
    ),
    _DayReward(
      day: 5,
      label: '+750 COİN',
      asset: 'assets/design/ui/icon_coin_exact.webp',
      fallbackIcon: Icons.monetization_on_rounded,
    ),
    _DayReward(
      day: 6,
      label: 'STİCKER',
      asset: 'assets/images/stickers/sticker_tier1_cone.png',
      fallbackIcon: Icons.auto_awesome_rounded,
    ),
    _DayReward(
      day: 7,
      label: 'SÜPER KUTU',
      asset: 'assets/design/ui/chest_result.webp',
      fallbackIcon: Icons.workspace_premium_rounded,
    ),
  ];

  Future<void> _claimBase() async {
    if (_claimed) return;
    setState(() => _claimed = true);
    final pm = ProgressManager.instance;
    if (pm.canClaimDailyGiftBox) {
      await pm.claimDailyGiftBox();
    } else {
      await pm.addCoins(500);
    }
    AudioManager().playWin();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Ödüllü reklam SDK'sı kurulu değil: reklam gösterilemez, ödül
  /// verilmez. Gerçek SDK eklendiğinde reklam dalları gerçek reklam
  /// akışına bağlanmalıdır; sahte (mock) reklamla ödül verilmez (madde 4).
  void _showRewardsComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ödüllü reklamlar yakında — şimdilik kullanılamıyor.',
          style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
        backgroundColor: LululuColors.carbonVoid,
      ),
    );
  }

  void _claimDouble() {
    _showRewardsComingSoon();
  }

  Future<void> _claimEnergy() async {
    final pm = ProgressManager.instance;
    if (pm.canClaimDailyFreeEnergy) {
      await pm.claimDailyFreeEnergy(amount: 5);
      AudioManager().playWin();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // Ücretsiz hak tükendi: reklam dalı ödül vermez, bilgi gösterir.
    if (!mounted) return;
    _showRewardsComingSoon();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 382),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment(-0.85, -0.5),
              end: Alignment(0.85, 0.5),
              colors: [
                Color(0xFF7C3AED),
                Color(0xFFE01E5A),
                Color(0xFFFF6B35),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/design/ui/icon_calendar_exact.webp',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.card_giftcard_rounded,
                        color: LululuColors.liquidGold,
                        size: 56,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GÜNLÜK HEDİYE KUTUSU',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.baloo2(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '3. gün · 500 coin seni bekliyor',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 6.0;
                    final cols = constraints.maxWidth < 290 ? 3 : 4;
                    final itemW =
                        (constraints.maxWidth - spacing * (cols - 1)) / cols;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final r in _rewards)
                          SizedBox(
                            width: r.day == 7 && cols == 4
                                ? itemW * 2 + spacing
                                : itemW,
                            height: 78,
                            child: _buildDayTile(r),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: LululuPress(
                        onTap: () {
                          if (!_claimed) _claimBase();
                        },
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFFD34D),
                                Color(0xFFFFB800),
                                Color(0xFFF59E00),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFFB97A00),
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _claimed ? 'ALINDI' : 'KUTUYU AÇ · 500',
                              style: GoogleFonts.baloo2(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LululuPress(
                        onTap: _claimDouble,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x8C080B12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFFB800),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'YAKINDA',
                                    style: GoogleFonts.baloo2(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '2X · YAKINDA',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LululuPress(
                  onTap: _claimEnergy,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF37E08B),
                          Color(0xFF12B76A),
                          Color(0xFF0A9553),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF066C3C),
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/design/ui/icon_energy_bolt_exact.webp',
                            width: 21,
                            height: 21,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ENERJİ AL · +5',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
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
    );
  }

  Widget _buildDayTile(_DayReward r) {
    final isToday = r.day == _today;
    final isPast = r.day < _today;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isToday
            ? Colors.white
            : isPast
                ? const Color(0x3800C853)
                : const Color(0x47080B12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? const Color(0xFFFFB800)
              : Colors.white.withValues(alpha: 0.22),
          width: isToday ? 2.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${r.day}. GÜN',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.baloo2(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isToday
                  ? const Color(0xFFE01E5A)
                  : Colors.white.withValues(alpha: 0.85),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: isPast
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF37E08B),
                    size: 24,
                  )
                : Image.asset(
                    r.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      r.fallbackIcon,
                      size: 22,
                      color: isToday
                          ? const Color(0xFFFFB800)
                          : Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              r.label,
              maxLines: 1,
              style: GoogleFonts.baloo2(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isToday ? const Color(0xFF141B2A) : Colors.white,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
