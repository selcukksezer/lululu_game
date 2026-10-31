import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/osmantus_cast.dart';
import '../services/audio_manager.dart';
import '../services/daily_challenge_service.dart';
import '../services/leaderboard_service.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';

/// Viral Osmantuş ritmi: videodaki iki kişiyle “TUŞ!” anında dokun.
class OsmantusScreen extends StatefulWidget {
  const OsmantusScreen({super.key});

  @override
  State<OsmantusScreen> createState() => _OsmantusScreenState();
}

class _OsmantusScreenState extends State<OsmantusScreen>
    with SingleTickerProviderStateMixin {
  static const _beatMs = 780;
  static const _windowMs = 140;

  late final AnimationController _pulse;
  final _rng = Random();

  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _best = 0;
  int _lives = 3;
  int _dayStreak = 0;
  bool _alive = true;
  String _callout = 'OSMAN TUŞ!';
  String _hint = 'İki kişi — yeşil halkada dokun, dıkkış dıkkış!';
  DateTime _nextBeat = DateTime.now().add(const Duration(milliseconds: 1400));
  final DateTime _startedAt = DateTime.now();
  bool _hitThisBeat = false;
  bool _introDone = false;
  Timer? _loop;
  late final int _beatBaseMs;

  /// Aktif konuşan: 0 = Osman, 1 = Tuş.
  int _speakerIndex = 0;

  OsmantusPerson get _speaker => OsmantusCast.duo[_speakerIndex];
  OsmantusPerson get _partner =>
      OsmantusCast.duo[1 - _speakerIndex];

  @override
  void initState() {
    super.initState();
    final day = DateTime.now();
    final seed = day.year * 10000 + day.month * 100 + day.day;
    _beatBaseMs = (_beatMs - 40) + (seed % 81); // daily tempo nudge
    _pulse = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _beatBaseMs),
    )..repeat();
    _loadBest();
    _loop = Timer.periodic(const Duration(milliseconds: 32), _tick);
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    await DailyChallengeService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best =
          LeaderboardService.instance.getBest(LeaderboardService.modeOsmantus);
      _dayStreak = DailyChallengeService.instance.streak;
    });
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _loop?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _tick(Timer _) {
    if (!_alive || !mounted) return;
    final now = DateTime.now();
    // Intro grace: no life drain while player reads the first cue.
    if (!_introDone) {
      if (now.difference(_startedAt).inMilliseconds < 1200) return;
      _introDone = true;
    }
    if (now.isAfter(_nextBeat.add(const Duration(milliseconds: _windowMs)))) {
      if (!_hitThisBeat) {
        _miss();
        if (!_alive) return;
      }
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    _nextBeat = DateTime.now()
        .add(Duration(milliseconds: _beatBaseMs - _rng.nextInt(80)));
    _hitThisBeat = false;
    _speakerIndex = 1 - _speakerIndex;
    final lines = _speaker.lines;
    _callout = lines[_rng.nextInt(lines.length)];
    _pulse
      ..duration = Duration(milliseconds: _beatBaseMs)
      ..forward(from: 0);
    setState(() {});
  }

  void _miss() {
    HapticFeedback.heavyImpact();
    _combo = 0;
    _lives -= 1;
    _hint = 'Kaçırdın! ${_speaker.displayName} kaçtı.';
    if (_lives <= 0) {
      _alive = false;
      _hint = 'Bitti. Osman & Tuş seni yendi.';
      unawaited(
        LeaderboardService.instance
            .submitScore(LeaderboardService.modeOsmantus, _score),
      );
      if (_score > _best) _best = _score;
    }
    setState(() {});
  }

  void _onTap() {
    if (!_alive) {
      _restart();
      return;
    }
    final delta = DateTime.now().difference(_nextBeat).inMilliseconds.abs();
    if (delta <= _windowMs) {
      if (_hitThisBeat) return;
      _hitThisBeat = true;
      final perfect = delta <= 55;
      _combo += 1;
      if (_combo > _maxCombo) _maxCombo = _combo;
      final gain = (perfect ? 120 : 70) + _combo * 8;
      _score += gain;
      _hint = perfect
          ? 'MÜKEMMEL ${_speaker.displayName}! x$_combo'
          : 'İyi tuş · ${_speaker.displayName}! x$_combo';
      AudioManager().triggerHaptic();
      HapticFeedback.mediumImpact();
      setState(() {});
    } else if (DateTime.now().isBefore(_nextBeat)) {
      _hint = 'Erkenci! ${_partner.displayName} bekliyor yeşili.';
      HapticFeedback.selectionClick();
      setState(() {});
    } else if (delta <= _windowMs * 3) {
      // Near-miss after the window — life cost. Far taps ignored (scroll/noise).
      _miss();
    } else {
      _hint = 'Bekle yeşil halkayı — ikili tuş anında bas.';
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  void _restart() {
    setState(() {
      _score = 0;
      _combo = 0;
      _maxCombo = 0;
      _lives = 3;
      _alive = true;
      _introDone = false;
      _speakerIndex = 0;
      _callout = 'OSMAN TUŞ!';
      _hint = 'İki kişi — yeşil halkada dokun, dıkkış dıkkış!';
      _hitThisBeat = false;
      _nextBeat = DateTime.now().add(const Duration(milliseconds: 1400));
    });
  }

  String _statsLine() =>
      'Max combo x$_maxCombo · Günlük streak $_dayStreak · tempo ${_beatBaseMs}ms';

  @override
  Widget build(BuildContext context) {
    final until = _nextBeat.difference(DateTime.now()).inMilliseconds;
    final inWindow = until.abs() <= _windowMs;

    return ArcadeScreen(
      title: 'Osmantuş',
      score: _score,
      best: _best,
      hint: _hint,
      statLabel: 'STREAK',
      statValue: '$_dayStreak',
      onRestart: _restart,
      overlay: !_alive
          ? ArcadeResultOverlay(
              title: 'İKİLİ YENDİ',
              message: _statsLine(),
              score: _score,
              best: _best,
              won: false,
              modeTitle: 'Osmantuş',
              shareLine: _statsLine(),
              retryLabel: 'YENİDEN',
              onRetry: _restart,
            )
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Can: ${'❤️' * _lives}${'🖤' * (3 - _lives)}',
                    style: GoogleFonts.exo2(
                      color: LululuColors.mysticRuby,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'x$_combo',
                    style: GoogleFonts.exo2(
                      color: LululuColors.toxicNeon,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = _pulse.value;
                    final ring = 40.0 + (1 - t) * 110;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: ring + 24,
                          height: ring + 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: inWindow
                                  ? LululuColors.toxicNeon
                                  : LululuColors.cyberFuchsia
                                      .withValues(alpha: 0.55),
                              width: inWindow ? 5 : 2,
                            ),
                            boxShadow: inWindow
                                ? [
                                    BoxShadow(
                                      color: LululuColors.toxicNeon
                                          .withValues(alpha: 0.45),
                                      blurRadius: 24,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0;
                                    i < OsmantusCast.duo.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  _DuoSlot(
                                    person: OsmantusCast.duo[i],
                                    active: i == _speakerIndex,
                                    inWindow: inWindow,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _callout,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.exo2(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: LululuColors.liquidGold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_speaker.displayName} · ${_partner.displayName}',
                              style: GoogleFonts.exo2(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: LululuColors.mutedTitanium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DuoSlot extends StatelessWidget {
  const _DuoSlot({
    required this.person,
    required this.active,
    required this.inWindow,
  });

  final OsmantusPerson person;
  final bool active;
  final bool inWindow;

  @override
  Widget build(BuildContext context) {
    final scale = active ? (inWindow ? 1.12 : 1.05) : 0.88;
    final glow = active && inWindow
        ? [
            BoxShadow(
              color: LululuColors.toxicNeon.withValues(alpha: 0.4),
              blurRadius: 18,
            ),
          ]
        : null;
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      child: Opacity(
        opacity: active ? 1 : 0.55,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(boxShadow: glow),
              child: StickerImage(
                assetPath: person.assetPath,
                size: active ? 128 : 100,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              person.displayName,
              style: GoogleFonts.exo2(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active
                    ? LululuColors.toxicNeon
                    : LululuColors.mutedTitanium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
