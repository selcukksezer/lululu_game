import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress_manager.dart';

/// Kalıcı enerji sistemi (Offline-First + Otomatik Süre Sayacı).
///
/// - Varsayılan başlangıç enerjisi: 5 (`5/5` standart oturum + `30` tavan depo).
/// - Her 5 dakikada +1 enerji otomatik dolar.
/// - [timeToNext] bir sonraki enerjiye kalan süreyi verir.
/// - [energyNotifier] ve [timeToNextNotifier] + [ChangeNotifier] ile UI'ı anında bilgilendirir.
/// - Dolum zamanlayıcısı tek atımlıktır: Yalnız enerji eksikken kurulur,
///   bir sonraki doluma kadar beklenir, enerji dolunca durdurulur
///   (ömür boyu 1 saniyelik periyodik zamanlayıcı yoktur).
/// - Dolum hesabı monoton saate dayanır: cihaz saati geriye alınırsa son
///   görülen zaman kalıcı olarak tutulur ve geriye sıçrama yok sayılır;
///   tek dolum çağrısında en fazla [EnergyService.maxRefillsPerCall] dolum verilir.
class EnergyService extends ChangeNotifier {
  EnergyService._internal();

  static final EnergyService instance = EnergyService._internal();
  factory EnergyService() => instance;

  static const int maxEnergy = 30;
  static const int defaultEnergy = 5;
  static const Duration regenDuration = Duration(minutes: 5);

  /// Tek [_refill] çağrısında verilebilecek en fazla dolum. Bir depo
  /// ([maxEnergy]) kadardır: meşru uzun yoklukta bile depo bir çağrıda
  /// dolabilir, ama saat sıçramasıyla oluşan devasa geçen-süre hesabı bu
  /// üst sınırla kırpılır.
  static const int maxRefillsPerCall = maxEnergy;

  static const String _keyEnergy = 'lululu.energy';
  static const String _keyLegacyEnergy = 'LululuEnergyCount';
  static const String _keyLastRefill = 'lululu.energy_last_refill';

  /// Son görülen monoton zaman (ms cinsinden). Mevcut anahtarların biçimi
  /// aynen korunur; bu anahtar yalnızca eklenir, eski kayıtlarda yoksa ilk
  /// yüklemede oluşur.
  static const String _keyLastSeen = 'lululu.energy_last_seen';

  final ValueNotifier<int> energyNotifier = ValueNotifier<int>(defaultEnergy);
  final ValueNotifier<Duration> timeToNextNotifier =
      ValueNotifier<Duration>(Duration.zero);

  int _energy = defaultEnergy;
  DateTime _lastRefill = DateTime.now();
  DateTime _lastSeen = DateTime.now();
  bool _loaded = false;
  Timer? _autoRegenTimer;

  /// Yükleme tamamlanmadan gelen yazmaların kuyruğu (şüphe 1 yarış
  /// koruması). `addEnergy`, `energy` setter ve `refillFull`, `_loaded`
  /// yanlışken değişimi bellekte iyimser uygular ve buraya sırayla
  /// kaydeder; [load] prefs değerini okuduktan sonra kuyruğu aynen
  /// tekrar oynatır. Kayıt ([_save]) yüklemeye bırakılır, böylece geç
  /// tamamlanan `load()` bağışı ezemez.
  final List<void Function()> _pendingWrites = [];

  /// Devam eden `load()` çağrısı (şüphe 1 uçuş koruması): eşzamanlı
  /// `load()`/`ensureLoaded()` çağrıları aynı yüklemeyi paylaşır.
  Future<void>? _loadFuture;

