// `EnergyService` içindeki iki sınır düzeltmesini kilitler:
//
// 1. `load()` kelepçesi (lib/services/energy_service.dart satır 159-162):
//    kalıcı kayıttaki enerji 0..30 aralığına kelepçelenir.
// 2. Setter `wasFull` çapası (satır 59-66): dolu depodan kısmi duruma
//    düşüşte dolum çapası (`_lastRefill`) o ana çekilir; bayat çapa bir
//    sonraki dolumda anında +1 vermez.
//
// Kurulum deseni mevcut testlerle aynıdır (energy_refund_test.dart,
// store_readiness_test.dart): `setMockInitialValues` + `load()`.
// `EnergyService` tekildir (singleton); her test tohumu yeniden atayıp
// `load()` çağırır. Serviste saat kancası (`clockForTesting` vb.) yoktur:
// `clockForTesting` yalnızca `OsmantusScreen`dedir, `EnergyService`
// `_effectiveNow()` ile gerçek saate dayanır. Bu yüzden çapa testi
// donmuş saat kullanamaz; çapayı gerçek zamanla yaşlandırıp
// `timeToNext` üzerinden gözler (ayrıntı testin içindeki yorumda).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/energy_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await EnergyService.instance.load();
  });

  /// Tohum haritası kurar: dolum çapası ve monoton son-görülen zaman
  /// "şimdi" olur, böylece `load()` içindeki `_refill` tohum enerjisine
  /// dolum eklemez ve kelepçe davranışı yalıtılmış ölçülür.
  Map<String, Object> seed({int? energy, int? legacyEnergy}) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return <String, Object>{
      if (energy != null) 'lululu.energy': energy,
      if (legacyEnergy != null) 'LululuEnergyCount': legacyEnergy,
      'lululu.energy_last_refill': nowMs,
      'lululu.energy_last_seen': nowMs,
    };
  }

  Future<void> loadSeeded(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    // Bir önceki adımın bekletilmeyen `_save()` yazılarının tohumun
    // üstüne binmemesi için olay döngüsüne bir tur verilir.
    await Future<void>.delayed(Duration.zero);
    await EnergyService.instance.load();
  }

  group('load() kelepçesi', () {
    test('tavan üstü kayıt (100) 30 olarak yüklenir', () async {
      await loadSeeded(seed(energy: 100));

      final service = EnergyService.instance;
      expect(service.energy, EnergyService.maxEnergy);
      expect(service.energyNotifier.value, EnergyService.maxEnergy);
      expect(service.isFull, isTrue);
    });

    test('negatif kayıt (-5) 0 olarak yüklenir', () async {
      await loadSeeded(seed(energy: -5));

      final service = EnergyService.instance;
      expect(service.energy, 0);
      expect(service.energyNotifier.value, 0);
      expect(service.isFull, isFalse);
    });

    test('aralık içi kayıt (15) aynen yüklenir', () async {
      await loadSeeded(seed(energy: 15));

      expect(EnergyService.instance.energy, 15);
      expect(EnergyService.instance.energyNotifier.value, 15);
    });

    test('sınır değer 0 aynen yüklenir', () async {
      await loadSeeded(seed(energy: 0));

      expect(EnergyService.instance.energy, 0);
      expect(EnergyService.instance.isFull, isFalse);
    });

    test('sınır değer 30 aynen yüklenir ve depo dolu sayılır', () async {
      await loadSeeded(seed(energy: 30));

      final service = EnergyService.instance;
      expect(service.energy, EnergyService.maxEnergy);
      expect(service.isFull, isTrue);
      expect(service.timeToNext, Duration.zero);
    });

    test('yalnızca eski anahtardaki tavan üstü kayıt (100) 30 olur',
        () async {
      await loadSeeded(seed(legacyEnergy: 100));

      expect(EnergyService.instance.energy, EnergyService.maxEnergy);
      expect(EnergyService.instance.isFull, isTrue);
    });
  });

  group('setter wasFull çapası', () {
    test("dolu depodan 29'a düşüşte dolum sayacı o andan başlar", () async {
      final service = EnergyService.instance;
      service.energy = EnergyService.maxEnergy;
      expect(service.energy, EnergyService.maxEnergy);
      expect(service.timeToNext, Duration.zero);

      // Çapa yaşlandırma: setter ile 30'a çıkınca çapa o ana çekilir
      // (satır 62-66). 3 saniye beklenir; düzeltme olmasaydı 29'a
      // düşüşte çapa 3 saniye yaşlı kalır ve `timeToNext` ~297 sn
      // gösterirdi. Düzeltmeyle çapa düşüş anına çekilir, `timeToNext`
      // tam aralığa (~300 sn) döner. 299 sn eşiği, 2 sn payla bayat
      // çapayı yakalar; setter ile beklenti arasındaki mikrosaniyelik
      // fark doğru kodu bozmaz.
      await Future<void>.delayed(const Duration(seconds: 3));

      service.energy = EnergyService.maxEnergy - 1;

      expect(service.energy, EnergyService.maxEnergy - 1);
      expect(service.timeToNext, greaterThan(const Duration(seconds: 299)));
      expect(
        service.timeToNext,
        lessThanOrEqualTo(EnergyService.regenDuration),
      );
      expect(
        service.timeToNextNotifier.value,
        greaterThan(const Duration(seconds: 299)),
      );
    });
  });

  group('regresyon', () {
    test('setter 15 -> 20 değerini aynen yazar ve bildirir', () {
      final service = EnergyService.instance;
      service.energy = 15;
      expect(service.energy, 15);

      service.energy = 20;

      expect(service.energy, 20);
      expect(service.energyNotifier.value, 20);
      expect(service.isFull, isFalse);
    });

    test('boş kayıtta varsayılan enerji (5) yüklenir', () async {
      await loadSeeded(<String, Object>{});

      expect(EnergyService.instance.energy, EnergyService.defaultEnergy);
      expect(
        EnergyService.instance.energyNotifier.value,
        EnergyService.defaultEnergy,
      );
    });
  });
}
