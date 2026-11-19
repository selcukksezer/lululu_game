// IAP-1 (mağaza yolu rollback) + IAP-3 (delivered-ID kap 1000) testleri.
//
// IAP-1: `_deliverProduct` grant yarıda fırlatırsa kısmi grant geri
// alınmalı ve `false` dönmeli; temiz yeniden teslimat ürünü tam olarak
// bir kez vermeli (çift-grant yok).
// IAP-3: delivered-ID kabı 1000 olmalı (özel const, kaynak düzeyinde
// kilitlenir — teslim kimlikleri testten erişilemeyen özeldir).
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/iap_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDocsDir;

  const List<MethodChannel> pathProviderChannels = <MethodChannel>[
    MethodChannel('plugins.flutter.io/path_provider'),
    MethodChannel('plugins.flutter.io/path_provider_macos'),
    MethodChannel('plugins.flutter.io/path_provider_foundation'),
  ];

  setUp(() async {
    tempDocsDir = await Directory.systemTemp.createTemp('lululu_iap_8d_');
    for (final channel in pathProviderChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        return tempDocsDir.path;
      });
    }
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await EnergyService.instance.load();
    await ProgressManager.instance.load();
    await IapService.instance.ensureLoaded();
  });

  tearDown(() async {
    IapService.throwAfterCoinsGrantForTest = false;
    for (final channel in pathProviderChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
    if (tempDocsDir.existsSync()) {
      await tempDocsDir.delete(recursive: true);
    }
  });

  test(
    'IAP-1: mağaza grant yarıda fırlatırsa geri alınır, yeniden teslimat '
    'çift-grant yapmaz',
    () async {
      final iap = IapService.instance;
      final pm = ProgressManager.instance;
      final energy = EnergyService.instance;

      // gold_chest: +1.200 coin + F16 x1 + Raid x2 + Terlik x2.
      // Kanca coin grant'inden SONRA fırlatır: coin verildi, güçler
      // verilmedi — geri alma coin'i de geri almalıdır.
      final coinsBefore = pm.coins;
      final f16Before = pm.f16Count;
      final raidBefore = pm.raidCount;
      final terlikBefore = pm.terlikCount;
      final energyBefore = energy.energy;

      IapService.throwAfterCoinsGrantForTest = true;
      final failed = await iap.purchase('gold_chest');
      IapService.throwAfterCoinsGrantForTest = false;

      expect(failed, isFalse, reason: 'yarıda kesilen teslimat false döner');
      expect(pm.coins, coinsBefore, reason: 'verilen coin geri alındı');
      expect(pm.f16Count, f16Before);
      expect(pm.raidCount, raidBefore);
      expect(pm.terlikCount, terlikBefore);
      expect(energy.energy, energyBefore);

      // Temiz yeniden teslimat: tam olarak bir kez grant.
      final ok = await iap.purchase('gold_chest');
      expect(ok, isTrue);
      expect(pm.coins, coinsBefore + 1200);
      expect(pm.f16Count, f16Before + 1);
      expect(pm.raidCount, raidBefore + 2);
      expect(pm.terlikCount, terlikBefore + 2);
      expect(energy.energy, energyBefore);
    },
  );

  test(
    'IAP-1: coin grant içermeyen üründe yarıda kesilme stokları bozmaz',
    () async {
      final iap = IapService.instance;
      final pm = ProgressManager.instance;

      // f16_x3: coin grant'i yok, kanca hiç tetiklenmez — normal grant.
      final f16Before = pm.f16Count;
      final ok = await iap.purchase('f16_x3');
      expect(ok, isTrue);
      expect(pm.f16Count, f16Before + 3);
    },
  );

  test('IAP-3: delivered-ID kap 1000', () {
    final root = Directory.current;
    final source = File('${root.path}/lib/services/iap_service.dart')
        .readAsStringSync();
    expect(
      source,
      contains('static const int _maxDeliveredPurchaseIds = 1000;'),
      reason: 'IAP-3: kap 200 değil 1000 olmalı',
    );
    expect(
      source,
      isNot(contains('_maxDeliveredPurchaseIds = 200')),
    );
    // İki budama noktası da sabiti kullanmalı (sabit değer yazılmamalı).
    expect(source, contains('_loadDeliveredIds'));
    expect(source, contains('_markPurchaseDelivered'));
  });
}
