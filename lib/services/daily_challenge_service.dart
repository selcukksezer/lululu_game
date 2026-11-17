import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'leaderboard_service.dart';
import 'progress_manager.dart';

class DailyMissionSpec {
  final String id;
  final String title;
  final String subtitle;
  final int target;
  final int coinReward;
  final int energyReward;
  final String iconAsset;

  const DailyMissionSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.target,
    required this.coinReward,
    this.energyReward = 0,
    required this.iconAsset,
  });
}

/// Günlük viral challenge + streak / daily reward.
class DailyChallengeService extends ChangeNotifier {
  DailyChallengeService._();
  static final DailyChallengeService instance = DailyChallengeService._();
  factory DailyChallengeService() => instance;

  static const _prefsKey = 'LululuDailyV1';

  bool _loaded = false;

  /// Devam eden `load()` çağrısı (uçuş koruması): eşzamanlı
  /// `load()`/`ensureLoaded()` çağrıları aynı yüklemeyi paylaşır.
  Future<void>? _loadFuture;
  String _dayKey = '';
  String modeId = LeaderboardService.modeOsmantus;
  String modeLabel = 'Osmantuş';
  int targetScore = 5000;
  bool completedToday = false;
  int streak = 0;
  String? lastClaimDay;

  static const List<DailyMissionSpec> defaultMissions = [
    DailyMissionSpec(
      id: 'play',
      title: '3 Oyun Oyna',
      subtitle: 'Herhangi bir modda 3 maç tamamla',
      target: 3,
      coinReward: 150,
      energyReward: 1,
      iconAsset: 'assets/design/ui/icons2/target.png',
    ),
    DailyMissionSpec(
      id: 'merge',
      title: '25 Böcek Birleştir',
      subtitle: 'Suika veya 2048 modunda evrim yap',
      target: 25,
      coinReward: 200,
      energyReward: 1,
      iconAsset: 'assets/design/ui/icons2/paw.png',
    ),
    DailyMissionSpec(
      id: 'combo',
      title: '5x Kombo Yap',
      subtitle: 'Peş peşe hızlı birleşim yakala',
      target: 5,
      coinReward: 250,
      energyReward: 2,
      iconAsset: 'assets/design/ui/icons2/bolt.png',
    ),
    DailyMissionSpec(
      id: 'video',
      title: 'Stüdyoya Göz At',
      subtitle: 'Böcek Stüdyosu veya GIF vitrinini ziyaret et',
      target: 1,
      coinReward: 120,
      energyReward: 1,
      iconAsset: 'assets/design/ui/icons2/star.png',
    ),
  ];

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
    final best = bestTowardTarget;
    if (targetScore <= 0) return 0;
    return (best / targetScore).clamp(0.0, 1.0);
  }

  int get bestTowardTarget {
    final lbBest = LeaderboardService.instance.getBest(modeId);
    final pmBest = ProgressManager.instance.getModeHighScore(modeId);
    return max(lbBest, pmBest);
  }

  /// Estimated coin reward for today's claim.
  int get nextClaimRewardCoins {
    if (!canClaimToday) {
      return 40 + max(1, streak) * 15 + (completedToday ? 80 : 0);
    }
    // Seri kuralı: son talep dün değilse seri sıfırlanır
    // (yeni seri 1'den başlar); aksi hâlde seri bir artar.
    final nextStreak = lastClaimDay == _dayKeyOffset(-1) ? streak + 1 : 1;
    return 40 + nextStreak * 15 + (completedToday ? 80 : 0);
  }

  String get formattedTimeLeft {
    final left = timeLeft;
    final hh = left.inHours.clamp(0, 99).toString().padLeft(2, '0');
    final mm = (left.inMinutes % 60).clamp(0, 59).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Kalıcı günlük görevi yükler. Eşzamanlı çağrılar aynı yüklemeyi
  /// paylaşır (uçuş koruması); yükleme bittikten sonra yeniden
  /// çağrılırsa prefs'ten tekrar okur (yeniden yükleme korunur).
  Future<void> load() async {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadAsync();
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  Future<void> _loadAsync() async {
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
    final end = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 1),
    );
    return end.difference(now);
  }

  Future<bool> tryCompleteWithScore(String playedModeId, int score) async {
    await ensureLoaded();
    // 'play' görevi burada kaydedilmez: tek kayıt noktası tur-bitirme
    // yardımcısıdır (finish_run.dart, recordPlayTask varsayılanı true).
    // Bu metot skor gönderimi başına (hatta Çığlık Böcek'te her çığlıkta)
    // çağrıldığı için buradaki kayıt '3 Oyun Oyna' görevini tek turda
    // dolduruyordu.
    if (completedToday) return false;
    final normalizedPlayed = ProgressManager.normalizeModeId(playedModeId);
    final normalizedTarget = ProgressManager.normalizeModeId(modeId);
    if (normalizedPlayed != normalizedTarget && playedModeId != modeId) {
      return false;
    }
    if (score < targetScore) return false;
    completedToday = true;
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    await prefs.setBool('${_prefsKey}_done_$today', true);
    notifyListeners();
    return true;
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
