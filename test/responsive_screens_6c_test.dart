// 6C (Faz 3, Dalga 6b): telefon uyumu ekran düzeltmelerinin regresyon
// testleri — A7/A7b taramasının F-01..F-04 bulguları.
//
// Her test gerçek viewport'ta (FittedBox maskesi yok, yazı ölçeği 1.0),
// gerçek fontlarla koşar (responsive_screens_test.dart deseni). Ellipsis
// denetimi RenderParagraph.didExceedMaxLines ile yapılır: kesilen metin
// `true` döner, FittedBox scaleDown ile tam sığan metin `false`.
//
// Bilinen kapsam-dışı baz hata YOKTUR — 7A'da kapatıldı: CampaignMapScreen
// 360x640'ta seviye ızgarası karo içeriği 7.2px taşıyordu (karo Column'u,
// ClipRRect altında). Düzeltme: karo içeriği FittedBox (scaleDown) içinde
// (lib/screens/campaign_map_screen.dart); 360'ta taşma sıfır, 430 düzeni
// aynen. Bu dosyadaki kampanya testleri artık HİÇBİR FlutterError'a izin
// vermez (izin listesi 7A'da kaldırıldı).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/campaign_map_screen.dart';
import 'package:lululu_game/screens/chat_screen.dart';
import 'package:lululu_game/screens/tasks_screen.dart';
import 'package:lululu_game/services/adaptive_quality_scaler.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/shop_dialog.dart';

import 'test_helpers.dart';

Future<void> _loadCustomFonts() async {
  final fontMap = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Bold.ttf',
      'assets/fonts/Baloo2-ExtraBold.ttf',
      'assets/fonts/Baloo2-SemiBold.ttf',
      'assets/fonts/Baloo2-Medium.ttf',
    ],
    'Bangers': [
      'assets/fonts/Bangers-Regular.ttf',
    ],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
      'assets/fonts/Nunito-SemiBold.ttf',
      'assets/fonts/Nunito-Black.ttf',
    ],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Bold.ttf',
      'assets/fonts/Exo2-ExtraBold.ttf',
      'assets/fonts/Exo2-SemiBold.ttf',
      'assets/fonts/Exo2-Black.ttf',
    ],
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

/// Ekranı gerçek boyutta kurar, [assertions] çalıştırır, sonra kaldırır.
/// Kurulum/kaldırma sırasında yakalanan FlutterError'ları döndürür
/// (varlık yükleme hataları yok sayılır — responsive deseni).
Future<List<String>> _pumpAndAssert(
  WidgetTester tester,
  Size size,
  Widget screen,
  void Function() assertions,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final flutterErrors = <String>[];
  final prevOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('Unable to load asset')) {
      return;
    }
    flutterErrors.add(details.toString());
  };

  try {
    await tester.pumpWidget(
      wrapWithL10n(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            devicePixelRatio: 1.0,
            textScaler: const TextScaler.linear(1.0),
            padding: const EdgeInsets.only(top: 35.4, bottom: 24),
            viewPadding: const EdgeInsets.only(top: 35.4, bottom: 24),
          ),
          child: TickerMode(
            enabled: false,
            child: screen,
          ),
        ),
        debugShowCheckedModeBanner: false,
        theme: buildLululuTheme(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final pendingEx = tester.takeException();
    if (pendingEx != null) {
      flutterErrors.add(pendingEx.toString());
    }

    assertions();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    final disposeEx = tester.takeException();
    if (disposeEx != null) {
      flutterErrors.add(disposeEx.toString());
    }
  } finally {
    FlutterError.onError = prevOnError;
  }
  return flutterErrors;
}

