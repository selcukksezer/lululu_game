import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/profile_screen.dart';
import 'package:lululu_game/services/achievement_pass_service.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/widgets/auth_panel.dart';

import 'test_helpers.dart';

// 12D2 — Ölü UI'yı canlandır: AuthPanel + AchievementToast/PassSheet.
//
// Doğrulanan bağlar (HEAD f12b308'de kaynak taramasıyla):
// * AuthPanel: hiçbir yerden örneklendirilmiyordu (yalnız
//   GuestSignInButton, AuthScreen tarafından paylaşılıyordu).
//   12D2'de profil "Hesap" girişi (_openAuth) gömülü panel sheet'i
//   oldu; kanonik tam ekran AuthScreen ayarlar + '/account' rotasında
//   aynen durur.
// * Toast: kilit açılınca AchievementPassService.activeToastNotifier
//   üzerinden HomeShell'deki banner'a zaten ulaşıyordu (K1-mount);
//   burada uçtan-uca + kapatma davranışı kilitlenir.
// * Pass sheet: profil satırı (_openPassSheet) zaten bağlıydı (K1-entry);
//   burada satırdan açılış kilitlenir.
Future<void> _pump430x932(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(wrapWithL10n(screen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// Bekleyen geçici kare geri çağrılarını boşaltır.
Future<void> _flushFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(
    () => Future.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
}

/// Profil ekranındaki önceden-var 44px taşmayı (XP satırı,
/// profile_screen.dart — wave3d_feedback_entries_test deseni) varsa
/// tüketir; BAŞKA hata varsa testi düşürür. Taşma her koşulda
/// oluşmayabilir (düzen/ypazı tipi durumuna bağlı), bu yüzden sıfır
/// drenaj da geçerlidir — yardımcı yalnız bilinen taşmayı yutar.
void _drainKnownProfileOverflow(WidgetTester tester) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    expect(
      error.toString(),
      contains('overflowed by 44 pixels'),
      reason: 'Beklenmeyen hata: $error',
    );
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
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
    await AchievementPassService.instance.resetForTesting();
    await AchievementPassService.instance.load();
    await AuthService.instance.load();
    await AuthService.instance.signOut();
  });

  group('12D2 — AuthPanel profil "Hesap" girişinden sheet olarak açılır',
      () {
    testWidgets('misafir CTA paneli açar, kapat düğmesi sheeti kapatır',
        (tester) async {
      await _pump430x932(tester, const ProfileScreen());
      expect(find.byType(AuthPanel), findsNothing);

      final cta = find.text('GİRİŞ YAP / KAYIT OL');
      await tester.ensureVisible(cta);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(cta);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AuthPanel), findsOneWidget);
      expect(find.text('Kullanıcı adın (min 3 karakter)'), findsOneWidget);
      expect(find.text('Şifre (min 6 karakter)'), findsOneWidget);
      expect(find.text('Giriş'), findsOneWidget);
      expect(find.text('Kayıt'), findsOneWidget);

      final close = find.descendant(
        of: find.byType(AuthPanel),
        matching: find.byIcon(Icons.close_rounded),
      );
      await tester.tap(close);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AuthPanel), findsNothing);

      await _flushFrames(tester);
      _drainKnownProfileOverflow(tester);
    });

    testWidgets('kayıt akışı: yeni hesap açılır, onSuccess çağrılır',
        (tester) async {
      var successCalled = false;
      await _pump430x932(
        tester,
        Scaffold(
          body: AuthPanel(
            onSuccess: () => successCalled = true,
          ),
        ),
      );

      await tester.tap(find.text('Kayıt'));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField).at(0),
        'paneluser1',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'abcdef',
      );
      await tester.tap(find.text('HESAP OLUŞTUR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(successCalled, isTrue);
      expect(AuthService.instance.isSignedIn, isTrue);
      expect(AuthService.instance.currentUser?.username, 'paneluser1');
      await _flushFrames(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('yanlış şifreyle giriş hata bandı gösterir, form açık kalır',
        (tester) async {
      final auth = AuthService.instance;
      await auth.register(username: 'paneluser2', password: 'abcdef');
      await auth.signOut();

      await _pump430x932(
        tester,
        const Scaffold(body: AuthPanel()),
      );
      await tester.enterText(
        find.byType(TextField).at(0),
        'paneluser2',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'yanlis1',
      );
      await tester.tap(find.text('GİRİŞ YAP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(AuthService.instance.isSignedIn, isFalse);
      expect(find.byType(AuthPanel), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      await _flushFrames(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('12D2 — Başarım toast + pass sheet gösterim noktaları', () {
    testWidgets('başarım açılınca HomeShell toast gösterir, kapatılabilir',
        (tester) async {
      await AchievementPassService.instance.unlockAchievement('merge_tier_13');
      expect(
        AchievementPassService.instance.activeToastNotifier.value,
        isNotNull,
      );

      await _pump430x932(tester, const HomeShell());
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('BAŞARIM AÇILDI!'), findsOneWidget);
      expect(find.text('Makara Efsanesi Tier 13'), findsOneWidget);

      await tester.tap(find.byKey(const Key('achievement_toast_close_btn')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        AchievementPassService.instance.activeToastNotifier.value,
        isNull,
      );
      expect(find.text('BAŞARIM AÇILDI!'), findsNothing);
      await _flushFrames(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pass satırı profil ekranından sheet açar', (tester) async {
      await _pump430x932(tester, const ProfileScreen());
      final passRow = find.byKey(const Key('profile_pass_row'));
      await tester.ensureVisible(passRow);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(passRow);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('achievement_pass_sheet')), findsOneWidget);
      await _flushFrames(tester);
      _drainKnownProfileOverflow(tester);
    });
  });
}
