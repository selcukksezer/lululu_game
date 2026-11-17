import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../screens/result_screen.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';
import '../widgets/mode_bonus_bar.dart';

/// Moving slab. Tap drops it. Overlap is kept, the overhang is cut off.
/// Perfect center keeps full width + combo heat.
class StackDropScreen extends StatefulWidget {
  const StackDropScreen({
    super.key,
    @visibleForTesting this.prototypeVisualState = false,
  });

  @visibleForTesting
  final bool prototypeVisualState;

  @override
  State<StackDropScreen> createState() => _StackDropScreenState();
}

class _Slab {
  _Slab({
    required this.center,
    required this.width,
    required this.tier,
    required this.floor,
    this.perfect = false,
  });

  double center;
  double width;
  final int tier;
  final int floor;
  final bool perfect;
}

class _CutPiece {
  _CutPiece({
    required this.center,
    required this.width,
    required this.y,
    required this.vy,
    required this.rot,
    required this.vRot,
    required this.tier,
    required this.life,
  });

  double center;
  final double width;
  double y;
  double vy;
  double rot;
  final double vRot;
  final int tier;
  double life;
}

enum _Phase { ready, falling, failed }

class _StackDropScreenState extends State<StackDropScreen>
    with SingleTickerProviderStateMixin {
  static const double slabH = 36;
  static const double _stageHintHeight = 0;
  static const double perfectPx = 7;
  static const double nearPx = 16;
  static const _slabColors = <Color>[
    Color(0xFFFFE9C9),
    Color(0xFFFFE3D6),
    Color(0xFFE4F0FF),
    Color(0xFFF3E4FF),
    Color(0xFFFFE0EC),
    Color(0xFFDFF7EA),
    Color(0xFFFFF0D6),
  ];
  final _rng = Random();
  final List<_Slab> _stack = [];
  final List<_CutPiece> _cutPieces = [];
  String? _activePowerFx;
  double _powerFxLife = 0;

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
  double _elapsedSeconds = 0;
  String _hint = 'Dokun. Tam ortala = combo. Kenar kesilir.';
  String? _feedback;
  String? _milestone;
  Timer? _milestoneTimer;
  Timer? _feedbackTimer;
  final Set<int> _milestonesHit = {};
  double _shake = 0;
  double _perfectBounce = 1.0;
  double _cameraY = 0;

  Ticker? _ticker;
  Duration _last = Duration.zero;

  DateTime? _freezeUntil;
  DateTime? _perfectSlowUntil;

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _ensureDefaultPowers();
    if (widget.prototypeVisualState) {
      final pm = ProgressManager();
      pm.extraPowers['freeze'] = 2;
      pm.extraPowers['widen'] = 3;
      pm.extraPowers['slows'] = 1;
      _score = 980;
      _best = 1540;
      _floors = 12;
      _combo = 3;
      _feedback = 'MÜKEMMEL İSABET! X3';
    }
    _loadBest();
    _ticker = createTicker(_tick)..start();
  }

  void _ensureDefaultPowers() {
    final pm = ProgressManager();
    if (pm.powerCount('freeze') == 0 &&
        pm.powerCount('widen') == 0 &&
        pm.powerCount('slows') == 0) {
      pm.extraPowers['freeze'] = 2;
      pm.extraPowers['widen'] = 3;
      pm.extraPowers['slows'] = 1;
    }
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _ticker?.dispose();
    _milestoneTimer?.cancel();
    _feedbackTimer?.cancel();
    if (_score > 0) unawaited(_persist());
    super.dispose();
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best = widget.prototypeVisualState
          ? max(_best, 1540)
          : LeaderboardService.instance.getBest(LeaderboardService.modeStack);
    });
  }

  Future<void> _persist() async {
    if (_score <= 0) return;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeStack,
      _score,
    );
    final best = LeaderboardService.instance.getBest(
      LeaderboardService.modeStack,
    );
    if (mounted && best > _best) setState(() => _best = best);
  }

  void _boot() {
    _stack.clear();
    _cutPieces.clear();
    _activePowerFx = null;
    _powerFxLife = 0;
    const widths = [150.0, 168.0, 182.0, 182.0, 196.0, 210.0, 210.0];
    const tiers = [4, 7, 6, 5, 4, 3, 2];
    final scaleW = (_arenaW / 398.0).clamp(0.75, 1.15);
    _stack.addAll(
      List.generate(
        widths.length,
        (index) => _Slab(
          center: _arenaW / 2,
          width: widths[index] * scaleW,
          tier: tiers[index],
          floor: index + 6,
          perfect: index == widths.length - 1,
        ),
      ),
    );
    _moverW = 150.0 * scaleW;
    _moverX = _arenaW / 2;
    _dir = 1;
    _speed = 150;
    _fallY = 16;
    _sway = 0;
    _tier = 4;
    _score = 0;
    _combo = 0;
    _maxCombo = 0;
    _floors = 12;
    _perfects = 0;
    _nears = 0;
    _comboMeter = 0;
    _elapsedSeconds = 0;
    _feedback = null;
    _feedbackTimer?.cancel();
    _perfectSlowUntil = null;
    _paused = false;
    _milestonesHit.clear();
    _milestone = null;
    _shake = 0;
    _perfectBounce = 1.0;
    _cameraY = 0;
    _resultShown = false;
    _phase = _Phase.ready;
    _hint = 'Dokun. Tam ortala = combo. Kenar kesilir.';
  }

  void _ensure(double w, double h) {
    if (_laidOut || w <= 0 || h <= 0) return;
    _arenaW = w;
    _arenaH = h;
    _boot();
    if (widget.prototypeVisualState) _applyPrototypeVisualState();
    _laidOut = true;
  }

  void _applyPrototypeVisualState() {
    const widths = [150.0, 168.0, 182.0, 182.0, 196.0, 210.0, 210.0];
    const tiers = [4, 7, 6, 5, 4, 3, 2];
    _stack
      ..clear()
      ..addAll(
        List.generate(
          widths.length,
          (index) => _Slab(
            center: _arenaW / 2,
            width: widths[index],
            tier: tiers[index],
            floor: index + 6,
            perfect: index == widths.length - 1,
          ),
        ),
      );
    _moverW = 150;
    _moverX = _arenaW / 2 - 2.1;
    _tier = 4;
    _speed = 150;
    _score = 980;
    _best = max(_best, 1540);
    _combo = 3;
    _maxCombo = 3;
    _floors = 12;
    _perfects = 3;
    _comboMeter = 0.62;
    _elapsedSeconds = 20;
    _feedback = 'MÜKEMMEL İSABET! X3';
  }

  void _restart() {
    setState(() {
      _boot();
      _laidOut = true;
    });
  }

  void _tick(Duration elapsed) {
    if (widget.prototypeVisualState) return;
    final frozen =
        _freezeUntil != null && DateTime.now().isBefore(_freezeUntil!);
    if (frozen) {
      setState(() {});
      return;
    }
    if (!mounted || !_laidOut) {
      _last = elapsed;
      return;
    }
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;

    if (_shake > 0) {
      _shake = max(0, _shake - dt * 4.5);
    }
    if (_perfectBounce > 1.0) {
      _perfectBounce = max(1.0, _perfectBounce - dt * 1.8);
    }
    if (_cutPieces.isNotEmpty) {
      for (final cp in _cutPieces) {
        cp.vy += 580 * dt;
        cp.y += cp.vy * dt;
        cp.rot += cp.vRot * dt;
        cp.life -= dt * 1.35;
      }
      _cutPieces.removeWhere((cp) => cp.life <= 0);
    }
    if (_powerFxLife > 0) {
      _powerFxLife = max(0, _powerFxLife - dt * 1.4);
      if (_powerFxLife <= 0) _activePowerFx = null;
    }
    // Keep top of tower near landY; older floors scroll down.
    final targetCam = -max(0.0, (_stack.length - 7) * (slabH + 4) * 0.55);
    _cameraY += (targetCam - _cameraY) * min(1.0, dt * 6);

    if (_paused || _phase == _Phase.failed) {
      if (_shake > 0) setState(() {});
      return;
    }

    _elapsedSeconds += dt;
    _sway += dt * 2.4;
    _comboMeter = max(0, _comboMeter - dt * 0.12);

    if (_phase == _Phase.ready) {
      final tutorialProgress = (_elapsedSeconds / 15).clamp(0.0, 1.0);
      final tutorialSpeed = 0.52 + tutorialProgress * 0.48;
      final perfectSlow =
          _perfectSlowUntil != null &&
          DateTime.now().isBefore(_perfectSlowUntil!);
      if (!perfectSlow) _perfectSlowUntil = null;
      final pulse = 1.0 + 0.08 * sin(_sway * 1.7);
      _moverX +=
          _dir *
          _speed *
          tutorialSpeed *
          (perfectSlow ? 0.48 : 1.0) *
          pulse *
          dt;
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
      _fallY += 920 * dt;
      if (_fallY >= _landY) {
        _settle();
      } else {
        setState(() {});
      }
    }
  }

  double get _baseY => max(0, _arenaH - _stageHintHeight - 12 - slabH);

  double get _currentLandY =>
      _baseY - (_stack.length - 1) * (slabH + 4) - _cameraY;

  double get _landY => _currentLandY;

  void _drop() {
    if (!_laidOut || _paused) return;
    if (_phase == _Phase.failed) {
      _restart();
      return;
    }
    if (_phase != _Phase.ready) return;

    _phase = _Phase.falling;
    _fallY = 16;
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
    final placedTier = _tier;
    if (width < 14) {
      _fail('Dilim çok inceldi.');
      return;
    }

    if (!perfect) {
      final cutW = (_moverW - overlap).clamp(0.0, _moverW);
      if (cutW >= 4) {
        final cutLeftSide = left < topLeft;
        final cutCenter = cutLeftSide
            ? (left + overlapL) / 2
            : (overlapR + right) / 2;
        _cutPieces.add(
          _CutPiece(
            center: cutCenter,
            width: cutW,
            y: _landY,
            vy: 35,
            rot: 0,
            vRot: cutLeftSide ? -2.6 : 2.6,
            tier: placedTier,
            life: 1.0,
          ),
        );
      }
    }

    _moverW = width;
    _floors++;

    if (perfect) {
      _combo++;
      _perfects++;
      _perfectBounce = 1.14;
      if (_combo > _maxCombo) _maxCombo = _combo;
      _comboMeter = min(1.0, 0.4 + _combo * 0.12);
      _perfectSlowUntil = DateTime.now().add(const Duration(milliseconds: 720));
      final heat = 1.0 + min(1.0, (_combo - 1) * 0.15);
      final gain = ((28 + _combo * 8 + _floors) * heat).round();
      _score += gain;
      _hint = 'TAM İSABET x$_combo · +$gain';
      _showFeedback('MÜKEMMEL İSABET! X$_combo');
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
      _showFeedback('YAKIN! +$gain');
      AudioManager().playMerge(tierNumber: _tier);
      HapticFeedback.lightImpact();
    } else {
      _combo = 0;
      _comboMeter = max(0, _comboMeter - 0.25);
      final gain = 10 + _floors;
      _score += gain;
      _hint = 'Kenar kesildi. +$gain · kat $_floors';
      _showFeedback('KENAR KESİLDİ · +$gain');
      AudioManager().playMerge(tierNumber: _tier);
      HapticFeedback.selectionClick();
    }

    if (_score > _best) _best = _score;
    _checkFloorMilestones();
    final floor = _floors + 1;
    _tier = 1 + _rng.nextInt(5);
    _speed = min(360.0, _speed + 8 + (_floors > 10 ? 2 : 0));
    _phase = _Phase.ready;
    _moverX = _moverX.clamp(_moverW / 2, _arenaW - _moverW / 2);
    _stack.add(
      _Slab(
        center: center,
        width: width,
        tier: placedTier,
        floor: floor,
        perfect: perfect,
      ),
    );
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

  void _showFeedback(String text) {
    _feedbackTimer?.cancel();
    setState(() => _feedback = text);
    _feedbackTimer = Timer(const Duration(milliseconds: 1150), () {
      if (mounted) setState(() => _feedback = null);
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
  bool _useFreeze() {
    if (_phase == _Phase.failed) return false;
    HapticFeedback.mediumImpact();
    AudioManager().playMerge(tierNumber: _tier);
    setState(() {
      if (_stack.isNotEmpty) {
        _moverX = _stack.last.center;
      }
      _freezeUntil = DateTime.now().add(const Duration(seconds: 4));
      _activePowerFx = 'freeze';
      _powerFxLife = 1.0;
      _hint = 'Mıknatıs Hizalama & Dondur (4 sn) aktif!';
    });
    _showMilestone('MIKNATIS HİZALAMA & DONDUR!');
    return true;
  }

  bool _useWiden() {
    if (_phase == _Phase.failed || _arenaW <= 0) return false;
    HapticFeedback.mediumImpact();
    AudioManager().playMerge(tierNumber: _tier);
    setState(() {
      _moverW = min(_arenaW * 0.86, _moverW + 40);
      _moverX = _moverX.clamp(_moverW / 2, _arenaW - _moverW / 2);
      if (_stack.isNotEmpty) {
        _stack.last.width = max(_stack.last.width, _moverW);
      }
      _activePowerFx = 'widen';
      _powerFxLife = 1.0;
      _hint = 'Geniş Blok aktif · Kule tabanı genişledi!';
    });
    _showMilestone('GENİŞ BLOK AKTİF!');
    return true;
  }

  bool _useSlowDrop() {
    if (_phase == _Phase.failed) return false;
    HapticFeedback.mediumImpact();
    AudioManager().playMerge(tierNumber: _tier);
    setState(() {
      _speed = max(70, _speed * 0.62);
      _perfectSlowUntil = DateTime.now().add(const Duration(seconds: 8));
      _activePowerFx = 'slows';
      _powerFxLife = 1.0;
      _hint = 'Yavaşlatıcı aktif (8 sn)!';
    });
    _showMilestone('YAVAŞLATICI AKTİF (8 SN)!');
    return true;
  }

  Future<void> _presentResult() async {
    final coins = _score > 0 ? max(1, ResultScoring.coinsFor(_score)) : 0;
    final stars = ResultScoring.starsFor(score: _score, best: _best);
    if (coins > 0) {
      await ProgressManager.instance.addCoins(coins);
    }
    if (_score > 0) {
      await LeaderboardService.instance.submitScore(
        LeaderboardService.modeStack,
        _score,
      );
    }
    await ProgressManager.instance.recordTaskProgress('play');
    if (!mounted) return;
    final replay = await showGameResult(
      context,
      score: _score,
      coins: coins,
      stars: stars,
    );
    if (!mounted) return;
    if (!replay) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    _resultShown = false;
    _restart();
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
      backgroundAsset: 'assets/design/backgrounds/stack_nightcity.webp',
      title: 'Stack Drop',
      hint: _paused
          ? 'DURAKLATILDI'
          : _elapsedSeconds < 15 && !widget.prototypeVisualState
          ? 'İlk 15 saniye öğretici tempoda. $_hint'
          : _hint,
      score: _score,
      best: _best,
      tag: 'KULE',
      tagColor: const Color(0xFFE52E2E),
      prototypeChrome: true,
      showStatusBar: true,
      prototypeModeChrome: true,
      statLabel: 'KAT',
      statValue: '$_floors',
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
          Center(
            child: SizedBox(
              width: 260,
              child: _StackBonusDock(
                items: [
                  stockBonus(
                    id: 'freeze',
                    label: 'DONDUR',
                    asset: 'assets/icons2/crystal.png',
                    effect: () {
                      _useFreeze();
                      setState(() {});
                    },
                  ),
                  stockBonus(
                    id: 'widen',
                    label: 'GENİŞLET',
                    asset: 'assets/icons2/block.png',
                    effect: () {
                      _useWiden();
                      setState(() {});
                    },
                  ),
                  stockBonus(
                    id: 'slows',
                    label: 'YAVAŞLAT',
                    asset: 'assets/icons2/clock.png',
                    effect: () {
                      _useSlowDrop();
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _ensure(constraints.maxWidth, constraints.maxHeight);
          final top = _stack.isEmpty ? null : _stack.last;
          final comboMessage =
              _feedback ?? (_combo > 0 ? 'KOMBO X$_combo' : null);
          final shakeX = _shake > 0 ? sin(_sway * 40) * 10 * _shake : 0.0;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _drop,
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(shakeX, 0),
                child: Stack(
                  children: [
                    // Near + perfect zone guides.
                    if (top != null && _phase == _Phase.ready && !_paused)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 84,
                        height: 2,
                        child: CustomPaint(
                          painter: _DashedLinePainter(
                            Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    for (var i = 0; i < _stack.length; i++)
                      _slabWidget(
                        _stack[i],
                        _baseY -
                            i * (slabH + 4) -
                            _cameraY +
                            sin(_sway + i * 0.35) * (i == 0 ? 0 : 1.2),
                        bounce: i == _stack.length - 1 ? _perfectBounce : 1.0,
                      ),
                    for (final cp in _cutPieces)
                      Positioned(
                        left: cp.center - cp.width / 2,
                        top: cp.y - _cameraY,
                        width: cp.width,
                        height: slabH,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: cp.life.clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: cp.rot,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _slabColors[
                                      (cp.tier - 1).clamp(
                                        0,
                                        _slabColors.length - 1,
                                      )],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE52E2E),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_activePowerFx != null && _powerFxLife > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Opacity(
                              opacity: _powerFxLife.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 1.4 - 0.4 * _powerFxLife,
                                child: Container(
                                  width: 148,
                                  height: 148,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _activePowerFx == 'freeze'
                                          ? const Color(0xFF00E5FF)
                                          : _activePowerFx == 'widen'
                                          ? const Color(0xFFFFD700)
                                          : const Color(0xFF12B76A),
                                      width: 5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_activePowerFx == 'freeze'
                                                ? const Color(0xFF00E5FF)
                                                : _activePowerFx == 'widen'
                                                ? const Color(0xFFFFD700)
                                                : const Color(0xFF12B76A))
                                            .withValues(alpha: 0.55),
                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_phase != _Phase.failed)
                      _movingSlab(
                        (_phase == _Phase.falling ? _fallY : 16) - _cameraY,
                      ),
                    if (comboMessage != null)
                      Positioned(
                        top: 96,
                        left: 12,
                        right: 12,
                        child: IgnorePointer(
                          child: Center(
                            child: Text(
                              comboMessage,
                              style: GoogleFonts.bangers(
                                fontSize: 26,
                                height: 1,
                                letterSpacing: 0.78,
                                color: const Color(0xFFFFB800),
                                shadows: const [
                                  Shadow(
                                    color: Color(0xEB080B12),
                                    offset: Offset(0, 3),
                                  ),
                                  Shadow(
                                    color: Color(0xE6FF6B35),
                                    blurRadius: 14,
                                  ),
                                  Shadow(
                                    color: Color(0x8CFF6B35),
                                    blurRadius: 32,
                                  ),
                                ],
                              ),
                            ),
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

  Widget _movingSlab(double top) {
    final insect = InsectTier.values[(_tier - 1).clamp(0, 7)];
    return Positioned(
      left: _moverX - _moverW / 2,
      top: top,
      width: _moverW,
      height: 40,
      child: _slabBox(
        insect,
        tier: _tier,
        moving: true,
        perfect: false,
        borderOverride: null,
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
        child: _slabBox(
          insect,
          tier: slab.tier,
          moving: false,
          perfect: slab.perfect,
          floor: slab.floor,
        ),
      ),
    );
  }

  Widget _slabBox(
    InsectTier insect, {
    required int tier,
    required bool moving,
    required bool perfect,
    int? floor,
    Color? borderOverride,
  }) {
    final fill = _slabColors[(tier - 1).clamp(0, _slabColors.length - 1)];
    final prototype = widget.prototypeVisualState;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(moving ? 11 : 9),
        border: perfect
            ? Border.all(
                color: const Color(0xFF00C853),
                width: 2.5,
              )
            : borderOverride == null
            ? null
            : Border.all(
                color: borderOverride,
                width: moving && prototype ? 2.5 : 2,
              ),
        boxShadow: moving
            ? [
                const BoxShadow(
                  color: Color(0x59000000),
                  offset: Offset(0, 6),
                  blurRadius: 14,
                ),
              ]
            : [
                if (perfect)
                  const BoxShadow(
                    color: Color(0xB300C853),
                    blurRadius: 14,
                  ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(moving ? 11 : 9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: moving ? 36 : 31,
                      child: Image.asset(
                        'assets/bugs/tier${tier.clamp(1, 13)}_hd.webp',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            StickerImage(assetPath: insect.assetPath),
                      ),
                    ),
                    if (!moving && floor != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'KAT $floor',
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xA6141B2A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 4,
              child: ColoredBox(color: Color(0x29000000)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackBonusDock extends StatelessWidget {
  const _StackBonusDock({required this.items});

  final List<ModeBonus> items;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: 20),
            _StackBonusButton(item: items[index]),
          ],
        ],
      ),
    ),
  );
}

class _StackBonusButton extends StatelessWidget {
  const _StackBonusButton({required this.item});

  final ModeBonus item;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: item.onTap != null,
    label: '${item.label}. ${item.count} adet',
    child: GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: item.count > 0 ? 1 : 0.55,
        child: SizedBox(
          width: 66,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF333F58), Color(0xFF1B2336)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x73000000),
                              offset: Offset(0, 3),
                            ),
                            BoxShadow(
                              color: Color(0x4D000000),
                              offset: Offset(0, 6),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          item.asset,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: 7,
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE01E5A),
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0xFF080B12), width: 2),
                          ),
                        ),
                        child: Text(
                          '${item.count}',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 9,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.18,
                    color: const Color(0xFFD8E0EE),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 5, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
