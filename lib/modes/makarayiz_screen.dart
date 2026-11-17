import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/leaderboard_service.dart';
import '../screens/result_screen.dart';
import '../services/progress_manager.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';
import '../widgets/mode_bonus_bar.dart';

const _tcol = [
  Color(0xFFFFE9C9),
  Color(0xFFFFE3D6),
  Color(0xFFE4F0FF),
  Color(0xFFF3E4FF),
  Color(0xFFFFE0EC),
  Color(0xFFDFF7EA),
  Color(0xFFFFF0D6),
  Color(0xFFE8ECF5),
  Color(0xFFFFE1E1),
  Color(0xFFFFE0EC),
  Color(0xFFEDF1F8),
  Color(0xFFE8ECF5),
  Color(0xFFFFDFF2),
];

class _Note {
  _Note(this.lane, this.hitMs, this.tier, this.travelMs);
  final int lane;
  double hitMs;
  final int tier; // 0-based
  final double travelMs;
  bool done = false;
}

/// Makarayız — notalar beat çizgisine akar; vuruş penceresi çizgiye bağlıdır.
/// Zaman tek bir Ticker saatinden gelir (kare başına), böylece ses/görsel/giriş
/// aynı saatte kalır.
class MakarayizScreen extends StatefulWidget {
  const MakarayizScreen({
    super.key,
    @visibleForTesting this.prototypeVisualState = false,
  });

  final bool prototypeVisualState;

  @override
  State<MakarayizScreen> createState() => MakarayizScreenState();
}

