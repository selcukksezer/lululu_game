// Günlük hediye kutusu kalıcı aynı-gün korumasını kilitleyen testler (W51-2).
//
// Kilitlenen davranış — `ProgressManager.claimDailyGiftBox`
// (lib/services/progress_manager.dart:1020-1045):
//  * `lastStreakClaimDay` bugünse ve `doubled` false ise null döner
//    (ödeme yok); aksi hâlde `(500 + (streak-1)*25)` coin + 5 enerji
//    öder ve günü `lululu_last_streak_claim_day` anahtarına kalıcı yazar.
//  * `doubled: true` aynı gün bile öder; coin tabanı 1000'dir
//    (`1000 + (streak-1)*25`). Bu, mevcut davranışın gözlem kilididir,
//    bir karar değildir.
//  * Son talep dünse seri +1 artar; daha eskiyse seri 1'e sıfırlanır;
//    hiç talep yoksa tohumlanan seri korunur (en az 1).
//
// YALNIZ servis düzeyi kapsanır: Hub'daki `else addCoins(500)` baypası
// ayrı bir dalganın işidir ve burada test edilmez.
//
// Tarih biçimi — koddan okundu, uydurma değil:
// `ProgressManager._todayKey` / `_yesterdayKey` (satır 380-388) sıfır
// doldurmasız `'yil-ay-gun'` üretir (`'${n.year}-${n.month}-${n.day}'`),
// yani `yyyy-MM-dd` DEĞİLDİR (örn. 5 Ocak → `2026-1-5`). Serviste saat
// kancası yoktur; gün, prefs tohumlamasıyla simüle edilir.
//
// Kurulum deseni mevcut testlerden alındı:
//  * `setMockInitialValues` + `load()` ile singleton sıfırlama:
//    test/store_readiness_test.dart (setUp + "Reset via clean
//    SharedPreferences + reload" bölümü). `ProgressManager`da reset/
//    `_loaded` bayrağı yoktur; `load()` her çağrıda prefs'i yeniden
//    okur ve `streak` / `lastStreakClaimDay` / `coins` alanlarını
//    tohumdan kurar (satır 489-490).
//  * Enerji tohumu + bekletilmeyen yazılara karşı sıfır gecikme:
//    test/energy_service_bounds_test.dart `seed()` / `loadSeeded()`.
//    Dolum çapaları (`lululu.energy_last_refill` /
//    `lululu.energy_last_seen`) "şimdi" olarak tohumlanır, böylece
//    `load()` / `addEnergy()` içindeki `_refill` zamana bağlı ekstra
//    enerji eklemez ve +5 ödülü yalıtılmış ölçülür.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

/// `ProgressManager._todayKey` / `_yesterdayKey` ile aynı biçim:
/// sıfır doldurmasız `'yil-ay-gun'` (progress_manager.dart:380-388).
String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _todayKey() => _dayKey(DateTime.now());

