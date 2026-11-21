import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'energy_service.dart';
import 'game_telemetry_service.dart';
import 'progress_manager.dart';

class StoreCatalogItem {
  const StoreCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.coinCost,
    required this.priceLabel,
    this.coinsGrant = 0,
    this.f16Grant = 0,
    this.raidGrant = 0,
    this.terlikGrant = 0,
    this.energyGrant = 0,
    this.fullEnergy = false,
    this.unlockRoyalCape = false,
    this.rewardedAdEligible = false,
    this.isConsumable = true,
    this.powerKey,
    this.powerGrant = 0,
  });

  final String id;
  final String title;
  final String description;
  final int coinCost;
  final String priceLabel;
  final int coinsGrant;
  final int f16Grant;
  final int raidGrant;
  final int terlikGrant;
  final int energyGrant;
  final bool fullEnergy;
  final bool unlockRoyalCape;
  final bool rewardedAdEligible;
  final bool isConsumable;
  final String? powerKey;
  final int powerGrant;
}

class ShopPowerUpCatalogEntry {
  const ShopPowerUpCatalogEntry({
    required this.key,
    required this.modeId,
    required this.modeName,
    required this.title,
    required this.description,
    required this.coinCost,
  });

  final String key;
  final String modeId;
  final String modeName;
  final String title;
  final String description;
  final int coinCost;
}

/// StoreKit / Play Billing + Coin Маğaza + Ödüllü Reklam servisi.
/// Store ürünleri mevcut olmadığında (simülatör / test / offline) otomatik
/// Sandbox bağışı YALNIZCA debug derlemelerinde yapılır; sürümde mağaza
/// veya ürün yoksa satın alma başarısız döner ve ürün verilmez. Ödüllü
/// reklam SDK'sı kurulu değildir: ödüllü reklam ödülü verilmez (bkz.
/// [rewardedAdsAvailable]).
class IapService extends ChangeNotifier {
  IapService._();
  static final instance = IapService._();

  /// Ödüllü reklamların kullanılabilir olup olmadığı.
  ///
  /// Şu an `false`: projede reklam SDK'sı (örn. `google_mobile_ads`) kurulu
  /// değil, bu yüzden gerçek bir reklam gösterilemez ve ödüllü reklam
  /// ödülü verilemez. Gerçek SDK entegrasyonu tamamlanıp reklam gösterimi
  /// doğrulandığında bu bayrak gerçek kullanılabilirlik kontrolüne
  /// bağlanmalıdır; SDK olmadan `true` yapılmamalıdır.
  static const bool rewardedAdsAvailable = false;

  /// Ana coin paketleri (`widget_test.dart` geriye dönük uyumluluğu için 3 eleman).
  static const packs = <({String id, String title, int coins, String priceLabel})>[
    (id: 'coins_small', title: 'Küçük Torba', coins: 500, priceLabel: '₺29,99'),
    (id: 'coins_mid', title: 'Makara Paket', coins: 1500, priceLabel: '₺79,99'),
    (id: 'coins_big', title: 'Kongo Sandık', coins: 5000, priceLabel: '₺199,99'),
  ];

  /// Mağaza ürün kataloğu: F16 x3, Raid x3, Anne Terliği x5, Enerji Paketi (+10 enerji),
  /// Tam Enerji, Sandıklar, İksirler, Coin Paketleri, Kraliyet Pelerini, Dev Başlangıç Paketi.
  static const List<StoreCatalogItem> storeCatalog = [
    StoreCatalogItem(
      id: 'f16_x3',
      title: 'F16 x3',
      description: '3 adet F16 Hava Desteği güçlendiricisi',
      coinCost: 240,
      priceLabel: '₺39,99',
      f16Grant: 3,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'raid_x3',
      title: 'Raid x3',
      description: '3 adet Raid Sprey güçlendiricisi',
      coinCost: 150,
      priceLabel: '₺24,99',
      raidGrant: 3,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'terlik_x5',
      title: 'Anne Terliği x5',
      description: '5 adet Anne Terliği güçlendiricisi',
      coinCost: 180,
      priceLabel: '₺29,99',
      terlikGrant: 5,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'energy_pack_10',
      title: 'Enerji Paketi',
      description: '+10 enerji · anında dolar, bekleme yok',
      coinCost: 80,
      priceLabel: '₺29,99',
      energyGrant: 10,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'full_energy',
      title: 'Tam Enerji',
      description: 'Enerjiyi anında maksimuma doldurur (30/30)',
      coinCost: 120,
      priceLabel: '₺59,99',
      fullEnergy: true,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'wood_chest',
      title: 'Ahşap Sandık',
      description: 'Anne Terliği x1 + 250 coin',
      coinCost: 200,
      priceLabel: '₺19,99',
      coinsGrant: 250,
      terlikGrant: 1,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'gold_chest',
      title: 'Altın Sandığı',
      description: '+1.200 Altın + F16 x1 + Raid x2 + Anne Terliği x2',
      coinCost: 750,
      priceLabel: '₺89,99',
      coinsGrant: 1200,
      f16Grant: 1,
      raidGrant: 2,
      terlikGrant: 2,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'surprise_box',
      title: 'Sürpriz Kutu',
      description: 'Anne Terliği x1 + Raid x1',
      coinCost: 350,
      priceLabel: '₺34,99',
      terlikGrant: 1,
      raidGrant: 1,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'star_pack',
      title: 'Yıldız Paketi',
      description: '1.000 coin + F16 x1',
      coinCost: 600,
      priceLabel: '₺149,99',
      coinsGrant: 1000,
      f16Grant: 1,
      rewardedAdEligible: false,
    ),
    StoreCatalogItem(
      id: 'double_coin',
      title: 'Çifte Coin',
      description: 'Makarayız Puan Çarpanı x2',
      coinCost: 400,
      priceLabel: '₺39,99',
      powerKey: 'x2',
      powerGrant: 2,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'luck_potion',
      title: 'Şans İksiri',
      description: '2048 Çiftleştir x1',
      coinCost: 180,
      priceLabel: '₺19,99',
      powerKey: 'pair2048',
      powerGrant: 1,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'coins_handful',
      title: 'Bir Avuç',
      description: '1.250 coin',
      coinCost: 0,
      priceLabel: '₺59,99',
      coinsGrant: 1250,
      rewardedAdEligible: false,
    ),
    StoreCatalogItem(
      id: 'coins_crate',
      title: 'Bir Kasa',
      description: '7.500 coin · +%50 bonus',
      coinCost: 0,
      priceLabel: '₺249,99',
      coinsGrant: 7500,
      rewardedAdEligible: false,
    ),
    StoreCatalogItem(
      id: 'royal_cape',
      title: 'Kraliyet Pelerini',
      description: 'Efsanevi Kraliyet Pelerini kozmetik görünümü',
      coinCost: 900,
      priceLabel: '₺99,99',
      unlockRoyalCape: true,
      rewardedAdEligible: false,
      isConsumable: false,
    ),
    StoreCatalogItem(
      id: 'mega_starter_pack',
      title: 'Dev Başlangıç Paketi',
      description:
          '+3.000 Altın + F16 x3 + Raid x3 + Anne Terliği x5 + Tam Enerji + Kraliyet Pelerini',
      coinCost: 1500,
      priceLabel: '₺149,99',
      coinsGrant: 3000,
      f16Grant: 3,
      raidGrant: 3,
      terlikGrant: 5,
      fullEnergy: true,
      unlockRoyalCape: true,
      rewardedAdEligible: false,
    ),
  ];

