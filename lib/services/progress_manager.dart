import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anti_cheat_service.dart';
import 'energy_service.dart';
import 'game_telemetry_service.dart';

class ProgressManager extends ChangeNotifier {
  static final ProgressManager _instance = ProgressManager._internal();
  factory ProgressManager() => _instance;
  static ProgressManager get instance => _instance;
  ProgressManager._internal();

  /// Yükleme tamamlandı mı ([ensureLoaded] kapısı).
  bool _loaded = false;

  /// Devam eden `load()` çağrısı (uçuş koruması): eşzamanlı
  /// `load()`/`ensureLoaded()` çağrıları aynı yüklemeyi paylaşır.
  Future<void>? _loadFuture;

  static const int defaultCoins = 1240;
  static const int maxCampaignLevels = 80;
  static const int maxSingleCoinGrant = 100000;
  static const int maxTotalCoins = 99999999;

  /// Tek güçlendirici stok üst sınırı (tüketim/iade çekirdeği [O1] ile
  /// kayıt yükleme kelepçesi aynı sınırı kullanır).
  static const int _maxPowerStock = 99999;
  /// Tüm modlar için mutlak skor üst sınırı (rules `score 0..500000` ile
  /// uyumlu). Mod bazlı tavanlar [modeScoreCeilings]'tedir; bilinmeyen
  /// modda bu değer varsayılan tavan olarak kullanılır.
  static const int maxValidModeScore = 500000;

  /// Mod bazlı skor tavanları — TEK KAYNAK (S1#35).
  ///
  /// [recordModeScore] (yerel depo) ile LeaderboardService.submitScore
  /// (liderlik deposu) AYNI tavanları kullanır: liderlik tarafı bu tabloya
  /// delege eder, kendi kopyasını tutmaz. Tersine bağlama (bu dosyanın
  /// liderlik servisini import etmesi) döngüsel import yaratacağı için
  /// tek kaynak burasıdır; liderlik servisi zaten bu dosyayı import eder.
  ///
  /// Tavanlar "ulaşılabilir en yüksek skor" değil, hileye karşı makullük
  /// sınırıdır. Değişmezler (firestore.rules + CloudSyncService ile
  /// uyumlu — tavan değiştirirken bu yerler birlikte gözden geçirilir):
  /// * Her tavan ≤ 500.000 (rules `score 0..500000` ve
  ///   CloudSyncService.maxValidModeScore). Üstünde bir skor buluta
  ///   yazılamaz; tavan bu sınırın üstüne çıkarılamaz.
  /// * Suika tavanı 250.000'dir ve skor formülü tarafına aittir; burada
  ///   değiştirilmez (formül ajanı ile eşgüdüm gerekir).
  /// * Tavanlar toplamı 2.500.000 ≤ 5.500.000 (rules `total11ModesScore`
  ///   sınırı); her modda tavan skor bile toplam sınırını aşamaz.
  /// * Bilinmeyen modda [maxValidModeScore] (500.000) uygulanır;
  ///   boş mod [isScoreValidForMode] tarafından reddedilir.
  static const Map<String, int> modeScoreCeilings = {
    'suika': 250000,
    'grid_2048': 500000,
    'balloon_pop': 150000,
    'match3': 300000,
    'connect_pop': 250000,
    'stack_drop': 150000,
    'osmantus': 200000,
    'scream_roach': 150000,
    'makarayiz': 200000,
    'terlik_tap': 150000,
    'yuva_defense': 200000,
  };
  static const String _integrityPrefKey = 'lululu_state_integrity_sig';
  static const String _integritySalt = 'LululuVaultSig_2026_v4';

  /// AntiCheat HMAC durum mührü anahtarı (12C1). Mevcut FNV imzasının
  /// YANINDA tutulur, yerine geçmez: eski imza yerinde kalır, eski
  /// kurulumlar etkilenmez. Mühür yalnız bu sınıfın sahip olduğu
  /// alanları kapsar (bkz. [_antiCheatStatePayload]).
  static const String _antiCheatSigPrefKey = 'lululu_state_anticheat_sig_v1';

  /// [load] tarafından okunan yerel ilerleme anahtarları — "İlerlemeyi
  /// Sıfırla" (SettingsScreen.resetAll) ile aynı küme; hesap silme
  /// temizliği ([clearLocalData]) de bu kümeyi kaldırır. Ses/titreşim
  /// ayar anahtarları (`lululu_sfx_enabled` vb.) bilinçli olarak
  /// dışarıda bırakılır — sıfırlama ayarları değiştirmez.
  static const List<String> _localProgressKeys = <String>[
    'lululu_unlocked_level',
    'lululu_coins',
    'LululuCoinBalance',
    'lululu_spray',
    'lululu_raid',
    'lululu_slipper',
    'lululu_terlik',
    'lululu_aydinlat',
    'lululu_f16',
    'lululu_shop_chest_day',
    'lululu_limited_drop_day',
    'lululu_royal_cape',
    'lululu_owned_cosmetics',
    'lululu_unlocked_tiers',
    'lululu_mode_high_scores',
    'lululu_best_combo',
    'lululu_daily_tasks_day',
    'lululu_daily_tasks_progress',
    'lululu_daily_tasks_claimed',
    'lululu_daily_streak',
    'lululu_last_streak_claim_day',
    'lululu_extra_powers',
    'lululu_earned_power_keys',
    'lululu_level_stars',
    'lululu_level_scores',
    'lululu_power_seed_v1',
    'lululu_daily_free_energy_day',
    'lululu_daily_free_energy_claims',
    'lululu_last_free_energy_epoch_ms',
    'lululu_state_integrity_sig',
    // Y6/LWW (Faz 4, 8E) alan damgaları — bkz. aşağıdaki damga bölümü.
    'lululu_ts_coins',
    'lululu_ts_energy',
    'lululu_ts_level',
    'lululu_ts_f16',
    'lululu_ts_raid',
    'lululu_ts_terlik',
    'lululu_ts_streak',
    'lululu_ts_tiers',
    'lululu_ts_display_name',
    'lululu_ts_extra_powers',
    // Dalga 3: günlük ödül / görev / ücretsiz enerji damgaları +
    // buluttan bilinen hak günleri.
    'lululu_ts_last_streak_claim_day',
    'lululu_ts_daily_tasks',
    'lululu_ts_daily_free_energy',
    'lululu_cloud_last_streak_claim_day',
    'lululu_cloud_daily_free_energy_day',
    'lululu_cloud_daily_free_energy_claims',
    'lululu_lww_stamps_seeded_v1',
  ];

  /// Y6/LWW göç bayrağı: damgalar ilk yüklemede bir kez tohumlandı mı.
  static const String _lwwSeedFlagKey = 'lululu_lww_stamps_seeded_v1';

  /// 11 oyun modundaki 33 güçlendiricinin tam anahtar listesi (11 × 3 = 33).
  static const List<String> all33PowerKeys = [
    // 1. Suika Arena
    'raid',
    'terlik',
    'f16',
    // 2. 2048 Grid
    'undo',
    'shuffle',
    'pair',
    // 3. Balon Patlat
    'triple',
    'bombb',
    'slowb',
    // 4. Match 3
    'hammer',
    'bomb3',
    'hunter',
    // 5. Bağla Patlat
    'chain',
    'bolt',
    'magnet',
    // 6. Stack Drop
    'freeze',
    'widen',
    'slows',
    // 7. Terlik Tap
    'dblslip',
    'goldslip',
    'spraybug',
    // 8. Yuva Savunması
    'yuva_dblslip',
    'yuva_goldslip',
    'nest_shield',
    // 9. Osmantuş
    'dik',
    'ring',
    'mic',
    // 10. Çığlık Böcek
    'jump',
    'shield',
    'nitro',
    // 11. Makarayız
    'beat',
    'auto',
    'x2',
  ];

  static const List<String> all11ModeIds = [
    'suika',
    'grid_2048',
    'balloon_pop',
    'match3',
    'connect_pop',
    'stack_drop',
    'osmantus',
    'scream_roach',
    'makarayiz',
    'terlik_tap',
    'yuva_defense',
  ];

  /// Y6/LWW (Faz 4, 8E) — alan-başına zaman-damgalı son-yazan-kazanır
  /// damgaları (istemci-ms, UTC epoch). Damga, alanın YEREL olarak son
  /// değiştiği andır; flush anı değil (yoksa her flush damgayı tazeler
  /// ve LWW anlamsızlaşır). Damgasız alan 0 sayılır (eski istemci /
  /// göç öncesi veri); ilk yüklemede mevcut değerler bir kez "şimdi"
  /// ile damgalanır (göçte yerel öncelik — bkz. [_seedFieldStamps]).
  ///
  /// Damgalar, değeri gerçekten değişen alan için [touchChangedFieldStamps]
  /// ile ilerletilir (kalıcı kayıt yolları [_persistEconomy],
  /// [_persistCoinsOnly], [persistBoosters] içinde çağrılır) ve
  /// [persistFieldStamps] ile prefs'e yazılır. [totalStars],
  /// [total11ModesScore] ve en iyi skor türev alanlardır — LWW'ye
  /// girmezler, damgaları yoktur (tasarım A10 §3.2.4).
  int coinsUpdatedAtMs = 0;
  int energyUpdatedAtMs = 0;
  int unlockedLevelUpdatedAtMs = 0;
  int f16UpdatedAtMs = 0;
  int raidUpdatedAtMs = 0;
  int terlikUpdatedAtMs = 0;
  int streakUpdatedAtMs = 0;
  int unlockedTiersUpdatedAtMs = 0;
  int displayNameUpdatedAtMs = 0;

  /// Dalga 3: günlük ödül / görev / ücretsiz enerji LWW damgaları
  /// (istemci-ms, UTC epoch). Gün anahtarı (`yyyy-M-d`) kendisi
  /// sürüm taşır — birleştirme kararı günü karşılaştırarak verilir
  /// (bkz. [CloudSyncService]); damga, Dalga 2 desenindeki gibi
  /// taşınır, ön-denetimden geçer ve kural allowlist'indedir.
  int lastStreakClaimDayUpdatedAtMs = 0;
  int dailyTasksUpdatedAtMs = 0;
  int dailyFreeEnergyUpdatedAtMs = 0;

  /// Güç anahtarı başına LWW damgası (`extraPowers` ile aynı anahtarlar).
  /// Anahtar başına LWW: eksik anahtar "değişim yok" sayılır; silme
  /// (tombstone) Faz 4 kapsamında eklenmez (tasarım A10 §3.2.4).
  final Map<String, int> extraPowersUpdatedAtMs = <String, int>{};

  /// Son kalıcı kayıtta görülen değerlerin anlık görüntüsü — damga
  /// farkı buradan okunur (değeri değişen alan damgalanır).
  int _snapCoins = defaultCoins;
  int _snapEnergy = 0;
  int _snapLevel = 1;
  int _snapF16 = 0;
  int _snapRaid = 0;
  int _snapTerlik = 0;
  int _snapStreak = 1;
  // Dalga 3: günlük alanların fark anlık görüntüsü.
  String _snapLastStreakClaimDay = '';
  String _snapDailyTasksDay = '';
  Map<String, int> _snapDailyTaskProgress = <String, int>{
    'play': 0,
    'merge': 0,
    'video': 0,
    'combo': 0,
  };
  Set<String> _snapClaimedDailyTasks = <String>{};
  String _snapLastDailyFreeEnergyDay = '';
  int _snapDailyFreeEnergyClaimsToday = 0;
  Set<int> _snapTiers = <int>{};
  Map<String, int> _snapExtraPowers = <String, int>{};

  /// Yükleme sürerken damga ilerletme kapalıdır ([load] içindeki
  /// atamalar değişim sayılmaz; göç tohumlaması bu kapının dışındadır).
  bool _loading = false;

  /// Enerji damgası dinleyicisi bağlandı mı (tek kez bağlanır).
  bool _energyListenerAttached = false;

  int unlockedLevel = 1;
  int _coins = defaultCoins;

  int get coins => _coins;
  set coins(int value) {
    _coins = value.clamp(0, maxTotalCoins);
    coinsNotifier.value = _coins;
    _scheduleCoinPersist();
  }

  final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(defaultCoins);

  /// `coins` setter'ının ertelenmiş kalıcı kaydı zamanlandı mı (S1#36).
  bool _coinPersistScheduled = false;

  /// Ana güçlendirici stokları (Slipper / Anne Terliği, Spray / Raid, Aydınlat / F16).
  int sprayCount = 3;
  int slipperCount = 5;
  int aydinlatCount = 2;

  /// İsimlendirilmiş güçlendirici alias'ları (`f16Count`, `raidCount`, `terlikCount`).
  int get f16Count => aydinlatCount;
  set f16Count(int value) {
    aydinlatCount = value < 0 ? 0 : value;
  }

  int get raidCount => sprayCount;
  set raidCount(int value) {
    sprayCount = value < 0 ? 0 : value;
  }

  int get terlikCount => slipperCount;
  set terlikCount(int value) {
    slipperCount = value < 0 ? 0 : value;
  }

  /// Kozmetik sahipliği (örn. Kraliyet Pelerini).
  bool hasRoyalCape = false;
  final Set<String> ownedCosmetics = <String>{};

  /// Açılan böcek tier'ları (1..8 ana evrim + üst tier'lar).
  final Set<int> unlockedTiers = <int>{1, 2, 3, 4, 5, 6, 7, 8};

  /// 11 oyun modunun yerel en yüksek skorları.
  final Map<String, int> modeHighScores = <String, int>{};

  /// Tüm modlardaki tüm zamanların en yüksek kombosu (Dalga 15,
  /// bulgu 12): TEK KAYNAK. Profil ("BEST COMBO") ve oyun sonu
  /// ekranı bu değeri okur. Eskiden profil, günlük görev sayacı
  /// (`dailyTaskProgress['combo']` — her gün sıfırlanır, kombo < 2
  /// ise hiç yazılmaz) okuyordu; bu yüzden profil x0 gösterirken
  /// oyun sonu x1 gösteriyordu. Kalıcı anahtar
  /// `lululu_best_combo`; yalnız artışta yazılır, asla sıfırlanmaz
  /// (sıfırlama yalnız [clearLocalData] ile olur).
  static const String _bestComboPrefKey = 'lululu_best_combo';
  int bestCombo = 0;

