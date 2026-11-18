// `ProgressManager.dailyStreak` getter'ını kilitleyen testler (W55-9).
//
// Kilitlenen davranış — `lib/services/progress_manager.dart`:
//  * Getter salt takma addır: `int get dailyStreak => streak;` (satır 182).
//    Hub + Osmantuş + Scream ekranları bu getter'ı okur; getter `streak`
//    alanından başka hiçbir şey yapmaz (artırma / sıfırlama / clamp yok).
//  * Alan başlangıcı `int streak = 1;` (satır ~180) ve `load()` satırı
//    `streak = prefs.getInt('lululu_daily_streak') ?? 1;` (satır ~489)
//    olduğu için TAZE yüklemede getter 1'dir, 0 DEĞİLDİR.
//    Görev brifindeki "(1) taze yüklemede dailyStreak 0" maddesi kodla
//    çelişir; bu dosya kodun gerçek davranışını (1) kilitler. Ürün kararı
//    "taze seri 0 olmalı" ise önce `streak` başlangıcı + `load()` varsayılanı
//    değiştirilmeli, sonra bu test güncellenmelidir — tersi yapılmaz.
//  * `claimDailyGiftBox` akışı (satır ~1020-1045): son talep dünse seri +1,
//    daha eskiyse seri 1'e sıfırlanır, hiç talep yoksa tohumlanan seri
//    korunur (en az 1: `streak < 1 ? 1 : streak`).
//
// Tarih biçimi — koddan okundu, uydurma değil:
// `ProgressManager._todayKey` / `_yesterdayKey` (satır 380-388) sıfır
// doldurmasız `'yil-ay-gun'` üretir (`'${n.year}-${n.month}-${n.day}'`),
// yani `yyyy-MM-dd` DEĞİLDİR (örn. 5 Ocak → `2026-1-5`). Serviste saat
// kancası yoktur; gün, prefs tohumlamasıyla simüle edilir.
//
// Kurulum deseni test/daily_gift_box_guard_test.dart'tan alındı:
// `setMockInitialValues` + `load()` ile singleton sıfırlama ve enerji
// tohumu + bekletilmeyen yazılara karşı sıfır gecikme
// (test/energy_service_bounds_test.dart `seed()` / `loadSeeded()`).
// Düz `test()` kullanılır, pump yok.
//
// GECE-YARISI UYARISI: yardımcılar `_todayKey()` / `_yesterdayKey()`'i
// tohumlama anında hesaplar; test gece yarısını aşarsa (tohumlama öncesi,
// claim sonrası gün değişirse) "dün" iki gün önceye döner ve seri artmak
// yerine sıfırlanır. Bu testler gece yarısına yakın çalıştırılmamalıdır;
// ilk koşumda bakılacak noktalar dosya sonundaki NOT bölümündedir.
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
  /// `streak: null` `lululu_daily_streak` anahtarını hiç yazmaz: taze
  /// yükleme durumunu simüle eder (`load()` sonrası varsayılan 1).
  /// `lastClaimDay: null` anahtarı hiç yazmaz: hiç talep edilmemiş
  /// durumu simüle eder (`load()` sonrası `lastStreakClaimDay == ''`).
  Future<void> loadSeeded({
    int coins = 1000,
    int? streak = 1,
    String? lastClaimDay,
    int energy = 10,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lululu_coins': coins,
      if (streak != null) 'lululu_daily_streak': streak,
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

  group('dailyStreak getter', () {
    test('taze yüklemede dailyStreak 1 (kod varsayılanı; 0 değil)', () async {
      // Brif 0 bekliyordu; kod `streak = 1` + `?? 1` dediği için gerçek
      // davranış 1'dir. Bkz. dosya başındaki açıklama.
      await loadSeeded(streak: null);
      final pm = ProgressManager.instance;

      expect(pm.streak, 1);
      expect(pm.dailyStreak, 1);
      expect(pm.dailyStreak, pm.streak);
      expect(pm.lastStreakClaimDay, isEmpty);
    });

    test('prefs\'te tohumlanmış seri load() sonrası getter\'da görünür',
        () async {
      await loadSeeded(streak: 4);
      final pm = ProgressManager.instance;

      expect(pm.streak, 4);
      expect(pm.dailyStreak, 4);
      expect(pm.dailyStreak, pm.streak);
    });

    test('prefs\'te 0 tohumlanmış seri getter\'da 0 görünür; load normalize etmez',
        () async {
      await loadSeeded(streak: 0);
      final pm = ProgressManager.instance;

      // Getter salt takma addır: load() 0'ı 1'e çevirmez.
      expect(pm.dailyStreak, 0);
      expect(pm.dailyStreak, pm.streak);

      // Normalleştirme yalnız claim'de olur (`streak < 1 ? 1 : streak`).
      final gift = await pm.claimDailyGiftBox();
      expect(gift, isNotNull);
      expect(gift!.streak, 1);
      expect(pm.dailyStreak, 1);
    });

    test('ilk claim sonrası dailyStreak 1', () async {
      await loadSeeded(streak: 1);
      final pm = ProgressManager.instance;

      expect(pm.dailyStreak, 1);

      final gift = await pm.claimDailyGiftBox();

      expect(gift, isNotNull);
      expect(gift!.streak, 1);
      expect(pm.dailyStreak, 1);
      expect(pm.dailyStreak, pm.streak);
      expect(pm.lastStreakClaimDay, _todayKey());
    });

    test('ertesi gün claim sonrası seri artar (dün tohumlanmış)', () async {
      await loadSeeded(streak: 2, lastClaimDay: _yesterdayKey());
      final pm = ProgressManager.instance;

      expect(pm.dailyStreak, 2);

      final gift = await pm.claimDailyGiftBox();

      expect(gift, isNotNull);
      expect(gift!.streak, 3);
      expect(pm.streak, 3);
      expect(pm.dailyStreak, 3);
      expect(pm.lastStreakClaimDay, _todayKey());
    });

    test('iki gün ara sonrası seri sıfırlanır (dailyStreak 1)', () async {
      final twoDaysAgo =
          _dayKey(DateTime.now().subtract(const Duration(days: 2)));
      await loadSeeded(streak: 5, lastClaimDay: twoDaysAgo);
      final pm = ProgressManager.instance;

      expect(pm.dailyStreak, 5);

      final gift = await pm.claimDailyGiftBox();

      expect(gift, isNotNull);
      expect(gift!.streak, 1);
      expect(pm.streak, 1);
      expect(pm.dailyStreak, 1);
      expect(pm.lastStreakClaimDay, _todayKey());
    });

    test('claim sonrası prefs\'teki seri getter ile aynıdır ve yeniden yüklemede sürer',
        () async {
      await loadSeeded(streak: 2, lastClaimDay: _yesterdayKey());
      final pm = ProgressManager.instance;

      final gift = await pm.claimDailyGiftBox();
      expect(gift, isNotNull);
      expect(pm.dailyStreak, 3);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('lululu_daily_streak'), 3);
      expect(prefs.getString('lululu_last_streak_claim_day'), _todayKey());

      // Yeniden başlatma simülasyonu: aynı prefs'ten tekrar yükle.
      await pm.load();
      expect(pm.dailyStreak, 3);
      expect(pm.dailyStreak, pm.streak);
    });
  });
}

// NOT — ilk koşumda bakılacaklar (testler kural gereği koşulmadı):
//  * Gece-yarısı devrilme penceresi: test 23:59:5x'te başlarsa tohumdaki
//    `_yesterdayKey()` claim anında iki gün öncesine döner; "ertesi gün"
//    testi seri 3 yerine 1 bekleyip patlar. Gece yarısına yakın koşulmaz;
//    patlarsa önce saat kontrol edilir, test değil.
//  * Bekletilmeyen yazı sızıntısı: `claimDailyGiftBox` içindeki `_save()` /
//    `_persistEconomy()` yazıları bir sonraki testin tohumunu ezerse
//    `loadSeeded` başındaki `Future.delayed(Duration.zero)` yetmeyebilir;
//    o durumda guard testindeki desen aynen korunur, test değiştirilmez.
//  * `dailyStreak == streak` her testte ayrıca doğrulanır: getter'ın
//    alanla senkronu bozulursa (örn. ayrı sayaç eklenirse) ilk bozulan
//    test burası olur.
