import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';

void main() {
  testWidgets('balloon pop: shots fire, game stays stable', (tester) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: BalloonPopScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 30; i++) {
      await tester.tapAt(Offset(40.0 + (i * 37) % 300, 300));
      for (var f = 0; f < 60; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    expect(find.text('SKOR'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
