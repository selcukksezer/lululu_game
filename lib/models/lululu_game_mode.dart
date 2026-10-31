import 'package:flutter/material.dart';

import '../theme/lululu_theme.dart';

enum GameModeKind {
  suika,
  grid2048,
  balloon,
  match3,
  connect,
  stack,
  osmantus,
  screamRoach,
  makarayiz,
  terlikTap,
}

class LululuGameMode {
  const LululuGameMode({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.stickerAsset,
    required this.accent,
    this.badge,
    this.featured = false,
  });

  final GameModeKind kind;
  final String title;
  final String subtitle;
  final String stickerAsset;
  final Color accent;
  final String? badge;
  final bool featured;

  static const catalog = <LululuGameMode>[
    LululuGameMode(
      kind: GameModeKind.suika,
      title: 'Suika Arena',
      subtitle: 'Aynı böceği bırak, birleşsin. Taşarsa biter.',
      stickerAsset: 'assets/design/bugs_hd/tier6_hd.png',
      accent: LululuColors.cyberFuchsia,
      badge: 'HOT',
      featured: true,
    ),
    LululuGameMode(
      kind: GameModeKind.grid2048,
      title: '2048 Grid',
      subtitle: 'Kaydır. Aynı sayı birleşir. Hedef 2048.',
      stickerAsset: 'assets/design/bugs_hd/tier3_hd.png',
      accent: LululuColors.liquidGold,
    ),
    LululuGameMode(
      kind: GameModeKind.balloon,
      title: 'Balon Patlat',
      subtitle: 'Nişan al. 3 aynı balon patlar, kopan düşer.',
      stickerAsset: 'assets/design/bugs_hd/tier2_hd.png',
      accent: LululuColors.coralFlare,
      badge: 'BONUS',
    ),
    LululuGameMode(
      kind: GameModeKind.match3,
      title: 'Match 3',
      subtitle: 'Komşuyu takas et. 3 yatay ya da dikey patlar.',
      stickerAsset: 'assets/design/bugs_hd/tier4_hd.png',
      accent: LululuColors.toxicNeon,
    ),
    LululuGameMode(
      kind: GameModeKind.connect,
      title: 'Bağla Patlat',
      subtitle: 'Aynı böceği çiz. Kare, o türün hepsini siler.',
      stickerAsset: 'assets/design/bugs_hd/tier5_hd.png',
      accent: LululuColors.warningSolar,
    ),
    LululuGameMode(
      kind: GameModeKind.stack,
      title: 'Stack Drop',
      subtitle: 'Dilim bırak. Üst üste gelsin, kenar kesilir.',
      stickerAsset: 'assets/design/bugs_hd/tier7_hd.png',
      accent: LululuColors.mysticRuby,
      badge: 'KULE',
    ),
    LululuGameMode(
      kind: GameModeKind.terlikTap,
      title: 'Terlik Tap',
      subtitle: 'Uçan böceği ez. Combo büyüsün — günlük seed.',
      stickerAsset: 'assets/design/bugs_hd/tier1_hd.png',
      accent: LululuColors.coralFlare,
      badge: 'YENİ',
    ),
    LululuGameMode(
      kind: GameModeKind.osmantus,
      title: 'Osmantuş',
      subtitle: 'Videodaki ikili! Yeşil halkada dokun — dıkkış dıkkış.',
      stickerAsset: 'assets/design/osman/osmantus_kisi_a.png',
      accent: LululuColors.warningSolar,
      badge: 'VİRAL',
    ),
    LululuGameMode(
      kind: GameModeKind.screamRoach,
      title: 'Çığlık Böcek',
      subtitle: 'Spam dokun, zıpla, engelleri aş. Scream tarzı.',
      stickerAsset: 'assets/design/bugs_hd/tier2_hd.png',
      accent: LululuColors.toxicNeon,
      badge: 'VİRAL',
    ),
    LululuGameMode(
      kind: GameModeKind.makarayiz,
      title: 'Makarayız',
      subtitle: 'Beat’te kaydır. Doğru şerit = makara.',
      stickerAsset: 'assets/design/bugs_hd/tier3_hd.png',
      accent: LululuColors.coralFlare,
      badge: 'VİRAL',
    ),
  ];

  static LululuGameMode get featuredMode =>
      catalog.firstWhere((m) => m.featured, orElse: () => catalog.first);
}