  /// 11 oyun modunun 33 güçlendirici kataloğu (11 × 3 = 33).
  static const List<ShopPowerUpCatalogEntry> shopPowerUpCatalog = [
    // 1. Suika Arena
    ShopPowerUpCatalogEntry(
      key: 'raid',
      modeId: 'suika',
      modeName: 'Suika Arena',
      title: 'Raid Spreyi',
      description: 'Küçük böcekleri temizler',
      coinCost: 450,
    ),
    ShopPowerUpCatalogEntry(
      key: 'terlik',
      modeId: 'suika',
      modeName: 'Suika Arena',
      title: 'Terlik Sarsıntısı',
      description: 'Alanı sarsıp yerleşimi düzeltir',
      coinCost: 300,
    ),
    ShopPowerUpCatalogEntry(
      key: 'f16',
      modeId: 'suika',
      modeName: 'Suika Arena',
      title: 'Aydınlat Hele!',
      description: 'F16 bombardımanı — 3 böceği yakıp geçer',
      coinCost: 250,
    ),
    // 2. 2048 Grid
    ShopPowerUpCatalogEntry(
      key: 'undo',
      modeId: 'grid_2048',
      modeName: '2048 Grid',
      title: 'Geri Al',
      description: 'Son hamleyi geri alır',
      coinCost: 200,
    ),
    ShopPowerUpCatalogEntry(
      key: 'shuffle',
      modeId: 'grid_2048',
      modeName: '2048 Grid',
      title: 'Karıştır',
      description: 'Izgarayı karıştırır, kilidi açar',
      coinCost: 350,
    ),
    ShopPowerUpCatalogEntry(
      key: 'pair',
      modeId: 'grid_2048',
      modeName: '2048 Grid',
      title: 'Çiftleştir',
      description: 'Rastgele iki aynı karoyu birleştirir',
      coinCost: 400,
    ),
    // 3. Balon Patlat
    ShopPowerUpCatalogEntry(
      key: 'triple',
      modeId: 'balloon_pop',
      modeName: 'Balon Patlat',
      title: 'Üçlü Ok',
      description: 'Tek atışta 3 balonu deler',
      coinCost: 300,
    ),
    ShopPowerUpCatalogEntry(
      key: 'bombb',
      modeId: 'balloon_pop',
      modeName: 'Balon Patlat',
      title: 'Bomba Balon',
      description: 'Alan patlatması yapar',
      coinCost: 450,
    ),
    ShopPowerUpCatalogEntry(
      key: 'slowb',
      modeId: 'balloon_pop',
      modeName: 'Balon Patlat',
      title: 'Yavaşlat',
      description: 'Balonları 10 sn yavaşlatır',
      coinCost: 250,
    ),
    // 4. Match 3
    ShopPowerUpCatalogEntry(
      key: 'hammer',
      modeId: 'match3',
      modeName: 'Match 3',
      title: 'Çekiç',
      description: 'Tek karo kırar',
      coinCost: 200,
    ),
    ShopPowerUpCatalogEntry(
      key: 'bomb3',
      modeId: 'match3',
      modeName: 'Match 3',
      title: 'Bomba',
      description: '3×3 alanı patlatır',
      coinCost: 400,
    ),
    ShopPowerUpCatalogEntry(
      key: 'hunter',
      modeId: 'match3',
      modeName: 'Match 3',
      title: 'Renk Avcısı',
      description: 'Bir türün hepsini toplar',
      coinCost: 500,
    ),
    // 5. Bağla Patlat
    ShopPowerUpCatalogEntry(
      key: 'chain',
      modeId: 'connect_pop',
      modeName: 'Bağla Patlat',
      title: 'Zincir Uzatıcı',
      description: 'Zincir hakkını artırır',
      coinCost: 250,
    ),
    ShopPowerUpCatalogEntry(
      key: 'bolt',
      modeId: 'connect_pop',
      modeName: 'Bağla Patlat',
      title: 'Yıldırım',
      description: 'Rastgele bir zincir oluşturur',
      coinCost: 350,
    ),
    ShopPowerUpCatalogEntry(
      key: 'magnet',
      modeId: 'connect_pop',
      modeName: 'Bağla Patlat',
      title: 'Mıknatıs',
      description: 'Aynı türü birbirine çeker',
      coinCost: 300,
    ),
    // 6. Stack Drop
    ShopPowerUpCatalogEntry(
      key: 'freeze',
      modeId: 'stack_drop',
      modeName: 'Stack Drop',
      title: 'Dondur',
      description: 'Sallantıyı durdurur',
      coinCost: 300,
    ),
    ShopPowerUpCatalogEntry(
      key: 'widen',
      modeId: 'stack_drop',
      modeName: 'Stack Drop',
      title: 'Genişlet',
      description: 'Dilimi büyütür',
      coinCost: 350,
    ),
    ShopPowerUpCatalogEntry(
      key: 'slows',
      modeId: 'stack_drop',
      modeName: 'Stack Drop',
      title: 'Yavaşlat',
      description: 'Düşüş hızını azaltır',
      coinCost: 250,
    ),
    // 7. Terlik Tap
    ShopPowerUpCatalogEntry(
      key: 'dblslip',
      modeId: 'terlik_tap',
      modeName: 'Terlik Tap',
      title: 'Çift Terlik',
      description: 'Tek dokunuşta çift vuruş',
      coinCost: 300,
    ),
    ShopPowerUpCatalogEntry(
      key: 'goldslip',
      modeId: 'terlik_tap',
      modeName: 'Terlik Tap',
      title: 'Altın Terlik',
      description: 'Süreli 2x puan',
      coinCost: 450,
    ),
    ShopPowerUpCatalogEntry(
      key: 'spraybug',
      modeId: 'terlik_tap',
      modeName: 'Terlik Tap',
      title: 'Böcek İlacı',
      description: 'Ekrandaki böcekleri temizler',
      coinCost: 400,
    ),
    // 8. Yuva Savunması
    ShopPowerUpCatalogEntry(
      key: 'yuva_dblslip',
      modeId: 'yuva_defense',
      modeName: 'Yuva Savunması',
      title: 'Çift Terlik',
      description: 'Tek dokunuşta çift vuruş',
      coinCost: 300,
    ),
    ShopPowerUpCatalogEntry(
      key: 'yuva_goldslip',
      modeId: 'yuva_defense',
      modeName: 'Yuva Savunması',
      title: 'Altın Terlik',
      description: 'Süreli 2x puan',
      coinCost: 450,
    ),
    ShopPowerUpCatalogEntry(
      key: 'nest_shield',
      modeId: 'yuva_defense',
      modeName: 'Yuva Savunması',
      title: 'Yuva Kalkanı',
      description: 'Bir kaçışı affeder',
      coinCost: 400,
    ),
    // 9. Osmantuş
    ShopPowerUpCatalogEntry(
      key: 'dik',
      modeId: 'osmantus',
      modeName: 'Osmantuş',
      title: 'Dıkkış Boost',
      description: 'Tempo artışı — halka yavaşlar',
      coinCost: 250,
    ),
    ShopPowerUpCatalogEntry(
      key: 'ring',
      modeId: 'osmantus',
      modeName: 'Osmantuş',
      title: 'Geniş Halka',
      description: 'Hedef halkayı büyütür',
      coinCost: 300,
    ),
    ShopPowerUpCatalogEntry(
      key: 'mic',
      modeId: 'osmantus',
      modeName: 'Osmantuş',
      title: 'Mikrofon',
      description: 'Komboyu bir hatada korur',
      coinCost: 400,
    ),
    // 10. Çığlık Böcek
    ShopPowerUpCatalogEntry(
      key: 'jump',
      modeId: 'scream_roach',
      modeName: 'Çığlık Böcek',
      title: 'Zıplama Botu',
      description: 'Engelleri aşar',
      coinCost: 300,
    ),
    ShopPowerUpCatalogEntry(
      key: 'shield',
      modeId: 'scream_roach',
      modeName: 'Çığlık Böcek',
      title: 'Kalkan',
      description: 'Bir hatayı affeder',
      coinCost: 350,
    ),
    ShopPowerUpCatalogEntry(
      key: 'nitro',
      modeId: 'scream_roach',
      modeName: 'Çığlık Böcek',
      title: 'Nitro',
      description: 'Hız ve puan artışı',
      coinCost: 400,
    ),
    // 11. Makarayız
    ShopPowerUpCatalogEntry(
      key: 'beat',
      modeId: 'makarayiz',
      modeName: 'Makarayız',
      title: 'Beat Dondur',
      description: 'Ritmi yavaşlatır',
      coinCost: 250,
    ),
    ShopPowerUpCatalogEntry(
      key: 'auto',
      modeId: 'makarayiz',
      modeName: 'Makarayız',
      title: 'Oto Makara',
      description: 'Kısa süre otomatik oynar',
      coinCost: 500,
    ),
    ShopPowerUpCatalogEntry(
      key: 'x2',
      modeId: 'makarayiz',
      modeName: 'Makarayız',
      title: 'Puan Çarpanı',
      description: 'Süreli x2 puan',
      coinCost: 350,
    ),
  ];

