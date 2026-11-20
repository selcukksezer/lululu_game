import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/firebase_bootstrap.dart';

// Dalga 2 — Firebase Auth eksikleri:
// (1) şifre sıfırlama, (2) misafir→hesap göçünde linkWithCredential,
// (3) authStateChanges dinleyicisi, (4) güvenli rastgele misafir kimliği.
//
// Firebase gerçek örneği testte başlatılamadığı için Firebase yüzeyi
// fake'lerle değiştirilir:
// [AuthService.firebaseAuthOverrideForTest] + [AuthService.sendPasswordResetEmailForTest].
// [fb.FirebaseAuthException] kurucusu `@protected` olduğundan hata
// kodları [_TestAuthException] alt sınıfıyla üretilir.

/// [fb.FirebaseAuthException] kurucusu `@protected` olduğundan test
/// doğrudan üretemez; alt sınıf üzerinden kod üretilir.
class _TestAuthException extends fb.FirebaseAuthException {
  _TestAuthException(String code, [String? message])
      : super(code: code, message: message);
}

class _FakeUserCredential extends Fake implements fb.UserCredential {
  _FakeUserCredential(this.user);

  @override
  final fb.User? user;
}

class _FakeFirebaseUser extends Fake implements fb.User {
  _FakeFirebaseUser({
    required this.uid,
    this.isAnonymous = false,
    this.email,
  });

  @override
  String uid;
  @override
  bool isAnonymous;
  @override
  String? email;
  @override
  String? displayName;

  bool linkCalled = false;
  fb.AuthCredential? linkedCredential;
  Object? linkError;

  @override
  Future<fb.UserCredential> linkWithCredential(
    fb.AuthCredential credential,
  ) async {
    linkCalled = true;
    linkedCredential = credential;
    if (linkError != null) throw linkError!;
    isAnonymous = false;
    return _FakeUserCredential(this);
  }

  @override
  Future<void> updateDisplayName(String? name) async {
    displayName = name;
  }

  @override
  Future<void> delete() async {}
}

class _FakeFirebaseAuth extends Fake implements fb.FirebaseAuth {
  fb.User? currentUserOverride;
  final _authStateController = StreamController<fb.User?>.broadcast();

  _FakeFirebaseUser? userToReturn;
  bool signInAnonymouslyCalled = false;
  bool createUserCalled = false;
  bool signInEmailCalled = false;
  bool signInCredentialCalled = false;
  String? lastResetEmail;
  Object? resetError;

  @override
  fb.User? get currentUser => currentUserOverride;

  @override
  Stream<fb.User?> authStateChanges() => _authStateController.stream;

  void emitAuthState(fb.User? user) {
    currentUserOverride = user;
    _authStateController.add(user);
  }

  @override
  Future<fb.UserCredential> signInAnonymously() async {
    signInAnonymouslyCalled = true;
    currentUserOverride ??= _FakeFirebaseUser(
      uid: 'anon_${DateTime.now().millisecondsSinceEpoch}',
      isAnonymous: true,
    );
    return _FakeUserCredential(currentUserOverride!);
  }

  @override
  Future<fb.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createUserCalled = true;
    final created =
        userToReturn ?? _FakeFirebaseUser(uid: 'created_uid', email: email);
    currentUserOverride = created;
    return _FakeUserCredential(created);
  }

  @override
  Future<fb.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInEmailCalled = true;
    final signedIn =
        userToReturn ?? _FakeFirebaseUser(uid: 'signedin_uid', email: email);
    currentUserOverride = signedIn;
    return _FakeUserCredential(signedIn);
  }

  @override
  Future<fb.UserCredential> signInWithCredential(
    fb.AuthCredential credential,
  ) async {
    signInCredentialCalled = true;
    final signedIn =
        userToReturn ?? _FakeFirebaseUser(uid: 'credential_uid');
    currentUserOverride = signedIn;
    return _FakeUserCredential(signedIn);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    fb.ActionCodeSettings? actionCodeSettings,
  }) async {
    lastResetEmail = email;
    if (resetError != null) throw resetError!;
  }

  @override
  Future<void> signOut() async {
    currentUserOverride = null;
  }
}

