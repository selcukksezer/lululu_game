import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import '../widgets/mode_bonus_bar.dart';

/// Puzzle-Bobble: aim, stick to the cluster, pop 3+ of the same bug.
/// Bubbles that lose their link to the ceiling fall.
class BalloonPopScreen extends StatefulWidget {
  const BalloonPopScreen({
    super.key,
    this.energyConsumed = false,
    @visibleForTesting this.prototypeVisualState = false,
  });

  /// `true` ise bu ekrana giriş `openGameMode` üzerinden 1 enerji
  /// tüketerek yapıldı; hiç hamle yapılmadan çıkılırsa enerji iade
  /// edilir (Suika `GameScreen` deseni). Doğrudan rota girişlerinde
  /// `false` kalır.
  final bool energyConsumed;

  final bool prototypeVisualState;

  @override
  State<BalloonPopScreen> createState() => _BalloonPopScreenState();
}

class _BalloonPopScreenState extends State<BalloonPopScreen>
    with SingleTickerProviderStateMixin {
  static const int cols = 7;
  static const int rows = 9;
  static const int kinds = 4;
  static const int fillRows = 4;
  static const int minPop = 3;
  static const int descendEvery = 8;
  static const double shotSpeed = 760;
  final _rng = Random();
  late List<List<int>> _grid;
  int _score = 0;
  int _best = 0;
  int _shots = 0;
  int _current = 1;
  int _next = 2;
  bool _flying = false;
  bool _over = false;
  bool _resultShown = false;
  bool _paused = false;

  /// Hamle bayrağı (enerji iadesi): oturum boyunca ilk atış (`_fire`)
  /// veya tur tamamlanması (`_lose`) ile `true` olur; TEKRAR/yeniden
  /// başlatmada SIFIRLANMAZ (Suika `_dropsMade` deseni — oturum ömrü;
  /// `_shots` `_boot` ile sıfırlanır, bu bayrak sıfırlanmaz).
  bool _moveMade = false;

  /// Çift-iade koruması: iade bu oturumda en fazla bir kez yapılır.
  bool _energyRefunded = false;

  bool _shotArmed = false;
  String _hint = 'balonlar süzülüyor · 3 aynı balon patlar';
  Offset? _fly;
  Offset _vel = Offset.zero;
  Offset _aim = const Offset(0, -1);

  // Combo / stats
  int _streak = 0;
  int _maxStreak = 0;
  int _popTotal = 0;
  int _fallTotal = 0;
  int _biggestPop = 0;
  double _comboMeter = 0;
  double _elapsed = 0;
  String? _milestone;
  String? _comboText;
  String? _gainText;
  Timer? _comboTimer;
  Timer? _milestoneTimer;
  final Set<int> _milestonesHit = {};
  final List<_PopFx> _popFx = [];
  final List<_FallingBubble> _fallingBubbles = [];
  double _dangerPulse = 0;
  bool _missFlash = false;
  Timer? _missTimer;
  String? _activePowerFx;
  double _powerFxLife = 0;

  Ticker? _ticker;
  Duration _last = Duration.zero;
  _Hex? _hex;

  bool _pierce = false;
  DateTime? _slowUntil;

  static const List<Color> _pastelColors = [
    Color(0xFFFFE9C9),
    Color(0xFFFFE3D6),
    Color(0xFFE4F0FF),
    Color(0xFFF3E4FF),
    Color(0xFFFFE0EC),
    Color(0xFFDFF7EA),
    Color(0xFFFFF0D6),
    Color(0xFFE8ECF5),
  ];

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _boot();
    if (widget.prototypeVisualState) {
      _score = 1940;
      _best = 3260;
      _elapsed = 42;
      _hint = 'balonlar süzülüyor · bir sıra daha indi';
    } else {
      _ensureDefaultPowers();
      _loadBest();
    }
    _ticker = createTicker(_tick)..start();
  }

  // Varsayılan stok YALNIZ ilk kurulumda verilir. ProgressManager.load()
  // 'lululu_power_seed_v1' bayrağıyla 33 gücü bir kez tohumlar; tohumlanan
  // anahtarlar extraPowers'ta kalıcı olur, takePower() ise anahtarı silmez,
  // 0'a düşürür. "Hiç tohumlanmadı" bu yüzden anahtar yokluğuyla anlaşılır;
  // eski "üçü de 0 ise doldur" koşulu her girişte bedava stok veriyordu.
  // Tohumlama persistBoosters() ile kalıcı kaydedilir.
  void _ensureDefaultPowers() {
    final pm = ProgressManager();
    const defaults = <String, int>{'triple': 3, 'bombb': 2, 'slowb': 1};
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
    _ticker?.dispose();
    _milestoneTimer?.cancel();
    _comboTimer?.cancel();
    _missTimer?.cancel();
    unawaited(_persist());
    super.dispose();
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best = LeaderboardService.instance.getBest(
        LeaderboardService.modeBalloon,
      );
    });
  }

  Future<void> _persist() async {
    if (_score <= 0) return;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeBalloon,
      _score,
    );
  }

  void _boot() {
    _grid = List.generate(rows, (_) => List.filled(cols, 0));
    _score = 0;
    _shots = 0;
    _flying = false;
    _over = false;
    _paused = false;
    _shotArmed = false;
    _hint = 'balonlar süzülüyor · 3 aynı balon patlar';
    _fly = null;
    _streak = 0;
    _maxStreak = 0;
    _popTotal = 0;
    _fallTotal = 0;
    _biggestPop = 0;
    _comboMeter = 0;
    _elapsed = 0;
    _milestonesHit.clear();
    _milestone = null;
    _comboText = null;
    _gainText = null;
    _popFx.clear();
    _fallingBubbles.clear();
    _activePowerFx = null;
    _powerFxLife = 0;
    _missFlash = false;
    _dangerPulse = 0;
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
      _elapsed += dt;
      _comboMeter = max(0, _comboMeter - dt * 0.18);
      if (_popFx.isNotEmpty) {
        for (final fx in _popFx) {
          fx.life -= dt * 6;
        }
        _popFx.removeWhere((f) => f.life <= 0);
        dirty = true;
      }
      if (_fallingBubbles.isNotEmpty) {
        for (final fb in _fallingBubbles) {
          fb.vel += Offset(0, 520 * dt);
          fb.pos += fb.vel * dt;
          fb.life -= dt * 1.6;
        }
        _fallingBubbles.removeWhere((fb) => fb.life <= 0);
        dirty = true;
      }
      if (_powerFxLife > 0) {
        _powerFxLife = max(0, _powerFxLife - dt * 1.4);
        if (_powerFxLife <= 0) _activePowerFx = null;
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
    // Enerji iadesi sayacı: atış anında sayılır (Suika deseni).
    _moveMade = true;
    _shotArmed = true;
    _fly = hex.shooter;
    _vel = _aim * shotSpeed;
    _flying = true;
    AudioManager().playDrop();
    AudioManager().triggerHaptic();
    setState(() {});
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
    final slowed = _slowUntil != null && DateTime.now().isBefore(_slowUntil!);
    if (slowed) dt *= 0.45;
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
      final ceiling = pos.dy <= hex.ceilingY;
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
    // Delici atış (r, c)'yi de siler; _popFrom(r, c) bu yüzden 0 döner.
    // Komşu gruplar ayrıca denetlenir, seri korunur (bkz. _popNeighborGroups).
    var pierced = 0;
    if (_pierce) {
      _pierce = false;
      for (final cell in <(int, int)>[(r, c), ..._neighbors(r, c)]) {
        if (pierced >= 3) break;
        if (_grid[cell.$1][cell.$2] == 0) continue;
        _grid[cell.$1][cell.$2] = 0;
        pierced++;
      }
      _score += pierced * 40;
      _popTotal += pierced;
      if (_score > _best) _best = _score;
      _checkScoreMilestones();
    }
    var popped = _popFrom(r, c);
    if (pierced > 0) popped += _popNeighborGroups(r, c);
    final fallen = _dropFloaters();
    var gained = 0;
    if (popped >= minPop) {
      _streak++;
      if (_streak > _maxStreak) _maxStreak = _streak;
      _popTotal += popped;
      if (popped > _biggestPop) _biggestPop = popped;
      final heat =
          1.0 + min(1.2, (_streak - 1) * 0.18) + min(0.6, (popped - 3) * 0.12);
      gained += (popped * popped * 14 * shotTier * heat).round();
      _comboMeter = min(1.0, 0.35 + _streak * 0.14 + popped * 0.04);
      if (popped >= 6) _showMilestone('SÜPER PATLAMA · $popped');
    } else if (pierced == 0) {
      if (_streak > 1) _showMilestone('KOMBO KIRILDI · ıskaladın');
      _streak = 0;
      _comboMeter = max(0, _comboMeter - 0.2);
    }
    // pierced > 0 ve grup yoksa: delici atış balon temizledi, seri korunur
    // (sıfırlanmaz, artmaz); "KOMBO KIRILDI" gösterilmez.
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
      _comboTimer?.cancel();
      _comboText = _streak >= 2 ? 'COMBO X$_streak!' : null;
      _gainText = '+$gained X${max(1, _streak)}';
      _comboTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _comboText = null;
            _gainText = null;
          });
        }
      });
      _hint = fallen > 0
          ? '${insect.viralReplik} +$gained · x$_streak'
          : 'Patladı x$_streak · +$gained';
    } else if (pierced > 0) {
      HapticFeedback.selectionClick();
      _hint = 'Delici atış $pierced balonu deldi · seri x$_streak korundu.';
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
    final nearCeiling = pos.dy < hex.ceilingY + hex.cell * 0.85;
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
        _popFx.add(_PopFx(center: hex.center(gr, gc), tier: tier, life: 1));
      }
      _grid[gr][gc] = 0;
    }
    return group.length;
  }

  /// Delici atış sonrası komşulardaki 3+ grupları patlatır. Her komşu
  /// _popFrom ile denetlenir; aynı grup iki kez sayılmaz çünkü ilk patlama
  /// hücreleri siler, sonraki denetim tier==0 görüp 0 döner.
  int _popNeighborGroups(int r, int c) {
    var total = 0;
    for (final (nr, nc) in _neighbors(r, c)) {
      total += _popFrom(nr, nc);
    }
    return total;
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
    final hex = _hex;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] != 0 && !anchored.contains((r, c))) {
          if (hex != null) {
            _fallingBubbles.add(
              _FallingBubble(
                pos: hex.center(r, c),
                vel: Offset(
                  (_rng.nextDouble() - 0.5) * 90,
                  -35 - _rng.nextDouble() * 45,
                ),
                tier: _grid[r][c],
                life: 1.0,
              ),
            );
          }
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
    // Tur tamamlandı: iade hakkı biter (bayrak oturum ömründe kalır).
    _moveMade = true;
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
    final count = _pierce ? 28 : (_streak >= 3 ? 22 : 18);
    for (var i = 0; i < count; i++) {
      p += v * (hex.cell * 0.48);
      if (p.dx < pad) {
        p = Offset(pad, p.dy);
        v = Offset(v.dx.abs(), v.dy);
      } else if (p.dx > hex.width - pad) {
        p = Offset(hex.width - pad, p.dy);
        v = Offset(-v.dx.abs(), v.dy);
      }
      if (p.dy < hex.ceilingY) break;
      if (_nearOccupied(p, hex)) {
        dots.add(p);
        if (!_pierce) break;
      }
      dots.add(p);
    }
    return dots;
  }

  /// Oyun sonu: yeni sonuç ekranı. "TEKRAR OYNA" aynı turu başlatır,
  /// "ANA SAYFA"da eski TAŞTI akışı devam eder (bozulmadı).
  bool _useTriple() {
    if (_over) return false;
    HapticFeedback.mediumImpact();
    AudioManager().playMerge(tierNumber: _current);
    setState(() {
      _pierce = true;
      _activePowerFx = 'triple';
      _powerFxLife = 1.0;
      _hint = 'Üçlü Ok / Lazer Nişan aktif · 3 balonu deler!';
    });
    _showMilestone('ÜÇLÜ OK · LAZER NİŞAN AKTİF!');
    return true;
  }

  bool _useBomb() {
    if (_over) return false;
    final spots = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] != 0) spots.add((r, c));
      }
    }
    if (spots.isEmpty) return false;
    spots.shuffle(_rng);
    final hex = _hex;
    HapticFeedback.heavyImpact();
    AudioManager().playMerge(tierNumber: min(8, _current + 1));
    setState(() {
      final take = min(8, spots.length);
      for (var i = 0; i < take; i++) {
        final (r, c) = spots[i];
        final t = _grid[r][c];
        if (hex != null && t > 0) {
          _popFx.add(_PopFx(center: hex.center(r, c), tier: t, life: 1.0));
        }
        _grid[r][c] = 0;
      }
      final fallen = _dropFloaters();
      final gained = take * 30 + fallen * 50;
      _score += gained;
      if (_score > _best) _best = _score;
      _popTotal += take;
      _fallTotal += fallen;
      _activePowerFx = 'bombb';
      _powerFxLife = 1.0;
      _gainText = '+$gained BOMBA!';
      _hint = 'Ateş Topu / Bomba $take balonu uçurdu!';
      _checkScoreMilestones();
    });
    _showMilestone('ATEŞ TOPU · BOMBA PATLADI!');
    return true;
  }

  bool _useSlow() {
    if (_over) return false;
    final hex = _hex;
    HapticFeedback.mediumImpact();
    AudioManager().playMerge(tierNumber: _current);
    setState(() {
      _slowUntil = DateTime.now().add(const Duration(seconds: 10));
      var cleared = 0;
      for (var r = rows - 1; r >= 0 && cleared < 4; r--) {
        for (var c = 0; c < cols && cleared < 4; c++) {
          if (_grid[r][c] == _current) {
            if (hex != null) {
              _popFx.add(
                _PopFx(center: hex.center(r, c), tier: _current, life: 1.0),
              );
            }
            _grid[r][c] = 0;
            cleared++;
          }
        }
      }
      final fallen = cleared > 0 ? _dropFloaters() : 0;
      if (cleared > 0 || fallen > 0) {
        final gained = cleared * 35 + fallen * 50;
        _score += gained;
        if (_score > _best) _best = _score;
        _popTotal += cleared;
        _fallTotal += fallen;
        _checkScoreMilestones();
      }
      _activePowerFx = 'slowb';
      _powerFxLife = 1.0;
      _hint = 'Renk Dalgası & Yavaşlatma (10 sn) aktif!';
    });
    _showMilestone('YAVAŞLAT & RENK BOMBASI AKTİF!');
    return true;
  }

  Future<void> _presentResult() async {
    // S1#49: ödeme + mod skoru + liderlik + görev kaydı + sonuç ekranı
    // finishRun() üzerinden (tek-ödeme korunur).
    final replay = await finishRun(
      context,
      score: _score,
      best: _best,
      leaderboardMode: LeaderboardService.modeBalloon,
      modeScoreId: 'balloon_pop',
    );
    if (!mounted) return;
    if (!replay) {
      Navigator.of(context).maybePop();
      return;
    }
    _resultShown = false;
    setState(_boot);
  }

  /// Hamlesiz-çıkış enerji iadesi (tek çıkış noktası: `PopScope`).
  ///
  /// Yalnız giriş enerjisi tüketildiyse, tur tamamlanmadıysa ve oturum
  /// boyunca hiç hamle yapılmadıysa 1 enerji iade edilir. `dispose`
  /// içinde DEĞİL, yalnızca gerçek rota çıkışında (`didPop`) çağrılır.
  void _maybeRefundEnergy() {
    if (_energyRefunded) return;
    if (!widget.energyConsumed || _moveMade || _over || _resultShown) {
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
    final until = descendEvery - (_shots % descendEvery);
    if (_over && !_resultShown) _edgeShowResult();
    final bonusItems = [
      stockBonusWithResult(
        id: 'triple',
        label: 'ÜÇLÜ OK',
        asset: 'assets/icons2/target.png',
        effect: () {
          final applied = _useTriple();
          setState(() {});
          return applied;
        },
      ),
      stockBonusWithResult(
        id: 'bombb',
        label: 'BOMBA',
        asset: 'assets/icons2/boom.png',
        effect: () {
          final applied = _useBomb();
          setState(() {});
          return applied;
        },
      ),
      stockBonusWithResult(
        id: 'slowb',
        label: 'YAVAŞLAT',
        asset: 'assets/icons2/stopwatch.png',
        effect: () {
          final applied = _useSlow();
          setState(() {});
          return applied;
        },
      ),
    ];
    final stageChild = widget.prototypeVisualState
        ? const _PrototypeBalloonField()
        : LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 430.0;
              final maxH = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 693.5;
              final hex = _Hex(maxW, maxH);
              _hex = hex;
              final dots = (_flying || _paused)
                  ? const <Offset>[]
                  : _aimDots(hex);
              final aimAngle = atan2(_aim.dx, -_aim.dy);
              return SizedBox(
                width: maxW,
                height: maxH,
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
                    clipBehavior: Clip.hardEdge,
                    children: [
                      // 1. ceiling-bar (0..30)
                      Positioned(
                        left: 0,
                        top: 0,
                        right: 0,
                        height: 30,
                        child: CustomPaint(
                          painter: const _CeilingBorderPainter(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TAVAN',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    height: 1.55,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.88,
                                    color: const Color(0xFFFFB3B3),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _paused
                                        ? 'DURAKLATILDI'
                                        : '$_hint · $until atışta sıra iner',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.nunito(
                                      fontSize: 11,
                                      height: 1.55,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.88,
                                      color: const Color(0xFFFFB3B3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 2. Danger line — bottom 2 rows lose zone.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: hex.center(rows - 2, 0).dy - hex.cell * 0.42,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: (0.28 +
                                    0.2 * sin(_dangerPulse) +
                                    (_fillDepth() * 0.35))
                                .clamp(0.18, 0.85),
                            child: const ColoredBox(
                              color: Color(0x66E52E2E),
                              child: SizedBox(height: 1.5),
                            ),
                          ),
                        ),
                      ),
                      // 3. Trajectory dots when aiming
                      for (var i = 0; i < dots.length; i++)
                        if (i.isEven)
                          Positioned(
                            left: dots[i].dx - (_pierce ? 2.5 : 1.5),
                            top: dots[i].dy - 4,
                            child: Transform.rotate(
                              angle: aimAngle,
                              child: Container(
                                width: _pierce ? 5 : 3,
                                height: 7,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: _pierce
                                      ? const Color(0xFF00E5FF)
                                      : const Color(0xE6FFD700),
                                ),
                              ),
                            ),
                          ),
                      // 4. Grid balloons (prototype oval + overflowing bug image)
                      for (var r = 0; r < rows; r++)
                        for (var c = 0; c < cols; c++)
                          if (_grid[r][c] != 0)
                            _bubble(
                              hex.center(r, c),
                              hex.cell,
                              _grid[r][c],
                              angle: sin(
                                    _dangerPulse * 0.35 + r * 1.3 + c * 0.9,
                                  ) *
                                  0.026,
                            ),
                      // 5. Falling detached balloons
                      for (final fb in _fallingBubbles)
                        Positioned(
                          left: fb.pos.dx - hex.cell * 0.44,
                          top: fb.pos.dy - hex.cell * 0.5,
                          child: Opacity(
                            opacity: fb.life.clamp(0.0, 1.0),
                            child: _bubbleFace(hex.cell * 0.96, fb.tier),
                          ),
                        ),
                      // 6. Pop burst FX (uses prototype boom.png)
                      for (final fx in _popFx)
                        Positioned(
                          left: fx.center.dx -
                              hex.cell * (0.95 - 0.35 * fx.life),
                          top: fx.center.dy -
                              hex.cell * (0.95 - 0.35 * fx.life),
                          width: hex.cell * (1.9 - 0.7 * fx.life),
                          height: hex.cell * (1.9 - 0.7 * fx.life),
                          child: Opacity(
                            opacity: fx.life.clamp(0.0, 1.0),
                            child: Image.asset(
                              'assets/icons2/boom.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      // 7. Powerup shockwave ring
                      if (_activePowerFx != null && _powerFxLife > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: Opacity(
                                opacity: _powerFxLife.clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: 1.5 - 0.5 * _powerFxLife,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _activePowerFx == 'triple'
                                            ? const Color(0xFF00E5FF)
                                            : _activePowerFx == 'bombb'
                                            ? const Color(0xFFFF6B35)
                                            : const Color(0xFF72C6FF),
                                        width: 5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 8. Shooter zone top 1px border
                      Positioned(
                        left: 0,
                        right: 0,
                        top: hex.shooterZoneTop,
                        height: 1,
                        child: const ColoredBox(color: Color(0x17FFFFFF)),
                      ),
                      // 9. Yellow dashed aim line inside shooter zone
                      Positioned(
                        left: hex.shooter.dx - 1.5,
                        top: hex.shooter.dy - 4.5 - 120,
                        width: 3,
                        height: 120,
                        child: Transform.rotate(
                          angle: aimAngle,
                          alignment: Alignment.bottomCenter,
                          child: const CustomPaint(painter: _DashPainter()),
                        ),
                      ),
                      // 10. Flying shot balloon
                      if (_fly != null) _bubble(_fly!, hex.cell, _current),
                      // 11. Shooter balloon (46x54 prototype oval)
                      Positioned(
                        left: hex.shooter.dx - 23,
                        top: hex.shooter.dy - 27,
                        child: _bubbleFace(
                          54,
                          _current,
                          aimed: true,
                          miss: _missFlash,
                        ),
                      ),
                      // 12. Shooter label (TUT · NİŞAN AL · BIRAK)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: hex.shooter.dy + 29,
                        child: IgnorePointer(
                          child: Text(
                            _pierce
                                ? 'LAZER NİŞAN AKTİF'
                                : 'TUT · NİŞAN AL · BIRAK',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              height: 1.55,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: _pierce
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF8E9CAE),
                            ),
                          ),
                        ),
                      ),
                      // 13. Combo & Score floating texts (prototype Bangers glow)
                      if (_comboText != null)
                        Positioned(
                          left: 12,
                          top: maxH * 0.32,
                          child: IgnorePointer(
                            child: Text(
                              _comboText!,
                              style: _PrototypeBalloonField._comboStyle(23),
                            ),
                          ),
                        ),
                      if (_gainText != null)
                        Positioned(
                          right: 16,
                          top: maxH * 0.49,
                          child: IgnorePointer(
                            child: Text(
                              _gainText!,
                              style: _PrototypeBalloonField._comboStyle(24),
                            ),
                          ),
                        ),
                      if (_milestone != null)
                        Positioned(
                          top: 38,
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
              );
            },
          );

    final overlayWidget = (_over && !_resultShown)
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
        : null;

    final timeStr =
        '${_elapsed ~/ 60}:${(_elapsed.floor() % 60).toString().padLeft(2, '0')}';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _maybeRefundEnergy();
      },
      child: _buildBalloonPrototypeChrome(
        context: context,
        timeStr: timeStr,
        stageChild: stageChild,
        overlayWidget: overlayWidget,
        bonusItems: bonusItems,
        until: until,
      ),
    );
  }

  static String _fmtDot(int v) {
    final s = v.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return v < 0 ? '-$buf' : buf.toString();
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

  Widget _buildBalloonPrototypeChrome({
    required BuildContext context,
    required String timeStr,
    required Widget stageChild,
    required Widget? overlayWidget,
    required List<ModeBonus> bonusItems,
    required int until,
  }) {
    final screenW = MediaQuery.sizeOf(context).width;
    final topPad = MediaQuery.paddingOf(context).top;
    final useHostTopInset = !widget.prototypeVisualState && topPad > 0;
    final coinsText = widget.prototypeVisualState
        ? '12.450'
        : _fmtDot(ProgressManager().coins);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: MediaQuery.withNoTextScaling(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.96,
                child: Image.asset(
                  'assets/design/backgrounds/balloon_fair.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.24, 0.76, 1.0],
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. statusbar (height: 35.4 in prototype/headless, topPad on real device)
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
                          top: 16.0,
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
                            painter: _BalloonStatusIconsPainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 2. mode-top (height: 56.3)
                _scaleBand(
                  screenW,
                  56.3,
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 12,
                        top: 7.1,
                        width: 44.4,
                        height: 48,
                        child: Semantics(
                          button: true,
                          label: context.l10n.goBackLabel,
                          child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).maybePop(),
                          child: CustomPaint(
                            painter: const _CssBoxPainter(
                              fillColor: Color(0xD9080B12),
                              radius: 14,
                              shadowColor: Color(0x73000000),
                              shadowOffset: Offset(0, 3),
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/icons2/back-prototype.png',
                                width: 29,
                                height: 29,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                        ),
                      ),
                      Positioned(
                        left: 66.4,
                        top: 6.0,
                        width: 153.6,
                        height: 27,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0x8C080B12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'BALON PATLAT',
                                maxLines: 1,
                                softWrap: false,
                                style: GoogleFonts.baloo2(
                                  fontSize: 20,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.0,
                                  color: Colors.white,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xA6000000),
                                      offset: Offset(0, 2),
                                      blurRadius: 6,
                                    ),
                                    Shadow(
                                      color: Color(0xCC000000),
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 66.4,
                        top: 36.0,
                        width: 55.5,
                        height: 20.3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Center(
                            child: Transform.translate(
                              offset: const Offset(0, -1),
                              child: Text(
                                'BONUS',
                                style: GoogleFonts.baloo2(
                                  fontSize: 10.5,
                                  height: 1.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.735,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 274.4,
                        top: 13.6,
                        width: 85.6,
                        height: 35,
                        child: CustomPaint(
                          painter: const _CssBoxPainter(
                            fillColor: Color(0xD1080B12),
                            radius: 17.5,
                            shadowColor: Color(0x59000000),
                            shadowOffset: Offset(0, 3),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icons2/coin.png',
                                  width: 25,
                                  height: 25,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Transform.translate(
                                    offset: const Offset(0, -1.5),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        coinsText,
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
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
                      ),
                      Positioned(
                        left: 370,
                        top: 7.1,
                        width: 48,
                        height: 48,
                        child: CustomPaint(
                          painter: const _CssBoxPainter(
                            fillColor: Color(0xDB080B12),
                            radius: 24,
                            borderColor: Color(0xB3FFB800),
                            borderWidth: 2,
                            shadowColor: Color(0x66000000),
                            shadowOffset: Offset(0, 3),
                          ),
                          child: Center(
                            child: Text(
                              '?',
                              style: GoogleFonts.baloo2(
                                fontSize: 22,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFFB800),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 3. game-hud (height: 54.0)
                _scaleBand(
                  screenW,
                  54.0,
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 10,
                        top: 9.3,
                        width: 64.6,
                        height: 41.0,
                        child: _buildHudStatBox(
                          label: 'SKOR',
                          value: _fmtDot(_score),
                        ),
                      ),
                      Positioned(
                        left: 80.6,
                        top: 9.3,
                        width: 84,
                        height: 41.0,
                        child: _buildHudStatBox(
                          label: 'REKOR',
                          value: _fmtDot(_best),
                        ),
                      ),
                      Positioned(
                        left: 282.2,
                        top: 9.3,
                        width: 74,
                        height: 41.0,
                        child: _buildHudStatBox(
                          label: 'SÜRE',
                          value: timeStr,
                        ),
                      ),
                      Positioned(
                        left: 362.2,
                        top: 5.9,
                        width: 57.8,
                        height: 48,
                        child: Semantics(
                          button: true,
                          label: context.l10n.finishRoundLabel,
                          child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(_boot),
                          child: DecoratedBox(
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
                            child: Center(
                              child: Text(
                                'BİTİR',
                                style: GoogleFonts.baloo2(
                                  fontSize: 12.5,
                                  height: 1.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.375,
                                  color: const Color(0xFF4A2E00),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 4. mode-stage (margin top: 8, height: 697.5)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x660E1422), Color(0x800E1422)],
                      ),
                      border: Border.symmetric(
                        horizontal: BorderSide(
                          color: Color(0x24FFFFFF),
                          width: 2,
                        ),
                      ),
                    ),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
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
                ),
                // 5. power-dock (height: 80.9)
                SizedBox(
                  height: 80.9,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < bonusItems.length; i++) ...[
                          if (i > 0) const SizedBox(width: 20),
                          _buildPowerButton(
                            item: bonusItems[i],
                            prototypeCount: const [3, 2, 1][i],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
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
    double valueDx = 0.0,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9080B12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x73FFB800), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
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
                overflow: TextOverflow.visible,
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  height: 1.55,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.72,
                  color: const Color(0xFFFFB800),
                ),
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: Offset(valueDx, -0.3),
                  child: Text(
                    value,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.baloo2(
                      fontSize: 17,
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
      ),
    );
  }

  Widget _buildPowerButton({
    required ModeBonus item,
    required int prototypeCount,
  }) {
    final count = widget.prototypeVisualState ? prototypeCount : item.count;
    return Semantics(
      button: true,
      label: context.l10n.boosterCountLabel(item.label, count),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.onTap,
        child: SizedBox(
          width: 66,
          height: 62.9,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
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
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF333F58), Color(0xFF1B2336)],
                    ),
                    border: Border.all(
                      color: const Color(0x47FFFFFF),
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
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              Positioned(
                left: 41,
                top: -2,
                width: 22,
                height: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE01E5A),
                    border: Border.all(
                      color: const Color(0xFF080B12),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
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
      );
    );
  }

  static const _tierAspects = <double>[
    2333 / 874,
    1761 / 893,
    1435 / 1282,
    1457 / 1307,
    2157 / 1072,
    1808 / 871,
    1626 / 1003,
    1.2,
  ];

  Widget _bubble(Offset center, double cell, int tier, {double angle = 0.0}) {
    final h = cell * 0.98;
    final w = h * 0.865;
    return Positioned(
      left: center.dx - w / 2,
      top: center.dy - h / 2,
      child: Transform.rotate(
        angle: angle,
        child: _bubbleFace(h, tier),
      ),
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
    final idx = (tier - 1).clamp(0, 7);
    final pastel = _pastelColors[idx];
    final h = size;
    final w = aimed ? (size * (46.0 / 54.0)) : (size * 0.865);
    final aspect = _tierAspects[idx];
    final rowH = max(h, 0.72 * w * aspect);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BalloonShapePainter(
                tint: miss ? const Color(0xFFFFB3B3) : pastel,
              ),
            ),
          ),
          Positioned(
            left: 0.14 * w,
            top: 0.14 * rowH,
            width: 0.72 * w,
            height: 0.72 * rowH,
            child: Image.asset(
              'assets/bugs/tier${idx + 1}_hd${(idx + 1) == 5 ? '.webp' : '.png'}',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ],
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

class _FallingBubble {
  _FallingBubble({
    required this.pos,
    required this.vel,
    required this.tier,
    required this.life,
  });
  Offset pos;
  Offset vel;
  final int tier;
  double life;
}

class _Hex {
  _Hex(this.width, [double? stageHeight])
    : cell = width / 7.6,
      totalHeight = stageHeight ?? (width / 7.6) * 9.5;

  final double width;
  final double cell;
  final double totalHeight;

  double get shooterZoneH => min(104.0, totalHeight * 0.22);

  double get shooterZoneTop => totalHeight - shooterZoneH;

  double get ceilingY => 30.0 + cell * 0.45;

  double get _rowStep {
    final avail = max(cell * 4.5, shooterZoneTop - 30.0 - cell);
    return min(cell * 0.90, avail / 8.0);
  }

  double get boardHeight => shooterZoneTop;

  Offset center(int r, int c) {
    final leftPad = (width - 7.5 * cell) * 0.5;
    final x = leftPad + cell * (c + (r.isOdd ? 1.0 : 0.5));
    final y = 30.0 + cell * 0.55 + r * _rowStep;
    return Offset(x, y);
  }

  Offset get shooter => Offset(width / 2, totalHeight - shooterZoneH * 0.52);
}

/// Deterministic mid-game scene that mirrors the HTML prototype (capture only).
class _PrototypeBalloonField extends StatelessWidget {
  const _PrototypeBalloonField();

  static const double _stageTopY = 155.6;

  // (left, top, w, h, imgLeft, imgTop, imgW, imgH, tier, deg)
  static const _specs =
      <(
        double,
        double,
        double,
        double,
        double,
        double,
        double,
        double,
        int,
        double,
      )>[
        (12.85, 204.45, 54.0, 62.0, 20.41, 213.08, 38.88, 44.64, 3, -0.292),
        (86.00, 196.90, 48.0, 56.0, 93.12, 209.79, 34.56, 66.42, 1, -1.444),
        (163.40, 213.90, 56.0, 64.0, 171.19, 222.81, 40.32, 46.08, 4, 0.000),
        (245.05, 201.30, 47.0, 55.0, 252.08, 213.83, 33.84, 65.04, 1, -1.205),
        (322.50, 213.90, 55.0, 63.0, 330.20, 222.72, 39.60, 45.36, 3, 0.000),
        (387.00, 201.80, 46.0, 54.0, 393.39, 211.11, 33.12, 47.98, 5, 0.000),
        (38.70, 325.70, 50.0, 58.0, 45.70, 335.69, 36.00, 51.11, 2, 0.000),
        (116.05, 312.80, 57.0, 65.0, 124.18, 324.32, 41.04, 59.46, 5, -0.971),
        (197.80, 314.30, 58.0, 64.0, 200.10, 316.90, 53.40, 58.90, 2, 0.000),
        (283.75, 320.15, 58.0, 66.0, 292.22, 332.24, 41.76, 62.41, 6, -1.498),
        (361.20, 330.90, 50.0, 58.0, 368.20, 340.89, 36.00, 51.11, 2, 0.000),
        (17.20, 448.80, 52.0, 60.0, 24.48, 462.77, 37.44, 71.96, 1, 0.000),
        (94.65, 436.50, 47.0, 55.0, 101.18, 444.15, 33.84, 39.60, 3, -1.356),
        (176.30, 453.75, 56.0, 64.0, 184.09, 462.82, 40.32, 47.06, 7, 0.000),
        (258.00, 440.50, 48.0, 56.0, 264.72, 448.29, 34.56, 40.32, 3, -0.683),
        (339.70, 454.20, 54.0, 62.0, 347.31, 468.69, 38.88, 74.72, 1, 0.000),
        (391.30, 436.90, 45.0, 53.0, 397.60, 444.32, 32.40, 38.16, 4, 0.000),
        (60.25, 555.05, 49.0, 57.0, 67.01, 563.03, 35.28, 41.04, 4, -1.484),
        (141.90, 565.90, 53.0, 61.0, 149.32, 580.18, 38.16, 73.34, 1, 0.000),
        (223.55, 554.35, 47.0, 55.0, 230.28, 563.89, 33.84, 49.03, 5, -1.199),
        (305.30, 565.65, 52.0, 60.0, 312.58, 575.92, 37.44, 53.16, 2, 0.000),
      ];

  static const _tints = <Color>[
    Color(0xFFFFE9C9),
    Color(0xFFFFE3D6),
    Color(0xFFE4F0FF),
    Color(0xFFF3E4FF),
    Color(0xFFFFE0EC),
    Color(0xFFDFF7EA),
    Color(0xFFFFF0D6),
    Color(0xFFE8ECF5),
  ];

  static const _glow = [
    Shadow(color: Color(0x52FF6B35), blurRadius: 54),
    Shadow(color: Color(0x8CFF6B35), blurRadius: 32),
    Shadow(color: Color(0xE6FF6B35), blurRadius: 14),
    Shadow(color: Color(0xEB080B12), offset: Offset(0, 3)),
  ];

  static TextStyle _comboStyle(double size) => GoogleFonts.bangers(
    fontSize: size,
    letterSpacing: 0.6,
    height: 1,
    color: const Color(0xFFFFB800),
    shadows: _glow,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // 1. ceiling-bar (local y = 0..30)
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: 30,
          child: CustomPaint(
            painter: const _CeilingBorderPainter(),
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 6.0,
                  child: Text(
                    'TAVAN',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      height: 1.55,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.88,
                      color: const Color(0xFFFFB3B3),
                    ),
                  ),
                ),
                Positioned(
                  left: 186.5,
                  top: 6.0,
                  child: Text(
                    'balonlar süzülüyor · bir sıra daha indi',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      height: 1.55,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.88,
                      color: const Color(0xFFFFB3B3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 2. 21 balloons + burst boom at index 8
        for (var i = 0; i < _specs.length; i++)
          if (i == 8)
            Positioned(
              left: _specs[i].$5,
              top: _specs[i].$6 - _stageTopY,
              width: _specs[i].$7,
              height: _specs[i].$8,
              child: Image.asset(
                'assets/icons2/boom.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            )
          else ...[
            Positioned(
              left: _specs[i].$1,
              top: _specs[i].$2 - _stageTopY,
              width: _specs[i].$3,
              height: _specs[i].$4,
              child: Transform.rotate(
                angle: _specs[i].$10 * pi / 180,
                child: CustomPaint(
                  painter: _BalloonShapePainter(
                    tint: _tints[_specs[i].$9 - 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: _specs[i].$5,
              top: _specs[i].$6 - _stageTopY,
              width: _specs[i].$7,
              height: _specs[i].$8,
              child: Transform.rotate(
                angle: _specs[i].$10 * pi / 180,
                child: Image.asset(
                  'assets/bugs/tier${_specs[i].$9}_hd${_specs[i].$9 == 5 ? '.webp' : '.png'}',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ],
        // 3. COMBO X4!
        Positioned(
          left: 11.2,
          top: 375.2 - _stageTopY,
          child: Transform.rotate(
            angle: 0.65 * pi / 180,
            child: Transform.scale(
              scale: 94.5 / 91.5,
              alignment: Alignment.center,
              child: Text('COMBO X4!', style: _comboStyle(23)),
            ),
          ),
        ),
        // 4. +90 X4
        Positioned(
          left: 354.5,
          top: 497.3 - _stageTopY,
          child: Text('+90 X4', style: _comboStyle(24)),
        ),
        // 5. shooter-zone top border at y = 745.1 - 155.6 = 589.5
        const Positioned(
          left: 0,
          right: 0,
          top: 745.1 - _stageTopY,
          height: 1,
          child: ColoredBox(color: Color(0x17FFFFFF)),
        ),
        // 6. aim-line (bottom: 58 inside shooter-zone y=745.1..849.1 -> bottom at y=791.1)
        Positioned(
          left: 215 - 1.5,
          top: 791.1 - 120 - _stageTopY,
          width: 3,
          height: 120,
          child: Transform.rotate(
            angle: 24 * pi / 180,
            alignment: Alignment.bottomCenter,
            child: const CustomPaint(painter: _DashPainter()),
          ),
        ),
        // 7. shooter balloon (rect: 192, 768.6, 46, 54)
        Positioned(
          left: 192,
          top: 769.0 - _stageTopY,
          width: 46,
          height: 54,
          child: CustomPaint(
            painter: _BalloonShapePainter(tint: _tints[0]),
          ),
        ),
        // 8. shooter bug image (rect: 198.4, 781.0, 33.1, 63.6)
        Positioned(
          left: 198.4,
          top: 781.0 - _stageTopY,
          width: 33.1,
          height: 63.6,
          child: Image.asset(
            'assets/bugs/tier1_hd.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        // 9. shooter label (rect: 147.3, 825.6, 135.4, 15.5)
        Positioned(
          left: 147.3,
          top: 824.6 - _stageTopY,
          child: Text(
            'TUT · NİŞAN AL · BIRAK',
            style: GoogleFonts.nunito(
              fontSize: 10,
              height: 1.55,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: const Color(0xFF8E9CAE),
            ),
          ),
        ),
      ],
    );
  }
}

class _BalloonShapePainter extends CustomPainter {
  const _BalloonShapePainter({required this.tint});

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, w, h),
      topLeft: Radius.elliptical(w * 0.5, h * 0.55),
      topRight: Radius.elliptical(w * 0.5, h * 0.55),
      bottomLeft: Radius.elliptical(w * 0.5, h * 0.45),
      bottomRight: Radius.elliptical(w * 0.5, h * 0.45),
    );
    final outerPath = Path()..addRRect(rrect);
    canvas.save();
    canvas.clipPath(outerPath);
    canvas.drawPath(outerPath, Paint()..color = tint);

    final lightShadow = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(5, 7)),
    );
    canvas.drawPath(lightShadow, Paint()..color = const Color(0x59FFFFFF));

    final darkShadow = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(-6, -8)),
    );
    canvas.drawPath(darkShadow, Paint()..color = const Color(0x21000000));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BalloonShapePainter oldDelegate) =>
      oldDelegate.tint != tint;
}

class _CeilingBorderPainter extends CustomPainter {
  const _CeilingBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x38E52E2E),
    );
    final dashPaint = Paint()..color = const Color(0xCCE52E2E);
    for (var x = 0.0; x < size.width; x += 5.0) {
      canvas.drawRect(
        Rect.fromLTWH(x, size.height - 1.0, min(3.0, size.width - x), 1.0),
        dashPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xE6FFD700);
    for (var y = 0.0; y < size.height; y += 13.0) {
      final bottom = min(size.height, y + 7.0);
      canvas.drawRect(Rect.fromLTRB(0, y, size.width, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _BalloonStatusIconsPainter extends CustomPainter {
  const _BalloonStatusIconsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const sx = 15 / 24.0;
    const sy = 15 / 24.0;

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
      const Offset(12 * sx, 19 * sy),
      1.5 * sx,
      Paint()..color = Colors.white,
    );

    const bx = 20.0;
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(bx + 2 * sx, 7 * sy, 17 * sx, 10 * sy),
      const Radius.circular(2 * sx),
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
        const Rect.fromLTWH(bx + 4 * sx, 9 * sy, 11 * sx, 6 * sy),
        const Radius.circular(1 * sx),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRect(
      const Rect.fromLTWH(bx + 20 * sx, 10 * sy, 2 * sx, 4 * sy),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CssBoxPainter extends CustomPainter {
  const _CssBoxPainter({
    required this.fillColor,
    required this.radius,
    this.borderColor,
    this.borderWidth = 0,
    this.shadowColor,
    this.shadowOffset = Offset.zero,
  });

  final Color fillColor;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final Color? shadowColor;
  final Offset shadowOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final outerPath = Path()..addRRect(rrect);

    if (shadowColor != null) {
      final shadowPath = Path.combine(
        PathOperation.difference,
        outerPath.shift(shadowOffset),
        outerPath,
      );
      canvas.drawPath(shadowPath, Paint()..color = shadowColor!);
    }

    canvas.drawPath(outerPath, Paint()..color = fillColor);

    if (borderColor != null && borderWidth > 0) {
      final innerPath = Path()..addRRect(rrect.deflate(borderWidth));
      final borderRing = Path.combine(
        PathOperation.difference,
        outerPath,
        innerPath,
      );
      canvas.drawPath(borderRing, Paint()..color = borderColor!);
    }
  }

  @override
  bool shouldRepaint(covariant _CssBoxPainter oldDelegate) => false;
}
