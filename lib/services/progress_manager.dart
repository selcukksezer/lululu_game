import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'energy_service.dart';

class ProgressManager extends ChangeNotifier {
  static final ProgressManager _instance = ProgressManager._internal();
  factory ProgressManager() => _instance;
  static ProgressManager get instance => _instance;
  ProgressManager._internal();

  static const int defaultCoins = 1240;
  static const int maxCampaignLevels = 80;
  static const int maxSingleCoinGrant = 100000;
  static const int maxTotalCoins = 99999999;
  static const int maxValidModeScore = 500000;
  static const String _integrityPrefKey = 'lululu_state_integrity_sig';
  static const String _integritySalt = 'LululuVaultSig_2026_v4';

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

  int unlockedLevel = 1;
  int _coins = defaultCoins;

  int get coins => _coins;
  set coins(int value) {
    _coins = value < 0 ? 0 : value;
    coinsNotifier.value = _coins;
  }

  final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(defaultCoins);

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

  int get dailyStreak => streak;

  /// Ses ve titreşim ayarları.
  bool musicEnabled = true;
  bool sfxEnabled = true;
  bool vibrationEnabled = true;

  final ValueNotifier<bool> musicNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> sfxNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> vibrationNotifier = ValueNotifier<bool>(true);

  /// Moda özel güçlendirici stokları (HTML POWERS id'leri).
  final Map<String, int> extraPowers = {};

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
  Duration get energyTimeToNext => EnergyService.instance.timeToNext;

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

  bool get canClaimDailyGiftBox => lastStreakClaimDay != _todayKey();

  /// Ana Hub'daki "ENERJİ AL · +5" butonu için günlük ücretsiz hak kontrolü.
  bool get canClaimDailyFreeEnergy {
    final today = _todayKey();
    if (lastDailyFreeEnergyDay != today) return true;
    return false;
  }

