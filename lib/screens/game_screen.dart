import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../models/campaign_level.dart';
import '../models/insect_tier.dart';
import '../physics/physics_engine.dart';
import '../services/adaptive_quality_scaler.dart';
import '../services/audio_manager.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../services/score_share_card.dart';
import '../theme/lululu_theme.dart';
import '../widgets/arena_prop_glb.dart';
import '../widgets/bonus_fx.dart';
import '../widgets/evolution_roadmap_bar.dart';
import '../widgets/game_arena_painter.dart';
import '../widgets/sticker_image.dart';
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

  const GameScreen({
    super.key,
    required this.level,
    this.arcade = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  CircularPhysicsEngine? _engine;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  late CampaignLevel _currentLevel;
  final progress = ProgressManager();

  // In-Game States
  int _score = 0;
  int _remainingMoves = 25;
  int _comboCount = 0;
  DateTime _lastMergeTime = DateTime.now();
  InsectTier _currentDropperTier = InsectTier.cone;
  InsectTier _nextDropperTier = InsectTier.helmet;
  InsectTier _highestTierUnlocked = InsectTier.cone;

  double _dropperX = 200.0;
  bool _isDropping = false;
  bool _isFinished = false;

  String _activeSpeechBubble = '';
  Timer? _speechTimer;
  bool _isAydinlatActive = false;

  // Bonus buton efekt kökenleri + tüketim nabzı (görsel katman).
  final GlobalKey _aydinlatKey = GlobalKey();
  final GlobalKey _terlikKey = GlobalKey();
  final GlobalKey _spreyKey = GlobalKey();
  final Set<String> _bonusPulse = {};

  final Map<String, ImageInfo?> _insectImages = {};

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
  double _overflowAccum = 0;
  double _dangerPulse = 0;
  double _dangerProximity = 0;
  int _bestScore = 0;
  final _rng = Random();

  // Mechanics / features
  bool _paused = false;
  bool _waitingSettle = false;
  double _settleHold = 0;
  InsectTier? _holdTier;
  /// Bumps on each drop so a late hold/swap cannot race the promote callback.
  int _dropGen = 0;
  int _mergeTotal = 0;

  static const ColorFilter _aydinlatBwFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);
  int _maxCombo = 0;
  InsectTier _peakTier = InsectTier.cone;
  String? _milestoneToast;
  Timer? _milestoneTimer;
  double _comboMeter = 0; // 0–1 visual decay of recent combo heat

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.level;
    _remainingMoves = widget.arcade ? -1 : _currentLevel.allowedMoves;
    AudioManager().initialize();
    _preloadImages();
    _loadBest();
    _currentDropperTier = _rollDropTier();
    _nextDropperTier = _rollDropTier();

    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _bestScore =
          LeaderboardService.instance.getBest(LeaderboardService.modeSuika);
    });
  }

  /// Weighted bag like classic Suika — mostly tier 1–3.
  InsectTier _rollDropTier() {
    final r = _rng.nextDouble();
    if (r < 0.42) return InsectTier.cone;
    if (r < 0.72) return InsectTier.helmet;
    if (r < 0.90) return InsectTier.fan;
    return InsectTier.dancer;
  }

  void _preloadImages() {
    for (final tier in InsectTier.values) {
      final imgStream = AssetImage(tier.assetPath).resolve(ImageConfiguration.empty);
      imgStream.addListener(
        ImageStreamListener((ImageInfo info, bool _) {
          if (mounted) {
            setState(() {
              _insectImages[tier.assetPath] = info;
            });
          }
        }),
      );
    }
  }

  /// Top playfield band for combo / replik toasts — keep clear of circle.
  static const double _toastBandH = 48;

  double _computeArenaRadius(Size play) {
    final byW = play.width * 0.48;
    final byH = play.height * 0.445;
    return min(byW, byH).clamp(118.0, play.width * 0.51);
  }

  Offset _computeArenaCenter(Size play, double radius) {
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
    if (_engine == null) {
      _engine = CircularPhysicsEngine(
        arenaCenter: center,
        arenaRadius: radius,
        squareArena: !widget.arcade && _currentLevel.squareArena,
      );
      _engine!.layoutBlocks(
        !widget.arcade && _currentLevel.hasObstacles ? 3 : 0,
      );
      _dropperX = center.dx;
    } else {
      _engine!.remountLayout(center, radius);
    }
  }

  double get _dropperMinX {
    final e = _engine!;
    return e.arenaCenter.dx - e.arenaRadius + 28;
  }

  double get _dropperMaxX {
    final e = _engine!;
    return e.arenaCenter.dx + e.arenaRadius - 28;
  }

  void _aimDropperAt(double localX) {
    if (_engine == null) return;
    _dropperX = localX.clamp(_dropperMinX, _dropperMaxX);
  }

  void _restartLevel(CampaignLevel level) {
    setState(() {
      _currentLevel = level;
      _score = 0;
      _remainingMoves = widget.arcade ? -1 : level.allowedMoves;
      _comboCount = 0;
      _isFinished = false;
      _highestTierUnlocked = InsectTier.cone;
      _hitStopRemaining = 0;
      _screenShake = 0;
      _shakeOffset = Offset.zero;
      _mergeFlashStrength = 0;
      _overflowAccum = 0;
      _dangerProximity = 0;
      _paused = false;
      _waitingSettle = false;
      _settleHold = 0;
      _holdTier = null;
      _mergeTotal = 0;
      _maxCombo = 0;
      _peakTier = InsectTier.cone;
      _comboMeter = 0;
      _milestoneToast = null;
      _currentDropperTier = _rollDropTier();
      _nextDropperTier = _rollDropTier();
      _engine?.squareArena = widget.arcade ? false : level.squareArena;
      _engine?.layoutBlocks(
        !widget.arcade && level.hasObstacles ? 3 : 0,
      );
      _engine?.clear();
    });
  }

  @override
  void dispose() {
    AudioManager().stopAll();
    _ticker.dispose();
    _speechTimer?.cancel();
    _milestoneTimer?.cancel();
    super.dispose();
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
      _comboMeter = max(0, _comboMeter - dt * 0.35);

      if (_waitingSettle) {
        _settleHold += dt;
        // Unlock when calm, or hard timeout so a stuck bounce never blocks drops.
        if ((_engine!.isSettled && _settleHold >= 0.04) ||
            _settleHold >= 0.38) {
          _waitingSettle = false;
          _settleHold = 0;
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
    _screenShake = max(_screenShake, min(0.18, 0.05 + combo * 0.02 + tierBoost * 0.5));
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
    Timer(const Duration(milliseconds: 950), () {
      if (!mounted) return;
      setState(() => _juicePopups.removeWhere((p) => p.id == popupId));
    });

    unawaited(_triggerMergeVibration(combo, event.tier.tier));
  }

  Future<void> _triggerMergeVibration(int combo, int tier) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) {
        AudioManager().triggerHaptic();
        return;
      }
      final duration = min(120, 28 + combo * 18 + tier * 4);
      await Vibration.vibrate(duration: duration);
      if (combo >= 3) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await Vibration.vibrate(duration: min(80, 20 + combo * 8));
      }
    } catch (_) {
      AudioManager().triggerHaptic();
    }
  }

  void _handleMerges(List<MergeEvent> mergeEvents) {
    for (final event in mergeEvents) {
      final nextTier = event.tier;
      final now = DateTime.now();
      if (now.difference(_lastMergeTime).inMilliseconds < 1800) {
        _comboCount++;
      } else {
        _comboCount = 1;
      }
      _lastMergeTime = now;

      // Combo heat: longer chains score harder.
      final heat = 1.0 + min(0.85, (_comboCount - 1) * 0.12);
      final pointsGained = (nextTier.scoreValue * _comboCount * heat).round();
      _score += pointsGained;
      _mergeTotal++;
      if (_comboCount > _maxCombo) _maxCombo = _comboCount;
      _comboMeter = min(1.0, 0.35 + _comboCount * 0.12);

      if (nextTier.tier > _highestTierUnlocked.tier) {
        _highestTierUnlocked = nextTier;
      }
      if (nextTier.tier > _peakTier.tier) {
        _peakTier = nextTier;
        _showMilestone(nextTier);
      }

      unawaited(
        AudioManager().playMerge(
          tier: nextTier,
          comboCount: _comboCount,
        ),
      );
      if (_comboCount >= 3) {
        AudioManager().triggerHeavyHaptic();
      }

      _playMergeJuice(event, _comboCount, pointsGained);
      _showSpeechBubble(nextTier.viralReplik);

      // Check Victory Condition
      if (widget.arcade) continue;
      if (_currentLevel.objectiveType == ObjectiveType.mergeTargetTier &&
          _currentLevel.targetTier != null &&
          nextTier.tier >= _currentLevel.targetTier!.tier) {
        _triggerVictory();
        return;
      } else if (_currentLevel.objectiveType == ObjectiveType.reachScore &&
          _score >= _currentLevel.targetScore) {
        _triggerVictory();
        return;
      }
    }
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
    setState(() => _aimDropperAt(details.localPosition.dx));
    _dropInsect();
  }

  void _dropInsect() {
    if (_engine == null || !_canDrop) return;
    if (!widget.arcade && _remainingMoves <= 0) return;

    final gen = ++_dropGen;
    setState(() {
      _isDropping = true;
      if (!widget.arcade) _remainingMoves--;
    });

    final dropY = _engine!.arenaCenter.dy - _engine!.arenaRadius + 18;
    _engine!.addBody(_currentDropperTier, _dropperX, dropY);

    AudioManager().playDrop();
    AudioManager().triggerHaptic();

    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || gen != _dropGen) return;
      setState(() {
        _currentDropperTier = _nextDropperTier;
        _nextDropperTier = _rollDropTier();
        _isDropping = false;
        _waitingSettle = true;
        _settleHold = 0;
      });

      if (!widget.arcade && _remainingMoves <= 0) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted || _isFinished) return;
          if (_calculateStars() >= 1) {
            _triggerVictory();
          } else {
            _triggerDefeat();
          }
        });
      }
    });
  }

  /// Tut = park current (or next-while-dropping). Slot doluysa swap.
  void _swapHold() {
    if (_isFinished || _paused) return;

    setState(() {
      if (_isDropping) {
        // In-flight piece already in arena — operate on the upcoming queue.
        if (_holdTier == null) {
          _holdTier = _nextDropperTier;
          _nextDropperTier = _rollDropTier();
        } else {
          final tmp = _nextDropperTier;
          _nextDropperTier = _holdTier!;
          _holdTier = tmp;
        }
      } else if (_holdTier == null) {
        _holdTier = _currentDropperTier;
        _currentDropperTier = _nextDropperTier;
        _nextDropperTier = _rollDropTier();
      } else {
        final tmp = _currentDropperTier;
        _currentDropperTier = _holdTier!;
        _holdTier = tmp;
      }
    });
    HapticFeedback.selectionClick();
    AudioManager().triggerHaptic();
  }

  void _togglePause() {
    if (_isFinished) return;
    setState(() => _paused = !_paused);
  }

  void _showMilestone(InsectTier tier) {
    _milestoneTimer?.cancel();
    setState(() => _milestoneToast = 'YENİ: ${tier.title}');
    _milestoneTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _milestoneToast = null);
    });
  }

  int _calculateStars() {
    if (_score >= _currentLevel.star3Score) return 3;
    if (_score >= _currentLevel.star2Score) return 2;
    if (_score >= _currentLevel.star1Score) return 1;
    return 0;
  }

  Future<void> _triggerVictory() async {
    if (_isFinished) return;
    _isFinished = true;

    final stars = max(1, _calculateStars());
    progress.recordLevelResult(
      levelId: _currentLevel.id,
      score: _score,
      stars: stars,
    );

    AudioManager().playWin();
    unawaited(_submitSuikaScore());
    // Önce yeni sonuç ekranı; "ANA SAYFA"da eski zafer akışı devam eder.
    final replay = await showGameResult(
      context,
      score: _score,
      coins: stars * 50,
      stars: stars,
    );
    if (!mounted) return;
    if (replay) {
      _restartLevel(_currentLevel);
    } else {
      _showVictoryModal(stars);
    }
  }

  Future<void> _triggerDefeat() async {
    if (_isFinished) return;
    _isFinished = true;

    AudioManager().playLose();
    unawaited(_submitSuikaScore());
    // Önce yeni sonuç ekranı; "ANA SAYFA"da eski yenilgi akışı devam eder.
    final replay = await showGameResult(
      context,
      score: _score,
      coins: 0,
      stars: _calculateStars(),
    );
    if (!mounted) return;
    if (replay) {
      _restartLevel(_currentLevel);
    } else {
      _showDefeatModal();
    }
  }

  Future<void> _submitSuikaScore() async {
    await LeaderboardService.instance.ensureLoaded();
    await LeaderboardService.instance
        .submitScore(LeaderboardService.modeSuika, _score);
    final best =
        LeaderboardService.instance.getBest(LeaderboardService.modeSuika);
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
    Timer(const Duration(milliseconds: 380), () {
      if (mounted) setState(() => _bonusPulse.remove(bonusId));
    });
    run();
  }

  // Mega Booster: Aydınlat Hele! — full grayscale then airstrike.
  void _useAydinlatMegaBonus() {
    if (_engine == null || progress.aydinlatCount <= 0 || _isAydinlatActive) {
      return;
    }
    setState(() {
      progress.aydinlatCount--;
      _isAydinlatActive = true;
    });

    AudioManager().playAydinlatVoice();
    _showSpeechBubble(
      'Kurban olduğum şuraları bir aydınlat hele!',
      durationSeconds: 4,
    );

    unawaited(progress.persistBoosters());

    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      AudioManager().playAydinlatBeam();
      final cleared = _engine!.executeAydinlatAirstrike();

      setState(() {
        _score += cleared * 350;
        _isAydinlatActive = false;
      });
    });
  }

  // Booster: Terlik
  void _useSlipperPowerup() {
    if (_engine == null || progress.slipperCount <= 0 || _engine!.bodies.isEmpty) return;
    setState(() => progress.slipperCount--);
    unawaited(progress.persistBoosters());

    final target = _engine!.bodies.first;
    target.isMarkedForRemoval = true;
    _score += 250;

    AudioManager().playSlipper();
    _showSpeechBubble('Şılapp! Terlik indi!', durationSeconds: 2);
  }

  // Booster: Raid Spray
  void _useSprayPowerup() {
    if (_engine == null || progress.sprayCount <= 0 || _engine!.bodies.isEmpty) return;
    setState(() => progress.sprayCount--);
    unawaited(progress.persistBoosters());

    final vaporized = _engine!.sprayVaporizeSmallest(2);
    _score += vaporized * 300;

    AudioManager().playSpray();
    _showSpeechBubble('Fısss! Raid tertemiz etti!', durationSeconds: 2);
  }

  @override
  Widget build(BuildContext context) {
    final stars = _calculateStars();

    Widget hudAndPlay = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
        child: Column(
          children: [
            _buildHeaderRow(),
            const SizedBox(height: 6),
            _buildGoalAndMovesRow(stars),
            const SizedBox(height: 4),
            _buildComboMeter(),
            const SizedBox(height: 4),
            EvolutionRoadmapBar(currentHighest: _highestTierUnlocked),
            const SizedBox(height: 6),
            _buildSideControlsRow(),
            const SizedBox(height: 4),
            Expanded(child: _buildPlayField()),
            _buildBoosterBar(),
          ],
        ),
      ),
    );

    if (_isAydinlatActive) {
      hudAndPlay = ColorFiltered(
        colorFilter: _aydinlatBwFilter,
        child: hudAndPlay,
      );
    }

    return Scaffold(
      backgroundColor: LululuColors.carbonVoid,
      body: Transform.translate(
        offset: _shakeOffset,
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.28,
                child: Image.asset(
                  _currentLevel.backgroundPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
            Positioned.fill(child: hudAndPlay),
            const Positioned(
              left: 10,
              bottom: 72,
              child: IgnorePointer(
                child: ArenaPropGlb(kind: ArenaPropKind.bee),
              ),
            ),
            if (_paused && !_isFinished)
              Positioned.fill(
                child: ColoredBox(
                  color: LululuColors.carbonVoid.withValues(alpha: 0.72),
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
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _togglePause,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LululuColors.liquidGold,
                            foregroundColor: LululuColors.carbonVoid,
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Text('DEVAM'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
    );
  }

  Widget _buildSideControlsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniIconBtn(
          icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          onTap: _togglePause,
        ),
        const Spacer(),
        _PieceSlot(
          label: 'SIRADAKİ',
          tier: _nextDropperTier,
          accent: _nextDropperTier.color,
        ),
        const SizedBox(width: 8),
        _PieceSlot(
          label: _holdTier == null ? 'TUT' : 'DEĞİŞ',
          tier: _holdTier,
          accent: LululuColors.cyberFuchsia,
          emptyHint: 'BOŞ',
          onTap: _swapHold,
        ),
      ],
    );
  }

  /// Combo-style floating text in the empty band above the arena.
  Widget _buildTopToastBand() {
    final danger = _dangerProximity > 0.65 && !_isFinished;
    final speech = _activeSpeechBubble.isNotEmpty;
    final milestone = _milestoneToast != null;
    final combo = _comboCount >= 2;

    String? text;
    Color color = LululuColors.liquidGold;
    Color glow = LululuColors.coralFlare;
    double size = 22;
    Object? animKey;

    if (danger) {
      text = _overflowAccum > 0
          ? 'TAŞIYOR! ${(max(0, _overflowGraceSec - _overflowAccum) * 10).ceil() / 10}s'
          : 'ÇİZGİYE YAKLAŞTIN';
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
    } else if (combo) {
      text = 'COMBO x$_comboCount!';
      color = LululuColors.liquidGold;
      glow = LululuColors.coralFlare;
      size = 26 + min(_comboCount, 6) * 1.5;
      animKey = 'combo_$_mergeJuiceTick';
    }

    if (text == null) return const SizedBox.shrink();

    final flashOut = combo || milestone;
    var line = Text(
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
    )
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
            Positioned.fill(
              child: CustomPaint(
                painter: GameArenaPainter(
                  engine: _engine!,
                  dropperX: _dropperX,
                  dropTier: _currentDropperTier,
                  isDropping: _isDropping,
                  insectImages: _insectImages,
                  dangerPulse: _dangerPulse,
                  dangerProximity: _dangerProximity,
                ),
              ),
            ),
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
                  child: Text(
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
                        duration: 420.ms,
                      )
                      .moveY(
                        begin: 0,
                        end: -42,
                        duration: 820.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .fadeOut(delay: 420.ms, duration: 280.ms),
                ),
              ),
            // Replik / combo / uyarı — üst boş band (çemberin üstü).
            Positioned(
              top: 2,
              left: 8,
              right: 8,
              height: _toastBandH,
              child: IgnorePointer(
                child: _buildTopToastBand(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBoosterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          return Row(
            children: [
              Expanded(
                child: _buildBoosterButton(
                  key: _aydinlatKey,
                  icon: '💡',
                  label: compact ? 'Aydınlat' : 'Aydınlat Hele!',
                  count: progress.aydinlatCount,
                  color: LululuColors.liquidGold,
                  pulse: _bonusPulse.contains('Aydınlat Hele!'),
                  onPressed: () => _useBonusWithFx(
                    bonusId: 'Aydınlat Hele!',
                    key: _aydinlatKey,
                    run: _useAydinlatMegaBonus,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBoosterButton(
                  key: _terlikKey,
                  icon: '🩴',
                  label: 'Terlik',
                  count: progress.slipperCount,
                  color: LululuColors.mysticRuby,
                  pulse: _bonusPulse.contains('Terlik'),
                  onPressed: () => _useBonusWithFx(
                    bonusId: 'Terlik',
                    key: _terlikKey,
                    run: _useSlipperPowerup,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildBoosterButton(
                  key: _spreyKey,
                  icon: '💨',
                  label: compact ? 'Raid' : 'Raid Sprey',
                  count: progress.sprayCount,
                  color: LululuColors.cyberFuchsia,
                  pulse: _bonusPulse.contains('Raid Sprey'),
                  onPressed: () => _useBonusWithFx(
                    bonusId: 'Raid Sprey',
                    key: _spreyKey,
                    run: _useSprayPowerup,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          button: true,
          label: 'Geri',
          child: IconButton(
            tooltip: 'Geri',
            icon: const Icon(Icons.arrow_back_ios_new, color: LululuColors.ink, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Column(
          children: [
            Text(
              widget.arcade ? 'SUİKA ARENA' : 'BÖLÜM ${_currentLevel.id}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: LululuColors.warningSolar,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              widget.arcade
                  ? 'Dokun veya kaydır · bırak'
                  : _currentLevel.chapterName,
              style: const TextStyle(fontSize: 11, color: LululuColors.mutedTitanium),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: LululuColors.spaceNavy,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LululuColors.darkObsidian),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'SKOR',
                style: GoogleFonts.fredoka(
                  fontSize: 9,
                  color: LululuColors.mutedTitanium,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_score',
                key: ValueKey('score_$_mergeJuiceTick'),
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.liquidGold,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.22, 1.22),
                    duration: 120.ms,
                    curve: Curves.easeOutBack,
                  )
                  .then()
                  .scale(
                    begin: const Offset(1.22, 1.22),
                    end: const Offset(1, 1),
                    duration: 180.ms,
                    curve: Curves.easeInOut,
                  ),
              Text(
                'EN ${max(_bestScore, _score) > 0 ? max(_bestScore, _score) : '—'}',
                style: GoogleFonts.exo2(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: LululuColors.mutedTitanium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalAndMovesRow(int stars) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: LululuColors.spaceNavy.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LululuColors.darkObsidian),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.arcade
                  ? (_dangerProximity > 0.5
                      ? 'Dikkat! Çizginin altında tut.'
                      : 'Dokun veya kaydır · aynılar birleşir')
                  : '🎯 ${_currentLevel.objectiveDescription}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _dangerProximity > 0.5
                    ? LululuColors.mysticRuby
                    : LululuColors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: List.generate(3, (i) {
              return Icon(
                i < stars ? Icons.star : Icons.star_border,
                size: 18,
                color: i < stars ? LululuColors.warningSolar : LululuColors.darkObsidian,
              );
            }),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: !widget.arcade && _remainingMoves <= 5
                  ? LululuColors.mysticRuby
                  : LululuColors.darkObsidian,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.arcade ? 'SONSUZ' : 'Atış: $_remainingMoves',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: LululuColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoosterButton({
    Key? key,
    required String icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onPressed,
    bool pulse = false,
  }) {
    return AnimatedOpacity(
      opacity: pulse ? 0.35 : 1,
      duration: const Duration(milliseconds: 180),
      child: AnimatedScale(
        scale: pulse ? 0.82 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            key: key,
            onPressed: count > 0 ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: LululuColors.ink,
              disabledBackgroundColor: color.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: LululuColors.warningSolar.withValues(alpha: 0.85),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 6,
              shadowColor: color.withValues(alpha: 0.55),
            ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '($count)',
                    style: const TextStyle(
                      fontSize: 9,
                      color: LululuColors.mutedTitanium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
        ),
      ),
    );
  }

  void _showVictoryModal(int stars) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: LululuColors.spaceNavy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: LululuColors.warningSolar, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BÖLÜM TAMAMLANDI!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.warningSolar,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Icon(
                      i < stars ? Icons.star : Icons.star_border,
                      size: 44,
                      color: i < stars ? LululuColors.warningSolar : LululuColors.darkObsidian,
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  'Skor: $_score',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: LululuColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ödül: +${stars * 50} 🪙',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: LululuColors.warningSolar),
                ),
                const SizedBox(height: 8),
                Text(
                  _statsLine(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: LululuColors.mutedTitanium),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    unawaited(
                      ScoreShareCard.instance.share(
                        modeTitle: widget.arcade ? 'Suika Arena' : _currentLevel.title,
                        score: _score,
                        line: _statsLine(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share_rounded, color: LululuColors.liquidGold),
                  label: const Text(
                    'PAYLAŞ KART',
                    style: TextStyle(
                      color: LululuColors.liquidGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _restartLevel(_currentLevel);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: LululuColors.ink,
                          side: const BorderSide(color: LululuColors.darkObsidian),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('TEKRAR 🔄'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (_currentLevel.id < 80) {
                            final nextLevel = CampaignDatabase.getLevel(_currentLevel.id + 1);
                            _restartLevel(nextLevel);
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LululuColors.liquidGold,
                          foregroundColor: LululuColors.carbonVoid,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('SONRAKİ ➡️', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('HARİTAYA DÖN 🗺️', style: TextStyle(color: LululuColors.mutedTitanium)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDefeatModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: LululuColors.carbonVoid,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: LululuColors.mysticRuby, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DUKTURU ARAYIN! 💀',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.mysticRuby,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '"Kurban olduğum böcekler taştı!"',
                  style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: LululuColors.mutedTitanium),
                ),
                const SizedBox(height: 16),
                Text(
                  'Skor: $_score',
                  style: const TextStyle(fontSize: 18, color: LululuColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  _statsLine(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: LululuColors.mutedTitanium),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    unawaited(
                      ScoreShareCard.instance.share(
                        modeTitle: widget.arcade ? 'Suika Arena' : _currentLevel.title,
                        score: _score,
                        line: _statsLine(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share_rounded, color: LululuColors.liquidGold),
                  label: const Text(
                    'PAYLAŞ KART',
                    style: TextStyle(
                      color: LululuColors.liquidGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _restartLevel(_currentLevel);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LululuColors.mysticRuby,
                    foregroundColor: LululuColors.ink,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('TEKRAR DENE 🔄', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('HARİTAYA DÖN 🗺️', style: TextStyle(color: LululuColors.mutedTitanium)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statsLine() =>
      'Birleşim $_mergeTotal · Max combo x$_maxCombo · Zirve ${_peakTier.name}';

  Widget _buildComboMeter() {
    return ClipRRect(
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
    );
  }
}

class _PieceSlot extends StatelessWidget {
  const _PieceSlot({
    required this.label,
    required this.tier,
    required this.accent,
    this.emptyHint,
    this.onTap,
  });

  final String label;
  final InsectTier? tier;
  final Color accent;
  final String? emptyHint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final slot = Container(
      width: 80,
      constraints: const BoxConstraints(minHeight: 56, minWidth: 80),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: LululuColors.spaceNavy.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: onTap != null ? accent : accent.withValues(alpha: 0.7),
          width: onTap != null ? 2 : 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: onTap != null ? accent : LululuColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 4),
          if (tier != null)
            StickerImage(assetPath: tier!.assetPath, width: 40, height: 40)
          else
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  emptyHint ?? '—',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return slot;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: slot,
    );
  }
}

class _MiniIconBtn extends StatelessWidget {
  const _MiniIconBtn({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LululuColors.spaceNavy.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: LululuColors.liquidGold),
        ),
      ),
    );
  }
}
