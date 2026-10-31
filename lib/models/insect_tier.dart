import 'package:flutter/material.dart';

enum InsectTier {
  cone(
    tier: 1,
    name: 'Bebek Huni',
    title: 'Lülülü Bebek',
    voiceFile: 'design/sounds/tier1_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier1_hd.png',
    radius: 16.0,
    mass: 1.0,
    scoreValue: 10,
    color: Color(0xFFFF6B35),
  ),
  helmet(
    tier: 2,
    name: 'Tencereli Çırak',
    title: 'Kasklı Böcek',
    voiceFile: 'design/sounds/tier2_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier2_hd.png',
    radius: 20.0,
    mass: 1.5,
    scoreValue: 25,
    color: Color(0xFF8E9CAE),
  ),
  fan(
    tier: 3,
    name: 'Makaracı Fan',
    title: 'Makarayız Abi',
    voiceFile: 'design/sounds/tier3_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier3_hd.png',
    radius: 26.0,
    mass: 2.2,
    scoreValue: 50,
    color: Color(0xFFE52E2E),
  ),
  dancer(
    tier: 4,
    name: 'Pijamalı Dansçı',
    title: 'Hoppa Gülüm',
    voiceFile: 'design/sounds/tier4_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier4_hd.png',
    radius: 32.0,
    mass: 3.2,
    scoreValue: 100,
    color: Color(0xFFE01E5A),
  ),
  diva(
    tier: 5,
    name: 'Hamam Diva',
    title: 'Ben Divayım Ayol!',
    voiceFile: 'design/sounds/tier5_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier5_hd.png',
    radius: 39.0,
    mass: 4.5,
    scoreValue: 200,
    color: Color(0xFFFFD700),
  ),
  can(
    tier: 6,
    name: 'Hamam Can',
    title: 'Sayın Seyirciler',
    voiceFile: 'design/sounds/tier6_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier6_hd.png',
    radius: 47.0,
    mass: 6.0,
    scoreValue: 400,
    color: Color(0xFF00FF66),
  ),
  kongo(
    tier: 7,
    name: 'Kongo Lideri',
    title: 'Kurban Olduğum',
    voiceFile: 'design/sounds/tier7_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier7_hd.png',
    radius: 56.0,
    mass: 8.0,
    scoreValue: 800,
    color: Color(0xFFFFB800),
  ),
  bed(
    tier: 8,
    name: 'Hasta Bilge',
    title: 'Dukturu Arayın!',
    voiceFile: 'design/sounds/tier8_ses.mp3',
    assetPath: 'assets/design/bugs_hd/tier8_hd.png',
    radius: 67.0,
    mass: 11.0,
    scoreValue: 1600,
    color: Color(0xFFFFD700),
  );

  final int tier;
  final String name;
  final String title;
  final String voiceFile;
  final String assetPath;
  final double radius;
  final double mass;
  final int scoreValue;
  final Color color;

  const InsectTier({
    required this.tier,
    required this.name,
    required this.title,
    required this.voiceFile,
    required this.assetPath,
    required this.radius,
    required this.mass,
    required this.scoreValue,
    required this.color,
  });

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
