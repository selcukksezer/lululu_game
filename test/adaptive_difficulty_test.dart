import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/adaptive_difficulty_service.dart';

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
}
