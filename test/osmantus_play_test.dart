import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    await loadTestFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  test('tutorial pacing stays gentle for the first 15 seconds', () {
    expect(OsmantusPacing.isTutorial(14999), isTrue);
    expect(OsmantusPacing.isTutorial(15000), isFalse);
    expect(OsmantusPacing.intervalMs(0), OsmantusPacing.tutorialIntervalMs);
    expect(OsmantusPacing.intervalMs(14999), OsmantusPacing.tutorialIntervalMs);
    // 45. sn (rampa 0.5): aralık 1100 − (1100−680)×0.5 = 890,
    // pencere 260 − (260−160)×0.5 = 210.
    expect(OsmantusPacing.intervalMs(45000), 890);
    expect(OsmantusPacing.windowMs(45000), 210);
  });

  test('ring colour eases continuously toward green', () {
    // Yeşil yalnız puan penceresi içinde görünür (faz ≈ 0.76'dan
    // itibaren): 0.82'de hafif yeşilimsi, 0.91'de belirgin yeşil,
    // 1.0'da tam yeşil.
    final before = OsmantusPacing.ringColorAt(0.82);
    final middle = OsmantusPacing.ringColorAt(0.91);
    final after = OsmantusPacing.ringColorAt(1);

    expect(middle, isNot(before));
    expect(after, isNot(middle));
    expect(middle.g, greaterThan(before.g));
    expect(after.g, greaterThan(middle.g));
  });

  testWidgets('reflex taps score and a broken combo shows its reason', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var nowMs = 0;
    await pumpWithL10n(
      tester,
      OsmantusScreen(clockForTesting: () => nowMs),
      theme: buildLululuTheme(),
    );
    await tester.pump();

    final stage = find.byWidgetPredicate(
      (widget) => widget is Listener && widget.onPointerDown != null,
    );
    final stageRects = List.generate(
      stage.evaluate().length,
      (index) => tester.getRect(stage.at(index)),
    );
    final stageRect = stageRects.firstWhere(
      (rect) => rect.top > 100 && rect.bottom < 600 && rect.width > 300,
    );
    final inputPoint = stageRect.center;

    nowMs = 1600;
    await tester.pump();
    await tester.tapAt(inputPoint);
    await tester.pump();
    expect(find.text('x1'), findsOneWidget);

    nowMs = 1800;
    await tester.pump();
    nowMs = 2700;
    await tester.pump();
    await tester.tapAt(inputPoint);
    await tester.pump();
    expect(find.text('x2'), findsOneWidget);

    nowMs = 2891;
    await tester.pump();
    // Erken-basış tuzağı ×1.2 — DDA hızı taze profilde 0.97 olduğu için
    // (nötr başlangıç: (0−1).clamp(−0.2,0.4)×0.15 = −0.03) pencere
    // 260/0.97 ≈ 268 ms, aralık 1100~/0.97 = 1134 ms olur; vuruşlar
    // 1600 → 2734 → 3868 ms'e oturur. Tuzak bandı delta ∈ [−321.6, −268):
    // 3568 ms'de delta −300 ms → 'ERKEN BASTIN' (pencere dışına 32 ms,
    // tuzak kenarına 21.6 ms pay).
    nowMs = 3568;
    await tester.pump();
    await tester.tapAt(inputPoint);
    await tester.pump();
    expect(find.text('KOMBO BOZULDU · ERKEN BASTIN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Kapanışta bekleyen sistem-yazıtipi çerçeve geri çağrısını
    // temizle: ağaç sökülürken asılı kalan geçici geri çağrı
    // zamanlayıcı istisnasına yol açıyor (HEAD'de de görülüyor).
    // Gerçek zamanlı bekleme motorun geç gelen yazıtipi bildirimini
    // ağaç sökülmeden önce teslim etmesini sağlar.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
