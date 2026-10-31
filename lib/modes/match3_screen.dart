import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/leaderboard_service.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';

/// Swap neighbors. 3+ pop, cascade. 4+ → bomba. Pause / hint.
class Match3Screen extends StatefulWidget {
  const Match3Screen({super.key});

  @override
  State<Match3Screen> createState() => _Match3ScreenState();
}

class _Match3ScreenState extends State<Match3Screen> {
  static const int rows = 7;
  static const int cols = 7;
  /// Softer starter — 4 kinds makes first swaps easier (playtest V2).
  static const int kinds = 4;
  static const int minRun = 3;
  static const int startMoves = 26;
  static const int target = 1400;
  /// Bomb encoding: baseKind + bombBias (6–10).
  static const int bombBias = 5;

  final _rng = Random();
  late List<List<int>> _grid;
  int _score = 0;
  int _best = 0;
  int _moves = startMoves;
  int _epoch = 0;
  bool _busy = false;
  bool _won = false;
  bool _lost = false;
  bool _paused = false;
  bool _swiped = false;
  Point<int>? _selected;
  Point<int>? _dragFrom;
  String _hint = 'Komşuyu kaydır. 3 patlar · 4 = bomba.';

  int _maxChain = 0;
  int _mergeTotal = 0;
  int _bombsMade = 0;
  int _bombsFired = 0;
  double _comboMeter = 0;
  String? _milestone;
  Timer? _milestoneTimer;
  final Set<int> _milestonesHit = {};
  List<Point<int>> _hintCells = [];
  Timer? _hintTimer;
  double _bombPulse = 0;
  Timer? _bombPulseTimer;

  bool get _ended => _won || _lost;

  int _base(int v) {
    if (v <= 0) return 0;
    if (v > kinds) return v - bombBias;
    return v;
  }

