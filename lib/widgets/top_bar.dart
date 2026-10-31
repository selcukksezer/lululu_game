import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/energy_service.dart';
import '../theme/lululu_theme.dart';

/// Üst bar: profil avatarı, coin hapı, yıldız hapı, enerji hapı, ayarlar.
/// Zil/bildirim ikonu KESİNLİKLE YOK.
class LululuTopBar extends StatelessWidget {
  const LululuTopBar({
    super.key,
    this.onProfileTap,
    this.onSettingsTap,
    this.light = false,
  });

  final VoidCallback? onProfileTap;
  final VoidCallback? onSettingsTap;

  /// Açık hub temasında (beyaz) yazı rengi koyulaşır.
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Profil avatarı (48dp dairesel, tıklanabilir).
        GestureDetector(
          onTap: onProfileTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: LululuMotion.minTap,
            height: LululuMotion.minTap,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: LululuColors.liquidGold,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      LululuColors.liquidGold.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/design/ui/tier1_bebek_huni.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.bug_report_rounded,
                  color: LululuColors.liquidGold,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Coin hapı.
        _Pill(
          light: light,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/design/ui/icon_coin.png',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.monetization_on_rounded,
                  color: LululuColors.warningSolar,
                  size: 20,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '12.450',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: light
                      ? LululuColors.inkDark
                      : LululuColors.liquidGold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.add_circle_rounded,
                color: LululuColors.toxicNeon,
                size: 18,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Yıldız hapı.
        _Pill(
          light: light,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/design/ui/icon_star.png',
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.star_rounded,
                  color: LululuColors.warningSolar,
                  size: 20,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '86',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color:
                      light ? LululuColors.inkDark : LululuColors.paper,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Enerji hapı (canlı sayaç).
        const _EnergyPill(),
        const SizedBox(width: 8),
        // Ayarlar dişlisi (48dp dokunma hedefi).
        GestureDetector(
          onTap: onSettingsTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: LululuMotion.minTap,
            height: LululuMotion.minTap,
            alignment: Alignment.center,
            child: Icon(
              Icons.settings_rounded,
              color: light
                  ? LululuColors.inkSoft
                  : LululuColors.mutedTitanium,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }
}

/// Koyu hap formu.
class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.light});

  final Widget child;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: light
            ? LululuColors.paperSoft
            : LululuColors.spaceNavy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LululuColors.liquidGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: LululuColors.carbonVoid.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Enerji hapı: atan kalp + "5/30" + mini sayaç. energyNotifier dinler,
/// sayaç için kendi periyodik Timer'ını kurar.
class _EnergyPill extends StatefulWidget {
  const _EnergyPill();

  @override
  State<_EnergyPill> createState() => _EnergyPillState();
}

class _EnergyPillState extends State<_EnergyPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat;
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _beat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _beat.dispose();
    super.dispose();
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final svc = EnergyService.instance;
    return ValueListenableBuilder<int>(
      valueListenable: svc.energyNotifier,
      builder: (_, energy, __) {
        final full = energy >= EnergyService.maxEnergy;
        return _Pill(
          light: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                  CurvedAnimation(
                      parent: _beat, curve: Curves.easeInOut),
                ),
                child: Icon(
                  energy > 0
                      ? Icons.favorite_rounded
                      : Icons.heart_broken_rounded,
                  color: energy > 0
                      ? LululuColors.mysticRuby
                      : LululuColors.mutedTitanium,
                  size: 22,
                ),
              ),
              const SizedBox(width: 5),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$energy/${EnergyService.maxEnergy}',
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.paper,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    full ? 'DOLU' : _mmss(svc.timeToNext),
                    style: GoogleFonts.exo2(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: LululuColors.mutedTitanium,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
