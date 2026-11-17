import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'cloud_sync_service.dart';
import 'firebase_bootstrap.dart';
import 'leaderboard_service.dart';
import 'progress_manager.dart';

enum AuthProviderKind { guest, apple, google, local, email }

class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.provider,
    this.email,
    this.username,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final AuthProviderKind provider;
  final String? email;
  final String? username;
  final String? avatarUrl;

  String get uid => id;
  bool get isSignedIn => id.isNotEmpty;
  bool get isGuest => provider == AuthProviderKind.guest;

  String get providerLabel => switch (provider) {
        AuthProviderKind.apple => 'Apple ile giriş yapıldı',
        AuthProviderKind.google => 'Google ile giriş yapıldı',
        AuthProviderKind.guest => 'Misafir oturumu',
        AuthProviderKind.local ||
        AuthProviderKind.email =>
          'Hesap ile giriş yapıldı',
      };

  AuthUser copyWith({
    String? id,
    String? displayName,
    AuthProviderKind? provider,
    String? email,
    String? username,
    String? avatarUrl,
  }) {
    return AuthUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      provider: provider ?? this.provider,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'uid': id,
        'displayName': displayName,
        'provider': provider.name,
        'email': email,
        'username': username,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
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
      id: json['id'] as String? ?? json['uid'] as String? ?? 'guest',
      displayName: json['displayName'] as String? ?? 'Misafir',
      provider: provider,
      email: json['email'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
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
    this.email,
  });

  final String id;
  final String username;
  final String displayName;
  final String salt;
  final String passwordHash;
  final int createdAtMs;
  final String? email;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'displayName': displayName,
        'salt': salt,
        'passwordHash': passwordHash,
        'createdAtMs': createdAtMs,
        if (email != null) 'email': email,
      };

  factory RegisteredAccount.fromJson(Map<String, dynamic> json) {
    return RegisteredAccount(
      id: json['id'] as String? ?? '',
      username: (json['username'] as String? ?? '').toLowerCase(),
      displayName: json['displayName'] as String? ?? '',
      salt: json['salt'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      email: json['email'] as String?,
    );
  }
}

/// Snapshot of guest progress captured before account registration or linking.
class _GuestProgressSnapshot {
  const _GuestProgressSnapshot({
    required this.previousGuestId,
    required this.includeInMemoryScores,
    required this.coins,
    required this.unlockedLevel,
    required this.slipperCount,
    required this.sprayCount,
    required this.aydinlatCount,
    required this.streak,
    required this.hasRoyalCape,
    required this.ownedCosmetics,
    required this.unlockedTiers,
    required this.modeHighScores,
    required this.extraPowers,
  });

  final String previousGuestId;
  final bool includeInMemoryScores;
  final int coins;
  final int unlockedLevel;
  final int slipperCount;
  final int sprayCount;
  final int aydinlatCount;
  final int streak;
  final bool hasRoyalCape;
  final Set<String> ownedCosmetics;
  final Set<int> unlockedTiers;
  final Map<String, int> modeHighScores;
  final Map<String, int> extraPowers;
}

