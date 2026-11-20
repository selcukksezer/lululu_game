import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/hisir_character.dart';
import '../models/osmantus_cast.dart';
import '../services/audio_manager.dart';
import '../services/difficulty_binding.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/global_notify.dart';
import '../services/haptic_service.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../utils/number_format.dart';
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
    // Yeşil SADECE puan penceresinin içinde görünür: pencere/genişlik
    // oranı öğreticide 190/1100 ≈ 0.173, sonda 110/620 ≈ 0.177 —
    // pencere faz ≈ 0.82'de açılır. Eski eşik (0.3) halkanın faz
    // 0.65'te bile belirgin yeşil görünmesine yol açıyordu; o fazda
    // vuruş penceresine daha ~385 ms vardı ve "yeşilde" basan oyuncu
    // erken-basış ıskası + can kaybı alıyordu ("YEŞİLDE BAS!" yazısına
    // rağmen kırmızıya dönüp oyun bitiyordu). 0.82 eşiğinde algılanır
    // yeşil ton her zaman pencere içindedir (öğretici: pencere
    // faz 0.827'de açılır; yeşil ~0.85'ten itibaren seçilir).
    final progress = Curves.easeInOut.transform(
      ((phase - 0.82) / 0.18).clamp(0.0, 1.0),
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

  /// N7 çıkış onayı durumu: onay bayrağı (diyalogda Çık seçildiyse
  /// `PopScope` çıkışı geçirir), çift-diyalog kilidi ve diyalog
  /// duraklatması bayrağı (yardım deseni: yalnız bu diyalog için
  /// duraklatıldıysa kapanınca devam edilir).
  bool _exitConfirmed = false;
  bool _exitConfirmShowing = false;
  bool _pausedForExitConfirm = false;
  bool _exitResumeClock = false;
  bool _exitResumeTicker = false;
  final ValueNotifier<double> _phase = ValueNotifier<double>(0);
  final _rng = Random();

  int _score = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int _best = 0;
  int _lives = 3;
  bool _alive = true;
  bool _resultShown = false;

  /// Y3 idempotency damgası: tur başlangıcında bir kez alınır
  /// (`initState` / `_restart`); aynı turun tüm bitiş yolları aynı
  /// anahtarı kullanır, yeni tur yeni damga alır. Bitiş anında
  /// `DateTime.now()` alınmaz.
  int _runStartedAtUs = DateTime.now().microsecondsSinceEpoch;

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

  /// Çıkış-sonrası iade bildirimi (S6): `PopScope` `didPop` anında
  /// bağlam artık ağaçta değildir; bildirim metni her `build`'de
  /// ÖNCEDEN yakalanır ve iade gerçekten verildiğinde paylaşılan
  /// `GlobalNotify` üzerinden çıkış yapılan ekranın üstünde
  /// gösterilir (balon/stack deseninin paylaşılan karşılığı).
  String? _refundNotice;
  String _hint = '';
  bool _hintSeeded = false;

  int _beatStartMs = 0;
  int _beatAtMs = _firstBeatMs;
  bool _hitThisBeat = false;
  int _speakerIndex = 0;

  /// Bu vuruş Hışır vuruşu mu? Hışır vuruşunda konuşmacı figürü
  /// Hışır görseliyle görünür, replik Hışır repliğidir, isabet sesi
  /// `hisir_zopa.mp3` olur. Skor/zamanlama aynen kalır.
  bool _hisirBeat = false;
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

  int _boostUntilMs = 0;
  int _ringUntilMs = 0;
  bool _micShield = false;

  int get _nowMs =>
      widget.clockForTesting?.call() ?? _clock.elapsedMilliseconds;
  int get _playMs => _nowMs;

  bool get _boostOn => _nowMs < _boostUntilMs;
  bool get _ringOn => _nowMs < _ringUntilMs;

  // 12C1: adaptif zorluk — merhamette vuruş penceresi genişler (daha
  // bağışlayıcı), kazanma serisinde daralır. Çarpan profilden senkron okunur.
  int get _window =>
      ((OsmantusPacing.windowMs(_playMs) +
                  (_boostOn ? 60 : 0) +
                  (_ringOn ? 60 : 0)) /
              DifficultyBinding.instance
                  .cachedProfileForMode('osmantus')
                  .speedMultiplier)
          .round();

  bool get _tutorial => OsmantusPacing.isTutorial(_playMs);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hintSeeded) {
      _hintSeeded = true;
      _hint = context.l10n.osmantusHintIdle;
    }
  }

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
      _bandText = 'MÜKEMMEL! X5';
      _bandUntilMs = 1 << 30;
      _phase.value = 1;
      _lines[1] = 'DIKKIŞ DIKKIŞ!';
      _hint = '';
      _loadBest();
      return;
    }
    // Y3: ilk turun başlangıç damgası (monoton koruma: aynı
    // mikrosaniyede başlayan iki turun anahtarı çakışmaz).
    _runStartedAtUs = max(
      DateTime.now().microsecondsSinceEpoch,
      _runStartedAtUs + 1,
    );
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
    // 10D P0-3: duraklatma sesi + titreşimi tek çağrıda
    // (playButtonTap içi selectionClick; ayrıca trigger* eklenmez).
    unawaited(AudioManager().playButtonTap());
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

  /// Yardım diyaloğu açıkken oyun durur (B4): saat + ticker durdurulur,
  /// diyalog kapanınca kaldığı yerden devam eder. Elle duraklatma
  /// bayrağına dokunulmaz (duraklatma kaplaması açılmaz). `_onFrame`
  /// saat/senkron mantığına dokunulmaz.
  Future<void> _showHelp() async {
    final resumeClock = _alive && !_paused && _clock.isRunning;
    final resumeTicker = _alive && !_paused && _ticker.isActive;
    if (resumeClock) _clock.stop();
    if (resumeTicker) _ticker.stop();
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.osmantusTitle),
          content: Text(context.l10n.osmantusRhythmHint),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.understoodButton),
            ),
          ],
        ),
      );
    } finally {
      if (mounted && _alive && !_paused) {
        if (resumeClock && !_clock.isRunning) _clock.start();
        if (resumeTicker && !_ticker.isActive) _ticker.start();
      }
    }
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
      // 12C1: adaptif zorluk — vuruş aralığı hız çarpanına bölünür
      // (merhamette daha seyrek vuruş, seride daha sık).
      final interval =
          OsmantusPacing.intervalMs(_playMs) ~/
          DifficultyBinding.instance
              .cachedProfileForMode('osmantus')
              .speedMultiplier;
      if (now > _beatAtMs + _window + interval) {
        _beatStartMs = now;
        _beatAtMs = now + interval;
        _hitThisBeat = false;
        _phase.value = 0;
        _hint = context.l10n.osmantusHintResume;
        setState(() {});
        return;
      }
      if (!_hitThisBeat) {
        if (_tutorial && _score == 0 && _combo == 0 && widget.clockForTesting == null) {
          _showBand(context.l10n.osmantusPressGreen, bad: false, ms: 900);
        } else {
          _miss(context.l10n.missedCaps);
          if (!_alive) return;
        }
      }
      _advanceBeat();
    } else if (_bandUntilMs != 0 && now > _bandUntilMs && _bandText != '') {
      setState(() => _bandText = '');
    }
  }

  void _advanceBeat() {
    // 12C1: adaptif zorluk — vuruş aralığı hız çarpanına bölünür
    // (merhamette daha seyrek vuruş, seride daha sık).
    final interval =
        OsmantusPacing.intervalMs(_playMs) ~/
        DifficultyBinding.instance
            .cachedProfileForMode('osmantus')
            .speedMultiplier;
    _beatStartMs = _beatAtMs;
    _beatAtMs = _beatAtMs + interval;
    _hitThisBeat = false;
    _speakerIndex = 1 - _speakerIndex;
    _hisirBeat =
        !_tutorial &&
        !widget.prototypeVisualState &&
        HisirCharacter.roll(_rng);
    if (_hisirBeat) {
      _lines[_speakerIndex] = HisirCharacter.replik;
    } else {
      final lines = OsmantusCast.duo[_speakerIndex].lines;
      _lines[_speakerIndex] = lines[_rng.nextInt(lines.length)];
    }
    if (_face != -1 && _nowMs > _flashUntilMs) _face = -1;
    setState(() {});
  }

  void _showBand(String text, {required bool bad, int ms = 1500}) {
    _bandText = text;
    _bandBad = bad;
    _bandUntilMs = _nowMs + ms;
  }

  void _miss(String reason, {bool costsLife = true}) {
    unawaited(HapticService.instance.heavyImpact());
    // 10D P0-2: ıska sesi — playDrop. Ses çağrısı kapılı lightImpact
    // içerir; yukarıdaki heavyImpact ile aynı tick'te 18 ms kapısına
    // takılıp düşer — toplam 1 impuls (ağır olan korunur).
    unawaited(AudioManager().playDrop());
    final lostCombo = _combo;
    _combo = 0;
    _face = 0;
    _flashBad = true;
    _flashUntilMs = _nowMs + 320;
    _showBand(lostCombo >= 2 ? context.l10n.osmantusComboBroken(reason) : reason, bad: true);
    if (_micShield) {
      _micShield = false;
      _hint = context.l10n.osmantusMicSaved;
      setState(() {});
      return;
    }
    if (costsLife && !_tutorial) {
      _lives -= 1;
      _hint = context.l10n.osmantusLifeStatus(reason, _lives);
    } else {
      _hint = context.l10n.osmantusWarmupMiss(reason);
    }
    if (_lives <= 0) {
      // Tur tamamlandı: iade hakkı biter (hiç dokunmadan canların
      // tükenmesi de tur sayılır — Stack Drop `_fail` deseni).
      _moveMade = true;
      _alive = false;
      _hint = context.l10n.osmantusDuoWonHint;
      // D1: bitiş sesi tek kaynak — sonuç ekranı çalar.
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
      if (_combo > _maxCombo) _maxCombo = _combo;
      final basePts = (perfect ? 120 : 70) + min(_combo, 30) * 8;
      _score += _boostOn ? basePts * 2 : basePts;
      _face = perfect ? 4 : 2;
      _flashBad = false;
      _flashUntilMs = now + 280;
      _showBand(perfect ? context.l10n.perfectCombo(_combo) : context.l10n.goodCombo(_combo), bad: false);
      _hint = delta < 0
          ? context.l10n.osmantusEarlyBy(delta)
          : context.l10n.osmantusLateBy(delta);
      if (perfect) _hint = context.l10n.osmantusJustInTime;
      if (_hisirBeat) {
        // Ritim SFX'i aynen, ses Hışır: Osman sesi Hışır'ı kesmez,
        // Hışır klibi tek yoldan tam çalar (12K düzeni).
        unawaited(
          AudioManager().playOsmantusBeat(
            isPersonB: _speakerIndex == 1,
            perfect: perfect,
            comboCount: _combo,
            includeVoice: false,
          ),
        );
        unawaited(AudioManager().playHusurAday());
      } else {
        unawaited(
          AudioManager().playOsmantusBeat(
            isPersonB: _speakerIndex == 1,
            perfect: perfect,
            comboCount: _combo,
          ),
        );
      }
      setState(() {});
    } else if (delta < 0 && delta >= -win * 2.2) {
      _hitThisBeat = true;
      _miss(context.l10n.osmantusEarlyPress);
    } else if (delta < 0) {
      _hint = context.l10n.osmantusWaitGreen;
      setState(() {});
    }
  }

  void _restart() {
    setState(() {
      _paused = false;
      _pausedByLifecycle = false;
      // Y3: yeni tur, yeni damga — önceki turun anahtarı tekrar
      // kullanılmaz (monoton koruma çakışmayı engeller).
      _runStartedAtUs = max(
        DateTime.now().microsecondsSinceEpoch,
        _runStartedAtUs + 1,
      );
      _score = 0;
      _combo = 0;
      _maxCombo = 0;
      _lives = 3;
      _alive = true;
      _resultShown = false;
      _speakerIndex = 0;
      _hisirBeat = false;
      _lines[0] = OsmantusCast.duo[0].lines[0];
      _lines[1] = OsmantusCast.duo[1].lines[2];
      _bandText = '';
      _face = -1;
      _hint = context.l10n.osmantusHintIdle;
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

  bool _useDikkis() {
    if (!_alive || _paused) return false;
    unawaited(AudioManager().playButtonTap());
    setState(() {
      _boostUntilMs = _nowMs + 12000;
      _showBand(context.l10n.osmantusDikkisBoost, bad: false);
      _hint = context.l10n.osmantusDikkisHint;
    });
    return true;
  }

  bool _useRing() {
    if (!_alive || _paused) return false;
    unawaited(AudioManager().playButtonTap());
    setState(() {
      _ringUntilMs = _nowMs + 12000;
      _showBand(context.l10n.osmantusRingActive, bad: false);
      _hint = context.l10n.osmantusRingHint;
    });
    return true;
  }

  bool _useMic() {
    if (!_alive || _paused || _micShield) return false;
    unawaited(AudioManager().playButtonTap());
    setState(() {
      _micShield = true;
      _showBand(context.l10n.osmantusMicShieldCallout, bad: false);
      _hint = context.l10n.osmantusMicReady;
    });
    return true;
  }

  Future<void> _presentResult({bool? won}) async {
    // S1#49: ödeme + liderlik + görev kaydı + sonuç ekranı finishRun()
    // üzerinden (tek-ödeme korunur). Doğal bitiş canların bitmesidir
    // (kayıp); `won` verilmezse kayıp başlığı gösterilir.
    final replay = await finishRun(
      context,
      score: _score,
      best: _best,
      bestCombo: _maxCombo,
      won: won ?? false,
      leaderboardMode: LeaderboardService.modeOsmantus,
      // K16: mod skoru kimliği liderlik kimliğiyle aynıdır
      // (`lululu_game_mode.dart` bestScoreKey: 'osmantus').
      modeScoreId: LeaderboardService.modeOsmantus,
      // Y3: tur başlangıç damgalı anahtar; bu turun tüm bitiş
      // yolları (_finishEarly + _edgeShowResult) aynı anahtarı
      // paylaşır, çift ödeme/gösterim engellenir.
      idempotencyKey:
          '${LeaderboardService.modeOsmantus}:$_runStartedAtUs',
      // 12C1: AntiCheat hız denetimi + adaptif zorluk kaydı için tur
      // süresi (duraklatma sayacı durdurur — kronometre esas alınır).
      elapsed: _clock.elapsed,
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
      widget.energyConsumed && _moveMade && _alive && !_resultShown;

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

  /// N7 diyalog duraklatması (yardım deseni: `_showHelp` ile aynı
  /// — saat + ticker durur, `_paused` bayrağına dokunulmaz,
  /// duraklatma kaplaması açılmaz).
  void _pauseForExitConfirm() {
    _exitResumeClock = _alive && !_paused && _clock.isRunning;
    _exitResumeTicker = _alive && !_paused && _ticker.isActive;
    if (_exitResumeClock) _clock.stop();
    if (_exitResumeTicker) _ticker.stop();
    _pausedForExitConfirm = _exitResumeClock || _exitResumeTicker;
  }

  void _resumeAfterExitConfirm() {
    if (!_pausedForExitConfirm) return;
    _pausedForExitConfirm = false;
    if (mounted && _alive && !_paused) {
      if (_exitResumeClock && !_clock.isRunning) _clock.start();
      if (_exitResumeTicker && !_ticker.isActive) _ticker.start();
    }
    _exitResumeClock = false;
    _exitResumeTicker = false;
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
    // Dondurma (B5): sonuç diyaloğu süresince saat + ticker durur,
    // vuruş kaçırma/can kaybı işlemez. TEKRAR _restart ile döner.
    if (_clock.isRunning) _clock.stop();
    _ticker.stop();
    try {
      await _presentResult(won: _score > 0);
    } finally {
      // _restart saati sıfırlayıp başlattıysa korumalar no-op'tur;
      // sonuç gösterilemeden dönüldüyse tur donuk kalmaz.
      if (mounted && _alive && !_paused) {
        if (!_clock.isRunning) _clock.start();
        if (!_ticker.isActive) _ticker.start();
      }
    }
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

  @override
  Widget build(BuildContext context) {
    // S6: iade bildirimi metni çıkıştan ÖNCE yakalanır
    // (`didPop` anında bağlam ağaçta değildir).
    _refundNotice = context.l10n.energyRefundNotice;
    if (!_alive && !_resultShown && !widget.prototypeVisualState) {
      _edgeShowResult();
    }
    final topPad = MediaQuery.paddingOf(context).top;
    final hasShellStatusBar = topPad > 0;
    final wideScreen = MediaQuery.sizeOf(context).width >= 400;
    final shiftOffset = wideScreen ? Offset.zero : const Offset(3, 0);
    return PopScope(
      canPop: _exitConfirmed || !_needsExitConfirm,
      onPopInvokedWithResult: (didPop, _) => _handleExitPop(didPop),
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
                      if (hasShellStatusBar) SizedBox(height: topPad),
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
              if (_paused && _alive && !widget.prototypeVisualState)
                _pauseOverlay(),
            ],
          ),
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
                          context.l10n.viralBadge,
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
                        : formatGroupedInt(
                            ProgressManager().coins,
                            Localizations.localeOf(context).languageCode,
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
              onTap: _showHelp,
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
                    onTap: _finishEarly,
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

  /// Güç stokları (B11): dock `ProgressManager`'ı dinler; soğuk
  /// başlatmada yükleme bitince `notifyListeners` ile yeniden çizilir,
  /// ilk karelerdeki 0/0/0 kalıcı olmaz. Stok kullanımı/iadesi de aynı
  /// bildirimle dock'u günceller. `initState`'te `load()` çağrılmaz:
  /// yükleme ana önyüklemede yapılır ve buradan çağrılmak testlerde
  /// bekleyen zamanlayıcı bırakırdı.
  Widget _powerDock() {
    return ListenableBuilder(
      listenable: ProgressManager(),
      builder: (context, _) => _powerDockContent(),
    );
  }

  Widget _powerDockContent() {
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
        label: context.l10n.powerRingPlus,
        asset: 'assets/icons2/wheel.png',
        effect: () {
          final applied = _useRing();
          setState(() {});
          return applied;
        },
      ),
      stockBonusWithResult(
        id: 'mic',
        label: context.l10n.powerMicrophoneCaps,
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
    // W13-F: `_hint` (yönlü zamanlama geri bildirimi: "Biraz erken
    // (-120ms)", "Bekle, halka yeşile dönsün.", ısınma/can durumu)
    // daha önce yalnız Semantics etiketindeydi — gören oyuncuya hiç
    // ulaşmıyordu; kör testte zamanlama öğrenilemedi (playtest §9).
    // Bant boşken ipucu satırı aynı yerde görünür; isabet/ıska anonsu
    // (bant) varken bant önceliklidir. Mekanik aynen kalır: yalnız
    // görünür metin, pencere/can kuralına dokunulmaz. Prototip
    // vitrininde bant dolu ('MÜKEMMEL! X5') olduğundan kare değişmez.
    final showHint =
        _bandText.isEmpty && _hint.isNotEmpty && !widget.prototypeVisualState;
    final text = _bandText.isNotEmpty ? _bandText : (showHint ? _hint : '');
    final visible = text.isNotEmpty;
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
          text.isEmpty ? ' ' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: showHint
              ? GoogleFonts.nunito(
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Color(0xEB080B12),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                )
              : GoogleFonts.bangers(
                  fontSize: _bandBad
                      ? 18
                      : (widget.prototypeVisualState && !wideScreen
                          ? 18
                          : 22),
                  height: 1,
                  letterSpacing: 0.6,
                  color: color,
                  shadows: [
                    const Shadow(
                      color: Color(0xEB080B12),
                      offset: Offset(0, 3),
                    ),
                    Shadow(color: glow.withValues(alpha: 0.9), blurRadius: 14),
                    Shadow(
                      color: glow.withValues(alpha: 0.55),
                      blurRadius: 32,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _cards() {
    final subs = [context.l10n.osmanRoleSub, context.l10n.tusRoleSub];
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
            asset: _hisirBeat && _speakerIndex == 0
                ? HisirCharacter.assetPath
                : OsmantusCast.duo[0].assetPath,
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
            asset: _hisirBeat && _speakerIndex == 1
                ? HisirCharacter.assetPath
                : OsmantusCast.duo[1].assetPath,
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
          context.l10n.osmantusPressGreenButton,
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
          context.l10n.osmantusDoubleButton,
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