/// Bulunan her Text'in kesilmediğini (ellipsis olmadığını) doğrular.
void _expectNoEllipsis(WidgetTester tester, Finder finder, String label) {
  expect(finder, findsWidgets, reason: '$label bulunamadı');
  for (final element in finder.evaluate()) {
    final renderObject = element.renderObject;
    expect(
      renderObject,
      isA<RenderParagraph>(),
      reason: '$label RenderParagraph değil',
    );
    expect(
      (renderObject as RenderParagraph).didExceedMaxLines,
      isFalse,
      reason: '$label kesik (ellipsis): "${(element.widget as Text).data}"',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceSizes = <String, Size>{
    '360x640': Size(360, 640),
    '390x844': Size(390, 844),
    '430x932': Size(430, 932),
  };

  setUpAll(() async {
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => null,
      );
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    await _loadCustomFonts();
    Animate.defaultDuration = Duration.zero;
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({
      'LululuOnboardingDoneV1': true,
      'LululuCoinBalance': 12450,
      'LululuEnergyCount': 5,
      'LululuDiamondBalance': 86,
      'LululuAuthV1':
          '{"uid":"apple-123","displayName":"Apple Oyuncu","provider":"apple"}',
      'lululu_coins': 12450,
    });
    await ProgressManager().load();
    await LeaderboardService.instance.ensureLoaded();
    AdaptiveQualityScaler.instance.bootstrap(forceTier: QualityTier.medium);
  });

  for (final deviceEntry in deviceSizes.entries) {
    final deviceLabel = deviceEntry.key;
    final size = deviceEntry.value;

    testWidgets(
      'F-01 shop free-chest description stays inside the card at $deviceLabel',
      (tester) async {
        final errors = await _pumpAndAssert(
          tester,
          size,
          const ShopScreen(embedded: true),
          () {
            final descFinder = find.text(
              'Ödüllü reklamlar yakında: ücretsiz Ahşap Sandık + '
              'rastgele 1 güçlendirici burada olacak.',
            );
            final noteFinder = find.text('5 dk = +1 kalp');
            expect(descFinder, findsOneWidget);
            expect(noteFinder, findsOneWidget);
            // Açıklamanın son satırı ENERJİ başlık satırının üstünde
            // bitmeli (önce: 360'ta 16.4px çakışma).
            expect(
              tester.getRect(descFinder).bottom,
              lessThanOrEqualTo(tester.getRect(noteFinder).top),
              reason: 'F-01: açıklama ENERJİ başlığıyla çakışıyor',
            );
          },
        );
        expect(
          errors,
          isEmpty,
          reason: 'F-01 shop at $deviceLabel had errors/overflows:\n'
              '${errors.join('\n---\n')}',
        );
      },
    );

    testWidgets(
      'F-02 tasks title fits fully at $deviceLabel',
      (tester) async {
        final errors = await _pumpAndAssert(
          tester,
          size,
          const TasksScreen(),
          () {
            _expectNoEllipsis(
              tester,
              find.text('GÜNLÜK GÖREVLER'),
              'tasks title',
            );
          },
        );
        expect(
          errors,
          isEmpty,
          reason: 'F-02 tasks at $deviceLabel had errors/overflows:\n'
              '${errors.join('\n---\n')}',
        );
      },
    );

    testWidgets(
      'F-03/F-09 chat channel labels fit fully at $deviceLabel',
      (tester) async {
        final errors = await _pumpAndAssert(
          tester,
          size,
          const ChatScreen(),
          () {
            for (final label in [
              'Genel Lobi',
              'Takım & Klan',
              'VS Meydan Okuma',
            ]) {
              _expectNoEllipsis(tester, find.text(label), 'chat tab $label');
            }
          },
        );
        expect(
          errors,
          isEmpty,
          reason: 'F-03 chat at $deviceLabel had errors/overflows:\n'
              '${errors.join('\n---\n')}',
        );
      },
    );

    testWidgets(
      'F-04 campaign header, chest chips and chapter chips fit at $deviceLabel',
      (tester) async {
        final errors = await _pumpAndAssert(
          tester,
          size,
          const CampaignMapScreen(),
          () {
            // (a) Üst başlık.
            _expectNoEllipsis(tester, find.text('LÜLÜLÜ'), 'campaign title');
            _expectNoEllipsis(
              tester,
              find.text('Bölüm Haritası'),
              'campaign subtitle',
            );
            // (b) Sandık çipi metinleri (etiket + ödül satırları).
            // Not: 390'daki cihaz-içi kesiklik test fontlarında
            // (emoji metrik farkı) üremez; 360 etiketi ayırt edicidir,
            // FittedBox düzeltmesi yapısal olarak her genişlikte sığar.
            _expectNoEllipsis(
              tester,
              find.descendant(
                of: find.byKey(const Key('campaign_map_chest_bar')),
                matching: find.byType(Text),
              ),
              'chest bar text',
            );
            // (c) İkinci bölüm çipi viewport içinde bitmeli.
            final divaChip = find.ancestor(
              of: find.text('Diva Malikanesi'),
              matching: find.byType(AnimatedContainer),
            );
            expect(divaChip, findsOneWidget);
            expect(
              tester.getRect(divaChip).right,
              lessThanOrEqualTo(size.width),
              reason: 'F-04(c): Diva Malikanesi çipi sağ kenarda kesik',
            );
          },
        );
        expect(
          errors,
          isEmpty,
          reason: 'F-04 campaign at $deviceLabel had errors/overflows:\n'
              '${errors.join('\n---\n')}',
        );
      },
    );
  }

  testWidgets('F-04 campaign 430x932 layout is unchanged', (tester) async {
    // Düzeltme öncesi baz ölçümler (gerçek fontlu harness): başlık,
    // sandık etiketi ve bölüm çipi konumları birebir aynı kalmalı.
    final errors = await _pumpAndAssert(
      tester,
      const Size(430, 932),
      const CampaignMapScreen(),
      () {
        final titleRect = tester.getRect(find.text('LÜLÜLÜ'));
        expect(titleRect.left, closeTo(110.0, 0.6));
        expect(titleRect.right, closeTo(184.9, 0.6));
        final subtitleRect = tester.getRect(find.text('Bölüm Haritası'));
        expect(subtitleRect.right, closeTo(187.3, 0.6));
        final chestLabel = find.descendant(
          of: find.byKey(const Key('campaign_map_chest_bar')),
          matching: find.text('10⭐ Sandık'),
        );
        expect(chestLabel, findsWidgets);
        final chestRect = tester.getRect(chestLabel.first);
        expect(chestRect.left, closeTo(123.0, 0.6));
        expect(chestRect.right, closeTo(178.0, 0.6));
        final divaChip = find.ancestor(
          of: find.text('Diva Malikanesi'),
          matching: find.byType(AnimatedContainer),
        );
        final chipRect = tester.getRect(divaChip);
        expect(chipRect.left, closeTo(198.5, 0.6));
        expect(chipRect.right, closeTo(368.2, 0.6));
      },
    );
    expect(
      errors,
      isEmpty,
      reason: 'F-04 campaign 430 had errors:\n'
          '${errors.join('\n---\n')}',
    );
  });

  testWidgets('7A shop YAKINDA button height >=44 at 360/390/430', (
    tester,
  ) async {
    // A9 canlı notu "40 px" widget ağacında üremedi: düğme kapsayıcısı
    // 48px, görünür yüz 44px (360/390/430 probe ölçümü). Bu test
    // 44px kılavuzunu kilitler: YAKINDA metninin Container atalarının
    // düğme yüzleri (kartın kendisi hariç) 44px'in altına inemez.
    for (final w in [360.0, 390.0, 430.0]) {
      final errors = await _pumpAndAssert(
        tester,
        Size(w, 932),
        const ShopScreen(embedded: true),
        () {
          final textFinder = find.text('YAKINDA');
          expect(textFinder, findsOneWidget, reason: 'YAKINDA @$w');
          final containers = find.ancestor(
            of: textFinder,
            matching: find.byType(Container),
          );
          final heights = <double>[];
          for (final el in containers.evaluate()) {
            final rect = tester.getRect(find.byWidget(el.widget));
            // Kartın kendisi (~250px) hariç: yalnız düğme yüzleri.
            if (rect.height < 100) heights.add(rect.height);
          }
          expect(heights, isNotEmpty, reason: 'düğme yüzü bulunamadı @$w');
          for (final h in heights) {
            expect(
              h,
              greaterThanOrEqualTo(44),
              reason: 'YAKINDA düğme yüzü $h px < 44px @$w',
            );
          }
        },
      );
      expect(
        errors,
        isEmpty,
        reason: 'shop YAKINDA @$w had errors:\n${errors.join('\n---\n')}',
      );
    }
  });

  testWidgets('7A campaign frontier tile with modifier dots fits at 360', (
    tester,
  ) async {
    // Sınır durum: sınır seviyesi 5 (hayatta kalma) değiştirici
    // noktalı karodur — 7A öncesi 360'ta ~18px taşardı (yalnız
    // sınır=1 durumu 6C'de bayraklıydı). FittedBox düzeltmesi her
    // sınır + nokta birleşiminde sığmayı garanti eder.
    SharedPreferences.setMockInitialValues({
      'LululuOnboardingDoneV1': true,
      'LululuCoinBalance': 12450,
      'LululuEnergyCount': 5,
      'LululuDiamondBalance': 86,
      'LululuAuthV1':
          '{"uid":"apple-123","displayName":"Apple Oyuncu","provider":"apple"}',
      'lululu_coins': 12450,
      'lululu_unlocked_level': 5,
    });
    await ProgressManager().load();
    final errors = await _pumpAndAssert(
      tester,
      const Size(360, 640),
      const CampaignMapScreen(),
      () {
        // Sınır karosu (seviye 5) ekranda, numarası kesiksiz.
        _expectNoEllipsis(tester, find.text('5'), 'frontier tile number');
      },
    );
    expect(
      errors,
      isEmpty,
      reason: 'frontier+dots 360 had errors:\n${errors.join('\n---\n')}',
    );
  });
}
