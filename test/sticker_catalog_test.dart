// W47-1: StickerGifCatalog statik katalog API'sinin gerileme koruması.
//
// `lib/services/sticker_gif_catalog.dart` artık yalnız statik katalog
// verisidir (W31-1/W39-1/W43-1 temizlikleri sonrası arama/indirme
// metotları silindi): `StickerGifCatalog.instance` +
// `static const items` (11 öğe), her öğede `id`/`title`/`tags`/
// `assetPath`. `asset_integrity_test` yalnız asset varlığını kontrol
// eder; bu dosya kalan API'nin şeklini kilitler.
//
// Katalog salt veridir: singleton kurulumu, mock ve widget pump
// GEREKMEZ; testler düz `test()`'tir.
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/services/sticker_gif_catalog.dart';

void main() {
  group('StickerGifCatalog.items', () {
    test('11 öğe içerir', () {
      expect(StickerGifCatalog.items, hasLength(11));
    });

    test('beklenen kimliklerin tamamını içerir', () {
      const expectedIds = <String>{
        't1',
        't2',
        't3',
        't4',
        't5',
        't6',
        't7',
        't8',
        'osman_kisi_a',
        'osman_kisi_b',
        'roach_run',
      };
      final actualIds =
          StickerGifCatalog.items.map((item) => item.id).toSet();
      expect(actualIds, expectedIds);
    });

    test('her öğenin idsi boş değildir ve tekildir', () {
      final ids = <String>[];
      for (final item in StickerGifCatalog.items) {
        expect(item.id, isNotEmpty, reason: 'boş id: ${item.title}');
        ids.add(item.id);
      }
      expect(ids.toSet(), hasLength(ids.length), reason: 'tekrarlanan id');
    });

    test('her öğenin title ve assetPathi boş değildir', () {
      for (final item in StickerGifCatalog.items) {
        expect(item.title, isNotEmpty, reason: 'boş title: ${item.id}');
        expect(
          item.assetPath,
          isNotEmpty,
          reason: 'boş assetPath: ${item.id}',
        );
        expect(
          item.assetPath,
          startsWith('assets/'),
          reason: 'asset yolu assets/ altında olmalı: ${item.id}',
        );
      }
    });

    test('her öğenin tags listesi boş değildir ve etiketler boş değildir', () {
      for (final item in StickerGifCatalog.items) {
        expect(item.tags, isNotEmpty, reason: 'boş tags: ${item.id}');
        for (final tag in item.tags) {
          expect(tag, isNotEmpty, reason: 'boş etiket: ${item.id}');
        }
      }
    });
  });

  group('StickerGifCatalog.instance', () {
    test('singleton: iki erişim aynı nesnedir', () {
      final first = StickerGifCatalog.instance;
      final second = StickerGifCatalog.instance;
      expect(identical(first, second), isTrue);
      expect(first, same(second));
    });
  });
}
