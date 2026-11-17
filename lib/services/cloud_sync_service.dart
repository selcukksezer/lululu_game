import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'bug_video_service.dart';
import 'chat_service.dart';
import 'energy_service.dart';
import 'firebase_bootstrap.dart';
import 'leaderboard_service.dart';
import 'progress_manager.dart';

/// Online sync — Firestore when Firebase ready; else durable local queue
/// with HMAC-SHA256 integrity verification and anti-cheat bounds enforcement.
class CloudSyncService extends ChangeNotifier {
  CloudSyncService._();
  static final instance = CloudSyncService._();

  static const _queueKey = 'LululuCloudQueueV1';
  static const _signedQueueKey = 'LululuCloudSignedQueueV1';
  static const _integritySecret = 'lululu_cloud_integrity_v2_hmac_key_2026';

  /// Anti-cheat bounds for cloud & offline sync payloads.
  static const int maxValidModeScore = 10000000;
  static const int maxValidCoins = 50000000;
  static const int maxValidEnergy = 999;
  static const int maxValidBoosterCount = 9999;
  static const int maxValidTier = 20;
  static const int maxValidStreak = 3650;
  static const int maxValidStars = ProgressManager.maxCampaignLevels * 3;

  bool onlineEnabled = false;
  String status = 'Yerel · bulut kuyruğu hazır';
  final List<String> pending = [];
  bool get firebaseReady => FirebaseBootstrap.ready;
  bool get isAvailable => FirebaseBootstrap.isAvailable;

