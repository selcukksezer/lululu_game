import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/daily_challenge_service.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/global_notify.dart';
import '../services/haptic_service.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/mode_bonus_bar.dart';

/// Viral “Scream” runner — spam zıplatır; skor yalnız kapı geçişinden gelir.
class ScreamRoachScreen extends StatefulWidget {
  const ScreamRoachScreen({
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
  State<ScreamRoachScreen> createState() => _ScreamRoachScreenState();
}

class _ScreamRoachScreenState extends State<ScreamRoachScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _bugSize = 48.0;
  static const _bugRenderHeight = 56.0;
  static const _gateW = 58.0;
  static const _grassH = 32.0;
  static const _screamCooldown = Duration(milliseconds: 55);
  static const _startGrace = 1.35;
  static const _groundGrace = 1.55;
  static const _gravity = 1350.0;
  static const _flapImpulse = -430.0;
  static const _tutorialSeconds = 15.0;
  static const _voiceThresholdDb = 64.0;

  late final Ticker _ticker;
  final NoiseMeter _noiseMeter = NoiseMeter();
  Duration _last = Duration.zero;
  StreamSubscription<NoiseReading>? _noiseSubscription;

  /// Mikrofon aboneliği duraklatma/arka plan nedeniyle askıda mı?
  /// `pause()`/`resume()` çağrıları bu bayrakla tekilleştirilir
  /// (çift `pause` çift `resume` ister; sayaç kaymasın).
  bool _noisePaused = false;

  double _x = 28;
  double _y = 220;
  double _vy = 0;
  double _power = 0;
  int _score = 0;
  int _best = 0;
  int _screamStreak = 0;
  int _maxScreamStreak = 0;
  int _gatesPassed = 0;
  bool _alive = true;
  // S1#48: ölüm anı — ölüm sonrası ilk 500 ms içindeki dokunuş
  // yeniden başlatmaz.
  DateTime? _diedAt;
  bool _resultShown = false;

  /// Tur kimliği (Terlik deseni): her `_restart` artırır; eski turun
  /// bekleyen `_presentResult` çağrısı kimlik tutmazsa sonuç göstermez.
  int _runId = 0;

  // Y3: tur başlangıç damgası — tur başına tek `finishRun` anahtarı
  // ('<mod>:<damga>') bu damgadan üretilir. İlk turda State
  // kuruluşunda, sonraki turlarda `_restart`'ta yakalanır; BİTİR +
  // can-bitiş yolları aynı anahtarı paylaşır, bitiş-anı
  // `DateTime.now()` kullanılmaz.
  int _runStartStamp = DateTime.now().microsecondsSinceEpoch;

  String get _runIdempotencyKey =>
      '${LeaderboardService.modeScream}:$_runStartStamp';

  /// Hamle bayrağı (enerji iadesi): oturum boyunca ilk zıplama
  /// (`_scream`, dokunuş veya ses) veya tur tamamlanması (`_die`)
  /// ile `true` olur; TEKRAR/yeniden başlatmada SIFIRLANMAZ (Suika
  /// `_dropsMade` deseni — oturum ömrü).
  bool _moveMade = false;

  /// Çift-iade koruması: iade bu oturumda en fazla bir kez yapılır.
  bool _energyRefunded = false;

  /// Çıkış-sonrası iade bildirimi (S6): `PopScope` `didPop` anında
  /// bağlam artık ağaçta değildir; bildirim metni her `build`'de
  /// ÖNCEDEN yakalanır ve iade gerçekten verildiğinde paylaşılan
  /// `GlobalNotify` üzerinden çıkış yapılan ekranın üstünde
  /// gösterilir (balon/stack deseninin paylaşılan karşılığı).
  String? _refundNotice;

  // Duraklatma (madde 37): Osmantuş deseni — arka planda ticker durur,
  // elle duraklatmada da aynı ticker durdurulur; nitro gibi duvar-saati
  // süreleri duraklatma süresi kadar ötelenir.
  bool _paused = false;
  bool _pausedByLifecycle = false;
  DateTime? _pauseStartedAt;
  bool _layoutReady = false;
  bool _layoutBootstrapping = false;
  double _groundIdle = 0;
  double _aliveFor = 0;
  String _hint = '';
  bool _hintSeeded = false;
  String _scorePopup = '';
  late final Random _rng;
  final List<_Gate> _gates = [];
  double _world = 0;
  InsectTier _bug = InsectTier.helmet;
  String _callout = '';
  DateTime _lastScreamAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Voice lock: no new SFX / no character swap until clip ends.
  bool _voiceBusy = false;
  bool _voiceInputEnabled = false;
  bool _voiceToggling = false;
  bool _voiceArmed = true;
  bool _prototypeInitialized = false;
  DateTime _lastVoiceTrigger = DateTime.fromMillisecondsSinceEpoch(0);
  late final double _gateSpacing;
  double _floorY = 420;
  double _ceilY = 72;
  double _arenaW = 320;
  double _arenaH = 480;

  bool _shield = false;
  bool _hop = false;
  DateTime? _nitroUntil;

  bool get _nitro =>
      _nitroUntil != null && DateTime.now().isBefore(_nitroUntil!);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hintSeeded) {
      _hintSeeded = true;
      _hint = context.l10n.screamHintIdle;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // KASITLI günlük tohum: aynı takvim gününde aynı başlangıç kapı
    // düzeni ve kapı aralığı üretilir (günlük meydan okuma tutarlılığı;
    // Terlik Tap'teki aynı desenle paralel). _rng initState'te bir kez
    // kurulur ve tur içinde ilerler; _restart tohumu yenilemez, o
    // yüzden aynı gündeki sonraki turlar dizinin devamını kullanır,
    // birebir tekrar etmez. Tohumsuz Random() bilinçli yapılmadı.
    final day = DateTime.now();
    final seed = day.year * 10000 + day.month * 100 + day.day;
    _rng = Random(seed ^ 0x5C12);
    _gateSpacing = 250 + (seed % 40).toDouble();
    AudioManager().initialize();
    unawaited(ProgressManager().load());
    _ticker = createTicker(_onTick)..start();
    _loadBest();
  }