  bool _isBomb(int v) => v > kinds && v <= kinds + bombBias;

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _deal();
    _loadBest();
    _bombPulseTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (!mounted || _paused || _ended) return;
      var hasBomb = false;
      for (final row in _grid) {
        for (final v in row) {
          if (_isBomb(v)) {
            hasBomb = true;
            break;
          }
        }
        if (hasBomb) break;
      }
      if (!hasBomb) return;
      setState(() => _bombPulse += 0.22);
    });
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _milestoneTimer?.cancel();
    _hintTimer?.cancel();
    _bombPulseTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best = LeaderboardService.instance.getBest(LeaderboardService.modeMatch3);
    });
  }

  Future<void> _persist() async {
    if (_score <= 0) return;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance
        .submitScore(LeaderboardService.modeMatch3, _score);
    final best =
        LeaderboardService.instance.getBest(LeaderboardService.modeMatch3);
    if (mounted && best > _best) setState(() => _best = best);
  }

  void _newGame() {
    _epoch++;
    _score = 0;
    _moves = startMoves;
    _busy = false;
    _won = false;
    _lost = false;
    _paused = false;
    _swiped = false;
    _selected = null;
    _dragFrom = null;
    _maxChain = 0;
    _mergeTotal = 0;
    _bombsMade = 0;
    _bombsFired = 0;
    _comboMeter = 0;
    _milestonesHit.clear();
    _milestone = null;
    _hintCells = [];
    _hint = 'Komşuyu kaydır. 3 patlar · 4 = bomba.';
    _deal();
    setState(() {});
  }

  void _deal() {
    for (var attempt = 0; attempt < 40; attempt++) {
      _grid = List.generate(rows, (_) => List.filled(cols, 0));
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          _grid[r][c] = _rollAvoiding(r, c);
        }
      }
      _plantEasySwap();
      if (_findMatches().isEmpty && _hasMove()) return;
    }
  }

  /// Guarantees a center-row swap that pops — coarse pans still score.
  void _plantEasySwap() {
    const r = 3;
    const c = 2;
    if (c + 3 >= cols) return;
    final a = 1 + _rng.nextInt(kinds);
    var b = 1 + _rng.nextInt(kinds);
    if (b == a) b = (a % kinds) + 1;
    _grid[r][c] = a;
    _grid[r][c + 1] = a;
    _grid[r][c + 2] = b;
    _grid[r][c + 3] = a;
    // Clearing accidental pre-matches elsewhere is handled by caller retry.
  }

  int _rollAvoiding(int r, int c) {
    for (var i = 0; i < 12; i++) {
      final tier = 1 + _rng.nextInt(kinds);
      final horz = c >= 2 &&
          _base(_grid[r][c - 1]) == tier &&
          _base(_grid[r][c - 2]) == tier;
      final vert = r >= 2 &&
          _base(_grid[r - 1][c]) == tier &&
          _base(_grid[r - 2][c]) == tier;
      if (!horz && !vert) return tier;
    }
    return 1 + _rng.nextInt(kinds);
  }

  void _reshuffle() {
    _deal();
    _hint = 'Hamle kalmadı. Tahta karıştı.';
  }

  bool _adjacent(Point<int> a, Point<int> b) =>
      (a.x - b.x).abs() + (a.y - b.y).abs() == 1;

  void _swap(int r0, int c0, int r1, int c1) {
    final t = _grid[r0][c0];
    _grid[r0][c0] = _grid[r1][c1];
    _grid[r1][c1] = t;
  }

  bool _hasMove() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (c + 1 < cols && _wouldMatch(r, c, r, c + 1)) return true;
        if (r + 1 < rows && _wouldMatch(r, c, r + 1, c)) return true;
      }
    }
    return false;
  }

  bool _wouldMatch(int r0, int c0, int r1, int c1) {
    _swap(r0, c0, r1, c1);
    final ok = _findMatches().isNotEmpty;
    _swap(r0, c0, r1, c1);
    return ok;
  }

  /// Returns a valid swap for hint, or null.
  (Point<int>, Point<int>)? _findHintSwap() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (c + 1 < cols && _wouldMatch(r, c, r, c + 1)) {
          return (Point(r, c), Point(r, c + 1));
        }
        if (r + 1 < rows && _wouldMatch(r, c, r + 1, c)) {
          return (Point(r, c), Point(r + 1, c));
        }
      }
    }
    return null;
  }

  void _showHint() {
    if (_busy || _ended || _paused) return;
    final swap = _findHintSwap();
    if (swap == null) {
      _reshuffle();
      setState(() {});
      return;
    }
    _hintTimer?.cancel();
    setState(() {
      _hintCells = [swap.$1, swap.$2];
      _hint = 'İpucu parlıyor.';
    });
    _hintTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _hintCells = []);
    });
    HapticFeedback.selectionClick();
  }

  Set<Point<int>> _findMatches() {
    final set = <Point<int>>{};
    // Horizontal
    for (var r = 0; r < rows; r++) {
      var run = 1;
      for (var c = 1; c < cols; c++) {
        final same = _grid[r][c] != 0 &&
            _base(_grid[r][c]) == _base(_grid[r][c - 1]);
        if (same) {
          run++;
        } else {
          if (run >= minRun) {
            for (var k = 0; k < run; k++) {
              set.add(Point(r, c - 1 - k));
            }
          }
          run = 1;
        }
      }
      if (run >= minRun) {
        for (var k = 0; k < run; k++) {
          set.add(Point(r, cols - 1 - k));
        }
      }
    }
    // Vertical
    for (var c = 0; c < cols; c++) {
      var run = 1;
      for (var r = 1; r < rows; r++) {
        final same = _grid[r][c] != 0 &&
            _base(_grid[r][c]) == _base(_grid[r - 1][c]);
        if (same) {
          run++;
        } else {
          if (run >= minRun) {
            for (var k = 0; k < run; k++) {
              set.add(Point(r - 1 - k, c));
            }
          }
          run = 1;
        }
      }
      if (run >= minRun) {
        for (var k = 0; k < run; k++) {
          set.add(Point(rows - 1 - k, c));
        }
      }
    }
    return set;
  }

  /// Longest run size covering a point (for bomb spawn).
  int _runLengthAt(Point<int> p) {
    final base = _base(_grid[p.x][p.y]);
    if (base == 0) return 0;
    var h = 1;
    for (var c = p.y - 1; c >= 0 && _base(_grid[p.x][c]) == base; c--) {
      h++;
    }
    for (var c = p.y + 1; c < cols && _base(_grid[p.x][c]) == base; c++) {
      h++;
    }
    var v = 1;
    for (var r = p.x - 1; r >= 0 && _base(_grid[r][p.y]) == base; r--) {
      v++;
    }
    for (var r = p.x + 1; r < rows && _base(_grid[r][p.y]) == base; r++) {
      v++;
    }
    return max(h, v);
  }

  void _expandBombs(Set<Point<int>> matches) {
    final extra = <Point<int>>{};
    for (final p in matches) {
      if (!_isBomb(_grid[p.x][p.y])) continue;
      _bombsFired++;
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          final nr = p.x + dr;
          final nc = p.y + dc;
          if (nr < 0 || nc < 0 || nr >= rows || nc >= cols) continue;
          if (_grid[nr][nc] != 0) extra.add(Point(nr, nc));
        }
      }
    }
    matches.addAll(extra);
  }

  void _onCell(Point<int> cell) {
    if (_busy || _ended || _paused) return;
    final sel = _selected;
    if (sel == null) {
      setState(() => _selected = cell);
      return;
    }
    if (sel == cell) {
      setState(() => _selected = null);
      return;
    }
    if (_adjacent(sel, cell)) {
      final from = sel;
      setState(() => _selected = null);
      unawaited(_resolve(from.x, from.y, cell.x, cell.y));
    } else {
      setState(() => _selected = cell);
    }
  }

  Future<void> _resolve(int r0, int c0, int r1, int c1) async {
    if (_busy || _ended || _paused) return;
    final epoch = _epoch;
    setState(() => _busy = true);
    _swap(r0, c0, r1, c1);
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted || epoch != _epoch) return;

    var matches = _findMatches();
    if (matches.isEmpty) {
      _swap(r0, c0, r1, c1);
      HapticFeedback.selectionClick();
      setState(() {
        _busy = false;
        _hint = 'Eşleşme yok — hamle iptal.';
        _comboMeter = max(0, _comboMeter - 0.2);
      });
      return;
    }

    HapticFeedback.mediumImpact();

    _moves--;
    var chain = 0;
    var voiceTier = 1;
    Point<int>? bombAt;

    while (matches.isNotEmpty) {
      chain++;
      if (chain > _maxChain) _maxChain = chain;
      if (chain > 1) HapticFeedback.lightImpact();
      _expandBombs(matches);

      // First cascade step: spawn bomb from 4+ before clear.
      if (chain == 1) {
        Point<int>? best;
        var bestLen = 0;
        for (final p in matches) {
          final len = _runLengthAt(p);
          if (len >= 4 && len > bestLen) {
            bestLen = len;
            best = p;
          }
        }
        // Prefer the swap destination as bomb seat.
        final seat = Point(r1, c1);
        if (best != null && matches.contains(seat) && _runLengthAt(seat) >= 4) {
          bombAt = seat;
        } else {
          bombAt = best;
        }
      }

      var gained = 0;
      final toClear = matches.toList();
      for (final p in toClear) {
        final raw = _grid[p.x][p.y];
        if (raw == 0) continue;
        final tier = _base(raw);
        if (tier > voiceTier) voiceTier = tier;
        gained += 12 * tier * chain;
        _grid[p.x][p.y] = 0;
      }
      _mergeTotal += toClear.length;
      gained += toClear.length * 8 * chain;
      // Cascade heat
      gained = (gained * (1.0 + min(0.8, (chain - 1) * 0.15))).round();
      _score += gained;
      if (_score > _best) _best = _score;
      _comboMeter = min(1.0, 0.3 + chain * 0.16);
      _checkMilestones();
      _hint = chain > 1 ? 'Zincir x$chain  +$gained' : '+$gained';

      if (bombAt != null && chain == 1) {
        final base = voiceTier.clamp(1, kinds);
        _grid[bombAt.x][bombAt.y] = base + bombBias;
        _bombsMade++;
        _hint = 'BOMBA oluştu!';
        _showMilestone('BOMBA');
        bombAt = null;
      }

      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted || epoch != _epoch) return;
      _collapse();
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 110));
      if (!mounted || epoch != _epoch) return;
      matches = _findMatches();
    }

    AudioManager().playMerge(tierNumber: voiceTier);
    if (!_ended && !_hasMove()) _reshuffle();
    await _endCheck(epoch);
  }

  void _togglePause() {
    if (_ended || _busy) return;
    setState(() => _paused = !_paused);
  }

  void _showMilestone(String text) {
    _milestoneTimer?.cancel();
    setState(() => _milestone = text);
    _milestoneTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _milestone = null);
    });
  }

  void _checkMilestones() {
    for (final m in const [500, 1200, 2000, 3500]) {
      if (_score >= m && !_milestonesHit.contains(m)) {
        _milestonesHit.add(m);
        _showMilestone('SKOR $m!');
        break;
      }
    }
  }

  void _collapse() {
    for (var c = 0; c < cols; c++) {
      var write = rows - 1;
      for (var r = rows - 1; r >= 0; r--) {
        if (_grid[r][c] == 0) continue;
        if (r != write) {
          _grid[write][c] = _grid[r][c];
          _grid[r][c] = 0;
        }
        write--;
      }
      for (var r = write; r >= 0; r--) {
        _grid[r][c] = 1 + _rng.nextInt(kinds);
      }
    }
  }

  Future<void> _endCheck(int epoch) async {
    if (!mounted || epoch != _epoch) return;
    if (_score >= target) {
      _won = true;
      _hint = 'Hedef tuttu.';
      HapticFeedback.heavyImpact();
      AudioManager().playWin();
      await _persist();
    } else if (_moves <= 0) {
      _lost = true;
      _hint = 'Hamle bitti.';
      HapticFeedback.heavyImpact();
      AudioManager().playLose();
      await _persist();
    } else {
      _hint = 'Hedef $target · $_moves hamle';
    }
    if (mounted && epoch == _epoch) setState(() => _busy = false);
  }

  String _statsLine() =>
      'Birleşim $_mergeTotal · Max zincir x$_maxChain · Bomba $_bombsMade/$_bombsFired';

  Point<int>? _cellAt(Offset local, double cell, double gap) {
    final stride = cell + gap;
    final gridW = cell * cols + gap * (cols - 1);
    final gridH = cell * rows + gap * (rows - 1);
    final pad = cell * 0.55;
    if (local.dx < -pad ||
        local.dy < -pad ||
        local.dx > gridW + pad ||
        local.dy > gridH + pad) {
      return null;
    }
    // Nearest cell center — coarse emulator / fat-finger pans still resolve.
    var bestR = 0;
    var bestC = 0;
    var bestD = double.infinity;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cx = c * stride + cell / 2;
        final cy = r * stride + cell / 2;
        final d = (local.dx - cx) * (local.dx - cx) +
            (local.dy - cy) * (local.dy - cy);
        if (d < bestD) {
          bestD = d;
          bestR = r;
          bestC = c;
        }
      }
    }
    final maxD = cell * 1.35;
    if (bestD > maxD * maxD) return null;
    return Point(bestR, bestC);
  }

  @override
  Widget build(BuildContext context) {
    return ArcadeScreen(
      title: 'Match 3',
      hint: _paused ? 'DURAKLATILDI' : _hint,
      score: _score,
      best: _best,
      statLabel: 'HAMLE',
      statValue: '$_moves',
      onRestart: _newGame,
      overlay: _ended
          ? ArcadeResultOverlay(
              title: _won ? 'HEDEF' : 'HAMLE BİTTİ',
              message: _statsLine(),
              score: _score,
              best: _best,
              won: _won,
              modeTitle: 'Match 3',
              shareLine: _statsLine(),
              retryLabel: 'TEKRAR',
              onRetry: _newGame,
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
              value: (_score / target).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: LululuColors.darkObsidian,
              color: _score >= target
                  ? LululuColors.toxicNeon
                  : LululuColors.liquidGold,
            ),
          ),
          const SizedBox(height: 4),
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
              Expanded(
                child: ArcadeButton(
                  label: 'İPUCU',
                  primary: false,
                  onPressed: (_busy || _ended || _paused) ? null : _showHint,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ArcadeButton(
                  label: _paused ? 'DEVAM' : 'DURAKLAT',
                  primary: false,
                  onPressed: _busy ? null : _togglePause,
                ),
              ),
            ],
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          final side = min(constraints.maxWidth - 8, constraints.maxHeight - 4);
          final cell = (side - gap * (cols - 1)) / cols;
          final gridW = cell * cols + gap * (cols - 1);
          return Stack(
            children: [
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _swiped = false,
                  onPanStart: (d) {
                    if (_paused || _busy) return;
                    _dragFrom = _cellAt(d.localPosition, cell, gap);
                    if (_dragFrom != null) {
                      setState(() => _selected = _dragFrom);
                    }
                  },
                  onPanUpdate: (d) {
                    if (_paused || _busy) return;
                    final from = _dragFrom;
                    if (from == null) return;
                    var to = _cellAt(d.localPosition, cell, gap);
                    // Direction fallback when finger stays in same cell.
                    if (to == null || to == from) {
                      final dx = d.delta.dx;
                      final dy = d.delta.dy;
                      if (dx.abs() < 4 && dy.abs() < 4) return;
                      if (dx.abs() >= dy.abs()) {
                        final nc = (from.y + (dx > 0 ? 1 : -1))
                            .clamp(0, cols - 1);
                        to = Point(from.x, nc);
                      } else {
                        final nr = (from.x + (dy > 0 ? 1 : -1))
                            .clamp(0, rows - 1);
                        to = Point(nr, from.y);
                      }
                    }
                    if (!_adjacent(from, to)) return;
                    _dragFrom = null;
                    _swiped = true;
                    unawaited(_resolve(from.x, from.y, to.x, to.y));
                  },
                  onPanEnd: (_) => _dragFrom = null,
                  onTapUp: (d) {
                    if (_swiped || _paused) return;
                    final p = _cellAt(d.localPosition, cell, gap);
                    if (p != null) _onCell(p);
                  },
                  child: SizedBox(
                    width: gridW,
                    height: gridW,
                    child: Stack(
                      children: [
                        for (var r = 0; r < rows; r++)
                          for (var c = 0; c < cols; c++)
                            Positioned(
                              left: c * (cell + gap),
                              top: r * (cell + gap),
                              width: cell,
                              height: cell,
                              child: _tile(r, c),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_milestone != null)
                Positioned(
                  top: 4,
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

  Widget _tile(int r, int c) {
    final raw = _grid[r][c];
    final tier = _base(raw);
    final bomb = _isBomb(raw);
    final selected = _selected == Point(r, c);
    final hinted = _hintCells.contains(Point(r, c));
    final insect = tier == 0 ? null : InsectTier.values[tier - 1];
    final bombGlow = bomb ? (0.55 + 0.35 * sin(_bombPulse)) : 0.0;
    return AnimatedScale(
      scale: selected || hinted
          ? 1.07
          : bomb
              ? 1.0 + 0.04 * sin(_bombPulse)
              : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.elasticOut,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: LululuColors.spaceNavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hinted
                ? LululuColors.toxicNeon
                : selected
                    ? LululuColors.liquidGold
                    : bomb
                        ? LululuColors.cyberFuchsia
                        : LululuColors.darkObsidian,
            width: selected || hinted || bomb ? 2.2 : 1,
          ),
          boxShadow: insect == null
              ? null
              : [
                  BoxShadow(
                    color: (bomb ? LululuColors.cyberFuchsia : insect.color)
                        .withValues(
                      alpha: selected || bomb
                          ? (bomb ? bombGlow.clamp(0.35, 0.9) : 0.55)
                          : 0.28,
                    ),
                    blurRadius: selected || bomb ? 14 + bombGlow * 8 : 8,
                  ),
                ],
        ),
        child: insect == null
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: StickerImage(assetPath: insect.assetPath),
                  ),
                  if (bomb)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Icon(
                        Icons.flash_on_rounded,
                        size: 14,
                        color: LululuColors.liquidGold,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