  /// Constant-time string comparison for integrity hashes.
  static bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    var diff = aBytes.length ^ bBytes.length;
    final maxLen = max(aBytes.length, bBytes.length);
    for (var i = 0; i < maxLen; i++) {
      final byteA = i < aBytes.length ? aBytes[i] : 0;
      final byteB = i < bBytes.length ? bBytes[i] : 0;
      diff |= byteA ^ byteB;
    }
    return diff == 0;
  }

  /// Canonical JSON serializer (sorted keys, skips transient `updatedAt` and `integrityHash`).
  static Object? _canonicalize(Object? value) {
    if (value == null || value is num || value is String || value is bool) {
      return value;
    }
    if (value is Iterable) {
      return value.map(_canonicalize).toList();
    }
    if (value is Map) {
      final sortedKeys = value.keys
          .map((k) => k.toString())
          .where((k) => k != 'integrityHash' && k != 'updatedAt')
          .toList()
        ..sort();
      final result = <String, Object?>{};
      for (final k in sortedKeys) {
        final v = value[k];
        if (v is FieldValue) continue;
        result[k] = _canonicalize(v);
      }
      return result;
    }
    return value.toString();
  }

  /// Computes deterministic HMAC-SHA256 `integrityHash` for a cloud or offline payload.
  String computeIntegrityHash(Map<String, dynamic> payload) {
    final canonical = _canonicalize(payload);
    final encoded = jsonEncode(canonical);
    final hmac = Hmac(sha256, utf8.encode(_integritySecret));
    return hmac.convert(utf8.encode(encoded)).toString();
  }

  /// Verifies the `integrityHash` of a payload in constant time.
  bool verifyIntegrityHash(
    Map<String, dynamic> payload, {
    bool allowUnsignedLegacy = false,
  }) {
    final rawSig = payload['integrityHash'];
    if (rawSig is! String || rawSig.isEmpty) {
      return allowUnsignedLegacy;
    }
    final expected = computeIntegrityHash(payload);
    return _constantTimeEquals(rawSig, expected);
  }

  /// Returns true if [score] is within valid anti-cheat bounds.
  static bool isValidScore(num? score) {
    if (score == null || score.isNaN || score.isInfinite) return false;
    final intVal = score.toInt();
    return intVal > 0 && intVal <= maxValidModeScore;
  }

  /// Validates and clamps a mode score; returns 0 if negative or above [maxValidModeScore].
  static int sanitizeModeScore(num? rawScore) {
    if (!isValidScore(rawScore)) return 0;
    return rawScore!.toInt().clamp(0, maxValidModeScore);
  }

  /// Validates and clamps a non-negative integer within `[minVal, maxVal]`.
  /// Rejects negative or excessive numbers when [rejectOutOfBounds] is true.
  static int? _validateBoundedInt(
    Object? raw, {
    required int minVal,
    required int maxVal,
    bool rejectOutOfBounds = false,
  }) {
    if (raw is! num || raw.isNaN || raw.isInfinite) return null;
    final val = raw.toInt();
    if (rejectOutOfBounds && (val < minVal || val > maxVal)) {
      return null;
    }
    return val.clamp(minVal, maxVal);
  }

  /// Builds a sanitized, bounds-clamped, and HMAC-signed player profile payload.
  Map<String, dynamic> buildSignedProfilePayload({
    String? uid,
    String? displayName,
  }) {
    final pm = ProgressManager();
    final board = LeaderboardService.instance;
    final resolvedUid = uid ?? AuthService.instance.playerId;
    final rawName = displayName ?? AuthService.instance.displayName;
    final safeName = rawName
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    final clampedName = safeName.isEmpty
        ? 'Oyuncu'
        : (safeName.length > 40 ? safeName.substring(0, 40) : safeName);

    final safeCoins = pm.coins.clamp(0, maxValidCoins);
    final safeEnergy = EnergyService.instance.energy.clamp(0, maxValidEnergy);
    final safeLevel =
        pm.unlockedLevel.clamp(1, ProgressManager.maxCampaignLevels);
    final safeStars = pm.totalStars.clamp(0, maxValidStars);
    final safeF16 = pm.f16Count.clamp(0, maxValidBoosterCount);
    final safeRaid = pm.raidCount.clamp(0, maxValidBoosterCount);
    final safeTerlik = pm.terlikCount.clamp(0, maxValidBoosterCount);
    final safeStreak = pm.streak.clamp(1, maxValidStreak);

    final safeTiers = pm.unlockedTiers
        .where((t) => t >= 1 && t <= maxValidTier)
        .toSet()
      ..add(1);
    final sortedTiers = safeTiers.toList()..sort();

    final safeExtraPowers = <String, int>{};
    final sortedPowerKeys = pm.extraPowers.keys.toList()..sort();
    for (final k in sortedPowerKeys) {
      final v = pm.extraPowers[k] ?? 0;
      if (v > 0) {
        safeExtraPowers[k] = v.clamp(0, maxValidBoosterCount);
      }
    }

    final safeModeScores = <String, int>{};
    var computedTotal11 = 0;
    var computedBestOverall = 0;
    for (final modeId in LeaderboardService.allModeIds) {
      final best = max(
        sanitizeModeScore(board.getBest(modeId)),
        sanitizeModeScore(pm.getModeHighScore(modeId)),
      );
      safeModeScores[modeId] = best;
      computedTotal11 += best;
      if (best > computedBestOverall) {
        computedBestOverall = best;
      }
    }

    final payload = <String, dynamic>{
      'uid': resolvedUid,
      'displayName': clampedName,
      'country': 'TR',
      'coins': safeCoins,
      'energy': safeEnergy,
      'unlockedLevel': safeLevel,
      'totalStars': safeStars,
      'total11ModesScore': computedTotal11,
      'bestOverallScore': computedBestOverall,
      'f16Count': safeF16,
      'raidCount': safeRaid,
      'terlikCount': safeTerlik,
      'extraPowers': safeExtraPowers,
      'streak': safeStreak,
      'unlockedTiers': sortedTiers,
      'modeHighScores': safeModeScores,
    };
    payload['integrityHash'] = computeIntegrityHash(payload);
    return payload;
  }

  /// Builds a sanitized, bounds-validated, and HMAC-signed mode score payload.
  Map<String, dynamic>? buildSignedModeScorePayload({
    required String uid,
    required String modeId,
    required int score,
    required String displayName,
    String country = 'TR',
  }) {
    final canonicalMode = LeaderboardService.normalizeModeId(modeId);
    if (canonicalMode.isEmpty || !isValidScore(score)) {
      return null;
    }
    final safeScore = sanitizeModeScore(score);
    final safeName = displayName
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    final payload = <String, dynamic>{
      'uid': uid,
      'modeId': canonicalMode,
      'score': safeScore,
      'displayName': safeName.isEmpty ? 'Oyuncu' : safeName,
      'country': country,
    };
    payload['integrityHash'] = computeIntegrityHash(payload);
    return payload;
  }

  /// Validates and conflict-free merges a remote/offline profile snapshot into
  /// [ProgressManager] and [LeaderboardService]. Returns false if rejected by
  /// integrity verification or anti-cheat bounds checks.
  Future<bool> applyVerifiedProfileSnapshot(
    Map<String, dynamic> data, {
    bool allowUnsignedLegacy = false,
  }) async {
    if (!verifyIntegrityHash(data, allowUnsignedLegacy: allowUnsignedLegacy)) {
      debugPrint('[lululu] CloudSync rejected profile: invalid integrityHash');
      return false;
    }

    // Reject payloads containing explicitly negative or absurdly inflated numbers
    final coinsVal = _validateBoundedInt(
      data['coins'],
      minVal: 0,
      maxVal: maxValidCoins,
      rejectOutOfBounds: true,
    );
    if (data.containsKey('coins') && coinsVal == null) {
      return false;
    }

    final energyVal = _validateBoundedInt(
      data['energy'],
      minVal: 0,
      maxVal: maxValidEnergy,
      rejectOutOfBounds: true,
    );
    if (data.containsKey('energy') && energyVal == null) {
      return false;
    }

    final levelVal = _validateBoundedInt(
      data['unlockedLevel'],
      minVal: 1,
      maxVal: ProgressManager.maxCampaignLevels,
      rejectOutOfBounds: true,
    );
    if (data.containsKey('unlockedLevel') && levelVal == null) {
      return false;
    }

    final f16Val = _validateBoundedInt(
      data['f16Count'],
      minVal: 0,
      maxVal: maxValidBoosterCount,
      rejectOutOfBounds: true,
    );
    final raidVal = _validateBoundedInt(
      data['raidCount'],
      minVal: 0,
      maxVal: maxValidBoosterCount,
      rejectOutOfBounds: true,
    );
    final terlikVal = _validateBoundedInt(
      data['terlikCount'],
      minVal: 0,
      maxVal: maxValidBoosterCount,
      rejectOutOfBounds: true,
    );
    if ((data.containsKey('f16Count') && f16Val == null) ||
        (data.containsKey('raidCount') && raidVal == null) ||
        (data.containsKey('terlikCount') && terlikVal == null)) {
      return false;
    }

    final pm = ProgressManager();
    if (coinsVal != null) {
      pm.coins = max(pm.coins, coinsVal).clamp(0, maxValidCoins);
    }
    if (energyVal != null) {
      final mergedEnergy =
          max(EnergyService.instance.energy, energyVal).clamp(0, maxValidEnergy);
      EnergyService.instance.energy = mergedEnergy;
    }
    if (levelVal != null) {
      pm.unlockedLevel = max(pm.unlockedLevel, levelVal)
          .clamp(1, ProgressManager.maxCampaignLevels);
    }
    if (f16Val != null) {
      pm.f16Count = max(pm.f16Count, f16Val).clamp(0, maxValidBoosterCount);
    }
    if (raidVal != null) {
      pm.raidCount = max(pm.raidCount, raidVal).clamp(0, maxValidBoosterCount);
    }
    if (terlikVal != null) {
      pm.terlikCount =
          max(pm.terlikCount, terlikVal).clamp(0, maxValidBoosterCount);
    }

    final streakVal = _validateBoundedInt(
      data['streak'],
      minVal: 1,
      maxVal: maxValidStreak,
    );
    if (streakVal != null) {
      pm.streak = max(pm.streak, streakVal).clamp(1, maxValidStreak);
    }

    final rawTiers = data['unlockedTiers'];
    if (rawTiers is Iterable) {
      for (final t in rawTiers) {
        final parsed = t is num ? t.toInt() : int.tryParse(t.toString());
        if (parsed != null && parsed >= 1 && parsed <= maxValidTier) {
          pm.unlockedTiers.add(parsed);
        }
      }
      pm.unlockedTiers.add(1);
    }

    final rawPowers = data['extraPowers'];
    if (rawPowers is Map) {
      rawPowers.forEach((k, v) {
        final bounded = _validateBoundedInt(
          v,
          minVal: 0,
          maxVal: maxValidBoosterCount,
          rejectOutOfBounds: true,
        );
        if (bounded != null) {
          final key = k.toString();
          pm.extraPowers[key] =
              max(pm.extraPowers[key] ?? 0, bounded).clamp(0, maxValidBoosterCount);
        }
      });
    }

    final rawModeScores = data['modeHighScores'];
    if (rawModeScores is Map) {
      for (final entry in rawModeScores.entries) {
        final modeId = LeaderboardService.normalizeModeId(entry.key.toString());
        final rawSc = entry.value;
        if (rawSc is num && isValidScore(rawSc)) {
          final sc = sanitizeModeScore(rawSc);
          if (sc > (pm.modeHighScores[modeId] ?? 0)) {
            pm.modeHighScores[modeId] = sc;
          }
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_coins', pm.coins);
    await prefs.setInt('LululuCoinBalance', pm.coins);
    await prefs.setInt('lululu_unlocked_level', pm.unlockedLevel);
    await prefs.setInt('lululu_spray', pm.sprayCount);
    await prefs.setInt('lululu_raid', pm.sprayCount);
    await prefs.setInt('lululu_slipper', pm.slipperCount);
    await prefs.setInt('lululu_terlik', pm.slipperCount);
    await prefs.setInt('lululu_aydinlat', pm.aydinlatCount);
    await prefs.setInt('lululu_f16', pm.aydinlatCount);
    await prefs.setInt('lululu_daily_streak', pm.streak);
    await prefs.setStringList(
      'lululu_unlocked_tiers',
      pm.unlockedTiers.map((e) => e.toString()).toList(),
    );
    await prefs.setString('lululu_extra_powers', jsonEncode(pm.extraPowers));
    await prefs.setString(
      'lululu_mode_high_scores',
      jsonEncode(pm.modeHighScores),
    );
    return true;
  }

  Map<String, dynamic> _buildSignedQueueEnvelope(String itemTag) {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final profile = buildSignedProfilePayload();
    final envelope = <String, dynamic>{
      'tag': itemTag,
      'timestamp': nowMs,
      'uid': AuthService.instance.playerId,
      'profile': profile,
    };
    envelope['integrityHash'] = computeIntegrityHash(envelope);
    return envelope;
  }

  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? const [];
    final signedRaw = prefs.getStringList(_signedQueueKey) ?? const [];

    final verifiedTags = <String>[];
    final validSignedRaw = <String>[];

    if (signedRaw.isNotEmpty) {
      for (final itemJson in signedRaw) {
        try {
          final decoded = jsonDecode(itemJson) as Map<String, dynamic>;
          if (!verifyIntegrityHash(decoded)) {
            debugPrint('[lululu] Dropping tampered offline queue item');
            continue;
          }
          final profileMap = decoded['profile'];
          if (profileMap is Map<String, dynamic>) {
            if (!verifyIntegrityHash(profileMap)) {
              debugPrint('[lululu] Dropping tampered offline profile snapshot');
              continue;
            }
          }
          final tag = decoded['tag'] as String? ?? '';
          if (tag.isNotEmpty) {
            verifiedTags.add(tag);
            validSignedRaw.add(itemJson);
          }
        } catch (_) {}
      }
      if (validSignedRaw.length != signedRaw.length) {
        await prefs.setStringList(_signedQueueKey, validSignedRaw);
        await prefs.setStringList(_queueKey, verifiedTags);
      }
    }

    pending
      ..clear()
      ..addAll(signedRaw.isNotEmpty ? verifiedTags : raw);
    status = FirebaseBootstrap.ready
        ? 'Online hazır · ${pending.length} bekleyen'
        : FirebaseBootstrap.playerStatus;
    notifyListeners();
  }

  Future<void> _persistQueue({String? addedTag}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_queueKey, List<String>.from(pending));
    if (pending.isEmpty) {
      await prefs.remove(_signedQueueKey);
      return;
    }
    if (addedTag != null) {
      final existing =
          List<String>.from(prefs.getStringList(_signedQueueKey) ?? const []);
      final envelope = _buildSignedQueueEnvelope(addedTag);
      existing.add(jsonEncode(envelope));
      await prefs.setStringList(_signedQueueKey, existing);
    }
  }

  Future<void> enqueueLeaderboardPush() async {
    await LeaderboardService.instance.ensureLoaded();
    final tag = 'leaderboard:${DateTime.now().millisecondsSinceEpoch}';
    pending.add(tag);
    status = onlineEnabled
        ? 'Sıralama gönderiliyor…'
        : 'Sıralama kuyrukta (online kapalı)';
    await _persistQueue(addedTag: tag);
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  Future<void> enqueueProgressPush() async {
    final tag = 'progress:${DateTime.now().millisecondsSinceEpoch}';
    pending.add(tag);
    status = onlineEnabled
        ? 'İlerleme senkronize ediliyor…'
        : 'İlerleme kuyrukta (online kapalı)';
    await _persistQueue(addedTag: tag);
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  Future<void> enqueueChatPush() async {
    await ChatService.instance.ensureLoaded();
    final tag = 'chat:${DateTime.now().millisecondsSinceEpoch}';
    pending.add(tag);
    status = onlineEnabled ? 'Sohbet sync…' : 'Sohbet kuyrukta (online kapalı)';
    await _persistQueue(addedTag: tag);
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  Future<void> enqueueVideoFeedPush() async {
    await BugVideoService.instance.ensureLoaded();
    final tag = 'videos:${DateTime.now().millisecondsSinceEpoch}';
    pending.add(tag);
    status = onlineEnabled
        ? 'Video feed sync…'
        : 'Video feed kuyrukta (online kapalı)';
    await _persistQueue(addedTag: tag);
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  Future<void> enableOnlineWhenSignedIn() async {
    await AuthService.instance.ensureLoaded();
    await FirebaseBootstrap.ensureInitialized();
    onlineEnabled = AuthService.instance.isSignedIn &&
        !(AuthService.instance.user?.isGuest ?? true);
    status = onlineEnabled
        ? (FirebaseBootstrap.ready
            ? 'Bağlı · senkron açık'
            : 'Hesap var · Firebase bekleniyor (kuyruk aktif)')
        : 'Misafir / yerel — online kapalı';
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  /// Verifies and merges any signed offline snapshots before flushing.
  Future<void> _reconcileOfflineSignedQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final signedRaw = prefs.getStringList(_signedQueueKey) ?? const [];
    if (signedRaw.isEmpty) return;

    final currentUid = AuthService.instance.playerId;
    for (final itemJson in signedRaw) {
      try {
        final decoded = jsonDecode(itemJson) as Map<String, dynamic>;
        if (!verifyIntegrityHash(decoded)) continue;
        final itemUid = decoded['uid'] as String? ?? '';
        final isCompatibleUser = itemUid == currentUid ||
            itemUid == 'guest_local' ||
            itemUid.startsWith('guest_');
        if (!isCompatibleUser) continue;

        final profile = decoded['profile'];
        if (profile is Map<String, dynamic>) {
          await applyVerifiedProfileSnapshot(profile);
        }
      } catch (_) {}
    }
  }

  /// Push queued leaderboard bests and player progress to Firestore.
  Future<int> flushPending() async {
    if (!onlineEnabled) return 0;
    await AuthService.instance.ensureLoaded();
    await _reconcileOfflineSignedQueue();
    final uid = AuthService.instance.playerId;
    final name = AuthService.instance.displayName;
    var flushed = 0;

    if (FirebaseBootstrap.ready) {
      try {
        final db = FirebaseFirestore.instance;
        final bests = LeaderboardService.instance.getAllModeBests();
        final batch = db.batch();
        for (final b in bests) {
          final signedScore = buildSignedModeScorePayload(
            uid: uid,
            modeId: b.modeId,
            score: b.best,
            displayName: name,
          );
          if (signedScore == null) continue;
          final ref = db
              .collection('scores')
              .doc(uid)
              .collection('modes')
              .doc(b.modeId);
          batch.set(
            ref,
            {
              ...signedScore,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          flushed++;
        }
        final signedProfile = buildSignedProfilePayload(
          uid: uid,
          displayName: name,
        );
        final profile = db.collection('players').doc(uid);
        batch.set(
          profile,
          {
            ...signedProfile,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        await batch.commit();
        await _pullRemoteBests(uid);
        await _pullRemoteProfile(uid);
      } catch (e) {
        status = 'Sync hata · kuyruk korunuyor ($e)';
        notifyListeners();
        return 0;
      }
    } else {
      // Local durable ack — keeps UX honest until Firebase defines land.
      flushed = pending.length;
    }

    final n = pending.length;
    pending.clear();
    await _persistQueue();
    status = FirebaseBootstrap.ready
        ? 'Flush tamam · $flushed skor · $n paket'
        : 'Yerel flush · $n paket (Firebase yok)';
    notifyListeners();
    return n;
  }

  Future<void> _pullRemoteBests(String uid) async {
    if (!FirebaseBootstrap.ready) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('scores')
          .doc(uid)
          .collection('modes')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (!verifyIntegrityHash(data, allowUnsignedLegacy: true)) {
          debugPrint('[lululu] Rejected tampered remote score for ${doc.id}');
          continue;
        }
        final rawScore = data['score'] as num?;
        if (!isValidScore(rawScore)) continue;
        final safeScore = sanitizeModeScore(rawScore);
        if (safeScore > 0) {
          await LeaderboardService.instance.submitScore(doc.id, safeScore);
        }
      }
    } catch (e) {
      debugPrint('[lululu] pull remote bests: $e');
    }
  }

  Future<void> _pullRemoteProfile(String uid) async {
    if (!FirebaseBootstrap.ready) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('players')
          .doc(uid)
          .get();
      final data = doc.data();
      if (data == null || data.isEmpty) return;
      await applyVerifiedProfileSnapshot(data, allowUnsignedLegacy: true);
    } catch (e) {
      debugPrint('[lululu] pull remote profile: $e');
    }
  }

  /// Global top for a mode from Firestore collectionGroup.
  Future<List<({String playerId, String name, int score})>> fetchGlobalTop(
    String modeId, {
    int limit = 20,
  }) async {
    if (!FirebaseBootstrap.ready) return const [];
    try {
      final safeLimit = limit.clamp(1, 100);
      final q = await FirebaseFirestore.instance
          .collectionGroup('modes')
          .where('modeId', isEqualTo: modeId)
          .orderBy('score', descending: true)
          .limit(safeLimit)
          .get();
      final results = <({String playerId, String name, int score})>[];
      for (final d in q.docs) {
        final data = d.data();
        if (!verifyIntegrityHash(data, allowUnsignedLegacy: true)) {
          continue;
        }
        final rawScore = data['score'] as num?;
        if (!isValidScore(rawScore)) continue;
        final safeScore = sanitizeModeScore(rawScore);
        // Path: scores/{uid}/modes/{modeId}
        final uid = d.reference.parent.parent?.id ?? '';
        final rawName = (data['displayName'] as String?) ?? 'Oyuncu';
        final safeName = rawName
            .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
            .trim();
        results.add((
          playerId: uid,
          name: safeName.isEmpty ? 'Oyuncu' : safeName,
          score: safeScore,
        ));
      }
      return results;
    } catch (e) {
      debugPrint('[lululu] fetchGlobalTop: $e');
      return const [];
    }
  }
}

/// Back-compat alias while call sites migrate.
typedef CloudSyncStub = CloudSyncService;
