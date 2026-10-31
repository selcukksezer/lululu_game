import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/lululu_game_mode.dart';
import '../../navigation/game_routes.dart';
import '../../services/daily_challenge_service.dart';
import '../../theme/lululu_theme.dart';

class DailyChallengeCard extends StatefulWidget {
  const DailyChallengeCard({super.key});

  @override
  State<DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<DailyChallengeCard> {
  bool _loading = true;
  String? _claimMsg;

  @override
  void initState() {
    super.initState();
    DailyChallengeService.instance.addListener(_refresh);
    _boot();
  }

  Future<void> _boot() async {
    await DailyChallengeService.instance.ensureLoaded();
    if (mounted) setState(() => _loading = false);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    DailyChallengeService.instance.removeListener(_refresh);
    super.dispose();
  }

  GameModeKind? _kindFor(String modeId) {
    return switch (modeId) {
      'osmantus' => GameModeKind.osmantus,
      'scream_roach' => GameModeKind.screamRoach,
      'suika' => GameModeKind.suika,
      'balloon_pop' => GameModeKind.balloon,
      'match3' => GameModeKind.match3,
      'makarayiz' => GameModeKind.makarayiz,
      'terlik_tap' => GameModeKind.terlikTap,
      _ => null,
    };
  }

  Future<void> _claim() async {
    final coins = await DailyChallengeService.instance.claimDailyReward();
    if (!mounted) return;
    setState(() {
      _claimMsg = coins > 0 ? '+$coins coin alındı' : 'Bugün alındı';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()));
    }
    final d = DailyChallengeService.instance;
    final left = d.timeLeft;
    final hh = left.inHours.toString().padLeft(2, '0');
    final mm = (left.inMinutes % 60).toString().padLeft(2, '0');

    return Semantics(
      container: true,
      label: 'Günlük viral: ${d.headline}',
      child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LululuRadii.card),
        gradient: LululuGradients.elevatedCard,
        border: Border.all(
          color: d.completedToday
              ? LululuColors.toxicNeon.withValues(alpha: 0.55)
              : LululuColors.coralFlare.withValues(alpha: 0.55),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'GÜNLÜK VİRAL',
                style: GoogleFonts.exo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                  color: LululuColors.mutedTitanium,
                ),
              ),
              const Spacer(),
              Text(
                '$hh:$mm',
                style: GoogleFonts.exo2(
                  fontWeight: FontWeight.w800,
                  color: LululuColors.liquidGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            d.headline,
            style: GoogleFonts.exo2(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: LululuColors.ink,
            ),
          ),
          Text(
            d.completedToday
                ? 'Tamam · streak ${d.streak}'
                : 'İlerleme ${d.bestTowardTarget}/${d.targetScore} · streak ${d.streak}',
            style: GoogleFonts.exo2(
              fontSize: 12,
              color: d.completedToday
                  ? LululuColors.toxicNeon
                  : LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: d.progressTowardTarget,
              minHeight: 6,
              backgroundColor: LululuColors.darkObsidian,
              color: d.completedToday
                  ? LululuColors.toxicNeon
                  : LululuColors.liquidGold,
            ),
          ),
          if (_claimMsg != null) ...[
            const SizedBox(height: 4),
            Text(
              _claimMsg!,
              style: GoogleFonts.exo2(
                fontSize: 11,
                color: LululuColors.toxicNeon,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Günlük oyna: ${d.headline}',
                  child: FilledButton(
                    onPressed: () {
                      final kind = _kindFor(d.modeId);
                      if (kind != null) openGameMode(context, kind);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: LululuColors.liquidGold,
                      foregroundColor: LululuColors.carbonVoid,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(
                      'OYNA',
                      style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: d.canClaimToday ? _claim : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LululuColors.liquidGold,
                    side: BorderSide(
                      color: LululuColors.liquidGold.withValues(alpha: 0.6),
                    ),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: Text(
                    'ÖDÜL',
                    style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}
