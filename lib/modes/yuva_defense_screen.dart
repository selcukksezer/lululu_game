import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/daily_challenge_service.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';

class YuvaDefenseScreen extends StatefulWidget {
  const YuvaDefenseScreen({
    super.key,
    this.energyConsumed = false,
    @visibleForTesting this.prototypeVisualState = false,
  });

  /// `true` ise bu ekrana giriş `openGameMode` üzerinden 1 enerji
  /// tüketerek yapıldı; hiç hamle yapılmadan çıkılırsa enerji iade
  /// edilir (Stack Drop deseni). Doğrudan rota girişlerinde
  /// `false` kalır.
  final bool energyConsumed;

  @visibleForTesting
  final bool prototypeVisualState;

  @override
  State<YuvaDefenseScreen> createState() => _YuvaDefenseScreenState();
}

class _DefenseBug {
  _DefenseBug({
    required this.id,
    required this.tier,
    required this.lane,
    required this.direction,
    required this.x,
    required this.y,
    this.speedMultiplier = 1.0,
  });

  final int id;
  final InsectTier tier;
  final int lane;
  final double direction;
  double x;
  double y;
  final double speedMultiplier;
  bool popping = false;
  double popTime = 0;
}

class _HitBurst {
  _HitBurst({required this.x, required this.y});

  final double x;
  final double y;
  double life = 1;
}

