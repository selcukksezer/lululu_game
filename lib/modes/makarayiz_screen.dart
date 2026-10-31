import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/leaderboard_service.dart';
import '../screens/result_screen.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';

enum _Lane { left, mid, right }

/// Viral Makarayız — kaydır / dokun, beat’te doğru şerit.
class MakarayizScreen extends StatefulWidget {
  const MakarayizScreen({super.key});

  @override
  State<MakarayizScreen> createState() => _MakarayizScreenState();
}

class _MakarayizScreenState extends State<MakarayizScreen>
    with SingleTickerProviderStateMixin {
  static const _beatMs = 640;
  static const _windowMs = 120;
  static const _introWindowMs = 200;
  static const _introBeats = 4;

  late final AnimationController _pulse;
  final _rng = Random();

  int _score = 0;
  int _combo = 0;
  int _best = 0;
  int _lives = 3;
  int _beatIndex = 0;
  bool _alive = true;
  bool _resultShown = false;
  _Lane _target = _Lane.mid;
  _Lane _player = _Lane.mid;
  InsectTier _bug = InsectTier.fan;
  String _hint = 'Makarayız abi! Beat’te kaydır / şeride dokun.';
  DateTime _nextBeat = DateTime.now().add(const Duration(milliseconds: 800));
  bool _hitThisBeat = false;
  Timer? _loop;

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _beatMs),
    )..repeat();
    _loadBest();
    _loop = Timer.periodic(const Duration(milliseconds: 32), _tick);
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best =
          LeaderboardService.instance.getBest(LeaderboardService.modeMakarayiz);
    });
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _loop?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  int get _hitWindowMs =>
      _beatIndex < _introBeats ? _introWindowMs : _windowMs;

  void _tick(Timer _) {
    if (!_alive || !mounted) return;
    final now = DateTime.now();
    if (now.isAfter(_nextBeat.add(Duration(milliseconds: _hitWindowMs)))) {
      if (!_hitThisBeat) _miss();
      if (!_alive) return;
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    _nextBeat =
        DateTime.now().add(Duration(milliseconds: _beatMs - _rng.nextInt(60)));
    _hitThisBeat = false;
    _beatIndex++;
    _target = _Lane.values[_rng.nextInt(3)];
    _bug = InsectTier.values[_rng.nextInt(InsectTier.values.length)];
    _pulse
      ..duration = const Duration(milliseconds: _beatMs)
      ..forward(from: 0);
    setState(() {});
  }

  void _miss() {
    HapticFeedback.heavyImpact();
    _combo = 0;
    _lives -= 1;
    _hint = 'Kaçırdın! Yanlış şerit ya da timing.';
    if (_lives <= 0) {
      _alive = false;
      _hint = 'Makara bitti. Yeniden çek!';
      unawaited(
        LeaderboardService.instance
            .submitScore(LeaderboardService.modeMakarayiz, _score),
      );
      if (_score > _best) _best = _score;
    }
    setState(() {});
  }

  void _tryHit(_Lane lane) {
    if (!_alive) {
      _restart();
      return;
    }
    _player = lane;
    final delta = DateTime.now().difference(_nextBeat).inMilliseconds.abs();
    final window = _hitWindowMs;
    if (delta <= window && lane == _target) {
      if (_hitThisBeat) return;
      _hitThisBeat = true;
      _combo += 1;
      final gain = 90 + _combo * 10;
      _score += gain;
      _hint = _bug.viralReplik;
      unawaited(
        AudioManager().playSfx(
          _bug.voiceFile,
          playbackRate: 0.95 + _rng.nextDouble() * 0.2,
        ),
      );
      HapticFeedback.mediumImpact();
      setState(() {});
      return;
    }
    if (delta <= window && lane != _target) {
      _miss();
    }
  }

  void _restart() {
    setState(() {
      _alive = true;
      _score = 0;
      _combo = 0;
      _lives = 3;
      _beatIndex = 0;
      _player = _Lane.mid;
      _hint = 'Makarayız abi! Beat’te kaydır / şeride dokun.';
      _scheduleNext();
    });
  }

  /// Oyun sonu: yeni sonuç ekranı. "TEKRAR OYNA" yeni turu başlatır,
  /// "ANA SAYFA"da eski sonuç akışı devam eder (bozulmadı).
  Future<void> _presentResult() async {
    final replay = await showGameResult(
      context,
      score: _score,
      coins: ResultScoring.coinsFor(_score),
      stars: ResultScoring.starsFor(score: _score, best: _best),
    );
    if (!mounted) return;
    _resultShown = false;
    if (replay) {
      _restart();
    } else {
      setState(() {});
    }
  }

  void _edgeShowResult() {
    if (_resultShown) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _presentResult();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_alive && !_resultShown) _edgeShowResult();
    final until = _nextBeat.difference(DateTime.now()).inMilliseconds;
    final inWindow = until.abs() <= _hitWindowMs;

    return ArcadeScreen(
      title: 'MAKARAYIZ',
      score: _score,
      best: _best,
      hint: _hint,
      onRestart: _restart,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -200) {
            _tryHit(_Lane.left);
          } else if (v > 200) {
            _tryHit(_Lane.right);
          } else {
            _tryHit(_Lane.mid);
          }
        },
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
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return Row(
                    children: [
                      for (final lane in _Lane.values)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _tryHit(lane),
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(LululuRadii.card),
                                border: Border.all(
                                  color: lane == _target && inWindow
                                      ? LululuColors.toxicNeon
                                      : LululuColors.darkObsidian,
                                  width: lane == _target && inWindow ? 3 : 1,
                                ),
                                color: lane == _player
                                    ? LululuColors.cyberFuchsia
                                        .withValues(alpha: 0.18)
                                    : LululuColors.spaceNavy
                                        .withValues(alpha: 0.5),
                              ),
                              child: Center(
                                child: lane == _target
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          StickerImage(
                                            assetPath: _bug.assetPath,
                                            size: 72,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'MAKARA',
                                            style: GoogleFonts.exo2(
                                              fontWeight: FontWeight.w900,
                                              color: LululuColors.liquidGold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Icon(
                                        Icons.music_note_rounded,
                                        color: LululuColors.mutedTitanium
                                            .withValues(alpha: 0.35),
                                      ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      overlay: (!_alive && !_resultShown)
          ? ArcadeResultOverlay(
              title: 'MAKARA BİTTİ',
              message: _hint,
              score: _score,
              best: _best,
              won: false,
              modeTitle: 'Makarayız',
              shareLine: 'Makarayız abi!',
              retryLabel: 'YENİDEN',
              onRetry: _restart,
            )
          : null,
    );
  }
}