  static final Set<String> productIds = {
    ...packs.map((p) => p.id),
    ...storeCatalog.map((item) => item.id),
  };

  String status = 'IAP · store bağlanıyor…';
  bool storeAvailable = false;

  /// Son ürün sorgusunda mağazada bulunamayan ürün kimlikleri (S2#24).
  /// Boş değilse katalog eksiktir: bu kimlikler mağaza konsolunda
  /// tanımlı değil ya da henüz yayılmamıştır.
  List<String> _missingProductIds = const [];
  List<String> get missingProductIds => List.unmodifiable(_missingProductIds);

  final Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _booted = false;

  /// Teslim edilmiş mağaza işlem kimlikleri (K1 tekrar koruması).
  ///
  /// Başarıyla teslim edilen her `purchaseID` kalıcı olarak işaretlenir;
  /// mağaza aynı işlemi yeniden gönderirse ürün ikinci kez verilmez.
  /// Liste en fazla [_maxDeliveredPurchaseIds] kimlik tutar (en eskiler
  /// atılır); kimliği boş olan işlemler işaretlenemez ve her zaman
  /// normal akışla teslim edilir.
  ///
  /// IAP-3: kap 200 → 1000. Kimlikler kısa metinlerdir (~20-40 karakter);
  /// 1000 kimlik SharedPreferences'ta on KB mertebesindedir, büyüme
  /// sınırlı kalır. 200 kap, sık satın alan bir kullanıcıda eski bir
  /// işlem kimliğinin atılıp aynı işlemin yeniden teslim edilmesine yol
  /// açabilirdi; 1000 ile bu eşik pratikte aşılmaz. Kap tamamen
  /// kaldırılmadı: kalıcı liste sınırsız büyümemelidir.
  static const String _deliveredIdsPrefKey = 'lululu_iap_delivered_ids';
  static const int _maxDeliveredPurchaseIds = 1000;
  final Set<String> _deliveredPurchaseIds = <String>{};
  Future<void>? _deliveredIdsFuture;

