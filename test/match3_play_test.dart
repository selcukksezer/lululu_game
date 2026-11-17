import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lululu_game/modes/match3_screen.dart';

void main() {
  testWidgets('match3: swipes resolve without errors', (tester) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: Match3Screen()));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 20; i++) {
      final y = 230.0 + (i % 6) * 34;
      await tester.dragFrom(Offset(70.0 + (i % 5) * 34, y), const Offset(34, 0));
      for (var f = 0; f < 80; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    expect(tester.takeException(), isNull);
    debugPrint('HAMLE visible: ${find.text('HAMLE').evaluate().length}, SKOR: ${find.text('SKOR').evaluate().length}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
