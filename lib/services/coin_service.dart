import 'package:flutter/foundation.dart';

import 'progress_manager.dart';

/// Merkezi altın (coin) ekonomisi servisi.
///
/// Tüm bakiye, harcama ve ödül işlemlerini [ProgressManager] ile %100
/// senkronize yürütür; böylece üst bar, mağaza, kampanya ve günlük görevler
/// tek doğruluk kaynağını (`ProgressManager.instance`) paylaşır.
class CoinService extends ChangeNotifier {
  static final CoinService _instance = CoinService._internal();
  factory CoinService() => _instance;
  static CoinService get instance => _instance;

  CoinService._internal() {
    ProgressManager.instance.addListener(_onProgressChanged);
  }

  int _lastKnownCoins = ProgressManager.instance.coins;

  void _onProgressChanged() {
    final current = ProgressManager.instance.coins;
    if (current != _lastKnownCoins) {
      _lastKnownCoins = current;
      notifyListeners();
    }
  }

  /// Güncel altın bakiyesi (`ProgressManager.instance.coins` ile birebir aynı).
  int get coins => ProgressManager.instance.coins;

  /// `balance` takma adı (eski/alternatif çağrılar için).
  int get balance => ProgressManager.instance.coins;

  /// Reaktif bakiye dinleyicisi.
  ValueListenable<int> get coinsNotifier =>
      ProgressManager.instance.coinsNotifier;

  /// Kalıcı ekonomiyi yükler ve senkronize eder.
  Future<void> load() async {
    await ProgressManager.instance.load();
    _lastKnownCoins = ProgressManager.instance.coins;
    notifyListeners();
  }

  /// Kasaya altın ekler ve kalıcı olarak kaydeder.
  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    await ProgressManager.instance.addCoins(amount);
    _lastKnownCoins = ProgressManager.instance.coins;
    notifyListeners();
  }

  /// Kasadan altın harcar. Yetersiz bakiyede `false` döner.
  Future<bool> spendCoins(int amount) async {
    if (amount < 0) return false;
    if (amount == 0) return true;
    final ok = await ProgressManager.instance.spendCoins(amount);
    if (ok) {
      _lastKnownCoins = ProgressManager.instance.coins;
      notifyListeners();
    }
    return ok;
  }

  /// Kampanya bölümü tamamlandığında yıldız ve boss durumuna göre altın verir.
  Future<int> grantLevelClearReward({
    required int stars,
    int baseReward = 50,
    bool isBossLevel = false,
  }) async {
    final clampedStars = stars.clamp(0, 3);
    if (clampedStars <= 0) return 0;
    final safeBase = baseReward < 0 ? 0 : baseReward;
    final reward =
        (clampedStars * safeBase) + (isBossLevel ? 100 : 0);
    await addCoins(reward);
    return reward;
  }
}
