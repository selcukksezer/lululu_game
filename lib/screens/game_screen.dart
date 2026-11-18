import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../models/campaign_level.dart';
import '../models/hisir_character.dart';
import '../models/insect_tier.dart';
import '../physics/physics_engine.dart';
import '../services/adaptive_quality_scaler.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/haptic_service.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../theme/lululu_theme.dart';
import '../widgets/bonus_fx.dart';
import '../widgets/game_arena_painter.dart';
import 'result_screen.dart';

class _MergeJuicePopup {
  final int id;
  final Offset position;
  final String text;
  final Color color;

  const _MergeJuicePopup({
    required this.id,
    required this.position,
    required this.text,
    required this.color,
  });
}

class GameScreen extends StatefulWidget {
  final CampaignLevel level;

  /// Hub play: drop until the jar overflows. Campaign keeps move goals.
  final bool arcade;

  /// `true` ise bu ekrana giriş `openGameMode` üzerinden 1 enerji
  /// tüketerek yapıldı; hiç hamle yapılmadan çıkılırsa enerji iade
  /// edilir. Doğrudan rota ve kampanya girişlerinde `false` kalır.
  final bool energyConsumed;

  /// Static mid-game sample matching the HTML prototype; capture tests only.
  final bool prototypeVisualState;

  const GameScreen({
    super.key,
    required this.level,
    this.arcade = false,
    this.energyConsumed = false,
    @visibleForTesting this.prototypeVisualState = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CircularPhysicsEngine? _engine;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  late CampaignLevel _currentLevel;
  final progress = ProgressManager();

  // In-Game States
  int _score = 0;
  int _remainingMoves = 25;
  int _comboCount = 0;
  double _comboTimeRemaining = 0;
  String? _comboBreakToast;
  Timer? _comboBreakTimer;
  Timer? _hisirTimer;
  Timer? _hisirHideTimer;
  bool _hisirVisible = false;
  double _hisirXFraction = 0.5;
  DateTime? _hisirTapSuppressUntil;
  bool _dropHadMerge = false;
  InsectTier _currentDropperTier = InsectTier.cone;
  InsectTier _nextDropperTier = InsectTier.helmet;
  InsectTier _highestTierUnlocked = InsectTier.cone;

  double _dropperX = 200.0;
  bool _isDropping = false;
  bool _isFinished = false;

  String _activeSpeechBubble = '';
  Timer? _speechTimer;
  Timer? _aydinlatTimer;
  bool _isAydinlatActive = false;

  // Bonus buton efekt kökenleri + tüketim nabzı (görsel katman).
  final GlobalKey _aydinlatKey = GlobalKey();
  final GlobalKey _terlikKey = GlobalKey();
  final GlobalKey _spreyKey = GlobalKey();
  final Set<String> _bonusPulse = {};

  final Map<String, ImageInfo?> _insectImages = {};
  final Map<ImageStream, ImageStreamListener> _insectImageListeners = {};

  int _mergeJuiceTick = 0;
  int _nextJuicePopupId = 0;
  final List<_MergeJuicePopup> _juicePopups = [];
  double _mergeFlashStrength = 0;
  Color _mergeFlashColor = Colors.transparent;
  double _screenShake = 0;
  Offset _shakeOffset = Offset.zero;

  /// Remaining hit-stop seconds; physics dt frozen while > 0 (tier ≥ 4).
  double _hitStopRemaining = 0;

  /// Classic Suika: must stay over line briefly before lose.
  static const _overflowGraceSec = 0.85;

  /// Tek birleşmede kazanılabilecek en yüksek puan (liderlik tavanı).
  static const int _maxSingleMergePoints = 250000;

  /// Kombo çarpanında hesaba katılan en yüksek kombo sayısı.
  static const int _comboScoreCap = 5;

  /// Düşürücü kelepçesi: önizleme yerleşmiş ölçekte çizilir, duvar payı
  /// doğma sırasındaki 1.06 taşmasını da kapsar.
  static const double _dropperSpawnScale = 1.0;
  static const double _dropperWallMargin = 4.0;

  /// Aydınlat bonusunun tek kullanımda verebileceği en yüksek toplam puan.
  static const int _aydinlatScoreCap = 2000;

  /// Süre sayacı işleyen gerçek bir hayatta kalma seviyesi mi?
  bool get _isSurvivalLevel =>
      !widget.arcade &&
      _currentLevel.isSurvival &&
      _currentLevel.timeLimitSeconds > 0;
  double _overflowAccum = 0;
  double _dangerPulse = 0;
  double _dangerProximity = 0;
  int _bestScore = 0;
  final _rng = Random();

  // Mechanics / features
  bool _paused = false;

  /// Yaşam döngüsü (arka plan) duraklatması bayrağı (Osmantus deseni):
  /// yardım diyaloğu açıkken arka plana alınmış oyun, diyalog kapanınca
  /// kendiliğinden başlamaz — DEVAM beklenir (B9). Yalnız açık devam
  /// yolları ([_togglePause] ile devam, [_restartLevel]) temizler.
  bool _pausedByLifecycle = false;

  /// Hamle-sonu değerlendirmesi duraklatma yüzünden ertelendiyse bekleyen
  /// turun kimliği ([_dropGen]); devamda [_flushPendingMovesEnd] okur.
  int? _pendingMovesEndGen;
  bool _waitingSettle = false;
  double _settleHold = 0;

  /// Bumps on each drop so a late hold/swap cannot race the promote callback.
  int _dropGen = 0;
  int _mergeTotal = 0;
  int _arcadeDropCount = 0;

  /// Bu oturumda yapılan düşürme sayısı. Yeniden başlatmada SIFIRLANMAZ:
  /// enerji iadesi, oturum boyunca hiç hamle yapılmamasına bakar.
  int _dropsMade = 0;

  static const ColorFilter _aydinlatBwFilter = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
  int _maxCombo = 0;
  InsectTier _peakTier = InsectTier.cone;

  /// Bu turda birleşmeyle ulaşılan en yüksek kademe; hamle-sonu hedef
  /// denetimi (hedef-kademe seviyeleri) bunu okur. [_peakTier] ile aynı
  /// tur sıfırlamasını paylaşır ama hedef denetimi için ayrı tutulur.
  InsectTier _runPeakTier = InsectTier.cone;

  /// Hayatta kalma seviyesinde kalan süre (saniye); süre dolunca zafer.
  double _survivalTimeRemaining = 0;

  /// Boss seviyesinde "duktur" repliği tur başına bir kez çalınır.
  bool _bossIntroPlayed = false;
  String? _milestoneToast;
  Timer? _milestoneTimer;
  Timer? _dropTimer;
  Timer? _movesEndTimer;
  Timer? _bonusPulseTimer;
  final Set<Timer> _juiceTimers = <Timer>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentLevel = widget.level;
    _survivalTimeRemaining = _currentLevel.timeLimitSeconds.toDouble();
    _remainingMoves = widget.arcade ? -1 : _currentLevel.allowedMoves;
    AudioManager().initialize();
    _preloadImages();
    _loadBest();
    _currentDropperTier = _rollDropTier();
    _nextDropperTier = _rollDropTier();
    if (widget.prototypeVisualState) {
      _currentDropperTier = InsectTier.cone;
      _nextDropperTier = InsectTier.helmet;
      _score = 0;
      _comboCount = 0;
      _comboTimeRemaining = 0;
      _mergeTotal = 0;
      _maxCombo = 0;
    }

    _ticker = createTicker(_onTick)..start();
    _scheduleHisir(const Duration(seconds: 15));
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _bestScore = LeaderboardService.instance.getBest(
        LeaderboardService.modeSuika,
      );
    });
  }

  /// Weighted bag like classic Suika — mostly tier 1–3.
  InsectTier _rollDropTier() {
    var r = _rng.nextDouble();
    if (widget.arcade) {
      final ramp = min(0.24, _arcadeDropCount * 0.003 + _score / 12000);
      if (r < ramp) {
        // Düşürücü tavanı Dansçı (tier 4): Diva (tier 5) doğrudan
        // düşürülmez, yalnızca birleşmeyle doğar.
        if (_arcadeDropCount >= 18 || _score >= 2400) {
          return InsectTier.dancer;
        }
        return InsectTier.fan;
      }
      r = (r - ramp) / (1 - ramp);
    }
    // Kampanyada zorluk (difficulty 1..10) üst kademe olasılığını kısar;
    // ölçek 1.0 iken eşikler taban dağılımla birebir aynıdır
    // (0.42 / 0.72 / 0.90). Arcade'de ölçek 1.0'dır.
    final scale = widget.arcade ? 1.0 : _currentLevel.highTierDropScale;
    final upperMass = 0.28 * scale;
    final lowerMass = 1.0 - upperMass;
    final coneThreshold = (0.42 / 0.72) * lowerMass;
    final fanThreshold = lowerMass + (0.18 / 0.28) * upperMass;
    if (r < coneThreshold) return InsectTier.cone;
    if (r < lowerMass) return InsectTier.helmet;
    if (r < fanThreshold) return InsectTier.fan;
    return InsectTier.dancer;
  }

  void _preloadImages() {
    for (final tier in InsectTier.values) {
      final imgStream = AssetImage(
        tier.assetPath,
      ).resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _insectImages[tier.assetPath] = info;
          });
        }
      });
      _insectImageListeners[imgStream] = listener;
      imgStream.addListener(listener);
    }
  }

  /// Top playfield band for combo / replik toasts — keep clear of circle.
  static const double _toastBandH = 48;

  double _computeArenaRadius(Size play) {
    if (widget.arcade) return min(play.width, play.height) / 2;
    final byW = play.width * 0.48;
    final byH = play.height * 0.445;
    return min(byW, byH).clamp(118.0, play.width * 0.51);
  }

  Offset _computeArenaCenter(Size play, double radius) {
    if (widget.arcade) return Offset(play.width / 2, play.height / 2);
    // Dropper sits ~45px above rim; toast band above that.
    const dropperClear = 48.0;
    final minTop = _toastBandH + dropperClear;
    var cy = play.height * 0.56;
    if (cy - radius < minTop) cy = radius + minTop;
    if (cy + radius > play.height - 6) {
      cy = play.height - 6 - radius;
    }
    return Offset(play.width / 2, cy);
  }

  void _syncArenaLayout(Size play) {
    if (play.width < 8 || play.height < 8) return;
    final radius = _computeArenaRadius(play);
    final center = _computeArenaCenter(play, radius);
    final arenaWidth = widget.arcade ? play.width : radius * 2;
    final arenaHeight = widget.arcade ? play.height : radius * 2;
    if (_engine == null) {
      _engine = CircularPhysicsEngine(
        arenaCenter: center,
        arenaRadius: radius,
        arenaWidth: arenaWidth,
        arenaHeight: arenaHeight,
        squareArena: widget.arcade || _currentLevel.squareArena,
      );
      _engine!.layoutBlocks(
        !widget.arcade && _currentLevel.hasObstacles ? 3 : 0,
      );
      _dropperX = center.dx;
    } else {
      _engine!.remountLayout(
        center,
        radius,
        newArenaWidth: arenaWidth,
        newArenaHeight: arenaHeight,
      );
    }
  }

  double get _dropperClampInset =>
      _currentDropperTier.radius * _dropperSpawnScale + _dropperWallMargin;

  double get _dropperMinX {
    final e = _engine!;
    return e.arenaBounds.left + _dropperClampInset;
  }

  double get _dropperMaxX {
    final e = _engine!;
    return e.arenaBounds.right - _dropperClampInset;
  }

  void _aimDropperAt(double localX) {
    if (_engine == null) return;
    final minX = _dropperMinX;
    final maxX = _dropperMaxX;
    _dropperX = minX > maxX ? (minX + maxX) / 2 : localX.clamp(minX, maxX);
  }

  void _restartLevel(CampaignLevel level) {
    _dropTimer?.cancel();
    _movesEndTimer?.cancel();
    _bonusPulseTimer?.cancel();
    _aydinlatTimer?.cancel();
    _speechTimer?.cancel();
    _milestoneTimer?.cancel();
    _comboBreakTimer?.cancel();
    _hisirTimer?.cancel();
    _hisirHideTimer?.cancel();
    for (final timer in _juiceTimers) {
      timer.cancel();
    }
    _juiceTimers.clear();
    setState(() {
      _dropGen++;
      _currentLevel = level;
      _score = 0;
      _remainingMoves = widget.arcade ? -1 : level.allowedMoves;
      _comboCount = 0;
      _comboTimeRemaining = 0;
      _comboBreakToast = null;
      _activeSpeechBubble = '';
      _isAydinlatActive = false;
      _isDropping = false;
      _dropHadMerge = false;
      _isFinished = false;
      _highestTierUnlocked = InsectTier.cone;
      _hitStopRemaining = 0;
      _screenShake = 0;
      _shakeOffset = Offset.zero;
      _mergeFlashStrength = 0;
      _overflowAccum = 0;
      _dangerProximity = 0;
      _paused = false;
      _pausedByLifecycle = false;
      _pendingMovesEndGen = null;
      _waitingSettle = false;
      _settleHold = 0;
      _mergeTotal = 0;
      _arcadeDropCount = 0;
      _maxCombo = 0;
      _peakTier = InsectTier.cone;
      _runPeakTier = InsectTier.cone;
      _survivalTimeRemaining = level.timeLimitSeconds.toDouble();
      _bossIntroPlayed = false;
      _milestoneToast = null;
      _hisirVisible = false;
      _juicePopups.clear();
      _bonusPulse.clear();
      _currentDropperTier = _rollDropTier();
      _nextDropperTier = _rollDropTier();
      _aimDropperAt(_dropperX);
      _engine?.squareArena = widget.arcade || level.squareArena;
      _engine?.layoutBlocks(!widget.arcade && level.hasObstacles ? 3 : 0);
      _engine?.clear();
    });
    _scheduleHisir(const Duration(seconds: 15));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Madde 35: giriş enerjisi tüketildiyse ve oyun bitmeden (zafer/yenilgi
    // olmadan) hiç hamle yapılmadan çıkıldıysa 1 enerjiyi iade et.
    // Kampanya ve doğrudan rota girişlerinde energyConsumed false'tur.
    if (widget.energyConsumed && !_isFinished && _dropsMade == 0) {
      EnergyService.instance.addEnergy(1);
    }
    AudioManager().stopAll();
    for (final entry in _insectImageListeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _insectImageListeners.clear();
    _ticker.dispose();
    _speechTimer?.cancel();
    _milestoneTimer?.cancel();
    _comboBreakTimer?.cancel();
    _aydinlatTimer?.cancel();
    _dropTimer?.cancel();
    _movesEndTimer?.cancel();
    _bonusPulseTimer?.cancel();
    for (final timer in _juiceTimers) {
      timer.cancel();
    }
    _juiceTimers.clear();
    _hisirTimer?.cancel();
    _hisirHideTimer?.cancel();
    super.dispose();
  }

  /// Arka plan / ön plan geçişleri (B9, Osmantus deseni): arka planda
  /// oyun duraklatılır ve kaplama gösterilir; dönüşte kendiliğinden
  /// başlamaz, DEVAM beklenir ([_pausedByLifecycle] bayrağı, yardım
  /// diyaloğu kapanışının bile tek başına başlatmasını engeller).
  /// Duvar-saati kaydırma gerekmez: hayatta
  /// kalma / taşma / kombo saatleri dt ile işler ve [_paused] kapısına
  /// takılır; tek duvar-saati oyun kararı [_movesEndTimer] ise
  /// duraklatmada ertelenir ([_pendingMovesEndGen]).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || widget.prototypeVisualState || _isFinished) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Bayrak, oyun zaten duraklatılmış olsa da (örn. yardım diyaloğu
        // açıkken arka plana alınma) kurulur: dönüşte diyalog kapanışı
        // tek başına başlatmasın, DEVAM beklensin.
        _pausedByLifecycle = true;
        if (!_paused) {
          setState(() => _paused = true);
        }
        break;
      case AppLifecycleState.resumed:
        // Bilerek boş: yaşam döngüsü duraklatması yalnız DEVAM ile
        // açılır; elle duraklatılmış oyun da kendiliğinden başlamaz.
        break;
    }
  }

  // Settle gate is only `_waitingSettle` (with timeout). Do NOT also require
  // engine.isSettled — pile micro-jiggle was soft-locking the next drop forever.
  bool get _canDrop =>
      !_isDropping && !_isFinished && !_paused && !_waitingSettle;

  void _onTick(Duration elapsed) {
    if (_engine == null) return;
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    double dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    if (dt > 0.033) dt = 0.033;
    AdaptiveQualityScaler.instance.recordFrameMs(dt * 1000);

    // Hit-stop: freeze physics integration briefly; juice/shake still tick.
    double physicsDt = dt;
    if (_hitStopRemaining > 0) {
      _hitStopRemaining = max(0, _hitStopRemaining - dt);
      physicsDt = 0;
    }

    if (!_isFinished && !_paused) {
      final mergeEvents = _engine!.update(physicsDt);
      if (mergeEvents.isNotEmpty) {
        _handleMerges(mergeEvents);
      }

      _dangerProximity = _engine!.dangerProximity;
      _dangerPulse += dt * (4 + _dangerProximity * 8);
      if (_comboTimeRemaining > 0) {
        _comboTimeRemaining = max(0, _comboTimeRemaining - dt);
        if (_comboTimeRemaining == 0 && _comboCount >= 2) {
          _breakCombo(context.l10n.comboTimeoutReason);
        }
      }

      if (_waitingSettle) {
        _settleHold += dt;
        // Unlock when calm, or hard timeout so a stuck bounce never blocks drops.
        if ((_engine!.isSettled && _settleHold >= 0.04) ||
            _settleHold >= 0.38) {
          _waitingSettle = false;
          _settleHold = 0;
          if (!_dropHadMerge) _breakCombo(context.l10n.comboMissReason);
        }
      }

      // Hayatta kalma: süre dolunca zafer (duraklatmada sayaç durur).
      if (_isSurvivalLevel) {
        _survivalTimeRemaining = max(0, _survivalTimeRemaining - dt);
        if (_survivalTimeRemaining <= 0) {
          _triggerVictory();
        }
      }

      if (_engine!.isOverflowing) {
        _overflowAccum += dt;
        if (_overflowAccum >= _overflowGraceSec) {
          _triggerDefeat();
        }
      } else {
        _overflowAccum = max(0, _overflowAccum - dt * 1.8);
      }
    }

    _decayMergeJuice(dt);

    if (mounted) setState(() {});
  }

  /// Tier 2+: short hit-stop; tier 4+ 30–50ms (scales with tier).
  void _triggerHitStop(int tier) {
    if (tier < 2) return;
    final ms = tier >= 4
        ? (30 + (tier - 4) * 4).clamp(30, 50)
        : (12 + tier * 4).clamp(12, 28);
    _hitStopRemaining = max(_hitStopRemaining, ms / 1000.0);
  }

  Color _juiceOverlayColor(InsectTier tier) {
    if (tier.tier >= 7) return LululuColors.cyberFuchsia;
    if (tier.tier >= 5) return LululuColors.coralFlare;
    if (tier.tier >= 4) return LululuColors.liquidGold;
    return LululuColors.warningSolar;
  }

  void _decayMergeJuice(double dt) {
    if (_mergeFlashStrength > 0) {
      _mergeFlashStrength = max(0, _mergeFlashStrength - dt * 2.8);
    }
    if (_screenShake > 0) {
      final rand = Random();
      _shakeOffset = Offset(
        (rand.nextDouble() - 0.5) * _screenShake * 14,
        (rand.nextDouble() - 0.5) * _screenShake * 14,
      );
      _screenShake = max(0, _screenShake - dt * 3.6);
      if (_screenShake <= 0.02) {
        _screenShake = 0;
        _shakeOffset = Offset.zero;
      }
    }
  }

  void _playMergeJuice(MergeEvent event, int combo, int pointsGained) {
    final tierBoost = event.tier.tier * 0.012;
    final juiceColor = _juiceOverlayColor(event.tier);
    _mergeFlashStrength = min(0.55, 0.18 + tierBoost + combo * 0.04);
    _mergeFlashColor = juiceColor;
    _screenShake = max(
      _screenShake,
      min(0.18, 0.05 + combo * 0.02 + tierBoost * 0.5),
    );
    // Soft local blast — strong values launched the pile into the air.
    final blast = 4.5 + combo * 1.4 + event.tier.tier * 0.45;
    _engine?.applyMergeBlast(event.x, event.y, blast);
    _engine?.spawnParticles(
      event.x,
      event.y,
      juiceColor,
      count: 8 + combo * 4 + event.tier.tier * 2,
    );
    _triggerHitStop(event.tier.tier);
    _mergeJuiceTick++;

    final popupId = _nextJuicePopupId++;
    _juicePopups.add(
      _MergeJuicePopup(
        id: popupId,
        position: Offset(event.x, event.y),
        text: combo >= 2 ? '+$pointsGained x$combo' : '+$pointsGained',
        color: juiceColor,
      ),
    );
    late final Timer juiceTimer;
    juiceTimer = Timer(const Duration(milliseconds: 950), () {
      _juiceTimers.remove(juiceTimer);
      if (!mounted) return;
      setState(() => _juicePopups.removeWhere((p) => p.id == popupId));
    });
    _juiceTimers.add(juiceTimer);

    unawaited(_triggerMergeVibration(combo, event.tier.tier));
  }

  /// Birleşme titreşimi: tek kapılı yol — [HapticService.onMerge] hem
  /// `vibrationEnabled` kapısına hem test ortamına saygı duyar, özel
  /// titreşim desteği yoksa hafif/orta/ağır dokunuş yedeğine düşer (H1).
  /// Eski kapısız `Vibration.vibrate` + `triggerHaptic` karışımı
  /// kaldırıldı; ölçekleme (kombo/kademe) serviste korunur.
  Future<void> _triggerMergeVibration(int combo, int tier) async {
    await HapticService.instance.onMerge(tier: tier, combo: combo);
  }

  void _handleMerges(List<MergeEvent> mergeEvents) {
    // Zafer, karedeki TÜM birleşmeler skorlandıktan sonra tetiklenir;
    // yoksa aynı karedeki diğer birleşmelerin skoru kaybolurdu.
    var victoryMet = false;
    for (final event in mergeEvents) {
      final nextTier = event.tier;
      _dropHadMerge = true;
      if (_comboTimeRemaining > 0 && _comboCount > 0) {
        _comboCount++;
      } else {
        _comboCount = 1;
      }
      _comboTimeRemaining = 1.8;

      // Combo heat: longer chains score harder, but the combo multiplier
      // counts at most [_comboScoreCap] so a single merge can never pass
      // the [_maxSingleMergePoints] ceiling.
      final effectiveCombo = min(_comboCount, _comboScoreCap);
      final heat = 1.0 + min(0.85, (effectiveCombo - 1) * 0.12);
      final pointsGained = min(
        _maxSingleMergePoints,
        (nextTier.scoreValue * effectiveCombo * heat).round(),
      );
      _score += pointsGained;
      _mergeTotal++;
      if (_comboCount > _maxCombo) _maxCombo = _comboCount;

      if (nextTier.tier > _highestTierUnlocked.tier) {
        _highestTierUnlocked = nextTier;
      }
      if (nextTier.tier > _runPeakTier.tier) {
        _runPeakTier = nextTier;
      }
      if (nextTier.tier > _peakTier.tier) {
        _peakTier = nextTier;
        _showMilestone(nextTier);
        _playMilestoneOneShot(nextTier);
      }

      unawaited(ProgressManager.instance.unlockTier(nextTier.tier));
      unawaited(ProgressManager.instance.recordTaskProgress('merge'));
      if (_comboCount >= 2) {
        unawaited(
          ProgressManager.instance.recordTaskProgress(
            'combo',
            absoluteValue: _comboCount,
          ),
        );
      }

      unawaited(
        AudioManager().playMerge(tier: nextTier, comboCount: _comboCount),
      );
      if (_comboCount >= 3) {
        AudioManager().triggerHeavyHaptic();
      }
      // Büyük kombo eşiği zincir başına bir kez çalınır.
      if (_comboCount == 8) {
        unawaited(AudioManager().playKanka());
      }

      _playMergeJuice(event, _comboCount, pointsGained);
      _showSpeechBubble(nextTier.viralReplik);

      // Check Victory Condition (deferred until every merge is scored).
      if (widget.arcade) continue;
      if (_currentLevel.objectiveType == ObjectiveType.mergeTargetTier &&
          _currentLevel.targetTier != null &&
          nextTier.tier >= _currentLevel.targetTier!.tier) {
        victoryMet = true;
      } else if (_currentLevel.objectiveType == ObjectiveType.reachScore &&
          _score >= _currentLevel.targetScore) {
        victoryMet = true;
      }
    }
    if (victoryMet) _triggerVictory();
  }

  void _breakCombo(String reason) {
    final hadVisibleCombo = _comboCount >= 2;
    _comboCount = 0;
    _comboTimeRemaining = 0;
    if (!hadVisibleCombo) return;

    _comboBreakTimer?.cancel();
    _comboBreakToast = context.l10n.comboBreakToast(reason);
    _comboBreakTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _comboBreakToast = null);
    });
  }

  void _showSpeechBubble(String text, {int durationSeconds = 3}) {
    _speechTimer?.cancel();
    setState(() => _activeSpeechBubble = text);
    _speechTimer = Timer(Duration(seconds: durationSeconds), () {
      if (mounted) setState(() => _activeSpeechBubble = '');
    });
  }

  void _onDropperDrag(DragUpdateDetails details) {
    if (_engine == null || _isDropping || _isFinished || _paused) return;
    setState(() => _aimDropperAt(details.localPosition.dx));
  }

  /// Tap = aim at finger X + drop (drag still aims without forcing release).
  void _onDropperTap(TapUpDetails details) {
    if (_engine == null || _isFinished || _paused) return;
    final suppressUntil = _hisirTapSuppressUntil;
    if (suppressUntil != null && DateTime.now().isBefore(suppressUntil)) {
      return;
    }
    setState(() => _aimDropperAt(details.localPosition.dx));
    _dropInsect();
  }

  void _dropInsect() {
    if (_engine == null || !_canDrop) return;
    // Hayatta kalmada sınır süredir, hamle değil.
    if (!widget.arcade && !_isSurvivalLevel && _remainingMoves <= 0) return;

    final gen = ++_dropGen;
    setState(() {
      _isDropping = true;
      _dropHadMerge = false;
      if (!widget.arcade && !_isSurvivalLevel) _remainingMoves--;
    });

    final dropY = _engine!.arenaBounds.top + 18;
    _engine!.addBody(_currentDropperTier, _dropperX, dropY);
    // Enerji iadesi sayacı (madde 35): düşürme anında sayılır, zamanlayıcı
    // geri çağrısında değil — 280 ms içinde çıkılsa bile hamle sayılır.
    _dropsMade++;

    AudioManager().playDrop();
    AudioManager().triggerHaptic();
    if (!widget.arcade && _currentLevel.isBossLevel && !_bossIntroPlayed) {
      _bossIntroPlayed = true;
      unawaited(AudioManager().playDuktur());
    }

    _dropTimer?.cancel();
    _dropTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || gen != _dropGen) return;
      setState(() {
        _arcadeDropCount++;
        _currentDropperTier = _nextDropperTier;
        _nextDropperTier = _rollDropTier();
        _aimDropperAt(_dropperX);
        _isDropping = false;
        _waitingSettle = true;
        _settleHold = 0;
      });

      if (!widget.arcade && !_isSurvivalLevel && _remainingMoves <= 0) {
        _movesEndTimer?.cancel();
        _movesEndTimer = Timer(const Duration(seconds: 2), () {
          if (!mounted || _isFinished || gen != _dropGen) return;
          // Duraklatma (elle / diyalog / arka plan) sürerken tur sonu
          // karara bağlanmaz: devamda [_flushPendingMovesEnd] okur (B9).
          if (_paused) {
            _pendingMovesEndGen = gen;
            return;
          }
          if (_hasMetObjective()) {
            _triggerVictory();
          } else {
            _triggerDefeat();
          }
        });
      }
    });
  }

  void _togglePause() {
    if (_isFinished) return;
    // Devama geçişte yaşam döngüsü bayrağı temizlenir (Osmantus deseni):
    // DEVAM / YENİDEN BAŞLAT / OYUNU BİTİR hep bu yoldan geçer.
    if (_paused) _pausedByLifecycle = false;
    setState(() => _paused = !_paused);
  }

  /// Duraklatma kaplamasındaki DEVAM: duraklatmayı açar, ertelenmiş
  /// hamle-sonu değerlendirmesi varsa hemen karara bağlar (B9). Yalnızca
  /// DEVAM bu yoldan geçer; YENİDEN BAŞLAT / OYUNU BİTİR bekleyen
  /// değerlendirmeyi ateşlemeden [_togglePause] kullanır.
  void _resumeFromPause() {
    if (_isFinished || !_paused) return;
    _togglePause();
    _flushPendingMovesEnd();
  }

  /// Ertelenmiş hamle-sonu değerlendirmesini (varsa) çalıştırır.
  void _flushPendingMovesEnd() {
    final gen = _pendingMovesEndGen;
    _pendingMovesEndGen = null;
    if (gen == null || !mounted || _isFinished || gen != _dropGen) return;
    if (_hasMetObjective()) {
      _triggerVictory();
    } else {
      _triggerDefeat();
    }
  }

  void _showMilestone(InsectTier tier) {
    _milestoneTimer?.cancel();
    setState(() => _milestoneToast = context.l10n.milestoneToast(tier.title));
    _milestoneTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _milestoneToast = null);
    });
  }

  /// Hışır Suika'da: tier dışı sürpriz hedef (Selçuk, 2026-11-18).
  /// Belirdiğinde "mezarına sıçtığım" der; dokunulursa +150 bonus.
  void _scheduleHisir(Duration delay) {
    _hisirTimer?.cancel();
    _hisirTimer = Timer(delay, _showHisir);
  }

  void _showHisir() {
    // Bağlı değilse (dispose sonrası) zamanlama yapılmaz: aksi hâlde
    // ölü durumda her 20 saniyede bir yeniden zamanlanan timer sızar (D4).
    if (!mounted) return;
    if (_engine == null || _isFinished || _paused) {
      _scheduleHisir(const Duration(seconds: 20));
      return;
    }
    setState(() {
      _hisirVisible = true;
      _hisirXFraction = 0.15 + _rng.nextDouble() * 0.7;
    });
    unawaited(AudioManager().playMezarinaSiktigim());
    _hisirHideTimer?.cancel();
    _hisirHideTimer = Timer(const Duration(seconds: 7), () {
      if (mounted) setState(() => _hisirVisible = false);
    });
    _scheduleHisir(Duration(seconds: 40 + _rng.nextInt(31)));
  }

  void _onHisirTapDown(TapDownDetails _) {
    // Aynı dokunuşun böcek düşürmesini engelle (500 ms).
    _hisirTapSuppressUntil =
        DateTime.now().add(const Duration(milliseconds: 500));
    if (!_hisirVisible) return;
    _hisirHideTimer?.cancel();
    setState(() {
      _hisirVisible = false;
      _score += 150;
    });
  }

  /// Milestone anına ek viral tek-seferlik ses (mevcut akışa ek, opt-in):
  /// Diva'ya ilk ulaşışta "sinyal", zirve tier'lere (12+) ilk ulaşışta
  /// (büyük birleşme) "mezarına" repliği. Ses ayarlarına metotlar saygı duyar.
  void _playMilestoneOneShot(InsectTier tier) {
    if (tier == InsectTier.diva) {
      unawaited(AudioManager().playDivaSinyal());
    } else if (tier.tier >= 12) {
      unawaited(AudioManager().playMezarinaSiktigim());
    }
  }

  int _calculateStars() {
    if (_score >= _currentLevel.star3Score) return 3;
    if (_score >= _currentLevel.star2Score) return 2;
    if (_score >= _currentLevel.star1Score) return 1;
    return 0;
  }

  /// Arcade yenilgisinde yıldız, oyun öncesi rekora oranla verilir ve
  /// 2'yi geçemez: yenilgi ekranı asla 3 yıldız göstermez. Rekor henüz
  /// yüklenmemişse (0) sıfırdan büyük skor 1 yıldız sayılır.
  int _defeatArcadeStars() {
    if (_score <= 0) return 0;
    if (_bestScore <= 0) return 1;
    final ratio = _score / _bestScore;
    if (ratio >= 0.9) return 2;
    if (ratio >= 0.6) return 1;
    return 0;
  }

  /// Hamleler bitince hedefe bakılır: hedef-kademe seviyesinde bu turda
  /// ulaşılan en yüksek kademe ([_runPeakTier]) şarttır; skor seviyesinde
  /// mevcut yıldız şartı korunur.
  bool _hasMetObjective() {
    switch (_currentLevel.objectiveType) {
      case ObjectiveType.mergeTargetTier:
        final target = _currentLevel.targetTier;
        if (target == null) return _calculateStars() >= 1;
        return _runPeakTier.tier >= target.tier;
      case ObjectiveType.reachScore:
      case ObjectiveType.survivalTimer:
        return _calculateStars() >= 1;
    }
  }

  Future<void> _triggerVictory() async {
    if (_isFinished) return;
    _isFinished = true;
    _pendingMovesEndGen = null;

    // Yıldız gerçek eşiklere bırakılır: hedef karşılansa bile skor yıldız
    // eşiğinin altındaysa 0 gösterilir (dürüst skor, garanti yok).
    final stars = _calculateStars();
    final earnedCoins = ResultScoring.coinsFor(_score);
    // recordLevelResult yalnız yıldız ARTIŞI kadar öder (starGain * 50);
    // önceki yıldız KAYIT ÖNCESİ okunmalıdır (kayıt haritayı günceller).
    final previousStars =
        widget.arcade ? 0 : progress.getStarCount(_currentLevel.id);
    final starGain = widget.arcade ? 0 : max(0, stars - previousStars);
    final starCoins = starGain * 50;
    final totalCoins =
        widget.arcade ? earnedCoins : max(earnedCoins, starCoins);
    // Ödenen toplam = starCoins + extraCoins = totalCoins: gösterilen
    // tutar ile ödenen tutar birebir uyuşur.
    final extraCoins = earnedCoins - starCoins;

    AudioManager().playWin();
    unawaited(AudioManager().playLululuNakarat());
    unawaited(_submitSuikaScore());
    if (!mounted) return;
    // S1#49: ödeme + görev kaydı + sonuç ekranı finishRun() üzerinden;
    // kampanya ödemesi (recordLevelResult + fark coini) settle kapaması
    // içinde, eski unawaited sırasıyla aynen yapılır. Liderlik gönderimi
    // _submitSuikaScore'da kalır (ensureLoaded + rekor tazeleme).
    final replay = await finishRun(
      context,
      score: _score,
      best: _bestScore,
      coins: totalCoins,
      stars: stars,
      bestScore: max(_score, _bestScore),
      bestCombo: max(1, _maxCombo),
      merges: _mergeTotal,
      awaitSettle: false,
      settle: () async {
        if (widget.arcade) {
          if (earnedCoins > 0) {
            unawaited(ProgressManager.instance.addCoins(earnedCoins));
          }
        } else {
          unawaited(
            progress.recordLevelResult(
              levelId: _currentLevel.id,
              score: _score,
              stars: stars,
              victory: true,
            ),
          );
          if (extraCoins > 0) {
            unawaited(ProgressManager.instance.addCoins(extraCoins));
          }
        }
      },
    );
    if (!mounted) return;
    if (replay) {
      _restartLevel(_currentLevel);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _triggerDefeat() async {
    if (_isFinished) return;
    _isFinished = true;
    _pendingMovesEndGen = null;

    final earnedCoins = ResultScoring.coinsFor(_score);

    AudioManager().playLose();
    unawaited(_submitSuikaScore());
    // Yenilgi asla 3 yıldız göstermez: arcade'de rekora oranla (en çok 2),
    // kampanyada eşik yıldızı 2 ile sınırlanır.
    final stars = widget.arcade
        ? _defeatArcadeStars()
        : min(2, _calculateStars());
    // S1#49: ödeme + görev kaydı + sonuç ekranı finishRun() üzerinden
    // (ateşle-unut ödeme, eski unawaited davranışı). Liderlik gönderimi
    // _submitSuikaScore'da kalır.
    final replay = await finishRun(
      context,
      score: _score,
      best: _bestScore,
      coins: earnedCoins,
      stars: stars,
      bestScore: max(_score, _bestScore),
      bestCombo: max(1, _maxCombo),
      merges: _mergeTotal,
      // Yenilgi başlığı skordan bağımsızdır: pes etme / taşma / hamle
      // bitimi skor > 0 olsa da zafer başlığı göstermez (B1).
      won: false,
      awaitSettle: false,
    );
    if (!mounted) return;
    if (replay) {
      _restartLevel(_currentLevel);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _submitSuikaScore() async {
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance.submitScore('suika', _score);
    final best = LeaderboardService.instance.getBest(
      LeaderboardService.modeSuika,
    );
    if (mounted && best > _bestScore) {
      setState(() => _bestScore = best);
    }
  }

  /// Bonus butonu sarma: önce kullanım efekti (bloklamaz), sonra mevcut
  /// bonus mantığı. Buton tüketim nabzıyla söner/küçülür (görsel).
  void _useBonusWithFx({
    required String bonusId,
    required GlobalKey key,
    required VoidCallback run,
  }) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(box.size.center(Offset.zero))
        : MediaQuery.of(context).size.center(Offset.zero);
    unawaited(playBonusFx(context, bonusId: bonusId, origin: origin));
    setState(() => _bonusPulse.add(bonusId));
    _bonusPulseTimer?.cancel();
    _bonusPulseTimer = Timer(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _bonusPulse.remove(bonusId));
    });
    run();
  }

  // Mega Booster: Aydınlat Hele! — F16 airstrike + grayscale flash.
  void _useAydinlatMegaBonus() {
    if (_engine == null ||
        progress.aydinlatCount <= 0 ||
        _isAydinlatActive ||
        _paused ||
        _isFinished) {
      return;
    }
    setState(() {
      progress.aydinlatCount--;
      _isAydinlatActive = true;
      _screenShake = max(_screenShake, 0.22);
    });

    unawaited(AudioManager().playF16Sfx());
    final initialBlast = _engine!.f16Bombardment(maxCount: 3);
    final initialAward = initialBlast.length * 180;
    if (initialAward > 0) {
      _score += initialAward;
    }
    _showSpeechBubble(
      context.l10n.speechAydinlat,
      durationSeconds: 3,
    );

    unawaited(progress.persistBoosters());

    _aydinlatTimer?.cancel();
    _aydinlatTimer = Timer(const Duration(milliseconds: 480), () {
      if (!mounted) return;
      if (_isFinished) {
        setState(() => _isAydinlatActive = false);
        return;
      }
      AudioManager().playAydinlatBeam();
      final cleared = _engine!.executeAydinlatAirstrike();
      // Tek kullanımın toplam bonusu tavanı aşamaz.
      final delayedAward = min(
        cleared * 350,
        max(0, _aydinlatScoreCap - initialAward),
      );

      setState(() {
        _score += delayedAward;
        if (_score > _bestScore) _bestScore = _score;
        _isAydinlatActive = false;
      });
    });
  }

  // Booster: Terlik (Anne Terliği / Sarsıntı)
  void _useSlipperPowerup() {
    if (_engine == null ||
        progress.slipperCount <= 0 ||
        _paused ||
        _isFinished ||
        _engine!.bodies.isEmpty) {
      return;
    }
    setState(() {
      progress.slipperCount--;
      _screenShake = max(_screenShake, 0.2);
    });
    unawaited(progress.persistBoosters());

    _engine!.crushTargetInsect(targetX: _dropperX);
    _score += 250;
    if (_score > _bestScore) _bestScore = _score;

    AudioManager().playSlipper();
    _showSpeechBubble(context.l10n.speechSlipper, durationSeconds: 2);
  }

  // Booster: Raid Spray
  void _useSprayPowerup() {
    if (_engine == null ||
        progress.sprayCount <= 0 ||
        _paused ||
        _isFinished ||
        _engine!.bodies.isEmpty) {
      return;
    }
    setState(() => progress.sprayCount--);
    unawaited(progress.persistBoosters());

    final vaporized = _engine!.sprayVaporizeSmallest(2);
    _score += vaporized * 300;

    AudioManager().playSpray();
    _showSpeechBubble(context.l10n.speechSpray, durationSeconds: 2);
  }

  Future<void> _showInfoDialog() async {
    // Yardım açıkken fizik/sayaç durur: önceden duraklatılmamışsa
    // duraklat, diyalog kapanınca devam ettir (B4-suika) — araya arka
    // plan duraklatması girdiyse ([_pausedByLifecycle]) devam ettirme,
    // DEVAM beklensin (B9).
    final wasPaused = _paused;
    if (!_isFinished && !wasPaused) {
      setState(() => _paused = true);
    }
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF141A29),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: LululuColors.liquidGold.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.l10n.howToTitle,
                  style: GoogleFonts.exo2(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.liquidGold,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  ctx.l10n.howToBody,
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  button: true,
                  label: ctx.l10n.understoodButton,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFCF3F), LululuColors.liquidGold],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: LululuColors.liquidGold.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        ctx.l10n.understoodButton,
                        style: GoogleFonts.bangers(
                          fontSize: 18,
                          color: const Color(0xFF4A2E00),
                          letterSpacing: 1,
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
    } finally {
      if (mounted && !_isFinished && !wasPaused && !_pausedByLifecycle) {
        setState(() => _paused = false);
        _flushPendingMovesEnd();
      }
    }
  }

  Widget _buildGameHud() {
    if (widget.arcade) {
      return _buildArcadeGameHud();
    }
    if (MediaQuery.sizeOf(context).width <= 430) {
      return _buildCompactGameHud();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: Row(
        children: [
          // Duraklat butonu
          Semantics(
            button: true,
            label: context.l10n.pause,
            child: GestureDetector(
            onTap: _togglePause,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2336),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: const Icon(
                Icons.pause_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          ),
          const SizedBox(width: 8),

          // Skor kutusu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            constraints: const BoxConstraints(minWidth: 88),
            decoration: BoxDecoration(
              color: const Color(0xFF080B12).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: LululuColors.liquidGold.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.gameScoreLabel,
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.liquidGold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '$_score',
                  style: GoogleFonts.bangers(
                    fontSize: 20,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Rekor kutusu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            constraints: const BoxConstraints(minWidth: 80),
            decoration: BoxDecoration(
              color: const Color(0xFF080B12).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.gameBestLabel,
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.mutedTitanium,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${_bestScore > 0 ? _bestScore : ResultScoring.defaultBestScore}',
                  style: GoogleFonts.bangers(
                    fontSize: 20,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Sıradaki böcek kutusu
          Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 8, 4),
            decoration: BoxDecoration(
              color: const Color(0xFF080B12).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.gameNextLabel,
                  style: GoogleFonts.exo2(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.mutedTitanium,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(width: 6),
                Image.asset(
                  _nextDropperTier.assetPath,
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.bug_report,
                    color: LululuColors.liquidGold,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Info (?) butonu
          Semantics(
            button: true,
            label: context.l10n.helpButtonLabel,
            child: GestureDetector(
            onTap: _showInfoDialog,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1B2336),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              alignment: Alignment.center,
              child: Text(
                '?',
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.liquidGold,
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  static const _protoPanel = Color(0xD9080B12);

  Widget _buildArcadeGameHud() {
    final best = _bestScore > 0 ? _bestScore : ResultScoring.defaultBestScore;
    final hudRow = Row(
      children: [
        Semantics(
          button: true,
          label: context.l10n.pause,
          child: GestureDetector(
            onTap: _togglePause,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xD1080B12),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x59000000), offset: Offset(0, 3)),
                ],
              ),
              child: const Icon(
                Icons.pause_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildArcadeScoreBox(context.l10n.gameScoreLabel, '$_score', 104),
        const SizedBox(width: 8),
        _buildArcadeScoreBox(context.l10n.gameBestLabel, _formatArcadeScore(best), 84),
        const Spacer(),
        Container(
          width: 90,
          height: 50,
          padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
          decoration: BoxDecoration(
            color: _protoPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.gameNextLabel,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.mutedTitanium,
                      letterSpacing: 0.8,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              Image.asset(
                _nextDropperTier.assetPath,
                width: 19.3,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.bug_report,
                  color: LululuColors.liquidGold,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: context.l10n.helpButtonLabel,
          child: GestureDetector(
          onTap: _showInfoDialog,
          behavior: HitTestBehavior.opaque,
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
                BoxShadow(color: Color(0x66000000), offset: Offset(0, 3)),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              '?',
              style: TextStyle(
                fontFamily: 'Baloo 2',
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w800,
                color: LululuColors.liquidGold,
              ),
            ),
          ),
        ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              height: 50.5,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 406,
                  height: 50.5,
                  child: hudRow,
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SizedBox(
            height: 50.5,
            child: hudRow,
          ),
        );
      },
    );
  }

  Widget _buildArcadeScoreBox(String label, String value, double width) {
    return Container(
      width: width,
      height: 50.5,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _protoPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x73FFB800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              height: 1.5,
              color: LululuColors.liquidGold,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: 'Baloo 2',
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatArcadeScore(int score) {
    final digits = score.toString().split('');
    for (var index = digits.length - 3; index > 0; index -= 3) {
      digits.insert(index, '.');
    }
    return digits.join();
  }

  Widget _buildCompactGameHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Semantics(
              button: true,
              label: context.l10n.pause,
              child: GestureDetector(
              onTap: _togglePause,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2336),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Icon(
                    Icons.pause_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: _buildCompactStatCard(
              label: context.l10n.gameScoreLabel,
              value: '$_score',
              accent: LululuColors.liquidGold,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: _buildCompactStatCard(
              label: context.l10n.gameBestLabel,
              value: '${_bestScore > 0 ? _bestScore : ResultScoring.defaultBestScore}',
              accent: LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF080B12).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.gameNextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: LululuColors.mutedTitanium,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Image.asset(
                    _nextDropperTier.assetPath,
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.bug_report,
                      color: LululuColors.liquidGold,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF080B12).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.exo2(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: accent,
              letterSpacing: 0.4,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.bangers(
                fontSize: 18,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF05070C).withValues(alpha: 0.85),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF141A29),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.gamePausedTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  fontSize: 28,
                  color: LululuColors.liquidGold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.pausedScoreLine(_score),
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: LululuColors.mutedTitanium,
                ),
              ),
              const SizedBox(height: 18),
              // DEVAM ET (Green)
              Semantics(
                button: true,
                label: context.l10n.resumeButtonCaps,
                child: GestureDetector(
                  onTap: _resumeFromPause,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF26E075),
                          Color(0xFF00C853),
                          Color(0xFF009624),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C853).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      context.l10n.resumeButtonCaps,
                      style: GoogleFonts.bangers(
                        fontSize: 20,
                        color: const Color(0xFF04140A),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // YENİDEN BAŞLA
              Semantics(
                button: true,
                label: context.l10n.restartLevelButton,
                child: GestureDetector(
                  onTap: () {
                    _togglePause();
                    _restartLevel(_currentLevel);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFCF3F),
                          LululuColors.liquidGold,
                          Color(0xFFF59E00),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      context.l10n.restartLevelButton,
                      style: GoogleFonts.bangers(
                        fontSize: 20,
                        color: const Color(0xFF4A2E00),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // OYUNU BİTİR (pes et): yenilgi akışı — kilit açmaz,
              // yıldız kaydetmez; zafer sayılmaz (B1).
              Semantics(
                button: true,
                label: context.l10n.finishGameButton,
                child: GestureDetector(
                  onTap: () {
                    _togglePause();
                    _triggerDefeat();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      context.l10n.finishGameButton,
                      style: GoogleFonts.bangers(
                        fontSize: 18,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ANA SAYFA
              Semantics(
                button: true,
                label: context.l10n.navHome,
                child: GestureDetector(
                  onTap: () {
                    final nav = Navigator.maybeOf(context);
                    if (nav != null && nav.canPop()) {
                      nav.maybePop();
                    } else {
                      _pausedByLifecycle = false;
                      setState(() => _paused = false);
                      _flushPendingMovesEnd();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      context.l10n.navHome,
                      style: GoogleFonts.bangers(
                        fontSize: 18,
                        color: LululuColors.mutedTitanium,
                        letterSpacing: 1,
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
  }

  /// Hayatta kalma sayacı ve/veya boss göstergesi (kampanya HUD'unun altı;
  /// arcade'de ve sıradan seviyelerde boş kutu döndürür).
  Widget _buildObjectiveBanner() {
    final showTimer = _isSurvivalLevel;
    final showBoss = !widget.arcade && _currentLevel.isBossLevel;
    if (!showTimer && !showBoss) return const SizedBox.shrink();

    final remaining = _survivalTimeRemaining.ceil();
    final urgent = showTimer && remaining <= 10;
    final timerText =
        '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showTimer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF080B12).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: urgent
                      ? LululuColors.mysticRuby
                      : LululuColors.liquidGold.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: urgent
                        ? LululuColors.mysticRuby
                        : LululuColors.liquidGold,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    timerText,
                    style: GoogleFonts.bangers(
                      fontSize: 17,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    context.l10n.surviveLabel,
                    style: GoogleFonts.exo2(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.mutedTitanium,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          if (showTimer && showBoss) const SizedBox(width: 8),
          if (showBoss)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF080B12).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: LululuColors.coralFlare.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.bossLabel(_currentLevel.bossName ?? 'BOSS'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.exo2(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: LululuColors.coralFlare,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (_currentLevel.bossSpecialHazard != null)
                    Text(
                      _currentLevel.bossSpecialHazard!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.exo2(
                        fontSize: 9,
                        color: LululuColors.mutedTitanium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassicLayout() {
    return SafeArea(
      bottom: !widget.arcade,
      child: Padding(
        padding: widget.arcade
            ? const EdgeInsets.fromLTRB(0, 4, 0, 0)
            : const EdgeInsets.fromLTRB(10, 4, 10, 0),
        child: Column(
          children: [
            if (!widget.arcade)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.chapterLabel(_currentLevel.id),
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: LululuColors.liquidGold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      // Bölüm alt başlığı dile göre (EN verisi
                      // CampaignLevel.titleEn'de hazır; bulgu #17).
                      _currentLevel.titleFor(
                        Localizations.localeOf(context),
                      ),
                      style: GoogleFonts.exo2(
                        fontSize: 11,
                        color: LululuColors.mutedTitanium,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            _buildGameHud(),
            _buildObjectiveBanner(),
            if (!widget.prototypeVisualState) _buildEvolutionStrip(),
            SizedBox(height: widget.arcade ? 6 : 4),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.arcade ? 14 : 0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      widget.arcade ? 16 : 20,
                    ),
                    border: Border.all(
                      color: widget.arcade
                          ? const Color(0xFF70543A)
                          : Colors.white.withValues(alpha: 0.14),
                      width: widget.arcade ? 1.5 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: widget.arcade ? 0.25 : 0.5,
                        ),
                        blurRadius: widget.arcade ? 8 : 16,
                        offset: Offset(0, widget.arcade ? 2 : 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildPlayField(),
                ),
              ),
            ),
            _buildBoosterBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEvolutionStrip() {
    final tiers = InsectTier.values.take(8).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xBF080B12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x24FFFFFF)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < tiers.length; i++) ...[
              if (i > 0)
                const ExcludeSemantics(
                  child: Text(
                    '›',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0x73FFFFFF),
                    ),
                  ),
                ),
              Opacity(
                opacity: tiers[i].tier <= _highestTierUnlocked.tier
                    ? 1.0
                    : 0.35,
                child: Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tiers[i].tier <= _highestTierUnlocked.tier
                        ? tiers[i].color.withValues(alpha: 0.28)
                        : Colors.transparent,
                    border: tiers[i].tier == _highestTierUnlocked.tier
                        ? Border.all(color: LululuColors.liquidGold, width: 1.2)
                        : null,
                  ),
                  child: Image.asset(
                    tiers[i].assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, _) {
                      // Sessiz boşluk yerine yer tutucu + hata kaydı.
                      debugPrint(
                        '[GameScreen] Kademe görseli yüklenemedi: '
                        '${tiers[i].assetPath} ($error)',
                      );
                      return Container(
                        color: tiers[i].color.withValues(alpha: 0.28),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          size: 12,
                          color: LululuColors.mutedTitanium,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArcadeLayout() {
    final topInset = max(MediaQuery.paddingOf(context).top, 35.375);
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Column(
        children: [
          _buildArcadeGameHud(),
          if (!widget.prototypeVisualState) _buildEvolutionStrip(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                widget.prototypeVisualState ? 12 : 8,
                14,
                0,
              ),
              child: _buildArcadeField(),
            ),
          ),
          _buildBoosterBar(),
        ],
      ),
    );
  }

  Widget _buildArcadeField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x75121826), Color(0x8F080B12)],
        ),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x24FFFFFF), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 12,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3A4358), Color(0xFF232B3E)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            bottom: widget.prototypeVisualState ? 0 : 12,
            child: _buildPlayField(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget hudAndPlay = widget.arcade
        ? _buildArcadeLayout()
        : _buildClassicLayout();

    if (_isAydinlatActive) {
      hudAndPlay = ColorFiltered(
        colorFilter: _aydinlatBwFilter,
        child: hudAndPlay,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: LululuColors.carbonVoid,
        body: Transform.translate(
          offset: _shakeOffset,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: widget.arcade ? 0.94 : 0.62,
                  child: Image.asset(
                    'assets/design/backgrounds/suika_kitchen.webp',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Image.asset(
                      _currentLevel.backgroundPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, _) {
                        // Sessiz boşluk yerine yer tutucu + hata kaydı.
                        debugPrint(
                          '[GameScreen] Seviye arka planı yüklenemedi: '
                          '${_currentLevel.backgroundPath} ($error)',
                        );
                        return Container(
                          color: LululuColors.carbonVoid,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.bug_report_rounded,
                            size: 72,
                            color: Color(0x33FFFFFF),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: widget.arcade
                    ? const DecoratedBox(
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
                            stops: [0, 0.24, 0.76, 1],
                          ),
                        ),
                      )
                    : Container(
                        color: LululuColors.carbonVoid.withValues(alpha: 0.5),
                      ),
              ),
              Positioned.fill(child: hudAndPlay),
              if (_hisirVisible) _buildHisirOverlay(),
              if (widget.prototypeVisualState)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 35.375,
                  child: IgnorePointer(child: _PrototypeStatusBar()),
                ),
              if (_paused && !_isFinished) _buildPauseOverlay(),
              if (_mergeFlashStrength > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: _mergeFlashColor.withValues(
                        alpha: _mergeFlashStrength * 0.35,
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

  /// Hışır sürpriz hedefi: konuşma balonu + kasketli dede görseli.
  Widget _buildHisirOverlay() {
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      left: _hisirXFraction * size.width - 55,
      top: size.height * 0.22,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onHisirTapDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xE6111923),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LululuColors.liquidGold,
                  width: 1,
                ),
              ),
              child: const Text(
                'Mezarına sıçtığım!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Image.asset(
              HisirCharacter.assetPath,
              width: 110,
              height: 110,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  /// Combo-style floating text in the empty band above the arena.
  Widget _buildTopToastBand() {
    final danger = _dangerProximity > 0.65 && !_isFinished;
    final speech = _activeSpeechBubble.isNotEmpty;
    final milestone = _milestoneToast != null;
    final comboBreak = _comboBreakToast != null;
    final combo = _comboCount >= 2;

    String? text;
    Color color = LululuColors.liquidGold;
    Color glow = LululuColors.coralFlare;
    double size = 22;
    Object? animKey;

    if (danger) {
      text = _overflowAccum > 0
          ? context.l10n.overflowingCountdown(
              '${(max(0, _overflowGraceSec - _overflowAccum) * 10).ceil() / 10}',
            )
          : context.l10n.nearLineWarning;
      color = LululuColors.mysticRuby;
      glow = LululuColors.warningSolar;
      size = 20;
      animKey = 'danger';
    } else if (speech) {
      text = _activeSpeechBubble;
      color = LululuColors.liquidGold;
      glow = LululuColors.cyberFuchsia;
      size = 18;
      animKey = _activeSpeechBubble;
    } else if (milestone) {
      text = _milestoneToast;
      color = LululuColors.coralFlare;
      glow = LululuColors.liquidGold;
      size = 20;
      animKey = _milestoneToast;
    } else if (comboBreak) {
      text = _comboBreakToast;
      color = LululuColors.coralFlare;
      glow = LululuColors.liquidGold;
      size = 18;
      animKey = _comboBreakToast;
    } else if (combo) {
      text = context.l10n.comboToast(_comboCount);
      color = LululuColors.liquidGold;
      glow = LululuColors.coralFlare;
      size = 26 + min(_comboCount, 6) * 1.5;
      animKey = 'combo_$_mergeJuiceTick';
    }

    if (text == null) return const SizedBox.shrink();

    final flashOut = combo || milestone || comboBreak;
    final comboLine = Text(
      text,
      key: ValueKey(animKey),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.bangers(
        fontSize: size,
        color: color,
        letterSpacing: 0.6,
        height: 1.05,
        shadows: [
          Shadow(color: glow, blurRadius: 10),
          const Shadow(
            color: LululuColors.carbonVoid,
            blurRadius: 4,
            offset: Offset(1, 2),
          ),
        ],
      ),
    );
    if (widget.prototypeVisualState) {
      return Align(alignment: Alignment.center, child: comboLine);
    }

    var line = comboLine
        .animate()
        .fadeIn(duration: 80.ms)
        .scale(
          begin: const Offset(0.35, 0.35),
          curve: Curves.elasticOut,
          duration: 420.ms,
        );

    if (danger || combo) {
      line = line.animate().shake(hz: 3.2, rotation: 0.03);
    }
    if (flashOut) {
      line = line.animate().fadeOut(delay: 700.ms, duration: 320.ms);
    }

    return Align(alignment: Alignment.center, child: line);
  }

  Widget _buildPlayField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final play = Size(constraints.maxWidth, constraints.maxHeight);
        _syncArenaLayout(play);
        if (_engine == null) return const SizedBox.expand();

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (!widget.prototypeVisualState)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: GameArenaPainter(
                      engine: _engine!,
                      insectImages: _insectImages,
                      dangerPulse: _dangerPulse,
                      dangerProximity: _dangerProximity,
                      transparentSquareArena: widget.arcade,
                      coneSpriteScale: 1,
                      dropperX: _dropperX,
                      currentDropperTier: _currentDropperTier,
                      showDropperPreview:
                          !_isFinished && !_paused && !_isDropping,
                      dangerLineLabel: context.l10n.dangerLineLabel,
                      dangerAlertLabel: context.l10n.dangerAlertLabel,
                    ),
                  ),
                ),
              ),
            if (widget.arcade || widget.prototypeVisualState)
              const Positioned(
                left: 2,
                right: 2,
                top: 8,
                height: 3,
                child: IgnorePointer(
                  child: CustomPaint(painter: _PrototypeDropLinePainter()),
                ),
              ),
            if (widget.prototypeVisualState) ...[
              Positioned(
                left: 118.4,
                top: 677.1,
                width: 53.8,
                height: 101.7,
                child: IgnorePointer(
                  child: Image.asset(
                    InsectTier.helmet.assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: 213.9,
                top: 677.1,
                width: 53.8,
                height: 101.7,
                child: IgnorePointer(
                  child: Image.asset(
                    InsectTier.helmet.assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                left: 171.0,
                top: 687.3,
                width: 44.2,
                height: 113.1,
                child: IgnorePointer(
                  child: Image.asset(
                    InsectTier.cone.assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: _onDropperDrag,
                onTapUp: _onDropperTap,
              ),
            ),
            // Score popups stay near merge point (arena-local juice).
            for (final popup in _juicePopups)
              Positioned(
                left: popup.position.dx - 44,
                top: popup.position.dy - 28,
                child: IgnorePointer(
                  child:
                      Text(
                            popup.text,
                            key: ValueKey('juice_${popup.id}'),
                            style: GoogleFonts.bangers(
                              fontSize: popup.text.contains('x') ? 22 : 18,
                              color: popup.color,
                              shadows: const [
                                Shadow(
                                  color: LululuColors.carbonVoid,
                                  blurRadius: 6,
                                  offset: Offset(1, 2),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 70.ms)
                          .scale(
                            begin: const Offset(0.45, 0.45),
                            end: const Offset(1, 1),
                            curve: Curves.elasticOut,
                            duration: 280.ms,
                          )
                          .moveY(
                            begin: 0,
                            end: -42,
                            duration: 540.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .fadeOut(delay: 340.ms, duration: 200.ms),
                ),
              ),
            // Replik / combo / uyarı — üst boş band (çemberin üstü).
            if (!widget.prototypeVisualState)
              Positioned(
                top: 2,
                left: 8,
                right: 8,
                height: _toastBandH,
                child: IgnorePointer(child: _buildTopToastBand()),
              ),
          ],
        );
      },
    );
  }

  int _shownCount(int real, int sample) =>
      widget.prototypeVisualState ? sample : real;

  Widget _buildBoosterBar() {
    return Padding(
      padding: widget.arcade
          ? const EdgeInsets.fromLTRB(14, 8, 14, 10)
          : const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Row(
        mainAxisAlignment: widget.arcade
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceEvenly,
        children: [
          _buildPowerBtn(
            key: _spreyKey,
            label: context.l10n.boosterRaidLabel,
            asset: 'assets/design/ui/powerup_raid_spreyi.png',
            count: _shownCount(progress.sprayCount, 3),
            pulse: _bonusPulse.contains('Raid Sprey'),
            onTap: () => _useBonusWithFx(
              bonusId: 'Raid Sprey',
              key: _spreyKey,
              run: _useSprayPowerup,
            ),
          ),
          if (widget.arcade) const SizedBox(width: 20),
          _buildPowerBtn(
            key: _terlikKey,
            label: context.l10n.boosterShakeLabel,
            asset: 'assets/design/ui/powerup_terlik.png',
            count: _shownCount(progress.slipperCount, 2),
            pulse: _bonusPulse.contains('Terlik'),
            onTap: () => _useBonusWithFx(
              bonusId: 'Terlik',
              key: _terlikKey,
              run: _useSlipperPowerup,
            ),
          ),
          if (widget.arcade) const SizedBox(width: 20),
          _buildPowerBtn(
            key: _aydinlatKey,
            label: context.l10n.boosterLightLabel,
            asset: 'assets/design/ui/powerup_aydinlat.png',
            count: _shownCount(progress.aydinlatCount, 1),
            pulse: _bonusPulse.contains('Aydınlat Hele!'),
            onTap: () => _useBonusWithFx(
              bonusId: 'Aydınlat Hele!',
              key: _aydinlatKey,
              run: _useAydinlatMegaBonus,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerBtn({
    Key? key,
    required String label,
    required String asset,
    required int count,
    required VoidCallback onTap,
    bool pulse = false,
  }) {
    final enabled = count > 0;
    if (widget.arcade) {
      return _buildArcadePowerBtn(
        key: key,
        label: label,
        asset: asset,
        count: count,
        onTap: onTap,
        pulse: pulse,
        enabled: enabled,
      );
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.boosterCountLabel(label, count),
      child: GestureDetector(
        key: key,
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: pulse ? 0.35 : (enabled ? 1.0 : 0.45),
          duration: const Duration(milliseconds: 180),
          child: AnimatedScale(
            scale: pulse ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 86,
                  constraints: const BoxConstraints(minHeight: 82),
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2E3850), Color(0xFF1B2336)],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 46,
                        height: 46,
                        child: Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.auto_awesome_rounded,
                            color: LululuColors.liquidGold,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD8E0EE),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -4,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: LululuColors.cyberFuchsia,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: LululuColors.carbonVoid,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.exo2(
                        fontSize: 11,
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

  Widget _buildArcadePowerBtn({
    Key? key,
    required String label,
    required String asset,
    required int count,
    required VoidCallback onTap,
    required bool enabled,
    required bool pulse,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.boosterCountLabel(label, count),
      child: GestureDetector(
        key: key,
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedOpacity(
          opacity: pulse ? 0.35 : (enabled ? 1 : 0.45),
          duration: const Duration(milliseconds: 180),
          child: AnimatedScale(
            scale: pulse ? 0.85 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: SizedBox(
              width: 66,
              height: 63,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 2),
                      Container(
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
                        child: Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.auto_awesome_rounded,
                            color: LululuColors.liquidGold,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 9,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFD8E0EE),
                          letterSpacing: 0.18,
                        ),
                      ),
                    ],
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
                          BorderSide(color: Color(0xFF080B12), width: 2),
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
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
      ),
    );
  }
}

class _PrototypeStatusBar extends StatelessWidget {
  const _PrototypeStatusBar();

  @override
  Widget build(BuildContext context) {
    return const Stack(
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
              Icon(Icons.battery_full_rounded, size: 15, color: Colors.white),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrototypeDropLinePainter extends CustomPainter {
  const _PrototypeDropLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xBFE52E2E)
      ..style = PaintingStyle.fill;
    const dash = 9.0;
    const gap = 6.0;
    var x = 0.0;
    while (x < size.width) {
      final w = min(dash, size.width - x);
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
