import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import 'ad_mock.dart';
import 'lululu_press.dart';

/// Günlük ödül diyaloğu — prototip içeriğiyle hizalı.
///
/// - "ÖDÜLÜN HAZIR!" / "3. gün · 500 coin"
/// - AL · 500 → +500 coin
/// - REKLAM → 2X · 1.000 → ad_mock + 1.000 coin
/// - ENERJİ AL · +5 → ad_mock + 5 enerji
///
/// Hub'dan [showDailyRewardDialog] ile açılır.
/// Tüm görseller assets/design/ içindeki gerçek dosyalar.
Future<void> showDailyRewardDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _DailyRewardDialog(),
  );
}

/// assets/design/ ikon klasörü — diyalog görselleri.
const _icons = 'assets/design/icons/extra_icons/All_Icons';
const _coinImg = 'assets/design/ui/icon_coin.png';
const _heartImg = '$_icons/health_heart.png';

class _DailyRewardDialog extends StatelessWidget {
  const _DailyRewardDialog();

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _claimCoins(BuildContext context) {
    ProgressManager().addCoins(500);
    AudioManager().playWin();
    _toast(context, '+500 coin alındı!');
    Navigator.of(context).pop();
  }

  Future<void> _claimDouble(BuildContext context) async {
    final ok = await showRewardedAdMock(
      context,
      rewardLabel: '+1.000 COİN',
    );
    if (!context.mounted) return;
    if (ok) {
      ProgressManager().addCoins(1000);
      AudioManager().playWin();
      _toast(context, '+1.000 coin alındı!');
    }
    Navigator.of(context).pop();
  }

  Future<void> _claimEnergy(BuildContext context) async {
    final ok = await showRewardedAdMock(
      context,
      rewardLabel: '+5 ENERJİ',
    );
    if (!context.mounted) return;
    if (ok) {
      EnergyService.instance.addEnergy(5);
      AudioManager().playWin();
      _toast(context, '+5 enerji alındı!');
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: LululuColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LululuGradients.fuchsiaToGold,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                '$_icons/daily_reward_calendar.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.card_giftcard_rounded,
                  color: LululuColors.paper,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ÖDÜLÜN HAZIR!',
              style: GoogleFonts.exo2(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: LululuColors.inkDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '3. gün · 500 coin',
              style: GoogleFonts.exo2(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: LululuColors.mutedTitanium,
              ),
            ),
            const SizedBox(height: 18),
            LululuPress(
              onTap: () => _claimCoins(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LululuGradients.fuchsiaToGold,
                  borderRadius:
                      BorderRadius.all(Radius.circular(14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      _coinImg,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.monetization_on_rounded,
                        color: LululuColors.paper,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AL · 500',
                      style: GoogleFonts.exo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: LululuColors.paper,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            LululuPress(
              onTap: () => _claimDouble(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LululuColors.inkDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      _coinImg,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.play_circle_fill_rounded,
                        color: LululuColors.liquidGold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'REKLAM → 2X · 1.000',
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: LululuColors.paper,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            LululuPress(
              onTap: () => _claimEnergy(context),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LululuColors.cyberFuchsia
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: LululuColors.cyberFuchsia
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      _heartImg,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.favorite_rounded,
                        color: LululuColors.cyberFuchsia,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ENERJİ AL · +5',
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: LululuColors.inkDark,
                      ),
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
