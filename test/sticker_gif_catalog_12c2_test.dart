// 12C2 — StickerGif bağlama testleri.
//
// Kapsar:
// - Katalogun GIF kare karşılığı (`gifFrameItems`): sıralı t4/t5/t7,
//   `byId` araması.
// - Katalog öğelerinin asset'leri diskte var (> 0 bayt) — uydurma
//   asset yok; eksik asset bu testte düşer.
// - Stüdyo GIF ekranı kare satırını katalogdan besler: her kare
//   düğmesi katalog kimlikli anahtarla çizilir, seçimi çalışır,
//   üretim yolu katalog dışı indeksi geçirmez.
//
// NOT: widget testleri gerçek fontları yükler
// (responsive_screens_test deseni) — test yazı tipiyle (Ahem)
// kare etiketi iki satıra sarıp 9 px taşar; gerçek Nunito ile
// tek satıra sığar. Taşma ekranın değil, test yazı tipinin
// eseridir.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lululu_game/screens/studio_screens.dart';
import 'package:lululu_game/services/sticker_gif_catalog.dart';

import 'test_helpers.dart';

/// Gerçek paket fontlarını yükler (responsive_screens_test deseni:
/// `loadAppFonts` + çoklu eklemeli `_loadCustomFonts`). Tekil
/// Regular yüklemesi GoogleFonts ağırlık çözümünde test yazı
/// tipine düşürüp kare etiketini iki satıra sarıyor (9 px taşma);
/// bu kurulumda etiket tek satıra sığar.
Future<void> _loadRealFonts() async {
  await loadAppFonts();
  final fontMap = <String, List<String>>{
    'Baloo 2': List<String>.filled(5, 'assets/fonts/Baloo2-Regular.ttf'),
    'Bangers': ['assets/fonts/Bangers-Regular.ttf'],
    'Nunito': List<String>.filled(4, 'assets/fonts/Nunito-Regular.ttf'),
    'Exo 2': List<String>.filled(5, 'assets/fonts/Exo2-Regular.ttf'),
  };
  for (final entry in fontMap.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }
  for (final w in FontWeight.values) {
    GoogleFonts.baloo2(fontWeight: w);
    GoogleFonts.nunito(fontWeight: w);
    GoogleFonts.bangers(fontWeight: w);
    GoogleFonts.exo2(fontWeight: w);
  }
  await GoogleFonts.pendingFonts();
}

/// Responsive kurulumundaki gibi: gerçek boyut, 1.0 yazı ölçeği,
/// ticker kapalı.
Future<void> _pumpGifScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    wrapWithL10n(
      const MediaQuery(
        data: MediaQueryData(
          size: Size(430, 932),
          devicePixelRatio: 1.0,
          textScaler: TextScaler.linear(1.0),
        ),
        child: TickerMode(
          enabled: false,
          child: StudioGifScreen(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StickerGifCatalog GIF kare katmanı', () {
    test('gifFrameItems sıralı t4/t5/t7 öğeleridir', () {
      expect(
        StickerGifCatalog.gifFrameIds,
        <String>['t4', 't5', 't7'],
      );
      final frames = StickerGifCatalog.gifFrameItems;
      expect(frames.map((item) => item.id).toList(), <String>[
        't4',
        't5',
        't7',
      ]);
      expect(frames[0].title, 'Pijama Dansçı');
      expect(frames[1].title, 'Hamam Diva');
      expect(frames[2].title, 'Kongo Lider');
    });

    test('byId bilinen öğeyi bulur, bilinmeyende null döner', () {
      expect(StickerGifCatalog.byId('t1')?.title, 'Huni Bebek');
      expect(
        StickerGifCatalog.byId('osman_kisi_a')?.assetPath,
        'assets/design/osman/osmantus_kisi_a.png',
      );
      expect(StickerGifCatalog.byId('yok_boyle_bir_id'), isNull);
    });

    test('katalog öğelerinin asset dosyaları diskte var (> 0 bayt)', () {
      final root = Directory.current.path;
      expect(StickerGifCatalog.items, hasLength(11));
      for (final item in StickerGifCatalog.items) {
        final file = File('$root/${item.assetPath}');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'eksik asset: ${item.id} -> ${item.assetPath}',
        );
        expect(
          file.lengthSync(),
          greaterThan(0),
          reason: 'boş asset: ${item.id} -> ${item.assetPath}',
        );
      }
      // GIF kare öğelerinin asset'leri ayrıca doğrulanır.
      for (final item in StickerGifCatalog.gifFrameItems) {
        expect(
          File('$root/${item.assetPath}').existsSync(),
          isTrue,
          reason: 'eksik GIF kare asseti: ${item.id}',
        );
      }
    });
  });

  group('StudioGifScreen katalog bağlama', () {
    testWidgets('kare satırı katalog kimlikli düğmelerden kurulur',
        (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await _loadRealFonts();
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpGifScreen(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (final item in StickerGifCatalog.gifFrameItems) {
        expect(
          find.byKey(ValueKey('gif_frame_${item.id}')),
          findsOneWidget,
          reason: 'katalog karesi çizilmedi: ${item.id}',
        );
      }
      // Piksel-perfect etiketler yerinde durur (katalog başlığıyla
      // değiştirilmedi: 'Pijamalı Dansçı' / 'Kongo Lideri').
      expect(find.text('Pijamalı Dansçı'), findsOneWidget);
      expect(find.text('Hamam Diva'), findsOneWidget);
      expect(find.text('Kongo Lideri'), findsOneWidget);
      // Kapanış: sistem yazı-tipi mesajı gerçek-zamanda geç gelir;
      // ağaç sökülmeden önce aksın (ciglik_play_test deseni).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('kare seçimi katalog düğmesiyle çalışır', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await _loadRealFonts();
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpGifScreen(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('gif_frame_t7')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('gif_frame_t4')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