  int get energy => _energy;
  int get current => _energy;
  set energy(int value) {
    final wasFull = _energy >= maxEnergy;
    final next = value.clamp(0, maxEnergy);
    if (!_loaded) {
      // Yükleme yarışı (şüphe 1): kalıcı değer henüz okunmadı; setter
      // değeri bekleyen yazmaya alınır, load() prefs değerine uygular.
      // Çapa ve kayıt yüklemeye bırakılır.
      _pendingWrites.add(() {
        _energy = next;
      });
    }
    _energy = next;
    if (_loaded && (_energy >= maxEnergy || wasFull)) {
      // Dolu depodan kısmi duruma düşüşte de (tryConsume'daki wasFull
      // dalıyla aynı) sayım bu andan başlar: bayat çapa bir sonraki
      // _refill'de anında +1 vermesin.
      _lastRefill = _effectiveNow();
    }
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    if (_loaded) unawaited(_save());
    notifyListeners();
    ProgressManager.instance.notifyListeners();
    _ensureAutoTimer();
  }

  bool get isLoaded => _loaded;
  bool get isFull => _energy >= maxEnergy;

  /// Bir sonraki enerjiye kalan süre. Enerji doluysa [Duration.zero].
  Duration get timeToNext {
    if (_energy >= maxEnergy) return Duration.zero;
    final next = _lastRefill.add(regenDuration);
    final remaining = next.difference(_effectiveNow());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// `EnergyEmptyPopup` uyumluluğu için bir sonraki enerjiye kalan süre (`null` = dolu).
  Duration? get timeUntilNextPoint => _energy >= maxEnergy ? null : timeToNext;

  /// `MM:SS` formatında kalan süre veya `'DOLU'`.
  String get formattedTimeToNext {
    if (_energy >= maxEnergy) return 'DOLU';
    final d = timeToNext;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _isFlutterTest {
    try {
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      return bindingType.contains('Test');
    } catch (_) {
      return true;
    }
  }

  /// Dolum hesabı için monoton "şimdi": asla geriye gitmez.
  ///
  /// Cihaz saati geriye alınırsa ham `DateTime.now()` yerine kalıcı olarak
  /// tutulan son görülen zaman kullanılır; böylece geriye sıçrama ne enerji
  /// verir ne de birikmiş kısmi ilerlemeyi siler. İleri gidişlerde son
  /// görülen zaman ilerletilir ve bir sonraki [_save] ile kalıcı olur.
  DateTime _effectiveNow() {
    final now = DateTime.now();
    if (now.isAfter(_lastSeen)) {
      _lastSeen = now;
    }
    return _lastSeen;
  }

  /// Tek atımlık dolum zamanlayıcısını duruma göre kurar veya durdurur.
  ///
  /// Yalnız enerji eksikken ve yükleme tamamlanmışken kurulur; gecikmesi
  /// bir sonraki doluma kalan süredir ([timeToNext]). Enerji dolunca
  /// zamanlayıcı kurulmaz (varsa iptal edilir). Her enerji değişiminden
  /// sonra çağrılır, böylece kalan süre değişince zamanlayıcı yeniden
  /// kurulur. Test ortamında zamanlayıcı kurulmaz.
  void _ensureAutoTimer() {
    _autoRegenTimer?.cancel();
    _autoRegenTimer = null;
    if (_isFlutterTest || !_loaded || _energy >= maxEnergy) return;
    _autoRegenTimer = Timer(timeToNext, _onRegenTimer);
  }

  /// Tek atımlık dolum zamanlayıcısının tetiklenmesi: doldur, bildir,
  /// enerji hâlâ eksikse bir sonraki doluma yeniden kur.
  void _onRegenTimer() {
    _autoRegenTimer = null;
    final before = _energy;
    _refill();
    timeToNextNotifier.value = timeToNext;
    if (_energy != before) {
      notifyListeners();
    }
    _ensureAutoTimer();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Kalıcı enerjiyi yükler. Eşzamanlı çağrılar aynı yüklemeyi paylaşır
  /// (şüphe 1 uçuş koruması); yükleme bittikten sonra yeniden çağrılırsa
  /// prefs'ten tekrar okur (yeniden yükleme korunur).
  Future<void> load() async {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadAsync();
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    // Kalıcı değer aralığa kelepçelenir: eski/bozuk bir kayıt tavanı
    // aşarsa _refill erken dönüş dalı değeri aynen bırakır ve tavan
    // ihlali kalıcı olurdu; diğer bütün yazma yolları zaten kelepçeler.
    _energy = (prefs.getInt(_keyEnergy) ??
            prefs.getInt(_keyLegacyEnergy) ??
            defaultEnergy)
        .clamp(0, maxEnergy);
    final lastSeenMs = prefs.getInt(_keyLastSeen);
    _lastSeen = lastSeenMs == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(lastSeenMs);
    final lastMs = prefs.getInt(_keyLastRefill);
    _lastRefill = lastMs == null
        ? _effectiveNow()
        : DateTime.fromMillisecondsSinceEpoch(lastMs);
    // Yükleme öncesi gelen bağışlar (şüphe 1): prefs değerine geliş
    // sırasıyla uygulanır, sonra kuyruk temizlenir.
    for (final apply in _pendingWrites) {
      apply();
    }
    _pendingWrites.clear();
    _refill();
    _loaded = true;
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    // Monoton son-görülen zamanı kalıcı tut: saat geriye alınmış bir
    // sonraki açılışta bu değer yok sayma dayanağıdır.
    unawaited(_save());
    _ensureAutoTimer();
    notifyListeners();
  }

  /// Geçen süreye göre enerji doldurur. Değişim olduysa kaydeder.
  ///
  /// Muhafazakâr saat koruması: geçen süre monoton saatle ([_effectiveNow])
  /// ölçülür ve tek çağrıda en fazla [maxRefillsPerCall] (bir depo) dolum
  /// verilir; dolum ayrıca boş kapasiteyle sınırlanır, böylece [_lastRefill]
  /// bir çağrıda en fazla `maxRefillsPerCall × regenDuration` ilerler. İleri
  /// saat sıçramasına karşı tam koruma sunucu saati gerektirir (kapsam dışı);
  /// bu düzeltme geriye sıçramayı yok sayar ve tek çağrıdaki dolumu sınırlar.
  void _refill() {
    if (_energy >= maxEnergy) {
      _lastRefill = _effectiveNow();
      timeToNextNotifier.value = Duration.zero;
      return;
    }
    final now = _effectiveNow();
    final elapsedSeconds = now.difference(_lastRefill).inSeconds;
    if (elapsedSeconds < 0) {
      // Dolum çapası monoton saatin ilerisinde (eski kayıttan kalma ileri
      // saat izi): enerji verilmez, çapa monoton saate çekilerek dolum
      // saati sıfırdan başlatılır.
      _lastRefill = now;
      return;
    }
    final room = maxEnergy - _energy;
    var ticks = elapsedSeconds ~/ regenDuration.inSeconds;
    if (ticks > room) ticks = room;
    if (ticks > maxRefillsPerCall) ticks = maxRefillsPerCall;
    if (ticks > 0) {
      _energy = (_energy + ticks).clamp(0, maxEnergy);
      _lastRefill = _lastRefill.add(regenDuration * ticks);
      if (_energy >= maxEnergy) _lastRefill = now;
      unawaited(_save());
      energyNotifier.value = _energy;
      timeToNextNotifier.value = timeToNext;
      notifyListeners();
    }
  }

  /// [amount] (varsayılan 1) enerji harcamaya çalışır. Enerji yoksa `false` döner.
  Future<bool> tryConsume([int amount = 1]) async {
    if (amount <= 0) return true;
    // Yükleme yarışı: kalıcı enerji yüklenmeden tüketim yapılmaz;
    // bu çağrı yüklemeyi bekler.
    await ensureLoaded();
    final safeAmount = amount.clamp(1, maxEnergy);
    _refill();
    if (_energy < safeAmount) return false;
    final wasFull = _energy >= maxEnergy;
    _energy = (_energy - safeAmount).clamp(0, maxEnergy);
    if (wasFull) {
      _lastRefill = _effectiveNow();
    }
    await _save();
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    notifyListeners();
    ProgressManager.instance.notifyListeners();
    _ensureAutoTimer();
    return true;
  }

  /// `amount` enerji ekler (negatif/taşan değerlere karşı korumalı, `ProgressManager.instance` ve `energyNotifier` ile senkronize).
  void addEnergy(int amount) {
    if (amount <= 0) return;
    final safeAmount = amount.clamp(1, maxEnergy);
    if (!_loaded) {
      // Yükleme yarışı (şüphe 1): bağış bekleyen yazmaya alınır, load()
      // prefs değerine uygular. Dolum ve kayıt yüklemeye bırakılır.
      _pendingWrites.add(() {
        _energy = (_energy + safeAmount).clamp(0, maxEnergy);
      });
    } else {
      _refill();
    }
    _energy = (_energy + safeAmount).clamp(0, maxEnergy);
    if (_loaded && _energy >= maxEnergy) {
      _lastRefill = _effectiveNow();
    }
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    if (_loaded) unawaited(_save());
    notifyListeners();
    ProgressManager.instance.notifyListeners();
    _ensureAutoTimer();
  }

  /// Enerjiyi tamamen doldurur (varsayılan olarak [maxEnergy], veya [target] değerine).
  Future<void> refillFull({int? target}) async {
    final cap = (target ?? maxEnergy).clamp(defaultEnergy, maxEnergy);
    if (!_loaded) {
      // Yükleme yarışı (şüphe 1): doldurma bekleyen yazmaya alınır,
      // load() prefs değerine uygular. Çapa ve kayıt yüklemeye bırakılır.
      _pendingWrites.add(() {
        if (_energy < cap) {
          _energy = cap;
        }
      });
    }
    if (_energy < cap) {
      _energy = cap;
    }
    if (_loaded) {
      _lastRefill = _effectiveNow();
      await _save();
    }
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    notifyListeners();
    ProgressManager.instance.notifyListeners();
    _ensureAutoTimer();
  }

  /// `amount` verilirse o kadar enerji ekler, verilmezse maksimuma doldurur.
  Future<void> grantFull([int? amount]) async {
    if (amount != null && amount > 0) {
      addEnergy(amount);
      // Yükleme öncesi: addEnergy bağışı bekleyen yazmaya aldı; bu ek
      // kayıt iyimser (varsayılan tabanlı) değeri kalıcılaştırıp load()
      // yarışını geri getirirdi — kayıt load() sonundaki kayda bırakılır.
      // Yüklüyken davranış aynen korunur (ek kayıt kalır).
      if (_loaded) await _save();
      return;
    }
    await refillFull();
  }

  Future<void> _save() async {
    final now = DateTime.now();
    if (now.isAfter(_lastSeen)) {
      _lastSeen = now;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyEnergy, _energy);
    await prefs.setInt(_keyLegacyEnergy, _energy);
    await prefs.setInt(_keyLastRefill, _lastRefill.millisecondsSinceEpoch);
    await prefs.setInt(_keyLastSeen, _lastSeen.millisecondsSinceEpoch);
  }

  /// Hesap silme için yerel enerji verisinin tamamını temizler
  /// (hesap-silme, yerel-temizlik): 4 enerji anahtarı
  /// (`lululu.energy`, `LululuEnergyCount`,
  /// `lululu.energy_last_refill`, `lululu.energy_last_seen`) kaldırılır,
  /// bellek-içi enerji varsayılan değere (5) döner ve bekleyen yazmalar
  /// atılır. Kayıt yapılmaz, böylece kaldırılan anahtarlar yeniden
  /// yazılmaz; sonraki `load()` prefs'ten varsayılanları okur.
  Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEnergy);
    await prefs.remove(_keyLegacyEnergy);
    await prefs.remove(_keyLastRefill);
    await prefs.remove(_keyLastSeen);
    _pendingWrites.clear();
    _energy = defaultEnergy;
    _lastRefill = DateTime.now();
    _lastSeen = DateTime.now();
    _autoRegenTimer?.cancel();
    _autoRegenTimer = null;
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    notifyListeners();
    ProgressManager.instance.notifyListeners();
    _ensureAutoTimer();
  }

  @override
  void dispose() {
    _autoRegenTimer?.cancel();
    _autoRegenTimer = null;
    super.dispose();
  }
}
