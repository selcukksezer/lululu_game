import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/leaderboard_service.dart';
import '../services/score_share_card.dart';
import '../theme/lululu_theme.dart';
import '../widgets/kenney_button.dart';
import '../widgets/kenney_panel.dart';
import '../widgets/star_row.dart';

class Grid2048Screen extends StatefulWidget {
  const Grid2048Screen({super.key});

  @override
  State<Grid2048Screen> createState() => _Grid2048ScreenState();
}

class _Grid2048ScreenState extends State<Grid2048Screen> {
  static const int gridSize = 4;

  late List<List<int>> _board;
  int _score = 0;
  int _bestScore = 0;
  bool _isGameOver = false;
  bool _isWon = false;
  bool _hasContinuedAfterWin = false;
  bool _paused = false;

  String _activeSpeechBubble = '';
  Timer? _speechTimer;
  int _peakTile = 0;
  Offset _pan = Offset.zero;

  // Stats / combo
  int _moveCount = 0;
  int _mergeTotal = 0;
  int _maxCombo = 0;
  int _streak = 0; // consecutive merge-swipes
  double _comboMeter = 0;
  String? _milestoneToast;
  Timer? _milestoneTimer;
  final Set<int> _milestonesHit = {};
  final _rng = Random();
  int _pulseValue = 0;
  int _pulseEpoch = 0;
  Timer? _pulseTimer;

