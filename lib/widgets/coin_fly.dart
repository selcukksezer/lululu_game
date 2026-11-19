import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Coin uçuş efekti (12N — Selçuk 20:51: ödül alınınca coinler olduğu
/// yerden üst bardaki coin simgesine uçsun).
///
/// Tasarım — ödeme ile GÖRÜNÜM ayrılır:
/// * Ödeme her zamanki yerde, her zamanki API ile yapılır
///   (`ProgressManager.addCoins` / `claimDailyTaskReward` / `finishRun`
///   settle). Bakiye kalıcılığı ve tek-ödeme sözleşmesi değişmez.
/// * [fly] çağrıldığı anda [pendingCoins] tutar kadar artar; üst bar
///   ([LululuTopBar], görev ekranı başlığı, kampanya haritası) görüntülenen
///   sayıyı `pm.coins - pendingCoins` olarak okur — yani sayı uçuş
///   sırasında ARTMAMIŞ görünür, varışta artar.
/// * Varış [Timer] ile olur, overlay animasyonuna bağlı değildir: rota
///   uçuş bitmeden kapanırsa bile bekleyen tutar süre dolunca iner
///   ([pendingCoins] azalır, [landings] artar, üst bar "pop" yapar).
///   Overlay yalnız görseldir; muhasebe asla ona emanet edilmez.
/// * Hedef: ekrandaki coin simgesi [CoinFlyTarget] ile kendini kaydeder;
///   kayıtlı hedef yoksa (ör. sonuç ekranında üst bar yoktur) uçuş
///   ekranın sağ üst köşesine gider.
/// * Çoklu ödülde uçuşlar üst üste binebilir: her uçuş kendi zamanlayıcı
///   ve overlay girdisiyle bağımsız tamamlanır (K kuralı: ses gibi
///   kesilmeden biter).
///
/// Suika'da coin toplama uçuşu yoktu (yalnız `particle_overlay.dart`
/// `mergeGold` patlaması var — hedefe uçmaz, yerinde patlar); bu dosya
/// sıfırdan yazıldı, aynı coin görseli (`icon_coin_exact.png`) kullanılır.
class CoinFlyService extends ChangeNotifier {
  CoinFlyService._();

  static final CoinFlyService instance = CoinFlyService._();

  /// Varsayılan uçuş süresi (brif: ~600-900 ms).
  static const Duration defaultFlightDuration = Duration(milliseconds: 750);

  /// Uçuş başladı ama henüz varmadı: ödenmiş, görüntüde bekleyen tutar.
  int _pendingCoins = 0;
  int get pendingCoins => _pendingCoins;

  /// Tamamlanan varış sayısı; üst bar "pop" animasyonu bunu dinler.
  int _landings = 0;
  int get landings => _landings;

  Offset? _targetCenter;
  Object? _targetOwner;

  /// Şu an kayıtlı varış noktası (yoksa null → sağ üst köşe yedeği).
  Offset? get targetCenter => _targetCenter;

  /// Devam eden uçuşlar (varış/iptal/sıfırlama ile kapanır).
  final List<_CoinFlightRecord> _flights = <_CoinFlightRecord>[];

  /// Varış noktası kaydeder. Son kaydeden canlı hedef kazanır; hedef
  /// dispose olunca [unregisterTarget] ile kaydını geri alır.
  void registerTarget(Offset center, Object owner) {
    _targetCenter = center;
    _targetOwner = owner;
  }

  void unregisterTarget(Object owner) {
    if (_targetOwner == owner) {
      _targetCenter = null;
      _targetOwner = null;
    }
  }

  /// [from] noktasından varış noktasına [amount] coin uçurur.
  ///
  /// Ödeme bu çağrıdan ÖNCE yapılmış olmalıdır (bakiye zaten
  /// [ProgressManager.coins] içindedir); bu metod yalnız görünümü
  /// erteler ve görsel uçuşu başlatır. [amount] <= 0 ise hiçbir şey
  /// yapmaz ve null döner. Overlay kurulamazsa bile (testte çıplak
  /// widget vb.) bekleyen tutar zamanlayıcıyla iner — sayı asla takılı
  /// kalmaz.
  ///
  /// Dönen tutamakla uçuş iptal edilebilir: her çağıran ekran/sayfa
  /// tutamağı saklar ve `dispose`'da iptal eder (bekleyen zamanlayıcı
  /// bırakılmaz; iptal sayıyı uçuşsuz son değere döndürür).
  CoinFlightHandle? fly({
    required BuildContext context,
    required Offset from,
    required int amount,
    Duration duration = defaultFlightDuration,
  }) {
    if (amount <= 0) return null;
    final safeDuration =
        duration.inMilliseconds <= 0 ? defaultFlightDuration : duration;
    _pendingCoins += amount;
    notifyListeners();

    final mediaSize = MediaQuery.maybeSizeOf(context);
    final to = _targetCenter ??
        Offset((mediaSize?.width ?? 430) - 56, 44);
    final coinCount = (amount / 60).ceil().clamp(1, 7);

    final record = _CoinFlightRecord(amount: amount);
    final handle = CoinFlightHandle._(this);
    record.handle = handle;
    _flights.add(record);

    final entry = OverlayEntry(
      builder: (_) => _CoinFlight(
        from: from,
        to: to,
        coinCount: coinCount,
        duration: safeDuration,
      ),
    );
    var entryInserted = false;
    try {
      Overlay.of(context, rootOverlay: true).insert(entry);
      entryInserted = true;
    } catch (_) {
      // Overlay yok: görsel atlanır, muhasebe aşağıdaki zamanlayıcıyla
      // aynen işler.
      entryInserted = false;
    }
    if (entryInserted) {
      record.entry = entry;
      // Animasyon bitince girdi kaldırılır; rota erken kapanırsa
      // framework girdiyi zaten kaldırır — iki kez kaldırma olmaz.
      // Zamanlayıcı kayda bağlıdır ki iptal/sıfırlama durdurabilsin.
      record.removeTimer = Timer(
        safeDuration + const Duration(milliseconds: 250),
        () {
          try {
            entry.remove();
          } catch (_) {
            // Girdi zaten kaldırılmış olabilir (rota kapandı); yoksay.
          }
        },
      );
    }

    // Varış: animasyondan bağımsız zamanlayıcı (rota kapanmasına dayanıklı).
    record.landTimer = Timer(safeDuration, () => _landRecord(record));
    return handle;
  }

  void _landRecord(_CoinFlightRecord record) {
    if (record.landed || record.cancelled) return;
    record.landed = true;
    record.handle?._done = true;
    _pendingCoins = math.max(0, _pendingCoins - record.amount);
    _landings++;
    _flights.remove(record);
    notifyListeners();
  }

  void _cancelFlight(CoinFlightHandle handle) {
    _CoinFlightRecord? record;
    for (final candidate in _flights) {
      if (candidate.handle == handle) {
        record = candidate;
        break;
      }
    }
    if (record == null) return;
    record.cancelled = true;
    record.landTimer?.cancel();
    record.removeTimer?.cancel();
    final entry = record.entry;
    if (entry != null) {
      try {
        entry.remove();
      } catch (_) {
        // Girdi zaten kaldırılmış olabilir; yoksay.
      }
    }
    // İptal, görünümü uçuşsuz son değere döndürür: ödenmiş tutar
    // bekleyen listesinden çıkar (sayı hemen artar).
    _pendingCoins = math.max(0, _pendingCoins - record.amount);
    _flights.remove(record);
    notifyListeners();
  }

  /// Yalnız testler için: bekleyen tutar, varış sayacı, hedef ve
  /// devam eden uçuşlar sıfırlanır (singleton testler arası sızmasın).
  /// Devam eden uçuşlar iptal edilir (zamanlayıcı bırakılmaz).
  @visibleForTesting
  void debugReset() {
    for (final record in List<_CoinFlightRecord>.of(_flights)) {
      record.handle?.cancel();
    }
    _flights.clear();
    _pendingCoins = 0;
    _landings = 0;
    _targetCenter = null;
    _targetOwner = null;
    notifyListeners();
  }
}

/// Devam eden tek uçuşun muhasebe kaydı (servis içindir).
class _CoinFlightRecord {
  _CoinFlightRecord({required this.amount});

  final int amount;
  CoinFlightHandle? handle;
  OverlayEntry? entry;
  Timer? landTimer;
  Timer? removeTimer;
  bool landed = false;
  bool cancelled = false;
}

/// Varış noktasını [CoinFlyService]e kaydeden sarmalayıcı.
///
/// Coin simgesinin (üst bar hapı, görev başlığı hapı, kampanya hapı)
/// etrafına konur; yerleşim sonrası global merkezini kaydeder,
/// dispose'da kaydını geri alır. Ekranda tek hedef canlıdır.
class CoinFlyTarget extends StatefulWidget {
  const CoinFlyTarget({super.key, required this.child});

  final Widget child;

  @override
  State<CoinFlyTarget> createState() => _CoinFlyTargetState();
}

class _CoinFlyTargetState extends State<CoinFlyTarget> {
  final Object _owner = Object();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _register());
  }

  @override
  void didUpdateWidget(covariant CoinFlyTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _register());
  }

  void _register() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    CoinFlyService.instance.registerTarget(
      box.localToGlobal(box.size.center(Offset.zero)),
      _owner,
    );
  }

  @override
  void dispose() {
    CoinFlyService.instance.unregisterTarget(_owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Varışta ("pop") büyüyüp küçülen sarmalayıcı.
///
/// [CoinFlyService.landings] artınca 300 ms'lik 1.0 → 1.28 → 1.0
/// ölçek animasyonu oynatır; üst bar coin hapının etrafına konur.
class CoinFlyPop extends StatefulWidget {
  const CoinFlyPop({super.key, required this.child});

  final Widget child;

  @override
  State<CoinFlyPop> createState() => _CoinFlyPopState();
}

class _CoinFlyPopState extends State<CoinFlyPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  int _seenLandings = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.28)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.28, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_controller);
    _seenLandings = CoinFlyService.instance.landings;
    CoinFlyService.instance.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    final landings = CoinFlyService.instance.landings;
    if (landings == _seenLandings || !mounted) return;
    _seenLandings = landings;
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    CoinFlyService.instance.removeListener(_onServiceChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// Tek uçuşun tutamacı: kaynak ekran kapanırsa uçuş iptal edilir.
///
/// İptal, bekleyen tutarı geri alır (sayı uçuş olmadan son değere
/// döner — ödeme zaten yapıldı, yalnız görünüm ertelenmişti),
/// zamanlayıcıları durdurur ve overlay girdisini kaldırır. Varış
/// gerçekleştiyse iptal etkisizdir.
class CoinFlightHandle {
  CoinFlightHandle._(this._service);

  final CoinFlyService _service;
  bool _done = false;

  /// Uçuş tamamlandıysa (varış olduysa) `true`.
  bool get isDone => _done;

  void cancel() {
    if (_done) return;
    _done = true;
    _service._cancelFlight(this);
  }
}
///
/// `IgnorePointer` + `Positioned.fill` overlay katmanıdır; oyun
/// duraklatılmaz, dokunma engellenmez. Kaldırma: animasyon bitince
/// [OverlayEntry] servis zamanlayıcısıyla kaldırılır; bu widget yalnız
/// çizer.
class _CoinFlight extends StatefulWidget {
  const _CoinFlight({
    required this.from,
    required this.to,
    required this.coinCount,
    required this.duration,
  });

  final Offset from;
  final Offset to;
  final int coinCount;
  final Duration duration;

  @override
  State<_CoinFlight> createState() => _CoinFlightState();
}

class _CoinFlightState extends State<_CoinFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _bezier(double t, Offset from, Offset control, Offset to) {
    final u = 1.0 - t;
    return Offset(
      u * u * from.dx + 2 * u * t * control.dx + t * t * to.dx,
      u * u * from.dy + 2 * u * t * control.dy + t * t * to.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kontrol noktası: iki uç arası orta noktanın ~120 px yukarısı
    // (ekran dışına taşmaz); yay önce yükselir, sonra hedefe iner.
    final mid = Offset(
      (widget.from.dx + widget.to.dx) / 2,
      (widget.from.dy + widget.to.dy) / 2,
    );
    final control = Offset(
      mid.dx,
      math.max(8.0, mid.dy - 120),
    );
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          for (var i = 0; i < widget.coinCount; i++)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Ardışık coinler 80 ms arayla kalkar; her biri 650 ms
                // uçar (toplam süre içinde üst üste biner).
                final delay = i * 0.08;
                final span = math.max(
                  0.05,
                  1.0 - delay - 0.05,
                );
                final rawT = ((_controller.value - delay) / span)
                    .clamp(0.0, 1.0);
                final t = Curves.easeInOut.transform(rawT);
                final pos = _bezier(t, widget.from, control, widget.to);
                final scale = rawT < 0.2
                    ? 0.6 + (rawT / 0.2) * 0.4
                    : 1.0 - (rawT - 0.2) * 0.25;
                final opacity = rawT < 0.1
                    ? rawT / 0.1
                    : rawT > 0.88
                        ? math.max(0.0, 1.0 - (rawT - 0.88) / 0.12)
                        : 1.0;
                return Positioned(
                  left: pos.dx - 11,
                  top: pos.dy - 11,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Transform.rotate(
                        angle: rawT * 1.2,
                        child: child,
                      ),
                    ),
                  ),
                );
              },
              child: Image.asset(
                'assets/design/ui/icon_coin_exact.png',
                width: 22,
                height: 22,
                errorBuilder: (_, _, _) => Image.asset(
                  'assets/design/ui/icon_coin.png',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFFFD34D),
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
