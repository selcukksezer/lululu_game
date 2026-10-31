import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';
import 'lululu_press.dart';

/// Sahte ödüllü reklam oynatıcı (SÖZLEŞME İMZA — değiştirme).
///
/// 5 saniye geri sayım; X butonu süre bitmeden kilitli. Süre bitince
/// "ÖDÜLÜ AL" belirir → true döner. Kapatılırsa false.
Future<bool> showRewardedAdMock(
  BuildContext context, {
  required String rewardLabel,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RewardedAdMock(rewardLabel: rewardLabel),
  ).then((v) => v ?? false);
}

class _RewardedAdMock extends StatefulWidget {
  const _RewardedAdMock({required this.rewardLabel});

  final String rewardLabel;

  @override
  State<_RewardedAdMock> createState() => _RewardedAdMockState();
}

class _RewardedAdMockState extends State<_RewardedAdMock> {
  static const _duration = 5;
  int _left = _duration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      AudioManager().playPop();
      if (_left <= 0) {
        t.cancel();
        AudioManager().playWin();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _done => _left <= 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: LululuColors.carbonVoid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: LululuColors.liquidGold.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: LululuColors.warningSolar,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'REKLAM',
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.carbonVoid,
                    ),
                  ),
                ),
                const Spacer(),
                Opacity(
                  opacity: _done ? 1 : 0.35,
                  child: IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _done
                        ? () => Navigator.of(context).pop(false)
                        : null,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: LululuColors.paper,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LululuGradients.navyToCarbon,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      color: LululuColors.mutedTitanium,
                      size: 44,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sponsorlu içerik oynatılıyor…',
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LululuColors.mutedTitanium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_done) ...[
              Text(
                '$_left',
                style: GoogleFonts.bangers(
                  fontSize: 52,
                  color: LululuColors.liquidGold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ödül için reklamın bitmesini bekle',
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: LululuColors.mutedTitanium,
                ),
              ),
            ] else ...[
              Text(
                'ÖDÜLÜN HAZIR',
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: LululuColors.liquidGold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.rewardLabel,
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: LululuColors.paper,
                ),
              ),
              const SizedBox(height: 12),
              LululuPress(
                onTap: () => Navigator.of(context).pop(true),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: LululuGradients.fuchsiaToGold,
                    borderRadius:
                        BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Text(
                    'ÖDÜLÜ AL',
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
          ],
        ),
      ),
    );
  }
}
