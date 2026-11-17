import 'package:flutter/material.dart';

enum InsectTier {
  cone(
    tier: 1,
    name: 'Bebek Huni',
    title: 'Lülülü Bebek',
    rarity: 'Sıradan',
    voiceFile: 'voice_tier1.mp3',
    soundFile: 'tier1_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier1_hd.png',
    stickerAsset: 'assets/images/stickers/sticker_tier1_cone.png',
    hdAsset: 'assets/bugs/tier1_hd.webp',
    radius: 23.0,
    mass: 1.0,
    scoreValue: 10,
    color: Color(0xFFFF6B35),
  ),
  helmet(
    tier: 2,
    name: 'Tencereli Çırak',
    title: 'Kasklı Böcek',
    rarity: 'Seyrek',
    voiceFile: 'voice_tier2.mp3',
    soundFile: 'tier2_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier2_hd.png',
    stickerAsset: 'assets/images/stickers/sticker_tier2_helmet.png',
    hdAsset: 'assets/bugs/tier2_hd.webp',
    radius: 28.0,
    mass: 1.5,
    scoreValue: 25,
    color: Color(0xFF8E9CAE),
  ),
  fan(
    tier: 3,
    name: 'Makaracı Fan',
    title: 'Makarayız Abi',
    rarity: 'Nadir',
    voiceFile: 'voice_tier3.mp3',
    soundFile: 'tier3_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier3_hd.png',
    stickerAsset: 'assets/images/stickers/sticker_tier3_fan.png',
    hdAsset: 'assets/bugs/tier3_hd.webp',
    radius: 33.0,
    mass: 2.2,
    scoreValue: 50,
    color: Color(0xFFE52E2E),
  ),
  dancer(
    tier: 4,
    name: 'Pijamalı Dansçı',
    title: 'Hoppa Gülüm',
    rarity: 'Destansı',
    voiceFile: 'voice_tier4.mp3',
    soundFile: 'tier4_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier4_hd.png',
    stickerAsset: 'assets/images/stickers/sticker_tier4_dancer.png',
    hdAsset: 'assets/bugs/tier4_hd.webp',
    radius: 39.0,
    mass: 3.2,
    scoreValue: 100,
    color: Color(0xFFE01E5A),
  ),
  diva(
    tier: 5,
    name: 'Hamam Diva',
    title: 'Ben Divayım Ayol!',
    rarity: 'Efsanevi',
    voiceFile: 'voice_tier5.mp3',
    soundFile: 'tier5_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier5_hd.png',
    stickerAsset: 'assets/images/stickers/sticker_tier5_diva.png',
    hdAsset: 'assets/bugs/tier5_hd.webp',
    radius: 45.0,
    mass: 4.5,
    scoreValue: 200,
    color: Color(0xFFFFD700),
  ),
  can(
    tier: 6,
    name: 'Hamam Can',
    title: 'Sayın Seyirciler',
    rarity: 'Mitik',
    voiceFile: 'voice_tier6.mp3',
    soundFile: 'tier6_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier6_hd.png',
    stickerAsset: 'assets/images/stickers/sticker_tier6_can.png',
    hdAsset: 'assets/bugs/tier6_hd.webp',
    radius: 51.0,
    mass: 6.0,
    scoreValue: 400,
    color: Color(0xFF00FF66),
  ),
  kongo(
    tier: 7,
    name: 'Kongo Lideri',
    title: 'Kurban Olduğum',
    rarity: 'Gizli',
    voiceFile: 'voice_tier7.mp3',
    soundFile: 'tier7_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier7_hd.png',
    stickerAsset: 'assets/images/stickers/sticker_tier7_kongo.png',
    hdAsset: 'assets/bugs/tier7_hd.webp',
    radius: 58.0,
    mass: 8.0,
    scoreValue: 800,
    color: Color(0xFFFFB800),
  ),
  bed(
    tier: 8,
    name: 'Hasta Bilge',
    title: 'Dukturu Arayın!',
    rarity: 'Evrim Kristali',
    voiceFile: 'voice_tier8.mp3',
    soundFile: 'tier8_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier8_hd.png',
    stickerAsset: 'assets/images/stickers/sticker_tier8_bed.png',
    hdAsset: 'assets/bugs/tier8_hd.webp',
    radius: 65.0,
    mass: 11.0,
    scoreValue: 1600,
    color: Color(0xFFFFD700),
  ),
  milli(
    tier: 9,
    name: 'Millî Formalı',
    title: 'Forvet Böcek',
    rarity: 'Süper',
    voiceFile: 'voice_tier9.mp3',
    soundFile: 'tier9_ses.mp3',
    assetPath: 'assets/design/bugs_new/tier9_hd.png',
    stickerAsset: 'assets/bugs/tier9_hd.webp',
    hdAsset: 'assets/bugs/tier9_hd.webp',
    radius: 70.0,
    mass: 13.0,
    scoreValue: 3200,
    color: Color(0xFFE52E2E),
  ),
  pinkJacket(
    tier: 10,
    name: 'Pembe Ceketli',
    title: 'Tarzımsın!',
    rarity: 'Ultra',
    voiceFile: 'voice_tier10.mp3',
    soundFile: 'tier10_ses.mp3',
    assetPath: 'assets/design/bugs_new/tier10_hd.png',
    stickerAsset: 'assets/bugs/tier10_hd.webp',
    hdAsset: 'assets/bugs/tier10_hd.webp',
    radius: 75.0,
    mass: 15.0,
    scoreValue: 6400,
    color: Color(0xFFE01E5A),
  ),
  whiteGhost(
    tier: 11,
    name: 'Beyaz Hayalet',
    title: 'Görünmez Şövalye',
    rarity: 'Kozmik',
    voiceFile: 'voice_tier11.mp3',
    soundFile: 'tier11_ses.mp3',
    assetPath: 'assets/design/bugs_new/tier11_hd.png',
    stickerAsset: 'assets/bugs/tier11_hd.webp',
    hdAsset: 'assets/bugs/tier11_hd.webp',
    radius: 80.0,
    mass: 17.5,
    scoreValue: 12800,
    color: Color(0xFFEDF1F8),
  ),
  greyShirt(
    tier: 12,
    name: 'Gri Tişörtlü',
    title: 'Sakin Güç',
    rarity: 'Kadim',
    voiceFile: 'voice_tier12.mp3',
    soundFile: 'tier12_ses.mp3',
    assetPath: 'assets/design/bugs_new/tier12_hd.png',
    stickerAsset: 'assets/bugs/tier12_hd.webp',
    hdAsset: 'assets/bugs/tier12_hd.webp',
    radius: 85.0,
    mass: 20.0,
    scoreValue: 25600,
    color: Color(0xFF8E9CAE),
  ),
  pinkRobe(
    tier: 13,
    name: 'Pembe Bornozlu',
    title: 'Evrimin Zirvesi',
    rarity: 'Mutlak',
    voiceFile: 'voice_tier13.mp3',
    soundFile: 'tier13_ses.mp3',
    assetPath: 'assets/design/bugs_new/tier13_hd.png',
    stickerAsset: 'assets/bugs/tier13_hd.webp',
    hdAsset: 'assets/bugs/tier13_hd.webp',
    radius: 90.0,
    mass: 24.0,
    scoreValue: 51200,
    color: Color(0xFFFFDFF2),
  );

