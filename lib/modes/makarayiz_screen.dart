import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../models/hisir_character.dart';
import '../models/insect_tier.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/finish_run.dart';
import '../services/global_notify.dart';
import '../services/haptic_service.dart';
import '../services/leaderboard_service.dart';
import '../services/progress_manager.dart';
import '../widgets/arcade_chrome.dart';
import '../widgets/sticker_image.dart';
import '../widgets/mode_bonus_bar.dart';

const _tcol = [
  Color(0xFFFFE9C9),
  Color(0xFFFFE3D6),
  Color(0xFFE4F0FF),
  Color(0xFFF3E4FF),
  Color(0xFFFFE0EC),
  Color(0xFFDFF7EA),
  Color(0xFFFFF0D6),
  Color(0xFFE8ECF5),
  Color(0xFFFFE1E1),
  Color(0xFFFFE0EC),
  Color(0xFFEDF1F8),
  Color(0xFFE8ECF5),
  Color(0xFFFFDFF2),
];

class _Note {
  _Note(this.lane, this.hitMs, this.tier, this.travelMs, {this.isHisir = false});
  final int lane;
  double hitMs;
  final int tier; // 0-based
  final double travelMs;

  /// Hışır derisi: nota bu kademenin notası gibi davranır (zamanlama,
  /// skor aynen), yalnız görseli `hisir_hd.png`, vuruş sesi
  /// `hisir_zopa.mp3`.
  final bool isHisir;
  bool done = false;
}

/// Makarayız — notalar beat çizgisine akar; vuruş penceresi çizgiye bağlıdır.
/// Zaman tek bir Ticker saatinden gelir (kare başına), böylece ses/görsel/giriş
/// aynı saatte kalır.
class MakarayizScreen extends StatefulWidget {
  const MakarayizScreen({
    super.key,
    this.energyConsumed = false,
    @visibleForTesting this.prototypeVisualState = false,
  });

  /// `true` ise bu ekrana giriş `openGameMode` üzerinden 1 enerji
  /// tüketerek yapıldı; hiç hamle yapılmadan çıkılırsa enerji iade
  /// edilir (Suika `GameScreen` deseni). Doğrudan rota girişlerinde
  /// `false` kalır.
  final bool energyConsumed;

  final bool prototypeVisualState;

  @override
  State<MakarayizScreen> createState() => MakarayizScreenState();
}

