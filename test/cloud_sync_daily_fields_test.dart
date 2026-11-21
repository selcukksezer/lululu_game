// Dalga 3 — CloudSync: günlük ödül hak günü / görev ilerlemesi /
// ücretsiz enerji hakları profil payload round-trip testleri.
//
// Kapsar: payload yeni alanları + damgaları taşır, sınırlara kelepçeler,
// bilinmeyen görev kimliğini atar; pull'da gün anahtarı sürümdür (yeni
// gün kazanır, eşit günde ilerleme max + ödül birleşimi, eski gün
// yereli korur); başka cihazda bugün alınan ödül claim kapısını
// kapatır (çift-claim engeli); flush yakınsaması bayat yerelin bulutu
// ezmesini önler; bozuk uzak gün / sınır dışı hak sayısı snapshot'ı
// reddeder; damga kalıcılığı; gün anahtarı karşılaştırması
// (sözlüksel tuzak: `2026-11-5` > `2026-11-15` sözlüksel olarak).
//
// Kurulum deseni test/cloud_sync_new_fields_test.dart'tan alındı:
// `setMockInitialValues` + olay döngüsüne bir tur +
// `EnergyService.load()` + `ProgressManager.load()` ile singleton
// sıfırlama.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/cloud_sync_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cloud = CloudSyncService.instance;
  final pm = ProgressManager.instance;

  /// `_todayKey` ile aynı biçim (`yyyy-M-d`, sıfır dolgusuz).
  String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  String todayKey() => dayKey(DateTime.now());
  String yesterdayKey() =>
      dayKey(DateTime.now().subtract(const Duration(days: 1)));
  String tomorrowKey() => dayKey(DateTime.now().add(const Duration(days: 1)));

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
  }

  /// Yerel Dalga 3 durumunu senkron kurar; damga fark anlık
  /// görüntüsü eşitlenir (kurulum değişim sayılmaz).
  void resetDaily({
    String lastStreakClaimDay = '',
    String cloudLastStreakClaimDay = '',
    String dailyTasksDay = '',
    Map<String, int> progress = const <String, int>{},
    Set<String> claimed = const <String>{},
    String lastDailyFreeEnergyDay = '',
    int dailyFreeEnergyClaimsToday = 0,
    String cloudDailyFreeEnergyDay = '',
    int cloudDailyFreeEnergyClaims = 0,
  }) {
    pm.lastStreakClaimDay = lastStreakClaimDay;
    pm.cloudLastStreakClaimDay = cloudLastStreakClaimDay;
    pm.dailyTasksDay = dailyTasksDay;
    pm.dailyTaskProgress.updateAll((_, _) => 0);
    for (final entry in progress.entries) {
      pm.dailyTaskProgress[entry.key] = entry.value;
    }
    pm.claimedDailyTasks
      ..clear()
      ..addAll(claimed);
    pm.lastDailyFreeEnergyDay = lastDailyFreeEnergyDay;
    pm.dailyFreeEnergyClaimsToday = dailyFreeEnergyClaimsToday;
    pm.cloudDailyFreeEnergyDay = cloudDailyFreeEnergyDay;
    pm.cloudDailyFreeEnergyClaims = cloudDailyFreeEnergyClaims;
    pm.syncPersistedSnapshot();
  }

  /// Dalga 3 damgalarını sıfırlar (kalıcılık testleri için).
  void zeroDailyStamps() {
    pm.lastStreakClaimDayUpdatedAtMs = 0;
    pm.dailyTasksUpdatedAtMs = 0;
    pm.dailyFreeEnergyUpdatedAtMs = 0;
    pm.syncPersistedSnapshot();
  }

  /// Uzak profil yükünü HMAC ile imzalar.
  Map<String, dynamic> signedRemote(Map<String, dynamic> fields) {
    final payload = Map<String, dynamic>.from(fields);
    payload['integrityHash'] = cloud.computeIntegrityHash(payload);
    return payload;
  }

  group('payload: yeni alanlar', () {
    test('payload günlük alanları + damgaları taşır', () async {
      await loadSeeded();
      resetDaily(
        lastStreakClaimDay: todayKey(),
        dailyTasksDay: todayKey(),
        progress: const {'play': 3, 'merge': 2},
        claimed: const {'play'},
        lastDailyFreeEnergyDay: todayKey(),
        dailyFreeEnergyClaimsToday: 2,
      );
      pm.lastStreakClaimDayUpdatedAtMs = 10000;
      pm.dailyTasksUpdatedAtMs = 11000;
      pm.dailyFreeEnergyUpdatedAtMs = 12000;
      final payload = cloud.buildSignedProfilePayload();
      expect(payload['lastStreakClaimDay'], todayKey());
      expect(payload['dailyTasksDay'], todayKey());
      expect(payload['dailyTasksProgress'], {
        'play': 3,
        'merge': 2,
        'video': 0,
        'combo': 0,
      });
      expect(payload['dailyTasksClaimed'], ['play']);
      expect(payload['dailyFreeEnergyDay'], todayKey());
      expect(payload['dailyFreeEnergyClaims'], 2);
      expect(payload['lastStreakClaimDayUpdatedAtMs'], 10000);
      expect(payload['dailyTasksUpdatedAtMs'], 11000);
      expect(payload['dailyFreeEnergyUpdatedAtMs'], 12000);
      expect(
        CloudSyncService.validateProfilePayloadForRules(payload),
        isEmpty,
      );
      expect(cloud.verifyIntegrityHash(payload), isTrue);
      // Damgalar imzaya dahildir: yeni damga değişince imza geçersiz olur.
      final tampered = Map<String, dynamic>.from(payload);
      tampered['dailyTasksUpdatedAtMs'] = 9999;
      expect(cloud.verifyIntegrityHash(tampered), isFalse);
    });

    test('payload bilinmeyen görev kimliğini atar, sınırlara kelepçeler',
        () async {
      await loadSeeded();
      resetDaily(
        dailyTasksDay: todayKey(),
        progress: const {'play': 5000},
        claimed: const {'play', 'bilinmeyen_gorev'},
        lastDailyFreeEnergyDay: todayKey(),
        dailyFreeEnergyClaimsToday: 99,
      );
      final payload = cloud.buildSignedProfilePayload();
      expect(
        (payload['dailyTasksProgress'] as Map)['play'],
        CloudSyncService.maxDailyTaskProgressValue,
      );
      expect(payload['dailyTasksClaimed'], ['play']);
      expect(
        payload['dailyFreeEnergyClaims'],
        CloudSyncService.maxDailyFreeEnergyClaims,
      );
      expect(
        CloudSyncService.validateProfilePayloadForRules(payload),
        isEmpty,
      );
    });

    test('ön-denetim bozuk yeni alanı reddeder', () async {
      await loadSeeded();
      resetDaily(
        lastStreakClaimDay: todayKey(),
        dailyTasksDay: todayKey(),
        lastDailyFreeEnergyDay: todayKey(),
        dailyFreeEnergyClaimsToday: 1,
      );
      final payload = cloud.buildSignedProfilePayload();
      final badDay = Map<String, dynamic>.from(payload);
      badDay['lastStreakClaimDay'] = 'bugün';
      expect(
        CloudSyncService.validateProfilePayloadForRules(badDay),
        isNotEmpty,
      );
      final badTasksDay = Map<String, dynamic>.from(payload);
      badTasksDay['dailyTasksDay'] = '2026-13-40';
      expect(
        CloudSyncService.validateProfilePayloadForRules(badTasksDay),
        isNotEmpty,
      );
      final badProgress = Map<String, dynamic>.from(payload);
      badProgress['dailyTasksProgress'] = {'play': -1};
      expect(
        CloudSyncService.validateProfilePayloadForRules(badProgress),
        isNotEmpty,
      );
      final unknownProgress = Map<String, dynamic>.from(payload);
      unknownProgress['dailyTasksProgress'] = {'bilinmeyen': 1};
      expect(
        CloudSyncService.validateProfilePayloadForRules(unknownProgress),
        isNotEmpty,
      );
      final badClaimed = Map<String, dynamic>.from(payload);
      badClaimed['dailyTasksClaimed'] = ['play', 'bilinmeyen_gorev'];
      expect(
        CloudSyncService.validateProfilePayloadForRules(badClaimed),
        isNotEmpty,
      );
      final badClaims = Map<String, dynamic>.from(payload);
      badClaims['dailyFreeEnergyClaims'] =
          CloudSyncService.maxDailyFreeEnergyClaims + 1;
      expect(
        CloudSyncService.validateProfilePayloadForRules(badClaims),
        isNotEmpty,
      );
      final badStamp = Map<String, dynamic>.from(payload);
      badStamp['dailyTasksUpdatedAtMs'] = -1;
      expect(
        CloudSyncService.validateProfilePayloadForRules(badStamp),
        isNotEmpty,
      );
    });
  });

  group('pull: gün birleştirme + çift-claim engeli', () {
    test('round-trip: A bugün ödülü aldı, B\'de claim kapanır', () async {
      await loadSeeded();
      // A cihazı: hediye kutusunu bugün alır.
      resetDaily();
      zeroDailyStamps();
      final reward = await pm.claimDailyGiftBox();
      expect(reward, isNotNull);
      final payloadA = cloud.buildSignedProfilePayload();
      // B cihazı: bugün henüz almamış.
      resetDaily();
      expect(pm.canClaimDailyGiftBox, isTrue);
      final ok = await cloud.applyTimestampedProfileSnapshot(payloadA);
      expect(ok, isTrue);
      expect(pm.lastStreakClaimDay, todayKey());
      expect(pm.cloudLastStreakClaimDay, todayKey());
      expect(pm.canClaimDailyGiftBox, isFalse);
      expect(await pm.claimDailyGiftBox(), isNull);
    });

    test('yalnız buluttan bilinen hak günü de claim kapısını kapatır',
        () async {
      await loadSeeded();
      resetDaily(cloudLastStreakClaimDay: todayKey());
      expect(pm.lastStreakClaimDay, isEmpty);
      expect(pm.canClaimDailyGiftBox, isFalse);
      expect(await pm.claimDailyGiftBox(), isNull);
    });

    test('aynı gün görev ilerlemesi max + ödül birleşimi', () async {
      await loadSeeded();
      // Uzak (A): play 3/3 tamam + ödülü alınmış, merge 1.
      resetDaily(
        dailyTasksDay: todayKey(),
        progress: const {'play': 3, 'merge': 1},
        claimed: const {'play'},
      );
      final payloadA = cloud.buildSignedProfilePayload();
      // Yerel (B): play 2, merge 5/5 tamam, ödül alınmamış.
      resetDaily(
        dailyTasksDay: todayKey(),
        progress: const {'play': 2, 'merge': 5},
      );
      final ok = await cloud.applyTimestampedProfileSnapshot(payloadA);
      expect(ok, isTrue);
      expect(pm.dailyTasksDay, todayKey());
      expect(pm.dailyTaskProgress['play'], 3);
      expect(pm.dailyTaskProgress['merge'], 5);
      expect(pm.claimedDailyTasks, {'play'});
      // Alınmış ödül tekrar verilmez.
      expect(
        await pm.claimDailyTaskReward('play', target: 3),
        isFalse,
      );
    });

    test('yeni gün toptan benimsenir', () async {
      await loadSeeded();
      // Uzak (A): bugün, merge 2, ödül yok.
      resetDaily(
        dailyTasksDay: todayKey(),
        progress: const {'merge': 2},
      );
      final payloadA = cloud.buildSignedProfilePayload();
      // Yerel (B): dün, play 3 + ödülü alınmış.
      resetDaily(
        dailyTasksDay: yesterdayKey(),
        progress: const {'play': 3},
        claimed: const {'play'},
      );
      final ok = await cloud.applyTimestampedProfileSnapshot(payloadA);
      expect(ok, isTrue);
      expect(pm.dailyTasksDay, todayKey());
      expect(pm.dailyTaskProgress['play'], 0);
      expect(pm.dailyTaskProgress['merge'], 2);
      expect(pm.claimedDailyTasks, isEmpty);
    });

    test('eski gün yereli korur', () async {
      await loadSeeded();
      resetDaily(
        dailyTasksDay: todayKey(),
        progress: const {'play': 3},
        claimed: const {'play'},
      );
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'dailyTasksDay': yesterdayKey(),
          'dailyTasksProgress': {'play': 1, 'merge': 5},
          'dailyTasksClaimed': <String>[],
        }),
      );
      expect(ok, isTrue);
      expect(pm.dailyTasksDay, todayKey());
      expect(pm.dailyTaskProgress['play'], 3);
      expect(pm.dailyTaskProgress['merge'], 0);
      expect(pm.claimedDailyTasks, {'play'});
    });

    test('ücretsiz enerji aynı gün max, yeni gün benimsenir', () async {
      await loadSeeded();
      // Aynı gün: yerel 1 hak, uzak 2 hak → 2.
      resetDaily(
        lastDailyFreeEnergyDay: todayKey(),
        dailyFreeEnergyClaimsToday: 1,
      );
      var ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'dailyFreeEnergyDay': todayKey(),
          'dailyFreeEnergyClaims': 2,
        }),
      );
      expect(ok, isTrue);
      expect(pm.lastDailyFreeEnergyDay, todayKey());
      expect(pm.dailyFreeEnergyClaimsToday, 2);
      expect(pm.cloudDailyFreeEnergyDay, todayKey());
      expect(pm.cloudDailyFreeEnergyClaims, 2);
      expect(pm.canClaimDailyFreeEnergy, isFalse);
      // Yeni gün: uzak yarın 1 hak → gün + sayı benimsenir.
      ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'dailyFreeEnergyDay': tomorrowKey(),
          'dailyFreeEnergyClaims': 1,
        }),
      );
      expect(ok, isTrue);
      expect(pm.lastDailyFreeEnergyDay, tomorrowKey());
      expect(pm.dailyFreeEnergyClaimsToday, 1);
      expect(pm.cloudDailyFreeEnergyDay, tomorrowKey());
      expect(pm.cloudDailyFreeEnergyClaims, 1);
    });

    test('buluttan bilinen hak sayısı reklam yolunda da sayılır', () async {
      await loadSeeded();
      resetDaily(
        cloudDailyFreeEnergyDay: todayKey(),
        cloudDailyFreeEnergyClaims: 2,
      );
      expect(pm.canClaimDailyFreeEnergy, isFalse);
      expect(pm.canClaimAdFreeEnergy, isTrue);
      expect(pm.effectiveFreeEnergyClaimsToday, 2);
      final granted =
          await pm.claimDailyFreeEnergy(fromRewardedAd: true);
      expect(granted, isTrue);
      expect(pm.dailyFreeEnergyClaimsToday, 3);
      expect(pm.canClaimAdFreeEnergy, isFalse);
    });

    test('bozuk uzak gün / sınır dışı hak sayısı snapshot\'ı reddeder',
        () async {
      await loadSeeded();
      resetDaily(
        lastStreakClaimDay: todayKey(),
        dailyTasksDay: todayKey(),
        lastDailyFreeEnergyDay: todayKey(),
        dailyFreeEnergyClaimsToday: 1,
      );
      var ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{'lastStreakClaimDay': 'bugün'}),
      );
      expect(ok, isFalse);
      expect(pm.lastStreakClaimDay, todayKey());
      ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{'dailyTasksDay': '2026-13-40'}),
      );
      expect(ok, isFalse);
      expect(pm.dailyTasksDay, todayKey());
      ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{'dailyFreeEnergyClaims': 4}),
      );
      expect(ok, isFalse);
      expect(pm.dailyFreeEnergyClaimsToday, 1);
      ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{'dailyFreeEnergyClaims': -1}),
      );
      expect(ok, isFalse);
      expect(pm.dailyFreeEnergyClaimsToday, 1);
    });

    test('birleşen günlük durum prefs\'e yazılır', () async {
      await loadSeeded();
      resetDaily();
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'lastStreakClaimDay': todayKey(),
          'dailyTasksDay': todayKey(),
          'dailyTasksProgress': {'play': 3},
          'dailyTasksClaimed': ['play'],
          'dailyFreeEnergyDay': todayKey(),
          'dailyFreeEnergyClaims': 2,
        }),
      );
      expect(ok, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lululu_last_streak_claim_day'), todayKey());
      expect(prefs.getString('lululu_daily_tasks_day'), todayKey());
      expect(prefs.getString('lululu_daily_free_energy_day'), todayKey());
      expect(prefs.getInt('lululu_daily_free_energy_claims'), 2);
      expect(
        prefs.getString('lululu_cloud_last_streak_claim_day'),
        todayKey(),
      );
      expect(
        prefs.getString('lululu_cloud_daily_free_energy_day'),
        todayKey(),
      );
      expect(prefs.getInt('lululu_cloud_daily_free_energy_claims'), 2);
    });
  });

  group('flush yakınsaması', () {
    test('bayat yerel uzaktaki yeni hak gününü ezemez', () async {
      await loadSeeded();
      resetDaily(
        lastStreakClaimDay: yesterdayKey(),
        dailyTasksDay: yesterdayKey(),
        progress: const {'play': 3},
        claimed: const {'play'},
        lastDailyFreeEnergyDay: yesterdayKey(),
        dailyFreeEnergyClaimsToday: 1,
      );
      final localProfile = cloud.buildSignedProfilePayload();
      final remoteData = <String, dynamic>{
        'lastStreakClaimDay': todayKey(),
        'dailyTasksDay': todayKey(),
        'dailyTasksProgress': {'merge': 2},
        'dailyTasksClaimed': <String>[],
        'dailyFreeEnergyDay': todayKey(),
        'dailyFreeEnergyClaims': 2,
      };
      final merged = CloudSyncService.convergedDailyFieldsForFlush(
        localProfile: localProfile,
        remoteData: remoteData,
      );
      expect(merged['lastStreakClaimDay'], todayKey());
      expect(merged['dailyTasksDay'], todayKey());
      expect(
        (merged['dailyTasksProgress'] as Map)['merge'],
        2,
      );
      expect(
        (merged['dailyTasksProgress'] as Map)['play'],
        isNot(3),
      );
      expect(merged['dailyTasksClaimed'], isEmpty);
      expect(merged['dailyFreeEnergyDay'], todayKey());
      expect(merged['dailyFreeEnergyClaims'], 2);
      expect(cloud.verifyIntegrityHash(merged), isTrue);
      expect(
        CloudSyncService.validateProfilePayloadForRules(merged),
        isEmpty,
      );
    });

    test('eşit günde flush ilerlemeyi max ile birleştirir', () async {
      await loadSeeded();
      resetDaily(
        dailyTasksDay: todayKey(),
        progress: const {'play': 1, 'merge': 5},
        claimed: const {'merge'},
        lastDailyFreeEnergyDay: todayKey(),
        dailyFreeEnergyClaimsToday: 1,
      );
      final localProfile = cloud.buildSignedProfilePayload();
      final remoteData = <String, dynamic>{
        'dailyTasksDay': todayKey(),
        'dailyTasksProgress': {'play': 3, 'video': 1},
        'dailyTasksClaimed': ['play'],
        'dailyFreeEnergyDay': todayKey(),
        'dailyFreeEnergyClaims': 2,
      };
      final merged = CloudSyncService.convergedDailyFieldsForFlush(
        localProfile: localProfile,
        remoteData: remoteData,
      );
      final progress = merged['dailyTasksProgress'] as Map;
      expect(progress['play'], 3);
      expect(progress['merge'], 5);
      expect(progress['video'], 1);
      expect(
        (merged['dailyTasksClaimed'] as List).toSet(),
        {'play', 'merge'},
      );
      expect(merged['dailyFreeEnergyClaims'], 2);
      expect(cloud.verifyIntegrityHash(merged), isTrue);
    });

    test('uzak belge yoksa / eskiyse flush yereli aynen yazar', () async {
      await loadSeeded();
      resetDaily(
        lastStreakClaimDay: todayKey(),
        dailyTasksDay: todayKey(),
      );
      final localProfile = cloud.buildSignedProfilePayload();
      expect(
        CloudSyncService.convergedDailyFieldsForFlush(
          localProfile: localProfile,
          remoteData: null,
        ),
        same(localProfile),
      );
      expect(
        CloudSyncService.convergedDailyFieldsForFlush(
          localProfile: localProfile,
          remoteData: <String, dynamic>{
            'lastStreakClaimDay': yesterdayKey(),
            'dailyTasksDay': yesterdayKey(),
          },
        ),
        same(localProfile),
      );
    });
  });

  group('damga kalıcılığı', () {
    test('claim / görev kaydı / ücretsiz enerji damgayı ilerletir',
        () async {
      await loadSeeded();
      resetDaily();
      zeroDailyStamps();
      expect(pm.lastStreakClaimDayUpdatedAtMs, 0);
      expect(pm.dailyTasksUpdatedAtMs, 0);
      expect(pm.dailyFreeEnergyUpdatedAtMs, 0);
      final reward = await pm.claimDailyGiftBox();
      expect(reward, isNotNull);
      expect(pm.lastStreakClaimDayUpdatedAtMs, greaterThan(0));
      await pm.recordTaskProgressDetailed('play');
      expect(pm.dailyTasksUpdatedAtMs, greaterThan(0));
      final granted =
          await pm.claimDailyFreeEnergy(fromRewardedAd: true);
      expect(granted, isTrue);
      expect(pm.dailyFreeEnergyUpdatedAtMs, greaterThan(0));
      // Bellek içi damgalar sıfırlanıp yeniden yüklenince prefs'ten döner.
      final claimStamp = pm.lastStreakClaimDayUpdatedAtMs;
      final tasksStamp = pm.dailyTasksUpdatedAtMs;
      final energyStamp = pm.dailyFreeEnergyUpdatedAtMs;
      await pm.persistFieldStamps();
      pm.lastStreakClaimDayUpdatedAtMs = 0;
      pm.dailyTasksUpdatedAtMs = 0;
      pm.dailyFreeEnergyUpdatedAtMs = 0;
      await ProgressManager.instance.load();
      expect(pm.lastStreakClaimDayUpdatedAtMs, claimStamp);
      expect(pm.dailyTasksUpdatedAtMs, tasksStamp);
      expect(pm.dailyFreeEnergyUpdatedAtMs, energyStamp);
    });
  });

  group('gün anahtarı karşılaştırma', () {
    test('sözlüksel tuzak: 5 Kasım, 15 Kasım\'dan eskidir', () {
      expect(
        ProgressManager.compareDayKeys('2026-11-5', '2026-11-15'),
        lessThan(0),
      );
      expect(
        ProgressManager.latestDayKey('2026-11-5', '2026-11-15'),
        '2026-11-15',
      );
      expect(ProgressManager.tryParseDayKey('2026-13-1'), isNull);
      expect(ProgressManager.tryParseDayKey('2026-2-30'), isNull);
      expect(ProgressManager.tryParseDayKey('bugün'), isNull);
      expect(
        ProgressManager.compareDayKeys('', '2026-11-20'),
        lessThan(0),
      );
      expect(
        ProgressManager.latestDayKey('', '2026-11-20'),
        '2026-11-20',
      );
    });
  });
}