/// Offline-First + Cloud-Ready AuthService:
/// Supports Email/Password, Username/Password, Guest Session, Google Sign-In,
/// Sign In with Apple, Username/DisplayName updates, and session persistence
/// (`SharedPreferences` + `FirebaseAuth`).
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _sessionKey = 'LululuAuthV1';
  // TODO(güvenlik, ayrı görev): Yerel hesap kasası (hash + salt) hâlen
  // SharedPreferences'te şifresiz duruyor. flutter_secure_storage'a taşıma
  // bu değişikliğin kapsamı dışındadır; bağımlılık eklenmedi.
  static const _localAccountsKey = 'LululuAccountsV1';
  static const _guestIdKey = 'LululuGuestIdV1';
  // Yeni kayıtlar için asgari şifre uzunluğu. Girişte (login) asgari uzunluk
  // dayatılmaz: eski kısa şifreli hesaplar giriş yapabilmeli ve hash'leri
  // başarılı girişte yeni biçime yükseltilmelidir.
  static const _minPasswordLen = 6;
  static const _maxPasswordLen = 128;
  static const _minUsernameLen = 3;
  static const _maxUsernameLen = 20;
  // Yeni hash'ler 10000 iterasyonla üretilir. Eski kayıtlar 1000 iterasyonla
  // üretildi; _legacyPbkdf2Prefix ile tanınır, eski parametreyle doğrulanır
  // ve başarılı girişte yeni biçime yükseltilir (bkz. _verifyAccountPassword).
  static const _pbkdf2Iterations = 10000;
  static const _legacyPbkdf2Iterations = 1000;
  static const _pbkdf2Prefix = 'pbkdf2_sha256\$$_pbkdf2Iterations\$';
  static const _legacyPbkdf2Prefix =
      'pbkdf2_sha256\$$_legacyPbkdf2Iterations\$';
  static const int maxFailedLoginAttempts = 5;
  static const int baseLockoutDurationMs = 15000;
  static const int maxLockoutDurationMs = 300000;

  static final RegExp _controlCharsRegex = RegExp(r'[\x00-\x1F\x7F]');

  AuthUser? _user;
  bool _loaded = false;
  bool _googleReady = false;
  final Map<String, RegisteredAccount> _accounts = {};
  final Map<String, int> _failedLoginAttempts = {};
  final Map<String, int> _loginLockoutUntilMs = {};
  final ValueNotifier<AuthUser?> userNotifier = ValueNotifier<AuthUser?>(null);

  AuthUser? get user => _user;
  AuthUser? get currentUser => _user;
  ValueNotifier<AuthUser?> get currentUserNotifier => userNotifier;
  bool get isSignedIn => _user != null;
  bool get isGuest => _user?.isGuest ?? true;
  AuthProviderKind get provider => _user?.provider ?? AuthProviderKind.guest;
  String get providerLabel =>
      _user?.providerLabel ?? 'Misafir oturumu';
  String get displayName => _user?.displayName ?? 'Misafir';
  String get username => _user?.username ?? displayName.toLowerCase();
  String? get email => _user?.email;
  String get playerId => _user?.id ?? 'guest_local';
  List<RegisteredAccount> get registeredAccounts =>
      _accounts.values.toList(growable: false);

  /// Returns consecutive failed login count for [usernameOrEmail].
  int failedAttemptsFor(String usernameOrEmail) {
    final key = _normalizeUsername(usernameOrEmail);
    return _failedLoginAttempts[key] ?? 0;
  }

  /// Clears brute-force counters (for testing or administrative reset).
  void resetLoginRateLimit([String? usernameOrEmail]) {
    if (usernameOrEmail == null) {
      _failedLoginAttempts.clear();
      _loginLockoutUntilMs.clear();
      return;
    }
    final key = _normalizeUsername(usernameOrEmail);
    _failedLoginAttempts.remove(key);
    _loginLockoutUntilMs.remove(key);
  }

  void _setUser(AuthUser? next) {
    _user = next;
    userNotifier.value = next;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    resetLoginRateLimit();
    final prefs = await SharedPreferences.getInstance();
    await _loadAccounts(prefs);
    final raw = prefs.getString(_sessionKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _setUser(AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        _setUser(null);
      }
    } else if (FirebaseBootstrap.isAvailable) {
      try {
        final fbUser = fb.FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final isAnon = fbUser.isAnonymous;
          _setUser(
            AuthUser(
              id: fbUser.uid,
              displayName: fbUser.displayName?.trim().isNotEmpty == true
                  ? fbUser.displayName!.trim()
                  : (isAnon ? 'Misafir' : 'Oyuncu'),
              provider: isAnon ? AuthProviderKind.guest : AuthProviderKind.local,
              email: fbUser.email,
              username: fbUser.email?.split('@').first,
            ),
          );
          await _persistSession();
        } else {
          _setUser(null);
        }
      } catch (_) {
        _setUser(null);
      }
    } else {
      _setUser(null);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadAccounts(SharedPreferences prefs) async {
    _accounts.clear();
    final raw = prefs.getString(_localAccountsKey);
    if (raw == null || raw.isEmpty) return;
    var migratedAny = false;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        var acc = RegisteredAccount.fromJson(item);
        // Upgrade any legacy record that stored a plaintext 'password' or lacked a salt.
        final legacyPlain = item['password'] as String?;
        if ((acc.passwordHash.isEmpty || acc.salt.isEmpty) &&
            legacyPlain != null &&
            legacyPlain.isNotEmpty) {
          final freshSalt = _salt();
          acc = RegisteredAccount(
            id: acc.id.isNotEmpty ? acc.id : _stableLocalId(acc.username),
            username: acc.username,
            displayName: acc.displayName,
            salt: freshSalt,
            passwordHash: _hashPassword(legacyPlain, freshSalt),
            createdAtMs: acc.createdAtMs,
            email: acc.email,
          );
          migratedAny = true;
        }
        if (acc.username.isNotEmpty &&
            acc.id.isNotEmpty &&
            acc.passwordHash.isNotEmpty) {
          _accounts[acc.username] = acc;
        }
      }
      if (migratedAny) {
        await _persistAccounts();
      }
    } catch (_) {
      _accounts.clear();
    }
  }

  Future<void> _persistAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _accounts.values.map((a) => a.toJson()).toList();
    await prefs.setString(_localAccountsKey, jsonEncode(list));
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_user == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, jsonEncode(_user!.toJson()));
    }
  }

  String _sanitizeInput(String raw, {String fieldLabel = 'Girdi'}) {
    if (_controlCharsRegex.hasMatch(raw)) {
      throw ArgumentError('$fieldLabel geçersiz kontrol karakteri içeriyor');
    }
    return raw.trim();
  }

  String _normalizeUsername(String raw) {
    final cleaned = raw.replaceAll(_controlCharsRegex, '').trim().toLowerCase();
    if (cleaned.contains('@')) {
      final localPart = cleaned.split('@').first;
      return localPart
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
    }
    return cleaned.replaceAll(RegExp(r'\s+'), '_');
  }

  void _validateUsername(String username) {
    if (_controlCharsRegex.hasMatch(username)) {
      throw ArgumentError('Kullanıcı adı geçersiz karakter içeriyor');
    }
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

  void _validateEmail(String email) {
    final trimmed = _sanitizeInput(email, fieldLabel: 'E-posta');
    if (trimmed.isEmpty ||
        trimmed.length > 254 ||
        !trimmed.contains('@') ||
        !trimmed.contains('.') ||
        trimmed.startsWith('@') ||
        trimmed.endsWith('@')) {
      throw ArgumentError('Geçerli bir e-posta adresi girin');
    }
  }

  void _validatePassword(String password) {
    if (_controlCharsRegex.hasMatch(password)) {
      throw ArgumentError('Şifre geçersiz kontrol karakteri içeremez');
    }
    if (password.trim().length < _minPasswordLen ||
        password.length < _minPasswordLen) {
      throw ArgumentError('Şifre en az $_minPasswordLen karakter');
    }
    if (password.length > _maxPasswordLen) {
      throw ArgumentError('Şifre en fazla $_maxPasswordLen karakter');
    }
  }

  String _salt([int length = 24]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Iterative PBKDF2-HMAC-SHA256 password derivation with cryptographic salt.
  ///
  /// Yeni hash'ler her zaman güncel iterasyon sayısıyla üretilir ve sonuç
  /// sürüm etiketli biçimdedir: `pbkdf2_sha256$<iterasyon>$<hex>`.
  String _hashPassword(String password, String salt) =>
      _hashPasswordWithIterations(password, salt, _pbkdf2Iterations);

  String _hashPasswordWithIterations(
    String password,
    String salt,
    int iterations,
  ) {
    final keyBytes = utf8.encode(password);
    final saltBytes = utf8.encode('lululu_vault_v2::$salt');
    final hmac = Hmac(sha256, keyBytes);

    // PBKDF2 block 1 (INT_32_BE(1) appended to saltBytes)
    final initialInput = <int>[...saltBytes, 0, 0, 0, 1];
    var u = hmac.convert(initialInput).bytes;
    final derived = List<int>.from(u);

    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < derived.length; j++) {
        derived[j] ^= u[j];
      }
    }

    final hex = derived.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'pbkdf2_sha256\$${iterations}\$$hex';
  }

  /// Kayıtlı hash'in hangi iterasyon sayısıyla üretildiğini önekten okur.
  /// Yalnızca bilinen iki sürüm tanınır (güncel + eski); bilinmeyen önek
  /// `null` döner ve doğrulama eski SHA-256 yollarına düşer (eşleşmez).
  static int? _pbkdf2IterationsOf(String stored) {
    if (stored.startsWith(_pbkdf2Prefix)) return _pbkdf2Iterations;
    if (stored.startsWith(_legacyPbkdf2Prefix)) {
      return _legacyPbkdf2Iterations;
    }
    return null;
  }

  /// Legacy v1 single-pass SHA-256 hash for backward compatibility before upgrade.
  String _legacyHashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt::$password')).toString();
  }

  /// Constant-time string comparison to mitigate timing side-channel attacks.
  bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    var diff = aBytes.length ^ bBytes.length;
    final maxLen = max(aBytes.length, bBytes.length);
    for (var i = 0; i < maxLen; i++) {
      final byteA = i < aBytes.length ? aBytes[i] : 0;
      final byteB = i < bBytes.length ? bBytes[i] : 0;
      diff |= byteA ^ byteB;
    }
    return diff == 0;
  }

  /// Verifies password against stored account hash (PBKDF2 v2 or legacy v1)
  /// in constant time, and reports whether the stored record should be upgraded.
  ///
  /// PBKDF2 hash'ler önekteki sürüm/iterasyon bilgisiyle, üretildikleri
  /// parametreyle doğrulanır; eski parametreli hash eşleşirse `needsUpgrade`
  /// true döner ve çağıran (login) başarılı girişte kaydı yeni biçime
  /// yükseltir. Yeni parametreyle üretilmiş hash için yükseltme gerekmez.
  ({bool matches, bool needsUpgrade}) _verifyAccountPassword(
    String password,
    RegisteredAccount account,
  ) {
    final stored = account.passwordHash;
    final storedIterations = _pbkdf2IterationsOf(stored);
    if (storedIterations != null && account.salt.isNotEmpty) {
      final candidate = _hashPasswordWithIterations(
        password,
        account.salt,
        storedIterations,
      );
      final matches = _constantTimeEquals(candidate, stored);
      return (
        matches: matches,
        needsUpgrade: matches && storedIterations != _pbkdf2Iterations,
      );
    }

    // Legacy v1 salted SHA-256 ('salt::password')
    if (account.salt.isNotEmpty) {
      final legacyCandidate = _legacyHashPassword(password, account.salt);
      if (_constantTimeEquals(legacyCandidate, stored)) {
        return (matches: true, needsUpgrade: true);
      }
    }

    // Legacy unsalted SHA-256 or raw fallback
    final rawSha = _sha256of(password);
    if (_constantTimeEquals(rawSha, stored) ||
        _constantTimeEquals(password, stored)) {
      return (matches: true, needsUpgrade: true);
    }

    return (matches: false, needsUpgrade: false);
  }

  void _enforceLoginRateLimit(String userKey) {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final lockedUntil = _loginLockoutUntilMs[userKey];
    if (lockedUntil != null) {
      if (nowMs < lockedUntil) {
        final remainingSec = ((lockedUntil - nowMs) / 1000).ceil();
        throw StateError(
          'Çok fazla başarısız giriş denemesi. Lütfen $remainingSec sn bekleyin',
        );
      }
      _loginLockoutUntilMs.remove(userKey);
    }
  }

  void _recordFailedLoginAttempt(String userKey) {
    final attempts = (_failedLoginAttempts[userKey] ?? 0) + 1;
    _failedLoginAttempts[userKey] = attempts;
    if (attempts >= maxFailedLoginAttempts) {
      final extra = attempts - maxFailedLoginAttempts;
      final multiplier = 1 << extra.clamp(0, 4);
      final duration =
          (baseLockoutDurationMs * multiplier).clamp(
            baseLockoutDurationMs,
            maxLockoutDurationMs,
          );
      _loginLockoutUntilMs[userKey] =
          DateTime.now().toUtc().millisecondsSinceEpoch + duration;
    }
  }

  void _clearFailedLoginAttempts(String userKey) {
    _failedLoginAttempts.remove(userKey);
    _loginLockoutUntilMs.remove(userKey);
  }

  Future<_GuestProgressSnapshot?> _captureGuestProgressBeforeLink() async {
    // Link guest progress when upgrading from an active guest session,
    // or when registering the very first account on this device,
    // or if there are guest leaderboard scores waiting to be claimed.
    final wasActiveGuest = _user != null && _user!.isGuest;
    final isFirstAccountOnDevice = _accounts.isEmpty && _user == null;
    final previousGuestId = wasActiveGuest
        ? _user!.id
        : 'guest_local';

    final pm = ProgressManager();
    final prefs = await SharedPreferences.getInstance();

    final prefsCoins = prefs.getInt('lululu_coins') ??
        prefs.getInt('LululuCoinBalance') ??
        ProgressManager.defaultCoins;
    final prefsLevel =
        (prefs.getInt('lululu_unlocked_level') ?? 1)
            .clamp(1, ProgressManager.maxCampaignLevels);
    final prefsSpray =
        prefs.getInt('lululu_spray') ?? prefs.getInt('lululu_raid') ?? 3;
    final prefsSlipper =
        prefs.getInt('lululu_slipper') ?? prefs.getInt('lululu_terlik') ?? 5;
    final prefsAydinlat =
        prefs.getInt('lululu_aydinlat') ?? prefs.getInt('lululu_f16') ?? 2;
    final prefsStreak = prefs.getInt('lululu_daily_streak') ?? 1;
    final prefsRoyalCape = prefs.getBool('lululu_royal_cape') ?? false;
    final prefsCosmetics =
        prefs.getStringList('lululu_owned_cosmetics') ?? const <String>[];
    final prefsTiers =
        prefs.getStringList('lululu_unlocked_tiers') ?? const <String>[];

    final mergedTiers = <int>{...pm.unlockedTiers};
    for (final rawTier in prefsTiers) {
      final parsed = int.tryParse(rawTier);
      if (parsed != null && parsed >= 1) {
        mergedTiers.add(parsed);
      }
    }

    final mergedModeScores = <String, int>{};
    if (wasActiveGuest || isFirstAccountOnDevice) {
      mergedModeScores.addAll(pm.modeHighScores);
      final rawScores = prefs.getString('lululu_mode_high_scores');
      if (rawScores != null && rawScores.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawScores) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            final key = ProgressManager.normalizeModeId(k);
            final val = (v as num?)?.toInt() ?? 0;
            if (val > (mergedModeScores[key] ?? 0)) {
              mergedModeScores[key] = val;
            }
          });
        } catch (_) {}
      }
    }

    return _GuestProgressSnapshot(
      previousGuestId: previousGuestId,
      includeInMemoryScores: wasActiveGuest || isFirstAccountOnDevice,
      coins: max(pm.coins, prefsCoins),
      unlockedLevel: max(pm.unlockedLevel, prefsLevel),
      slipperCount: max(pm.slipperCount, prefsSlipper),
      sprayCount: max(pm.sprayCount, prefsSpray),
      aydinlatCount: max(pm.aydinlatCount, prefsAydinlat),
      streak: max(pm.streak, prefsStreak),
      hasRoyalCape: pm.hasRoyalCape || prefsRoyalCape,
      ownedCosmetics: <String>{...pm.ownedCosmetics, ...prefsCosmetics},
      unlockedTiers: mergedTiers,
      modeHighScores: mergedModeScores,
      extraPowers: Map<String, int>.from(pm.extraPowers),
    );
  }

  Future<void> _mergeGuestProgressIntoAccount(
    _GuestProgressSnapshot? snapshot,
  ) async {
    if (snapshot == null || _user == null || _user!.isGuest) return;
    final targetUid = _user!.id;
    final targetName = _user!.displayName;
    final pm = ProgressManager();
    final prefs = await SharedPreferences.getInstance();

    if (snapshot.includeInMemoryScores) {
      pm.coins = max(pm.coins, snapshot.coins);
      pm.unlockedLevel = max(pm.unlockedLevel, snapshot.unlockedLevel)
          .clamp(1, ProgressManager.maxCampaignLevels);
      pm.slipperCount = max(pm.slipperCount, snapshot.slipperCount);
      pm.sprayCount = max(pm.sprayCount, snapshot.sprayCount);
      pm.aydinlatCount = max(pm.aydinlatCount, snapshot.aydinlatCount);
      pm.streak = max(pm.streak, snapshot.streak);
      if (snapshot.hasRoyalCape) {
        pm.hasRoyalCape = true;
        pm.ownedCosmetics.add('royal_cape');
      }
      pm.ownedCosmetics.addAll(snapshot.ownedCosmetics);
      pm.unlockedTiers.addAll(snapshot.unlockedTiers);
      snapshot.extraPowers.forEach((k, v) {
        if (v > (pm.extraPowers[k] ?? 0)) {
          pm.extraPowers[k] = v;
        }
      });

      await prefs.setInt('lululu_coins', pm.coins);
      await prefs.setInt('LululuCoinBalance', pm.coins);
      await prefs.setInt('lululu_unlocked_level', pm.unlockedLevel);
      await prefs.setInt('lululu_spray', pm.sprayCount);
      await prefs.setInt('lululu_raid', pm.sprayCount);
      await prefs.setInt('lululu_slipper', pm.slipperCount);
      await prefs.setInt('lululu_terlik', pm.slipperCount);
      await prefs.setInt('lululu_aydinlat', pm.aydinlatCount);
      await prefs.setInt('lululu_f16', pm.aydinlatCount);
      await prefs.setInt('lululu_daily_streak', pm.streak);
      await prefs.setBool('lululu_royal_cape', pm.hasRoyalCape);
      await prefs.setStringList(
        'lululu_owned_cosmetics',
        pm.ownedCosmetics.toList(),
      );
      await prefs.setStringList(
        'lululu_unlocked_tiers',
        pm.unlockedTiers.map((e) => e.toString()).toList(),
      );
      await prefs.setString('lululu_extra_powers', jsonEncode(pm.extraPowers));
    }

    // Rebind guest entries in LeaderboardService if any exist for guest_local / previousGuestId
    final storedGuestId = prefs.getString(_guestIdKey) ?? '';
    bool isGuestId(String pid) {
      if (pid.isEmpty) return snapshot.includeInMemoryScores;
      return pid == 'guest_local' ||
          pid == 'guest' ||
          pid == snapshot.previousGuestId ||
          (storedGuestId.isNotEmpty && pid == storedGuestId) ||
          pid.startsWith('guest_');
    }

    final rawBoard = prefs.getString(LeaderboardService.prefsKey);
    var boardUpdated = false;
    if (rawBoard != null && rawBoard.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBoard) as Map<String, dynamic>;
        final modes = (decoded['modes'] as List<dynamic>? ?? <dynamic>[]);
        for (final modeObj in modes) {
          if (modeObj is! Map<String, dynamic>) continue;
          final modeId = LeaderboardService.normalizeModeId(
            modeObj['modeId'] as String? ?? '',
          );
          final top = (modeObj['top'] as List<dynamic>? ?? <dynamic>[]);
          Map<String, dynamic>? targetEntry;
          var bestGuestScore = 0;
          final toRemove = <Map<String, dynamic>>[];

          for (final item in top) {
            if (item is! Map<String, dynamic>) continue;
            final pid = item['playerId'] as String? ?? '';
            final sc = (item['score'] as num?)?.toInt() ?? 0;
            if (pid == targetUid) {
              targetEntry = item;
            } else if (isGuestId(pid)) {
              if (sc > bestGuestScore) bestGuestScore = sc;
              toRemove.add(item);
            }
          }

          if (bestGuestScore > 0 || toRemove.isNotEmpty) {
            boardUpdated = true;
            for (final rem in toRemove) {
              top.remove(rem);
            }
            if (targetEntry != null) {
              final cur = (targetEntry['score'] as num?)?.toInt() ?? 0;
              if (bestGuestScore > cur) {
                targetEntry['score'] = bestGuestScore;
              }
              targetEntry['playerName'] = targetName;
              targetEntry['isLocalPlayer'] = true;
            } else if (bestGuestScore > 0) {
              top.add(<String, dynamic>{
                'modeId': modeId,
                'playerId': targetUid,
                'playerName': targetName,
                'score': bestGuestScore,
                'utcTicks': DateTime.now().toUtc().millisecondsSinceEpoch,
                'isLocalPlayer': true,
                'country': 'TR',
              });
            }
            if (bestGuestScore > (pm.modeHighScores[modeId] ?? 0)) {
              pm.modeHighScores[modeId] = bestGuestScore;
            }
          }
        }
        if (boardUpdated) {
          await prefs.setString(
            LeaderboardService.prefsKey,
            jsonEncode(decoded),
          );
          await LeaderboardService.instance.load();
        }
      } catch (_) {}
    }

    if (snapshot.includeInMemoryScores && snapshot.modeHighScores.isNotEmpty) {
      for (final entry in snapshot.modeHighScores.entries) {
        if (entry.value > 0) {
          final canonical = ProgressManager.normalizeModeId(entry.key);
          if (entry.value > (pm.modeHighScores[canonical] ?? 0)) {
            pm.modeHighScores[canonical] = entry.value;
          }
          if (entry.value > LeaderboardService.instance.getBest(canonical)) {
            await LeaderboardService.instance.submitScore(
              canonical,
              entry.value,
              playerName: targetName,
            );
          }
        }
      }
      await prefs.setString(
        'lululu_mode_high_scores',
        jsonEncode(pm.modeHighScores),
      );
    }

    await CloudSyncService.instance.enableOnlineWhenSignedIn();
    await CloudSyncService.instance.enqueueProgressPush();
    if (boardUpdated || snapshot.modeHighScores.isNotEmpty) {
      await CloudSyncService.instance.enqueueLeaderboardPush();
    }
  }

  String _stableLocalId(String username) {
    final digest = sha256.convert(utf8.encode('lululu_user::$username'));
    return 'local_${digest.toString().substring(0, 24)}';
  }

  /// Synthetic email for Firebase email/password when only username is collected.
  String firebaseEmailForUsername(String username) {
    final trimmed = username.trim().toLowerCase();
    if (trimmed.contains('@')) return trimmed;
    return '${_normalizeUsername(username)}@users.lululu.app';
  }

  Future<void> _afterSignIn() async {
    await _persistSession();
    notifyListeners();
  }

  /// Register with explicit email and password.
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    String? username,
    String? displayName,
  }) async {
    _validateEmail(email);
    final normalizedEmail = email.trim().toLowerCase();
    final derivedUser = (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : normalizedEmail.split('@').first;
    return register(
      username: derivedUser,
      password: password,
      displayName: displayName ?? derivedUser,
      email: normalizedEmail,
    );
  }

  /// Sign in with explicit email and password.
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _validateEmail(email);
    final normalizedEmail = email.trim().toLowerCase();
    // Look up by email first if registered locally.
    for (final acc in _accounts.values) {
      if (acc.email?.toLowerCase() == normalizedEmail) {
        return login(username: acc.username, password: password);
      }
    }
    return login(
      username: normalizedEmail.split('@').first,
      password: password,
      emailOverride: normalizedEmail,
    );
  }

  /// Register a durable username+password (or email+password) account
  /// (device vault + optional Firebase Auth).
  Future<AuthUser> register({
    required String username,
    required String password,
    String? displayName,
    String? email,
  }) async {
    await ensureLoaded();
    final rawTrimmed = _sanitizeInput(username, fieldLabel: 'Kullanıcı adı');
    final isEmailInput = rawTrimmed.contains('@');
    if (email != null && email.trim().isNotEmpty) {
      _validateEmail(email);
    }
    final resolvedEmail = (email != null && email.trim().isNotEmpty)
        ? _sanitizeInput(email, fieldLabel: 'E-posta').toLowerCase()
        : (isEmailInput
            ? rawTrimmed.toLowerCase()
            : firebaseEmailForUsername(rawTrimmed));
    final userKey = _normalizeUsername(rawTrimmed);
    _validateUsername(userKey);
    _validatePassword(password);

    if (_accounts.containsKey(userKey)) {
      throw StateError('Bu kullanıcı adı zaten kayıtlı — giriş yap');
    }

    final guestSnapshot = await _captureGuestProgressBeforeLink();

    final salt = _salt();
    final hash = _hashPassword(password, salt);
    final id = _stableLocalId(userKey);
    final sanitizedDisplay = displayName != null
        ? _sanitizeInput(displayName, fieldLabel: 'Görünen ad')
        : '';
    final shown = sanitizedDisplay.isEmpty
        ? (isEmailInput ? userKey : rawTrimmed)
        : sanitizedDisplay;

    var firebaseUid = id;
    await FirebaseBootstrap.ensureInitialized();
    if (FirebaseBootstrap.ready) {
      try {
        final cred = await fb.FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: resolvedEmail,
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
      email: resolvedEmail,
    );
    _accounts[userKey] = account;
    await _persistAccounts();
    _clearFailedLoginAttempts(userKey);

    _setUser(
      AuthUser(
        id: account.id,
        displayName: shown,
        provider: AuthProviderKind.local,
        email: resolvedEmail,
        username: userKey,
      ),
    );
    await _mergeGuestProgressIntoAccount(guestSnapshot);
    await _afterSignIn();
    return _user!;
  }

  /// Login with username+password (or email+password) against local vault
  /// and Firebase Auth if available.
  Future<AuthUser> login({
    required String username,
    required String password,
    String? emailOverride,
  }) async {
    await ensureLoaded();
    final rawTrimmed = _sanitizeInput(username, fieldLabel: 'Kullanıcı adı');
    final isEmailInput = rawTrimmed.contains('@');
    final userKey = _normalizeUsername(rawTrimmed);
    _validateUsername(userKey);
    _enforceLoginRateLimit(userKey);
    if (_controlCharsRegex.hasMatch(password)) {
      _recordFailedLoginAttempt(userKey);
      throw ArgumentError('Şifre geçersiz kontrol karakteri içeremez');
    }
    if (password.isEmpty || password.length > _maxPasswordLen) {
      _recordFailedLoginAttempt(userKey);
      throw StateError('Şifre yanlış');
    }

    RegisteredAccount? local = _accounts[userKey];
    if (local == null && isEmailInput) {
      final lowerEmail = rawTrimmed.toLowerCase();
      for (final acc in _accounts.values) {
        if (acc.email?.toLowerCase() == lowerEmail) {
          local = acc;
          break;
        }
      }
    }

    final authEmail = emailOverride ??
        local?.email ??
        (isEmailInput
            ? rawTrimmed.toLowerCase()
            : firebaseEmailForUsername(userKey));

    if (local != null) {
      _enforceLoginRateLimit(local.username);
      final verification = _verifyAccountPassword(password, local);
      if (!verification.matches) {
        _recordFailedLoginAttempt(userKey);
        if (local.username != userKey) {
          _recordFailedLoginAttempt(local.username);
        }
        throw StateError('Şifre yanlış');
      }
      _clearFailedLoginAttempts(userKey);
      _clearFailedLoginAttempts(local.username);

      var resolvedAccount = local;
      if (verification.needsUpgrade) {
        final newSalt = _salt();
        resolvedAccount = RegisteredAccount(
          id: local.id,
          username: local.username,
          displayName: local.displayName,
          salt: newSalt,
          passwordHash: _hashPassword(password, newSalt),
          createdAtMs: local.createdAtMs,
          email: local.email,
        );
        _accounts[local.username] = resolvedAccount;
        await _persistAccounts();
      }

      await FirebaseBootstrap.ensureInitialized();
      if (FirebaseBootstrap.ready) {
        try {
          await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
            email: authEmail,
            password: password,
          );
        } catch (e) {
          debugPrint('[lululu] Firebase login (local ok): $e');
        }
      }
      _setUser(
        AuthUser(
          id: resolvedAccount.id,
          displayName: resolvedAccount.displayName,
          provider: AuthProviderKind.local,
          email: authEmail,
          username: resolvedAccount.username,
        ),
      );
      await _afterSignIn();
      return _user!;
    }

    // No local account — try Firebase, then cache locally.
    await FirebaseBootstrap.ensureInitialized();
    if (FirebaseBootstrap.ready) {
      try {
        final cred = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
          email: authEmail,
          password: password,
        );
        final uid = cred.user?.uid ?? _stableLocalId(userKey);
        final shown = cred.user?.displayName?.trim().isNotEmpty == true
            ? cred.user!.displayName!.trim()
            : (isEmailInput ? userKey : rawTrimmed);
        final salt = _salt();
        final account = RegisteredAccount(
          id: uid,
          username: userKey,
          displayName: shown,
          salt: salt,
          passwordHash: _hashPassword(password, salt),
          createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          email: authEmail,
        );
        _accounts[userKey] = account;
        await _persistAccounts();
        _clearFailedLoginAttempts(userKey);
        _setUser(
          AuthUser(
            id: uid,
            displayName: shown,
            provider: AuthProviderKind.local,
            email: authEmail,
            username: userKey,
          ),
        );
        await _afterSignIn();
        return _user!;
      } on fb.FirebaseAuthException catch (e) {
        _recordFailedLoginAttempt(userKey);
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          throw StateError('Kullanıcı bulunamadı — önce kayıt ol');
        }
        if (e.code == 'wrong-password') {
          throw StateError('Şifre yanlış');
        }
        throw StateError('Giriş başarısız: ${e.message ?? e.code}');
      }
    }

    _recordFailedLoginAttempt(userKey);
    throw StateError('Kullanıcı bulunamadı — önce kayıt ol');
  }

  /// Starts or restores a persistent guest player session.
  Future<AuthUser> signInAsGuest({String? nickname}) async {
    await ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    var guestId = prefs.getString(_guestIdKey) ?? '';
    if (guestId.isEmpty) {
      guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_guestIdKey, guestId);
    }

    await FirebaseBootstrap.ensureInitialized();
    if (FirebaseBootstrap.ready) {
      try {
        final cred = await fb.FirebaseAuth.instance.signInAnonymously();
        if (cred.user?.uid != null && cred.user!.uid.isNotEmpty) {
          guestId = cred.user!.uid;
          await prefs.setString(_guestIdKey, guestId);
        }
      } catch (e) {
        debugPrint('[lululu] Firebase anonymous sign-in fallback: $e');
      }
    }

    final sanitizedNick = nickname != null
        ? _sanitizeInput(nickname, fieldLabel: 'Takma ad')
        : '';
    final name = sanitizedNick.isEmpty ? 'Misafir' : sanitizedNick;
    _setUser(
      AuthUser(
        id: guestId,
        displayName: name,
        provider: AuthProviderKind.guest,
        username: _normalizeUsername(name),
      ),
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
    await ensureLoaded();
    final guestSnapshot = await _captureGuestProgressBeforeLink();
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
      _setUser(
        AuthUser(
          id: 'apple_local_${DateTime.now().millisecondsSinceEpoch}',
          displayName: 'Apple Oyuncu',
          provider: AuthProviderKind.apple,
          username: 'apple_oyuncu',
        ),
      );
      await _mergeGuestProgressIntoAccount(guestSnapshot);
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
        final cred =
            await fb.FirebaseAuth.instance.signInWithCredential(oauth);
        _setUser(
          AuthUser(
            id: cred.user?.uid ?? stableId,
            displayName: cred.user?.displayName ?? display,
            provider: AuthProviderKind.apple,
            email: cred.user?.email ?? credential.email,
            username: _normalizeUsername(display),
          ),
        );
        await _mergeGuestProgressIntoAccount(guestSnapshot);
        await _afterSignIn();
        return _user!;
      } catch (e) {
        debugPrint('[lululu] Firebase Apple link failed: $e');
      }
    }

    _setUser(
      AuthUser(
        id: stableId,
        displayName: display,
        provider: AuthProviderKind.apple,
        email: credential.email,
        username: _normalizeUsername(display),
      ),
    );
    await _mergeGuestProgressIntoAccount(guestSnapshot);
    await _afterSignIn();
    return _user!;
  }

  Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize();
    _googleReady = true;
  }

  Future<AuthUser> signInWithGoogle() async {
    await ensureLoaded();
    final guestSnapshot = await _captureGuestProgressBeforeLink();
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
          final resolvedName = userCred.user?.displayName ??
              account.displayName ??
              'Google Oyuncu';
          _setUser(
            AuthUser(
              id: userCred.user?.uid ?? stableId,
              displayName: resolvedName,
              provider: AuthProviderKind.google,
              email: userCred.user?.email ?? account.email,
              username: _normalizeUsername(resolvedName),
            ),
          );
          await _mergeGuestProgressIntoAccount(guestSnapshot);
          await _afterSignIn();
          return _user!;
        } catch (e) {
          debugPrint('[lululu] Firebase Google link failed: $e');
        }
      }

      final fallbackName = account.displayName ?? 'Google Oyuncu';
      _setUser(
        AuthUser(
          id: stableId,
          displayName: fallbackName,
          provider: AuthProviderKind.google,
          email: account.email,
          username: _normalizeUsername(fallbackName),
        ),
      );
      await _mergeGuestProgressIntoAccount(guestSnapshot);
      await _afterSignIn();
      return _user!;
    } catch (e) {
      debugPrint('[lululu] Google Sign In fallback: $e');
      _setUser(
        AuthUser(
          id: 'google_local_${DateTime.now().millisecondsSinceEpoch}',
          displayName: 'Google Oyuncu',
          provider: AuthProviderKind.google,
          username: 'google_oyuncu',
        ),
      );
      await _mergeGuestProgressIntoAccount(guestSnapshot);
      await _afterSignIn();
      return _user!;
    }
  }

  /// Updates the signed-in user's display name locally and in Firebase Auth.
  Future<void> updateDisplayName(String name) async {
    await ensureLoaded();
    if (_user == null) return;
    final trimmed = _sanitizeInput(name, fieldLabel: 'Görünen ad');
    if (trimmed.isEmpty) return;
    final currentUsername = _user!.username;
    _setUser(
      _user!.copyWith(
        displayName: trimmed,
        username: currentUsername,
      ),
    );
    if (currentUsername != null && _accounts.containsKey(currentUsername)) {
      final old = _accounts[currentUsername]!;
      _accounts[currentUsername] = RegisteredAccount(
        id: old.id,
        username: old.username,
        displayName: trimmed,
        salt: old.salt,
        passwordHash: old.passwordHash,
        createdAtMs: old.createdAtMs,
        email: old.email,
      );
      await _persistAccounts();
    }
    if (FirebaseBootstrap.ready) {
      try {
        await fb.FirebaseAuth.instance.currentUser?.updateDisplayName(trimmed);
      } catch (e) {
        debugPrint('[lululu] Firebase updateDisplayName error: $e');
      }
    }
    await _persistSession();
    notifyListeners();
  }

  /// Oturumu açık hesabın YEREL kaydını siler ve oturumu kapatır.
  ///
  /// Cihazda yapılanlar:
  /// * Hesap, yerel hesap kasasından ([_localAccountsKey]) çıkarılır ve
  ///   kalan hesaplar kalıcı hâle getirilir — cihazdaki diğer hesaplara
  ///   dokunulmaz. Sosyal girişlerde (Apple/Google) kasa kaydı olmayabilir;
  ///   o durumda yalnız oturum silinir.
  /// * Silinen hesabın başarısız-giriş sayaçları temizlenir.
  /// * [signOut] ile oturum kapatılır (Firebase + Google oturum sonlandırma
  ///   ve oturum anahtarının silinmesi).
  /// * [CloudSyncService.enableOnlineWhenSignedIn] yeniden değerlendirilir:
  ///   kimse oturumda olmayınca çevrimiçi eşitleme kapanır, bekleyen kuyruk
  ///   gönderilmez.
  ///
  /// Yapılmayanlar — sunucu tarafı silme uç noktası YOK:
  /// TODO(hesap-silme, sunucu): Firebase Auth kullanıcısı ile Firestore
  /// `players`/skor/sohbet verilerinin silinmesi için backend uç noktası
  /// (örn. Cloud Function + yeniden kimlik doğrulama akışı) gerekir. Bu
  /// sürümde bulut kopyaları silinmez; aynı e-postayla yeniden kayıt,
  /// Firebase'te `email-already-in-use` ile reddedilebilir.
  ///
  /// TODO(hesap-silme, yerel-temizlik): ProgressManager, LeaderboardService,
  /// ChatService ve CloudSyncService'te herkese açık bir temizleme/sıfırlama
  /// API'si YOK (2026-11-18, salt okuma: reset/clear/deleteAll araması 0
  /// sonuç verdi). Bu servisler temizleme API'si kazanınca bu metot o
  /// API'leri çağırmalıdır; o güne kadar cihaz içi ilerleme/liderlik/sohbet
  /// kayıtları ayrıca "İlerlemeyi Sıfırla" ile temizlenebilir.
  ///
  /// Oturum açık değilse veya oturum misafir oturumuysa [StateError] fırlatır
  /// (misafirlerin silinecek hesap kaydı yoktur).
  Future<void> deleteAccount() async {
    await ensureLoaded();
    final current = _user;
    if (current == null) {
      throw StateError('Oturum açık değil — silinecek hesap yok');
    }
    if (current.isGuest) {
      throw StateError('Misafir oturumunda silinecek hesap yok');
    }
    final usernameKey = current.username;
    final accountId = current.id;
    final vaultKeys = _accounts.entries
        .where(
          (entry) =>
              (usernameKey != null && entry.key == usernameKey) ||
              entry.value.id == accountId,
        )
        .map((entry) => entry.key)
        .toList();
    for (final key in vaultKeys) {
      _accounts.remove(key);
      _clearFailedLoginAttempts(key);
    }
    if (vaultKeys.isNotEmpty) {
      await _persistAccounts();
    }
    await signOut();
    await CloudSyncService.instance.enableOnlineWhenSignedIn();
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
    _setUser(null);
    await _persistSession();
    notifyListeners();
  }
}
