import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı enerji sistemi.
///
/// - Varsayılan enerji: 5, maksimum: 30.
/// - Her 5 dakikada +1 enerji (maksimumda durur).
/// - [timeToNext] bir sonraki enerjiye kalan süreyi verir; UI kendi
///   Timer'ını kurup bu hesabı periyodik okur.
/// - [energyNotifier] UI'nin dinlediği ValueNotifier'dır.
class EnergyService {
  EnergyService._internal();

  static final EnergyService instance = EnergyService._internal();

  static const int maxEnergy = 30;
  static const int defaultEnergy = 5;
  static const Duration regenDuration = Duration(minutes: 5);

  static const String _keyEnergy = 'lululu.energy';
  static const String _keyLastRefill = 'lululu.energy_last_refill';

  final ValueNotifier<int> energyNotifier = ValueNotifier<int>(defaultEnergy);

  int _energy = defaultEnergy;
  DateTime _lastRefill = DateTime.now();
  bool _loaded = false;

  int get energy => _energy;

  bool get isLoaded => _loaded;

  /// Bir sonraki enerjiye kalan süre. Enerji doluysa [Duration.zero].
  Duration get timeToNext {
    if (_energy >= maxEnergy) return Duration.zero;
    final next = _lastRefill.add(regenDuration);
    final remaining = next.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _energy = prefs.getInt(_keyEnergy) ?? defaultEnergy;
    final lastMs = prefs.getInt(_keyLastRefill);
    _lastRefill = lastMs == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(lastMs);
    _refill();
    _loaded = true;
    energyNotifier.value = _energy;
  }

  /// Geçen süreye göre enerji doldurur. Değişim olduysa kaydeder.
  void _refill() {
    if (_energy >= maxEnergy) {
      _lastRefill = DateTime.now();
      return;
    }
    final now = DateTime.now();
    final ticks = now.difference(_lastRefill) ~/ regenDuration;
    if (ticks > 0) {
      _energy = (_energy + ticks).clamp(0, maxEnergy);
      _lastRefill = _lastRefill.add(regenDuration * ticks);
      if (_energy >= maxEnergy) _lastRefill = now;
      unawaited(_save());
      energyNotifier.value = _energy;
    }
  }

  /// 1 enerji harcamaya çalışır. Enerji yoksa `false` döner, harcamaz.
  Future<bool> tryConsume() async {
    _refill();
    if (_energy <= 0) return false;
    _energy -= 1;
    unawaited(_save());
    energyNotifier.value = _energy;
    return true;
  }

  /// `n` enerji ekler (maksimumu aşmaz).
  void addEnergy(int n) {
    _refill();
    _energy = (_energy + n).clamp(0, maxEnergy);
    unawaited(_save());
    energyNotifier.value = _energy;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyEnergy, _energy);
    await prefs.setInt(
        _keyLastRefill, _lastRefill.millisecondsSinceEpoch);
  }
}
