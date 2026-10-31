import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/daily_challenge_service.dart';
import '../services/leaderboard_service.dart';
import '../screens/result_screen.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';

/// Viral “Scream” runner — spam zıplatır; skor yalnız kapı geçişinden gelir.
class ScreamRoachScreen extends StatefulWidget {
  const ScreamRoachScreen({super.key});

  @override
  State<ScreamRoachScreen> createState() => _ScreamRoachScreenState();
}

class _ScreamRoachScreenState extends State<ScreamRoachScreen>
    with SingleTickerProviderStateMixin {
  static const _bugSize = 52.0;
  static const _gateW = 62.0;
  static const _grassH = 52.0;
  static const _screamCooldown = Duration(milliseconds: 90);
  static const _startGrace = 1.35;
  static const _groundGrace = 1.55;

  static const _sky = 'assets/images/scream/sky_strip.png';
  static const _grass = 'assets/images/scream/terrain_grass.png';
  static const _grassTile = 'assets/images/scream/grass_tile.png';

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double _x = 78;
  double _y = 220;
  double _vy = 0;
  double _power = 0;
  int _score = 0;
  int _best = 0;
  int _screamStreak = 0;
  int _maxScreamStreak = 0;
  int _dayStreak = 0;
  int _gatesPassed = 0;
  bool _alive = true;
  bool _resultShown = false;
  bool _layoutReady = false;
  bool _layoutBootstrapping = false;
  double _groundIdle = 0;
  double _aliveFor = 0;
  String _hint = 'Spam dokun = zıpla. Terlik · sprey · tava arasından geç!';
  late final Random _rng;
  final List<_Gate> _gates = [];
  double _world = 0;
  InsectTier _bug = InsectTier.helmet;
  String _callout = '';
  DateTime _lastScreamAt = DateTime.fromMillisecondsSinceEpoch(0);
  /// Voice lock: no new SFX / no character swap until clip ends.
  bool _voiceBusy = false;
  late final double _gateSpacing;
  double _floorY = 420;
  double _ceilY = 72;
  double _arenaW = 320;
  double _arenaH = 480;

  @override
  void initState() {
    super.initState();
    final day = DateTime.now();
    final seed = day.year * 10000 + day.month * 100 + day.day;
    _rng = Random(seed ^ 0x5C12);
    _gateSpacing = 250 + (seed % 40).toDouble();
    AudioManager().initialize();
    _ticker = createTicker(_onTick)..start();
    _loadBest();
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    await DailyChallengeService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best =
          LeaderboardService.instance.getBest(LeaderboardService.modeScream);
      _dayStreak = DailyChallengeService.instance.streak;
    });
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _ticker.dispose();
    super.dispose();
  }

  void _applyLayout(double w, double h) {
    _arenaW = max(200.0, w);
    _arenaH = max(240.0, h);
    _floorY = _arenaH - 4;
    _ceilY = min(88.0, _arenaH * 0.12).clamp(52.0, 100.0);
    if (_layoutReady || _layoutBootstrapping) return;
    _layoutBootstrapping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _layoutReady) return;
      setState(() {
        _layoutReady = true;
        _layoutBootstrapping = false;
        _y = _ceilY + (_floorY - _ceilY - _bugSize) * 0.42;
        _vy = 0;
        _gates.clear();
        _spawnGate(initial: true);
      });
    });
  }

  void _onTick(Duration elapsed) {
    if (!_alive || !_layoutReady) return;
    if (_last == Duration.zero) {
      _last = elapsed;
      return;
    }
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 0.033) dt = 0.033;

    _aliveFor += dt;
    _power = (_power - dt * 1.15).clamp(0.0, 1.0);

    // Idle yavaş sürüklenme; spam hızı artırır. Mesafe puan vermez.
    final scroll = 70 + _power * 280;
    _world += scroll * dt;

    // Flappy-ish gravity — spam ile kontrol edilebilir.
    _vy += (980 - _power * 1100) * dt;
    _y += _vy * dt;

    final floorBug = _floorY - _grassH * 0.35 - _bugSize;
    if (_y >= floorBug) {
      _y = floorBug;
      if (_vy > 0) _vy = 0;
      _groundIdle += dt;
      // Başlangıç grace + çimde kısa dinlenme OK; uzun uyku = ölüm.
      if (_aliveFor > _startGrace &&
          _groundIdle > _groundGrace &&
          _power < 0.12) {
        _die('Çimde uyudun! Zıpla / spam et.');
        return;
      }
    } else {
      _groundIdle = 0;
    }
    if (_y < _ceilY) {
      _y = _ceilY;
      _vy = min(0, _vy);
    }

    for (final g in _gates) {
      g.x = g.base - _world;
    }
    _gates.removeWhere((g) => g.x < -_gateW - 40);

    // Keep ~2 gates ahead — spacing from last.base (never stack on _world).
    while (_gates.length < 3) {
      _spawnGate();
    }
    if (_gates.isNotEmpty && _gates.last.x < _arenaW * 0.55) {
      _spawnGate();
    }

    final bugRect = Rect.fromLTWH(_x, _y, _bugSize, _bugSize).deflate(5);
    for (final g in _gates) {
      if (_aliveFor > _startGrace && _hitGate(bugRect, g)) {
        _die('${g.kind.deathLine} Kapı $_gatesPassed');
        return;
      }
      if (!g.scored && g.x + _gateW < _x) {
        g.scored = true;
        _gatesPassed++;
        _score = _gatesPassed * 10 + (_maxScreamStreak ~/ 2);
        HapticFeedback.lightImpact();
        _hint = '${g.kind.passLine} · spam x$_screamStreak';
        unawaited(
          DailyChallengeService.instance.tryCompleteWithScore(
            LeaderboardService.modeScream,
            _score,
          ),
        );
      }
    }

    if (mounted) setState(() {});
  }

  bool _hitGate(Rect bug, _Gate g) {
    final gapTop = g.gapCenter - g.gapHalf;
    final gapBot = g.gapCenter + g.gapHalf;
    final top = Rect.fromLTWH(g.x + 5, _ceilY, _gateW - 10, gapTop - _ceilY);
    final bot = Rect.fromLTWH(
      g.x + 5,
      gapBot,
      _gateW - 10,
      max(0.0, _floorY - _grassH * 0.25 - gapBot),
    );
    if (top.height > 4 && bug.overlaps(top)) return true;
    if (bot.height > 4 && bug.overlaps(bot)) return true;
    return false;
  }

  void _spawnGate({bool initial = false}) {
    final gapHalf =
        (72.0 - min(22.0, _gatesPassed * 0.55)).clamp(52.0, 78.0);
    final minC = _ceilY + gapHalf + 18;
    final maxC = _floorY - _grassH - gapHalf - 12;
    final center = minC >= maxC
        ? (_ceilY + _floorY) * 0.5
        : minC + _rng.nextDouble() * (maxC - minC);

    final double base;
    if (_gates.isEmpty) {
      base = _world + _arenaW * 0.92 + (initial ? 40 : 0);
    } else {
      base = _gates.last.base + _gateSpacing + _rng.nextDouble() * 36;
    }

    // Avoid same hazard twice in a row for visual variety.
    final kinds = _GateKind.values;
    _GateKind kind;
    do {
      kind = kinds[_rng.nextInt(kinds.length)];
    } while (_gates.isNotEmpty && kind == _gates.last.kind && kinds.length > 1);

    _gates.add(
      _Gate(
        base: base,
        gapCenter: center,
        gapHalf: gapHalf,
        kind: kind,
      ),
    );
  }

  void _die([String? reason]) {
    if (!_alive) return;
    _alive = false;
    _screamStreak = 0;
    _hint = reason ??
        'Ezildin! Kapı $_gatesPassed · max spam x$_maxScreamStreak';
    HapticFeedback.heavyImpact();
    unawaited(
      LeaderboardService.instance
          .submitScore(LeaderboardService.modeScream, _score),
    );
    if (_score > _best) _best = _score;
    setState(() {});
  }

  InsectTier _nextBug() {
    // Playable sticker set only (skip rare/broken paths).
    const pool = <InsectTier>[
      InsectTier.cone,
      InsectTier.helmet,
      InsectTier.fan,
      InsectTier.dancer,
      InsectTier.diva,
      InsectTier.can,
      InsectTier.kongo,
    ];
    InsectTier next;
    do {
      next = pool[_rng.nextInt(pool.length)];
    } while (next == _bug && pool.length > 1);
    return next;
  }

  void _onVoiceComplete() {
    if (!mounted) return;
    setState(() {
      _voiceBusy = false;
      _bug = _nextBug();
      _callout = _bug.viralReplik;
    });
  }

  void _scream() {
    if (!_alive) {
      _restart();
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastScreamAt) < _screamCooldown) return;
    _lastScreamAt = now;

    // Jump / power every tap — voice + character are gated separately.
    _screamStreak++;
    if (_screamStreak > _maxScreamStreak) _maxScreamStreak = _screamStreak;
    _groundIdle = 0;
    _power = (_power + 0.28).clamp(0.0, 1.0);
    _vy = -290 - _power * 300;
    HapticFeedback.selectionClick();
    _hint = '${_callout.isEmpty ? _bug.viralReplik : _callout} · spam x$_screamStreak';

    if (_voiceBusy || AudioManager().isExclusivePlaying) {
      setState(() {});
      return;
    }

    _voiceBusy = true;
    _callout = _bug.viralReplik;
    _hint = '$_callout · spam x$_screamStreak';
    final pitch = 0.88 + _rng.nextDouble() * 0.32;
    unawaited(() async {
      final started = await AudioManager().playExclusiveSfx(
        _bug.voiceFile,
        volume: 0.82 + _power * 0.18,
        playbackRate: pitch,
        onComplete: _onVoiceComplete,
      );
      if (!started && mounted) {
        // Already playing elsewhere, or start failed — unlock without swap.
        setState(() => _voiceBusy = false);
      }
    }());
    setState(() {});
  }

  void _restart() {
    unawaited(AudioManager().stopAll());
    setState(() {
      _alive = true;
      _layoutReady = _arenaW > 0 && _arenaH > 0;
      _score = 0;
      _gatesPassed = 0;
      _world = 0;
      _x = 78;
      _y = _ceilY + (_floorY - _ceilY - _bugSize) * 0.42;
      _vy = 0;
      _power = 0;
      _screamStreak = 0;
      _maxScreamStreak = 0;
      _groundIdle = 0;
      _aliveFor = 0;
      _gates.clear();
      _bug = InsectTier.helmet;
      _callout = '';
      _voiceBusy = false;
      _hint = 'Spam dokun = zıpla. Terlik · sprey · tava arasından geç!';
      _last = Duration.zero;
      if (_layoutReady) _spawnGate(initial: true);
    });
  }

  String _statsLine() =>
      'Kapı $_gatesPassed · Max spam x$_maxScreamStreak · Streak $_dayStreak';

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
      _restart();
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
    if (!_alive && !_resultShown) _edgeShowResult();
    return ArcadeScreen(
      title: 'ÇIĞLIK BÖCEK',
      score: _score,
      best: _best,
      hint: _hint,
      statLabel: 'KAPI',
      statValue: '$_gatesPassed',
      onRestart: _restart,
      overlay: (!_alive && !_resultShown)
          ? ArcadeResultOverlay(
              title: 'EZİLDİN',
              message: _statsLine(),
              score: _score,
              best: _best,
              won: false,
              modeTitle: 'Çığlık Böcek',
              shareLine: _statsLine(),
              retryLabel: 'YENİDEN',
              onRetry: _restart,
            )
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _scream,
        child: LayoutBuilder(
          builder: (context, box) {
            _applyLayout(box.maxWidth, box.maxHeight);
            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      _sky,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: LululuColors.spaceNavy,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: _grassH + 8,
                    height: 64,
                    child: Opacity(
                      opacity: 0.35,
                      child: _ScrollingTiles(
                        asset: _grassTile,
                        scroll: _world * 0.35,
                        tileW: 96,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: _ceilY,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            LululuColors.carbonVoid.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (final g in _gates) ..._buildGate(g),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _grassH,
                    child: _ScrollingTiles(
                      asset: _grass,
                      scroll: _world,
                      tileW: 128,
                      fallbackAsset: _grassTile,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _power,
                        minHeight: 10,
                        backgroundColor: LululuColors.darkObsidian,
                        color: LululuColors.coralFlare,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    top: 28,
                    child: Text(
                      'SES ${_power < 0.3 ? 'fısıltı' : _power < 0.7 ? 'bağır' : 'ÇIĞLIK!!!'} · ${_bug.name}',
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w800,
                        color: LululuColors.coralFlare,
                      ),
                    ),
                  ),
                  if (_callout.isNotEmpty)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 52,
                      child: Text(
                        _callout,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _bug.color,
                        ),
                      ),
                    ),
                  Positioned(
                    left: _x,
                    top: _y,
                    child: Transform.rotate(
                      angle: (_vy.clamp(-400, 400)) / 600,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 90),
                        child: StickerImage(
                          key: ValueKey(_bug),
                          assetPath: _bug.assetPath,
                          size: _bugSize,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildGate(_Gate g) {
    final gapTop = g.gapCenter - g.gapHalf;
    final gapBot = g.gapCenter + g.gapHalf;
    final topH = max(8.0, gapTop - _ceilY);
    final botH = max(8.0, _floorY - _grassH - gapBot);
    return [
      Positioned(
        left: g.x,
        top: _ceilY,
        width: _gateW,
        height: topH,
        child: _HazardColumn(kind: g.kind, flip: true),
      ),
      Positioned(
        left: g.x,
        top: gapBot,
        width: _gateW,
        height: botH,
        child: _HazardColumn(kind: g.kind, flip: false),
      ),
    ];
  }
}

/// Mutfak / viral engeller — Flappy boru yok.
enum _GateKind {
  terlik(
    deathLine: 'Terlik şılapp!',
    passLine: 'Terlik sıyırdı!',
  ),
  raid(
    deathLine: 'Raid bulutu!',
    passLine: 'Spreyi geçtin!',
  ),
  tava(
    deathLine: 'Tava tokattı!',
    passLine: 'Tava altından!',
  ),
  tuzak(
    deathLine: 'Yapışkan tuzak!',
    passLine: 'Tuzaktan kaçtın!',
  ),
  hamamTas(
    deathLine: 'Tas kafaya!',
    passLine: 'Hamam tas geçti!',
  ),
  vuvuzela(
    deathLine: 'Vuvuzela ezdi!',
    passLine: 'Kongo koridoru!',
  );

  const _GateKind({required this.deathLine, required this.passLine});
  final String deathLine;
  final String passLine;
}

class _Gate {
  _Gate({
    required this.base,
    required this.gapCenter,
    required this.gapHalf,
    required this.kind,
  });

  final double base;
  final double gapCenter;
  final double gapHalf;
  final _GateKind kind;
  double x = 0;
  bool scored = false;
}

class _ScrollingTiles extends StatelessWidget {
  const _ScrollingTiles({
    required this.asset,
    required this.scroll,
    required this.tileW,
    this.fallbackAsset,
  });

  final String asset;
  final double scroll;
  final double tileW;
  final String? fallbackAsset;

  @override
  Widget build(BuildContext context) {
    final shift = scroll % tileW;
    return LayoutBuilder(
      builder: (context, box) {
        final n = (box.maxWidth / tileW).ceil() + 2;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (var i = 0; i < n; i++)
              Positioned(
                left: i * tileW - shift,
                top: 0,
                bottom: 0,
                width: tileW,
                child: Image.asset(
                  asset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, __, ___) => fallbackAsset == null
                      ? const ColoredBox(color: Color(0xFF3D8B4F))
                      : Image.asset(
                          fallbackAsset!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFF3D8B4F)),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HazardColumn extends StatelessWidget {
  const _HazardColumn({required this.kind, required this.flip});

  final _GateKind kind;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HazardPainter(kind: kind, flip: flip),
      child: const SizedBox.expand(),
    );
  }
}

class _HazardPainter extends CustomPainter {
  _HazardPainter({required this.kind, required this.flip});

  final _GateKind kind;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    canvas.save();
    if (flip) {
      canvas.translate(0, size.height);
      canvas.scale(1, -1);
    }
    switch (kind) {
      case _GateKind.terlik:
        _paintTerlikStack(canvas, size);
      case _GateKind.raid:
        _paintRaidCans(canvas, size);
      case _GateKind.tava:
        _paintTavaStack(canvas, size);
      case _GateKind.tuzak:
        _paintStickyTrap(canvas, size);
      case _GateKind.hamamTas:
        _paintHamamTas(canvas, size);
      case _GateKind.vuvuzela:
        _paintVuvuzela(canvas, size);
    }
    canvas.restore();
  }

  void _paintTerlikStack(Canvas canvas, Size size) {
    final pink = Paint()..color = const Color(0xFFFF5FA2);
    final sole = Paint()..color = const Color(0xFFE8E0D8);
    final stripe = Paint()..color = const Color(0xFFFFD6E8);
    final step = 36.0;
    for (var y = 4.0; y < size.height - 8; y += step) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(6, y, size.width - 12, 28),
        const Radius.circular(10),
      );
      canvas.drawRRect(r, pink);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(10, y + 18, size.width - 20, 8),
          const Radius.circular(4),
        ),
        sole,
      );
      canvas.drawOval(Rect.fromLTWH(14, y + 4, size.width - 28, 10), stripe);
    }
  }

  void _paintRaidCans(Canvas canvas, Size size) {
    final body = Paint()..color = const Color(0xFF2ECC71);
    final label = Paint()..color = const Color(0xFFFFF200);
    final nozzle = Paint()..color = const Color(0xFF1A1A1A);
    final mist = Paint()..color = const Color(0xFF7CFC9A).withValues(alpha: 0.35);
    final step = 44.0;
    for (var y = 2.0; y < size.height - 10; y += step) {
      final can = RRect.fromRectAndRadius(
        Rect.fromLTWH(14, y + 8, size.width - 28, 30),
        const Radius.circular(6),
      );
      canvas.drawRRect(can, body);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(18, y + 14, size.width - 36, 10),
          const Radius.circular(3),
        ),
        label,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.42, y, size.width * 0.16, 10),
          const Radius.circular(2),
        ),
        nozzle,
      );
      canvas.drawOval(
        Rect.fromLTWH(4, y + 4, 12, 18),
        mist,
      );
    }
  }

  void _paintTavaStack(Canvas canvas, Size size) {
    final pan = Paint()..color = const Color(0xFF8A93A0);
    final rim = Paint()
      ..color = const Color(0xFFD0D5DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final handle = Paint()..color = const Color(0xFF3A2A1A);
    final step = 40.0;
    for (var y = 4.0; y < size.height - 8; y += step) {
      final oval = Rect.fromLTWH(4, y + 4, size.width - 18, 26);
      canvas.drawOval(oval, pan);
      canvas.drawOval(oval, rim);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width - 18, y + 12, 14, 8),
          const Radius.circular(3),
        ),
        handle,
      );
    }
  }

  void _paintStickyTrap(Canvas canvas, Size size) {
    final board = Paint()..color = const Color(0xFFF4D35E);
    final goo = Paint()..color = const Color(0xFFC9A227);
    final edge = Paint()
      ..color = const Color(0xFF8B6914)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 0, size.width - 16, size.height),
        const Radius.circular(4),
      ),
      board,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 0, size.width - 16, size.height),
        const Radius.circular(4),
      ),
      edge,
    );
    for (var y = 10.0; y < size.height; y += 18) {
      canvas.drawLine(Offset(14, y), Offset(size.width - 14, y + 6), goo);
      canvas.drawCircle(Offset(size.width * 0.35, y + 4), 3, goo);
      canvas.drawCircle(Offset(size.width * 0.65, y + 8), 2.5, goo);
    }
  }

  void _paintHamamTas(Canvas canvas, Size size) {
    final copper = Paint()..color = const Color(0xFFB87333);
    final shine = Paint()..color = const Color(0xFFE8B87A);
    final water = Paint()..color = const Color(0xFF4FC3F7).withValues(alpha: 0.55);
    final step = 38.0;
    for (var y = 2.0; y < size.height - 6; y += step) {
      final bowl = Rect.fromLTWH(8, y + 6, size.width - 16, 24);
      canvas.drawOval(bowl, copper);
      canvas.drawOval(
        Rect.fromLTWH(14, y + 10, size.width - 28, 10),
        water,
      );
      canvas.drawArc(
        Rect.fromLTWH(12, y + 8, size.width - 36, 12),
        -2.2,
        1.2,
        false,
        shine..style = PaintingStyle.stroke..strokeWidth = 2,
      );
    }
  }

  void _paintVuvuzela(Canvas canvas, Size size) {
    final horn = Paint()..color = const Color(0xFFFF8C00);
    final tip = Paint()..color = const Color(0xFFFFD700);
    final band = Paint()..color = const Color(0xFFE52E2E);
    final path = Path()
      ..moveTo(size.width * 0.35, 0)
      ..lineTo(size.width * 0.65, 0)
      ..lineTo(size.width * 0.92, size.height)
      ..lineTo(size.width * 0.08, size.height)
      ..close();
    canvas.drawPath(path, horn);
    for (var y = 16.0; y < size.height; y += 28) {
      canvas.drawLine(
        Offset(size.width * 0.2, y),
        Offset(size.width * 0.8, y),
        band..strokeWidth = 4..style = PaintingStyle.stroke,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.28, 0, size.width * 0.44, 12),
        const Radius.circular(4),
      ),
      tip,
    );
  }

  @override
  bool shouldRepaint(covariant _HazardPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.flip != flip;
}
