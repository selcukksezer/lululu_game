import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressManager extends ChangeNotifier {
  static final ProgressManager _instance = ProgressManager._internal();
  factory ProgressManager() => _instance;
  ProgressManager._internal();

  int unlockedLevel = 1;
  int coins = 300;
  int sprayCount = 3;
  int slipperCount = 5;
  int aydinlatCount = 2;

  /// Shop daily free case — separate from hub daily challenge claim.
  String shopChestDay = '';
  /// Limited FOMO drop — one purchase per calendar day.
  String limitedDropDay = '';

  final Map<int, int> _levelStars = {};
  final Map<int, int> _levelHighScores = {};

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

  bool isLevelUnlocked(int levelId) => levelId <= unlockedLevel;

  static String _todayKey() {
    final n = DateTime.now();
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
    unlockedLevel = prefs.getInt('lululu_unlocked_level') ?? 1;
    coins = prefs.getInt('lululu_coins') ?? 300;
    sprayCount = prefs.getInt('lululu_spray') ?? 3;
    slipperCount = prefs.getInt('lululu_slipper') ?? 5;
    aydinlatCount = prefs.getInt('lululu_aydinlat') ?? 2;
    shopChestDay = prefs.getString('lululu_shop_chest_day') ?? '';
    limitedDropDay = prefs.getString('lululu_limited_drop_day') ?? '';

    final starsJson = prefs.getString('lululu_level_stars');
    if (starsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(starsJson);
        decoded.forEach((k, v) {
          _levelStars[int.parse(k)] = v as int;
        });
      } catch (_) {}
    }

    final scoresJson = prefs.getString('lululu_level_scores');
    if (scoresJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(scoresJson);
        decoded.forEach((k, v) {
          _levelHighScores[int.parse(k)] = v as int;
        });
      } catch (_) {}
    }

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

      if (levelId >= unlockedLevel && unlockedLevel < 80) {
        unlockedLevel = levelId + 1;
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

    final starsMap = _levelStars.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString('lululu_level_stars', jsonEncode(starsMap));

    final scoresMap = _levelHighScores.map((k, v) => MapEntry(k.toString(), v));
    await prefs.setString('lululu_level_scores', jsonEncode(scoresMap));

    notifyListeners();
  }

  Future<bool> buyBooster(String type, int cost) async {
    if (coins < cost) return false;
    coins -= cost;
    if (type == 'aydinlat') {
      aydinlatCount++;
    } else if (type == 'slipper') {
      slipperCount += 2;
    } else if (type == 'spray') {
      sprayCount += 2;
    }

    await _persistEconomy();
    notifyListeners();
    return true;
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
    if (amount <= 0) return;
    coins += amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_coins', coins);
    notifyListeners();
  }

  /// Arcade mode drip (Terlik Tap bonuses) — real vault economy, not stub.
  Future<void> grantArcadeDrop({
    int coins = 0,
    int slipper = 0,
    int spray = 0,
  }) async {
    if (coins <= 0 && slipper <= 0 && spray <= 0) return;
    if (coins > 0) this.coins += coins;
    if (slipper > 0) slipperCount += slipper;
    if (spray > 0) sprayCount += spray;
    await _persistEconomy();
    notifyListeners();
  }

  /// Persist booster counts after in-match use (shop buy already saves).
  Future<void> persistBoosters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_spray', sprayCount);
    await prefs.setInt('lululu_slipper', slipperCount);
    await prefs.setInt('lululu_aydinlat', aydinlatCount);
  }

  Future<void> _persistEconomy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_coins', coins);
    await prefs.setInt('lululu_spray', sprayCount);
    await prefs.setInt('lululu_slipper', slipperCount);
    await prefs.setInt('lululu_aydinlat', aydinlatCount);
    await prefs.setString('lululu_shop_chest_day', shopChestDay);
    await prefs.setString('lululu_limited_drop_day', limitedDropDay);
  }
}
