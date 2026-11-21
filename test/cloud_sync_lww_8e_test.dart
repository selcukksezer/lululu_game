// FAZ 4 / 8E — CloudSync Y6: alan-başına zaman-damgalı son-yazan-kazanır
// (LWW) birleştirme testleri (tasarım A10 §3.2.7).
//
// Kapsar: damga matrisi (uzak-yeni / yerel-yeni / eşit / damgasız /
// bozuk), harcama-dirilme senaryosu, çakışma senaryosu, damgasız göç
// senaryosu, alan bağımsızlığı, güç anahtarı-başına LWW, skor
// yalnız-büyür kuralının korunması, tier birleşimi, payload damgaları
// + kural ön-denetimi, göç tohumlaması, damga ilerletme yolları
// (spendCoins, enerji bildiricisi).
//
// Kurulum deseni test/progress_manager_faz2_test.dart'tan alındı:
// `setMockInitialValues` + olay döngüsüne bir tur +
// `EnergyService.load()` + `ProgressManager.load()` ile singleton
// sıfırlama. Damga değerleri testte küçük ms sayılarıdır (10000
// gibi); "bozuk-gelecek" damgası gerçek saatten türetilir.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/cloud_sync_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cloud = CloudSyncService.instance;

  /// Prefs tohumunu kurup iki singleton'ı da tohumdan yükler.
  Future<void> loadSeeded({int coins = 1000, int energy = 10}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lululu_coins': coins,
      'lululu.energy': energy,
      'lululu.energy_last_refill': nowMs,
      'lululu.energy_last_seen': nowMs,
    });
    // Bir önceki testin bekletilmeyen yazılarının tohumun üstüne
    // binmemesi için olay döngüsüne bir tur verilir.
    await Future<void>.delayed(Duration.zero);
    await EnergyService.instance.load();
    await ProgressManager.instance.load();
  }

  /// Yerel durumu + damgaları senkron kurar; fark anlık görüntüsünü
  /// eşitler (sonraki değişimler yalnız gerçekten yeni olur).
  /// Değerler ÖNCE, damgalar SONRA yazılır: `coins` setter'ı ve enerji
  /// bildiricisi damgayı ilerletebilir; açık damga ataması en sonda
  /// yapılır, ardından anlık görüntü eşitlenir.
  void resetLocal({
    int coins = 5000,
    int coinsStamp = 10000,
    int energy = 20,
    int energyStamp = 10000,
    int level = 5,
    int levelStamp = 10000,
    int f16 = 2,
    int raid = 3,
    int terlik = 5,
    int streak = 3,
    int streakStamp = 10000,
    Map<String, int> powers = const <String, int>{
      'raid': 3,
      'terlik': 5,
      'f16': 2,
    },
    Map<String, int> powerStamps = const <String, int>{
      'raid': 10000,
      'terlik': 10000,
      'f16': 10000,
    },
    Map<String, int> modeScores = const <String, int>{'suika': 1000},
    Set<int> tiers = const <int>{1, 2, 3, 4, 5, 6, 7, 8},
  }) {
    final pm = ProgressManager.instance;
    pm.coins = coins;
    EnergyService.instance.energy = energy;
    pm.unlockedLevel = level;
    pm.f16Count = f16;
    pm.raidCount = raid;
    pm.terlikCount = terlik;
    pm.streak = streak;
    pm.extraPowers
      ..clear()
      ..addAll(powers);
    pm.modeHighScores
      ..clear()
      ..addAll(modeScores);
    pm.unlockedTiers
      ..clear()
      ..addAll(tiers);
    pm.coinsUpdatedAtMs = coinsStamp;
    pm.energyUpdatedAtMs = energyStamp;
    pm.unlockedLevelUpdatedAtMs = levelStamp;
    pm.f16UpdatedAtMs = 10000;
    pm.raidUpdatedAtMs = 10000;
    pm.terlikUpdatedAtMs = 10000;
    pm.streakUpdatedAtMs = streakStamp;
    pm.unlockedTiersUpdatedAtMs = 10000;
    pm.extraPowersUpdatedAtMs
      ..clear()
      ..addAll(powerStamps);
    pm.syncPersistedSnapshot();
  }

  /// Uzak profil yükünü HMAC ile imzalar (damga alanları imzaya dahildir).
  Map<String, dynamic> signedRemote(Map<String, dynamic> fields) {
    final payload = Map<String, dynamic>.from(fields);
    payload['integrityHash'] = cloud.computeIntegrityHash(payload);
    return payload;
  }

  group('resolveLwwInt: damga matrisi', () {
    test('uzak damga yeniyse uzak kazanır', () {
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 5000,
          localStamp: 9000,
          remoteValue: 8000,
          remoteStamp: 10000,
        ),
        8000,
      );
    });

    test('uzak damga eskiyse yerel korunur (harcama dirilmez)', () {
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 5000,
          localStamp: 10000,
          remoteValue: 8000,
          remoteStamp: 7000,
        ),
        5000,
      );
    });

    test('fark 2 sn içindeyse eşit sayılır, max uygulanır', () {
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 5000,
          localStamp: 10000,
          remoteValue: 8000,
          remoteStamp: 11500,
        ),
        8000,
      );
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 8000,
          localStamp: 11500,
          remoteValue: 5000,
          remoteStamp: 10000,
        ),
        8000,
      );
      // Sınır: tam 2000 ms fark eşit sayılır.
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 5000,
          localStamp: 10000,
          remoteValue: 8000,
          remoteStamp: 12000,
        ),
        8000,
      );
    });

    test('fark 2 sn üstüyse LWW uygulanır', () {
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 5000,
          localStamp: 10000,
          remoteValue: 8000,
          remoteStamp: 12001,
        ),
        8000,
      );
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 5000,
          localStamp: 12001,
          remoteValue: 8000,
          remoteStamp: 10000,
        ),
        5000,
      );
    });

    test('uzak değer yoksa yerel korunur', () {
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 5000,
          localStamp: 10000,
          remoteValue: null,
          remoteStamp: 20000,
        ),
        5000,
      );
    });

    test('bozuk uzak damgada max yedeği uygulanır', () {
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 5000,
          localStamp: 10000,
          remoteValue: 8000,
          remoteStamp: 0,
          remoteStampBad: true,
        ),
        8000,
      );
      expect(
        CloudSyncService.resolveLwwInt(
          localValue: 8000,
          localStamp: 10000,
          remoteValue: 5000,
          remoteStamp: 0,
          remoteStampBad: true,
        ),
        8000,
      );
    });
  });

  group('readFieldStamp: damga okuma', () {
    test('yoksa 0, bozuk değil (damgasız/epoch)', () {
      final r = CloudSyncService.readFieldStamp(
        <String, dynamic>{},
        'coinsUpdatedAtMs',
      );
      expect(r.stamp, 0);
      expect(r.bad, isFalse);
    });

    test('geçerli int okunur', () {
      final r = CloudSyncService.readFieldStamp(
        <String, dynamic>{'coinsUpdatedAtMs': 12345},
        'coinsUpdatedAtMs',
      );
      expect(r.stamp, 12345);
      expect(r.bad, isFalse);
    });

    test('negatif, tür yanlış ve absürt-gelecek damga bozuktur', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      expect(
        CloudSyncService.readFieldStamp(
          <String, dynamic>{'coinsUpdatedAtMs': -5},
          'coinsUpdatedAtMs',
          nowMs: nowMs,
        ).bad,
        isTrue,
      );
      expect(
        CloudSyncService.readFieldStamp(
          <String, dynamic>{'coinsUpdatedAtMs': 'dün'},
          'coinsUpdatedAtMs',
          nowMs: nowMs,
        ).bad,
        isTrue,
      );
      expect(
        CloudSyncService.readFieldStamp(
          <String, dynamic>{
            'coinsUpdatedAtMs': nowMs + 25 * 60 * 60 * 1000,
          },
          'coinsUpdatedAtMs',
          nowMs: nowMs,
        ).bad,
        isTrue,
      );
      // 1 saat ileri kayma tolerans içindedir (bozuk değil).
      expect(
        CloudSyncService.readFieldStamp(
          <String, dynamic>{
            'coinsUpdatedAtMs': nowMs + 60 * 60 * 1000,
          },
          'coinsUpdatedAtMs',
          nowMs: nowMs,
        ).bad,
        isFalse,
      );
    });
  });

  group('applyTimestampedProfileSnapshot: birleştirme', () {
    test('harcama dirilmez: yerel harcama + eski bulut → harcama korunur',
        () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 10000);
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'coins': 8000,
          'coinsUpdatedAtMs': 7000,
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.coins, 5000);
      expect(ProgressManager.instance.coinsUpdatedAtMs, 10000);
    });

    test('çakışma: yeni damga kazanır', () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 9000);
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'coins': 8000,
          'coinsUpdatedAtMs': 12000,
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.coins, 8000);
    });

    test('damgasız göç: damgasız uzak, damgalı yerele yenilir', () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 10000);
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{'coins': 8000}),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.coins, 5000);
    });

    test('iki taraf da damgasızsa max yedeği çalışır', () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 0);
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{'coins': 8000}),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.coins, 8000);
    });

    test('bozuk uzak damgada max yedeği çalışır', () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 10000);
      var ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'coins': 8000,
          'coinsUpdatedAtMs': -5,
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.coins, 8000);

      resetLocal(coins: 8000, coinsStamp: 10000);
      final futureMs =
          DateTime.now().millisecondsSinceEpoch + 25 * 60 * 60 * 1000;
      ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'coins': 5000,
          'coinsUpdatedAtMs': futureMs,
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.coins, 8000);
    });

    test('alan bağımsızlığı: coin uzak-yeni, enerji uzak-eski', () async {
      await loadSeeded();
      resetLocal(
        coins: 5000,
        coinsStamp: 9000,
        energy: 20,
        energyStamp: 10000,
      );
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'coins': 8000,
          'coinsUpdatedAtMs': 12000,
          'energy': 30,
          'energyUpdatedAtMs': 7000,
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.coins, 8000);
      expect(EnergyService.instance.energy, 20);
    });

    test('extraPowers anahtar-başına LWW; eksik anahtar değişmez',
        () async {
      await loadSeeded();
      resetLocal(
        terlik: 1,
        powers: const <String, int>{'raid': 3, 'terlik': 1, 'f16': 2},
        powerStamps: const <String, int>{
          'raid': 10000,
          'terlik': 10000,
          'f16': 10000,
        },
      );
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'extraPowers': <String, int>{'raid': 5, 'terlik': 2},
          'extraPowersUpdatedAtMs': <String, int>{
            'raid': 7000,
            'terlik': 13000,
          },
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      final pm = ProgressManager.instance;
      expect(pm.extraPowers['raid'], 3);
      expect(pm.extraPowers['terlik'], 2);
      // Uzakta olmayan anahtar "değişim yok" sayılır.
      expect(pm.extraPowers['f16'], 2);
      // Birincil sayaçlar haritayla aynı stoktur: birleşme sayaca da yansır.
      expect(pm.terlikCount, 2);
      expect(pm.raidCount, 3);
    });

    test('mod skorları yalnız-büyür kalır (LWW dışı)', () async {
      await loadSeeded();
      resetLocal(modeScores: const <String, int>{'suika': 1000});
      var ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'modeHighScores': <String, int>{'suika': 500},
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.modeHighScores['suika'], 1000);

      ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'modeHighScores': <String, int>{'suika': 1500},
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.modeHighScores['suika'], 1500);
    });

    test('tier birleşimi korunur', () async {
      await loadSeeded();
      resetLocal();
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'unlockedTiers': <int>[9, 10],
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      final tiers = ProgressManager.instance.unlockedTiers;
      expect(tiers.contains(9), isTrue);
      expect(tiers.contains(10), isTrue);
      expect(tiers.contains(1), isTrue);
    });

    test('bozuk imza reddedilir, yerel değişmez', () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 10000);
      final payload = <String, dynamic>{
        'coins': 8000,
        'coinsUpdatedAtMs': 20000,
        'integrityHash': '0' * 64,
      };
      final ok = await cloud.applyTimestampedProfileSnapshot(
        payload,
        allowUnsignedLegacy: false,
      );
      expect(ok, isFalse);
      expect(ProgressManager.instance.coins, 5000);
    });

    test('sınır-dışı uzak değer reddedilir', () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 10000);
      final ok = await cloud.applyTimestampedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'coins': -1,
          'coinsUpdatedAtMs': 20000,
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isFalse);
      expect(ProgressManager.instance.coins, 5000);
    });

    test('eski ad applyVerifiedProfileSnapshot LWW sürümüne delege eder',
        () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 10000);
      final ok = await cloud.applyVerifiedProfileSnapshot(
        signedRemote(<String, dynamic>{
          'coins': 8000,
          'coinsUpdatedAtMs': 7000,
        }),
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      expect(ProgressManager.instance.coins, 5000);
    });
  });

  group('payload damgaları + kural ön-denetimi', () {
    test('payload yerel damgaları taşır ve ön-denetimden geçer', () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 10000);
      final payload = cloud.buildSignedProfilePayload();
      expect(payload['coins'], 5000);
      expect(payload['coinsUpdatedAtMs'], 10000);
      expect(payload['energyUpdatedAtMs'], 10000);
      expect(payload['unlockedLevelUpdatedAtMs'], 10000);
      expect(payload['streakUpdatedAtMs'], 10000);
      expect(payload['extraPowersUpdatedAtMs'], isA<Map>());
      expect(
        (payload['extraPowersUpdatedAtMs'] as Map)['raid'],
        10000,
      );
      expect(
        CloudSyncService.validateProfilePayloadForRules(payload),
        isEmpty,
      );
      // Damgalar imzaya dahildir: damga değişince imza geçersiz olur.
      final tampered = Map<String, dynamic>.from(payload);
      tampered['coinsUpdatedAtMs'] = 9999;
      expect(cloud.verifyIntegrityHash(tampered), isFalse);
    });

    test('ön-denetim bozuk damgayı reddeder', () async {
      await loadSeeded();
      resetLocal();
      final payload = cloud.buildSignedProfilePayload();
      final bad = Map<String, dynamic>.from(payload);
      bad['coinsUpdatedAtMs'] = -1;
      expect(
        CloudSyncService.validateProfilePayloadForRules(bad),
        isNotEmpty,
      );
      final badMap = Map<String, dynamic>.from(payload);
      badMap['extraPowersUpdatedAtMs'] = <String, int>{'raid': -1};
      expect(
        CloudSyncService.validateProfilePayloadForRules(badMap),
        isNotEmpty,
      );
    });
  });

  group('damga ilerletme yolları', () {
    test('spendCoins coin damgasını ilerletir', () async {
      await loadSeeded();
      resetLocal(coins: 5000, coinsStamp: 10000);
      final pm = ProgressManager.instance;
      expect(await pm.spendCoins(1000), isTrue);
      expect(pm.coins, 4000);
      // Ertelenmiş kalıcı kayıt (coins setter) çalışsın diye tur verilir.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(pm.coinsUpdatedAtMs, greaterThan(10000));
    });

    test('enerji değişimi enerji damgasını ilerletir', () async {
      await loadSeeded();
      resetLocal(energy: 20, energyStamp: 10000);
      final pm = ProgressManager.instance;
      EnergyService.instance.energy = 25;
      expect(pm.energyUpdatedAtMs, greaterThan(10000));
    });
  });

  group('göç tohumlaması', () {
    test('ilk yüklemede mevcut değerler bir kez damgalanır', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues(<String, Object>{
        'lululu_coins': 7000,
        'lululu.energy': 15,
        'lululu.energy_last_refill': nowMs,
        'lululu.energy_last_seen': nowMs,
      });
      await Future<void>.delayed(Duration.zero);
      await EnergyService.instance.load();
      await ProgressManager.instance.load();
      final pm = ProgressManager.instance;
      expect(pm.coinsUpdatedAtMs, greaterThan(0));
      expect(pm.coinsUpdatedAtMs, greaterThanOrEqualTo(nowMs));
      expect(pm.energyUpdatedAtMs, greaterThan(0));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('lululu_lww_stamps_seeded_v1'), isTrue);
      expect(prefs.getInt('lululu_ts_coins'), pm.coinsUpdatedAtMs);

      // İkinci yükleme tohumlamayı tekrarlamaz: damga aynı kalır.
      final firstStamp = pm.coinsUpdatedAtMs;
      SharedPreferences.setMockInitialValues(<String, Object>{
        'lululu_coins': 7000,
        'lululu.energy': 15,
        'lululu.energy_last_refill': nowMs,
        'lululu.energy_last_seen': nowMs,
        'lululu_ts_coins': firstStamp,
        'lululu_ts_energy': pm.energyUpdatedAtMs,
        'lululu_ts_level': pm.unlockedLevelUpdatedAtMs,
        'lululu_ts_f16': pm.f16UpdatedAtMs,
        'lululu_ts_raid': pm.raidUpdatedAtMs,
        'lululu_ts_terlik': pm.terlikUpdatedAtMs,
        'lululu_ts_streak': pm.streakUpdatedAtMs,
        'lululu_ts_tiers': pm.unlockedTiersUpdatedAtMs,
        'lululu_ts_display_name': pm.displayNameUpdatedAtMs,
        'lululu_ts_extra_powers': '{}',
        'lululu_lww_stamps_seeded_v1': true,
      });
      await Future<void>.delayed(Duration.zero);
      await EnergyService.instance.load();
      await ProgressManager.instance.load();
      expect(ProgressManager.instance.coinsUpdatedAtMs, firstStamp);
    });
  });
}
