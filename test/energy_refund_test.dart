import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

// Madde 35: `energyConsumed` ile girilen Suika oturumunda, oyun bitmeden
// ve hiç hamle yapılmadan çıkılırsa 1 enerji iade edilir
// (lib/screens/game_screen.dart dispose: `addEnergy(1)`).
// İade sayacı `_dropsMade` düşürme anında artar; yeniden başlatma
// sıfırlamaz.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(channel),
            (call) async => null,
          );
    }
    await EnergyService.instance.load();
    EnergyService.instance.energy = 3;
  });

  Future<void> pumpGame(
    WidgetTester tester, {
    required bool energyConsumed,
  }) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpWithL10n(
      tester,
      GameScreen(
        level: CampaignDatabase.kitchenLevel1,
        arcade: true,
        energyConsumed: energyConsumed,
      ),
      theme: buildLululuTheme(),
      debugShowCheckedModeBanner: false,
    );
    await tester.pump(const Duration(milliseconds: 80));
  }

  Future<void> disposeGame(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('hamlesiz çıkışta 1 enerji iade edilir', (tester) async {
    await pumpGame(tester, energyConsumed: true);
    expect(EnergyService.instance.energy, 3);
    expect(find.text('SIRADAKİ'), findsOneWidget);

    await disposeGame(tester);

    expect(EnergyService.instance.energy, 4);
    expect(EnergyService.instance.energyNotifier.value, 4);
  });

  testWidgets('energyConsumed false ise çıkışta iade yapılmaz', (
    tester,
  ) async {
    await pumpGame(tester, energyConsumed: false);
    await disposeGame(tester);

    expect(EnergyService.instance.energy, 3);
  });

  testWidgets('hamle yapıldıysa çıkışta iade yapılmaz', (tester) async {
    await pumpGame(tester, energyConsumed: true);
    // suika_play_test ile aynı kanıtlanmış desen: arena satırına dokunuş
    // düşürme sayılır (`_dropsMade` düşürme anında artar). İki ayrı
    // noktaya dokunulur; 280 ms düşürme kilidi arasında beklenir.
    await tester.tapAt(const Offset(120, 250));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(const Offset(250, 250));
    await tester.pump(const Duration(milliseconds: 400));

    await disposeGame(tester);

    expect(EnergyService.instance.energy, 3);
  });

  group('EnergyService iade ilkelleri (servis seviyesi)', () {
    test('tryConsume + addEnergy turu bakiyeyi eski hâline getirir', () async {
      final service = EnergyService.instance;
      expect(await service.tryConsume(), isTrue);
      expect(service.energy, 2);

      service.addEnergy(1);
      expect(service.energy, 3);
    });

    test('enerji yokken tryConsume false döner ve bakiye değişmez', () async {
      final service = EnergyService.instance;
      service.energy = 0;

      expect(await service.tryConsume(), isFalse);
      expect(service.energy, 0);
    });

    test('addEnergy tavanda kırpılır (maxEnergy üstüne çıkmaz)', () {
      final service = EnergyService.instance;
      service.energy = EnergyService.maxEnergy;

      service.addEnergy(5);

      expect(service.energy, EnergyService.maxEnergy);
    });

    test('tryConsume(0) enerji harcamaz', () async {
      final service = EnergyService.instance;

      expect(await service.tryConsume(0), isTrue);
      expect(service.energy, 3);
    });
  });
}