  final int tier;
  final String name;
  final String title;
  final String rarity;
  final String voiceFile;
  final String soundFile;
  final String assetPath;
  final String stickerAsset;
  final String hdAsset;
  final double radius;
  final double mass;
  final int scoreValue;
  final Color color;

  const InsectTier({
    required this.tier,
    required this.name,
    required this.title,
    required this.rarity,
    required this.voiceFile,
    required this.soundFile,
    required this.assetPath,
    required this.stickerAsset,
    required this.hdAsset,
    required this.radius,
    required this.mass,
    required this.scoreValue,
    required this.color,
  });

  /// Prototype design sound filename (`tier1_ses.mp3`..`tier13_ses.mp3`).
  String get sesFile => soundFile;

  /// Full verified sound asset path under `assets/design/sounds/`.
  String get soundAssetPath => 'assets/design/sounds/$soundFile';

  /// Merge points alias for UI/HUD consumers.
  int get mergePoints => scoreValue;

  /// Primary 8 prototype evolution tiers (Bebek Huni .. Hasta Bilge).
  static List<InsectTier> get coreTiers => values.take(8).toList(growable: false);

  /// Safe lookup by 1-based tier number (clamped to 1..13).
  static InsectTier fromTier(int tierNumber) {
    final idx = (tierNumber - 1).clamp(0, values.length - 1);
    return values[idx];
  }

  String get viralReplik {
    switch (this) {
      case InsectTier.cone:
        return 'Lülülü bebek!';
      case InsectTier.helmet:
        return 'Vurma kafama usta!';
      case InsectTier.fan:
        return 'Makarayız abi!';
      case InsectTier.dancer:
        return 'Hoppa oyna gülüm!';
      case InsectTier.diva:
        return 'Ben divayım ayol! Divalar yemek yapmaz!';
      case InsectTier.can:
        return 'Sayın seyirciler flaş flaş!';
      case InsectTier.kongo:
        return 'Kurban olduğum Kongo istilası!';
      case InsectTier.bed:
        return 'Dukturu arayın ölüyorum lülülü!';
      case InsectTier.milli:
        return 'Sahaya çıktık!';
      case InsectTier.pinkJacket:
        return 'Tarzımsın!';
      case InsectTier.whiteGhost:
        return 'Görünmezim!';
      case InsectTier.greyShirt:
        return 'Rahatına bak!';
      case InsectTier.pinkRobe:
        return 'Zirvedeyim!';
    }
  }

  InsectTier? get nextTier {
    final nextIdx = index + 1;
    if (nextIdx < InsectTier.values.length) {
      return InsectTier.values[nextIdx];
    }
    return null;
  }
}
