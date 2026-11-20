import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/adaptive_difficulty_service.dart';
import 'package:lululu_game/services/difficulty_binding.dart';

/// 12C1 — AdaptiveDifficulty bağlama testleri.
///
/// Kural: her mod bitişi `recordMatchResult` ile kaydedilir, profil
/// kalıcıdır (`lululu_adaptive_difficulty_v1`); 3 yenilgi merhamet
/// desteğini açar (hız 0.88), 3 zafer zorluğu artırır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AdaptiveDifficultyService.instance.resetAll();
    DifficultyBinding.instance.resetForTesting();
  });

  group('AdaptiveDifficultyService profili', () {
    test('3 yenilgi sonrası merhamet desteği aktifleşir', () {
      final dda = AdaptiveDifficultyService();
      dda.recordMatchResult(mode: 'suika', score: 500, won: false);
      dda.recordMatchResult(mode: 'suika', score: 450, won: false);
      final profile = dda.recordMatchResult(
        mode: 'suika',
        score: 400,
        won: false,
      );

      expect(profile.lossStreak, 3);
      expect(profile.isMercyBoostActive, isTrue);
      expect(profile.speedMultiplier, closeTo(0.88, 1e-6));
      expect(profile.bonusStartingBoosters, greaterThanOrEqualTo(1));
      expect(profile.spawnFavorability, greaterThan(1.0));
      expect(profile.difficultyTierLabel, 'mercy');
    });

    test('3 zafer sonrası zorluk artar', () {
      final dda = AdaptiveDifficultyService();
      dda.recordMatchResult(mode: 'suika', score: 4000, won: true);
      dda.recordMatchResult(mode: 'suika', score: 4200, won: true);
      final profile = dda.recordMatchResult(
        mode: 'suika',
        score: 4400,
        won: true,
      );

      expect(profile.winStreak, 3);
      expect(profile.isMercyBoostActive, isFalse);
      expect(profile.speedMultiplier, greaterThan(1.0));
      expect(profile.skillScoreBonusMultiplier, greaterThan(1.0));
      expect(profile.spawnFavorability, lessThanOrEqualTo(1.0));
    });

    test('nötr profil tarafsızdır', () {
      final dda = AdaptiveDifficultyService();
      final profile = dda.getProfileForMode('suika');
      expect(profile.isMercyBoostActive, isFalse);
      expect(profile.bonusStartingBoosters, 0);
      expect(profile.speedMultiplier, inInclusiveRange(0.88, 1.35));
      expect(profile.spawnFavorability, inInclusiveRange(0.85, 1.25));
    });

    test('mod takma adları kanonik moda çözülür', () {
      final dda = AdaptiveDifficultyService();
      dda.recordMatchResult(mode: 'grid_2048', score: 3000, won: true);
      dda.recordMatchResult(mode: 'terlikTap', score: 500, won: false);
      expect(dda.getStatsForMode('grid2048').matchesPlayed, 1);
      expect(dda.getStatsForMode('terlik').matchesPlayed, 1);
    });
  });

  group('Profil kalıcılığı', () {
    test('kaydet + yeniden yükle: 3 yenilgi merhameti korunur', () async {
      final dda = AdaptiveDifficultyService();
      dda.recordMatchResult(mode: 'terlik', score: 500, won: false);
      dda.recordMatchResult(mode: 'terlik', score: 450, won: false);
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

  group('DifficultyBinding (mod bitişi kaydı)', () {
    test('recordRun 3 yenilgiyi kaydeder ve merhameti kalıcı yazar',
        () async {
      final binding = DifficultyBinding.instance;
      await binding.recordRun(mode: 'suika', score: 500, won: false);
      await binding.recordRun(mode: 'suika', score: 450, won: false);
      await binding.recordRun(mode: 'suika', score: 400, won: false);

      final cached = binding.cachedProfileForMode('suika');
      expect(cached.isMercyBoostActive, isTrue);
      expect(cached.lossStreak, 3);
      expect(cached.speedMultiplier, closeTo(0.88, 1e-6));

      // Yeni servis örneği kalıcı profili okur (bağlama yazar).
      final restored = AdaptiveDifficultyService();
      await restored.loadFromPreferences();
      expect(
        restored.getProfileForMode('suika').isMercyBoostActive,
        isTrue,
      );
    });

    test('recordRun zaferi kaydeder, profil zorlaşır', () async {
      final binding = DifficultyBinding.instance;
      await binding.recordRun(mode: 'suika', score: 4000, won: true);
      await binding.recordRun(mode: 'suika', score: 4200, won: true);
      await binding.recordRun(mode: 'suika', score: 4400, won: true);

      final cached = binding.cachedProfileForMode('suika');
      expect(cached.isMercyBoostActive, isFalse);
      expect(cached.winStreak, 3);
      expect(cached.speedMultiplier, greaterThan(1.0));
    });

    test('yüklenmeden önce önbellek tarafsız profil döner', () {
      final fresh = AdaptiveDifficultyService();
      final profile = fresh.getProfileForMode('stack');
      expect(profile.isMercyBoostActive, isFalse);
      expect(profile.speedMultiplier, inInclusiveRange(0.88, 1.35));
    });
  });
}