  /// Reklam izleyerek ek ücretsiz enerji alınıp alınamayacağını kontrol eder (cooldown + günlük limit).
  bool get canClaimAdFreeEnergy {
    final today = _todayKey();
    final claims = lastDailyFreeEnergyDay == today ? dailyFreeEnergyClaimsToday : 0;
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
    if (lastDailyFreeEnergyDay != today) {
      dailyFreeEnergyClaimsToday = 0;
    }

    if (!fromRewardedAd) {
      if (!canClaimDailyFreeEnergy) return false;
    } else {
      if (!canClaimAdFreeEnergy) return false;
    }

    final safeAmount = amount.clamp(1, EnergyService.maxEnergy);
    lastDailyFreeEnergyDay = today;
    dailyFreeEnergyClaimsToday += 1;
    lastFreeEnergyClaimEpochMs = nowMs;

    EnergyService.instance.addEnergy(safeAmount);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lululu_daily_free_energy_day', lastDailyFreeEnergyDay);
    await prefs.setInt(
      'lululu_daily_free_energy_claims',
      dailyFreeEnergyClaimsToday,
    );
    await prefs.setInt(
      'lululu_last_free_energy_epoch_ms',
      lastFreeEnergyClaimEpochMs,
    );
    await _persistEconomy();
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

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

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

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    unlockedLevel =
        (prefs.getInt('lululu_unlocked_level') ?? 1).clamp(1, maxCampaignLevels);
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

    // 11 oyun modu en yüksek skorları
    modeHighScores.clear();
    final modeScoresRaw = prefs.getString('lululu_mode_high_scores');
    if (modeScoresRaw != null && modeScoresRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(modeScoresRaw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          modeHighScores[normalizeModeId(k)] = (v as num).toInt();
        });
      } catch (_) {}
    }

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
        try {
          final decoded = jsonDecode(taskProgRaw) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            dailyTaskProgress[k] = (v as num).toInt();
          });
        } catch (_) {}
      }
      final claimedRaw = prefs.getStringList('lululu_daily_tasks_claimed');
      claimedDailyTasks
        ..clear()
        ..addAll(claimedRaw ?? const []);
    }

    // Günlük hediye kutusu serisi (streak)
    streak = prefs.getInt('lululu_daily_streak') ?? 1;
    lastStreakClaimDay = prefs.getString('lululu_last_streak_claim_day') ?? '';

    // Ses ve titreşim ayarları
    musicEnabled = prefs.getBool('lululu_music_enabled') ?? true;
    sfxEnabled = prefs.getBool('lululu_sfx_enabled') ?? true;
    vibrationEnabled = prefs.getBool('lululu_vibration_enabled') ?? true;
    musicNotifier.value = musicEnabled;
    sfxNotifier.value = sfxEnabled;
    vibrationNotifier.value = vibrationEnabled;

    extraPowers.clear();
    final extraRaw = prefs.getString('lululu_extra_powers');
    if (extraRaw != null && extraRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(extraRaw) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          extraPowers[k] = (v as num).toInt();
        });
      } catch (_) {}
    }

    _levelStars.clear();
    final starsJson = prefs.getString('lululu_level_stars');
    if (starsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(starsJson);
        decoded.forEach((k, v) {
          _levelStars[int.parse(k)] = (v as num).toInt();
        });
      } catch (_) {}
    }

    _levelHighScores.clear();
    final scoresJson = prefs.getString('lululu_level_scores');
    if (scoresJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(scoresJson);
        decoded.forEach((k, v) {
          _levelHighScores[int.parse(k)] = (v as num).toInt();
        });
      } catch (_) {}
    }

    if (!(prefs.getBool('lululu_power_seed_v1') ?? false)) {
      const seeds = <String, int>{
        'raid': 3,
        'terlik': 5,
        'f16': 2,
        'undo': 3,
        'shuffle': 2,
        'pair': 1,
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
      for (final entry in seeds.entries) {
        extraPowers.putIfAbsent(entry.key, () => entry.value);
      }
      await prefs.setBool('lululu_power_seed_v1', true);
      await _persistEconomy();
    }

    _syncPrimaryPowersToExtra();
    _stateIntegritySig =
        prefs.getString(_integrityPrefKey) ?? _computeStateIntegritySig();
    if (!verifyStateIntegrity()) {
      // Tamper / aşırı hileli değer tespit edilirse güvenli sınırlara çek.
      coins = coins.clamp(0, maxTotalCoins);
      unlockedLevel = unlockedLevel.clamp(1, maxCampaignLevels);
      _stateIntegritySig = _computeStateIntegritySig();
      await prefs.setString(_integrityPrefKey, _stateIntegritySig);
    }

    notifyListeners();
  }

  /// 33 oyun modu güçlendiricisinin anahtarlarını ve Türkçe mağaza adlarını kanonikleştirir.
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
      case 'shuffle':
      case 'karistir':
        return 'shuffle';
      case 'pair':
      case 'ciftlestir':
        return 'pair';
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
        return 'yuva_dblslip';
      case 'yuva_goldslip':
      case 'yuva altin terlik':
        return 'yuva_goldslip';
      case 'nest_shield':
      case 'yuva kalkani':
      case 'yuva_kalkani':
      case 'yuvakalkan':
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
    extraPowers['raid'] = sprayCount;
    extraPowers['spray'] = sprayCount;
    extraPowers['terlik'] = slipperCount;
    extraPowers['slipper'] = slipperCount;
    extraPowers['f16'] = aydinlatCount;
    extraPowers['aydinlat'] = aydinlatCount;
    extraPowers.putIfAbsent('yuva_dblslip', () => extraPowers['dblslip'] ?? 3);
    extraPowers.putIfAbsent(
      'yuva_goldslip',
      () => extraPowers['goldslip'] ?? 2,
    );
    extraPowers.putIfAbsent('nest_shield', () => extraPowers['shield'] ?? 1);
  }

  int powerCount(String id) {
    final canonical = normalizePowerKey(id);
    switch (canonical) {
      case 'raid':
        return sprayCount;
      case 'terlik':
        return slipperCount;
      case 'f16':
        return aydinlatCount;
      default:
        return extraPowers[canonical] ?? extraPowers[id] ?? 0;
    }
  }

  /// Moda özel güçlendirici stoğunu doğrudan ayarlar ve kaydeder.
  Future<void> setPowerCount(String id, int count) async {
    final safeCount = count < 0 ? 0 : count;
    final canonical = normalizePowerKey(id);
    switch (canonical) {
      case 'raid':
        sprayCount = safeCount;
        break;
      case 'terlik':
        slipperCount = safeCount;
        break;
      case 'f16':
        aydinlatCount = safeCount;
        break;
      default:
        extraPowers[canonical] = safeCount;
        extraPowers[id] = safeCount;
        break;
    }
    _syncPrimaryPowersToExtra();
    await _persistEconomy();
    notifyListeners();
  }

  /// 33 oyun modu güçlendiricisi için envanteri `delta` kadar artırır (veya azaltır),
  /// `extraPowers` + `f16Count`/`raidCount`/`terlikCount` değerlerini kalıcı günceller.
  Future<int> incrementPowerCount(String key, [int delta = 1]) async {
    if (delta == 0) return powerCount(key);
    final canonical = normalizePowerKey(key);
    int nextValue;
    switch (canonical) {
      case 'raid':
        sprayCount = (sprayCount + delta).clamp(0, 99999);
        nextValue = sprayCount;
        break;
      case 'terlik':
        slipperCount = (slipperCount + delta).clamp(0, 99999);
        nextValue = slipperCount;
        break;
      case 'f16':
        aydinlatCount = (aydinlatCount + delta).clamp(0, 99999);
        nextValue = aydinlatCount;
        break;
      default:
        final current = extraPowers[canonical] ?? extraPowers[key] ?? 0;
        nextValue = (current + delta).clamp(0, 99999);
        extraPowers[canonical] = nextValue;
        if (key != canonical) {
          extraPowers[key] = nextValue;
        }
        break;
    }
    _syncPrimaryPowersToExtra();
    await _persistEconomy();
    notifyListeners();
    return nextValue;
  }

  /// Oyun içinden veya mağazadan 1 adet güçlendirici harcar (`extraPowers` + `f16Count`/`raidCount`/`terlikCount`).
  Future<bool> consumePower(String key) async {
    final canonical = normalizePowerKey(key);
    switch (canonical) {
      case 'raid':
        if (sprayCount <= 0) return false;
        sprayCount--;
        break;
      case 'terlik':
        if (slipperCount <= 0) return false;
        slipperCount--;
        break;
      case 'f16':
        if (aydinlatCount <= 0) return false;
        aydinlatCount--;
        break;
      default:
        final have = extraPowers[canonical] ?? extraPowers[key] ?? 0;
        if (have <= 0) return false;
        final next = have - 1;
        extraPowers[canonical] = next;
        if (key != canonical) {
          extraPowers[key] = next;
        }
        break;
    }
    _syncPrimaryPowersToExtra();
    await _persistEconomy();
    notifyListeners();
    return true;
  }

  /// Kasadan 1 yük harcar. Stok yoksa false.
  bool takePower(String id) {
    final canonical = normalizePowerKey(id);
    switch (canonical) {
      case 'raid':
        if (sprayCount <= 0) return false;
        sprayCount--;
        break;
      case 'terlik':
        if (slipperCount <= 0) return false;
        slipperCount--;
        break;
      case 'f16':
        if (aydinlatCount <= 0) return false;
        aydinlatCount--;
        break;
      default:
        final have = extraPowers[canonical] ?? extraPowers[id] ?? 0;
        if (have <= 0) return false;
        extraPowers[canonical] = have - 1;
        if (id != canonical) {
          extraPowers[id] = have - 1;
        }
        break;
    }
    _syncPrimaryPowersToExtra();
    notifyListeners();
    unawaited(_persistEconomy());
    return true;
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
    notifyListeners();
    return true;
  }

  /// 11 oyun modundan birinin yüksek skorunu kaydeder (anti-cheat tavan kontrollü).
  Future<bool> recordModeScore(String modeId, int score) async {
    if (score <= 0 || score > maxValidModeScore) return false;
    final key = normalizeModeId(modeId);
    if (key.isEmpty) return false;
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
    final today = _todayKey();
    if (dailyTasksDay != today) {
      dailyTasksDay = today;
      dailyTaskProgress.updateAll((_, _) => 0);
      claimedDailyTasks.clear();
    }
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
    claimedDailyTasks.add(taskId);
    if (coinReward > 0) {
      coins += coinReward;
    }
    if (energyReward > 0) {
      EnergyService.instance.addEnergy(energyReward);
    }
    await _persistDailyTasks();
    await _persistEconomy();
    notifyListeners();
    return true;
  }

  Future<void> _persistDailyTasks() async {
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
  }

  /// Günlük hediye kutusu ve seri (`streak`) ödülünü toplar.
  Future<({int coins, int energy, int streak})?> claimDailyGiftBox({
    bool doubled = false,
  }) async {
    final today = _todayKey();
    if (lastStreakClaimDay == today && !doubled) return null;
    if (lastStreakClaimDay != today) {
      if (lastStreakClaimDay == _yesterdayKey()) {
        streak += 1;
      } else if (lastStreakClaimDay.isNotEmpty) {
        streak = 1;
      } else {
        streak = streak < 1 ? 1 : streak;
      }
      lastStreakClaimDay = today;
    }
    final rewardCoins = (doubled ? 1000 : 500) + (streak - 1) * 25;
    const rewardEnergy = 5;
    coins += rewardCoins;
    EnergyService.instance.addEnergy(rewardEnergy);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_daily_streak', streak);
    await prefs.setString('lululu_last_streak_claim_day', lastStreakClaimDay);
    await _persistEconomy();
    notifyListeners();
    return (coins: rewardCoins, energy: rewardEnergy, streak: streak);
  }

  /// Ses ve titreşim ayarlarını günceller ve kalıcı olarak saklar.
  Future<void> setMusicEnabled(bool enabled) async {
    musicEnabled = enabled;
    musicNotifier.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lululu_music_enabled', enabled);
    notifyListeners();
  }

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

  Future<void> recordLevelResult({
    required int levelId,
    required int score,
    required int stars,
  }) async {
    if (stars > 0) {
      final currentStars = _levelStars[levelId] ?? 0;
      if (stars > currentStars) {
        _levelStars[levelId] = stars;
      }

      if (levelId >= unlockedLevel && unlockedLevel < maxCampaignLevels) {
        unlockedLevel = (levelId + 1).clamp(1, maxCampaignLevels);
      }

      // Coin ödülü (yıldız başına 50 coin)
      coins += stars * 50;
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
        final next = (extraPowers[canonical] ?? extraPowers[type] ?? 0) + 1;
        extraPowers[canonical] = next;
        if (type != canonical) {
          extraPowers[type] = next;
        }
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
  Future<bool> buyBundle(String id, int cost) async {
    if (coins < cost) return false;
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
        coins += 1000;
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
        coins += 2500;
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
    notifyListeners();
    return true;
  }

  /// Free daily shop case — coins + small booster drip.
  Future<({int coins, int slipper, int spray})?> claimShopChest() async {
    if (!canClaimShopChest) return null;
    shopChestDay = _todayKey();
    const grantCoins = 80;
    const grantSlipper = 1;
    const grantSpray = 1;
    coins += grantCoins;
    slipperCount += grantSlipper;
    sprayCount += grantSpray;
    await _persistEconomy();
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
    if (slipper > 0) slipperCount += slipper.clamp(0, 1000);
    if (spray > 0) sprayCount += spray.clamp(0, 1000);
    if (f16 > 0) aydinlatCount += f16.clamp(0, 1000);
    _syncPrimaryPowersToExtra();
    await _persistEconomy();
    notifyListeners();
  }

  /// Persist booster counts after in-match use (shop buy already saves).
  Future<void> persistBoosters() async {
    _syncPrimaryPowersToExtra();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_spray', sprayCount);
    await prefs.setInt('lululu_raid', sprayCount);
    await prefs.setInt('lululu_slipper', slipperCount);
    await prefs.setInt('lululu_terlik', slipperCount);
    await prefs.setInt('lululu_aydinlat', aydinlatCount);
    await prefs.setInt('lululu_f16', aydinlatCount);
    await prefs.setString('lululu_extra_powers', jsonEncode(extraPowers));
    _stateIntegritySig = _computeStateIntegritySig();
    await prefs.setString(_integrityPrefKey, _stateIntegritySig);
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
  bool verifyStateIntegrity() {
    if (coins < 0 || coins > maxTotalCoins) return false;
    if (unlockedLevel < 1 || unlockedLevel > maxCampaignLevels) return false;
    for (final s in modeHighScores.values) {
      if (s < 0 || s > maxValidModeScore) return false;
    }
    if (_stateIntegritySig.isEmpty) return true;
    return _stateIntegritySig == _computeStateIntegritySig();
  }

  Future<void> _persistEconomy() async {
    _syncPrimaryPowersToExtra();
    final prefs = await SharedPreferences.getInstance();
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
    _stateIntegritySig = _computeStateIntegritySig();
    await prefs.setString(_integrityPrefKey, _stateIntegritySig);
  }
}
