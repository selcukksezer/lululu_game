import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/hisir_character.dart';
import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/daily_challenge_service.dart';
import '../services/leaderboard_service.dart';
import '../screens/result_screen.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/mode_bonus_bar.dart';
import '../widgets/sticker_image.dart';

/// Viral mini: böcekler + Osmantuş kişileri uçuşur, terlikle ez.
/// Combo / coin / booster bonus + karaktere özel ses.
class TerlikTapScreen extends StatefulWidget {
  const TerlikTapScreen({
    super.key,
    @visibleForTesting this.prototypeVisualState = false,
    @visibleForTesting this.initialTargetForTesting = false,
  });

  @visibleForTesting
  final bool prototypeVisualState;

  @visibleForTesting
  final bool initialTargetForTesting;

  @override
  State<TerlikTapScreen> createState() => _TerlikTapScreenState();
}

enum _BonusKind { scoreBurst, coin, slipper, spray, life }

@visibleForTesting
class TerlikTapPacing {
  static const tutorialSeconds = 15.0;

  static double spawnInterval(double elapsedSeconds) {
    final rampTime = max(0.0, elapsedSeconds - tutorialSeconds);
    return elapsedSeconds < tutorialSeconds
        ? 1.15
        : max(0.58, 1.05 - rampTime * 0.01);
  }

