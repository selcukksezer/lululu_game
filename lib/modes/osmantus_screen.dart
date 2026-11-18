import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/osmantus_cast.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/mode_bonus_bar.dart';

/// Viral Osmantuş ritmi: videodaki iki kişiyle “TUŞ!” anında dokun.
///
/// Refleks modu: vuruş zamanı bir [Ticker] + [Stopwatch] ile ölçülür, dokunuş
/// `onTapDown` anında değerlendirilir (parmak kalkmasını beklemez).
class OsmantusScreen extends StatefulWidget {
  const OsmantusScreen({
    super.key,
    this.energyConsumed = false,
    @visibleForTesting this.prototypeVisualState = false,
    @visibleForTesting this.clockForTesting,
  });

  /// `true` ise bu ekrana giriş `openGameMode` üzerinden 1 enerji
  /// tüketerek yapıldı; hiç hamle yapılmadan çıkılırsa enerji iade
  /// edilir (Stack Drop deseni). Doğrudan rota girişlerinde
  /// `false` kalır.
  final bool energyConsumed;

  final bool prototypeVisualState;
  final int Function()? clockForTesting;

  @override
  State<OsmantusScreen> createState() => _OsmantusScreenState();
}

/// Oyun temposu: ilk [tutorialMs] boyunca yavaş ve geniş pencere, sonra hızlanır.
class OsmantusPacing {
  const OsmantusPacing._();

  static const tutorialMs = 15000;
  static const rampMs = 60000;
  static const tutorialIntervalMs = 1100;
  static const minIntervalMs = 620;
  static const tutorialWindowMs = 190;
  static const minWindowMs = 110;

  @visibleForTesting
  static Color ringColorAt(double phase) {
    final progress = Curves.easeInOut.transform(
      ((phase - 0.3) / 0.7).clamp(0.0, 1.0),
    );
    return Color.lerp(
      const Color(0xFF5B6B86),
      const Color(0xFF12B76A),
      progress,
    )!;
  }

  static double _ramp(int elapsedMs) =>
      ((elapsedMs - tutorialMs) / rampMs).clamp(0.0, 1.0);

  static int intervalMs(int elapsedMs) =>
      (tutorialIntervalMs -
              (tutorialIntervalMs - minIntervalMs) * _ramp(elapsedMs))
          .round();

  static int windowMs(int elapsedMs) =>
      (tutorialWindowMs - (tutorialWindowMs - minWindowMs) * _ramp(elapsedMs))
          .round();

  static bool isTutorial(int elapsedMs) => elapsedMs < tutorialMs;
}

