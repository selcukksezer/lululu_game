import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/widgets/arcade_chrome.dart';

/// ArcadeStat etiketine göre görüntülenen sayısal değeri okur
/// (binlik ayracı '.' kaldırılır).
int _statValue(WidgetTester tester, String label) {
  final stats = find
      .byType(ArcadeStat)
      .evaluate()
      .map((e) => e.widget as ArcadeStat)
      .where((s) => s.label == label)
      .toList();
  expect(stats, isNotEmpty, reason: 'ArcadeStat "$label" bulunamadı');
  return int.parse(stats.first.value.replaceAll('.', ''));
}

void main() {
  testWidgets('balloon pop: shots fire, score increases, game stays stable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: BalloonPopScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    // Madde 100: başlangıç durumu — skor 0.
    expect(find.text('SKOR'), findsOneWidget);
    expect(_statValue(tester, 'SKOR'), 0);

    for (var i = 0; i < 30; i++) {
      await tester.tapAt(Offset(40.0 + (i * 37) % 300, 300));
      for (var f = 0; f < 60; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // 30 atıştan sonra skor artmış olmalı: atışlar tahtaya yapışır ve
    // 3+ aynı renk patlar. Skor 0 kalırsa atış/patlama akışı bozuktur.
    expect(_statValue(tester, 'SKOR'), greaterThan(0));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