class MakarayizScreenState extends State<MakarayizScreen>
    with SingleTickerProviderStateMixin {
  static const tutorialMs = 15000;
  static const _noteSize = 45.0;
  static const _beatInset = 44.0; // beat çizgisi şerit tabanından yukarıda

  late final Ticker _ticker;
  final _rng = Random();

  final List<_Note> _notes = [];
  double _now = 0; // ms
  double _nextHit = 0;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _best = 0;
  int _lives = 3;
  int _hits = 0;
  int _misses = 0;
  double _reel = 0;
  double _nextPulseMs = 1800;
  bool _alive = true;
  bool _resultShown = false;
  String _hint = 'Nota beat çizgisine gelince şeride dokun ya da kaydır.';
  String? _comboText;
  String? _breakText;
  String? _gainText;
  double _textUntil = 0;
  double _pulseAt = -1000;
  double _freezeUntil = 0;
  double _autoUntil = 0;
  double _x2Until = 0;
  int _bubbleTier = 2;

  bool get _auto => _now < _autoUntil;
  bool get _x2 => _now < _x2Until;

  /// İlk 15 sn eğitim hızı; sonra beat sıklaşır, nota daha hızlı iner.
  double _rampAt(double timeMs) =>
      ((timeMs - tutorialMs) / 60000).clamp(0.0, 1.0).toDouble();
  double _beatAt(double timeMs) => lerpDouble(900, 520, _rampAt(timeMs))!;
  double _travelAt(double timeMs) => lerpDouble(2600, 1500, _rampAt(timeMs))!;
  double get beatMs => _beatAt(_now);
  double get windowMs => lerpDouble(230, 140, _rampAt(_now))!;
  double get perfectMs => 70;

  @visibleForTesting
  List<({int lane, double hitMs})> get debugNotes => [
    for (final n in _notes)
      if (!n.done) (lane: n.lane, hitMs: n.hitMs),
  ];
  @visibleForTesting
  double get debugNow => _now;
  @visibleForTesting
  double get debugBeatMs => beatMs;
  @visibleForTesting
  double get debugWindowMs => windowMs;
  @visibleForTesting
  int get debugScore => _score;
  @visibleForTesting
  int get debugCombo => _combo;
  @visibleForTesting
  int get debugLives => _lives;
  @visibleForTesting
  bool get debugAlive => _alive;
  @visibleForTesting
  String? get debugBreakText => _breakText;
  @visibleForTesting
  String get debugHint => _hint;

  @override
  void initState() {
    super.initState();
    if (widget.prototypeVisualState) {
      _score = 1105;
      _best = 1760;
      _combo = 8;
      _reel = 0.64;
      _comboText = 'COMBO X8!';
      _textUntil = double.infinity;
      return;
    }
    AudioManager().initialize();
    unawaited(ProgressManager().load());
    _loadBest();
    _boot();
    _ticker = createTicker(_onTick)..start();
  }

  void _boot() {
    _notes.clear();
    _now = 0;
    _nextHit = 1800;
    _score = 0;
    _combo = 0;
    _bestCombo = 0;
    _lives = 3;
    _hits = 0;
    _misses = 0;
    _reel = 0;
    _nextPulseMs = _nextHit;
    _alive = true;
    _comboText = null;
    _breakText = null;
    _gainText = null;
    _freezeUntil = _autoUntil = _x2Until = 0;
    _hint = 'Nota beat çizgisine gelince şeride dokun ya da kaydır.';
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best = LeaderboardService.instance.getBest(
        LeaderboardService.modeMakarayiz,
      );
    });
  }

  @override
  void dispose() {
    if (!widget.prototypeVisualState) {
      AudioManager().stopAll();
      _ticker.dispose();
    }
    super.dispose();
  }

  Duration? _lastElapsed;
  void _onTick(Duration elapsed) {
    final dt = _lastElapsed == null
        ? 0.0
        : (elapsed - _lastElapsed!).inMicroseconds / 1000.0;
    _lastElapsed = elapsed;
    if (!_alive) return;
    // Opening grace in live ticker mode so the very first note before the
    // player's first tap doesn't immediately deduct a life at 1.9s.
    if (_hits == 0 && _now + dt < 4200) {
      for (final n in _notes) {
        if (!n.done && (_now + dt) - n.hitMs > windowMs * 0.85) {
          n.done = true;
          _showText(combo: 'BEAT ÇİZGİSİNDE BAS!');
        }
      }
    }
    advance(dt);
  }

  /// Oyun saatini ileri sar (test ve ticker ortak yolu).
  @visibleForTesting
  void advance(double dtMs) {
    final freezeFor = min(dtMs, max(0.0, _freezeUntil - _now));
    if (freezeFor > 0) {
      for (final note in _notes) {
        if (!note.done) note.hitMs += freezeFor;
      }
      _nextHit += freezeFor;
      _nextPulseMs += freezeFor;
    }
    _now += dtMs;
    while (_nextHit - _now <= _travelAt(_nextHit)) {
      _notes.add(
        _Note(
          _rng.nextInt(3),
          _nextHit,
          _rng.nextInt(InsectTier.values.length),
          _travelAt(_nextHit),
        ),
      );
      _nextHit += _beatAt(_nextHit);
    }
    if (_auto) {
      for (final n in _notes) {
        if (!n.done && _now >= n.hitMs) _hit(n);
      }
    }
    for (final n in _notes) {
      if (!n.done && _now - n.hitMs > windowMs) {
        n.done = true;
        _breakCombo('KAÇIRDIN', loseLife: true);
      }
    }
    _notes.removeWhere((n) => n.done && _now - n.hitMs > 400);
    while (_nextPulseMs <= _now) {
      _pulseAt = _nextPulseMs;
      _nextPulseMs += _beatAt(_nextPulseMs);
    }
    if (_textUntil.isFinite && _now > _textUntil) {
      _comboText = null;
      _breakText = null;
      _gainText = null;
    }
    if (mounted) setState(() {});
  }

  void _showText({String? combo, String? brk, String? gain}) {
    _comboText = combo;
    _breakText = brk;
    _gainText = gain;
    _textUntil = _now + 1400;
  }

  void _breakCombo(String reason, {required bool loseLife}) {
    final had = _combo;
    _combo = 0;
    _misses++;
    _hint = '$reason — vuruş penceresi: ±${windowMs.round()} ms';
    _showText(brk: had >= 2 ? 'KOMBO KIRILDI · $reason' : reason);
    HapticFeedback.heavyImpact();
    if (loseLife) {
      _lives -= 1;
      if (_lives <= 0) _gameOver();
    }
  }

  void _gameOver() {
    _alive = false;
    _hint = 'Makara bitti. Yeniden çek!';
    unawaited(AudioManager().playLose());
    unawaited(
      LeaderboardService.instance.submitScore(
        LeaderboardService.modeMakarayiz,
        _score,
      ),
    );
    if (_score > _best) _best = _score;
  }

  void _hit(_Note n) {
    final d = (_now - n.hitMs).abs();
    n.done = true;
    _combo += 1;
    _bestCombo = max(_bestCombo, _combo);
    _hits++;
    final perfect = d <= perfectMs;
    final gain = (60 + _combo * 10 + (perfect ? 40 : 0)) * (_x2 ? 2 : 1);
    _score += gain;
    _reel += 0.08;
    if (_reel >= 1) {
      _reel = 0;
      _score += 250;
      _lives = min(3, _lives + 1);
    }
    final bug = InsectTier.values[n.tier];
    _bubbleTier = n.tier;
    _hint = bug.viralReplik;
    _showText(
      combo: _combo >= 2 ? 'COMBO X$_combo!' : (perfect ? 'MÜKEMMEL!' : null),
      gain: '+$gain X$_combo',
    );
    unawaited(
      AudioManager().playMakaraSpin(
        bug: bug,
        comboCount: _combo,
        playbackRate: 0.95 + _rng.nextDouble() * 0.2,
      ),
    );
    HapticFeedback.mediumImpact();
  }

  /// Şerit vuruşu: pencere içindeki en yakın nota, çizgiye bağlıdır.
  void tryHit(int lane) {
    if (!_alive) return;
    _Note? best;
    double bestD = windowMs + 1;
    for (final n in _notes) {
      if (n.done) continue;
      final d = (_now - n.hitMs).abs();
      if (d <= windowMs && n.lane == lane && d < bestD) {
        best = n;
        bestD = d;
      }
    }
    if (best != null) {
      _hit(best);
    } else {
      final other =
          _notes
              .where(
                (n) =>
                    !n.done &&
                    n.lane != lane &&
                    (_now - n.hitMs).abs() <= windowMs,
              )
              .toList()
            ..sort(
              (a, b) =>
                  (_now - a.hitMs).abs().compareTo((_now - b.hitMs).abs()),
            );
      if (other.isNotEmpty) {
        other.first.done = true;
        _breakCombo('YANLIŞ ŞERİT', loseLife: true);
      } else if (_notes.any((n) => !n.done && n.lane == lane)) {
        _breakCombo('ERKEN DOKUNDUN', loseLife: false);
      }
    }
    setState(() {});
  }

  void _restart() => setState(_boot);

  bool _useBeatFreeze() {
    if (!_alive) return false;
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _freezeUntil = _now + 8000;
      _hint = 'BEAT DONDUR · 8 sn notalar dondu!';
      _showText(combo: 'BEAT DONDUR!');
    });
    return true;
  }

  bool _useAuto() {
    if (!_alive) return false;
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _autoUntil = _now + 6000;
      _hint = 'OTO MAKARA · 6 sn otomatik vuruş!';
      _showText(combo: 'OTO MAKARA!');
    });
    return true;
  }

  bool _useX2() {
    if (!_alive) return false;
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _x2Until = _now + 12000;
      _hint = 'PUAN X2 · 12 sn çift puan!';
      _showText(combo: 'PUAN X2 AKTİF!');
    });
    return true;
  }

  Future<void> _presentResult() async {
    final coins = ResultScoring.coinsFor(_score);
    await ProgressManager.instance.addCoins(coins);
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeMakarayiz,
      _score,
    );
    await ProgressManager.instance.recordTaskProgress('play');
    if (!mounted) return;
    final replay = await showGameResult(
      context,
      score: _score,
      coins: coins,
      stars: ResultScoring.starsFor(score: _score, best: _best),
    );
    if (!mounted) return;
    _resultShown = false;
    if (!replay) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    _restart();
  }

  void _edgeShowResult() {
    if (_resultShown) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _presentResult();
    });
  }

  static const _fixtureNotes = [
    [(8.0, 3), (46.0, 1), (72.0, 5)],
    [(26.0, 4), (62.0, 2)],
    [(14.0, 6), (52.0, 3), (80.0, 1)],
  ];

  Widget _note(
    double top,
    int tier, {
    double opacity = 1,
    bool wideScreen = false,
  }) {
    final bug =
        InsectTier.values[(tier - 1).clamp(0, InsectTier.values.length - 1)];
    if (wideScreen) {
      final topPad = (tier == 3 || tier == 4)
          ? 3.15
          : (tier == 2
                ? 5.9
                : (tier == 1 ? 7.2 : (tier == 5 ? 5.5 : 5.3)));
      return Positioned(
        top: top,
        left: 0,
        right: 0,
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: _noteSize,
              height: _noteSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _tcol[(tier - 1) % _tcol.length],
              ),
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minWidth: 38.7,
                maxWidth: 38.7,
                minHeight: 0,
                maxHeight: 120,
                child: Padding(
                  padding: EdgeInsets.only(top: topPad),
                  child: Image.asset(
                    bug.assetPath,
                    width: 38.7,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: _noteSize,
            height: _noteSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _tcol[(tier - 1) % _tcol.length],
            ),
            padding: const EdgeInsets.all(3),
            child: StickerImage(assetPath: bug.assetPath, size: 39),
          ),
        ),
      ),
    );
  }

  Widget _lane(int lane, double h, {bool wideScreen = false}) {
    final beatY = h - _beatInset;
    final children = <Widget>[];
    if (widget.prototypeVisualState) {
      for (final (pct, tier) in _fixtureNotes[lane]) {
        children.add(_note(pct / 100 * h, tier, wideScreen: wideScreen));
      }
    } else {
      for (final n in _notes) {
        if (n.lane != lane) continue;
        final p = 1 - (n.hitMs - _now) / n.travelMs;
        final top = -_noteSize + (beatY - _noteSize / 2 + _noteSize) * p;
        if (n.done) {
          children.add(
            _note(top, n.tier + 1, opacity: 0.0, wideScreen: wideScreen),
          );
        } else {
          children.add(_note(top, n.tier + 1, wideScreen: wideScreen));
        }
      }
    }
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => tryHit(lane),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x0FFFFFFF)),
          ),
          child: wideScreen
              ? Stack(clipBehavior: Clip.none, children: children)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(children: children),
                ),
        ),
      ),
    );
  }

  TextStyle _bangers(double size, Color c, Color glow) => GoogleFonts.bangers(
    fontSize: size,
    height: 1,
    letterSpacing: 0.6,
    color: c,
    shadows: [
      const Shadow(color: Color(0xEB080B12), offset: Offset(0, 3)),
      Shadow(color: glow.withValues(alpha: 0.9), blurRadius: 14),
      Shadow(color: glow.withValues(alpha: 0.55), blurRadius: 32),
      Shadow(color: glow.withValues(alpha: 0.32), blurRadius: 54),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!_alive && !_resultShown) _edgeShowResult();
    final proto = widget.prototypeVisualState;
    final wideScreen = MediaQuery.sizeOf(context).width >= 400;
    final pulse = proto ? 0.0 : (1 - ((_now - _pulseAt) / 220).clamp(0.0, 1.0));
    final pct = (_reel * 100).round();
    final hero = InsectTier.values[proto ? 2 : _bubbleTier];

    return _MakarayizChrome(
      score: _score,
      best: _best,
      combo: _combo,
      hint: _hint,
      onRestart: _restart,
      prototypeVisualState: proto,
      overlay: (!_alive && !_resultShown)
          ? ArcadeResultOverlay(
              title: 'MAKARA BİTTİ',
              message:
                  'En iyi kombo x$_bestCombo · $_hits vuruş · $_misses kaçan',
              score: _score,
              best: _best,
              won: false,
              modeTitle: 'Makarayız',
              shareLine: 'Makarayız abi!',
              retryLabel: 'YENİDEN',
              onRetry: _restart,
            )
          : null,
      bonuses: [
        stockBonus(
          id: 'beat',
          label: 'BEAT DONDUR',
          asset: 'assets/icons2/clock.png',
          effect: _useBeatFreeze,
        ),
        stockBonus(
          id: 'auto',
          label: 'OTO MAKARA',
          asset: 'assets/icons2/wheel.png',
          effect: _useAuto,
        ),
        stockBonus(
          id: 'x2',
          label: 'PUAN X2',
          asset: 'assets/icons2/boost_coins.png',
          effect: _useX2,
        ),
      ],
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 200) return;
          // Kaydırma: en yakın nota şeridini yöne göre seç.
          final cand =
              _notes
                  .where((n) => !n.done && (_now - n.hitMs).abs() <= windowMs)
                  .toList()
                ..sort(
                  (a, b) =>
                      (a.hitMs - _now).abs().compareTo((b.hitMs - _now).abs()),
                );
          if (cand.isNotEmpty) tryHit(cand.first.lane);
        },
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final h = c.maxHeight - 12 - 74 - 2;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 74),
                        child: Row(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) const SizedBox(width: 7),
                              _lane(i, h, wideScreen: wideScreen),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 118,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      boxShadow: pulse > 0
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.7 * pulse),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: CustomPaint(
                      size: const Size(double.infinity, 3),
                      painter: _DashPainter(),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: -19,
                    child: Text(
                      'BEAT',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: _reelWrap(hero, pct, wideScreen: wideScreen),
            ),
            if (!proto)
              Positioned(
                right: 12,
                top: 10,
                child: IgnorePointer(
                  child: Text(
                    '${'♥' * _lives}${'♡' * (3 - _lives)}',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFFE01E5A),
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (_comboText != null || _breakText != null)
              Positioned(
                left: 12,
                top: 10,
                child: IgnorePointer(
                  child: _breakText != null
                      ? Text(
                          _breakText!,
                          style: _bangers(
                            21,
                            const Color(0xFFE52E2E),
                            const Color(0xFFFFD700),
                          ),
                        )
                      : Text(
                          _comboText!,
                          style: _bangers(
                            23,
                            const Color(0xFFFFB800),
                            const Color(0xFFFF6B35),
                          ),
                        ),
                ),
              ),
            if (_gainText != null && !proto)
              Positioned(
                left: 126,
                top: 58,
                child: IgnorePointer(
                  child: Text(
                    _gainText!,
                    style: _bangers(
                      20,
                      const Color(0xFFFFB800),
                      const Color(0xFFFF6B35),
                    ),
                  ),
                ),
              ),
            if (proto || (_combo >= 2 && _alive))
              Positioned(
                right: 12,
                bottom: 158,
                child: IgnorePointer(
                  child: _bubble(hero, wideScreen: wideScreen),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(InsectTier bug, {bool wideScreen = false}) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 176),
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xF0080B12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xBFE01E5A), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x8CE01E5A), blurRadius: 14),
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            widget.prototypeVisualState
                ? 'MAKARAYIZ ABİ!'
                : bug.viralReplik.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.bangers(
              fontSize: 16.5,
              height: 1.05,
              letterSpacing: 0.6,
              color: const Color(0xFFFFB800),
              shadows: const [Shadow(color: Color(0xA6E01E5A), blurRadius: 10)],
            ),
          ),
        ),
        if (wideScreen)
          const Positioned(
            bottom: -7,
            child: CustomPaint(
              size: Size(14, 7),
              painter: _BubbleTailPainter(),
            ),
          ),
      ],
    );
  }

  Widget _reelWrap(InsectTier hero, int pct, {bool wideScreen = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFFD34D), Color(0xFFFFB800), Color(0xFFD98E00)],
              stops: [0, 0.65, 1],
            ),
            border: Border.all(color: const Color(0xFF8A5A00), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: StickerImage(assetPath: hero.assetPath, size: 41),
        ),
        const SizedBox(height: 5),
        FractionallySizedBox(
          widthFactor: 0.62,
          child: Column(
            children: [
              Container(
                height: 15,
                decoration: BoxDecoration(
                  color: const Color(0x24FFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _reel.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB800), Color(0xFFFF6B35)],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'MAKARA %$pct DOLDU',
                style: GoogleFonts.nunito(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  color: const Color(0xFF9AA7BC),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xF0080B12)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) => false;
}

class _MakarayizChrome extends StatelessWidget {
  const _MakarayizChrome({
    required this.score,
    required this.best,
    required this.combo,
    required this.hint,
    required this.onRestart,
    required this.prototypeVisualState,
    required this.bonuses,
    required this.child,
    this.overlay,
  });

  final int score;
  final int best;
  final int combo;
  final String hint;
  final VoidCallback onRestart;
  final bool prototypeVisualState;
  final List<ModeBonus> bonuses;
  final Widget child;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final hasShellStatusBar = topPad > 0;
    final wideScreen = MediaQuery.sizeOf(context).width >= 400;
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B12),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: wideScreen ? 0.96 : 1,
                child: Image.asset(
                  'assets/design/backgrounds/makarayiz_stage.webp',
                  fit: BoxFit.cover,
                  alignment: wideScreen
                      ? Alignment.center
                      : Alignment.centerLeft,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: wideScreen
                        ? const [0, 0.24, 0.76, 1]
                        : const [0, 0.3, 0.58, 1],
                    colors: wideScreen
                        ? const [
                            Color(0x4D080B12),
                            Color(0x00080B12),
                            Color(0x00080B12),
                            Color(0x52080B12),
                          ]
                        : const [
                            Color(0x7A080B12),
                            Color(0x00080B12),
                            Color(0x00080B12),
                            Color(0x94080B12),
                          ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                _statusBar(
                  hasShellStatusBar: hasShellStatusBar,
                  wideScreen: wideScreen,
                  topPad: topPad,
                ),
                _header(context, wideScreen: wideScreen),
                _hud(wideScreen: wideScreen),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: wideScreen
                            ? const [Color(0x660E1422), Color(0x800E1422)]
                            : const [Color(0x4C533351), Color(0x5952284E)],
                      ),
                      border: Border.all(
                        color: const Color(0x24FFFFFF),
                        width: 2,
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: child,
                    ),
                  ),
                ),
                _dock(wideScreen: wideScreen),
              ],
            ),
            ?overlay,
          ],
        ),
      ),
    );
  }

  Widget _statusBar({
    required bool hasShellStatusBar,
    required bool wideScreen,
    required double topPad,
  }) {
    final h = wideScreen ? 35.4 : 38.0;
    if (hasShellStatusBar) {
      return SizedBox(height: prototypeVisualState ? h : topPad);
    }
    return SizedBox(
      height: h,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, wideScreen ? 14 : 12, 22, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '09:41',
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                height: 1,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(
              width: 38,
              height: 16,
              child: CustomPaint(painter: _StatusIndicatorsPainter()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, {required bool wideScreen}) {
    if (wideScreen) {
      return SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(
            children: [
              _RoundButton(
                child: Image.asset(
                  'assets/icons2/back-prototype.png',
                  width: 29,
                  height: 29,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: Color(0xFF4A9DDB),
                  ),
                ),
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  runSpacing: 3,
                  children: [
                    Container(
                      height: 27,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x8C080B12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'MAKARAYIZ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 20,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Color(0xE6000000),
                              offset: Offset(0, 2),
                              blurRadius: 6,
                            ),
                            Shadow(
                              color: Color(0xD9000000),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 20.3,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'VİRAL',
                        style: GoogleFonts.baloo2(
                          fontSize: 10.5,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 35,
                padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                decoration: BoxDecoration(
                  color: const Color(0xD1080B12),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(color: Color(0x59000000), offset: Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons2/coin.png',
                      width: 25,
                      height: 25,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _format(
                        prototypeVisualState
                            ? 12450
                            : (ProgressManager().coins > 0
                                  ? ProgressManager().coins
                                  : 12450),
                      ),
                      style: GoogleFonts.nunito(
                        fontSize: 13.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RoundButton(
                circular: true,
                borderColor: const Color(0xB3FFB800),
                child: Text(
                  '?',
                  style: GoogleFonts.baloo2(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFB800),
                  ),
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('MAKARAYIZ'),
                    content: Text(hint),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('ANLADIM'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 8, 0),
        child: Row(
          children: [
            _RoundButton(
              child: Image.asset(
                'assets/icons2/back-prototype.png',
                width: 29,
                height: 29,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: Color(0xFF4A9DDB),
                ),
              ),
              onTap: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x66080B12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'MAKARAYIZ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.baloo2(
                        fontSize: 20,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Color(0xD9000000),
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
                  const SizedBox(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'VİRAL',
                      style: GoogleFonts.baloo2(
                        fontSize: 10.5,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
              decoration: BoxDecoration(
                color: const Color(0xD1080B12),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: Color(0x59000000), offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons2/coin.png',
                    width: 20,
                    height: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _format(
                      ProgressManager().coins > 0
                          ? ProgressManager().coins
                          : 12450,
                    ),
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _RoundButton(
              circular: true,
              borderColor: const Color(0xB3FFB800),
              child: Text(
                '?',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFB800),
                ),
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('MAKARAYIZ'),
                  content: Text(hint),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ANLADIM'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hud({required bool wideScreen}) {
    return SizedBox(
      height: wideScreen ? 58.5 : 60,
      child: Padding(
        padding: EdgeInsets.fromLTRB(wideScreen ? 12 : 11, 8, wideScreen ? 12 : 8, 0),
        child: LayoutBuilder(
          builder: (context, hudBox) {
            final row = Row(
              children: [
                SizedBox(
                  width: wideScreen ? 104 : 108,
                  child: _stat('SKOR', _format(score), wideScreen: wideScreen),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 84,
                  child: _stat('REKOR', _format(best), wideScreen: wideScreen),
                ),
                const Spacer(),
                SizedBox(
                  width: 74,
                  child: _stat('COMBO', 'x$combo', wideScreen: wideScreen),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRestart,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: wideScreen ? 57.8 : 58,
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
                      'BİTİR',
                      style: GoogleFonts.baloo2(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF4A2E00),
                      ),
                    ),
                  ),
                ),
              ],
            );
            if (hudBox.maxWidth >= 340) return row;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(width: 340, height: 50, child: row),
            );
          },
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {required bool wideScreen}) {
    return Container(
      height: wideScreen ? 50.5 : 50,
      alignment: Alignment.centerLeft,
      padding: wideScreen
          ? const EdgeInsets.fromLTRB(14, 6, 10, 6)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: wideScreen ? const Color(0xD9080B12) : const Color(0x73080B12),
        border: Border.all(
          color: wideScreen
              ? const Color(0x8CFFB800)
              : const Color(0x73FFB800),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                height: 1,
                letterSpacing: 1,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFFB800),
              ),
            ),
            const SizedBox(height: 3.5),
            Text(
              value,
              maxLines: 1,
              style: GoogleFonts.baloo2(
                fontSize: wideScreen ? 21 : 19,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dock({required bool wideScreen}) {
    return SizedBox(
      height: wideScreen ? 90.8 : 92,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, wideScreen ? 10 : 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < bonuses.length; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              _bonusButton(
                bonuses[i],
                prototypeVisualState ? const [2, 2, 1][i] : bonuses[i].count,
                wideScreen: wideScreen,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bonusButton(
    ModeBonus bonus,
    int count, {
    required bool wideScreen,
  }) {
    final enabled = count > 0 && bonus.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${bonus.label}. $count adet',
      child: GestureDetector(
        onTap: enabled ? bonus.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: count > 0 ? 1 : 0.55,
          child: SizedBox(
            width: 66,
            height: wideScreen ? 72.8 : 72,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    if (wideScreen) const SizedBox(height: 1.5),
                    Container(
                      height: 48,
                      width: 48,
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
                          width: 1.5,
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
                        bonus.asset,
                        width: wideScreen ? 36 : 30,
                        height: wideScreen ? 36 : 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: wideScreen ? 66 : 72,
                      child: Text(
                        bonus.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD8E0EE),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: wideScreen ? -2 : -4,
                  right: 3,
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
                      '$count',
                      style: GoogleFonts.baloo2(
                        fontSize: 11,
                        height: 1,
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
      ),
    );
  }

  static String _format(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.child,
    required this.onTap,
    this.circular = false,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool circular;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xD9080B12),
          borderRadius: BorderRadius.circular(circular ? 99 : 14),
          border: borderColor == null
              ? null
              : Border.all(color: borderColor!, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x73000000), offset: Offset(0, 3)),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _StatusIndicatorsPainter extends CustomPainter {
  const _StatusIndicatorsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 4; i++) {
      final height = 4.0 + i * 3.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1 + i * 4.5, size.height - height, 2.4, height),
          const Radius.circular(0.7),
        ),
        paint,
      );
    }
    final battery = RRect.fromRectAndRadius(
      Rect.fromLTWH(22, 3, 14, 9),
      const Radius.circular(2),
    );
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(battery, paint);
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, 5, 9, 5),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawRect(const Rect.fromLTWH(36.5, 5.5, 1.5, 4), paint);
  }

  @override
  bool shouldRepaint(_StatusIndicatorsPainter oldDelegate) => false;
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 3;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 1.5), Offset(min(x + 5, size.width), 1.5), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}
