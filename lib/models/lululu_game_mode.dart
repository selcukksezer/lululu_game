import 'package:flutter/material.dart';
import '../navigation/game_routes.dart';

/// Master enum of the 11 playable LÜLÜLÜ arcade game modes.
enum LululuGameModeId {
  suikaArena,
  grid2048,
  bubblePop,
  match3,
  connectBlast,
  stackDrop,
  terlikTap,
  yuvaDefense,
  osmantus,
  screamBug,
  makarayiz,
}

/// Complete metadata for each of the 11 LÜLÜLÜ arcade modes.
class LululuGameMode {
  final LululuGameModeId id;
  final int index;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color thumbBgColor;
  final Color accentColor;
  final Color cardDarkColor;
  final String stickerAsset;
  final String badgeIconAsset;
  final String mechanicSummary;
  final String bestScoreKey;
  final int defaultBestScore;
  final bool isHot;

  const LululuGameMode({
    required this.id,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    this.badgeTextColor = const Color(0xFFFFFFFF),
    this.thumbBgColor = const Color(0xFFFFE9C9),
    required this.accentColor,
    required this.cardDarkColor,
    required this.stickerAsset,
    required this.badgeIconAsset,
    required this.mechanicSummary,
    required this.bestScoreKey,
    this.defaultBestScore = 0,
    this.isHot = false,
  });

  /// Legacy compatibility getters for GameSelectorScreen & other callers.
  GameModeKind get kind => LululuRoutes.fromModeId(id);
  Color get accent => accentColor;
  String? get badge => badgeLabel;

  // --- English (EN) counterparts: pure additions, TR defaults untouched. ---
  // Screens migrate to the `*For(Locale)` accessors in a later wave; the
  // existing `title`/`subtitle`/`badgeLabel`/`mechanicSummary` fields keep
  // returning Turkish. Proper names (Osmantuş, Makarayız) and
  // already-English titles stay identical in EN. No AppLocalizations import:
  // these are pure `Locale`-parameterized accessors, so no import cycle.
  String get titleEn {
    switch (id) {
      case LululuGameModeId.suikaArena:
        return 'Suika Arena';
      case LululuGameModeId.grid2048:
        return '2048 Grid';
      case LululuGameModeId.bubblePop:
        return 'Balloon Pop';
      case LululuGameModeId.match3:
        return 'Match 3';
      case LululuGameModeId.connectBlast:
        return 'Connect Blast';
      case LululuGameModeId.stackDrop:
        return 'Stack Drop';
      case LululuGameModeId.terlikTap:
        return 'Terlik Tap';
      case LululuGameModeId.yuvaDefense:
        return 'Nest Defense';
      case LululuGameModeId.osmantus:
        return 'Osmantuş';
      case LululuGameModeId.screamBug:
        return 'Scream Bug';
      case LululuGameModeId.makarayiz:
        return 'Makarayız';
    }
  }

  String titleFor(Locale locale) =>
      locale.languageCode == 'en' ? titleEn : title;

  String get subtitleEn {
    switch (id) {
      case LululuGameModeId.suikaArena:
        return 'The classic merge game';
      case LululuGameModeId.grid2048:
        return 'Slide, merge, reach 2048';
      case LululuGameModeId.bubblePop:
        return 'Aim and pop 3 matching balloons';
      case LululuGameModeId.match3:
        return 'Swap a neighbor, blast rows of 3';
      case LululuGameModeId.connectBlast:
        return 'Draw chains of the same bug and blast them';
      case LululuGameModeId.stackDrop:
        return 'Stack the tower without clipping the edge';
      case LululuGameModeId.terlikTap:
        return 'Slap what pops out of the holes with a slipper';
      case LululuGameModeId.yuvaDefense:
        return 'Slap anything reaching the nest with a slipper';
      case LululuGameModeId.osmantus:
        return 'Hit the double tap in the green ring!';
      case LululuGameModeId.screamBug:
        return 'Shout to fly through the gates without getting squashed';
      case LululuGameModeId.makarayiz:
        return 'Swipe on the beat, wind the reel';
    }
  }

  String subtitleFor(Locale locale) =>
      locale.languageCode == 'en' ? subtitleEn : subtitle;

