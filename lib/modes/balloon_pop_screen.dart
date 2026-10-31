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

/// Puzzle-Bobble: aim, stick to the cluster, pop 3+ of the same bug.
/// Bubbles that lose their link to the ceiling fall.
class BalloonPopScreen extends StatefulWidget {
  const BalloonPopScreen({super.key});

  @override
  State<BalloonPopScreen> createState() => _BalloonPopScreenState();
}

class _BalloonPopScreenState extends State<BalloonPopScreen>
    with SingleTickerProviderStateMixin {
  static const int cols = 7;
  static const int rows = 10;
  static const int kinds = 4;
  static const int fillRows = 5;
  static const int minPop = 3;
  static const int descendEvery = 5;
  static const double shotSpeed = 760;
  final _rng = Random();
  late List<List<int>> _grid;
  int _score = 0;
  int _best = 0;
  int _shots = 0;
  int _current = 1;
  int _next = 2;
  int? _hold;
  bool _flying = false;
  bool _over = false;
  bool _resultShown = false;
  bool _paused = false;
  bool _shotArmed = false;
  Offset? _fly;
  Offset _vel = Offset.zero;
  Offset _aim = const Offset(0, -1);
  String _hint = 'Nişan al, bırak. 3 aynı balon patlar.';

  // Combo / stats
  int _streak = 0;
  int _maxStreak = 0;
  int _popTotal = 0;
  int _fallTotal = 0;
  int _biggestPop = 0;
  double _comboMeter = 0;
  String? _milestone;
  Timer? _milestoneTimer;
  final Set<int> _milestonesHit = {};
  final List<_PopFx> _popFx = [];
  double _dangerPulse = 0;
  bool _missFlash = false;
  Timer? _missTimer;

  Ticker? _ticker;
  Duration _last = Duration.zero;
  _Hex? _hex;

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _boot();
    _loadBest();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _ticker?.dispose();
    _milestoneTimer?.cancel();
    _missTimer?.cancel();
    unawaited(_persist());
    super.dispose();
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best = LeaderboardService.instance.getBest(LeaderboardService.modeBalloon);
    });
  }

  Future<void> _persist() async {
    if (_score <= 0) return;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance
        .submitScore(LeaderboardService.modeBalloon, _score);
  }

  void _boot() {
    _grid = List.generate(rows, (_) => List.filled(cols, 0));
    _score = 0;
    _shots = 0;
    _flying = false;
    _over = false;
    _paused = false;
    _shotArmed = false;
    _fly = null;
    _hold = null;
    _streak = 0;
    _maxStreak = 0;
    _popTotal = 0;
    _fallTotal = 0;
    _biggestPop = 0;
    _comboMeter = 0;
    _milestonesHit.clear();
    _milestone = null;
    _popFx.clear();
    _missFlash = false;
    _dangerPulse = 0;
    _hint = 'Nişan al, bırak. 3 aynı balon patlar.';
    for (var attempt = 0; attempt < 16; attempt++) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          _grid[r][c] = r < fillRows ? 1 + _rng.nextInt(kinds) : 0;
        }
      }
      if (_firstGroup() == null) break;
    }
    _current = _rollColor();
    _next = _rollColor();
  }

  /// Bias toward colors still on the board (classic Puzzle Bobble feel).
  int _rollColor() {
    final counts = List<int>.filled(kinds + 1, 0);
    var any = 0;
    for (final row in _grid) {
      for (final v in row) {
        if (v > 0 && v <= kinds) {
          counts[v]++;
          any++;
        }
      }
    }
    if (any == 0) return 1 + _rng.nextInt(kinds);
    if (_rng.nextDouble() < 0.35) return 1 + _rng.nextInt(kinds);
    final bag = <int>[];
    for (var k = 1; k <= kinds; k++) {
      final n = max(1, counts[k]);
      for (var i = 0; i < n; i++) {
        bag.add(k);
      }
    }
    return bag[_rng.nextInt(bag.length)];
  }

  void _tick(Duration elapsed) {
    if (!mounted) {
      _last = elapsed;
      return;
    }
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.05) return;

    var dirty = false;
    if (!_paused && !_over) {
      _dangerPulse += dt * 5;
      _comboMeter = max(0, _comboMeter - dt * 0.18);
      if (_popFx.isNotEmpty) {
        for (final fx in _popFx) {
          fx.life -= dt * 6;
        }
        _popFx.removeWhere((f) => f.life <= 0);
        dirty = true;
      }
    }
    if (_paused || !_flying || _over || _fly == null || _hex == null) {
      if (dirty) setState(() {});
      return;
    }
    _step(dt);
  }

  void _aimAt(Offset local) {
    final hex = _hex;
    if (hex == null || _flying || _over || _paused) return;
    var dir = local - hex.shooter;
    if (dir.dy > -12) dir = Offset(dir.dx, -12);
    if (dir.distance < 4) return;
    setState(() => _aim = dir / dir.distance);
  }

  void _fire() {
    final hex = _hex;
    if (hex == null || _flying || _over || _paused || _shotArmed) return;
    _shotArmed = true;
    _fly = hex.shooter;
    _vel = _aim * shotSpeed;
    _flying = true;
    AudioManager().playDrop();
    AudioManager().triggerHaptic();
    setState(() {});
  }

  void _swapHold() {
    if (_over || _paused) return;
    setState(() {
      if (_flying) {
        // Shot already in air — operate on the upcoming queue.
        if (_hold == null) {
          _hold = _next;
          _next = _rollColor();
        } else {
          final t = _next;
          _next = _hold!;
          _hold = t;
        }
      } else if (_hold == null) {
        _hold = _current;
        _current = _next;
        _next = _rollColor();
      } else {
        final t = _current;
        _current = _hold!;
        _hold = t;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _togglePause() {
    if (_over) return;
    setState(() => _paused = !_paused);
  }

  void _showMilestone(String text) {
    _milestoneTimer?.cancel();
    setState(() => _milestone = text);
    _milestoneTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _milestone = null);
    });
  }

  void _checkScoreMilestones() {
    for (final m in const [500, 1500, 3000, 6000, 10000]) {
      if (_score >= m && !_milestonesHit.contains(m)) {
        _milestonesHit.add(m);
        _showMilestone('SKOR $m!');
        break;
      }
    }
  }

  void _step(double dt) {
    final hex = _hex!;
    var pos = _fly!;
    var vel = _vel;
    final pad = hex.cell * 0.28;
    var left = dt;
    while (left > 0) {
      final slice = min(left, 0.008);
      pos += vel * slice;
      left -= slice;
      if (pos.dx < pad) {
        pos = Offset(pad, pos.dy);
        vel = Offset(vel.dx.abs(), vel.dy);
      } else if (pos.dx > hex.width - pad) {
        pos = Offset(hex.width - pad, pos.dy);
        vel = Offset(-vel.dx.abs(), vel.dy);
      }
      final hit = _nearOccupied(pos, hex);
      final ceiling = pos.dy <= hex.cell * 0.35;
      if (hit || ceiling) {
        _stick(pos, hex);
        return;
      }
      if (pos.dy > hex.shooter.dy + 8) {
        _flying = false;
        _fly = null;
        _shotArmed = false;
        _streak = 0;
        _flashMiss();
        setState(() => _hint = 'Iskaladın. Tekrar nişan al.');
        return;
      }
    }
    _fly = pos;
    _vel = vel;
    setState(() {});
  }

  bool _nearOccupied(Offset pos, _Hex hex) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] == 0) continue;
        if ((hex.center(r, c) - pos).distance < hex.cell * 0.78) return true;
      }
    }
    return false;
  }

  void _stick(Offset pos, _Hex hex) {
    final spot = _snap(pos, hex);
    _flying = false;
    _fly = null;
    _shotArmed = false;
    if (spot == null) {
      _streak = 0;
      _comboMeter = max(0, _comboMeter - 0.3);
      _hint = 'Tutunamadı. Tekrar nişan al.';
      _flashMiss();
      setState(() {});
      return;
    }
    final (r, c) = spot;
    final shotTier = _current;
    _grid[r][c] = shotTier;
    final popped = _popFrom(r, c);
    final fallen = _dropFloaters();
    var gained = 0;
    if (popped >= minPop) {
      _streak++;
      if (_streak > _maxStreak) _maxStreak = _streak;
      _popTotal += popped;
      if (popped > _biggestPop) _biggestPop = popped;
      final heat = 1.0 + min(1.2, (_streak - 1) * 0.18) + min(0.6, (popped - 3) * 0.12);
      gained += (popped * popped * 14 * shotTier * heat).round();
      _comboMeter = min(1.0, 0.35 + _streak * 0.14 + popped * 0.04);
      if (popped >= 6) _showMilestone('SÜPER PATLAMA · $popped');
    } else {
      _streak = 0;
      _comboMeter = max(0, _comboMeter - 0.2);
    }
    if (fallen > 0) {
      _fallTotal += fallen;
      gained += (fallen * 50 * (1 + _streak * 0.1)).round();
    }
    if (gained > 0) {
      _score += gained;
      if (_score > _best) _best = _score;
      _checkScoreMilestones();
      if (popped >= 6) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
      AudioManager().playMerge(tierNumber: shotTier);
      final insect = InsectTier.values[(shotTier - 1).clamp(0, 7)];
      _hint = fallen > 0
          ? '${insect.viralReplik} +$gained · x$_streak'
          : 'Patladı x$_streak · +$gained';
    } else {
      HapticFeedback.selectionClick();
      _hint = 'Yapıştı. 3 aynı lazım.';
    }
    _current = _next;
    _next = _rollColor();
    _shots++;
    if (_reachedDanger()) {
      _lose('Balonlar nişancıya dayandı.');
      return;
    }
    if (_shots % descendEvery == 0) _descend();
    setState(() {});
  }

  (int, int)? _snap(Offset pos, _Hex hex) {
    var bestD = double.infinity;
    (int, int)? best;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] != 0) continue;
        if (r != 0 && !_touchesOccupied(r, c)) continue;
        final d = (hex.center(r, c) - pos).distance;
        if (d < bestD) {
          bestD = d;
          best = (r, c);
        }
      }
    }
    if (best == null) return null;
    final nearCeiling = pos.dy < hex.cell * 1.15;
    final limit = nearCeiling ? hex.cell * 2.6 : hex.cell * 1.45;
    if (bestD > limit) return null;
    return best;
  }

  bool _touchesOccupied(int r, int c) {
    for (final (nr, nc) in _neighbors(r, c)) {
      if (_grid[nr][nc] != 0) return true;
    }
    return false;
  }

  void _flashMiss() {
    HapticFeedback.heavyImpact();
    _missTimer?.cancel();
    _missFlash = true;
    _missTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _missFlash = false);
    });
  }

  int _popFrom(int r, int c) {
    final tier = _grid[r][c];
    if (tier == 0) return 0;
    final group = _flood(r, c, tier);
    if (group.length < minPop) return 0;
    final hex = _hex;
    for (final (gr, gc) in group) {
      if (hex != null) {
        _popFx.add(
          _PopFx(
            center: hex.center(gr, gc),
            tier: tier,
            life: 1,
          ),
        );
      }
      _grid[gr][gc] = 0;
    }
    return group.length;
  }

  int _dropFloaters() {
    final anchored = <(int, int)>{};
    final queue = <(int, int)>[];
    for (var c = 0; c < cols; c++) {
      if (_grid[0][c] != 0) queue.add((0, c));
    }
    while (queue.isNotEmpty) {
      final (r, c) = queue.removeLast();
      if (!anchored.add((r, c))) continue;
      for (final (nr, nc) in _neighbors(r, c)) {
        if (_grid[nr][nc] != 0 && !anchored.contains((nr, nc))) {
          queue.add((nr, nc));
        }
      }
    }
    var fallen = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] != 0 && !anchored.contains((r, c))) {
          _grid[r][c] = 0;
          fallen++;
        }
      }
    }
    return fallen;
  }

  List<(int, int)>? _firstGroup() {
    final seen = <(int, int)>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] == 0 || seen.contains((r, c))) continue;
        final group = _flood(r, c, _grid[r][c]);
        seen.addAll(group);
        if (group.length >= minPop) return group;
      }
    }
    return null;
  }

  List<(int, int)> _flood(int r, int c, int tier) {
    final out = <(int, int)>[];
    final seen = <(int, int)>{};
    final queue = <(int, int)>[(r, c)];
    while (queue.isNotEmpty) {
      final (cr, cc) = queue.removeLast();
      if (!seen.add((cr, cc))) continue;
      if (_grid[cr][cc] != tier) continue;
      out.add((cr, cc));
      for (final (nr, nc) in _neighbors(cr, cc)) {
        if (_grid[nr][nc] == tier) queue.add((nr, nc));
      }
    }
    return out;
  }

  List<(int, int)> _neighbors(int r, int c) {
    final odd = r.isOdd;
    const evenD = [(0, -1), (0, 1), (-1, -1), (-1, 0), (1, -1), (1, 0)];
    const oddD = [(0, -1), (0, 1), (-1, 0), (-1, 1), (1, 0), (1, 1)];
    final deltas = odd ? oddD : evenD;
    final out = <(int, int)>[];
    for (final (dr, dc) in deltas) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nc < 0 || nr >= rows || nc >= cols) continue;
      out.add((nr, nc));
    }
    return out;
  }

  bool _reachedDanger() {
    for (var c = 0; c < cols; c++) {
      if (_grid[rows - 1][c] != 0 || _grid[rows - 2][c] != 0) return true;
    }
    return false;
  }

  void _descend() {
    for (var c = 0; c < cols; c++) {
      if (_grid[rows - 1][c] != 0) {
        _lose('Tavan indi, yer kalmadı.');
        return;
      }
    }
    for (var r = rows - 1; r > 0; r--) {
      _grid[r] = List<int>.from(_grid[r - 1]);
    }
    _grid[0] = List.generate(cols, (_) => _rollColor());
    final group = _firstGroup();
    if (group != null) {
      final tier = _grid[group.first.$1][group.first.$2];
      for (final (r, c) in group) {
        _grid[r][c] = 0;
      }
      final fallen = _dropFloaters();
      final gained = group.length * group.length * 14 * tier + fallen * 50;
      _score += gained;
      _popTotal += group.length;
      _fallTotal += fallen;
      if (_score > _best) _best = _score;
      AudioManager().playMerge(tierNumber: _current);
      _checkScoreMilestones();
    }
    _hint = 'Tavan bir sıra indi.';
    if (_reachedDanger()) _lose('Balonlar nişancıya dayandı.');
  }

  void _lose(String why) {
    if (_over) return;
    _over = true;
    _flying = false;
    _fly = null;
    _paused = false;
    _hint = why;
    HapticFeedback.heavyImpact();
    AudioManager().playLose();
    unawaited(_persist());
    setState(() {});
  }

  String _statsLine() =>
      'Patlama $_popTotal · Düşen $_fallTotal · Max streak x$_maxStreak · En büyük $_biggestPop';

  List<Offset> _aimDots(_Hex hex) {
    var p = hex.shooter;
    var v = _aim;
    final pad = hex.cell * 0.28;
    final dots = <Offset>[];
    final count = _streak >= 3 ? 22 : 18;
    for (var i = 0; i < count; i++) {
      p += v * (hex.cell * 0.48);
      if (p.dx < pad) {
        p = Offset(pad, p.dy);
        v = Offset(v.dx.abs(), v.dy);
      } else if (p.dx > hex.width - pad) {
        p = Offset(hex.width - pad, p.dy);
        v = Offset(-v.dx.abs(), v.dy);
      }
      if (p.dy < hex.cell * 0.2) break;
      if (_nearOccupied(p, hex)) {
        dots.add(p);
        break;
      }
      dots.add(p);
    }
    return dots;
  }

  /// Oyun sonu: yeni sonuç ekranı. "TEKRAR OYNA" aynı turu başlatır,
  /// "ANA SAYFA"da eski TAŞTI akışı devam eder (bozulmadı).
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
      setState(_boot);
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
    final until = descendEvery - (_shots % descendEvery);
    if (_over && !_resultShown) _edgeShowResult();
    return ArcadeScreen(
      title: 'BALON PATLAT',
      hint: _paused ? 'DURAKLATILDI' : _hint,
      score: _score,
      best: _best,
      statLabel: _streak > 0 ? 'STREAK' : 'TAVAN',
      statValue: _streak > 0 ? 'x$_streak' : '$until',
      onRestart: () => setState(_boot),
      overlay: (_over && !_resultShown)
          ? ArcadeResultOverlay(
              title: 'TAŞTI',
              message: _statsLine(),
              score: _score,
              best: _best,
              won: false,
              modeTitle: 'Balon Patlat',
              shareLine: _statsLine(),
              retryLabel: 'TEKRAR',
              onRetry: () => setState(_boot),
            )
          : _paused
              ? Positioned.fill(
                  child: ColoredBox(
                    color: LululuColors.carbonVoid.withValues(alpha: 0.7),
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
                LululuColors.cyberFuchsia,
                _comboMeter,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniSlot(
                label: 'SIRADAKİ',
                tier: _next,
                onTap: null,
              ),
              const SizedBox(width: 8),
              _MiniSlot(
                label: _hold == null ? 'TUT' : 'DEĞİŞ',
                tier: _hold,
                onTap: _swapHold,
              ),
              const Spacer(),
              IconButton(
                onPressed: _togglePause,
                icon: Icon(
                  _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: LululuColors.liquidGold,
                ),
              ),
            ],
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 360.0;
          final maxH = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 640.0;
          var width = max(maxW - 4, 160.0);
          var hex = _Hex(width);
          if (hex.totalHeight > maxH && maxH > 80) {
            width = width * (maxH / hex.totalHeight);
            hex = _Hex(width);
          }
          _hex = hex;
          final dots = (_flying || _paused) ? const <Offset>[] : _aimDots(hex);
          return Stack(
            children: [
              Center(
                child: SizedBox(
                  width: width,
                  height: hex.totalHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => _shotArmed = false,
                    onPanStart: (d) {
                      _shotArmed = false;
                      _aimAt(d.localPosition);
                    },
                    onPanUpdate: (d) => _aimAt(d.localPosition),
                    onPanEnd: (_) => _fire(),
                    onTapUp: (d) {
                      _aimAt(d.localPosition);
                      _fire();
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Danger line — bottom 2 rows lose zone.
                        Positioned(
                          left: 4,
                          right: 4,
                          top: hex.center(rows - 2, 0).dy - hex.cell * 0.42,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: (0.35 +
                                      0.25 * sin(_dangerPulse) +
                                      (_fillDepth() * 0.4))
                                  .clamp(0.25, 0.95),
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: LululuColors.mysticRuby,
                                  boxShadow: [
                                    BoxShadow(
                                      color: LululuColors.mysticRuby
                                          .withValues(alpha: 0.55),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        for (var i = 0; i < dots.length; i++)
                          Positioned(
                            left: dots[i].dx - (i == dots.length - 1 ? 5 : 3),
                            top: dots[i].dy - (i == dots.length - 1 ? 5 : 3),
                            child: Container(
                              width: i == dots.length - 1 ? 10 : 6,
                              height: i == dots.length - 1 ? 10 : 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: LululuColors.liquidGold.withValues(
                                  alpha: 0.55 + (_comboMeter * 0.4),
                                ),
                                border: i == dots.length - 1
                                    ? Border.all(
                                        color: LululuColors.toxicNeon,
                                        width: 1.5,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        for (var r = 0; r < rows; r++)
                          for (var c = 0; c < cols; c++)
                            if (_grid[r][c] != 0)
                              _bubble(hex.center(r, c), hex.cell, _grid[r][c]),
                        for (final fx in _popFx)
                          Positioned(
                            left: fx.center.dx - hex.cell * 0.35 * fx.life,
                            top: fx.center.dy - hex.cell * 0.35 * fx.life,
                            width: hex.cell * 0.7 * fx.life,
                            height: hex.cell * 0.7 * fx.life,
                            child: Opacity(
                              opacity: fx.life.clamp(0.0, 1.0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: InsectTier
                                      .values[(fx.tier - 1).clamp(0, 7)]
                                      .color
                                      .withValues(alpha: 0.55),
                                  border: Border.all(
                                    color: LululuColors.liquidGold,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_fly != null)
                          _bubble(_fly!, hex.cell, _current),
                        Positioned(
                          left: hex.shooter.dx - hex.cell * 0.42,
                          top: hex.shooter.dy - hex.cell * 0.42,
                          child: _bubbleFace(
                            hex.cell * 0.84,
                            _current,
                            aimed: true,
                            miss: _missFlash,
                          ),
                        ),
                      ],
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
          );
        },
      ),
    );
  }

  Widget _bubble(Offset center, double cell, int tier) {
    final size = cell * 0.86;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: _bubbleFace(size, tier),
    );
  }

  double _fillDepth() {
    var deepest = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] != 0 && r > deepest) deepest = r;
      }
    }
    return (deepest / (rows - 1)).clamp(0.0, 1.0);
  }

  Widget _bubbleFace(
    double size,
    int tier, {
    bool aimed = false,
    bool miss = false,
  }) {
    final insect = InsectTier.values[(tier - 1).clamp(0, 7)];
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: aimed
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: miss ? LululuColors.mysticRuby : LululuColors.liquidGold,
                  width: miss ? 3 : 2,
                ),
                boxShadow: miss
                    ? [
                        BoxShadow(
                          color: LululuColors.mysticRuby.withValues(alpha: 0.7),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              )
            : const BoxDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: StickerImage(assetPath: insect.assetPath),
        ),
      ),
    );
  }
}

class _PopFx {
  _PopFx({required this.center, required this.tier, required this.life});
  final Offset center;
  final int tier;
  double life;
}

class _Hex {
  _Hex(this.width) : cell = width / 7.55;

  final double width;
  final double cell;

  double get boardHeight => cell * (0.55 + 9 * 0.86);

  double get totalHeight => boardHeight + cell * 1.35;

  Offset center(int r, int c) {
    final x = cell * (c + (r.isOdd ? 1.0 : 0.5));
    final y = cell * (0.5 + r * 0.86);
    return Offset(x, y);
  }

  Offset get shooter => Offset(width / 2, boardHeight + cell * 0.55);
}

class _MiniSlot extends StatelessWidget {
  const _MiniSlot({
    required this.label,
    required this.tier,
    required this.onTap,
  });

  final String label;
  final int? tier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LululuColors.spaceNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LululuColors.liquidGold.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(width: 6),
          if (tier != null)
            StickerImage(
              assetPath: InsectTier.values[(tier! - 1).clamp(0, 7)].assetPath,
              size: 28,
            )
          else
            Text(
              'TUT',
              style: GoogleFonts.exo2(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: LululuColors.cyberFuchsia,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}
