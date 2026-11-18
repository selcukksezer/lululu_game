import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

/// Gerçek oyun fontlarını yükler (pixel capture testleriyle aynı desen):
/// yüklenmezse metinler yedek fontla ölçülür ve başlık satırı 430 px'te
/// 15 px taşma raporlar; gerçek Nunito ölçüleriyle satır sığar.
Future<void> _loadRealFonts() async {
  const fontFiles = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Bold.ttf',
      'assets/fonts/Baloo2-ExtraBold.ttf',
    ],
    'Bangers': ['assets/fonts/Bangers-Regular.ttf'],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
    ],
  };
  for (final entry in fontFiles.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    await _loadRealFonts();
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    await ProgressManager().load();
    await LeaderboardService.instance.ensureLoaded();
  });

  Widget wrapPlayable(Widget home) {
    return wrapWithL10n(
      home,
      debugShowCheckedModeBanner: false,
      theme: buildLululuTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(430, 932),
          devicePixelRatio: 1.0,
          textScaler: const TextScaler.linear(0.85),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  testWidgets(
    '5A: pair fallback branch unlocks the produced tier (no slides, pair taps only)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      // Motorun geç gelen `fontsChange` bildirimi, gövdenin son
      // pompasından SONRA bir kare geri çağrısı zamanlayabiliyor;
      // tearDown pompaları test-sonu değişmez denetiminden önce onu
      // akıtır ("animation is still running" hatasını önler).
      addTearDown(() async {
        await tester.pump();
        await tester.pump();
      });

      final pm = ProgressManager();
      // Başlangıç: yalnız 1..8 açık; 9+ kilitli.
      expect(pm.isTierUnlocked(9), isFalse);
      expect(pm.isTierUnlocked(10), isFalse);

      // Yeterli çiftleştirme stoğu: tahta yalnız bu düğmeyle evrilir.
      await pm.setPowerCount('pair2048', 30);
      expect(pm.powerCount('pair2048'), 30);

      await tester.pumpWidget(
        wrapPlayable(const Grid2048Screen(prototypeVisualState: false)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Grid2048Screen), findsOneWidget);
      expect(find.text('ÇİFTLEŞTİR'), findsOneWidget);

      // Kaydırma YOK: başlangıç tahtası en fazla 3. kademededir
      // (sabit taşlar 1/1/2/2 + en fazla 3. kademe doğuş) ve
      // birleşmelerle ulaşılabilecek tavan 4. kademedir. Eşleşen
      // çift tükenince yedek dal en yüksek taşı yükseltir; 20
      // dokunuş 9. ve 10. kademeye ulaşmaya yeter (en fazla 4
      // birleşme dokunuşu + kalanı yedek dal yükseltmesi).
      for (var i = 0; i < 20; i++) {
        await tester.tap(find.text('ÇİFTLEŞTİR'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      // Her dokunuş `playBonusFx` üzerinden 720 ms'lik bir bekleme
      // zamanlar (bonus_fx.dart); ağaç kaldırılmadan önce bunların
      // tamamlanması gerekir, yoksa test-sonu değişmez denetimi
      // ("Timer is still pending") testi düşürür.
      await tester.pump(const Duration(milliseconds: 1500));

      // Yedek dal `unlockTier(next)` çağırmasaydı 9/10 kilitli kalırdı.
      expect(pm.isTierUnlocked(9), isTrue);
      expect(pm.isTierUnlocked(10), isTrue);
      expect(pm.powerCount('pair2048'), lessThan(30));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      // Görünüm sıfırlama gövde içinde + son pompa: tearDown'da yapılan
      // sıfırlama, test-sonu değişmez denetiminden önce akıtılamayan
      // bir sistem-fontu kare geri çağrısı bırakıyor ("animation is
      // still running"); sıfırlamayı burada yapıp pompalayınca geri
      // çağrı denetimden önce çalışır.
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  test('5A: ProgressManager.unlockTier is idempotent', () async {
    final pm = ProgressManager();
    expect(pm.isTierUnlocked(9), isFalse);

    expect(await pm.unlockTier(9), isTrue);
    expect(pm.isTierUnlocked(9), isTrue);

    // Tekrar çağrı: ikinci kez eklenmez, kalıcı listede tek kayıt.
    expect(await pm.unlockTier(9), isFalse);
    expect(pm.unlockedTiers.where((t) => t == 9).length, 1);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('lululu_unlocked_tiers') ?? const [];
    expect(stored.where((e) => e == '9').length, 1);
  });
}