String _yesterdayKey() =>
    _dayKey(DateTime.now().subtract(const Duration(days: 1)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Prefs tohumunu kurup iki singleton'ı da tohumdan yükler.
  ///
  /// `lastClaimDay: null` anahtarı hiç yazmaz: hiç talep edilmemiş
  /// durumu simüle eder (`load()` sonrası `lastStreakClaimDay == ''`).
  Future<void> loadSeeded({
    int coins = 1000,
    int streak = 1,
    String? lastClaimDay,
    int energy = 10,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lululu_coins': coins,
      'lululu_daily_streak': streak,
      if (lastClaimDay != null)
        'lululu_last_streak_claim_day': lastClaimDay,
      'lululu.energy': energy,
      'lululu.energy_last_refill': nowMs,
      'lululu.energy_last_seen': nowMs,
    });
    // Bir önceki testin bekletilmeyen `_save()` / coin-kayıt
    // yazılarının tohumun üstüne binmemesi için olay döngüsüne bir tur
    // verilir (energy_service_bounds_test.dart `loadSeeded` deseni).
    await Future<void>.delayed(Duration.zero);
    await EnergyService.instance.load();
    await ProgressManager.instance.load();
  }

  group('claimDailyGiftBox aynı-gün koruması', () {
    test('ilk claim ödül döndürür: 500 coin + 5 enerji, seri 1', () async {
      await loadSeeded();
      final pm = ProgressManager.instance;

      expect(pm.canClaimDailyGiftBox, isTrue);
      expect(pm.streak, 1);
      expect(pm.lastStreakClaimDay, isEmpty);

      final gift = await pm.claimDailyGiftBox();

      expect(gift, isNotNull);
      expect(gift!.coins, 500);
      expect(gift.energy, 5);
      expect(gift.streak, 1);
      expect(pm.coins, 1500);
      expect(EnergyService.instance.energy, 15);
      expect(pm.streak, 1);
      expect(pm.lastStreakClaimDay, _todayKey());
      expect(pm.canClaimDailyGiftBox, isFalse);
    });

    test('aynı gün ikinci claim null döner ve ödeme yapmaz', () async {
      await loadSeeded();
      final pm = ProgressManager.instance;

      final first = await pm.claimDailyGiftBox();
      expect(first, isNotNull);
      expect(first!.coins, 500);
      expect(pm.coins, 1500);
      expect(EnergyService.instance.energy, 15);

      final second = await pm.claimDailyGiftBox();

      expect(second, isNull);
      expect(pm.coins, 1500);
      expect(EnergyService.instance.energy, 15);
      expect(pm.streak, 1);
      expect(pm.lastStreakClaimDay, _todayKey());
    });

    test('farklı gün (dün tohumlanmış) claim seriyi artırarak öder',
        () async {
      await loadSeeded(streak: 2, lastClaimDay: _yesterdayKey());
      final pm = ProgressManager.instance;

      expect(pm.canClaimDailyGiftBox, isTrue);

      final gift = await pm.claimDailyGiftBox();

      // Seri 2 → 3; ödül 500 + (3-1)*25 = 550.
      expect(gift, isNotNull);
      expect(gift!.streak, 3);
      expect(gift.coins, 550);
      expect(gift.energy, 5);
      expect(pm.coins, 1550);
      expect(EnergyService.instance.energy, 15);
      expect(pm.streak, 3);
      expect(pm.lastStreakClaimDay, _todayKey());
    });

    test('doubled: true aynı gün bile öder ve coin 1000 bazlıdır', () async {
      // Gözlem kilidi, karar değil: mevcut kodda `doubled` aynı-gün
      // korumasını atlar (satır 1024) ve seri bloğu atlandığı için
      // seri değişmeden kalır (satır 1025-1034).
      await loadSeeded(streak: 1, lastClaimDay: _todayKey());
      final pm = ProgressManager.instance;

      // Normal yol aynı gün kapalıdır; yalnız doubled öder.
      expect(await pm.claimDailyGiftBox(), isNull);
      expect(pm.coins, 1000);

      final gift = await pm.claimDailyGiftBox(doubled: true);

      expect(gift, isNotNull);
      expect(gift!.coins, 1000);
      expect(gift.energy, 5);
      expect(gift.streak, 1);
      expect(pm.coins, 2000);
      expect(EnergyService.instance.energy, 15);
      expect(pm.streak, 1);
      expect(pm.lastStreakClaimDay, _todayKey());
    });

    test('doubled seri 3 iken 1000 bazlı formülü korur (1050)', () async {
      await loadSeeded(streak: 3, lastClaimDay: _todayKey());
      final pm = ProgressManager.instance;

      final gift = await pm.claimDailyGiftBox(doubled: true);

      // 1000 + (3-1)*25 = 1050; aynı gün olduğu için seri artmaz.
      expect(gift, isNotNull);
      expect(gift!.coins, 1050);
      expect(gift.energy, 5);
      expect(gift.streak, 3);
      expect(pm.coins, 2050);
      expect(pm.streak, 3);
    });

    test('iki gün önceki talep seriyi sıfırlar (seri 1, 500 coin)', () async {
      final twoDaysAgo =
          _dayKey(DateTime.now().subtract(const Duration(days: 2)));
      await loadSeeded(streak: 5, lastClaimDay: twoDaysAgo);
      final pm = ProgressManager.instance;

      final gift = await pm.claimDailyGiftBox();

      expect(gift, isNotNull);
      expect(gift!.streak, 1);
      expect(gift.coins, 500);
      expect(gift.energy, 5);
      expect(pm.coins, 1500);
      expect(pm.streak, 1);
      expect(pm.lastStreakClaimDay, _todayKey());
    });

    test('claim sonrası prefs\'te bugün tarihi yazılıdır ve yeniden yüklemede koruma sürer',
        () async {
      await loadSeeded();
      final pm = ProgressManager.instance;
      final today = _todayKey();

      final gift = await pm.claimDailyGiftBox();
      expect(gift, isNotNull);

      // Kalıcı kayıt doğrudan prefs'ten okunur.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lululu_last_streak_claim_day'), today);
      expect(prefs.getInt('lululu_daily_streak'), 1);

      // Yeniden başlatma simülasyonu: aynı prefs'ten tekrar yükle —
      // koruma bellek içi bayrak değil, kalıcı kayıttır.
      await pm.load();
      expect(pm.lastStreakClaimDay, today);
      expect(pm.canClaimDailyGiftBox, isFalse);
      expect(await pm.claimDailyGiftBox(), isNull);
      expect(pm.coins, 1500);
      expect(EnergyService.instance.energy, 15);
    });
  });
}
