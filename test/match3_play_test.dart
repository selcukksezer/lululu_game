import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lululu_game/modes/match3_screen.dart';

import 'test_helpers.dart';

/// HUD istatistik kutusundaki sayısal değeri etiketine göre okur
/// (binlik ayracı '.' kaldırılır).
/// NOT: Match3Screen'in görünür HUD'u _buildHudStatBox'tur (Column içinde
/// Text(etiket) + Text(değer)); dosyadaki ArcadeStat'lar yalnız
/// Offstage(offstage: true) içinde durur ve find.byType varsayılanı
/// (skipOffstage: true) onları görmez — değer, etiketin en yakın Column
/// atasındaki ikinci Text'tir.
int _statValue(WidgetTester tester, String label) {
  final labelFinder = find.text(label);
  expect(labelFinder, findsOneWidget, reason: 'Etiket "$label" bulunamadı');
  final columnFinder = find.ancestor(
    of: labelFinder,
    matching: find.byType(Column),
  );
  final texts = find
      .descendant(of: columnFinder.first, matching: find.byType(Text))
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .toList();
  expect(texts, hasLength(2), reason: 'HUD kutusu "$label" + değer olmalı');
  return int.parse(texts.last.replaceAll('.', ''));
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
    await tester.pumpWidget(wrapWithL10n(const Match3Screen()));
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
