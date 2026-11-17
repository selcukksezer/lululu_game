// `LiveOpsEventService` içindeki idle-jar (Çevrimdışı Böcek Kavanozu)
// kalıcılık metotlarını kilitler: `loadJarStateFromPreferences`,
// `saveJarStateToPreferences` ve `resetJarState`
// (lib/services/live_ops_event_service.dart).
//
// Gözlem yolu: kalıcılık alanları (`_lastJarReferenceTimestampMs`,
// `_highestObservedTimestampMs`) özeldir; doğrudan okunamaz. Davranış,
// `claimIdleJarCoins` üzerinden gözlenir:
// - `lastActive` argümanı verilmezse claim, yüklenen
//   `_lastJarReferenceTimestampMs` değerine dayanır; değer yoksa
//   `missing_last_active_timestamp` reddi verir.
// - `nowMs`, yüklenen `_highestObservedTimestampMs` değerinin altındaysa
//   claim `clock_rollback_detected` reddi verir.
// Prefs anahtar adları koddan okunmuştur (`_prefsLastActiveMsKey` /
// `_prefsHighestSeenMsKey`).
//
// Mock deseni mevcut testlerle aynıdır
// (live_ops_difficulty_test.dart, energy_service_bounds_test.dart):
// `TestWidgetsFlutterBinding.ensureInitialized()` +
// `SharedPreferences.setMockInitialValues(<String, Object>{})`.
// Buna ek olarak her test başında canlı prefs örneği `clear()` ile
// boşaltılır, böylece testler birbirinin yazdığı anahtarları görmez.
// Tekil `LiveOpsEventService.instance` kullanılmaz; her test taze bir
// örnek + taze `AntiCheatService` kurar (taze örnek = uygulama yeniden
// başlatma; taze anti-cheat = cooldown/replay geçmişi yalıtımı).
//
// Not: herkese açık API üzerinden (`recordPlayerActiveTimestamp` /
// `claimIdleJarCoins`) iki alan hep birlikte aynı değere ilerler;
// farklı last/highest değerleri ancak prefs'e doğrudan yazılarak
// oluşur. Ayrık okuma kanıtı için "farklı last/highest" testi prefs'i
// doğrudan tohumlar.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/anti_cheat_service.dart';
import 'package:lululu_game/services/live_ops_event_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Koddan okunan prefs anahtarları (live_ops_event_service.dart).
  const lastActiveKey = 'lululu_idle_jar_last_active_ms';
  const highestSeenKey = 'lululu_idle_jar_highest_seen_ms';
  const minuteMs = 60000;

  // Sabit referans anı (live_ops_difficulty_test.dart ile aynı gün/saat
  // geleneği); testler yalnızca ms farklarına dayanır.
  final baseMs = DateTime(2026, 11, 4, 10, 0).millisecondsSinceEpoch;

  LiveOpsEventService newService() => LiveOpsEventService(
        antiCheat: AntiCheatService(secretKey: 'test_idle_jar_secret_key'),
      );

  /// Mock prefs'i boşaltıp canlı örneği döndürür.
  Future<SharedPreferences> cleanPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return prefs;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Idle-jar kalıcılığı (load/save/reset)', () {
    test("save → load turu: kaydedilen lastActive/highest değerleri load sonrası geri okunur",
        () async {
      await cleanPrefs();

      final writer = newService();
      expect(writer.recordPlayerActiveTimestamp(nowMs: baseMs), isTrue);
      await writer.saveJarStateToPreferences();

      // Yeni örnek = uygulama yeniden başlatma: bellek durumu boş başlar.
      final reader = newService();
      await reader.loadJarStateFromPreferences();

      // Geri alınmış saat sondası: yüklenen en yüksek zaman damgasından
      // eski bir `nowMs`, rollback reddi üretir. Başarısız claim durumu
      // değiştirmez, bu yüzden sonda önce yapılır. (Bu sonda tek başına
      // highest'ı last'ten ayırt etmez; ayrık kanıt aşağıdaki
      // "farklı last/highest" testindedir.)
      final rollbackProbe = reader.claimIdleJarCoins(
        highestUnlockedTier: 1,
        nowMs: baseMs - minuteMs,
      );
      expect(rollbackProbe.isSuccess, isFalse);
      expect(rollbackProbe.grantedCoins, 0);
      expect(rollbackProbe.reason, 'clock_rollback_detected');

      // `lastActive` argümanı verilmeden yapılan claim, yüklenen
      // `_lastJarReferenceTimestampMs` değerine dayanır: tier 1
      // (1.0 altın/dk) ile 10 dakika -> 10 altın.
      final claim = reader.claimIdleJarCoins(
        highestUnlockedTier: 1,
        nowMs: baseMs + 10 * minuteMs,
      );
      expect(claim.isSuccess, isTrue);
      expect(claim.reason, 'ok');
      expect(claim.accumulatedMinutes, 10);
      expect(claim.grantedCoins, 10);
      expect(claim.newCoinBalance, 10);
    });

    test("boş prefs'te load boş duruma döner: claim zaman damgası eksik reddi verir",
        () async {
      await cleanPrefs();

      final fresh = newService();
      await fresh.loadJarStateFromPreferences();
      final missing = fresh.claimIdleJarCoins(
        highestUnlockedTier: 1,
        nowMs: baseMs,
      );
      expect(missing.isSuccess, isFalse);
      expect(missing.grantedCoins, 0);
      expect(missing.reason, 'missing_last_active_timestamp');

      // load, bellek durumunu koşulsuz olarak prefs içeriğiyle ezer:
      // kayıtlı zaman damgası olan bir örnek bile boş prefs'ten
      // yükleyince boş duruma döner (getInt -> null ataması).
      final seeded = newService();
      expect(seeded.recordPlayerActiveTimestamp(nowMs: baseMs), isTrue);
      await seeded.loadJarStateFromPreferences();
      final missingAfterLoad = seeded.claimIdleJarCoins(
        highestUnlockedTier: 1,
        nowMs: baseMs + 10 * minuteMs,
      );
      expect(missingAfterLoad.isSuccess, isFalse);
      expect(missingAfterLoad.grantedCoins, 0);
      expect(missingAfterLoad.reason, 'missing_last_active_timestamp');
    });

    test("reset sonrası bellek boşalır ve boş prefs'ten load boş durumda bırakır",
        () async {
      final prefs = await cleanPrefs();

      final service = newService();
      expect(service.recordPlayerActiveTimestamp(nowMs: baseMs), isTrue);
      await service.saveJarStateToPreferences();
      expect(prefs.getInt(lastActiveKey), baseMs);

      service.resetJarState();

      final afterReset = service.claimIdleJarCoins(
        highestUnlockedTier: 1,
        nowMs: baseMs + 10 * minuteMs,
      );
      expect(afterReset.isSuccess, isFalse);
      expect(afterReset.grantedCoins, 0);
      expect(afterReset.reason, 'missing_last_active_timestamp');

      // Prefs boşaltıldıktan sonra load, boş durumu korur.
      await prefs.clear();
      await service.loadJarStateFromPreferences();
      final afterEmptyLoad = service.claimIdleJarCoins(
        highestUnlockedTier: 1,
        nowMs: baseMs + 10 * minuteMs,
      );
      expect(afterEmptyLoad.isSuccess, isFalse);
      expect(afterEmptyLoad.reason, 'missing_last_active_timestamp');
    });

    test('save, beklenen 2 anahtarı yazar; kayıtsız durumda hiçbir anahtar yazmaz',
        () async {
      final prefs = await cleanPrefs();

      final service = newService();
      expect(service.recordPlayerActiveTimestamp(nowMs: baseMs), isTrue);
      await service.saveJarStateToPreferences();

      expect(prefs.getInt(lastActiveKey), baseMs);
      expect(prefs.getInt(highestSeenKey), baseMs);
      expect(
        prefs.getKeys(),
        containsAll(<String>[lastActiveKey, highestSeenKey]),
      );
      expect(prefs.getKeys().length, 2);

      // save yalnızca null olmayan alanları yazar: hiç zaman damgası
      // kaydedilmemiş bir örnek save çağırsa bile prefs'e dokunulmaz.
      await prefs.clear();
      final untouched = newService();
      await untouched.saveJarStateToPreferences();
      expect(prefs.getKeys(), isEmpty);
    });

    test('load, farklı last/highest değerlerini ayrı ayrı okur', () async {
      final prefs = await cleanPrefs();
      await prefs.setInt(lastActiveKey, baseMs);
      await prefs.setInt(highestSeenKey, baseMs + 60 * minuteMs);

      final reader = newService();
      await reader.loadJarStateFromPreferences();

      // nowMs last'in üstünde ama highest'ın altında: yalnızca yüklenen
      // highest kontrolü bu claim'i rollback reddine götürür.
      final highestProbe = reader.claimIdleJarCoins(
        highestUnlockedTier: 1,
        nowMs: baseMs + 10 * minuteMs,
      );
      expect(highestProbe.isSuccess, isFalse);
      expect(highestProbe.reason, 'clock_rollback_detected');

      // highest'ın üstündeki bir nowMs, last'ten hesaplanan 70 dakikalık
      // birikimi verir (tier 1 -> 70 altın).
      final claim = reader.claimIdleJarCoins(
        highestUnlockedTier: 1,
        nowMs: baseMs + 70 * minuteMs,
      );
      expect(claim.isSuccess, isTrue);
      expect(claim.reason, 'ok');
      expect(claim.accumulatedMinutes, 70);
      expect(claim.grantedCoins, 70);
    });

    test('resetJarState yalnızca belleği temizler: prefs anahtarları yerinde kalır',
        () async {
      final prefs = await cleanPrefs();

      final service = newService();
      expect(service.recordPlayerActiveTimestamp(nowMs: baseMs), isTrue);
      await service.saveJarStateToPreferences();

      service.resetJarState();

      // resetJarState prefs'e erişmez (kodda yalnızca iki alan
      // null'lanır ve anti-cheat geçmişi sıfırlanır); kaydedilmiş
      // anahtarlar durur.
      expect(prefs.getInt(lastActiveKey), baseMs);
      expect(prefs.getInt(highestSeenKey), baseMs);
      expect(prefs.getKeys().length, 2);
    });
  });
}
