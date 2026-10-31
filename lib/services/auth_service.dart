import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'firebase_bootstrap.dart';

enum AuthProviderKind { guest, apple, google, local }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.provider,
    this.email,
    this.username,
  });

  final String id;
  final String displayName;
  final AuthProviderKind provider;
  final String? email;
  final String? username;

  bool get isGuest => provider == AuthProviderKind.guest;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'provider': provider.name,
        'email': email,
        'username': username,
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final providerName = json['provider'] as String?;
    // Legacy "nick" sessions → local without password vault entry.
    final provider = providerName == 'nick'
        ? AuthProviderKind.local
        : AuthProviderKind.values.firstWhere(
            (p) => p.name == providerName,
            orElse: () => AuthProviderKind.guest,
          );
    return AuthUser(
      id: json['id'] as String? ?? 'guest',
      displayName: json['displayName'] as String? ?? 'Misafir',
      provider: provider,
      email: json['email'] as String?,
      username: json['username'] as String?,
    );
  }
}

class RegisteredAccount {
  const RegisteredAccount({
    required this.id,
    required this.username,
    required this.displayName,
    required this.salt,
    required this.passwordHash,
    required this.createdAtMs,
  });

  final String id;
  final String username;
  final String displayName;
  final String salt;
  final String passwordHash;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'salt': salt,
        'passwordHash': passwordHash,
        'createdAtMs': createdAtMs,
      };

  factory RegisteredAccount.fromJson(Map<String, dynamic> json) {
    return RegisteredAccount(
      id: json['id'] as String? ?? '',
      username: (json['username'] as String? ?? '').toLowerCase(),
      displayName: json['displayName'] as String? ?? '',
      salt: json['salt'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Local-first username+password auth; Apple/Google + Firebase when configured.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _sessionKey = 'LululuAuthV1';
  static const _accountsKey = 'LululuAccountsV1';
  static const _minPasswordLen = 4;
  static const _minUsernameLen = 3;
  static const _maxUsernameLen = 20;

  AuthUser? _user;
  bool _loaded = false;
  bool _googleReady = false;
  final Map<String, RegisteredAccount> _accounts = {};

  AuthUser? get user => _user;
  bool get isSignedIn => _user != null;
  String get displayName => _user?.displayName ?? 'Misafir';
  String get playerId => _user?.id ?? 'guest_local';
  List<RegisteredAccount> get registeredAccounts =>
      _accounts.values.toList(growable: false);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadAccounts(prefs);
    final raw = prefs.getString(_sessionKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _user = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _user = null;
      }
    } else {
      _user = null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadAccounts(SharedPreferences prefs) async {
    _accounts.clear();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        final acc =
            RegisteredAccount.fromJson(item as Map<String, dynamic>);
        if (acc.username.isNotEmpty && acc.id.isNotEmpty) {
          _accounts[acc.username] = acc;
        }
      }
    } catch (_) {
      _accounts.clear();
    }
  }

  Future<void> _persistAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _accounts.values.map((a) => a.toJson()).toList();
    await prefs.setString(_accountsKey, jsonEncode(list));
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, jsonEncode(_user!.toJson()));
    }
  }

  String _normalizeUsername(String raw) {
    return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  void _validateUsername(String username) {
    if (username.length < _minUsernameLen) {
      throw ArgumentError('Kullanıcı adı en az $_minUsernameLen karakter');
    }
    if (username.length > _maxUsernameLen) {
      throw ArgumentError('Kullanıcı adı en fazla $_maxUsernameLen karakter');
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
      throw ArgumentError(
        'Kullanıcı adı yalnızca a-z, 0-9 ve _ olabilir',
      );
    }
  }

  void _validatePassword(String password) {
    if (password.length < _minPasswordLen) {
      throw ArgumentError('Şifre en az $_minPasswordLen karakter');
    }
  }

  String _salt([int length = 16]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt::$password')).toString();
  }

  String _stableLocalId(String username) {
    final digest = sha256.convert(utf8.encode('lululu_user::$username'));
    return 'local_${digest.toString().substring(0, 24)}';
  }

  /// Synthetic email for Firebase email/password when only username is collected.
  String firebaseEmailForUsername(String username) =>
      '${_normalizeUsername(username)}@users.lululu.app';

  Future<void> _afterSignIn() async {
    await _persistSession();
    notifyListeners();
  }

  /// Register a durable username+password account (device vault + optional Firebase).
  Future<AuthUser> register({
    required String username,
    required String password,
    String? displayName,
  }) async {
    await ensureLoaded();
    final userKey = _normalizeUsername(username);
    _validateUsername(userKey);
    _validatePassword(password);

    if (_accounts.containsKey(userKey)) {
      throw StateError('Bu kullanıcı adı zaten kayıtlı — giriş yap');
    }

    final salt = _salt();
    final hash = _hashPassword(password, salt);
    final id = _stableLocalId(userKey);
    final shown = (displayName == null || displayName.trim().isEmpty)
        ? username.trim()
        : displayName.trim();

    var firebaseUid = id;
    await FirebaseBootstrap.ensureInitialized();
    if (FirebaseBootstrap.ready) {
      try {
        final cred = await fb.FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: firebaseEmailForUsername(userKey),
          password: password,
        );
        await cred.user?.updateDisplayName(shown);
        firebaseUid = cred.user?.uid ?? id;
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw StateError('Bu kullanıcı adı bulutta da kayıtlı — giriş yap');
        }
        debugPrint('[lululu] Firebase register: ${e.code} ${e.message}');
        // Continue with local vault — offline-first.
      } catch (e) {
        debugPrint('[lululu] Firebase register failed: $e');
      }
    }

    final account = RegisteredAccount(
      id: firebaseUid,
      username: userKey,
      displayName: shown,
      salt: salt,
      passwordHash: hash,
      createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    _accounts[userKey] = account;
    await _persistAccounts();

    _user = AuthUser(
      id: account.id,
      displayName: shown,
      provider: AuthProviderKind.local,
      email: firebaseEmailForUsername(userKey),
      username: userKey,
    );
    await _afterSignIn();
    return _user!;
  }

  /// Login with username+password against local vault (and Firebase if ready).
  Future<AuthUser> login({
    required String username,
    required String password,
  }) async {
    await ensureLoaded();
    final userKey = _normalizeUsername(username);
    _validateUsername(userKey);
    _validatePassword(password);

    final local = _accounts[userKey];
    if (local != null) {
      final hash = _hashPassword(password, local.salt);
      if (hash != local.passwordHash) {
        throw StateError('Şifre yanlış');
      }
      await FirebaseBootstrap.ensureInitialized();
      if (FirebaseBootstrap.ready) {
        try {
          await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
            email: firebaseEmailForUsername(userKey),
            password: password,
          );
        } catch (e) {
          debugPrint('[lululu] Firebase login (local ok): $e');
        }
      }
      _user = AuthUser(
        id: local.id,
        displayName: local.displayName,
        provider: AuthProviderKind.local,
        email: firebaseEmailForUsername(userKey),
        username: userKey,
      );
      await _afterSignIn();
      return _user!;
    }

    // No local account — try Firebase, then cache locally.
    await FirebaseBootstrap.ensureInitialized();
    if (FirebaseBootstrap.ready) {
      try {
        final cred = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: firebaseEmailForUsername(userKey),
          password: password,
        );
        final uid = cred.user?.uid ?? _stableLocalId(userKey);
        final shown = cred.user?.displayName?.trim().isNotEmpty == true
            ? cred.user!.displayName!.trim()
            : username.trim();
        final salt = _salt();
        final account = RegisteredAccount(
          id: uid,
          username: userKey,
          displayName: shown,
          salt: salt,
          passwordHash: _hashPassword(password, salt),
          createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        );
        _accounts[userKey] = account;
        await _persistAccounts();
        _user = AuthUser(
          id: uid,
          displayName: shown,
          provider: AuthProviderKind.local,
          email: firebaseEmailForUsername(userKey),
          username: userKey,
        );
        await _afterSignIn();
        return _user!;
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          throw StateError('Kullanıcı bulunamadı — önce kayıt ol');
        }
        if (e.code == 'wrong-password') {
          throw StateError('Şifre yanlış');
        }
        throw StateError('Giriş başarısız: ${e.message ?? e.code}');
      }
    }

    throw StateError('Kullanıcı bulunamadı — önce kayıt ol');
  }

  /// Back-compat: nickname without password is no longer enough.
  @Deprecated('Use register/login with password')
  Future<AuthUser> signInWithNick(String nickname) async {
    throw StateError('Takma ad yetmez — kullanıcı adı + şifre ile kayıt/giriş yap');
  }

  Future<AuthUser> signInAsGuest({String? nickname}) async {
    final name = (nickname == null || nickname.trim().isEmpty)
        ? 'Misafir'
        : nickname.trim();
    _user = AuthUser(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      displayName: name,
      provider: AuthProviderKind.guest,
    );
    await _afterSignIn();
    return _user!;
  }

  String _nonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256of(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<AuthUser> signInWithApple() async {
    await FirebaseBootstrap.ensureInitialized();
    final rawNonce = _nonce();
    final hashed = _sha256of(rawNonce);

    AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashed,
      );
    } catch (e) {
      debugPrint('[lululu] Apple Sign In fallback: $e');
      _user = AuthUser(
        id: 'apple_local_${DateTime.now().millisecondsSinceEpoch}',
        displayName: 'Apple Oyuncu',
        provider: AuthProviderKind.apple,
      );
      await _afterSignIn();
      return _user!;
    }

    final given = credential.givenName;
    final family = credential.familyName;
    final composed = [
      if (given != null && given.isNotEmpty) given,
      if (family != null && family.isNotEmpty) family,
    ].join(' ');
    final display = composed.isEmpty ? 'Apple Oyuncu' : composed;
    final idToken = credential.identityToken;
    final stableId = idToken != null && idToken.isNotEmpty
        ? 'apple_${_sha256of(idToken).substring(0, 24)}'
        : 'apple_${credential.userIdentifier ?? DateTime.now().millisecondsSinceEpoch}';

    if (FirebaseBootstrap.ready && idToken != null) {
      try {
        final oauth = fb.OAuthProvider('apple.com').credential(
          idToken: idToken,
          rawNonce: rawNonce,
        );
        final cred = await fb.FirebaseAuth.instance.signInWithCredential(oauth);
        _user = AuthUser(
          id: cred.user?.uid ?? stableId,
          displayName: cred.user?.displayName ?? display,
          provider: AuthProviderKind.apple,
          email: cred.user?.email ?? credential.email,
        );
        await _afterSignIn();
        return _user!;
      } catch (e) {
        debugPrint('[lululu] Firebase Apple link failed: $e');
      }
    }

    _user = AuthUser(
      id: stableId,
      displayName: display,
      provider: AuthProviderKind.apple,
      email: credential.email,
    );
    await _afterSignIn();
    return _user!;
  }

  Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  Future<AuthUser> signInWithGoogle() async {
    await FirebaseBootstrap.ensureInitialized();
    try {
      await _ensureGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      final stableId = 'google_${account.id}';

      if (FirebaseBootstrap.ready && idToken != null) {
        try {
          final cred = fb.GoogleAuthProvider.credential(idToken: idToken);
          final userCred =
              await fb.FirebaseAuth.instance.signInWithCredential(cred);
          _user = AuthUser(
            id: userCred.user?.uid ?? stableId,
            displayName:
                userCred.user?.displayName ?? account.displayName ?? 'Google',
            provider: AuthProviderKind.google,
            email: userCred.user?.email ?? account.email,
          );
          await _afterSignIn();
          return _user!;
        } catch (e) {
          debugPrint('[lululu] Firebase Google link failed: $e');
        }
      }

      _user = AuthUser(
        id: stableId,
        displayName: account.displayName ?? 'Google Oyuncu',
        provider: AuthProviderKind.google,
        email: account.email,
      );
      await _afterSignIn();
      return _user!;
    } catch (e) {
      debugPrint('[lululu] Google Sign In fallback: $e');
      _user = AuthUser(
        id: 'google_local_${DateTime.now().millisecondsSinceEpoch}',
        displayName: 'Google Oyuncu',
        provider: AuthProviderKind.google,
      );
      await _afterSignIn();
      return _user!;
    }
  }

  Future<void> updateDisplayName(String name) async {
    if (_user == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final username = _user!.username;
    _user = AuthUser(
      id: _user!.id,
      displayName: trimmed,
      provider: _user!.provider,
      email: _user!.email,
      username: username,
    );
    if (username != null && _accounts.containsKey(username)) {
      final old = _accounts[username]!;
      _accounts[username] = RegisteredAccount(
        id: old.id,
        username: old.username,
        displayName: trimmed,
        salt: old.salt,
        passwordHash: old.passwordHash,
        createdAtMs: old.createdAtMs,
      );
      await _persistAccounts();
    }
    await _persistSession();
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      if (FirebaseBootstrap.ready) {
        await fb.FirebaseAuth.instance.signOut();
      }
      if (_googleReady) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    _user = null;
    await _persistSession();
    notifyListeners();
  }
}
