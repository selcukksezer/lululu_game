import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'cloud_sync_service.dart';
import 'daily_challenge_service.dart';

/// Per-mode high scores bound to real player IDs (local vault + optional cloud).
class LeaderboardService extends ChangeNotifier {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  static const String prefsKey = 'LululuLeaderboardV3';
  static const String legacyPrefsKey = 'LululuLeaderboardV2';
  static const int maxTop = 50;

  static const String modeSuika = 'suika';
  static const String mode2048 = 'grid_2048';
  static const String modeBalloon = 'balloon_pop';
  static const String modeMatch3 = 'match3';
  static const String modeConnect = 'connect_pop';
  static const String modeStack = 'stack_drop';
  static const String modeOsmantus = 'osmantus';
  static const String modeScream = 'scream_roach';
  static const String modeMakarayiz = 'makarayiz';
  static const String modeTerlik = 'terlik_tap';

  static const List<String> allModeIds = [
    modeSuika,
    mode2048,
    modeBalloon,
    modeMatch3,
    modeConnect,
    modeStack,
    modeOsmantus,
    modeScream,
    modeMakarayiz,
    modeTerlik,
  ];

  static const Map<String, String> modeDisplayNames = {
    modeSuika: 'Suika Arena',
    mode2048: 'Lululu 2048',
    modeBalloon: 'Balon Patlat',
    modeMatch3: 'Match-3',
    modeConnect: 'Bagla-Patlat',
    modeStack: 'Stack Drop',
    modeOsmantus: 'Osmantuş',
    modeScream: 'Çığlık Böcek',
    modeMakarayiz: 'Makarayız',
    modeTerlik: 'Terlik Tap',
  };

