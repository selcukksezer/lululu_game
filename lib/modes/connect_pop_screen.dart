import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

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

/// Drag through orthogonal neighbors of the same bug.
/// A loop (back to the start) clears every bug of that kind.
class ConnectPopScreen extends StatefulWidget {
  const ConnectPopScreen({super.key});

  @override
  State<ConnectPopScreen> createState() => _ConnectPopScreenState();
}

class _ConnectPopScreenState extends State<ConnectPopScreen> {
  static const int rows = 7;
  static const int cols = 7;
  /// Softer starter — fewer kinds + seeded cluster (playtest V2).
  static const int kinds = 3;
  static const int minLen = 3;
  static const int startLines = 24;
  static const int target = 1200;

  final _rng = Random();
  late List<List<int>> _grid;
  int _score = 0;
  int _best = 0;
  int _lines = startLines;
  int _epoch = 0;
  bool _busy = false;
  bool _won = false;
  bool _lost = false;
  bool _resultShown = false;
  bool _paused = false;
  bool _loop = false;
  int _paint = 0;
  final List<Point<int>> _path = [];
  final Set<Point<int>> _pathSet = {};
  String _hint = 'Aynı böceği çiz. Kare = o türün hepsi.';

  int _streak = 0;
  int _maxStreak = 0;
  int _clearTotal = 0;
  int _loopCount = 0;
  int _longestPath = 0;
  double _comboMeter = 0;
  String? _milestone;
  Timer? _milestoneTimer;
  final Set<int> _milestonesHit = {};
  Set<Point<int>> _hintCells = {};
  Timer? _hintTimer;
  Set<Point<int>> _flashCells = {};
  Timer? _flashTimer;
  double _gridBurst = 1.0;

