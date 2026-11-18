/// Böcek çıkartması / GIF kataloğu (statik veri; arama/indirme kaldırıldı).
class StickerGifItem {
  const StickerGifItem({
    required this.id,
    required this.title,
    required this.tags,
    required this.assetPath,
  });

  final String id;
  final String title;
  final List<String> tags;
  final String assetPath;
}

class StickerGifCatalog {
  StickerGifCatalog._();
  static final instance = StickerGifCatalog._();

  static const items = <StickerGifItem>[
    StickerGifItem(
      id: 't1',
      title: 'Huni Bebek',
      tags: ['lululu', 'bebek', 'huni', 'gif'],
      assetPath: 'assets/design/bugs_hd/tier1_hd.png',
    ),
    StickerGifItem(
      id: 't2',
      title: 'Tencere Çırak',
      tags: ['kask', 'tencere', 'çırak', 'böcek'],
      assetPath: 'assets/design/bugs_hd/tier2_hd.png',
    ),
    StickerGifItem(
      id: 't3',
      title: 'Makarayız Fan',
      tags: ['makarayız', 'fan', 'viral', 'abi'],
      assetPath: 'assets/design/bugs_hd/tier3_hd.png',
    ),
    StickerGifItem(
      id: 't4',
      title: 'Pijama Dansçı',
      tags: ['dans', 'pijama', 'hoppa'],
      assetPath: 'assets/design/bugs_hd/tier4_hd.png',
    ),
    StickerGifItem(
      id: 't5',
      title: 'Hamam Diva',
      tags: ['diva', 'hamam', 'rezzillik'],
      assetPath: 'assets/design/bugs_hd/tier5_hd.png',
    ),
    StickerGifItem(
      id: 't6',
      title: 'Hamam Can',
      tags: ['şovmen', 'can', 'flaş'],
      assetPath: 'assets/design/bugs_hd/tier6_hd.png',
    ),
    StickerGifItem(
      id: 't7',
      title: 'Kongo Lider',
      tags: ['kongo', 'istila', 'lider'],
      assetPath: 'assets/design/bugs_hd/tier7_hd.png',
    ),
    StickerGifItem(
      id: 't8',
      title: 'Hasta Bilge',
      tags: ['yatak', 'duktur', 'ölüyorum'],
      assetPath: 'assets/design/bugs_hd/tier8_hd.png',
    ),
    StickerGifItem(
      id: 'osman_kisi_a',
      title: 'Osmantuş · Osman',
      tags: ['osmantuş', 'osman', 'tuş', 'dıkkış', 'viral', 'iki kişi'],
      assetPath: 'assets/design/osman/osmantus_kisi_a.png',
    ),
    StickerGifItem(
      id: 'osman_kisi_b',
      title: 'Osmantuş · Tuş',
      tags: ['osmantuş', 'tuş', 'eşofman', 'makara', 'viral', 'iki kişi'],
      assetPath: 'assets/design/osman/osmantus_kisi_b.png',
    ),
    StickerGifItem(
      id: 'roach_run',
      title: 'Koşan Hamamböceği',
      tags: ['koşu', 'gif', 'böcek', 'çığlık'],
      assetPath: 'assets/design/bugs_hd/tier2_hd.png',
    ),
  ];
}