  LeaderboardData _data = LeaderboardData(modes: []);
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(prefsKey);
    if (json == null || json.isEmpty) {
      final legacy = prefs.getString(legacyPrefsKey);
      if (legacy != null && legacy.isNotEmpty) {
        try {
          _data = LeaderboardData.fromJson(
            jsonDecode(legacy) as Map<String, dynamic>,
          );
          _stripFakeSeededRivals();
          await _save();
          await prefs.remove(legacyPrefsKey);
        } catch (_) {
          _data = LeaderboardData(modes: []);
        }
      } else {
        _data = LeaderboardData(modes: []);
      }
    } else {
      try {
        _data = LeaderboardData.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      } catch (_) {
        _data = LeaderboardData(modes: []);
      }
    }
    _rebindCurrentUserBests();
    _loaded = true;
    notifyListeners();
  }

  /// Drop V2 seeded NPC names — keep only real / local-player rows.
  void _stripFakeSeededRivals() {
    const seeded = {
      'KongoReis',
      'DivaHamam',
      'MakarayızAbi',
      'LululuFan',
      'TerlikKing',
      'RaidSprey',
      'PikoPro',
      'MutfakBoss',
      'BöcekDiva',
      'SuikaAce',
      'BalonSniper',
      'MatchQueen',
      'StackNinja',
      'ConnectGod',
      'NeonRoach',
    };
    for (final board in _data.modes) {
      board.top.removeWhere(
        (e) => !e.isLocalPlayer && seeded.contains(e.playerName),
      );
      for (final e in board.top) {
        if (e.playerId.isEmpty && e.isLocalPlayer) {
          e.playerId = AuthService.instance.playerId;
        }
      }
    }
  }

  /// Recompute each mode's bestScore for the signed-in player.
  void _rebindCurrentUserBests() {
    final uid = AuthService.instance.playerId;
    final name = AuthService.instance.displayName;
    for (final board in _data.modes) {
      var best = 0;
      for (final e in board.top) {
        final mine = e.playerId == uid ||
            (e.playerId.isEmpty &&
                (e.isLocalPlayer || e.playerName == name));
        if (mine) {
          e.isLocalPlayer = true;
          e.playerId = uid;
          if (e.score > best) best = e.score;
        } else {
          e.isLocalPlayer = false;
        }
      }
      board.bestScore = best;
    }
  }

  Future<void> onAuthChanged() async {
    await ensureLoaded();
    _rebindCurrentUserBests();
    await _save();
    notifyListeners();
    unawaited(refreshFromCloud());
  }

  /// Pull Firestore tops (when configured) and merge into local boards.
  Future<void> refreshFromCloud() async {
    await ensureLoaded();
    await CloudSyncService.instance.enableOnlineWhenSignedIn();
    if (!CloudSyncService.instance.firebaseReady) {
      notifyListeners();
      return;
    }
    var changed = false;
    for (final modeId in allModeIds) {
      final remote = await CloudSyncService.instance.fetchGlobalTop(
        modeId,
        limit: maxTop,
      );
      if (remote.isEmpty) continue;
      final board = _getOrCreate(modeId);
      for (final row in remote) {
        final merged = _upsertRemoteEntry(
          board,
          playerId: row.playerId,
          playerName: row.name,
          score: row.score,
        );
        if (merged) changed = true;
      }
    }
    if (changed) {
      _rebindCurrentUserBests();
      await _save();
    }
    notifyListeners();
  }

  bool _upsertRemoteEntry(
    ModeBoard board, {
    required String playerId,
    required String playerName,
    required int score,
  }) {
    if (score <= 0) return false;
    final uid = AuthService.instance.playerId;
    final id = playerId.isEmpty ? 'remote_${playerName.toLowerCase()}' : playerId;
    LeaderboardEntry? existing;
    for (final e in board.top) {
      if (e.playerId == id ||
          (e.playerId.isEmpty && e.playerName == playerName)) {
        existing = e;
        break;
      }
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (existing != null) {
      if (score <= existing.score) return false;
      existing.score = score;
      existing.playerName = playerName;
      existing.playerId = id;
      existing.utcTicks = now;
      existing.isLocalPlayer = id == uid;
      return true;
    }
    board.top.add(
      LeaderboardEntry(
        modeId: board.modeId,
        playerId: id,
        playerName: playerName,
        score: score,
        utcTicks: now,
        isLocalPlayer: id == uid,
      ),
    );
    return true;
  }

  Future<bool> submitScore(
    String modeId,
    int score, {
    String? playerName,
  }) async {
    if (modeId.isEmpty || score <= 0) return false;
    await ensureLoaded();
    await AuthService.instance.ensureLoaded();

    final board = _getOrCreate(modeId);
    final uid = AuthService.instance.playerId;
    final name = (playerName == null || playerName.isEmpty)
        ? AuthService.instance.displayName
        : playerName;
    var changed = false;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    LeaderboardEntry? mine;
    for (final e in board.top) {
      if (e.playerId == uid ||
          (e.playerId.isEmpty &&
              (e.isLocalPlayer || e.playerName == name))) {
        mine = e;
        break;
      }
    }

    if (mine != null) {
      if (score > mine.score) {
        mine.score = score;
        mine.utcTicks = now;
        mine.playerName = name;
        mine.playerId = uid;
        mine.isLocalPlayer = true;
        changed = true;
      }
    } else {
      board.top.add(
        LeaderboardEntry(
          modeId: modeId,
          playerId: uid,
          playerName: name,
          score: score,
          utcTicks: now,
          isLocalPlayer: true,
        ),
      );
      changed = true;
    }

    if (score > board.bestScore) {
      board.bestScore = score;
      changed = true;
    } else if (mine != null || changed) {
      // Keep bestScore as this user's personal best for current session.
      var personal = 0;
      for (final e in board.top) {
        if (e.playerId == uid && e.score > personal) personal = e.score;
      }
      board.bestScore = personal;
    }

    unawaited(
      DailyChallengeService.instance.tryCompleteWithScore(modeId, score),
    );
    unawaited(CloudSyncService.instance.enqueueLeaderboardPush());

    if (!changed) return false;

    board.top.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.utcTicks.compareTo(b.utcTicks);
    });
    if (board.top.length > maxTop) {
      board.top.removeRange(maxTop, board.top.length);
    }

    await _save();
    notifyListeners();
    return true;
  }

  int getBest(String modeId) {
    final b = _find(modeId);
    return b?.bestScore ?? 0;
  }

  List<LeaderboardEntry> getTop(String modeId, {int n = maxTop}) {
    final b = _find(modeId);
    if (b == null || b.top.isEmpty) return [];
    final take = n.clamp(1, maxTop);
    return b.top.take(take).toList();
  }

  List<({String modeId, String display, int best})> getAllModeBests() {
    return allModeIds.map((id) {
      final display = modeDisplayNames[id] ?? id;
      return (modeId: id, display: display, best: getBest(id));
    }).toList();
  }

  List<LeaderboardEntry> getOverallTop({int n = 50}) {
    final cap = n.clamp(1, maxTop * allModeIds.length);
    // Best score per player across modes (real users only).
    final byPlayer = <String, LeaderboardEntry>{};
    for (final m in _data.modes) {
      for (final e in m.top) {
        final key = e.playerId.isNotEmpty ? e.playerId : e.playerName;
        final prev = byPlayer[key];
        if (prev == null || e.score > prev.score) {
          byPlayer[key] = LeaderboardEntry(
            modeId: e.modeId,
            playerId: e.playerId,
            playerName: e.playerName,
            score: e.score,
            utcTicks: e.utcTicks,
            isLocalPlayer: e.isLocalPlayer,
          );
        }
      }
    }
    final all = byPlayer.values.toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.utcTicks.compareTo(b.utcTicks);
      });
    return all.take(cap).toList();
  }

  int get myBestOverall {
    final uid = AuthService.instance.playerId;
    var best = 0;
    for (final m in _data.modes) {
      if (m.bestScore > best) best = m.bestScore;
      for (final e in m.top) {
        if ((e.playerId == uid || e.isLocalPlayer) && e.score > best) {
          best = e.score;
        }
      }
    }
    return best;
  }

  int? getMyOverallRank({int n = 50}) {
    final uid = AuthService.instance.playerId;
    final name = AuthService.instance.displayName;
    final list = getOverallTop(n: n);
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e.playerId == uid ||
          e.isLocalPlayer ||
          e.playerName == name) {
        return i + 1;
      }
    }
    return null;
  }

  int? getMyModeRank(String modeId, {int n = 50}) {
    final uid = AuthService.instance.playerId;
    final name = AuthService.instance.displayName;
    final list = getTop(modeId, n: n);
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e.playerId == uid ||
          e.isLocalPlayer ||
          e.playerName == name) {
        return i + 1;
      }
    }
    final best = getBest(modeId);
    if (best <= 0) return null;
    var rank = 1;
    for (final e in list) {
      if (e.score > best) rank++;
    }
    return rank;
  }

  ModeBoard? _find(String modeId) {
    for (final m in _data.modes) {
      if (m.modeId == modeId) return m;
    }
    return null;
  }

  ModeBoard _getOrCreate(String modeId) {
    final existing = _find(modeId);
    if (existing != null) return existing;
    final board = ModeBoard(modeId: modeId, bestScore: 0, top: []);
    _data.modes.add(board);
    return board;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(_data.toJson()));
  }
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.modeId,
    this.playerId = '',
    this.playerName = 'Sen',
    required this.score,
    required this.utcTicks,
    this.isLocalPlayer = false,
  });

  String modeId;
  String playerId;
  String playerName;
  int score;
  int utcTicks;
  bool isLocalPlayer;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      modeId: json['modeId'] as String? ?? '',
      playerId: json['playerId'] as String? ?? '',
      playerName: json['playerName'] as String? ?? 'Sen',
      score: (json['score'] as num?)?.toInt() ?? 0,
      utcTicks: (json['utcTicks'] as num?)?.toInt() ?? 0,
      isLocalPlayer: json['isLocalPlayer'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'modeId': modeId,
        'playerId': playerId,
        'playerName': playerName,
        'score': score,
        'utcTicks': utcTicks,
        'isLocalPlayer': isLocalPlayer,
      };
}

class ModeBoard {
  ModeBoard({
    required this.modeId,
    required this.bestScore,
    required this.top,
  });

  String modeId;
  int bestScore;
  List<LeaderboardEntry> top;

  factory ModeBoard.fromJson(Map<String, dynamic> json) {
    final rawTop = json['top'] as List<dynamic>? ?? [];
    return ModeBoard(
      modeId: json['modeId'] as String? ?? '',
      bestScore: (json['bestScore'] as num?)?.toInt() ?? 0,
      top: rawTop
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'modeId': modeId,
        'bestScore': bestScore,
        'top': top.map((e) => e.toJson()).toList(),
      };
}

class LeaderboardData {
  LeaderboardData({required this.modes});

  List<ModeBoard> modes;

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    final raw = json['modes'] as List<dynamic>? ?? [];
    return LeaderboardData(
      modes: raw
          .map((e) => ModeBoard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'modes': modes.map((m) => m.toJson()).toList(),
      };
}