  /// Günlük görev tamamlama eşikleri — `TasksScreen` aynası (PM-detailed).
  ///
  /// Değerler `TasksScreen._TaskItem.max` ile AYNI (oyna 3, birleştir
  /// 5, video 1, kombo 4); ekonomi değişimi yok, eşik aynen kopyalandı.
  /// [recordTaskProgressDetailed] tamamlanma hesabını buradan okur;
  /// görev ekranı kendi tanımlarını kullanmaya devam eder.
  static const Map<String, int> dailyTaskTargets = <String, int>{
    'play': 3,
    'merge': 5,
    'video': 1,
    'combo': 4,
  };

  /// Günlük görev ilerlemeleri ve ödül alım durumları.
  final Map<String, int> dailyTaskProgress = <String, int>{
    'play': 0,
    'merge': 0,
    'video': 0,
    'combo': 0,
  };
  final Set<String> claimedDailyTasks = <String>{};
  String dailyTasksDay = '';

  /// Günlük hediye kutusu serisi (`streak`).
  int streak = 1;
  String lastStreakClaimDay = '';

  /// Dalga 3: buluttan son görülen hak günleri — başka cihazda alınan
  /// ödül, bu cihaz pull yapana kadar yerel alanda görünmez; claim
  /// kapıları bu değeri de esas alır (bkz.
  /// [effectiveLastStreakClaimDay], [effectiveFreeEnergyClaimsToday]).
  /// Yalnız CloudSync pull yazar; [clearLocalData] siler.
  String cloudLastStreakClaimDay = '';
  String cloudDailyFreeEnergyDay = '';
  int cloudDailyFreeEnergyClaims = 0;

  int get dailyStreak => streak;

  /// Ses ve titreşim ayarları.
  bool sfxEnabled = true;
  bool vibrationEnabled = true;

  final ValueNotifier<bool> sfxNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> vibrationNotifier = ValueNotifier<bool>(true);

  /// Moda özel güçlendirici stokları (HTML POWERS id'leri).
  final Map<String, int> extraPowers = {};

  /// W13-D — kazanılan/kullanılan güç türlerinin kalıcı kaydı
  /// (`lululu_earned_power_keys`, 33'lük katalog anahtarları).
  /// Tohum stokları bu kümeye GİRMEZ: `eco_all_33_boosters` başarımı
  /// yalnız bu kümeyi sayar, yoksa her taze misafir tohumlar yüzünden
  /// başarımı ilk hub açılışında bedavaya alırdı. Tohumlar `load()`
  /// içinde doğrudan `extraPowers` haritasına yazılır ve bu metotları
  /// çağırmaz; küme yalnız gerçek kazanım/kullanım yollarında
  /// (`incrementPowerCount`, `consumePower`/`takePower`,
  /// `grantArcadeDrop`) işaretlenir.
  static const String _earnedPowersPrefKey = 'lululu_earned_power_keys';
  final Set<String> _earnedPowerKeys = <String>{};

  /// Kazanılan/kullanılan güç türleri (33'lük katalogdan) — salt okunur.
  Set<String> get earnedPowerKeys => Set.unmodifiable(_earnedPowerKeys);

  /// `eco_all_33_boosters` sayacı: kazanılan/kullanılan güç türü sayısı.
  int earnedPowerTypeCount() {
    var count = 0;
    for (final key in all33PowerKeys) {
      if (_earnedPowerKeys.contains(key)) count++;
    }
    return count;
  }

  /// 2048 ekranının ayrı stok anahtarlarını (`undo2048` …) başarım
  /// kataloğundaki karşılıklarına (`undo` …) katlar: başarım 11×3=33
  /// gücü sayar ve 2048'in üç gücü katalogda bu adlarla yer alır.
  /// Mağaza 2048 güçlerini yalnız `*2048` anahtarlarına yazar
  /// (`shop_dialog.dart` ~421-432) ve 2048 ekranı yalnız `*2048`
  /// stoklarını tüketir — katlama olmazsa düz `undo`/`shuffle`/`pair`
  /// yalnız Sezon Bileti 20. kademe paketiyle kazanılır ve başarım
  /// normal oynayışla tamamlanamaz hâle gelirdi. Stok ayrımı (O1)
  /// değişmez — yalnız kazanılan-küme eşlemesidir.
  static String _achievementPowerKey(String canonical) {
    switch (canonical) {
      case 'undo2048':
        return 'undo';
      case 'shuffle2048':
        return 'shuffle';
      case 'pair2048':
        return 'pair';
      default:
        return canonical;
    }
  }

  /// Bir güç türünü kazanılan/kullanılan kümeye ekler (yalnız 33'lük
  /// katalog üyeleri tutulur). Tohum yolları bu metodu çağırmaz.
  void _markPowerEarned(String canonical) {
    final key = _achievementPowerKey(canonical);
    if (all33PowerKeys.contains(key)) {
      _earnedPowerKeys.add(key);
    }
  }

  /// Shop daily free case — separate from hub daily challenge claim.
  String shopChestDay = '';

  /// Limited FOMO drop — one purchase per calendar day.
  String limitedDropDay = '';

  /// Ana Hub "ENERJİ AL · +5" günlük ücretsiz enerji koruması.
  String lastDailyFreeEnergyDay = '';
  int dailyFreeEnergyClaimsToday = 0;
  int lastFreeEnergyClaimEpochMs = 0;
  static const int maxDailyFreeEnergyClaimsWithAd = 3;
  static const int freeEnergyCooldownMs = 30000;

  /// Durum bütünlük imzası (hile / tamper koruması).
  String _stateIntegritySig = '';
  String get stateIntegritySig => _stateIntegritySig;

  final Map<int, int> _levelStars = {};
  final Map<int, int> _levelHighScores = {};

  /// Enerji servisi köprüleri.
  int get energy => EnergyService.instance.energy;
  set energy(int value) => EnergyService.instance.energy = value;
  ValueNotifier<int> get energyNotifier => EnergyService.instance.energyNotifier;

  /// Enerjiyi tamamen doldurur ve dinleyicileri bilgilendirir.
  Future<void> refillFullEnergy({int? target}) async {
    await EnergyService.instance.refillFull(target: target);
    notifyListeners();
  }

  int getStarCount(int levelId) => _levelStars[levelId] ?? 0;
  int getHighScore(int levelId) => _levelHighScores[levelId] ?? 0;

  int get totalStars {
    return _levelStars.values.fold(0, (sum, val) => sum + val);
  }

  /// Soft vault estimate for shop header (boosters weighted).
  int get inventoryValue =>
      coins + slipperCount * 50 + sprayCount * 40 + aydinlatCount * 150;

  int get boosterStock => slipperCount + sprayCount + aydinlatCount;

  bool get canClaimShopChest => shopChestDay != _todayKey();

  bool get canBuyLimitedDrop => limitedDropDay != _todayKey();

  bool get canClaimDailyGiftBox =>
      effectiveLastStreakClaimDay != _todayKey();

  /// Dalga 3: hediye kutusu için esas alınan hak günü — yerel ve
  /// buluttan bilinen günlerin yenisi. Başka cihazda bugün alındıysa
  /// (pull'da görüldü) yerelde tekrar verilmez.
  String get effectiveLastStreakClaimDay =>
      latestDayKey(lastStreakClaimDay, cloudLastStreakClaimDay);

  /// Dalga 3: bugün için esas alınan ücretsiz enerji hak sayısı —
  /// yerel ve buluttan bilinen bugün sayımlarının büyüğü.
  int get effectiveFreeEnergyClaimsToday {
    final today = _todayKey();
    var claims = 0;
    if (lastDailyFreeEnergyDay == today) {
      claims = max(claims, dailyFreeEnergyClaimsToday);
    }
    if (cloudDailyFreeEnergyDay == today) {
      claims = max(claims, cloudDailyFreeEnergyClaims);
    }
    return claims;
  }

  /// Ana Hub'daki "ENERJİ AL · +5" butonu için günlük ücretsiz hak kontrolü.
  bool get canClaimDailyFreeEnergy {
    final today = _todayKey();
    return lastDailyFreeEnergyDay != today &&
        cloudDailyFreeEnergyDay != today;
  }

  /// Reklam izleyerek ek ücretsiz enerji alınıp alınamayacağını kontrol eder (cooldown + günlük limit).
  bool get canClaimAdFreeEnergy {
    final claims = effectiveFreeEnergyClaimsToday;
    if (claims >= maxDailyFreeEnergyClaimsWithAd) return false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return (nowMs - lastFreeEnergyClaimEpochMs) >= freeEnergyCooldownMs;
  }

