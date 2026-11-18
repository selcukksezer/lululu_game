import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/widgets/arcade_chrome.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('Bağla Patlat draws and scores a chain', (tester) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpWithL10n(
      tester,
      const ConnectPopScreen(gameplayTestState: true),
    );
    await tester.pump();

    final board = tester.getRect(
      find.byKey(const ValueKey('connect-pop-board')),
    );
    const gap = 5.0;
    final cell = (board.width - gap * 5) / 6;
    final stride = cell + gap;
    Offset centerOf(int row, int column) => Offset(
      board.left + column * stride + cell / 2,
      board.top + row * stride + cell / 2,
    );
    final gesture = await tester.startGesture(centerOf(1, 1));
    var previous = centerOf(1, 1);
    for (final point in const [(1, 2), (2, 2), (2, 3), (3, 3)]) {
      final next = centerOf(point.$1, point.$2);
      await gesture.moveTo(Offset.lerp(previous, next, 0.5)!);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(next);
      await tester.pump(const Duration(milliseconds: 16));
      previous = next;
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 150));

    expect(
      tester.widgetList<ArcadeStat>(find.byType(ArcadeStat)).first.value,
      '744',
    );
    expect(find.text('+744 X1'), findsOneWidget);
    expect(find.text('ZİNCİR X1 · +744'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
