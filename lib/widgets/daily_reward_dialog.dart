import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';
import 'lululu_press.dart';

/// 7 günlük ödül takvimi. Bugünün ödülü +5 ENERJİ.
Future<void> showDailyRewardDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _DailyRewardDialog(),
  );
}

class _DayReward {
  const _DayReward(this.day, this.label, this.icon);

  final int day;
  final String label;
  final IconData icon;
}

class _DailyRewardDialog extends StatelessWidget {
  const _DailyRewardDialog();

  // Mock seri: bugün 4. gün.
  static const _today = 4;

  static const _rewards = <_DayReward>[
    _DayReward(1, '+100 COİN', Icons.monetization_on_rounded),
    _DayReward(2, '+150 COİN', Icons.monetization_on_rounded),
    _DayReward(3, '+200 COİN', Icons.monetization_on_rounded),
    _DayReward(4, '+5 ENERJİ', Icons.favorite_rounded),
    _DayReward(5, '+250 COİN', Icons.monetization_on_rounded),
    _DayReward(6, '+300 COİN', Icons.monetization_on_rounded),
    _DayReward(7, '+10 ENERJİ', Icons.favorite_rounded),
  ];

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
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                gradient: LululuGradients.fuchsiaToGold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: LululuColors.paper,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'GÜNLÜK ÖDÜL',
              style: GoogleFonts.exo2(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: LululuColors.inkDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Her gün gir, seriyi bozma!',
              style: GoogleFonts.exo2(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: LululuColors.mutedTitanium,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _rewards.length,
              itemBuilder: (context, i) {
                final r = _rewards[i];
                final isToday = r.day == _today;
                final isPast = r.day < _today;
                return Container(
                  decoration: BoxDecoration(
                    gradient: isToday
                        ? LululuGradients.fuchsiaToGold
                        : null,
                    color: isToday
                        ? null
                        : isPast
                            ? LululuColors.toxicNeon
                                .withValues(alpha: 0.15)
                            : LululuColors.paperSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isToday
                          ? Colors.transparent
                          : LululuColors.mutedTitanium
                              .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${r.day}. GÜN',
                        style: GoogleFonts.exo2(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isToday
                              ? LululuColors.paper
                              : LululuColors.mutedTitanium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isPast ? Icons.check_circle_rounded : r.icon,
                        size: 22,
                        color: isToday
                            ? LululuColors.paper
                            : isPast
                                ? LululuColors.toxicNeon
                                : LululuColors.inkDark,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isToday
                              ? LululuColors.paper
                              : LululuColors.inkDark,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            LululuPress(
              onTap: () {
                AudioManager().playWin();
                Navigator.of(context).pop();
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LululuGradients.fuchsiaToGold,
                  borderRadius:
                      BorderRadius.all(Radius.circular(14)),
                ),
                child: Text(
                  'AL · +5 ENERJİ',
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: LululuColors.paper,
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