  /// Ana Hub "ENERJİ AL · +5" butonuna art arda basılıp sınırsız enerji alınmasını engeller.
  /// Günde 1 kez ücretsiz (veya `fromRewardedAd: true` ile cooldown + günlük limit dahilinde) enerji verir.
  Future<bool> claimDailyFreeEnergy({
    int amount = 5,
    bool fromRewardedAd = false,
  }) async {
    final today = _todayKey();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Dalga 3: başka cihazda bugün alınan haklar yerelde sıfırlanmaz —
    // bugün sayımı buluttan bilinen değerden başlar.
    if (lastDailyFreeEnergyDay != today) {
      dailyFreeEnergyClaimsToday = effectiveFreeEnergyClaimsToday;
    }

    if (!fromRewardedAd) {
      if (!canClaimDailyFreeEnergy) return false;
    } else {
      if (!canClaimAdFreeEnergy) return false;
    }

    final safeAmount = amount.clamp(1, EnergyService.maxEnergy);
    // PM-claim: kalıcı yazım başarısız olursa ödeme geri alınır
    // (bkz. _ClaimSnapshot) — kısmi ödeme ve UI'ya fırlatma yok.
    final snapshot = _ClaimSnapshot.capture(this);
    lastDailyFreeEnergyDay = today;
    dailyFreeEnergyClaimsToday += 1;
    lastFreeEnergyClaimEpochMs = nowMs;

    EnergyService.instance.addEnergy(safeAmount);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'lululu_daily_free_energy_day',
        lastDailyFreeEnergyDay,
      );
      await prefs.setInt(
        'lululu_daily_free_energy_claims',
        dailyFreeEnergyClaimsToday,
      );
      await prefs.setInt(
        'lululu_last_free_energy_epoch_ms',
        lastFreeEnergyClaimEpochMs,
      );
      await _persistEconomy();
    } catch (e) {
      snapshot.restore(this);
      notifyListeners();
      debugPrint(
        'ProgressManager: claimDailyFreeEnergy kalici kayit basarisiz; '
        'odeme geri alindi ($e).',
      );
      return false;
    }
    notifyListeners();
    return true;
  }

  bool isLevelUnlocked(int levelId) =>
      levelId >= 1 && levelId <= unlockedLevel && levelId <= maxCampaignLevels;

  bool isTierUnlocked(int tier) => unlockedTiers.contains(tier);

  int get maxUnlockedTier {
    if (unlockedTiers.isEmpty) return 1;
    return unlockedTiers.reduce((a, b) => a > b ? a : b);
  }

  static String normalizeModeId(String modeId) {
    switch (modeId.trim().toLowerCase()) {
      case 'grid2048':
      case '2048':
      case 'grid_2048':
        return 'grid_2048';
      case 'balloon':
      case 'balloon_pop':
        return 'balloon_pop';
      case 'connect':
      case 'connect_pop':
        return 'connect_pop';
      case 'stack':
      case 'stack_drop':
        return 'stack_drop';
      case 'scream':
      case 'scream_roach':
        return 'scream_roach';
      case 'makara':
        return 'makarayiz';
      case 'terlik':
      case 'terlik_tap':
        return 'terlik_tap';
      case 'yuva':
      case 'yuva_defense':
        return 'yuva_defense';
      default:
        return modeId.trim().toLowerCase();
    }
  }

  /// Verilen mod için geçerli üst skor sınırını döner (her zaman ≤ 500.000,
  /// rules skor sınırıyla uyumlu). Bilinmeyen modda [maxValidModeScore]
  /// varsayılan tavan olarak kullanılır.
  static int ceilingForMode(String modeId) {
    final canonical = normalizeModeId(modeId);
    return modeScoreCeilings[canonical] ?? maxValidModeScore;
  }

  /// Skorun pozitif ve modun anti-cheat tavanı içinde olup olmadığını doğrular.
  /// Boş mod reddedilir; bilinmeyen modda varsayılan tavan (500.000) uygulanır.
  static bool isScoreValidForMode(String modeId, int score) {
    if (score <= 0) return false;
    final canonical = normalizeModeId(modeId);
    if (canonical.isEmpty) return false;
    return score <= ceilingForMode(canonical);
  }

  int getModeHighScore(String modeId) {
    final key = normalizeModeId(modeId);
    return modeHighScores[key] ?? 0;
  }

  /// Alias for [getModeHighScore] used by ModesScreen.
  int getModeBestScore(String modeId) => getModeHighScore(modeId);

  /// Alias for [recordModeScore].
  Future<bool> setModeBestScore(String modeId, int score) =>
      recordModeScore(modeId, score);

  int get total11ModesScore {
    var sum = 0;
    for (final mode in all11ModeIds) {
      sum += modeHighScores[mode] ?? 0;
    }
    return sum;
  }

  /// Bir seviye için gereken XP (12A: şişirme değil, seviye hedefi).
  static const int xpTargetPerLevel = 2000;

  /// Gerçek XP (12A): kalıcı bir XP alanı yoktur; XP gerçek ilerlemeden
  /// türetilir — TABAN YOK, 0 ilerlemede 0 XP. Bileşenler: yıldız başına
  /// 25, günlük 'play' başına 40, toplam skorun 50'ye bölümünün 760
  /// modülü (eski top_bar formülünün 1240 tabansız hâli).
  int get xp =>
      totalStars * 25 +
      (dailyTaskProgress['play'] ?? 0) * 40 +
      (total11ModesScore ~/ 50) % 760;

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Dalga 3: gün anahtarı (`yyyy-M-d`, sıfır dolgusuz da olabilir)
  /// ayrıştırır; bozuk anahtar `null` döner.
  static DateTime? tryParseDayKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (y < 2000 || y > 2100 || m < 1 || m > 12 || d < 1 || d > 31) {
      return null;
    }
    final parsed = DateTime(y, m, d);
    if (parsed.year != y || parsed.month != m || parsed.day != d) {
      return null;
    }
    return parsed;
  }

  /// Dalga 3: gün anahtarlarını kronolojik karşılaştırır (<0: `a` eski,
  /// 0: eşit, >0: `a` yeni). Sözlüksel karşılaştırma YANLIŞTIR
  /// (`2026-11-5` sözlüksel olarak `2026-11-15`'ten büyüktür) — gün
  /// karşılaştırması her zaman buradan yapılır. Bozuk anahtar en eski
  /// sayılır.
  static int compareDayKeys(String a, String b) {
    final pa = tryParseDayKey(a);
    final pb = tryParseDayKey(b);
    if (pa == null && pb == null) return 0;
    if (pa == null) return -1;
    if (pb == null) return 1;
    return pa.compareTo(pb);
  }

  /// Dalga 3: iki gün anahtarından yenisi (eşitse `a`).
  static String latestDayKey(String a, String b) =>
      compareDayKeys(a, b) >= 0 ? a : b;

  static String _yesterdayKey() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Seconds until local midnight — FOMO countdown.
  int secondsUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now).inSeconds.clamp(0, 86400);
  }

  /// Bozuk JSON kaydını kayıt bazında ayıklar (O2): üst düzey çözümleme
  /// başarısız olursa boş harita döner; tekil bozuk girdiler atlanır,
  /// sağlam girdiler yüklenir. Atılan her kayıt `debugPrint` ile
  /// bildirilir; sessizce yutulmaz.
  static Map<String, dynamic>? _decodeJsonMap(String raw, String prefKey) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      debugPrint(
        'ProgressManager: $prefKey beklenen harita biciminde degil; bos yuklendi.',
      );
      return null;
    } catch (e) {
      debugPrint(
        'ProgressManager: $prefKey JSON cozumu basarisiz ($e); bos yuklendi.',
      );
      return null;
    }
  }

  static Map<String, int> _decodeIntMap(String raw, String prefKey) {
    final decoded = _decodeJsonMap(raw, prefKey);
    if (decoded == null) return <String, int>{};
    final result = <String, int>{};
    decoded.forEach((key, value) {
      if (value is! num) {
        debugPrint(
          'ProgressManager: $prefKey girdisi atlandi ($key: sayi degil).',
        );
        return;
      }
      result[key] = value.toInt();
    });
    return result;
  }

  static Map<int, int> _decodeLevelMap(String raw, String prefKey) {
    final decoded = _decodeJsonMap(raw, prefKey);
    if (decoded == null) return <int, int>{};
    final result = <int, int>{};
    decoded.forEach((key, value) {
      final levelId = int.tryParse(key);
      if (levelId == null) {
        debugPrint(
          'ProgressManager: $prefKey girdisi atlandi (seviye anahtari sayi degil: $key).',
        );
        return;
      }
      if (value is! num) {
        debugPrint(
          'ProgressManager: $prefKey girdisi atlandi ($key: sayi degil).',
        );
        return;
      }
      result[levelId] = value.toInt();
    });
    return result;
  }

  /// Yükleme tamamlanmışsa hemen döner; yoksa [load] ile aynı
  /// paylaşımlı yüklemeyi bekler.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Kalıcı ilerlemeyi yükler. Eşzamanlı çağrılar aynı yüklemeyi
  /// paylaşır (uçuş koruması); yükleme bittikten sonra yeniden
  /// çağrılırsa prefs'ten tekrar okur (yeniden yükleme korunur).
  Future<void> load() async {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    // Yükleme yarıda kesilirse bile damga kapısı açık kalmasın.
    final future = _loadAsync().whenComplete(() {
      _loading = false;
    });
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  Future<void> _loadAsync() async {
    _loading = true;
    // Y6/LWW: enerji damgası dinleyicisi — enerji değişimleri
    // (regen, grant, tüketim) EnergyService içinden gelir ve PM kalıcı
    // kayıt yolundan geçmeyebilir; damga, enerji bildiricisini
    // dinleyerek ilerletilir (bkz. [_onEnergyChanged]).
    if (!_energyListenerAttached) {
      _energyListenerAttached = true;
      EnergyService.instance.energyNotifier.addListener(_onEnergyChanged);
    }
    final prefs = await SharedPreferences.getInstance();
    unlockedLevel =
        (prefs.getInt('lululu_unlocked_level') ?? 1).clamp(1, maxCampaignLevels);
    // Kanonik okuma önceliği (O1): kanonik anahtar önce, alias anahtar
    // yalnızca geriye dönük uyumluluk için yedek okunur.
    coins = prefs.getInt('lululu_coins') ??
        prefs.getInt('LululuCoinBalance') ??
        defaultCoins;
    sprayCount = prefs.getInt('lululu_spray') ??
        prefs.getInt('lululu_raid') ??
        3;
    slipperCount = prefs.getInt('lululu_slipper') ??
        prefs.getInt('lululu_terlik') ??
        5;
    aydinlatCount = prefs.getInt('lululu_aydinlat') ??
        prefs.getInt('lululu_f16') ??
        2;
    shopChestDay = prefs.getString('lululu_shop_chest_day') ?? '';
    limitedDropDay = prefs.getString('lululu_limited_drop_day') ?? '';
    lastDailyFreeEnergyDay =
        prefs.getString('lululu_daily_free_energy_day') ?? '';
    dailyFreeEnergyClaimsToday =
        prefs.getInt('lululu_daily_free_energy_claims') ?? 0;
    // Dalga 3: buluttan bilinen ücretsiz enerji hakları.
    cloudDailyFreeEnergyDay =
        prefs.getString('lululu_cloud_daily_free_energy_day') ?? '';
    cloudDailyFreeEnergyClaims =
        prefs.getInt('lululu_cloud_daily_free_energy_claims') ?? 0;
    lastFreeEnergyClaimEpochMs =
        prefs.getInt('lululu_last_free_energy_epoch_ms') ?? 0;
    if (lastDailyFreeEnergyDay != _todayKey()) {
      dailyFreeEnergyClaimsToday = 0;
    }
    hasRoyalCape = prefs.getBool('lululu_royal_cape') ?? false;
    final cosmeticsRaw = prefs.getStringList('lululu_owned_cosmetics');
    ownedCosmetics
      ..clear()
      ..addAll(cosmeticsRaw ?? const []);
    if (hasRoyalCape) {
      ownedCosmetics.add('royal_cape');
    }

    // Açılan böcek tier'ları (1..8)
    final tiersRaw = prefs.getStringList('lululu_unlocked_tiers');
    unlockedTiers.clear();
    if (tiersRaw != null && tiersRaw.isNotEmpty) {
      for (final t in tiersRaw) {
        final parsed = int.tryParse(t);
        if (parsed != null && parsed >= 1) {
          unlockedTiers.add(parsed);
        }
      }
    }
    if (unlockedTiers.isEmpty) {
      unlockedTiers.addAll(const [1, 2, 3, 4, 5, 6, 7, 8]);
    } else {
      unlockedTiers.add(1);
    }

    // 11 oyun modu en yüksek skorları (O2: kayıt bazlı ayrıştırma —
    // bozuk girdi atlanır, sağlam skorlar yüklenir).
    modeHighScores.clear();
    final modeScoresRaw = prefs.getString('lululu_mode_high_scores');
    if (modeScoresRaw != null && modeScoresRaw.isNotEmpty) {
      for (final entry in _decodeIntMap(
        modeScoresRaw,
        'lululu_mode_high_scores',
      ).entries) {
        modeHighScores[normalizeModeId(entry.key)] = entry.value;
      }
    }

    // Tüm zamanların en yüksek kombosu (Dalga 15, bulgu 12).
    bestCombo = (prefs.getInt(_bestComboPrefKey) ?? 0).clamp(0, 999999);

    // Günlük görev ilerlemeleri
    final today = _todayKey();
    dailyTasksDay = prefs.getString('lululu_daily_tasks_day') ?? '';
    if (dailyTasksDay != today) {
      dailyTasksDay = today;
      dailyTaskProgress['play'] = 0;
      dailyTaskProgress['merge'] = 0;
      dailyTaskProgress['video'] = 0;
      dailyTaskProgress['combo'] = 0;
      claimedDailyTasks.clear();
    } else {
      final taskProgRaw = prefs.getString('lululu_daily_tasks_progress');
      if (taskProgRaw != null && taskProgRaw.isNotEmpty) {
        // O2: kayıt bazlı ayrıştırma — bozuk girdi atlanır, sağlam
        // ilerlemeler yüklenir.
        for (final entry in _decodeIntMap(
          taskProgRaw,
          'lululu_daily_tasks_progress',
        ).entries) {
          dailyTaskProgress[entry.key] = entry.value;
        }
      }
      final claimedRaw = prefs.getStringList('lululu_daily_tasks_claimed');
      claimedDailyTasks
        ..clear()
        ..addAll(claimedRaw ?? const []);
    }

    // Günlük hediye kutusu serisi (streak)
    streak = prefs.getInt('lululu_daily_streak') ?? 1;
    lastStreakClaimDay = prefs.getString('lululu_last_streak_claim_day') ?? '';
    // Dalga 3: buluttan bilinen hediye kutusu hak günü.
    cloudLastStreakClaimDay =
        prefs.getString('lululu_cloud_last_streak_claim_day') ?? '';

    // Ses ve titreşim ayarları
    sfxEnabled = prefs.getBool('lululu_sfx_enabled') ?? true;
    vibrationEnabled = prefs.getBool('lululu_vibration_enabled') ?? true;
    sfxNotifier.value = sfxEnabled;
    vibrationNotifier.value = vibrationEnabled;

    extraPowers.clear();
    final extraRaw = prefs.getString('lululu_extra_powers');
    if (extraRaw != null && extraRaw.isNotEmpty) {
      // O1 kanonik göç + O2 kayıt bazlı ayrıştırma: eski kayıtlardaki
      // alias anahtarlar (`spray`, `Geri Al` vb.) kanonik anahtara
      // çevrilir. Tam kanonik girdiler önceliklidir (eski okuma
      // davranışı aynen korunur); yalnızca alias girdisi varsa en
      // yüksek stok korunur (kayıpsız). Değerler yazıcı sınırlarına
      // (0..99999) kelepçelenir.
      final decoded = _decodeIntMap(extraRaw, 'lululu_extra_powers');
      final pendingAliases = <String, int>{};
      for (final entry in decoded.entries) {
        final canonical = normalizePowerKey(entry.key);
        final value = entry.value.clamp(0, _maxPowerStock);
        if (entry.key == canonical) {
          extraPowers[canonical] = value;
        } else {
          final prev = pendingAliases[canonical];
          pendingAliases[canonical] = prev == null || value > prev
              ? value
              : prev;
        }
      }
      for (final entry in pendingAliases.entries) {
        extraPowers.putIfAbsent(entry.key, () => entry.value);
      }
    }

    // W13-D: kazanılan/kullanılan güç kümesini yükle. Eski kayıtlarda
    // anahtar yoksa küme boş başlar — tohum stokları ASLA buraya
    // yazılmaz (tohumlar aşağıdaki `seeds` bloğunda doğrudan
    // `extraPowers` haritasına uygulanır).
    _earnedPowerKeys.clear();
    final earnedRaw = prefs.getStringList(_earnedPowersPrefKey);
    if (earnedRaw != null) {
      for (final raw in earnedRaw) {
        final key = _achievementPowerKey(normalizePowerKey(raw));
        if (all33PowerKeys.contains(key)) {
          _earnedPowerKeys.add(key);
        }
      }
    }

    _levelStars.clear();
    final starsJson = prefs.getString('lululu_level_stars');
    if (starsJson != null) {
      // O2: kayıt bazlı ayrıştırma — bozuk anahtar/değer atlanır.
      _levelStars.addAll(_decodeLevelMap(starsJson, 'lululu_level_stars'));
    }

    _levelHighScores.clear();
    final scoresJson = prefs.getString('lululu_level_scores');
    if (scoresJson != null) {
      // O2: kayıt bazlı ayrıştırma — bozuk anahtar/değer atlanır.
      _levelHighScores.addAll(
        _decodeLevelMap(scoresJson, 'lululu_level_scores'),
      );
    }

    // 12T: tohumlar HER yüklemede eksik anahtarlara uygulanır
    // (`putIfAbsent` — mevcut stok asla ezilmez). Eski kod tohumlamayı
    // `lululu_power_seed_v1` bayrağına bağlıyordu: bayrak bir kez
    // konduktan sonra tohum haritasına eklenen yeni güç anahtarları
    // (jump/shield/nitro) mevcut kurulumlara HİÇ ulaşmıyor, stok 0
    // kalıyor ve bonus düğmeleri ölü görünüyordu. Bayrak yalnızca
    // geriye dönük uyumluluk için korunur.
    const seeds = <String, int>{
      'raid': 3,
      'terlik': 5,
      'f16': 2,
      'undo': 3,
      'shuffle': 2,
      'pair': 1,
      // B3: 2048 ekranı `*2048` anahtarlarını okur; tohumlar
      // `putIfAbsent` ile verilir, mevcut stoklar ezilmez.
      'undo2048': 3,
      'shuffle2048': 2,
      'pair2048': 1,
      'triple': 3,
      'bombb': 2,
      'slowb': 1,
      'hammer': 2,
      'bomb3': 2,
      'hunter': 1,
      'chain': 3,
      'bolt': 1,
      'magnet': 1,
      'freeze': 2,
      'widen': 3,
      'slows': 1,
      'dblslip': 3,
      'goldslip': 2,
      'spraybug': 1,
      'yuva_dblslip': 3,
      'yuva_goldslip': 2,
      'nest_shield': 1,
      'dik': 1,
      'ring': 2,
      'mic': 3,
      'jump': 3,
      'shield': 2,
      'nitro': 1,
      'beat': 2,
      'auto': 2,
      'x2': 1,
    };
    var seeded = false;
    for (final entry in seeds.entries) {
      if (!extraPowers.containsKey(entry.key)) {
        extraPowers[entry.key] = entry.value;
        seeded = true;
      }
    }
    if (!(prefs.getBool('lululu_power_seed_v1') ?? false)) {
      await prefs.setBool('lululu_power_seed_v1', true);
      seeded = true;
    }
    if (seeded) await _persistEconomy();

    _syncPrimaryPowersToExtra();
    // Y6/LWW: alan damgalarını prefs'ten yükle; ilk yüklemede
    // (göç) mevcut değerleri "şimdi" ile damgala.
    await _loadFieldStamps(prefs);
    // Damga farkı anlık görüntüsünü yüklenen duruma eşitle: yükleme
    // sırasındaki atamalar değişim sayılmaz.
    syncPersistedSnapshot();
    _stateIntegritySig =
        prefs.getString(_integrityPrefKey) ?? _computeStateIntegritySig();
    if (!verifyStateIntegrity()) {
      // Tamper / aşırı hileli değer tespit edilirse güvenli sınırlara çek.
      coins = coins.clamp(0, maxTotalCoins);
      unlockedLevel = unlockedLevel.clamp(1, maxCampaignLevels);
      _stateIntegritySig = _computeStateIntegritySig();
      await prefs.setString(_integrityPrefKey, _stateIntegritySig);
    }
    // 12C1: AntiCheat HMAC mührünü yüklenen duruma karşı doğrula
    // (yoksa benimse, uyuşmazsa telemetriye yaz + yeniden mühürle).
    await _verifyAndResealAntiCheatState(prefs);

    _loaded = true;
    _loading = false;
    notifyListeners();
  }

  /// Hesap silme için yerel ilerlemenin tamamını temizler (hesap-silme,
  /// yerel-temizlik): [_localProgressKeys] kaldırılır, ardından [load]
  /// varsayılanlarla yeniden yüklenir (güç tohumları dahil). Ses/
  /// titreşim ayarlarına dokunulmaz.
  Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _localProgressKeys) {
      await prefs.remove(key);
    }
    await load();
  }

  /// 33 oyun modu güçlendiricisinin anahtarlarını ve Türkçe mağaza adlarını kanonikleştirir.
  ///
  /// Kanonik anahtar seti (O1): [all33PowerKeys] + 2048 ekranının ayrı
  /// stokları (`undo2048`/`shuffle2048`/`pair2048`). Alias'lar
  /// (`spray`, `slipper`, `aydinlat`, Türkçe adlar) YALNIZCA okuma
  /// uyumluluğu için çözülür; yazım yolları kanonik anahtar kullanır.
  /// `*2048` anahtarları `undo`/`shuffle`/`pair` ile BİRLEŞTİRİLMEZ:
  /// 2048 ekranı ayrı stok okur, mağaza iki stoku ayrı artırır;
  /// birleştirmek çift dağıtıma yol açar.
  static String normalizePowerKey(String rawKey) {
    final trimmed = rawKey
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('!', '');
    switch (trimmed) {
      case 'raid':
      case 'spray':
      case 'raid spreyi':
      case 'raid_spreyi':
        return 'raid';
      case 'terlik':
      case 'slipper':
      case 'anne terligi':
      case 'terlik sarsintisi':
      case 'terlik_sarsintisi':
        return 'terlik';
      case 'f16':
      case 'aydinlat':
      case 'aydinlat hele':
      case 'aydinlat_hele':
        return 'f16';
      case 'undo':
      case 'geri al':
      case 'geri_al':
        return 'undo';
      case 'undo2048':
      case 'undo_2048':
        return 'undo2048';
      case 'shuffle':
      case 'karistir':
        return 'shuffle';
      case 'shuffle2048':
      case 'shuffle_2048':
        return 'shuffle2048';
      case 'pair':
      case 'ciftlestir':
        return 'pair';
      case 'pair2048':
      case 'pair_2048':
        return 'pair2048';
      case 'triple':
      case 'uclu ok':
      case 'uclu_ok':
        return 'triple';
      case 'bombb':
      case 'bomba balon':
      case 'bomba_balon':
        return 'bombb';
      case 'slowb':
      case 'balon yavaslat':
      case 'yavaslat_balon':
        return 'slowb';
      case 'hammer':
      case 'cekic':
        return 'hammer';
      case 'bomb3':
      case 'bomba':
        return 'bomb3';
      case 'hunter':
      case 'renk avcisi':
      case 'renk_avcisi':
        return 'hunter';
      case 'chain':
      case 'zincir uzatici':
      case 'zincir_uzatici':
        return 'chain';
      case 'bolt':
      case 'yildirim':
        return 'bolt';
      case 'magnet':
      case 'miknatis':
        return 'magnet';
      case 'freeze':
      case 'dondur':
        return 'freeze';
      case 'widen':
      case 'genislet':
        return 'widen';
      case 'slows':
      case 'stack yavaslat':
      case 'yavaslat':
      case 'yavaslat_stack':
        return 'slows';
      case 'dblslip':
      case 'cift terlik':
      case 'cift_terlik':
        return 'dblslip';
      case 'goldslip':
      case 'altin terlik':
      case 'altin_terlik':
        return 'goldslip';
      case 'spraybug':
      case 'bocek ilaci':
      case 'bocek_ilaci':
        return 'spraybug';
      case 'yuva_dblslip':
      case 'yuva cift terlik':
      case 'yuva_cift_terlik':
      case 'yuva dblslip':
        return 'yuva_dblslip';
      case 'yuva_goldslip':
      case 'yuva altin terlik':
      case 'yuva_altin_terlik':
      case 'yuva goldslip':
        return 'yuva_goldslip';
      case 'nest_shield':
      case 'yuva kalkani':
      case 'yuva_kalkani':
      case 'yuva kalkan':
      case 'yuva_kalkan':
      case 'yuvakalkan':
      case 'nest shield':
      case 'nestshield':
        return 'nest_shield';
      case 'dik':
      case 'dikkis boost':
      case 'dikkis_boost':
        return 'dik';
      case 'ring':
      case 'genis halka':
      case 'genis_halka':
        return 'ring';
      case 'mic':
      case 'mikrofon':
        return 'mic';
      case 'jump':
      case 'ziplama botu':
      case 'ziplama_botu':
        return 'jump';
      case 'shield':
      case 'kalkan':
        return 'shield';
      case 'nitro':
        return 'nitro';
      case 'beat':
      case 'beat dondur':
      case 'beat_dondur':
        return 'beat';
      case 'auto':
      case 'oto makara':
      case 'oto_makara':
        return 'auto';
      case 'x2':
      case 'puan carpani':
      case 'puan_carpani':
        return 'x2';
      default:
        return rawKey.trim().toLowerCase();
    }
  }

  void _syncPrimaryPowersToExtra() {
    // Kanonik göç (O1): haritaya YALNIZCA kanonik anahtarlar yazılır.
    // Eski kayıtlardan gelen alias girdileri (`spray`/`slipper`/
    // `aydinlat`) kaldırılır — okuma her zaman [normalizePowerKey]
    // üzerinden kanonik anahtara çözüldüğü için stok kaybı olmaz.
    extraPowers['raid'] = sprayCount;
    extraPowers['terlik'] = slipperCount;
    extraPowers['f16'] = aydinlatCount;
    extraPowers.remove('spray');
    extraPowers.remove('slipper');
    extraPowers.remove('aydinlat');
    extraPowers.putIfAbsent('yuva_dblslip', () => extraPowers['dblslip'] ?? 3);
    extraPowers.putIfAbsent(
      'yuva_goldslip',
      () => extraPowers['goldslip'] ?? 2,
    );
    extraPowers.putIfAbsent('nest_shield', () => extraPowers['shield'] ?? 1);
  }

  /// Güç stokları için TEK çekirdek (O1): üç tüketim yolu
  /// ([consumePower]/[takePower]/[refundPower]) ile [setPowerCount] /
  /// [incrementPowerCount] aynı stok aritmetiğini paylaşır. Bu
  /// yardımcılar YALNIZCA bellek içi stoku değiştirir; kalıcı kayıt ve
  /// bildirim her metodun kendi sözleşmesine aittir (senkron yollar
  /// ateşle-unut yazar, async yollar beklenen kayıt yazar).
  int _stockOf(String canonical, String rawId) {
    switch (canonical) {
      case 'raid':
        return sprayCount;
      case 'terlik':
        return slipperCount;
      case 'f16':
        return aydinlatCount;
      default:
        return extraPowers[canonical] ?? extraPowers[rawId] ?? 0;
    }
  }

  /// Stoku doğrudan yazar (kanonik anahtar; negatif sıfıra çekilir).
  /// Üst kelepçe uygulanmaz — eski [setPowerCount] davranışı aynen
  /// korunur; üst sınır yalnız [incrementPowerCount]/[refundPower]
  /// yolundaki [_adjustStock] tarafından uygulanır.
  void _setStock(String canonical, int value) {
    final safe = value < 0 ? 0 : value;
    switch (canonical) {
      case 'raid':
        sprayCount = safe;
        break;
      case 'terlik':
        slipperCount = safe;
        break;
      case 'f16':
        aydinlatCount = safe;
        break;
      default:
        extraPowers[canonical] = safe;
        break;
    }
  }

  /// Stoku `delta` kadar değiştirir, 0..[_maxPowerStock] aralığına
  /// kelepçeler ve yeni değeri döner. Ham alias girdisi kalmışsa
  /// budanır (kanonik girdi tek kaynaktır).
  int _adjustStock(String canonical, String rawId, int delta) {
    final next = (_stockOf(canonical, rawId) + delta).clamp(0, _maxPowerStock);
    _setStock(canonical, next);
    if (rawId != canonical) extraPowers.remove(rawId);
    return next;
  }

  /// Stok > 0 ise 1 düşürür ve true döner; stok yoksa değiştirmeden
  /// false döner.
  bool _takeOneStock(String canonical, String rawId) {
    if (_stockOf(canonical, rawId) <= 0) return false;
    _adjustStock(canonical, rawId, -1);
    return true;
  }

  int powerCount(String id) {
    final canonical = normalizePowerKey(id);
    return _stockOf(canonical, id);
  }

  /// Moda özel güçlendirici stoğunu doğrudan ayarlar ve kaydeder.
  Future<void> setPowerCount(String id, int count) async {
    final canonical = normalizePowerKey(id);
    _setStock(canonical, count);
    if (id != canonical) extraPowers.remove(id);
    _syncPrimaryPowersToExtra();
    await _persistEconomy();
    notifyListeners();
  }

  /// 33 oyun modu güçlendiricisi için envanteri `delta` kadar artırır (veya azaltır),
  /// `extraPowers` + `f16Count`/`raidCount`/`terlikCount` değerlerini kalıcı günceller.
  Future<int> incrementPowerCount(String key, [int delta = 1]) async {
    if (delta == 0) return powerCount(key);
    final canonical = normalizePowerKey(key);
    final nextValue = _adjustStock(canonical, key, delta);
    // W13-D: pozitif artış gerçek kazanımdır (mağaza/IAP/kampanya/
    // Sezon Bileti) — tohumlar bu yoldan geçmez.
    if (delta > 0) _markPowerEarned(canonical);
    _syncPrimaryPowersToExtra();
    await _persistEconomy();
    notifyListeners();
    return nextValue;
  }

  /// Oyun içinden veya mağazadan 1 adet güçlendirici harcar (`extraPowers` + `f16Count`/`raidCount`/`terlikCount`).
  /// Kalıcı kayıt beklenir ([takePower] senkron karşılığıdır, kaydı
  /// ateşle-unut yazar; stok aritmetiği aynı çekirdektedir).
  Future<bool> consumePower(String key) async {
    final canonical = normalizePowerKey(key);
    if (!_takeOneStock(canonical, key)) return false;
    // W13-D: güç kullanımı da kazanılan sayılır (tohum stokundan
    // kullanılsa bile — oyuncu o gücü oyunda gerçekten harcamıştır).
    _markPowerEarned(canonical);
    _syncPrimaryPowersToExtra();
    await _persistEconomy();
    notifyListeners();
    return true;
  }

  /// Kasadan 1 yük harcar. Stok yoksa false. Kalıcı kayıt ateşle-unut
  /// yazılır (senkron sözleşme); stok aritmetiği [consumePower] ile
  /// aynı çekirdektedir.
  bool takePower(String id) {
    final canonical = normalizePowerKey(id);
    if (!_takeOneStock(canonical, id)) return false;
    // W13-D: bkz. [consumePower] — kullanım kazanılan sayılır.
    _markPowerEarned(canonical);
    _syncPrimaryPowersToExtra();
    notifyListeners();
    unawaited(_persistEconomy());
    return true;
  }

  /// Başarısız olan bir güçlendirici etkisinin stoğunu iade eder (S1#30):
  /// [takePower]'ın senkron tersidir — 1 yük geri verir, dinleyicileri
  /// bilgilendirir ve kalıcı kaydı ateşle-unut yazar. Stok üst sınırı
  /// [incrementPowerCount] ile aynıdır (99999).
  void refundPower(String id) {
    final canonical = normalizePowerKey(id);
    _adjustStock(canonical, id, 1);
    _syncPrimaryPowersToExtra();
    notifyListeners();
    unawaited(_persistEconomy());
  }

  /// Moda özel güçlendirici ekler.
  Future<void> addPower(String id, [int amount = 1]) async {
    if (amount <= 0) return;
    await incrementPowerCount(id, amount);
  }

  /// Böcek tier kilidini açar (1..8 ve üstü).
  Future<bool> unlockTier(int tier) async {
    if (tier < 1) return false;
    final added = unlockedTiers.add(tier);
    if (!added) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'lululu_unlocked_tiers',
      unlockedTiers.map((e) => e.toString()).toList(),
    );
    // Y6/LWW: tier değişimi damgalanır.
    touchChangedFieldStamps();
    await persistFieldStamps();
    await _persistAntiCheatSeal(prefs);
    notifyListeners();
    return true;
  }

  /// 11 oyun modundan birinin yüksek skorunu kaydeder (anti-cheat tavan kontrollü).
  ///
  /// Tavan, [modeScoreCeilings] tablosundan mod bazlı okunur — liderlik
  /// servisinin `submitScore` yolu aynı tabloyu kullandığı için iki depo
  /// ayrışamaz (S1#35).
  ///
  /// 12C1: yazımdan ÖNCE [AntiCheatService.validateGameScore] çalışır.
  /// Geçersiz skor (bilinmeyen mod, negatif, tavan üstü) sessizce
  /// reddedilir (`false` döner, kayıt yazılmaz, hata fırlatılmaz).
  /// Uzak birleştirme / göç yolu (`fromRemoteSync: true`) ARTIK AYNI
  /// kapıdan geçer (Dalga 3 ek: kapı deliği kapatıldı) — bilinmeyen mod,
  /// negatif ve mod tavanı üstü skorlar uzaktan gelse de kayda girmez.
  /// `fromRemoteSync` yalnız çağrı niyetini belirtir, denetimi atlamaz.
  Future<bool> recordModeScore(
    String modeId,
    int score, {
    bool fromRemoteSync = false,
  }) async {
    final key = normalizeModeId(modeId);
    if (key.isEmpty) return false;
    // Dalga 3 ek: kapı her iki yolda da çalışır — uzak birleştirme /
    // göç (`fromRemoteSync: true`) artık AntiCheat'i atlamaz.
    final check = AntiCheatService.instance.validateGameScore(key, score);
    if (!check.isValid) {
      debugPrint(
        '[lululu] AntiCheat: recordModeScore reddedildi '
        '(mod: ${check.mode}, neden: ${check.reason}, skor: $score)',
      );
      return false;
    }
    if (!isScoreValidForMode(key, score)) return false;
    final prev = modeHighScores[key] ?? 0;
    if (score <= prev) return false;
    modeHighScores[key] = score;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'lululu_mode_high_scores',
      jsonEncode(modeHighScores),
    );
    _stateIntegritySig = _computeStateIntegritySig();
    await prefs.setString(_integrityPrefKey, _stateIntegritySig);
    await _persistAntiCheatSeal(prefs);
    notifyListeners();
    return true;
  }

  /// Tüm zamanların en yüksek kombosunu kaydeder (Dalga 15, bulgu 12):
  /// yalnız artışta kalıcı yazılır (`lululu_best_combo`); düşük/eşit
  /// değer yazılmaz, `false` döner. Negatif değer yoksayılır.
  /// Tek yazım noktası [finishRun] settle adımıdır — 11 modun tamamı
  /// oradan geçtiği için tur kombosu tek yerden kayda girer.
  Future<bool> recordBestCombo(int combo) async {
    if (combo <= bestCombo) return false;
    if (combo < 0) return false;
    bestCombo = combo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestComboPrefKey, bestCombo);
    notifyListeners();
    return true;
  }

  /// Günlük görev ilerlemesini günceller.
  int getTaskProgress(String taskId) => dailyTaskProgress[taskId] ?? 0;

  bool isTaskClaimed(String taskId) => claimedDailyTasks.contains(taskId);

  Future<void> recordTaskProgress(
    String taskId, {
    int delta = 1,
    int? absoluteValue,
  }) async {
    // Tek hesaplama yeri _recordTaskProgressCore: dönüş (yeni
    // tamamlananlar) bu imzada yoksayılır.
    await _recordTaskProgressCore(
      taskId,
      delta: delta,
      absoluteValue: absoluteValue,
    );
  }

  /// Günlük görev ilerlemesini kaydeder ve bu çağrıyla YENİ
  /// tamamlanan görev kimliklerini döner.
  ///
  /// Sözleşme (PM-detailed, koordinatör bağlayacak):
  /// * İlerleme kaydı [recordTaskProgress] ile aynıdır (varsayılan
  ///   `delta: 1`; gün değişiminde sıfırlama + kalıcı kayıt + bildirim
  ///   aynen yapılır — tek hesaplama yeri _recordTaskProgressCore).
  /// * Dönen liste, bu çağrıdan ÖNCE tamamlanmamışken çağrıyla eşiğe
  ///   ulaşan görevleri içerir; hiçbiri tamamlanmadıysa boş listedir.
  ///   Zaten ödülü alınmış görev tekrar bildirilmez.
  /// * Tek çağrı tek görevi ilerlettiği için liste en fazla bir
  ///   kimlik içerir (`[kind]` ya da `[]`).
  /// * Eşikler [dailyTaskTargets]tandır; bilinmeyen görev kaydedilir
  ///   ama asla tamamlanmış sayılmaz (boş liste döner).
  Future<List<String>> recordTaskProgressDetailed(String kind) =>
      _recordTaskProgressCore(kind);

  /// Görev ilerleme kaydının TEK hesaplama yeri: [recordTaskProgress]
  /// ve [recordTaskProgressDetailed] buraya delege eder. Dönen liste,
  /// bu çağrıyla yeni tamamlanan görev kimlikleridir (en fazla bir
  /// kimlik; yoksa boş liste). `delta`/`absoluteValue` parametreleri
  /// [recordTaskProgress] çağrıcıları içindir (oyun ekranları mutlak
  /// kombo ve çoklu birleştirme kaydeder); ayrıntılı imza bunları
  /// taşımaz, varsayılanları kullanır.
  Future<List<String>> _recordTaskProgressCore(
    String taskId, {
    int delta = 1,
    int? absoluteValue,
  }) async {
    final today = _todayKey();
    if (dailyTasksDay != today) {
      dailyTasksDay = today;
      dailyTaskProgress.updateAll((_, _) => 0);
      claimedDailyTasks.clear();
    }
    final target = dailyTaskTargets[taskId];
    final before = dailyTaskProgress[taskId] ?? 0;
    final wasClaimed = claimedDailyTasks.contains(taskId);
    if (absoluteValue != null) {
      final current = dailyTaskProgress[taskId] ?? 0;
      if (absoluteValue > current) {
        dailyTaskProgress[taskId] = absoluteValue;
      }
    } else if (delta > 0) {
      dailyTaskProgress[taskId] = (dailyTaskProgress[taskId] ?? 0) + delta;
    }
    await _persistDailyTasks();
    notifyListeners();
    if (target == null || wasClaimed) return <String>[];
    final after = dailyTaskProgress[taskId] ?? 0;
    if (before < target && after >= target) return <String>[taskId];
    return <String>[];
  }

  Future<bool> claimDailyTaskReward(
    String taskId, {
    required int target,
    int coinReward = 0,
    int energyReward = 0,
  }) async {
    final progress = dailyTaskProgress[taskId] ?? 0;
    if (progress < target || claimedDailyTasks.contains(taskId)) {
      return false;
    }
    // PM-claim: kalıcı yazım başarısız olursa ödeme geri alınır
    // (bkz. _ClaimSnapshot) — kısmi ödeme ve UI'ya fırlatma yok.
    final snapshot = _ClaimSnapshot.capture(this);
    claimedDailyTasks.add(taskId);
    if (coinReward > 0) {
      coins += coinReward;
    }
    if (energyReward > 0) {
      EnergyService.instance.addEnergy(energyReward);
    }
    try {
      await _persistDailyTasks();
      await _persistEconomy();
    } catch (e) {
      snapshot.restore(this);
      notifyListeners();
      debugPrint(
        'ProgressManager: claimDailyTaskReward kalici kayit basarisiz; '
        'odeme geri alindi ($e).',
      );
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<void> _persistDailyTasks() async {
    // Y6/LWW: değeri değişen alanı damgala, damgaları da yaz.
    touchChangedFieldStamps();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lululu_daily_tasks_day', dailyTasksDay);
    await prefs.setString(
      'lululu_daily_tasks_progress',
      jsonEncode(dailyTaskProgress),
    );
    await prefs.setStringList(
      'lululu_daily_tasks_claimed',
      claimedDailyTasks.toList(),
    );
    if (!_loading) unawaited(_persistStamps(prefs));
  }

  /// Dalga 3: bulut birleşmesi sonrası günlük alanları + buluttan
  /// bilinen hak günleri + damgaları kalıcı olarak yazar.
  /// [CloudSyncService.applyTimestampedProfileSnapshot] birleşmiş
  /// değerleri belleğe yazdıktan sonra çağırır (doğrudan prefs yazımı
  /// yerine — günlük anahtarları tek yerdedir).
  Future<void> persistDailyCloudState() async {
    touchChangedFieldStamps();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'lululu_last_streak_claim_day',
      lastStreakClaimDay,
    );
    await prefs.setString('lululu_daily_tasks_day', dailyTasksDay);
    await prefs.setString(
      'lululu_daily_tasks_progress',
      jsonEncode(dailyTaskProgress),
    );
    await prefs.setStringList(
      'lululu_daily_tasks_claimed',
      claimedDailyTasks.toList(),
    );
    await prefs.setString(
      'lululu_daily_free_energy_day',
      lastDailyFreeEnergyDay,
    );
    await prefs.setInt(
      'lululu_daily_free_energy_claims',
      dailyFreeEnergyClaimsToday,
    );
    await prefs.setInt(
      'lululu_last_free_energy_epoch_ms',
      lastFreeEnergyClaimEpochMs,
    );
    await prefs.setString(
      'lululu_cloud_last_streak_claim_day',
      cloudLastStreakClaimDay,
    );
    await prefs.setString(
      'lululu_cloud_daily_free_energy_day',
      cloudDailyFreeEnergyDay,
    );
    await prefs.setInt(
      'lululu_cloud_daily_free_energy_claims',
      cloudDailyFreeEnergyClaims,
    );
    if (!_loading) await _persistStamps(prefs);
  }

  /// Günlük hediye kutusu ve seri (`streak`) ödülünü toplar.
  ///
  /// TEK TALEP KURALI (O22): günde en fazla bir kez ödenir; aynı gün
  /// ikinci çağrı her zaman null döner. `doubled` parametresi
  /// YOKSAYILIR ve yalnızca API uyumluluğu için korunur: ödüllü
  /// reklam SDK'sı kurulu değildir (reklam doğrulaması yapılamaz),
  /// bu yüzden doğrulanmamış iki katı ödül yolu kaldırılmıştır.
  /// Reklam SDK'sı eklendiğinde bu parametre yerine servis içinde
  /// doğrulanan bir talep akışı getirilmelidir.
  Future<({int coins, int energy, int streak})?> claimDailyGiftBox({
    bool doubled = false,
  }) async {
    // `doubled` bilinçli olarak okunmaz (bkz. yukarıdaki not).
    final today = _todayKey();
    // Dalga 3: buluttan bilinen hak günü de kapıdır — başka cihazda
    // bugün alındıysa (pull'da görüldü) yerelde tekrar verilmez.
    if (effectiveLastStreakClaimDay == today) return null;
    // PM-claim: kalıcı yazım başarısız olursa ödeme geri alınır
    // (bkz. _ClaimSnapshot) — kısmi ödeme ve UI'ya fırlatma yok.
    final snapshot = _ClaimSnapshot.capture(this);
    if (lastStreakClaimDay == _yesterdayKey()) {
      streak += 1;
    } else if (lastStreakClaimDay.isNotEmpty) {
      streak = 1;
    } else {
      streak = streak < 1 ? 1 : streak;
    }
    lastStreakClaimDay = today;
    final rewardCoins = 500 + (streak - 1) * 25;
    const rewardEnergy = 5;
    coins += rewardCoins;
    EnergyService.instance.addEnergy(rewardEnergy);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lululu_daily_streak', streak);
      await prefs.setString(
        'lululu_last_streak_claim_day',
        lastStreakClaimDay,
      );
      await _persistEconomy();
    } catch (e) {
      snapshot.restore(this);
      notifyListeners();
      debugPrint(
        'ProgressManager: claimDailyGiftBox kalici kayit basarisiz; '
        'odeme geri alindi ($e).',
      );
      return null;
    }
    notifyListeners();
    return (coins: rewardCoins, energy: rewardEnergy, streak: streak);
  }

  /// Ses ve titreşim ayarlarını günceller ve kalıcı olarak saklar.
  Future<void> setSfxEnabled(bool enabled) async {
    sfxEnabled = enabled;
    sfxNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lululu_sfx_enabled', enabled);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    vibrationEnabled = enabled;
    vibrationNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lululu_vibration_enabled', enabled);
    notifyListeners();
  }

  /// Seviye sonucunu kaydeder.
  ///
  /// Yıldız coini (yıldız başına 50) YALNIZ kazanılan YENİ yıldız başına
  /// ödenir: aynı/yüksek olmayan yıldızla tekrar oynamak coin vermez,
  /// yıldız artışı yalnız fark kadar öder (örn. 1 → 3 yıldız = +100).
  /// İlk temizleme, önceki yıldız 0 olduğu için tam yıldız kadar öder.
  /// Önceki yıldız asla ezilmez: yıldız haritası yalnız artışta yazılır.
  ///
  /// Kilit açma yıldızdan bağımsızdır (S1#23 yan etkisi): 0 yıldızlı bir
  /// zafer de (hedef-kademe / hayatta kalma hedefi skor eşiğinin altında
  /// karşılansa bile) sonraki seviyeyi açar. [victory] üç durumludur:
  /// * `true` — zafer: yıldız 0 olsa bile sınırdaki seviye açılır.
  /// * `false` — yenilgi: yıldız olsa bile seviye açılmaz (yıldız/coin/
  ///   yüksek skor kaydı aynen yapılır, yalnız kilit açılmaz).
  /// * `null` (varsayılan) — eski davranış: yıldızlı her tamamlama
  ///   sınırdaki seviyeyi açar, 0 yıldız açmaz. Parametreyi vermeyen
  ///   eski çağrıcılar aynen çalışmaya devam eder.
  Future<void> recordLevelResult({
    required int levelId,
    required int score,
    required int stars,
    bool? victory,
  }) async {
    final earnedStars = stars < 0 ? 0 : (stars > 3 ? 3 : stars);
    if (earnedStars > 0) {
      final previousStars = _levelStars[levelId] ?? 0;
      final starGain = earnedStars - previousStars;
      if (starGain > 0) {
        _levelStars[levelId] = earnedStars;
        // Coin ödülü: yalnız YENİ yıldız başına 50 coin (tekrar ödemesi yok).
        coins += starGain * 50;
      }
    }

    // Kilit açma zafer bilgisinden okunur, yıldızdan değil. victory
    // verilmezse eski kural (yıldız > 0) aynen korunur.
    final shouldUnlock = victory ?? (earnedStars > 0);
    if (shouldUnlock) {
      // 12W: yalnız sınır seviye ilerletir — ilerideki bir seviyenin
      // tek tamamlanışı seviyeyi sıçratmaz (seviye = bitirilen en
      // yüksek seviye + 1 değişmezi; harita zaten sırayla açar).
      if (levelId == unlockedLevel && unlockedLevel < maxCampaignLevels) {
        unlockedLevel = (levelId + 1).clamp(1, maxCampaignLevels);
      }
    }

    final currentScore = _levelHighScores[levelId] ?? 0;
    if (score > currentScore) {
      _levelHighScores[levelId] = score;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_unlocked_level', unlockedLevel);
    await prefs.setInt('lululu_coins', coins);
    await prefs.setInt('LululuCoinBalance', coins);

    final starsMap = _levelStars.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString('lululu_level_stars', jsonEncode(starsMap));

    final scoresMap =
        _levelHighScores.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString('lululu_level_scores', jsonEncode(scoresMap));

    // Y6/LWW: seviye/coin değişimi damgalanır (bu metot doğrudan
    // prefs yazar, [_persistEconomy] yolundan geçmez).
    touchChangedFieldStamps();
    await persistFieldStamps();

    notifyListeners();
  }

  Future<bool> buyBooster(String type, int cost) async {
    if (cost < 0 || coins < cost) return false;
    coins -= cost;
    switch (type.toLowerCase()) {
      case 'aydinlat':
      case 'f16':
        aydinlatCount++;
        break;
      case 'f16_x3':
        aydinlatCount += 3;
        break;
      case 'slipper':
      case 'terlik':
        slipperCount += 2;
        break;
      case 'terlik_x5':
        slipperCount += 5;
        break;
      case 'spray':
      case 'raid':
        sprayCount += 2;
        break;
      case 'raid_x3':
        sprayCount += 3;
        break;
      default:
        final canonical = normalizePowerKey(type);
        _setStock(canonical, _stockOf(canonical, type) + 1);
        if (type != canonical) extraPowers.remove(type);
        break;
    }

    _syncPrimaryPowersToExtra();
    await _persistEconomy();
    notifyListeners();
    return true;
  }

  /// Güçlendirici kullanır (F16 / Raid / Anne Terliği veya mod gücü).
  Future<bool> useBooster(String type) async {
    return consumePower(type);
  }

  /// Coin-shop bundles. Returns false if broke or unknown id.
  ///
  /// Ödüller `IapService.storeCatalog` ile aynıdır (K6: katalog
  /// kanonik). Katalogda karşılığı olmayan id'ler (`makara`,
  /// `kongo`, `limited`) katalog dışı eski paketlerdir; ödülleri
  /// değiştirilmeden korunur.
  Future<bool> buyBundle(String id, int cost) async {
    // O3: negatif maliyet [buyBooster] ile aynı kuralda reddedilir
    // (negatif maliyet coin eklerdi).
    if (cost < 0 || coins < cost) return false;
    // PM-claim: kalıcı yazım (veya enerji doldurma) başarısız olursa
    // ödeme geri alınır (bkz. _ClaimSnapshot) — kısmi ödeme ve UI'ya
    // fırlatma yok. Koruma öncesi erken dönüşler (bilinmeyen id,
    // `limited` gün koruması) değişim yapmadan döner.
    final snapshot = _ClaimSnapshot.capture(this);
    try {
      switch (id) {
        case 'makara':
          coins -= cost;
          slipperCount += 3;
          sprayCount += 3;
          aydinlatCount += 1;
          break;
        case 'kongo':
          coins -= cost;
          slipperCount += 5;
          sprayCount += 5;
          aydinlatCount += 2;
          break;
        case 'limited':
          if (!canBuyLimitedDrop) return false;
          coins -= cost;
          slipperCount += 4;
          sprayCount += 4;
          aydinlatCount += 2;
          coins += 120; // bonus coin splash
          limitedDropDay = _todayKey();
          break;
        case 'f16_x3':
          coins -= cost;
          aydinlatCount += 3;
          break;
        case 'raid_x3':
          coins -= cost;
          sprayCount += 3;
          break;
        case 'terlik_x5':
          coins -= cost;
          slipperCount += 5;
          break;
        case 'full_energy':
          coins -= cost;
          await EnergyService.instance.refillFull();
          break;
        case 'gold_chest':
          coins -= cost;
          coins += 1200;
          slipperCount += 2;
          sprayCount += 2;
          aydinlatCount += 1;
          break;
        case 'royal_cape':
          coins -= cost;
          hasRoyalCape = true;
          ownedCosmetics.add('royal_cape');
          break;
        case 'mega_starter_pack':
          coins -= cost;
          coins += 3000;
          aydinlatCount += 3;
          sprayCount += 3;
          slipperCount += 5;
          hasRoyalCape = true;
          ownedCosmetics.add('royal_cape');
          await EnergyService.instance.refillFull();
          break;
        default:
          return false;
      }
      await _persistEconomy();
    } catch (e) {
      snapshot.restore(this);
      notifyListeners();
      debugPrint(
        'ProgressManager: buyBundle kalici kayit basarisiz; '
        'odeme geri alindi ($e).',
      );
      return false;
    }
    notifyListeners();
    return true;
  }

  /// Free daily shop case — coins + small booster drip.
  Future<({int coins, int slipper, int spray})?> claimShopChest() async {
    if (!canClaimShopChest) return null;
    // PM-claim: kalıcı yazım başarısız olursa ödeme geri alınır
    // (bkz. _ClaimSnapshot) — kısmi ödeme ve UI'ya fırlatma yok.
    final snapshot = _ClaimSnapshot.capture(this);
    shopChestDay = _todayKey();
    const grantCoins = 80;
    const grantSlipper = 1;
    const grantSpray = 1;
    coins += grantCoins;
    slipperCount += grantSlipper;
    sprayCount += grantSpray;
    try {
      await _persistEconomy();
    } catch (e) {
      snapshot.restore(this);
      notifyListeners();
      debugPrint(
        'ProgressManager: claimShopChest kalici kayit basarisiz; '
        'odeme geri alindi ($e).',
      );
      return null;
    }
    notifyListeners();
    return (coins: grantCoins, slipper: grantSlipper, spray: grantSpray);
  }

  Future<void> addCoins(int amount) async {
    if (amount <= 0 || amount > maxSingleCoinGrant) return;
    coins = (coins + amount).clamp(0, maxTotalCoins);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_coins', coins);
    await prefs.setInt('LululuCoinBalance', coins);
    _stateIntegritySig = _computeStateIntegritySig();
    await prefs.setString(_integrityPrefKey, _stateIntegritySig);
    await _persistAntiCheatSeal(prefs);
    notifyListeners();
  }

  Future<bool> spendCoins(int amount) async {
    if (amount < 0) return false;
    if (amount == 0) return true;
    if (coins < amount) return false;
    coins -= amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_coins', coins);
    await prefs.setInt('LululuCoinBalance', coins);
    _stateIntegritySig = _computeStateIntegritySig();
    await prefs.setString(_integrityPrefKey, _stateIntegritySig);
    await _persistAntiCheatSeal(prefs);
    notifyListeners();
    return true;
  }

  /// Arcade mode drip (Terlik Tap bonuses) — real vault economy, not stub.
  Future<void> grantArcadeDrop({
    int coins = 0,
    int slipper = 0,
    int spray = 0,
    int f16 = 0,
  }) async {
    if (coins <= 0 && slipper <= 0 && spray <= 0 && f16 <= 0) return;
    if (coins > 0 && coins <= maxSingleCoinGrant) {
      this.coins = (this.coins + coins).clamp(0, maxTotalCoins);
    }
    if (slipper > 0) {
      slipperCount += slipper.clamp(0, 1000);
      // W13-D: tur-sonu/mağaza ödülü gerçek kazanımdır.
      _markPowerEarned('terlik');
    }
    if (spray > 0) {
      sprayCount += spray.clamp(0, 1000);
      _markPowerEarned('raid');
    }
    if (f16 > 0) {
      aydinlatCount += f16.clamp(0, 1000);
      _markPowerEarned('f16');
    }
    _syncPrimaryPowersToExtra();
    await _persistEconomy();
    notifyListeners();
  }

  /// Persist booster counts after in-match use (shop buy already saves).
  Future<void> persistBoosters() async {
    _syncPrimaryPowersToExtra();
    // Y6/LWW: değeri değişen güç alanlarını damgala, damgaları da yaz.
    touchChangedFieldStamps();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_spray', sprayCount);
    await prefs.setInt('lululu_raid', sprayCount);
    await prefs.setInt('lululu_slipper', slipperCount);
    await prefs.setInt('lululu_terlik', slipperCount);
    await prefs.setInt('lululu_aydinlat', aydinlatCount);
    await prefs.setInt('lululu_f16', aydinlatCount);
    await prefs.setString('lululu_extra_powers', jsonEncode(extraPowers));
    // W13-D: kazanılan güç kümesini de yaz (sıralı — deterministik).
    final earned = _earnedPowerKeys.toList()..sort();
    await prefs.setStringList(_earnedPowersPrefKey, earned);
    _stateIntegritySig = _computeStateIntegritySig();
    await prefs.setString(_integrityPrefKey, _stateIntegritySig);
    await _persistAntiCheatSeal(prefs);
    // Y6/LWW: damga yazımı ateşle-unut — bellek içi damga zaten
    // günceldir; 11 yazımın her kalıcı kayıt yolunu uzatması
    // (özellikle birleştirme/flush kritik yolunda) tek-uçuş
    // korumalı akışları bayat işlere takar. Sonraki kalıcı kayıt
    // da damgaları yazar; yazım penceresi milisaniyelerdir.
    if (!_loading) unawaited(_persistStamps(prefs));
  }

  /// Durum bütünlük imzasını hesaplar (FNV-1a 64-bit benzeri deterministik özet).
  String _computeStateIntegritySig() {
    final sortedScores = modeHighScores.keys.toList()..sort();
    final scorePart = sortedScores
        .map((k) => '$k:${modeHighScores[k]}')
        .join(',');
    final payload = '$_integritySalt|c:$coins|lv:$unlockedLevel|'
        'sp:$sprayCount|sl:$slipperCount|ay:$aydinlatCount|'
        'rc:$hasRoyalCape|sc:$scorePart';
    var hash = 0x811c9dc5;
    for (var i = 0; i < payload.length; i++) {
      hash ^= payload.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 'sig_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  /// Mevcut ekonomi/skor durumunun bütünlük imzası ve tavan sınırlarıyla uyumunu doğrular.
  ///
  /// Skor kontrolü burada BİLİNÇLİ olarak mutlak sınır ([maxValidModeScore],
  /// rules `score 0..500000` ile aynı) kullanır: tek-tavan döneminde
  /// kaydedilmiş eski skorlar mod bazlı tavanın üstünde olabilir; mod bazlı
  /// tavanlar yazma anında ([recordModeScore] / liderlik `submitScore`)
  /// zorlanır, bu okuma kontrolü eski veriyi hile saymaz (S1#35).
  bool verifyStateIntegrity() {
    if (coins < 0 || coins > maxTotalCoins) return false;
    if (unlockedLevel < 1 || unlockedLevel > maxCampaignLevels) return false;
    for (final s in modeHighScores.values) {
      if (s < 0 || s > maxValidModeScore) return false;
    }
    if (_stateIntegritySig.isEmpty) return true;
    return _stateIntegritySig == _computeStateIntegritySig();
  }

  /// AntiCheat HMAC mührü için durum paketi (12C1).
  ///
  /// Enerji bilinçli olarak 0 geçirilir: enerji [EnergyService]'e
  /// aittir ve 5 dakikalık yenileme sayacıyla bu sınıfın kalıcı kayıt
  /// yollarından geçmeden değişir — canlı enerji mühürlense her
  /// yenileme sahte uyumsuzluk üretirdi. Mühür coin, rekorlar,
  /// kademe kilitleri ve güç envanterini kapsar; enerji bu mührün
  /// dışındadır.
  Map<String, dynamic> _antiCheatStatePayload() {
    var highScore = 0;
    for (final s in modeHighScores.values) {
      if (s > highScore) highScore = s;
    }
    return AntiCheatService.instance.buildStatePayload(
      coins: coins,
      energy: 0,
      highScore: highScore,
      modeHighScores: modeHighScores,
      unlockedTiers: unlockedTiers,
      powerCounts: extraPowers,
    );
  }

  /// Güncel durumun HMAC mührünü kalıcı yazar. Hata fırlatmaz: mühür
  /// yazımı oyun akışını bozamaz.
  Future<void> _persistAntiCheatSeal([SharedPreferences? prefs]) async {
    try {
      final store = prefs ?? await SharedPreferences.getInstance();
      final payload = _antiCheatStatePayload();
      final signature = AntiCheatService.instance.computeStateSignature(
        payload,
      );
      await store.setString(_antiCheatSigPrefKey, signature);
    } catch (e) {
      debugPrint('[lululu] AntiCheat: durum mührü yazılamadı: $e');
    }
  }

  /// Saklı HMAC mührünü yüklenen duruma karşı doğrular (12C1).
  ///
  /// Mühür yoksa ilk kez mühürlenir (benimseme). Mühür uyuşmazsa veri
  /// SİLİNMEZ: uyumsuzluk telemetriye yazılır ve güncel durum
  /// yeniden mühürlenir (bulut birleştirme bu sınıfın kayıt yollarını
  /// atlayarak yazabildiği için mühür bayat kalabilir — uyumsuzluk
  /// tek başına hile kanıtı sayılmaz).
  Future<void> _verifyAndResealAntiCheatState(SharedPreferences prefs) async {
    try {
      final stored = prefs.getString(_antiCheatSigPrefKey);
      if (stored != null && stored.isNotEmpty) {
        final payload = _antiCheatStatePayload();
        final valid = AntiCheatService.instance.verifyStateSignature(
          payload,
          stored,
        );
        if (!valid) {
          debugPrint(
            '[lululu] AntiCheat: durum imzası uyuşmadı '
            '(${AntiCheatService.instance.lastSignatureFailureReason}) — '
            'durum korunarak yeniden mühürleniyor.',
          );
          GameTelemetryService.instance.recordError(
            'state_signature_mismatch',
            category: 'anticheat',
            action: 'state_signature_mismatch',
            meta: <String, Object?>{
              'reason': AntiCheatService.instance.lastSignatureFailureReason,
            },
          );
        }
      }
      await _persistAntiCheatSeal(prefs);
    } catch (e) {
      debugPrint('[lululu] AntiCheat: durum imzası doğrulanamadı: $e');
    }
  }

  /// Saklı HMAC mührünü güncel bellek durumuna karşı doğrular
  /// (test/diagnostik içindir; mühür yoksa `true` döner).
  Future<bool> verifyStoredAntiCheatSignature() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_antiCheatSigPrefKey);
      if (stored == null || stored.isEmpty) return true;
      return AntiCheatService.instance.verifyStateSignature(
        _antiCheatStatePayload(),
        stored,
      );
    } catch (_) {
      return false;
    }
  }

  /// `coins` setter'ının kalıcı kaydı (S1#36): setter senkron olduğu için
  /// kayıt olay kuyruğuna ertelenir; aynı senkron bloktaki tekrarlı
  /// atamalar tek kayıtta birleşir. Erteleme sayesinde kayıt, çağıran
  /// metodun senkron değişiklikleri (örn. güçlendirici sayıları) bittikten
  /// sonra okunur; bütünlük imzası ara durumdan hesaplanmaz. Yazan
  /// anahtarlar [addCoins] ile aynıdır (`lululu_coins`,
  /// `LululuCoinBalance`, bütünlük imzası).
  void _scheduleCoinPersist() {
    if (_coinPersistScheduled) return;
    _coinPersistScheduled = true;
    unawaited(
      Future(() async {
        _coinPersistScheduled = false;
        await _persistCoinsOnly();
      }),
    );
  }

  /// Yalnız coin bakiyesi + bütünlük imzası yazar ([addCoins] ile aynı
  /// kayıt yolu; tam ekonomi kaydı için [_persistEconomy] kullanılır).
  Future<void> _persistCoinsOnly() async {
    // Y6/LWW: coin değiştiyse damgala, damgaları da yaz.
    touchChangedFieldStamps();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_coins', coins);
    await prefs.setInt('LululuCoinBalance', coins);
    _stateIntegritySig = _computeStateIntegritySig();
    await prefs.setString(_integrityPrefKey, _stateIntegritySig);
    await _persistAntiCheatSeal(prefs);
    // Y6/LWW: damga yazımı ateşle-unut — bellek içi damga zaten
    // günceldir; 11 yazımın her kalıcı kayıt yolunu uzatması
    // (özellikle birleştirme/flush kritik yolunda) tek-uçuş
    // korumalı akışları bayat işlere takar. Sonraki kalıcı kayıt
    // da damgaları yazar; yazım penceresi milisaniyelerdir.
    if (!_loading) unawaited(_persistStamps(prefs));
  }

  /// Y6/LWW: alan damgalarını prefs'ten yükler; göçte (bayrak yoksa)
  /// mevcut değerleri "şimdi" ile bir kez damgalar ve bayrağı yazar.
  /// Damgasız uzak kayıt 0 sayıldığı için tohumlanmış yerel değer
  /// göçte eski buluta karşı kazanır — veri kaybı olmaz (tasarım
  /// A10 §3.2.5–§3.2.6, adım 1).
  Future<void> _loadFieldStamps(SharedPreferences prefs) async {
    int readStamp(String key) {
      final v = prefs.getInt(key);
      return v == null || v < 0 ? 0 : v;
    }

    coinsUpdatedAtMs = readStamp('lululu_ts_coins');
    energyUpdatedAtMs = readStamp('lululu_ts_energy');
    unlockedLevelUpdatedAtMs = readStamp('lululu_ts_level');
    f16UpdatedAtMs = readStamp('lululu_ts_f16');
    raidUpdatedAtMs = readStamp('lululu_ts_raid');
    terlikUpdatedAtMs = readStamp('lululu_ts_terlik');
    streakUpdatedAtMs = readStamp('lululu_ts_streak');
    unlockedTiersUpdatedAtMs = readStamp('lululu_ts_tiers');
    displayNameUpdatedAtMs = readStamp('lululu_ts_display_name');
    // Dalga 3: günlük alan damgaları (eski kurulumda yoksa 0 — damgasız
    // sayılır; gün anahtarı kendisi sürüm taşıdığı için birleştirme
    // damgaya muhtaç değildir).
    lastStreakClaimDayUpdatedAtMs =
        readStamp('lululu_ts_last_streak_claim_day');
    dailyTasksUpdatedAtMs = readStamp('lululu_ts_daily_tasks');
    dailyFreeEnergyUpdatedAtMs = readStamp('lululu_ts_daily_free_energy');
    extraPowersUpdatedAtMs.clear();
    final extraRaw = prefs.getString('lululu_ts_extra_powers');
    if (extraRaw != null && extraRaw.isNotEmpty) {
      for (final entry in _decodeIntMap(
        extraRaw,
        'lululu_ts_extra_powers',
      ).entries) {
        if (entry.value >= 0) {
          extraPowersUpdatedAtMs[entry.key] = entry.value;
        }
      }
    }
    if (prefs.getBool(_lwwSeedFlagKey) ?? false) return;
    // Göç tohumlaması: bu cihazdaki mevcut değerler ilk kez
    // damgalanır (damga = ilk damgalı yazım anı). İki cihaz da kendi
    // ilk açılışında tohumlar; tohum anları 2 sn içindeyse eşitlik
    // kuralı (max) uygulanır, aksi hâlde geç tohumlayan kazanır —
    // tasarımın kabul ettiği göç yarışıdır, tek cihazda yerel
    // öncelik korunur.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    coinsUpdatedAtMs = nowMs;
    energyUpdatedAtMs = nowMs;
    unlockedLevelUpdatedAtMs = nowMs;
    f16UpdatedAtMs = nowMs;
    raidUpdatedAtMs = nowMs;
    terlikUpdatedAtMs = nowMs;
    streakUpdatedAtMs = nowMs;
    unlockedTiersUpdatedAtMs = nowMs;
    displayNameUpdatedAtMs = nowMs;
    // Dalga 3: günlük alanlar da göçte bir kez damgalanır.
    lastStreakClaimDayUpdatedAtMs = nowMs;
    dailyTasksUpdatedAtMs = nowMs;
    dailyFreeEnergyUpdatedAtMs = nowMs;
    for (final key in extraPowers.keys) {
      extraPowersUpdatedAtMs[key] = nowMs;
    }
    await _persistStamps(prefs);
    await prefs.setBool(_lwwSeedFlagKey, true);
  }

  /// Y6/LWW: son kalıcı kayıttan beri değeri değişen alanların
  /// damgasını "şimdi"ye ilerletir; fark anlık görüntüsünü günceller.
  /// Yükleme sırasında kapalıdır (yükleme değişim sayılmaz).
  void touchChangedFieldStamps() {
    if (_loading) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (coins != _snapCoins) {
      coinsUpdatedAtMs = nowMs;
      _snapCoins = coins;
    }
    final currentEnergy = EnergyService.instance.energy;
    if (currentEnergy != _snapEnergy) {
      energyUpdatedAtMs = nowMs;
      _snapEnergy = currentEnergy;
    }
    if (unlockedLevel != _snapLevel) {
      unlockedLevelUpdatedAtMs = nowMs;
      _snapLevel = unlockedLevel;
    }
    if (f16Count != _snapF16) {
      f16UpdatedAtMs = nowMs;
      _snapF16 = f16Count;
    }
    if (raidCount != _snapRaid) {
      raidUpdatedAtMs = nowMs;
      _snapRaid = raidCount;
    }
    if (terlikCount != _snapTerlik) {
      terlikUpdatedAtMs = nowMs;
      _snapTerlik = terlikCount;
    }
    if (streak != _snapStreak) {
      streakUpdatedAtMs = nowMs;
      _snapStreak = streak;
    }
    // Dalga 3: günlük alanlar — hak günü, görev günü/ilerlemesi/
    // ödül alımları, ücretsiz enerji günü/sayımı.
    if (lastStreakClaimDay != _snapLastStreakClaimDay) {
      lastStreakClaimDayUpdatedAtMs = nowMs;
      _snapLastStreakClaimDay = lastStreakClaimDay;
    }
    var tasksChanged = dailyTasksDay != _snapDailyTasksDay ||
        claimedDailyTasks.length != _snapClaimedDailyTasks.length ||
        !claimedDailyTasks.containsAll(_snapClaimedDailyTasks);
    if (!tasksChanged) {
      for (final entry in dailyTaskProgress.entries) {
        if (_snapDailyTaskProgress[entry.key] != entry.value) {
          tasksChanged = true;
          break;
        }
      }
    }
    if (tasksChanged) {
      dailyTasksUpdatedAtMs = nowMs;
      _snapDailyTasksDay = dailyTasksDay;
      _snapDailyTaskProgress = Map<String, int>.of(dailyTaskProgress);
      _snapClaimedDailyTasks = Set<String>.of(claimedDailyTasks);
    }
    if (lastDailyFreeEnergyDay != _snapLastDailyFreeEnergyDay ||
        dailyFreeEnergyClaimsToday != _snapDailyFreeEnergyClaimsToday) {
      dailyFreeEnergyUpdatedAtMs = nowMs;
      _snapLastDailyFreeEnergyDay = lastDailyFreeEnergyDay;
      _snapDailyFreeEnergyClaimsToday = dailyFreeEnergyClaimsToday;
    }
    if (unlockedTiers.length != _snapTiers.length ||
        !unlockedTiers.containsAll(_snapTiers)) {
      unlockedTiersUpdatedAtMs = nowMs;
      _snapTiers = Set<int>.of(unlockedTiers);
    }
    // Güç anahtarları: birincil güçlerin (raid/terlik/f16) damgası
    // birincil stok damgasını izler; diğer anahtarlar kendi
    // değişiminde "şimdi" ile damgalanır.
    final nextPowers = <String, int>{};
    for (final entry in extraPowers.entries) {
      final prev = _snapExtraPowers[entry.key];
      if (prev == null || prev != entry.value) {
        switch (entry.key) {
          case 'raid':
            extraPowersUpdatedAtMs[entry.key] = raidUpdatedAtMs;
            break;
          case 'terlik':
            extraPowersUpdatedAtMs[entry.key] = terlikUpdatedAtMs;
            break;
          case 'f16':
            extraPowersUpdatedAtMs[entry.key] = f16UpdatedAtMs;
            break;
          default:
            extraPowersUpdatedAtMs[entry.key] = nowMs;
            break;
        }
      }
      nextPowers[entry.key] = entry.value;
    }
    _snapExtraPowers = nextPowers;
    for (final key in extraPowersUpdatedAtMs.keys.toList()) {
      if (!extraPowers.containsKey(key)) {
        extraPowersUpdatedAtMs.remove(key);
      }
    }
  }

  /// Y6/LWW: fark anlık görüntüsünü mevcut duruma eşitler — damga
  /// ilerletmez. Birleştirme/test sıfırlaması sonrası kullanılır:
  /// sonraki [touchChangedFieldStamps] yalnız gerçekten yeni
  /// değişimleri damgalar.
  void syncPersistedSnapshot() {
    _snapCoins = coins;
    _snapEnergy = EnergyService.instance.energy;
    _snapLevel = unlockedLevel;
    _snapF16 = f16Count;
    _snapRaid = raidCount;
    _snapTerlik = terlikCount;
    _snapStreak = streak;
    _snapTiers = Set<int>.of(unlockedTiers);
    _snapExtraPowers = Map<String, int>.of(extraPowers);
    // Dalga 3: günlük alanlar.
    _snapLastStreakClaimDay = lastStreakClaimDay;
    _snapDailyTasksDay = dailyTasksDay;
    _snapDailyTaskProgress = Map<String, int>.of(dailyTaskProgress);
    _snapClaimedDailyTasks = Set<String>.of(claimedDailyTasks);
    _snapLastDailyFreeEnergyDay = lastDailyFreeEnergyDay;
    _snapDailyFreeEnergyClaimsToday = dailyFreeEnergyClaimsToday;
  }

  /// Y6/LWW: enerji bildiricisinden gelen değişimde enerji damgasını
  /// ilerletir. Enerji (regen/grant/tüketim) PM kalıcı kayıt yolundan
  /// geçmeden de değişebilir; bu dinleyici o yolu kapatır.
  void _onEnergyChanged() {
    if (_loading) return;
    final currentEnergy = EnergyService.instance.energy;
    if (currentEnergy == _snapEnergy) return;
    energyUpdatedAtMs = DateTime.now().millisecondsSinceEpoch;
    _snapEnergy = currentEnergy;
    unawaited(persistFieldStamps());
  }

  /// Y6/LWW: görünen ad değiştiğinde ad damgasını ilerletir. Ad,
  /// AuthService'e aittir; bu kanca ad değişimini PM'e bildirmek
  /// içindir (şu an çağrıcısı yok — damga payload'da taşınır,
  /// pull'da ad ezilmez, bkz. CloudSync).
  void noteDisplayNameChanged() {
    displayNameUpdatedAtMs = DateTime.now().millisecondsSinceEpoch;
    unawaited(persistFieldStamps());
  }

  /// Y6/LWW: bulut payload'una girecek damga haritası.
  Map<String, dynamic> fieldUpdatedAtMap() {
    return <String, dynamic>{
      'coinsUpdatedAtMs': coinsUpdatedAtMs,
      'energyUpdatedAtMs': energyUpdatedAtMs,
      'unlockedLevelUpdatedAtMs': unlockedLevelUpdatedAtMs,
      'f16UpdatedAtMs': f16UpdatedAtMs,
      'raidUpdatedAtMs': raidUpdatedAtMs,
      'terlikUpdatedAtMs': terlikUpdatedAtMs,
      'streakUpdatedAtMs': streakUpdatedAtMs,
      'unlockedTiersUpdatedAtMs': unlockedTiersUpdatedAtMs,
      'displayNameUpdatedAtMs': displayNameUpdatedAtMs,
      // Dalga 3: günlük alan damgaları.
      'lastStreakClaimDayUpdatedAtMs': lastStreakClaimDayUpdatedAtMs,
      'dailyTasksUpdatedAtMs': dailyTasksUpdatedAtMs,
      'dailyFreeEnergyUpdatedAtMs': dailyFreeEnergyUpdatedAtMs,
      'extraPowersUpdatedAtMs':
          Map<String, int>.from(extraPowersUpdatedAtMs),
    };
  }

  /// Y6/LWW: damga prefs yazımı (tek yer).
  Future<void> _persistStamps(SharedPreferences prefs) async {
    await prefs.setInt('lululu_ts_coins', coinsUpdatedAtMs);
    await prefs.setInt('lululu_ts_energy', energyUpdatedAtMs);
    await prefs.setInt('lululu_ts_level', unlockedLevelUpdatedAtMs);
    await prefs.setInt('lululu_ts_f16', f16UpdatedAtMs);
    await prefs.setInt('lululu_ts_raid', raidUpdatedAtMs);
    await prefs.setInt('lululu_ts_terlik', terlikUpdatedAtMs);
    await prefs.setInt('lululu_ts_streak', streakUpdatedAtMs);
    await prefs.setInt('lululu_ts_tiers', unlockedTiersUpdatedAtMs);
    await prefs.setInt('lululu_ts_display_name', displayNameUpdatedAtMs);
    // Dalga 3: günlük alan damgaları.
    await prefs.setInt(
      'lululu_ts_last_streak_claim_day',
      lastStreakClaimDayUpdatedAtMs,
    );
    await prefs.setInt('lululu_ts_daily_tasks', dailyTasksUpdatedAtMs);
    await prefs.setInt(
      'lululu_ts_daily_free_energy',
      dailyFreeEnergyUpdatedAtMs,
    );
    await prefs.setString(
      'lululu_ts_extra_powers',
      jsonEncode(extraPowersUpdatedAtMs),
    );
  }

  /// Y6/LWW: bellek içi damgaları prefs'e yazar (yükleme sırasında
  /// çağrılmaz; yükleme kendi damga yolunu kullanır).
  Future<void> persistFieldStamps() async {
    if (_loading) return;
    final prefs = await SharedPreferences.getInstance();
    await _persistStamps(prefs);
  }

  Future<void> _persistEconomy() async {
    _syncPrimaryPowersToExtra();
    // Y6/LWW: değeri değişen alanları damgala, sonra damgaları da yaz.
    touchChangedFieldStamps();
    final prefs = await SharedPreferences.getInstance();
    // O1 NOTU: alias pref anahtarlarına yazım BİLİNÇLİ korunur —
    // `auth_service.dart` ve `cloud_sync_service.dart` aynı çift
    // anahtarları okuyup yazar; tek-dosya kapsamında göç
    // tamamlanamaz. Okuma önceliği kanonik anahtardadır (bkz. [load]).
    await prefs.setInt('lululu_coins', coins);
    await prefs.setInt('LululuCoinBalance', coins);
    await prefs.setInt('lululu_spray', sprayCount);
    await prefs.setInt('lululu_raid', sprayCount);
    await prefs.setInt('lululu_slipper', slipperCount);
    await prefs.setInt('lululu_terlik', slipperCount);
    await prefs.setInt('lululu_aydinlat', aydinlatCount);
    await prefs.setInt('lululu_f16', aydinlatCount);
    await prefs.setBool('lululu_royal_cape', hasRoyalCape);
    await prefs.setStringList(
      'lululu_owned_cosmetics',
      ownedCosmetics.toList(),
    );
    await prefs.setString('lululu_shop_chest_day', shopChestDay);
    await prefs.setString('lululu_limited_drop_day', limitedDropDay);
    await prefs.setString('lululu_extra_powers', jsonEncode(extraPowers));
    // W13-D: kazanılan güç kümesini de yaz (sıralı — deterministik).
    final earned = _earnedPowerKeys.toList()..sort();
    await prefs.setStringList(_earnedPowersPrefKey, earned);
    _stateIntegritySig = _computeStateIntegritySig();
    await prefs.setString(_integrityPrefKey, _stateIntegritySig);
    await _persistAntiCheatSeal(prefs);
    // Y6/LWW: damga yazımı ateşle-unut — bellek içi damga zaten
    // günceldir; 11 yazımın her kalıcı kayıt yolunu uzatması
    // (özellikle birleştirme/flush kritik yolunda) tek-uçuş
    // korumalı akışları bayat işlere takar. Sonraki kalıcı kayıt
    // da damgaları yazar; yazım penceresi milisaniyelerdir.
    if (!_loading) unawaited(_persistStamps(prefs));
  }
}

