import 'package:flutter/material.dart';

import '../widgets/dot_scaffold.dart';
import '../widgets/home/lululu_dock_bar.dart';
import '../widgets/shop_dialog.dart';
import 'auth_screen.dart';
import 'campaign_map_screen.dart';
import 'chat_screen.dart';
import 'game_selector_screen.dart';
import 'leaderboard_screen.dart';

/// Root shell: Vault home + sıralama + sohbet + harita + dükkan.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  LululuDockTab _dock = LululuDockTab.home;

  @override
  void initState() {
    super.initState();
    _dock = LululuDockTab.home;
  }

  void _onDockSelect(LululuDockTab tab) {
    setState(() => _dock = tab);
  }

  void openMapTab() => setState(() => _dock = LululuDockTab.map);
  void openBoardTab() => setState(() => _dock = LululuDockTab.board);
  void openChatTab() => setState(() => _dock = LululuDockTab.chat);
  void openShopTab() => setState(() => _dock = LululuDockTab.shop);
  void openAuth() => AuthScreen.open(context);

  bool get _lightHome => _dock == LululuDockTab.home;

  @override
  Widget build(BuildContext context) {
    return DotScaffold(
      light: _lightHome,
      safeArea: _dock != LululuDockTab.map,
      body: IndexedStack(
        index: _stackIndex(_dock),
        children: [
          GameSelectorScreen(
            onOpenMap: openMapTab,
            onOpenBoard: openBoardTab,
            onOpenChat: openChatTab,
            onOpenShop: openShopTab,
            onOpenAuth: openAuth,
          ),
          const LeaderboardScreen(embedded: true),
          const ChatScreen(embedded: true),
          const CampaignMapScreen(),
          const ShopScreen(),
        ],
      ),
      bottomNavigationBar: LululuDockBar(
        selected: _dock,
        onSelect: _onDockSelect,
        light: _lightHome,
      ),
    );
  }

  int _stackIndex(LululuDockTab tab) {
    return switch (tab) {
      LululuDockTab.home => 0,
      LululuDockTab.board => 1,
      LululuDockTab.chat => 2,
      LululuDockTab.map => 3,
      LululuDockTab.shop => 4,
    };
  }
}