  @visibleForTesting
  bool get isTutorialActive => _aliveFor < _tutorialSeconds;

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    await DailyChallengeService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _best = LeaderboardService.instance.getBest(
        LeaderboardService.modeScream,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioManager().stopAll();
    _noiseSubscription?.cancel();
    _ticker.dispose();
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
        // Mikrofon arka planda dinlemesin: abonelik askıya alınır,
        // dönüşte (elle duraklatma yoksa) kaldığı yerden devam eder.
        _pauseNoiseSubscription();
        // Osmantuş deseni: arka planda ticker dursun; dönüşte _last
        // sıfırlanır, dt kısması da ikinci korumadır.
        if (_ticker.isActive) {
          _ticker.stop();
          _pausedByLifecycle = true;
          _pauseStartedAt ??= DateTime.now();
        }
        break;
      case AppLifecycleState.resumed:
        // Elle duraklatılmışsa mikrofon kapalı kalsın; devam
        // düğmesi (_togglePause) açar.
        if (!_paused) _resumeNoiseSubscription();
        // Elle duraklatılmışsa dönüşte kendiliğinden başlamasın.
        if (_pausedByLifecycle && !_paused) {
          _pausedByLifecycle = false;
          _shiftPauseDeadlines();
          _last = Duration.zero;
          if (_alive && !_ticker.isActive) _ticker.start();
        }
        break;
    }
  }

  /// Duraklatma süresince duvar-saati süreleri (nitro) işlemesin.
  void _shiftPauseDeadlines() {
    final started = _pauseStartedAt;
    _pauseStartedAt = null;
    if (started == null) return;
    final pausedFor = DateTime.now().difference(started);
    if (pausedFor <= Duration.zero) return;
    if (_nitroUntil != null) _nitroUntil = _nitroUntil!.add(pausedFor);
  }

  /// Mikrofon aboneliğini askıya al (tekilleştirilmiş: çift `pause`
  /// çağrısı aboneliği kalıcı askıda bırakmasın).
  void _pauseNoiseSubscription() {
    if (_noisePaused) return;
    _noisePaused = true;
    _noiseSubscription?.pause();
  }

  /// Askıdaki mikrofon aboneliğini devam ettir (tekilleştirilmiş).
  void _resumeNoiseSubscription() {
    if (!_noisePaused) return;
    _noisePaused = false;
    _noiseSubscription?.resume();
  }

  /// Elle duraklatma / devam (madde 37): ticker durur, fizik ve kapılar donar.
  void _togglePause() {
    if (widget.prototypeVisualState || !_alive) return;
    if (_paused) {
      _paused = false;
      _pausedByLifecycle = false;
      _shiftPauseDeadlines();
      _last = Duration.zero;
      _resumeNoiseSubscription();
      if (!_ticker.isActive) _ticker.start();
    } else {
      _paused = true;
      _pauseStartedAt ??= DateTime.now();
      _pauseNoiseSubscription();
      _ticker.stop();
    }
    setState(() {});
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
        _x = 28;
        _y = _ceilY + (_floorY - _ceilY - _bugSize) * 0.52;
        _vy = 0;
        _gates.clear();
        _spawnGate(initial: true);
        if (widget.prototypeVisualState && !_prototypeInitialized) {
          _prototypeInitialized = true;
          _aliveFor = 18;
          _score = 1320;
          _best = max(_best, 2105);
          _gatesPassed = 7;
          _screamStreak = 7;
          _maxScreamStreak = 7;
          _power = 0.7;
          _bug = InsectTier.kongo;
          _callout = context.l10n.screamGatePrototype;
          _scorePopup = '+50 X7';
          _x = 24;
          _y = _arenaH * 0.30 - 3;
          _gates.first
            ..base = _world + _arenaW * 0.56
            ..x = _arenaW * 0.56
            ..gapCenter = _arenaH * 0.49
            ..gapHalf = _arenaH * 0.15;
        }
      });
    });
  }

  void _onTick(Duration elapsed) {
    if (widget.prototypeVisualState || !_alive || !_layoutReady || _paused) {
      return;
    }
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

    final tutorial = _aliveFor < _tutorialSeconds;
    final ramp = ((_aliveFor - _tutorialSeconds) / 45).clamp(0.0, 1.0);
    // Keep the opening generous; increase gate speed only after the tutorial.
    final scroll = (tutorial ? 72 : 104 + 86 * ramp) * (_nitro ? 1.35 : 1);
    _world += scroll * dt;

    // A fixed gravity and impulse make each tap predictable, like Flappy.
    // Before the player's first tap (up to 3.5s), hover smoothly at gap height.
    if (_screamStreak == 0 && _aliveFor < 3.5) {
      final gapCenter = _gates.isNotEmpty
          ? _gates.first.gapCenter
          : _arenaH * 0.45;
      _vy = 0;
      _y = (gapCenter - _bugRenderHeight * 0.5 + sin(_aliveFor * 4.2) * 6.0)
          .clamp(_ceilY, _floorY - _grassH - _bugRenderHeight);
    } else {
      _vy += _gravity * dt;
      _y += _vy * dt;
    }

    final floorBug = max(_ceilY, _floorY - _grassH * 0.35 - _bugRenderHeight);
    if (_y >= floorBug) {
      _y = floorBug;
      if (_vy > 0) _vy = 0;
      _groundIdle += dt;
      // Başlangıç grace + çimde kısa dinlenme OK; uzun uyku = ölüm.
      if (_aliveFor > _startGrace &&
          _groundIdle > _groundGrace &&
          _power < 0.12) {
        _die(context.l10n.screamIdleGround);
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

    final bugRect = Rect.fromLTWH(_x, _y, _bugSize, _bugSize).deflate(7);
    for (final g in _gates) {
      if (_aliveFor > _startGrace && _hitGate(bugRect, g)) {
        if (_hop) {
          _hop = false;
          continue;
        }
        _die(
          context.l10n.screamDeathLine(
            g.kind.deathLineFor(context.l10n),
            _gatesPassed,
          ),
        );
        return;
      }
      if (!g.scored && g.x + _gateW < _x) {
        g.scored = true;
        _gatesPassed++;
        final gain = 10 + _screamStreak * 5 + (_nitro ? 25 : 0);
        _score += gain;
        _callout = context.l10n.screamGateStreak(_screamStreak);
        _scorePopup = '+$gain X$_screamStreak';
        unawaited(HapticService.instance.lightImpact());
        _hint = '${g.kind.passLineFor(context.l10n)} · spam x$_screamStreak';
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
    final tutorial = _aliveFor < _tutorialSeconds;
    final ramp = ((_aliveFor - _tutorialSeconds) / 45).clamp(0.0, 1.0);
    final gapHalf = tutorial ? 96.0 : 88.0 - ramp * 18;
    final minC = _ceilY + gapHalf + 24;
    final maxC = _floorY - _grassH - gapHalf - 18;
    final center = minC >= maxC
        ? (_ceilY + _floorY) * 0.5
        : minC + _rng.nextDouble() * (maxC - minC);

    final double base;
    if (_gates.isEmpty) {
      base = _world + _arenaW * 0.56 + (initial ? 10 : 0);
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
      _Gate(base: base, gapCenter: center, gapHalf: gapHalf, kind: kind),
    );
  }

  void _die([String? reason]) {
    if (!_alive) return;
    if (_shield) {
      _shield = false;
      _vy = -280;
      _hint = context.l10n.screamShieldSaved;
      setState(() {});
      return;
    }
    _alive = false;
    _diedAt = DateTime.now();
    // Tur tamamlandı: iade hakkı biter (dokunmadan uyuyup ölen tur
    // da turdur; bayrak oturum ömründe kalır).
    _moveMade = true;
    _screamStreak = 0;
    _hint =
        reason ??
        context.l10n.screamCrushedHint(_gatesPassed, _maxScreamStreak);
    unawaited(HapticService.instance.heavyImpact());
    unawaited(AudioManager().playLose());
    unawaited(
      LeaderboardService.instance.submitScore(
        LeaderboardService.modeScream,
        _score,
      ),
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
    if (_paused) return;
    if (!_alive) {
      // S1#48: ölüm sonrası 500 ms dokunuş yoksayma.
      if (_diedAt != null &&
          DateTime.now().difference(_diedAt!) <
              const Duration(milliseconds: 500)) {
        return;
      }
      _restart();
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastScreamAt) < _screamCooldown) return;
    _lastScreamAt = now;

    // Jump / power every tap — voice + character are gated separately.
    // Enerji iadesi sayacı: zıplama anında sayılır (Suika deseni).
    _moveMade = true;
    _screamStreak++;
    if (_screamStreak > _maxScreamStreak) _maxScreamStreak = _screamStreak;
    _groundIdle = 0;
    _power = (_power + 0.28).clamp(0.0, 1.0);
    _vy = _flapImpulse;
    unawaited(HapticService.instance.selectionClick());
    _hint =
        '${_callout.isEmpty ? _bug.viralReplik : _callout} · spam x$_screamStreak';

    if (_voiceBusy || AudioManager().isExclusivePlaying) {
      setState(() {});
      return;
    }

    _voiceBusy = true;
    _callout = _bug.viralReplik;
    _hint = '$_callout · spam x$_screamStreak';
    final pitch = 0.88 + _rng.nextDouble() * 0.32;
    unawaited(() async {
      final started = await AudioManager().playScreamRoach(
        bug: _bug,
        power: _power,
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

  Future<void> _toggleVoiceInput() async {
    // Çift-dokunma yarışı: izin beklerken ikinci dokunma ikinci
    // listen() açmasın, ilki sızmasın.
    if (_voiceToggling) return;
    _voiceToggling = true;
    try {
      if (_voiceInputEnabled) {
        await _noiseSubscription?.cancel();
        _noiseSubscription = null;
        _noisePaused = false;
        if (mounted) setState(() => _voiceInputEnabled = false);
        return;
      }

      final permission = await Permission.microphone.request();
      if (!permission.isGranted) {
        if (mounted) {
          setState(() {
            _hint = permission.isPermanentlyDenied
                ? context.l10n.screamMicPermissionSettings
                : context.l10n.screamMicDeniedHint;
          });
        }
        return;
      }

      try {
        _noiseSubscription = _noiseMeter.noise.listen(
          _onNoiseReading,
          onError: (Object _) {
            if (mounted) setState(() => _voiceInputEnabled = false);
            _noiseSubscription?.cancel();
            _noiseSubscription = null;
            _noisePaused = false;
          },
          cancelOnError: true,
        );
        _noisePaused = false;
        if (mounted) setState(() => _voiceInputEnabled = true);
      } catch (_) {
        _noisePaused = false;
        if (mounted) setState(() => _voiceInputEnabled = false);
      }
    } finally {
      _voiceToggling = false;
    }
  }

  void _onNoiseReading(NoiseReading reading) {
    // Duraklatmada ve arka planda ses zıplatmasın (abonelik askısı
    // birinci koruma; bu kontrol kuyrukta kalmış okumalar için).
    if (!mounted || !_alive || _paused || _pausedByLifecycle) return;
    final level = reading.meanDecibel;
    if (level < _voiceThresholdDb - 8) _voiceArmed = true;
    if (level < _voiceThresholdDb || !_voiceArmed) return;
    final now = DateTime.now();
    if (now.difference(_lastVoiceTrigger).inMilliseconds < 220) return;
    _lastVoiceTrigger = now;
    _voiceArmed = false;
    _scream();
  }

  void _restart() {
    unawaited(AudioManager().stopAll());
    // Yeni tur kimliği: eski turun bekleyen sonuç çağrısı gösterilmez.
    _runId++;
    // Y3: yeni tur, yeni idempotency anahtarı — damga tur
    // başlangıcında bir kez yakalanır.
    _runStartStamp = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _alive = true;
      _diedAt = null;
      _paused = false;
      _pausedByLifecycle = false;
      _pauseStartedAt = null;
      _resultShown = false;
      _shield = false;
      _hop = false;
      _nitroUntil = null;
      _layoutReady = _arenaW > 0 && _arenaH > 0;
      _score = 0;
      _gatesPassed = 0;
      _world = 0;
      _x = 28;
      _y = _ceilY + (_floorY - _ceilY - _bugSize) * 0.52;
      _vy = 0;
      _power = 0;
      _screamStreak = 0;
      _maxScreamStreak = 0;
      _groundIdle = 0;
      _aliveFor = 0;
      _gates.clear();
      _bug = InsectTier.helmet;
      _callout = '';
      _scorePopup = '';
      _voiceBusy = false;
      _voiceArmed = true;
      _hint = context.l10n.screamHintIdle;
      _last = Duration.zero;
      if (_layoutReady) _spawnGate(initial: true);
    });
    // Duraklatılmışken yeniden başlatılırsa ticker dursun kalmasın.
    // BİTİR ile dondurulan mikrofon da devam etsin: _finishEarly
    // aboneliği askıya almıştı, TEKRAR OYNA sonrası ses girişi
    // ölü kalmasın (askıda değilse no-op).
    _resumeNoiseSubscription();
    if (!_ticker.isActive) _ticker.start();
  }

  /// Oyun sonu: yeni sonuç ekranı. "TEKRAR OYNA" yeni turu başlatır,
  /// "ANA SAYFA"da eski sonuç akışı devam eder (bozulmadı).
  bool _useJump() {
    if (!_alive || _paused) return false;
    AudioManager().triggerMediumHaptic();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _vy = -520;
      _hop = true;
      _callout = context.l10n.screamMegaJumpCallout;
      _hint = context.l10n.screamMegaJumpHint;
    });
    return true;
  }

  bool _useShield() {
    if (!_alive || _paused || _shield) return false;
    AudioManager().triggerMediumHaptic();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _shield = true;
      _callout = context.l10n.screamShieldBalloonCallout;
      _hint = context.l10n.screamShieldBalloonHint;
    });
    return true;
  }

  bool _useNitro() {
    if (!_alive || _paused) return false;
    AudioManager().triggerMediumHaptic();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _nitroUntil = DateTime.now().add(const Duration(seconds: 8));
      _power = 1;
      _callout = context.l10n.screamNitroCallout;
      _hint = context.l10n.screamNitroHint;
    });
    return true;
  }

  Future<void> _presentResult(int runId, {bool? won}) async {
    // Tur değiştiyse (yeniden başlatma araya girdiyse) eski turun
    // sonucunu gösterme ve yeni turun ödülüne dokunma (Terlik deseni).
    // Yeni turun bayrağına dokunulmaz: `_restart` zaten temizledi.
    if (runId != _runId) return;
    if (!mounted) return;
    // S1#49: ödeme + liderlik + görev kaydı + sonuç ekranı finishRun()
    // üzerinden (tek-ödeme korunur). Doğal bitiş böceğin düşmesidir
    // (kayıp); `won` verilmezse kayıp başlığı gösterilir.
    try {
      final replay = await finishRun(
        context,
        score: _score,
        best: _best,
        won: won ?? false,
        leaderboardMode: LeaderboardService.modeScream,
        // K16: mod skoru kimliği `bestScoreKey` ile aynıdır
        // ('scream_roach'); Y3: anahtar tur başlangıç damgalıdır.
        modeScoreId: LeaderboardService.modeScream,
        idempotencyKey: _runIdempotencyKey,
        stillValid: () => mounted && runId == _runId,
      );
      if (runId != _runId) return;
      if (!mounted) return;
      if (!replay) {
        // İade kontrolü bayrağı temiz görsün (önceki sıra korunur).
        _resultShown = false;
        Navigator.of(context).maybePop();
        return;
      }
      _restart();
    } finally {
      // Aynı turdaysa bayrağı temizle ki hata/iptal sonrası BİTİR
      // yeniden denensin; yeni tur başladıysa onun bayrağına dokunma
      // (`_restart` temizledi, `_finishEarly` yeniden kurmuş olabilir).
      if (runId == _runId) _resultShown = false;
    }
  }

  /// Hamlesiz-çıkış enerji iadesi (tek çıkış noktası: `PopScope`).
  ///
  /// Yalnız giriş enerjisi tüketildiyse, tur tamamlanmadıysa ve oturum
  /// boyunca hiç hamle yapılmadıysa 1 enerji iade edilir. `dispose`
  /// içinde DEĞİL, yalnızca gerçek rota çıkışında (`didPop`) çağrılır.
  ///
  /// S6: iade bildirimi `GlobalNotify` üzerinden gösterilir —
  /// metin `build`'de önceden yakalanır (`didPop` anında görünür
  /// bağlam yoktur); iki geri düğmesi de yalnızca pop yapar, iade
  /// çağrısı taşımaz.
  void _maybeRefundEnergy() {
    if (_energyRefunded) return;
    if (!widget.energyConsumed || _moveMade || !_alive || _resultShown) {
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

  /// BİTİR: turu sessizce silmek yerine sonuç ekranını açar
  /// (playtest bulgu #10). Erken bitirmede başlık skora göre
  /// belirlenir (skor 0 ise kayıp başlığı).
  Future<void> _finishEarly() async {
    if (_resultShown) return;
    _resultShown = true;
    // Turu dondur: ticker durur, `_paused` girişleri (`_scream`,
    // bonuslar, mikrofon) kilitler. TEKRAR OYNA `_restart` ile
    // devam ettirir; hata çıkarsa duraklatma kaplamasından DEVAM
    // ile kaldığı yerden dönülür.
    _paused = true;
    _pauseStartedAt ??= DateTime.now();
    _pauseNoiseSubscription();
    _ticker.stop();
    if (mounted) setState(() {});
    await _presentResult(_runId, won: _score > 0);
  }

  void _edgeShowResult() {
    if (_resultShown) return;
    _resultShown = true;
    final runId = _runId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _presentResult(runId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // S6: iade bildirimi metni çıkıştan ÖNCE yakalanır
    // (`didPop` anında bağlam ağaçta değildir).
    _refundNotice = context.l10n.energyRefundNotice;
    if (!_alive && !_resultShown) _edgeShowResult();
    final wideScreen = MediaQuery.sizeOf(context).width >= 400;
    final hasShellStatusBar = MediaQuery.paddingOf(context).top > 0;
    final bonuses = [
      stockBonusWithResult(
        id: 'jump',
        label: context.l10n.powerJumpCaps,
        asset: 'assets/icons2/boot.png',
        effect: () {
          final applied = _useJump();
          setState(() {});
          return applied;
        },
      ),
      stockBonusWithResult(
        id: 'shield',
        label: context.l10n.powerShieldCaps,
        asset: 'assets/icons2/shield.png',
        effect: () {
          final applied = _useShield();
          setState(() {});
          return applied;
        },
      ),
      stockBonusWithResult(
        id: 'nitro',
        label: context.l10n.shopPowerNitroNameCaps,
        asset: 'assets/icons2/potion_speed.png',
        effect: () {
          final applied = _useNitro();
          setState(() {});
          return applied;
        },
      ),
    ];

    final stageChild = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _scream(),
      child: LayoutBuilder(
        builder: (context, box) {
          final playfieldHeight = max(240.0, box.maxHeight - 63);
          _applyLayout(box.maxWidth, playfieldHeight);
          final bugTop = widget.prototypeVisualState && wideScreen
              ? playfieldHeight * 0.35 + 8.8
              : _y;
          return Column(
            children: [
              Expanded(
                child: ClipRect(
                  child: LayoutBuilder(
                    builder: (context, playfield) => Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: wideScreen
                                ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0, 0.55, 1],
                                    colors: [
                                      Color(0x4D462478),
                                      Color(0x2E18123A),
                                      Color(0x4D0A2016),
                                    ],
                                  )
                                : const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: [0, 0.94, 0.945, 1],
                                    colors: [
                                      Color(0x803C4385),
                                      Color(0x801E4155),
                                      Color(0x8C1E4030),
                                      Color(0x8C1E4030),
                                    ],
                                  ),
                          ),
                        ),
                        if (!wideScreen)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: playfield.maxHeight * 0.94,
                            height: 3,
                            child: ColoredBox(color: const Color(0x40FFFFFF)),
                          ),
                        if (widget.prototypeVisualState && wideScreen)
                          Positioned(
                            left: 184.6,
                            top: 0,
                            width: 153.4,
                            height: playfield.maxHeight,
                            child: Image.asset(
                              'assets/obstacles/obstacle-pipes.webp',
                              fit: BoxFit.fill,
                            ),
                          )
                        else
                          for (final g in _gates) ..._buildGate(g),
                        if (widget.prototypeVisualState) ...[
                          Positioned(
                            left: 0,
                            bottom: 0,
                            width: playfield.maxWidth * 0.54,
                            height: 42,
                            child: Image.asset(
                              'assets/obstacles/obstacle-spikes.webp',
                              fit: BoxFit.cover,
                              alignment: Alignment.bottomCenter,
                            ),
                          ),
                          Positioned(
                            right: 2,
                            bottom: 0,
                            width: 106,
                            child: Image.asset(
                              'assets/obstacles/obstacle-bush.webp',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ] else
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 14,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF2CC84D),
                                    Color(0xFF0E6822),
                                  ],
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0xFF8CFF9E),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (widget.prototypeVisualState) ...[
                          Positioned(
                            left: wideScreen ? 61.6 : 44,
                            top: wideScreen
                                ? 209.5
                                : playfield.maxHeight * 0.30,
                            width: wideScreen ? 56.8 : 92,
                            height: wideScreen ? 56.8 : 92,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xBF00C853),
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: wideScreen ? 63.3 : 58,
                            top: wideScreen
                                ? 206.5
                                : playfield.maxHeight * 0.33,
                            width: wideScreen ? 53.4 : 64,
                            height: wideScreen ? 53.4 : 64,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xBF00C853),
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ] else if (_power > 0.15)
                          Positioned(
                            left: _x + 12,
                            top: bugTop + 4,
                            width: 44 + _power * 16,
                            height: 44 + _power * 16,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0x9900C853),
                                    width: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_callout.isNotEmpty)
                          Positioned(
                            left: 12,
                            top: wideScreen ? 10 : 8,
                            child: Text(
                              _callout,
                              style: GoogleFonts.bangers(
                                fontSize: 22,
                                height: 1,
                                letterSpacing: 0.4,
                                color: const Color(0xFFFFB800),
                                shadows: const [
                                  Shadow(
                                    color: Color(0xCC000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_scorePopup.isNotEmpty)
                          Positioned(
                            left: wideScreen ? 126 : playfield.maxWidth * 0.37,
                            top: wideScreen
                                ? playfield.maxHeight * 0.58
                                : playfield.maxHeight * 0.57,
                            child: Text(
                              _scorePopup,
                              style: GoogleFonts.bangers(
                                fontSize: wideScreen ? 24 : 22,
                                height: 1,
                                color: const Color(0xFFFFB800),
                                shadows: const [
                                  Shadow(
                                    color: Color(0xCC000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          left: 12,
                          bottom: wideScreen ? 54 : 58,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 30),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xE6080B12),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: const Color(0x8CFFB800),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              context.l10n.screamNextGate(_gatesPassed + 1),
                              style:
                                  (wideScreen
                                  ? GoogleFonts.nunito
                                  : GoogleFonts.exo2)(
                                    fontSize: 12,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                        ),
                        if (!widget.prototypeVisualState && (_shield || _nitro))
                          Positioned(
                            left: _x - 6,
                            top: bugTop - 6,
                            width: 64,
                            height: 64,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _shield
                                        ? const Color(0xCC38BDF8)
                                        : const Color(0xCCFFB800),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _shield
                                          ? const Color(0x6638BDF8)
                                          : const Color(0x66FFB800),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: _x,
                          top: bugTop,
                          child: Transform.rotate(
                            angle: widget.prototypeVisualState
                                ? (wideScreen ? 0.052 : -0.087)
                                : (_vy.clamp(-400, 400)) / 600,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 90),
                              child: Image.asset(
                                key: ValueKey(_bug),
                                'assets/bugs/tier${_bug.tier}_hd${_bug.tier == 5 ? '.webp' : '.png'}',
                                width: widget.prototypeVisualState ? 98 : 50,
                                height: widget.prototypeVisualState ? null : 54,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        if (!widget.prototypeVisualState)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                tooltip: _voiceInputEnabled
                                    ? context.l10n.screamMicOffLabel
                                    : context.l10n.screamMicOnLabel,
                                onPressed: _toggleVoiceInput,
                                icon: Icon(
                                  _voiceInputEnabled
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  size: 22,
                                  color: _voiceInputEnabled
                                      ? const Color(0xFF00C853)
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        // Dar ekranda başlık satırına düğme sığmadığı için
                        // duraklatma düğmesi sahnede, mikrofonun yanındadır
                        // (madde 37). Geniş ekranda başlık satırındadır.
                        if (!widget.prototypeVisualState && !wideScreen)
                          Positioned(
                            right: 56,
                            top: 4,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton(
                                tooltip: context.l10n.pause,
                                onPressed: _togglePause,
                                icon: const Icon(
                                  Icons.pause_rounded,
                                  size: 22,
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
              Container(
                height: 63,
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x17FFFFFF))),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: wideScreen ? 17 : 13,
                      child: Row(
                        children: [
                          // Sol etiket içerik genişliğinde kalır; sağdaki
                          // yüzde/ipucu metni kalan genişliği alır, yoksa
                          // "İLK 15 SN YAVAŞ" kesiliyordu (bulgu #6).
                          Flexible(
                            flex: 0,
                            child: Text(
                              context.l10n.screamVoicePower,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                height: 1,
                                letterSpacing: 0.77,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF9AA7BC),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _voiceInputEnabled || _power >= 0.7
                                  ? context.l10n.screamShoutingPercent(
                                      (_power * 100).round(),
                                    )
                                  : '${context.l10n.screamTapPercent((_power * 100).round())}${isTutorialActive ? context.l10n.screamSlowStart : ''}',
                              maxLines: 1,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                height: 1,
                                letterSpacing: 0.77,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF9AA7BC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const Positioned.fill(
                              child: ColoredBox(color: Color(0x24FFFFFF)),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: widget.prototypeVisualState
                                    ? 0.7
                                    : _power,
                                heightFactor: 1,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF00C853),
                                        Color(0xFFFFD700),
                                        Color(0xFFFF6B35),
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
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Canlı _hint'in erişilebilirlik etiketi (Terlik deseni): F4'ten
    // beri yardım sayfası kural metnini gösteriyor; _hint artık
    // burada okunur, oyun-içi atamalar aynen durur.
    final labeledStageChild = Semantics(label: _hint, child: stageChild);

    if (!wideScreen) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _maybeRefundEnergy();
        },
        child: ArcadeScreen(
          backgroundAsset: 'assets/scream_sky.webp',
          title: context.l10n.screamBugTitle,
          score: _score,
          best: _best,
          // F4: dar düzende '?' sayfası bu `hint` metnini gösterir
          // (ArcadeScreen'in ayrı kural-gövdesi parametresi yok;
          // `hintLabel` verilmediği için şerit çizilmez, oyun-içi
          // canlı _hint gösterimi etkilenmez). Kural metni verilir.
          hint: context.l10n.screamHowToBody,
          statLabel: context.l10n.screamGateStat,
          statValue: '$_gatesPassed',
          tag: context.l10n.viralBadge,
          tagColor: const Color(0xFF00C853),
          tagTextColor: const Color(0xFF04140A),
          prototypeChrome: true,
          showStatusBar: true,
          prototypeModeChrome: true,
          prototypeTagLayout: true,
          onRestart: _finishEarly,
          // Ölü sonuç kaplaması kaldırıldı: build başındaki
          // _edgeShowResult `_resultShown`u hep `true` yaptığı için bu
          // koşul hiç sağlanmıyordu; tek sonuç yolu finishRun diyaloğu.
          overlay: _paused ? _pauseOverlay() : null,
          footer: Center(
            child: SizedBox(width: 285, child: ModeBonusBar(items: bonuses)),
          ),
          child: labeledStageChild,
        ),
      );
    }

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
              Positioned.fill(
                child: Opacity(
                  opacity: 0.96,
                  child: Image.asset(
                    'assets/scream_sky.webp',
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
              Column(
                children: [
                  if (hasShellStatusBar)
                    SizedBox(
                      height: widget.prototypeVisualState
                          ? 35.4
                          : MediaQuery.paddingOf(context).top,
                    )
                  else
                    _prototypeStatusBar(),
                  _prototypeHeader(context),
                  _prototypeHud(),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x660E1422), Color(0x800E1422)],
                        ),
                        border: Border.all(
                          color: const Color(0x24FFFFFF),
                          width: 2,
                        ),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: labeledStageChild,
                      ),
                    ),
                  ),
                  _prototypeDock(bonuses),
                ],
              ),
              // Ölü sonuç kaplaması kaldırıldı (dar ekranla aynı gerekçe);
              // tek sonuç yolu finishRun diyaloğu.
              if (_paused && _alive && !widget.prototypeVisualState)
                _pauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// Duraklatma düğmesi (madde 37, geniş ekran): başlık satırında
  /// '?' düğmesinin yanında, HUD düzenini kaydırmadan durur.
  Widget _pauseButton() {
    return Semantics(
      button: true,
      label: context.l10n.pause,
      child: GestureDetector(
        onTap: _togglePause,
        child: Container(
          width: 48,
          height: 48,
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
            size: 22,
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
                  context.l10n.screamPauseScore(_score, _gatesPassed),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ArcadeButton(
                  label: context.l10n.continueAction,
                  onPressed: _togglePause,
                ),
                const SizedBox(height: 12),
                // N6: duraklatmadan çıkış — mevcut geri yolu
                // (`maybePop`); iade kuralları PopScope handler'da
                // aynen korunur, yeni iade mantığı yok.
                ArcadeButton(
                  label: context.l10n.quit,
                  primary: false,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Yardım diyaloğu: açıkken oyun durur, kapanınca kaldığı yerden
  /// devam eder. Zaten duraklatılmışsa veya tur bitmişse duraklatma
  /// durumuna dokunulmaz (diyalog kapanınca eski hâl korunur).
  Future<void> _showHelpDialog() async {
    final wasAlive = _alive;
    final wasPaused = _paused;
    final frozeHere = wasAlive && !wasPaused;
    if (frozeHere) {
      _paused = true;
      _pauseStartedAt ??= DateTime.now();
      _pauseNoiseSubscription();
      _ticker.stop();
      setState(() {});
    }
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.screamBugTitle),
          // Kural metni (F4): yardım diyaloğu canlı _hint'i
          // (spam/kombo mesajları) değil oyun kurallarını gösterir;
          // oyun-içi _hint atamaları aynen durur (bulgu #9).
          content: Text(context.l10n.screamHowToBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.understoodButton),
            ),
          ],
        ),
      );
    } finally {
      if (frozeHere && mounted) {
        _paused = false;
        // Diyalog açıkken arka plana alındıysa konan bayrak da
        // temizlenir; yoksa `_onNoiseReading` koruması mikrofonu
        // kalıcı kilitler (koordinatör incelemesinde bulundu).
        _pausedByLifecycle = false;
        _shiftPauseDeadlines();
        _last = Duration.zero;
        _resumeNoiseSubscription();
        if (_alive && !_ticker.isActive) _ticker.start();
        setState(() {});
      }
    }
  }

  Widget _prototypeStatusBar() {
    return SizedBox(
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
              child: CustomPaint(painter: _ScreamStatusIndicatorsPainter()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prototypeHeader(BuildContext context) {
    return SizedBox(
      height: 56.3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: context.l10n.goBackLabel,
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 45.9,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xD9080B12),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Color(0x73000000), offset: Offset(0, 3)),
                    ],
                  ),
                  child: Image.asset(
                    'assets/icons2/back-prototype.png',
                    width: 29,
                    height: 29,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF4A9DDB),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      context.l10n.screamBugTitle,
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
                  const SizedBox(height: 3),
                  Container(
                    height: 20.3,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      context.l10n.viralBadge,
                      style: GoogleFonts.baloo2(
                        fontSize: 10.5,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: const Color(0xFF04140A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 88.8,
              height: 35,
              padding: const EdgeInsets.fromLTRB(6, 5, 0, 5),
              decoration: BoxDecoration(
                color: const Color(0xD1080B12),
                borderRadius: BorderRadius.circular(99),
                boxShadow: const [
                  BoxShadow(color: Color(0x59000000), offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icons2/coin.png', width: 25, height: 25),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _fmtInt(
                        widget.prototypeVisualState
                            ? 12450
                            : ProgressManager().coins,
                      ),
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
            ),
            if (!widget.prototypeVisualState) ...[
              const SizedBox(width: 10),
              _pauseButton(),
            ],
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: context.l10n.helpButtonLabel,
              child: GestureDetector(
                onTap: _showHelpDialog,
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
                      BoxShadow(color: Color(0x66000000), offset: Offset(0, 3)),
                    ],
                  ),
                  child: Text(
                    '?',
                    style: GoogleFonts.baloo2(
                      fontSize: 22,
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
    );
  }

  Widget _prototypeHud() {
    return SizedBox(
      height: 58.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _prototypeStat(context.l10n.gameScoreLabel, _fmtInt(_score), 104),
            const SizedBox(width: 8),
            _prototypeStat(context.l10n.gameBestLabel, _fmtInt(_best), 84),
            const Spacer(),
            _prototypeStat(context.l10n.screamGateStat, '$_gatesPassed', 74),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: context.l10n.finishRoundLabel,
              child: GestureDetector(
                onTap: _finishEarly,
                child: Container(
                  width: 57.8,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFFB97A00), offset: Offset(0, 3)),
                    ],
                  ),
                  child: Text(
                    context.l10n.finishCaps,
                    style: GoogleFonts.baloo2(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4A2E00),
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

  Widget _prototypeStat(String label, String value, double width) {
    return Container(
      width: width,
      height: 50.5,
      padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xD9080B12),
        border: Border.all(color: const Color(0x73FFB800), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: const Color(0xFFFFB800),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3.5),
          SizedBox(
            height: 21,
            width: width - 24,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _prototypeDock(List<ModeBonus> bonuses) {
    const protoCounts = [3, 2, 1];
    return SizedBox(
      height: 80.9,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < bonuses.length; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              _prototypeBonusButton(
                bonuses[i],
                widget.prototypeVisualState ? protoCounts[i] : bonuses[i].count,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _prototypeBonusButton(ModeBonus item, int count) {
    return Semantics(
      button: true,
      enabled: count > 0,
      label: context.l10n.boosterCountLabel(item.label, count),
      child: GestureDetector(
        onTap: count > 0 ? item.onTap : null,
        behavior: HitTestBehavior.opaque,
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
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF333F58), Color(0xFF1B2336)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x47FFFFFF),
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
                      child: Image.asset(item.asset, fit: BoxFit.contain),
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
                          '$count',
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
    );
  }

  static String _fmtInt(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );

  List<Widget> _buildGate(_Gate g) {
    final topHeight = max(0.0, g.gapCenter - g.gapHalf);
    final bottomTop = g.gapCenter + g.gapHalf;
    final bottomHeight = max(0.0, _arenaH - bottomTop);
    return [
      if (topHeight > 12)
        Positioned(
          left: g.x,
          top: 0,
          width: _gateW,
          height: topHeight,
          child: _PipeColumn(height: topHeight, isTop: true),
        ),
      if (bottomHeight > 12)
        Positioned(
          left: g.x,
          top: bottomTop,
          width: _gateW,
          height: bottomHeight,
          child: _PipeColumn(height: bottomHeight, isTop: false),
        ),
    ];
  }
}

class _PipeColumn extends StatelessWidget {
  const _PipeColumn({required this.height, required this.isTop});

  final double height;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final capHeight = min(22.0, height * 0.45);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: isTop ? 0 : capHeight * 0.5,
          bottom: isTop ? capHeight * 0.5 : 0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF1B8A3D),
                  Color(0xFF4ADE80),
                  Color(0xFF22C55E),
                  Color(0xFF14532D),
                ],
                stops: [0.0, 0.28, 0.65, 1.0],
              ),
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0xFF0A2E17), width: 2.5),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: isTop ? null : 0,
          bottom: isTop ? 0 : null,
          height: capHeight,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF1B8A3D),
                  Color(0xFF6EE7B7),
                  Color(0xFF22C55E),
                  Color(0xFF14532D),
                ],
                stops: [0.0, 0.28, 0.65, 1.0],
              ),
              border: Border.all(color: const Color(0xFF0A2E17), width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Mutfak / viral engeller — Flappy boru yok.
enum _GateKind {
  terlik,
  raid,
  tava,
  tuzak,
  hamamTas,
  vuvuzela;

  const _GateKind();

  String deathLineFor(AppLocalizations l10n) {
    switch (this) {
      case _GateKind.terlik:
        return l10n.gateTerlikDeath;
      case _GateKind.raid:
        return l10n.gateRaidDeath;
      case _GateKind.tava:
        return l10n.gateTavaDeath;
      case _GateKind.tuzak:
        return l10n.gateTuzakDeath;
      case _GateKind.hamamTas:
        return l10n.gateHamamDeath;
      case _GateKind.vuvuzela:
        return l10n.gateVuvuzelaDeath;
    }
  }

  String passLineFor(AppLocalizations l10n) {
    switch (this) {
      case _GateKind.terlik:
        return l10n.gateTerlikPass;
      case _GateKind.raid:
        return l10n.gateRaidPass;
      case _GateKind.tava:
        return l10n.gateTavaPass;
      case _GateKind.tuzak:
        return l10n.gateTuzakPass;
      case _GateKind.hamamTas:
        return l10n.gateHamamPass;
      case _GateKind.vuvuzela:
        return l10n.gateVuvuzelaPass;
    }
  }
}

class _Gate {
  _Gate({
    required this.base,
    required this.gapCenter,
    required this.gapHalf,
    required this.kind,
  });

  double base;
  double gapCenter;
  double gapHalf;
  final _GateKind kind;
  double x = 0;
  bool scored = false;
}

class _ScreamStatusIndicatorsPainter extends CustomPainter {
  const _ScreamStatusIndicatorsPainter();

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
  bool shouldRepaint(_ScreamStatusIndicatorsPainter oldDelegate) => false;
}