class MakarayizScreenState extends State<MakarayizScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const tutorialMs = 15000;
  static const _noteSize = 45.0;
  static const _beatInset = 44.0; // beat çizgisi şerit tabanından yukarıda

  late final Ticker _ticker;

  /// Kare sayacı (10E, 8C VLB deseni): `advance` yalnız bu sayacı
  /// artırır; sahne [ValueListenableBuilder] ile yenilenir. Tick
  /// sıklığı ve vuruş penceresi (140-230 ms) aynen korunur.
  final ValueNotifier<int> _tickNotifier = ValueNotifier<int>(0);
  final _rng = Random();

  final List<_Note> _notes = [];
  double _now = 0; // ms
  double _nextHit = 0;
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _best = 0;
  int _lives = 3;
  int _hits = 0;
  int _misses = 0;
  double _reel = 0;
  double _nextPulseMs = 1800;
  bool _alive = true;
  bool _resultShown = false;

  /// 12P: tur sayacı — sahne giriş animasyonu her turda yeniden
  /// oynar (`TweenAnimationBuilder` anahtarı). `_boot` artırır.
  int _roundId = 0;

  /// 12P: bitiş sebebi satırı — sonuç ekranının alt başlığında
  /// görünür (can bitmesi / erken bitirme). `_gameOver` can bitmesi
  /// sebebini yazar, `_finishEarly` erken bitirme sebebini.
  String? _endReason;

  /// 12P: BİTİR onay diyaloğu açıkken ticker bu bayrakla durdurulur;
  /// iptalde yalnız bu bayrak set edildiyse devam edilir (yardım /
  /// çıkış-onayı deseni).
  bool _pausedForFinishConfirm = false;
  bool _finishConfirmShowing = false;

  /// Y3 idempotency damgası: tur başlangıcında bir kez alınır
  /// (`_boot`); aynı turun tüm bitiş yolları aynı anahtarı kullanır,
  /// yeni tur yeni damga alır. Bitiş anında `DateTime.now()` alınmaz.
  int _runStartedAtUs = DateTime.now().microsecondsSinceEpoch;

  /// Hamle bayrağı (enerji iadesi): oturum boyunca ilk şerit dokunuşu
  /// (`tryHit`, ıska da dahil), oto-vuruş isabeti (`_hit`) veya tur
  /// tamamlanması (`_gameOver`) ile `true` olur; TEKRAR/yeniden
  /// başlatmada SIFIRLANMAZ (Suika `_dropsMade` deseni — oturum ömrü).
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
  // elle duraklatmada da aynı ticker durdurulur; oyun saati (_now) donar.
  bool _paused = false;
  bool _pausedByLifecycle = false;
  // F9: yardım diyaloğu açıkken ticker bu bayrakla durdurulur; diyalog
  // kapanınca yalnız bu bayrak set edildiyse devam edilir.
  bool _pausedForHelp = false;

  /// N7 çıkış onayı durumu: onay bayrağı (diyalogda Çık seçildiyse
  /// `PopScope` çıkışı geçirir), çift-diyalog kilidi ve diyalog
  /// duraklatması bayrağı (yardım deseni: yalnız bu diyalog için
  /// duraklatıldıysa kapanınca devam edilir).
  bool _exitConfirmed = false;
  bool _exitConfirmShowing = false;
  bool _pausedForExitConfirm = false;
  String _hint = '';
  bool _hintSeeded = false;
  String? _comboText;
  String? _breakText;
  String? _gainText;
  double _textUntil = 0;
  double _pulseAt = -1000;
  double _freezeUntil = 0;
  double _autoUntil = 0;
  double _x2Until = 0;
  int _bubbleTier = 2;

  bool get _auto => _now < _autoUntil;
  bool get _x2 => _now < _x2Until;

  /// İlk 15 sn eğitim hızı; sonra beat sıklaşır, nota daha hızlı iner.
  double _rampAt(double timeMs) =>
      ((timeMs - tutorialMs) / 60000).clamp(0.0, 1.0).toDouble();
  double _beatAt(double timeMs) => lerpDouble(900, 520, _rampAt(timeMs))!;
  double _travelAt(double timeMs) => lerpDouble(2600, 1500, _rampAt(timeMs))!;
  double get beatMs => _beatAt(_now);
  double get windowMs => lerpDouble(230, 140, _rampAt(_now))!;
  double get perfectMs => 70;

  @visibleForTesting
  List<({int lane, double hitMs})> get debugNotes => [
    for (final n in _notes)
      if (!n.done) (lane: n.lane, hitMs: n.hitMs),
  ];
  @visibleForTesting
  double get debugNow => _now;
  @visibleForTesting
  double get debugBeatMs => beatMs;
  @visibleForTesting
  double get debugWindowMs => windowMs;
  @visibleForTesting
  int get debugScore => _score;
  @visibleForTesting
  int get debugBest => _best;
  @visibleForTesting
  int get debugCombo => _combo;
  @visibleForTesting
  int get debugLives => _lives;
  @visibleForTesting
  int get debugMisses => _misses;
  @visibleForTesting
  bool get debugAlive => _alive;
  @visibleForTesting
  String? get debugBreakText => _breakText;
  @visibleForTesting
  String get debugHint => _hint;
  @visibleForTesting
  int get debugRoundId => _roundId;
  @visibleForTesting
  String? get debugEndReason => _endReason;
  @visibleForTesting
  bool get debugResultShown => _resultShown;
  @visibleForTesting
  bool get debugPausedForFinishConfirm => _pausedForFinishConfirm;

  /// 12P: dondurma gücünün test yolu — yalnız `_freezeUntil`
  /// yazar (ses/ipucu yok); güç envanteri testte 0 olduğu için
  /// düğme üzerinden tetiklenemez.
  @visibleForTesting
  void debugApplyFreeze(double durationMs) {
    _freezeUntil = _now + durationMs;
  }

  /// 12P: yeniden başlatmanın test yolu.
  @visibleForTesting
  void debugRestart() => _restart();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hintSeeded) {
      _hintSeeded = true;
      _hint = context.l10n.makaraHintIdle;
    }
  }

  void _setIdleHint() {
    // initState yolundan çağrılırsa tohum didChangeDependencies'te atılır.
    if (_hintSeeded) _hint = context.l10n.makaraHintIdle;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.prototypeVisualState) {
      _score = 1105;
      _best = 1760;
      _combo = 8;
      _reel = 0.64;
      _comboText = 'COMBO X8!';
      _textUntil = double.infinity;
      return;
    }
    AudioManager().initialize();
    unawaited(ProgressManager().load());
    _loadBest();
    _boot();
    _ticker = createTicker(_onTick)..start();
  }

  void _boot() {
    // Y3: tur başlangıç damgası — her turda bir kez yenilenir; monoton
    // koruma aynı mikrosaniyede başlayan iki turun anahtar çakışmasını
    // engeller (aynı anahtar ikinci turu ödeme dışı bırakırdı).
    _runStartedAtUs = max(
      DateTime.now().microsecondsSinceEpoch,
      _runStartedAtUs + 1,
    );
    _notes.clear();
    _now = 0;
    _nextHit = 1800;
    _score = 0;
    _combo = 0;
    _bestCombo = 0;
    _lives = 3;
    _hits = 0;
    _misses = 0;
    _reel = 0;
    _nextPulseMs = _nextHit;
    _alive = true;
    _paused = false;
    _pausedByLifecycle = false;
    _pausedForHelp = false;
    _roundId++;
    _endReason = null;
    _pausedForFinishConfirm = false;
    _finishConfirmShowing = false;
    _lastElapsed = null;
    _comboText = null;
    _breakText = null;
    _gainText = null;
    _freezeUntil = _autoUntil = _x2Until = 0;
    _setIdleHint();
  }

  Future<void> _loadBest() async {
    // F4: ateşle-unut çağrısı; liderlik yüklemesi fırlatırsa hata
    // yutulur, rekor 0 kalır, oyun etkilenmez.
    try {
      await LeaderboardService.instance.ensureLoaded();
      if (!mounted) return;
      setState(() {
        _best = LeaderboardService.instance.getBest(
          LeaderboardService.modeMakarayiz,
        );
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!widget.prototypeVisualState) {
      AudioManager().stopAll();
      _ticker.dispose();
    }
    _tickNotifier.dispose();
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
        // Osmantuş deseni: arka planda ticker dursun; dönüşte _lastElapsed
        // sıfırlanır, dt kısması da ikinci korumadır.
        if (_ticker.isActive) {
          _ticker.stop();
          _pausedByLifecycle = true;
        }
        break;
      case AppLifecycleState.resumed:
        // Elle duraklatılmışsa dönüşte kendiliğinden başlamasın.
        if (_pausedByLifecycle && !_paused) {
          _pausedByLifecycle = false;
          _lastElapsed = null;
          if (_alive && !_ticker.isActive) _ticker.start();
        }
        break;
    }
  }

  /// Elle duraklatma / devam (madde 37): ticker durur, oyun saati donar.
  void _togglePause() {
    if (widget.prototypeVisualState || !_alive) return;
    // 10D P0-3: duraklatma sesi + titreşimi tek çağrıda
    // (playButtonTap içi selectionClick; ayrıca trigger* eklenmez).
    unawaited(AudioManager().playButtonTap());
    if (_paused) {
      _paused = false;
      _pausedByLifecycle = false;
      _lastElapsed = null;
      if (!_ticker.isActive) _ticker.start();
    } else {
      _paused = true;
      _ticker.stop();
    }
    setState(() {});
  }

  /// Yardım diyaloğu açılırken oyunu duraklat (F9): ticker durur,
  /// oyun saati donar; notalar düşmez, can kaybı olmaz. Önceden elle
  /// duraklatılmışsa bayrak set edilmez, kapanınca devam edilmez.
  void _pauseForHelpDialog() {
    if (widget.prototypeVisualState || !_alive || _paused) return;
    if (_ticker.isActive) {
      _ticker.stop();
      _pausedForHelp = true;
    }
  }

  /// Yardım diyaloğu kapanınca devam et (F9): yalnız diyalog
  /// duraklatmasıysa ve elle/lifecycle duraklatması yoksa ticker
  /// yeniden başlar.
  void _resumeAfterHelpDialog() {
    if (widget.prototypeVisualState || !_pausedForHelp) return;
    _pausedForHelp = false;
    _lastElapsed = null;
    if (_alive && !_paused && !_pausedByLifecycle && !_ticker.isActive) {
      _ticker.start();
    }
  }

  Duration? _lastElapsed;
  void _onTick(Duration elapsed) {
    var dt = _lastElapsed == null
        ? 0.0
        : (elapsed - _lastElapsed!).inMicroseconds / 1000.0;
    _lastElapsed = elapsed;
    if (!_alive) return;
    if (_paused) return;
    // Kare süresi kısması: arka plan dönüşü / takılma sonrası dev dt,
    // oyun saatini ileri fırlatıp birikmiş notaları toplu kaçırmasın.
    dt = dt.clamp(0.0, 33.0).toDouble();
    // Opening grace in live ticker mode so the very first note before the
    // player's first tap doesn't immediately deduct a life at 1.9s.
    if (_hits == 0 && _now + dt < 4200) {
      for (final n in _notes) {
        if (!n.done && (_now + dt) - n.hitMs > windowMs * 0.85) {
          n.done = true;
          _showText(combo: context.l10n.makaraBeatLine);
        }
      }
    }
    advance(dt);
  }

  /// Oyun saatini ileri sar (test ve ticker ortak yolu).
  @visibleForTesting
  void advance(double dtMs) {
    final freezeFor = min(dtMs, max(0.0, _freezeUntil - _now));
    if (freezeFor > 0) {
      for (final note in _notes) {
        if (!note.done) note.hitMs += freezeFor;
      }
      _nextHit += freezeFor;
      _nextPulseMs += freezeFor;
    }
    _now += dtMs;
    while (_nextHit - _now <= _travelAt(_nextHit)) {
      _notes.add(
        _Note(
          _rng.nextInt(3),
          _nextHit,
          _rng.nextInt(InsectTier.values.length),
          _travelAt(_nextHit),
          isHisir:
              !widget.prototypeVisualState && HisirCharacter.roll(_rng),
        ),
      );
      _nextHit += _beatAt(_nextHit);
    }
    if (_auto) {
      for (final n in _notes) {
        if (!n.done && _now >= n.hitMs) _hit(n);
      }
    }
    // Kare başına en fazla 1 can kaybı: aynı karede birden çok nota
    // kaçsa bile diğerleri yalnız kombo/ıska sayar, can almaz.
    var lifeLost = false;
    for (final n in _notes) {
      if (!n.done && _now - n.hitMs > windowMs) {
        n.done = true;
        final loseLife = !lifeLost;
        lifeLost = true;
        _breakCombo(context.l10n.missedCaps, loseLife: loseLife);
        // F18: canlar bittiyse (_gameOver) aynı karedeki diğer kaçan
        // notalar _misses'i şişirmesin; döngüden çık.
        if (!_alive) break;
      }
    }
    _notes.removeWhere((n) => n.done && _now - n.hitMs > 400);
    while (_nextPulseMs <= _now) {
      _pulseAt = _nextPulseMs;
      _nextPulseMs += _beatAt(_nextPulseMs);
    }
    if (_textUntil.isFinite && _now > _textUntil) {
      _comboText = null;
      _breakText = null;
      _gainText = null;
    }
    // 12P: canlar bu yolda (kaçan nota) biterse `_gameOver` çalışır
    // ama dış `build()` çalışmadığı için `build()` içindeki
    // `_edgeShowResult` kenarı hiç tetiklenmezdi — sonuç ekranı
    // açılmaz, `_alive == false` olduğu için `_onTick` erken döner
    // ve oyun sonsuza dek donardı (video: ~10. sn donma, ~14. sn
    // BİTİR'e basınca sonuç). Sonucu buradan da tetikle; bayrak
    // (`_resultShown`) çift sunumu engeller.
    if (!_alive && !_resultShown) _edgeShowResult();
    if (mounted) _tickNotifier.value++;
  }

  void _showText({String? combo, String? brk, String? gain}) {
    _comboText = combo;
    _breakText = brk;
    _gainText = gain;
    _textUntil = _now + 1400;
  }

  void _breakCombo(String reason, {required bool loseLife}) {
    final had = _combo;
    _combo = 0;
    _misses++;
    _hint = context.l10n.makaraMissWindow(reason, windowMs.round());
    _showText(brk: had >= 2 ? context.l10n.makaraComboBroken(reason) : reason);
    unawaited(HapticService.instance.heavyImpact());
    // 10D P0-2: ıska sesi — playDrop. Ses çağrısı kapılı lightImpact
    // içerir; yukarıdaki heavyImpact ile aynı tick'te 18 ms kapısına
    // takılıp düşer — toplam 1 impuls (ağır olan korunur). Bu tek
    // _breakCombo erken/yanlış/kaçan üç ıska yolunu da kapsar.
    AudioManager().playDrop();
    if (loseLife) {
      _lives -= 1;
      if (_lives <= 0) _gameOver();
    }
  }

  void _gameOver() {
    // Tur tamamlandı: iade hakkı biter (dokunmadan can kaybedip
    // biten tur da turdur; bayrak oturum ömründe kalır).
    _moveMade = true;
    _alive = false;
    _hint = context.l10n.makaraReelOut;
    // 12P: bitiş sebebi sonuç ekranında görünür.
    _endReason = context.l10n.makaraReelOut;
    // D1: bitiş sesi tek kaynak — sonuç ekranı çalar.
    unawaited(
      LeaderboardService.instance.submitScore(
        LeaderboardService.modeMakarayiz,
        _score,
      ),
    );
    if (_score > _best) _best = _score;
  }

  void _hit(_Note n) {
    // Oto-vuruş (OTO MAKARA) da buradan geçer: isabet hamle sayılır.
    _moveMade = true;
    final d = (_now - n.hitMs).abs();
    n.done = true;
    _combo += 1;
    _bestCombo = max(_bestCombo, _combo);
    _hits++;
    final perfect = d <= perfectMs;
    final gain = (60 + _combo * 10 + (perfect ? 40 : 0)) * (_x2 ? 2 : 1);
    _score += gain;
    _reel += 0.08;
    if (_reel >= 1) {
      _reel = 0;
      _score += 250;
      _lives = min(3, _lives + 1);
      // 10F P2-4: dolum anı sesi — playPop kapılı lightImpact içerir;
      // aynı _hit içindeki playMakaraSpin haptic'i ile çakışırsa 18 ms
      // kapı ikinciyi düşürür, tek impuls kalır.
      unawaited(AudioManager().playPop());
    }
    // G33: REKOR HUD'da canlı güncellenir (match3 deseni: skor yazılan
    // her yerde `_best` eşitlenir; kalıcı kayıt `_gameOver` /
    // `finishRun` akışında aynen kalır).
    if (_score > _best) _best = _score;
    final bug = InsectTier.values[n.tier];
    _bubbleTier = n.tier;
    _hint = n.isHisir ? HisirCharacter.replik : bug.viralReplik;
    _showText(
      combo: _combo >= 2
          ? 'COMBO X$_combo!'
          : (perfect ? context.l10n.perfectCaps : null),
      gain: '+$gain X$_combo',
    );
    final rate = 0.95 + _rng.nextDouble() * 0.2;
    if (n.isHisir) {
      // Makara SFX'i seste, Hışır sesi tek yoldan: kademe sesi
      // Hışır'ı kesmez, Hışır klibi tam çalar (12K düzeni).
      unawaited(
        AudioManager().playMakaraSpin(
          comboCount: _combo,
          playbackRate: rate,
        ),
      );
      unawaited(AudioManager().playHusurAday());
    } else {
      unawaited(
        AudioManager().playMakaraSpin(
          bug: bug,
          comboCount: _combo,
          playbackRate: rate,
        ),
      );
    }
  }

  /// Şerit vuruşu: pencere içindeki en yakın nota, çizgiye bağlıdır.
  void tryHit(int lane) {
    if (!_alive || _paused) return;
    // Enerji iadesi sayacı: şerit dokunuşu anında sayılır (ıska,
    // erken veya yanlış şerit de hamle sayılır — Suika deseni).
    _moveMade = true;
    _Note? best;
    double bestD = windowMs + 1;
    for (final n in _notes) {
      if (n.done) continue;
      final d = (_now - n.hitMs).abs();
      if (d <= windowMs && n.lane == lane && d < bestD) {
        best = n;
        bestD = d;
      }
    }
    if (best != null) {
      _hit(best);
    } else {
      final other =
          _notes
              .where(
                (n) =>
                    !n.done &&
                    n.lane != lane &&
                    (_now - n.hitMs).abs() <= windowMs,
              )
              .toList()
            ..sort(
              (a, b) =>
                  (_now - a.hitMs).abs().compareTo((_now - b.hitMs).abs()),
            );
      if (other.isNotEmpty) {
        other.first.done = true;
        _breakCombo(context.l10n.makaraWrongLane, loseLife: true);
      } else if (_notes.any((n) => !n.done && n.lane == lane)) {
        _breakCombo(context.l10n.makaraEarlyTap, loseLife: false);
      } else {
        // W13-F: şeritte hiç nota yokken dokunuş TAMAMEN sessizdi —
        // oyuncu neyin yanlış olduğunu öğrenemiyordu (playtest §11:
        // "büyük düğmeye 5 basış + şeride dokunuş skor vermedi" ve
        // "TAPPED TOO EARLY dışında geri bildirim yok"). Yalnız
        // öğretici ipucu güncellenir (artık görünür satırda);
        // skor/can/kombo/ıska sayacı aynen kalır — mekanik değişmez.
        _hint = context.l10n.makaraBeatLine;
      }
    }
    setState(() {});
  }

  void _restart() {
    setState(_boot);
    if (!widget.prototypeVisualState && !_ticker.isActive) _ticker.start();
  }

  bool _useBeatFreeze() {
    if (!_alive || _paused) return false;
    unawaited(AudioManager().playButtonTap());
    setState(() {
      _freezeUntil = _now + 8000;
      _hint = context.l10n.makaraFreezeHint;
      _showText(combo: context.l10n.makaraFreezeCallout);
    });
    return true;
  }

  bool _useAuto() {
    if (!_alive || _paused) return false;
    unawaited(AudioManager().playButtonTap());
    setState(() {
      _autoUntil = _now + 6000;
      _hint = context.l10n.makaraAutoHint;
      _showText(combo: context.l10n.makaraAutoCallout);
    });
    return true;
  }

  bool _useX2() {
    if (!_alive || _paused) return false;
    unawaited(AudioManager().playButtonTap());
    setState(() {
      _x2Until = _now + 12000;
      _hint = context.l10n.makaraX2Hint;
      _showText(combo: context.l10n.makaraX2Active);
    });
    return true;
  }

  Future<void> _presentResult({bool? won}) async {
    // S1#49: ödeme + liderlik + görev kaydı + sonuç ekranı finishRun()
    // üzerinden (tek-ödeme korunur). _gameOver'daki liderlik gönderimi
    // ayrıca durur (eski çift-gönderim davranışı aynen korunur).
    // Doğal bitiş canların bitmesidir (kayıp); `won` verilmezse
    // kayıp başlığı gösterilir.
    // F4: finishRun fırlatırsa sonuçsuz takılma olmasın — bayrak
    // düşürülür, BİTİR/geri ile yeniden deneme yolu açık kalır.
    // setState çağrılmaz: yeniden çizim _edgeShowResult'u tetikleyip
    // hatayı döngüye sokardı.
    bool replay;
    try {
      replay = await finishRun(
        context,
        score: _score,
        best: _best,
        bestCombo: _bestCombo,
        won: won ?? false,
        // 12P: bitiş sebebi sonuç ekranının alt başlığında görünür.
        resultLine: _endReason,
        leaderboardMode: LeaderboardService.modeMakarayiz,
        // K16: mod skoru kimliği liderlik kimliğiyle aynıdır
        // (`lululu_game_mode.dart` bestScoreKey: 'makarayiz').
        modeScoreId: LeaderboardService.modeMakarayiz,
        // Y3: tur başlangıç damgalı anahtar; bu turun tüm bitiş
        // yolları (_finishEarly + _edgeShowResult) aynı anahtarı
        // paylaşır, çift ödeme/gösterim engellenir.
        idempotencyKey: '${LeaderboardService.modeMakarayiz}:$_runStartedAtUs',
      );
    } catch (_) {
      if (mounted) _resultShown = false;
      return;
    }
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

  /// N7 diyalog duraklatması (yardım deseni: `_pauseForHelpDialog`
  /// ile aynı — yalnız ticker durur, `_paused` bayrağı konmaz,
  /// duraklatma kaplaması açılmaz; oyun saati donar).
  void _pauseForExitConfirm() {
    if (widget.prototypeVisualState || !_alive || _paused) return;
    if (_ticker.isActive) {
      _ticker.stop();
      _pausedForExitConfirm = true;
    }
  }

  void _resumeAfterExitConfirm() {
    if (widget.prototypeVisualState || !_pausedForExitConfirm) return;
    _pausedForExitConfirm = false;
    _lastElapsed = null;
    if (_alive && !_paused && !_pausedByLifecycle && !_ticker.isActive) {
      _ticker.start();
    }
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

  /// BİTİR: 12P — tek dokunuşla tur bitmez; onay istenir (video:
  /// donan oyundan çıkmak için BİTİR'e basılınca skor > 0 diye
  /// "SEVİYE TAMAM!" açılmıştı — Makarayız'da seviye hedefi yok).
  /// Onayda tur kazanıldı sayılmaz (`won: false`) ve erken-bitirme
  /// sebebi sonuç ekranında görünür. Onay diyaloğu açıkken ticker
  /// durur (yardım/çıkış-onayı deseni); iptalde oyun kaldığı yerden
  /// devam eder.
  Future<void> _finishEarly() async {
    if (_resultShown || _finishConfirmShowing) return;
    _finishConfirmShowing = true;
    _pauseForFinishConfirm();
    final confirmed = await _confirmFinishRound();
    _finishConfirmShowing = false;
    if (!mounted) return;
    if (!confirmed) {
      _resumeAfterFinishConfirm();
      return;
    }
    _resultShown = true;
    // Canlar zaten bittiyse sebep can bitmesidir, erken bitirme değil.
    if (_alive) _endReason = context.l10n.makaraFinishedEarlyReason;
    await _presentResult(won: false);
  }

  /// BİTİR onay diyaloğu (N7 çıkış-onayı deseni).
  Future<bool> _confirmFinishRound() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.makaraFinishConfirmTitle),
        content: Text(ctx.l10n.makaraFinishConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.confirm),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// BİTİR onayı duraklatması (yardım deseni: yalnız ticker durur,
  /// `_paused` bayrağı konmaz, duraklatma kaplaması açılmaz).
  void _pauseForFinishConfirm() {
    if (widget.prototypeVisualState || !_alive || _paused) return;
    if (_ticker.isActive) {
      _ticker.stop();
      _pausedForFinishConfirm = true;
    }
  }

  void _resumeAfterFinishConfirm() {
    if (widget.prototypeVisualState || !_pausedForFinishConfirm) return;
    _pausedForFinishConfirm = false;
    _lastElapsed = null;
    if (_alive && !_paused && !_pausedByLifecycle && !_ticker.isActive) {
      _ticker.start();
    }
  }

  void _edgeShowResult() {
    if (_resultShown) return;
    _resultShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _presentResult();
    });
  }

  static const _fixtureNotes = [
    [(8.0, 3), (46.0, 1), (72.0, 5)],
    [(26.0, 4), (62.0, 2)],
    [(14.0, 6), (52.0, 3), (80.0, 1)],
  ];

  Widget _note(
    double top,
    int tier, {
    double opacity = 1,
    bool wideScreen = false,
    bool isHisir = false,
  }) {
    final bug =
        InsectTier.values[(tier - 1).clamp(0, InsectTier.values.length - 1)];
    final assetPath = isHisir ? HisirCharacter.assetPath : bug.assetPath;
    if (wideScreen) {
      final topPad = (tier == 3 || tier == 4)
          ? 3.15
          : (tier == 2 ? 5.9 : (tier == 1 ? 7.2 : (tier == 5 ? 5.5 : 5.3)));
      return Positioned(
        top: top,
        left: 0,
        right: 0,
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: _noteSize,
              height: _noteSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _tcol[(tier - 1) % _tcol.length],
              ),
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minWidth: 38.7,
                maxWidth: 38.7,
                minHeight: 0,
                maxHeight: 120,
                child: Padding(
                  padding: EdgeInsets.only(top: topPad),
                  child: Image.asset(
                    assetPath,
                    width: 38.7,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: _noteSize,
            height: _noteSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _tcol[(tier - 1) % _tcol.length],
            ),
            padding: const EdgeInsets.all(3),
            child: StickerImage(assetPath: assetPath, size: 39),
          ),
        ),
      ),
    );
  }

  Widget _lane(int lane, double h, {bool wideScreen = false}) {
    final beatY = h - _beatInset;
    final children = <Widget>[];
    if (widget.prototypeVisualState) {
      for (final (pct, tier) in _fixtureNotes[lane]) {
        children.add(_note(pct / 100 * h, tier, wideScreen: wideScreen));
      }
    } else {
      for (final n in _notes) {
        if (n.lane != lane) continue;
        final p = 1 - (n.hitMs - _now) / n.travelMs;
        final top = -_noteSize + (beatY - _noteSize / 2 + _noteSize) * p;
        if (n.done) {
          children.add(
            _note(
              top,
              n.tier + 1,
              opacity: 0.0,
              wideScreen: wideScreen,
              isHisir: n.isHisir,
            ),
          );
        } else {
          children.add(
            _note(
              top,
              n.tier + 1,
              wideScreen: wideScreen,
              isHisir: n.isHisir,
            ),
          );
        }
      }
    }
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => tryHit(lane),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x0FFFFFFF)),
          ),
          child: wideScreen
              ? Stack(clipBehavior: Clip.none, children: children)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(children: children),
                ),
        ),
      ),
    );
  }

  TextStyle _bangers(double size, Color c, Color glow) => GoogleFonts.bangers(
    fontSize: size,
    height: 1,
    letterSpacing: 0.6,
    color: c,
    shadows: [
      const Shadow(color: Color(0xEB080B12), offset: Offset(0, 3)),
      Shadow(color: glow.withValues(alpha: 0.9), blurRadius: 14),
      Shadow(color: glow.withValues(alpha: 0.55), blurRadius: 32),
      Shadow(color: glow.withValues(alpha: 0.32), blurRadius: 54),
    ],
  );

  @override
  Widget build(BuildContext context) {
    // S6: iade bildirimi metni çıkıştan ÖNCE yakalanır
    // (`didPop` anında bağlam ağaçta değildir).
    _refundNotice = context.l10n.energyRefundNotice;
    if (!_alive && !_resultShown) _edgeShowResult();
    final proto = widget.prototypeVisualState;
    final wideScreen = MediaQuery.sizeOf(context).width >= 400;

    // Statik arka plan: kare bildiriminde yeniden kurulmaz --
    // [ValueListenableBuilder] `child` olarak bir kez kurulur.
    final background = Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: wideScreen ? 0.96 : 1,
            child: Image.asset(
              'assets/design/backgrounds/makarayiz_stage.webp',
              fit: BoxFit.cover,
              alignment: wideScreen ? Alignment.center : Alignment.centerLeft,
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: wideScreen
                    ? const [0, 0.24, 0.76, 1]
                    : const [0, 0.3, 0.58, 1],
                colors: wideScreen
                    ? const [
                        Color(0x4D080B12),
                        Color(0x00080B12),
                        Color(0x00080B12),
                        Color(0x52080B12),
                      ]
                    : const [
                        Color(0x7A080B12),
                        Color(0x00080B12),
                        Color(0x00080B12),
                        Color(0x94080B12),
                      ],
              ),
            ),
          ),
        ),
      ],
    );
    return PopScope(
      canPop: _exitConfirmed || !_needsExitConfirm,
      onPopInvokedWithResult: (didPop, _) => _handleExitPop(didPop),
      child: ValueListenableBuilder<int>(
        valueListenable: _tickNotifier,
        child: background,
        builder: (context, _, backgroundChild) {
          // Kare başına değişen değerler burada, VLB içinde okunur
          // (dış `build` yalnız olay `setState`'lerinde çalışır).
          final pulse = proto
              ? 0.0
              : (1 - ((_now - _pulseAt) / 220).clamp(0.0, 1.0));
          final pct = (_reel * 100).round();
          final hero = InsectTier.values[proto ? 2 : _bubbleTier];
          return _MakarayizChrome(
            score: _score,
            best: _best,
            combo: _combo,
            hint: _hint,
            onRestart: _finishEarly,
            prototypeVisualState: proto,
            showPauseButton: !proto,
            onPausePressed: _togglePause,
            onHelpOpened: _pauseForHelpDialog,
            onHelpClosed: _resumeAfterHelpDialog,
            // F6: tek sonuç yolu finishRun diyaloğudur (_edgeShowResult);
            // ölü ArcadeResultOverlay dalı kaldırıldı.
            overlay: _paused ? _pauseOverlay() : null,
            bonuses: [
              stockBonusWithResult(
                id: 'beat',
                label: context.l10n.powerBeatFreezeCaps,
                asset: 'assets/icons2/clock.png',
                effect: _useBeatFreeze,
              ),
              stockBonusWithResult(
                id: 'auto',
                label: context.l10n.powerAutoReelCaps,
                asset: 'assets/icons2/wheel.png',
                effect: _useAuto,
              ),
              stockBonusWithResult(
                id: 'x2',
                label: context.l10n.powerScoreX2,
                asset: 'assets/icons2/boost_coins.png',
                effect: _useX2,
              ),
            ],
            background: backgroundChild!,
            stageBuilder: () {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() < 200) return;
                  // Kaydırma: en yakın nota şeridini yöne göre seç.
                  final cand =
                      _notes
                          .where(
                            (n) =>
                                !n.done && (_now - n.hitMs).abs() <= windowMs,
                          )
                          .toList()
                        ..sort(
                          (a, b) => (a.hitMs - _now).abs().compareTo(
                            (b.hitMs - _now).abs(),
                          ),
                        );
                  if (cand.isNotEmpty) tryHit(cand.first.lane);
                },
                child: TweenAnimationBuilder<double>(
                  // 12P: sahne girişi — şeritler ("boru") + beat çizgisi
                  // + makara, rota açılışında aniden belirmek yerine
                  // 600 ms'de solarak + hafifçe yükselerek girer
                  // (video: f02 liste → f03 sahne, sıfır geçiş).
                  // Anahtar tur sayacıdır: TEKRAR OYNA'da da yeniden
                  // oynar. Aynı turda kare yenilemeleri animasyonu
                  // başlatmaz (tween/anahtar değişmez). Prototip
                  // vitrininde (`prototypeVisualState`) giriş
                  // oynatılmaz: piksel yakalama statik kareyi
                  // değişmeden alır (begin == end → ilk karede tam
                  // görünür).
                  key: ValueKey<int>(_roundId),
                  tween: Tween<double>(begin: proto ? 1.0 : 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 28),
                      child: child,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final h = c.maxHeight - 12 - 74 - 2;
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    74,
                                  ),
                                  child: Row(
                                    children: [
                                      for (var i = 0; i < 3; i++) ...[
                                        if (i > 0) const SizedBox(width: 7),
                                        _lane(i, h, wideScreen: wideScreen),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 118,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              boxShadow: pulse > 0
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFFD700,
                                        ).withValues(alpha: 0.7 * pulse),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: CustomPaint(
                              size: const Size(double.infinity, 3),
                              painter: _DashPainter(),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: -19,
                            child: Text(
                              'BEAT',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: const Color(0xFFFFD700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: _reelWrap(hero, pct, wideScreen: wideScreen),
                    ),
                    if (!proto)
                      Positioned(
                        right: 12,
                        top: 10,
                        // 12P: biten can `♡` ince kontur olarak açık
                        // zemin üstünde görünmez oluyordu (video:
                        // m10/m12'de kalp yok sanıldı). Biten can da
                        // aynı dolu glifle, yalnız soluk renkte çizilir;
                        // 3 yuva her zaman görünür.
                        child: IgnorePointer(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Text(
                                  '♥',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: const Color(
                                      0xFFE01E5A,
                                    ).withValues(alpha: i < _lives ? 1 : 0.3),
                                    height: 1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (_comboText != null || _breakText != null)
                      Positioned(
                        left: 12,
                        top: 10,
                        child: IgnorePointer(
                          child: _breakText != null
                              ? Text(
                                  _breakText!,
                                  style: _bangers(
                                    21,
                                    const Color(0xFFE52E2E),
                                    const Color(0xFFFFD700),
                                  ),
                                )
                              : Text(
                                  _comboText!,
                                  style: _bangers(
                                    23,
                                    const Color(0xFFFFB800),
                                    const Color(0xFFFF6B35),
                                  ),
                                ),
                        ),
                      ),
                    if (_gainText != null && !proto)
                      Positioned(
                        left: 126,
                        top: 58,
                        child: IgnorePointer(
                          child: Text(
                            _gainText!,
                            style: _bangers(
                              20,
                              const Color(0xFFFFB800),
                              const Color(0xFFFF6B35),
                            ),
                          ),
                        ),
                      ),
                    if (proto || (_combo >= 2 && _alive))
                      Positioned(
                        right: 12,
                        bottom: 158,
                        child: IgnorePointer(
                          child: _bubble(hero, wideScreen: wideScreen),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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

  Widget _bubble(InsectTier bug, {bool wideScreen = false}) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 176),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xF0080B12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xBFE01E5A), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x8CE01E5A), blurRadius: 14),
              BoxShadow(
                color: Color(0x73000000),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            widget.prototypeVisualState
                ? 'MAKARAYIZ ABİ!'
                // TR büyük harf: Dart'ın toUpperCase() 'ı'→'I',
                // 'ş'→'Ş' vb.'yi doğru yapar ama 'i'→'I' üretir
                // (doğrusu 'İ'). viralReplik her dilde Türkçedir
                // (bkz. insect_tier.dart), o yüzden 'i' önce 'İ'ye
                // çevrilir, sonra toUpperCase() uygulanır.
                : bug.viralReplik.replaceAll('i', 'İ').toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: GoogleFonts.bangers(
              fontSize: 16.5,
              height: 1.05,
              letterSpacing: 0.6,
              color: const Color(0xFFFFB800),
              shadows: const [Shadow(color: Color(0xA6E01E5A), blurRadius: 10)],
            ),
          ),
        ),
        if (wideScreen)
          const Positioned(
            bottom: -7,
            child: CustomPaint(
              size: Size(14, 7),
              painter: _BubbleTailPainter(),
            ),
          ),
      ],
    );
  }

  Widget _reelWrap(InsectTier hero, int pct, {bool wideScreen = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFFFFD34D), Color(0xFFFFB800), Color(0xFFD98E00)],
              stops: [0, 0.65, 1],
            ),
            border: Border.all(color: const Color(0xFF8A5A00), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: StickerImage(assetPath: hero.assetPath, size: 41),
        ),
        const SizedBox(height: 5),
        FractionallySizedBox(
          widthFactor: 0.62,
          child: Column(
            children: [
              Container(
                height: 15,
                decoration: BoxDecoration(
                  color: const Color(0x24FFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _reel.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB800), Color(0xFFFF6B35)],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.makaraFillPercent(pct),
                style: GoogleFonts.nunito(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                  color: const Color(0xFF9AA7BC),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xF0080B12)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) => false;
}

class _MakarayizChrome extends StatelessWidget {
  const _MakarayizChrome({
    required this.score,
    required this.best,
    required this.combo,
    required this.hint,
    required this.onRestart,
    required this.prototypeVisualState,
    required this.bonuses,
    required this.stageBuilder,
    required this.background,
    this.overlay,
    this.showPauseButton = false,
    this.onPausePressed,
    this.onHelpOpened,
    this.onHelpClosed,
  });

  final int score;
  final int best;
  final int combo;
  final String hint;
  final VoidCallback onRestart;
  final bool prototypeVisualState;
  final List<ModeBonus> bonuses;
  final Widget Function() stageBuilder;
  final Widget background;
  final Widget? overlay;
  final bool showPauseButton;
  final VoidCallback? onPausePressed;
  final VoidCallback? onHelpOpened;
  final VoidCallback? onHelpClosed;

  /// Yardım diyaloğu (F9): açılırken oyun duraklatılır, kapanınca
  /// (önceden duraklatılmamışsa) devam eder. Diyalog içeriği kural
  /// metnidir (F4, tek kaynak `makaraRules`); canlı hint yardım
  /// diyaloğuna sızmaz (bulgu #9). İki yardım düğmesi de (geniş/dar
  /// yerleşim) bu tek metoda bağlıdır.
  Future<void> _showHelpDialog(BuildContext context) async {
    onHelpOpened?.call();
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.makarayizTitle),
          // F4: kural metni; canlı hint yardım diyaloğuna
          // sızmaz (bulgu #9). Oyun-içi hint gösterimi aynen durur.
          content: Text(context.l10n.makaraRules),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.understoodButton),
            ),
          ],
        ),
      );
    } finally {
      onHelpClosed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final hasShellStatusBar = topPad > 0;
    final wideScreen = MediaQuery.sizeOf(context).width >= 400;
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B12),
        body: Stack(
          fit: StackFit.expand,
          children: [
            background,
            Column(
              children: [
                if (hasShellStatusBar) SizedBox(height: topPad),
                _header(context, wideScreen: wideScreen),
                _hud(wideScreen: wideScreen),
                // W13-F: öğretici ipucu satırı. `hint` (boşta "Nota beat
                // çizgisine gelince…", ıskada pencere bilgisi, güç
                // duyuruları) daha önce chrome'a geçiriliyor ama HİÇ
                // çizilmiyordu — kör testte doğru vuruş öğrenilemedi
                // (playtest §11). Mekanik aynen kalır: yalnız görünür
                // metin. Prototip vitrininde gizlidir (kare değişmez).
                if (!prototypeVisualState && hint.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xE6FFFFFF),
                        shadows: const [
                          Shadow(
                            color: Color(0xCC080B12),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: wideScreen
                            ? const [Color(0x660E1422), Color(0x800E1422)]
                            : const [Color(0x4C533351), Color(0x5952284E)],
                      ),
                      border: Border.all(
                        color: const Color(0x24FFFFFF),
                        width: 2,
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: stageBuilder(),
                    ),
                  ),
                ),
                _dock(context, wideScreen: wideScreen),
              ],
            ),
            ?overlay,
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, {required bool wideScreen}) {
    if (wideScreen) {
      return SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Row(
            children: [
              _RoundButton(
                semanticLabel: context.l10n.goBackLabel,
                child: Image.asset(
                  'assets/icons2/back-prototype.png',
                  width: 29,
                  height: 29,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: Color(0xFF4A9DDB),
                  ),
                ),
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  runSpacing: 3,
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
                      child: FittedBox(
                        // F-12 deseni: ellipsis yerine scaleDown —
                        // tam başlık her genişlikte sığar.
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.makarayizTitle,
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
                                color: Color(0xE6000000),
                                offset: Offset(0, 2),
                                blurRadius: 6,
                              ),
                              Shadow(
                                color: Color(0xD9000000),
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 20.3,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        context.l10n.viralBadge,
                        style: GoogleFonts.baloo2(
                          fontSize: 10.5,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
                    BoxShadow(color: Color(0x59000000), offset: Offset(0, 3)),
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
                      _format(
                        prototypeVisualState ? 12450 : ProgressManager().coins,
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
              const SizedBox(width: 10),
              if (showPauseButton) ...[
                _PauseHeaderButton(onTap: onPausePressed),
                const SizedBox(width: 10),
              ],
              _RoundButton(
                semanticLabel: context.l10n.helpButtonLabel,
                circular: true,
                borderColor: const Color(0xB3FFB800),
                child: Text(
                  '?',
                  style: GoogleFonts.baloo2(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFB800),
                  ),
                ),
                onTap: () => _showHelpDialog(context),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 8, 0),
        child: Row(
          children: [
            _RoundButton(
              semanticLabel: context.l10n.goBackLabel,
              child: Image.asset(
                'assets/icons2/back-prototype.png',
                width: 29,
                height: 29,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: Color(0xFF4A9DDB),
                ),
              ),
              onTap: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x66080B12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: FittedBox(
                      // F-12: 360 px'te başlık "MAKA..." diye
                      // kesiliyordu — FittedBox (scaleDown) tam
                      // başlığı sığdırır.
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.makarayizTitle,
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
                  ),
                  const SizedBox(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      context.l10n.viralBadge,
                      style: GoogleFonts.baloo2(
                        fontSize: 10.5,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
              decoration: BoxDecoration(
                color: const Color(0xD1080B12),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(color: Color(0x59000000), offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/icons2/coin.png', width: 20, height: 20),
                  const SizedBox(width: 6),
                  Text(
                    _format(ProgressManager().coins),
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            if (showPauseButton) ...[
              _PauseHeaderButton(onTap: onPausePressed),
              const SizedBox(width: 4),
            ],
            _RoundButton(
              semanticLabel: context.l10n.helpButtonLabel,
              circular: true,
              borderColor: const Color(0xB3FFB800),
              child: Text(
                '?',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFB800),
                ),
              ),
              onTap: () => _showHelpDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hud({required bool wideScreen}) {
    return SizedBox(
      height: wideScreen ? 58.5 : 60,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          wideScreen ? 12 : 11,
          8,
          wideScreen ? 12 : 8,
          0,
        ),
        child: LayoutBuilder(
          builder: (context, hudBox) {
            final row = Row(
              children: [
                SizedBox(
                  width: wideScreen ? 104 : 108,
                  child: _stat(
                    context.l10n.gameScoreLabel,
                    _format(score),
                    wideScreen: wideScreen,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 84,
                  child: _stat(
                    context.l10n.gameBestLabel,
                    _format(best),
                    wideScreen: wideScreen,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 74,
                  child: _stat('COMBO', 'x$combo', wideScreen: wideScreen),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: context.l10n.finishRoundLabel,
                  child: GestureDetector(
                    onTap: onRestart,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: wideScreen ? 57.8 : 58,
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
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF4A2E00),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
            if (hudBox.maxWidth >= 340) return row;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(width: 340, height: 50, child: row),
            );
          },
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {required bool wideScreen}) {
    return Container(
      height: wideScreen ? 50.5 : 50,
      alignment: Alignment.centerLeft,
      padding: wideScreen
          ? const EdgeInsets.fromLTRB(14, 6, 10, 6)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: wideScreen ? const Color(0xD9080B12) : const Color(0x73080B12),
        border: Border.all(
          color: wideScreen ? const Color(0x8CFFB800) : const Color(0x73FFB800),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                height: 1,
                letterSpacing: 1,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFFB800),
              ),
            ),
            const SizedBox(height: 3.5),
            Text(
              value,
              maxLines: 1,
              style: GoogleFonts.baloo2(
                fontSize: wideScreen ? 21 : 19,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dock(BuildContext context, {required bool wideScreen}) {
    return SizedBox(
      height: wideScreen ? 90.8 : 92,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, wideScreen ? 10 : 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < bonuses.length; i++) ...[
              if (i > 0) const SizedBox(width: 20),
              _bonusButton(
                context,
                bonuses[i],
                prototypeVisualState ? const [2, 2, 1][i] : bonuses[i].count,
                wideScreen: wideScreen,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bonusButton(
    BuildContext context,
    ModeBonus bonus,
    int count, {
    required bool wideScreen,
  }) {
    final enabled = count > 0 && bonus.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.boosterCountLabel(bonus.label, count),
      child: GestureDetector(
        onTap: enabled ? bonus.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: count > 0 ? 1 : 0.55,
          child: SizedBox(
            width: 66,
            height: wideScreen ? 72.8 : 72,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    if (wideScreen) const SizedBox(height: 1.5),
                    Container(
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
                        bonus.asset,
                        width: wideScreen ? 36 : 30,
                        height: wideScreen ? 36 : 30,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      width: wideScreen ? 66 : 72,
                      child: Text(
                        bonus.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFD8E0EE),
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: wideScreen ? -2 : -4,
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
                      style: GoogleFonts.baloo2(
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
        ),
      ),
    );
  }

  static String _format(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
}

/// Küçük duraklatma düğmesi (madde 37): başlık satırında '?' düğmesinin
/// yanında, HUD düzenini kaydırmadan durur; prototip vitrininde gizlidir.
/// Vuruş kutusu 48×48'dir (komşu _RoundButton ile aynı).
class _PauseHeaderButton extends StatelessWidget {
  const _PauseHeaderButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.pause,
      child: GestureDetector(
        onTap: onTap,
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
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.child,
    required this.onTap,
    this.circular = false,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool circular;
  final Color? borderColor;

  /// Ekran okuyucu etiketi (örn. 'Geri', 'Nasıl oynanır'); `null` ise
  /// `Semantics` sarması eklenmez (arcade_chrome'daki _ChromeRound deseni).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xD9080B12),
          borderRadius: BorderRadius.circular(circular ? 99 : 14),
          border: borderColor == null
              ? null
              : Border.all(color: borderColor!, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x73000000), offset: Offset(0, 3)),
          ],
        ),
        child: child,
      ),
    );
    final label = semanticLabel;
    if (label != null) {
      button = Semantics(button: true, label: label, child: button);
    }
    return button;
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 3;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 1.5), Offset(min(x + 5, size.width), 1.5), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}
