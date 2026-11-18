import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/global_notify.dart';
import '../services/haptic_service.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/mode_bonus_bar.dart';

/// Drag through orthogonal neighbors of the same bug.
/// A loop (back to the start) clears every bug of that kind.
class ConnectPopScreen extends StatefulWidget {
  const ConnectPopScreen({
    super.key,
    this.energyConsumed = false,
    @visibleForTesting this.prototypeVisualState = false,
    @visibleForTesting this.gameplayTestState = false,
  });

  /// `true` ise bu ekrana giriş `openGameMode` üzerinden 1 enerji
  /// tüketerek yapıldı; hiç hamle yapılmadan çıkılırsa enerji iade
  /// edilir (Suika `GameScreen` deseni). Doğrudan rota girişlerinde
  /// `false` kalır.
  final bool energyConsumed;

  final bool prototypeVisualState;
  final bool gameplayTestState;

  @override
  State<ConnectPopScreen> createState() => _ConnectPopScreenState();
}

enum _ConnectHint {
  idle,
  refreshed,
  loopHint,
  groupHint,
  selectedOne,
  selectedCount,
  squareReady,
  longChain,
  minLink,
  squareHit,
  viral,
  bonusDrop,
  targetHit,
  linesOut,
  loseHint,
  chainExtender,
  bolt,
  magnet,
}

