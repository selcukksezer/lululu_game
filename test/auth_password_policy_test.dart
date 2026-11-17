import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';

// Şifre politikası: yeni kayıtlar için asgari uzunluk 6
// (`AuthService._minPasswordLen`, lib/services/auth_service.dart).
// Girişte asgari uzunluk dayatılmaz: eski kısa şifreli hesaplar giriş
// yapabilmeli (aynı dosyadaki kural yorumu).
//
// Bu dosya `auth_leaderboard_test.dart` ile çakışmaz: ayrı dosya,
// ayrı kullanıcı adları, her testte boş kasadan başlanır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.load();
    await AuthService.instance.signOut();
  });

  Matcher rejectsShortPassword() => throwsA(
        isA<ArgumentError>().having(
          (e) => e.toString(),
          'toString',
          contains('en az 6'),
        ),
      );

  test('5 karakterli şifre ile kayıt reddedilir ve hesap oluşmaz', () async {
    final auth = AuthService.instance;

    await expectLater(
      () => auth.register(username: 'pwuser1', password: 'abc12'),
      rejectsShortPassword(),
    );

    expect(auth.registeredAccounts, isEmpty);
    expect(auth.isSignedIn, isFalse);
    // Kayıt oluşmadığı için giriş "bulunamadı" der.
    await expectLater(
      () => auth.login(username: 'pwuser1', password: 'abc12'),
      throwsA(isA<StateError>()),
    );
  });

  test('boş ve 1 karakterli şifre reddedilir', () async {
    final auth = AuthService.instance;

    await expectLater(
      () => auth.register(username: 'pwuser2', password: ''),
      rejectsShortPassword(),
    );
    await expectLater(
      () => auth.register(username: 'pwuser3', password: 'x'),
      rejectsShortPassword(),
    );
    expect(auth.registeredAccounts, isEmpty);
  });

  test('yalnızca boşluk içeren 6 karakterli şifre reddedilir', () async {
    final auth = AuthService.instance;

    // Kural kırpılmış uzunluğa da bakar: 6 boşluk, 0 karakter sayılır.
    await expectLater(
      () => auth.register(username: 'pwuser4', password: '      '),
      rejectsShortPassword(),
    );
    expect(auth.registeredAccounts, isEmpty);
  });

  test('tam 6 karakterli şifre kabul edilir', () async {
    final auth = AuthService.instance;

    final created = await auth.register(
      username: 'pwuser5',
      password: 'abcdef',
    );

    expect(created.username, 'pwuser5');
    expect(created.provider, AuthProviderKind.local);
    expect(auth.isSignedIn, isTrue);
    expect(auth.registeredAccounts.length, 1);
  });

  test('e-posta ile kayıtta kısa şifre reddedilir', () async {
    final auth = AuthService.instance;

    await expectLater(
      () => auth.registerWithEmail(
        email: 'pwtest@example.com',
        password: '12345',
      ),
      rejectsShortPassword(),
    );
    expect(auth.registeredAccounts, isEmpty);
  });

  test('girişte asgari uzunluk dayatılmaz (kısa şifre ArgumentError vermez)',
      () async {
    final auth = AuthService.instance;

    // Kayıtlı olmayan kullanıcı + kısa şifre: uzunluk hatası değil,
    // "bulunamadı" hatası (StateError) gelir.
    await expectLater(
      () => auth.login(username: 'pwuser6', password: 'abc'),
      throwsA(isA<StateError>()),
    );
  });
}