  static double targetVisibleSeconds(double elapsedSeconds) {
    final rampTime = max(0.0, elapsedSeconds - tutorialSeconds);
    return elapsedSeconds < tutorialSeconds
        ? 1.8
        : max(1.0, 1.55 - rampTime * 0.008);
  }
}

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
    required this.holeIndex,
    required this.life,
    required this.basePoints,
    required this.isOsman,
    this.isTrap = false,
    this.halfVisible = false,
  });

  final int id;
  final String characterId;
  final String assetPath;
  final String replik;
  final InsectTier? voiceHintTier;
  final int holeIndex;
  final int basePoints;
  final bool isOsman;
  final bool isTrap;
  final bool halfVisible;
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
  double _elapsedSeconds = 0;
  bool _alive = true;
  bool _resultShown = false;
  String? _missMessage;
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

  bool _doubleNext = false;
  DateTime? _goldUntil;

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
    if (widget.prototypeVisualState) {
      _score = 860;
      _best = 1150;
      _combo = 8;
      _maxCombo = 8;
      _smashed = 23;
      _missed = 2;
      _lives = 3;
      _seedPrototypeTargets();
      _pulse.value = 0.31;
    } else {
      _loadBest();
      if (widget.initialTargetForTesting) {
        _spawn();
      } else {
        _spawn(preferredRow: 0);
        _spawn(preferredRow: 1);
        _spawn(preferredRow: 2);
      }
      _loop = Timer.periodic(const Duration(milliseconds: 16), _tick);
    }
  }

  void _seedPrototypeTargets() {
    final tiersByHole = <int, InsectTier>{
      1: InsectTier.values[0],
      3: InsectTier.values[4],
      4: InsectTier.values[1],
      6: InsectTier.values[2],
      7: InsectTier.values[3],
    };
    for (final entry in tiersByHole.entries) {
      final tier = entry.value;
      _bugs.add(
        _Bug(
          id: _nextId++,
          characterId: GameAudio.characterIdForTier(tier),
          assetPath: tier.assetPath,
          replik: tier.viralReplik,
          voiceHintTier: tier,
          holeIndex: entry.key,
          life: 1,
          basePoints: 40 + tier.tier * 4,
          isOsman: false,
          halfVisible: entry.key == 6,
        ),
      );
    }
    _bugs.firstWhere((bug) => bug.holeIndex == 3).smashed = true;
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best = LeaderboardService.instance.getBest(
        LeaderboardService.modeTerlik,
      );
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

    _elapsedSeconds += dt;
    _spawnAcc += dt;
    final spawnEvery = TerlikTapPacing.spawnInterval(_elapsedSeconds);
    final maxConcurrent = _elapsedSeconds < 12 ? 3 : 4;
    if (_spawnAcc >= spawnEvery &&
        _bugs.where((bug) => !bug.smashed).length < maxConcurrent) {
      _spawnAcc = 0;
      _spawn();
    }

    for (final b in _bugs) {
      if (b.smashed) {
        b.life -= dt * 3.5;
      } else {
        b.life -= dt;
        if (b.life <= 0) {
          b.smashed = true;
          b.life = 0;
          if (b.isTrap) {
            _score += 30;
            final center = _holeCenter(b.holeIndex);
            _pushFx('TUZAK GEÇTİ +30', center.dx, center.dy, LululuColors.toxicNeon);
          } else {
            _applyMiss('KAÇTI');
            if (_lives <= 0) {
              _die();
              return;
            }
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

  void _spawn({int? preferredRow}) {
    final occupied = _bugs
        .where((bug) => !bug.smashed)
        .map((bug) => bug.holeIndex)
        .toSet();
    var freeHoles = List<int>.generate(
      9,
      (index) => index,
    ).where((index) => !occupied.contains(index)).toList();
    if (freeHoles.isEmpty) return;
    if (preferredRow != null) {
      final rowHoles = freeHoles
          .where((index) => index ~/ 3 == preferredRow)
          .toList();
      if (rowHoles.isNotEmpty) {
        freeHoles = rowHoles;
      }
    }
    final holeIndex = freeHoles[_rng.nextInt(freeHoles.length)];
    final visibleFor = TerlikTapPacing.targetVisibleSeconds(_elapsedSeconds);

    // Skor yükselince %12 ihtimalle dokunulmaması gereken elektrik/bomba tuzağı.
    if (!widget.prototypeVisualState &&
        _score >= 220 &&
        _bugs.any((bug) => !bug.smashed && !bug.isTrap) &&
        _rng.nextDouble() < 0.12) {
      _bugs.add(
        _Bug(
          id: _nextId++,
          characterId: 'trap_bomb',
          assetPath: 'assets/game/trap_electric.png',
          replik: 'CIZZT! Tuzağa basma!',
          voiceHintTier: null,
          holeIndex: holeIndex,
          life: visibleFor * 0.85,
          basePoints: 0,
          isOsman: false,
          isTrap: true,
        ),
      );
      return;
    }

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
          holeIndex: holeIndex,
          life: visibleFor,
          basePoints: 90,
          isOsman: true,
        ),
      );
      return;
    }

    // ~8% Hışır özel hedefi (tier dışı; sesi 'hisir' kimliğiyle husur_aday).
    // Görsel GEÇİCİ: tier1 görseli ödünç (bkz. HisirCharacter).
    if (_rng.nextDouble() < 0.08) {
      _bugs.add(
        _Bug(
          id: _nextId++,
          characterId: HisirCharacter.id,
          assetPath: HisirCharacter.assetPath,
          replik: HisirCharacter.replik,
          voiceHintTier: null,
          holeIndex: holeIndex,
          life: visibleFor,
          basePoints: 90,
          isOsman: false,
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
        holeIndex: holeIndex,
        life: visibleFor,
        basePoints: 40 + tier.tier * 4,
        isOsman: false,
      ),
    );
  }

  void _pushFx(String label, double x, double y, Color color) {
    _fx.add(_FloatFx(id: _nextFx++, label: label, x: x, y: y, color: color));
  }

  /// Combo / rastgele / Osmantuş — gerçek vault drop (ProgressManager).
  List<({_BonusKind kind, int amount, String label, Color color})> _rollBonuses(
    _Bug hit,
  ) {
    final out = <({_BonusKind kind, int amount, String label, Color color})>[];

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

  Offset _holeCenter(int index) {
    final column = index % 3;
    final row = index ~/ 3;
    final cellExtent = widget.prototypeVisualState ? 76.0 : 120.0;
    final mainSpace = widget.prototypeVisualState ? 10.0 : 18.0;
    final cellWidth = max(0.0, (_arena.width - 32 - 24) / 3);
    final gridHeight = 3 * cellExtent + 2 * mainSpace + 16 + 6;
    final gridTop = max(0.0, (_arena.height - gridHeight) / 2) + 16;
    return Offset(
      16 + column * (cellWidth + 12) + cellWidth / 2,
      gridTop + row * (cellExtent + mainSpace) + cellExtent / 2,
    );
  }

  void _tapHole(int index) {
    if (!_alive) {
      _restart();
      return;
    }
    _Bug? hit = _bugs
        .where((bug) => bug.holeIndex == index && !bug.smashed)
        .firstOrNull;
    if (hit == null) {
      if (_bugs.any((bug) => bug.holeIndex == index && bug.smashed)) {
        return;
      }
      _applyMiss('BOŞA VURDUN');
      HapticFeedback.selectionClick();
      if (_lives <= 0) {
        _die();
        return;
      }
      setState(() {});
      return;
    }

    if (hit.isTrap) {
      hit.smashed = true;
      hit.life = 0.6;
      _applyMiss('TUZAĞA BASTIN');
      HapticFeedback.heavyImpact();
      unawaited(AudioManager().playSfx(GameAudio.sfxSpray));
      if (_lives <= 0) {
        _die();
        return;
      }
      setState(() {});
      return;
    }

    hit.smashed = true;
    hit.life = 0.9;
    _combo++;
    if (_combo > _maxCombo) _maxCombo = _combo;
    _smashed++;

    final gain = hit.basePoints + _combo * 12;
    var scoreGain = gain;
    var coinDrop = 0;
    var slipperDrop = 0;
    var sprayDrop = 0;
    final hitCenter = _holeCenter(hit.holeIndex);

    if (_doubleNext) {
      _doubleNext = false;
      for (final other in _bugs) {
        if (identical(other, hit) || other.smashed || other.isTrap) continue;
        other.smashed = true;
        other.life = 0.9;
        _smashed++;
        scoreGain += other.basePoints;
        final otherCenter = _holeCenter(other.holeIndex);
        _pushFx(
          '+${other.basePoints}',
          otherCenter.dx,
          otherCenter.dy,
          LululuColors.liquidGold,
        );
        break;
      }
    }
    if (_goldUntil != null && DateTime.now().isBefore(_goldUntil!)) {
      scoreGain *= 2;
    }

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
      _pushFx(
        b.label,
        hitCenter.dx,
        hitCenter.dy - 10 - _fx.length * 14.0,
        b.color,
      );
    }

    _score += scoreGain;
    _coinsEarned += coinDrop;
    _slipperEarned += slipperDrop;
    _sprayEarned += sprayDrop;
    _pushFx(
      '+$scoreGain',
      hitCenter.dx,
      hitCenter.dy + 8,
      LululuColors.liquidGold,
    );

    _hint =
        'VURUŞ · COMBO X$_combo · +$scoreGain'
        '${coinDrop > 0 ? ' · +$coinDrop💰' : ''}'
        '${slipperDrop > 0 ? ' · terlik+$slipperDrop' : ''}'
        '${sprayDrop > 0 ? ' · sprey+$sprayDrop' : ''}';
    _missMessage = null;

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
    // Ek: Diva ezilince "yasla" repliği (mevcut terlik sesi aynen durur).
    if (hit.voiceHintTier == InsectTier.diva) {
      unawaited(AudioManager().playDivaYasla());
    }
    unawaited(_applyEconomyDrops(coinDrop, slipperDrop, sprayDrop));
    setState(() {});
  }

  void _applyMiss(String reason) {
    _missed++;
    _combo = 0;
    final lifeLost = _missed % 3 == 0;
    if (lifeLost) _lives--;
    _missMessage = lifeLost
        ? '$reason · -1 CAN · KOMBO KIRILDI'
        : '$reason · KOMBO KIRILDI · ${3 - (_missed % 3)} KAÇIŞA KADAR CAN';
    _hint = lifeLost
        ? '$reason · -1 CAN · KOMBO KIRILDI · $_lives CAN KALDI'
        : '$reason · KOMBO KIRILDI · ${3 - (_missed % 3)} KAÇIŞA KADAR CAN';
    _pushFx(
      'KOMBO KIRILDI',
      _arena.width / 2,
      _arena.height / 2,
      LululuColors.mysticRuby,
    );
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
      LeaderboardService.instance.submitScore(
        LeaderboardService.modeTerlik,
        _score,
      ),
    );
    if (_score > _best) _best = _score;
    unawaited(
      DailyChallengeService.instance.tryCompleteWithScore(
        LeaderboardService.modeTerlik,
        _score,
      ),
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
      _elapsedSeconds = 0;
      _alive = true;
      _spawnAcc = 0;
      _shake = 0;
      _hitStop = 0;
      _hint = 'Uçan böceği terlikle ez!';
      _last = DateTime.now();
      if (!widget.prototypeVisualState) {
        _spawn();
        _spawn();
      }
    });
  }

  String _stats() =>
      'Ezilen $_smashed · Kaçan $_missed · Max combo x$_maxCombo\n'
      '+$_coinsEarned coin · terlik +$_slipperEarned · sprey +$_sprayEarned';

  /// Oyun sonu: yeni sonuç ekranı. "TEKRAR OYNA" yeni turu başlatır,
  /// "ANA SAYFA"da eski sonuç akışı devam eder (bozulmadı).
  bool _useDoubleSlip() {
    if (!_alive) return false;
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _doubleNext = true;
      _hint = 'ÇİFT TERLİK HAZIR · SONRAKİ VURUŞ ÇİFT BÖCEK EZER!';
      _pushFx(
        'ÇİFT TERLİK!',
        _arena.width / 2,
        _arena.height / 2,
        LululuColors.cyberFuchsia,
      );
    });
    return true;
  }

  bool _useGoldSlip() {
    if (!_alive) return false;
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _goldUntil = DateTime.now().add(const Duration(seconds: 20));
      _hint = 'ALTIN TERLİK AKTİF · 20 SN BOYUNCA 2X PUAN!';
      _pushFx(
        'ALTIN TERLİK 2X!',
        _arena.width / 2,
        _arena.height / 2,
        LululuColors.liquidGold,
      );
    });
    return true;
  }

  bool _useBugSpray() {
    if (!_alive) return false;
    HapticFeedback.heavyImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxSpray));
    setState(() {
      if (_bugs.every((b) => b.smashed)) {
        _spawn();
        _spawn();
      }
      var cleared = 0;
      for (final bug in _bugs) {
        if (bug.smashed) continue;
        bug.smashed = true;
        bug.life = 0.95;
        cleared++;
        if (!bug.isTrap) {
          _smashed++;
          _combo++;
          if (_combo > _maxCombo) _maxCombo = _combo;
          final pts = bug.basePoints + _combo * 10;
          _score += pts;
          final c = _holeCenter(bug.holeIndex);
          _pushFx('+$pts', c.dx, c.dy, LululuColors.toxicNeon);
        }
      }
      _shake = 0.28;
      _hint = 'İLAÇ SIKILDI · $cleared HEDEF TEMİZLENDİ!';
      _pushFx(
        'İLAÇ TEMİZLİĞİ!',
        _arena.width / 2,
        _arena.height / 2 - 20,
        LululuColors.toxicNeon,
      );
    });
    return true;
  }

  Future<void> _presentResult() async {
    await ProgressManager.instance.addCoins(_coinsEarned);
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeTerlik,
      _score,
    );
    await ProgressManager.instance.recordTaskProgress('play');
    if (!mounted) return;
    final replay = await showGameResult(
      context,
      score: _score,
      coins: _coinsEarned,
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

  String _formatNumber(int value) {
    final digits = value.toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
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
    final topPad = MediaQuery.paddingOf(context).top;
    final hasHostStatusBar = topPad > 0;
    final coins = widget.prototypeVisualState
        ? 12450
        : (ProgressManager().coins > 0 ? ProgressManager().coins : 12450);
    final bonusItems = [
      stockBonus(
        id: 'dblslip',
        label: 'ÇİFT TERLİK',
        asset: 'assets/icons2/boot.png',
        effect: () {
          _useDoubleSlip();
          setState(() {});
        },
      ),
      stockBonus(
        id: 'goldslip',
        label: 'ALTIN TERLİK',
        asset: 'assets/icons2/premium_token.png',
        effect: () {
          _useGoldSlip();
          setState(() {});
        },
      ),
      stockBonus(
        id: 'spraybug',
        label: 'İLAÇ',
        asset: 'assets/icons2/potion_health.png',
        effect: () {
          _useBugSpray();
          setState(() {});
        },
      ),
    ];

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
                opacity: 0.96,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.95, 0, 0, 0, 0,
                    0, 0.95, 0, 0, 0,
                    0, 0, 0.95, 0, 0,
                    0, 0, 0, 1, 0,
                  ]),
                  child: Image.asset(
                    'assets/design/backgrounds/terlik_livingroom.webp',
                    fit: BoxFit.cover,
                  ),
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
            Column(
              children: [
                if (hasHostStatusBar)
                  SizedBox(height: widget.prototypeVisualState ? 35.4 : topPad)
                else
                  SizedBox(
                    height: 35.4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            child: CustomPaint(
                              painter: _TerlikStatusIndicatorsPainter(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(
                  height: 54,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Geri',
                          child: GestureDetector(
                            onTap: () => Navigator.maybePop(context),
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
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
                                'assets/icons2/back-prototype.png',
                                width: 29,
                                height: 29,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                      'TERLİK TAP',
                                      style: GoogleFonts.baloo2(
                                        fontSize: 20,
                                        height: 1.05,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        shadows: const [
                                          Shadow(
                                            color: Color(0xEB000000),
                                            offset: Offset(0, 2),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 20.3,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B35),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'YENİ',
                                      style: GoogleFonts.baloo2(
                                        fontSize: 10.5,
                                        height: 1.0,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.735,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatNumber(coins),
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
                        Semantics(
                          button: true,
                          label: 'Nasıl oynanır',
                          child: GestureDetector(
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('TERLİK TAP'),
                                content: Text(_hint),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('ANLADIM'),
                                  ),
                                ],
                              ),
                            ),
                            child: Container(
                              width: 48,
                              height: 48,
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
                                    color: Color(0x73000000),
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
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 58.5,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: LayoutBuilder(
                      builder: (context, hudBox) {
                        final hudRow = Row(
                          children: [
                            Container(
                              width: 104,
                              height: 50.5,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xD9080B12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x73FFB800),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 12,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'SKOR',
                                        style: GoogleFonts.nunito(
                                          fontSize: 10,
                                          height: 1,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFFFB800),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3.5),
                                  SizedBox(
                                    height: 21,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '$_score',
                                          style: GoogleFonts.baloo2(
                                            fontSize: 21,
                                            height: 1,
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
                            const SizedBox(width: 8),
                            Container(
                              width: 84,
                              height: 50.5,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xD9080B12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x73FFB800),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 12,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'REKOR',
                                        style: GoogleFonts.nunito(
                                          fontSize: 10,
                                          height: 1,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFFFB800),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3.5),
                                  SizedBox(
                                    height: 21,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _formatNumber(_best),
                                          style: GoogleFonts.baloo2(
                                            fontSize: 21,
                                            height: 1,
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
                            const Spacer(),
                            Container(
                              width: 98.4,
                              height: 50.5,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xD9080B12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x73FFB800),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 12,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'CAN',
                                        style: GoogleFonts.nunito(
                                          fontSize: 10,
                                          height: 1,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFFFB800),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var index = 0; index < 3; index++) ...[
                                        if (index > 0)
                                          const SizedBox(width: 4.2),
                                        Opacity(
                                          opacity: index < _lives ? 1 : 0.25,
                                          child: Image.asset(
                                            'assets/icons/health.png',
                                            width: 20,
                                            height: 20,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _restart,
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
                                  'BİTİR',
                                  style: GoogleFonts.baloo2(
                                    fontSize: 12.5,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF4A2E00),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                        if (hudBox.maxWidth >= 364) return hudRow;
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 364,
                            height: 50.5,
                            child: hudRow,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x660E1422), Color(0x800E1422)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0x24FFFFFF),
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: LayoutBuilder(
                              builder: (context, box) {
                                _arena = Size(box.maxWidth, box.maxHeight);
                                return Semantics(
                                  label: _hint,
                                  child: Transform.translate(
                                    offset: Offset(shakeX, shakeY),
                                    child: Stack(
                                      children: [
                                        if (!widget.prototypeVisualState)
                                          const Positioned(
                                            left: 0,
                                            top: 0,
                                            width: 0,
                                            height: 0,
                                            child: Opacity(
                                              opacity: 0,
                                              child: Text('TERLIK TAP'),
                                            ),
                                          ),
                                        Center(
                                          child: GridView.count(
                                            crossAxisCount: 3,
                                            mainAxisExtent:
                                                widget.prototypeVisualState
                                                ? 76
                                                : 146,
                                            mainAxisSpacing:
                                                widget.prototypeVisualState
                                                ? 10
                                                : 28,
                                            crossAxisSpacing:
                                                widget.prototypeVisualState
                                                ? 12
                                                : 16,
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              16,
                                              16,
                                              6,
                                            ),
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            children: [
                                              for (var index = 0;
                                                  index < 9;
                                                  index++)
                                                _TerlikHole(
                                                  key: ValueKey(
                                                    'terlik-hole-$index',
                                                  ),
                                                  index: index,
                                                  bug: _bugs
                                                      .where(
                                                        (bug) =>
                                                            bug.holeIndex ==
                                                                index &&
                                                            (bug.smashed ||
                                                                bug.life > 0),
                                                      )
                                                      .firstOrNull,
                                                  pulse: _pulse.value,
                                                  prototypeVisualState:
                                                      widget.prototypeVisualState,
                                                  onTap: () => _tapHole(index),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (_combo > 0)
                                          Positioned(
                                            left: 12,
                                            top: 10,
                                            child: _TerlikCombo(
                                              label: 'COMBO X$_combo!',
                                            ),
                                          )
                                        else if (!widget.prototypeVisualState)
                                          Positioned(
                                            left: 12,
                                            right: 12,
                                            top: 12,
                                            child: IgnorePointer(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 7,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0x8C080B12,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0x2EFFFFFF,
                                                    ),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Text(
                                                      'DELİKTEN ÇIKANI ANINDA EZ!',
                                                      style: TextStyle(
                                                        fontFamily: 'Nunito',
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        letterSpacing: 0.7,
                                                        color: Color(
                                                          0xFFFFB800,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      'HIZ X${(1 + _elapsedSeconds / 30).clamp(1.0, 2.5).toStringAsFixed(1)}',
                                                      style: const TextStyle(
                                                        fontFamily: 'Nunito',
                                                        fontSize: 10.5,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 0.5,
                                                        color: Color(
                                                          0xCCFFFFFF,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          left: 10,
                                          bottom: 52,
                                          child: _TerlikChip(
                                            label: 'VURUŞ $_smashed',
                                          ),
                                        ),
                                        Positioned(
                                          right: 12,
                                          bottom: 54,
                                          child: _TerlikCombo(
                                            label: 'KAÇAN $_missed!',
                                            danger: true,
                                          ),
                                        ),
                                        if (_missMessage != null)
                                          Positioned(
                                            top: 42,
                                            right: 12,
                                            child: _TerlikChip(
                                              label: _missMessage!,
                                              danger: true,
                                            ),
                                          ),
                                        for (final f in _fx)
                                          Positioned(
                                            left: f.x - 48,
                                            top: f.y - 12,
                                            width: 96,
                                            child: IgnorePointer(
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
                                                        color: LululuColors
                                                            .carbonVoid
                                                            .withValues(
                                                              alpha: 0.85,
                                                            ),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
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
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 80.9,
                  child: _TerlikBonusDock(items: bonusItems),
                ),
              ],
            ),
            if (!_alive && !_resultShown)
              Positioned.fill(
                child: ArcadeResultOverlay(
                  title: 'TERLİK BİTTİ',
                  message: _stats(),
                  score: _score,
                  best: _best,
                  won: false,
                  modeTitle: 'TERLİK TAP',
                  shareLine: _stats(),
                  retryLabel: 'YENİDEN',
                  onRetry: _restart,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TerlikHole extends StatelessWidget {
  const _TerlikHole({
    super.key,
    required this.index,
    required this.bug,
    required this.pulse,
    this.prototypeVisualState = false,
    required this.onTap,
  });

  final int index;
  final _Bug? bug;
  final double pulse;
  final bool prototypeVisualState;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visibleBug = bug != null && (!bug!.smashed || bug!.life > 0);
    final hit = visibleBug && bug!.smashed;
    final halfClip = bug != null && bug!.halfVisible && !hit;
    final bugW = prototypeVisualState ? 50.0 : 92.0;
    final bugH = prototypeVisualState ? 50.0 : 96.0;
    final holeH = prototypeVisualState ? 26.0 : 38.0;
    final bugBottom = prototypeVisualState ? 13.0 : 19.0;
    return Semantics(
      button: true,
      label: visibleBug ? 'Böceği ez, delik ${index + 1}' : 'Boş delik',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: prototypeVisualState ? null : (_) => onTap(),
        onTap: prototypeVisualState ? onTap : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (visibleBug)
              Positioned(
                left: 0,
                right: 0,
                bottom: bugBottom,
                child: Center(
                  child: Opacity(
                    opacity: hit && !prototypeVisualState
                        ? bug!.life.clamp(0.0, 1.0)
                        : 1,
                    child: Transform(
                      alignment: Alignment.bottomCenter,
                      transform: hit && !prototypeVisualState
                          ? Matrix4.diagonal3Values(1.15, 0.65, 1)
                          : Matrix4.identity(),
                      child: Transform.rotate(
                        angle: prototypeVisualState
                            ? 0.0
                            : (hit ? 0.08 : sin(pulse * pi * 2) * 0.03),
                        child: SizedBox(
                          width: bugW,
                          height: bugH,
                          child: halfClip
                              ? Align(
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    width: bugW,
                                    height: 31,
                                    child: ClipRect(
                                      child: OverflowBox(
                                        alignment: Alignment.bottomCenter,
                                        minWidth: bugW,
                                        maxWidth: bugW,
                                        minHeight: bugH,
                                        maxHeight: bugH,
                                        child: StickerImage(
                                          assetPath: bug!.assetPath,
                                          key: ValueKey(
                                            'terlik-bug-hole-$index',
                                          ),
                                          width: bugW,
                                          height: bugH,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : StickerImage(
                                  assetPath: bug!.assetPath,
                                  key: ValueKey('terlik-bug-hole-$index'),
                                  width: bugW,
                                  height: bugH,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: prototypeVisualState ? 0.86 : 0.92,
                  child: Container(
                    height: holeH,
                    decoration: BoxDecoration(
                      color: const Color(0xFF04060A),
                      borderRadius: const BorderRadius.all(
                        Radius.elliptical(49, 13),
                      ),
                      border: (!prototypeVisualState && visibleBug && !hit)
                          ? Border.all(
                              color: bug!.isTrap
                                  ? const Color(0x99E52E2E)
                                  : const Color(0x88FFB800),
                              width: 1.5,
                            )
                          : null,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12FFFFFF),
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (visibleBug && bug!.isTrap && !hit)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE52E2E),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'TUZAK!',
                      style: GoogleFonts.nunito(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            if (hit) ...[
              Positioned(
                top: 2,
                left: 18,
                child: Image.asset(
                  'assets/icons2/terlik-hitstar-prototype.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                top: -4,
                left: 65.4,
                child: Transform.rotate(
                  angle: -16 * pi / 180,
                  child: Image.asset(
                    'assets/icons2/terlik-slip-prototype.webp',
                    width: 47,
                    height: 47,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TerlikCombo extends StatelessWidget {
  const _TerlikCombo({required this.label, this.danger = false});

  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: GoogleFonts.bangers(
      fontSize: danger ? 21 : 23,
      height: 1,
      letterSpacing: 0.6,
      color: danger ? const Color(0xFFE52E2E) : const Color(0xFFFFB800),
      shadows: [
        Shadow(
          color: LululuColors.carbonVoid.withValues(alpha: 0.92),
          offset: const Offset(0, 3),
        ),
        Shadow(
          color: danger ? const Color(0xE6FFD700) : const Color(0xE6FF6B35),
          blurRadius: 14,
        ),
        Shadow(
          color: (danger ? const Color(0x8CFFD700) : const Color(0x8CFF6B35)),
          blurRadius: 32,
        ),
        Shadow(
          color: (danger ? const Color(0x52FFD700) : const Color(0x52FF6B35)),
          blurRadius: 54,
        ),
      ],
    ),
  );
}

class _TerlikBonusDock extends StatelessWidget {
  const _TerlikBonusDock({required this.items});

  final List<ModeBonus> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(width: 20),
          _TerlikBonusButton(item: items[index]),
        ],
      ],
    ),
  );
}

class _TerlikBonusButton extends StatelessWidget {
  const _TerlikBonusButton({required this.item});

  final ModeBonus item;

  @override
  Widget build(BuildContext context) {
    final enabled = item.onTap != null && item.count > 0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '${item.label}. ${item.count} adet',
      child: GestureDetector(
        onTap: enabled ? item.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: item.count > 0 ? 1 : 0.55,
          child: SizedBox(
            width: 66,
            height: 62.9,
            child: Column(
              children: [
                const SizedBox(height: 2),
                SizedBox(
                  height: 48,
                  width: 66,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 48,
                        width: 48,
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
                          item.asset,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: 3,
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE01E5A),
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Color(0xFF141B2A), width: 2),
                            ),
                          ),
                          child: Text(
                            '${item.count}',
                            style: GoogleFonts.nunito(
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
                const SizedBox(height: 3),
                SizedBox(
                  height: 9.9,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 9,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.18,
                        color: const Color(0xFFD8E0EE),
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
}

class _TerlikChip extends StatelessWidget {
  const _TerlikChip({required this.label, this.danger = false});

  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 85, minHeight: 30.6),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xE6080B12),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: danger ? const Color(0xE6E52E2E) : const Color(0x8CFFB800),
      ),
    ),
    child: Text(
      label,
      style: GoogleFonts.nunito(
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w900,
        color: danger ? const Color(0xFFFF8A8A) : Colors.white,
      ),
    ),
  );
}

class _TerlikStatusIndicatorsPainter extends CustomPainter {
  const _TerlikStatusIndicatorsPainter();

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
  bool shouldRepaint(_TerlikStatusIndicatorsPainter oldDelegate) => false;
}
