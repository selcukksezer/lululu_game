import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'cloud_sync_service.dart';
import 'daily_challenge_service.dart';
import 'progress_manager.dart';

enum LeaderboardCategory {
  turkeyTop100,
  global,
  total11Modes,
}

/// Per-mode high scores bound to real player IDs (local vault + optional cloud),
/// plus dynamic Turkey Top 100, Global, and 11-Mode Total rankings.
class LeaderboardService extends ChangeNotifier {
  LeaderboardService._();
  static final LeaderboardService instance = LeaderboardService._();

  static const String prefsKey = 'LululuLeaderboardV3';
  static const String legacyPrefsKey = 'LululuLeaderboardV2';
  static const int maxTop = 100;

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
  static const String modeYuva = 'yuva_defense';

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
    modeYuva,
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
    modeYuva: 'Yuva Savunması',
  };

  /// Mod bazlı makul üst sınır kontrolü (anti-cheat ceiling) — TEK KAYNAK
  /// [ProgressManager.modeScoreCeilings]'tedir (S1#35). Bu sınıf tabloyu
  /// ve doğrulamayı oraya delege eder; kendi kopyasını tutmaz. Böylece
  /// [submitScore] ile `ProgressManager.recordModeScore` aynı tavanı
  /// kullanır ve iki depo ayrışamaz. Tavan değişmezleri (rules +
  /// `CloudSyncService` uyumu, Suika 250.000, toplam ≤ 5.500.000) tablonun
  /// başındaki belgede yazılıdır.
  ///
  /// Tavanlar "ulaşılabilir en yüksek skor" değil, hileye karşı makullük
  /// sınırıdır: [submitScore] üstündeki skorları reddeder,
  /// [_rebindCurrentUserBests] yüklü veriden atar.
  static const int defaultMaxScoreCeiling = ProgressManager.maxValidModeScore;
  static const Map<String, int> modeScoreCeilings =
      ProgressManager.modeScoreCeilings;

  /// Verilen mod için geçerli üst skor sınırını döner (her zaman ≤ 500.000,
  /// rules skor sınırıyla uyumlu). [ProgressManager.ceilingForMode] delege edilir.
  static int ceilingForMode(String modeId) =>
      ProgressManager.ceilingForMode(modeId);

  /// Skorun pozitif ve modun anti-cheat tavanı içinde olup olmadığını doğrular.
  /// [ProgressManager.isScoreValidForMode] delege edilir.
  static bool isScoreValidForMode(String modeId, int score) =>
      ProgressManager.isScoreValidForMode(modeId, score);

  /// Canonicalizes mode aliases (e.g. 'balloon' -> 'balloon_pop', 'grid2048' -> 'grid_2048').
  static String normalizeModeId(String modeId) {
    switch (modeId.trim().toLowerCase()) {
      case 'grid2048':
      case '2048':
      case 'grid_2048':
        return mode2048;
      case 'balloon':
      case 'balloon_pop':
        return modeBalloon;
      case 'connect':
      case 'connect_pop':
        return modeConnect;
      case 'stack':
      case 'stack_drop':
        return modeStack;
      case 'scream':
      case 'scream_roach':
        return modeScream;
      case 'makara':
        return modeMakarayiz;
      case 'terlik':
      case 'terlik_tap':
        return modeTerlik;
      case 'yuva':
      case 'yuva_defense':
        return modeYuva;
      default:
        return modeId.trim().toLowerCase();
    }
  }

  LeaderboardData _data = LeaderboardData(modes: []);
  bool _loaded = false;

  /// Devam eden `load()` çağrısı (uçuş koruması): eşzamanlı
  /// `load()`/`ensureLoaded()` çağrıları aynı yüklemeyi paylaşır.
  Future<void>? _loadFuture;

  /// Bulut üst-sıralama önbelleğinin tazelik süresi (mod başına). Süre
  /// içinde tekrar istenen mod buluta sorulmaz; tahtadaki (yerel +
  /// kalıcı) eski sonuç kullanılır. `force: true` önbelleği atlar.
  static const Duration cloudTopCacheTtl = Duration(seconds: 60);

  /// Mod başına son bulut çekme denemesi zamanı (yalnız bellek içi;
  /// tahtaların kendisi `_data` içinde kalıcı önbellektir).
  final Map<String, DateTime> _lastCloudFetchAt = {};

  LeaderboardCategory _activeCategory = LeaderboardCategory.turkeyTop100;

  LeaderboardCategory get activeCategory => _activeCategory;
  void setCategory(LeaderboardCategory category) {
    if (_activeCategory == category) return;
    _activeCategory = category;
    notifyListeners();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Kalıcı tahtayı yükler. Eşzamanlı çağrılar aynı yüklemeyi
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

  /// Hesap silme için yerel liderlik önbelleğini temizler (hesap-silme,
  /// yerel-temizlik): tahtalar + bulut çekme zamanları bellekten
  /// silinir, kalıcı anahtarlar (güncel + eski) kaldırılır. Bulut
  /// skorları silinmez (sunucu tarafı silme işi AuthService.deleteAccount
  /// dokümantasyonundadır).
  Future<void> clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    await prefs.remove(legacyPrefsKey);
    _data = LeaderboardData(modes: []);
    _lastCloudFetchAt.clear();
    notifyListeners();
  }

  /// Drop V2 seeded NPC names — keep only real / local-player rows in raw mode boards.
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
    ProgressManager.instance.modeHighScores.clear();
    for (final board in _data.modes) {
      board.top.removeWhere(
        (e) => !isScoreValidForMode(board.modeId, e.score),
      );
      var best = 0;
      for (final e in board.top) {
        final mine = e.playerId == uid ||
            (e.playerId.isEmpty && (e.isLocalPlayer || e.playerName == name));
        if (mine) {
          e.isLocalPlayer = true;
          e.playerId = uid;
          if (e.score > best) best = e.score;
        } else {
          e.isLocalPlayer = false;
        }
      }
      board.bestScore = best;
      if (best > 0) {
        ProgressManager.instance.modeHighScores[normalizeModeId(board.modeId)] =
            best;
      }
    }
  }

  Future<void> onAuthChanged() async {
    await ensureLoaded();
    _rebindCurrentUserBests();
    await _save();
    notifyListeners();
    // Kimlik değişti: önbelleği atla, tüm modları tazele.
    unawaited(refreshFromCloud(force: true));
  }

  /// Pull Firestore tops (when configured) and merge into local boards.
  ///
  /// [onlyModeId] verilirse yalnız o mod buluttan tazelenir; diğer modlar
  /// tahtalarındaki eski (önbellek) sonucu kullanır. `force: false` ise
  /// [cloudTopCacheTtl] içinde çekilmiş modlar atlanır. Parametresiz
  /// çağrı eski davranışı korur: tüm modlar (tazelik süresi dolmuş
  /// olanlar) sırayla tazelenir.
  Future<void> refreshFromCloud({
    String? onlyModeId,
    bool force = false,
  }) async {
    await ensureLoaded();
    await CloudSyncService.instance.enableOnlineWhenSignedIn();
    if (!CloudSyncService.instance.firebaseReady) {
      notifyListeners();
      return;
    }
    final List<String> targetModes;
    if (onlyModeId != null) {
      final canonical = normalizeModeId(onlyModeId);
      // Bilinmeyen modda sorgu yapılmaz (11 sorguluk tam tazelemeye düşme).
      if (!allModeIds.contains(canonical)) {
        notifyListeners();
        return;
      }
      targetModes = [canonical];
    } else {
      targetModes = allModeIds;
    }
    var changed = false;
    for (final modeId in targetModes) {
      if (await _refreshSingleModeFromCloud(modeId, force: force)) {
        changed = true;
      }
    }
    if (changed) {
      _rebindCurrentUserBests();
      await _save();
    }
    notifyListeners();
  }

  /// Yalnız [modeId] modunun bulut üst-sıralamasını tazeler; diğer modlar
  /// eski önbelleği kullanır. Bilinmeyen modda sorgu yapılmaz.
  Future<void> refreshModeFromCloud(
    String modeId, {
    bool force = false,
  }) async {
    await refreshFromCloud(onlyModeId: modeId, force: force);
  }

  /// Tek modun bulut üst-sıralamasını çeker ve tahtaya birleştirir.
  /// Taze önbellek varsa (`force` yoksa) buluta sorulmadan `false` döner.
  /// Birleştirme değişim yaptıysa `true` döner.
  Future<bool> _refreshSingleModeFromCloud(
    String modeId, {
    bool force = false,
  }) async {
    if (!force) {
      final lastFetch = _lastCloudFetchAt[modeId];
      if (lastFetch != null &&
          DateTime.now().difference(lastFetch) < cloudTopCacheTtl) {
        return false;
      }
    }
    final remote = await CloudSyncService.instance.fetchGlobalTop(
      modeId,
      limit: maxTop,
    );
    // fetchGlobalTop hata durumunda da [] döner (fırlatmaz); çekim denemesi
    // önbelleğe yazılır, böylece hata/burst durumunda sorgu yağmuru olmaz.
    // Süre kısadır (60 sn) ve `force: true` atlar.
    _lastCloudFetchAt[modeId] = DateTime.now();
    if (remote.isEmpty) return false;
    final board = _getOrCreate(modeId);
    var changed = false;
    for (final row in remote) {
      final merged = _upsertRemoteEntry(
        board,
        playerId: row.playerId,
        playerName: row.name,
        score: row.score,
      );
      if (merged) changed = true;
    }
    return changed;
  }

  bool _upsertRemoteEntry(
    ModeBoard board, {
    required String playerId,
    required String playerName,
    required int score,
    String country = 'TR',
  }) {
    if (!isScoreValidForMode(board.modeId, score)) return false;
    final uid = AuthService.instance.playerId;
    final id = playerId.isEmpty
        ? 'remote_${playerName.toLowerCase()}'
        : playerId;
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
      existing.country = country;
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
        country: country,
      ),
    );
    return true;
  }

  Future<bool> submitScore(
    String modeId,
    int score, {
    String? playerName,
  }) async {
    final canonicalMode = normalizeModeId(modeId);
    if (!isScoreValidForMode(canonicalMode, score)) return false;
    await ensureLoaded();
    await AuthService.instance.ensureLoaded();

    final board = _getOrCreate(canonicalMode);
    final uid = AuthService.instance.playerId;
    final name = (playerName == null || playerName.isEmpty)
        ? AuthService.instance.displayName
        : playerName;
    var changed = false;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    LeaderboardEntry? mine;
    for (final e in board.top) {
      if (e.playerId == uid ||
          (e.playerId.isEmpty && (e.isLocalPlayer || e.playerName == name))) {
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
          modeId: canonicalMode,
          playerId: uid,
          playerName: name,
          score: score,
          utcTicks: now,
          isLocalPlayer: true,
          country: 'TR',
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

    await ProgressManager.instance.recordModeScore(canonicalMode, score);
    unawaited(
      DailyChallengeService.instance.tryCompleteWithScore(canonicalMode, score),
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
    // Yalnız gönderilen mod tazelenir (tek sorgu, TTL önbellekli); diğer
    // modlar eski önbelleği kullanır. Ateşle-unut: gönderim beklemez.
    unawaited(refreshModeFromCloud(canonicalMode));
    return true;
  }

  int getBest(String modeId) {
    final canonical = normalizeModeId(modeId);
    final b = _find(canonical);
    return b?.bestScore ?? ProgressManager().getModeHighScore(canonical);
  }

  List<LeaderboardEntry> getTop(String modeId, {int n = maxTop}) {
    final b = _find(normalizeModeId(modeId));
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

  /// Toplam 11 mod skoru (oyuncunun tüm 11 moddaki en yüksek skorlarının toplamı).
  int get total11ModesScore {
    var total = 0;
    for (final id in allModeIds) {
      total += getBest(id);
    }
    return total;
  }

  /// Türkiye Top 100 sıralaması (oyuncunun skoru arttıkça dinamik olarak yükselir).
  List<LeaderboardEntry> getTurkeyTop100({int limit = 100, String? modeId}) {
    return _buildCompetitiveLadder(
      category: LeaderboardCategory.turkeyTop100,
      limit: limit.clamp(1, 100),
      modeId: modeId,
    );
  }

  /// Global sıralama (oyuncunun skoru arttıkça dinamik olarak yükselir).
  List<LeaderboardEntry> getGlobalTop({int limit = 100, String? modeId}) {
    return _buildCompetitiveLadder(
      category: LeaderboardCategory.global,
      limit: limit.clamp(1, 100),
      modeId: modeId,
    );
  }

  /// 11 Mod Toplam sıralaması (tüm 11 modun toplam skoruna göre dinamik sıralama).
  List<LeaderboardEntry> get11ModeTotalTop({int limit = 100}) {
    return _buildCompetitiveLadder(
      category: LeaderboardCategory.total11Modes,
      limit: limit.clamp(1, 100),
    );
  }

  List<LeaderboardEntry> _buildCompetitiveLadder({
    required LeaderboardCategory category,
    required int limit,
    String? modeId,
  }) {
    final uid = AuthService.instance.playerId;
    final myName = AuthService.instance.isSignedIn
        ? AuthService.instance.displayName
        : 'SEN · LülüSever';

    final int myDynamicScore;
    if (category == LeaderboardCategory.total11Modes) {
      final sum = total11ModesScore;
      myDynamicScore = sum > 0 ? sum : 7915;
    } else if (modeId != null && modeId.isNotEmpty) {
      final mScore = getBest(modeId);
      myDynamicScore = mScore > 0 ? mScore : 7915;
    } else {
      final best = myBestOverall;
      final sum = total11ModesScore;
      final candidate = sum > best ? sum : best;
      myDynamicScore = candidate > 0 ? candidate : 7915;
    }

    final map = <String, LeaderboardEntry>{};

    // 1. Base ladder entries for Turkey Top 100 / Global / 11-Mode Total
    final seeds = _ladderAnchorsFor(category);
    for (final s in seeds) {
      map[s.playerId] = s;
    }

    // 2. Real local/cloud entries from _data.modes
    if (category == LeaderboardCategory.total11Modes) {
      final totalsByPlayer = <String, int>{};
      final namesByPlayer = <String, String>{};
      for (final m in _data.modes) {
        for (final e in m.top) {
          if (e.playerId == uid || e.isLocalPlayer) continue;
          final key = e.playerId.isNotEmpty ? e.playerId : e.playerName;
          totalsByPlayer[key] = (totalsByPlayer[key] ?? 0) + e.score;
          namesByPlayer[key] = e.playerName;
        }
      }
      totalsByPlayer.forEach((pid, totalScore) {
        map[pid] = LeaderboardEntry(
          modeId: 'total_11',
          playerId: pid,
          playerName: namesByPlayer[pid] ?? 'Oyuncu',
          score: totalScore,
          utcTicks: 0,
          isLocalPlayer: false,
          country: category == LeaderboardCategory.global ? 'GLOBAL' : 'TR',
        );
      });
    } else {
      final targetModes = (modeId != null && modeId.isNotEmpty)
          ? _data.modes.where((m) => m.modeId == normalizeModeId(modeId))
          : _data.modes;
      for (final m in targetModes) {
        for (final e in m.top) {
          if (e.playerId == uid || e.isLocalPlayer) continue;
          final key = e.playerId.isNotEmpty ? e.playerId : e.playerName;
          final prev = map[key];
          if (prev == null || e.score > prev.score) {
            map[key] = LeaderboardEntry(
              modeId: e.modeId,
              playerId: key,
              playerName: e.playerName,
              score: e.score,
              utcTicks: e.utcTicks,
              isLocalPlayer: false,
              country: e.country,
            );
          }
        }
      }
    }

    // 3. Upsert current player's live score
    map[uid] = LeaderboardEntry(
      modeId: modeId != null ? normalizeModeId(modeId) : 'overall',
      playerId: uid,
      playerName: myName,
      score: myDynamicScore,
      utcTicks: DateTime.now().toUtc().millisecondsSinceEpoch,
      isLocalPlayer: true,
      country: 'TR',
    );

    final list = map.values.toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        if (a.isLocalPlayer != b.isLocalPlayer) {
          return a.isLocalPlayer ? -1 : 1;
        }
        return a.utcTicks.compareTo(b.utcTicks);
      });

    return list.take(limit).toList();
  }

  List<LeaderboardEntry> _ladderAnchorsFor(LeaderboardCategory category) {
    const trNames = <(String, String, int, int)>[
      ('tr_1', 'KongoKralı', 11204, 7),
      ('tr_2', 'HamamCan_34', 9310, 6),
      ('tr_3', 'DivaNur', 8977, 5),
      ('tr_4', 'TerlikUstası', 8540, 4),
      ('tr_5', 'MakaraMehmet', 7402, 3),
      ('tr_6', 'HuniKafa', 6988, 1),
      ('tr_7', 'BilgeDede', 6511, 8),
      ('tr_8', 'PijamaDans_06', 6240, 4),
      ('tr_9', 'TencereÇırak', 5980, 2),
      ('tr_10', 'F16Pilotu_35', 5720, 7),
      ('tr_11', 'AnneTerliği_16', 5490, 5),
      ('tr_12', 'RaidAvcısı', 5210, 6),
      ('tr_13', 'BornozluEfsane', 4980, 8),
      ('tr_14', 'SuikaPrensi', 4750, 3),
      ('tr_15', 'OsmantuşBeyi', 4520, 4),
    ];

    const globalNames = <(String, String, int, String)>[
      ('gl_1', 'TokyoSuika_JP', 14850, 'JP'),
      ('gl_2', 'KongoKralı', 11204, 'TR'),
      ('gl_3', 'RoachMaster_KR', 10890, 'KR'),
      ('gl_4', 'BerlinMerger_DE', 9840, 'DE'),
      ('gl_5', 'HamamCan_34', 9310, 'TR'),
      ('gl_6', 'DivaNur', 8977, 'TR'),
      ('gl_7', 'NeonBug_US', 8720, 'US'),
      ('gl_8', 'TerlikUstası', 8540, 'TR'),
      ('gl_9', 'SambaRoach_BR', 7650, 'BR'),
      ('gl_10', 'MakaraMehmet', 7402, 'TR'),
      ('gl_11', 'HuniKafa', 6988, 'TR'),
      ('gl_12', 'BilgeDede', 6511, 'TR'),
    ];

    final scale = category == LeaderboardCategory.total11Modes ? 3 : 1;
    final out = <LeaderboardEntry>[];

    if (category == LeaderboardCategory.global) {
      for (var i = 0; i < 99; i++) {
        if (i < globalNames.length) {
          final g = globalNames[i];
          out.add(
            LeaderboardEntry(
              modeId: 'global',
              playerId: g.$1,
              playerName: g.$2,
              score: g.$3,
              utcTicks: i + 1,
              country: g.$4,
            ),
          );
        } else {
          final score = (6400 - (i - globalNames.length) * 55).clamp(400, 6400);
          out.add(
            LeaderboardEntry(
              modeId: 'global',
              playerId: 'gl_${i + 1}',
              playerName: 'GlobalOyuncu_${i + 1}',
              score: score,
              utcTicks: i + 1,
              country: i.isEven ? 'GLOBAL' : 'TR',
            ),
          );
        }
      }
      return out;
    }

    for (var i = 0; i < 99; i++) {
      if (i < trNames.length) {
        final t = trNames[i];
        out.add(
          LeaderboardEntry(
            modeId: category == LeaderboardCategory.total11Modes
                ? 'total_11'
                : 'tr_top100',
            playerId: t.$1,
            playerName: t.$2,
            score: t.$3 * scale,
            utcTicks: i + 1,
            country: 'TR',
          ),
        );
      } else {
        final baseScore = (4400 - (i - trNames.length) * 42).clamp(350, 4400);
        out.add(
          LeaderboardEntry(
            modeId: category == LeaderboardCategory.total11Modes
                ? 'total_11'
                : 'tr_top100',
            playerId: 'tr_${i + 1}',
            playerName: 'LülüAvcısı_${i + 1}',
            score: baseScore * scale,
            utcTicks: i + 1,
            country: 'TR',
          ),
        );
      }
    }
    return out;
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
            country: e.country,
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
      if (e.playerId == uid || e.isLocalPlayer || e.playerName == name) {
        return i + 1;
      }
    }
    return null;
  }

  int? getMyModeRank(String modeId, {int n = 50}) {
    final canonical = normalizeModeId(modeId);
    final uid = AuthService.instance.playerId;
    final name = AuthService.instance.displayName;
    final list = getTop(canonical, n: n);
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      if (e.playerId == uid || e.isLocalPlayer || e.playerName == name) {
        return i + 1;
      }
    }
    final best = getBest(canonical);
    if (best <= 0) return null;
    var rank = 1;
    for (final e in list) {
      if (e.score > best) rank++;
    }
    return rank;
  }

  ModeBoard? _find(String modeId) {
    final canonical = normalizeModeId(modeId);
    for (final m in _data.modes) {
      if (normalizeModeId(m.modeId) == canonical) return m;
    }
    return null;
  }

  ModeBoard _getOrCreate(String modeId) {
    final canonical = normalizeModeId(modeId);
    final existing = _find(canonical);
    if (existing != null) return existing;
    final board = ModeBoard(modeId: canonical, bestScore: 0, top: []);
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
    this.country = 'TR',
  });

  String modeId;
  String playerId;
  String playerName;
  int score;
  int utcTicks;
  bool isLocalPlayer;
  String country;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      modeId: json['modeId'] as String? ?? '',
      playerId: json['playerId'] as String? ?? '',
      playerName: json['playerName'] as String? ?? 'Sen',
      score: (json['score'] as num?)?.toInt() ?? 0,
      utcTicks: (json['utcTicks'] as num?)?.toInt() ?? 0,
      isLocalPlayer: json['isLocalPlayer'] as bool? ?? false,
      country: json['country'] as String? ?? 'TR',
    );
  }

  Map<String, dynamic> toJson() => {
        'modeId': modeId,
        'playerId': playerId,
        'playerName': playerName,
        'score': score,
        'utcTicks': utcTicks,
        'isLocalPlayer': isLocalPlayer,
        'country': country,
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
