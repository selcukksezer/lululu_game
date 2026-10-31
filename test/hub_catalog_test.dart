import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/lululu_game_mode.dart';
import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('hub lists every catalog mode title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLululuTheme(),
        home: const Scaffold(body: GameSelectorScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    for (final mode in LululuGameMode.catalog) {
      // Featured banner uppercases title; grid uses catalog title as-is.
      final candidates = <Finder>[
        find.text(mode.title),
        find.text(mode.title.toUpperCase()),
      ];
      var found = false;
      for (var i = 0; i < 14 && !found; i++) {
        for (final f in candidates) {
          if (f.evaluate().isNotEmpty) {
            found = true;
            break;
          }
        }
        if (found) break;
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -280));
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(
        found,
        isTrue,
        reason: 'missing hub title for ${mode.kind.name}: ${mode.title}',
      );
    }

    // flutter_animate leaves timers — tear down tree so binding stays clean.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
