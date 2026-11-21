import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/iap_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/widgets/shop_dialog.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

// Dalga 8F: katalogdaki 11 IAP ürününe mağaza kartı eklendi
// (coins_small / coins_handful / coins_crate, f16_x3 / raid_x3 /
// terlik_x5 / double_coin / luck_potion, gold_chest / surprise_box /
// wood_chest). Her kart: katalog başlığı + açıklaması + fiyat etiketi
// VERBATIM, satın alma mevcut _buyIapProduct + O1/O2 onay deseniyle.
// HARİÇ: mega_starter_pack — kart eklenmedi (Selçuk kararı bekliyor).
// TR yerelinde çalışır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SemanticsHandle semanticsHandle;
  late dynamic prevOnError;

  setUpAll(() async {
    await loadAppFonts();
    await loadTestFonts();
    semanticsHandle = TestWidgetsFlutterBinding.instance.ensureSemantics();
  });

  tearDownAll(() {
    semanticsHandle.dispose();
  });

  setUp(() async {
    AudioManager().isMuted = true;
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
    prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('Unable to load asset')) {
        return;
      }
      prevOnError?.call(details);
    };
    SharedPreferences.setMockInitialValues({
      'lululu_coins': 1000,
      'LululuCoinBalance': 1000,
      'lululu_royal_cape': false,
    });
    final pm = ProgressManager();
    pm.hasRoyalCape = false;
    pm.ownedCosmetics.clear();
    await pm.load();
    await EnergyService.instance.load();
    EnergyService.instance.energy = 5;
  });

  tearDown(() {
    FlutterError.onError = prevOnError;
  });

  // 8F notu: mağaza 932px görünümde kaydırılarak gezilir, ama
  // `dragUntilVisible` / `scrollUntilVisible` fling'leri ve
  // `jumpTo` adımları 277px'lik kartın düğme etiketini atlayabiliyor:
  // düğmenin semantics düğümü yalnız düğme görünür alan ± önbellek
  // içindeyken ağaçta var (8F tanısında kanıtlandı — aynı pikselde
  // bir koşuda etiket var, diğerinde yok). Bu dosya kart VARLIĞINI
  // ve satın alma yolunu denetler; kaydırma davranışı zaten
  // shop_confirm_test'te (O2/K8) kapsanıyor. Bu yüzden mağaza
  // 12000px'lik uzun görünümde pompalanır: bütün kartlar aynı anda
  // kurulur ve görünür olur, kaydırma gerekmez, test deterministiktir.
  Future<void> pumpShop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 12000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpWithL10n(
      tester,
      const ShopScreen(showBottomNav: false, embedded: true),
      debugShowCheckedModeBanner: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapDialogButton(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 11 IAP kartı: (productId, katalog başlığı, katalog açıklaması,
  /// fiyat etiketi). Katalog kanonik kaynaktır
  /// (iap_service.dart: `packs` + `storeCatalog`).
  const iapCards = <(String, String, String, String)>[
    ('coins_small', 'Küçük Torba', '500 coin', '₺29,99'),
    ('coins_handful', 'Bir Avuç', '1.250 coin', '₺59,99'),
    ('coins_crate', 'Bir Kasa', '7.500 coin · +%50 bonus', '₺249,99'),
    ('f16_x3', 'F16 x3', '3 adet F16 Hava Desteği güçlendiricisi', '₺39,99'),
    ('raid_x3', 'Raid x3', '3 adet Raid Sprey güçlendiricisi', '₺24,99'),
    ('terlik_x5', 'Anne Terliği x5', '5 adet Anne Terliği güçlendiricisi',
        '₺29,99'),
    ('double_coin', 'Çifte Coin', 'Makarayız Puan Çarpanı x2', '₺39,99'),
    ('luck_potion', 'Şans İksiri', '2048 Çiftleştir x1', '₺19,99'),
    (
      'gold_chest',
      'Altın Sandığı',
      '+1.200 Altın + F16 x1 + Raid x2 + Anne Terliği x2',
      '₺89,99'
    ),
    ('surprise_box', 'Sürpriz Kutu', 'Anne Terliği x1 + Raid x1', '₺34,99'),
    ('wood_chest', 'Ahşap Sandık', 'Anne Terliği x1 + 250 coin', '₺19,99'),
  ];

  group('8F katalog eşleşmesi (widget yok)', () {
    test('11 ürünün başlık/açıklama/fiyatı katalogla birebir', () {
      for (final (id, title, desc, price) in iapCards) {
        if (id == 'coins_small') {
          // coins_small yalnız `packs`'te: `findCatalogItem` onu
          // bulmaz (3C tuzağı) — `purchase()` yol alır.
          expect(
            IapService.findCatalogItem(id),
            isNull,
            reason: 'coins_small storeCatalog\'da değil, packs\'te',
          );
          final pack = IapService.packs
              .where((p) => p.id == id)
              .firstOrNull;
          expect(pack, isNotNull, reason: 'coins_small packs\'te olmalı');
          expect(pack!.title, title);
          expect(pack.coins, 500);
          expect(pack.priceLabel, price);
          continue;
        }
        final item = IapService.findCatalogItem(id);
        expect(item, isNotNull, reason: 'katalogda yok: $id');
        expect(item!.title, title, reason: 'başlık uyumsuz: $id');
        expect(item.description, desc, reason: 'açıklama uyumsuz: $id');
        expect(item.priceLabel, price, reason: 'fiyat uyumsuz: $id');
      }
    });

    test('mega_starter_pack katalogda var ama mağazada kartı yok', () {
      // Katalogda durur (Selçuk kararı bekliyor) ama shop_dialog
      // kaynağında hiç geçmez: kart eklenmedi, dokunulmadı.
      expect(IapService.findCatalogItem('mega_starter_pack'), isNotNull);
      final shopSource =
          File('lib/widgets/shop_dialog.dart').readAsStringSync();
      expect(shopSource, isNot(contains('mega_starter_pack')));
      // 11 ürünün her biri _buyIapProduct ile bağlıdır.
      for (final (id, _, _, _) in iapCards) {
        expect(
          shopSource,
          contains("productId: '$id'"),
          reason: 'kart _buyIapProduct ile bağlı değil: $id',
        );
      }
    });
  });

  group('8F kart görünürlüğü + katalog-verbatim metin', () {
    testWidgets('Coin bölümü: 3 yeni IAP kartı görünür', (tester) async {
      await pumpShop(tester);

      expect(find.text('KÜÇÜK TORBA'), findsOneWidget);
      expect(find.text('500 coin'), findsOneWidget);

      expect(find.text('BİR AVUÇ'), findsOneWidget);
      expect(find.text('1.250 coin'), findsOneWidget);

      expect(find.text('BİR KASA'), findsOneWidget);
      expect(find.text('7.500 coin · +%50 bonus'), findsOneWidget);
      expect(find.text('₺249,99'), findsOneWidget);
    });

    testWidgets('Güç bölümü: 5 yeni IAP kartı görünür', (tester) async {
      await pumpShop(tester);

      expect(find.text('F16 X3'), findsOneWidget);
      expect(
        find.text('3 adet F16 Hava Desteği güçlendiricisi'),
        findsOneWidget,
      );

      expect(find.text('RAİD X3'), findsOneWidget);
      expect(
        find.text('3 adet Raid Sprey güçlendiricisi'),
        findsOneWidget,
      );
      expect(find.text('₺24,99'), findsOneWidget);

      expect(find.text('ANNE TERLİĞİ X5'), findsOneWidget);
      expect(
        find.text('5 adet Anne Terliği güçlendiricisi'),
        findsOneWidget,
      );

      // Çifte Coin / Şans İksiri'nin coin kartı da var: başlık ve
      // açıklama iki kartta da görünür, IAP düğmesi fiyatıyla ayrılır.
      expect(find.text('ÇİFTE COİN'), findsWidgets);
      expect(find.text('Makarayız Puan Çarpanı x2'), findsWidgets);

      expect(find.text('ŞANS İKSİRİ'), findsWidgets);
      expect(find.text('2048 Çiftleştir x1'), findsWidgets);
    });

    testWidgets('Sandık bölümü: 3 yeni IAP kartı görünür', (tester) async {
      await pumpShop(tester);

      expect(find.text('ALTIN SANDIĞI'), findsOneWidget);
      expect(
        find.text('+1.200 Altın + F16 x1 + Raid x2 + Anne Terliği x2'),
        findsOneWidget,
      );
      expect(find.text('₺89,99'), findsOneWidget);

      expect(find.text('SÜRPRİZ KUTU'), findsWidgets);
      expect(find.text('Anne Terliği x1 + Raid x1'), findsWidgets);
      expect(find.text('₺34,99'), findsOneWidget);

      expect(find.text('AHŞAP SANDIK'), findsWidgets);
      expect(find.text('Anne Terliği x1 + 250 coin'), findsWidgets);
    });

    testWidgets('mega_starter_pack kartı çizilmez', (tester) async {
      await pumpShop(tester);
      // Uzun görünümde bütün bölümler kurulu: kart olsaydı ağaçta olurdu.
      expect(find.text('DEV BAŞLANGIÇ PAKETİ'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'Dev Başlangıç Paketi')),
        findsNothing,
      );
    });
  });

  group('8F satın alma yolu (O2 deseni)', () {
    testWidgets('her kartta dokunma onay dialogunu açar, vazgeçte harcama yok',
        (tester) async {
      await pumpShop(tester);
      expect(ProgressManager().coins, 1000);

      for (final (id, title, _, price) in iapCards) {
        await tapLabel(tester, '$title satın al, $price');
        expect(find.text('Satın almayı onayla'), findsOneWidget);
        expect(
          find.text('"$title" ürününü $price karşılığında almak istiyor musun?'),
          findsOneWidget,
          reason: 'onay gövdesi uyumsuz: $id',
        );
        await tapDialogButton(tester, 'İptal');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Satın almayı onayla'), findsNothing);
        expect(ProgressManager().coins, 1000, reason: 'vazgeçte harcama: $id');
      }
    });

    testWidgets('O2: onayla → coins_small sandbox teslimatı +500',
        (tester) async {
      await pumpShop(tester);

      await tapLabel(tester, 'Küçük Torba satın al, ₺29,99');
      await tapDialogButton(tester, 'Onayla');
      // IAP ensureLoaded 6 sn zaman aşımıyla mağaza kanalını bekleyebilir.
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 300));

      expect(ProgressManager().coins, 1500);
    });

    testWidgets('O2: onayla → f16_x3 sandbox teslimatı +3 F16',
        (tester) async {
      await pumpShop(tester);
      final f16Before = ProgressManager().f16Count;

      await tapLabel(tester, 'F16 x3 satın al, ₺39,99');
      await tapDialogButton(tester, 'Onayla');
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 300));

      expect(ProgressManager().f16Count, f16Before + 3);
    });
  });
}
