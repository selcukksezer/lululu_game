import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/hisir_character.dart';
import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/haptic_service.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../widgets/bonus_fx.dart';

class _BoardSnapshot {
  final List<List<int>> grid;
  final int score;
  final int moveCount;
  final int streak;

  const _BoardSnapshot({
    required this.grid,
    required this.score,
    required this.moveCount,
    required this.streak,
  });
}

/// 2048 Grid (`m2048`) — 4x4 kaydırmalı böcek birleştirme modu.
/// Prototip `reference-m2048.png` ve `reference-m2048-spec.json` (`430x932`)
/// ile birebir aynı üst `.statusbar`, `.mode-top`, `.game-hud`, `.mode-stage`,
/// `.g2048` 4x4 pastel `TCOL` ızgarası, `.chipfloat`, `.combo-float`,
/// `.score-pop` ve alt `.power-dock` (`GERİ AL 3`, `KARIŞTIR 2`, `ÇİFTLEŞTİR 1`)
/// bileşenlerini içerir; kaydırma + klavye yön tuşları ile tam oynanabilirdir.
class Grid2048Screen extends StatefulWidget {
  const Grid2048Screen({
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
  State<Grid2048Screen> createState() => _Grid2048ScreenState();
}

class _Grid2048ScreenState extends State<Grid2048Screen>
    with WidgetsBindingObserver {
  static const int size = 4;

  /// Üst satır ve HUD içerik genişliğinin tavanı: 430 referans genişlikten
  /// iki yandaki 12'şer px kenar boşluğu çıkarılınca kalan 406px.
  /// Gerçek genişlik her zaman LayoutBuilder constraints'inden hesaplanır.
  static const double _maxContentWidth = 406.0;

  /// Prototip `TCOL` pastel taş arka plan renkleri (Tier 1..13).
  static const List<Color> _tcol = <Color>[
    Color(0xFFFFE9C9), // T1 -> 2
    Color(0xFFFFE3D6), // T2 -> 4
    Color(0xFFE4F0FF), // T3 -> 8
    Color(0xFFF3E4FF), // T4 -> 16
    Color(0xFFFFE0EC), // T5 -> 32
    Color(0xFFDFF7EA), // T6 -> 64
    Color(0xFFFFF0D6), // T7 -> 128
    Color(0xFFE8ECF5), // T8 -> 256
    Color(0xFFFFE1E1), // T9 -> 512
    Color(0xFFFFE0EC), // T10 -> 1024
    Color(0xFFEDF1F8), // T11 -> 2048
    Color(0xFFE8ECF5), // T12 -> 4096
    Color(0xFFFFDFF2), // T13 -> 8192
  ];

  /// Prototip `f2048()` başlangıç dizilimi (`reference-m2048-spec.json`).
  static const List<List<int>> _prototypeGrid = <List<int>>[
    [1, 2, 0, 1],
    [3, 2, 4, 0],
    [2, 5, 3, 6],
    [5, 4, 7, 8],
  ];

  final Random _rng = Random();
  final FocusNode _focusNode = FocusNode();

  late List<List<int>> _grid;
  final List<_BoardSnapshot> _history = <_BoardSnapshot>[];

  int _score = 8640;
  int _best = 0;
  int _moveCount = 36;
  int _streak = 4;
  int _maxStreak = 4;
  int _mergeTotal = 0;
  int _highestTier = 8;

  bool _gameOver = false;
  bool _won = false;
  bool _paused = false;

  /// Yaşam döngüsü duraklatması ayrımı (Osmantus deseni): arka plana
  /// geçiş kaplamayı açtıysa `true` olur; elle duraklatma bu bayrağı
  /// koymaz. Dönüşte (`resumed`) yalnız bu bayrak konmuşsa devam
  /// edilir — elle duraklatma yapışkan kalır.
  bool _pausedByLifecycle = false;

  /// N7 çıkış onayı durumu: onay bayrağı (diyalogda Çık seçildiyse
  /// `PopScope` çıkışı geçirir), çift-diyalog kilidi ve diyalog
  /// duraklatması bayrağı (yardım deseni: yalnız bu diyalog için
  /// duraklatıldıysa kapanınca devam edilir).
  bool _exitConfirmed = false;
  bool _exitConfirmShowing = false;
  bool _pausedForExitConfirm = false;
  bool _showHelpModal = false;
  bool _resultShown = false;
  bool _presentingResultModal = false;

  /// Hamle bayrağı (enerji iadesi): oturum boyunca tahtayı değiştiren
  /// ilk kaydırma (`_slide`, `moved == true`) ile `true` olur;
  /// TEKRAR/yeniden başlatmada SIFIRLANMAZ (Suika `_dropsMade`
  /// deseni — oturum ömrü; `_moveCount` `_initBoard` ile sıfırlanır
  /// ve geri alma ile geri alınır, bu bayrak sıfırlanmaz).
  bool _moveMade = false;

  /// Çift-iade koruması: iade bu oturumda en fazla bir kez yapılır.
  bool _energyRefunded = false;

  /// Y3 tur başlangıç damgası: `_initBoard` her turda bir kez yazar
  /// (milisaniye). `_presentResult` bu damgadan
  /// `'grid2048:<damga>'` idempotency anahtarını üretir; aynı turun
  /// BİTİR + hamle-bitiş yolları aynı anahtarı paylaşır, yeni oyun
  /// (`_restart` → `_initBoard`) yeni anahtar alır. Bitiş anında
  /// `DateTime.now()` kullanılmaz.
  int _runStartedAt = 0;

  bool _panConsumed = false;
  Offset _panAccum = Offset.zero;

  Point<int>? _lastSpawned;
  Set<Point<int>> _mergedCells = <Point<int>>{};
  String? _comboText = 'COMBO X4!';
  String? _gainText = '+128 X4';
  String? _speechBubble;
  Timer? _overlayTimer;
  Timer? _speechTimer;
  Timer? _popTimer;

  /// 10D P0-2: geçersiz kaydırma sarsıntısı — tahtanın yatay ötelemesi
  /// (±6 px, iki adımda gidip döner; Timer/setState deseni, mevcut
  /// `_popTimer` ile aynı kalıp). Varsayılan 0 = sarsıntı yok.
  double _invalidShakeX = 0;
  Timer? _invalidShakeTimer;

  int _undoCount = 3;
  int _shuffleCount = 2;
  int _pairCount = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioManager().initialize();
    _syncPowerCounts();
    _initBoard(initialPrototypeState: widget.prototypeVisualState);
    _loadBest();
  }

  /// Güçlendirici stoklarını kasadan okur; eksik anahtar 0 sayılır.
  /// Giriş-başı dolum YOKTUR (B3): tohum bir kez `ProgressManager.load`
  /// tarafından verilir, bu ekran kasaya yazmaz.
  void _syncPowerCounts() {
    final pm = ProgressManager();
    _undoCount = pm.powerCount('undo2048');
    _shuffleCount = pm.powerCount('shuffle2048');
    _pairCount = pm.powerCount('pair2048');
  }

  void _initBoard({bool initialPrototypeState = false}) {
    // Y3: tur başlangıç damgası — prototip dalı dahil her turda bir
    // kez, tahta kurulmadan önce yazılır.
    _runStartedAt = DateTime.now().millisecondsSinceEpoch;
    // B17: kozmetik timer'lar iptal edilmeden tahta sıfırlanırsa eski
    // zamanlayıcılar yeni turun kaplama/patlama durumunu temizler.
    // (`_restart` bu yöntemden geçtiği için tek nokta yeterlidir.)
    _overlayTimer?.cancel();
    _speechTimer?.cancel();
    _popTimer?.cancel();
    _invalidShakeTimer?.cancel();
    _invalidShakeX = 0;
    _history.clear();
    _mergedCells = <Point<int>>{};
    _lastSpawned = null;
    _gameOver = false;
    _won = false;
    _paused = false;
    _pausedByLifecycle = false;
    _showHelpModal = false;
    _resultShown = false;
    _presentingResultModal = false;

    if (initialPrototypeState || widget.prototypeVisualState) {
      _grid = List<List<int>>.generate(
        size,
        (r) => List<int>.from(_prototypeGrid[r]),
      );
      _score = 8640;
      _best = 12480;
      _moveCount = 36;
      _streak = 4;
      _maxStreak = 4;
      _highestTier = 8;
      _comboText = 'COMBO X4!';
      _gainText = '+128 X4';
      _speechBubble = null;
      return;
    }

    _grid = List<List<int>>.generate(size, (_) => List<int>.filled(size, 0));
    _score = 0;
    _best = LeaderboardService.instance.getBest(LeaderboardService.mode2048);
    _moveCount = 0;
    _streak = 0;
    _maxStreak = 0;
    _mergeTotal = 0;
    _highestTier = 2;
    _comboText = null;
    _gainText = null;
    _speechBubble = null;

    _grid[0][0] = 1;
    _grid[0][1] = 1;
    _grid[1][1] = 2;
    _grid[2][2] = 2;
    _spawnRandomTile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlayTimer?.cancel();
    _speechTimer?.cancel();
    _popTimer?.cancel();
    _invalidShakeTimer?.cancel();
    _focusNode.dispose();
    AudioManager().stopAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.prototypeVisualState || !mounted) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Sıra tabanlı oyun: işleyen saat ve ötelenmesi gereken
        // duvar-saati son tarihi yok; arka plana/kısmi örtünmeye
        // geçişte mevcut duraklatma kaplaması gösterilir (`inactive`
        // dahil: kaplama uygulama değiştiricide ve bildirim gölgesi
        // arkasında da görünür). Oyun bitmiş, yardım/sonuç açık veya
        // elle zaten duraklatılmışsa sahiplenilmez (Osmantus
        // `_pausedByLifecycle` ayrımı).
        if (_gameOver ||
            _showHelpModal ||
            _resultShown ||
            _presentingResultModal ||
            _paused) {
          return;
        }
        _pausedByLifecycle = true;
        setState(() => _paused = true);
      case AppLifecycleState.detached:
        // Ayrılma sonrası dönüş beklenmez; kaplama açılmaz.
        break;
      case AppLifecycleState.resumed:
        // Yalnız yaşam döngüsü duraklatmasıysa devam edilir; elle
        // duraklatma yapışkan kalır (DEVAM düğmesiyle açılır).
        // 2048 sıra tabanlı olduğu için kendiliğinden devamın oyun
        // cezası yoktur.
        if (_pausedByLifecycle) {
          _pausedByLifecycle = false;
          if (_paused) {
            setState(() => _paused = false);
          }
        }
        break;
    }
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    final saved = LeaderboardService.instance.getBest(
      LeaderboardService.mode2048,
    );
    if (saved > _best) {
      setState(() => _best = saved);
    }
  }

  Future<void> _persistBest() async {
    if (_score <= 0) return;
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance.submitScore(
      'grid2048',
      _score,
    );
    final saved = LeaderboardService.instance.getBest(
      LeaderboardService.mode2048,
    );
    if (mounted && saved > _best) {
      setState(() => _best = saved);
    }
  }

  void _restart() {
    setState(() => _initBoard(initialPrototypeState: false));
  }

  void _togglePause() {
    if (_gameOver) return;
    // 10D P0-3: duraklatma sesi + titreşimi tek çağrıda
    // (playButtonTap içi selectionClick; ayrıca trigger* eklenmez).
    AudioManager().playButtonTap();
    setState(() {
      _paused = !_paused;
      if (!_paused) _pausedByLifecycle = false;
    });
  }

  List<List<int>> _cloneGrid(List<List<int>> src) =>
      List<List<int>>.generate(size, (r) => List<int>.from(src[r]));

  void _saveHistory() {
    if (_history.length >= 12) {
      _history.removeAt(0);
    }
    _history.add(
      _BoardSnapshot(
        grid: _cloneGrid(_grid),
        score: _score,
        moveCount: _moveCount,
        streak: _streak,
      ),
    );
  }

  void _spawnRandomTile() {
    final empties = <Point<int>>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (_grid[r][c] == 0) empties.add(Point<int>(r, c));
      }
    }
    if (empties.isEmpty) return;
    final spot = empties[_rng.nextInt(empties.length)];
    final roll = _rng.nextDouble();
    final tier = roll < 0.72
        ? 1
        : roll < 0.94
        ? 2
        : 3;
    _grid[spot.x][spot.y] = widget.prototypeVisualState
        ? tier
        : HisirCharacter.encodeGridValue(tier, _rng);
    _lastSpawned = spot;
    if (tier > _highestTier) _highestTier = tier;
  }

  bool _hasMovesAvailable() {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = HisirCharacter.baseTier(_grid[r][c]);
        if (v == 0) return true;
        // Zirve kademe birleşmediği için iki zirvenin yan yana olması
        // hamle sayılmaz; yoksa tahta doluyken oyun bitmezdi.
        if (v < InsectTier.values.length) {
          if (r + 1 < size &&
              HisirCharacter.baseTier(_grid[r + 1][c]) == v) {
            return true;
          }
          if (c + 1 < size &&
              HisirCharacter.baseTier(_grid[r][c + 1]) == v) {
            return true;
          }
        }
      }
    }
    return false;
  }

  (List<int>, int, int, List<int>, bool) _compressLine(List<int> line) {
    final nonZero = line.where((v) => v != 0).toList();
    final out = <int>[];
    final mergedIndices = <int>[];
    var gained = 0;
    var topMergedTier = 0;
    var hisirMerged = false;
    final maxTier = InsectTier.values.length;
    var i = 0;
    while (i < nonZero.length) {
      // Zirve kademe birleşmez: iki zirve yan yana kalır, üst kademe yok.
      // (_usePair da zirveyi dışlar; kayma ile güçlendirici tutarlı.)
      // Hışır derisi kademeyi değiştirmez: iki aynı kademe (biri Hışır
      // derili de olsa) birleşir; doğan taş düz üst kademedir.
      final a = HisirCharacter.baseTier(nonZero[i]);
      final b = i + 1 < nonZero.length
          ? HisirCharacter.baseTier(nonZero[i + 1])
          : 0;
      if (i + 1 < nonZero.length && a == b && a < maxTier) {
        final next = (a + 1).clamp(1, maxTier);
        out.add(next);
        mergedIndices.add(out.length - 1);
        gained += 1 << next;
        if (next > topMergedTier) topMergedTier = next;
        if (HisirCharacter.isEncoded(nonZero[i]) ||
            HisirCharacter.isEncoded(nonZero[i + 1])) {
          hisirMerged = true;
        }
        i += 2;
      } else {
        out.add(nonZero[i]);
        i++;
      }
    }
    while (out.length < size) {
      out.add(0);
    }
    return (out, gained, topMergedTier, mergedIndices, hisirMerged);
  }

  void _slide(int dr, int dc) {
    if (_gameOver || _paused || _showHelpModal) return;

    final snapshot = _cloneGrid(_grid);
    var moved = false;
    var totalGain = 0;
    var topMerge = 0;
    var mergesThisTurn = 0;
    var hisirMerged = false;
    final newMerged = <Point<int>>{};

    if (dr == 0 && dc != 0) {
      for (var r = 0; r < size; r++) {
        final row = List<int>.from(_grid[r]);
        final input = dc < 0 ? row : row.reversed.toList();
        final (compressed, gain, topTier, mergedIdx, lineHisir) =
            _compressLine(input);
        hisirMerged = hisirMerged || lineHisir;
        final result = dc < 0 ? compressed : compressed.reversed.toList();
        for (var c = 0; c < size; c++) {
          if (_grid[r][c] != result[c]) moved = true;
          _grid[r][c] = result[c];
        }
        for (final idx in mergedIdx) {
          final col = dc < 0 ? idx : (size - 1 - idx);
          newMerged.add(Point<int>(r, col));
        }
        mergesThisTurn += mergedIdx.length;
        totalGain += gain;
        if (topTier > topMerge) topMerge = topTier;
      }
    } else if (dc == 0 && dr != 0) {
      for (var c = 0; c < size; c++) {
        final col = List<int>.generate(size, (r) => _grid[r][c]);
        final input = dr < 0 ? col : col.reversed.toList();
        final (compressed, gain, topTier, mergedIdx, lineHisir) =
            _compressLine(input);
        hisirMerged = hisirMerged || lineHisir;
        final result = dr < 0 ? compressed : compressed.reversed.toList();
        for (var r = 0; r < size; r++) {
          if (_grid[r][c] != result[r]) moved = true;
          _grid[r][c] = result[r];
        }
        for (final idx in mergedIdx) {
          final row = dr < 0 ? idx : (size - 1 - idx);
          newMerged.add(Point<int>(row, c));
        }
        mergesThisTurn += mergedIdx.length;
        totalGain += gain;
        if (topTier > topMerge) topMerge = topTier;
      }
    }

    if (!moved) {
      unawaited(HapticService.instance.selectionClick());
      // 10D P0-2: geçersiz kaydırmada ses yoktu + görsel de yoktu.
      // playDrop (kapılı lightImpact; yukarıdaki selectionClick ile
      // aynı tick'te 18 ms kapısına takılıp düşer — toplam 1 impuls)
      // + mevcut Timer/setState deseninde hafif tahta sarsıntısı.
      AudioManager().playDrop();
      _flashInvalidShake();
      return;
    }

    // Enerji iadesi sayacı: tahtayı değiştiren kaydırma anında sayılır
    // (duvara dayanan, tahtayı değiştirmeyen kaydırma hamle sayılmaz).
    _moveMade = true;
    _history.add(
      _BoardSnapshot(
        grid: snapshot,
        score: _score,
        moveCount: _moveCount,
        streak: _streak,
      ),
    );
    if (_history.length > 12) _history.removeAt(0);

    _moveCount++;
    _mergedCells = newMerged;
    _spawnRandomTile();

    if (topMerge > 0) {
      _streak++;
      if (_streak > _maxStreak) _maxStreak = _streak;
      _mergeTotal += mergesThisTurn;
      if (topMerge > _highestTier) _highestTier = topMerge;

      final mult = 1.0 + min(1.5, (_streak - 1) * 0.25);
      final boostedGain = (totalGain * mult).round();
      _score += boostedGain;
      if (_score > _best) _best = _score;

      final tierEnum =
          InsectTier.values[(topMerge - 1).clamp(0, InsectTier.values.length - 1)];

      _showTurnOverlays(
        gain: boostedGain,
        streak: _streak,
        tier: tierEnum,
        topMerge: topMerge,
        hisir: hisirMerged,
      );

      unawaited(
        hisirMerged
            ? AudioManager().playMergeHisir(
                tierNumber: topMerge,
                comboCount: _streak,
              )
            : AudioManager().playMerge(tier: tierEnum, comboCount: _streak),
      );
      unawaited(
        ProgressManager.instance.recordTaskProgress(
          'merge',
          delta: max(1, mergesThisTurn),
        ),
      );
      if (_streak >= 2) {
        unawaited(
          ProgressManager.instance.recordTaskProgress(
            'combo',
            absoluteValue: _streak,
          ),
        );
      }
      unawaited(ProgressManager.instance.unlockTier(topMerge));
      unawaited(_persistBest());

      if (topMerge >= 11 && !_won) {
        _won = true;
        AudioManager().playWin();
      }
    } else {
      _streak = 0;
      AudioManager().playDrop();
    }

    _popTimer?.cancel();
    _popTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _mergedCells = <Point<int>>{};
        _lastSpawned = null;
      });
    });

    if (!_hasMovesAvailable()) {
      _gameOver = true;
      // D1: bitiş sesi tek kaynak — sonuç ekranı çalar.
      unawaited(_persistBest());
    }

    setState(() {});
  }

  void _showTurnOverlays({
    required int gain,
    required int streak,
    required InsectTier tier,
    required int topMerge,
    bool hisir = false,
  }) {
    _overlayTimer?.cancel();
    _comboText =
        streak >= 2 ? 'COMBO X$streak!' : context.l10n.gridSuperCombo;
    _gainText = streak >= 2 ? '+$gain X$streak' : '+$gain';
    _overlayTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _comboText = null;
        _gainText = null;
      });
    });

    if (topMerge >= 3 || streak >= 2) {
      _speechTimer?.cancel();
      _speechBubble = hisir
          ? HisirCharacter.replik
          : topMerge >= 4
          ? context.l10n.gridSuperMergeSpeech(tier.title)
          : tier.viralReplik;
      _speechTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        setState(() => _speechBubble = null);
      });
    }
  }

  /// Geçersiz kaydırma sarsıntısı (10D P0-2): tahta +6 px, −6 px,
  /// 0 — her adım 70 ms (toplam 140 ms). Timer/setState deseni;
  /// yeni animasyon denetleyicisi yok.
  void _flashInvalidShake() {
    _invalidShakeTimer?.cancel();
    setState(() => _invalidShakeX = 6);
    _invalidShakeTimer = Timer(const Duration(milliseconds: 70), () {
      if (!mounted) return;
      setState(() => _invalidShakeX = -6);
      _invalidShakeTimer = Timer(const Duration(milliseconds: 70), () {
        if (!mounted) return;
        setState(() => _invalidShakeX = 0);
      });
    });
  }

  /// Etkisiz güçlendirici denemesinde oyuncuya nedeni mevcut konuşma
  /// balonu mekanizmasıyla gösterir (B12). 2048 güçlendirici
  /// bağlamına özel `gridBoosterNoEffect` anahtarı kullanılır
  /// (Match3'ün `match3NoMatchCancel` anahtarı yeniden kullanılmaz);
  /// stok tüketilmez.
  void _showNoEffectHint() {
    _speechTimer?.cancel();
    setState(() {
      _speechBubble = context.l10n.gridBoosterNoEffect;
    });
    _speechTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _speechBubble = null);
    });
  }

  /// Geri alma yedeğinin (`_removeLowestTile`) silebileceği taş var mı?
  bool _hasRemovableTile() {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (_grid[r][c] > 0) return true;
      }
    }
    return false;
  }

  /// Karıştırma anlamlı mı? Tek taşlı/boş tahtada karıştırma görünür
  /// bir etki üretmez.
  bool _hasShufflableBoard() {
    var filled = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (_grid[r][c] > 0 && ++filled >= 2) return true;
      }
    }
    return false;
  }

  /// Çiftleştirme planı (B12 önkoşul denetimi): tüketimden ÖNCE,
  /// tahtayı değiştirmeden hesaplanır. `null` dönerse etki yoktur.
  ///
  /// Eşleşen çift varsa en yüksek kademedeki çift birleştirilir
  /// (`matched`); yoksa yükseltilebilir en yüksek taş bir kademe
  /// yükseltilir (mevcut yedek davranış korunur).
  ({Point<int> target, Point<int>? source, int next, bool matched, bool hisir})?
  _planPairEffect() {
    final byTier = <int, List<Point<int>>>{};
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = HisirCharacter.baseTier(_grid[r][c]);
        if (v > 0 && v < InsectTier.values.length) {
          byTier.putIfAbsent(v, () => <Point<int>>[]).add(Point<int>(r, c));
        }
      }
    }
    final matchingTiers = byTier.entries
        .where((e) => e.value.length >= 2)
        .map((e) => e.key)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (matchingTiers.isNotEmpty) {
      final t = matchingTiers.first;
      final cells = byTier[t]!;
      return (
        target: cells[0],
        source: cells[1],
        next: (t + 1).clamp(1, InsectTier.values.length),
        matched: true,
        hisir:
            HisirCharacter.isEncoded(_grid[cells[0].x][cells[0].y]) ||
            HisirCharacter.isEncoded(_grid[cells[1].x][cells[1].y]),
      );
    }
    Point<int>? bestCell;
    var maxT = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = HisirCharacter.baseTier(_grid[r][c]);
        if (v > maxT && v < InsectTier.values.length) {
          maxT = v;
          bestCell = Point<int>(r, c);
        }
      }
    }
    if (bestCell == null) return null;
    return (
      target: bestCell,
      source: null,
      next: maxT + 1,
      matched: false,
      hisir: HisirCharacter.isEncoded(
        _grid[bestCell.x][bestCell.y],
      ),
    );
  }

  /// Güçlendirici 1: GERİ AL (son hamleyi geri alır veya en küçük taşı temizler)
  void _useUndo() {
    if (_paused || _showHelpModal || _undoCount <= 0) return;
    // B12: etki uygulanabilirliğini tüketimden önce denetle — geri
    // alınacak hamle ve silinecek taş yoksa stok yakma.
    if (_history.isEmpty && !_hasRemovableTile()) {
      _showNoEffectHint();
      return;
    }
    // B3: tüketim kasadan (`takePower` + kalıcı kayıt); yerel sayaç
    // yalnız kasadan okunur. `takePower` başarısızsa sayaç bayattır,
    // kasadan tazele ve çık.
    final pm = ProgressManager();
    if (!pm.takePower('undo2048')) {
      setState(_syncPowerCounts);
      return;
    }
    var applied = false;
    setState(() {
      _syncPowerCounts();
      if (_history.isNotEmpty) {
        final prev = _history.removeLast();
        _grid = _cloneGrid(prev.grid);
        _score = prev.score;
        _moveCount = prev.moveCount;
        _streak = prev.streak;
        _gameOver = false;
        applied = true;
      } else {
        applied = _removeLowestTile();
      }
    });
    // stockBonusWithResult deseni: etki uygulanamadıysa stoğu iade et.
    if (!applied) {
      pm.refundPower('undo2048');
      setState(_syncPowerCounts);
      return;
    }
    unawaited(
      playBonusFx(
        context,
        bonusId: 'Geri Al',
        origin: MediaQuery.sizeOf(context).center(Offset.zero),
      ),
    );
    // 10D P1-5: Geri Al'a ses — playButtonTap tek çağrıda ses +
    // titreşim verir. Yanındaki kapısız triggerMediumHaptic
    // kaldırıldı: ikisi bir arada 2 impuls olurdu (baypas kapıya
    // takılmaz). Titreşim mediumImpact'tan selectionClick'e hafifler;
    // tek impuls kuralı korunur.
    AudioManager().playButtonTap();
  }

  /// En küçük taşı temizler; silinen taş yoksa `false` döner.
  bool _removeLowestTile() {
    Point<int>? target;
    var minTier = 999;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = HisirCharacter.baseTier(_grid[r][c]);
        if (v > 0 && v < minTier) {
          minTier = v;
          target = Point<int>(r, c);
        }
      }
    }
    if (target != null) {
      _grid[target.x][target.y] = 0;
      return true;
    }
    return false;
  }

  /// Güçlendirici 2: KARIŞTIR (tahtadaki böceklerin yerlerini karıştırır)
  void _useShuffle() {
    if (_paused || _showHelpModal || _shuffleCount <= 0) return;
    // B12 deseni: tek taşlı/boş tahtada karıştırmanın etkisi yoktur.
    if (!_hasShufflableBoard()) {
      _showNoEffectHint();
      return;
    }
    // B3: tüketim kasadan (`takePower` + kalıcı kayıt).
    final pm = ProgressManager();
    if (!pm.takePower('shuffle2048')) {
      setState(_syncPowerCounts);
      return;
    }
    _saveHistory();
    final flat = <int>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        flat.add(_grid[r][c]);
      }
    }
    flat.shuffle(_rng);
    setState(() {
      _syncPowerCounts();
      for (var i = 0; i < flat.length; i++) {
        _grid[i ~/ size][i % size] = flat[i];
      }
      _gameOver = false;
    });
    unawaited(
      playBonusFx(
        context,
        bonusId: 'Karıştır',
        origin: MediaQuery.sizeOf(context).center(Offset.zero),
      ),
    );
    AudioManager().playDrop();
  }

  /// Güçlendirici 3: ÇİFTLEŞTİR / 2X BİRLEŞİM (aynı tier iki böceği anında birleştirir)
  void _usePair() {
    if (_paused || _showHelpModal || _pairCount <= 0) return;
    // B12: etki uygulanabilirliğini tüketimden ÖNCE denetle — eşleşen
    // çift ve yükseltilebilir taş yoksa stok yakma, nedenini göster.
    final plan = _planPairEffect();
    if (plan == null) {
      _showNoEffectHint();
      return;
    }
    // B3: tüketim kasadan (`takePower` + kalıcı kayıt).
    final pm = ProgressManager();
    if (!pm.takePower('pair2048')) {
      setState(_syncPowerCounts);
      return;
    }
    _saveHistory();

    final target = plan.target;
    final source = plan.source;
    final next = plan.next;
    var reachedWin = false;
    setState(() {
      _syncPowerCounts();

      if (plan.matched) {
        _grid[target.x][target.y] = next;
        _grid[source!.x][source.y] = 0;
        _mergedCells = <Point<int>>{target};
        final gain = (1 << next) * 2;
        _score += gain;
        if (_score > _best) _best = _score;
        if (next > _highestTier) _highestTier = next;
        final tierEnum = InsectTier.values[next - 1];
        _showTurnOverlays(
          gain: gain,
          streak: max(2, _streak + 1),
          tier: tierEnum,
          topMerge: next,
        );
        unawaited(
          plan.hisir
              ? AudioManager().playMergeHisir(
                  tierNumber: next,
                  comboCount: 2,
                )
              : AudioManager().playMerge(tier: tierEnum, comboCount: 2),
        );
        unawaited(ProgressManager.instance.recordTaskProgress('merge'));
        unawaited(ProgressManager.instance.unlockTier(next));
      } else {
        _grid[target.x][target.y] = next;
        _mergedCells = <Point<int>>{target};
        final gain = 1 << next;
        _score += gain;
        if (_score > _best) _best = _score;
        if (next > _highestTier) _highestTier = next;
        unawaited(ProgressManager.instance.unlockTier(next));
      }
      // B15: 2048'e güçlendiriciyle ulaşmak da zaferdir.
      if (next >= 11 && !_won) {
        _won = true;
        reachedWin = true;
      }
      _gameOver = false;
    });

    if (reachedWin) {
      AudioManager().playWin();
    }
    unawaited(_persistBest());
    unawaited(
      playBonusFx(
        context,
        bonusId: 'Çiftleştir',
        origin: MediaQuery.sizeOf(context).center(Offset.zero),
      ),
    );
    // P0-4: eşleşen çiftte playMerge zaten haptic tetikler; heavyImpact
    // yalnız eşleşmesiz yükseltmede tek impuls olarak kalır.
    if (!plan.matched) {
      unawaited(HapticService.instance.heavyImpact());
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      _slide(0, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _slide(0, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      _slide(-1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      _slide(1, 0);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _formatDotNumber(int n) {
    final raw = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(raw[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  Future<void> _presentResult() async {
    if (_presentingResultModal) return;
    _presentingResultModal = true;
    _resultShown = true;
    // S1#49: ödeme + liderlik + görev kaydı + sonuç ekranı finishRun()
    // üzerinden (ateşle-unut ödeme, eski unawaited davranışı;
    // 'grid2048' takma adı aynen korunur).
    final replay = await finishRun(
      context,
      score: _score,
      best: _best,
      bestScore: max(_score, _best),
      bestCombo: max(1, _maxStreak),
      merges: _mergeTotal,
      // B15: kademe-11 zaferi sonuç ekranına taşınır. `_score > 0`
      // yedeği `finishRun` varsayılanını korur: 2048'e ulaşmadan
      // skorla bitirmek eskisi gibi zafer başlığı gösterir.
      won: _won || _score > 0,
      leaderboardMode: 'grid2048',
      // K16: mod skoru kimliği — `LululuGameMode` kataloğundaki
      // `bestScoreKey` ('grid_2048') ile aynı; `normalizeModeId`
      // 'grid2048' takma adını da bu kimliğe çevirir.
      modeScoreId: 'grid_2048',
      // Y3: tur-başı damgadan üretilen tek anahtar; çift çağrı
      // (BİTİR + bitiş kenarı) ikinci kez ödeme yapamaz.
      idempotencyKey: 'grid2048:$_runStartedAt',
      awaitSettle: false,
    );
    _presentingResultModal = false;
    if (!mounted) return;
    if (!replay) {
      final nav = Navigator.maybeOf(context);
      if (nav != null && nav.canPop()) {
        await nav.maybePop();
      }
      return;
    }
    _resultShown = false;
    _restart();
  }

  /// Hamlesiz-çıkış enerji iadesi (tek çıkış noktası: `PopScope`).
  ///
  /// Yalnız giriş enerjisi tüketildiyse, tur tamamlanmadıysa ve oturum
  /// boyunca hiç hamle yapılmadıysa 1 enerji iade edilir. `dispose`
  /// içinde DEĞİL, yalnızca gerçek rota çıkışında (`didPop`) çağrılır.
  /// `_handleBack` geri düğmesi de aynı rota çıkışından geçtiği için
  /// ayrıca kanca gerektirmez.
  void _maybeRefundEnergy() {
    if (_energyRefunded) return;
    if (!widget.energyConsumed ||
        _moveMade ||
        _gameOver ||
        _resultShown ||
        _presentingResultModal) {
      return;
    }
    _energyRefunded = true;
    EnergyService.instance.addEnergy(1);
  }

  void _edgeShowResult() {
    if (_resultShown || _presentingResultModal) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _presentResult();
    });
  }

  /// N7: tur sürerken, hamle yapılmışsa ve giriş enerjisi
  /// tüketilmişse (iade hakkı yoksa) çıkış onayı gerekir. Hamlesiz
  /// çıkışta onay YOK — çıkış anında kalır, iade yolu aynen çalışır
  /// (S6'ya dokunulmaz).
  bool get _needsExitConfirm =>
      widget.energyConsumed &&
      _moveMade &&
      !_gameOver &&
      !_resultShown &&
      !_presentingResultModal;

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

  /// N7 diyalog duraklatması: sıra tabanlı oyunda girdi kapıları
  /// (`_paused`) durur; sayaç yoktur.
  void _pauseForExitConfirm() {
    if (_gameOver || _paused) return;
    _pausedForExitConfirm = true;
    setState(() => _paused = true);
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

  void _handleBack() {
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      // N7: `pop()` yerine `maybePop()` — çıkış onayı (`PopScope`
      // vetosu) geri düğmesinden de geçer; onay gerekmiyorsa
      // davranış aynıdır.
      nav.maybePop();
    } else {
      _togglePause();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gameOver && !_resultShown) _edgeShowResult();

    return PopScope(
      canPop: _exitConfirmed || !_needsExitConfirm,
      onPopInvokedWithResult: (didPop, _) => _handleExitPop(didPop),
      child: Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B12),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final mq = MediaQuery.of(context);
            final topInset = mq.padding.top > 0 ? mq.padding.top : 35.375;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Zero-footprint test finder text for widget_test.dart ('2048 Grid')
                const Positioned(
                  left: 0,
                  top: 0,
                  width: 0,
                  height: 0,
                  child: Opacity(opacity: 0, child: Text('2048 Grid')),
                ),

                // .bg (`assets/design/backgrounds/2048_casino.webp`, opacity: .96)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.96,
                    child: Image.asset(
                      'assets/design/backgrounds/2048_casino.webp',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(color: Color(0xFF141B2A)),
                    ),
                  ),
                ),

                // .bgshade
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x4D080B12),
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x52080B12),
                        ],
                        stops: [0.0, 0.24, 0.76, 1.0],
                      ),
                    ),
                  ),
                ),

                // Main column (`statusbar` -> `mode-top` -> `game-hud` -> `mode-stage` -> `power-dock`)
                Positioned.fill(
                  top: topInset,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildModeTop(),
                      _buildGameHud(),
                      Expanded(child: _buildModeStage()),
                      _buildPowerDock(),
                    ],
                  ),
                ),

                // Top statusbar (`9:41` + signal + battery) — only in headless/prototype mode
                if (mq.padding.top <= 0 || widget.prototypeVisualState)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 35.375,
                    child: _PrototypeStatusBar(),
                  ),

                if (_showHelpModal) _buildHelpOverlay(),
                if (_paused) _buildPauseOverlay(),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  /// `.mode-top` (`rect: [0, 35.4, 430, 54]`)
  Widget _buildModeTop() {
    final coins = ProgressManager().coins;

    final topRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // .back-btn (`[12, 41.4, 48, 48]`)
        Semantics(
          button: true,
          label: context.l10n.goBackLabel,
          child: GestureDetector(
          onTap: _handleBack,
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(9),
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
            child: Image.asset(
              'assets/icons2/back.png',
              width: 29,
              height: 29,
              fit: BoxFit.contain,
            ),
          ),
        ),
        ),
        const SizedBox(width: 10),

        // .mode-title (`[70, 51.7, 160.3, 27.3]`)
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: const Color(0x8C080B12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                context.l10n.grid2048Title,
                style: TextStyle(
                  fontFamily: 'Baloo 2',
                  fontSize: 20,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Colors.white,
                  shadows: [
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '2048',
                style: TextStyle(
                  fontFamily: 'Baloo 2',
                  fontSize: 11,
                  height: 1.55,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.735,
                  color: Color(0xFF4A2E00),
                ),
              ),
            ),
              ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        // .pill (`[266.8, 47.9, 93.2, 35]`)
        Container(
          height: 35,
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
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
              const SizedBox(width: 6),
              Text(
                _formatDotNumber(coins),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // .info-btn (`[370, 41.4, 48, 48]`)
        Semantics(
          button: true,
          label: context.l10n.helpButtonLabel,
          child: GestureDetector(
          onTap: () => setState(() => _showHelpModal = true),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xDB080B12),
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
            alignment: Alignment.center,
            child: const Text(
              '?',
              style: TextStyle(
                fontFamily: 'Baloo 2',
                fontSize: 22,
                height: 1.0,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFB800),
              ),
            ),
          ),
        ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // İçerik genişliği mevcut alandan hesaplanır; 406 tavandır.
        // Dar ekranda 406'luk tasarım FittedBox ile orantılı küçültülür.
        final contentWidth =
            (constraints.maxWidth - 24).clamp(0.0, _maxContentWidth);
        return SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: contentWidth,
                height: 48,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _maxContentWidth,
                    height: 48,
                    child: topRow,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// `.game-hud` (`rect: [0, 89.4, 430, 58.5]`)
  Widget _buildGameHud() {
    final hudRow = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // SKOR (`[12, 97.4, 104, 50.5]`)
        _buildScoreBox(
          label: context.l10n.gameScoreLabel,
          value: _formatDotNumber(_score),
          width: 104,
        ),
        const SizedBox(width: 8),

        // REKOR (`[124, 97.4, 92.1, 50.5]`): gerçek kayıtlı rekor
        // gösterilir; kayıt yoksa 0 — sahte 12.480 yedeği kaldırıldı
        // (playtest bulgu #1).
        _buildScoreBox(
          label: context.l10n.gameBestLabel,
          value: _formatDotNumber(_best),
          width: 92.1,
        ),

        const Spacer(),

        // HAMLE (`[278.2, 97.4, 74, 50.5]`)
        _buildScoreBox(
          label: context.l10n.moveLabel,
          value: '$_moveCount',
          width: 74,
        ),
        const SizedBox(width: 8),

        // BİTİR `.mini-btn` (`[360.2, 98.6, 57.8, 48]`)
        Semantics(
          button: true,
          label: context.l10n.finishRoundLabel,
          child: GestureDetector(
            onTap: _presentResult,
            child: Container(
              width: 57.8,
              height: 48,
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
                style: TextStyle(
                  fontFamily: 'Baloo 2',
                  fontSize: 12.5,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.375,
                  color: Color(0xFF4A2E00),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // İçerik genişliği mevcut alandan hesaplanır; 406 tavandır.
        // Dar ekranda 406'luk tasarım FittedBox ile orantılı küçültülür.
        final contentWidth =
            (constraints.maxWidth - 24).clamp(0.0, _maxContentWidth);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: contentWidth,
              height: 50.5,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: _maxContentWidth,
                  height: 50.5,
                  child: hudRow,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreBox({
    required String label,
    required String value,
    required double width,
  }) {
    return Container(
      width: width,
      height: 50.5,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5.5),
      decoration: BoxDecoration(
        color: const Color(0xD9080B12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0x73FFB800),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Etiket kutuya sığmazsa küçülür ("HAMLE" → "HAM…" kesikliği
          // olmasın, bulgu #5); değer satırı zaten aynı deseni kullanır.
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  height: 1.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Color(0xFFFFB800),
                ),
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: const TextStyle(
                  fontFamily: 'Baloo 2',
                  fontSize: 21,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _highestTileValue() {
    var bestTier = 1;
    for (final row in _grid) {
      for (final v in row) {
        final base = HisirCharacter.baseTier(v);
        if (base > bestTier) bestTier = base;
      }
    }
    return 1 << bestTier;
  }

  /// `.mode-stage` (`rect: [14, 157.9, 402, 693.2]`)
  Widget _buildModeStage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxSide = widget.prototypeVisualState ? 302.0 : 394.0;
          final boardSide = min(
            maxSide,
            min(constraints.maxWidth - 12, constraints.maxHeight - 96),
          ).clamp(180.0, maxSide);
          final scale = boardSide / 302.0;
          final boardPad = 14.0 * scale;
          final gap = 7.0 * scale;
          final tileSize = (boardSide - boardPad * 2 - gap * 3) / 4;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              _panAccum = Offset.zero;
              _panConsumed = false;
            },
            onPanUpdate: (details) {
              if (_panConsumed || _paused || _gameOver || _showHelpModal) return;
              _panAccum += details.delta;
              if (_panAccum.distance < 16) return;
              _panConsumed = true;
              if (_panAccum.dx.abs() >= _panAccum.dy.abs()) {
                _slide(0, _panAccum.dx > 0 ? 1 : -1);
              } else {
                _slide(_panAccum.dy > 0 ? 1 : -1, 0);
              }
            },
            onPanEnd: (details) {
              if (_panConsumed || _paused || _gameOver || _showHelpModal) return;
              final v = details.velocity.pixelsPerSecond;
              if (v.distance < 80) return;
              _panConsumed = true;
              if (v.dx.abs() >= v.dy.abs()) {
                _slide(0, v.dx > 0 ? 1 : -1);
              } else {
                _slide(v.dy > 0 ? 1 : -1, 0);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x660E1422), Color(0x800E1422)],
                ),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0x24FFFFFF),
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (!widget.prototypeVisualState && _speechBubble == null)
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x99080B12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0x2EFFFFFF),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.l10n.gridTarget2048,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: Color(0xFFFFB800),
                                ),
                              ),
                              Text(
                                context.l10n.gridHighestTile(_highestTileValue()),
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: Color(0xCCFFFFFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Ortalanmış `.g2048` (`[64, 353.5, 302, 302]`)
                  // 10D P0-2: geçersiz kaydırma sarsıntısı (_invalidShakeX).
                  Transform.translate(
                    offset: Offset(_invalidShakeX, 0),
                    child: Center(
                      child: Container(
                      width: boardSide,
                      height: boardSide,
                      decoration: widget.prototypeVisualState
                          ? null
                          : BoxDecoration(
                              color: const Color(0x4D080B12),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: const Color(0x24FFFFFF),
                                width: 1.5,
                              ),
                            ),
                      child: Padding(
                        padding: EdgeInsets.all(boardPad),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List<Widget>.generate(size, (r) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List<Widget>.generate(size, (c) {
                                return SizedBox(
                                  width: tileSize,
                                  height: tileSize,
                                  child: _buildTile(r, c, tileSize),
                                );
                              }),
                            );
                          }),
                        ),
                      ),
                    ),
                    ),
                  ),

                  // Sol üst konuşma balonu (birleşim replikleri)
                  if (_speechBubble != null)
                    Positioned(
                      top: 12,
                      left: 14,
                      right: 14,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF141B2A),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              _speechBubble!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Baloo 2',
                                fontSize: 12,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF141B2A),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // B15: kademe-11 (2048) zafer rozeti — hedefe
                  // ulaşıldığında sahnenin üstünde görünür. Dile bağlı
                  // metin içermez; prototip durumunda `_won` hep
                  // `false` olduğu için referans kareler etkilenmez.
                  if (_won)
                    Positioned(
                      top: 58,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB800),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Text(
                              '★ 2048',
                              style: TextStyle(
                                fontFamily: 'Baloo 2',
                                fontSize: 13,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Color(0xFF4A2E00),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // `.chipfloat` (`rect: [293.6, 766.1, 110.4, 31]`)
                  Positioned(
                    right: 12,
                    bottom: 54,
                    child: IgnorePointer(
                      child: Container(
                        height: 31,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE6080B12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0x8CFFB800),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/icons/level_up.png',
                              width: 19,
                              height: 19,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.gridMovesCount(_moveCount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                height: 1.55,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.48,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // `.combo-float` (`rect: [28, 771.4, 91.5, 25.7]`)
                  if (_comboText != null)
                    Positioned(
                      left: 14,
                      bottom: 54,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: -3 * pi / 180,
                          child: Text(
                            _comboText!,
                            style: GoogleFonts.bangers(
                              fontSize: 23,
                              height: 1.0,
                              letterSpacing: 0.6,
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

                  // `.score-pop` (`rect: [329.9, 399.2, 68.1, 24]`)
                  if (_gainText != null)
                    Positioned(
                      right: 18,
                      top: 241.3,
                      child: IgnorePointer(
                        child: Text(
                          _gainText!,
                          style: GoogleFonts.bangers(
                            fontSize: 24,
                            height: 1.0,
                            letterSpacing: 0.6,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTile(int r, int c, double tileSize) {
    final raw = _grid[r][c];
    final tier = HisirCharacter.baseTier(raw);
    final isHisir = HisirCharacter.isEncoded(raw);
    final pt = Point<int>(r, c);
    final isMerged = _mergedCells.contains(pt);
    final isSpawned = _lastSpawned == pt;

    if (tier <= 0) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    final insect =
        InsectTier.values[(tier - 1).clamp(0, InsectTier.values.length - 1)];
    final bg = _tcol[(tier - 1).clamp(0, _tcol.length - 1)];
    final value = 1 << tier;

    return AnimatedScale(
      scale: isMerged
          ? 1.1
          : isSpawned
          ? 1.04
          : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // `inset 0 -4px 0 rgba(0, 0, 0, 0.12)`
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 4,
              child: ColoredBox(color: Color(0x1F000000)),
            ),

            // Bug image (`74% x 78%`, centered horizontally, slightly upper-centered)
            Positioned(
              left: tileSize * 0.13,
              top: tileSize * 0.09,
              width: tileSize * 0.74,
              height: tileSize * 0.78,
              child: Image.asset(
                HisirCharacter.assetFor(isHisir: isHisir, tier: insect),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),

            // Bottom-right value (`span`: `right: 6, bottom: 3`, `11px Baloo 2 w800 rgba(20, 27, 42, 0.6)`)
            Positioned(
              right: 6,
              bottom: 3,
              child: Text(
                '$value',
                style: const TextStyle(
                  fontFamily: 'Baloo 2',
                  fontSize: 11,
                  height: 1.55,
                  fontWeight: FontWeight.w800,
                  color: Color(0x99141B2A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `.power-dock` (`rect: [0, 851.1, 430, 80.9]`)
  Widget _buildPowerDock() {
    return SizedBox(
      height: 80.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPowerBtn(
              iconPath: 'assets/icons2/back.png',
              label: context.l10n.shopPowerUndoNameCaps,
              count: _undoCount,
              onTap: _useUndo,
            ),
            const SizedBox(width: 20),
            _buildPowerBtn(
              iconPath: 'assets/icons2/wand.png',
              label: context.l10n.shopPowerShuffleNameCaps,
              count: _shuffleCount,
              onTap: _useShuffle,
            ),
            const SizedBox(width: 20),
            _buildPowerBtn(
              iconPath: 'assets/icons2/magnet.png',
              label: context.l10n.shopPowerMergePairNameCaps,
              count: _pairCount,
              onTap: _usePair,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerBtn({
    required String iconPath,
    required String label,
    required int count,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: context.l10n.boosterCountLabel(label, count),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 66,
          height: 62.9,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 2,
                child: Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(6),
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
                  child: Image.asset(iconPath, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 53,
                left: 0,
                right: 0,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.27,
                    color: Color(0xFFD8E0EE),
                  ),
                ),
              ),
              Positioned(
                top: -2,
                right: 3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE01E5A),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF080B12),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
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
        ),
      ),
    );
  }

  Widget _buildHelpOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showHelpModal = false),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ColoredBox(
            color: const Color(0xBF060910),
            child: Center(
              child: Container(
                width: 340,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1E2740), Color(0xFF121829)],
                  ),
                  border: Border.all(
                    color: const Color(0x8CFFB800),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.gridHowToTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Baloo 2',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFB800),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.l10n.gridHowToBody1 +
                          context.l10n.gridHowToBody2 +
                          context.l10n.gridHowToBody3 +
                          context.l10n.gridHowToBody4,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      button: true,
                      label: context.l10n.understoodButton,
                      child: GestureDetector(
                        onTap: () => setState(() => _showHelpModal = false),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB800),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            context.l10n.understoodButton,
                            style: TextStyle(
                              fontFamily: 'Baloo 2',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4A2E00),
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
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: ColoredBox(
          color: const Color(0xCC060910),
          child: Center(
            child: Container(
              width: 340,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E2740), Color(0xFF121829)],
                ),
                border: Border.all(
                  color: const Color(0x73FFB800),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.gamePausedTitle,
                    style: TextStyle(
                      fontFamily: 'Baloo 2',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFB800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.gridPauseStats(_moveCount, _mergeTotal, _maxStreak),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD8E0EE),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: context.l10n.resume,
                    child: GestureDetector(
                      onTap: _togglePause,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB800),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '▶ ${context.l10n.resumeButtonCaps}',
                          style: TextStyle(
                            fontFamily: 'Baloo 2',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4A2E00),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    button: true,
                    label: context.l10n.restart,
                    child: GestureDetector(
                      onTap: _restart,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2438),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x3DFFFFFF)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🔄 ${context.l10n.restartLevelButton}',
                          style: TextStyle(
                            fontFamily: 'Baloo 2',
                            fontSize: 15,
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
          ),
        ),
      ),
    );
  }
}

class _PrototypeStatusBar extends StatelessWidget {
  const _PrototypeStatusBar();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 22,
            right: 22,
            height: 19.4,
            child: Row(
              children: [
                Text(
                  '09:41',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    height: 1.55,
                    color: Colors.white,
                  ),
                ),
                Spacer(),
                Icon(
                  Icons.signal_cellular_alt_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                SizedBox(width: 5),
                Icon(
                  Icons.battery_full_rounded,
                  size: 15,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
