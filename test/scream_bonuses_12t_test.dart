import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> mockAudio() async {
    AudioManager().isMuted = true;
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
  }

  Future<void> pumpScream(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // GoogleFonts ağdan yazı tipi çekmesin: testte yazı tipi
    // yüklemesi geç tamamlanınca zamanlayıcı geri çağrısı postTest
    // denetimine takılır (önceden var olan ortam sorunu).
    GoogleFonts.config.allowRuntimeFetching = false;
    await mockAudio();
    await tester.pumpWidget(wrapWithL10n(const ScreamRoachScreen()));
    await tester.pump();
    // ProgressManager.load() + ilk tickler: bonus bar stokla dolsun.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('12T Çığlık Böcek bonus stokları', () {
    test('taze kurulumda tohum jump 3 / shield 2 / nitro 1 verir', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProgressManager().load();
      expect(ProgressManager().powerCount('jump'), 3);
      expect(ProgressManager().powerCount('shield'), 2);
      expect(ProgressManager().powerCount('nitro'), 1);
    });

    test(
      'mevcut kurulumda eksik tohumlar geriye dönük dolar, mevcut stok ezilmez',
      () async {
        // 12T kök sebep: eski tohumlama `lululu_power_seed_v1`
        // bayrağına bağlıydı; bayrak konmuş kurulumlara sonradan
        // eklenen güç anahtarları hiç ulaşmıyor, stok 0 kalıyordu.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'lululu_power_seed_v1': true,
          // 'raid' burada yok: `_syncPrimaryPowersToExtra` raid /
          // terlik / f16 stoklarını birincil sayaçlardan aynalar,
          // o yüzden sade `extraPowers` anahtarı (`bolt`) kullanılır.
          'lululu_extra_powers': jsonEncode(<String, int>{
            'jump': 5,
            'bolt': 7,
          }),
        });
        await ProgressManager().load();
        expect(ProgressManager().powerCount('jump'), 5);
        expect(ProgressManager().powerCount('bolt'), 7);
        expect(ProgressManager().powerCount('shield'), 2);
        expect(ProgressManager().powerCount('nitro'), 1);
      },
    );
  });

  /// Ekranı temiz kapat: ticker durur; ardından gerçek zamanlı kısa
  /// bekleme + kareler, motorun geç gelen yazı tipi bildirimlerini
  /// işletsin (yoksa postTest "animation is still running" der).
  Future<void> disposeScream(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await tester.pump();
  }

  /// Kalkan halkası (mavi daire) görünüyor mu? `_shield` true iken
  /// sahnede çizilir, kalkan bir ölümü kurtarınca söner; güç halkası
  /// (yeşil) ve nitro halkası (altın) renkleriyle ayrılır.
  bool shieldRingVisible(WidgetTester tester) {
    return find
        .byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          if (decoration is! BoxDecoration) return false;
          if (decoration.shape != BoxShape.circle) return false;
          final border = decoration.border;
          if (border is! Border) return false;
          return border.top.color == const Color(0xCC38BDF8);
        })
        .evaluate()
        .isNotEmpty;
  }

  group('12T Çığlık Böcek bonus etkileri', () {
    testWidgets('stok varken her bonus çalışır: stok düşer, çağrı görünür',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProgressManager().load();
      await pumpScream(tester);

      expect(ProgressManager().powerCount('jump'), 3);
      expect(ProgressManager().powerCount('shield'), 2);
      expect(ProgressManager().powerCount('nitro'), 1);

      await tester.tap(find.text('ZIPLAMA'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ProgressManager().powerCount('jump'), 2);
      expect(find.text('MEGA ZIPLAMA!'), findsOneWidget);

      await tester.tap(find.text('KALKAN'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ProgressManager().powerCount('shield'), 1);
      expect(find.text('KALKAN BALONU!'), findsOneWidget);

      await tester.tap(find.text('NİTRO'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ProgressManager().powerCount('nitro'), 0);
      expect(find.text('NİTRO ÇIĞLIK!'), findsOneWidget);
      // 12T: nitrodayken güç dolu kalır (önceden 1 sn içinde
      // sönüyordu); 2 sn sonra bile %100 görünür — sahte zaman
      // değil GERÇEK zamanla da (duvar saati 8 sn'lik nitro).
      expect(find.text('%100 · BAĞIRIYOR'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('%100 · BAĞIRIYOR'), findsOneWidget);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      expect(find.text('%100 · BAĞIRIYOR'), findsOneWidget);

      await disposeScream(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kalkan bir ölümü kurtarır', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProgressManager().load();
      await pumpScream(tester);

      await tester.tap(find.text('KALKAN'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ProgressManager().powerCount('shield'), 1);
      expect(shieldRingVisible(tester), isTrue);

      // Hiç dokunmadan bekle: ilk ölüm anında kalkan tükenir (halka
      // söner) ama tur sürer — sonuç ekranı henüz açılmaz. İkinci
      // ölümde sonuç ekranı açılır. (İpucu metni yalnız erişilebilirlik
      // etiketinde yazılır; `find.bySemanticsLabel` bu düzende
      // eşleşmediği için halka + sonuç ekranı gözlenir.)
      var ringGone = false;
      var dialogAt = -1;
      for (var i = 0; i < 1200; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (!ringGone && !shieldRingVisible(tester)) ringGone = true;
        if (find.text('TEKRAR OYNA').evaluate().isNotEmpty) {
          dialogAt = i;
          break;
        }
      }
      expect(ringGone, isTrue);
      expect(dialogAt, isNot(-1));
      await disposeScream(tester);
      expect(tester.takeException(), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stok 0 iken düğme pasif: stok düşmez, mağaza bildirimi çıkar',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await ProgressManager().load();
      await pumpScream(tester);

      await ProgressManager().setPowerCount('jump', 0);
      await ProgressManager().setPowerCount('shield', 0);
      await ProgressManager().setPowerCount('nitro', 0);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('ZIPLAMA'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ProgressManager().powerCount('jump'), 0);
      expect(find.text('MEGA ZIPLAMA!'), findsNothing);
      expect(
        find.text('ZIPLAMA kalmadı! Mağazadan alabilirsin.'),
        findsOneWidget,
      );

      await disposeScream(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