/// Claim/ödeme metotlarının geri alma anlık görüntüsü (PM-claim).
///
/// Semantik: kalıcı yazım başarısız olursa bellek durumu ödeme-öncesi
/// hâle döndürülür ve metot başarısızlık değerini döner
/// (`false`/`null`) — hata UI'ya fırlatılmaz, `debugPrint` ile
/// görünür kılınır. Yalnız başarısızlık dönmek yetmezdi: bellek içi
/// koruma bayrakları (gün işaretleri, `claimedDailyTasks`) tekrar
/// denemeyi engellerdi; geri alma çağırıcının tekrar deneyebilmesini
/// sağlar. Ödeme-yan-etki sırası değişmez (önce hesap, sonra yazım);
/// kısmi ödeme oluşmaz. Desen, IAP tarafındaki O19 geri alma anlık
/// görüntüsüyle aynıdır.
///
/// Kapsam: [ProgressManager]ın claim metotlarının değiştirdiği tüm
/// alanlar + enerji bakiyesi. Bütünlük imzası bellek içinde geri
/// alınan durumdan yeniden hesaplanır; kalıcı kayıt yazılmaz.
/// `coins` setter'ının ertelenmiş kaydı (`_scheduleCoinPersist`)
/// ateşle-unut yoludur ve bu kapsamın dışındadır (önceden var olan
/// davranış, değiştirilmedi).
class _ClaimSnapshot {
  _ClaimSnapshot.capture(ProgressManager pm)
      : _coins = pm.coins,
        _sprayCount = pm.sprayCount,
        _slipperCount = pm.slipperCount,
        _aydinlatCount = pm.aydinlatCount,
        _hasRoyalCape = pm.hasRoyalCape,
        _ownedCosmetics = Set<String>.of(pm.ownedCosmetics),
        _extraPowers = Map<String, int>.of(pm.extraPowers),
        _shopChestDay = pm.shopChestDay,
        _limitedDropDay = pm.limitedDropDay,
        _streak = pm.streak,
        _lastStreakClaimDay = pm.lastStreakClaimDay,
        _dailyTaskProgress = Map<String, int>.of(pm.dailyTaskProgress),
        _claimedDailyTasks = Set<String>.of(pm.claimedDailyTasks),
        _dailyTasksDay = pm.dailyTasksDay,
        _lastDailyFreeEnergyDay = pm.lastDailyFreeEnergyDay,
        _dailyFreeEnergyClaimsToday = pm.dailyFreeEnergyClaimsToday,
        _lastFreeEnergyClaimEpochMs = pm.lastFreeEnergyClaimEpochMs,
        _energy = EnergyService.instance.energy,
        // Y6/LWW: damgalar da geri alınır (ödeme geri alınırken
        // damga ilerlemesi kalırsa harcama "yeni" görünür).
        _coinsUpdatedAtMs = pm.coinsUpdatedAtMs,
        _energyUpdatedAtMs = pm.energyUpdatedAtMs,
        _unlockedLevelUpdatedAtMs = pm.unlockedLevelUpdatedAtMs,
        _f16UpdatedAtMs = pm.f16UpdatedAtMs,
        _raidUpdatedAtMs = pm.raidUpdatedAtMs,
        _terlikUpdatedAtMs = pm.terlikUpdatedAtMs,
        _streakUpdatedAtMs = pm.streakUpdatedAtMs,
        _unlockedTiersUpdatedAtMs = pm.unlockedTiersUpdatedAtMs,
        _displayNameUpdatedAtMs = pm.displayNameUpdatedAtMs,
        // Dalga 3: günlük alan damgaları da geri alınır.
        _lastStreakClaimDayUpdatedAtMs = pm.lastStreakClaimDayUpdatedAtMs,
        _dailyTasksUpdatedAtMs = pm.dailyTasksUpdatedAtMs,
        _dailyFreeEnergyUpdatedAtMs = pm.dailyFreeEnergyUpdatedAtMs,
        _extraPowersUpdatedAtMs =
            Map<String, int>.of(pm.extraPowersUpdatedAtMs);

