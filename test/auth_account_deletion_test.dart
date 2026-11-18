import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';

// Hesap silme (yerel, madde 97): `AuthService.deleteAccount`
// (lib/services/auth_service.dart) oturumdaki hesabı yerel kasadan
// çıkarır, başarısız-giriş sayaçlarını temizler, oturumu kapatır ve
// çevrimiçi eşitlemeyi yeniden değerlendirir. Diğer hesaplara
// dokunulmaz. Sunucu tarafı silme (Firebase/Firestore) bu sürümde
// YOKTUR — metodun kendi dokümantasyonundaki TODO kapsamındadır.
//
// Oturum yoksa veya misafir oturumuysa StateError fırlatır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.instance.load();
    await AuthService.instance.signOut();
  });

  test('hesap silinir: kasa boşalır, oturum kapanır, giriş reddedilir',
      () async {
    final auth = AuthService.instance;
    await auth.register(username: 'deluser1', password: 'abcdef');
    expect(auth.isSignedIn, isTrue);

    await auth.deleteAccount();

    expect(auth.isSignedIn, isFalse);
    expect(auth.user, isNull);
    expect(auth.registeredAccounts, isEmpty);
    await expectLater(
      () => auth.login(username: 'deluser1', password: 'abcdef'),
      throwsA(isA<StateError>()),
    );
  });

  test('silinen kullanıcı adıyla yeniden kayıt yapılabilir', () async {
    final auth = AuthService.instance;
    await auth.register(username: 'deluser2', password: 'abcdef');
    await auth.deleteAccount();

    final recreated = await auth.register(
      username: 'deluser2',
      password: 'yenisi1',
    );

    expect(recreated.username, 'deluser2');
    expect(auth.registeredAccounts.length, 1);
  });

  test('yalnız oturumdaki hesap silinir, diğer hesaplar kalır', () async {
    final auth = AuthService.instance;
    await auth.register(username: 'deluser3', password: 'abcdef');
    await auth.signOut();
    await auth.register(username: 'deluser4', password: 'abcdef');
    await auth.signOut();

    await auth.login(username: 'deluser3', password: 'abcdef');
    await auth.deleteAccount();

    expect(auth.registeredAccounts.length, 1);
    expect(auth.registeredAccounts.first.username, 'deluser4');
    final survivor = await auth.login(
      username: 'deluser4',
      password: 'abcdef',
    );
    expect(survivor.username, 'deluser4');
  });

  test('oturum açık değilken silme StateError verir', () async {
    final auth = AuthService.instance;
    expect(auth.isSignedIn, isFalse);

    await expectLater(
      () => auth.deleteAccount(),
      throwsA(isA<StateError>()),
    );
  });

  test('misafir oturumunda silme StateError verir, oturum sürer', () async {
    final auth = AuthService.instance;
    await auth.signInAsGuest();
    expect(auth.isGuest, isTrue);

    await expectLater(
      () => auth.deleteAccount(),
      throwsA(isA<StateError>()),
    );

    expect(auth.isSignedIn, isTrue);
    expect(auth.isGuest, isTrue);
  });

  test('silme, hesabın başarısız-giriş sayaçlarını temizler', () async {
    final auth = AuthService.instance;
    await auth.register(username: 'deluser5', password: 'abcdef');
    await auth.signOut();
    await auth.login(username: 'deluser5', password: 'abcdef');
    await expectLater(
      () => auth.login(username: 'deluser5', password: 'yanlis1'),
      throwsA(isA<StateError>()),
    );
    expect(auth.failedAttemptsFor('deluser5'), 1);

    await auth.deleteAccount();

    expect(auth.failedAttemptsFor('deluser5'), 0);
  });
}
