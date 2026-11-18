import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/haptic_service.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';
import '../widgets/mode_bonus_bar.dart';

/// Moving slab. Tap drops it. Overlap is kept, the overhang is cut off.
/// Perfect center keeps full width + combo heat.
class StackDropScreen extends StatefulWidget {
  const StackDropScreen({
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
  State<StackDropScreen> createState() => _StackDropScreenState();
}

class _Slab {
  _Slab({
    required this.center,
    required this.width,
    required this.tier,
    required this.floor,
    this.perfect = false,
  });

  double center;
  double width;
  final int tier;
  final int floor;
  final bool perfect;
}

class _CutPiece {
  _CutPiece({
    required this.center,
    required this.width,
    required this.y,
    required this.vy,
    required this.rot,
    required this.vRot,
    required this.tier,
    required this.life,
  });

  double center;
  final double width;
  double y;
  double vy;
  double rot;
  final double vRot;
  final int tier;
  double life;
}

enum _Phase { ready, falling, failed }

class _StackDropScreenState extends State<StackDropScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double slabH = 36;
  static const double _stageHintHeight = 0;
  // İsabet bantları ÇAKIŞMAZ (S1#47): perfect = offset ≤ perfectPx,
  // near = perfectPx < offset ≤ nearPx, diğer = offset > nearPx.
  // nearPx her zaman perfectPx'ten büyük tutulmalıdır; bant tanımı
  // _settle() içinde açık aralık olarak yazılır.
  static const double perfectPx = 7;
  static const double nearPx = 16;
  static const _slabColors = <Color>[
    Color(0xFFFFE9C9),
    Color(0xFFFFE3D6),
    Color(0xFFE4F0FF),
    Color(0xFFF3E4FF),
    Color(0xFFFFE0EC),
    Color(0xFFDFF7EA),
    Color(0xFFFFF0D6),
  ];
  final _rng = Random();
  final List<_Slab> _stack = [];
  final List<_CutPiece> _cutPieces = [];
  String? _activePowerFx;
  double _powerFxLife = 0;

  _Phase _phase = _Phase.ready;
  // S1#48: başarısızlık anı — ölüm sonrası ilk 500 ms içindeki dokunuş
  // yeniden başlatmaz (sonuç ekranı zaten yolda; yanlışlıkla dokunuş
  // yeni turu bozmasın).
  DateTime? _failedAt;
  bool _resultShown = false;

  /// Tur kimliği (F2): her `_boot` artırır. Bekleyen `_presentResult`,
  /// tur değiştiyse eski turun sonucunu göstermez (`stillValid`).
  int _runId = 0;

  /// Yaşam döngüsü duraklatması ayrımı (L1): `resumed` yalnız bu
  /// bayrak setliyken oyunu devam ettirir; elle duraklatma sürer.
  bool _pausedByLifecycle = false;

  /// Yardım sayfası duraklatması bayrağı (F3): sayfa kapanınca yalnız
  /// bu bayrak setliyken devam ettirilir (önceden elle duraklatıldıysa
  /// duraklatma sürer).
  bool _pausedByHowToPlay = false;

  /// Duraklatma başlangıcı (L1): duvar-saati son tarihleri
  /// (`_freezeUntil`, `_perfectSlowUntil`, `_slowDropUntil`) duraklatma
  /// süresince işlemesin diye devamda kaydırılır.
  DateTime? _pauseStartedAt;

  /// Hamle bayrağı (enerji iadesi): oturum boyunca ilk dilim bırakma
  /// (`_drop`) veya tur tamamlanması (`_fail`) ile `true` olur;
  /// TEKRAR/yeniden başlatmada SIFIRLANMAZ (Suika `_dropsMade`
  /// deseni — oturum ömrü).
  bool _moveMade = false;

  /// Çift-iade koruması: iade bu oturumda en fazla bir kez yapılır.
  bool _energyRefunded = false;

  bool _laidOut = false;
  bool _paused = false;
  double _arenaW = 320;
  double _arenaH = 480;
  double _moverX = 160;
  double _moverW = 140;
  double _dir = 1;
  double _speed = 160;
  double _fallY = 16;
  double _sway = 0;
  int _tier = 1;
  int _score = 0;
  int _best = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _floors = 0;
  int _perfects = 0;
  int _nears = 0;
  double _comboMeter = 0;
  double _elapsedSeconds = 0;
  // Ş5: başlatıcı boş — ilk karede EN oyuncu TR metin görmesin diye
  // gerçek metin `didChangeDependencies`'te l10n'den atanır (Osmantus deseni).
  String _hint = '';
  bool _hintSeeded = false;
  String? _feedback;
  String? _milestone;
  Timer? _milestoneTimer;
  Timer? _feedbackTimer;
  final Set<int> _milestonesHit = {};
  double _shake = 0;
  double _perfectBounce = 1.0;
  double _cameraY = 0;

  Ticker? _ticker;
  Duration _last = Duration.zero;

  DateTime? _freezeUntil;
  DateTime? _perfectSlowUntil;

  /// Yavaşlatma gücünün geçici çarpan son tarihi (F8): `_speed`'e
  /// yazılmaz, süre bitince eski hız aynen sürer.
  DateTime? _slowDropUntil;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hintSeeded) {
      _hintSeeded = true;
      _hint = context.l10n.stackHintIdle;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioManager().initialize();
    _ensureDefaultPowers();
    if (widget.prototypeVisualState) {
      final pm = ProgressManager();
      pm.extraPowers['freeze'] = 2;
      pm.extraPowers['widen'] = 3;
      pm.extraPowers['slows'] = 1;
      _score = 980;
      _best = 1540;
      _floors = 12;
      _combo = 3;
      _feedback = 'MÜKEMMEL İSABET! X3';
    }
    _loadBest();
    _ticker = createTicker(_tick)..start();
  }