  final int _coins;
  final int _sprayCount;
  final int _slipperCount;
  final int _aydinlatCount;
  final bool _hasRoyalCape;
  final Set<String> _ownedCosmetics;
  final Map<String, int> _extraPowers;
  final String _shopChestDay;
  final String _limitedDropDay;
  final int _streak;
  final String _lastStreakClaimDay;
  final Map<String, int> _dailyTaskProgress;
  final Set<String> _claimedDailyTasks;
  final String _dailyTasksDay;
  final String _lastDailyFreeEnergyDay;
  final int _dailyFreeEnergyClaimsToday;
  final int _lastFreeEnergyClaimEpochMs;
  final int _energy;
  final int _coinsUpdatedAtMs;
  final int _energyUpdatedAtMs;
  final int _unlockedLevelUpdatedAtMs;
  final int _f16UpdatedAtMs;
  final int _raidUpdatedAtMs;
  final int _terlikUpdatedAtMs;
  final int _streakUpdatedAtMs;
  final int _unlockedTiersUpdatedAtMs;
  final int _displayNameUpdatedAtMs;
  final int _lastStreakClaimDayUpdatedAtMs;
  final int _dailyTasksUpdatedAtMs;
  final int _dailyFreeEnergyUpdatedAtMs;
  final Map<String, int> _extraPowersUpdatedAtMs;

