import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/daily_challenge_service.dart';
import '../services/leaderboard_service.dart';
import '../screens/result_screen.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';

/// Viral mini: böcekler + Osmantuş kişileri uçuşur, terlikle ez.
/// Combo / coin / booster bonus + karaktere özel ses.
class TerlikTapScreen extends StatefulWidget {
  const TerlikTapScreen({super.key});

  @override
  State<TerlikTapScreen> createState() => _TerlikTapScreenState();
}

enum _BonusKind { scoreBurst, coin, slipper, spray, life }

class _FloatFx {
  _FloatFx({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.color,
  });

  final int id;
  final String label;
  final double x;
  double y;
  final Color color;
  double life = 1;
}

class _Bug {
  _Bug({
    required this.id,
    required this.characterId,
    required this.assetPath,
    required this.replik,
    required this.voiceHintTier,
    required this.x,
    required this.y,
    required this.life,
    required this.basePoints,
    required this.isOsman,
  });

  final int id;
  final String characterId;
  final String assetPath;
  final String replik;
  final InsectTier? voiceHintTier;
  final int basePoints;
  final bool isOsman;
  double x;
  double y;
  double life;
  bool smashed = false;
}

class _TerlikTapScreenState extends State<TerlikTapScreen>
    with SingleTickerProviderStateMixin {
  late final Random _rng;
  late final AnimationController _pulse;
  final List<_Bug> _bugs = [];
  final List<_FloatFx> _fx = [];
  int _nextId = 0;
  int _nextFx = 0;
  int _score = 0;
  int _best = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _smashed = 0;
  int _missed = 0;
  int _lives = 3;
  int _coinsEarned = 0;
  int _slipperEarned = 0;
  int _sprayEarned = 0;
  bool _alive = true;
  bool _resultShown = false;
  String _hint = 'Uçan böceği terlikle ez!';
  double _spawnAcc = 0;
  double _shake = 0;
  double _hitStop = 0;
  DateTime _last = DateTime.now();
  Timer? _loop;
  Size _arena = const Size(320, 480);

  static const _osmanA = (
    id: 'osman_a',
    asset: 'assets/design/osman/osman_1.png',
    replik: 'Osmantuş A — şılapp!',
  );
  static const _osmanB = (
    id: 'osman_b',
    asset: 'assets/design/osman/osman_2.png',
    replik: 'Osmantuş B — dıkkış!',
  );

  @override
  void initState() {
    super.initState();
    final day = DateTime.now();
    final seed = day.year * 10000 + day.month * 100 + day.day;
    _rng = Random(seed ^ 0x7E11);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    AudioManager().initialize();
    unawaited(ProgressManager().load());
    _loadBest();
    _loop = Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best =
          LeaderboardService.instance.getBest(LeaderboardService.modeTerlik);
    });
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _loop?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _tick(Timer _) {
    if (!_alive || !mounted) return;
    final now = DateTime.now();
    var dt = now.difference(_last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.05) dt = 0.016;

    if (_hitStop > 0) {
      _hitStop = max(0, _hitStop - dt);
      // Soft freeze: skip spawn/physics while hit-stop active.
      if (_hitStop > 0) {
        _shake = max(0, _shake - dt * 4);
        setState(() {});
        return;
      }
    }

    _spawnAcc += dt;
    final spawnEvery = max(0.35, 0.85 - _score / 8000);
    if (_spawnAcc >= spawnEvery) {
      _spawnAcc = 0;
      _spawn();
    }

    for (final b in _bugs) {
      if (b.smashed) {
        b.life -= dt * 4;
      } else {
        b.y -= (90 + _score * 0.02) * dt;
        b.life -= dt * 0.22;
        if (b.life <= 0 || b.y < -40) {
          b.smashed = true;
          b.life = 0;
          _missed++;
          _combo = 0;
          _lives--;
          _hint = 'Kaçtı! Can $_lives';
          if (_lives <= 0) {
            _die();
            return;
          }
        }
      }
    }
    _bugs.removeWhere((b) => b.smashed && b.life <= 0);

    for (final f in _fx) {
      f.life -= dt * 1.6;
      f.y -= 48 * dt;
    }
    _fx.removeWhere((f) => f.life <= 0);

    if (_shake > 0) {
      _shake = max(0, _shake - dt * 3.8);
    }
    setState(() {});
  }

  void _spawn() {
    final w = max(96.0, _arena.width);
    final h = max(220.0, _arena.height);
    final x = 36 + _rng.nextDouble() * max(24.0, w - 72);
    final y = h - 28 - _rng.nextDouble() * 36;

    // ~12% Osmantuş kişi hedefi (A/B ayrı ses).
    if (_rng.nextDouble() < 0.12) {
      final a = _rng.nextBool();
      final person = a ? _osmanA : _osmanB;
      _bugs.add(
        _Bug(
          id: _nextId++,
          characterId: person.id,
          assetPath: person.asset,
          replik: person.replik,
          voiceHintTier: null,
          x: x,
          y: y,
          life: 1.05,
          basePoints: 90,
          isOsman: true,
        ),
      );
      return;
    }

    final tier = InsectTier.values[_rng.nextInt(InsectTier.values.length)];
    _bugs.add(
      _Bug(
        id: _nextId++,
        characterId: GameAudio.characterIdForTier(tier),
        assetPath: tier.assetPath,
        replik: tier.viralReplik,
        voiceHintTier: tier,
        x: x,
        y: y,
        life: 1,
        basePoints: 40 + tier.tier * 4,
        isOsman: false,
      ),
    );
  }

  void _pushFx(String label, double x, double y, Color color) {
    _fx.add(
      _FloatFx(
        id: _nextFx++,
        label: label,
        x: x,
        y: y,
        color: color,
      ),
    );
  }

  /// Combo / rastgele / Osmantuş — gerçek vault drop (ProgressManager).
  List<({_BonusKind kind, int amount, String label, Color color})> _rollBonuses(
    _Bug hit,
  ) {
    final out =
        <({_BonusKind kind, int amount, String label, Color color})>[];

    if (_combo == 3) {
      out.add((
        kind: _BonusKind.scoreBurst,
        amount: 80,
        label: 'COMBO x3 +80',
        color: LululuColors.toxicNeon,
      ));
    } else if (_combo == 5) {
      out.add((
        kind: _BonusKind.coin,
        amount: 8,
        label: 'COMBO x5 +8💰',
        color: LululuColors.liquidGold,
      ));
    } else if (_combo == 8) {
      out.add((
        kind: _BonusKind.slipper,
        amount: 1,
        label: 'COMBO x8 TERLİK +1',
        color: LululuColors.cyberFuchsia,
      ));
    } else if (_combo == 10 || (_combo > 10 && _combo % 5 == 0)) {
      out.add((
        kind: _BonusKind.spray,
        amount: 1,
        label: 'COMBO x$_combo SPREY +1',
        color: LululuColors.coralFlare,
      ));
    }

    if (hit.isOsman) {
      out.add((
        kind: _BonusKind.scoreBurst,
        amount: 120,
        label: 'OSMAN BONUS +120',
        color: LululuColors.warningSolar,
      ));
      if (_rng.nextDouble() < 0.35) {
        out.add((
          kind: _BonusKind.coin,
          amount: 12,
          label: '+12 coin',
          color: LululuColors.liquidGold,
        ));
      }
    } else if (hit.voiceHintTier != null && hit.voiceHintTier!.tier >= 6) {
      out.add((
        kind: _BonusKind.scoreBurst,
        amount: 40 + hit.voiceHintTier!.tier * 8,
        label: 'TIER ${hit.voiceHintTier!.tier} BONUS',
        color: hit.voiceHintTier!.color,
      ));
    }

    // Rastgele drip (~14%).
    if (_rng.nextDouble() < 0.14) {
      final roll = _rng.nextDouble();
      if (roll < 0.55) {
        final c = 3 + _rng.nextInt(6);
        out.add((
          kind: _BonusKind.coin,
          amount: c,
          label: '+$c coin',
          color: LululuColors.liquidGold,
        ));
      } else if (roll < 0.78) {
        out.add((
          kind: _BonusKind.scoreBurst,
          amount: 50 + _rng.nextInt(70),
          label: 'ŞANS PATLAMA',
          color: LululuColors.toxicNeon,
        ));
      } else if (roll < 0.9 && _lives < 3) {
        out.add((
          kind: _BonusKind.life,
          amount: 1,
          label: 'CAN +1',
          color: LululuColors.mysticRuby,
        ));
      } else {
        out.add((
          kind: _BonusKind.slipper,
          amount: 1,
          label: 'TERLİK +1',
          color: LululuColors.cyberFuchsia,
        ));
      }
    }

    return out;
  }

  Future<void> _applyEconomyDrops(int coins, int slipper, int spray) async {
    if (coins <= 0 && slipper <= 0 && spray <= 0) return;
    await ProgressManager().grantArcadeDrop(
      coins: coins,
      slipper: slipper,
      spray: spray,
    );
  }

  void _onTapDown(TapDownDetails d) {
    if (!_alive) {
      _restart();
      return;
    }
    final local = d.localPosition;
    _Bug? hit;
    for (final b in _bugs.reversed) {
      if (b.smashed) continue;
      final dx = local.dx - b.x;
      final dy = local.dy - b.y;
      if (dx * dx + dy * dy < 48 * 48) {
        hit = b;
        break;
      }
    }
    if (hit == null) {
      HapticFeedback.selectionClick();
      return;
    }

    hit.smashed = true;
    hit.life = 1;
    _combo++;
    if (_combo > _maxCombo) _maxCombo = _combo;
    _smashed++;

    final gain = hit.basePoints + _combo * 12;
    var scoreGain = gain;
    var coinDrop = 0;
    var slipperDrop = 0;
    var sprayDrop = 0;

    final bonuses = _rollBonuses(hit);
    for (final b in bonuses) {
      switch (b.kind) {
        case _BonusKind.scoreBurst:
          scoreGain += b.amount;
          break;
        case _BonusKind.coin:
          coinDrop += b.amount;
          break;
        case _BonusKind.slipper:
          slipperDrop += b.amount;
          break;
        case _BonusKind.spray:
          sprayDrop += b.amount;
          break;
        case _BonusKind.life:
          _lives = min(3, _lives + b.amount);
          break;
      }
      _pushFx(b.label, hit.x, hit.y - 10 - _fx.length * 14.0, b.color);
    }

    _score += scoreGain;
    _coinsEarned += coinDrop;
    _slipperEarned += slipperDrop;
    _sprayEarned += sprayDrop;
    _pushFx('+$scoreGain', hit.x, hit.y + 8, LululuColors.liquidGold);

    _hint = '${hit.replik} · x$_combo +$scoreGain'
        '${coinDrop > 0 ? ' · +$coinDrop💰' : ''}'
        '${slipperDrop > 0 ? ' · terlik+$slipperDrop' : ''}'
        '${sprayDrop > 0 ? ' · sprey+$sprayDrop' : ''}';

    // Juice: shake + hit-stop (tier4+ / osman / combo≥4).
    final juiceTier = hit.voiceHintTier?.tier ?? (hit.isOsman ? 6 : 1);
    _shake = max(_shake, min(0.42, 0.12 + _combo * 0.03 + juiceTier * 0.02));
    if (juiceTier >= 4 || hit.isOsman || _combo >= 4) {
      _hitStop = max(_hitStop, juiceTier >= 6 || hit.isOsman ? 0.05 : 0.03);
    }

    if (_combo >= 5 || hit.isOsman) {
      AudioManager().triggerHeavyHaptic();
    } else {
      HapticFeedback.mediumImpact();
    }

    unawaited(
      AudioManager().playSlipperSmash(
        characterId: hit.characterId,
        tier: hit.voiceHintTier,
        comboCount: _combo,
      ),
    );
    unawaited(_applyEconomyDrops(coinDrop, slipperDrop, sprayDrop));
    setState(() {});
  }

  void _die() {
    _alive = false;
    // Run sonu skor→coin (ekonomi uyumlu).
    final endCoins = max(1, _score ~/ 400);
    _coinsEarned += endCoins;
    unawaited(ProgressManager().grantArcadeDrop(coins: endCoins));
    _hint =
        'Terlik yetmedi. Ezilen $_smashed · max x$_maxCombo · +$_coinsEarned💰';
    HapticFeedback.heavyImpact();
    unawaited(AudioManager().playLose());
    unawaited(
      LeaderboardService.instance
          .submitScore(LeaderboardService.modeTerlik, _score),
    );
    if (_score > _best) _best = _score;
    unawaited(
      DailyChallengeService.instance
          .tryCompleteWithScore(LeaderboardService.modeTerlik, _score),
    );
    setState(() {});
  }

  void _restart() {
    setState(() {
      _bugs.clear();
      _fx.clear();
      _score = 0;
      _combo = 0;
      _maxCombo = 0;
      _smashed = 0;
      _missed = 0;
      _lives = 3;
      _coinsEarned = 0;
      _slipperEarned = 0;
      _sprayEarned = 0;
      _alive = true;
      _spawnAcc = 0;
      _shake = 0;
      _hitStop = 0;
      _hint = 'Uçan böceği terlikle ez!';
      _last = DateTime.now();
    });
  }

  String _stats() =>
      'Ezilen $_smashed · Kaçan $_missed · Max combo x$_maxCombo\n'
      '+$_coinsEarned coin · terlik +$_slipperEarned · sprey +$_sprayEarned';

  /// Oyun sonu: yeni sonuç ekranı. "TEKRAR OYNA" yeni turu başlatır,
  /// "ANA SAYFA"da eski sonuç akışı devam eder (bozulmadı).
  Future<void> _presentResult() async {
    final replay = await showGameResult(
      context,
      score: _score,
      coins: _coinsEarned,
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
    final shakeX = _shake > 0
        ? (sin(_pulse.value * pi * 18) * _shake * 10)
        : 0.0;
    final shakeY = _shake > 0
        ? (cos(_pulse.value * pi * 14) * _shake * 8)
        : 0.0;

    return ArcadeScreen(
      title: 'TERLİK TAP',
      hint: _hint,
      score: _score,
      best: _best,
      statLabel: _combo > 0 ? 'COMBO' : 'CAN',
      statValue: _combo > 0 ? 'x$_combo' : '$_lives',
      onRestart: _restart,
      overlay: (!_alive && !_resultShown)
          ? ArcadeResultOverlay(
              title: 'TERLİK BİTTİ',
              message: _stats(),
              score: _score,
              best: _best,
              won: false,
              modeTitle: 'Terlik Tap',
              shareLine: _stats(),
              retryLabel: 'YENİDEN',
              onRetry: _restart,
            )
          : null,
      child: LayoutBuilder(
        builder: (context, box) {
          _arena = Size(box.maxWidth, box.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapDown,
            child: Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 8,
                    child: Text(
                      'Günlük seed · can $_lives'
                      '${_coinsEarned > 0 ? ' · +$_coinsEarned💰' : ''}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        color: LululuColors.mutedTitanium,
                      ),
                    ),
                  ),
                  for (final b in _bugs)
                    Positioned(
                      left: b.x - 36,
                      top: b.y - 36,
                      child: Opacity(
                        opacity: b.smashed ? b.life.clamp(0.0, 1.0) : 1,
                        child: Transform.scale(
                          scale: b.smashed
                              ? 1.2
                              : (b.isOsman ? 1.08 : 1.0),
                          child: Transform.rotate(
                            angle: b.smashed
                                ? 0.4
                                : sin(_pulse.value * pi * 2) * 0.08,
                            child: StickerImage(
                              assetPath: b.assetPath,
                              size: 72,
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (final f in _fx)
                    Positioned(
                      left: f.x - 48,
                      top: f.y - 12,
                      width: 96,
                      child: Opacity(
                        opacity: f.life.clamp(0.0, 1.0),
                        child: Text(
                          f.label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.exo2(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: f.color,
                            shadows: [
                              Shadow(
                                color: LululuColors.carbonVoid
                                    .withValues(alpha: 0.85),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 20,
                    bottom: 24,
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Icon(
                        Icons.do_not_step_rounded,
                        size: 64,
                        color: LululuColors.mysticRuby.withValues(alpha: 0.55),
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
}
