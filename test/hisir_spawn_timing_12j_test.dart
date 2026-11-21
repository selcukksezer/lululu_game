// test/hisir_spawn_timing_12j_test.dart — Brif 12J.
//
// Hışır ilk spawn zamanlaması: kapı açıkken 15. sn'de belirir; kapı
// geçici kapalıyken (motor yok / duraklatılmış) 20 sn erteleme yerine
// 3 sn aralıkla yeniden denenir, duraklatma açılınca en geç 3 sn
// içinde belirir. Sonraki aralık (40–70 sn) + 7 sn görünür aynen kalır.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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
  });

  Future<void> pumpGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpWithL10n(
      tester,
      GameScreen(
        level: CampaignDatabase.kitchenLevel1,
        arcade: true,
      ),
      debugShowCheckedModeBanner: false,
      theme: buildLululuTheme(),
    );
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets('kapı açıkken Hışır 15. sn\'de belirir, 7 sn görünür',
      (tester) async {
    await pumpGame(tester);
    expect(find.text('Mezarına sıçtığım!'), findsNothing);

    await tester.pump(const Duration(seconds: 15));
    expect(
      find.text('Mezarına sıçtığım!'),
      findsOneWidget,
      reason: 'ilk spawn 15. sn\'de olmalı',
    );

    // 7 sn görünür: 6 sn sonra hâlâ görünür, 7 sn dolunca gizlenir.
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Mezarına sıçtığım!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Mezarına sıçtığım!'), findsNothing);

    // Sonraki spawn en erken 40 sn sonra (15 + 40 = 55. sn): 54. sn'de
    // hâlâ görünmemeli.
    await tester.pump(const Duration(seconds: 32));
    expect(find.text('Mezarına sıçtığım!'), findsNothing);

    // Bekleyen geçici kare geri çağrılarını ağaç bağlıyken temizle.
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Görünüm sıfırlamasını gövde içinde yap, sonra kaldır ve birkaç
    // kare daha pompalayın: sistem yazı tipi bildirimi geç gelirse
    // bekleyen geçici geri çağrı çalışsın, teardown'da kalmasın.
    // Sistem-yazıtipi bildirimi gerçek-zamanlı gelir: sahte saatli
    // pump'lar onu yakalayamaz (12P deseni) — gerçek kısa bekleme +
    // pump, dispose anında bekleyen kare geri-çağrısı kalmasın diye.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.pump();
  });

  testWidgets(
      'duraklatılmışken spawn olmaz, DEVAM sonrası en geç 3 sn içinde belirir',
      (tester) async {
    await pumpGame(tester);

    // Yaşam döngüsü duraklatması: oyun DEVAM beklerken durur.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // 15. sn'de kapı kapalı: gösterim olmaz, kısa aralıkla yeniden deneme
    // kurulur. Duraklatma sürerken 12 sn daha geçse de belirmez.
    await tester.pump(const Duration(seconds: 15));
    expect(find.text('Mezarına sıçtığım!'), findsNothing);
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Mezarına sıçtığım!'), findsNothing);

    // Arka plandan dönüş: `resumed` olayı test bağlayıcısında
    // dokunuşları açar ama oyunu başlatmaz (üretimde `resumed` dalı
    // bilerek boştur — oyun yalnız DEVAM ile açılır). Kaplama hâlâ
    // DEVAM bekler; bu, arka plandan dönen kullanıcının gerçek akışıdır.
    // (`resumed` olmadan test bağlayıcısı dokunuşları iletmez.)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('DEVAM ET'), findsOneWidget);

    // DEVAM: duraklatma açılır, bir sonraki kısa yeniden denemede
    // (en geç 3 sn) Hışır belirir. Önce sıfır süreli kareyle dokunuş
    // işlensin (_paused açılsın): aksi hâlde 3 sn'lik pump'ta
    // zamanlayıcı dokunuştan önce ateşlenip yeniden erteler.
    await tester.tap(find.text('DEVAM ET'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.text('Mezarına sıçtığım!'),
      findsOneWidget,
      reason: 'DEVAM sonrası kısa yeniden denemeyle Hışır belirmeli',
    );

    // Bekleyen geçici kare geri çağrılarını ağaç bağlıyken temizle.
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Görünüm sıfırlamasını gövde içinde yap, sonra kaldır ve birkaç
    // kare daha pompalayın: sistem yazı tipi bildirimi geç gelirse
    // bekleyen geçici geri çağrı çalışsın, teardown'da kalmasın.
    // Sistem-yazıtipi bildirimi gerçek-zamanlı gelir: sahte saatli
    // pump'lar onu yakalayamaz (12P deseni) — gerçek kısa bekleme +
    // pump, dispose anında bekleyen kare geri-çağrısı kalmasın diye.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.pump();
  });
}
