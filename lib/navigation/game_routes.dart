import 'package:flutter/material.dart';

import '../models/campaign_level.dart';
import '../models/lululu_game_mode.dart';
import '../modes/balloon_pop_screen.dart';
import '../modes/connect_pop_screen.dart';
import '../modes/match3_screen.dart';
import '../modes/makarayiz_screen.dart';
import '../modes/osmantus_screen.dart';
import '../modes/scream_roach_screen.dart';
import '../modes/stack_drop_screen.dart';
import '../modes/terlik_tap_screen.dart';
import '../screens/game_screen.dart';
import '../screens/grid_2048_screen.dart';
import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../widgets/energy_empty_popup.dart';

/// Stops game SFX/voice when the pushed game route leaves the tree.
class GameAudioGate extends StatefulWidget {
  const GameAudioGate({super.key, required this.child});

  final Widget child;

  @override
  State<GameAudioGate> createState() => _GameAudioGateState();
}

class _GameAudioGateState extends State<GameAudioGate> {
  @override
  void dispose() {
    // Fire-and-forget: route pop must mute immediately even if await races.
    AudioManager().stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> openGameMode(BuildContext context, GameModeKind kind) async {
  // Enerji yoksa oyun açılmasın — popup göster, geri dön.
  final ok = await EnergyService.instance.tryConsume();
  if (!ok) {
    await showEnergyEmptyPopup(context);
    return;
  }

  final child = switch (kind) {
    GameModeKind.suika => GameScreen(
        level: CampaignDatabase.kitchenLevel1,
        arcade: true,
      ),
    GameModeKind.grid2048 => const Grid2048Screen(),
    GameModeKind.balloon => const BalloonPopScreen(),
    GameModeKind.match3 => const Match3Screen(),
    GameModeKind.connect => const ConnectPopScreen(),
    GameModeKind.stack => const StackDropScreen(),
    GameModeKind.osmantus => const OsmantusScreen(),
    GameModeKind.screamRoach => const ScreamRoachScreen(),
    GameModeKind.makarayiz => const MakarayizScreen(),
    GameModeKind.terlikTap => const TerlikTapScreen(),
  };

  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => GameAudioGate(child: child),
      transitionsBuilder: (_, anim, _, page) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: page,
          ),
        );
      },
    ),
  );
}
