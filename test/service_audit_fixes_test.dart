// Servis-denetim dalgasının düzeltmelerini kilitleyen testler (W24-2).
//
// Her grup, düzeltmenin bulunduğu kaynak dosyadaki gerçek davranışa göre
// yazıldı; kurulum desenleri mevcut test dosyalarından alındı:
//  - mock prefs + load(): test/live_ops_difficulty_test.dart,
//    test/auth_leaderboard_test.dart
//  - telemetri sıfırlama / kayıt deseni:
//    test/game_enhancements_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/anti_cheat_service.dart';
import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/daily_challenge_service.dart';
import 'package:lululu_game/services/friend_invite_service.dart';
import 'package:lululu_game/services/game_telemetry_service.dart';
import 'package:lululu_game/services/live_ops_event_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

/// DailyChallengeService._todayKey / _dayKeyOffset ile aynı biçim:
/// 'yil-ay-gun', sıfır doldurmasız (daily_challenge_service.dart:220-227).
String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// FriendInviteService._makeCode ile aynı türetme
/// (friend_invite_service.dart:27-31): kodun oyuncuya bağlı ilk bölümü.
String _expectedCodePrefix(String playerId) {
  final id = playerId.hashCode.abs().toRadixString(36);
  return 'LULU-${id.toUpperCase().padLeft(4, 'X').substring(0, 4)}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameTelemetryService (servis denetimi: percentileFrameTimeMs NaN koruması)',
      () {
    test('percentileFrameTimeMs NaN girdide örnek yokken 0.0 döner', () {
      // game_telemetry_service.dart:319-320: NaN koruması örnek
      // kontrolünden ÖNCE döner. Fabrika, 200 dışı kapasitede singleton
      // dışı yeni örnek üretir (test örneği).
      final telemetry = GameTelemetryService(maxBufferSize: 10);
      expect(telemetry.percentileFrameTimeMs(double.nan), 0.0);
    });

    test('percentileFrameTimeMs NaN girdide örnek varken de 0.0 döner', () {
      final telemetry = GameTelemetryService(maxBufferSize: 10);
      telemetry.recordFrameTiming(
        const Duration(milliseconds: 10),
        const Duration(milliseconds: 5),
      );
      telemetry.recordFrameTiming(
        const Duration(milliseconds: 4),
        const Duration(milliseconds: 3),
      );
      telemetry.recordFrameTiming(
        const Duration(milliseconds: 12),
        const Duration(milliseconds: 10),
      );
      expect(telemetry.bufferedFrameCount, 3);
      // Ortanca kontrolü: sıralı [7, 15, 22] ms, P50 = 15.0.
      expect(telemetry.percentileFrameTimeMs(0.5), 15.0);
      // NaN, dolu tamponda da çökmeden 0.0 döner.
      expect(telemetry.percentileFrameTimeMs(double.nan), 0.0);
    });
  });

  group('FriendInviteService (servis denetimi: playerId değişince kod yenilenir)',
      () {
    // Kurulum deseni: test/auth_leaderboard_test.dart setUp.
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AuthService.instance.load();
      await AuthService.instance.signOut();
    });

    test('aynı oyuncuda inviteCode tekrarlı okumalarda sabit kalır', () async {
      final auth = AuthService.instance;
      await auth.register(username: 'davetci_a', password: 'sifre123');
      final first = FriendInviteService.instance.inviteCode;
      final second = FriendInviteService.instance.inviteCode;
      expect(first, startsWith('LULU-'));
      expect(second, first);
      expect(
        first,
        startsWith(_expectedCodePrefix(auth.playerId)),
      );
    });

    test('playerId değişince inviteCode yeniden üretilir ve yeni oyuncuya bağlanır',
        () async {
      // friend_invite_service.dart:19-22: _codePlayerId != playerId ise
      // kod _makeCode(playerId) ile yeniden üretilir.
      final auth = AuthService.instance;
      await auth.register(username: 'davetci_bir', password: 'sifre123');
      final idA = auth.playerId;
      final codeA = FriendInviteService.instance.inviteCode;
      expect(codeA, startsWith(_expectedCodePrefix(idA)));

      await auth.signOut();
      await auth.register(username: 'davetci_iki', password: 'sifre123');
      final idB = auth.playerId;
      expect(idB, isNot(idA));
      final codeB = FriendInviteService.instance.inviteCode;
      expect(codeB, isNot(codeA));
      expect(codeB, startsWith(_expectedCodePrefix(idB)));
    });
  });

  group('LiveOpsEventService claimIdleJarCoins (servis denetimi: ekonomi reddi claimId yakmaz)',
      () {
    // Kurulum deseni: test/live_ops_difficulty_test.dart setUp.
    late AntiCheatService antiCheat;
    late LiveOpsEventService liveOps;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      antiCheat = AntiCheatService(secretKey: 'test_liveops_secret_key');
      liveOps = LiveOpsEventService(antiCheat: antiCheat);
    });

    test('bakiye tavanında ekonomi reddi claimIdyi tüketmez; aynı claimId ile tekrar deneme başarılı olur',
        () {
      // live_ops_event_service.dart:493-514: ekonomi doğrulaması
      // cooldown/replay kaydından ÖNCE yapılır; reddedilen talebin
      // claimId'si tüketilmez.
      final baseTime = DateTime(2026, 11, 4, 10, 0);
      const claimId = 'audit_cap_retry_001';

      final rejected = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 1,
        currentCoinBalance: AntiCheatService.maxCoinBalanceCap,
        lastActiveAt: baseTime,
        now: baseTime.add(const Duration(minutes: 60)),
        claimId: claimId,
      );
      expect(rejected.isSuccess, isFalse);
      expect(rejected.grantedCoins, 0);
      expect(rejected.reason, 'exceeds_max_coin_balance_cap');

      // Aynı claimId ile, tavan altında bakiyeyle tekrar deneme: eğer
      // claimId yansaydı bu çağrı replay engeline takılırdı.
      final retry = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 1,
        currentCoinBalance: 500,
        lastActiveAt: baseTime,
        now: baseTime.add(const Duration(minutes: 60)),
        claimId: claimId,
      );
      expect(retry.isSuccess, isTrue);
      expect(retry.grantedCoins, 60);
      expect(retry.newCoinBalance, 560);
      expect(retry.reason, 'ok');
    });

    test('başarılı talep claimIdyi tüketir; aynı claimId ile tekrar deneme engellenir',
        () {
      // Karşıt koruma: düzeltme, başarılı talebin replay korumasını
      // bozmamalı (live_ops_event_service.dart:516-531).
      final baseTime = DateTime(2026, 11, 4, 10, 0);
      const claimId = 'audit_replay_001';

      final first = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 1,
        currentCoinBalance: 500,
        lastActiveAt: baseTime,
        now: baseTime.add(const Duration(minutes: 60)),
        claimId: claimId,
      );
      expect(first.isSuccess, isTrue);
      expect(first.grantedCoins, 60);

      final replay = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 1,
        currentCoinBalance: first.newCoinBalance,
        lastActiveAt: baseTime.add(const Duration(minutes: 60)),
        now: baseTime.add(const Duration(minutes: 120)),
        claimId: claimId,
      );
      expect(replay.isSuccess, isFalse);
      expect(replay.grantedCoins, 0);
      expect(replay.reason, 'anti_cheat_cooldown_or_replay_blocked');
    });
  });

  group('DailyChallengeService nextClaimRewardCoins (servis denetimi: seri tahmini)',
      () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProgressManager.instance.load();
      // load() doğrudan çağrılır: ensureLoaded() _loaded bayrağı
      // nedeniyle sonraki testlerde prefs'i yeniden okumaz.
      await DailyChallengeService.instance.load();
    });

    test('son talep dün değilse seri-1 hesabı yapılır (seri 10 + eski talep → 55)',
        () {
      // daily_challenge_service.dart:108-116: nextStreak, son talep
      // dün değilse 1'dir; 40 + 1*15 = 55 (seri-10 hesabı 190 olurdu).
      final daily = DailyChallengeService.instance;
      daily.streak = 10;
      daily.lastClaimDay = '2000-1-1';
      daily.completedToday = false;
      expect(daily.canClaimToday, isTrue);
      expect(daily.nextClaimRewardCoins, 55);
    });

    test('son talep dünse seri+1 hesabı yapılır (seri 10 + dün → 205)', () {
      final daily = DailyChallengeService.instance;
      daily.streak = 10;
      daily.lastClaimDay =
          _dayKey(DateTime.now().subtract(const Duration(days: 1)));
      daily.completedToday = false;
      expect(daily.canClaimToday, isTrue);
      expect(daily.nextClaimRewardCoins, 40 + 11 * 15);
    });

    test('son talep dün değilse tamamlanma bonusu seri-1 hesabına eklenir (→ 135)',
        () {
      final daily = DailyChallengeService.instance;
      daily.streak = 10;
      daily.lastClaimDay = '2000-1-1';
      daily.completedToday = true;
      expect(daily.nextClaimRewardCoins, 55 + 80);
    });
  });

  group('DailyChallengeService tryCompleteWithScore (servis denetimi: play görevi sayılmaz)',
      () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProgressManager.instance.load();
      await DailyChallengeService.instance.load();
    });

    test('tamamlayıcı skor gönderimi play görev ilerlemesini artırmaz', () async {
      // daily_challenge_service.dart:169-177: 'play' görevi burada
      // kaydedilmez; tek kayıt noktası finish_run.dart'tır. İlerleme
      // ProgressManager.getTaskProgress('play') ile okunur
      // (progress_manager.dart:955).
      final daily = DailyChallengeService.instance;
      expect(ProgressManager.instance.getTaskProgress('play'), 0);
      final completed = await daily.tryCompleteWithScore(
        daily.modeId,
        daily.targetScore,
      );
      expect(completed, isTrue);
      expect(ProgressManager.instance.getTaskProgress('play'), 0);
    });

    test('tekrarlanan skor gönderimleri play görev ilerlemesini artırmaz',
        () async {
      // Gerekçe: metot skor gönderimi başına (Çığlık Böcek'te her
      // çığlıkta) çağrılır; tekrarlar da 'play' sayılmamalı.
      final daily = DailyChallengeService.instance;
      var firstResult = false;
      for (var i = 0; i < 5; i++) {
        final result = await daily.tryCompleteWithScore(
          daily.modeId,
          daily.targetScore,
        );
        if (i == 0) firstResult = result;
      }
      expect(firstResult, isTrue);
      expect(ProgressManager.instance.getTaskProgress('play'), 0);
    });
  });
}
