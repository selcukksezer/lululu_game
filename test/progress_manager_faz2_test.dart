// FAZ 2 / 3E — ProgressManager kalıcı testleri: 2B davranış kilitleri
// (O1, O2, O3, K6, O22) + PM-detailed yeni API testleri.
//
// DURUM: O1/O2/O3/K6/O22 düzeltmeleri bazda MEVCUT (kodda O1/O2/O3/K6/O22
// yorumları var); bu testler "davranış kilidi"dir — 2B-öncesi davranışta
// başarısız oldukları ayrıca gösterilmemiştir (bazda geriye dönük
// koşum yapılmadı). PM-detailed testleri YENİ davranışı kapsar.
//
// Kurulum deseni test/daily_gift_box_guard_test.dart'tan alındı:
// `setMockInitialValues` + olay döngüsüne bir tur + `EnergyService.load()`
// + `ProgressManager.load()` ile singleton sıfırlama. `ProgressManager`da
// reset kancası yoktur; `load()` her çağrıda prefs'i yeniden okur.
// Tarih biçimi koddan okundu: sıfır doldurmasız `'yil-ay-gun'`
// (`ProgressManager._todayKey`).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/iap_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

/// `ProgressManager._todayKey` / `_yesterdayKey` ile aynı biçim:
/// sıfır doldurmasız `'yil-ay-gun'`.
String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _todayKey() => _dayKey(DateTime.now());

