import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/energy_service.dart';
import '../theme/lululu_theme.dart';
import '../widgets/shop_dialog.dart';
import 'ad_mock.dart';

/// Enerji bitince gösterilen popup: sayaç + reklam/mağaza seçenekleri.
Future<void> showEnergyEmptyPopup(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _EnergyEmptyDialog(),
  );
}

class _EnergyEmptyDialog extends StatefulWidget {
  const _EnergyEmptyDialog();

  @override
  State<_EnergyEmptyDialog> createState() => _EnergyEmptyDialogState();
}

class _EnergyEmptyDialogState extends State<_EnergyEmptyDialog> {
  late Timer _timer;
  bool _rewarding = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final svc = EnergyService.instance;
      // Sayaç dolduysa (enerji doldu) popup kendiliğinden kapanır.
      if (svc.energy > 0) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _watchAd() async {
    if (_rewarding) return;
    setState(() => _rewarding = true);
    final granted = await showRewardedAdMock(context, rewardLabel: '+5 ENERJİ');
    if (!mounted) return;
    setState(() => _rewarding = false);
    if (granted) {
      EnergyService.instance.addEnergy(5);
      Navigator.of(context).pop();
    }
  }

  void _openShop() {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ShopScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = EnergyService.instance;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          gradient: LululuGradients.carbonToNavy,
          borderRadius: BorderRadius.circular(LululuRadii.panel),
          border: Border.all(
            color: LululuColors.mysticRuby.withValues(alpha: 0.55),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: LululuColors.mysticRuby.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.heart_broken_rounded,
              size: 64,
              color: LululuColors.mysticRuby,
            ),
            const SizedBox(height: 12),
            Text(
              'ENERJİN BİTTİ!',
              textAlign: TextAlign.center,
              style: GoogleFonts.bangers(
                fontSize: 34,
                color: LululuColors.warningSolar,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: svc.energyNotifier,
              builder: (_, energy, __) => Text(
                '$energy/${EnergyService.maxEnergy}',
                style: GoogleFonts.exo2(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: LululuColors.paper,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sonraki enerji: ${_mmss(svc.timeToNext)}',
              style: GoogleFonts.exo2(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: LululuColors.mutedTitanium,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: LululuMotion.minTap,
              child: ElevatedButton(
                onPressed: _watchAd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: LululuColors.toxicNeon,
                  foregroundColor: LululuColors.carbonVoid,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LululuRadii.pill),
                  ),
                ),
                child: _rewarding
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Text(
                        'REKLAM İZLE (+5)',
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: LululuMotion.minTap,
              child: OutlinedButton(
                onPressed: _openShop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: LululuColors.liquidGold,
                  side: const BorderSide(
                      color: LululuColors.liquidGold, width: 1.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LululuRadii.pill),
                  ),
                ),
                child: Text(
                  'MAĞAZA',
                  style: GoogleFonts.exo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
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
