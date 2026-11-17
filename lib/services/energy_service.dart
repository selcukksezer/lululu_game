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
class EnergyService extends ChangeNotifier {
  EnergyService._internal();

  static final EnergyService instance = EnergyService._internal();
  factory EnergyService() => instance;

  static const int maxEnergy = 30;
  static const int defaultEnergy = 5;
  static const int standardMaxEnergy = 5;
  static const Duration regenDuration = Duration(minutes: 5);

  static const String _keyEnergy = 'lululu.energy';
  static const String _keyLegacyEnergy = 'LululuEnergyCount';
  static const String _keyLastRefill = 'lululu.energy_last_refill';

  final ValueNotifier<int> energyNotifier = ValueNotifier<int>(defaultEnergy);
  final ValueNotifier<Duration> timeToNextNotifier =
      ValueNotifier<Duration>(Duration.zero);

  int _energy = defaultEnergy;
  DateTime _lastRefill = DateTime.now();
  bool _loaded = false;
  Timer? _autoRegenTimer;

  int get energy => _energy;
  int get current => _energy;
  set energy(int value) {
    final next = value.clamp(0, maxEnergy);
    _energy = next;
    if (_energy >= maxEnergy) {
      _lastRefill = DateTime.now();
    }
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    unawaited(_save());
    notifyListeners();
    ProgressManager.instance.notifyListeners();
  }

  bool get isLoaded => _loaded;
  bool get isFull => _energy >= maxEnergy;

  /// Bir sonraki enerjiye kalan süre. Enerji doluysa [Duration.zero].
  Duration get timeToNext {
    if (_energy >= maxEnergy) return Duration.zero;
    final next = _lastRefill.add(regenDuration);
    final remaining = next.difference(DateTime.now());
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

  void _ensureAutoTimer() {
    if (_autoRegenTimer != null || _isFlutterTest) return;
    _autoRegenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final before = _energy;
      _refill();
      timeToNextNotifier.value = timeToNext;
      if (_energy != before) {
        notifyListeners();
      }
    });
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _energy = prefs.getInt(_keyEnergy) ??
        prefs.getInt(_keyLegacyEnergy) ??
        defaultEnergy;
    final lastMs = prefs.getInt(_keyLastRefill);
    _lastRefill = lastMs == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(lastMs);
    _refill();
    _loaded = true;
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    _ensureAutoTimer();
    notifyListeners();
  }

  /// Geçen süreye göre enerji doldurur. Değişim olduysa kaydeder.
  void _refill() {
    if (_energy >= maxEnergy) {
      _lastRefill = DateTime.now();
      timeToNextNotifier.value = Duration.zero;
      return;
    }
    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastRefill).inSeconds;
    if (elapsedSeconds < 0) {
      _lastRefill = now;
      return;
    }
    final ticks = elapsedSeconds ~/ regenDuration.inSeconds;
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
    final safeAmount = amount.clamp(1, maxEnergy);
    _refill();
    if (_energy < safeAmount) return false;
    final wasFull = _energy >= maxEnergy;
    _energy = (_energy - safeAmount).clamp(0, maxEnergy);
    if (wasFull) {
      _lastRefill = DateTime.now();
    }
    await _save();
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    notifyListeners();
    ProgressManager.instance.notifyListeners();
    return true;
  }

  /// `amount` enerji ekler (negatif/taşan değerlere karşı korumalı, `ProgressManager.instance` ve `energyNotifier` ile senkronize).
  void addEnergy(int amount) {
    if (amount <= 0) return;
    _refill();
    final safeAmount = amount.clamp(1, maxEnergy);
    _energy = (_energy + safeAmount).clamp(0, maxEnergy);
    if (_energy >= maxEnergy) {
      _lastRefill = DateTime.now();
    }
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    unawaited(_save());
    notifyListeners();
    ProgressManager.instance.notifyListeners();
  }

  /// Enerjiyi tamamen doldurur (varsayılan olarak [maxEnergy], veya [target] değerine).
  Future<void> refillFull({int? target}) async {
    final cap = (target ?? maxEnergy).clamp(defaultEnergy, maxEnergy);
    if (_energy < cap) {
      _energy = cap;
    }
    _lastRefill = DateTime.now();
    await _save();
    energyNotifier.value = _energy;
    timeToNextNotifier.value = timeToNext;
    notifyListeners();
    ProgressManager.instance.notifyListeners();
  }

  /// `amount` verilirse o kadar enerji ekler, verilmezse maksimuma doldurur.
  Future<void> grantFull([int? amount]) async {
    if (amount != null && amount > 0) {
      addEnergy(amount);
      await _save();
      return;
    }
    await refillFull();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyEnergy, _energy);
    await prefs.setInt(_keyLegacyEnergy, _energy);
    await prefs.setInt(_keyLastRefill, _lastRefill.millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _autoRegenTimer?.cancel();
    _autoRegenTimer = null;
    super.dispose();
  }
}
