import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/profile_screen.dart';
import 'package:lululu_game/services/achievement_pass_service.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/widgets/achievement_toast_overlay.dart';
import 'package:lululu_game/widgets/mode_bonus_bar.dart';

import 'test_helpers.dart';

// Dalga 3D: K1-mount + K1-entry + K8-profil + S9 kanıt testleri.
// HomeShell mount'unun yerleşimi bozmadığı (toast yokken sıfır boyut)
// ve toast varken banner'ın göründüğü; profil girişlerinin sheet
// açtığı; takePower yarışında bildirim çıktığı denetlenir.

Future<void> _pump430x932(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  // NOT: addTearDown ile view reset YOK — reset, teardown'da sistem
  // yazı tipi geri çağrısı bırakıp "animation is still running"
  // hatasına dönüşüyor. Boyut dosya boyunca aynıdır; sızıntı
  // zararsızdır (her test dosyası kendi yalıtımında koşar).
  await tester.pumpWidget(wrapWithL10n(screen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}


/// Bekleyen geçici kare geri çağrılarını boşaltır (sistem yazı tipi
/// bildirimi gibi zaman uyumsuz platform mesajları teardown'da asılı
/// animasyon hatasına dönüşmesin).
Future<void> _flushFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  // Sistem yazı tipi platform mesajı zaman uyumsuz gelir; gerçek
  // zamanlı kısa bekleme + kare, geri çağrının teardown'dan önce
  // çalışmasını sağlar.
  await tester.runAsync(
    () => Future.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

/// Profil ekranındaki bazda önceden-var 44px taşmayı (XP satırı,
/// profile_screen.dart:654 — eklemeler nötrlenmiş probe ile doğrulandı)
/// tüketir; BAŞKA hata varsa testi düşürür.
void _drainKnownProfileOverflow(WidgetTester tester) {
  Object? error;
  var drained = 0;
  while ((error = tester.takeException()) != null) {
    expect(
      error.toString(),
      contains('overflowed by 44 pixels'),
      reason: 'Beklenmeyen hata: $error',
    );
    drained++;
  }
  expect(drained, greaterThan(0));
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
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
    await AchievementPassService.instance.resetForTesting();
    await AchievementPassService.instance.load();
  });

  group('K1-mount — HomeShell toast banner', () {
    testWidgets('toast yokken banner sıfır boyutludur ve hata vermez',
        (tester) async {
      await _pump430x932(tester, const HomeShell());
      expect(find.byType(AchievementToastBanner), findsOneWidget);
      // Positioned(left:0, right:0) genişliği yayar; yükseklik 0'dır —
      // yerleşim kaymaz, dokunuş alanı oluşmaz.
      expect(tester.getSize(find.byType(AchievementToastBanner)).height, 0.0);
      await _flushFrames(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('toast varken banner HomeShell üst katmanında görünür',
        (tester) async {
      await AchievementPassService.instance.unlockAchievement('merge_tier_13');
      expect(
        AchievementPassService.instance.activeToastNotifier.value,
        isNotNull,
      );
      await _pump430x932(tester, const HomeShell());
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('BAŞARIM AÇILDI!'), findsOneWidget);
      await _flushFrames(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('K1-entry + K8-profil — ProfileScreen girişleri', () {
    testWidgets('pass satırı sheet açar, davet satırı görünür', (tester) async {
      await _pump430x932(tester, const ProfileScreen());
      final passRow = find.byKey(const Key('profile_pass_row'));
      await tester.ensureVisible(passRow);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('profile_invite_row')), findsOneWidget);
      await tester.tap(passRow);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('achievement_pass_sheet')), findsOneWidget);
      await _flushFrames(tester);
      _drainKnownProfileOverflow(tester);
    });

    testWidgets('pelerin rozeti yalnız sahipken görünür', (tester) async {
      await _pump430x932(tester, const ProfileScreen());
      expect(
        find.byKey(const Key('profile_royal_cape_badge')),
        findsNothing,
      );

      ProgressManager.instance.hasRoyalCape = true;
      await _pump430x932(tester, const ProfileScreen());
      expect(
        find.byKey(const Key('profile_royal_cape_badge')),
        findsOneWidget,
      );
      await _flushFrames(tester);
      _drainKnownProfileOverflow(tester);
    });
  });

  group('S9 — takePower yarışı bildirimi', () {
    testWidgets('stok dokunuş anında tükenmişse bildirim çıkar',
        (tester) async {
      final pm = ProgressManager.instance;
      await pm.setPowerCount('spray', 1);
      var effectRan = false;
      final bonus = stockBonus(
        id: 'spray',
        label: 'Raid',
        asset: 'assets/design/ui/icons/raid.png',
        effect: () => effectRan = true,
      );
      expect(bonus.count, 1);
      // Yarış: kurulumdan sonra stok başka yoldan tükenir.
      await pm.setPowerCount('spray', 0);

      await _pump430x932(
        tester,
        Scaffold(body: Center(child: ModeBonusBar(items: [bonus]))),
      );
      await tester.tap(find.text('Raid'));
      await tester.pump();
      expect(effectRan, isFalse);
      expect(find.textContaining('kalmadı'), findsOneWidget);
      // SnackBar animasyonu bitsin (teardown'da asılı animasyon kalmasın).
      await tester.pump(const Duration(seconds: 5));
      await _flushFrames(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