  Future<void> _ensureDeliveredIdsLoaded() =>
      _deliveredIdsFuture ??= _loadDeliveredIds();

  Future<void> _loadDeliveredIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored =
          prefs.getStringList(_deliveredIdsPrefKey) ?? const <String>[];
      _deliveredPurchaseIds
        ..clear()
        ..addAll(stored.where((id) => id.trim().isNotEmpty));
      if (_deliveredPurchaseIds.length > _maxDeliveredPurchaseIds) {
        final ids = _deliveredPurchaseIds.toList();
        _deliveredPurchaseIds
          ..clear()
          ..addAll(
            ids.sublist(ids.length - _maxDeliveredPurchaseIds),
          );
      }
    } catch (e) {
      debugPrint('[lululu] IAP teslim kimlikleri okunamadı: $e');
    }
  }

  Future<void> _markPurchaseDelivered(String purchaseId) async {
    if (purchaseId.isEmpty ||
        _deliveredPurchaseIds.contains(purchaseId)) {
      return;
    }
    _deliveredPurchaseIds.add(purchaseId);
    try {
      var ids = _deliveredPurchaseIds.toList();
      if (ids.length > _maxDeliveredPurchaseIds) {
        ids = ids.sublist(ids.length - _maxDeliveredPurchaseIds);
        _deliveredPurchaseIds
          ..clear()
          ..addAll(ids);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_deliveredIdsPrefKey, ids);
    } catch (e) {
      // Kalıcı işaret yazılamadı: bu oturumda bellek içi küme korur;
      // işlem yine de tamamlanır, mağaza yeniden göndermez.
      debugPrint('[lululu] IAP teslim kimliği yazılamadı: $e');
    }
  }

  /// IAP olayını mevcut telemetri kanalına yazar (K1/K7).
  ///
  /// Breadcrumb'lar cihaz-içi tanılama tamponundadır; işlem kimliğinin
  /// kendisi yazılmaz, yalnızca varlığı (`hasPurchaseId`) kaydedilir.
  void _recordIapBreadcrumb(String action, PurchaseDetails purchase) {
    GameTelemetryService.instance.recordBreadcrumb(
      'iap',
      action,
      meta: <String, Object?>{
        'productId': purchase.productID,
        'status': purchase.status.name,
        'hasPurchaseId': purchase.purchaseID?.trim().isNotEmpty ?? false,
      },
    );
  }

  static StoreCatalogItem? findCatalogItem(String idOrTitle) {
    final key = _normalizeProductKey(idOrTitle);
    for (final item in storeCatalog) {
      if (item.id == key || item.title.toLowerCase() == key) {
        return item;
      }
    }
    return null;
  }

  static ShopPowerUpCatalogEntry? findPowerUpEntry(
    String powerKeyOrName, {
    String? modeNameOrId,
  }) {
    final normalizedMode = modeNameOrId == null || modeNameOrId.trim().isEmpty
        ? null
        : ProgressManager.normalizeModeId(modeNameOrId);
    final rawLower = powerKeyOrName.trim().toLowerCase();
    final canonicalKey = ProgressManager.normalizePowerKey(powerKeyOrName);

    if (normalizedMode != null) {
      for (final entry in shopPowerUpCatalog) {
        if (entry.modeId == normalizedMode ||
            entry.modeName.toLowerCase() == modeNameOrId!.trim().toLowerCase()) {
          if (entry.key == canonicalKey ||
              entry.title.toLowerCase() == rawLower ||
              ProgressManager.normalizePowerKey(entry.title) == canonicalKey) {
            return entry;
          }
        }
      }
    }

    for (final entry in shopPowerUpCatalog) {
      if (entry.key == canonicalKey || entry.title.toLowerCase() == rawLower) {
        return entry;
      }
    }
    return null;
  }

  static String _normalizeProductKey(String raw) {
    final trimmed = raw.trim().toLowerCase();
    switch (trimmed) {
      case 'f16':
      case 'f16 x3':
      case 'f16_x3':
        return 'f16_x3';
      case 'raid':
      case 'raid x3':
      case 'raid_x3':
        return 'raid_x3';
      case 'terlik':
      case 'anne terliği':
      case 'anne terliği x5':
      case 'anne terligi x5':
      case 'terlik_x5':
        return 'terlik_x5';
      case '+10 enerji':
      case '10 enerji':
      case 'enerji paketi':
      case 'energy_pack':
      case 'energy_pack_10':
        return 'energy_pack_10';
      case 'tam enerji':
      case 'enerji deposu':
      case 'full_energy':
        return 'full_energy';
      case 'ahşap sandık':
      case 'ahsap sandik':
      case 'ücretsiz sandık':
      case 'ucretsiz sandik':
      case 'wood_chest':
        return 'wood_chest';
      case 'altın sandığı':
      case 'altın sandık':
      case 'altin sandigi':
      case 'altin sandik':
      case 'gold_chest':
        return 'gold_chest';
      case 'sürpriz kutu':
      case 'surpriz kutu':
      case 'surprise_box':
        return 'surprise_box';
      case 'yıldız paketi':
      case 'yildiz paketi':
      case 'star_pack':
        return 'star_pack';
      case 'çifte coin':
      case 'cifte coin':
      case 'double_coin':
        return 'double_coin';
      case 'şans iksiri':
      case 'sans iksiri':
      case 'luck_potion':
        return 'luck_potion';
      case 'bir avuç':
      case 'bir avuc':
      case 'coins_handful':
        return 'coins_handful';
      case 'bir kasa':
      case 'coins_crate':
        return 'coins_crate';
      case 'küçük torba':
      case 'kucuk torba':
      case 'coins_small':
        return 'coins_small';
      case 'makara paket':
      case 'coins_mid':
        return 'coins_mid';
      case 'kongo sandık':
      case 'kongo sandik':
      case 'coins_big':
        return 'coins_big';
      case 'kraliyet pelerini':
      case 'royal_cape':
        return 'royal_cape';
      case 'dev başlangıç paketi':
      case 'dev baslangic paketi':
      case 'mega_starter_pack':
        return 'mega_starter_pack';
      default:
        return trimmed;
    }
  }

  Future<void> ensureLoaded() async {
    if (_booted) return;
    _booted = true;
    try {
      // K1: tekrar koruması, satın alma akışı dinlenmeden önce hazır olur.
      await _ensureDeliveredIdsLoaded();
      final iap = InAppPurchase.instance;
      // Web'de yanıt gelmeyen kanal çağrısı süresiz asılmasın diye
      // 6 sn zaman aşımı (bulgu #16: satın alma hiç dönmüyordu).
      // Zaman aşımı aşağıdaki catch'e düşer: mağaza yok sayılır.
      storeAvailable = await iap
          .isAvailable()
          .timeout(const Duration(seconds: 6));
      if (!storeAvailable) {
        status = kDebugMode
            ? 'Store yok · sandbox simülasyon açık (yalnızca debug)'
            : 'Mağaza kullanılamıyor';
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
      final resp = await iap
          .queryProductDetails(productIds)
          .timeout(const Duration(seconds: 6));
      for (final p in resp.productDetails) {
        _products[p.id] = p;
      }
      // S2#24: bulunamayan kimlikler yok sayılmaz — durum iletisine ve
      // debug kaydına yazılır, katalog eksikliği görünür olur.
      _missingProductIds = List<String>.from(resp.notFoundIDs);
      if (_missingProductIds.isNotEmpty) {
        debugPrint('[lululu] IAP bulunamayan ürünler '
            '(${_missingProductIds.length}/${productIds.length}): '
            '${_missingProductIds.join(', ')}');
      }
      final missingSuffix = _missingProductIds.isEmpty
          ? ''
          : ' · bulunamadı (${_missingProductIds.length}): '
              '${_missingProductIds.join(', ')}';
      status = _products.isEmpty
          ? (kDebugMode
              ? 'Ürün ID bulunamadı · sandbox simülasyon (yalnızca debug)$missingSuffix'
              : 'Mağaza ürünleri bulunamadı$missingSuffix')
          : 'Store hazır · ${_products.length} ürün$missingSuffix';
    } catch (e) {
      storeAvailable = false;
      status = kDebugMode
          ? 'Store kanal yok · sandbox simülasyon ($e)'
          : 'Mağaza kullanılamıyor';
    }
    notifyListeners();
  }

  /// İstemci-içi asgari doğrulama: sürüm derlemesinde (release/profile)
  /// doğrulama verisi boş olan bir satın alma teslim edilmez. Debug'da
  /// mağaza sandbox'ı doğrulama verisi döndürmeyebildiği için izin verilir.
  ///
  /// Bu kontrol tek başına yeterli DEĞİLDİR: istemciye gelen doğrulama
  /// verisi taklit edilebilir.
  /// TODO (sunucu doğrulaması, kapsam dışı): teslimattan önce satın alma
  /// bir arka uç servisinde doğrulanmalıdır — App Store makbuzu
  /// (App Store Server API) / Play satın alma jetonu (Google Play
  /// Developer API) sunucuda sorgulanıp onaylanmadan ürün verilmemeli,
  /// aynı işlem kimliği (purchaseID) iki kez teslim edilmemelidir.
  /// Sunucu hazır olana dek bu asgari kontrol sürümde boş veriyle
  /// teslimatı engeller.
  bool _isVerifiedForDelivery(PurchaseDetails purchase) {
    if (kDebugMode) return true;
    return purchase.verificationData.serverVerificationData.trim().isNotEmpty;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        status = 'Ödeme bekleniyor…';
        notifyListeners();
        continue;
      }
      // K1: teslim edilemeyen satın alma tamamlanmaz. Tamamlama kararı
      // varsayılan olarak bekleyen duruma eşittir; teslimat başarısız
      // olursa aşağıda iptal edilir ve işlem mağaza kuyruğunda kalır.
      var shouldComplete = purchase.pendingCompletePurchase;
      if (purchase.status == PurchaseStatus.error) {
        status = 'Satın alma hata · ${purchase.error?.message}';
        notifyListeners();
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (!_isVerifiedForDelivery(purchase)) {
          status = 'Doğrulama başarısız · ürün teslim edilmedi';
          notifyListeners();
          // completePurchase çağrılmaz: tamamlanmamış satın alma mağaza
          // kuyruğunda kalır; sunucu doğrulaması eklendiğinde aynı
          // işlem yeniden ele alınıp doğrulanarak teslim edilebilir.
          continue;
        }
        await _ensureDeliveredIdsLoaded();
        final purchaseId = purchase.purchaseID?.trim() ?? '';
        if (purchaseId.isNotEmpty &&
            _deliveredPurchaseIds.contains(purchaseId)) {
          // K1 tekrar koruması: ürün ikinci kez verilmez. İşlem daha
          // önce teslim edildiği için tamamlanması güvenlidir; kuyrukta
          // bırakmak aynı işlemin her açılışta yeniden gelmesine yol açar.
          status = 'Zaten teslim edildi · tekrar verilmedi';
          notifyListeners();
          _recordIapBreadcrumb('duplicate_delivery_blocked', purchase);
        } else {
          var delivered = false;
          var threw = false;
          try {
            delivered = await _deliverProduct(
              purchase.productID,
              source: 'Satın alındı',
            );
          } catch (e) {
            threw = true;
            debugPrint('[lululu] IAP teslimat hata: $e');
          }
          if (delivered) {
            if (purchaseId.isNotEmpty) {
              await _markPurchaseDelivered(purchaseId);
            }
            // K7: teslimat anı, durum iletisinin yanında mevcut
            // telemetri kanalına da yazılır (status'ü okuyan UI Faz 2'de).
            _recordIapBreadcrumb('delivered', purchase);
          } else {
            // K1: ürün verilmedi — işlem tamamlanmaz, kuyrukta kalır.
            shouldComplete = false;
            if (threw) {
              status = 'Teslimat hata · ürün verilmedi, tekrar denenecek';
              _recordIapBreadcrumb('delivery_failed_error', purchase);
            } else {
              status =
                  'Teslim edilemedi · bilinmeyen ürün (${purchase.productID})';
              _recordIapBreadcrumb(
                'delivery_failed_unknown_product',
                purchase,
              );
            }
            notifyListeners();
          }
        }
      }
      if (shouldComplete) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<bool> _deliverProduct(String rawId, {required String source}) async {
    final key = _normalizeProductKey(rawId);
    final pack = packs.where((p) => p.id == key).firstOrNull;
    if (pack != null) {
      await ProgressManager().addCoins(pack.coins);
      status = '$source · ${pack.title} (+${pack.coins})';
      notifyListeners();
      return true;
    }

    final catalogItem = findCatalogItem(key);
    if (catalogItem != null) {
      // IAP-1: mağaza yolu, coin yolundaki (buyWithCoins, O19) rollback
      // deseninin aynısını kullanır. Grant yarıda fırlatırsa kısmi
      // grant [_rollbackCatalogGrant] ile geri alınır ve `false` döner:
      // işlem kuyrukta kalır, temiz yeniden denemede çift-grant olmaz.
      final pm = ProgressManager.instance;
      final coinsBefore = pm.coins;
      final f16Before = pm.f16Count;
      final raidBefore = pm.raidCount;
      final terlikBefore = pm.terlikCount;
      final powerBefore = catalogItem.powerKey == null
          ? 0
          : pm.powerCount(catalogItem.powerKey!);
      final energyBefore = EnergyService.instance.energy;
      final hadRoyalCape = pm.hasRoyalCape;
      try {
        await _applyCatalogGrant(catalogItem);
      } catch (e) {
        debugPrint('[lululu] IAP mağaza teslimat hata, geri alınıyor: $e');
        await _rollbackCatalogGrant(
          pm: pm,
          item: catalogItem,
          coinsBefore: coinsBefore,
          f16Before: f16Before,
          raidBefore: raidBefore,
          terlikBefore: terlikBefore,
          powerBefore: powerBefore,
          energyBefore: energyBefore,
          hadRoyalCape: hadRoyalCape,
        );
        return false;
      }
      status = '$source · ${catalogItem.title}';
      notifyListeners();
      return true;
    }
    return false;
  }

  /// YALNIZCA TEST (IAP-1): `true` iken [_applyCatalogGrant] coin
  /// grant'ini uyguladıktan sonra fırlatır — grant ortasında kesilme
  /// simülasyonu. Üretimde her zaman `false` kalır; grant yolları
  /// (clamp'lı sayaçlar) kendiliğinden fırlatmadığı için deterministik
  /// bir hata simülasyonunun başka yolu yoktur.
  @visibleForTesting
  static bool throwAfterCoinsGrantForTest = false;

  Future<void> _applyCatalogGrant(StoreCatalogItem item) async {
    final pm = ProgressManager.instance;
    if (item.coinsGrant > 0) {
      await pm.addCoins(item.coinsGrant);
    }
    if (throwAfterCoinsGrantForTest) {
      throw StateError('IAP-1 test: grant coin adımından sonra kesildi');
    }
    if (item.f16Grant > 0 || item.raidGrant > 0 || item.terlikGrant > 0) {
      await pm.grantArcadeDrop(
        f16: item.f16Grant,
        spray: item.raidGrant,
        slipper: item.terlikGrant,
      );
    }
    if (item.powerKey != null && item.powerGrant > 0) {
      await pm.incrementPowerCount(item.powerKey!, item.powerGrant);
    }
    if (item.energyGrant > 0) {
      EnergyService.instance.addEnergy(item.energyGrant);
    }
    if (item.fullEnergy) {
      await EnergyService.instance.refillFull();
    }
    if (item.unlockRoyalCape) {
      pm.hasRoyalCape = true;
      pm.ownedCosmetics.add('royal_cape');
      await pm.persistBoosters();
    }
  }

  /// Katalog grant'i boş mu (hiçbir şey vermiyor mu).
  ///
  /// O19 ön doğrulaması: boş grant'e coin harcanmaz. Negatif veya sıfır
  /// grant alanları [_applyCatalogGrant] tarafından yok sayıldığı için
  /// burada da grant sayılmaz.
  bool _catalogGrantIsEmpty(StoreCatalogItem item) {
    return item.coinsGrant <= 0 &&
        item.f16Grant <= 0 &&
        item.raidGrant <= 0 &&
        item.terlikGrant <= 0 &&
        !(item.powerKey != null && item.powerGrant > 0) &&
        item.energyGrant <= 0 &&
        !item.fullEnergy &&
        !item.unlockRoyalCape;
  }

  /// Coin bakiyesini [snapshot] değerine kalıcı şekilde döndürür.
  ///
  /// Fark [ProgressManager.addCoins]/[ProgressManager.spendCoins] ile
  /// kapatılır, böylece bütünlük imzası da güncellenir. Geri alma
  /// farkları (harcama + grant toplamı) tek seferlik grant üst sınırının
  /// çok altındadır; kısmi yazma riski yoktur.
  Future<void> _restoreCoinsToSnapshot(
    ProgressManager pm,
    int snapshot,
  ) async {
    final delta = snapshot - pm.coins;
    if (delta > 0) {
      await pm.addCoins(delta);
    } else if (delta < 0) {
      await pm.spendCoins(-delta);
    }
  }

  /// Başarısız katalog grant'ini geri alır (O19).
  ///
  /// Coin bakiyesi, güçlendirici sayıları, enerji ve pelerin durumu
  /// anlık görüntüdeki değerlere döndürülür. Geri alma kendisi de
  /// fırlatırsa yutulur: çağıran zaten hata yolundadır ve geri alma
  /// hatası satın alma sonucunu değiştirmemelidir.
  Future<void> _rollbackCatalogGrant({
    required ProgressManager pm,
    required StoreCatalogItem item,
    required int coinsBefore,
    required int f16Before,
    required int raidBefore,
    required int terlikBefore,
    required int powerBefore,
    required int energyBefore,
    required bool hadRoyalCape,
  }) async {
    try {
      // Önce coin: sonraki kalıcı yazmalar geri alınmış bakiyeyi yazar.
      await _restoreCoinsToSnapshot(pm, coinsBefore);
      if (pm.f16Count != f16Before) {
        await pm.setPowerCount('f16', f16Before);
      }
      if (pm.raidCount != raidBefore) {
        await pm.setPowerCount('raid', raidBefore);
      }
      if (pm.terlikCount != terlikBefore) {
        await pm.setPowerCount('terlik', terlikBefore);
      }
      if (item.powerKey != null &&
          pm.powerCount(item.powerKey!) != powerBefore) {
        await pm.setPowerCount(item.powerKey!, powerBefore);
      }
      if (EnergyService.instance.energy != energyBefore) {
        EnergyService.instance.energy = energyBefore;
      }
      if (!hadRoyalCape && pm.hasRoyalCape) {
        pm.hasRoyalCape = false;
        pm.ownedCosmetics.remove('royal_cape');
        await pm.persistBoosters();
      }
    } catch (e) {
      debugPrint('[lululu] IAP geri alma başarısız: $e');
    }
  }

  /// Uygulama içi satın alma (StoreKit / Play Billing). Mağaza veya ürün
  /// yoksa YALNIZCA debug derlemesinde sandbox bağışı yapılır; sürümde
  /// `false` döner ve ürün verilmez.
  ///
  /// Dönen değer satın almanın BAŞLATILDIĞINI gösterir; gerçek teslimat
  /// asenkron olarak satın alma akışından ([_onPurchases]) gelir. Teslimat
  /// anı `status` iletisine ve telemetri breadcrumb'ına yazılır (K7).
  Future<bool> purchase(String packId) async {
    await ensureLoaded();
    final key = _normalizeProductKey(packId);
    final pack = packs.where((p) => p.id == key).firstOrNull;
    final catalogItem = findCatalogItem(key);
    if (pack == null && catalogItem == null) return false;

    final details = _products[key];
    if (details != null && storeAvailable) {
      status = 'Store satın alma…';
      notifyListeners();
      final param = PurchaseParam(productDetails: details);
      // Başlatma çağrısı da yanıtsız kalırsa kullanıcı kilitlenmesin:
      // 10 sn'de false döner; akış sonradan tamamlanırsa purchase
      // stream teslimatı yine işler (bulgu #16).
      final ok = (catalogItem != null && !catalogItem.isConsumable)
          ? await InAppPurchase.instance
              .buyNonConsumable(purchaseParam: param)
              .timeout(const Duration(seconds: 10), onTimeout: () => false)
          : await InAppPurchase.instance
              .buyConsumable(purchaseParam: param)
              .timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (!ok) {
        status = 'Satın alma başlatılamadı';
        notifyListeners();
      }
      return ok;
    }

    // Sandbox yolu YALNIZCA debug'da (simülatör / eksik mağaza ürünü).
    // Sürümde mağaza/ürün yoksa ödeme alınmadan ürün verilmez: açık
    // hata sonucu döndürülür.
    if (!kDebugMode) {
      status = 'Mağaza kullanılamıyor · satın alma yapılamadı';
      notifyListeners();
      return false;
    }
    return _deliverProduct(key, source: 'Sandbox grant');
  }

  /// Altın (Coin) ile mağaza ürünü satın alma.
  ///
  /// Grant önce doğrulanır, harcama sonra yapılır; grant yarıda
  /// fırlatırsa harcanan altın iade edilir ve kısmi grant geri alınır
  /// (O19). Bu yöntem fırlatmaz: her hata `false` döner.
  Future<bool> buyWithCoins(String itemIdOrTitle, {int? overrideCost}) async {
    await ensureLoaded();
    final item = findCatalogItem(itemIdOrTitle);
    if (item == null) return false;
    final cost = overrideCost ?? item.coinCost;
    if (cost < 0) {
      status = 'Geçersiz fiyat · satın alma yapılmadı';
      notifyListeners();
      return false;
    }
    if (_catalogGrantIsEmpty(item)) {
      status = 'Ürün grant\'i boş · satın alma yapılmadı';
      notifyListeners();
      return false;
    }
    final pm = ProgressManager();
    if (pm.coins < cost) {
      status = 'Yetersiz altın (${pm.coins}/$cost)';
      notifyListeners();
      return false;
    }
    // Geri alma anlık görüntüsü (O19).
    final coinsBefore = pm.coins;
    final f16Before = pm.f16Count;
    final raidBefore = pm.raidCount;
    final terlikBefore = pm.terlikCount;
    final powerBefore =
        item.powerKey == null ? 0 : pm.powerCount(item.powerKey!);
    final energyBefore = EnergyService.instance.energy;
    final hadRoyalCape = pm.hasRoyalCape;
    try {
      final spent = await pm.spendCoins(cost);
      if (!spent) return false;
      await _applyCatalogGrant(item);
    } catch (e) {
      debugPrint('[lululu] IAP coin satın alma hata, geri alınıyor: $e');
      await _rollbackCatalogGrant(
        pm: pm,
        item: item,
        coinsBefore: coinsBefore,
        f16Before: f16Before,
        raidBefore: raidBefore,
        terlikBefore: terlikBefore,
        powerBefore: powerBefore,
        energyBefore: energyBefore,
        hadRoyalCape: hadRoyalCape,
      );
      status = 'Satın alma hata · altın iade edildi';
      notifyListeners();
      GameTelemetryService.instance.recordBreadcrumb(
        'iap',
        'coin_purchase_rolled_back',
        meta: <String, Object?>{
          'productId': item.id,
          'cost': cost,
        },
      );
      return false;
    }
    status = 'Altınla alındı · ${item.title} (-$cost coin)';
    notifyListeners();
    return true;
  }

  /// Ödüllü reklam izleyerek mağaza ürünü / sandık / enerji kazanma.
  ///
  /// Reklam SDK'sı kurulu olmadığı için ([rewardedAdsAvailable] `false`)
  /// gerçek bir reklam gösterilemez; bu yöntem ödül VERMEZ ve her zaman
  /// `false` döndürür. İmza, mevcut çağrıcılarla uyumluluk için korunur.
  /// Gerçek SDK entegrasyonu tamamlandığında reklam gösterimi doğrulanıp
  /// ödül ancak izleme tamamlandıktan sonra verilmelidir.
  Future<bool> claimWithRewardedAd(String itemIdOrTitle) async {
    await ensureLoaded();
    status = 'Ödüllü reklam kullanılamıyor · reklam SDK\'sı kurulu değil';
    notifyListeners();
    return false;
  }

  /// Mağazadaki 33 oyun modu güçlendiricisinden birini altınla veya ödüllü reklamla satın alır.
  ///
  /// Grant önce doğrulanır, harcama sonra yapılır; grant fırlatırsa
  /// harcanan altın iade edilir ve kısmi grant geri alınır (O19).
  /// Bu yöntem fırlatmaz: her hata `false` döner.
  Future<bool> purchaseShopPowerUp(
    String powerKeyOrName, {
    String? modeName,
    int? coinCost,
    int quantity = 1,
    bool useRewardedAd = false,
  }) async {
    await ensureLoaded();
    if (quantity <= 0) return false;
    final entry = findPowerUpEntry(powerKeyOrName, modeNameOrId: modeName);
    final canonicalKey =
        entry?.key ?? ProgressManager.normalizePowerKey(powerKeyOrName);
    // Boş anahtar hayalet grant'e (extraPowers['']) coin harcatır; reddet.
    if (canonicalKey.isEmpty) return false;
    final displayTitle = entry?.title ?? powerKeyOrName;
    final pm = ProgressManager.instance;

    if (useRewardedAd) {
      // Reklam SDK'sı yok: reklam gösterilmeden ödül verilmez.
      status = 'Ödüllü reklam kullanılamıyor · reklam SDK\'sı kurulu değil';
      notifyListeners();
      return false;
    }

    final unitCost = coinCost ?? entry?.coinCost ?? 300;
    final totalCost = unitCost * quantity;
    if (totalCost < 0 || pm.coins < totalCost) {
      status = 'Yetersiz altın (${pm.coins}/$totalCost)';
      notifyListeners();
      return false;
    }
    // Geri alma anlık görüntüsü (O19).
    final coinsBefore = pm.coins;
    final powerBefore = pm.powerCount(canonicalKey);
    try {
      final spent = await pm.spendCoins(totalCost);
      if (!spent) return false;
      await pm.incrementPowerCount(canonicalKey, quantity);
    } catch (e) {
      debugPrint('[lululu] IAP güçlendirici alma hata, geri alınıyor: $e');
      try {
        await _restoreCoinsToSnapshot(pm, coinsBefore);
        if (pm.powerCount(canonicalKey) != powerBefore) {
          await pm.setPowerCount(canonicalKey, powerBefore);
        }
      } catch (rollbackError) {
        debugPrint('[lululu] IAP geri alma başarısız: $rollbackError');
      }
      status = 'Satın alma hata · altın iade edildi';
      notifyListeners();
      GameTelemetryService.instance.recordBreadcrumb(
        'iap',
        'powerup_purchase_rolled_back',
        meta: <String, Object?>{
          'powerKey': canonicalKey,
          'quantity': quantity,
          'cost': totalCost,
        },
      );
      return false;
    }
    status = 'Güçlendirici alındı · $displayTitle (+$quantity)';
    notifyListeners();
    return true;
  }

  /// Mağazadaki enerji paketlerini (+10 enerji, Tam Enerji), sandıkları, iksirleri,
  /// coin paketlerini ve 33 güçlendiriciyi satın alma / reklamla alma birleşik yardımcısı.
  Future<bool> purchaseShopItem(
    String itemIdOrTitle, {
    int? overrideCoinCost,
    bool useRewardedAd = false,
    String? modeName,
  }) async {
    await ensureLoaded();
    if (useRewardedAd) {
      return claimWithRewardedAd(itemIdOrTitle);
    }

    final key = _normalizeProductKey(itemIdOrTitle);

    // 1. Doğrudan IAP Coin Paketi mi?
    final pack = packs.where((p) => p.id == key).firstOrNull;
    if (pack != null) {
      return purchase(pack.id);
    }

    // 2. Mağaza Kataloğu Ürünü mü?
    final catalogItem = findCatalogItem(key);
    if (catalogItem != null) {
      if (overrideCoinCost != null || catalogItem.coinCost > 0) {
        final cost = overrideCoinCost ?? catalogItem.coinCost;
        if (cost > 0 && ProgressManager.instance.coins >= cost) {
          return buyWithCoins(catalogItem.id, overrideCost: cost);
        } else if (overrideCoinCost != null) {
          status = 'Yetersiz altın (${ProgressManager.instance.coins}/$cost)';
          notifyListeners();
          return false;
        }
      }
      return purchase(catalogItem.id);
    }

    // 3. 33 Oyun Modu Güçlendiricisi mi?
    final powerEntry = findPowerUpEntry(itemIdOrTitle, modeNameOrId: modeName);
    if (powerEntry != null) {
      return purchaseShopPowerUp(
        powerEntry.key,
        modeName: modeName ?? powerEntry.modeId,
        coinCost: overrideCoinCost ?? powerEntry.coinCost,
      );
    }

    return false;
  }

  /// Satın alımları geri yükler (Kraliyet Pelerini vb. non-consumable ürünler için).
  ///
  /// Mağaza yoksa geri yükleme yapılamaz: `false` döner ve yerel kasa
  /// başarı sayılmaz. Geri yüklenen ürünler satın alma akışından
  /// ([_onPurchases]) teslim edilir.
  Future<bool> restorePurchases() async {
    await ensureLoaded();
    if (!storeAvailable) {
      status = 'Geri yükleme kullanılamıyor · mağaza yok';
      notifyListeners();
      return false;
    }
    try {
      await InAppPurchase.instance.restorePurchases();
      status = 'Geri yükleme başlatıldı';
      notifyListeners();
      return true;
    } catch (e) {
      status = 'Geri yükleme hata ($e)';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