String _yesterdayKey() =>
    _dayKey(DateTime.now().subtract(const Duration(days: 1)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Prefs tohumunu kurup iki singleton'ı da tohumdan yükler.
  Future<void> loadSeeded({
    int coins = 1000,
    int energy = 10,
    Map<String, Object> extraPrefs = const <String, Object>{},
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lululu_coins': coins,
      'lululu.energy': energy,
      'lululu.energy_last_refill': nowMs,
      'lululu.energy_last_seen': nowMs,
      ...extraPrefs,
    });
    // Bir önceki testin bekletilmeyen yazılarının tohumun üstüne
    // binmemesi için olay döngüsüne bir tur verilir.
    await Future<void>.delayed(Duration.zero);
    await EnergyService.instance.load();
    await ProgressManager.instance.load();
  }

  group('O1: tek-stok aritmetiği (alias + kanonik)', () {
    test(
      'alias ve kanonik yazımlarda consume/take/refund aynı stoku görür',
      () async {
        await loadSeeded();
        final pm = ProgressManager.instance;

        // Kanonik stok başlangıcı: tohumlanan spray/raid = 3.
        expect(pm.powerCount('raid'), 3);
        expect(pm.powerCount('spray'), 3);

        // Alias yazımı kanonik stoku kurar.
        await pm.setPowerCount('spray', 5);
        expect(pm.powerCount('raid'), 5);
        expect(pm.powerCount('spray'), 5);
        expect(pm.sprayCount, 5);
        // Haritada yalnız kanonik anahtar yaşar.
        expect(pm.extraPowers.containsKey('spray'), isFalse);
        expect(pm.extraPowers['raid'], 5);

        // Kanonik tüketim alias okumasını düşürür.
        expect(await pm.consumePower('raid'), isTrue);
        expect(pm.powerCount('spray'), 4);

        // Alias tüketimi kanonik okumayı düşürür.
        expect(pm.takePower('spray'), isTrue);
        expect(pm.powerCount('raid'), 3);

        // İade tek stoğa döner.
        pm.refundPower('raid');
        expect(pm.powerCount('spray'), 4);
        expect(pm.powerCount('raid'), 4);

        // Türkçe alias da aynı stoğu tüketir.
        expect(await pm.consumePower('Raid Spreyi'), isTrue);
        expect(pm.powerCount('raid'), 3);
        expect(pm.extraPowers.containsKey('spray'), isFalse);
      },
    );

    test('kanonik pref anahtarı önce okunur, alias yalnız yedektir', () async {
      await loadSeeded(
        extraPrefs: <String, Object>{'lululu_spray': 7, 'lululu_raid': 9},
      );
      expect(ProgressManager.instance.sprayCount, 7);

      await loadSeeded(extraPrefs: <String, Object>{'lululu_raid': 9});
      expect(ProgressManager.instance.sprayCount, 9);
    });
  });

  group('O2: kayıt-bazlı yükleme', () {
    test('tek bozuk değer haritanın geri kalanını düşürmez', () async {
      // Faz 1: dün tohumla — yükleme sıfırlama yolunu çalıştırır,
      // böylece faz 2 öncesi görev ilerlemesi deterministik 0'dır.
      await loadSeeded(
        extraPrefs: <String, Object>{'lululu_daily_tasks_day': _yesterdayKey()},
      );
      final pm = ProgressManager.instance;
      expect(pm.getTaskProgress('merge'), 0);

      // Faz 2: her haritada bir bozuk girdi içeren blob'ları yazıp
      // aynı prefs'ten tekrar yükle.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lululu_daily_tasks_day', _todayKey());
      await prefs.setString(
        'lululu_daily_tasks_progress',
        '{"play": 2, "merge": "bozuk", "video": 1}',
      );
      await prefs.setString(
        'lululu_mode_high_scores',
        '{"suika": 100, "match3": "bozuk", "stack_drop": 50, '
            '"balloon_pop": null}',
      );
      await prefs.setString(
        'lululu_extra_powers',
        '{"hammer": 4, "bomb3": "xx", "hunter": 2}',
      );
      await prefs.setBool('lululu_power_seed_v1', true);
      await pm.load();

      // Görev ilerlemesi: sağlam girdiler yüklendi, bozuk atlandı.
      expect(pm.getTaskProgress('play'), 2);
      expect(pm.getTaskProgress('video'), 1);
      expect(pm.getTaskProgress('merge'), 0);

      // Mod skorları: sağlam girdiler yüklendi, bozuk/null atlandı.
      expect(pm.getModeHighScore('suika'), 100);
      expect(pm.getModeHighScore('stack_drop'), 50);
      expect(pm.getModeHighScore('match3'), 0);
      expect(pm.getModeHighScore('balloon_pop'), 0);

      // Güç stokları: sağlam girdiler yüklendi, bozuk atlandı.
      expect(pm.powerCount('hammer'), 4);
      expect(pm.powerCount('hunter'), 2);
      expect(pm.powerCount('bomb3'), 0);
    });
  });

  group('O3: buyBundle negatif maliyet reddi', () {
    test('negatif maliyet reddedilir, bakiye ve stok değişmez', () async {
      await loadSeeded(coins: 1000);
      final pm = ProgressManager.instance;

      // Çağırıcı yok (grep ile doğrulandı) — latent davranış kilidi.
      expect(await pm.buyBundle('gold_chest', -5), isFalse);
      expect(await pm.buyBundle('bilinmeyen_paket', -1), isFalse);

      expect(pm.coins, 1000);
      expect(pm.sprayCount, 3);
      expect(pm.slipperCount, 5);
      expect(pm.aydinlatCount, 2);
      expect(pm.hasRoyalCape, isFalse);
    });
  });

  group('K6: bundle tutarları katalogla eşit', () {
    test('gold_chest ödülleri katalogla eşit', () async {
      final gold = IapService.storeCatalog.firstWhere(
        (item) => item.id == 'gold_chest',
      );
      // Brifteki sayılar katalogda aynen durur.
      expect(gold.coinsGrant, 1200);

      await loadSeeded(coins: 5000);
      final pm = ProgressManager.instance;
      final coinsBefore = pm.coins;
      final slipperBefore = pm.slipperCount;
      final sprayBefore = pm.sprayCount;
      final f16Before = pm.aydinlatCount;

      expect(await pm.buyBundle('gold_chest', gold.coinCost), isTrue);

      // Karşılaştırma katalog okuyarak yapılır (sabit kopya değil).
      expect(pm.coins, coinsBefore - gold.coinCost + gold.coinsGrant);
      expect(pm.slipperCount, slipperBefore + gold.terlikGrant);
      expect(pm.sprayCount, sprayBefore + gold.raidGrant);
      expect(pm.aydinlatCount, f16Before + gold.f16Grant);
    });

    test('mega_starter_pack ödülleri katalogla eşit', () async {
      final mega = IapService.storeCatalog.firstWhere(
        (item) => item.id == 'mega_starter_pack',
      );
      expect(mega.coinsGrant, 3000);

      await loadSeeded(coins: 5000, energy: 10);
      final pm = ProgressManager.instance;
      final coinsBefore = pm.coins;
      final slipperBefore = pm.slipperCount;
      final sprayBefore = pm.sprayCount;
      final f16Before = pm.aydinlatCount;

      expect(await pm.buyBundle('mega_starter_pack', mega.coinCost), isTrue);

      expect(pm.coins, coinsBefore - mega.coinCost + mega.coinsGrant);
      expect(pm.slipperCount, slipperBefore + mega.terlikGrant);
      expect(pm.sprayCount, sprayBefore + mega.raidGrant);
      expect(pm.aydinlatCount, f16Before + mega.f16Grant);
      expect(pm.hasRoyalCape, isTrue);
      expect(EnergyService.instance.energy, EnergyService.maxEnergy);
    });
  });

  group('O22: tek-talep kuralı', () {
    test('aynı gün doubled ile ikinci talep null döner, ödeme yok', () async {
      await loadSeeded(
        coins: 1000,
        energy: 10,
        extraPrefs: <String, Object>{'lululu_daily_streak': 1},
      );
      final pm = ProgressManager.instance;

      final first = await pm.claimDailyGiftBox();
      expect(first, isNotNull);
      expect(first!.coins, 500);
      expect(first.energy, 5);
      expect(pm.coins, 1500);
      expect(EnergyService.instance.energy, 15);

      final second = await pm.claimDailyGiftBox(doubled: true);

      expect(second, isNull);
      expect(pm.coins, 1500);
      expect(EnergyService.instance.energy, 15);
      expect(pm.streak, 1);
      expect(pm.lastStreakClaimDay, _todayKey());
    });

    test('doubled: true ilk talepte de iki katı ödemez (yoksayılır)', () async {
      await loadSeeded(
        coins: 1000,
        energy: 10,
        extraPrefs: <String, Object>{'lululu_daily_streak': 1},
      );
      final pm = ProgressManager.instance;

      final gift = await pm.claimDailyGiftBox(doubled: true);

      expect(gift, isNotNull);
      expect(gift!.coins, 500);
      expect(gift.energy, 5);
      expect(pm.coins, 1500);
    });
  });

  group('PM-detailed: recordTaskProgressDetailed', () {
    test(
      'eşik aşımında görev kimliğini döner, öncesi ve sonrası boştur',
      () async {
        await loadSeeded();
        final pm = ProgressManager.instance;

        expect(await pm.recordTaskProgressDetailed('play'), isEmpty);
        expect(await pm.recordTaskProgressDetailed('play'), isEmpty);
        expect(await pm.recordTaskProgressDetailed('play'), ['play']);
        expect(await pm.recordTaskProgressDetailed('play'), isEmpty);
        expect(pm.getTaskProgress('play'), 4);
      },
    );

    test('video eşiği 1: ilk çağrı tamamlar', () async {
      await loadSeeded();
      final pm = ProgressManager.instance;

      expect(await pm.recordTaskProgressDetailed('video'), ['video']);
      expect(await pm.recordTaskProgressDetailed('video'), isEmpty);
    });

    test('bilinmeyen görev kaydedilir ama tamamlanmış sayılmaz', () async {
      await loadSeeded();
      final pm = ProgressManager.instance;

      expect(await pm.recordTaskProgressDetailed('bilinmeyen_gorev'), isEmpty);
      expect(pm.getTaskProgress('bilinmeyen_gorev'), 1);
    });

    test('zaten ödülü alınmış görev tekrar bildirilmez', () async {
      await loadSeeded(
        extraPrefs: <String, Object>{
          'lululu_daily_tasks_day': _todayKey(),
          'lululu_daily_tasks_progress': '{"play": 2}',
          'lululu_daily_tasks_claimed': ['play'],
        },
      );
      final pm = ProgressManager.instance;
      expect(pm.isTaskClaimed('play'), isTrue);

      // Eşik aşılır (2 -> 3) ama görev zaten alınmış: bildirim yok.
      expect(await pm.recordTaskProgressDetailed('play'), isEmpty);
      expect(pm.getTaskProgress('play'), 3);
    });

    test(
      'recordTaskProgress aynı çekirdeğe delege eder (delta/mutlak)',
      () async {
        await loadSeeded();
        final pm = ProgressManager.instance;

        await pm.recordTaskProgress('merge', delta: 5);
        expect(pm.getTaskProgress('merge'), 5);
        // Eşikteki görev ayrıntılı çağrıda yeniden bildirilmez.
        expect(await pm.recordTaskProgressDetailed('merge'), isEmpty);

        await pm.recordTaskProgress('combo', absoluteValue: 4);
        expect(pm.getTaskProgress('combo'), 4);
        expect(
          await pm.claimDailyTaskReward('combo', target: 4, coinReward: 200),
          isTrue,
        );
        expect(pm.coins, 1200);
      },
    );

    test(
      'recordTaskProgress kaydı kalıcıdır (yeniden yüklemede sürer)',
      () async {
        await loadSeeded();
        final pm = ProgressManager.instance;

        await pm.recordTaskProgress('play');
        await pm.load();

        expect(pm.getTaskProgress('play'), 1);
      },
    );
  });
}
