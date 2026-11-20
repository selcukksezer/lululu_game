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
    expect(OsmantusPacing.intervalMs(45000), lessThan(900));
    expect(OsmantusPacing.windowMs(45000), greaterThan(110));
  });

  test('ring colour eases continuously toward green', () {
    // Yeşil yalnız puan penceresi içinde görünür (faz ≈ 0.82'den
    // itibaren): 0.82'de hâlâ gri, 0.91'de yeşilimsi, 1.0'da tam yeşil.
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
    nowMs = 3500;
    await tester.pump();
    await tester.tapAt(inputPoint);
    await tester.pump();
    expect(find.text('KOMBO BOZULDU · ERKEN BASTIN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
