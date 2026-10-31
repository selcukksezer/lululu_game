import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'leaderboard_service.dart';
import 'progress_manager.dart';

/// Günlük viral challenge + streak / daily reward.
class DailyChallengeService extends ChangeNotifier {
  DailyChallengeService._();
  static final instance = DailyChallengeService._();

  static const _prefsKey = 'LululuDailyV1';

  bool _loaded = false;
  String _dayKey = '';
  String modeId = LeaderboardService.modeOsmantus;
  String modeLabel = 'Osmantuş';
  int targetScore = 5000;
  bool completedToday = false;
  int streak = 0;
  String? lastClaimDay;

  static const _rotation = <(String id, String label, int target)>[
    (LeaderboardService.modeOsmantus, 'Osmantuş', 5000),
    (LeaderboardService.modeScream, 'Çığlık Böcek', 3500),
    (LeaderboardService.modeSuika, 'Suika Arena', 8000),
    (LeaderboardService.modeBalloon, 'Balon Patlat', 4000),
    (LeaderboardService.modeMatch3, 'Match 3', 4500),
    (LeaderboardService.modeTerlik, 'Terlik Tap', 3000),
  ];

  /// Best progress toward today's target (0–1).
  double get progressTowardTarget {
    final best = LeaderboardService.instance.getBest(modeId);
    if (targetScore <= 0) return 0;
    return (best / targetScore).clamp(0.0, 1.0);
  }

  int get bestTowardTarget => LeaderboardService.instance.getBest(modeId);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    _dayKey = prefs.getString('${_prefsKey}_day') ?? '';
    streak = prefs.getInt('${_prefsKey}_streak') ?? 0;
    lastClaimDay = prefs.getString('${_prefsKey}_lastClaim');
    completedToday = prefs.getBool('${_prefsKey}_done_$today') ?? false;

    if (_dayKey != today) {
      _dayKey = today;
      completedToday = false;
      final seed = today.hashCode;
      final pick = _rotation[Random(seed).nextInt(_rotation.length)];
      modeId = pick.$1;
      modeLabel = pick.$2;
      targetScore = pick.$3;
      await prefs.setString('${_prefsKey}_day', today);
      await prefs.setString('${_prefsKey}_modeId', modeId);
      await prefs.setString('${_prefsKey}_modeLabel', modeLabel);
      await prefs.setInt('${_prefsKey}_target', targetScore);
    } else {
      modeId = prefs.getString('${_prefsKey}_modeId') ?? modeId;
      modeLabel = prefs.getString('${_prefsKey}_modeLabel') ?? modeLabel;
      targetScore = prefs.getInt('${_prefsKey}_target') ?? targetScore;
    }
    _loaded = true;
    notifyListeners();
  }

  String get headline => 'Bugün $modeLabel · $targetScore puan';

  Duration get timeLeft {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return end.difference(now);
  }

  Future<bool> tryCompleteWithScore(String playedModeId, int score) async {
    await ensureLoaded();
    if (completedToday) return false;
    if (playedModeId != modeId) return false;
    if (score < targetScore) return false;
    completedToday = true;
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    await prefs.setBool('${_prefsKey}_done_$today', true);
    notifyListeners();
    return true;
  }

  /// Günlük ödül + streak. Challenge tamam zorunlu değil; giriş ödülü.
  Future<int> claimDailyReward() async {
    await ensureLoaded();
    final today = _todayKey();
    if (lastClaimDay == today) return 0;

    final yesterday = _dayKeyOffset(-1);
    if (lastClaimDay == yesterday) {
      streak += 1;
    } else {
      streak = 1;
    }
    lastClaimDay = today;

    var coins = 40 + streak * 15;
    if (completedToday) coins += 80;
    await ProgressManager().addCoins(coins);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefsKey}_streak', streak);
    await prefs.setString('${_prefsKey}_lastClaim', today);
    notifyListeners();
    return coins;
  }

  bool get canClaimToday {
    return lastClaimDay != _todayKey();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  String _dayKeyOffset(int days) {
    final n = DateTime.now().add(Duration(days: days));
    return '${n.year}-${n.month}-${n.day}';
  }
}
