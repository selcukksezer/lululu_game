import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';
import '../widgets/mode_bonus_bar.dart';

/// Swap neighbors. 3+ pop, cascade. 4+ → bomba. Pause / hint.
class Match3Screen extends StatefulWidget {
  const Match3Screen({
    super.key,
    this.energyConsumed = false,
    @visibleForTesting this.prototypeVisualState = false,
  });

  /// `true` ise bu ekrana giriş `openGameMode` üzerinden 1 enerji
  /// tüketerek yapıldı; hiç hamle yapılmadan çıkılırsa enerji iade
  /// edilir (Suika `GameScreen` deseni). Doğrudan rota girişlerinde
  /// `false` kalır.
  final bool energyConsumed;

  @visibleForTesting
  final bool prototypeVisualState;

  @override
  State<Match3Screen> createState() => _Match3ScreenState();
}

class _Match3ScreenState extends State<Match3Screen> {
  static const int rows = 8;
  int get _cols => widget.prototypeVisualState ? 8 : 6;

  /// 5 kinds matching the 5 prototype insect tiers and pastel tile colors.
  static const int kinds = 5;
  static const int minRun = 3;
  static const int startMoves = 30;
  static const int target = 3000;

  /// Bomb encoding: baseKind + bombBias (6–10).
  static const int bombBias = 5;
  static const _prototypeTileColors = <Color>[
    Color(0xFFFFE9C9),
    Color(0xFFFFE3D6),
    Color(0xFFE4F0FF),
    Color(0xFFF3E4FF),
    Color(0xFFFFE0EC),
  ];

  final _rng = Random();
  late List<List<int>> _grid;
  int _score = 0;
  int _best = 0;
  int _moves = startMoves;
  int _epoch = 0;
  bool _busy = false;
  bool _won = false;
  bool _lost = false;
  bool _resultShown = false;
  bool _paused = false;

  /// Hamle bayrağı (enerji iadesi): oturum boyunca ilk takas denemesi
  /// (`_resolve`, eşleşmese de) veya tur tamamlanması (`_endCheck`)
  /// ile `true` olur; TEKRAR/yeniden başlatmada SIFIRLANMAZ (Suika
  /// `_dropsMade` deseni — oturum ömrü).
  bool _moveMade = false;

  /// Çift-iade koruması: iade bu oturumda en fazla bir kez yapılır.
  bool _energyRefunded = false;

  bool _swiped = false;
  Point<int>? _selected;
  Point<int>? _dragFrom;
  String _hint = '';
  bool _hintSeeded = false;

  int _maxChain = 0;
  int _mergeTotal = 0;
  int _bombsMade = 0;
  int _bombsFired = 0;
  double _comboMeter = 0;
  String? _milestone;
  String? _comboText;
  String? _gainText;
  Timer? _comboTimer;
  Timer? _milestoneTimer;
  final Set<int> _milestonesHit = {};
  List<Point<int>> _hintCells = [];
  Timer? _hintTimer;
  double _bombPulse = 0;
  Timer? _bombPulseTimer;
  String? _activePowerFx;
  Timer? _powerFxTimer;

  bool get _ended => _won || _lost;

  int _base(int v) {
    if (v <= 0) return 0;
    if (widget.prototypeVisualState && v <= _prototypeTileColors.length) {
      return v;
    }
    if (v > kinds) return v - bombBias;
    return v;
  }

