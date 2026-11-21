import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/achievement_pass_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

/// W13-D — "33 Güçlendirici Koleksiyoncusu" başarımı taze misafire
/// hiçbir şey oynamadan ilk hub açılışında bedavaya veriliyordu
/// (playtest-raporu.md §0). Nedeni: `syncWithProgressManager`
/// başarım ilerlemesini `powerCount(key) > 0` ile sayıyordu ve
/// varsayılan tohumlar (`progress_manager.dart` ~790-835) 33'lük
/// kataloğun tamamını zaten kapsıyordu.
///
/// Düzeltme: sayaç stok saymaz; yalnız kazanılan/kullanılan güç
/// türlerini sayar (`ProgressManager.earnedPowerTypeCount`).
/// Tohumlar aynen kalır (12T dersi — bonus düğmelerinin ölü
/// görünmesini engellerler).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
    await AchievementPassService.instance.resetForTesting();
    await AchievementPassService.instance.load();
  });

  group('W13-D — eco_all_33_boosters bedava açılmamalı', () {
    test(
      'taze misafir boot senkronunda başarımı ALMAMALI (tohumlar sayılmaz)',
      () async {
        final pm = ProgressManager.instance;
        final service = AchievementPassService.instance;

        // Tohumlar 33'lük kataloğun tamamını kapsar: her güçten stok > 0.
        expect(ProgressManager.all33PowerKeys.length, 33);
        for (final key in ProgressManager.all33PowerKeys) {
          expect(pm.powerCount(key), greaterThan(0), reason: key);
        }
        // Ama kazanılan/kullanılan güç kümesi boştur.
        expect(pm.earnedPowerTypeCount(), 0);
        expect(pm.earnedPowerKeys, isEmpty);

        final coinsBefore = pm.coins;
        final newlyUnlocked = await service.syncWithProgressManager();

        // Taze misafir hiçbir başarım açmamalı — tohum stokları
        // başarım sayacına girmez.
        expect(newlyUnlocked, 0);
        expect(
          service.isAchievementUnlocked('eco_all_33_boosters'),
          isFalse,
        );
        expect(service.getAchievementProgress('eco_all_33_boosters'), 0);
        expect(pm.coins, coinsBefore);
        expect(service.seasonXp, 0);
        expect(
          service.unlockedTitles,
          isNot(contains('Cephanelik Komutanı')),
        );
      },
    );

    test('33 gücü kazanan oyuncu başarımı alır (+1500 coin +500 XP)',
        () async {
      final pm = ProgressManager.instance;
      final service = AchievementPassService.instance;

      for (final key in ProgressManager.all33PowerKeys) {
        await pm.addPower(key);
      }
      expect(pm.earnedPowerTypeCount(), 33);

      final coinsBefore = pm.coins;
      final newlyUnlocked = await service.syncWithProgressManager();

      expect(newlyUnlocked, 1);
      expect(service.isAchievementUnlocked('eco_all_33_boosters'), isTrue);
      expect(service.getAchievementProgress('eco_all_33_boosters'), 33);
      expect(pm.coins, coinsBefore + 1500);
      expect(service.seasonXp, 500);
      expect(service.unlockedTitles, contains('Cephanelik Komutanı'));

      // İkinci senkron idempotenttir: tekrar ödül yok.
      expect(await service.syncWithProgressManager(), 0);
      expect(pm.coins, coinsBefore + 1500);
    });

    test('kullanım yolu: tohum stokundan güç kullanmak kazanılan sayılır',
        () async {
      final pm = ProgressManager.instance;
      final service = AchievementPassService.instance;

      // Taze misafir tohum raid'ini (3 adet) bir kez kullanır.
      expect(pm.takePower('raid'), isTrue);
      expect(pm.powerCount('raid'), 2);
      expect(pm.earnedPowerKeys, contains('raid'));
      expect(pm.earnedPowerTypeCount(), 1);

      final newlyUnlocked = await service.syncWithProgressManager();
      expect(newlyUnlocked, 0);
      expect(service.isAchievementUnlocked('eco_all_33_boosters'), isFalse);
      expect(service.getAchievementProgress('eco_all_33_boosters'), 1);
    });

    test('2048 katlama: undo2048 almak/kullanmak undo sayılır', () async {
      final pm = ProgressManager.instance;

      // Mağaza 2048 güçlerini yalnız `*2048` anahtarlarına yazar,
      // 2048 ekranı yalnız `*2048` stoklarını tüketir — başarım
      // kataloğunda bunlar düz undo/shuffle/pair'dir.
      await pm.incrementPowerCount('undo2048', 1);
      expect(pm.earnedPowerKeys, contains('undo'));
      expect(pm.earnedPowerKeys, isNot(contains('undo2048')));

      expect(pm.takePower('shuffle2048'), isTrue);
      expect(pm.earnedPowerKeys, contains('shuffle'));

      expect(pm.earnedPowerTypeCount(), 2);
    });

    test('grantArcadeDrop terlik/raid/f16 kazandırır', () async {
      final pm = ProgressManager.instance;

      await pm.grantArcadeDrop(slipper: 1, spray: 1, f16: 1);
      expect(pm.earnedPowerKeys, containsAll(['terlik', 'raid', 'f16']));
      expect(pm.earnedPowerTypeCount(), 3);
    });

    test('setPowerCount (IAP geri alma yolu) kazanılan sayılmaz', () async {
      final pm = ProgressManager.instance;

      // Geri alma, satın alma öncesi stok değerini yazar — kazanım değildir.
      await pm.setPowerCount('raid', 5);
      expect(pm.powerCount('raid'), 5);
      expect(pm.earnedPowerTypeCount(), 0);
    });

    test('kazanılan güçler yeniden yüklemede korunur', () async {
      final pm = ProgressManager.instance;

      await pm.addPower('raid');
      await pm.addPower('hammer');
      await pm.load();

      expect(pm.earnedPowerKeys, containsAll(['raid', 'hammer']));
      expect(pm.earnedPowerTypeCount(), 2);
      // Tohumlar da aynen durur.
      expect(pm.powerCount('raid'), greaterThan(0));
    });

    test('clearLocalData kazanılan kümeyi sıfırlar, tohumlar geri gelir',
        () async {
      final pm = ProgressManager.instance;

      await pm.addPower('raid');
      expect(pm.earnedPowerTypeCount(), 1);

      await pm.clearLocalData();

      expect(pm.earnedPowerTypeCount(), 0);
      expect(pm.earnedPowerKeys, isEmpty);
      // Tohumlar yeniden uygulanır — bonus düğmeleri ölü görünmez.
      expect(pm.powerCount('raid'), 3);
    });
  });
}
