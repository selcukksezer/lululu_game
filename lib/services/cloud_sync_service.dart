import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'bug_video_service.dart';
import 'chat_service.dart';
import 'firebase_bootstrap.dart';
import 'leaderboard_service.dart';

/// Online sync — Firestore when Firebase ready; else durable local queue.
class CloudSyncService extends ChangeNotifier {
  CloudSyncService._();
  static final instance = CloudSyncService._();

  static const _queueKey = 'LululuCloudQueueV1';

  bool onlineEnabled = false;
  String status = 'Yerel · bulut kuyruğu hazır';
  final List<String> pending = [];
  bool get firebaseReady => FirebaseBootstrap.ready;

  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? const [];
    pending
      ..clear()
      ..addAll(raw);
    status = FirebaseBootstrap.ready
        ? 'Online hazır · ${pending.length} bekleyen'
        : FirebaseBootstrap.playerStatus;
    notifyListeners();
  }

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_queueKey, List<String>.from(pending));
  }

  Future<void> enqueueLeaderboardPush() async {
    await LeaderboardService.instance.ensureLoaded();
    pending.add('leaderboard:${DateTime.now().millisecondsSinceEpoch}');
    status = onlineEnabled
        ? 'Sıralama gönderiliyor…'
        : 'Sıralama kuyrukta (online kapalı)';
    await _persistQueue();
    notifyListeners();
    if (onlineEnabled) unawaited(flushPending());
  }

  Future<void> enqueueChatPush() async {
    await ChatService.instance.ensureLoaded();
    pending.add('chat:${DateTime.now().millisecondsSinceEpoch}');
    status = onlineEnabled ? 'Sohbet sync…' : 'Sohbet kuyrukta (online kapalı)';
    await _persistQueue();
    notifyListeners();
  }

  Future<void> enqueueVideoFeedPush() async {
    await BugVideoService.instance.ensureLoaded();
    pending.add('videos:${DateTime.now().millisecondsSinceEpoch}');
    status = onlineEnabled
        ? 'Video feed sync…'
        : 'Video feed kuyrukta (online kapalı)';
    await _persistQueue();
    notifyListeners();
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

  /// Push queued leaderboard bests to Firestore `scores/{uid}/modes/{modeId}`.
  Future<int> flushPending() async {
    if (!onlineEnabled) return 0;
    await AuthService.instance.ensureLoaded();
    final uid = AuthService.instance.playerId;
    final name = AuthService.instance.displayName;
    var flushed = 0;

    if (FirebaseBootstrap.ready) {
      try {
        final db = FirebaseFirestore.instance;
        final bests = LeaderboardService.instance.getAllModeBests();
        final batch = db.batch();
        for (final b in bests) {
          if (b.best <= 0) continue;
          final ref = db
              .collection('scores')
              .doc(uid)
              .collection('modes')
              .doc(b.modeId);
          batch.set(
            ref,
            {
              'modeId': b.modeId,
              'score': b.best,
              'displayName': name,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          flushed++;
        }
        final profile = db.collection('players').doc(uid);
        batch.set(
          profile,
          {
            'displayName': name,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        await batch.commit();
        await _pullRemoteBests(uid);
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
        final score = (doc.data()['score'] as num?)?.toInt() ?? 0;
        if (score > 0) {
          await LeaderboardService.instance.submitScore(doc.id, score);
        }
      }
    } catch (e) {
      debugPrint('[lululu] pull remote bests: $e');
    }
  }

  /// Global top for a mode from Firestore collectionGroup.
  Future<List<({String playerId, String name, int score})>> fetchGlobalTop(
    String modeId, {
    int limit = 20,
  }) async {
    if (!FirebaseBootstrap.ready) return const [];
    try {
      final q = await FirebaseFirestore.instance
          .collectionGroup('modes')
          .where('modeId', isEqualTo: modeId)
          .orderBy('score', descending: true)
          .limit(limit)
          .get();
      return q.docs.map((d) {
        final data = d.data();
        // Path: scores/{uid}/modes/{modeId}
        final uid = d.reference.parent.parent?.id ?? '';
        return (
          playerId: uid,
          name: (data['displayName'] as String?) ?? 'Oyuncu',
          score: (data['score'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('[lululu] fetchGlobalTop: $e');
      return const [];
    }
  }
}

/// Back-compat alias while call sites migrate.
typedef CloudSyncStub = CloudSyncService;