  bool _isBomb(int v) =>
      v > (widget.prototypeVisualState ? _prototypeTileColors.length : kinds) &&
      v <=
          (widget.prototypeVisualState
              ? _prototypeTileColors.length + bombBias
              : kinds + bombBias);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hintSeeded) {
      _hintSeeded = true;
      _hint = context.l10n.match3HintIdle;
    }
  }

  void _setIdleHint() {
    // initState yolundan çağrılırsa tohum didChangeDependencies'te atılır.
    if (_hintSeeded) _hint = context.l10n.match3HintIdle;
  }

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _deal();
    if (widget.prototypeVisualState) {
      _score = 3420;
      _best = 5940;
      _moves = 18;
      _selected = const Point(3, 3);
      _comboText = 'COMBO X3!';
      _gainText = '+240 X3';
      _hint =
          "Komşu böceği kaydır — 3 aynı tier patlar, 4'lü bomba yapar. Hamle bitmeden hedefe ulaş.";
      final pm = ProgressManager();
      pm.extraPowers['hammer'] = 2;
      pm.extraPowers['bomb3'] = 2;
      pm.extraPowers['hunter'] = 1;
    } else {
      _ensureDefaultPowers();
    }
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

  // Varsayılan stok YALNIZ ilk kurulumda verilir. ProgressManager.load()
  // 'lululu_power_seed_v1' bayrağıyla 33 gücü bir kez tohumlar; tohumlanan
  // anahtarlar extraPowers'ta kalıcı olur, takePower() ise anahtarı silmez,
  // 0'a düşürür. "Hiç tohumlanmadı" bu yüzden anahtar yokluğuyla anlaşılır;
  // eski "üçü de 0 ise doldur" koşulu her girişte bedava stok veriyordu.
  // Tohumlama persistBoosters() ile kalıcı kaydedilir.
  void _ensureDefaultPowers() {
    final pm = ProgressManager();
    const defaults = <String, int>{'hammer': 2, 'bomb3': 2, 'hunter': 1};
    var seeded = false;
    for (final entry in defaults.entries) {
      if (!pm.extraPowers.containsKey(entry.key)) {
        pm.extraPowers[entry.key] = entry.value;
        seeded = true;
      }
    }
    if (seeded) unawaited(pm.persistBoosters());
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _comboTimer?.cancel();
    _milestoneTimer?.cancel();
    _hintTimer?.cancel();
    _bombPulseTimer?.cancel();
    _powerFxTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    if (widget.prototypeVisualState) return;
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best = LeaderboardService.instance.getBest(
        LeaderboardService.modeMatch3,
      );
    });
  }

  Future<void> _persist() async {
    if (_score <= 0) return;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeMatch3,
      _score,
    );
    final best = LeaderboardService.instance.getBest(
      LeaderboardService.modeMatch3,
    );
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
    _comboText = null;
    _gainText = null;
    _hintCells = [];
    _setIdleHint();
    _deal();
    setState(() {});
  }

  void _deal() {
    if (widget.prototypeVisualState) {
      _grid = List.generate(rows, (r) {
        return List.generate(_cols, (c) {
          final index = r * _cols + c;
          if (index == 44) return 6;
          return ((index * 7 + r * 3) % 5) + 1;
        });
      });
      return;
    }
    for (var attempt = 0; attempt < 40; attempt++) {
      _grid = List.generate(rows, (_) => List.filled(_cols, 0));
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < _cols; c++) {
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
    const c = 1;
    if (c + 3 >= _cols) return;
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
      final horz =
          c >= 2 &&
          _base(_grid[r][c - 1]) == tier &&
          _base(_grid[r][c - 2]) == tier;
      final vert =
          r >= 2 &&
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
      for (var c = 0; c < _cols; c++) {
        if (c + 1 < _cols && _wouldMatch(r, c, r, c + 1)) return true;
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

  Set<Point<int>> _findMatches() {
    final set = <Point<int>>{};
    // Horizontal
    for (var r = 0; r < rows; r++) {
      var run = 1;
      for (var c = 1; c < _cols; c++) {
        final same =
            _grid[r][c] != 0 && _base(_grid[r][c]) == _base(_grid[r][c - 1]);
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
          set.add(Point(r, _cols - 1 - k));
        }
      }
    }
    // Vertical
    for (var c = 0; c < _cols; c++) {
      var run = 1;
      for (var r = 1; r < rows; r++) {
        final same =
            _grid[r][c] != 0 && _base(_grid[r][c]) == _base(_grid[r - 1][c]);
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
    for (var c = p.y + 1; c < _cols && _base(_grid[p.x][c]) == base; c++) {
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
          if (nr < 0 || nc < 0 || nr >= rows || nc >= _cols) continue;
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
    // Enerji iadesi sayacı: takas denemesi anında sayılır (eşleşme
    // olmasa da hamle sayılır — Suika'da ıska atış gibi).
    _moveMade = true;
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
      _comboTimer?.cancel();
      _comboText = chain > 1 ? 'COMBO X$chain!' : null;
      _gainText = '+$gained X$chain';
      _comboTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted) {
          setState(() {
            _comboText = null;
            _gainText = null;
          });
        }
      });

      if (bombAt != null && chain == 1) {
        final base = voiceTier.clamp(1, kinds);
        _grid[bombAt.x][bombAt.y] = base + bombBias;
        _bombsMade++;
        _hint = 'BOMBA oluştu!';
        _showMilestone(context.l10n.powerBombCaps);
        bombAt = null;
      }

      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!mounted || epoch != _epoch) return;
      _collapse(avoidRunaway: chain >= 2);
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

  void _collapse({bool avoidRunaway = false}) {
    for (var c = 0; c < _cols; c++) {
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
        _grid[r][c] = avoidRunaway
            ? _rollAvoiding(r, c)
            : (1 + _rng.nextInt(kinds));
      }
    }
  }

  Future<void> _endCheck(int epoch) async {
    if (!mounted || epoch != _epoch) return;
    if (_score >= target) {
      // Tur tamamlandı: iade hakkı biter (bayrak oturum ömründe kalır).
      _moveMade = true;
      _won = true;
      _hint = 'Hedef tuttu.';
      HapticFeedback.heavyImpact();
      AudioManager().playWin();
      await _persist();
    } else if (_moves <= 0) {
      _moveMade = true;
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
    final gridW = cell * _cols + gap * (_cols - 1);
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
      for (var c = 0; c < _cols; c++) {
        final cx = c * stride + cell / 2;
        final cy = r * stride + cell / 2;
        final d =
            (local.dx - cx) * (local.dx - cx) +
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

  /// Oyun sonu: yeni sonuç ekranı. "TEKRAR OYNA" yeni turu başlatır,
  /// "ANA SAYFA"da eski sonuç akışı devam eder (bozulmadı).

  Point<int>? _firstFilled() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < _cols; c++) {
        if (_grid[r][c] != 0) return Point(r, c);
      }
    }
    return null;
  }

  void _triggerPowerFx(String kind, String milestoneText) {
    _powerFxTimer?.cancel();
    _activePowerFx = kind;
    _showMilestone(milestoneText);
    _powerFxTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _activePowerFx = null);
    });
  }

  Future<void> _resolveCascadeAfterPower() async {
    if (_ended) return;
    final epoch = _epoch;
    var chain = 1;
    var matches = _findMatches();
    while (matches.isNotEmpty) {
      chain++;
      if (chain > _maxChain) _maxChain = chain;
      _expandBombs(matches);
      var gained = 0;
      for (final p in matches) {
        final raw = _grid[p.x][p.y];
        if (raw == 0) continue;
        gained += 12 * _base(raw) * chain;
        _grid[p.x][p.y] = 0;
      }
      _mergeTotal += matches.length;
      _score += gained;
      if (_score > _best) _best = _score;
      _checkMilestones();
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 110));
      if (!mounted || epoch != _epoch) return;
      _collapse();
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 90));
      if (!mounted || epoch != _epoch) return;
      matches = _findMatches();
    }
    if (!_ended && !_hasMove()) _reshuffle();
    await _endCheck(epoch);
  }

  /// Güçler skor verir ama bedava değildir: kalıcı stoktan 1 adet
  /// (stockBonus/takePower) + 1 hamle harcar. Hamle bedeli, güç sonrası
  /// çalışan _resolveCascadeAfterPower → _endCheck tarafından görülür.
  bool _useHammer() {
    if (_ended || _paused || _busy) return false;
    final cell = _selected ?? _firstFilled();
    if (cell == null) return false;
    HapticFeedback.heavyImpact();
    AudioManager().playMerge(tierNumber: max(1, _base(_grid[cell.x][cell.y])));
    setState(() {
      _grid[cell.x][cell.y] = 0;
      _moves--;
      _score += 48;
      if (_score > _best) _best = _score;
      _mergeTotal++;
      _gainText = '+48 ÇEKİÇ!';
      _hint = 'Çekiç seçili taşı kırdı!';
      _collapse();
      _triggerPowerFx('hammer', 'ÇEKİÇ DARBESİ!');
    });
    unawaited(_resolveCascadeAfterPower());
    return true;
  }

  bool _useBomb3() {
    if (_ended || _paused || _busy) return false;
    final cell = _selected ?? const Point<int>(3, 3);
    HapticFeedback.heavyImpact();
    AudioManager().playMerge(tierNumber: 4);
    setState(() {
      var n = 0;
      for (var r = cell.x - 1; r <= cell.x + 1; r++) {
        for (var c = cell.y - 1; c <= cell.y + 1; c++) {
          if (r < 0 || c < 0 || r >= rows || c >= _cols) continue;
          if (_grid[r][c] == 0) continue;
          _grid[r][c] = 0;
          n++;
        }
      }
      for (var c = 0; c < _cols; c++) {
        if (_grid[cell.x][c] != 0) {
          _grid[cell.x][c] = 0;
          n++;
        }
      }
      final gained = n * 22;
      _moves--;
      _score += gained;
      if (_score > _best) _best = _score;
      _mergeTotal += n;
      _bombsFired++;
      _gainText = '+$gained ROKET BOMBA!';
      _hint = 'Satır Roketi & 3x3 Bomba $n taşı uçurdu!';
      _collapse();
      _triggerPowerFx('bomb3', 'ROKET & 3x3 BOMBA!');
    });
    unawaited(_resolveCascadeAfterPower());
    return true;
  }

  bool _useHunter() {
    if (_ended || _paused || _busy) return false;
    final counts = List<int>.filled(kinds + 1, 0);
    for (final row in _grid) {
      for (final value in row) {
        if (value != 0) counts[_base(value)]++;
      }
    }
    var best = 1;
    for (var i = 2; i <= kinds; i++) {
      if (counts[i] > counts[best]) best = i;
    }
    if (counts[best] == 0) return false;
    HapticFeedback.heavyImpact();
    AudioManager().playMerge(tierNumber: best);
    setState(() {
      var n = 0;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < _cols; c++) {
          if (_base(_grid[r][c]) != best) continue;
          _grid[r][c] = 0;
          n++;
        }
      }
      final gained = n * 20;
      _moves--;
      _score += gained;
      if (_score > _best) _best = _score;
      _mergeTotal += n;
      _comboText = 'RENK KÜRESİ!';
      _gainText = '+$gained AVCI!';
      _hint = 'Renk Küresi / Avcı $n aynı tür böceği temizledi!';
      _collapse();
      _triggerPowerFx('hunter', 'RENK KÜRESİ · $n BÖCEK!');
    });
    unawaited(_resolveCascadeAfterPower());
    return true;
  }

  void _reset() {
    _resultShown = false;
    _newGame();
  }

  Future<void> _presentResult() async {
    if (_score > _best) _best = _score;
    // S1#49: ödeme + mod skoru + liderlik + görev kaydı + sonuç ekranı
    // finishRun() üzerinden (tek-ödeme korunur).
    final replay = await finishRun(
      context,
      score: _score,
      best: _best,
      leaderboardMode: LeaderboardService.modeMatch3,
      modeScoreId: 'match3',
    );
    if (!mounted) return;
    if (!replay) {
      Navigator.of(context).maybePop();
      return;
    }
    _reset();
  }

  /// Hamlesiz-çıkış enerji iadesi (tek çıkış noktası: `PopScope`).
  ///
  /// Yalnız giriş enerjisi tüketildiyse, tur tamamlanmadıysa ve oturum
  /// boyunca hiç hamle yapılmadıysa 1 enerji iade edilir. `dispose`
  /// içinde DEĞİL, yalnızca gerçek rota çıkışında (`didPop`) çağrılır.
  void _maybeRefundEnergy() {
    if (_energyRefunded) return;
    if (!widget.energyConsumed || _moveMade || _ended || _resultShown) {
      return;
    }
    _energyRefunded = true;
    EnergyService.instance.addEnergy(1);
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
    final overlayWidget = (_ended && !_resultShown)
        ? ArcadeResultOverlay(
            title: _won ? context.l10n.targetTitle : context.l10n.movesOutTitle,
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
        : null;

    final bonusItems = [
      stockBonusWithResult(
        id: 'hammer',
        label: context.l10n.powerHammerCaps,
        asset: 'assets/icons2/hammer.png',
        effect: () {
          final applied = _useHammer();
          setState(() {});
          return applied;
        },
      ),
      stockBonusWithResult(
        id: 'bomb3',
        label: context.l10n.powerBombCaps,
        asset: 'assets/icons2/boom.png',
        effect: () {
          final applied = _useBomb3();
          setState(() {});
          return applied;
        },
      ),
      stockBonusWithResult(
        id: 'hunter',
        label: context.l10n.powerHunterCaps,
        asset: 'assets/icons2/gem_blue.png',
        effect: () {
          final applied = _useHunter();
          setState(() {});
          return applied;
        },
      ),
    ];

    final stageChild = LayoutBuilder(
      builder: (context, constraints) {
        final double gap;
        final double boardPadding;
        final double cell;
        final double gridW;
        final double gridH;
        final double boardW;
        final double boardH;
        if (widget.prototypeVisualState) {
          gap = 4.0;
          boardPadding = 12.0;
          final boardSide = min(
            306.0,
            min(constraints.maxWidth, constraints.maxHeight - 52),
          );
          final gridSide = boardSide - boardPadding * 2;
          cell = (gridSide - gap * (_cols - 1)) / _cols;
          gridW = cell * _cols + gap * (_cols - 1);
          gridH = gridSide;
          boardW = boardSide;
          boardH = boardSide;
        } else {
          gap = 5.0;
          boardPadding = 8.0;
          final availW = max(160.0, constraints.maxWidth - boardPadding * 2);
          final availH = max(
            160.0,
            constraints.maxHeight - 54.0 - boardPadding * 2,
          );
          cell = min(
            (availW - gap * (_cols - 1)) / _cols,
            (availH - gap * (rows - 1)) / rows,
          );
          gridW = cell * _cols + gap * (_cols - 1);
          gridH = cell * rows + gap * (rows - 1);
          boardW = gridW + boardPadding * 2;
          boardH = gridH + boardPadding * 2;
        }
        return Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: constraints.maxHeight >= 550 ? 50 : 28,
                ),
                child: Center(
                  child: SizedBox(
                    width: boardW,
                    height: boardH,
                    child: Padding(
                      padding: EdgeInsets.all(boardPadding),
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
                          if (to == null || to == from) {
                            final dx = d.delta.dx;
                            final dy = d.delta.dy;
                            if (dx.abs() < 4 && dy.abs() < 4) return;
                            if (dx.abs() >= dy.abs()) {
                              final nc = (from.y + (dx > 0 ? 1 : -1))
                                  .clamp(0, _cols - 1);
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
                          height: gridH,
                          child: GridView.builder(
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: rows * _cols,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _cols,
                                  crossAxisSpacing: gap,
                                  mainAxisSpacing: gap,
                                  childAspectRatio: 1,
                                ),
                            itemBuilder: (context, index) =>
                                _tile(index ~/ _cols, index % _cols),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.targetWithValue('3.000'),
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          height: 1.55,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.77,
                          color: const Color(0xFF9AA7BC),
                        ),
                      ),
                      Text(
                        widget.prototypeVisualState
                            ? '%62'
                            : '%${((_score / target) * 100).clamp(0, 100).round()}',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          height: 1.55,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.77,
                          color: const Color(0xFF9AA7BC),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 15,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: const Color(0x24FFFFFF),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: widget.prototypeVisualState
                          ? 0.62
                          : (_score / target).clamp(0.02, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF00C853),
                              Color(0xFFFFD700),
                              Color(0xFFE52E2E),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_comboText != null)
              Positioned(
                left: 9.8,
                bottom: 60.4,
                child: IgnorePointer(
                  child: Text(
                    _comboText!,
                    style: GoogleFonts.bangers(
                      fontSize: 23,
                      letterSpacing: 1.15,
                      height: 1,
                      color: const Color(0xFFFFB800),
                      shadows: const [
                        Shadow(color: Color(0x52FF6B35), blurRadius: 54),
                        Shadow(color: Color(0x8CFF6B35), blurRadius: 32),
                        Shadow(color: Color(0xE6FF6B35), blurRadius: 14),
                        Shadow(
                          color: Color(0xEB080B12),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_gainText != null)
              Positioned(
                right: 16,
                top: constraints.maxHeight * 0.38 - 1,
                child: IgnorePointer(
                  child: Text(
                    _gainText!,
                    style: GoogleFonts.bangers(
                      fontSize: 24,
                      letterSpacing: 0.6,
                      height: 1,
                      color: const Color(0xFFFFB800),
                      shadows: const [
                        Shadow(color: Color(0x52FF6B35), blurRadius: 54),
                        Shadow(color: Color(0x8CFF6B35), blurRadius: 32),
                        Shadow(color: Color(0xE6FF6B35), blurRadius: 14),
                        Shadow(
                          color: Color(0xEB080B12),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_activePowerFx != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _activePowerFx == 'hammer'
                              ? const Color(0xFFFFD700)
                              : _activePowerFx == 'bomb3'
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF00E5FF),
                          width: 5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_activePowerFx == 'hammer'
                                    ? const Color(0xFFFFD700)
                                    : _activePowerFx == 'bomb3'
                                    ? const Color(0xFFFF6B35)
                                    : const Color(0xFF00E5FF))
                                .withValues(alpha: 0.55),
                            blurRadius: 28,
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
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _maybeRefundEnergy();
      },
      child: _buildMatch3PrototypeChrome(
        context: context,
        stageChild: stageChild,
        bonusItems: bonusItems,
        overlayWidget: overlayWidget,
      ),
    );
  }

  String _formatTrInt(int value) {
    final s = value.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return value < 0 ? '-$buf' : buf.toString();
  }

  void _showHelpModal(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF141B2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0x66FFB800), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x26FFB800),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xB3FFB800),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '?',
                      style: GoogleFonts.baloo2(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFB800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'MATCH 3 · NASIL OYNANIR?',
                      style: GoogleFonts.baloo2(
                        fontSize: 18,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B101B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  _hint,
                  style: GoogleFonts.nunito(
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD8E0EE),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB800),
                    foregroundColor: const Color(0xFF4A2E00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    'ANLADIM, OYNA!',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4A2E00),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scaleBand(double screenW, double height, Widget child) {
    if ((screenW - 430.0).abs() < 0.5) {
      return SizedBox(width: 430, height: height, child: child);
    }
    return SizedBox(
      height: height * (screenW / 430.0),
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.center,
        child: SizedBox(width: 430, height: height, child: child),
      ),
    );
  }

  Widget _buildMatch3PrototypeChrome({
    required BuildContext context,
    required Widget stageChild,
    required List<ModeBonus> bonusItems,
    required Widget? overlayWidget,
  }) {
    final screenW = MediaQuery.sizeOf(context).width;
    final topPad = MediaQuery.paddingOf(context).top;
    final useHostTopInset = !widget.prototypeVisualState && topPad > 0;
    final coinsText = _formatTrInt(ProgressManager().coins);
    return Scaffold(
      backgroundColor: const Color(0xFF080B12),
      body: MediaQuery.withNoTextScaling(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.96,
                child: Image.asset(
                  'assets/design/backgrounds/match3_lab.webp',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.24, 0.76, 1],
                    colors: [
                      Color(0x4D080B12),
                      Color(0x00080B12),
                      Color(0x00080B12),
                      Color(0x52080B12),
                    ],
                  ),
                ),
              ),
            ),
            Offstage(
              offstage: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ArcadeStat(label: context.l10n.gameScoreLabel, value: _formatTrInt(_score)),
                    ArcadeStat(label: context.l10n.gameBestLabel, value: _formatTrInt(_best)),
                    ArcadeStat(label: context.l10n.movesLabelCaps, value: '$_moves'),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  // Statusbar (35.4px in headless/prototype, topPad on real device)
                  if (useHostTopInset)
                    SizedBox(height: topPad)
                  else
                    _scaleBand(
                      screenW,
                      35.4,
                      Stack(
                        children: [
                          Positioned(
                            left: 21,
                            top: 16,
                            child: Text(
                              '09:41',
                              style: GoogleFonts.nunito(
                                fontSize: 12.5,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.25,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 373,
                            top: 16.2,
                            child: CustomPaint(
                              size: Size(35, 15),
                              painter: _Match3StatusIconsPainter(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // mode-top (54px: top=35.4..89.4)
                  _scaleBand(
                    screenW,
                    54,
                    Stack(
                      children: [
                        Positioned(
                          left: 12,
                          top: 6,
                          width: 48,
                          height: 48,
                          child: Semantics(
                            button: true,
                            label: context.l10n.goBackLabel,
                            child: GestureDetector(
                            onTap: () => Navigator.maybePop(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xD9080B12),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x73000000),
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/icons2/back-prototype.png',
                                width: 29,
                                height: 29,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          ),
                        ),
                        Positioned(
                          left: 70,
                          top: 16.3,
                          height: 27,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x8C080B12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Transform.translate(
                              offset: const Offset(1, 0),
                              child: Text(
                                'MATCH 3',
                                style: GoogleFonts.baloo2(
                                  fontSize: 20,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xB3000000),
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 167.7,
                          top: 23.3,
                          width: 48.3,
                          height: 20.3,
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 1.5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'NEON',
                              style: GoogleFonts.baloo2(
                                fontSize: 10.5,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.42,
                                color: const Color(0xFF04140A),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 266.8,
                          top: 12.5,
                          width: 93.2,
                          height: 35,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
                            decoration: BoxDecoration(
                              color: const Color(0xD1080B12),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icons2/coin.png',
                                  width: 25,
                                  height: 25,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Transform.translate(
                                    offset: const Offset(0, -1),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        coinsText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.nunito(
                                          fontSize: 13.5,
                                          height: 1.2,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 370,
                          top: 6,
                          width: 48,
                          height: 48,
                          child: Semantics(
                            button: true,
                            label: context.l10n.helpButtonLabel,
                            child: GestureDetector(
                            onTap: () => _showHelpModal(context),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xDB080B12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xB3FFB800),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                '?',
                                style: GoogleFonts.baloo2(
                                  fontSize: 22,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFFFB800),
                                ),
                              ),
                            ),
                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // game-hud (58.5px: top=89.4..147.9)
                  _scaleBand(
                    screenW,
                    58.5,
                    Stack(
                      children: [
                        Positioned(
                          left: 12,
                          top: 7.6,
                          width: 104,
                          height: 51,
                          child: _buildHudStatBox(
                            label: context.l10n.gameScoreLabel,
                            value: _formatTrInt(_score),
                            valueDx: -1,
                          ),
                        ),
                        Positioned(
                          left: 124,
                          top: 7.6,
                          width: 84,
                          height: 51,
                          child: _buildHudStatBox(
                            label: context.l10n.gameBestLabel,
                            value: _formatTrInt(_best),
                            valueDx: -1,
                          ),
                        ),
                        Positioned(
                          left: 278.2,
                          top: 7.6,
                          width: 74,
                          height: 51,
                          child: _buildHudStatBox(
                            label: context.l10n.movesLabelCaps,
                            value: '$_moves',
                          ),
                        ),
                        Positioned(
                          left: 360.2,
                          top: 9.2,
                          width: 57.8,
                          height: 48,
                          child: Semantics(
                            button: true,
                            label: context.l10n.finishRoundLabel,
                            child: GestureDetector(
                            onTap: _newGame,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB800),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFFB97A00),
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                context.l10n.finishCaps,
                                style: GoogleFonts.baloo2(
                                  fontSize: 12.5,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: const Color(0xFF4A2E00),
                                ),
                              ),
                            ),
                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // mode-stage (margin: 10px 14px 0)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x660E1422),
                            Color(0x800E1422),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0x24FFFFFF),
                          width: 2,
                        ),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: DecoratedBox(
                          position: DecorationPosition.foreground,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0x59000000),
                              width: 1,
                            ),
                          ),
                          child: stageChild,
                        ),
                      ),
                    ),
                  ),
                  // power-dock (80.9px: top=851.1..932)
                  SizedBox(
                    height: 80.9,
                    child: _buildMatch3PowerDock(bonusItems),
                  ),
                ],
              ),
            ),
            ?overlayWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildHudStatBox({
    required String label,
    required String value,
    double valueDx = 0,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: const Color(0xD9080B12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x73FFB800), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -1),
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 10,
                height: 1.55,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: const Color(0xFFFFB800),
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(valueDx, 0),
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.baloo2(
                    fontSize: 21,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatch3PowerDock(List<ModeBonus> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            _buildPowerButton(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildPowerButton(ModeBonus item) {
    final hasStock = item.count > 0;
    final enabled = item.onTap != null && hasStock;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${item.label}. ${item.count} adet',
      child: GestureDetector(
        onTap: enabled ? item.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: hasStock ? 1 : 0.55,
          child: SizedBox(
            width: 66,
            height: 62.9,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 9,
                  top: 2,
                  width: 48,
                  height: 48,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF333F58), Color(0xFF1B2336)],
                      ),
                      shape: BoxShape.circle,
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
                  left: 41,
                  top: -2,
                  width: 22,
                  height: 22,
                  child: Container(
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
                Positioned(
                  left: 0,
                  right: 0,
                  top: 52,
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: GoogleFonts.nunito(
                      fontSize: 9,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.18,
                      color: const Color(0xFFD8E0EE),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final bgColor = bomb
        ? const Color(0xFF2A3042)
        : insect == null
        ? LululuColors.spaceNavy
        : _prototypeTileColors[
            (tier - 1).clamp(0, _prototypeTileColors.length - 1)];
    return AnimatedScale(
      scale: widget.prototypeVisualState
          ? 1
          : selected || hinted
          ? 1.07
          : bomb
          ? 1.0 + 0.04 * sin(_bombPulse)
          : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.elasticOut,
      child: CustomPaint(
        painter: _CellBoxPainter(
          row: r,
          col: c,
          color: bgColor,
          isBomb: bomb,
          isSelected: selected,
          isHinted: hinted,
          snapToPixel: widget.prototypeVisualState,
        ),
        child: bomb
            ? Padding(
                padding: const EdgeInsets.all(1.9),
                child: Image.asset(
                  'assets/icons2/boom.png',
                  fit: BoxFit.contain,
                ),
              )
            : insect == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(1.9),
                child: StickerImage(assetPath: insect.assetPath),
              ),
      ),
    );
  }
}

class _CellBoxPainter extends CustomPainter {
  const _CellBoxPainter({
    required this.row,
    required this.col,
    required this.color,
    required this.isBomb,
    required this.isSelected,
    required this.isHinted,
    required this.snapToPixel,
  });

  final int row;
  final int col;
  final Color color;
  final bool isBomb;
  final bool isSelected;
  final bool isHinted;
  final bool snapToPixel;

  @override
  void paint(Canvas canvas, Size size) {
    Rect rect = Offset.zero & size;
    if (snapToPixel) {
      final rawLeft = 74.0 + col * 35.75;
      final rawTop = 338.45 + row * 35.75;
      final dx0 = rawLeft.roundToDouble() - rawLeft;
      final dy0 = rawTop.roundToDouble() - rawTop;
      final dx1 = (rawLeft + 31.75).roundToDouble() - rawLeft;
      final dy1 = (rawTop + 31.75).roundToDouble() - rawTop;
      rect = Rect.fromLTRB(dx0, dy0, dx1, dy1);
    }

    final outer = RRect.fromRectAndRadius(rect, const Radius.circular(9));
    if (isBomb) {
      canvas.drawRRect(
        outer,
        Paint()
          ..color = const Color(0xBFFF6B35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawRRect(outer, Paint()..color = color);

    if (!isBomb) {
      final shifted = outer.shift(const Offset(0, -3));
      final shadowPath = Path.combine(
        PathOperation.difference,
        Path()..addRRect(outer),
        Path()..addRRect(shifted),
      );
      canvas.drawPath(shadowPath, Paint()..color = const Color(0x26000000));
    }

    if (isSelected) {
      // CSS: outline: 3px solid #FFD700; outline-offset: -1px
      final outlineRect = RRect.fromRectAndRadius(
        rect.inflate(0.5),
        const Radius.circular(9.5),
      );
      canvas.drawRRect(
        outlineRect,
        Paint()
          ..color = const Color(0xFFFFD700)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    } else if (isHinted) {
      final outlineRect = RRect.fromRectAndRadius(
        rect.deflate(1.0),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        outlineRect,
        Paint()
          ..color = LululuColors.toxicNeon
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CellBoxPainter oldDelegate) =>
      oldDelegate.row != row ||
      oldDelegate.col != col ||
      oldDelegate.color != color ||
      oldDelegate.isBomb != isBomb ||
      oldDelegate.isSelected != isSelected ||
      oldDelegate.isHinted != isHinted ||
      oldDelegate.snapToPixel != snapToPixel;
}

class _Match3StatusIconsPainter extends CustomPainter {
  const _Match3StatusIconsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final sx = 15 / 24.0;
    final sy = 15 / 24.0;

    final outerArc = Path()
      ..moveTo(2 * sx, 8.5 * sy)
      ..quadraticBezierTo(12 * sx, 1.5 * sy, 22 * sx, 8.5 * sy);
    canvas.drawPath(outerArc, strokePaint);

    final midArc = Path()
      ..moveTo(5 * sx, 12 * sy)
      ..quadraticBezierTo(12 * sx, 7.2 * sy, 19 * sx, 12 * sy);
    canvas.drawPath(midArc, strokePaint);

    final innerArc = Path()
      ..moveTo(8.5 * sx, 15.5 * sy)
      ..quadraticBezierTo(12 * sx, 13 * sy, 15.5 * sx, 15.5 * sy);
    canvas.drawPath(innerArc, strokePaint);

    canvas.drawCircle(
      Offset(12 * sx, 19 * sy),
      1.5 * sx,
      Paint()..color = Colors.white,
    );

    const bx = 20.0;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx + 2 * sx, 7 * sy, 17 * sx, 10 * sy),
      Radius.circular(2 * sx),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * sx,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bx + 4 * sx, 9 * sy, 11 * sx, 6 * sy),
        Radius.circular(1 * sx),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      Rect.fromLTWH(bx + 20 * sx, 10 * sy, 2 * sx, 4 * sy),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