class _OsmantusScreenState extends State<OsmantusScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _green = Color(0xFF12B76A);
  static const _ruby = Color(0xFFFF5A6E);
  static const _firstBeatMs = 1600;

  late final Ticker _ticker;
  final Stopwatch _clock = Stopwatch();
  bool _pausedByLifecycle = false;
  // Elle duraklatma (madde 37): yaşam döngüsü durdurmasıyla aynı saat
  // (Stopwatch + Ticker) durdurulur; dokunuşlar _onTapDown korumasıyla
  // oyunu etkilemez.
  bool _paused = false;
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  final _rng = Random();

  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _best = 0;
  int _lives = 3;
  int _dayStreak = 0;
  bool _alive = true;
  bool _resultShown = false;

  /// Hamle bayrağı (enerji iadesi): oturum boyunca ilk dokunuş
  /// (`_onTapDown` — isabet, erken basış veya pencere dışı
  /// bekle-dokunuş fark etmez; oyun canlıyken sahneye yapılan her
  /// dokunuş hamledir) veya turun bitmesi (`_miss` içinde canların
  /// tükenmesi) ile `true` olur; TEKRAR/yeniden başlatmada
  /// SIFIRLANMAZ (Stack Drop `_moveMade` deseni — oturum ömrü).
  /// Güçlendirici kullanımı tek başına hamle sayılmaz (Stack deseni).
  bool _moveMade = false;

  /// Çift-iade koruması: iade bu oturumda en fazla bir kez yapılır.
  bool _energyRefunded = false;
  String _hint = 'Halka yeşile dönünce dokun!';

  int _beatStartMs = 0;
  int _beatAtMs = _firstBeatMs;
  bool _hitThisBeat = false;
  int _speakerIndex = 0;
  final List<String> _lines = [
    OsmantusCast.duo[0].lines[0],
    OsmantusCast.duo[1].lines[2],
  ];

  String _bandText = '';
  bool _bandBad = false;
  int _bandUntilMs = 0;
  int _face = -1;
  int _flashUntilMs = 0;
  bool _flashBad = false;
  String? _breakReason;

  int _boostUntilMs = 0;
  int _ringUntilMs = 0;
  bool _micShield = false;

  int get _nowMs =>
      widget.clockForTesting?.call() ?? _clock.elapsedMilliseconds;
  int get _playMs => _nowMs;

  bool get _boostOn => _nowMs < _boostUntilMs;
  bool get _ringOn => _nowMs < _ringUntilMs;

  int get _window =>
      OsmantusPacing.windowMs(_playMs) +
      (_boostOn ? 60 : 0) +
      (_ringOn ? 60 : 0);

  bool get _tutorial => OsmantusPacing.isTutorial(_playMs);

  @override
  void initState() {
    super.initState();
    AudioManager().initialize();
    _ticker = createTicker(_onFrame);
    WidgetsBinding.instance.addObserver(this);
    if (widget.prototypeVisualState) {
      _score = 640;
      _best = 980;
      _combo = 5;
      _maxCombo = 5;
      _dayStreak = 5;
      _bandText = 'MÜKEMMEL! X5';
      _bandUntilMs = 1 << 30;
      _phase.value = 1;
      _lines[1] = 'DIKKIŞ DIKKIŞ!';
      _hint = '';
      _loadBest();
      return;
    }
    _clock.start();
    _ticker.start();
    _loadBest();
  }

  Future<void> _loadBest() async {
    await LeaderboardService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      final stored = LeaderboardService.instance.getBest(
        LeaderboardService.modeOsmantus,
      );
      _best = widget.prototypeVisualState ? max(stored, 980) : stored;
      _dayStreak = widget.prototypeVisualState
          ? 5
          : ProgressManager().dailyStreak;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioManager().stopAll();
    _ticker.dispose();
    _phase.dispose();
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
        // Arka planda oyun saatini durdur: Stopwatch işlemeye devam
        // ederse dönüşte her kare _miss + _advanceBeat ile canlar erir.
        if (_clock.isRunning) {
          _clock.stop();
          _pausedByLifecycle = true;
        }
        _ticker.stop();
        break;
      case AppLifecycleState.resumed:
        // Elle duraklatılmışsa yaşam döngüsü dönüşü oyunu kendiliğinden
        // başlatmasın; devam kararı kullanıcıda (DEVAM düğmesi).
        if (_pausedByLifecycle && !_paused) {
          _pausedByLifecycle = false;
          _clock.start();
        }
        if (_alive && !_paused && !_ticker.isActive) _ticker.start();
        break;
    }
  }

  /// Elle duraklatma / devam (madde 37): yaşam döngüsü durdurmasıyla
  /// birebir aynı saat durdurulur, can/skor kaybı olmaz.
  void _togglePause() {
    if (widget.prototypeVisualState || !_alive) return;
    if (_paused) {
      _paused = false;
      _pausedByLifecycle = false;
      if (!_clock.isRunning) _clock.start();
      if (!_ticker.isActive) _ticker.start();
    } else {
      _paused = true;
      if (_clock.isRunning) _clock.stop();
      _ticker.stop();
    }
    setState(() {});
  }

  void _onFrame(Duration _) {
    if (!_alive || _paused) return;
    final now = _nowMs;
    final span = max(1, _beatAtMs - _beatStartMs);
    _phase.value = ((now - _beatStartMs) / span).clamp(0.0, 1.0);

    if (now > _beatAtMs + _window) {
      // Saat sıçraması (arka plan dönüşü / atlanan yaşam döngüsü olayı):
      // son tarihin bir tam vuruş aralığından fazla geride kalınmışsa,
      // kaçan vuruşları kare kare cezalandırmak yerine cezasız
      // yeniden senkronla. Normal oyunda kare başına sapma ~16 ms
      // olduğundan bu eşik asla tutmaz.
      final interval = OsmantusPacing.intervalMs(_playMs);
      if (now > _beatAtMs + _window + interval) {
        _beatStartMs = now;
        _beatAtMs = now + interval;
        _hitThisBeat = false;
        _phase.value = 0;
        _hint = 'Devam! Halka yeşile dönünce dokun.';
        setState(() {});
        return;
      }
      if (!_hitThisBeat) {
        if (_tutorial && _score == 0 && _combo == 0 && widget.clockForTesting == null) {
          _showBand('YEŞİLDE BAS!', bad: false, ms: 900);
        } else {
          _miss('KAÇIRDIN');
          if (!_alive) return;
        }
      }
      _advanceBeat();
    } else if (_bandUntilMs != 0 && now > _bandUntilMs && _bandText != '') {
      setState(() => _bandText = '');
    }
  }

  void _advanceBeat() {
    final interval = OsmantusPacing.intervalMs(_playMs);
    _beatStartMs = _beatAtMs;
    _beatAtMs = _beatAtMs + interval;
    _hitThisBeat = false;
    _speakerIndex = 1 - _speakerIndex;
    final lines = OsmantusCast.duo[_speakerIndex].lines;
    _lines[_speakerIndex] = lines[_rng.nextInt(lines.length)];
    if (_face != -1 && _nowMs > _flashUntilMs) _face = -1;
    setState(() {});
  }

  void _showBand(String text, {required bool bad, int ms = 1500}) {
    _bandText = text;
    _bandBad = bad;
    _bandUntilMs = _nowMs + ms;
  }

  void _miss(String reason, {bool costsLife = true}) {
    HapticFeedback.heavyImpact();
    final lostCombo = _combo;
    _combo = 0;
    _breakReason = reason;
    _face = 0;
    _flashBad = true;
    _flashUntilMs = _nowMs + 320;
    _showBand(lostCombo >= 2 ? 'KOMBO BOZULDU · $reason' : reason, bad: true);
    if (_micShield) {
      _micShield = false;
      _hint = 'Mikrofon tuttu, can gitmedi.';
      setState(() {});
      return;
    }
    if (costsLife && !_tutorial) {
      _lives -= 1;
      _hint = '$reason · ${_lives > 0 ? '$_lives can kaldı' : 'son can gitti'}';
    } else {
      _hint = '$reason · ısınma turu, can gitmedi';
    }
    if (_lives <= 0) {
      // Tur tamamlandı: iade hakkı biter (hiç dokunmadan canların
      // tükenmesi de tur sayılır — Stack Drop `_fail` deseni).
      _moveMade = true;
      _alive = false;
      _hint = 'Bitti. Osman & Tuş seni yendi.';
      unawaited(AudioManager().playLose());
      unawaited(
        LeaderboardService.instance.submitScore(
          LeaderboardService.modeOsmantus,
          _score,
        ),
      );
      if (_score > _best) _best = _score;
    }
    setState(() {});
  }

  void _onTapDown() {
    if (!_alive || _paused) return;
    // Hamle: oyun canlıyken sahneye yapılan ilk dokunuş (isabet,
    // erken basış veya pencere dışı bekle-dokunuş fark etmez).
    _moveMade = true;
    final now = _nowMs;
    final delta = now - _beatAtMs;
    final win = _window;
    if (delta.abs() <= win) {
      if (_hitThisBeat) return;
      _hitThisBeat = true;
      final perfect = delta.abs() <= win * 0.35;
      _combo += 1;
      _breakReason = null;
      if (_combo > _maxCombo) _maxCombo = _combo;
      final basePts = (perfect ? 120 : 70) + min(_combo, 30) * 8;
      _score += _boostOn ? basePts * 2 : basePts;
      _face = perfect ? 4 : 2;
      _flashBad = false;
      _flashUntilMs = now + 280;
      _showBand(perfect ? 'MÜKEMMEL! X$_combo' : 'İYİ! X$_combo', bad: false);
      _hint = delta < 0
          ? 'Biraz erken (${-delta}ms)'
          : 'Biraz geç (+${delta}ms)';
      if (perfect) _hint = 'Tam zamanında!';
      AudioManager().triggerHaptic();
      HapticFeedback.mediumImpact();
      unawaited(
        AudioManager().playOsmantusBeat(
          isPersonB: _speakerIndex == 1,
          perfect: perfect,
          comboCount: _combo,
        ),
      );
      setState(() {});
    } else if (delta < 0 && delta >= -win * 2.2) {
      _hitThisBeat = true;
      _miss('ERKEN BASTIN');
    } else if (delta < 0) {
      _hint = 'Bekle, halka yeşile dönsün.';
      setState(() {});
    }
  }

  void _restart() {
    setState(() {
      _paused = false;
      _pausedByLifecycle = false;
      _score = 0;
      _combo = 0;
      _maxCombo = 0;
      _lives = 3;
      _alive = true;
      _resultShown = false;
      _speakerIndex = 0;
      _lines[0] = OsmantusCast.duo[0].lines[0];
      _lines[1] = OsmantusCast.duo[1].lines[2];
      _bandText = '';
      _face = -1;
      _breakReason = null;
      _hint = 'Halka yeşile dönünce dokun!';
      _hitThisBeat = false;
      _boostUntilMs = 0;
      _ringUntilMs = 0;
      _micShield = false;
      _clock
        ..reset()
        ..start();
      _beatStartMs = 0;
      _beatAtMs = _firstBeatMs;
    });
    if (!_ticker.isActive) _ticker.start();
  }

  String _statsLine() =>
      'Max combo x$_maxCombo · Günlük streak $_dayStreak'
      '${_breakReason == null ? '' : ' · Son hata: $_breakReason'}';

  bool _useDikkis() {
    if (!_alive || _paused) return false;
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _boostUntilMs = _nowMs + 12000;
      _showBand('DIKKIŞ 2X PUAN!', bad: false);
      _hint = 'DIKKIŞ aktif · 12 sn 2X sahne puanı ve geniş ritim!';
    });
    return true;
  }

  bool _useRing() {
    if (!_alive || _paused) return false;
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _ringUntilMs = _nowMs + 12000;
      _showBand('HALKA + AKTİF!', bad: false);
      _hint = 'Halka + aktif · 12 sn geniş zamanlama penceresi!';
    });
    return true;
  }

  bool _useMic() {
    if (!_alive || _paused || _micShield) return false;
    HapticFeedback.mediumImpact();
    unawaited(AudioManager().playSfx(GameAudio.sfxButtonTap));
    setState(() {
      _micShield = true;
      _showBand('MİKROFON KALKANI!', bad: false);
      _hint = 'Mikrofon kalkanı hazır · sıradaki kaçışta can gitmez!';
    });
    return true;
  }

  Future<void> _presentResult() async {
    // S1#49: ödeme + liderlik + görev kaydı + sonuç ekranı finishRun()
    // üzerinden (tek-ödeme korunur).
    final replay = await finishRun(
      context,
      score: _score,
      best: _best,
      leaderboardMode: LeaderboardService.modeOsmantus,
    );
    if (!mounted) return;
    _resultShown = false;
    if (!replay) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
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
        !_alive ||
        _resultShown) {
      return;
    }
    _energyRefunded = true;
    EnergyService.instance.addEnergy(1);
  }

  void _edgeShowResult() {
    if (_resultShown) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _presentResult();
    });
  }

  Color _ringColor(double t) {
    final now = _nowMs;
    if (now < _flashUntilMs) return _flashBad ? _ruby : _green;
    return OsmantusPacing.ringColorAt(t);
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
                  'DURAKLATILDI',
                  style: GoogleFonts.baloo2(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFB800),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Skor $_score · Kombo x$_combo',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ArcadeButton(label: context.l10n.continueAction, onPressed: _togglePause),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_alive && !_resultShown && !widget.prototypeVisualState) {
      _edgeShowResult();
    }
    final topPad = MediaQuery.paddingOf(context).top;
    final hasShellStatusBar = topPad > 0;
    final wideScreen = MediaQuery.sizeOf(context).width >= 400;
    final shiftOffset = wideScreen ? Offset.zero : const Offset(3, 0);
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
          backgroundColor: wideScreen
              ? const Color(0xFF080B12)
              : const Color(0xFFEEF1F7),
          body: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: wideScreen
                    ? const Color(0xFF080B12)
                    : const Color(0xFFEEF1F7),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: shiftOffset,
                  child: Opacity(
                    opacity: 0.96,
                    child: Image.asset(
                      'assets/design/backgrounds/osmantus_mansion.webp',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: shiftOffset,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.24, 0.76, 1],
                        colors: [
                          const Color(0x4D080B12),
                          const Color(0x00080B12),
                          const Color(0x00080B12),
                          const Color(0x52080B12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ClipRect(
                child: Transform.translate(
                  offset: shiftOffset,
                  child: Column(
                    children: [
                      _statusBar(
                        hasShellStatusBar: hasShellStatusBar,
                        topPad: topPad,
                      ),
                      _modeHeader(wideScreen: wideScreen),
                      _statsBar(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                          child: Semantics(
                            label: _hint,
                            child: Listener(
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (_) => _onTapDown(),
                              child: _stage(wideScreen: wideScreen),
                            ),
                          ),
                        ),
                      ),
                      _powerDock(),
                    ],
                  ),
                ),
              ),
              if (!_alive && !_resultShown)
                Positioned.fill(
                  child: ArcadeResultOverlay(
                    title: 'İKİLİ YENDİ',
                    message: _statsLine(),
                    score: _score,
                    best: _best,
                    won: false,
                    modeTitle: context.l10n.shopModeOsmantus,
                    shareLine: _statsLine(),
                    retryLabel: 'YENİDEN',
                    onRetry: _restart,
                  ),
                ),
              if (_paused && _alive && !widget.prototypeVisualState)
                _pauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBar({
    required bool hasShellStatusBar,
    required double topPad,
  }) {
    if (hasShellStatusBar) {
      return SizedBox(height: widget.prototypeVisualState ? 35.38 : topPad);
    }
    return SizedBox(
      height: 35.38,
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
              child: CustomPaint(painter: _OsmantusStatusIndicatorsPainter()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeHeader({required bool wideScreen}) {
    return SizedBox(
      height: wideScreen ? 54 : 56.27,
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
                width: wideScreen ? 48 : 41.42,
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
                          context.l10n.osmantusTitle,
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
                      Container(
                        height: 20.27,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'VİRAL',
                          style: GoogleFonts.baloo2(
                            fontSize: 10.5,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: const Color(0xFF4A2E00),
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
              padding: EdgeInsets.fromLTRB(wideScreen ? 6 : 11, 5, 12, 5),
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
                  Image.asset(
                    'assets/icons2/coin.png',
                    width: wideScreen ? 25 : 14,
                    height: wideScreen ? 25 : 14,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.monetization_on,
                      color: Color(0xFFFFD700),
                      size: 14,
                    ),
                  ),
                  SizedBox(width: wideScreen ? 6 : 10),
                  Text(
                    widget.prototypeVisualState
                        ? '12.450'
                        : ProgressManager().coins.toString().replaceAllMapped(
                            RegExp(r'\B(?=(\d{3})+(?!\d))'),
                            (_) => '.',
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
            if (!widget.prototypeVisualState) ...[
              const SizedBox(width: 10),
              _pauseButton(),
            ],
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: context.l10n.helpButtonLabel,
              child: GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.l10n.osmantusTitle),
                  content: const Text(
                    'Ritim halkası yeşile döndüğünde İKİLİ TUŞ butonuna dokun! '
                    'Zamanında basarak kombo yap ve özel sahne güçlerini kullan.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.understoodButton),
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
                  border: Border.all(color: const Color(0xB3FFB800), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 3),
                    ),
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

  Widget _statsBar() {
    return SizedBox(
      height: 58.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: LayoutBuilder(
          builder: (context, statsBox) {
            final row = Row(
              children: [
                _scoreBox(context.l10n.gameScoreLabel, '$_score', width: 104),
                const SizedBox(width: 8),
                _scoreBox(context.l10n.gameBestLabel, '$_best', width: 84),
                const Spacer(),
                _scoreBox('COMBO', 'x$_combo', width: 74),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: context.l10n.finishRoundLabel,
                  child: GestureDetector(
                    onTap: _restart,
                    child: Container(
                      width: 57.81,
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
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4A2E00),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
            if (statsBox.maxWidth >= 350) return row;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(width: 350, height: 50.5, child: row),
            );
          },
        ),
      ),
    );
  }

  Widget _scoreBox(String label, String value, {required double width}) {
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

  Widget _powerDock() {
    final items = [
      stockBonusWithResult(
        id: 'dik',
        label: 'DIKKIŞ',
        asset: 'assets/icons2/fist.png',
        effect: () {
          final applied = _useDikkis();
          setState(() {});
          return applied;
        },
      ),
      stockBonusWithResult(
        id: 'ring',
        label: 'HALKA +',
        asset: 'assets/icons2/wheel.png',
        effect: () {
          final applied = _useRing();
          setState(() {});
          return applied;
        },
      ),
      stockBonusWithResult(
        id: 'mic',
        label: 'MİKROFON',
        asset: 'assets/icons2/star.png',
        effect: () {
          final applied = _useMic();
          setState(() {});
          return applied;
        },
      ),
    ];
    return SizedBox(
      height: 80.89,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              _powerButton(items[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _powerButton(ModeBonus item) {
    return Semantics(
      button: true,
      enabled: item.count > 0,
      label: context.l10n.boosterCountLabel(item.label, item.count),
      child: GestureDetector(
        onTap: item.count > 0 ? item.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 66,
          height: 62.89,
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
                      child: Image.asset(
                        item.asset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFFFFB800),
                          size: 24,
                        ),
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
                height: 9.89,
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

  Widget _stage({required bool wideScreen}) {
    return LayoutBuilder(
      builder: (context, box) {
        const contentOverflow = 49.1;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x24FFFFFF), width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x660E1422), Color(0x800E1422)],
                  ),
                ),
                child: Stack(
                  children: [
                    if (wideScreen)
                      Column(
                        children: [
                          _cards(),
                          _faces(),
                          Expanded(child: _arena(wideScreen: true)),
                          _tapButton(),
                        ],
                      )
                    else
                      OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: 0,
                        maxHeight: max(485.0, box.maxHeight + contentOverflow),
                        child: SizedBox(
                          height: max(485.0, box.maxHeight + contentOverflow),
                          child: Column(
                            children: [
                              _cards(),
                              _faces(),
                              SizedBox(
                                height: 189.94,
                                child: _arena(wideScreen: false),
                              ),
                              _tapButton(),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 2,
                      left: 0,
                      right: 0,
                      height: 25,
                      child: _comboBand(wideScreen: wideScreen),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _comboBand({required bool wideScreen}) {
    final visible = _bandText.isNotEmpty;
    final color = _bandBad
        ? const Color(0xFFE5334A)
        : (wideScreen ? const Color(0xFFFFB800) : const Color(0xFFFFD700));
    final glow = _bandBad ? const Color(0xFFFFD700) : const Color(0xFFFF6B35);
    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: visible
            ? (widget.prototypeVisualState && !wideScreen ? 0.55 : 1)
            : 0,
        duration: const Duration(milliseconds: 120),
        child: Text(
          _bandText.isEmpty ? ' ' : _bandText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.bangers(
            fontSize: _bandBad
                ? 18
                : (widget.prototypeVisualState && !wideScreen ? 18 : 22),
            height: 1,
            letterSpacing: 0.6,
            color: color,
            shadows: [
              const Shadow(color: Color(0xEB080B12), offset: Offset(0, 3)),
              Shadow(color: glow.withValues(alpha: 0.9), blurRadius: 14),
              Shadow(color: glow.withValues(alpha: 0.55), blurRadius: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cards() {
    const subs = ['Tuşçu · işaretçi', 'Makara · dinleyen'];
    return SizedBox(
      height: 163.16,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _PersonCard(
                  person: OsmantusCast.duo[i],
                  sub: subs[i],
                  on: i == _speakerIndex,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _faces() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var n = 1; n <= 7; n++) ...[
            if (n > 1) const SizedBox(width: 6),
            Container(
              width: 35,
              height: 46,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0x12FFFFFF),
                borderRadius: BorderRadius.circular(9),
                border: _face == n - 1
                    ? Border.all(color: _green, width: 2)
                    : null,
              ),
              child: Image.asset(
                'assets/images/stickers/osman_$n.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) {
                  if (kDebugMode) {
                    debugPrint(
                      'Osmantus çıkartması yüklenemedi: assets/images/stickers/osman_$n.png',
                    );
                  }
                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: Color(0xCCFFFFFF),
                      size: 20,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _arena({required bool wideScreen}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Fig(
            line: _lines[0],
            asset: OsmantusCast.duo[0].assetPath,
            wideScreen: wideScreen,
          ),
          if (wideScreen)
            Align(
              alignment: Alignment.center,
              child: ValueListenableBuilder<double>(
                valueListenable: _phase,
                builder: (context, t, _) => _ring(t, wideScreen: true),
              ),
            )
          else
            SizedBox(
              width: 84,
              height: 181.94,
              child: Align(
                alignment: Alignment.center,
                child: ValueListenableBuilder<double>(
                  valueListenable: _phase,
                  builder: (context, t, _) => _ring(t, wideScreen: false),
                ),
              ),
            ),
          _Fig(
            line: _lines[1],
            asset: OsmantusCast.duo[1].assetPath,
            wideScreen: wideScreen,
          ),
        ],
      ),
    );
  }

  Widget _ring(double t, {required bool wideScreen}) {
    final color = _ringColor(t);
    final k = Curves.easeInOut.transform(((t - 0.3) / 0.7).clamp(0.0, 1.0));
    final scale = widget.prototypeVisualState
        ? (wideScreen ? 1.065 : 1.0)
        : 1 + 0.07 * k;
    // Yaklaşan halo: vuruşa doğru küçülür, tam anda prototipteki 7px halkaya oturur.
    final halo = 7.0 + (1 - t) * 26;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 6),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.22), spreadRadius: halo),
            BoxShadow(
              color: color.withValues(alpha: 0.2 + 0.35 * k),
              blurRadius: 26,
            ),
          ],
        ),
        child: Text(
          'YEŞİLDE\nBAS!',
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 12.5,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF7CF2B8),
          ),
        ),
      ),
    );
  }

  Widget _tapButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 13),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF37E08B), Color(0xFF12B76A), Color(0xFF0A9553)],
            stops: [0, 0.55, 1],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x47000000),
              offset: Offset(0, 10),
              blurRadius: 18,
            ),
            BoxShadow(color: Color(0xFF066C3C), offset: Offset(0, 5)),
          ],
        ),
        child: Text(
          'İKİLİ TUŞ',
          style: GoogleFonts.baloo2(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.36,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.sub,
    required this.on,
  });

  final OsmantusPerson person;
  final String sub;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 151.16,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 7),
        decoration: BoxDecoration(
          color: on ? const Color(0x2112B76A) : const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: on ? const Color(0xFF12B76A) : const Color(0x29FFFFFF),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 86,
              child: Image.asset(person.assetPath, fit: BoxFit.contain),
            ),
            const SizedBox(height: 2),
            Text(
              person.displayName,
              style: GoogleFonts.baloo2(
                fontSize: 14.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  sub,
                  maxLines: 1,
                  softWrap: false,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9AA7BC),
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

class _Fig extends StatelessWidget {
  const _Fig({
    required this.line,
    required this.asset,
    required this.wideScreen,
  });

  final String line;
  final String asset;
  final bool wideScreen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 181.94,
      child: Column(
        children: [
          Container(
            width: 86,
            height: 58.94,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 5),
            padding: EdgeInsets.symmetric(
              horizontal: wideScreen ? 10 : 6,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xF0080B12),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xBFE01E5A), width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x80E01E5A), blurRadius: 12),
                BoxShadow(
                  color: Color(0x4D000000),
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Text(
              line,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.clip,
              style: GoogleFonts.bangers(
                fontSize: wideScreen ? 14.5 : 16.5,
                height: wideScreen ? 1.55 : 1.05,
                letterSpacing: 0.6,
                color: wideScreen
                    ? const Color(0xFFFFB800)
                    : const Color(0xFFFFD700),
                shadows: const [
                  Shadow(color: Color(0x99E01E5A), blurRadius: 9),
                ],
              ),
            ),
          ),
          SizedBox(height: 118, child: Image.asset(asset, fit: BoxFit.contain)),
        ],
      ),
    );
  }
}

class _OsmantusStatusIndicatorsPainter extends CustomPainter {
  const _OsmantusStatusIndicatorsPainter();

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
  bool shouldRepaint(_OsmantusStatusIndicatorsPainter oldDelegate) => false;
}
