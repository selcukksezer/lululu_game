import 'package:flutter/material.dart';

import '../theme/lululu_theme.dart';
import '../widgets/home/lululu_dock_bar.dart';
import '../widgets/shop_dialog.dart';
import 'game_selector_screen.dart';
import 'leaderboard_screen.dart';
import 'modes_screen.dart';
import 'tiers_screen.dart';

/// Root shell: 5 sekme — ANA SAYFA / MODLAR / AİLEM / MAĞAZA / SKORLAR.
///
/// Floating dock, Scaffold'un bottomNavigationBar'ı yerine
/// `extendBody: true` + Stack ile içeriğin ÜSTÜNE konur; içerik dock'un
/// altından kayar. ANA SAYFA açık tema (paper), diğer sekmeler koyu.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  LululuDockTab _tab = LululuDockTab.home;

  int get _index => _tab.index;

  bool get _lightHome => _tab == LululuDockTab.home;

  void _select(LululuDockTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor:
          _lightHome ? LululuColors.paper : LululuColors.carbonVoid,
      body: Stack(
        children: [
          // İçerik: dock'un altından kayar.
          IndexedStack(
            index: _index,
            children: const [
              GameSelectorScreen(),
              ModesScreen(),
              TiersScreen(),
              ShopScreen(),
              LeaderboardScreen(embedded: true),
            ],
          ),
          // Floating dock: içeriğin üstünde.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LululuDockBar(
              selected: _tab,
              onSelect: _select,
            ),
          ),
        ],
      ),
    );
  }
}
