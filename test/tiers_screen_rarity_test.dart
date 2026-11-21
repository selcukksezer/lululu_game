// 12B-tiers: Tiers ekranı nadirlik + puanları modelden okur.
// Brif: tek doğruluk kaynağı InsectTier (rarity / scoreValue); ekran kendi
// kopyasını tutmaz. TR'de t9 Süper, t13 Mutlak; EN'de Common...Absolute;
// puanlar dile duyarlı binlik ayırıcı ile (TR '1.600', EN '1,600').
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/screens/tiers_screen.dart';

import 'test_helpers.dart';

const _raritiesTr = <String>[
  'Sıradan',
  'Seyrek',
  'Nadir',
  'Destansı',
  'Efsanevi',
  'Mitik',
  'Gizli',
  'Evrim Kristali',
  'Süper',
  'Ultra',
  'Kozmik',
  'Kadim',
  'Mutlak',
];

const _raritiesEn = <String>[
  'Common',
  'Uncommon',
  'Rare',
  'Epic',
  'Legendary',
  'Mythic',
  'Hidden',
  'Evolution Crystal',
  'Super',
  'Ultra',
  'Cosmic',
  'Ancient',
  'Absolute',
];

const _scores = <int>[
  10,
  25,
  50,
  100,
  200,
  400,
  800,
  1600,
  3200,
  6400,
  12800,
  25600,
  51200,
];

Future<void> _pumpTiers(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await pumpWithL10n(
    tester,
    const TiersScreen(embedded: true),
    locale: locale,
  );
  await tester.pumpAndSettle();
}

Future<void> _expectRowVisible(
  WidgetTester tester,
  String text,
) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  expect(find.text(text), findsOneWidget, reason: 'satır metni: $text');
}

void main() {
  group('Tiers ekranı model nadirlik + puanlarını gösterir (12B)', () {
    test('model scoreValue tablosu t1 10 ... t13 51200', () {
      expect(InsectTier.values.length, 13);
      for (var i = 0; i < 13; i++) {
        final tier = InsectTier.fromTier(i + 1);
        expect(tier.scoreValue, _scores[i], reason: 'tier ${i + 1}');
        expect(tier.rarity, _raritiesTr[i], reason: 'tier ${i + 1} TR');
        expect(
          tier.rarityFor(const Locale('en')),
          _raritiesEn[i],
          reason: 'tier ${i + 1} EN',
        );
      }
    });

    testWidgets('TR: 13 nadirlik + TR binlik ayırıcılı puanlar', (
      WidgetTester tester,
    ) async {
      await _pumpTiers(tester, const Locale('tr'));
      for (var i = 0; i < 13; i++) {
        await _expectRowVisible(tester, _raritiesTr[i]);
      }
      // Spot check: t9 Süper / t13 Mutlak + TR puan biçimi.
      await _expectRowVisible(tester, 'Süper');
      await _expectRowVisible(tester, '+3.200');
      await _expectRowVisible(tester, 'Mutlak');
      await _expectRowVisible(tester, '+51.200');
      await _expectRowVisible(tester, '+1.600');
      // Eski yanlış etiketler artık yok.
      expect(find.text('EFSANEVİ'), findsNothing);
      expect(find.text('ZİRVE'), findsNothing);
    });

    testWidgets('EN: 13 nadirlik + EN binlik ayırıcılı puanlar', (
      WidgetTester tester,
    ) async {
      await _pumpTiers(tester, const Locale('en'));
      for (var i = 0; i < 13; i++) {
        await _expectRowVisible(tester, _raritiesEn[i]);
      }
      await _expectRowVisible(tester, 'Super');
      await _expectRowVisible(tester, '+3,200');
      await _expectRowVisible(tester, 'Absolute');
      await _expectRowVisible(tester, '+51,200');
      await _expectRowVisible(tester, '+1,600');
    });
  });
}