Future<bool> _waitFor(
  bool Function() condition, {
  int timeoutMs = 3000,
}) async {
  final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return condition();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeFirebaseAuth fakeAuth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeAuth = _FakeFirebaseAuth();
    AuthService.firebaseAuthOverrideForTest = null;
    AuthService.sendPasswordResetEmailForTest = null;
    AuthService.instance.stopAuthStateListenerForTest();
    FirebaseBootstrap.resetForTest();
    await AuthService.instance.load();
    await AuthService.instance.signOut();
  });

  tearDown(() async {
    AuthService.instance.stopAuthStateListenerForTest();
    AuthService.firebaseAuthOverrideForTest = null;
    AuthService.sendPasswordResetEmailForTest = null;
    FirebaseBootstrap.resetForTest();
    await AuthService.instance.signOut();
  });

  /// Firebase hazır kipi: fake auth kancalanır, hazır bayrağı açılır
  /// (dinleyici fake akışa abone olur).
  void enableFakeFirebase() {
    AuthService.firebaseAuthOverrideForTest = fakeAuth;
    FirebaseBootstrap.isAvailable = true;
  }

  fb.AuthCredential emailCredential() =>
      fb.EmailAuthProvider.credential(
        email: 'link@example.com',
        password: 'secret123',
      );

  group('şifre sıfırlama', () {
    test('geçersiz e-posta ArgumentError verir', () async {
      await expectLater(
        () => AuthService.instance.requestPasswordReset('gecersiz'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Firebase hazır değilken bilinmeyen e-posta bulunamadı der',
        () async {
      await expectLater(
        () => AuthService.instance.requestPasswordReset('yok@example.com'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('bulunamadı'),
          ),
        ),
      );
    });

    test(
        'Firebase hazır değilken yerelde kayıtlı e-posta bulut bağlantısı ister',
        () async {
      final auth = AuthService.instance;
      await auth.register(
        username: 'resetuser1',
        password: 'secret123',
        email: 'reset1@example.com',
      );

      await expectLater(
        () => auth.requestPasswordReset('reset1@example.com'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('bulut'),
          ),
        ),
      );
    });

    test('Firebase hazırken e-posta normalize edilip gönderilir', () async {
      enableFakeFirebase();

      await AuthService.instance.requestPasswordReset('  RESET@Example.COM ');

      expect(fakeAuth.lastResetEmail, 'reset@example.com');
    });

    test('Firebase user-not-found bulunamadı StateError olur (kanca yolu)',
        () async {
      enableFakeFirebase();
      AuthService.sendPasswordResetEmailForTest = (_) async {
        throw _TestAuthException('user-not-found');
      };

      await expectLater(
        () => AuthService.instance.requestPasswordReset('yok@example.com'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('bulunamadı'),
          ),
        ),
      );
    });

    test('Firebase invalid-email ArgumentError olur', () async {
      enableFakeFirebase();
      fakeAuth.resetError = _TestAuthException('invalid-email');

      await expectLater(
        () =>
            AuthService.instance.requestPasswordReset('a@example.com'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Firebase too-many-requests bekleme StateError olur', () async {
      enableFakeFirebase();
      fakeAuth.resetError = _TestAuthException('too-many-requests');

      await expectLater(
        () =>
            AuthService.instance.requestPasswordReset('a@example.com'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('daha sonra'),
          ),
        ),
      );
    });
  });

  group('misafir→hesap link', () {
    test('anonim oturumda credential bağlanır, giriş çağrılmaz', () async {
      final anon = _FakeFirebaseUser(uid: 'anon_uid_1', isAnonymous: true);
      fakeAuth.currentUserOverride = anon;
      enableFakeFirebase();

      var fallbackCalled = false;
      final cred = await AuthService.instance.linkOrFallbackSignInForTest(
        emailCredential(),
        () async {
          fallbackCalled = true;
          return _FakeUserCredential(
            _FakeFirebaseUser(uid: 'fallback_uid'),
          );
        },
      );

      expect(cred.user?.uid, 'anon_uid_1');
      expect(anon.linkCalled, isTrue);
      expect(anon.linkedCredential, isNotNull);
      expect(fallbackCalled, isFalse);
      expect(anon.isAnonymous, isFalse);
    });

    test('bağlama credential-already-in-use ile başarısız olursa girişe düşer',
        () async {
      final anon = _FakeFirebaseUser(uid: 'anon_uid_2', isAnonymous: true);
      anon.linkError = _TestAuthException('credential-already-in-use');
      fakeAuth.currentUserOverride = anon;
      enableFakeFirebase();

      var fallbackCalled = false;
      final cred = await AuthService.instance.linkOrFallbackSignInForTest(
        emailCredential(),
        () async {
          fallbackCalled = true;
          return _FakeUserCredential(
            _FakeFirebaseUser(uid: 'fallback_uid'),
          );
        },
      );

      expect(anon.linkCalled, isTrue);
      expect(fallbackCalled, isTrue);
      expect(cred.user?.uid, 'fallback_uid');
    });

    test('anonim olmayan oturumda doğrudan giriş çalışır', () async {
      final signedIn =
          _FakeFirebaseUser(uid: 'user_uid', isAnonymous: false);
      fakeAuth.currentUserOverride = signedIn;
      enableFakeFirebase();

      var fallbackCalled = false;
      final cred = await AuthService.instance.linkOrFallbackSignInForTest(
        emailCredential(),
        () async {
          fallbackCalled = true;
          return _FakeUserCredential(
            _FakeFirebaseUser(uid: 'fallback_uid'),
          );
        },
      );

      expect(signedIn.linkCalled, isFalse);
      expect(fallbackCalled, isTrue);
      expect(cred.user?.uid, 'fallback_uid');
    });

    test('Firebase oturumu yokken doğrudan giriş çalışır', () async {
      fakeAuth.currentUserOverride = null;
      enableFakeFirebase();

      var fallbackCalled = false;
      final cred = await AuthService.instance.linkOrFallbackSignInForTest(
        emailCredential(),
        () async {
          fallbackCalled = true;
          return _FakeUserCredential(
            _FakeFirebaseUser(uid: 'fallback_uid'),
          );
        },
      );

      expect(fallbackCalled, isTrue);
      expect(cred.user?.uid, 'fallback_uid');
    });

    test('kayıt: anonim Firebase oturumu bağlanır, anonim UID korunur',
        () async {
      final anon = _FakeFirebaseUser(uid: 'anon_uid_123', isAnonymous: true);
      fakeAuth.currentUserOverride = anon;
      enableFakeFirebase();

      final auth = AuthService.instance;
      final created = await auth.register(
        username: 'linkreg1',
        password: 'secret123',
        email: 'linkreg1@example.com',
      );

      expect(created.id, 'anon_uid_123');
      expect(anon.linkCalled, isTrue);
      expect(fakeAuth.createUserCalled, isFalse);
      expect(auth.registeredAccounts.single.id, 'anon_uid_123');
      expect(auth.registeredAccounts.single.email, 'linkreg1@example.com');
    });

    test('kayıt: bağlama başarısız olursa createUser yoluna düşer',
        () async {
      final anon = _FakeFirebaseUser(uid: 'anon_uid_456', isAnonymous: true);
      anon.linkError = _TestAuthException('credential-already-in-use');
      fakeAuth.currentUserOverride = anon;
      fakeAuth.userToReturn =
          _FakeFirebaseUser(uid: 'created_uid_9', isAnonymous: false);
      enableFakeFirebase();

      final created = await AuthService.instance.register(
        username: 'linkreg2',
        password: 'secret123',
        email: 'linkreg2@example.com',
      );

      expect(created.id, 'created_uid_9');
      expect(anon.linkCalled, isTrue);
      expect(fakeAuth.createUserCalled, isTrue);
    });
  });

  group('auth durum dinleyicisi', () {
    test('Firebase hazır değilken dinleyici kurulmaz', () {
      expect(AuthService.instance.isAuthStateListenerActive, isFalse);
    });

    test('bilinen kullanıcı yok olunca misafire düşer', () async {
      final auth = AuthService.instance;
      final registered = await auth.register(
        username: 'handler1',
        password: 'secret123',
        email: 'handler1@example.com',
      );
      final fbUser =
          _FakeFirebaseUser(uid: registered.id, isAnonymous: false);

      await auth.handleFirebaseAuthStateChangeForTest(fbUser);
      expect(auth.isGuest, isFalse);
      await auth.handleFirebaseAuthStateChangeForTest(null);

      expect(auth.isGuest, isTrue);
      expect(auth.user?.provider, AuthProviderKind.guest);
      expect(
        auth.user?.id,
        matches(RegExp(r'^guest_[0-9a-f]{20}$')),
      );
    });

    test('açılıştaki ilk null olayı yoksayılır', () async {
      final auth = AuthService.instance;
      final registered = await auth.register(
        username: 'handler2',
        password: 'secret123',
        email: 'handler2@example.com',
      );

      await auth.handleFirebaseAuthStateChangeForTest(null);

      expect(auth.isGuest, isFalse);
      expect(auth.user?.id, registered.id);
    });

    test('başka UID\'ye geçiş misafire düşürür', () async {
      final auth = AuthService.instance;
      final registered = await auth.register(
        username: 'handler3',
        password: 'secret123',
        email: 'handler3@example.com',
      );

      await auth.handleFirebaseAuthStateChangeForTest(
        _FakeFirebaseUser(uid: registered.id, isAnonymous: false),
      );
      await auth.handleFirebaseAuthStateChangeForTest(
        _FakeFirebaseUser(uid: 'baska_uid', isAnonymous: false),
      );

      expect(auth.isGuest, isTrue);
    });

    test('misafir oturumu dış değişimden etkilenmez', () async {
      final auth = AuthService.instance;
      final guest = await auth.signInAsGuest();

      await auth.handleFirebaseAuthStateChangeForTest(
        _FakeFirebaseUser(uid: 'anon_x', isAnonymous: true),
      );
      await auth.handleFirebaseAuthStateChangeForTest(null);

      expect(auth.user?.id, guest.id);
      expect(auth.isGuest, isTrue);
    });

    test('oturum yokken null olayı etkisizdir', () async {
      final auth = AuthService.instance;

      await auth.handleFirebaseAuthStateChangeForTest(null);

      expect(auth.isSignedIn, isFalse);
    });

    test('gerçek dinleyici: akışta kullanıcı→yok geçişi misafire düşürür',
        () async {
      final auth = AuthService.instance;
      final registered = await auth.register(
        username: 'listener1',
        password: 'secret123',
        email: 'listener1@example.com',
      );
      final fbUser =
          _FakeFirebaseUser(uid: registered.id, isAnonymous: false);
      enableFakeFirebase();

      expect(auth.isAuthStateListenerActive, isTrue);
      fakeAuth.emitAuthState(fbUser);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      fakeAuth.emitAuthState(null);

      final fellBack = await _waitFor(() => auth.isGuest);
      expect(fellBack, isTrue);
      expect(auth.user?.provider, AuthProviderKind.guest);
    });
  });

  group('misafir kimliği', () {
    test('yeni misafir kimliği güvenli rastgele hex olur ve tekrarlanmaz',
        () async {
      final auth = AuthService.instance;
      final first = await auth.signInAsGuest();

      expect(first.id, matches(RegExp(r'^guest_[0-9a-f]{20}$')));
      expect(first.provider, AuthProviderKind.guest);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('LululuGuestIdV1');
      await prefs.remove('LululuAuthV1');
      final second = await auth.signInAsGuest();

      expect(second.id, matches(RegExp(r'^guest_[0-9a-f]{20}$')));
      expect(second.id, isNot(first.id));
    });

    test('kayıtlı misafir kimliği korunur', () async {
      SharedPreferences.setMockInitialValues({
        'LululuGuestIdV1': 'guest_0123456789abcdef0123',
      });
      final auth = AuthService.instance;
      await auth.load();

      final guest = await auth.signInAsGuest();

      expect(guest.id, 'guest_0123456789abcdef0123');
    });
  });
}
