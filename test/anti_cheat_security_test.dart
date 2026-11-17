import 'package:flutter_test/flutter_test.dart';
import 'package:lululu_game/services/anti_cheat_service.dart';

void main() {
  late AntiCheatService antiCheat;

  setUp(() {
    antiCheat = AntiCheatService();
    antiCheat.resetRewardHistory();
  });

  group('1. HMAC-SHA256 State Integrity (Tampering Detection)', () {
    Map<String, dynamic> sampleState() => <String, dynamic>{
          'coins': 1240,
          'energy': 5,
          'highScore': 14800,
          'modeHighScores': <String, int>{
            'suika': 14800,
            'grid2048': 22400,
            'balloon': 6200,
          },
          'unlockedTiers': <int>[1, 2, 3, 4, 5],
          'powerCounts': <String, int>{
            'slipper': 5,
            'spray': 3,
            'f16': 2,
          },
        };

    test('computes deterministic HMAC-SHA256 signature regardless of key order', () {
      final stateA = sampleState();
      final stateB = <String, dynamic>{
        'powerCounts': <String, int>{'f16': 2, 'spray': 3, 'slipper': 5},
        'unlockedTiers': <int>[1, 2, 3, 4, 5],
        'modeHighScores': <String, int>{
          'balloon': 6200,
          'suika': 14800,
          'grid2048': 22400,
        },
        'highScore': 14800,
        'energy': 5,
        'coins': 1240,
      };

      final sigA = antiCheat.computeStateSignature(stateA);
      final sigB = antiCheat.computeStateSignature(stateB);

      expect(sigA.length, 64);
      expect(sigA, equals(sigB));
      expect(antiCheat.verifyStateSignature(stateA, sigA), isTrue);
      expect(antiCheat.verifyStateSignature(stateB, sigA), isTrue);
    });

    test('detects tampering on coins, energy, highScore, modeHighScores, unlockedTiers, and powerCounts', () {
      final original = sampleState();
      final validSignature = antiCheat.computeStateSignature(original);

      // 1. Coins tampering (SharedPreferences editörü ile 999999 altın yazılması)
      final tamperedCoins = sampleState()..['coins'] = 999999;
      expect(
        antiCheat.verifyStateSignature(tamperedCoins, validSignature),
        isFalse,
      );

      // 2. Energy tampering
      final tamperedEnergy = sampleState()..['energy'] = 30;
      expect(
        antiCheat.verifyStateSignature(tamperedEnergy, validSignature),
        isFalse,
      );

      // 3. HighScore tampering
      final tamperedHigh = sampleState()..['highScore'] = 500000;
      expect(
        antiCheat.verifyStateSignature(tamperedHigh, validSignature),
        isFalse,
      );

      // 4. modeHighScores tampering
      final tamperedModes = sampleState();
      (tamperedModes['modeHighScores'] as Map<String, int>)['suika'] = 249999;
      expect(
        antiCheat.verifyStateSignature(tamperedModes, validSignature),
        isFalse,
      );

      // 5. unlockedTiers tampering
      final tamperedTiers = sampleState()
        ..['unlockedTiers'] = <int>[1, 2, 3, 4, 5, 6, 7, 8];
      expect(
        antiCheat.verifyStateSignature(tamperedTiers, validSignature),
        isFalse,
      );

      // 6. powerCounts tampering
      final tamperedPowers = sampleState();
      (tamperedPowers['powerCounts'] as Map<String, int>)['f16'] = 99;
      expect(
        antiCheat.verifyStateSignature(tamperedPowers, validSignature),
        isFalse,
      );
    });

    test('rejects malformed, empty, or forged signatures', () {
      final state = sampleState();
      expect(antiCheat.verifyStateSignature(state, ''), isFalse);
      expect(antiCheat.verifyStateSignature(state, 'not_a_hex_sig'), isFalse);
      expect(
        antiCheat.verifyStateSignature(state, '0' * 64),
        isFalse,
      );
    });
  });

  group('2. 11 Game Modes Score & Duration Consistency (validateGameScore)', () {
    const all11Modes = <String>[
      'suika',
      'grid2048',
      'balloon',
      'match3',
      'connect',
      'stack',
      'terlikTap',
      'yuvaDefense',
      'osmantus',
      'screamRoach',
      'makarayiz',
    ];

    test('accepts legitimate scores and durations across all 11 modes', () {
      for (final mode in all11Modes) {
        final result = antiCheat.validateGameScore(
          mode,
          4500,
          elapsed: const Duration(seconds: 45),
        );
        expect(result.isValid, isTrue, reason: 'Mode $mode should be valid');
        expect(result.sanitizedScore, 4500);
        expect(result.reason, 'ok');
      }
    });

    test('resolves snake_case mode aliases accurately', () {
      final result = antiCheat.validateGameScore(
        'terlik_tap',
        3200,
        elapsedSeconds: 20,
      );
      expect(result.isValid, isTrue);
      expect(result.mode, 'terlikTap');
      expect(result.sanitizedScore, 3200);
    });

    test('blocks scores exceeding maxPossibleScore ceiling for each mode', () {
      for (final mode in all11Modes) {
        final policy = AntiCheatService.modePolicies[mode]!;
        final cheatedScore = policy.maxPossibleScore + 50000;
        final result = antiCheat.validateGameScore(
          mode,
          cheatedScore,
          elapsed: const Duration(minutes: 30),
        );
        expect(result.isValid, isFalse, reason: 'Mode $mode ceiling breach');
        expect(result.sanitizedScore, policy.maxPossibleScore);
        expect(result.reason, 'exceeds_max_possible_score');
      }
    });

    test('blocks speed-hack scores exceeding maxPointsPerSecond', () {
      // 3 saniyede 50.000 puan kazanma hilesi
      final result = antiCheat.validateGameScore(
        'suika',
        50000,
        elapsed: const Duration(seconds: 3),
      );
      expect(result.isValid, isFalse);
      expect(result.reason, 'exceeds_max_points_per_second');
      expect(result.sanitizedScore, lessThanOrEqualTo(3 * 1200));
    });

    test('blocks negative, NaN, Infinity, zero-duration, and unknown mode scores', () {
      final neg = antiCheat.validateGameScore('suika', -500);
      expect(neg.isValid, isFalse);
      expect(neg.sanitizedScore, 0);
      expect(neg.reason, 'negative_score');

      final nanRes = antiCheat.validateGameScore('grid2048', double.nan);
      expect(nanRes.isValid, isFalse);
      expect(nanRes.sanitizedScore, 0);
      expect(nanRes.reason, 'non_finite_score');

      final infRes =
          antiCheat.validateGameScore('balloon', double.infinity);
      expect(infRes.isValid, isFalse);
      expect(infRes.sanitizedScore, 0);

      final zeroDur = antiCheat.validateGameScore(
        'match3',
        1200,
        elapsed: Duration.zero,
      );
      expect(zeroDur.isValid, isFalse);
      expect(zeroDur.sanitizedScore, 0);
      expect(zeroDur.reason, 'zero_or_negative_duration');

      final unknown = antiCheat.validateGameScore('hacked_mode', 100);
      expect(unknown.isValid, isFalse);
      expect(unknown.sanitizedScore, 0);
      expect(unknown.reason, 'unknown_game_mode');
    });
  });

  group('3. Economy & Reward Replay/Exploit Protection', () {
    test('validateCoinDelta blocks negative coin injection and excessive grants', () {
      // Negatif altın enjeksiyonu (ödül çağrısına -1000 gönderme)
      final negInjection = antiCheat.validateCoinDelta(
        -1000,
        currentBalance: 1500,
      );
      expect(negInjection.isValid, isFalse);
      expect(negInjection.sanitizedDelta, 0);
      expect(negInjection.sanitizedBalance, 1500);
      expect(negInjection.reason, 'negative_coin_injection_blocked');

      // Tek seferde aşırı altın basma hilesi (50.000 altın)
      final excessiveGrant = antiCheat.validateCoinDelta(
        50000,
        currentBalance: 1000,
      );
      expect(excessiveGrant.isValid, isFalse);
      expect(
        excessiveGrant.sanitizedDelta,
        AntiCheatService.maxSingleCoinGrant,
      );
      expect(
        excessiveGrant.sanitizedBalance,
        1000 + AntiCheatService.maxSingleCoinGrant,
      );
      expect(excessiveGrant.reason, 'exceeds_max_single_coin_grant');

      // Normal ödül kazanımı
      final validGrant = antiCheat.validateCoinDelta(
        250,
        currentBalance: 1000,
      );
      expect(validGrant.isValid, isTrue);
      expect(validGrant.sanitizedDelta, 250);
      expect(validGrant.sanitizedBalance, 1250);
    });

    test('validateEnergyDelta blocks negative energy injection and caps at maxEnergyCap', () {
      final negEnergy = antiCheat.validateEnergyDelta(-5, currentEnergy: 5);
      expect(negEnergy.isValid, isFalse);
      expect(negEnergy.sanitizedDelta, 0);
      expect(negEnergy.sanitizedBalance, 5);

      final hugeEnergy = antiCheat.validateEnergyDelta(999, currentEnergy: 5);
      expect(hugeEnergy.isValid, isFalse);
      expect(hugeEnergy.sanitizedBalance, AntiCheatService.maxEnergyCap);

      final validEnergy = antiCheat.validateEnergyDelta(5, currentEnergy: 5);
      expect(validEnergy.isValid, isTrue);
      expect(validEnergy.sanitizedBalance, 10);
    });

    test('canClaimCooldownReward blocks replay attacks (duplicate nonce/claimId), rapid spam, and clock rollback', () {
      final baseTime = DateTime.utc(2026, 11, 4, 12, 0, 0);

      // İlk geçerli ödül talebi
      final firstClaim = antiCheat.canClaimCooldownReward(
        'rewarded_ad',
        claimId: 'ad_nonce_001',
        now: baseTime,
      );
      expect(firstClaim, isTrue);

      // 1. Replay Attack: Aynı claimId ile 1 saat sonra bile tekrar denense reddedilmeli
      final replayAttempt = antiCheat.canClaimCooldownReward(
        'rewarded_ad',
        claimId: 'ad_nonce_001',
        now: baseTime.add(const Duration(hours: 1)),
      );
      expect(replayAttempt, isFalse);

      // 2. Cooldown Spam: Yeni nonce ile ama bekleme süresi (25 sn) dolmadan art arda basma
      final rapidSpam = antiCheat.canClaimCooldownReward(
        'rewarded_ad',
        claimId: 'ad_nonce_002',
        now: baseTime.add(const Duration(seconds: 3)),
      );
      expect(rapidSpam, isFalse);

      // 3. Clock Rollback: Cihaz saatini geri alarak ödül isteme hilesi
      final clockRollback = antiCheat.canClaimCooldownReward(
        'rewarded_ad',
        claimId: 'ad_nonce_003',
        now: baseTime.subtract(const Duration(minutes: 10)),
      );
      expect(clockRollback, isFalse);

      // 4. Cooldown süresi dolduktan sonra yeni nonce ile geçerli talep
      final validNextClaim = antiCheat.canClaimCooldownReward(
        'rewarded_ad',
        claimId: 'ad_nonce_004',
        now: baseTime.add(const Duration(seconds: 30)),
      );
      expect(validNextClaim, isTrue);
    });
  });

  group('4. Input Security, XSS/SQL/NoSQL Injection & Profanity Protection', () {
    test('sanitizeUserInput strips XSS scripts, SQL/NoSQL injection, control chars, and masks profanity', () {
      const xssPayload =
          '<script>alert("xss")</script><img src=x onerror=alert(1)>Selam Lululu!';
      final sanitizedXss = antiCheat.sanitizeUserInput(xssPayload);
      expect(sanitizedXss.contains('<script>'), isFalse);
      expect(sanitizedXss.contains('onerror'), isFalse);
      expect(sanitizedXss, equals('Selam Lululu!'));

      const sqlNoSqlPayload =
          "Oyuncu'; DROP TABLE users; -- {\$where: '1==1'}";
      final sanitizedSql = antiCheat.sanitizeUserInput(sqlNoSqlPayload);
      expect(sanitizedSql.toUpperCase().contains('DROP TABLE'), isFalse);
      expect(sanitizedSql.contains(r'$where'), isFalse);
      expect(sanitizedSql.contains(';'), isFalse);

      const profanityPayload = 'Bu oyun çok amk ve shit olmuş';
      final sanitizedProfanity = antiCheat.sanitizeUserInput(profanityPayload);
      expect(sanitizedProfanity.contains('amk'), isFalse);
      expect(sanitizedProfanity.contains('shit'), isFalse);
      expect(sanitizedProfanity, contains('***'));

      final longInput = 'A' * 500;
      final truncated = antiCheat.sanitizeUserInput(longInput, maxLength: 32);
      expect(truncated.length, 32);
    });

    test('validateCredentials enforces safe usernames, valid emails, and strong passwords', () {
      final valid = antiCheat.validateCredentials(
        username: 'lululu_usta_42',
        email: 'oyuncu@lululu.app',
        password: 'Guclu_Sifre#2026',
      );
      expect(valid.isValid, isTrue);
      expect(valid.sanitizedUsername, 'lululu_usta_42');
      expect(valid.sanitizedEmail, 'oyuncu@lululu.app');

      // XSS/SQLi kullanıcı adı reddedilmeli
      final unsafeUser = antiCheat.validateCredentials(
        username: '<script>admin</script>',
        email: 'admin@lululu.app',
        password: 'Guclu_Sifre#2026',
      );
      expect(unsafeUser.isValid, isFalse);
      expect(
        unsafeUser.errors,
        contains('username_contains_unsafe_characters'),
      );

      // Küfürlü kullanıcı adı reddedilmeli
      final profaneUser = antiCheat.validateCredentials(
        username: 'kral_orospu_99',
        email: 'test@lululu.app',
        password: 'Guclu_Sifre#2026',
      );
      expect(profaneUser.isValid, isFalse);
      expect(profaneUser.errors, contains('username_contains_profanity'));

      // Zayıf/yaygın şifre reddedilmeli
      final weakPass = antiCheat.validateCredentials(
        username: 'temiz_oyuncu',
        email: 'temiz@lululu.app',
        password: '123456',
      );
      expect(weakPass.isValid, isFalse);
      expect(weakPass.errors, contains('password_too_common'));
    });
  });
}