class _YuvaDefenseScreenState extends State<YuvaDefenseScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Tohumsuz: her tur farklı doğma düzeni (sabit tohum her turu aynen tekrarlardı).
  final _random = Random();
  final List<_DefenseBug> _bugs = [];
  final List<_HitBurst> _bursts = [];
  late final AnimationController _pulse;
  late final AnimationController _comboPulse;
  Timer? _loop;
  Timer? _hitEffectTimer;
  DateTime _lastTick = DateTime.now();
  // Duraklatma (madde 37): Osmantuş deseni — arka planda oyun zamanlayıcısı
  // durur, elle duraklatmada da aynı zamanlayıcı durdurulur; altın terlik /
  // buz / kombo penceresi gibi duvar-saati süreleri duraklatma süresi kadar
  // ötelenir. takePower korumalarına dokunulmaz; güçlendirici handler'ları
  // duraklatmada en başta döner, kasa hiç tüketilmez.
  bool _paused = false;
  bool _pausedByLifecycle = false;
  DateTime? _pauseStartedAt;
  DateTime? _lastHit;
  int _nextBugId = 0;
  int _score = 0;
  int _best = 0;
  int _lives = 3;
  int _combo = 0;
  int _maxCombo = 0;
  int _hits = 0;
  int _misses = 0;
  int _coinsEarned = 0;
  int _doubleSlipCount = 3;
  int _goldSlipCount = 2;
  int _shieldCount = 1;
  int _doubleSlipCharges = 0;
  DateTime? _goldSlipUntil;
  DateTime? _freezeUntil;
  bool _shieldActive = false;
  bool _resultShown = false;

  /// Hamle bayrağı (enerji iadesi): oturum boyunca ilk savunma
  /// aksiyonu ile `true` olur — arenaya ilk dokunuş (`_tapArena`,
  /// isabet/ıska fark etmez), böcek ezilmesi (`_hitBug`, dokunuşla
  /// veya güçlendirici otomatik vuruşuyla), güçlendirici kullanımı
  /// (kasa tüketimi) veya turun bitmesi (`_endGame`). TEKRAR/yeniden
  /// başlatmada SIFIRLANMAZ (Stack Drop `_moveMade` deseni —
  /// oturum ömrü).
  bool _moveMade = false;

  /// Çift-iade koruması: iade bu oturumda en fazla bir kez yapılır.
  bool _energyRefunded = false;
  double _spawnElapsed = 0;
  double _arenaWidth = 300;
  double _arenaHeight = 360;
  double _shake = 0;
  double _elapsedSeconds = 0;
  double? _hitEffectX;
  double? _hitEffectY;
  int? _hitEffectLane;
  bool _ended = false;
  // S1#48: bitiş anı — ölüm sonrası ilk 500 ms içindeki dokunuş
  // yeniden başlatmaz.
  DateTime? _endedAt;
  bool _hitEffectActive = false;
  String _hint = 'Yuvaya yaklaşan böcekleri durdur!';
  // W66-3: _hint'in kombo-bitiş mesajı olup olmadığı metnin
  // sabit TR önekiyle karşılaştırılarak okunmaz; dil bağımsız
  // bu bayrakla taşınır. Her _hint atamasında güncellenir.
  bool _hintIsComboBroken = false;

  static const _gold = Color(0xFFFFB800);
  static const _ink = Color(0xFF4A2E00);
  static const _laneTopFactors = [0.07, 0.41, 0.75];
  static const double _nestCenterX = 0.50;
  static const double _nestCenterY = 0.45;

  static double _laneTop(int lane, double arenaHeight) =>
      _laneTopFactors[lane] * arenaHeight;

  static double _laneCenterY(int lane, double arenaHeight) =>
      _laneTop(lane, arenaHeight) + 30;

  bool get _isGoldActive =>
      _goldSlipUntil != null && DateTime.now().isBefore(_goldSlipUntil!);

  bool get _isFrozen =>
      _freezeUntil != null && DateTime.now().isBefore(_freezeUntil!);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _comboPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    AudioManager().initialize();
    unawaited(
      ProgressManager().load().then((_) {
        if (!mounted || widget.prototypeVisualState) return;
        setState(() {
          _doubleSlipCount = ProgressManager.instance.powerCount('dblslip');
          _goldSlipCount = ProgressManager.instance.powerCount('goldslip');
          _shieldCount = ProgressManager.instance.powerCount('shield');
        });
      }),
    );
    _best = LeaderboardService.instance.getBest(LeaderboardService.modeYuva);
    if (widget.prototypeVisualState) {
      _pulse.value = 0;
      _comboPulse.value = 0.31;
      _score = 740;
      _best = max(_best, 1240);
      _combo = 5;
      _maxCombo = 5;
      _hits = 17;
      _misses = 2;
      _lastHit = DateTime.now();
      _spawn(lane: 0, fromLeft: true, x: 0.1611, tier: InsectTier.helmet);
      _spawn(lane: 1, fromLeft: false, x: 0.8338, tier: InsectTier.diva);
      _spawn(lane: 1, fromLeft: true, x: 0.5927, tier: InsectTier.dancer);
      _bugs.last
        ..popping = true
        ..popTime = 0.10;
      _hitEffectX = 0.57;
      _hitEffectLane = _bugs.last.lane;
      _hitEffectActive = true;
      _spawn(lane: 2, fromLeft: true, x: 0.2515, tier: InsectTier.cone);
      _spawn(lane: 2, fromLeft: false, x: 0.4326, tier: InsectTier.fan);
    } else {
      _spawnRadial(angleRad: 0.25, radiusFrac: 0.42);
      _spawnRadial(angleRad: 2.35, radiusFrac: 0.44);
      _spawnRadial(angleRad: 4.20, radiusFrac: 0.40);
      _spawnRadial(angleRad: 5.35, radiusFrac: 0.43);
      _loop = Timer.periodic(const Duration(milliseconds: 16), _tick);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioManager().stopAll();
    _loop?.cancel();
    _hitEffectTimer?.cancel();
    _pulse.dispose();
    _comboPulse.dispose();
    super.dispose();
  }

  void _startLoop() {
    _lastTick = DateTime.now();
    _loop ??= Timer.periodic(const Duration(milliseconds: 16), _tick);
  }

  void _stopLoop() {
    _loop?.cancel();
    _loop = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.prototypeVisualState) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Osmantuş deseni: arka planda oyun saati dursun; _tick dt
        // kısması da korur ama zamanlayıcıyı durdurmak kesin çözümdür.
        if (_loop != null) {
          _stopLoop();
          _pausedByLifecycle = true;
          _pauseStartedAt ??= DateTime.now();
        }
        break;
      case AppLifecycleState.resumed:
        // Elle duraklatılmışsa dönüşte kendiliğinden başlamasın.
        if (_pausedByLifecycle && !_paused) {
          _pausedByLifecycle = false;
          _shiftPauseDeadlines();
          if (!_ended) _startLoop();
        }
        break;
    }
  }

  /// Duraklatma süresince duvar-saati süreleri (altın terlik, buz, kombo
  /// penceresi) işlemesin.
  void _shiftPauseDeadlines() {
    final started = _pauseStartedAt;
    _pauseStartedAt = null;
    if (started == null) return;
    final pausedFor = DateTime.now().difference(started);
    if (pausedFor <= Duration.zero) return;
    if (_goldSlipUntil != null) {
      _goldSlipUntil = _goldSlipUntil!.add(pausedFor);
    }
    if (_freezeUntil != null) _freezeUntil = _freezeUntil!.add(pausedFor);
    if (_lastHit != null) _lastHit = _lastHit!.add(pausedFor);
  }

  /// Elle duraklatma / devam (madde 37): zamanlayıcı durur, böcek ilerlemesi
  /// ve doğma sayacı donar.
  void _togglePause() {
    if (widget.prototypeVisualState || _ended) return;
    if (_paused) {
      _paused = false;
      _pausedByLifecycle = false;
      _shiftPauseDeadlines();
      _startLoop();
    } else {
      _paused = true;
      _pauseStartedAt ??= DateTime.now();
      _stopLoop();
    }
    setState(() {});
  }

  void _spawn({
    int? lane,
    bool? fromLeft,
    double? x,
    double? y,
    InsectTier? tier,
  }) {
    final chosenLane = lane ?? _random.nextInt(_laneTopFactors.length);
    final left = fromLeft ?? _random.nextBool();
    final spawnX = x ?? (left ? 0.08 : 0.92);
    final spawnY = y ?? (_laneTopFactors[chosenLane] + 0.05);
    _bugs.add(
      _DefenseBug(
        id: _nextBugId++,
        tier:
            tier ??
            InsectTier.values[_random.nextInt(InsectTier.values.length)],
        lane: chosenLane,
        direction: left ? 1 : -1,
        x: spawnX,
        y: spawnY,
      ),
    );
  }

  /// Canlı oynanışta 360° rastgele kenar noktalarından orta deliğe (YUVA) doğru böcek doğurur.
  void _spawnRadial({double? angleRad, double? radiusFrac, InsectTier? tier}) {
    final theta = angleRad ?? (_random.nextDouble() * 2 * pi);
    final r = radiusFrac ?? (0.44 + _random.nextDouble() * 0.05);
    final sx = (_nestCenterX + cos(theta) * r).clamp(0.06, 0.94);
    final sy = (_nestCenterY + sin(theta) * r).clamp(0.08, 0.88);
    final selectedTier =
        tier ?? InsectTier.values[_random.nextInt(InsectTier.values.length)];
    final speedMul = 0.88 + _random.nextDouble() * 0.36;
    _bugs.add(
      _DefenseBug(
        id: _nextBugId++,
        tier: selectedTier,
        lane: 1,
        direction: sx < _nestCenterX ? 1 : -1,
        x: sx,
        y: sy,
        speedMultiplier: speedMul,
      ),
    );
  }

  void _tick(Timer _) {
    if (!mounted || _ended || _paused) return;
    final now = DateTime.now();
    var dt = now.difference(_lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    if (dt <= 0 || dt > 0.05) dt = 0.016;

    if (_combo > 0 &&
        _lastHit != null &&
        now.difference(_lastHit!).inMilliseconds >= 1600) {
      _combo = 0;
      _hint = context.l10n.comboBreakToast(context.l10n.comboTimeoutReason);
      _hintIsComboBroken = true;
    }
    for (final burst in _bursts) {
      burst.life -= dt * 3.8;
    }
    _bursts.removeWhere((burst) => burst.life <= 0);
    _shake = max(0, _shake - dt * 3);

    _elapsedSeconds += dt;
    _spawnElapsed += dt;
    // Zaman ve vuruş sayısı arttıkça hem doğma sıklığı hem hız gitgide artar!
    final ramp = _elapsedSeconds + _hits * 0.65;
    final spawnEvery = max(0.36, 1.25 - ramp * 0.016);
    if (_spawnElapsed >= spawnEvery) {
      _spawnElapsed = 0;
      _spawnRadial();
      // İlerleyen saniyelerde aynı anda farklı köşelerden çift böcek gelebilir
      if (ramp > 18 && _bugs.length < 9 && _random.nextDouble() < 0.38) {
        _spawnRadial();
      }
    }

    final baseSpeed = 0.095 + min(0.24, ramp * 0.0036);
    final speed = _isFrozen ? baseSpeed * 0.42 : baseSpeed;
    _bugs.removeWhere((bug) {
      if (!bug.popping) return false;
      bug.popTime -= dt;
      return bug.popTime <= 0;
    });
    var escaped = false;
    for (final bug in _bugs) {
      if (bug.popping) continue;
      final dx = _nestCenterX - bug.x;
      final dy = _nestCenterY - bug.y;
      final dist = sqrt(dx * dx + dy * dy);
      final step = speed * bug.speedMultiplier * dt;
      if (dist > 0.001) {
        bug.x += (dx / dist) * step;
        bug.y += (dy / dist) * step;
      }
      if (dist <= 0.072) {
        if (_shieldActive) {
          _shieldActive = false;
          final pushTheta = atan2(bug.y - _nestCenterY, bug.x - _nestCenterX);
          bug.x = (_nestCenterX + cos(pushTheta) * 0.42).clamp(0.08, 0.92);
          bug.y = (_nestCenterY + sin(pushTheta) * 0.40).clamp(0.10, 0.86);
          _bursts.add(
            _HitBurst(
              x: _nestCenterX * _arenaWidth,
              y: _nestCenterY * _arenaHeight,
            ),
          );
          HapticFeedback.mediumImpact();
          unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
          _hint = context.l10n.yuvaShieldSaved;
          _hintIsComboBroken = false;
          continue;
        }
        _bugs.remove(bug);
        _lives--;
        _misses++;
        _combo = 0;
        _hint = context.l10n.yuvaBugEntered(_lives);
        _hintIsComboBroken = false;
        escaped = true;
        break;
      }
    }
    if (escaped && _lives <= 0) {
      _endGame();
      return;
    }
    setState(() {});
  }

  /// S1#48: ölüm sonrası 500 ms geçmeden dokunuşla yeniden başlatma yok.
  bool _deathRestartAllowed() =>
      _endedAt == null ||
      DateTime.now().difference(_endedAt!) >=
          const Duration(milliseconds: 500);

  void _endGame() {
    // Tur tamamlandı: iade hakkı biter (Stack Drop `_fail` deseni).
    _moveMade = true;
    _ended = true;
    _endedAt = DateTime.now();
    _best = max(_best, _score);
    final endCoins = max(1, _score ~/ 360);
    _coinsEarned += endCoins;
    HapticFeedback.heavyImpact();
    unawaited(AudioManager().playLose());
    unawaited(
      LeaderboardService.instance.submitScore(
        LeaderboardService.modeYuva,
        _score,
      ),
    );
    unawaited(
      DailyChallengeService.instance.tryCompleteWithScore(
        LeaderboardService.modeYuva,
        _score,
      ),
    );
    setState(() {
      _hint = context.l10n.yuvaFellHint;
      _hintIsComboBroken = false;
    });
    if (!widget.prototypeVisualState && !_resultShown) {
      _resultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _presentResult();
      });
    }
  }

  /// Hamlesiz-çıkış enerji iadesi (tek çıkış noktası: `PopScope`).
  ///
  /// Yalnız giriş enerjisi tüketildiyse, tur tamamlanmadıysa ve oturum
  /// boyunca hiç hamle yapılmadıysa 1 enerji iade edilir. `dispose`
  /// içinde DEĞİL, yalnızca gerçek rota çıkışında (`didPop`) çağrılır.
  void _maybeRefundEnergy() {
    if (_energyRefunded) return;
    if (!widget.energyConsumed ||
        _moveMade ||
        _ended ||
        _resultShown) {
      return;
    }
    _energyRefunded = true;
    EnergyService.instance.addEnergy(1);
  }

  Future<void> _presentResult() async {
    // S1#49: ödeme (birikmiş _coinsEarned) + liderlik + görev kaydı +
    // sonuç ekranı finishRun() üzerinden (tek-ödeme korunur).
    // _endGame'deki liderlik gönderimi ayrıca durur (eski çift-gönderim
    // davranışı aynen korunur).
    final replay = await finishRun(
      context,
      score: _score,
      best: _best,
      coins: _coinsEarned,
      leaderboardMode: LeaderboardService.modeYuva,
    );
    if (!mounted) return;
    _resultShown = false;
    if (!replay) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    _restart();
  }

  void _hitBug(_DefenseBug bug, {bool fromSplash = false}) {
    if (_paused) return;
    if (_ended) {
      if (!_deathRestartAllowed()) return;
      _restart();
      return;
    }
    if (bug.popping || !_bugs.contains(bug)) return;
    // Savunma aksiyonu: böcek ezildi (dokunuşla veya güçlendirici
    // otomatik vuruşuyla fark etmez).
    _moveMade = true;
    bug.popping = true;
    bug.popTime = 0.10;
    final now = DateTime.now();
    _combo = _lastHit != null && now.difference(_lastHit!).inMilliseconds < 1400
        ? _combo + 1
        : 1;
    if (_combo > _maxCombo) _maxCombo = _combo;
    _hits++;
    _lastHit = now;
    _hitEffectX = bug.x;
    _hitEffectY = bug.y;
    _hitEffectLane = bug.lane;
    _hitEffectActive = true;
    _hitEffectTimer?.cancel();
    _hitEffectTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _hitEffectActive = false);
    });
    final basePoints = 40 + _combo * 10 + bug.tier.tier * 5;
    final points = _isGoldActive ? basePoints * 2 : basePoints;
    _score += points;
    _best = max(_best, _score);
    final wave = 1 + (_hits ~/ 8);
    _hint = _hits % 8 == 0
        ? context.l10n.yuvaWaveHit(wave, points, _combo)
        : context.l10n.yuvaHitHint(points, _combo);
    _hintIsComboBroken = false;
    _bursts.add(
      _HitBurst(
        x: bug.x * _arenaWidth,
        y: widget.prototypeVisualState
            ? _laneCenterY(bug.lane, _arenaHeight)
            : bug.y * _arenaHeight,
      ),
    );
    if (!fromSplash && _doubleSlipCharges > 0) {
      _doubleSlipCharges--;
      final extra = _bugs
          .where((candidate) => !candidate.popping && !identical(candidate, bug))
          .firstOrNull;
      if (extra != null) {
        _hitBug(extra, fromSplash: true);
      }
    }
    _shake = min(0.35, 0.12 + _combo * 0.025);
    HapticFeedback.mediumImpact();
    unawaited(
      AudioManager().playSlipperSmash(
        characterId: GameAudio.characterIdForTier(bug.tier),
        tier: bug.tier,
        comboCount: _combo,
      ),
    );
    setState(() {});
  }

  double _bugDistanceToNest(_DefenseBug bug) {
    if (widget.prototypeVisualState) {
      return (bug.x - 0.5).abs();
    }
    final dx = bug.x - _nestCenterX;
    final dy = bug.y - _nestCenterY;
    return sqrt(dx * dx + dy * dy);
  }

  void _useDoubleSlipBonus() {
    if (_paused || _ended || _doubleSlipCount <= 0) return;
    // Kasa boşsa (yerel sayaç bayatsa) etki çalışmaz, sayaç azalmaz.
    if (!ProgressManager.instance.takePower('dblslip')) {
      setState(() {
        _doubleSlipCount = ProgressManager.instance.powerCount('dblslip');
      });
      return;
    }
    // Savunma aksiyonu: güçlendirici kullanıldı (kasa tüketildi).
    _moveMade = true;
    setState(() {
      _doubleSlipCount--;
      _doubleSlipCharges = 3;
      _hint = context.l10n.yuvaDoubleHint;
      _hintIsComboBroken = false;
    });
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    final nearest = _bugs.where((b) => !b.popping).toList()
      ..sort((a, b) => _bugDistanceToNest(a).compareTo(_bugDistanceToNest(b)));
    if (nearest.isNotEmpty) {
      _hitBug(nearest.first);
    }
  }

  void _useGoldSlipBonus() {
    if (_paused || _ended || _goldSlipCount <= 0) return;
    // Kasa boşsa (yerel sayaç bayatsa) etki çalışmaz, sayaç azalmaz.
    if (!ProgressManager.instance.takePower('goldslip')) {
      setState(() {
        _goldSlipCount = ProgressManager.instance.powerCount('goldslip');
      });
      return;
    }
    // Savunma aksiyonu: güçlendirici kullanıldı (kasa tüketildi).
    _moveMade = true;
    setState(() {
      _goldSlipCount--;
      _goldSlipUntil = DateTime.now().add(const Duration(seconds: 12));
      _hint = context.l10n.yuvaGoldHint;
      _hintIsComboBroken = false;
    });
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    final nearest = _bugs.where((b) => !b.popping).toList()
      ..sort((a, b) => _bugDistanceToNest(a).compareTo(_bugDistanceToNest(b)));
    if (nearest.isNotEmpty) {
      _hitBug(nearest.first, fromSplash: true);
    }
  }

  void _useShieldBonus() {
    if (_paused || _ended || _shieldCount <= 0) return;
    // Kasa boşsa (yerel sayaç bayatsa) etki çalışmaz, sayaç azalmaz.
    if (!ProgressManager.instance.takePower('shield')) {
      setState(() {
        _shieldCount = ProgressManager.instance.powerCount('shield');
      });
      return;
    }
    // Savunma aksiyonu: güçlendirici kullanıldı (kasa tüketildi).
    _moveMade = true;
    setState(() {
      _shieldCount--;
      _shieldActive = true;
      _freezeUntil = DateTime.now().add(const Duration(seconds: 6));
      for (final bug in _bugs) {
        if (bug.popping) continue;
        if (widget.prototypeVisualState) {
          bug.x = bug.direction > 0
              ? max(0.08, bug.x - 0.14)
              : min(0.92, bug.x + 0.14);
        } else {
          final dx = bug.x - _nestCenterX;
          final dy = bug.y - _nestCenterY;
          final dist = max(0.001, sqrt(dx * dx + dy * dy));
          bug.x = (bug.x + (dx / dist) * 0.16).clamp(0.06, 0.94);
          bug.y = (bug.y + (dy / dist) * 0.16).clamp(0.06, 0.94);
        }
      }
      _hint = context.l10n.yuvaShieldIceHint;
      _hintIsComboBroken = false;
    });
    HapticFeedback.heavyImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
  }

  void _tapArena(TapDownDetails details) {
    if (_paused) return;
    if (_ended) {
      if (!_deathRestartAllowed()) return;
      _restart();
      return;
    }
    // Savunma aksiyonu: arenaya dokunuş (isabet/ıska fark etmez —
    // ıska da bilinçli savunma denemesidir).
    _moveMade = true;
    final p = details.localPosition - const Offset(2, 2);
    if (!widget.prototypeVisualState) {
      _DefenseBug? hit;
      var bestDistance = 68.0;
      for (final bug in _bugs.where((candidate) => !candidate.popping)) {
        final bx = bug.x * _arenaWidth;
        final by = bug.y * _arenaHeight;
        final dist = sqrt(pow(bx - p.dx, 2) + pow(by - p.dy, 2));
        if (dist < bestDistance) {
          hit = bug;
          bestDistance = dist;
        }
      }
      if (hit == null) {
        _combo = 0;
        _hint = context.l10n.yuvaMissHint;
        _hintIsComboBroken = true;
        HapticFeedback.selectionClick();
        setState(() {});
        return;
      }
      _hitBug(hit);
      return;
    }
    final laneHeight = max(72.0, _arenaHeight * 0.24);
    final lane = List<int>.generate(
      _laneTopFactors.length,
      (index) => index,
    ).indexWhere(
      (index) =>
          (p.dy - _laneCenterY(index, _arenaHeight)).abs() <= laneHeight / 2,
    );
    if (lane < 0) {
      _combo = 0;
      _hint = context.l10n.yuvaMissHint;
      _hintIsComboBroken = true;
      HapticFeedback.selectionClick();
      setState(() {});
      return;
    }
    _DefenseBug? hit;
    var bestDistance = 56.0;
    for (final bug in _bugs.where(
      (candidate) => candidate.lane == lane && !candidate.popping,
    )) {
      final dx = (bug.x * _arenaWidth - p.dx).abs();
      if (dx < bestDistance) {
        hit = bug;
        bestDistance = dx;
      }
    }
    if (hit == null) {
      _combo = 0;
      _hint = context.l10n.yuvaMissHint;
      _hintIsComboBroken = true;
      HapticFeedback.selectionClick();
      setState(() {});
      return;
    }
    _hitBug(hit);
  }

  void _restart() {
    // Restart güç üretmez: sayaçlar kasadaki güncel stoktan yüklenir
    // (initState'teki yüklemeyle aynı anahtarlar). Prototip görünümünde
    // sabit vitrin sayıları korunur (ekran zaten sabit gösterir).
    final pm = ProgressManager.instance;
    final doubleSlip =
        widget.prototypeVisualState ? 3 : pm.powerCount('dblslip');
    final goldSlip =
        widget.prototypeVisualState ? 2 : pm.powerCount('goldslip');
    final shield = widget.prototypeVisualState ? 1 : pm.powerCount('shield');
    setState(() {
      _bugs.clear();
      _bursts.clear();
      _paused = false;
      _pausedByLifecycle = false;
      _pauseStartedAt = null;
      _score = 0;
      _lives = 3;
      _combo = 0;
      _maxCombo = 0;
      _hits = 0;
      _misses = 0;
      _coinsEarned = 0;
      _doubleSlipCount = doubleSlip;
      _goldSlipCount = goldSlip;
      _shieldCount = shield;
      _doubleSlipCharges = 0;
      _goldSlipUntil = null;
      _freezeUntil = null;
      _shieldActive = false;
      _hitEffectTimer?.cancel();
      _hitEffectActive = false;
      _spawnElapsed = 0;
      _elapsedSeconds = 0;
      _ended = false;
      _endedAt = null;
      _shake = 0;
      _hint = context.l10n.yuvaHintIdle;
      _hintIsComboBroken = false;
      _lastTick = DateTime.now();
      _lastHit = null;
      if (widget.prototypeVisualState) {
        _spawn(lane: 0, fromLeft: true, x: 0.18);
        _spawn(lane: 1, fromLeft: false, x: 0.67);
        _spawn(lane: 2, fromLeft: true, x: 0.45);
      } else {
        _spawnRadial(angleRad: -2.4, radiusFrac: 0.44);
        _spawnRadial(angleRad: -0.6, radiusFrac: 0.45);
        _spawnRadial(angleRad: 1.1, radiusFrac: 0.43);
        _spawnRadial(angleRad: 2.5, radiusFrac: 0.46);
      }
    });
    // Duraklatılmışken yeniden başlatılırsa zamanlayıcı dursun kalmasın.
    if (!widget.prototypeVisualState) _startLoop();
  }

  String _formatCoins(int value) {
    final digits = value.toString();
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  }

  /// Küçük duraklatma düğmesi (madde 37): başlık satırında '?' düğmesinin
  /// yanında, HUD düzenini kaydırmadan durur; prototip vitrininde gizlidir.
  Widget _pauseButton() {
    return Semantics(
      button: true,
      label: context.l10n.pause,
      child: GestureDetector(
        onTap: _togglePause,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xDB080B12),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xB3FFB800), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), offset: Offset(0, 3)),
            ],
          ),
          child: const Icon(
            Icons.pause_rounded,
            size: 20,
            color: Color(0xFFFFB800),
          ),
        ),
      ),
    );
  }

  /// Görünür "duraklatıldı" durumu (madde 37): tam ekran kaplama dokunuşları
  /// yutar, DEVAM düğmesi oyunu kaldığı yerden başlatır.
  Widget _pauseOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: const Color(0xFF080B12).withValues(alpha: 0.72),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.pausedStatusCaps,
                  style: GoogleFonts.baloo2(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFB800),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.yuvaPauseScore(_score, _hits),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _togglePause,
                  child: Text(context.l10n.continueAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coins = widget.prototypeVisualState ? 12450 : ProgressManager().coins;
    final topPad = MediaQuery.paddingOf(context).top;
    final hasHostStatusBar = topPad > 0;
    final wideScreen = MediaQuery.sizeOf(context).width >= 400;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _maybeRefundEnergy();
      },
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF080B12),
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (!widget.prototypeVisualState)
                Positioned(
                  left: 0,
                  top: 0,
                  width: 0,
                  height: 0,
                  child: Opacity(opacity: 0, child: Text(context.l10n.shopModeNestDefense.toUpperCase())),
                ),
              Opacity(
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
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFFEAC8A0)),
                  ),
                ),
              ),
              const DecoratedBox(
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
              SafeArea(
                child: Column(
                  children: [
                    if (hasHostStatusBar)
                      SizedBox(
                        height: widget.prototypeVisualState ? 35.4 : topPad,
                      )
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
                                  painter: _YuvaStatusIndicatorsPainter(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(
                      height: wideScreen ? 56.3 : 77.2,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: Row(
                          children: [
                            _RoundAction(
                              semanticLabel: context.l10n.goBackLabel,
                              icon: Icons.arrow_back_rounded,
                              asset: 'assets/icons2/back-prototype.png',
                              onTap: () => Navigator.maybePop(context),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: wideScreen
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0x8C080B12),
                                              borderRadius: BorderRadius.circular(
                                                10,
                                              ),
                                            ),
                                            child: Text(
                                              context.l10n.shopModeNestDefense.toUpperCase(),
                                              maxLines: 1,
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
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE01E5A),
                                              borderRadius: BorderRadius.circular(
                                                999,
                                              ),
                                            ),
                                            child: Text(
                                              context.l10n.newBadge,
                                              style: GoogleFonts.baloo2(
                                                fontSize: 10.5,
                                                height: 1.1,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.735,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Image.asset(
                                        'assets/icons2/yuva-title-prototype.png',
                                        width: 155.2,
                                        height: 71.3,
                                        fit: BoxFit.fill,
                                        semanticLabel: context.l10n.yuvaTitleNewSemantic,
                                      ),
                              ),
                            ),
                            SizedBox(width: wideScreen ? 10 : 20),
                            if (wideScreen)
                              Container(
                                width: 82.5,
                                height: 35,
                                padding: const EdgeInsets.fromLTRB(6, 5, 0, 5),
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
                                    Expanded(
                                      child: Text(
                                        _formatCoins(coins),
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                        softWrap: false,
                                        style: GoogleFonts.nunito(
                                          fontSize: 13.5,
                                          height: 1,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                width: 70,
                                height: 35,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xD1080B12),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: 3,
                                        top: 8,
                                        child: Image.asset(
                                          'assets/icons2/coin.png',
                                          width: 19,
                                          height: 19,
                                        ),
                                      ),
                                      Positioned(
                                        left: 31,
                                        top: 8,
                                        child: SizedBox(
                                          width: 44,
                                          child: FittedBox(
                                            alignment: Alignment.centerLeft,
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              _formatCoins(coins),
                                              style: GoogleFonts.nunito(
                                                fontSize: 13.5,
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
                            if (!widget.prototypeVisualState) ...[
                              const SizedBox(width: 10),
                              _pauseButton(),
                            ],
                            const SizedBox(width: 10),
                            _RoundAction(
                              semanticLabel: context.l10n.helpButtonLabel,
                              icon: Icons.help_outline_rounded,
                              text: '?',
                              color: _gold,
                              circular: true,
                              onTap: () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(context.l10n.shopModeNestDefense.toUpperCase()),
                                  content: Text(
                                    context.l10n.yuvaHowToBody1 +
                                        context.l10n.yuvaHowToBody2,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(context.l10n.understoodButton),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: wideScreen ? 58.5 : 79.5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: LayoutBuilder(
                          builder: (context, hudBox) {
                            final hudRow = Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 104,
                                  child: _HudCard(
                                    label: context.l10n.gameScoreLabel,
                                    value: '$_score',
                                    singleRowHearts: wideScreen,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 84,
                                  child: _HudCard(
                                    label: context.l10n.gameBestLabel,
                                    value: _formatCoins(_best),
                                    singleRowHearts: wideScreen,
                                  ),
                                ),
                                if (wideScreen)
                                  const Spacer()
                                else
                                  const SizedBox(width: 8),
                                SizedBox(
                                  width: wideScreen ? 98.4 : 80,
                                  child: _HudCard(
                                    label: context.l10n.livesLabel,
                                    value: '$_lives',
                                    singleRowHearts: wideScreen,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Semantics(
                                  button: true,
                                  label: _ended ? context.l10n.playAgainButton : context.l10n.finishRoundLabel,
                                  child: GestureDetector(
                                  onTap: _restart,
                                  child: Container(
                                    width: 58,
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
                                      _ended
                                          ? context.l10n.tryAgainCaps
                                          : context.l10n.finishCaps,
                                      style: GoogleFonts.baloo2(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                ),
                                ),
                              ],
                            );
                            if (hudBox.maxWidth >= 350) return hudRow;
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 350,
                                height: wideScreen ? 50.5 : 71.5,
                                child: hudRow,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _arenaWidth = constraints.maxWidth - 4;
                            _arenaHeight = constraints.maxHeight - 4;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: _tapArena,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Transform.translate(
                                  offset: Offset(
                                    sin(_pulse.value * pi * 20) * _shake * 10,
                                    cos(_pulse.value * pi * 16) * _shake * 8,
                                  ),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 2,
                                      sigmaY: 2,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Color(0x660E1422),
                                            Color(0x800E1422),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.14,
                                          ),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.black.withValues(
                                                alpha: 0.35,
                                              ),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                CustomPaint(
                                                  painter: _DefenseArenaPainter(
                                                    combo: _combo,
                                                    comboProgress:
                                                        _comboPulse.value,
                                                    hits: _hits,
                                                    misses: _misses,
                                                    hitsLabel:
                                                        context.l10n.yuvaHitsPainter(
                                                          _hits,
                                                        ),
                                                    missesLabel:
                                                        context.l10n.yuvaMissedPainter(
                                                          _misses,
                                                        ),
                                                    hint: _hint,
                                                    comboBroken:
                                                        _hintIsComboBroken,
                                                    bursts: List<_HitBurst>.of(
                                                      _bursts,
                                                    ),
                                                    showRadialRings:
                                                        !widget.prototypeVisualState,
                                                  ),
                                                ),
                                                for (final bug in _bugs)
                                                  Positioned(
                                                    left:
                                                        bug.x * _arenaWidth - 30,
                                                    top: widget.prototypeVisualState
                                                        ? _laneTop(
                                                            bug.lane,
                                                            _arenaHeight,
                                                          )
                                                        : bug.y * _arenaHeight -
                                                            30,
                                                    child: IgnorePointer(
                                                      child: SizedBox(
                                                        width: 60,
                                                        height: 60,
                                                        child: Stack(
                                                          alignment:
                                                              Alignment.topCenter,
                                                          clipBehavior: Clip.none,
                                                          children: [
                                                            if (!bug.popping &&
                                                                _bugDistanceToNest(
                                                                      bug,
                                                                    ) <
                                                                    (widget.prototypeVisualState
                                                                        ? 0.10
                                                                        : 0.16))
                                                              Positioned(
                                                                left: widget.prototypeVisualState
                                                                    ? 0
                                                                    : -3.3,
                                                                top: widget.prototypeVisualState
                                                                    ? 0
                                                                    : -3.3,
                                                                child: Transform.scale(
                                                                  scale: widget.prototypeVisualState
                                                                      ? 1.0
                                                                      : 1 +
                                                                          sin(
                                                                                _pulse.value *
                                                                                    pi,
                                                                              ) *
                                                                              0.07,
                                                                  child: Container(
                                                                    width: widget.prototypeVisualState
                                                                        ? 60
                                                                        : 66.6,
                                                                    height: widget.prototypeVisualState
                                                                        ? 60
                                                                        : 66.6,
                                                                    decoration: BoxDecoration(
                                                                      shape: BoxShape
                                                                          .circle,
                                                                      border: Border.all(
                                                                        color: const Color(
                                                                          0xFFE52E2E,
                                                                        ),
                                                                        width: 3,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            Positioned(
                                                              top: 6,
                                                              left: 6,
                                                              width: 48,
                                                              height: 48,
                                                              child: Transform.rotate(
                                                                angle: widget.prototypeVisualState
                                                                    ? 0.0
                                                                    : atan2(
                                                                            _nestCenterY -
                                                                                bug.y,
                                                                            _nestCenterX -
                                                                                bug.x,
                                                                          ) *
                                                                          0.18,
                                                                child: Transform.scale(
                                                                  alignment: Alignment
                                                                      .topCenter,
                                                                  scaleX:
                                                                      bug.popping &&
                                                                          !widget.prototypeVisualState
                                                                      ? 1.25
                                                                      : 1,
                                                                  scaleY:
                                                                      bug.popping &&
                                                                          !widget.prototypeVisualState
                                                                      ? 0.72
                                                                      : 1,
                                                                  child: Image.asset(
                                                                    'assets/bugs/tier${bug.tier.tier}_hd${bug.tier.tier == 5 ? '.webp' : '.png'}',
                                                                    width: 48,
                                                                    height: 48,
                                                                    fit: BoxFit
                                                                        .contain,
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
                                                  left: (_arenaWidth - 160) / 2,
                                                  top:
                                                      _arenaHeight * 0.47 -
                                                      95 +
                                                      10,
                                                  width: 160,
                                                  height: 190,
                                                  child: IgnorePointer(
                                                    child: Image.asset(
                                                      'assets/icons2/yuva-nest-prototype.png',
                                                      width: 160,
                                                      height: 190,
                                                    ),
                                                  ),
                                                ),
                                                if (_hitEffectActive &&
                                                    _hitEffectX != null &&
                                                    _hitEffectLane != null) ...[
                                                  Positioned(
                                                    left:
                                                        _hitEffectX! *
                                                            _arenaWidth -
                                                        12.26,
                                                    top:
                                                        (widget.prototypeVisualState
                                                            ? _laneTop(
                                                                _hitEffectLane!,
                                                                _arenaHeight,
                                                              )
                                                            : (_hitEffectY ??
                                                                      0.45) *
                                                                  _arenaHeight -
                                                                30) -
                                                        8.1,
                                                    child: IgnorePointer(
                                                      child: Image.asset(
                                                        'assets/icons2/boom.png',
                                                        width: 56,
                                                        height: 56,
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    left:
                                                        _hitEffectX! *
                                                            _arenaWidth -
                                                        12.86,
                                                    top:
                                                        (widget.prototypeVisualState
                                                            ? _laneTop(
                                                                _hitEffectLane!,
                                                                _arenaHeight,
                                                              )
                                                            : (_hitEffectY ??
                                                                      0.45) *
                                                                  _arenaHeight -
                                                                30) -
                                                        44.7,
                                                    width: 87.1,
                                                    height: 87.1,
                                                    child: IgnorePointer(
                                                      child: Center(
                                                        child: Transform.rotate(
                                                          angle: -24 * pi / 180,
                                                          child: Image.asset(
                                                            'assets/powerup_terlik.png',
                                                            width: 66,
                                                            height: 66,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                if (_ended)
                                                  Center(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            20,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.9,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            context.l10n.yuvaFellTitle,
                                                            style:
                                                                GoogleFonts.baloo2(
                                                                  fontSize: 23,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color: _ink,
                                                                ),
                                                          ),
                                                          Text(
                                                            context.l10n.yuvaResultScore(_score, _combo),
                                                            style:
                                                                GoogleFonts.nunito(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  color: _ink,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          FilledButton(
                                                            onPressed: _restart,
                                                            child: Text(
                                                              context.l10n.playAgainButton,
                                                            ),
                                                          ),
                                                        ],
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
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 80.9,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 66,
                              child: _BonusCard(
                                asset: 'assets/icons2/boot.png',
                                label: context.l10n.shopPowerDoubleSlipperNameCaps,
                                count:
                                    '${widget.prototypeVisualState ? 3 : _doubleSlipCount}',
                                onTap: _useDoubleSlipBonus,
                              ),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 66,
                              child: _BonusCard(
                                asset: 'assets/icons2/premium_token.png',
                                label: context.l10n.shopPowerGoldenSlipperNameCaps,
                                count:
                                    '${widget.prototypeVisualState ? 2 : _goldSlipCount}',
                                onTap: _useGoldSlipBonus,
                              ),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 66,
                              child: _BonusCard(
                                asset: 'assets/icons2/shield.png',
                                label: context.l10n.powerShieldCaps,
                                count:
                                    '${widget.prototypeVisualState ? 1 : _shieldCount}',
                                onTap: _useShieldBonus,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_paused && !_ended && !widget.prototypeVisualState)
                _pauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefenseArenaPainter extends CustomPainter {
  const _DefenseArenaPainter({
    required this.combo,
    required this.comboProgress,
    required this.hits,
    required this.misses,
    required this.hint,
    required this.comboBroken,
    required this.bursts,
    required this.hitsLabel,
    required this.missesLabel,
    this.showRadialRings = false,
  });

  final int combo;
  final double comboProgress;
  final int hits;
  final int misses;
  final String hint;
  // W66-3: kombo-bitiş durumu metinden değil, state'ten
  // gelen bu bayrakla okunur — dil bağımsızdır.
  final bool comboBroken;
  final List<_HitBurst> bursts;
  final String hitsLabel;
  final String missesLabel;
  final bool showRadialRings;

  @override
  void paint(Canvas canvas, Size size) {
    final lanePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 3;
    if (showRadialRings) {
      final nestCenter = Offset(size.width * 0.50, size.height * 0.45);
      final ringRadii = <double>[
        min(size.width, size.height) * 0.22,
        min(size.width, size.height) * 0.36,
        min(size.width, size.height) * 0.48,
      ];
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final r in ringRadii) {
        const dashCount = 28;
        const step = (2 * pi) / dashCount;
        for (var i = 0; i < dashCount; i++) {
          final startAngle = i * step;
          canvas.drawArc(
            Rect.fromCircle(center: nestCenter, radius: r),
            startAngle,
            step * 0.55,
            false,
            ringPaint,
          );
        }
      }
      final spokePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.11)
        ..strokeWidth = 1.5;
      for (var i = 0; i < 8; i++) {
        final angle = i * pi / 4;
        final inner = nestCenter + Offset(cos(angle), sin(angle)) * 68;
        final outer = nestCenter +
            Offset(cos(angle), sin(angle)) * (min(size.width, size.height) * 0.52);
        canvas.drawLine(inner, outer, spokePaint);
      }
    } else {
      for (var lane = 0;
          lane < _YuvaDefenseScreenState._laneTopFactors.length;
          lane++) {
        final centerY = _YuvaDefenseScreenState._laneCenterY(lane, size.height);
        for (var x = 8.0; x < size.width - 10; x += 9.5) {
          canvas.drawLine(
            Offset(x, centerY),
            Offset(min(x + 6, size.width - 10), centerY),
            lanePaint,
          );
        }
        final trailRect = switch (lane) {
          0 => Rect.fromLTWH(size.width * 0.04, centerY - 4, 70, 8),
          1 => Rect.fromLTWH(size.width * 0.95 - 64, centerY - 4, 64, 8),
          _ => Rect.fromLTWH(size.width * 0.14, centerY - 4, 60, 8),
        };
        final trailPaint = Paint()
          ..shader = LinearGradient(
            colors: lane == 1
                ? const [Color(0x33FFFFFF), Color(0x00FFFFFF)]
                : const [Color(0x00FFFFFF), Color(0x33FFFFFF)],
          ).createShader(trailRect);
        canvas.drawRRect(
          RRect.fromRectAndRadius(trailRect, const Radius.circular(4)),
          trailPaint,
        );
      }
    }
    for (final burst in bursts) {
      final life = burst.life.clamp(0.0, 1.0);
      final progress = 1.0 - life;
      final center = Offset(burst.x, burst.y);
      final radius = 8 + 30 * progress;
      final particlePaint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFE078),
          Colors.white,
          progress,
        )!.withValues(alpha: life);
      for (var i = 0; i < 8; i++) {
        final angle = i * pi / 4;
        canvas.drawCircle(
          center + Offset(cos(angle), sin(angle)) * radius,
          max(1.5, 4 * life).toDouble(),
          particlePaint,
        );
      }
      canvas.drawCircle(
        center,
        18 + 24 * progress,
        Paint()
          ..color = const Color(0xFFFFE078).withValues(alpha: life * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final label = comboBroken
        ? hint.toUpperCase()
        : (combo > 0 ? 'COMBO X$combo!' : 'YUVA SAVUNMASI · 360°');
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.bangers(
          fontSize: 23,
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
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 30);
    _paintAnimatedLabel(canvas, labelPainter, const Offset(12, 10));
    final hitLabel = TextPainter(
      text: TextSpan(
        text: hitsLabel,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final chipRect = Rect.fromLTWH(10, size.height - 52 - 30.6, 85, 30.6);
    final chipRRect = RRect.fromRectAndRadius(
      chipRect,
      const Radius.circular(999),
    );
    canvas.drawRRect(chipRRect, Paint()..color = const Color(0xE6080B12));
    canvas.drawRRect(
      chipRRect,
      Paint()
        ..color = const Color(0x8CFFB800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    hitLabel.paint(
      canvas,
      Offset(
        chipRect.left + 11,
        chipRect.top + (chipRect.height - hitLabel.height) / 2,
      ),
    );
    if (misses > 0) {
      final missLabel = TextPainter(
        text: TextSpan(
          text: missesLabel,
          style: GoogleFonts.bangers(
            fontSize: 21,
            height: 1,
            letterSpacing: 0.5,
            color: const Color(0xFFE52E2E),
            shadows: const [
              Shadow(color: Color(0xEB080B12), offset: Offset(0, 3)),
              Shadow(color: Color(0xE6FFD700), blurRadius: 14),
              Shadow(color: Color(0x8CFFD700), blurRadius: 32),
              Shadow(color: Color(0x52FFD700), blurRadius: 54),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - 16);
      _paintAnimatedLabel(
        canvas,
        missLabel,
        Offset(size.width - missLabel.width - 12, size.height - 52 - 24.5),
      );
    }
  }

  void _paintAnimatedLabel(Canvas canvas, TextPainter painter, Offset offset) {
    double sample(List<(double, double)> keyframes) {
      for (var index = 1; index < keyframes.length; index++) {
        final previous = keyframes[index - 1];
        final next = keyframes[index];
        if (comboProgress <= next.$1) {
          final progress =
              ((comboProgress - previous.$1) / (next.$1 - previous.$1)).clamp(
                0.0,
                1.0,
              );
          final eased = Curves.easeInOut.transform(progress);
          return previous.$2 + (next.$2 - previous.$2) * eased;
        }
      }
      return keyframes.last.$2;
    }

    final opacity = sample([(0, 0), (0.1, 1), (0.8, 1), (1, 0)]);
    final scale = sample([
      (0, 0.3),
      (0.1, 1.3),
      (0.17, 0.93),
      (0.24, 1.07),
      (0.31, 1),
      (0.42, 1.04),
      (0.53, 1),
      (0.64, 1.03),
      (1, 1.05),
    ]);
    final rotation =
        sample([
          (0, -3),
          (0.1, 2),
          (0.17, -1.2),
          (0.24, 1),
          (0.31, 0),
          (0.42, 0.7),
          (0.53, -0.7),
          (0.64, 0.5),
          (1, 0),
        ]) *
        pi /
        180;
    final translateY = sample([(0, 0), (0.8, 0), (1, -6)]);
    final center = offset + Offset(painter.width / 2, painter.height / 2);
    final bounds = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      painter.width,
      painter.height,
    ).inflate(56);
    canvas.saveLayer(
      bounds,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.translate(center.dx, center.dy + translateY);
    canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    painter.paint(canvas, offset);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DefenseArenaPainter oldDelegate) =>
      combo != oldDelegate.combo ||
      comboProgress != oldDelegate.comboProgress ||
      hits != oldDelegate.hits ||
      misses != oldDelegate.misses ||
      hint != oldDelegate.hint ||
      comboBroken != oldDelegate.comboBroken ||
      bursts != oldDelegate.bursts ||
      hitsLabel != oldDelegate.hitsLabel ||
      missesLabel != oldDelegate.missesLabel;
}

class _HudCard extends StatelessWidget {
  const _HudCard({
    required this.label,
    required this.value,
    this.singleRowHearts = false,
  });

  final String label;
  final String value;
  final bool singleRowHearts;

  @override
  Widget build(BuildContext context) => Container(
    height: label == context.l10n.livesLabel && !singleRowHearts ? 71.5 : 50.5,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xD9080B12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0x73FFB800)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            height: 1,
            letterSpacing: 1,
            fontWeight: FontWeight.w900,
            color: _YuvaDefenseScreenState._gold,
          ),
        ),
        SizedBox(height: label == context.l10n.livesLabel && singleRowHearts ? 4 : 5),
        if (label == context.l10n.livesLabel && singleRowHearts)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4.2),
                Opacity(
                  opacity: i < (int.tryParse(value) ?? 0) ? 1 : 0.25,
                  child: Image.asset(
                    'assets/icons/health.png',
                    width: 20,
                    height: 20,
                  ),
                ),
              ],
            ],
          )
        else if (label == context.l10n.livesLabel)
          Wrap(
            spacing: 4,
            runSpacing: 1,
            children: [
              for (var i = 0; i < 3; i++)
                Image.asset(
                  'assets/icons/health.png',
                  width: 20,
                  height: 20,
                  color: i < (int.tryParse(value) ?? 0) ? null : Colors.white24,
                ),
            ],
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.baloo2(
                fontSize: 21,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
      ],
    ),
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFF4A9DDB),
    this.circular = false,
    this.asset,
    this.text,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final bool circular;
  final String? asset;
  final String? text;

  /// Ekran okuyucu etiketi (örn. 'Geri', 'Nasıl oynanır'); `null` ise
  /// `Semantics` sarması eklenmez (arcade_chrome'daki _ChromeRound deseni).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 400;
    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: circular ? 48 : (wide ? 42.9 : 37),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: circular ? const Color(0xDB080B12) : const Color(0xD9080B12),
          borderRadius: BorderRadius.circular(circular ? 99 : 14),
        border: circular
            ? Border.all(color: const Color(0xB3FFB800), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: asset != null
          ? Image.asset(asset!, width: 29, height: 29, fit: BoxFit.contain)
          : text != null
          ? Text(
              text!,
              style: GoogleFonts.baloo2(
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            )
          : Icon(icon, size: 20, color: color),
      ),
    );
    final label = semanticLabel;
    if (label != null) {
      button = Semantics(
        button: true,
        label: label,
        child: button,
      );
    }
    return button;
  }
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({
    required this.asset,
    required this.label,
    required this.count,
    this.onTap,
  });

  final String asset;
  final String label;
  final String count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final countValue = int.tryParse(count) ?? 0;
    return Semantics(
      button: true,
      enabled: countValue > 0 && onTap != null,
      label: context.l10n.boosterCountLabel(label, countValue),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
      children: [
      Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 66,
            height: 50,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
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
                    BoxShadow(color: Color(0x73000000), offset: Offset(0, 3)),
                    BoxShadow(
                      color: Color(0x4D000000),
                      offset: Offset(0, 6),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Image.asset(
                  asset,
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF4779A8),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -2,
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
                count,
                style: GoogleFonts.baloo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      SizedBox(
        height: 9.9,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _YuvaStatusIndicatorsPainter extends CustomPainter {
  const _YuvaStatusIndicatorsPainter();

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
  bool shouldRepaint(_YuvaStatusIndicatorsPainter oldDelegate) => false;
}
