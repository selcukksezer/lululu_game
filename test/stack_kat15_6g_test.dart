// 6G: Stack Drop KAT-15 kule kaybolması (A8b G15 / A8c G28) regresyon testi.
//
// Canlı (web, 430x932) iki bağımsız koşuda: KAT 15'e ulaşınca arena
// tamamen boşalıyor (kule + hareketli blok yok), dokunuşlar 20+ sn
// yanıtsız; duraklatma/yardım/BİTİR çalışıyor. KAT 13/14 normal.
//
// Kök neden (lib/modes/stack_drop_screen.dart `_slabWidget`): arena
// altına kayan ilk dilim (KAT 15'te alt tohum dilim) `SizedBox.shrink`
// ile konumlandırılmamış çocuk olarak dönüyordu; arena `Stack`'i
// (loose fit) `RenderStack._computeSize` gereği 0 genişliğe küçülüyor,
// kule + hareketli blok görünmez oluyor, dokunuşlar ıskalanıyordu.
//
// Bu test oyunu kapalı-döngü mükemmel bırakmalarla KAT 15'e taşır ve
// (a) KAT 15 etiketli kulenin ekranda görünür olduğunu,
// (b) hareketli bloğun görünür olduğunu,
// (c) KAT 15 sonrası bir bırakmanın daha KAT 16'ya ulaştırdığını
// (skor/kat artmaya devam eder) doğrular.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

