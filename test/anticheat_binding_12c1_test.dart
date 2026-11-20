import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/anti_cheat_service.dart';
import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

/// 12C1 — AntiCheat bağlama testleri.
///
/// Kural: geçersiz skor hiçbir kayda yazılmaz (mod rekoru / liderlik),
/// ama hata fırlatılmaz ve oyun akışı bozulmaz (kapı `false` döner).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProgressManager pm;
  late LeaderboardService board;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AntiCheatService.instance.resetSignatureFailureRecord();
    pm = ProgressManager.instance;
    await pm.load();
    board = LeaderboardService.instance;
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await board.load();
  });

  group('AntiCheatService.validateGameScore kapısı', () {
    test('meşru skor geçer', () {
      final antiCheat = AntiCheatService.instance;
      final valid = antiCheat.validateGameScore(
        'suika',
        14500,
        elapsed: const Duration(seconds: 45),
      );
      expect(valid.isValid, isTrue);
      expect(valid.sanitizedScore, 14500);
      expect(valid.reason, 'ok');

      final valid2048 = antiCheat.validateGameScore(
        'grid_2048',
        20000,
        elapsed: const Duration(seconds: 60),
      );
      expect(valid2048.isValid, isTrue);
    });

    test('şişirilmiş skor reddedilir', () {
      final antiCheat = AntiCheatService.instance;
      // Tavan üstü + imkânsız hız (2 saniyede 9.999.999).
      final inflated = antiCheat.validateGameScore(
        'suika',
        9999999,
        elapsed: const Duration(seconds: 2),
      );
      expect(inflated.isValid, isFalse);
      expect(inflated.reason, isNot('ok'));
    });

    test('saniye başına puan hızı ihlali reddedilir', () {
      final antiCheat = AntiCheatService.instance;
      // Suika tavanı 1200 puan/sn: 10 saniyede 50000 imkânsızdır.
      final tooFast = antiCheat.validateGameScore(
        'suika',
        50000,
        elapsed: const Duration(seconds: 10),
      );
      expect(tooFast.isValid, isFalse);
      expect(tooFast.reason, 'exceeds_max_points_per_second');
    });

    test('negatif skor ve bilinmeyen mod reddedilir', () {
      final antiCheat = AntiCheatService.instance;
      expect(
        antiCheat.validateGameScore(
          'suika',
          -100,
          elapsed: const Duration(seconds: 30),
        ).isValid,
        isFalse,
      );
      expect(
        antiCheat.validateGameScore(
          'bilinmeyen_mod',
          1000,
          elapsed: const Duration(seconds: 30),
        ).isValid,
        isFalse,
      );
      // Süresiz (0 saniye) yüksek skor anında-kazanım hilesidir.
      expect(
        antiCheat.validateGameScore(
          'suika',
          5000,
          elapsed: Duration.zero,
        ).isValid,
        isFalse,
      );
    });
  });

  group('Yazım yolları (rekor + liderlik)', () {
    test('recordModeScore şişirilmiş skoru yazmaz, meşru skoru yazar',
        () async {
      final rejected = await pm.recordModeScore('suika', 999999);
      expect(rejected, isFalse);
      expect(pm.modeHighScores['suika'] ?? 0, 0);

      final accepted = await pm.recordModeScore('suika', 14500);
      expect(accepted, isTrue);
      expect(pm.modeHighScores['suika'], 14500);
    });

    test('submitScore şişirilmiş skoru tahtaya yazmaz', () async {
      final rejected = await board.submitScore(
        LeaderboardService.modeSuika,
        999999,
      );
      expect(rejected, isFalse);
      expect(board.getBest(LeaderboardService.modeSuika), 0);

      final accepted = await board.submitScore(
        LeaderboardService.modeSuika,
        5000,
      );
      expect(accepted, isTrue);
      expect(board.getBest(LeaderboardService.modeSuika), 5000);
    });

    test('uzak birleştirme kap denetimini atlar ama tavanı korur',
        () async {
      // Tavan hizalama (14C1): AntiCheat tavanı PM tavanına eşit (match3
      // 300.000) — 250.000 artık yerelden de kabul edilir; 350.000 ise
      // her iki yoldan da reddedilir.
      final localAccepted = await board.submitScore('match3', 250000);
      expect(localAccepted, isTrue);
      expect(board.getBest('match3'), 250000);

      final localRejected = await board.submitScore('match3', 350000);
      expect(localRejected, isFalse);
      expect(board.getBest('match3'), 250000);

      // Uzak yol bile PM tavanını aşamaz (match3 tavanı 300.000).
      final remoteTooBig = await board.submitScore(
        'match3',
        400000,
        fromRemoteSync: true,
      );
      expect(remoteTooBig, isFalse);
      expect(board.getBest('match3'), 250000);
    });
  });

  group('HMAC durum mührü (buildStatePayload + verifyStateSignature)', () {
    test('sağlam durum doğrulanır, kurcalanan durum reddedilir', () async {
      final recorded = await pm.recordModeScore('suika', 14500);
      expect(recorded, isTrue);

      expect(await pm.verifyStoredAntiCheatSignature(), isTrue);

      // Yalnız bellek-içi kurcalama: mühür artık uyuşmaz.
      pm.modeHighScores['suika'] = 999999;
      expect(await pm.verifyStoredAntiCheatSignature(), isFalse);

      // Kalıcı durumdan yeniden yükleme temiz durumu geri getirir.
      await pm.load();
      expect(pm.modeHighScores['suika'], 14500);
      expect(await pm.verifyStoredAntiCheatSignature(), isTrue);
    });

    test('imza API\'si kurcalanmış yükü reddeder', () {
      final antiCheat = AntiCheatService.instance;
      final payload = antiCheat.buildStatePayload(
        coins: 1240,
        energy: 5,
        highScore: 14500,
        modeHighScores: const <String, int>{'suika': 14500},
        unlockedTiers: const <int>[1, 2, 3],
        powerCounts: const <String, int>{'raid': 1},
      );
      final signature = antiCheat.computeStateSignature(payload);
      expect(antiCheat.verifyStateSignature(payload, signature), isTrue);

      final tampered = Map<String, dynamic>.from(payload)..['coins'] = 9999999;
      expect(antiCheat.verifyStateSignature(tampered, signature), isFalse);
      expect(antiCheat.signatureVerificationFailures, greaterThan(0));
    });
  });

  group('tavan hizalama (14C1-koordinator karari)', () {
    test('AntiCheat maxPossibleScore, PM modeScoreCeilings ile birebir ayni', () {
      for (final entry in ProgressManager.modeScoreCeilings.entries) {
        final key = AntiCheatService.tryResolveModeKey(entry.key);
        expect(key, isNotNull, reason: 'PM modu cozulemedi: ${entry.key}');
        final policy = AntiCheatService.modePolicies[key];
        expect(policy, isNotNull, reason: 'politika yok: $key');
        expect(
          policy!.maxPossibleScore,
          entry.value,
          reason: 'tavan uyumsuz: ${entry.key} PM=${entry.value} AntiCheat=${policy.maxPossibleScore}',
        );
      }
    });

    test('PM tavanindaki skor yerelden gecer (yanlis ret yok)', () {
      final antiCheat = AntiCheatService.instance;
      final result = antiCheat.validateGameScore(
        'match3',
        300000,
        elapsed: const Duration(minutes: 10),
      );
      expect(result.isValid, isTrue, reason: result.reason);
    });
  });
}