  // Varsayılan stok YALNIZ ilk kurulumda verilir. ProgressManager.load()
  // 'lululu_power_seed_v1' bayrağıyla 33 gücü bir kez tohumlar; tohumlanan
  // anahtarlar extraPowers'ta kalıcı olur, takePower() ise anahtarı silmez,
  // 0'a düşürür. "Hiç tohumlanmadı" bu yüzden anahtar yokluğuyla anlaşılır;
  // eski "üçü de 0 ise doldur" koşulu her girişte bedava stok veriyordu.
  // Tohumlama persistBoosters() ile kalıcı kaydedilir.
  void _ensureDefaultPowers() {
    final pm = ProgressManager();
    const defaults = <String, int>{'freeze': 2, 'widen': 3, 'slows': 1};
    var seeded = false;
    for (final entry in defaults.entries) {
      if (!pm.extraPowers.containsKey(entry.key)) {
        pm.extraPowers[entry.key] = entry.value;
        seeded = true;
      }
    }
    if (seeded) unawaited(pm.persistBoosters());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioManager().stopAll();
    _ticker?.dispose();
    _milestoneTimer?.cancel();
    _feedbackTimer?.cancel();
    if (_score > 0) unawaited(_persist());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.prototypeVisualState || !mounted) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Osmantus deseni: arka planda oyun donsun; dönüşte _tick'in
        // dt kısması (0.05) ikinci korumadır. Zaten duraklatılmışsa
        // bayrak set edilmez — dönüşte elle duraklatma sürer.
        if (_phase == _Phase.failed || _resultShown || _paused) return;
        _pausedByLifecycle = true;
        _pauseStartedAt ??= DateTime.now();
        setState(() => _paused = true);
      case AppLifecycleState.resumed:
        // Yalnız yaşam döngüsü duraklatmasıysa devam et.
        if (!_pausedByLifecycle) return;
        _pausedByLifecycle = false;
        // Yardım sayfası açıkken arka plana gidildiyse devam kararı
        // sayfa kapanınca yardım kancasında verilir; son tarih kaydırma
        // da o ana bırakılır.
        if (_pausedByHowToPlay) return;
        _shiftPauseDeadlines();
        setState(() => _paused = false);
    }
  }

  /// Duraklatma süresince duvar-saati süreleri (freeze / perfect-slow /
  /// yavaşlatma) işlemesin: devamda son tarihler duraklatma süresi
  /// kadar ileri kaydırılır (Scream deseni).
  void _shiftPauseDeadlines() {
    final started = _pauseStartedAt;
    _pauseStartedAt = null;
    if (started == null) return;
    final pausedFor = DateTime.now().difference(started);
    if (pausedFor <= Duration.zero) return;
    if (_freezeUntil != null) _freezeUntil = _freezeUntil!.add(pausedFor);
    if (_perfectSlowUntil != null) {
      _perfectSlowUntil = _perfectSlowUntil!.add(pausedFor);
    }
    if (_slowDropUntil != null) {
      _slowDropUntil = _slowDropUntil!.add(pausedFor);
    }
  }

  Future<void> _loadBest() async {
    // F4: `ensureLoaded` fırlatırsa (initState'ten beklemesiz çağrılır)
    // işlenmemiş async hata olmasın; rekor 0 kalır, oyun sürer.
    try {
      await LeaderboardService.instance.ensureLoaded();
    } catch (error) {
      debugPrint('StackDropScreen: _loadBest hatası: $error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _best = widget.prototypeVisualState
          ? max(_best, 1540)
          : LeaderboardService.instance.getBest(LeaderboardService.modeStack);
    });
  }

  Future<void> _persist() async {
    if (_score <= 0) return;
    // F4 deseni: `_fail`/`dispose`'dan beklemesiz çağrılır; liderlik
    // yazımı fırlatırsa oyun akışı bozulmasın.
    try {
      await LeaderboardService.instance.ensureLoaded();
      await LeaderboardService.instance.submitScore(
        LeaderboardService.modeStack,
        _score,
      );
    } catch (error) {
      debugPrint('StackDropScreen: _persist hatası: $error');
      return;
    }
    final best = LeaderboardService.instance.getBest(
      LeaderboardService.modeStack,
    );
    if (mounted && best > _best) setState(() => _best = best);
  }

  void _boot() {
    // F2: tur kimliği her yeni turda artar; bekleyen eski sunum
    // `stillValid` ile elenir. Bayrak sıfırlamadan ÖNCE artırılır ki
    // araya giren async sunum yeni turu kirletmesin.
    _runId++;
    _stack.clear();
    _cutPieces.clear();
    _activePowerFx = null;
    _powerFxLife = 0;
    const widths = [150.0, 168.0, 182.0, 182.0, 196.0, 210.0, 210.0];
    const tiers = [4, 7, 6, 5, 4, 3, 2];
    final scaleW = (_arenaW / 398.0).clamp(0.75, 1.15);
    _stack.addAll(
      List.generate(
        widths.length,
        (index) => _Slab(
          center: _arenaW / 2,
          width: widths[index] * scaleW,
          tier: tiers[index],
          floor: index + 6,
          perfect: index == widths.length - 1,
        ),
      ),
    );
    _moverW = 150.0 * scaleW;
    _moverX = _arenaW / 2;
    _dir = 1;
    _speed = 150;
    _fallY = 16;
    _sway = 0;
    _tier = 4;
    _score = 0;
    _combo = 0;
    _maxCombo = 0;
    _floors = 12;
    _perfects = 0;
    _nears = 0;
    _comboMeter = 0;
    _elapsedSeconds = 0;
    _feedback = null;
    _feedbackTimer?.cancel();
    // F11: dönüm noktası zamanlayıcısı da iptal edilir; F5: freeze yeni
    // tura sızmaz; F8: yavaşlatma son tarihi de sıfırlanır.
    _milestoneTimer?.cancel();
    _freezeUntil = null;
    _perfectSlowUntil = null;
    _slowDropUntil = null;
    _paused = false;
    _pausedByLifecycle = false;
    _pausedByHowToPlay = false;
    _pauseStartedAt = null;
    _milestonesHit.clear();
    _milestone = null;
    _shake = 0;
    _perfectBounce = 1.0;
    _cameraY = 0;
    _resultShown = false;
    _phase = _Phase.ready;
    _failedAt = null;
    _hint = context.l10n.stackHintIdle;
  }

  void _ensure(double w, double h) {
    if (w <= 0 || h <= 0) return;
    if (!_laidOut) {
      _arenaW = w;
      _arenaH = h;
      _boot();
      if (widget.prototypeVisualState) _applyPrototypeVisualState();
      _laidOut = true;
      return;
    }
    // F13: rotasyon / boyut değişimi mandala takılmaz — ölçü farkı
    // 0.5px'i aşarsa arena güncellenir, tahta yeni ölçüyle orantılı
    // kurulur (skor/tur korunur, dilimler ve hareketli dilim ölçeklenir).
    if ((w - _arenaW).abs() <= 0.5 && (h - _arenaH).abs() <= 0.5) return;
    final oldW = _arenaW;
    final scale = oldW > 0 ? w / oldW : 1.0;
    _arenaW = w;
    _arenaH = h;
    for (final slab in _stack) {
      slab.width = (slab.width * scale).clamp(14.0, w);
      slab.center = (slab.center * scale).clamp(
        slab.width / 2,
        w - slab.width / 2,
      );
    }
    _moverW = (_moverW * scale).clamp(14.0, w);
    _moverX = (_moverX * scale).clamp(_moverW / 2, w - _moverW / 2);
    for (final cp in _cutPieces) {
      cp.center = cp.center * scale;
    }
  }

  void _applyPrototypeVisualState() {
    const widths = [150.0, 168.0, 182.0, 182.0, 196.0, 210.0, 210.0];
    const tiers = [4, 7, 6, 5, 4, 3, 2];
    _stack
      ..clear()
      ..addAll(
        List.generate(
          widths.length,
          (index) => _Slab(
            center: _arenaW / 2,
            width: widths[index],
            tier: tiers[index],
            floor: index + 6,
            perfect: index == widths.length - 1,
          ),
        ),
      );
    _moverW = 150;
    _moverX = _arenaW / 2 - 2.1;
    _tier = 4;
    _speed = 150;
    _score = 980;
    _best = max(_best, 1540);
    _combo = 3;
    _maxCombo = 3;
    _floors = 12;
    _perfects = 3;
    _comboMeter = 0.62;
    _elapsedSeconds = 20;
    _feedback = context.l10n.stackPerfectPrototype;
  }

  void _restart() {
    setState(() {
      _boot();
      _laidOut = true;
    });
  }

  void _tick(Duration elapsed) {
    if (widget.prototypeVisualState) return;
    final frozen =
        _freezeUntil != null && DateTime.now().isBefore(_freezeUntil!);
    if (frozen) {
      setState(() {});
      return;
    }
    if (!mounted || !_laidOut) {
      _last = elapsed;
      return;
    }
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;

    if (_shake > 0) {
      _shake = max(0, _shake - dt * 4.5);
    }
    if (_perfectBounce > 1.0) {
      _perfectBounce = max(1.0, _perfectBounce - dt * 1.8);
    }
    if (_cutPieces.isNotEmpty) {
      for (final cp in _cutPieces) {
        cp.vy += 580 * dt;
        cp.y += cp.vy * dt;
        cp.rot += cp.vRot * dt;
        cp.life -= dt * 1.35;
      }
      _cutPieces.removeWhere((cp) => cp.life <= 0);
    }
    if (_powerFxLife > 0) {
      _powerFxLife = max(0, _powerFxLife - dt * 1.4);
      if (_powerFxLife <= 0) _activePowerFx = null;
    }
    // Keep top of tower near landY; older floors scroll down.
    final targetCam = -max(0.0, (_stack.length - 7) * (slabH + 4) * 0.55);
    _cameraY += (targetCam - _cameraY) * min(1.0, dt * 6);

    if (_paused || _phase == _Phase.failed) {
      if (_shake > 0) setState(() {});
      return;
    }

    _elapsedSeconds += dt;
    _sway += dt * 2.4;
    _comboMeter = max(0, _comboMeter - dt * 0.12);

    if (_phase == _Phase.ready) {
      final tutorialProgress = (_elapsedSeconds / 15).clamp(0.0, 1.0);
      final tutorialSpeed = 0.52 + tutorialProgress * 0.48;
      final now = DateTime.now();
      final perfectSlow =
          _perfectSlowUntil != null && now.isBefore(_perfectSlowUntil!);
      if (!perfectSlow) _perfectSlowUntil = null;
      // F8: yavaşlatma gücü yalnız geçici çarpandır; `_speed`'e yazılmaz.
      final slowDrop = _slowDropUntil != null && now.isBefore(_slowDropUntil!);
      if (!slowDrop) _slowDropUntil = null;
      final pulse = 1.0 + 0.08 * sin(_sway * 1.7);
      _moverX +=
          _dir *
          _speed *
          tutorialSpeed *
          (perfectSlow || slowDrop ? 0.48 : 1.0) *
          pulse *
          dt;
      final half = _moverW / 2;
      if (_moverX + half > _arenaW) {
        _moverX = _arenaW - half;
        _dir = -1;
      } else if (_moverX - half < 0) {
        _moverX = half;
        _dir = 1;
      }
      setState(() {});
    } else if (_phase == _Phase.falling) {
      _fallY += 920 * dt;
      if (_fallY >= _landY) {
        _settle();
      } else {
        setState(() {});
      }
    }
  }

  double get _baseY => max(0, _arenaH - _stageHintHeight - 12 - slabH);

  double get _currentLandY =>
      _baseY - (_stack.length - 1) * (slabH + 4) - _cameraY;

  double get _landY => _currentLandY;

  void _drop() {
    if (!_laidOut || _paused) return;
    if (_phase == _Phase.failed) {
      // S1#48: ölüm sonrası 500 ms dokunuş yoksayma.
      if (_failedAt != null &&
          DateTime.now().difference(_failedAt!) <
              const Duration(milliseconds: 500)) {
        return;
      }
      _restart();
      return;
    }
    if (_phase != _Phase.ready) return;

    // Enerji iadesi sayacı: bırakma anında sayılır (Suika deseni).
    _moveMade = true;
    _phase = _Phase.falling;
    _fallY = 16;
    AudioManager().playDrop();
    AudioManager().triggerHaptic();
    setState(() {});
  }

  void _settle() {
    final top = _stack.last;
    final left = _moverX - _moverW / 2;
    final right = _moverX + _moverW / 2;
    final topLeft = top.center - top.width / 2;
    final topRight = top.center + top.width / 2;
    final overlapL = max(left, topLeft);
    final overlapR = min(right, topRight);
    final overlap = overlapR - overlapL;
    final offset = (_moverX - top.center).abs();

    if (overlap <= 2) {
      _fail(context.l10n.stackMissedFall);
      return;
    }

    // Bantlar ayrık aralıklar: perfect [0, 7], near (7, 16], diğer (16, ∞).
    // Eski `!perfect && ...` yazımı da ayrık sonuç veriyordu; açık aralık
    // yazımı perfect tanımı değişse bile çakışmayı imkânsız kılar.
    final perfect = offset <= perfectPx;
    final near = offset > perfectPx && offset <= nearPx;
    final width = perfect ? top.width : overlap;
    final center = perfect ? top.center : (overlapL + overlapR) / 2;
    final placedTier = _tier;
    if (width < 14) {
      _fail(context.l10n.stackSliceThin);
      return;
    }

    if (!perfect) {
      final cutW = (_moverW - overlap).clamp(0.0, _moverW);
      if (cutW >= 4) {
        final cutLeftSide = left < topLeft;
        final cutCenter = cutLeftSide
            ? (left + overlapL) / 2
            : (overlapR + right) / 2;
        _cutPieces.add(
          _CutPiece(
            center: cutCenter,
            width: cutW,
            y: _landY,
            vy: 35,
            rot: 0,
            vRot: cutLeftSide ? -2.6 : 2.6,
            tier: placedTier,
            life: 1.0,
          ),
        );
      }
    }

    _moverW = width;
    _floors++;

    if (perfect) {
      _combo++;
      _perfects++;
      _perfectBounce = 1.14;
      if (_combo > _maxCombo) _maxCombo = _combo;
      _comboMeter = min(1.0, 0.4 + _combo * 0.12);
      _perfectSlowUntil = DateTime.now().add(const Duration(milliseconds: 720));
      final heat = 1.0 + min(1.0, (_combo - 1) * 0.15);
      final gain = ((28 + _combo * 8 + _floors) * heat).round();
      _score += gain;
      _hint = context.l10n.stackDirectHit(_combo, gain);
      _showFeedback(context.l10n.stackPerfectHit(_combo));
      AudioManager().playMerge(tierNumber: _tier, comboCount: _combo);
      AudioManager().triggerMediumHaptic();
      if (_combo == 3 || _combo == 5 || _combo == 8) {
        _showMilestone('COMBO x$_combo');
      }
    } else if (near) {
      _nears++;
      _combo = max(0, _combo - 1);
      _comboMeter = min(1.0, 0.25 + _combo * 0.08);
      final gain = 16 + _floors + _combo * 2;
      _score += gain;
      _hint = context.l10n.stackNearHint(gain, _floors);
      _showFeedback(context.l10n.stackNearCallout(gain));
      AudioManager().playMerge(tierNumber: _tier);
      unawaited(HapticService.instance.lightImpact());
    } else {
      _combo = 0;
      _comboMeter = max(0, _comboMeter - 0.25);
      final gain = 10 + _floors;
      _score += gain;
      _hint = context.l10n.stackEdgeCutHint(gain, _floors);
      _showFeedback(context.l10n.stackEdgeCutCallout(gain));
      AudioManager().playMerge(tierNumber: _tier);
      unawaited(HapticService.instance.selectionClick());
    }

    if (_score > _best) _best = _score;
    _checkFloorMilestones();
    // Kat etiketi sayaca eşit olmalı: tohum katlar 6..12 ve sayaç 12'den
    // başlar; bırakmada _floors++ sonrası yeni kat _floors'tur.
    // Eski `_floors + 1`, KAT 13'ü atlayıp etiketi sayaçtan 1 fazla
    // gösteriyordu (playtest S1).
    final floor = _floors;
    _tier = 1 + _rng.nextInt(5);
    _speed = min(360.0, _speed + 8 + (_floors > 10 ? 2 : 0));
    _phase = _Phase.ready;
    _moverX = _moverX.clamp(_moverW / 2, _arenaW - _moverW / 2);
    _stack.add(
      _Slab(
        center: center,
        width: width,
        tier: placedTier,
        floor: floor,
        perfect: perfect,
      ),
    );
    setState(() {});
  }

  void _fail(String why) {
    // Tur tamamlandı: iade hakkı biter (tekrar oynayıp hamlesiz
    // çıkmak da iade vermez — bayrak oturum ömründe kalır).
    _moveMade = true;
    _phase = _Phase.failed;
    _failedAt = DateTime.now();
    _hint = why;
    _paused = false;
    _shake = 1.0;
    unawaited(HapticService.instance.heavyImpact());
    AudioManager().playLose();
    unawaited(_persist());
    setState(() {});
  }

  void _togglePause() {
    if (widget.prototypeVisualState) return;
    if (_phase == _Phase.failed || _phase == _Phase.falling) return;
    if (_paused) {
      _paused = false;
      _pausedByLifecycle = false;
      _pausedByHowToPlay = false;
      _shiftPauseDeadlines();
    } else {
      _paused = true;
      _pauseStartedAt ??= DateTime.now();
    }
    setState(() {});
  }

  /// Yardım sayfası görünürlük kancası (F3): sayfa açılırken oyunu
  /// duraklat, kapanırken yalnız bu kancayla duraklatıldıysa devam et.
  /// Sayaç koruması yok: ilk dialogun bariyeri ikinci dokunuşu yuttuğu
  /// için üst üste dialog pratikte mümkün değildir (1D notu).
  void _handleHowToPlayVisibilityChanged(bool visible) {
    // Kapanış geri çağrısı asenkron gelir (dialog future'ı): sayfa
    // açıkken rota dispose edildiyse setState çökmesin.
    if (!mounted) return;
    if (visible) {
      if (_phase == _Phase.failed ||
          _resultShown ||
          _paused ||
          widget.prototypeVisualState) {
        return;
      }
      _pausedByHowToPlay = true;
      _pauseStartedAt ??= DateTime.now();
      setState(() => _paused = true);
    } else {
      if (!_pausedByHowToPlay) return;
      _pausedByHowToPlay = false;
      // Yaşam döngüsü duraklatması sürüyorsa devam kararı `resumed`
      // kancasında verilir; son tarih kaydırma da o ana bırakılır.
      if (_pausedByLifecycle) return;
      _shiftPauseDeadlines();
      setState(() => _paused = false);
    }
  }

  void _showMilestone(String text) {
    _milestoneTimer?.cancel();
    setState(() => _milestone = text);
    _milestoneTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _milestone = null);
    });
  }

  void _showFeedback(String text) {
    _feedbackTimer?.cancel();
    setState(() => _feedback = text);
    _feedbackTimer = Timer(const Duration(milliseconds: 1150), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  void _checkFloorMilestones() {
    for (final m in const [5, 10, 15, 20, 30]) {
      if (_floors >= m && !_milestonesHit.contains(m)) {
        _milestonesHit.add(m);
        _showMilestone(context.l10n.stackMilestoneFloors(m));
        break;
      }
    }
  }

  String _statsLine() =>
      context.l10n.stackStatsLine(_floors, _perfects, _nears, _maxCombo);

  /// Oyun sonu: yeni sonuç ekranı. "TEKRAR OYNA" yeni turu başlatır,
  /// "ANA SAYFA"da eski sonuç akışı devam eder (bozulmadı).
  bool _useFreeze() {
    // F7: duraklatılmışken veya düşüş ortasında kullanım reddedilir
    // (stok `stockBonusWithResult` ile iade edilir).
    if (_paused || _phase != _Phase.ready) return false;
    AudioManager().triggerMediumHaptic();
    AudioManager().playMerge(tierNumber: _tier);
    setState(() {
      if (_stack.isNotEmpty) {
        _moverX = _stack.last.center;
      }
      _freezeUntil = DateTime.now().add(const Duration(seconds: 4));
      _activePowerFx = 'freeze';
      _powerFxLife = 1.0;
      _hint = context.l10n.stackMagnetHint;
    });
    _showMilestone(context.l10n.stackMagnetMilestone);
    return true;
  }

  bool _useWiden() {
    // F7: duraklatılmışken veya düşüş ortasında kullanım reddedilir.
    if (_paused || _phase != _Phase.ready || _arenaW <= 0) return false;
    AudioManager().triggerMediumHaptic();
    AudioManager().playMerge(tierNumber: _tier);
    setState(() {
      // F8: yalnız hareketli dilim genişler; yerleşmiş dilim
      // (`_stack.last.width`) kalıcı genişletilmez.
      _moverW = min(_arenaW * 0.86, _moverW + 40);
      _moverX = _moverX.clamp(_moverW / 2, _arenaW - _moverW / 2);
      _activePowerFx = 'widen';
      _powerFxLife = 1.0;
      _hint = context.l10n.stackWidenHint;
    });
    _showMilestone(context.l10n.stackWidenMilestone);
    return true;
  }

  bool _useSlowDrop() {
    // F7: duraklatılmışken veya düşüş ortasında kullanım reddedilir.
    if (_paused || _phase != _Phase.ready) return false;
    AudioManager().triggerMediumHaptic();
    AudioManager().playMerge(tierNumber: _tier);
    setState(() {
      // F8: `_speed`'e yazılmaz; yalnız 8 saniyelik geçici çarpan
      // (`_slowDropUntil`) kullanılır, süre bitince eski hız sürer.
      _slowDropUntil = DateTime.now().add(const Duration(seconds: 8));
      _activePowerFx = 'slows';
      _powerFxLife = 1.0;
      _hint = context.l10n.stackSlowHint;
    });
    _showMilestone(context.l10n.stackSlowMilestone);
    return true;
  }

  Future<void> _presentResult(int runId, {bool? won}) async {
    // F2: tur değiştiyse (ölüm sonrası dokunuşla `_restart` araya
    // girdiyse) eski turun sonucunu gösterme; yeni turun bayrağına
    // dokunma (Yuva deseni — `_restart` bayrağı sıfırladı).
    if (runId != _runId) return;
    if (!mounted) return;
    final score = _score;
    final best = _best;
    final bestCombo = _maxCombo;
    // S1#49: ödeme + liderlik (yalnız skor > 0) + görev kaydı + sonuç
    // ekranı finishRun() üzerinden (tek-ödeme korunur). Doğal bitiş
    // kulenin devrilmesidir (kayıp); `won` verilmezse kayıp başlığı
    // gösterilir.
    bool replay;
    try {
      replay = await finishRun(
        context,
        score: score,
        best: best,
        bestCombo: bestCombo,
        won: won ?? false,
        leaderboardMode: LeaderboardService.modeStack,
        leaderboardOnlyIfPositiveScore: true,
        // F2: sunum anında tur değişmişse dialog açılmadan `false` döner.
        stillValid: () => mounted && runId == _runId,
      );
    } catch (error) {
      // F4: finishRun fırlatırsa sonuçsuz takılma olmasın — bayrak
      // düşürülür, BİTİR/ölüm kenarı sonucu yeniden deneyebilir.
      // setState çağrılmaz: yeniden çizim `_edgeShowResult`'u tetikleyip
      // hatayı döngüye sokardı (Makara deseni).
      debugPrint('StackDropScreen: finishRun hatası: $error');
      if (runId == _runId) _resultShown = false;
      return;
    }
    // Bayat sunum: `stillValid` yüzünden dialog açılmadıysa veya tur
    // değiştiyse yeni turu pop/restart ile kirletme.
    if (runId != _runId) return;
    if (!mounted) return;
    if (!replay) {
      Navigator.of(context).maybePop();
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
  void _maybeRefundEnergy() {
    if (_energyRefunded) return;
    if (!widget.energyConsumed ||
        _moveMade ||
        _phase == _Phase.failed ||
        _resultShown) {
      return;
    }
    _energyRefunded = true;
    EnergyService.instance.addEnergy(1);
  }

  /// BİTİR: turu sessizce silmek yerine sonuç ekranını açar
  /// (playtest bulgu #10). Erken bitirmede başlık skora göre
  /// belirlenir (skor 0 ise kayıp başlığı).
  Future<void> _finishEarly() async {
    if (_resultShown) return;
    _resultShown = true;
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
    if (_phase == _Phase.failed && !_resultShown) _edgeShowResult();
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _maybeRefundEnergy();
      },
      child: ArcadeScreen(
      backgroundAsset: 'assets/design/backgrounds/stack_nightcity.webp',
      title: context.l10n.shopModeStackDrop,
      hint: _paused
          ? context.l10n.pausedStatusCaps
          : _elapsedSeconds < 15 && !widget.prototypeVisualState
          ? context.l10n.stackTutorialHint(_hint)
          : _hint,
      score: _score,
      best: _best,
      tag: context.l10n.stackTowerTag,
      tagColor: const Color(0xFFE52E2E),
      prototypeChrome: true,
      showStatusBar: true,
      prototypeModeChrome: true,
      statLabel: context.l10n.stackFloorStat,
      statValue: '$_floors',
      onRestart: _finishEarly,
      onPausePressed: _togglePause,
      onHowToPlayVisibilityChanged: _handleHowToPlayVisibilityChanged,
      overlay: _paused
          ? Positioned.fill(
              child: ColoredBox(
                color: LululuColors.carbonVoid.withValues(alpha: 0.72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.pausedStatusCaps,
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
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: SizedBox(
              width: 260,
              child: _StackBonusDock(
                items: [
                  stockBonusWithResult(
                    id: 'freeze',
                    label: context.l10n.shopPowerFreezeNameCaps,
                    asset: 'assets/icons2/crystal.png',
                    effect: () {
                      final applied = _useFreeze();
                      setState(() {});
                      return applied;
                    },
                  ),
                  stockBonusWithResult(
                    id: 'widen',
                    label: context.l10n.shopPowerWidenNameCaps,
                    asset: 'assets/icons2/block.png',
                    effect: () {
                      final applied = _useWiden();
                      setState(() {});
                      return applied;
                    },
                  ),
                  stockBonusWithResult(
                    id: 'slows',
                    label: context.l10n.shopPowerSlowNameCaps,
                    asset: 'assets/icons2/clock.png',
                    effect: () {
                      final applied = _useSlowDrop();
                      setState(() {});
                      return applied;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _ensure(constraints.maxWidth, constraints.maxHeight);
          final top = _stack.isEmpty ? null : _stack.last;
          final comboMessage =
              _feedback ?? (_combo > 0 ? 'KOMBO X$_combo' : null);
          final shakeX = _shake > 0 ? sin(_sway * 40) * 10 * _shake : 0.0;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _drop,
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(shakeX, 0),
                child: Stack(
                  children: [
                    // Near + perfect zone guides.
                    if (top != null && _phase == _Phase.ready && !_paused)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 84,
                        height: 2,
                        child: CustomPaint(
                          painter: _DashedLinePainter(
                            Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    for (var i = 0; i < _stack.length; i++)
                      _slabWidget(
                        _stack[i],
                        _baseY -
                            i * (slabH + 4) -
                            _cameraY +
                            sin(_sway + i * 0.35) * (i == 0 ? 0 : 1.2),
                        bounce: i == _stack.length - 1 ? _perfectBounce : 1.0,
                      ),
                    for (final cp in _cutPieces)
                      Positioned(
                        left: cp.center - cp.width / 2,
                        top: cp.y - _cameraY,
                        width: cp.width,
                        height: slabH,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: cp.life.clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: cp.rot,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _slabColors[
                                      (cp.tier - 1).clamp(
                                        0,
                                        _slabColors.length - 1,
                                      )],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE52E2E),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_activePowerFx != null && _powerFxLife > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: Opacity(
                              opacity: _powerFxLife.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 1.4 - 0.4 * _powerFxLife,
                                child: Container(
                                  width: 148,
                                  height: 148,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _activePowerFx == 'freeze'
                                          ? const Color(0xFF00E5FF)
                                          : _activePowerFx == 'widen'
                                          ? const Color(0xFFFFD700)
                                          : const Color(0xFF12B76A),
                                      width: 5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_activePowerFx == 'freeze'
                                                ? const Color(0xFF00E5FF)
                                                : _activePowerFx == 'widen'
                                                ? const Color(0xFFFFD700)
                                                : const Color(0xFF12B76A))
                                            .withValues(alpha: 0.55),
                                        blurRadius: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_phase != _Phase.failed)
                      _movingSlab(
                        (_phase == _Phase.falling ? _fallY : 16) - _cameraY,
                      ),
                    if (comboMessage != null)
                      Positioned(
                        top: 96,
                        left: 12,
                        right: 12,
                        child: IgnorePointer(
                          child: Center(
                            child: Text(
                              comboMessage,
                              style: GoogleFonts.bangers(
                                fontSize: 26,
                                height: 1,
                                letterSpacing: 0.78,
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
                    if (_milestone != null)
                      Positioned(
                        top: 8,
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
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _movingSlab(double top) {
    final insect = InsectTier.values[(_tier - 1).clamp(0, 7)];
    return Positioned(
      left: _moverX - _moverW / 2,
      top: top,
      width: _moverW,
      height: 40,
      child: _slabBox(
        insect,
        tier: _tier,
        moving: true,
        perfect: false,
        borderOverride: null,
      ),
    );
  }

  Widget _slabWidget(_Slab slab, double top, {double bounce = 1.0}) {
    if (top > _arenaH || top + slabH < -slabH) return const SizedBox.shrink();
    final insect = InsectTier.values[(slab.tier - 1).clamp(0, 7)];
    return Positioned(
      left: slab.center - slab.width / 2,
      top: top,
      width: slab.width,
      height: slabH,
      child: Transform.scale(
        scale: bounce,
        child: _slabBox(
          insect,
          tier: slab.tier,
          moving: false,
          perfect: slab.perfect,
          floor: slab.floor,
        ),
      ),
    );
  }

  Widget _slabBox(
    InsectTier insect, {
    required int tier,
    required bool moving,
    required bool perfect,
    int? floor,
    Color? borderOverride,
  }) {
    final fill = _slabColors[(tier - 1).clamp(0, _slabColors.length - 1)];
    final prototype = widget.prototypeVisualState;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(moving ? 11 : 9),
        border: perfect
            ? Border.all(
                color: const Color(0xFF00C853),
                width: 2.5,
              )
            : borderOverride == null
            ? null
            : Border.all(
                color: borderOverride,
                width: moving && prototype ? 2.5 : 2,
              ),
        boxShadow: moving
            ? [
                const BoxShadow(
                  color: Color(0x59000000),
                  offset: Offset(0, 6),
                  blurRadius: 14,
                ),
              ]
            : [
                if (perfect)
                  const BoxShadow(
                    color: Color(0xB300C853),
                    blurRadius: 14,
                  ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(moving ? 11 : 9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: moving ? 36 : 31,
                      child: Image.asset(
                        'assets/bugs/tier${tier.clamp(1, 13)}_hd${tier.clamp(1, 13) == 5 ? '.webp' : '.png'}',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            StickerImage(assetPath: insect.assetPath),
                      ),
                    ),
                    if (!moving && floor != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.stackFloorLabel(floor),
                        style: GoogleFonts.baloo2(
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xA6141B2A),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 4,
              child: ColoredBox(color: Color(0x29000000)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StackBonusDock extends StatelessWidget {
  const _StackBonusDock({required this.items});

  final List<ModeBonus> items;

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: 20),
            _StackBonusButton(item: items[index]),
          ],
        ],
      ),
    ),
  );
}

class _StackBonusButton extends StatelessWidget {
  const _StackBonusButton({required this.item});

  final ModeBonus item;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: item.onTap != null,
    label: context.l10n.boosterCountLabel(item.label, item.count),
    child: GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: item.count > 0 ? 1 : 0.55,
        child: SizedBox(
          width: 66,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(6),
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
                        child: Image.asset(
                          item.asset,
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: 7,
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
                          '${item.count}',
                          style: GoogleFonts.nunito(
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
                const SizedBox(height: 3),
                Text(
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + 5, size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
