import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_tr.dart';
import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('hub lists every featured mode title', (tester) async {
    await tester.pumpWidget(
      wrapWithL10n(
        const Scaffold(body: GameSelectorScreen()),
        theme: buildLululuTheme(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 3H: hub, katalogdaki 11 modun tamamını listelemez — ızgarada
    // YALNIZCA 4 öne çıkan mod vardır (hero + 2x2 ızgara, piksel
    // prototipine uygun). Eski beklenti ("her katalog başlığı")
    // bayattı: 7 mod başlığı (Bağla Patlat, Stack Drop, Terlik Tap,
    // Yuva Savunması, Osmantuş, Çığlık Böcek, Makarayız) hub'da hiç
    // görünmez (sondaj kanıtı: 2026-11-18 hub metin dökümü) ve TR
    // başlıklar (`SUİKA ARENA`, `2048 GRİD`) katalog başlıklarının
    // ASCII büyük harf hâliyle (`SUIKA ARENA`, `2048 GRID`)
    // eşleşmez. Beklenti, ızgaranın kullandığı l10n başlıklarına
    // (TR harness) dayandırıldı; kaydırarak bulma mekaniği ve
    // katılık aynen korundu (gevşetme yok).
    final l10n = AppLocalizationsTr();
    final featuredTitles = <String>[
      l10n.suikaArenaTitle,
      l10n.grid2048Title,
      l10n.balloonPopTitle,
      l10n.match3Title,
    ];
    for (final title in featuredTitles) {
      var found = false;
      for (var i = 0; i < 14 && !found; i++) {
        if (find.text(title).evaluate().isNotEmpty) {
          found = true;
          break;
        }
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -280));
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(
        found,
        isTrue,
        reason: 'missing hub title: $title',
      );
    }

    // flutter_animate leaves timers — tear down tree so binding stays clean.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
