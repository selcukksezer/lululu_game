import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/modes/yuva_defense_screen.dart';
import 'package:lululu_game/navigation/game_routes.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';

// W32-3: `LululuRoutes.buildGameModeWidget` enerji bayrağı bağlantı testi.
// Kaynak: lib/navigation/game_routes.dart — `buildGameModeWidget` 11/11
// mod dalında `energyConsumed` bayrağını geçirir (W22-1 + W30-1); her
// mod ekranı bayrağı `final bool energyConsumed` olarak tutar
// (varsayılan `false`). Bu dosya bağlantının kırılmasını önler: bir
// dal bayrağı geçirmeyi bırakırsa veya yanlış ekran tipine çözülürse
// ilgili test düşer.
//
// PUMP YOK: testler yalnız widget ağacı inşası düzeyindedir.
// `buildGameModeWidget` çağrısı + tip/alan okuma yeterlidir; ekranları
// pump etmek init mantığını (zamanlayıcı, ses, mikrofon) çalıştırır,
// bu testin kapsamı dışındadır. Bu yüzden düz `test` kullanılır,
// `testWidgets` kullanılmaz.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'GameModeKind tam 11 değer içerir (yeni mod eklenirse bu dosya güncellenir)',
      () {
    expect(GameModeKind.values.length, 11);
    expect(
      GameModeKind.values.toSet(),
      {
        GameModeKind.suika,
        GameModeKind.grid2048,
        GameModeKind.balloon,
        GameModeKind.match3,
        GameModeKind.connect,
        GameModeKind.stack,
        GameModeKind.terlikTap,
        GameModeKind.yuvaDefense,
        GameModeKind.osmantus,
        GameModeKind.screamRoach,
        GameModeKind.makarayiz,
      },
    );
  });

  group('buildGameModeWidget energyConsumed: true', () {
    test('suika -> GameScreen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.suika,
        energyConsumed: true,
      );
      expect(widget, isA<GameScreen>());
      expect((widget as GameScreen).energyConsumed, isTrue);
    });

    test('grid2048 -> Grid2048Screen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.grid2048,
        energyConsumed: true,
      );
      expect(widget, isA<Grid2048Screen>());
      expect((widget as Grid2048Screen).energyConsumed, isTrue);
    });

    test('balloon -> BalloonPopScreen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.balloon,
        energyConsumed: true,
      );
      expect(widget, isA<BalloonPopScreen>());
      expect((widget as BalloonPopScreen).energyConsumed, isTrue);
    });

    test('match3 -> Match3Screen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.match3,
        energyConsumed: true,
      );
      expect(widget, isA<Match3Screen>());
      expect((widget as Match3Screen).energyConsumed, isTrue);
    });

    test('connect -> ConnectPopScreen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.connect,
        energyConsumed: true,
      );
      expect(widget, isA<ConnectPopScreen>());
      expect((widget as ConnectPopScreen).energyConsumed, isTrue);
    });

    test('stack -> StackDropScreen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.stack,
        energyConsumed: true,
      );
      expect(widget, isA<StackDropScreen>());
      expect((widget as StackDropScreen).energyConsumed, isTrue);
    });

    test('terlikTap -> TerlikTapScreen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.terlikTap,
        energyConsumed: true,
      );
      expect(widget, isA<TerlikTapScreen>());
      expect((widget as TerlikTapScreen).energyConsumed, isTrue);
    });

    test('yuvaDefense -> YuvaDefenseScreen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.yuvaDefense,
        energyConsumed: true,
      );
      expect(widget, isA<YuvaDefenseScreen>());
      expect((widget as YuvaDefenseScreen).energyConsumed, isTrue);
    });

    test('osmantus -> OsmantusScreen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.osmantus,
        energyConsumed: true,
      );
      expect(widget, isA<OsmantusScreen>());
      expect((widget as OsmantusScreen).energyConsumed, isTrue);
    });

    test('screamRoach -> ScreamRoachScreen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.screamRoach,
        energyConsumed: true,
      );
      expect(widget, isA<ScreamRoachScreen>());
      expect((widget as ScreamRoachScreen).energyConsumed, isTrue);
    });

    test('makarayiz -> MakarayizScreen, energyConsumed true', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.makarayiz,
        energyConsumed: true,
      );
      expect(widget, isA<MakarayizScreen>());
      expect((widget as MakarayizScreen).energyConsumed, isTrue);
    });
  });

  group('buildGameModeWidget energyConsumed varsayılanı (false)', () {
    test('suika: bayrak geçilmezse GameScreen.energyConsumed false', () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.suika,
      );
      expect(widget, isA<GameScreen>());
      expect((widget as GameScreen).energyConsumed, isFalse);
    });

    test('osmantus: bayrak geçilmezse OsmantusScreen.energyConsumed false',
        () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.osmantus,
      );
      expect(widget, isA<OsmantusScreen>());
      expect((widget as OsmantusScreen).energyConsumed, isFalse);
    });

    test(
        'yuvaDefense: bayrak geçilmezse YuvaDefenseScreen.energyConsumed false',
        () {
      final Widget widget = LululuRoutes.buildGameModeWidget(
        GameModeKind.yuvaDefense,
      );
      expect(widget, isA<YuvaDefenseScreen>());
      expect((widget as YuvaDefenseScreen).energyConsumed, isFalse);
    });
  });
}
