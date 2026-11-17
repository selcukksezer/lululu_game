import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'energy_service.dart';
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
      description: 'Rastgele güçlendirici + 250 coin',
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
      description: 'Rastgele moddan 1 güçlendirici',
      coinCost: 350,
      priceLabel: '₺34,99',
      terlikGrant: 1,
      raidGrant: 1,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'star_pack',
      title: 'Yıldız Paketi',
      description: '25 yıldız + 1.000 coin',
      coinCost: 600,
      priceLabel: '₺149,99',
      coinsGrant: 1000,
      f16Grant: 1,
      rewardedAdEligible: false,
    ),
    StoreCatalogItem(
      id: 'double_coin',
      title: 'Çifte Coin',
      description: '30 dakika boyunca 2× coin',
      coinCost: 400,
      priceLabel: '₺39,99',
      powerKey: 'x2',
      powerGrant: 2,
      rewardedAdEligible: true,
    ),
    StoreCatalogItem(
      id: 'luck_potion',
      title: 'Şans İksiri',
      description: 'Birleşmede kritik şansı artar',
      coinCost: 180,
      priceLabel: '₺19,99',
      powerKey: 'pair',
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
      final iap = InAppPurchase.instance;
      storeAvailable = await iap.isAvailable();
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
      final resp = await iap.queryProductDetails(productIds);
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
        await _deliverProduct(purchase.productID, source: 'Satın alındı');
      }
      if (purchase.pendingCompletePurchase) {
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
      await _applyCatalogGrant(catalogItem);
      status = '$source · ${catalogItem.title}';
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> _applyCatalogGrant(StoreCatalogItem item) async {
    final pm = ProgressManager.instance;
    if (item.coinsGrant > 0) {
      await pm.addCoins(item.coinsGrant);
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

  /// Uygulama içi satın alma (StoreKit / Play Billing). Mağaza veya ürün
  /// yoksa YALNIZCA debug derlemesinde sandbox bağışı yapılır; sürümde
  /// `false` döner ve ürün verilmez.
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
      final ok = (catalogItem != null && !catalogItem.isConsumable)
          ? await InAppPurchase.instance.buyNonConsumable(purchaseParam: param)
          : await InAppPurchase.instance.buyConsumable(purchaseParam: param);
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
  Future<bool> buyWithCoins(String itemIdOrTitle, {int? overrideCost}) async {
    await ensureLoaded();
    final item = findCatalogItem(itemIdOrTitle);
    if (item == null) return false;
    final cost = overrideCost ?? item.coinCost;
    final pm = ProgressManager();
    if (pm.coins < cost) {
      status = 'Yetersiz altın (${pm.coins}/$cost)';
      notifyListeners();
      return false;
    }
    final spent = await pm.spendCoins(cost);
    if (!spent) return false;
    await _applyCatalogGrant(item);
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
    final spent = await pm.spendCoins(totalCost);
    if (!spent) return false;

    await pm.incrementPowerCount(canonicalKey, quantity);
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
