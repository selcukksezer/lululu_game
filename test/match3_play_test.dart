import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/widgets/arcade_chrome.dart';

/// ArcadeStat etiketine göre görüntülenen sayısal değeri okur
/// (binlik ayracı '.' kaldırılır; aynı etiketten birden fazla varsa
/// hepsi aynı durumu gösterir, ilki okunur).
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
  testWidgets('match3: swipes score, consume moves, resolve without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MaterialApp(home: Match3Screen()));
    await tester.pump(const Duration(milliseconds: 100));

    // Madde 100: başlangıç durumu — skor 0, hamle tam (30; _Match3ScreenState.startMoves).
    expect(_statValue(tester, 'SKOR'), 0);
    expect(_statValue(tester, 'HAMLE'), 30);

    for (var i = 0; i < 20; i++) {
      final y = 230.0 + (i % 6) * 34;
      await tester.dragFrom(Offset(70.0 + (i % 5) * 34, y), const Offset(34, 0));
      for (var f = 0; f < 80; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    // Hamleler tahtayı değiştirmeli: en az bir eşleşme skora yazılır ve
    // hamle tüketir (hamle yalnız eşleşmede azalır). İkisi de değişmediyse
    // kaydırma/eşleşme akışı bozuktur.
    expect(_statValue(tester, 'SKOR'), greaterThan(0));
    expect(_statValue(tester, 'HAMLE'), lessThan(30));
    expect(tester.takeException(), isNull);
    debugPrint(
      'HAMLE visible: ${find.text('HAMLE').evaluate().length}, SKOR: ${find.text('SKOR').evaluate().length}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
