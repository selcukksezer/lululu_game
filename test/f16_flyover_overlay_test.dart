import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/widgets/bonus_fx.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSteps(
    WidgetTester tester, {
    int count = 10,
    Duration step = const Duration(milliseconds: 100),
  }) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(step);
    }
  }

  group('12S F16 flyover katmani (prototip v4)', () {
    testWidgets('jet belirir, ucar, 3 bomba birakir, katman kalkar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(debugResetF16FlyoverGuard);

      await tester.pumpWidget(
        wrapWithL10n(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => playF16Flyover(context),
                child: const Text('UC'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('f16-flyover-jet')), findsNothing);

      await tester.tap(find.text('UC'));
      await tester.pump();
      expect(find.byKey(const Key('f16-flyover-jet')), findsOneWidget);

      final atStart =
          tester.getTopLeft(find.byKey(const Key('f16-flyover-jet')));
      await tester.pump(const Duration(milliseconds: 750));
      final atMid =
          tester.getTopLeft(find.byKey(const Key('f16-flyover-jet')));
      expect(atMid.dx, greaterThan(atStart.dx));
      expect(find.byKey(const Key('f16-flyover-jet')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('f16-flyover-bomb-0')), findsOneWidget);
      expect(find.byKey(const Key('f16-flyover-bomb-1')), findsOneWidget);
      expect(find.byKey(const Key('f16-flyover-bomb-2')), findsOneWidget);

      await pumpSteps(tester, count: 12);
      expect(find.byKey(const Key('f16-flyover-jet')), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('cift cagri tek ucus acar (f16Busy korumasi)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(debugResetF16FlyoverGuard);

      late BuildContext captured;
      await tester.pumpWidget(
        wrapWithL10n(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      unawaited(playF16Flyover(captured));
      unawaited(playF16Flyover(captured));
      await tester.pump();
      expect(find.byKey(const Key('f16-flyover-jet')), findsOneWidget);
      expect(find.byKey(const Key('f16-flyover')), findsOneWidget);

      await pumpSteps(tester, count: 20);
      expect(find.byKey(const Key('f16-flyover-jet')), findsNothing);

      // Koruma kalkti: yeni cagri yeniden acar (beklenmez — sahte
      // zaman yalniz pompalamayla ilerler).
      unawaited(playF16Flyover(captured));
      await tester.pump();
      expect(find.byKey(const Key('f16-flyover-jet')), findsOneWidget);
      await pumpSteps(tester, count: 20);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
