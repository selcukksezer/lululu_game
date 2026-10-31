/// Osmantuş viral kadrosu — videodaki iki kişi (böcek değil).
class OsmantusPerson {
  const OsmantusPerson({
    required this.id,
    required this.displayName,
    required this.assetPath,
    required this.lines,
  });

  final String id;
  final String displayName;
  final String assetPath;
  final List<String> lines;
}

class OsmantusCast {
  OsmantusCast._();

  /// Beyaz tişörtlü — tuş / işaretçi.
  static const kisiA = OsmantusPerson(
    id: 'osman',
    displayName: 'Osman',
    assetPath: 'assets/images/stickers/osmantus_kisi_a.png',
    lines: [
      'OSMAN TUŞ!',
      'DIKKIŞ DIKKIŞ!',
      'AĞZIMA DÜŞ!',
    ],
  );

  /// Lacivert eşofmanlı — makara / dinleyen.
  static const kisiB = OsmantusPerson(
    id: 'tus',
    displayName: 'Tuş',
    assetPath: 'assets/images/stickers/osmantus_kisi_b.png',
    lines: [
      'ARMUT PİŞ!',
      'LÜLÜLÜ!',
      'YEŞİLDE BAS!',
    ],
  );

  static const duo = <OsmantusPerson>[kisiA, kisiB];

  static const hubSticker = 'assets/images/stickers/osmantus_kisi_a.png';
}