  String get badgeLabelEn {
    switch (id) {
      case LululuGameModeId.suikaArena:
        return 'HOT';
      case LululuGameModeId.grid2048:
        return '2048';
      case LululuGameModeId.bubblePop:
        return 'BONUS';
      case LululuGameModeId.match3:
        return 'NEON';
      case LululuGameModeId.connectBlast:
        return 'CHAIN';
      case LululuGameModeId.stackDrop:
        return 'TOWER';
      case LululuGameModeId.terlikTap:
        return 'NEW';
      case LululuGameModeId.yuvaDefense:
        return 'NEW';
      case LululuGameModeId.osmantus:
        return 'VIRAL';
      case LululuGameModeId.screamBug:
        return 'VIRAL';
      case LululuGameModeId.makarayiz:
        return 'VIRAL';
    }
  }

  String badgeLabelFor(Locale locale) =>
      locale.languageCode == 'en' ? badgeLabelEn : badgeLabel;

  String get mechanicSummaryEn {
    switch (id) {
      case LululuGameModeId.suikaArena:
        return 'Drop bugs into the jar and bump matching levels together to reach the King Bug!';
      case LululuGameModeId.grid2048:
        return 'Slide the 4x4 board in 4 directions! Matching bugs evolve to the next level.';
      case LululuGameModeId.bubblePop:
        return 'Aim from below, hit at least 3 balloons with the same bug, and drop them!';
      case LululuGameModeId.match3:
        return 'Swap neighboring bugs and blast horizontal or vertical rows of 3!';
      case LululuGameModeId.connectBlast:
        return 'Draw long chains between neighboring matching bugs without lifting your finger!';
      case LululuGameModeId.stackDrop:
        return 'Drop the swaying bug blocks exactly on top of each other and raise the tower without toppling it!';
      case LululuGameModeId.terlikTap:
        return 'Slap the bugs popping out of the holes with a slipper, and never touch the bombs!';
      case LululuGameModeId.yuvaDefense:
        return 'Stop the bugs running toward the kitchen counter through 4 lanes with your slipper and protect the cake!';
      case LululuGameModeId.osmantus:
        return 'Catch the shrinking timing ring exactly on the green line and hit the Osman button!';
      case LululuGameModeId.screamBug:
        return 'Fly the bug by shouting into the microphone or holding down, and never hit the pipes!';
      case LululuGameModeId.makarayiz:
        return 'Catch the rhythm notes on the line and spin the reel to multiply your combo!';
    }
  }

  String mechanicSummaryFor(Locale locale) =>
      locale.languageCode == 'en' ? mechanicSummaryEn : mechanicSummary;

