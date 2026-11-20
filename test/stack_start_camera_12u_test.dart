// 12U: Stack Drop 1 katla başlar + kamera tepeyi görünür tutar.
//
// (a) Başlangıç: tek dilim (KAT 1), KAT 2 yok.
// (b) Kamera: mükemmel bırakmalarla KAT 20'ye çıkılır; en üst dilim
//     ekran içinde kalır ve kat arttıkça ekran konumu sabitlenir
//     (çapa) — eski %55 kaymada tepe her katta 18 px yukarı kaçıyordu.
// (c) İniş: her bırakmada hareketli bloğun düşüşteki son karesi ile
//     yerleşen yeni dilimin üstü çakışır (eski çift `- _cameraY`
//     kaydırması bloğu kulenin içine indiriyordu).
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

Future<void> _load12uFonts() async {
  const fontFiles = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
    ],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
    ],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
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
    await _load12uFonts();
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
  Finder moverFinder() => find.byWidgetPredicate(
    (widget) => widget is Positioned && widget.height == 40.0,
  );

  /// Yerleşmiş dilimler: yükseklik 36 olan Positioned'lar.
  Iterable<Element> slabElements(WidgetTester tester) => find
      .byWidgetPredicate(
        (widget) => widget is Positioned && widget.height == 36.0,
      )
      .evaluate();

  /// En üst yerleşmiş dilimin rect'i (en küçük top).
  Rect topSlabRect(WidgetTester tester) {
    var bestTop = double.infinity;
    var best = Rect.zero;
    for (final element in slabElements(tester)) {
      final rect = tester.getRect(find.byWidget(element.widget));
      if (rect.top < bestTop) {
        bestTop = rect.top;
        best = rect;
      }
    }
    expect(bestTop, isNot(double.infinity), reason: 'hiç dilim yok');
    return best;
  }

  double topSlabCenterX(WidgetTester tester) =>
      topSlabRect(tester).center.dx;

  Future<void> pumpView(
    WidgetTester tester,
  ) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
        await binding.pump();
      }
    });
    await pumpWithL10n(tester, StackDropScreen(), theme: buildLululuTheme());
    await pumpFrames(tester, 32);
  }

  /// Mükemmel bırakma; iniş hizasını da doğrular: düşüşün son
  /// karesindeki hareketli blok üstü ile yeni dilimin üstü çakışmalı.
  Future<void> dropPerfectWithLandingCheck(
    WidgetTester tester,
    int floor,
  ) async {
    final slab = find.text('KAT $floor');
    expect(slab, findsOneWidget, reason: 'KAT $floor dilimi yok');
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
    expect(
      centered,
      isTrue,
      reason: 'hareketli blok KAT $floor merkezine gelmedi',
    );
    await tester.tapAt(const Offset(215, 500));
    var lastMoverTop = double.nan;
    var settled = false;
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.text('KAT ${floor + 1}').evaluate().isNotEmpty) {
        settled = true;
        break;
      }
      if (moverFinder().evaluate().isNotEmpty) {
        lastMoverTop = tester.getRect(moverFinder()).top;
      }
    }
    expect(settled, isTrue, reason: 'KAT ${floor + 1} yerleşmedi');
    expect(
      lastMoverTop.isNaN,
      isFalse,
      reason: 'düşüş karesi yakalanamadı (KAT ${floor + 1})',
    );
    final newTop = topSlabRect(tester).top;
    expect(
      (lastMoverTop - newTop).abs(),
      lessThanOrEqualTo(24.0),
      reason:
          'iniş hizası bozuk: düşüş son karesi $lastMoverTop, yeni dilim $newTop (KAT ${floor + 1})',
    );
    expect(tester.takeException(), isNull);
  }

  testWidgets('Stack Drop 1 katla başlar', (tester) async {
    await pumpView(tester);
    expect(find.text('KAT 1'), findsOneWidget);
    expect(find.text('KAT 2'), findsNothing);
    expect(slabElements(tester).length, 1,
        reason: 'başlangıçta tek dilim olmalı');
    expect(moverFinder(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpFrames(tester, 500);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kamera tepeyi görünür tutar, iniş tam üstte olur', (
    tester,
  ) async {
    await pumpView(tester);
    expect(find.text('KAT 1'), findsOneWidget);

    double? topAt15;
    for (var floor = 1; floor < 20; floor++) {
      await dropPerfectWithLandingCheck(tester, floor);
      if (floor + 1 == 15) {
        final rect = tester.getRect(find.text('KAT 15'));
        expect(rect.top, greaterThanOrEqualTo(0.0));
        expect(rect.bottom, lessThanOrEqualTo(932.0));
        topAt15 = topSlabRect(tester).top;
      }
    }

    // KAT 20: tepe ekranda, konumu KAT 15'teki çapa konumuna yakın.
    final kat20 = find.text('KAT 20');
    expect(kat20, findsOneWidget, reason: 'KAT 20 dilimi ağaçta yok');
    final kat20Rect = tester.getRect(kat20);
    expect(kat20Rect.top, greaterThanOrEqualTo(0.0));
    expect(kat20Rect.bottom, lessThanOrEqualTo(932.0));
    expect(kat20Rect.left, greaterThanOrEqualTo(0.0));
    expect(kat20Rect.right, lessThanOrEqualTo(430.0));
    final topAt20 = topSlabRect(tester).top;
    expect(topAt20, greaterThanOrEqualTo(80.0));
    expect(topAt20, lessThanOrEqualTo(420.0));
    expect(topAt15, isNotNull);
    expect(
      (topAt20 - topAt15!).abs(),
      lessThanOrEqualTo(40.0),
      reason: 'kamera tepeyi sabit tutmuyor: KAT 15 üst $topAt15, KAT 20 üst $topAt20',
    );
    // Hareketli blok görünür.
    expect(moverFinder(), findsOneWidget);
    final moverRect = tester.getRect(moverFinder());
    expect(moverRect.top, greaterThanOrEqualTo(0.0));
    expect(moverRect.bottom, lessThanOrEqualTo(932.0));

    await pumpFrames(tester, 2500);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpFrames(tester, 500);
    expect(tester.takeException(), isNull);
  });
}