  static const _milestoneTiles = [64, 128, 256, 512, 1024, 2048, 4096];

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _loadBestScore();
    _initBoard();
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _speechTimer?.cancel();
    _milestoneTimer?.cancel();
    _pulseTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bestScore = prefs.getInt('lululu_2048_best') ?? 0;
    });
  }

  Future<void> _saveBestScore(int score) async {
    if (score > _bestScore) {
      _bestScore = score;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lululu_2048_best', _bestScore);
    }
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance
        .submitScore(LeaderboardService.mode2048, score);
  }

  void _initBoard() {
    _board = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    _score = 0;
    _isGameOver = false;
    _isWon = false;
    _hasContinuedAfterWin = false;
    _paused = false;
    _peakTile = 0;
    _moveCount = 0;
    _mergeTotal = 0;
    _maxCombo = 0;
    _streak = 0;
    _comboMeter = 0;
    _milestonesHit.clear();
    _milestoneToast = null;
    _activeSpeechBubble = '';
    _pulseValue = 0;
    _pulseEpoch = 0;
    _spawnRandomTile();
    _spawnRandomTile();
    setState(() {});
  }

  /// Early game: almost always 2. Late: more 4s when board crowded.
  void _spawnRandomTile() {
    final emptyCells = <Point<int>>[];
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_board[r][c] == 0) emptyCells.add(Point(r, c));
      }
    }
    if (emptyCells.isEmpty) return;

    final filled = 16 - emptyCells.length;
    final fourChance = filled < 4
        ? 0.08
        : filled < 10
            ? 0.12
            : 0.22;
    final p = emptyCells[_rng.nextInt(emptyCells.length)];
    _board[p.x][p.y] = _rng.nextDouble() < (1 - fourChance) ? 2 : 4;
  }

  void _togglePause() {
    if (_isGameOver || _isWon) return;
    setState(() => _paused = !_paused);
  }

  void _handleSwipe(int dx, int dy) {
    if (_isGameOver || _paused) return;

    var moved = false;
    var turnScore = 0;
    var highestMergedVal = 0;
    var mergesThisTurn = 0;

    if (dx != 0) {
      for (int r = 0; r < gridSize; r++) {
        final row = List<int>.from(_board[r]);
        if (dx < 0) {
          final res = _slideAndMerge(row);
          if (res.moved) moved = true;
          turnScore += res.score;
          mergesThisTurn += res.mergeCount;
          if (res.maxMerged > highestMergedVal) highestMergedVal = res.maxMerged;
          _board[r] = res.line;
        } else {
          final reversed = row.reversed.toList();
          final res = _slideAndMerge(reversed);
          if (res.moved) moved = true;
          turnScore += res.score;
          mergesThisTurn += res.mergeCount;
          if (res.maxMerged > highestMergedVal) highestMergedVal = res.maxMerged;
          _board[r] = res.line.reversed.toList();
        }
      }
    } else if (dy != 0) {
      for (int c = 0; c < gridSize; c++) {
        final col = List.generate(gridSize, (r) => _board[r][c]);
        if (dy < 0) {
          final res = _slideAndMerge(col);
          if (res.moved) moved = true;
          turnScore += res.score;
          mergesThisTurn += res.mergeCount;
          if (res.maxMerged > highestMergedVal) highestMergedVal = res.maxMerged;
          for (int r = 0; r < gridSize; r++) {
            _board[r][c] = res.line[r];
          }
        } else {
          final reversed = col.reversed.toList();
          final res = _slideAndMerge(reversed);
          if (res.moved) moved = true;
          turnScore += res.score;
          mergesThisTurn += res.mergeCount;
          if (res.maxMerged > highestMergedVal) highestMergedVal = res.maxMerged;
          final unreversed = res.line.reversed.toList();
          for (int r = 0; r < gridSize; r++) {
            _board[r][c] = unreversed[r];
          }
        }
      }
    }

    if (!moved) {
      return;
    }

    // Combo heat: multi-merge swipe + streak of merge-swipes.
    if (mergesThisTurn > 0) {
      _streak++;
      _mergeTotal += mergesThisTurn;
      if (mergesThisTurn > _maxCombo) _maxCombo = mergesThisTurn;
      if (_streak > _maxCombo) _maxCombo = _streak;
      final heat = 1.0 +
          min(0.9, (_streak - 1) * 0.1) +
          min(0.5, (mergesThisTurn - 1) * 0.15);
      turnScore = (turnScore * heat).round();
      _comboMeter = min(1.0, 0.3 + _streak * 0.12 + mergesThisTurn * 0.08);
    } else {
      _streak = 0;
      _comboMeter = max(0, _comboMeter - 0.25);
    }

    _score += turnScore;
    _moveCount++;
    unawaited(_saveBestScore(_score));

    if (highestMergedVal > _peakTile) {
      _peakTile = highestMergedVal;
      _checkMilestone(highestMergedVal);
    }
    final boardPeak = _boardPeak();
    if (boardPeak > _peakTile) {
      _peakTile = boardPeak;
      _checkMilestone(boardPeak);
    }

    _spawnRandomTile();
    AudioManager().triggerHaptic();

    if (highestMergedVal > 0) {
      _playMergeSoundAndQuote(highestMergedVal);
      _pulseMerged(highestMergedVal);
    } else {
      AudioManager().playDrop();
    }

    if (!_hasContinuedAfterWin && highestMergedVal >= 2048) {
      _isWon = true;
      AudioManager().playWin();
    }

    if (!_canMove()) {
      _isGameOver = true;
      AudioManager().playLose();
    }

    setState(() {});
  }

  void _pulseMerged(int value) {
    _pulseTimer?.cancel();
    _pulseValue = value;
    _pulseEpoch++;
    final epoch = _pulseEpoch;
    _pulseTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || epoch != _pulseEpoch) return;
      setState(() => _pulseValue = 0);
    });
  }

  void _checkMilestone(int tile) {
    for (final m in _milestoneTiles) {
      if (tile >= m && !_milestonesHit.contains(m)) {
        _milestonesHit.add(m);
        _showMilestone('YENİ KARO · $m');
        final tierN = (log(m) / ln2).round().clamp(1, 8);
        unawaited(AudioManager().playMerge(tierNumber: tierN, comboCount: 2));
        break;
      }
    }
  }

  void _showMilestone(String text) {
    _milestoneTimer?.cancel();
    setState(() => _milestoneToast = text);
    _milestoneTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _milestoneToast = null);
    });
  }

  void _showSpeech(String text, {int seconds = 3}) {
    _speechTimer?.cancel();
    setState(() => _activeSpeechBubble = text);
    _speechTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _activeSpeechBubble = '');
    });
  }

  _MergeResult _slideAndMerge(List<int> line) {
    final nonZero = line.where((v) => v != 0).toList();
    final merged = <int>[];
    var score = 0;
    var maxMerged = 0;
    var mergeCount = 0;
    var i = 0;

    while (i < nonZero.length) {
      if (i + 1 < nonZero.length && nonZero[i] == nonZero[i + 1]) {
        final val = nonZero[i] * 2;
        merged.add(val);
        score += val;
        mergeCount++;
        if (val > maxMerged) maxMerged = val;
        i += 2;
      } else {
        merged.add(nonZero[i]);
        i++;
      }
    }

    while (merged.length < gridSize) {
      merged.add(0);
    }

    var changed = false;
    for (int j = 0; j < gridSize; j++) {
      if (merged[j] != line[j]) {
        changed = true;
        break;
      }
    }

    return _MergeResult(
      line: merged,
      moved: changed,
      score: score,
      maxMerged: maxMerged,
      mergeCount: mergeCount,
    );
  }

  bool _canMove() {
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (_board[r][c] == 0) return true;
        if (r + 1 < gridSize && _board[r][c] == _board[r + 1][c]) return true;
        if (c + 1 < gridSize && _board[r][c] == _board[r][c + 1]) return true;
      }
    }
    return false;
  }

  void _playMergeSoundAndQuote(int val) {
    final tier = _getTierForValue(val);
    AudioManager().playMerge(tier: tier);
    _showSpeech(tier.viralReplik);
  }

  InsectTier _getTierForValue(int val) {
    switch (val) {
      case 2:
        return InsectTier.cone;
      case 4:
        return InsectTier.helmet;
      case 8:
        return InsectTier.fan;
      case 16:
        return InsectTier.dancer;
      case 32:
        return InsectTier.diva;
      case 64:
        return InsectTier.can;
      case 128:
        return InsectTier.kongo;
      case 256:
        return InsectTier.bed;
      case 512:
        return InsectTier.diva;
      case 1024:
        return InsectTier.kongo;
      case 2048:
      case 4096:
      default:
        return InsectTier.bed;
    }
  }

  int _boardPeak() {
    var peak = 0;
    for (final row in _board) {
      for (final v in row) {
        if (v > peak) peak = v;
      }
    }
    return peak;
  }

  int _hudStarCount() {
    final peak = _boardPeak();
    if (peak >= 2048) return 3;
    if (peak >= 1024) return 2;
    if (peak >= 512) return 1;
    return 0;
  }

  int _sessionStarCount() {
    if (_score >= 15000 || _peakTile >= 4096) return 3;
    if (_score >= 8000 || _peakTile >= 2048) return 2;
    if (_score >= 2500 || _peakTile >= 1024) return 1;
    return 0;
  }

  String _statsLine() =>
      'Hamle $_moveCount · Birleşim $_mergeTotal · Max combo x$_maxCombo · Zirve $_peakTile';

  DateTime _lastSwipeAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _commitPan() {
    if (_paused || _isGameOver) {
      _pan = Offset.zero;
      return;
    }
    final dx = _pan.dx;
    final dy = _pan.dy;
    _pan = Offset.zero;
    // Ignore diagonal noise / micro pans — stops phantom bottom spawns.
    if (dx.abs() < 28 && dy.abs() < 28) return;
    // Dominant axis must clearly win (horizontal vs vertical).
    if (dx.abs() > dy.abs()) {
      if (dx.abs() < dy.abs() * 1.35 && dy.abs() > 18) return;
    } else {
      if (dy.abs() < dx.abs() * 1.35 && dx.abs() > 18) return;
    }
    final now = DateTime.now();
    if (now.difference(_lastSwipeAt).inMilliseconds < 160) return;
    _lastSwipeAt = now;
    if (dx.abs() > dy.abs()) {
      _handleSwipe(dx > 0 ? 1 : -1, 0);
    } else {
      _handleSwipe(0, dy > 0 ? 1 : -1);
    }
  }

  Future<void> _shareScore() async {
    await ScoreShareCard.instance.share(
      modeTitle: 'Lülülü 2048',
      score: _score,
      best: _bestScore,
      line: _statsLine(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    // Material required — without it Flutter paints yellow debug underlines on Text.
    return Scaffold(
      backgroundColor: LululuColors.carbonVoid,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'assets/images/bg_kitchen_counter.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(canPop),
                const SizedBox(height: 8),
                StarRow(filledCount: _hudStarCount(), size: 26),
                const SizedBox(height: 10),
                _buildScoreRow(),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _comboMeter,
                      minHeight: 6,
                      backgroundColor: LululuColors.darkObsidian,
                      color: Color.lerp(
                        LululuColors.liquidGold,
                        LululuColors.cyberFuchsia,
                        _comboMeter,
                      ),
                    ),
                  ),
                ),
                if (_streak >= 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'STREAK x$_streak',
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w900,
                        color: LululuColors.toxicNeon,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (_activeSpeechBubble.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: KenneyPanel(
                      palette: KenneyPalette.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Text(
                        _activeSpeechBubble,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: LululuColors.liquidGold,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = min(
                        constraints.maxWidth - 24,
                        constraints.maxHeight - 8,
                      );
                      final grid = side.clamp(160.0, 420.0).toDouble();
                      return Center(
                        child: SizedBox(
                          width: grid,
                          height: grid,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (_) => _pan = Offset.zero,
                            onPanUpdate: (details) => _pan += details.delta,
                            onPanEnd: (_) => _commitPan(),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: LululuColors.spaceNavy,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: LululuColors.liquidGold
                                      .withValues(alpha: 0.45),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: LululuColors.liquidGold
                                        .withValues(alpha: 0.16),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: IgnorePointer(
                                  child: GridView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: 16,
                                    itemBuilder: (context, idx) {
                                      final r = idx ~/ 4;
                                      final c = idx % 4;
                                      return _buildTile(_board[r][c]);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: KenneyButton(
                          label: _paused ? 'DEVAM' : 'DURAKLAT',
                          primary: false,
                          palette: KenneyPalette.blue,
                          onPressed: _togglePause,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KenneyButton(
                          label: 'YENİ',
                          onPressed: _initBoard,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_milestoneToast != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 120,
              left: 40,
              right: 40,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LululuGradients.fuchsiaToGold,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _milestoneToast!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.exo2(
                      fontWeight: FontWeight.w900,
                      color: LululuColors.carbonVoid,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          if (_paused && !_isGameOver && !_isWon)
            Positioned.fill(
              child: ColoredBox(
                color: LululuColors.carbonVoid.withValues(alpha: 0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DURAKLATILDI',
                        style: GoogleFonts.exo2(
                          fontSize: 26,
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
                      KenneyButton(label: 'DEVAM', onPressed: _togglePause),
                    ],
                  ),
                ),
              ),
            ),
          if (_isWon)
            _buildOverlayModal(
              palette: KenneyPalette.yellow,
              title: '2048 ŞAMPİYONU!',
              subtitle: _statsLine(),
              stars: _sessionStarCount(),
              scoreLabel: 'Skor: $_score',
              actions: [
                Expanded(
                  child: KenneyButton(
                    label: 'HUB',
                    primary: false,
                    palette: KenneyPalette.grey,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KenneyButton(
                    label: 'DEVAM',
                    primary: false,
                    palette: KenneyPalette.grey,
                    onPressed: () {
                      setState(() {
                        _isWon = false;
                        _hasContinuedAfterWin = true;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KenneyButton(
                    label: 'YENİ',
                    onPressed: _initBoard,
                  ),
                ),
              ],
            ),
          if (_isGameOver)
            _buildOverlayModal(
              palette: KenneyPalette.red,
              title: 'DUKTURU ARAYIN!',
              subtitle: _statsLine(),
              stars: _sessionStarCount(),
              scoreLabel: 'Final: $_score',
              actions: [
                Expanded(
                  child: KenneyButton(
                    label: 'HUB',
                    primary: false,
                    palette: KenneyPalette.grey,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KenneyButton(
                    label: 'PAYLAŞ',
                    primary: false,
                    palette: KenneyPalette.grey,
                    onPressed: _shareScore,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KenneyButton(
                    label: 'TEKRAR',
                    palette: KenneyPalette.red,
                    onPressed: _initBoard,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOverlayModal({
    required KenneyPalette palette,
    required String title,
    required String subtitle,
    required int stars,
    required String scoreLabel,
    required List<Widget> actions,
  }) {
    return Positioned.fill(
      child: ColoredBox(
        color: LululuColors.carbonVoid.withValues(alpha: 0.88),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: KenneyPanel(
              palette: palette,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.liquidGold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: LululuColors.mutedTitanium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StarRow(filledCount: stars, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    scoreLabel,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: LululuColors.ink,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool canPop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          if (canPop)
            _KenneyIconTap(
              asset: LululuKenneyAssets.buttonRoundDepthGradient(
                KenneyPalette.grey,
              ),
              icon: Icons.arrow_back_ios_new,
              semanticsLabel: 'Geri',
              onTap: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Column(
              children: [
                Text(
                  '2048 Grid',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: LululuColors.liquidGold,
                        letterSpacing: 1.2,
                      ),
                ),
                Text(
                  'Zirve $_peakTile · kaydır birleştir',
                  style: const TextStyle(
                    fontSize: 11,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildScoreRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildScoreCard('SKOR', '$_score')),
          const SizedBox(width: 10),
          Expanded(child: _buildScoreCard('REKOR', '$_bestScore')),
          const SizedBox(width: 10),
          Expanded(child: _buildScoreCard('HAMLE', '$_moveCount')),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, String value) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LululuColors.spaceNavy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: LululuColors.liquidGold.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: LululuColors.mutedTitanium,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: LululuColors.liquidGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(int val) {
    if (val == 0) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: LululuColors.carbonVoid.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LululuColors.darkObsidian),
        ),
      );
    }

    final tier = _getTierForValue(val);
    final hot = val >= 512;
    final pulse = val == _pulseValue && _pulseValue > 0;
    return AnimatedScale(
      scale: pulse ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LululuColors.spaceNavy,
              tier.color.withValues(alpha: hot || pulse ? 0.55 : 0.38),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: pulse
                ? LululuColors.toxicNeon
                : tier.color.withValues(alpha: 0.9),
            width: hot || pulse ? 2.2 : 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: (pulse ? LululuColors.toxicNeon : tier.color)
                  .withValues(alpha: hot || pulse ? 0.55 : 0.35),
              blurRadius: hot || pulse ? 16 : 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  tier.assetPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.bug_report, color: LululuColors.liquidGold),
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              right: 5,
              child: Text(
                '$val',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.liquidGold,
                  shadows: [
                    Shadow(color: LululuColors.carbonVoid, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KenneyIconTap extends StatelessWidget {
  const _KenneyIconTap({
    required this.asset,
    required this.icon,
    required this.onTap,
    this.semanticsLabel,
  });

  final String asset;
  final IconData icon;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  asset,
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
                Icon(icon, size: 18, color: LululuColors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MergeResult {
  const _MergeResult({
    required this.line,
    required this.moved,
    required this.score,
    required this.maxMerged,
    required this.mergeCount,
  });

  final List<int> line;
  final bool moved;
  final int score;
  final int maxMerged;
  final int mergeCount;
}