  /// Canonical catalog of all 11 modes in prototype order (`LÜLÜLÜ UI:UX Tasarım.html` L2841-2853).
  static const List<LululuGameMode> catalog = [
    LululuGameMode(
      id: LululuGameModeId.suikaArena,
      index: 1,
      title: 'Suika Arena',
      subtitle: 'Birleştirme klasiği',
      badgeLabel: 'HOT',
      badgeColor: Color(0xFFE01E5A),
      badgeTextColor: Color(0xFFFFFFFF),
      thumbBgColor: Color(0xFFFFE9C9),
      accentColor: Color(0xFFFFB800),
      cardDarkColor: Color(0xFF2B1B0E),
      stickerAsset: 'assets/bugs/tier1_hd.png',
      badgeIconAsset: 'assets/icons2/target.png',
      mechanicSummary:
          'Böcekleri kavanoza bırak, aynı seviyeleri çarpıştırarak Kral Böceğe ulaş!',
      bestScoreKey: 'suika',
      defaultBestScore: 4820,
      isHot: true,
    ),
    LululuGameMode(
      id: LululuGameModeId.grid2048,
      index: 2,
      title: '2048 Grid',
      subtitle: 'Kaydır, birleştir, 2048 yap',
      badgeLabel: '2048',
      badgeColor: Color(0xFFFFB800),
      badgeTextColor: Color(0xFF4A2E00),
      thumbBgColor: Color(0xFFFFF0D6),
      accentColor: Color(0xFF00E5FF),
      cardDarkColor: Color(0xFF102536),
      stickerAsset: 'assets/bugs/tier2_hd.png',
      badgeIconAsset: 'assets/icons/level_up.png',
      mechanicSummary:
          '4x4 tahtayı 4 yöne kaydır! Eşleşen böcekler bir üst seviyeye evrimleşir.',
      bestScoreKey: 'grid_2048',
      defaultBestScore: 12480,
    ),
    LululuGameMode(
      id: LululuGameModeId.bubblePop,
      index: 3,
      title: 'Balon Patlat',
      subtitle: 'Nişan al, 3 aynı balonu patlat',
      badgeLabel: 'BONUS',
      badgeColor: Color(0xFFFF6B35),
      badgeTextColor: Color(0xFFFFFFFF),
      thumbBgColor: Color(0xFFFFE3D6),
      accentColor: Color(0xFFFF4081),
      cardDarkColor: Color(0xFF2D122B),
      stickerAsset: 'assets/bugs/tier1_hd.png',
      badgeIconAsset: 'assets/icons2/boom.png',
      mechanicSummary:
          'Aşağıdan nişan al, aynı böcek balonundan en az 3 tanesini vur ve düşür!',
      bestScoreKey: 'balloon_pop',
      defaultBestScore: 3260,
    ),
    LululuGameMode(
      id: LululuGameModeId.match3,
      index: 4,
      title: 'Match 3',
      subtitle: "Komşuyu kaydır, 3'lü patlat",
      badgeLabel: 'NEON',
      badgeColor: Color(0xFF00C853),
      badgeTextColor: Color(0xFF04140A),
      thumbBgColor: Color(0xFFDFF7EA),
      accentColor: Color(0xFF69F0AE),
      cardDarkColor: Color(0xFF0E291E),
      stickerAsset: 'assets/bugs/tier5_hd.webp',
      badgeIconAsset: 'assets/icons2/gem_blue.png',
      mechanicSummary:
          "Komşu böcekleri yer değiştir, yatay veya dikey 3'lü dizileri patlat!",
      bestScoreKey: 'match3',
      defaultBestScore: 5940,
    ),
    LululuGameMode(
      id: LululuGameModeId.connectBlast,
      index: 5,
      title: 'Bağla Patlat',
      subtitle: 'Aynı böceği çiz, zinciri patlat',
      badgeLabel: 'ZİNCİR',
      badgeColor: Color(0xFFFFD700),
      badgeTextColor: Color(0xFF4A2E00),
      thumbBgColor: Color(0xFFFFF6D8),
      accentColor: Color(0xFFCE93D8),
      cardDarkColor: Color(0xFF211332),
      stickerAsset: 'assets/bugs/tier3_hd.png',
      badgeIconAsset: 'assets/icons2/magnet.png',
      mechanicSummary:
          'Parmağını kaldırmadan komşu aynı böcekler arasında uzun zincirler çiz!',
      bestScoreKey: 'connect_pop',
      defaultBestScore: 2870,
    ),
    LululuGameMode(
      id: LululuGameModeId.stackDrop,
      index: 6,
      title: 'Stack Drop',
      subtitle: 'Kuleyi diz, kenarı kesme',
      badgeLabel: 'KULE',
      badgeColor: Color(0xFFE52E2E),
      badgeTextColor: Color(0xFFFFFFFF),
      thumbBgColor: Color(0xFFFFE0E0),
      accentColor: Color(0xFFFFAB40),
      cardDarkColor: Color(0xFF2B1911),
      stickerAsset: 'assets/bugs/tier6_hd.png',
      badgeIconAsset: 'assets/icons2/block.png',
      mechanicSummary:
          'Sallanan böcek bloklarını tam üst üste bırak, gökdeleni devirmeden yüksel!',
      bestScoreKey: 'stack_drop',
      defaultBestScore: 1540,
    ),
    LululuGameMode(
      id: LululuGameModeId.terlikTap,
      index: 7,
      title: 'Terlik Tap',
      subtitle: 'Delikten çıkanı terlikle ez',
      badgeLabel: 'YENİ',
      badgeColor: Color(0xFFFF6B35),
      badgeTextColor: Color(0xFFFFFFFF),
      thumbBgColor: Color(0xFFFFE3D6),
      accentColor: Color(0xFFFF5252),
      cardDarkColor: Color(0xFF331114),
      stickerAsset: 'assets/powerup_terlik.png',
      badgeIconAsset: 'assets/icons2/boot.png',
      mechanicSummary:
          'Deliklerden fırlayan böceklere anne terliğiyle şaplak indir, bombalara dokunma!',
      bestScoreKey: 'terlik_tap',
      defaultBestScore: 1150,
      isHot: true,
    ),
    LululuGameMode(
      id: LululuGameModeId.yuvaDefense,
      index: 8,
      title: 'Yuva Savunması',
      subtitle: 'Yuvaya ulaşanı terlikle ez',
      badgeLabel: 'YENİ',
      badgeColor: Color(0xFFE01E5A),
      badgeTextColor: Color(0xFFFFFFFF),
      thumbBgColor: Color(0xFFFFE3D6),
      accentColor: Color(0xFFFF9100),
      cardDarkColor: Color(0xFF2A180D),
      stickerAsset: 'assets/bugs/tier2_hd.png',
      badgeIconAsset: 'assets/icons2/target.png',
      mechanicSummary:
          '4 koridordan mutfak tezgahına koşan böcekleri terlikle durdur, pastayı koru!',
      bestScoreKey: 'yuva_defense',
      defaultBestScore: 1240,
    ),
    LululuGameMode(
      id: LululuGameModeId.osmantus,
      index: 9,
      title: 'Osmantuş',
      subtitle: 'Yeşil halkada ikili tuş!',
      badgeLabel: 'VİRAL',
      badgeColor: Color(0xFFFFD700),
      badgeTextColor: Color(0xFF4A2E00),
      thumbBgColor: Color(0xFFFFF6D8),
      accentColor: Color(0xFFFFD740),
      cardDarkColor: Color(0xFF281F0C),
      stickerAsset: 'assets/osman/osmantus_kisi_a.png',
      badgeIconAsset: 'assets/icons2/crown.png',
      mechanicSummary:
          'Daralan zamanlama halkasını tam yeşil çizgide yakala, Osman Tuşu indir!',
      bestScoreKey: 'osmantus',
      defaultBestScore: 980,
      isHot: true,
    ),
    LululuGameMode(
      id: LululuGameModeId.screamBug,
      index: 10,
      title: 'Çığlık Böcek',
      subtitle: 'Bağır, kapılardan geç, ezilme',
      badgeLabel: 'VİRAL',
      badgeColor: Color(0xFF00C853),
      badgeTextColor: Color(0xFF04140A),
      thumbBgColor: Color(0xFFE4F0FF),
      accentColor: Color(0xFF40C4FF),
      cardDarkColor: Color(0xFF0D2233),
      stickerAsset: 'assets/bugs/tier7_hd.png',
      badgeIconAsset: 'assets/icons2/bolt.png',
      mechanicSummary:
          'Mikrofona bağırarak veya basılı tutarak böceği uçur, borulara çarpma!',
      bestScoreKey: 'scream_roach',
      defaultBestScore: 2105,
      isHot: true,
    ),
    LululuGameMode(
      id: LululuGameModeId.makarayiz,
      index: 11,
      title: 'Makarayız',
      subtitle: "Beat'te kaydır, makarayı sar",
      badgeLabel: 'VİRAL',
      badgeColor: Color(0xFFFF6B35),
      badgeTextColor: Color(0xFFFFFFFF),
      thumbBgColor: Color(0xFFFFE0EC),
      accentColor: Color(0xFFE040FB),
      cardDarkColor: Color(0xFF290F30),
      stickerAsset: 'assets/bugs/tier3_hd.png',
      badgeIconAsset: 'assets/icons2/wheel.png',
      mechanicSummary:
          'Ritim notalarını çizgide yakala, makarayı döndürerek kombo çarpanını katla!',
      bestScoreKey: 'makarayiz',
      defaultBestScore: 1760,
    ),
  ];

  static LululuGameMode byId(LululuGameModeId id) {
    return catalog.firstWhere((m) => m.id == id, orElse: () => catalog.first);
  }
}
