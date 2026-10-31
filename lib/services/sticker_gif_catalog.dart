import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Aranabilir böcek çıkartması / GIF kataloğu + indirme.
class StickerGifItem {
  const StickerGifItem({
    required this.id,
    required this.title,
    required this.tags,
    required this.assetPath,
    this.remoteGifUrl,
  });

  final String id;
  final String title;
  final List<String> tags;
  final String assetPath;
  final String? remoteGifUrl;

  bool matches(String q) {
    if (q.trim().isEmpty) return true;
    final s = q.toLowerCase();
    if (title.toLowerCase().contains(s)) return true;
    return tags.any((t) => t.toLowerCase().contains(s));
  }
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
      remoteGifUrl:
          'https://media.giphy.com/media/3o7aCTPPm4OHfRLSH6/giphy.gif',
    ),
  ];

  List<StickerGifItem> search(String query) =>
      items.where((e) => e.matches(query)).toList();

  /// PNG asset veya remote GIF → cihaz dosyası + paylaş / kaydet.
  Future<String> downloadAndShare(StickerGifItem item) async {
    final dir = await getApplicationDocumentsDirectory();
    final stickersDir = Directory('${dir.path}/sticker_downloads');
    if (!await stickersDir.exists()) {
      await stickersDir.create(recursive: true);
    }

    late File out;
    if (item.remoteGifUrl != null) {
      final res = await http.get(Uri.parse(item.remoteGifUrl!));
      if (res.statusCode != 200) {
        throw StateError('GIF indirilemedi (${res.statusCode})');
      }
      out = File('${stickersDir.path}/${item.id}.gif');
      await out.writeAsBytes(res.bodyBytes);
    } else {
      final data = await rootBundle.load(item.assetPath);
      out = File('${stickersDir.path}/${item.id}.png');
      await out.writeAsBytes(data.buffer.asUint8List());
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(out.path)],
        text: '${item.title} — Lülülü çıkartması',
      ),
    );
    return out.path;
  }
}
