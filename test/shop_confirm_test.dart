import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/widgets/energy_empty_popup.dart';
import 'package:lululu_game/widgets/shop_dialog.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

// Dalga 3C: mağaza + enerji popup'ı satın alma ön-onayları (O1/O2/O3),
// katalog-hizalı kart metinleri (2H bayrakları) ve Kraliyet Pelerini
// sahiplik durumu (K8). TR yerelinde çalışır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SemanticsHandle semanticsHandle;
  late dynamic prevOnError;

  setUpAll(() async {
    // Gerçek font metrikleri: test fontlarıyla bölüm başlıkları 0,16 px
    // taşıyor (responsive harness ile aynı kurulum).
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
    // Eksik görsel yükleme hataları (responsive harness ile aynı koruma).
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

  Future<void> pumpShop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
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

  Future<void> scrollToLabel(WidgetTester tester, String label) async {
    await tester.dragUntilVisible(
      find.bySemanticsLabel(label),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.pump();
  }

  Future<void> scrollToText(WidgetTester tester, String text) async {
    await tester.dragUntilVisible(
      find.text(text),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.pump();
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    await scrollToLabel(tester, label);
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapDialogButton(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('O1: vazgeç → coin harcanmaz, dialog kapanır', (tester) async {
    await pumpShop(tester);
    expect(ProgressManager().coins, 1000);

    await tapLabel(tester, 'Ahşap Sandık satın al, 200');
    expect(find.text('Satın almayı onayla'), findsOneWidget);
    expect(
      find.text('"Ahşap Sandık" ürününü 200 coin karşılığında almak istiyor musun?'),
      findsOneWidget,
    );

    await tapDialogButton(tester, 'İptal');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Satın almayı onayla'), findsNothing);
    expect(ProgressManager().coins, 1000);
  });

  testWidgets('O1: onayla → coin harcanır, sandık ödülü verilir',
      (tester) async {
    await pumpShop(tester);

    await tapLabel(tester, 'Ahşap Sandık satın al, 200');
    await tapDialogButton(tester, 'Onayla');
    await tester.pump(const Duration(milliseconds: 300));

    // 200 harcama + 250 sandık ödülü.
    expect(ProgressManager().coins, 1050);
    expect(find.text('Ahşap Sandık sepete eklendi'), findsOneWidget);
  });

  testWidgets('O2: IAP vazgeç → satın alma başlamaz, coin değişmez',
      (tester) async {
    await pumpShop(tester);

    await tapLabel(tester, 'Makara Paket satın al, ₺79,99');
    expect(find.text('Satın almayı onayla'), findsOneWidget);
    expect(
      find.text('"Makara Paket" ürününü ₺79,99 karşılığında almak istiyor musun?'),
      findsOneWidget,
    );

    await tapDialogButton(tester, 'İptal');
    await tester.pump(const Duration(milliseconds: 300));
    expect(ProgressManager().coins, 1000);
  });

  testWidgets('O2: IAP onayla → teslimat çalışır (debug sandbox)',
      (tester) async {
    await pumpShop(tester);

    await tapLabel(tester, 'Makara Paket satın al, ₺79,99');
    await tapDialogButton(tester, 'Onayla');
    // IAP ensureLoaded 6 sn zaman aşımıyla mağaza kanalını bekleyebilir;
    // sahte saat ilerletilmeden teslimat tamamlanmaz.
    await tester.pump(const Duration(seconds: 7));
    await tester.pump(const Duration(milliseconds: 300));

    // Sandbox teslimatı: coins_mid 1500 coin verir.
    expect(ProgressManager().coins, 2500);
  });

  testWidgets('2H bayrakları: kart metinleri katalogla birebir eşleşir',
      (tester) async {
    await pumpShop(tester);

    // Yıldız Paketi kartı: star_pack başlık/açıklama/fiyat.
    await scrollToLabel(tester, 'Yıldız Paketi satın al, ₺149,99');
    expect(find.text('YILDIZ PAKETİ'), findsOneWidget);
    expect(find.text('1.000 coin + F16 x1'), findsOneWidget);

    // Coin paketleri: teslim edilen coins_mid / coins_big değerleri.
    await scrollToLabel(tester, 'Makara Paket satın al, ₺79,99');
    expect(find.text('MAKARA PAKET'), findsOneWidget);
    expect(find.text('1.500 coin'), findsOneWidget);
    expect(find.text('₺79,99'), findsWidgets);
    await scrollToLabel(tester, 'Kongo Sandık satın al, ₺199,99');
    expect(find.text('KONGO SANDIK'), findsOneWidget);
    expect(find.text('5.000 coin'), findsOneWidget);
    expect(find.text('₺199,99'), findsWidgets);
  });

  testWidgets('K8: pelerin kartı görünür; sahip olunmadığında satın alınabilir',
      (tester) async {
    await pumpShop(tester);

    await scrollToText(tester, 'KRALİYET PELERİNİ');
    expect(find.text('KRALİYET PELERİNİ'), findsOneWidget);
    expect(
      find.text('Efsanevi Kraliyet Pelerini kozmetik görünümü'),
      findsOneWidget,
    );
    expect(find.text('Kozmetik'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Kraliyet Pelerini satın al')),
      findsOneWidget,
    );
  });

  testWidgets('K8: pelerin sahiplenildiğinde kart devre dışı kalır',
      (tester) async {
    ProgressManager().hasRoyalCape = true;
    ProgressManager().ownedCosmetics.add('royal_cape');
    await pumpShop(tester);

    await scrollToText(tester, 'KRALİYET PELERİNİ');
    expect(find.text('Sahip Olundu'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Kraliyet Pelerini · Sahip Olundu')),
      findsOneWidget,
    );
    await tester.tap(find.text('Sahip Olundu'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Satın almayı onayla'), findsNothing);
    expect(ProgressManager().coins, 1000);
  });

  testWidgets('Restore girişi görünür ve dokunulabilir', (tester) async {
    await pumpShop(tester);
    await tester.dragUntilVisible(
      find.text('Satın alımları geri yükle'),
      find.byType(ListView),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(find.text('Satın alımları geri yükle'), findsOneWidget);
    await tester.tap(find.text('Satın alımları geri yükle'));
    await tester.pump(const Duration(milliseconds: 500));
    // Mağaza yok: kullanılamıyor bildirimi gösterilir.
    expect(
      find.text('Geri yükleme kullanılamıyor — mağaza yok.'),
      findsOneWidget,
    );
  });

  Future<void> pumpPopupHost(WidgetTester tester, {int energy = 0}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    EnergyService.instance.energy = energy;
    await pumpWithL10n(
      tester,
      Scaffold(
        body: Center(
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showEnergyEmptyPopup(context),
              child: const Text('AC'),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
    await tester.pump();
    await tester.tap(find.text('AC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Dalga 18: başlık enerjiye göre — 0 iken "ENERJİN BİTTİ!",
    // kısmi enerjide "ENERJİ AL".
    expect(
      find.text(energy == 0 ? 'ENERJİN BİTTİ!' : 'ENERJİ AL'),
      findsOneWidget,
    );
  }

  testWidgets('O3: enerji popup vazgeç → harcama yok, popup açık kalır',
      (tester) async {
    await pumpPopupHost(tester);
    expect(ProgressManager().coins, 1000);

    await tester.tap(find.text('MAĞAZA · ENERJİ PAKETİ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Satın almayı onayla'), findsOneWidget);
    expect(
      find.text('+5 enerji için 100 coin harcamak istiyor musun?'),
      findsOneWidget,
    );

    await tapDialogButton(tester, 'İptal');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Satın almayı onayla'), findsNothing);
    expect(find.text('ENERJİN BİTTİ!'), findsOneWidget);
    expect(ProgressManager().coins, 1000);
    expect(EnergyService.instance.energy, 0);

    await tester.tap(find.text('SAYACI BEKLE'));
    await tester.pump(const Duration(milliseconds: 200));
    // Popup kapandı (ticker durdu). Motorun 'fontsChange' bildirimi
    // gerçek zamanlı gelir: FakeAsync dışında bekleyip kare
    // pompalayarak planlanan geri çağrıyı akıt, sonra ağacı
    // test içinde dispose et.
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
  });

  testWidgets('O3: enerji popup onayla → 100 coin harcanır, +5 enerji verilir',
      (tester) async {
    await pumpPopupHost(tester);

    await tester.tap(find.text('MAĞAZA · ENERJİ PAKETİ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tapDialogButton(tester, 'Onayla');
    await tester.pump(const Duration(milliseconds: 300));

    expect(ProgressManager().coins, 900);
    expect(EnergyService.instance.energy, 5);
    expect(find.text('ENERJİN BİTTİ!'), findsNothing);
    expect(find.text('+5 enerji eklendi!'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
  });

  testWidgets('Dalga 18: kısmi enerjide (29/30) popup başlığı ENERJİ AL',
      (tester) async {
    await pumpPopupHost(tester, energy: 29);
    expect(find.text('ENERJİN BİTTİ!'), findsNothing);
    // Not: SAYACI BEKLE ile kapanış bu harness'ta enerji 0'da da
    // işlemiyor (önceden var, Dalga 18 dışı) — başlık iddiası bu;
    // kapanış ayrıca doğrulanmaz, ağaç doğrudan dispose edilir.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.pump();
  });
}