  /// Bellek durumunu anlık görüntüdeki hâle döndürür. `coins`
  /// doğrudan alana yazılır (setter'ın ertelenmiş kalıcı kaydı hata
  /// yolunda yeniden zamanlanmaz); bildirim değeri elle eşitlenir.
  /// Dinleyici bildirimi çağırana aittir (`notifyListeners` korumalı
  /// üyedir, bu sınıftan çağrılamaz).
  void restore(ProgressManager pm) {
    pm._coins = _coins;
    pm.coinsNotifier.value = _coins;
    pm.sprayCount = _sprayCount;
    pm.slipperCount = _slipperCount;
    pm.aydinlatCount = _aydinlatCount;
    pm.hasRoyalCape = _hasRoyalCape;
    pm.ownedCosmetics
      ..clear()
      ..addAll(_ownedCosmetics);
    pm.extraPowers
      ..clear()
      ..addAll(_extraPowers);
    pm.shopChestDay = _shopChestDay;
    pm.limitedDropDay = _limitedDropDay;
    pm.streak = _streak;
    pm.lastStreakClaimDay = _lastStreakClaimDay;
    pm.dailyTaskProgress
      ..clear()
      ..addAll(_dailyTaskProgress);
    pm.claimedDailyTasks
      ..clear()
      ..addAll(_claimedDailyTasks);
    pm.dailyTasksDay = _dailyTasksDay;
    pm.lastDailyFreeEnergyDay = _lastDailyFreeEnergyDay;
    pm.dailyFreeEnergyClaimsToday = _dailyFreeEnergyClaimsToday;
    pm.lastFreeEnergyClaimEpochMs = _lastFreeEnergyClaimEpochMs;
    pm._stateIntegritySig = pm._computeStateIntegritySig();
    // Y6/LWW: damgalar da geri alınır.
    pm.coinsUpdatedAtMs = _coinsUpdatedAtMs;
    pm.energyUpdatedAtMs = _energyUpdatedAtMs;
    pm.unlockedLevelUpdatedAtMs = _unlockedLevelUpdatedAtMs;
    pm.f16UpdatedAtMs = _f16UpdatedAtMs;
    pm.raidUpdatedAtMs = _raidUpdatedAtMs;
    pm.terlikUpdatedAtMs = _terlikUpdatedAtMs;
    pm.streakUpdatedAtMs = _streakUpdatedAtMs;
    pm.unlockedTiersUpdatedAtMs = _unlockedTiersUpdatedAtMs;
    pm.displayNameUpdatedAtMs = _displayNameUpdatedAtMs;
    pm.lastStreakClaimDayUpdatedAtMs = _lastStreakClaimDayUpdatedAtMs;
    pm.dailyTasksUpdatedAtMs = _dailyTasksUpdatedAtMs;
    pm.dailyFreeEnergyUpdatedAtMs = _dailyFreeEnergyUpdatedAtMs;
    pm.extraPowersUpdatedAtMs
      ..clear()
      ..addAll(_extraPowersUpdatedAtMs);
    // Y6/LWW: enerji ataması dinleyiciyi tetikler; anlık görüntüyü
    // önce geri alınmış değere eşitle ki dinleyici damgayı yeniden
    // ilerletmesin; sonra tüm fark anlık görüntülerini geri alınmış
    // duruma eşitle (sonraki touch yalnız yeni değişimleri damgalar).
    pm._snapEnergy = _energy;
    EnergyService.instance.energy = _energy;
    pm.syncPersistedSnapshot();
  }
}
