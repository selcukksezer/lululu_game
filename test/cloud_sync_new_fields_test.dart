// Dalga 2 — CloudSync: sezon XP'si / kazanılan başarımlar / en iyi kombo
// profil payload round-trip testleri.
//
// Kapsar: payload yeni alanları + damgaları taşır, sınırlara kelepçeler,
// bilinmeyen başarım kimliğini atar; pull'da XP ve bestCombo yalnız-büyür
// (max), başarım listesi birleşim (union); birleşme ödül tekrarı yapmaz;
// sınır dışı uzak değer snapshot'ı reddeder; damga kalıcılığı; bestCombo
// birleşmesinin prefs yazımı.
//
// Kurulum deseni test/cloud_sync_lww_8e_test.dart'tan alındı:
// `setMockInitialValues` + olay döngüsüne bir tur +
// `EnergyService.load()` + `ProgressManager.load()` ile singleton
// sıfırlama; başarım durumu `resetForTesting()` + `load()` ile sıfırlanır.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/achievement_pass_service.dart';
import 'package:lululu_game/services/cloud_sync_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cloud = CloudSyncService.instance;
  final aps = AchievementPassService.instance;

  Future<void> loadSeeded({int coins = 1000, int energy = 10}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lululu_coins': coins,
      'lululu.energy': energy,
      'lululu.energy_last_refill': nowMs,
      'lululu.energy_last_seen': nowMs,
    });
    await Future<void>.delayed(Duration.zero);
    await EnergyService.instance.load();
    await ProgressManager.instance.load();
    await aps.resetForTesting();
    await aps.load();
  }

  /// Yerel Dalga 2 durumunu senkron kurar: XP `addSeasonXp` ile
  /// eklenir (damga sonra ezilir), başarımlar kümeye doğrudan yazılır,
  /// bestCombo PM alanına doğrudan yazılır.
  Future<void> resetNewFields({
    int seasonXp = 0,
    int seasonXpStamp = 10000,
    Set<String> achievements = const <String>{},
    int achievementsStamp = 10000,
    int bestCombo = 0,
  }) async {
    final pm = ProgressManager.instance;
    await aps.resetForTesting();
    if (seasonXp > 0) {
      await aps.addSeasonXp(seasonXp);
    }
    aps.seasonXpUpdatedAtMs = seasonXpStamp;
    aps.unlockedAchievementIds
      ..clear()
      ..addAll(achievements);
    aps.achievementsUpdatedAtMs = achievementsStamp;
    pm.bestCombo = bestCombo;
  }

  /// Uzak profil yükünü HMAC ile imzalar.
  Map<String, dynamic> signedRemote(Map<String, dynamic> fields) {
    final payload = Map<String, dynamic>.from(fields);
    payload['integrityHash'] = cloud.computeIntegrityHash(payload);
    return payload;
  }

  group('payload: yeni alanlar', () {
    test('payload sezon XP / başarımlar / bestCombo + damgaları taşır',
        () async {
      await loadSeeded();
      await resetNewFields(
        seasonXp: 500,
        seasonXpStamp: 10000,
        achievements: const {'merge_first', 'combo_5x'},
        achievementsStamp: 12000,
        bestCombo: 7,
      );
      final payload = cloud.buildSignedProfilePayload();
      expect(payload['seasonXp'], 500);
      expect(payload['unlockedAchievements'], ['combo_5x', 'merge_first']);
      expect(payload['bestCombo'], 7);
      expect(payload['seasonXpUpdatedAtMs'], 10000);
      expect(payload['unlockedAchievementsUpdatedAtMs'], 12000);
      expect(
        CloudSyncService.validateProfilePayloadForRules(payload),
        isEmpty,
      );
      expect(cloud.verifyIntegrityHash(payload), isTrue);
      // Damgalar imzaya dahildir: yeni damga değişince imza geçersiz olur.
      final tampered = Map<String, dynamic>.from(payload);
      tampered['seasonXpUpdatedAtMs'] = 9999;
      expect(cloud.verifyIntegrityHash(tampered), isFalse);
    });

    test('payload bilinmeyen kimliği atar, sınırlara kelepçeler', () async {
      await loadSeeded();
      await resetNewFields(
        achievements: const {'merge_first', 'gelecekteki_basarim_x'},
        bestCombo: 2000000,
      );
      await aps.addSeasonXp(99999999);
      final payload = cloud.buildSignedProfilePayload();
      expect(payload['seasonXp'], CloudSyncService.maxValidSeasonXp);
      expect(payload['unlockedAchievements'], ['merge_first']);
      expect(payload['bestCombo'], CloudSyncService.maxValidBestCombo);
      expect(
        CloudSyncService.validateProfilePayloadForRules(payload),
        isEmpty,
      );
    });

    test('ön-denetim bozuk yeni alanı reddeder', () async {
      await loadSeeded();
      await resetNewFields(seasonXp: 500, bestCombo: 7);
      final payload = cloud.buildSignedProfilePayload();
      final badXp = Map<String, dynamic>.from(payload);
      badXp['seasonXp'] = -1;
      expect(
        CloudSyncService.validateProfilePayloadForRules(badXp),
        isNotEmpty,
      );
      final badCombo = Map<String, dynamic>.from(payload);
      badCombo['bestCombo'] = 1000000;
      expect(
        CloudSyncService.validateProfilePayloadForRules(badCombo),
        isNotEmpty,
      );
      final badList = Map<String, dynamic>.from(payload);
      badList['unlockedAchievements'] = ['merge_first', 42];
      expect(
        CloudSyncService.validateProfilePayloadForRules(badList),
        isNotEmpty,
      );
      final badStamp = Map<String, dynamic>.from(payload);
      badStamp['seasonXpUpdatedAtMs'] = -1;
      expect(
        CloudSyncService.validateProfilePayloadForRules(badStamp),
        isNotEmpty,
      );
    });
  });

  group('pull: yalnız-büyür + birleşim', () {
    test('round-trip: A payload\'u B\'de max + union ile birleşir', () async {
      await loadSeeded();
      // A cihazı: XP 500, {merge_first}, kombo 7.
      await resetNewFields(
        seasonXp: 500,
        achievements: const {'merge_first'},
        bestCombo: 7,
      );
      final payloadA = cloud.buildSignedProfilePayload();
      // B cihazı: XP 800 (daha yüksek), {combo_5x}, kombo 12.
      await resetNewFields(
        seasonXp: 800,
        achievements: const {'combo_5x'},
        bestCombo: 12,
      );
      final ok = await cloud.applyTimestampedProfileSnapshot(payloadA);
      expect(ok, isTrue);
      expect(aps.seasonXp, 800);
      expect(aps.unlockedAchievementIds, {'merge_first', 'combo_5x'});
      expect(ProgressManager.instance.bestCombo, 12);
    });

    test('round-trip: A daha yüksekse B yükselir', () async {
      await loadSeeded();
      await resetNewFields(
        seasonXp: 500,
        achievements: const {'merge_first'},
        bestCombo: 7,
      );
      final payloadA = cloud.buildSignedProfilePayload();
      await resetNewFields(seasonXp: 300, bestCombo: 3);
      final ok = await cloud.applyTimestampedProfileSnapshot(payloadA);
      expect(ok, isTrue);
      expect(aps.seasonXp, 500);
      expect(aps.unlockedAchievementIds, {'merge_first'});
      expect(ProgressManager.instance.bestCombo, 7);
    });

    test('düşük uzak değer yereli azaltmaz', () async {
      await loadSeeded();
      await resetNewFields(
        seasonXp: 800,
        achievements: const {'combo_5x'},
        bestCombo: 12,
      );
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'seasonXp': 100,
          'unlockedAchievements': <String>[],
          'bestCombo': 2,
        }),
      );
      expect(ok, isTrue);
      expect(aps.seasonXp, 800);
      expect(aps.unlockedAchievementIds, {'combo_5x'});
      expect(ProgressManager.instance.bestCombo, 12);
    });

    test('bilinmeyen uzak başarım kimliği atılır, bilinen birleşir',
        () async {
      await loadSeeded();
      await resetNewFields(achievements: const {'merge_first'});
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'unlockedAchievements': ['combo_5x', 'bilinmeyen_basarim'],
        }),
      );
      expect(ok, isTrue);
      expect(aps.unlockedAchievementIds, {'merge_first', 'combo_5x'});
    });

    test('birleşme ödül tekrarı yapmaz', () async {
      await loadSeeded();
      await resetNewFields();
      final pm = ProgressManager.instance;
      pm.coins = 1000;
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          // merge_first tek başına 100 altın + 60 XP ödüllü; birleşme
          // yalnız kimliği ekler, ödülü vermez.
          'unlockedAchievements': ['merge_first'],
        }),
      );
      expect(ok, isTrue);
      expect(aps.unlockedAchievementIds, {'merge_first'});
      expect(pm.coins, 1000);
      expect(aps.seasonXp, 0);
    });

    test('sınır dışı uzak sezon XP / bestCombo snapshot\'ı reddeder',
        () async {
      await loadSeeded();
      await resetNewFields(seasonXp: 800, bestCombo: 12);
      var ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{'seasonXp': -1}),
      );
      expect(ok, isFalse);
      expect(aps.seasonXp, 800);
      ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'seasonXp': CloudSyncService.maxValidSeasonXp + 1,
        }),
      );
      expect(ok, isFalse);
      expect(aps.seasonXp, 800);
      ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{'bestCombo': -5}),
      );
      expect(ok, isFalse);
      expect(ProgressManager.instance.bestCombo, 12);
    });

    test('bestCombo birleşmesi prefs\'e yazılır', () async {
      await loadSeeded();
      await resetNewFields(bestCombo: 5);
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{'bestCombo': 15}),
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.bestCombo, 15);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('lululu_best_combo'), 15);
    });
  });

  group('damga kalıcılığı', () {
    test('addSeasonXp / unlockAchievement damgayı ilerletir ve saklar',
        () async {
      await loadSeeded();
      await aps.resetForTesting();
      expect(aps.seasonXpUpdatedAtMs, 0);
      expect(aps.achievementsUpdatedAtMs, 0);
      await aps.addSeasonXp(60);
      expect(aps.seasonXpUpdatedAtMs, greaterThan(0));
      await aps.unlockAchievement('merge_first');
      expect(aps.achievementsUpdatedAtMs, greaterThan(0));
      // Bellek içi damgalar sıfırlanıp yeniden yüklenince prefs'ten döner.
      final xpStamp = aps.seasonXpUpdatedAtMs;
      final achStamp = aps.achievementsUpdatedAtMs;
      aps.seasonXpUpdatedAtMs = 0;
      aps.achievementsUpdatedAtMs = 0;
      await aps.load();
      expect(aps.seasonXpUpdatedAtMs, xpStamp);
      expect(aps.achievementsUpdatedAtMs, achStamp);
      expect(aps.seasonXp, 120);
      expect(aps.unlockedAchievementIds, {'merge_first'});
    });

    test('applyCloudMerge değişimde damgayı ilerletir, değişimsiz yazmaz',
        () async {
      await loadSeeded();
      await resetNewFields(seasonXp: 500, seasonXpStamp: 10000);
      await aps.applyCloudMerge(
        remoteSeasonXp: 100,
        remoteAchievementIds: const <String>[],
        nowMs: 20000,
      );
      expect(aps.seasonXp, 500);
      expect(aps.seasonXpUpdatedAtMs, 10000);
      await aps.applyCloudMerge(
        remoteSeasonXp: 900,
        remoteAchievementIds: const ['combo_5x'],
        nowMs: 20000,
      );
      expect(aps.seasonXp, 900);
      expect(aps.seasonXpUpdatedAtMs, 20000);
      expect(aps.achievementsUpdatedAtMs, 20000);
      expect(aps.unlockedAchievementIds, {'combo_5x'});
    });
  });
}