class _ConnectPopScreenState extends State<ConnectPopScreen>
    with WidgetsBindingObserver {
  int get rows => (widget.prototypeVisualState || widget.gameplayTestState) ? 6 : 8;
  static const int cols = 6;
  static const int maxKinds = 5;
  static const _tileColors = [
    Color(0xFFFFE9C9),
    Color(0xFFFFE3D6),
    Color(0xFFE4F0FF),
    Color(0xFFF3E4FF),
    Color(0xFFFFE0EC),
  ];

  /// Difficulty ramp: starts with 3 kinds, a new kind every 14 cleared bugs.
  int get kinds => kindsForCleared(_clearTotal);

  @visibleForTesting
  static int kindsForCleared(int cleared) => min(maxKinds, 3 + cleared ~/ 14);
  static const int minLen = 3;
  static const int startLines = 24;
  static const int target = 1600;

  final _rng = Random();
  late List<List<int>> _grid;
  int _score = 0;
  int _best = 0;
  int _lines = startLines;
  int _epoch = 0;

  /// Y3 tur kimliği: turun BAŞLANGIÇ damgası (ms cinsinden epoch).
  /// `initState` ve her `_newGame`'de bir kez yakalanır; aynı turun
  /// BİTİR + otomatik-bitiş yolları aynı `idempotencyKey`'i paylaşır,
  /// yeni tur yeni damga alır. Bitiş anında üretilmez (çift-sunumu
  /// engellemezdi).
  int _runStartStamp = 0;
  bool _busy = false;
  bool _won = false;
  bool _lost = false;
  bool _resultShown = false;
  bool _paused = false;

  /// Yaşam döngüsü (arka plan) duraklatması bayrağı (Osmantus deseni):
  /// `resumed` yalnız bu bayrak setliyken devam ettirir; elle
  /// duraklatma kullanıcının kararıyla sürer.
  bool _pausedByLifecycle = false;

  /// Yardım sayfası duraklatması bayrağı: sayfa kapanınca yalnız bu
  /// bayrak setliyken devam ettirilir (önceden elle duraklatıldıysa
  /// duraklatma sürer).
  bool _pausedByHowToPlay = false;

  /// N7 çıkış onayı durumu: onay bayrağı (diyalogda Çık seçildiyse
  /// `PopScope` çıkışı geçirir), çift-diyalog kilidi ve diyalog
  /// duraklatması bayrağı (yardım deseni: yalnız bu diyalog için
  /// duraklatıldıysa kapanınca devam edilir).
  bool _exitConfirmed = false;
  bool _exitConfirmShowing = false;
  bool _pausedForExitConfirm = false;

  /// Hamle bayrağı (enerji iadesi): oturum boyunca ilk geçerli zincir
  /// (`_commit`, en az `minLen` hücre) veya tur tamamlanması
  /// (`_endCheck`) ile `true` olur; TEKRAR/yeniden başlatmada
  /// SIFIRLANMAZ (Suika `_dropsMade` deseni — oturum ömrü).
  bool _moveMade = false;

  /// Çift-iade koruması: iade bu oturumda en fazla bir kez yapılır.
  bool _energyRefunded = false;

  /// Çıkış-sonrası iade bildirimi (S6): `PopScope` `didPop` anında
  /// bağlam artık ağaçta değildir; bildirim metni her `build`'de
  /// ÖNCEDEN yakalanır ve iade gerçekten verildiğinde paylaşılan
  /// `GlobalNotify` üzerinden çıkış yapılan ekranın üstünde
  /// gösterilir (balon/stack deseninin paylaşılan karşılığı).
  String? _refundNotice;

  bool _loop = false;
  int _paint = 0;
  final List<Point<int>> _path = [];
  final Set<Point<int>> _pathSet = {};
  _ConnectHint _hintKind = _ConnectHint.idle;
  int _hintA = 0;
  int _hintB = 0;
  int _hintC = 0;
  String _hintText = '';

  void _setHint(
    _ConnectHint kind, {
    int a = 0,
    int b = 0,
    int c = 0,
    String text = '',
  }) {
    _hintKind = kind;
    _hintA = a;
    _hintB = b;
    _hintC = c;
    _hintText = text;
  }

  String _hintString(AppLocalizations l10n) => switch (_hintKind) {
        _ConnectHint.idle => l10n.connectHintIdle,
        _ConnectHint.refreshed => l10n.connectBoardRefreshed,
        _ConnectHint.loopHint => l10n.connectLoopHint,
        _ConnectHint.groupHint => l10n.connectGroupHint,
        _ConnectHint.selectedOne => l10n.connectSelectedOne(_hintA),
        _ConnectHint.selectedCount => l10n.connectSelectedCount(_hintA),
        _ConnectHint.squareReady => l10n.connectLoopReady,
        _ConnectHint.longChain => l10n.connectLongChain(_hintA),
        _ConnectHint.minLink => l10n.connectMinLength(_hintA),
        _ConnectHint.squareHit => l10n.connectSquareHint(_hintA, _hintB),
        _ConnectHint.viral => '$_hintText · x$_hintA +$_hintB',
        _ConnectHint.bonusDrop => l10n.connectBonusDrop(_hintA),
        _ConnectHint.targetHit => l10n.connectTargetHit,
        _ConnectHint.linesOut => l10n.connectLinesOut,
        _ConnectHint.loseHint => l10n.connectLoseHint(_hintA, _hintB, _hintC),
        _ConnectHint.chainExtender => l10n.connectChainExtenderHint,
        _ConnectHint.bolt => l10n.connectBoltHint(_hintA),
        _ConnectHint.magnet => l10n.connectMagnetHint,
      };

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
  String? _popText;
  String? _chainText;
  int _popLen = 0;
  Timer? _popTimer;
  Offset? _lastTouch;
  String? _activePowerFx;
  Timer? _powerFxTimer;

  bool get _ended => _won || _lost;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioManager().initialize();
    _fill();
    // Y3: ilk turun başlangıç damgası (tek yakalama).
    _runStartStamp = DateTime.now().millisecondsSinceEpoch;
    if (widget.prototypeVisualState) {
      _applyPrototypeState();
    } else if (widget.gameplayTestState) {
      _applyGameplayTestState();
    } else {
      _ensureDefaultPowers();
      _loadBest();
    }
  }

  // Varsayılan stok YALNIZ ilk kurulumda verilir. ProgressManager.load()
  // 'lululu_power_seed_v1' bayrağıyla 33 gücü bir kez tohumlar; tohumlanan
  // anahtarlar extraPowers'ta kalıcı olur, takePower() ise anahtarı silmez,
  // 0'a düşürür. "Hiç tohumlanmadı" bu yüzden anahtar yokluğuyla anlaşılır;
  // eski "üçü de 0 ise doldur" koşulu her girişte bedava stok veriyordu.
  // Tohumlama persistBoosters() ile kalıcı kaydedilir.
  void _ensureDefaultPowers() {
    final pm = ProgressManager();
    const defaults = <String, int>{'chain': 3, 'bolt': 1, 'magnet': 1};
    var seeded = false;
    for (final entry in defaults.entries) {
      if (!pm.extraPowers.containsKey(entry.key)) {
        pm.extraPowers[entry.key] = entry.value;
        seeded = true;
      }
    }
    if (seeded) unawaited(pm.persistBoosters());
  }

  void _applyGameplayTestState() {
    _grid = List.generate(
      rows,
      (r) => List.generate(cols, (_) => (r * 2) % 5 + 1),
    );
    for (final p in const [
      Point(1, 1),
      Point(1, 2),
      Point(2, 2),
      Point(2, 3),
      Point(3, 3),
    ]) {
      _grid[p.x][p.y] = 3;
    }
    _score = 0;
    _best = 0;
    _lines = startLines;
    _streak = 0;
  }

  void _applyPrototypeState() {
    _grid = List.generate(
      rows,
      (r) => List.generate(cols, (_) => (r * 2) % 5 + 1),
    );
    for (final p in const [
      Point(1, 1),
      Point(1, 2),
      Point(2, 2),
      Point(2, 3),
      Point(3, 3),
    ]) {
      _grid[p.x][p.y] = 3;
      _path.add(p);
      _pathSet.add(p);
    }
    _paint = 3;
    _score = 1610;
    _best = 2870;
    _lines = 7;
    _streak = 2;
    _popText = '+150 X2';
    _chainText = 'ZİNCİR X2 · +150';
    _popLen = 5;
    final pm = ProgressManager();
    pm.extraPowers['chain'] = 3;
    pm.extraPowers['bolt'] = 1;
    pm.extraPowers['magnet'] = 1;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioManager().stopAll();
    _milestoneTimer?.cancel();
    _hintTimer?.cancel();
    _flashTimer?.cancel();
    _popTimer?.cancel();
    _powerFxTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.prototypeVisualState) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Sıra tabanlı oyun: duvar-saati son tarihi ve kaydırılacak
        // oyun saati yok; yalnız girişi kilitleyip sürüklenen yolu
        // temizle. Zaten duraklatıldıysa bayrağı sahiplenme.
        if (_ended || _resultShown || _paused) return;
        _pausedByLifecycle = true;
        setState(() {
          _paused = true;
          _clearPath();
        });
        break;
      case AppLifecycleState.resumed:
        // Yalnız yaşam-döngüsü duraklatmasıysa devam et; elle
        // duraklatma veya yardım sayfası duraklatması kullanıcıda kalır.
        if (_pausedByLifecycle) {
          _pausedByLifecycle = false;
          setState(() => _paused = false);
        }
        break;
    }
  }

  Future<void> _loadBest() async {
    try {
      await LeaderboardService.instance.ensureLoaded();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _best = LeaderboardService.instance.getBest(
        LeaderboardService.modeConnect,
      );
    });
  }

  Future<void> _persist() async {
    if (_score <= 0) return;
    try {
      await LeaderboardService.instance.ensureLoaded();
      await LeaderboardService.instance.submitScore(
        LeaderboardService.modeConnect,
        _score,
      );
    } catch (error) {
      // F4: liderlik kaydı fırlatırsa _endCheck'in `unawaited`
      // çağırıcılarına (şarj/bolt yolu, sürükleme yolu) işlenmemiş hata
      // yayılmasın; skor finishRun üzerinden de gönderilir, bu çağrı
      // en-iyi çabadır ve oyun akışını kilitlememelidir.
      debugPrint('ConnectPopScreen: _persist hatası: $error');
      return;
    }
    final best = LeaderboardService.instance.getBest(
      LeaderboardService.modeConnect,
    );
    if (mounted && best > _best) setState(() => _best = best);
  }

  void _newGame() {
    _epoch++;
    // Y3: yeni tur, yeni başlangıç damgası.
    _runStartStamp = DateTime.now().millisecondsSinceEpoch;
    _milestoneTimer?.cancel();
    _milestoneTimer = null;
    _hintTimer?.cancel();
    _hintTimer = null;
    _flashTimer?.cancel();
    _flashTimer = null;
    _popTimer?.cancel();
    _popTimer = null;
    _powerFxTimer?.cancel();
    _powerFxTimer = null;
    _score = 0;
    _lines = startLines;
    _busy = false;
    _won = false;
    _lost = false;
    _resultShown = false;
    _paused = false;
    _pausedByLifecycle = false;
    _pausedByHowToPlay = false;
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
    _popText = null;
    _chainText = null;
    _popLen = 0;
    _activePowerFx = null;
    _lastTouch = null;
    _clearPath();
    _setHint(_ConnectHint.idle);
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
      setState(() => _setHint(_ConnectHint.refreshed));
      return;
    }
    final isLoopHint = loopPick != null;
    _hintTimer?.cancel();
    setState(() {
      _hintCells = pick!.toSet();
      _setHint(isLoopHint ? _ConnectHint.loopHint : _ConnectHint.groupHint);
    });
    _hintTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _hintCells = {});
    });
    unawaited(HapticService.instance.selectionClick());
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

  void _begin(Point<int> p) {
    if (_busy || _ended || _paused || _grid[p.x][p.y] == 0) return;
    _clearPath();
    _hintCells = {};
    _paint = _grid[p.x][p.y];
    _path.add(p);
    _pathSet.add(p);
    setState(() => _setHint(_ConnectHint.selectedOne, a: minLen));
  }

  void _extend(Point<int> p) {
    if (_busy || _ended || _paused || _path.isEmpty) return;
    if (_path.length >= 2 && p == _path[_path.length - 2]) {
      final removed = _path.removeLast();
      _pathSet.remove(removed);
      _loop = false;
      setState(() => _setHint(_ConnectHint.selectedCount, a: _path.length));
      return;
    }
    // Kare kapandıktan sonra yol kilitlidir: yeni hücre kabul edilmez, kare
    // bayrağı korunur. Kareyi açmanın tek yolu geri adım atmaktır (yukarıdaki
    // dal). Eskiden yeni hücre _loop=false yapıp kare temizliğini sessizce
    // iptal ediyordu.
    if (_loop) return;
    if (_pathSet.contains(p)) {
      if (p == _path.first && _path.length >= 4 && _ortho(p, _path.last)) {
        _loop = true;
        setState(() => _setHint(_ConnectHint.squareReady));
        unawaited(HapticService.instance.lightImpact());
      }
      return;
    }
    if (_grid[p.x][p.y] != _paint) return;
    if (!_ortho(p, _path.last)) return;
    _path.add(p);
    _pathSet.add(p);
    final len = _path.length;
    setState(() {
      if (len >= 6) {
        _setHint(_ConnectHint.longChain, a: len);
      } else {
        _setHint(_ConnectHint.selectedCount, a: len);
      }
    });
  }

  Future<void> _commit() async {
    if (_busy || _ended || _paused) return;
    if (_path.length < minLen) {
      _clearPath();
      setState(() {
        _streak = 0;
        _setHint(_ConnectHint.minLink, a: minLen);
        _comboMeter = max(0, _comboMeter - 0.15);
      });
      return;
    }

    // Enerji iadesi sayacı: geçerli zincir bırakma anında sayılır
    // (en az minLen kontrolü yukarıda geçti; kısa çizgi hamle sayılmaz).
    _moveMade = true;
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
      _showMilestone(context.l10n.connectSquareClear);
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
    _showPop(pathLen, gained, loop);
    _comboMeter = min(1.0, 0.25 + _streak * 0.12 + pathLen * 0.04);
    _lines--;
    if (pathLen >= 6 && !loop) _lines++;
    _checkScoreMilestones();
    final insect = InsectTier.values[(tier - 1).clamp(0, 7)];
    if (loop) {
      _setHint(_ConnectHint.squareHit, a: _streak, b: gained);
    } else {
      _setHint(_ConnectHint.viral, a: _streak, b: gained, text: insect.viralReplik);
    }
    _flashCells = group.toSet();
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _flashCells = {});
    });
    if (loop) {
      _gridBurst = 1.08;
      unawaited(HapticService.instance.heavyImpact());
      unawaited(AudioManager().playMerge(tierNumber: tier, comboCount: 3));
    } else {
      AudioManager().triggerMediumHaptic();
    }
    setState(() {});
    await Future<void>.delayed(Duration(milliseconds: loop ? 200 : 130));
    if (!mounted || epoch != _epoch) return;
    _gridBurst = 1.0;
    _collapse();
    // Soft cascade: auto-clear tiny leftover singles of same color if 6+ path
    if (pathLen >= 6 && !loop) {
      final leftover = _floodAutoBonus(tier);
      if (leftover > 0) {
        _score += leftover * 30;
        _clearTotal += leftover;
        _setHint(_ConnectHint.bonusDrop, a: leftover * 30);
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
      if (_paused) {
        _clearPath();
      } else {
        _pausedByLifecycle = false;
        _pausedByHowToPlay = false;
      }
    });
  }

  /// Yardım sayfası görünürlük kancası (F9): sayfa açılırken oyunu
  /// duraklat, kapanırken yalnız bu kancayla duraklatıldıysa devam et.
  void _handleHowToPlayVisibilityChanged(bool visible) {
    // Kapanış geri çağrısı asenkron gelir (dialog future'ı): sayfa
    // açıkken rota dispose edildiyse setState çökmesin.
    if (!mounted) return;
    if (visible) {
      if (_ended ||
          _resultShown ||
          _paused ||
          widget.prototypeVisualState) {
        return;
      }
      _pausedByHowToPlay = true;
      setState(() {
        _paused = true;
        _clearPath();
      });
    } else {
      if (!_pausedByHowToPlay) return;
      _pausedByHowToPlay = false;
      setState(() => _paused = false);
    }
  }

  void _showPop(int len, int gained, bool loop) {
    _popTimer?.cancel();
    _popLen = len;
    _popText = '+$gained X$_streak';
    _chainText = loop ? context.l10n.connectSquareChain(gained) : context.l10n.connectChainText(_streak, gained);
    _popTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _popText = null;
          _chainText = null;
        });
      }
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
        _showMilestone(context.l10n.scoreMilestone(m));
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
    try {
      if (_score >= target) {
        // Tur tamamlandı: iade hakkı biter (bayrak oturum ömründe kalır).
        _moveMade = true;
        _won = true;
        _setHint(_ConnectHint.targetHit);
        unawaited(HapticService.instance.heavyImpact());
        // D1: bitiş sesi tek kaynak — sonuç ekranı çalar.
        await _persist();
      } else if (_lines <= 0) {
        _moveMade = true;
        _lost = true;
        _setHint(_ConnectHint.linesOut);
        unawaited(HapticService.instance.heavyImpact());
        // D1: bitiş sesi tek kaynak — sonuç ekranı çalar.
        await _persist();
      } else {
        _setHint(_ConnectHint.loseHint, a: target, b: _lines, c: _streak);
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _busy = false);
    }
  }

  String _statsLine() =>
      'Temiz $_clearTotal · Kare $_loopCount · Max streak x$_maxStreak · En uzun $_longestPath';

  /// Oyun sonu: yeni sonuç ekranı. "TEKRAR OYNA" yeni turu başlatır,
  /// "ANA SAYFA"da eski sonuç akışı devam eder (bozulmadı).

  List<Point<int>> _cluster(int r, int c) {
    final tier = _grid[r][c];
    final out = <Point<int>>[];
    final seen = <int>{};
    final queue = <Point<int>>[Point(r, c)];
    while (queue.isNotEmpty) {
      final pt = queue.removeLast();
      if (pt.x < 0 || pt.y < 0 || pt.x >= rows || pt.y >= cols) continue;
      if (!seen.add(pt.x * cols + pt.y)) continue;
      if (_grid[pt.x][pt.y] != tier) continue;
      out.add(pt);
      queue.add(Point(pt.x + 1, pt.y));
      queue.add(Point(pt.x - 1, pt.y));
      queue.add(Point(pt.x, pt.y + 1));
      queue.add(Point(pt.x, pt.y - 1));
    }
    return out;
  }

  void _triggerPowerFx(String kind, String milestoneText) {
    _powerFxTimer?.cancel();
    _activePowerFx = kind;
    _showMilestone(milestoneText);
    _powerFxTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _activePowerFx = null);
    });
  }

  /// Zincir Uzatıcı skor vermez; etkisi +3 çizgidir. Çizgi bedeli yoktur
  /// (bedel, kalıcı stoktan harcanan 1 adettir); bedel koymak "+3" metnini
  /// boşa çıkarırdı.
  bool _useChain() {
    if (_ended || _paused) return false;
    AudioManager().triggerMediumHaptic();
    AudioManager().playMerge(tierNumber: 2);
    setState(() {
      _lines += 3;
      _setHint(_ConnectHint.chainExtender);
      _triggerPowerFx('chain', context.l10n.connectChainExtenderMilestone);
    });
    _showHint();
    return true;
  }

  /// Yıldırım skoru bedava değildir: kalıcı stoktan 1 adet
  /// (stockBonus/takePower) + 1 çizgi harcar. Çizgi bedeli, güç sonrası
  /// çalışan _endCheck tarafından görülür.
  bool _useBolt() {
    if (_ended || _paused || _busy) return false;
    var best = <Point<int>>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (_grid[r][c] == 0) continue;
        final group = _cluster(r, c);
        if (group.length > best.length) best = group;
      }
    }
    if (best.isEmpty) return false;
    unawaited(HapticService.instance.heavyImpact());
    AudioManager().playMerge(tierNumber: 4);
    final gained = best.length * 28;
    setState(() {
      _flashCells = best.toSet();
      for (final p in best) {
        _grid[p.x][p.y] = 0;
      }
      _lines--;
      _score += gained;
      if (_score > _best) _best = _score;
      _clearTotal += best.length;
      _collapse();
      _showPop(best.length, gained, false);
      _setHint(_ConnectHint.bolt, a: best.length);
      _triggerPowerFx('bolt', context.l10n.connectBoltMilestone(gained));
      _checkScoreMilestones();
    });
    unawaited(_endCheck(_epoch));
    return true;
  }

  /// Mıknatıs skor vermez; yalnızca tahtada kare zinciri kurar. Skor,
  /// oyuncunun kurulan kareyi çizmesiyle gelir ve o çizgi _commit'te 1 çizgi
  /// harcar. Bu yüzden ayrıca çizgi bedeli yoktur; bedel stoktan 1 adettir.
  bool _useMagnet() {
    if (_ended || _paused || _busy) return false;
    final counts = List<int>.filled(maxKinds + 1, 0);
    for (final row in _grid) {
      for (final value in row) {
        if (value > 0 && value <= maxKinds) counts[value]++;
      }
    }
    var tier = 1;
    for (var i = 2; i <= maxKinds; i++) {
      if (counts[i] > counts[tier]) tier = i;
    }
    AudioManager().triggerMediumHaptic();
    AudioManager().playMerge(tierNumber: tier);
    setState(() {
      for (var i = 0; i < 4 && 1 + i < cols; i++) {
        _grid[3][1 + i] = tier;
      }
      _grid[2][2] = tier;
      _grid[2][3] = tier;
      _hintCells = {
        const Point(2, 2),
        const Point(2, 3),
        const Point(3, 2),
        const Point(3, 3),
      };
      _setHint(_ConnectHint.magnet);
      _triggerPowerFx('magnet', context.l10n.connectMagnetMilestone);
    });
    return true;
  }

  Future<void> _presentResult({bool? won}) async {
    // S1#49: ödeme + liderlik (yalnız skor > 0) + görev kaydı + sonuç
    // ekranı finishRun() üzerinden (tek-ödeme korunur). `won`
    // verilmezse hedefin tutup tutmadığı (_won) başlığı belirler.
    bool replay;
    try {
      replay = await finishRun(
        context,
        score: _score,
        best: _best,
        bestCombo: _maxStreak,
        merges: _clearTotal,
        won: won ?? _won,
        leaderboardMode: LeaderboardService.modeConnect,
        leaderboardOnlyIfPositiveScore: true,
        // K16: ModesScreen `getModeBestScore('connect_pop')` ile okuyor;
        // `recordModeScore` yazılmazsa mod rekoru hiç güncellenmiyordu.
        modeScoreId: 'connect_pop',
        // Y3: tur-başlangıç damgası — aynı turun çift sunumu engellenir.
        idempotencyKey: 'connect:$_runStartStamp',
      );
    } catch (error) {
      // finishRun fırlatırsa sonuçsuz takılma: bayrağı düşür ki BİTİR
      // veya bitiş kenarı sonucu yeniden deneyebilsin.
      debugPrint('ConnectPopScreen: finishRun hatası: $error');
      _resultShown = false;
      return;
    }
    if (!mounted) return;
    if (!replay) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    _resultShown = false;
    _newGame();
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
    // S6: bildirim yalnız iade GERÇEKTEN verildiğinde gösterilir —
    // enerji zaten doluysa `addEnergy` kelepçelenir, değişim olmaz.
    final before = EnergyService.instance.energy;
    EnergyService.instance.addEnergy(1);
    if (EnergyService.instance.energy > before) {
      GlobalNotify.showSnackBar(_refundNotice);
    }
  }

  /// N7: tur sürerken, hamle yapılmışsa ve giriş enerjisi
  /// tüketilmişse (iade hakkı yoksa) çıkış onayı gerekir. Hamlesiz
  /// çıkışta onay YOK — çıkış anında kalır, iade yolu aynen çalışır
  /// (S6'ya dokunulmaz).
  bool get _needsExitConfirm =>
      widget.energyConsumed && _moveMade && !_ended && !_resultShown;

  /// N7 `PopScope` yolu: `didPop` ise mevcut iade mantığı aynen
  /// çalışır; veto ise onay diyaloğu açılır.
  void _handleExitPop(bool didPop) {
    if (didPop) {
      _maybeRefundEnergy();
      return;
    }
    unawaited(_showExitConfirm());
  }

  /// N7 çıkış onayı: sohbet/satın alma onay deseni
  /// (`showDialog<bool>` + `AlertDialog` + İptal TextButton / Çık
  /// FilledButton). Yeni dialog widget'ı yok, mevcut desen çağrılır.
  Future<bool> _confirmExitRound() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.exitRoundConfirmTitle),
        content: Text(ctx.l10n.exitRoundConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.quit),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// N7 diyalog duraklatması (yardım kancası deseni): diyalog
  /// açıkken oyun durur; yarım kalan zincir çizimi temizlenir.
  void _pauseForExitConfirm() {
    if (_ended || _resultShown || _paused) return;
    _pausedForExitConfirm = true;
    setState(() {
      _paused = true;
      _clearPath();
    });
  }

  void _resumeAfterExitConfirm() {
    if (!_pausedForExitConfirm) return;
    _pausedForExitConfirm = false;
    setState(() => _paused = false);
  }

  Future<void> _showExitConfirm() async {
    if (_exitConfirmShowing) return;
    _exitConfirmShowing = true;
    _pauseForExitConfirm();
    final confirmed = await _confirmExitRound();
    _exitConfirmShowing = false;
    if (!mounted) return;
    if (confirmed) {
      setState(() => _exitConfirmed = true);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final popped = await Navigator.of(context).maybePop();
        if (!popped && mounted) {
          setState(() => _exitConfirmed = false);
          _resumeAfterExitConfirm();
        }
      });
    } else {
      _resumeAfterExitConfirm();
    }
  }

  /// BİTİR: turu sessizce silmek yerine sonuç ekranını açar
  /// (playtest bulgu #10). Erken bitirmede başlık skora göre
  /// belirlenir (skor 0 ise kayıp başlığı).
  Future<void> _finishEarly() async {
    if (_resultShown) return;
    _resultShown = true;
    await _presentResult(won: _score > 0);
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
    // S6: iade bildirimi metni çıkıştan ÖNCE yakalanır
    // (`didPop` anında bağlam ağaçta değildir).
    _refundNotice = context.l10n.energyRefundNotice;
    if (_ended && !_resultShown) _edgeShowResult();
    return PopScope(
      canPop: _exitConfirmed || !_needsExitConfirm,
      onPopInvokedWithResult: (didPop, _) => _handleExitPop(didPop),
      child: ArcadeScreen(
      backgroundAsset: 'assets/design/backgrounds/connect_workshop.webp',
      title: context.l10n.shopModeLinkPop,
      tag: context.l10n.connectChainTag,
      tagColor: const Color(0xFFFFD700),
      tagTextColor: const Color(0xFF4A2E00),
      showStatusBar: true,
      hint: _paused ? context.l10n.pausedStatusCaps : _hintString(context.l10n),
      score: _score,
      best: _best,
      statLabel: context.l10n.linesLabel,
      statValue: '$_lines',
      prototypeChrome: true,
      prototypeBaglaChrome: true,
      onRestart: _finishEarly,
      onPausePressed: _togglePause,
      onHowToPlayVisibilityChanged: _handleHowToPlayVisibilityChanged,
      // F6: ölü sonuç overlay'i kaldırıldı — tek sonuç yolu finishRun
      // diyaloğudur (build _resultShown'u senkron set ediyordu, dal
      // hiç çizilmiyordu).
      overlay: _paused
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
                      ArcadeButton(label: context.l10n.continueAction, onPressed: _togglePause),
                    ],
                  ),
                ),
              ),
            )
          : null,
      footer: ModeBonusBar(
        items: [
          stockBonusWithResult(
            id: 'chain',
            label: context.l10n.powerChainPlus,
            asset: 'assets/icons2/flame.png',
            effect: () {
              final applied = _useChain();
              setState(() {});
              return applied;
            },
          ),
          stockBonusWithResult(
            id: 'bolt',
            label: context.l10n.powerLightningCaps,
            asset: 'assets/icons2/bolt.png',
            effect: () {
              final applied = _useBolt();
              setState(() {});
              return applied;
            },
          ),
          stockBonusWithResult(
            id: 'magnet',
            label: context.l10n.powerMagnetCaps,
            asset: 'assets/icons2/magnet.png',
            effect: () {
              final applied = _useMagnet();
              setState(() {});
              return applied;
            },
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 5.0;
          final bool compactFixed =
              widget.prototypeVisualState || widget.gameplayTestState;
          final double cell = compactFixed
              ? (min(
                      284.0,
                      min(constraints.maxWidth - 24, constraints.maxHeight - 24),
                    ) -
                    gap * (cols - 1)) /
                  cols
              : min(
                  (constraints.maxWidth - 16 - gap * (cols - 1)) / cols,
                  (constraints.maxHeight - 58 - gap * (rows - 1)) / rows,
                );
          final stride = cell + gap;
          final boardW = cell * cols + gap * (cols - 1);
          final boardH = cell * rows + gap * (rows - 1);
          final popSize = widget.prototypeVisualState
              ? 24.0
              : 20.0 + min(10, max(0, _popLen - 3) * 2.0);
          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) {
                          final p = _cellAt(d.localPosition, cell, gap);
                          _lastTouch = d.localPosition;
                          if (p != null) _begin(p);
                        },
                        onPanUpdate: (d) {
                          final from = _lastTouch ?? d.localPosition;
                          _lastTouch = d.localPosition;
                          final dist = (d.localPosition - from).distance;
                          final steps = max(
                            1,
                            (dist / (cell * 0.4)).ceil(),
                          );
                          for (var i = 1; i <= steps; i++) {
                            final p = _cellAt(
                              Offset.lerp(
                                from,
                                d.localPosition,
                                i / steps,
                              )!,
                              cell,
                              gap,
                            );
                            if (p != null) _extend(p);
                          }
                        },
                        onPanEnd: (_) => unawaited(_commit()),
                        onPanCancel: () => unawaited(_commit()),
                        child: AnimatedScale(
                          scale: _gridBurst,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          child: SizedBox(
                            key: const ValueKey('connect-pop-board'),
                            width: boardW,
                            height: boardH,
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
                  ),
                  if (!compactFixed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.connectTargetLine(_longestPath),
                                style: GoogleFonts.nunito(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                  color: const Color(0xBDFFFFFF),
                                ),
                              ),
                              Text(
                                '%${((_score / target).clamp(0.0, 1.0) * 100).round()}',
                                style: GoogleFonts.nunito(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFFFFD700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: SizedBox(
                              height: 11,
                              child: LinearProgressIndicator(
                                value: (_score / target).clamp(0.03, 1.0),
                                backgroundColor: const Color(0x66080B12),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFD700),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_popText != null)
                Positioned(
                  left: 16,
                  top: 190.5,
                  child: IgnorePointer(
                    child: _comboText(_popText!, popSize),
                  ),
                ),
              if (_chainText != null)
                Positioned(
                  right: 12,
                  bottom: 54,
                  child: IgnorePointer(child: _comboText(_chainText!, 22)),
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
                            color: _activePowerFx == 'chain'
                                ? const Color(0xFFFFD700)
                                : _activePowerFx == 'bolt'
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFF00C853),
                            width: 5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_activePowerFx == 'chain'
                                      ? const Color(0xFFFFD700)
                                      : _activePowerFx == 'bolt'
                                      ? const Color(0xFF00E5FF)
                                      : const Color(0xFF00C853))
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
                  top: 56,
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
      ),
    );
  }

  Widget _comboText(String text, double size) {
    return Text(
      text,
      style: GoogleFonts.bangers(
        fontSize: size,
        height: 1,
        letterSpacing: 0.6,
        color: const Color(0xFFFFB800),
        shadows: const [
          Shadow(color: Color(0xEB080B12), offset: Offset(0, 3)),
          Shadow(color: Color(0xE6FF6B35), blurRadius: 14),
          Shadow(color: Color(0x8CFF6B35), blurRadius: 32),
          Shadow(color: Color(0x52FF6B35), blurRadius: 54),
        ],
      ),
    );
  }

  Widget _tile(int r, int c) {
    final tier = _grid[r][c];
    final onPath = _pathSet.contains(Point(r, c));
    final hinted = _hintCells.contains(Point(r, c));
    final flashed = _flashCells.contains(Point(r, c));
    final lit = onPath || hinted || flashed;
    return AnimatedScale(
      scale: lit ? 1.04 : 1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: tier == 0
              ? Colors.white10
              : _tileColors[(tier - 1) % _tileColors.length],
          borderRadius: BorderRadius.circular(10),
        ),
        foregroundDecoration: lit
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: flashed
                      ? Colors.white
                      : hinted
                      ? const Color(0xFF00C853)
                      : _loop
                      ? const Color(0xFF00C853)
                      : const Color(0xFFFFD700),
                  width: 3,
                ),
              )
            : null,
        child: tier == 0
            ? null
            : Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(_cellInset),
                      child: Image.asset(
                        'assets/bugs/tier${tier}_hd${tier == 5 ? '.webp' : '.png'}',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 3,
                    child: ColoredBox(color: Color(0x24000000)),
                  ),
                ],
              ),
      ),
    );
  }

  static const double _cellInset = 3.0;
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
    Offset center(Point<int> p) =>
        Offset(p.y * stride + cell / 2, p.x * stride + cell / 2);
    final gold = loop ? const Color(0xFF00C853) : const Color(0xFFFFD700);
    final paint = Paint()
      ..color = gold.withValues(alpha: 0.92)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final pathDraw = Path()
      ..moveTo(center(path.first).dx, center(path.first).dy);
    for (var i = 1; i < path.length; i++) {
      final o = center(path[i]);
      pathDraw.lineTo(o.dx, o.dy);
    }
    if (loop) {
      final o = center(path.first);
      pathDraw.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(pathDraw, paint);
    final dot = Paint()..color = gold.withValues(alpha: 0.92);
    for (var i = 0; i < path.length; i++) {
      if (i.isEven || i == path.length - 1) {
        canvas.drawCircle(center(path[i]), 7, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) => true;
}
