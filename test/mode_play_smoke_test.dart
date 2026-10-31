import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

/// Sequential mount smoke for every arcade + viral mini.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> playMount(
    WidgetTester tester,
    Widget home,
    String title,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildLululuTheme(), home: home),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull, reason: '$title threw');
    expect(find.text(title), findsOneWidget, reason: '$title title missing');
    // Soft interaction: tap center if possible.
    final size = tester.getSize(find.byType(MaterialApp));
    await tester.tapAt(Offset(size.width / 2, size.height * 0.55));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull, reason: '$title after tap');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('play all modes in catalog order', (tester) async {
    await playMount(
      tester,
      GameScreen(level: CampaignDatabase.kitchenLevel1, arcade: true),
      'Suika Arena',
    );
    await playMount(tester, const Grid2048Screen(), '2048 Grid');
    await playMount(tester, const BalloonPopScreen(), 'Balon Patlat');
    await playMount(tester, const Match3Screen(), 'Match 3');
    await playMount(tester, const ConnectPopScreen(), 'Bağla Patlat');
    await playMount(tester, const StackDropScreen(), 'Stack Drop');
    await playMount(tester, const OsmantusScreen(), 'Osmantuş');
    await playMount(tester, const ScreamRoachScreen(), 'Çığlık Böcek');
    await playMount(tester, const MakarayizScreen(), 'Makarayız');
    await playMount(tester, const TerlikTapScreen(), 'Terlik Tap');
  });
}