  bool get _ended => _won || _lost;

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _fill();
    _loadBest();
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _milestoneTimer?.cancel();
    _hintTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best =
          LeaderboardService.instance.getBest(LeaderboardService.modeConnect);
    });
  }

  Future<void> _persist() async {
    if (_score <= 0) return;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance
        .submitScore(LeaderboardService.modeConnect, _score);
    final best =
        LeaderboardService.instance.getBest(LeaderboardService.modeConnect);
    if (mounted && best > _best) setState(() => _best = best);
  }

  void _newGame() {
    _epoch++;
    _score = 0;
    _lines = startLines;
    _busy = false;
    _won = false;
    _lost = false;
    _paused = false;
    _streak = 0;
    _maxStreak = 0;
    _clearTotal = 0;
    _loopCount = 0;
    _longestPath = 0;
    _comboMeter = 0;
    _milestonesHit.clear();
    _milestone = null;
    _hintCells = {};
    _flashCells = {};
    _gridBurst = 1.0;
    _clearPath();
    _hint = 'Aynı böceği çiz. Kare = o türün hepsi.';
    _fill();
    setState(() {});
  }

  void _fill() {
    for (var attempt = 0; attempt < 24; attempt++) {
      _grid = List.generate(
        rows,
        (_) => List.generate(cols, (_) => 1 + _rng.nextInt(kinds)),
      );
      _plantEasyCluster();
      if (_hasGroup()) return;
    }
  }

  /// Center row of 4 identical bugs — first drag always scores.
  void _plantEasyCluster() {
    const r = 3;
    const c0 = 1;
    final tier = 1 + _rng.nextInt(kinds);
    for (var i = 0; i < 4 && c0 + i < cols; i++) {
      _grid[r][c0 + i] = tier;
    }
  }

  void _clearPath() {
    _path.clear();
    _pathSet.clear();
    _paint = 0;
    _loop = false;
  }

  /// Orthogonal or diagonal neighbor — diagonal helps coarse drag trails.
  bool _ortho(Point<int> a, Point<int> b) {
    final dx = (a.x - b.x).abs();
    final dy = (a.y - b.y).abs();
    return (dx <= 1 && dy <= 1) && (dx + dy) > 0;
  }

  bool _hasGroup() {
    final seen = <Point<int>>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = Point(r, c);
        if (seen.contains(p) || _grid[r][c] == 0) continue;
        final group = _flood(r, c);
        seen.addAll(group);
        if (group.length >= minLen) return true;
      }
    }
    return false;
  }

  List<Point<int>> _flood(int r, int c) {
    final tier = _grid[r][c];
    final out = <Point<int>>[];
    final seen = <Point<int>>{};
    final queue = <Point<int>>[Point(r, c)];
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      if (!seen.add(p)) continue;
      if (_grid[p.x][p.y] != tier) continue;
      out.add(p);
      const d = [
        Point(1, 0),
        Point(-1, 0),
        Point(0, 1),
        Point(0, -1),
        Point(1, 1),
        Point(1, -1),
        Point(-1, 1),
        Point(-1, -1),
      ];
      for (final o in d) {
        final nr = p.x + o.x;
        final nc = p.y + o.y;
        if (nr < 0 || nc < 0 || nr >= rows || nc >= cols) continue;
        if (_grid[nr][nc] == tier) queue.add(Point(nr, nc));
      }
    }
    return out;
  }

  /// Hint: prefer loopable 4+ groups, else any minLen path.
  void _showHint() {
    if (_busy || _ended || _paused) return;
    final seen = <Point<int>>{};
    List<Point<int>>? pick;
    List<Point<int>>? loopPick;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = Point(r, c);
        if (seen.contains(p) || _grid[r][c] == 0) continue;
        final group = _flood(r, c);
        seen.addAll(group);
        if (group.length >= 4 && loopPick == null) {
          loopPick = group.take(min(group.length, 6)).toList();
        } else if (group.length >= minLen && pick == null) {
          pick = group.take(min(group.length, 5)).toList();
        }
      }
    }
    pick = loopPick ?? pick;
    if (pick == null) {
      _fill();
      setState(() => _hint = 'Tahta yenilendi.');
      return;
    }
    final isLoopHint = loopPick != null;
    _hintTimer?.cancel();
    setState(() {
      _hintCells = pick!.toSet();
      _hint = isLoopHint
          ? 'İpucu: kare yap, türün hepsi gider.'
          : 'İpucu: bu grubu bağla.';
    });
    _hintTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _hintCells = {});
    });
    HapticFeedback.selectionClick();
  }

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

  void _begin(Point<int> p) {
    if (_busy || _ended || _paused || _grid[p.x][p.y] == 0) return;
    _clearPath();
    _hintCells = {};
    _paint = _grid[p.x][p.y];
    _path.add(p);
    _pathSet.add(p);
    setState(() => _hint = 'Seçili 1 · en az $minLen');
  }

  void _extend(Point<int> p) {
    if (_busy || _ended || _paused || _path.isEmpty) return;
    if (_path.length >= 2 && p == _path[_path.length - 2]) {
      final removed = _path.removeLast();
      _pathSet.remove(removed);
      _loop = false;
      setState(() => _hint = 'Seçili ${_path.length}');
      return;
    }
    if (_pathSet.contains(p)) {
      if (p == _path.first && _path.length >= 4 && _ortho(p, _path.last)) {
        _loop = true;
        setState(() => _hint = 'KARE · bırak, hepsi silinsin');
        HapticFeedback.lightImpact();
      }
      return;
    }
    if (_grid[p.x][p.y] != _paint) return;
    if (!_ortho(p, _path.last)) return;
    _path.add(p);
    _pathSet.add(p);
    _loop = false;
    final len = _path.length;
    setState(() {
      if (len >= 6) {
        _hint = 'Uzun zincir! $len';
      } else {
        _hint = 'Seçili $len';
      }
    });
  }

  Future<void> _commit() async {
    if (_busy || _ended || _paused) return;
    if (_path.length < minLen) {
      _clearPath();
      setState(() {
        _streak = 0;
        _hint = 'En az $minLen böcek bağla.';
        _comboMeter = max(0, _comboMeter - 0.15);
      });
      return;
    }

    final epoch = _epoch;

    final group = List<Point<int>>.from(_path);
    final loop = _loop;
    final tier = _paint;
    final pathLen = group.length;
    setState(() => _busy = true);
    _clearPath();

    var cleared = 0;
    if (loop) {
      _loopCount++;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (_grid[r][c] == tier) {
            _grid[r][c] = 0;
            cleared++;
          }
        }
      }
      _showMilestone('KARE TEMİZLİK');
    } else {
      for (final p in group) {
        if (_grid[p.x][p.y] == 0) continue;
        _grid[p.x][p.y] = 0;
        cleared++;
      }
    }

    _streak++;
    if (_streak > _maxStreak) _maxStreak = _streak;
    if (pathLen > _longestPath) _longestPath = pathLen;
    _clearTotal += cleared;

    final tierScore = tier < 1 ? 1 : tier;
    final lengthHeat = 1.0 + min(0.9, (pathLen - minLen) * 0.12);
    final streakHeat = 1.0 + min(0.7, (_streak - 1) * 0.12);
    final loopMult = loop ? 3.2 : 1.0;
    final gained =
        (loopMult * cleared * cleared * 8 * tierScore * lengthHeat * streakHeat)
            .round();
    _score += gained;
    if (_score > _best) _best = _score;
    _comboMeter = min(1.0, 0.25 + _streak * 0.12 + pathLen * 0.04);
    _lines--;
    _checkScoreMilestones();
    final insect = InsectTier.values[(tier - 1).clamp(0, 7)];
    _hint = loop
        ? 'Kare! x$_streak · +$gained'
        : '${insect.viralReplik} · x$_streak +$gained';
    _flashCells = group.toSet();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _flashCells = {});
    });
    if (loop) {
      _gridBurst = 1.08;
      HapticFeedback.heavyImpact();
      unawaited(AudioManager().playMerge(tierNumber: tier, comboCount: 3));
    } else {
      HapticFeedback.mediumImpact();
    }
    setState(() {});
    await Future<void>.delayed(
      Duration(milliseconds: loop ? 200 : 130),
    );
    if (!mounted || epoch != _epoch) return;
    _gridBurst = 1.0;
    _collapse();
    // Soft cascade: auto-clear tiny leftover singles of same color if 6+ path
    if (pathLen >= 6 && !loop) {
      final leftover = _floodAutoBonus(tier);
      if (leftover > 0) {
        _score += leftover * 30;
        _clearTotal += leftover;
        _hint = 'Bonus düşüş +${leftover * 30}';
      }
    }
    if (!_hasGroup()) _fill();
    if (!loop) AudioManager().playMerge(tierNumber: tier);
    await _endCheck(epoch);
  }

  int _floodAutoBonus(int tier) {
    // Clear orphan pairs of this tier that are isolated size 1 after long path.
    var n = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] != tier) continue;
        final g = _flood(r, c);
        if (g.length == 1) {
          _grid[r][c] = 0;
          n++;
        }
      }
    }
    if (n > 0) _collapse();
    return n;
  }

  void _togglePause() {
    if (_ended || _busy) return;
    setState(() {
      _paused = !_paused;
      if (_paused) _clearPath();
    });
  }

  void _showMilestone(String text) {
    _milestoneTimer?.cancel();
    setState(() => _milestone = text);
    _milestoneTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _milestone = null);
    });
  }

  void _checkScoreMilestones() {
    for (final m in const [400, 1000, 2000, 3500]) {
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
    } else if (_lines <= 0) {
      _lost = true;
      _hint = 'Çizgi hakkın bitti.';
      HapticFeedback.heavyImpact();
      AudioManager().playLose();
      await _persist();
    } else {
      _hint = 'Hedef $target · $_lines çizgi · streak x$_streak';
    }
    if (mounted && epoch == _epoch) setState(() => _busy = false);
  }

  String _statsLine() =>
      'Temiz $_clearTotal · Kare $_loopCount · Max streak x$_maxStreak · En uzun $_longestPath';

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
      _newGame();
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
    if (_ended && !_resultShown) _edgeShowResult();
    return ArcadeScreen(
      title: 'BAĞLA PATLAT',
      hint: _paused ? 'DURAKLATILDI' : _hint,
      score: _score,
      best: _best,
      statLabel: _streak > 0 ? 'STREAK' : 'ÇİZGİ',
      statValue: _streak > 0 ? 'x$_streak' : '$_lines',
      onRestart: _newGame,
      overlay: (_ended && !_resultShown)
          ? ArcadeResultOverlay(
              title: _won ? 'BAĞLANDI' : 'HAK BİTTİ',
              message: _statsLine(),
              score: _score,
              best: _best,
              won: _won,
              modeTitle: 'Bağla Patlat',
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
              value: _comboMeter,
              minHeight: 5,
              backgroundColor: LululuColors.darkObsidian,
              color: Color.lerp(
                LululuColors.liquidGold,
                _loop ? LululuColors.toxicNeon : LululuColors.cyberFuchsia,
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
          final stride = cell + gap;
          return Stack(
            children: [
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) {
                    final p = _cellAt(d.localPosition, cell, gap);
                    if (p != null) _begin(p);
                  },
                  onPanUpdate: (d) {
                    final p = _cellAt(d.localPosition, cell, gap);
                    if (p != null) _extend(p);
                  },
                  onPanEnd: (_) {
                    if (_streak > 0 && _path.length < minLen) {
                      // failed short path breaks streak only on commit fail
                    }
                    unawaited(_commit());
                  },
                  child: AnimatedScale(
                    scale: _gridBurst,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    child: SizedBox(
                      width: gridW,
                      height: gridW,
                      child: Stack(
                        children: [
                          for (var r = 0; r < rows; r++)
                            for (var c = 0; c < cols; c++)
                              Positioned(
                                left: c * stride,
                                top: r * stride,
                                width: cell,
                                height: cell,
                                child: _tile(r, c),
                              ),
                          if (_path.length >= 2)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _PathPainter(
                                    path: _path,
                                    cell: cell,
                                    gap: gap,
                                    loop: _loop,
                                    hot: _comboMeter,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
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
    final tier = _grid[r][c];
    final onPath = _pathSet.contains(Point(r, c));
    final hinted = _hintCells.contains(Point(r, c));
    final flashed = _flashCells.contains(Point(r, c));
    final insect = tier == 0 ? null : InsectTier.values[tier - 1];
    return AnimatedScale(
      scale: onPath || hinted || flashed ? 1.06 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: flashed
              ? LululuColors.liquidGold.withValues(alpha: 0.35)
              : LululuColors.spaceNavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: flashed
                ? Colors.white
                : hinted
                    ? LululuColors.toxicNeon
                    : onPath
                        ? (_loop
                            ? LululuColors.toxicNeon
                            : LululuColors.liquidGold)
                        : LululuColors.darkObsidian,
            width: onPath || hinted || flashed ? 2.2 : 1,
          ),
          boxShadow: onPath || hinted || flashed
              ? [
                  BoxShadow(
                    color: (flashed
                            ? Colors.white
                            : _loop
                                ? LululuColors.toxicNeon
                                : LululuColors.liquidGold)
                        .withValues(alpha: 0.45),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: insect == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(4),
                child: StickerImage(assetPath: insect.assetPath),
              ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.path,
    required this.cell,
    required this.gap,
    required this.loop,
    required this.hot,
  });

  final List<Point<int>> path;
  final double cell;
  final double gap;
  final bool loop;
  final double hot;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final stride = cell + gap;
    Offset center(Point<int> p) => Offset(
          p.y * stride + cell / 2,
          p.x * stride + cell / 2,
        );
    final paint = Paint()
      ..color = (loop ? LululuColors.toxicNeon : LululuColors.liquidGold)
          .withValues(alpha: 0.55 + hot * 0.35)
      ..strokeWidth = 3.5 + hot * 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5);

    final pathDraw = Path()..moveTo(center(path.first).dx, center(path.first).dy);
    for (var i = 1; i < path.length; i++) {
      final o = center(path[i]);
      pathDraw.lineTo(o.dx, o.dy);
    }
    if (loop) {
      final o = center(path.first);
      pathDraw.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(pathDraw, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) => true;
}
