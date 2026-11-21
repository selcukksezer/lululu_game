import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/settings_screen.dart';
import 'package:lululu_game/services/campaign_progression_service.dart';
import 'package:lululu_game/services/cloud_sync_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

// Dalga 12W — profil seviyesi her cihazda 18.
//
// Teşhis özeti (bkz. briefs/12W-profile-level-report.md):
// * Taze varsayılan 1'dir; 18 kodda tohumlanmaz.
// * `recordLevelResult` eski kuralı (`levelId >= unlockedLevel`) ile
//   ilerideki bir seviyenin tek tamamlanışında seviyeyi sıçratırdı.
// * Ayarlar → "İlerlemeyi Sıfırla" kampanya v2 anahtarlarını ve LWW
//   damgalarını temizlemediği için sıfırlama tutunmuyordu.
// * Bulut birleşmesinde OTOMATİK KISMA YOKTUR (bilinçli karar): yerel
//   tamamlanma kanıtı cihaz başına kısmi görünümdür; başka cihazda
//   gerçekten bitmiş 17 seviyeyi, bu cihazda yalnız 5 bitmiş diye
//   6'ya kısmak gerçek ilerlemeyi bütün cihazlarda siler. Düzeltme
//   yalnız kullanıcının onaylı sıfırlamasıyla olur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Future<void>.delayed(Duration.zero);
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
    await CampaignProgressionService.instance.load();
  });

  group('12W — taze profil ve sıralı ilerleme', () {
    test('taze profil seviye 1 başlar', () {
      expect(ProgressManager.instance.unlockedLevel, 1);
    });

    test('ilerideki seviye tek başına bitince seviye sıçramaz', () async {
      final pm = ProgressManager.instance;
      expect(pm.unlockedLevel, 1);

      await pm.recordLevelResult(
        levelId: 17,
        score: 100,
        stars: 3,
        victory: true,
      );

      expect(pm.unlockedLevel, 1);
      expect(pm.getStarCount(17), 3);
      expect(pm.getHighScore(17), 100);
    });

    test('sırayla bitirme 1 → 2 → 3 ilerletir', () async {
      final pm = ProgressManager.instance;

      await pm.recordLevelResult(
        levelId: 1,
        score: 100,
        stars: 2,
        victory: true,
      );
      expect(pm.unlockedLevel, 2);

      await pm.recordLevelResult(
        levelId: 2,
        score: 100,
        stars: 1,
        victory: true,
      );
      expect(pm.unlockedLevel, 3);

      // Gerideki seviyeyi tekrar bitirmek kilidi geri/ileri oynatmaz.
      await pm.recordLevelResult(
        levelId: 1,
        score: 200,
        stars: 3,
        victory: true,
      );
      expect(pm.unlockedLevel, 3);
    });
  });

  group('12W — bulut birleşmesinde otomatik kısma yok', () {
    test('yerel kanıtsız taze cihaz bulut 18’i benimser', () async {
      final pm = ProgressManager.instance;
      final cloud = CloudSyncService.instance;
      pm.unlockedLevel = 1;
      pm.unlockedLevelUpdatedAtMs = 10000;
      pm.syncPersistedSnapshot();

      final payload = <String, dynamic>{
        'unlockedLevel': 18,
        'unlockedLevelUpdatedAtMs': 12000,
      };
      payload['integrityHash'] = cloud.computeIntegrityHash(payload);

      final ok = await cloud.applyTimestampedProfileSnapshot(
        payload,
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      // Bilinçli karar: yerel kanıt yoksa bulut değeri gerçektir
      // sayılır; taze cihaz gerçek ilerlemesini kaybetmez.
      expect(pm.unlockedLevel, 18);
    });

    test('yerel kanıt varken bile birleşim bulutu ezmez', () async {
      final pm = ProgressManager.instance;
      final service = CampaignProgressionService.instance;
      final cloud = CloudSyncService.instance;
      for (int id = 1; id <= 5; id++) {
        await service.setStarsForLevel(id, 3);
      }
      expect(pm.unlockedLevel, 6);
      expect(service.isLevelCompleted(5), isTrue);
      pm.unlockedLevelUpdatedAtMs = 10000;
      pm.syncPersistedSnapshot();

      final payload = <String, dynamic>{
        'unlockedLevel': 18,
        'unlockedLevelUpdatedAtMs': 12000,
      };
      payload['integrityHash'] = cloud.computeIntegrityHash(payload);

      final ok = await cloud.applyTimestampedProfileSnapshot(
        payload,
        allowUnsignedLegacy: true,
      );
      expect(ok, isTrue);
      // Yerel 1..5 kanıtı kısmi görünüm olabilir (17 seviye başka
      // cihazda bitmiş olabilir); otomatik kısma yapılmaz, düzeltme
      // yalnız kullanıcının sıfırlamasıyla olur.
      expect(pm.unlockedLevel, 18);
    });
  });

  group('12W — sıfırlama gerçekten sıfırlar', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrapWithL10n(const SettingsScreen(), theme: buildLululuTheme()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    /// Motor bildirimlerini (sistem fontu değişimi) tüketir: bildirimler
    /// GERÇEK zamanda ulaşır, sahte zamanlı pump'lar onları beklemez;
    /// bekleyen çerçeve geri çağrısı teardown'da "animation is still
    /// running" istisnasına dönüşür. Bu ortam sorunu bu kopyada
    /// `missing_screens_test`'te de testleri düşürür (önceden var);
    /// kısa gerçek bekleme + 3 pump, bildirimi test gövdesi içinde
    /// güvenle tüketir (audio_settings_6b_test deseni).
    Future<void> flushEngineNotifications(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }

    testWidgets('Ayarlar sıfırlaması seviye + kampanya + damgaları temizler',
        (tester) async {
      final pm = ProgressManager.instance;
      final service = CampaignProgressionService.instance;
      for (int id = 1; id <= 5; id++) {
        await service.setStarsForLevel(id, 3);
      }
      expect(pm.unlockedLevel, 6);
      expect(service.isLevelCompleted(5), isTrue);
      expect(service.isLevelUnlocked(6), isTrue);

      // Sıfırlama öncesi seviye damgasını eski bir değere sabitle:
      // sıfırlama damgayı "şimdi" ile yeniden tohumlamalı ki bulut
      // 18'i geri uygulayamasın.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lululu_ts_level', 1000);
      await prefs.setBool('lululu_lww_stamps_seeded_v1', true);

      await pumpSettings(tester);
      await tester.ensureVisible(find.text('İlerlemeyi Sıfırla'));
      await tester.tap(find.text('İlerlemeyi Sıfırla'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('İLERLEMEYİ SIFIRLA'), findsOneWidget);

      await tester.tap(find.text('SIFIRLA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(pm.unlockedLevel, 1);
      expect(service.isLevelCompleted(1), isFalse);
      expect(service.isLevelCompleted(5), isFalse);
      expect(service.isLevelUnlocked(2), isFalse);
      expect(service.isLevelUnlocked(6), isFalse);

      final after = await SharedPreferences.getInstance();
      expect(
        after.getStringList('lululu_campaign_completed_v2'),
        isNull,
      );
      expect(after.getString('lululu_campaign_stars_v2'), isNull);
      expect(after.getInt('lululu_unlocked_level'), isNull);
      // Damgalar yeniden tohumlandı: eski 1000 değeri gitti, bayrak
      // yeniden kuruldu.
      expect(after.getInt('lululu_ts_level'), greaterThan(1000));
      expect(after.getBool('lululu_lww_stamps_seeded_v1'), isTrue);
      await flushEngineNotifications(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
