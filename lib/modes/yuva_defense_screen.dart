import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/hisir_character.dart';
import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/daily_challenge_service.dart';
import '../services/difficulty_binding.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/global_notify.dart';
import '../services/haptic_service.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../utils/number_format.dart';

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

  /// Tur-sonu skor→coin bağışı (13E): `skor ~/ 360`, en az 1.
  ///
  /// Yenilgi (`_endGame`) ve BİTİR (`_presentResult`) yolları aynı
  /// bağışı bir kez uygular (`_applyEndCoins` — `_endCoinsApplied`
  /// korumasıyla). Skor 0'da BİTİR yolu bağış vermez (F10 kuralı);
  /// yenilgi yolunun `max(1, ...)` davranışı aynen korunur.
  static int endCoinsForScore(int score) => max(1, score ~/ 360);

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
    this.isHisir = false,
  });

  final int id;
  final InsectTier tier;
  final int lane;
  final double direction;
  double x;
  double y;
  final double speedMultiplier;

  /// Hışır derisi: böcek bu kademenin böceği gibi davranır (hız, skor
  /// aynen), yalnız görseli `hisir_hd.png`, vuruş sesi `hisir_zopa.mp3`.
  final bool isHisir;
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

  /// Kare bildirimi: [_tick] tam `setState` yerine bunu artırır —
  /// yalnız `build` içindeki [ValueListenableBuilder] alt-ağacı
  /// (başlık + arena + güç çubuğu) yenilenir; arka plan, [Scaffold]
  /// ve [PopScope] kare başına kurulmaz.
  final ValueNotifier<int> _tickNotifier = ValueNotifier<int>(0);
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

  /// N7 çıkış onayı durumu: onay bayrağı (diyalogda Çık seçildiyse
  /// `PopScope` çıkışı geçirir), çift-diyalog kilidi ve diyalog
  /// duraklatması bayrağı (yardım deseni: yalnız bu diyalog için
  /// duraklatıldıysa kapanınca devam edilir).
  bool _exitConfirmed = false;
  bool _exitConfirmShowing = false;
  bool _pausedForExitConfirm = false;
  DateTime? _lastHit;
  int _nextBugId = 0;
  int _score = 0;
  int _best = 0;
  int _lives = 4;
  // Dalga 16 (F-Y7): azami can — kalp HUD'u bu sayıyla çizilir.
  static const int _maxLives = 4;
  int _combo = 0;
  int _maxCombo = 0;
  int _hits = 0;
  int _misses = 0;
  int _coinsEarned = 0;
  // 13E: tur-sonu skor→coin bağışı bu turda uygulandı mı? Yenilgi
  // (`_endGame`) ve BİTİR (`_presentResult`) aynı bağışı paylaşır —
  // bayrak çift eklemeyi kapatır. `_restart` sıfırlar.
  bool _endCoinsApplied = false;
  // B18: kasa yüklenene kadar hayalet stok gösterme — sayaçlar 0'dan
  // başlar, initState'teki yükleme Yuva anahtarlarından doldurur.
  int _doubleSlipCount = 0;
  int _goldSlipCount = 0;
  int _shieldCount = 0;
  int _doubleSlipCharges = 0;
  DateTime? _goldSlipUntil;
  DateTime? _freezeUntil;
  bool _shieldActive = false;
  bool _resultShown = false;

  /// Tur kimliği (Terlik `runId` deseni): `_restart` her yeni turda
  /// artırır; bekleyen sonuç sunumu eski tura aitse gösterilmez.
  int _runId = 0;

  /// Tur başlangıç damgası (Y3): idempotency anahtarının tur bileşeni.
  /// İlk turda State kurulurken, her yeni turda `_restart` içinde
  /// yakalanır; bitiş anında `DateTime.now()` kullanılmaz. BİTİR +
  /// yenilgi yolları aynı `_presentResult` üzerinden aynı anahtarı
  /// paylaşır. Monoton artırılır: aynı milisaniyede iki yeniden
  /// başlatma bile farklı anahtar üretir.
  int _runStartedAtMs = DateTime.now().millisecondsSinceEpoch;

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

  /// Çıkış-sonrası iade bildirimi (S6): `PopScope` `didPop` anında
  /// bağlam artık ağaçta değildir; bildirim metni her `build`'de
  /// ÖNCEDEN yakalanır ve iade gerçekten verildiğinde paylaşılan
  /// `GlobalNotify` üzerinden çıkış yapılan ekranın üstünde
  /// gösterilir (balon/stack deseninin paylaşılan karşılığı).
  String? _refundNotice;
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
  String _hint = '';
  bool _hintSeeded = false;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hintSeeded) {
      _hintSeeded = true;
      _hint = context.l10n.yuvaHintIdle;
    }
  }

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
          // B2: Yuva kendi kasasını kullanır — tohum/pass/IAP bu
          // anahtarlara yazar; ortak dblslip/goldslip/shield Terlik'te kalır.
          _doubleSlipCount = ProgressManager.instance.powerCount(
            'yuva_dblslip',
          );
          _goldSlipCount = ProgressManager.instance.powerCount('yuva_goldslip');
          _shieldCount = ProgressManager.instance.powerCount('nest_shield');
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
      // Dalga 16 (F-Y6): açılış dalgası 4→2 böcek (yayılım korunur).
      _spawnRadial(angleRad: 2.35, radiusFrac: 0.44);
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
    _tickNotifier.dispose();
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
    if (widget.prototypeVisualState || _ended || _resultShown) return;
    // 10D P0-3: duraklatma sesi + titreşimi tek çağrıda
    // (playButtonTap içi selectionClick; ayrıca trigger* eklenmez).
    unawaited(AudioManager().playButtonTap());
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

  /// Yardım diyaloğu açıkken oyun donsun (B4): diyalog açılırken loop
  /// durur, kapanınca kaldığı yerden devam eder (duvar-saati süreleri
  /// duraklatma kadar ötelenir). Zaten duraklatılmış, sonuç
  /// gösteriliyor veya tur bitmişse duraklatma durumuna dokunulmaz.
  Future<void> _showHelpDialog() async {
    final shouldPause =
        !widget.prototypeVisualState && !_ended && !_paused && !_resultShown;
    if (shouldPause) {
      _paused = true;
      _pauseStartedAt ??= DateTime.now();
      _stopLoop();
      setState(() {});
    }
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.shopModeNestDefense.toUpperCase()),
          content: Text(
            context.l10n.yuvaHowToBody1 + context.l10n.yuvaHowToBody2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.understoodButton),
            ),
          ],
        ),
      );
    } finally {
      if (shouldPause && mounted && !_ended) {
        _paused = false;
        _shiftPauseDeadlines();
        _startLoop();
        setState(() {});
      }
    }
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
        isHisir:
            tier == null &&
            !widget.prototypeVisualState &&
            HisirCharacter.roll(_random),
        lane: chosenLane,
        direction: left ? 1 : -1,
        x: spawnX,
        y: spawnY,
        // 12C1: adaptif zorluk — merhamette böcekler yavaşlar (0.88x),
        // kazanma serisinde hızlanır (1.35x tavan).
        speedMultiplier: DifficultyBinding.instance
            .cachedProfileForMode('yuva')
            .speedMultiplier,
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
    // 12C1: adaptif zorluk — merhamette böcekler yavaşlar (0.88x),
    // kazanma serisinde hızlanır (1.35x tavan).
    final speedMul =
        (0.88 + _random.nextDouble() * 0.36) *
        DifficultyBinding.instance.cachedProfileForMode('yuva').speedMultiplier;
    _bugs.add(
      _DefenseBug(
        id: _nextBugId++,
        tier: selectedTier,
        isHisir:
            tier == null &&
            !widget.prototypeVisualState &&
            HisirCharacter.roll(_random),
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
    final spawnEvery = max(0.36, 1.6 - ramp * 0.011);
    if (_spawnElapsed >= spawnEvery) {
      _spawnElapsed = 0;
      _spawnRadial();
      // İlerleyen saniyelerde aynı anda farklı köşelerden çift böcek gelebilir
      if (ramp > 30 && _bugs.length < 9 && _random.nextDouble() < 0.38) {
        _spawnRadial();
      }
    }

    final baseSpeed = 0.095 + min(0.24, ramp * 0.0028);
    final speed = _isFrozen ? baseSpeed * 0.42 : baseSpeed;
    _bugs.removeWhere((bug) {
      if (!bug.popping) return false;
      bug.popTime -= dt;
      return bug.popTime <= 0;
    });
    var escaped = false;
    // B16: iterasyon sırasında koleksiyondan silme — kaçan böcek
    // işaretlenir, döngüden sonra silinir (kare başına 1 kaçış, aynı davranış).
    _DefenseBug? escapedBug;
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
      if (dist <= 0.06) {
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
          // 10D P1-4: kalkan kurtarması savunma başarısıdır — UI tık
          // sesi (playButtonTap) yerine isabet deseni playSlipperSmash
          // (terlik tokadı + onSlipperSlap, tek impuls; titreşim yoktu).
          unawaited(AudioManager().playSlipperSmash());
          _hint = context.l10n.yuvaShieldSaved;
          _hintIsComboBroken = false;
          continue;
        }
        escapedBug = bug;
        _lives--;
        _misses++;
        _combo = 0;
        _hint = context.l10n.yuvaBugEntered(_lives);
        _hintIsComboBroken = false;
        // 10D P0-1: yuva kaçışı tamamen sessizdi (yalnız ipucu).
        // İsabet deseni: yuvada _HitBurst + sarsıntı + terlik tokadı
        // (playSlipperSmash içi onSlipperSlap, tek impuls).
        _bursts.add(
          _HitBurst(
            x: _nestCenterX * _arenaWidth,
            y: _nestCenterY * _arenaHeight,
          ),
        );
        _shake = 0.35;
        unawaited(AudioManager().playSlipperSmash());
        escaped = true;
        break;
      }
    }
    if (escapedBug != null) _bugs.remove(escapedBug);
    if (escaped && _lives <= 0) {
      _endGame();
      return;
    }
    // Kare-başına tam rebuild yok: yalnız [_tickNotifier] dinleyen
    // alt-ağaç yenilenir (başlık + arena + güç çubuğu).
    _tickNotifier.value++;
  }

  /// S1#48: ölüm sonrası 500 ms geçmeden dokunuşla yeniden başlatma yok.
  bool _deathRestartAllowed() =>
      _endedAt == null ||
      DateTime.now().difference(_endedAt!) >= const Duration(milliseconds: 500);

  /// Tur-sonu skor→coin bağışı (13E): [YuvaDefenseScreen.endCoinsForScore]
  /// bir kez `_coinsEarned`'e eklenir. Yenilgi yolu (`_endGame`) ve
  /// BİTİR yolu (`_presentResult`) aynı yardımcıdan geçer; ikinci
  /// çağrı no-op'tur. Ödeme burada yapılmaz — birikim yalnız artırılır,
  /// grant `finishRun` varsayılan ödemesindedir.
  void _applyEndCoins() {
    if (_endCoinsApplied) return;
    _endCoinsApplied = true;
    _coinsEarned += YuvaDefenseScreen.endCoinsForScore(_score);
  }

  void _endGame() {
    // Tur tamamlandı: iade hakkı biter (Stack Drop `_fail` deseni).
    _moveMade = true;
    _ended = true;
    _endedAt = DateTime.now();
    _best = max(_best, _score);
    _applyEndCoins();
    unawaited(HapticService.instance.heavyImpact());
    // D1: bitiş sesi tek kaynak — sonuç ekranı çalar.
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
      final runId = _runId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _presentResult(runId);
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

  /// N7 diyalog duraklatması (`_togglePause` deseni): oyun
  /// zamanlayıcısı durur, duvar-saati süreleri devamda kaydırılır.
  void _pauseForExitConfirm() {
    if (widget.prototypeVisualState || _ended || _resultShown || _paused) {
      return;
    }
    _pausedForExitConfirm = true;
    _paused = true;
    _pauseStartedAt ??= DateTime.now();
    _stopLoop();
    setState(() {});
  }

  void _resumeAfterExitConfirm() {
    if (!_pausedForExitConfirm) return;
    _pausedForExitConfirm = false;
    _paused = false;
    _shiftPauseDeadlines();
    _startLoop();
    setState(() {});
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
    final runId = _runId;
    // B5: sonuç ekranı açılırken tur donsun — loop durur, giriş
    // koruması _paused üzerinden çalışır (güçlendirici handler'ları,
    // _tapArena ve _hitBug duraklatmada en başta döner; _togglePause
    // _resultShown varken kilitlidir). _restart yeni turda sıfırlar.
    _stopLoop();
    _paused = true;
    _pauseStartedAt ??= DateTime.now();
    try {
      await _presentResult(runId, won: _score > 0);
    } finally {
      // Sonuç gösterilemediyse (hata) ve tur hâlâ buysa oyunu çöz;
      // _restart araya girdiyse runId değişmiştir, dokunulmaz.
      // Tekrar-dışı çıkışta (pop) bu satırlar zararsızdır: dispose
      // zamanlayıcıyı iptal eder; pop gerçekleşmezse oyun devam eder.
      if (mounted && runId == _runId && !_ended) {
        _paused = false;
        _pausedByLifecycle = false;
        _shiftPauseDeadlines();
        _startLoop();
        setState(() {});
      }
    }
  }

  Future<void> _presentResult(int runId, {bool? won}) async {
    // S1#49: ödeme (birikmiş _coinsEarned) + liderlik + görev kaydı +
    // sonuç ekranı finishRun() üzerinden (tek-ödeme korunur).
    // _endGame'deki liderlik gönderimi ayrıca durur (eski çift-gönderim
    // davranışı aynen korunur). Doğal bitiş üssün düşmesidir (kayıp);
    // `won` verilmezse kayıp başlığı gösterilir.
    // Tur değiştiyse (yeniden başlatma araya girdiyse) eski turun
    // sonucunu gösterme (Terlik runId deseni). Bayrağa dokunulmaz:
    // _restart onu sıfırladı, yeni sunum kurduysa da ezilmez.
    if (runId != _runId) return;
    if (!mounted) return;
    // 13E: BİTİR yolu _endGame() uğramadan gelir — tur-sonu bağışı
    // burada da bir kez uygulanır (yenilgi yolunda _endGame zaten
    // uyguladıysa no-op). Skor 0 ise bağış yok (F10 kuralı).
    if (_score > 0) _applyEndCoins();
    try {
      final replay = await finishRun(
        context,
        score: _score,
        best: _best,
        coins: _coinsEarned,
        bestCombo: _maxCombo,
        won: won ?? false,
        leaderboardMode: LeaderboardService.modeYuva,
        // K16: kimlik `bestScoreKey` ('yuva_defense') ile aynıdır —
        // `LeaderboardService.modeYuva` da aynı değerdir.
        modeScoreId: LeaderboardService.modeYuva,
        stillValid: () => mounted && runId == _runId,
        // Y3: '<mod>:<tur başlangıç damgası>' — damga tur
        // başlangıcında yakalandı (`_runStartedAtMs`), bitiş anı değil.
        idempotencyKey: '${LeaderboardService.modeYuva}:$_runStartedAtMs',
        // 12C1: AntiCheat hız denetimi + adaptif zorluk kaydı için tur süresi.
        elapsed: Duration(
          milliseconds: DateTime.now().millisecondsSinceEpoch - _runStartedAtMs,
        ),
      );
      if (runId != _runId) return;
      if (!mounted) return;
      if (!replay) {
        if (mounted) Navigator.of(context).maybePop();
        return;
      }
      _restart();
    } finally {
      // B7: sunum her yoldan bitince bayrak sıfırlanır. _restart yeni
      // tur başlattıysa bayrağı o sıfırladı (runId farklı), dokunulmaz.
      if (runId == _runId) _resultShown = false;
    }
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
          .where(
            (candidate) => !candidate.popping && !identical(candidate, bug),
          )
          .firstOrNull;
      if (extra != null) {
        _hitBug(extra, fromSplash: true);
      }
    }
    _shake = min(0.35, 0.12 + _combo * 0.025);
    unawaited(
      AudioManager().playSlipperSmash(
        characterId: bug.isHisir
            ? HisirCharacter.id
            : GameAudio.characterIdForTier(bug.tier),
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
    if (!ProgressManager.instance.takePower('yuva_dblslip')) {
      setState(() {
        _doubleSlipCount = ProgressManager.instance.powerCount('yuva_dblslip');
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
    unawaited(AudioManager().playButtonTap());
    final nearest = _bugs.where((b) => !b.popping).toList()
      ..sort((a, b) => _bugDistanceToNest(a).compareTo(_bugDistanceToNest(b)));
    if (nearest.isNotEmpty) {
      _hitBug(nearest.first);
    }
  }

  void _useGoldSlipBonus() {
    if (_paused || _ended || _goldSlipCount <= 0) return;
    // Kasa boşsa (yerel sayaç bayatsa) etki çalışmaz, sayaç azalmaz.
    if (!ProgressManager.instance.takePower('yuva_goldslip')) {
      setState(() {
        _goldSlipCount = ProgressManager.instance.powerCount('yuva_goldslip');
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
    unawaited(AudioManager().playButtonTap());
    final nearest = _bugs.where((b) => !b.popping).toList()
      ..sort((a, b) => _bugDistanceToNest(a).compareTo(_bugDistanceToNest(b)));
    if (nearest.isNotEmpty) {
      _hitBug(nearest.first, fromSplash: true);
    }
  }

  void _useShieldBonus() {
    if (_paused || _ended || _shieldCount <= 0) return;
    // B22: kalkan aktifken tekrar basmak stok yakmasın — kasa hiç
    // tüketilmez, ipucu kalkanın aktif olduğunu gösterir.
    if (_shieldActive) {
      setState(() {
        _hint = context.l10n.yuvaShieldIceHint;
        _hintIsComboBroken = false;
      });
      return;
    }
    // Kasa boşsa (yerel sayaç bayatsa) etki çalışmaz, sayaç azalmaz.
    if (!ProgressManager.instance.takePower('nest_shield')) {
      setState(() {
        _shieldCount = ProgressManager.instance.powerCount('nest_shield');
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
    unawaited(AudioManager().playButtonTap());
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
        unawaited(HapticService.instance.selectionClick());
        // 10D P0-2: ıska sesi — playDrop (kapılı lightImpact;
        // yukarıdaki selectionClick ile aynı tick'te 18 ms kapısına
        // takılıp düşer — toplam 1 impuls).
        unawaited(AudioManager().playDrop());
        setState(() {});
        return;
      }
      _hitBug(hit);
      return;
    }
    final laneHeight = max(72.0, _arenaHeight * 0.24);
    final lane = List<int>.generate(_laneTopFactors.length, (index) => index)
        .indexWhere(
          (index) =>
              (p.dy - _laneCenterY(index, _arenaHeight)).abs() <=
              laneHeight / 2,
        );
    if (lane < 0) {
      _combo = 0;
      _hint = context.l10n.yuvaMissHint;
      _hintIsComboBroken = true;
      unawaited(HapticService.instance.selectionClick());
      // 10D P0-2: ıska sesi — playDrop (kapılı lightImpact;
      // yukarıdaki selectionClick ile aynı tick'te 18 ms kapısına
      // takılıp düşer — toplam 1 impuls).
      unawaited(AudioManager().playDrop());
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
      unawaited(HapticService.instance.selectionClick());
      // 10D P0-2: ıska sesi — playDrop (kapılı lightImpact;
      // yukarıdaki selectionClick ile aynı tick'te 18 ms kapısına
      // takılıp düşer — toplam 1 impuls).
      unawaited(AudioManager().playDrop());
      setState(() {});
      return;
    }
    _hitBug(hit);
  }

  void _restart() {
    // Restart güç üretmez: sayaçlar kasadaki güncel stoktan yüklenir
    // (initState'teki yüklemeyle aynı Yuva anahtarları). Prototip
    // görünümünde sabit vitrin sayıları korunur (ekran zaten sabit gösterir).
    // Yeni tur kimliği: bekleyen eski sonuç sunumu gösterilmez (B5).
    _runId++;
    // Y3: yeni tur, yeni idempotency damgası (monoton — aynı
    // milisaniyede iki yeniden başlatma bile çakışmaz).
    _runStartedAtMs = max(
      DateTime.now().millisecondsSinceEpoch,
      _runStartedAtMs + 1,
    );
    final pm = ProgressManager.instance;
    final doubleSlip = widget.prototypeVisualState
        ? 3
        : pm.powerCount('yuva_dblslip');
    final goldSlip = widget.prototypeVisualState
        ? 2
        : pm.powerCount('yuva_goldslip');
    final shield = widget.prototypeVisualState
        ? 1
        : pm.powerCount('nest_shield');
    setState(() {
      _bugs.clear();
      _bursts.clear();
      _paused = false;
      _pausedByLifecycle = false;
      _pauseStartedAt = null;
      _resultShown = false;
      _score = 0;
      _lives = 4;
      _combo = 0;
      _maxCombo = 0;
      _hits = 0;
      _misses = 0;
      _coinsEarned = 0;
      _endCoinsApplied = false;
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
        // Dalga 16 (F-Y6): açılış dalgası 4→2 böcek (yayılım korunur).
        _spawnRadial(angleRad: -0.6, radiusFrac: 0.45);
        _spawnRadial(angleRad: 2.5, radiusFrac: 0.46);
      }
    });
    // Duraklatılmışken yeniden başlatılırsa zamanlayıcı dursun kalmasın.
    if (!widget.prototypeVisualState) _startLoop();
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
                const SizedBox(height: 12),
                // N6: duraklatmadan çıkış — mevcut geri yolu
                // (`maybePop`); iade kuralları PopScope handler'da
                // aynen korunur, yeni iade mantığı yok.
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 48),
                  ),
                  onPressed: () => Navigator.maybePop(context),
                  child: Text(context.l10n.quit),
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
    // S6: iade bildirimi metni çıkıştan ÖNCE yakalanır
    // (`didPop` anında bağlam ağaçta değildir).
    _refundNotice = context.l10n.energyRefundNotice;
    final coins = widget.prototypeVisualState ? 12450 : ProgressManager().coins;
    final topPad = MediaQuery.paddingOf(context).top;
    final hasHostStatusBar = topPad > 0;
    final wideScreen = MediaQuery.sizeOf(context).width >= 400;
    // Statik arka plan: kare bildiriminde yeniden kurulmaz --
    // [ValueListenableBuilder] `child` olarak bir kez kurulur.
    final background = Stack(
      fit: StackFit.expand,
      children: [
        if (!widget.prototypeVisualState)
          Positioned(
            left: 0,
            top: 0,
            width: 0,
            height: 0,
            child: Opacity(
              opacity: 0,
              child: Text(context.l10n.shopModeNestDefense.toUpperCase()),
            ),
          ),
        Opacity(
          opacity: 0.96,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.95,
              0,
              0,
              0,
              0,
              0,
              0.95,
              0,
              0,
              0,
              0,
              0,
              0.95,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
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
      ],
    );
    return PopScope(
      canPop: _exitConfirmed || !_needsExitConfirm,
      onPopInvokedWithResult: (didPop, _) => _handleExitPop(didPop),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF080B12),
          body: ValueListenableBuilder<int>(
            valueListenable: _tickNotifier,
            builder: (context, _, backgroundChild) => Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: backgroundChild!),
                SafeArea(
                  child: Column(
                    children: [
                      if (hasHostStatusBar) SizedBox(height: topPad),
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0x8C080B12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: FittedBox(
                                                // F-11: `maxLines: 1` +
                                                // varsayılan softWrap,
                                                // geniş ekranda ikinci
                                                // kelimeyi üç nokta
                                                // olmadan düşürüyordu
                                                // ("YUVA"). FittedBox
                                                // (scaleDown) tam başlığı
                                                // sığdırır.
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  context
                                                      .l10n
                                                      .shopModeNestDefense
                                                      .toUpperCase(),
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  overflow: TextOverflow.clip,
                                                  style: GoogleFonts.baloo2(
                                                    fontSize: 20,
                                                    height: 1.05,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                    shadows: const [
                                                      Shadow(
                                                        color: Color(
                                                          0xEB000000,
                                                        ),
                                                        offset: Offset(0, 2),
                                                        blurRadius: 6,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE01E5A),
                                                borderRadius:
                                                    BorderRadius.circular(999),
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
                                          semanticLabel:
                                              context.l10n.yuvaTitleNewSemantic,
                                        ),
                                ),
                              ),
                              SizedBox(width: wideScreen ? 10 : 20),
                              if (wideScreen)
                                Container(
                                  width: 82.5,
                                  height: 35,
                                  padding: const EdgeInsets.fromLTRB(
                                    6,
                                    5,
                                    0,
                                    5,
                                  ),
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
                                          formatGroupedInt(
                                            coins,
                                            Localizations.localeOf(
                                              context,
                                            ).languageCode,
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
                                                formatGroupedInt(
                                                  coins,
                                                  Localizations.localeOf(
                                                    context,
                                                  ).languageCode,
                                                ),
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
                                onTap: () => _showHelpDialog(),
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
                                      value: formatGroupedInt(
                                        _best,
                                        Localizations.localeOf(
                                          context,
                                        ).languageCode,
                                      ),
                                      singleRowHearts: wideScreen,
                                    ),
                                  ),
                                  if (wideScreen)
                                    const Spacer()
                                  else
                                    const SizedBox(width: 8),
                                  SizedBox(
                                    // Dalga 16 (F-Y7): 4 kalp sığsın diye
                                    // geniş kart 98.4→108 (kalp 17 px).
                                    width: wideScreen ? 108 : 80,
                                    child: _HudCard(
                                      label: context.l10n.livesLabel,
                                      value: '$_lives',
                                      singleRowHearts: wideScreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Semantics(
                                    button: true,
                                    label: _ended
                                        ? context.l10n.playAgainButton
                                        : context.l10n.finishRoundLabel,
                                    child: GestureDetector(
                                      // Tur bitmişse doğrudan yeniden başlat
                                      // (eski davranış); tur sürüyorsa BİTİR
                                      // sonuç ekranını açar (bulgu #10).
                                      onTap: _ended ? _restart : _finishEarly,
                                      child: Container(
                                        width: 58,
                                        height: 48,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFB800),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
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
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
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
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
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
                                                      hitsLabel: context.l10n
                                                          .yuvaHitsPainter(
                                                            _hits,
                                                          ),
                                                      missesLabel: context.l10n
                                                          .yuvaMissedPainter(
                                                            _misses,
                                                          ),
                                                      bannerLabel: context
                                                          .l10n
                                                          .yuvaBanner,
                                                      hint: _hint,
                                                      comboBroken:
                                                          _hintIsComboBroken,
                                                      bursts:
                                                          List<_HitBurst>.of(
                                                            _bursts,
                                                          ),
                                                      showRadialRings: !widget
                                                          .prototypeVisualState,
                                                    ),
                                                  ),
                                                  for (final bug in _bugs)
                                                    Positioned(
                                                      left:
                                                          bug.x * _arenaWidth -
                                                          30,
                                                      top:
                                                          widget
                                                              .prototypeVisualState
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
                                                            alignment: Alignment
                                                                .topCenter,
                                                            clipBehavior:
                                                                Clip.none,
                                                            children: [
                                                              if (!bug.popping &&
                                                                  _bugDistanceToNest(
                                                                        bug,
                                                                      ) <
                                                                      (widget.prototypeVisualState
                                                                          ? 0.10
                                                                          : 0.16))
                                                                Positioned(
                                                                  left:
                                                                      widget
                                                                          .prototypeVisualState
                                                                      ? 0
                                                                      : -3.3,
                                                                  top:
                                                                      widget
                                                                          .prototypeVisualState
                                                                      ? 0
                                                                      : -3.3,
                                                                  child: Transform.scale(
                                                                    scale:
                                                                        widget
                                                                            .prototypeVisualState
                                                                        ? 1.0
                                                                        : 1 +
                                                                              sin(
                                                                                    _pulse.value *
                                                                                        pi,
                                                                                  ) *
                                                                                  0.07,
                                                                    child: Container(
                                                                      width:
                                                                          widget
                                                                              .prototypeVisualState
                                                                          ? 60
                                                                          : 66.6,
                                                                      height:
                                                                          widget
                                                                              .prototypeVisualState
                                                                          ? 60
                                                                          : 66.6,
                                                                      decoration: BoxDecoration(
                                                                        shape: BoxShape
                                                                            .circle,
                                                                        border: Border.all(
                                                                          color: const Color(
                                                                            0xFFE52E2E,
                                                                          ),
                                                                          width:
                                                                              3,
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
                                                                  angle:
                                                                      widget
                                                                          .prototypeVisualState
                                                                      ? 0.0
                                                                      : atan2(
                                                                              _nestCenterY -
                                                                                  bug.y,
                                                                              _nestCenterX -
                                                                                  bug.x,
                                                                            ) *
                                                                            0.18,
                                                                  child: Transform.scale(
                                                                    alignment:
                                                                        Alignment
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
                                                                      bug.isHisir
                                                                          ? HisirCharacter.assetPath
                                                                          : 'assets/bugs/tier${bug.tier.tier}_hd${bug.tier.tier == 5 ? '.webp' : '.png'}',
                                                                      width: 48,
                                                                      height:
                                                                          48,
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
                                                    left:
                                                        (_arenaWidth - 160) / 2,
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
                                                      _hitEffectLane !=
                                                          null) ...[
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
                                                            angle:
                                                                -24 * pi / 180,
                                                            child: Image.asset(
                                                              'assets/powerup_terlik.png',
                                                              width: 66,
                                                              height: 66,
                                                              fit: BoxFit
                                                                  .contain,
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
                                                              context
                                                                  .l10n
                                                                  .yuvaFellTitle,
                                                              style: GoogleFonts.baloo2(
                                                                fontSize: 23,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color: _ink,
                                                              ),
                                                            ),
                                                            Text(
                                                              context.l10n
                                                                  .yuvaResultScore(
                                                                    _score,
                                                                    _combo,
                                                                  ),
                                                              style: GoogleFonts.nunito(
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
                                                              onPressed:
                                                                  _restart,
                                                              child: Text(
                                                                context
                                                                    .l10n
                                                                    .playAgainButton,
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
                                  label: context
                                      .l10n
                                      .shopPowerDoubleSlipperNameCaps,
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
                                  label: context
                                      .l10n
                                      .shopPowerGoldenSlipperNameCaps,
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
            child: background,
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
    required this.bannerLabel,
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
  final String bannerLabel;
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
        final outer =
            nestCenter +
            Offset(cos(angle), sin(angle)) *
                (min(size.width, size.height) * 0.52);
        canvas.drawLine(inner, outer, spokePaint);
      }
    } else {
      for (
        var lane = 0;
        lane < _YuvaDefenseScreenState._laneTopFactors.length;
        lane++
      ) {
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
        : (combo > 0 ? 'COMBO X$combo!' : bannerLabel);
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
    _paintAnimatedLabel(canvas, labelPainter, const Offset(12, 10), size);
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
        size,
      );
    }
  }

  void _paintAnimatedLabel(
    Canvas canvas,
    TextPainter painter,
    Offset offset,
    Size canvasSize,
  ) {
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
    // Nabız ölçeği etiketi tuval dışına taşırmasın (bulgu #4): 1.3
    // ölçek, sol kenara yakın pankartın "Y" harfini ekran dışına
    // itiyordu. Ölçek, merkeze göre ölçeklenmiş etiketin dört kenarı
    // da tuval içinde kalacak şekilde sınırlandırılır (dönüş payı
    // için 0.95 katsayı).
    var clampedScale = scale;
    final halfW = painter.width / 2;
    final halfH = painter.height / 2;
    if (halfW > 0 && halfH > 0) {
      final maxScaleX = min(center.dx, canvasSize.width - center.dx) / halfW;
      final maxScaleY = min(center.dy, canvasSize.height - center.dy) / halfH;
      final maxScale = min(maxScaleX, maxScaleY) * 0.95;
      if (maxScale < clampedScale) clampedScale = max(0.3, maxScale);
    }
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
    canvas.scale(clampedScale);
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
        SizedBox(
          height: label == context.l10n.livesLabel && singleRowHearts ? 4 : 5,
        ),
        if (label == context.l10n.livesLabel && singleRowHearts)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _YuvaDefenseScreenState._maxLives; i++) ...[
                if (i > 0) const SizedBox(width: 3.0),
                Opacity(
                  opacity: i < (int.tryParse(value) ?? 0) ? 1 : 0.25,
                  child: Image.asset(
                    'assets/icons/health.png',
                    width: 17,
                    height: 17,
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
              for (var i = 0; i < _YuvaDefenseScreenState._maxLives; i++)
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
      button = Semantics(button: true, label: label, child: button);
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
