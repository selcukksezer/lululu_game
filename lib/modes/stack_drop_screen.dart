import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/leaderboard_service.dart';
import '../screens/result_screen.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';

/// Moving slab. Tap drops it. Overlap is kept, the overhang is cut off.
/// Perfect center keeps full width + combo heat.
class StackDropScreen extends StatefulWidget {
  const StackDropScreen({super.key});

  @override
  State<StackDropScreen> createState() => _StackDropScreenState();
}

class _Slab {
  _Slab({
    required this.center,
    required this.width,
    required this.tier,
    this.perfect = false,
  });

  double center;
  double width;
  final int tier;
  final bool perfect;
}

enum _Phase { ready, falling, failed }

class _StackDropScreenState extends State<StackDropScreen>
    with SingleTickerProviderStateMixin {
  static const double slabH = 34;
  static const double perfectPx = 7;
  static const double nearPx = 16;
  final _rng = Random();
  final List<_Slab> _stack = [];

  _Phase _phase = _Phase.ready;
  bool _resultShown = false;
  bool _laidOut = false;
  bool _paused = false;
  double _arenaW = 320;
  double _arenaH = 480;
  double _moverX = 160;
  double _moverW = 140;
  double _dir = 1;
  double _speed = 160;
  double _fallY = 16;
  double _sway = 0;
  int _tier = 1;
  int _score = 0;
  int _best = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _floors = 0;
  int _perfects = 0;
  int _nears = 0;
  double _comboMeter = 0;
  String _hint = 'Dokun. Tam ortala = combo. Kenar kesilir.';
  String? _milestone;
  Timer? _milestoneTimer;
  final Set<int> _milestonesHit = {};
  double _shake = 0;
  double _perfectBounce = 1.0;
  double _cameraY = 0;

  Ticker? _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _loadBest();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _ticker?.dispose();
    _milestoneTimer?.cancel();
    if (_score > 0) unawaited(_persist());
    super.dispose();
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best = LeaderboardService.instance.getBest(LeaderboardService.modeStack);
    });
  }

  Future<void> _persist() async {
    if (_score <= 0) return;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance
        .submitScore(LeaderboardService.modeStack, _score);
    final best =
        LeaderboardService.instance.getBest(LeaderboardService.modeStack);
    if (mounted && best > _best) setState(() => _best = best);
  }

  void _boot() {
    _stack.clear();
    final baseW = _arenaW * 0.46;
    _stack.add(_Slab(center: _arenaW / 2, width: baseW, tier: 1));
    _moverW = baseW;
    _moverX = _arenaW / 2;
    _dir = 1;
    _speed = 150;
    _fallY = 18;
    _sway = 0;
    _tier = 1 + _rng.nextInt(4);
    _score = 0;
    _combo = 0;
    _maxCombo = 0;
    _floors = 0;
    _perfects = 0;
    _nears = 0;
    _comboMeter = 0;
    _paused = false;
    _milestonesHit.clear();
    _milestone = null;
    _shake = 0;
    _perfectBounce = 1.0;
    _cameraY = 0;
    _phase = _Phase.ready;
    _hint = 'Dokun. Tam ortala = combo. Kenar kesilir.';
  }

  void _ensure(double w, double h) {
    if (_laidOut || w <= 0 || h <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _laidOut) return;
      setState(() {
        _arenaW = w;
        _arenaH = h;
        _boot();
        _laidOut = true;
      });
    });
  }

  void _restart() {
    setState(() {
      _boot();
      _laidOut = true;
    });
  }

  void _tick(Duration elapsed) {
    if (!mounted || !_laidOut) {
      _last = elapsed;
      return;
    }
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.05) return;

    if (_shake > 0) {
      _shake = max(0, _shake - dt * 4.5);
    }
    if (_perfectBounce > 1.0) {
      _perfectBounce = max(1.0, _perfectBounce - dt * 1.8);
    }
    // Keep top of tower near landY; older floors scroll down.
    final targetCam = max(0.0, (_stack.length - 8) * (slabH + 4) * 0.55);
    _cameraY += (targetCam - _cameraY) * min(1.0, dt * 6);

    if (_paused || _phase == _Phase.failed) {
      if (_shake > 0) setState(() {});
      return;
    }

    _sway += dt * 2.4;
    _comboMeter = max(0, _comboMeter - dt * 0.12);

    if (_phase == _Phase.ready) {
      // Soft speed pulse every few seconds — harder to time.
      final pulse = 1.0 + 0.08 * sin(_sway * 1.7);
      _moverX += _dir * _speed * pulse * dt;
      final half = _moverW / 2;
      if (_moverX + half > _arenaW) {
        _moverX = _arenaW - half;
        _dir = -1;
      } else if (_moverX - half < 0) {
        _moverX = half;
        _dir = 1;
      }
      setState(() {});
    } else if (_phase == _Phase.falling) {
      _fallY += 820 * dt;
      if (_fallY >= _landY) {
        _settle();
      } else {
        setState(() {});
      }
    }
  }

  double get _landY => 64;

  void _drop() {
    if (!_laidOut || _paused) return;
    if (_phase == _Phase.failed) {
      _restart();
      return;
    }
    if (_phase != _Phase.ready) return;

    _phase = _Phase.falling;
    _fallY = 18;
    AudioManager().playDrop();
    AudioManager().triggerHaptic();
    setState(() {});
  }

  void _settle() {
    final top = _stack.last;
    final left = _moverX - _moverW / 2;
    final right = _moverX + _moverW / 2;
    final topLeft = top.center - top.width / 2;
    final topRight = top.center + top.width / 2;
    final overlapL = max(left, topLeft);
    final overlapR = min(right, topRight);
    final overlap = overlapR - overlapL;
    final offset = (_moverX - top.center).abs();

    if (overlap <= 2) {
      _fail('Kaçırdın. Kule yıkıldı.');
      return;
    }

    final perfect = offset <= perfectPx;
    final near = !perfect && offset <= nearPx;
    final width = perfect ? top.width : overlap;
    final center = perfect ? top.center : (overlapL + overlapR) / 2;
    if (width < 14) {
      _fail('Dilim çok inceldi.');
      return;
    }

    _stack.add(
      _Slab(center: center, width: width, tier: _tier, perfect: perfect),
    );
    _moverW = width;
    _floors++;

    if (perfect) {
      _combo++;
      _perfects++;
      _perfectBounce = 1.14;
      if (_combo > _maxCombo) _maxCombo = _combo;
      _comboMeter = min(1.0, 0.4 + _combo * 0.12);
      final heat = 1.0 + min(1.0, (_combo - 1) * 0.15);
      final gain = ((28 + _combo * 8 + _floors) * heat).round();
      _score += gain;
      _hint = 'TAM İSABET x$_combo · +$gain';
      AudioManager().playMerge(tierNumber: _tier, comboCount: _combo);
      HapticFeedback.mediumImpact();
      if (_combo == 3 || _combo == 5 || _combo == 8) {
        _showMilestone('COMBO x$_combo');
      }
    } else if (near) {
      _nears++;
      _combo = max(0, _combo - 1);
      _comboMeter = min(1.0, 0.25 + _combo * 0.08);
      final gain = 16 + _floors + _combo * 2;
      _score += gain;
      _hint = 'Neredeyse · +$gain · kat $_floors';
      AudioManager().playMerge(tierNumber: _tier);
      HapticFeedback.lightImpact();
    } else {
      _combo = 0;
      _comboMeter = max(0, _comboMeter - 0.25);
      final gain = 10 + _floors;
      _score += gain;
      _hint = 'Kenar kesildi. +$gain · kat $_floors';
      AudioManager().playMerge(tierNumber: _tier);
      HapticFeedback.selectionClick();
    }

    if (_score > _best) _best = _score;
    _checkFloorMilestones();
    _tier = 1 + _rng.nextInt(5);
    _speed = min(360.0, _speed + 8 + (_floors > 10 ? 2 : 0));
    _phase = _Phase.ready;
    _moverX = _moverX.clamp(_moverW / 2, _arenaW - _moverW / 2);
    setState(() {});
  }

  void _fail(String why) {
    _phase = _Phase.failed;
    _hint = why;
    _paused = false;
    _shake = 1.0;
    HapticFeedback.heavyImpact();
    AudioManager().playLose();
    unawaited(_persist());
    setState(() {});
  }

  void _togglePause() {
    if (_phase == _Phase.failed || _phase == _Phase.falling) return;
    setState(() => _paused = !_paused);
  }

  void _showMilestone(String text) {
    _milestoneTimer?.cancel();
    setState(() => _milestone = text);
    _milestoneTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _milestone = null);
    });
  }

  void _checkFloorMilestones() {
    for (final m in const [5, 10, 15, 20, 30]) {
      if (_floors >= m && !_milestonesHit.contains(m)) {
        _milestonesHit.add(m);
        _showMilestone('$m KAT!');
        break;
      }
    }
  }

  String _statsLine() =>
      'Kat $_floors · Perfect $_perfects · Near $_nears · Max combo x$_maxCombo';

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
    if (_phase == _Phase.failed && !_resultShown) _edgeShowResult();
    return ArcadeScreen(
      title: 'STACK DROP',
      hint: _paused ? 'DURAKLATILDI' : _hint,
      score: _score,
      best: _best,
      statLabel: _combo > 0 ? 'COMBO' : 'KAT',
      statValue: _combo > 0 ? 'x$_combo' : '$_floors',
      onRestart: _restart,
      overlay: (_phase == _Phase.failed && !_resultShown)
          ? ArcadeResultOverlay(
              title: 'KULE DÜŞTÜ',
              message: _statsLine(),
              score: _score,
              best: _best,
              won: false,
              modeTitle: 'Stack Drop',
              shareLine: _statsLine(),
              retryLabel: 'TEKRAR',
              onRetry: _restart,
            )
          : _paused
              ? Positioned.fill(
                  child: ColoredBox(
                    color: LululuColors.carbonVoid.withValues(alpha: 0.72),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DURAKLATILDI',
                            style: GoogleFonts.exo2(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: LululuColors.liquidGold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statsLine(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: LululuColors.mutedTitanium,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ArcadeButton(label: 'DEVAM', onPressed: _togglePause),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _comboMeter,
              minHeight: 5,
              backgroundColor: LululuColors.darkObsidian,
              color: Color.lerp(
                LululuColors.liquidGold,
                LululuColors.toxicNeon,
                _comboMeter,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ArcadeButton(
            label: _paused ? 'DEVAM' : 'DURAKLAT',
            primary: false,
            onPressed: (_phase == _Phase.ready) ? _togglePause : null,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _ensure(constraints.maxWidth, constraints.maxHeight);
          final top = _stack.isEmpty ? null : _stack.last;
          final aimOffset = top == null
              ? 99.0
              : (_moverX - top.center).abs();
          final shakeX = _shake > 0
              ? sin(_sway * 40) * 10 * _shake
              : 0.0;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _drop,
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(shakeX, 0),
                child: Stack(
                  children: [
                    // Near + perfect zone guides.
                    if (top != null && _phase == _Phase.ready && !_paused) ...[
                      Positioned(
                        left: top.center - nearPx,
                        top: _landY - 6 - _cameraY,
                        width: nearPx * 2,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: LululuColors.mutedTitanium
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: top.center - perfectPx,
                        top: _landY - 6 - _cameraY,
                        width: perfectPx * 2,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                LululuColors.toxicNeon.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: LululuColors.toxicNeon
                                    .withValues(alpha: 0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    for (var i = 0; i < _stack.length; i++)
                      _slabWidget(
                        _stack[_stack.length - 1 - i],
                        _landY +
                            i * (slabH + 4) +
                            sin(_sway + i * 0.35) * (i == 0 ? 0 : 1.2) -
                            _cameraY,
                        bounce: i == 0 ? _perfectBounce : 1.0,
                      ),
                    if (_phase != _Phase.failed)
                      _movingSlab(
                        (_phase == _Phase.falling ? _fallY : 16) - _cameraY,
                        aimOffset: aimOffset,
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 8,
                      child: Text(
                        'Dokun = bırak · yeşil = perfect · gri = near',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 11,
                          color: LululuColors.mutedTitanium,
                        ),
                      ),
                    ),
                    if (_milestone != null)
                      Positioned(
                        top: 8,
                        left: 24,
                        right: 24,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LululuGradients.fuchsiaToGold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _milestone!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.exo2(
                                fontWeight: FontWeight.w900,
                                color: LululuColors.carbonVoid,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _movingSlab(double top, {required double aimOffset}) {
    final insect = InsectTier.values[(_tier - 1).clamp(0, 7)];
    final Color border;
    if (aimOffset <= perfectPx) {
      border = LululuColors.toxicNeon;
    } else if (aimOffset <= nearPx) {
      border = LululuColors.liquidGold;
    } else {
      border = LululuColors.mysticRuby.withValues(alpha: 0.85);
    }
    return Positioned(
      left: _moverX - _moverW / 2,
      top: top,
      width: _moverW,
      height: slabH,
      child: _slabBox(
        insect,
        moving: true,
        perfect: false,
        borderOverride: border,
      ),
    );
  }

  Widget _slabWidget(_Slab slab, double top, {double bounce = 1.0}) {
    if (top > _arenaH || top + slabH < -slabH) return const SizedBox.shrink();
    final insect = InsectTier.values[(slab.tier - 1).clamp(0, 7)];
    return Positioned(
      left: slab.center - slab.width / 2,
      top: top,
      width: slab.width,
      height: slabH,
      child: Transform.scale(
        scale: bounce,
        child: _slabBox(insect, moving: false, perfect: slab.perfect),
      ),
    );
  }

  Widget _slabBox(
    InsectTier insect, {
    required bool moving,
    required bool perfect,
    Color? borderOverride,
  }) {
    final border = borderOverride ??
        (moving
            ? LululuColors.liquidGold
            : perfect
                ? LululuColors.toxicNeon
                : insect.color);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LululuColors.spaceNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: border,
          width: moving || perfect || borderOverride != null ? 2.2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.4),
            blurRadius: perfect ? 16 : 12,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: StickerImage(assetPath: insect.assetPath),
      ),
    );
  }
}

