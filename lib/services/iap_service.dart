import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'progress_manager.dart';

/// StoreKit / Play Billing coin packs. Falls back to sandbox grant when store
/// products are unavailable (simulator / no App Store Connect IDs yet).
class IapService extends ChangeNotifier {
  IapService._();
  static final instance = IapService._();

  static const packs = <({String id, String title, int coins, String priceLabel})>[
    (id: 'coins_small', title: 'Küçük Torba', coins: 500, priceLabel: '₺29,99'),
    (id: 'coins_mid', title: 'Makara Paket', coins: 1500, priceLabel: '₺79,99'),
    (id: 'coins_big', title: 'Kongo Sandık', coins: 5000, priceLabel: '₺199,99'),
  ];

  static final productIds = packs.map((p) => p.id).toSet();

  String status = 'IAP · store bağlanıyor…';
  bool storeAvailable = false;
  final Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _booted = false;

  Future<void> ensureLoaded() async {
    if (_booted) return;
    _booted = true;
    try {
      final iap = InAppPurchase.instance;
      storeAvailable = await iap.isAvailable();
      if (!storeAvailable) {
        status = 'Store yok · sandbox simülasyon açık';
        notifyListeners();
        return;
      }
      _sub = iap.purchaseStream.listen(
        _onPurchases,
        onError: (Object e) {
          status = 'IAP stream hata: $e';
          notifyListeners();
        },
      );
      final resp = await iap.queryProductDetails(productIds);
      for (final p in resp.productDetails) {
        _products[p.id] = p;
      }
      status = _products.isEmpty
          ? 'Ürün ID bulunamadı · sandbox simülasyon'
          : 'Store hazır · ${_products.length} ürün';
    } catch (e) {
      storeAvailable = false;
      status = 'Store kanal yok · sandbox simülasyon ($e)';
    }
    notifyListeners();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        status = 'Ödeme bekleniyor…';
        notifyListeners();
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        status = 'Satın alma hata · ${purchase.error?.message}';
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final pack = packs.where((p) => p.id == purchase.productID).firstOrNull;
        if (pack != null) {
          await ProgressManager().addCoins(pack.coins);
          status = 'Satın alındı · ${pack.title} (+${pack.coins})';
          notifyListeners();
        }
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<bool> purchase(String packId) async {
    await ensureLoaded();
    final pack = packs.where((p) => p.id == packId).firstOrNull;
    if (pack == null) return false;

    final details = _products[packId];
    if (details != null && storeAvailable) {
      status = 'Store satın alma…';
      notifyListeners();
      final ok = await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!ok) {
        status = 'Satın alma başlatılamadı';
        notifyListeners();
      }
      return ok;
    }

    // Sandbox path — simulator / missing App Store products.
    status = 'Sandbox grant · ${pack.title}';
    await ProgressManager().addCoins(pack.coins);
    notifyListeners();
    return true;
  }

  /// Legacy name used by shop UI.
  Future<bool> purchaseStub(String packId) => purchase(packId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Back-compat while shop migrates.
typedef IapStubService = IapService;