/// Piksel testindeki desen: yazı tipleri önceden yüklenir; aksi hâlde
/// motorun tembel yazı-tipi yüklemesi teardown'da `fontsChange` geri
/// çağrısı bırakıp testi düşürür (bazda stack_play_test de aynı
/// tuzakla düşer).
Future<void> _loadKat15Fonts() async {
  const fontFiles = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Bold.ttf',
      'assets/fonts/Baloo2-ExtraBold.ttf',
    ],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
    ],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Bold.ttf',
      'assets/fonts/Exo2-ExtraBold.ttf',
    ],
    'Bangers': ['assets/fonts/Bangers-Regular.ttf'],
  };
  for (final entry in fontFiles.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadAppFonts();
    await _loadKat15Fonts();
  });

  Future<void> pumpFrames(WidgetTester tester, int milliseconds) async {
    final frames = (milliseconds / 16).ceil();
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AudioManager().isMuted = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (call) async => null,
        );
  });

  /// Hareketli blok: yükseklik 40 olan tek Positioned (_movingSlab).
  /// Yerleşmiş dilimler 36 px yüksekliğindedir.
  Finder moverFinder() => find.byWidgetPredicate(
    (widget) => widget is Positioned && widget.height == 40.0,
  );

  /// En üst yerleşmiş dilimin merkez x'i: yükseklik 36 olan Positioned
  /// dilimler arasından en üstteki (en küçük top). Etiket ('KAT n')
  /// dilim içinde sağa kayıktır (böcek + boşluk + yazı satırı) — merkez
  /// hedefi olarak kullanılırsa her bırakma sağa kayar.
  double topSlabCenterX(WidgetTester tester) {
    final slabs = find.byWidgetPredicate(
      (widget) => widget is Positioned && widget.height == 36.0,
    );
    expect(slabs, findsWidgets);
    var bestTop = double.infinity;
    var bestCenterX = 0.0;
    for (final element in slabs.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      if (rect.top < bestTop) {
        bestTop = rect.top;
        bestCenterX = rect.center.dx;
      }
    }
    return bestCenterX;
  }

  /// Ekrandaki en üst kat etiketi (örn. 'KAT 15'). Kırpılan (ekran dışı)
  /// dilimler ağaçta yoktur.
  int topFloor(WidgetTester tester) {
    var top = -1;
    for (var floor = 6; floor <= 40; floor++) {
      if (find.text('KAT $floor').evaluate().isNotEmpty) top = floor;
    }
    return top;
  }

  /// Ekrandaki sayısal Text'ler (SKOR / KAT değerleri).
  Set<String> numericTexts(WidgetTester tester) {
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((data) => RegExp(r'^[0-9.]+$').hasMatch(data))
        .toSet();
  }

  /// Hareketli blok üst dilimin merkezine gelene dek kare ilerlet, sonra
  /// bırak. Mükemmel bırakma genişliği korur (kule daralmaz).
  Future<void> dropWhenCentered(
    WidgetTester tester,
    int floor,
    String why,
  ) async {
    final slab = find.text('KAT $floor');
    expect(slab, findsOneWidget, reason: 'KAT $floor dilimi yok ($why)');
    final targetX = topSlabCenterX(tester);
    var centered = false;
    for (var frame = 0; frame < 600; frame++) {
      final mover = moverFinder();
      if (mover.evaluate().isNotEmpty) {
        final dx = (tester.getCenter(mover).dx - targetX).abs();
        if (dx <= 5) {
          centered = true;
          break;
        }
      }
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(centered, isTrue,
        reason: 'hareketli blok KAT $floor merkezine gelmedi ($why)');
    await tester.tapAt(const Offset(215, 500));
    await pumpFrames(tester, 900);
    expect(tester.takeException(), isNull);
  }

  testWidgets('Stack Drop KAT 15 kulesi görünür kalır ve bırakma sürer', (
    tester,
  ) async {
    // Görünüm boyutu test başında sıfırlanıp kurulur; teardown'da
    // sıfırlama yapılmaz.
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;

    await pumpWithL10n(tester, StackDropScreen(), theme: buildLululuTheme());
    await pumpFrames(tester, 32);
    expect(find.text('KAT 12'), findsOneWidget);
    expect(moverFinder(), findsOneWidget);

    // KAT 12 -> 15: üç mükemmel bırakma.
    for (var floor = 12; floor < 15; floor++) {
      await dropWhenCentered(tester, floor, 'KAT ${floor + 1} bırakması');
      expect(
        topFloor(tester),
        floor + 1,
        reason: 'KAT ${floor + 1} bırakması yerleşmedi',
      );
    }

    // KAT 15: kule + hareketli blok ekranda, sonlu ve görünür olmalı.
    final kat15 = find.text('KAT 15');
    expect(kat15, findsOneWidget, reason: 'KAT 15 dilimi ağaçta yok');
    final kat15Rect = tester.getRect(kat15);
    // ignore: avoid_print
    print('6G KAT15 label rect: $kat15Rect');
    expect(kat15Rect.top, greaterThanOrEqualTo(0.0));
    expect(kat15Rect.bottom, lessThanOrEqualTo(932.0));
    expect(kat15Rect.left, greaterThanOrEqualTo(0.0));
    expect(kat15Rect.right, lessThanOrEqualTo(430.0));
    // Kulenin üst katları da görünür (en az KAT 13-15).
    for (var floor = 13; floor <= 15; floor++) {
      final rect = tester.getRect(find.text('KAT $floor'));
      expect(rect.height, greaterThan(10.0),
          reason: 'KAT $floor etiketi görünür yükseklikte değil: $rect');
      expect(rect.top, greaterThanOrEqualTo(0.0),
          reason: 'KAT $floor ekranın üstünde: $rect');
      expect(rect.bottom, lessThanOrEqualTo(932.0),
          reason: 'KAT $floor ekranın altında: $rect');
    }
    // Hareketli blok görünür: sonlu konum, sıfırdan geniş.
    expect(moverFinder(), findsOneWidget,
        reason: 'KAT 15’te hareketli blok yok');
    final moverRect = tester.getRect(moverFinder());
    // ignore: avoid_print
    print('6G KAT15 mover rect: $moverRect');
    expect(moverRect.width, greaterThan(40.0));
    expect(moverRect.top, greaterThanOrEqualTo(0.0));
    expect(moverRect.bottom, lessThanOrEqualTo(932.0));
    expect(moverRect.left, greaterThanOrEqualTo(0.0));
    expect(moverRect.right, lessThanOrEqualTo(430.0));

    // KAT 15 sonrası bırakma devam eder: KAT 16 + skor artışı.
    final before = numericTexts(tester);
    await dropWhenCentered(tester, 15, 'KAT 16 bırakması');
    expect(topFloor(tester), 16, reason: 'KAT 15 sonrası bırakma yerleşmedi');
    expect(find.text('KAT 16'), findsOneWidget);
    final after = numericTexts(tester);
    expect(after, isNot(equals(before)),
        reason: 'KAT 16 bırakması sayısal değerleri değiştirmedi');
    expect(moverFinder(), findsOneWidget,
        reason: 'KAT 16’da hareketli blok yok');

    // Kapanış: bekleyen geri bildirim (1,15 sn) + dönüm noktası (2 sn)
    // zamanlayıcıları bitsin; sonra ağaç gövdede dispose edilip
    // birkaç kare daha çevrilsin.
    await pumpFrames(tester, 2500);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpFrames(tester, 500);
    expect(tester.takeException(), isNull);
  });
}
