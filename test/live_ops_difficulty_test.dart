import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/adaptive_difficulty_service.dart';
import 'package:lululu_game/services/anti_cheat_service.dart';
import 'package:lululu_game/services/live_ops_event_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdaptiveDifficultyService (11 Oyun Modu DDA & Merhamet Desteği)', () {
    late AdaptiveDifficultyService dda;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      dda = AdaptiveDifficultyService(maxHistoryPerMode: 12);
    });

    test('11 oyun modunun tamamı desteklenir ve varsayılan dengeli profil üretir', () {
      expect(AdaptiveDifficultyService.supportedModes.length, 11);
      const expectedModes = <String>[
        'suika',
        'grid2048',
        'balloon',
        'match3',
        'connect',
        'stack',
        'terlik',
        'yuva',
        'osmantus',
        'scream',
        'makara',
      ];
      expect(AdaptiveDifficultyService.supportedModes, expectedModes);

      final allProfiles = dda.getAllModeProfiles();
      expect(allProfiles.length, 11);

      for (final mode in expectedModes) {
        final profile = allProfiles[mode]!;
        expect(profile.modeId, mode);
        expect(profile.isMercyBoostActive, isFalse);
        expect(profile.speedMultiplier, inInclusiveRange(0.88, 1.35));
        expect(profile.spawnFavorability, inInclusiveRange(0.85, 1.25));
        expect(profile.bonusStartingBoosters, 0);
        expect(profile.skillScoreBonusMultiplier, inInclusiveRange(1.0, 1.5));
      }
    });

    test('Üst üste 3+ yenilgide Merhamet Desteği (Mercy Boost) devreye girer', () {
      for (final mode in AdaptiveDifficultyService.supportedModes) {
        // 1. ve 2. yenilgide henüz Mercy Boost aktif olmamalı
        final loss1 = dda.recordMatchResult(
          mode: mode,
          score: 400,
          won: false,
          reflexMs: 750,
        );
        expect(loss1.isMercyBoostActive, isFalse);
        expect(loss1.lossStreak, 1);

        final loss2 = dda.recordMatchResult(
          mode: mode,
          score: 350,
          won: false,
          reflexMs: 800,
        );
        expect(loss2.isMercyBoostActive, isFalse);
        expect(loss2.lossStreak, 2);

        // 3. ardışık yenilgide Merhamet Desteği aktifleşir:
        // Hız %12 yumuşatılır (0.88), +1 başlangıç güçlendiricisi ve >1.0 uygun taş dağılımı
        final loss3 = dda.recordMatchResult(
          mode: mode,
          score: 300,
          won: false,
          reflexMs: 820,
        );
        expect(loss3.isMercyBoostActive, isTrue, reason: 'Mode $mode should trigger mercy boost on 3 losses');
        expect(loss3.lossStreak, 3);
        expect(loss3.winStreak, 0);
        expect(loss3.speedMultiplier, closeTo(0.88, 1e-6));
        expect(loss3.bonusStartingBoosters, 1);
        expect(loss3.spawnFavorability, inInclusiveRange(1.15, 1.25));
        expect(loss3.skillScoreBonusMultiplier, 1.0);
        expect(loss3.difficultyTierLabel, 'mercy');

        // 5. yenilgide de sınırlar (clamp) aşılmaz
        dda.recordMatchResult(mode: mode, score: 250, won: false);
        final loss5 = dda.recordMatchResult(mode: mode, score: 200, won: false);
        expect(loss5.isMercyBoostActive, isTrue);
        expect(loss5.speedMultiplier, closeTo(0.88, 1e-6));
        expect(loss5.spawnFavorability, inInclusiveRange(0.85, 1.25));
        expect(loss5.bonusStartingBoosters, 1);
      }
    });

    test('Kazanma serisinde tempo (0.88..1.35) ve Ustalık Skor Çarpanı (1.0..1.5x) akıcı artar', () {
      for (final mode in AdaptiveDifficultyService.supportedModes) {
        final baseline = AdaptiveDifficultyService.modeBaselines[mode]!;
        var prevSpeed = 0.88;
        var prevSkillBonus = 1.0;

        for (var i = 1; i <= 8; i++) {
          final profile = dda.recordMatchResult(
            mode: mode,
            score: baseline.targetScore * (1.1 + i * 0.1),
            won: true,
            reflexMs: baseline.targetReflexMs * 0.72,
          );
          expect(profile.isMercyBoostActive, isFalse);
          expect(profile.winStreak, i);
          expect(profile.lossStreak, 0);
          expect(profile.speedMultiplier, greaterThanOrEqualTo(prevSpeed));
          expect(profile.speedMultiplier, inInclusiveRange(0.88, 1.35));
          expect(profile.skillScoreBonusMultiplier, greaterThanOrEqualTo(prevSkillBonus));
          expect(profile.skillScoreBonusMultiplier, inInclusiveRange(1.0, 1.5));
          expect(profile.spawnFavorability, inInclusiveRange(0.85, 1.25));
          expect(profile.bonusStartingBoosters, 0);

          prevSpeed = profile.speedMultiplier;
          prevSkillBonus = profile.skillScoreBonusMultiplier;
        }

        expect(prevSpeed, greaterThan(1.15));
        expect(prevSkillBonus, greaterThan(1.25));
      }
    });

    test('NaN, Infinity ve negatif girdilerde deterministik clamp sınırları korunur', () {
      final edgeInputs = <num>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -999999,
        0,
        999999999,
      ];

      for (final mode in AdaptiveDifficultyService.supportedModes) {
        for (final badVal in edgeInputs) {
          final profile = dda.evaluateDifficulty(
            mode: mode,
            winStreak: badVal.isFinite ? badVal.toInt() : -50,
            lossStreak: badVal.isFinite ? badVal.toInt() : -10,
            averageScore: badVal,
            averageReflexMs: badVal,
          );

          expect(profile.speedMultiplier.isNaN, isFalse);
          expect(profile.speedMultiplier.isInfinite, isFalse);
          expect(profile.speedMultiplier, inInclusiveRange(0.88, 1.35));

          expect(profile.spawnFavorability.isNaN, isFalse);
          expect(profile.spawnFavorability.isInfinite, isFalse);
          expect(profile.spawnFavorability, inInclusiveRange(0.85, 1.25));

          expect(profile.skillScoreBonusMultiplier.isNaN, isFalse);
          expect(profile.skillScoreBonusMultiplier.isInfinite, isFalse);
          expect(profile.skillScoreBonusMultiplier, inInclusiveRange(1.0, 1.5));

          expect(profile.bonusStartingBoosters, inInclusiveRange(0, 2));
          expect(profile.averageScore, greaterThanOrEqualTo(0.0));
          expect(profile.averageReflexMs, greaterThan(0.0));
        }
      }
    });

    test('Mod takma adları (aliases) ve SharedPreferences kalıcılığı doğru çalışır', () async {
      expect(AdaptiveDifficultyService.resolveModeKey('terlikTap'), 'terlik');
      expect(AdaptiveDifficultyService.resolveModeKey('yuvaDefense'), 'yuva');
      expect(AdaptiveDifficultyService.resolveModeKey('screamRoach'), 'scream');
      expect(AdaptiveDifficultyService.resolveModeKey('makarayiz'), 'makara');
      expect(AdaptiveDifficultyService.resolveModeKey('grid_2048'), 'grid2048');

      dda.recordMatchResult(mode: 'terlikTap', score: 500, won: false);
      dda.recordMatchResult(mode: 'terlik_tap', score: 450, won: false);
      dda.recordMatchResult(mode: 'terlik', score: 400, won: false);

      await dda.saveToPreferences();

      final restored = AdaptiveDifficultyService();
      await restored.loadFromPreferences();
      final profile = restored.getProfileForMode('terlik');
      expect(profile.isMercyBoostActive, isTrue);
      expect(profile.lossStreak, 3);
      expect(profile.speedMultiplier, closeTo(0.88, 1e-6));
    });
  });

  group('LiveOpsEventService (4 Dönüşümlü Etkinlik & Çevrimdışı Böcek Kavanozu)', () {
    late AntiCheatService antiCheat;
    late LiveOpsEventService liveOps;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      antiCheat = AntiCheatService(secretKey: 'test_liveops_secret_key');
      liveOps = LiveOpsEventService(antiCheat: antiCheat);
    });

    test('4 özel LiveOps etkinliği doğru çarpanları ve hedef modları uygular', () {
      // 1. Altın Yağmuru Festivali (coinMultiplier: 2.0)
      for (final mode in AdaptiveDifficultyService.supportedModes) {
        final mods = liveOps.getModifiersForMode(
          mode,
          overrideActiveEvents: const <LiveOpsEventType>[
            LiveOpsEventType.goldRainFestival,
          ],
        );
        expect(mods.coinMultiplier, 2.0);
        expect(mods.activeEventIds, contains('gold_rain_festival'));
      }

      // 2. Terlik Fırtınası Maratonu (terlik & yuva modlarında 1.5x skor ve ekstra terlik)
      for (final mode in <String>['terlik', 'yuva', 'terlikTap', 'yuvaDefense']) {
        final mods = liveOps.getModifiersForMode(
          mode,
          overrideActiveEvents: const <LiveOpsEventType>[
            LiveOpsEventType.slipperStormMarathon,
          ],
        );
        expect(mods.scoreMultiplier, 1.5);
        expect(mods.extraSlippers, greaterThan(0));
        expect(mods.activeEventIds, contains('slipper_storm_marathon'));
      }
      final nonSlipperMods = liveOps.getModifiersForMode(
        'suika',
        overrideActiveEvents: const <LiveOpsEventType>[
          LiveOpsEventType.slipperStormMarathon,
        ],
      );
      expect(nonSlipperMods.scoreMultiplier, 1.0);
      expect(nonSlipperMods.extraSlippers, 0);

      // 3. Osmantuş & Makara Müzik Gecesi (osmantus & makara modlarında 1.5x kombo ödülü)
      for (final mode in <String>['osmantus', 'makara', 'makarayiz']) {
        final mods = liveOps.getModifiersForMode(
          mode,
          overrideActiveEvents: const <LiveOpsEventType>[
            LiveOpsEventType.osmantusMakaraMusicNight,
          ],
        );
        expect(mods.comboRewardMultiplier, 1.5);
        expect(mods.activeEventIds, contains('osmantus_makara_music_night'));
      }

      // 4. Büyük Birleşim Çılgınlığı (suika, grid2048, match3, connect modlarında ekstra yıldız şansı)
      for (final mode in <String>['suika', 'grid2048', 'match3', 'connect']) {
        final mods = liveOps.getModifiersForMode(
          mode,
          overrideActiveEvents: const <LiveOpsEventType>[
            LiveOpsEventType.grandMergeFrenzy,
          ],
        );
        expect(mods.extraStarChance, greaterThan(0.0));
        expect(mods.activeEventIds, contains('grand_merge_frenzy'));
      }
    });

    test('Haftanın gününe ve saatine göre 4 LiveOps etkinliği deterministik olarak aktifleşir', () {
      // Çarşamba 09:00 -> Büyük Birleşim Çılgınlığı
      final wedMorning = DateTime(2026, 11, 4, 9, 0); // Çarşamba
      final wedEvents = liveOps.getActiveEvents(at: wedMorning);
      expect(
        wedEvents.map((e) => e.type),
        contains(LiveOpsEventType.grandMergeFrenzy),
      );

      // Salı 14:00 -> Terlik Fırtınası Maratonu
      final tueAfternoon = DateTime(2026, 11, 3, 14, 0); // Salı
      final tueEvents = liveOps.getActiveEvents(at: tueAfternoon);
      expect(
        tueEvents.map((e) => e.type),
        contains(LiveOpsEventType.slipperStormMarathon),
      );

      // Perşembe 20:00 -> Osmantuş & Makara Müzik Gecesi
      final thuNight = DateTime(2026, 11, 5, 20, 0); // Perşembe
      final thuEvents = liveOps.getActiveEvents(at: thuNight);
      expect(
        thuEvents.map((e) => e.type),
        contains(LiveOpsEventType.osmantusMakaraMusicNight),
      );

      // Cumartesi 15:00 -> Altın Yağmuru Festivali + Terlik Fırtınası Maratonu
      final satAfternoon = DateTime(2026, 11, 7, 15, 0); // Cumartesi
      final satEvents = liveOps.getActiveEvents(at: satAfternoon);
      expect(
        satEvents.map((e) => e.type),
        containsAll(<LiveOpsEventType>[
          LiveOpsEventType.goldRainFestival,
          LiveOpsEventType.slipperStormMarathon,
        ]),
      );
    });

    test('Çevrimdışı Böcek Kavanozu highestUnlockedTier seviyesine göre birikir ve 8 saat / 2.400 altın tavanını aşmaz', () {
      final baseTime = DateTime(2026, 11, 4, 10, 0);

      // Tier 1 (1.0 altın/dk) ile 60 dakika çevrimdışı -> 60 altın
      final tier1Claim = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 1,
        currentCoinBalance: 500,
        lastActiveAt: baseTime,
        now: baseTime.add(const Duration(minutes: 60)),
        claimId: 'jar_claim_tier1_60m',
      );
      expect(tier1Claim.isSuccess, isTrue);
      expect(tier1Claim.accumulatedMinutes, 60);
      expect(tier1Claim.grantedCoins, 60);
      expect(tier1Claim.newCoinBalance, 560);

      // Tier 12 (5.0 altın/dk) ile 8 saat (480 dk) çevrimdışı -> tam 2.400 altın
      final afterFirstClaim = baseTime.add(const Duration(minutes: 60));
      final tier12FullJar = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 12,
        currentCoinBalance: tier1Claim.newCoinBalance,
        lastActiveAt: afterFirstClaim,
        now: afterFirstClaim.add(const Duration(hours: 8)),
        claimId: 'jar_claim_tier12_8h',
      );
      expect(tier12FullJar.isSuccess, isTrue);
      expect(tier12FullJar.accumulatedMinutes, 480);
      expect(tier12FullJar.grantedCoins, 2400);
      expect(tier12FullJar.newCoinBalance, 2960);

      // 14 saat çevrimdışı kalınsa bile maksimum 8 saat (480 dk) ve 2.400 altın tavanı uygulanır
      final afterSecondClaim = afterFirstClaim.add(const Duration(hours: 8));
      final cappedClaim = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 12,
        currentCoinBalance: tier12FullJar.newCoinBalance,
        lastActiveAt: afterSecondClaim,
        now: afterSecondClaim.add(const Duration(hours: 14)),
        claimId: 'jar_claim_tier12_14h_capped',
      );
      expect(cappedClaim.isSuccess, isTrue);
      expect(cappedClaim.accumulatedMinutes, 480);
      expect(cappedClaim.grantedCoins, 2400);
    });

    test('AntiCheatService cihaz saati geri/ileri alma ve replay hilelerini engeller', () {
      final logoutTime = DateTime(2026, 11, 4, 12, 0);
      expect(liveOps.recordPlayerActiveTimestamp(now: logoutTime), isTrue);

      // 1. Cihaz saatini geri alma hilesi (clock rollback)
      final rollbackResult = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 8,
        currentCoinBalance: 1000,
        lastActiveAt: logoutTime,
        now: logoutTime.subtract(const Duration(minutes: 30)),
        claimId: 'rollback_attempt',
      );
      expect(rollbackResult.isSuccess, isFalse);
      expect(rollbackResult.grantedCoins, 0);
      expect(rollbackResult.reason, 'clock_rollback_detected');

      // 2. Cihaz saatini aşırı ileri alma hilesi (forward clock jump > 30 gün)
      final forwardTamperResult = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 8,
        currentCoinBalance: 1000,
        lastActiveAt: logoutTime,
        now: logoutTime.add(const Duration(days: 45)),
        claimId: 'forward_tamper_attempt',
      );
      expect(forwardTamperResult.isSuccess, isFalse);
      expect(forwardTamperResult.grantedCoins, 0);
      expect(forwardTamperResult.reason, 'clock_forward_tamper_detected');

      // 3. Geçerli bir talep sonrası aynı claimId (replay attack) veya geri tarihli talep reddedilir
      final validNow = logoutTime.add(const Duration(hours: 2));
      final validClaim = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 6,
        currentCoinBalance: 1000,
        lastActiveAt: logoutTime,
        now: validNow,
        claimId: 'unique_jar_nonce_001',
      );
      expect(validClaim.isSuccess, isTrue);
      expect(validClaim.grantedCoins, greaterThan(0));

      final replayAttempt = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 6,
        currentCoinBalance: validClaim.newCoinBalance,
        lastActiveAt: validNow,
        now: validNow.add(const Duration(hours: 1)),
        claimId: 'unique_jar_nonce_001',
      );
      expect(replayAttempt.isSuccess, isFalse);
      expect(replayAttempt.grantedCoins, 0);
      expect(replayAttempt.reason, 'anti_cheat_cooldown_or_replay_blocked');

      // Gözlemlenen en yüksek zamandan (validNow) daha eski bir zamana dönülürse engellenir
      final monotonicRollback = liveOps.claimIdleJarCoins(
        highestUnlockedTier: 6,
        currentCoinBalance: validClaim.newCoinBalance,
        lastActiveAt: logoutTime,
        now: validNow.subtract(const Duration(minutes: 10)),
        claimId: 'unique_jar_nonce_002',
      );
      expect(monotonicRollback.isSuccess, isFalse);
      expect(monotonicRollback.reason, 'clock_rollback_detected');
    });
  });
}
