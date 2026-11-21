import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'achievement_pass_service.dart';
import 'adaptive_difficulty_service.dart';
import 'bug_video_service.dart';
import 'campaign_progression_service.dart';
import 'chat_service.dart';
import 'cloud_sync_service.dart';
import 'daily_challenge_service.dart';
import 'energy_service.dart';
import 'firebase_bootstrap.dart';
import 'leaderboard_service.dart';
import 'online_notify_service.dart';
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

/// Kullanıcı, Apple/Google giriş sayfasını onaylamadan kapattı.
/// Çağırıcılar bu türü sessizce yutabilir (hata iletisi göstermeden);
/// sağlayıcı hataları ise [StateError] olarak görünür iletilir.
/// Mevcut çağırıcılar (auth_screen/auth_panel) genel `catch` ile
/// [toString] çıktısını gösterir; ileti bu yüzden nötr tutulur.
class AuthSignInCancelledException implements Exception {
  const AuthSignInCancelledException({required this.provider});

  final AuthProviderKind provider;

  String get message => 'Giriş iptal edildi';

  @override
  String toString() => message;
}

/// [AuthService.deleteAccount] özeti: hesabın silindiğini ve hangi
/// temizlik adımlarının başarısız olduğunu çağırıcıya bildirir.
/// Fırlatma yoksa hesap silinmiştir; listedeki adımlar kısmi
/// temizliktir (kalan yerel/bulut artığı olabilir). Çağırıcı UI'ı
/// Faz 2'de bu sonuca bağlanacak; bu dosyada yalnız sözleşme hazır.
/// `requires-recent-login` durumunda metot fırlatır, sonuç dönmez
/// (o durumda hiçbir şey silinmemiştir, yerel veri korunur).
class AccountDeletionResult {
  const AccountDeletionResult({
    required this.failedLocalCleanups,
    required this.failedCloudCleanups,
    required this.cloudDeletionAttempted,
  });

  /// Başarısız yerel temizlik adımları (servis adları).
  final List<String> failedLocalCleanups;

  /// Başarısız bulut temizlik adımları (servis/adım adları).
  final List<String> failedCloudCleanups;

  /// Bulut silme denendi mi (Firebase hazır + Firebase oturumu var).
  final bool cloudDeletionAttempted;

  bool get hasFailures =>
      failedLocalCleanups.isNotEmpty || failedCloudCleanups.isNotEmpty;

  bool get success => !hasFailures;
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
  AuthService._() {
    // Firebase oturum dinleyicisi: Firebase hazır olduğu an kurulur
    // (bkz. [_ensureAuthStateListener]); hazır olma anı
    // [FirebaseBootstrap.availableNotifier] üzerinden izlenir.
    FirebaseBootstrap.availableNotifier.addListener(
      _onFirebaseAvailabilityChanged,
    );
    if (FirebaseBootstrap.isAvailable) {
      _ensureAuthStateListener();
    }
  }
  static final AuthService instance = AuthService._();

  static const _sessionKey = 'LululuAuthV1';
  // TODO(güvenlik, ayrı görev): Yerel hesap kasası (hash + salt) hâlen
  // SharedPreferences'te şifresiz duruyor. flutter_secure_storage'a taşıma
  // bu değişikliğin kapsamı dışındadır; bağımlılık eklenmedi.
  static const _localAccountsKey = 'LululuAccountsV1';
  static const _guestIdKey = 'LululuGuestIdV1';

  /// O9: kaba-kuvvet sayaçları + kilit bitiş damgaları
  /// (`{'attempts': {kullanıcı: sayı}, 'locks': {kullanıcı: bitişMs}}`).
  /// Bellek-içi sayaçlar uygulama yeniden başlayınca sıfırlanıyordu;
  /// kilit durumu artık kalıcıdır, [_loadAsync] geri yükler.
  static const _rateLimitKey = 'LululuLoginRateLimitV1';

  /// O11: Firebase kaydı başarısız olup yalnız yerel kasaya yazılan
  /// hesapların kullanıcı adları (JSON liste). Girişte uzlaştırma
  /// denenir; başarılı uzlaştırmada kayıttan çıkarılır.
  static const _pendingFirebaseSyncKey = 'LululuPendingFirebaseSyncV1';

  /// Misafir kimliği -> hesap UID eşlemesi (JSON harita): misafir
  /// giriş yaptığında göç kaydı buraya yazılır. Göçün tek seferlik
  /// olduğunun kanıtı (idempotency işareti) ve sohbet engel/rapor
  /// çözümlemesinin kaynağıdır. [ChatService] buradan okur.
  static const guestIdentityLinksKey = 'LululuGuestIdentityLinksV1';
  // Yeni kayıtlar için asgari şifre uzunluğu. Girişte (login) asgari uzunluk
  // dayatılmaz: eski kısa şifreli hesaplar giriş yapabilmeli ve hash'leri
  // başarılı girişte yeni biçime yükseltilmelidir.
  static const _minPasswordLen = 6;
  static const _maxPasswordLen = 128;
  static const _minUsernameLen = 3;
  static const _maxUsernameLen = 20;
  // K3: kural displayName/authorName 1..32 ister (firestore.rules:301,
  // profil displayName 1..32). Görünen ad bu sınırı aşamaz.
  static const _maxDisplayNameLen = 32;
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

  /// Devam eden `load()` çağrısı (uçuş koruması): eşzamanlı
  /// `load()`/`ensureLoaded()` çağrıları aynı yüklemeyi paylaşır.
  Future<void>? _loadFuture;
  bool _googleReady = false;
  final Map<String, RegisteredAccount> _accounts = {};
  final Map<String, int> _failedLoginAttempts = {};
  final Map<String, int> _loginLockoutUntilMs = {};
  final Set<String> _pendingFirebaseSync = {};
  bool _lastRegistrationLocalOnly = false;
  String? _lastRegistrationFirebaseError;
  final ValueNotifier<AuthUser?> userNotifier = ValueNotifier<AuthUser?>(null);

  /// YALNIZCA TEST: ayarlıysa Firebase çağrıları gerçek
  /// [fb.FirebaseAuth.instance] yerine bu örneği kullanır (fake ile
  /// link akışı testi için). Üretimde `null` kalır.
  @visibleForTesting
  static fb.FirebaseAuth? firebaseAuthOverrideForTest;

  /// YALNIZCA TEST: ayarlıysa [requestPasswordReset] Firebase hazır
  /// yolunda gerçek `sendPasswordResetEmail` yerine bu göndericiyi
  /// çağırır (hata eşlemesi testi için). Üretimde `null` kalır.
  @visibleForTesting
  static Future<void> Function(String email)? sendPasswordResetEmailForTest;

  /// Firebase Auth durum dinleyicisi aboneliği (yalnız Firebase
  /// hazırsa kurulur; bkz. [_ensureAuthStateListener]).
  StreamSubscription<fb.User?>? _authStateSubscription;

  /// Dinleyici bu oturumda Firebase kullanıcısı gördü mü?
  /// Açılıştaki geçici `null` olayı (henüz geri yüklenmemiş oturum)
  /// geçersiz sayılmaz — yalnız kullanıcı→yok geçişi misafire düşürür.
  bool _sawFirebaseUser = false;

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

  /// O11: Firebase kaydı başarısız olduğu için yalnız yerel kasada
  /// duran hesapların kullanıcı adları (uzlaştırma bekleyenler).
  Set<String> get pendingFirebaseSyncUsernames =>
      Set<String>.unmodifiable(_pendingFirebaseSync);

  /// O11: son [register] çağrısında Firebase kaydı başarısız olup
  /// hesap yalnız yerel kasaya yazıldıysa true. Çağırıcı, kayıt
  /// başarısından sonra bunu okuyup kullanıcıya bildirebilir
  /// (hesap bu cihazda oluşturuldu; bulut eşitlemesi bir sonraki
  /// girişte denenecek). Firebase hiç denenmediyse (hazır değil)
  /// false'tur — o durumda yerel-öncelikli kayıt beklenen kip'tir.
  bool get lastRegistrationWasLocalOnly => _lastRegistrationLocalOnly;

  /// O11: son kaydın Firebase hata kodu (yalnız
  /// [lastRegistrationWasLocalOnly] true ise anlamlıdır).
  String? get lastRegistrationFirebaseError => _lastRegistrationFirebaseError;

  /// Returns consecutive failed login count for [usernameOrEmail].
  int failedAttemptsFor(String usernameOrEmail) {
    final key = _normalizeUsername(usernameOrEmail);
    return _failedLoginAttempts[key] ?? 0;
  }

  /// Clears brute-force counters (for testing or administrative reset).
  /// O9: kalıcı kopya da güncellenir — sıfırlama yeniden başlatmada
  /// geri gelmez.
  void resetLoginRateLimit([String? usernameOrEmail]) {
    if (usernameOrEmail == null) {
      _failedLoginAttempts.clear();
      _loginLockoutUntilMs.clear();
    } else {
      final key = _normalizeUsername(usernameOrEmail);
      _failedLoginAttempts.remove(key);
      _loginLockoutUntilMs.remove(key);
    }
    unawaited(_persistLoginRateLimit());
  }

  void _setUser(AuthUser? next) {
    // K3: görünen ad tek huniden geçer — 32 karakteri aşan ad (kayıtlı
    // eski oturum, sosyal giriş, Firebase adı) burada sessizce kısalır;
    // hiçbir yoldan uzun ad buluta çıkamaz (kesme, reddetme yok).
    final clamped = next == null || next.displayName.length <= _maxDisplayNameLen
        ? next
        : next.copyWith(displayName: _clampDisplayName(next.displayName));
    _user = clamped;
    userNotifier.value = clamped;
  }

  /// K3: görünen ad kelepçesi — `firestore.rules` displayName/authorName
  /// 1..32 ister. Ad nerede belirlenirse belirlensin 32 karaktere sessizce
  /// kısaltılır (red yok); kontrol karakterleri atılır, kırpılır, boşsa
  /// 'Oyuncu' döner. [CloudSyncService.sanitizeDisplayName] ile aynı sınır.
  static String _clampDisplayName(String raw) {
    final safe = raw.replaceAll(_controlCharsRegex, '').trim();
    if (safe.isEmpty) return 'Oyuncu';
    return safe.length > _maxDisplayNameLen
        ? safe.substring(0, _maxDisplayNameLen)
        : safe;
  }

  /// Test kancası varsa onu, yoksa gerçek FirebaseAuth örneğini döner.
  fb.FirebaseAuth get _firebaseAuth =>
      firebaseAuthOverrideForTest ?? fb.FirebaseAuth.instance;

  /// Firebase hazırsa o anki Firebase kullanıcısı, değilse `null`.
  /// Gerçek örnek yokken (test ortamı) fırlatmaz.
  fb.User? _currentFirebaseUser() {
    if (!FirebaseBootstrap.ready) return null;
    try {
      return _firebaseAuth.currentUser;
    } catch (_) {
      return null;
    }
  }

  void _onFirebaseAvailabilityChanged() {
    if (FirebaseBootstrap.isAvailable) {
      _ensureAuthStateListener();
    } else {
      _stopAuthStateListener();
    }
  }

  /// Firebase Auth durum dinleyicisini kurar (tek seferlik).
  /// Firebase hazır değilse veya akış açılamazsa sessizce kurumsuz
  /// kalır (yerel-öncelikli kip bozulmaz).
  void _ensureAuthStateListener() {
    if (_authStateSubscription != null) return;
    if (!FirebaseBootstrap.isAvailable) return;
    try {
      _authStateSubscription = _firebaseAuth.authStateChanges().listen(
        _onFirebaseAuthStateChanged,
        onError: (_) {},
      );
    } catch (_) {
      _authStateSubscription = null;
    }
  }

  void _stopAuthStateListener() {
    unawaited(_authStateSubscription?.cancel());
    _authStateSubscription = null;
    _sawFirebaseUser = false;
  }

  /// YALNIZCA TEST: dinleyici aktif mi?
  @visibleForTesting
  bool get isAuthStateListenerActive => _authStateSubscription != null;

  /// YALNIZCA TEST: dinleyiciyi durdurur (test izolasyonu).
  @visibleForTesting
  void stopAuthStateListenerForTest() => _stopAuthStateListener();

  void _onFirebaseAuthStateChanged(fb.User? fbUser) {
    unawaited(_handleFirebaseAuthStateChange(fbUser));
  }

  /// Firebase oturumu dışarıdan değiştiğinde (token iptali, başka
  /// cihazda silme) uygulama oturumunu düzeltir: kayıtlı oturum
  /// varken Firebase kullanıcısı yok olmuşsa veya başka bir
  /// kullanıcıya dönmüşse misafir oturumuna düşülür. Misafir
  /// oturumu ve oturumsuz hâl etkilenmez (yerel misafir sürer).
  /// Açılıştaki ilk `null` olayı yoksayılır (oturum henüz
  /// geri yüklenmemiş olabilir) — yalnız kullanıcı→yok geçişi
  /// geçersiz sayılır.
  Future<void> _handleFirebaseAuthStateChange(fb.User? fbUser) async {
    final firebaseUid = fbUser?.uid;
    final hadKnownUser = _sawFirebaseUser;
    _sawFirebaseUser = firebaseUid != null;
    final current = _user;
    if (current == null || current.isGuest) return;
    if (!hadKnownUser) return;
    final invalidated =
        firebaseUid == null ||
            (!fbUser!.isAnonymous && firebaseUid != current.id);
    if (!invalidated) return;
    debugPrint(
      '[lululu] Firebase oturumu dışarıdan geçersiz kılındı — misafire düşülüyor',
    );
    await _fallBackToGuest();
  }

  /// YALNIZCA TEST: dış Firebase durum değişimini doğrudan işletir
  /// (dinleyici akışı olmadan).
  @visibleForTesting
  Future<void> handleFirebaseAuthStateChangeForTest(fb.User? fbUser) =>
      _handleFirebaseAuthStateChange(fbUser);

  /// Kayıtlı oturumu düşürüp kalıcı misafir oturumuna döner
  /// (misafir kimliği korunur, yoksa güvenli rastgele üretilir).
  Future<void> _fallBackToGuest() async {
    final prefs = await SharedPreferences.getInstance();
    var guestId = prefs.getString(_guestIdKey) ?? '';
    if (guestId.isEmpty) {
      guestId = _newGuestId();
      await prefs.setString(_guestIdKey, guestId);
    }
    _setUser(
      AuthUser(
        id: guestId,
        displayName: 'Misafir',
        provider: AuthProviderKind.guest,
        username: _normalizeUsername('Misafir'),
      ),
    );
    await _persistSession();
    // K1 (W60-6): misafire düşünce sohbet bulut dinlemesi kapatılır
    // (eski kimlikle reddedilen okuma denemesi yapmasın).
    ChatService.instance.refreshCloudBinding();
    notifyListeners();
  }

  /// Yeni misafir kimliği: `guest_` + 20 kriptografik rastgele hex.
  /// ChatService kural deseniyle (`^guest_[0-9a-f]{8,64}$`) uyumludur.
  /// Yalnız YENİ misafirlerde üretilir; kayıtlı kimliklere dokunulmaz.
  static String _newGuestId() {
    final random = Random.secure();
    const hex = '0123456789abcdef';
    final suffix =
        List.generate(20, (_) => hex[random.nextInt(hex.length)]).join();
    return 'guest_$suffix';
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Kalıcı oturumu yükler. Eşzamanlı çağrılar aynı yüklemeyi
  /// paylaşır (uçuş koruması); yükleme bittikten sonra yeniden
  /// çağrılırsa prefs'ten tekrar okur (yeniden yükleme korunur).
  Future<void> load() async {
    final inFlight = _loadFuture;
    if (inFlight != null) return inFlight;
    final future = _loadAsync();
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    // O9: hız sınırı sıfırlanmaz, kalıcı hâlden geri yüklenir —
    // yeniden başlatma kilidi/sayacı silmez.
    _restoreLoginRateLimit(prefs);
    _loadPendingFirebaseSync(prefs);
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
        final fbUser = _firebaseAuth.currentUser;
        if (fbUser != null) {
          final isAnon = fbUser.isAnonymous;
          _setUser(
            AuthUser(
              id: fbUser.uid,
              displayName: _clampDisplayName(
                fbUser.displayName?.trim().isNotEmpty == true
                    ? fbUser.displayName!.trim()
                    : (isAnon ? 'Misafir' : 'Oyuncu'),
              ),
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
      unawaited(_persistLoginRateLimit());
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
    unawaited(_persistLoginRateLimit());
  }

  void _clearFailedLoginAttempts(String userKey) {
    final hadAttempts = _failedLoginAttempts.remove(userKey) != null;
    final hadLock = _loginLockoutUntilMs.remove(userKey) != null;
    if (hadAttempts || hadLock) {
      unawaited(_persistLoginRateLimit());
    }
  }

  /// O9: kalıcı hız sınırı durumunu bellek-içi haritalara yükler.
  /// Haritalar kalıcı hâlden atanır (birleştirilmez): boş kalıcı hâl
  /// eski bellek durumunu temizler (test izolasyonu + taze kurulum).
  /// Süresi dolmuş kilitler atılır; sayaçlar korunur (kilit bitince
  /// yeni başarısız deneme, eskiden olduğu gibi katlanan kilit kurar).
  void _restoreLoginRateLimit(SharedPreferences prefs) {
    _failedLoginAttempts.clear();
    _loginLockoutUntilMs.clear();
    final raw = prefs.getString(_rateLimitKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final attempts = decoded['attempts'];
      if (attempts is Map<String, dynamic>) {
        attempts.forEach((key, value) {
          final count = (value as num?)?.toInt() ?? 0;
          if (key.isNotEmpty && count > 0) {
            _failedLoginAttempts[key] = count;
          }
        });
      }
      final locks = decoded['locks'];
      if (locks is Map<String, dynamic>) {
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        var prunedAny = false;
        locks.forEach((key, value) {
          final untilMs = (value as num?)?.toInt() ?? 0;
          if (key.isEmpty || untilMs <= 0) return;
          if (untilMs > nowMs) {
            _loginLockoutUntilMs[key] = untilMs;
          } else {
            prunedAny = true;
          }
        });
        if (prunedAny) {
          unawaited(_persistLoginRateLimit());
        }
      }
    } catch (_) {
      _failedLoginAttempts.clear();
      _loginLockoutUntilMs.clear();
    }
  }

  /// O9: hız sınırı durumunu kalıcı yazar. Best-effort: yazım
  /// başarısızlığı giriş akışını bozmaz (bellek-içi hâl geçerlidir).
  Future<void> _persistLoginRateLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_failedLoginAttempts.isEmpty && _loginLockoutUntilMs.isEmpty) {
        await prefs.remove(_rateLimitKey);
        return;
      }
      await prefs.setString(
        _rateLimitKey,
        jsonEncode({
          'attempts': _failedLoginAttempts,
          'locks': _loginLockoutUntilMs,
        }),
      );
    } catch (e) {
      debugPrint('[lululu] rate-limit persist failed: $e');
    }
  }

  /// O11: uzlaştırma bekleyen kullanıcı adlarını kalıcı hâlden yükler.
  void _loadPendingFirebaseSync(SharedPreferences prefs) {
    _pendingFirebaseSync.clear();
    final raw = prefs.getString(_pendingFirebaseSyncKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final item in decoded) {
        if (item is String && item.isNotEmpty) {
          _pendingFirebaseSync.add(item);
        }
      }
    } catch (_) {
      _pendingFirebaseSync.clear();
    }
  }

  /// O11: uzlaştırma bekleyen listesini kalıcı yazar (best-effort).
  Future<void> _persistPendingFirebaseSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_pendingFirebaseSync.isEmpty) {
        await prefs.remove(_pendingFirebaseSyncKey);
        return;
      }
      await prefs.setString(
        _pendingFirebaseSyncKey,
        jsonEncode(_pendingFirebaseSync.toList()),
      );
    } catch (e) {
      debugPrint('[lululu] pending Firebase sync persist failed: $e');
    }
  }

  /// Misafir kimliği -> hesap UID eşlemesini okur (göç kayıtları).
  Future<Map<String, String>> guestIdentityLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(guestIdentityLinksKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final out = <String, String>{};
      decoded.forEach((key, value) {
        if (value is String && value.isNotEmpty) out[key] = value;
      });
      return out;
    } catch (_) {
      return <String, String>{};
    }
  }

  /// Misafir kimliğini hesaba bağlar (kalıcı eşleme). Göç kaydıdır:
  /// aynı misafir kimliği daha önce başka bir hesaba bağlanmışsa ilk
  /// kayıt korunur (üzerine yazılmaz); aynı eşlemenin tekrarı
  /// değişim yapmaz (idempotent).
  Future<void> recordGuestIdentityLink(String guestId, String uid) async {
    if (guestId.isEmpty || uid.isEmpty) return;
    final links = await guestIdentityLinks();
    if (links.containsKey(guestId)) return;
    links[guestId] = uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(guestIdentityLinksKey, jsonEncode(links));
    // Bulut kopyası (best-effort, bekletmez): hesap silmede eski
    // misafir mesajlarının silinebilmesi için kuralların okuduğu
    // `guest_identity_links/{guestId}` belgesi.
    unawaited(
      ChatService.instance.recordGuestIdentityLinkCloud(guestId, uid),
    );
  }

  /// Hesaba bağlı misafir kimliklerinin eşlemelerini siler (hesap
  /// silmede kullanılır; göç kaydı silinen hesapla birlikte gider).
  Future<void> _removeGuestIdentityLinksForUid(String uid) async {
    if (uid.isEmpty) return;
    final links = await guestIdentityLinks();
    final removed = links.entries
        .where((entry) => entry.value == uid)
        .map((entry) => entry.key)
        .toList();
    if (removed.isEmpty) return;
    for (final key in removed) {
      links.remove(key);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(guestIdentityLinksKey, jsonEncode(links));
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

    // Göç kaydı (idempotency): bu misafir kimlikleri bu hesaba daha
    // önce göçmüşse tekrar birleştirme yapılmaz — çift sayma yok.
    // Kayıt yoksa göç çalışır; max()/birleşim anlamları sayesinde
    // yarım kalmış bir göçün tekrarı da güvenlidir (üzerine yazma
    // yok, yerel veri asla silinmez; bulut yazımı kuyruktadır).
    final migratingGuestIds = await _migratingGuestIds(snapshot, prefs);
    final existingLinks = await guestIdentityLinks();
    final alreadyMigrated = migratingGuestIds.isNotEmpty &&
        migratingGuestIds.every((id) => existingLinks[id] == targetUid);
    if (alreadyMigrated) return;

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
              // Dalga 3 ek: göç skoru da AntiCheat kapısından geçer —
              // recordModeScore bilinmeyen mod / negatif / tavan üstü
              // skoru yazmaz (doğrudan harita yazımı kapısızdı).
              await pm.recordModeScore(
                modeId,
                bestGuestScore,
                fromRemoteSync: true,
              );
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
            // Dalga 3 ek: göç skoru da AntiCheat kapısından geçer —
            // recordModeScore bilinmeyen mod / negatif / tavan üstü
            // skoru yazmaz (doğrudan harita yazımı kapısızdı).
            await pm.recordModeScore(
              canonical,
              entry.value,
              fromRemoteSync: true,
            );
          }
          if (entry.value > LeaderboardService.instance.getBest(canonical)) {
            // 12C1: göç birleştirme — doğrulanmış anlık görüntüden gelen
            // uzak skor; AntiCheat kap denetimi submitScore içinde
            // çalışır (uzak yol da aynı kapıdan geçer — Dalga 3 ek).
            await LeaderboardService.instance.submitScore(
              canonical,
              entry.value,
              playerName: targetName,
              fromRemoteSync: true,
            );
          }
        }
      }
    }

    // O4: göç, ProgressManager alanlarına doğrudan yazdı; bütünlük
    // imzasını PM'nin kendi kalıcı kayıt yolundan yenile. Doğrudan
    // prefs yazımı imza hesaplamaz ve `coins` setter'ının ertelenmiş
    // kaydı ara durumdan imza üretebilir (skor birleştirme henüz
    // bitmeden) — bu yüzden skor yazımı + imza tazelemesi, TÜM
    // birleştirmeler bittikten sonra tek noktada yapılır.
    // `persistBoosters()` güçlendirici prefs'lerini + bütünlük
    // imzasını son bellek-içi durumdan yazar (coin/seviye/kozmetik
    // prefs'leri yukarıda aynı değerlerle yazıldı). Liderlik
    // yeniden bağlama da skorları değiştirmiş olabilir
    // (`boardUpdated`), o yüzden koşul iki yolu da kapsar.
    if (snapshot.includeInMemoryScores || boardUpdated) {
      await prefs.setString(
        'lululu_mode_high_scores',
        jsonEncode(pm.modeHighScores),
      );
      await pm.persistBoosters();
    }

    await CloudSyncService.instance.enableOnlineWhenSignedIn();
    await CloudSyncService.instance.enqueueProgressPush();
    if (boardUpdated || snapshot.modeHighScores.isNotEmpty) {
      await CloudSyncService.instance.enqueueLeaderboardPush();
    }

    // Göç kaydı: kimlik eşlemeleri kalıcı yazılır (tek seferlik
    // göçün kanıtı + sohbet engel/rapor çözümlemesi). Eski sohbet
    // mesajları misafir UUID'siyle kalır; yeni mesajlar hesap
    // kimliğiyle gider; eşleme engel/rapor kayıtlarını çözer.
    for (final guestId in migratingGuestIds) {
      await recordGuestIdentityLink(guestId, targetUid);
    }
    await ChatService.instance.refreshIdentityLinks();
  }

  /// Göçen misafir kimlikleri: aktif misafir oturumu id'si, saklı
  /// misafir id'si ve sohbet misafir kimliği (varsa). Paylaşılan
  /// 'guest_local' yer tutucusu kimlik değildir, eşlemeye girmez.
  Future<List<String>> _migratingGuestIds(
    _GuestProgressSnapshot snapshot,
    SharedPreferences prefs,
  ) async {
    final ids = <String>{};
    void addId(String value) {
      if (value.isNotEmpty && value != 'guest_local') ids.add(value);
    }

    addId(snapshot.previousGuestId);
    addId(prefs.getString(_guestIdKey) ?? '');
    await ChatService.instance.ensureLoaded();
    final chatGuestId = ChatService.instance.guestIdentity?.id;
    if (chatGuestId != null) addId(chatGuestId);
    return ids.toList();
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
    // K1 (W60-6): girişle kimlik kapısı açılmış olabilir; sohbet bulut
    // dinlemesini yeniden kur (kanal değişimi beklenmez).
    ChatService.instance.refreshCloudBinding();
    await ChatService.instance.refreshIdentityLinks();
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

  /// Şifre sıfırlama e-postası gönderir.
  ///
  /// Firebase hazırsa `sendPasswordResetEmail` kullanılır; hata
  /// kodları kullanıcıya uygun iletilere çevrilir (`user-not-found`
  /// → kayıt yok, `invalid-email` → geçersiz e-posta,
  /// `too-many-requests` → bekleme). Firebase hazır değilse yerel
  /// kasa denetlenir: e-posta yerelde kayıtlıysa sıfırlama için bulut
  /// bağlantısı gerektiği söylenir, kayıtlı değilse "bulunamadı"
  /// döner. E-posta doğrulaması [_validateEmail] ile yapılır.
  Future<void> requestPasswordReset(String email) async {
    _validateEmail(email);
    final normalized = email.trim().toLowerCase();
    await ensureLoaded();
    if (FirebaseBootstrap.ready) {
      try {
        if (sendPasswordResetEmailForTest != null) {
          await sendPasswordResetEmailForTest!(normalized);
        } else {
          await _firebaseAuth.sendPasswordResetEmail(email: normalized);
        }
        return;
      } on fb.FirebaseAuthException catch (e) {
        switch (e.code) {
          case 'user-not-found':
          case 'invalid-credential':
            throw StateError('Bu e-posta ile kayıtlı hesap bulunamadı');
          case 'invalid-email':
            throw ArgumentError('Geçerli bir e-posta adresi girin');
          case 'too-many-requests':
            throw StateError(
              'Çok fazla sıfırlama isteği gönderildi — lütfen daha sonra tekrar deneyin',
            );
          default:
            throw StateError(
              'Şifre sıfırlama başarısız: ${e.message ?? e.code}',
            );
        }
      }
    }
    final knownLocally = _accounts.values.any(
      (a) => a.email?.toLowerCase() == normalized,
    );
    if (!knownLocally) {
      throw StateError('Bu e-posta ile kayıtlı hesap bulunamadı');
    }
    throw StateError(
      'Şifre sıfırlama şu an kullanılamıyor — bulut bağlantısı gerekli, '
      'internete bağlanıp tekrar deneyin',
    );
  }

  /// Anonim Firebase oturumunu kalıcı kimlik bilgileriyle bağlar
  /// (misafir→hesap göçünde anonim UID yetim kalmaz).
  ///
  /// Firebase hazır ve oturum anonimse [credential] mevcut anonim
  /// kullanıcıya [linkWithCredential] ile bağlanır (aynı UID kalır).
  /// Bağlama başarısız olursa (örn. kimlik bilgisi başka bir
  /// hesapta) eski davranışa düşülür: [fallbackSignIn] çalışır,
  /// misafir ilerlemesi uygulama-düzeyi göçle birleştirilir
  /// ([_captureGuestProgressBeforeLink] +
  /// [_mergeGuestProgressIntoAccount] aynen çalışır). Anonim oturum
  /// yoksa doğrudan [fallbackSignIn] çalışır.
  Future<fb.UserCredential> _linkOrFallbackSignIn(
    fb.AuthCredential credential,
    Future<fb.UserCredential> Function() fallbackSignIn,
  ) async {
    final current = _currentFirebaseUser();
    if (current != null && current.isAnonymous) {
      try {
        return await current.linkWithCredential(credential);
      } on fb.FirebaseAuthException catch (e) {
        debugPrint(
          '[lululu] Firebase link başarısız (${e.code}), girişe düşülüyor',
        );
      }
    }
    return fallbackSignIn();
  }

  /// YALNIZCA TEST: [_linkOrFallbackSignIn] akışını doğrudan işletir.
  @visibleForTesting
  Future<fb.UserCredential> linkOrFallbackSignInForTest(
    fb.AuthCredential credential,
    Future<fb.UserCredential> Function() fallbackSignIn,
  ) => _linkOrFallbackSignIn(credential, fallbackSignIn);

  /// Register a durable username+password (or email+password) account
  /// (device vault + optional Firebase Auth).
  ///
  /// O11: Firebase kaydı başarısız olursa hesap yalnız yerel kasaya
  /// yazılır ve [lastRegistrationWasLocalOnly] true olur; hesap
  /// uzlaştırma listesine alınır, bir sonraki girişte Firebase
  /// hesabı oluşturulup UID uzlaştırılır (bkz. [login]).
  Future<AuthUser> register({
    required String username,
    required String password,
    String? displayName,
    String? email,
  }) async {
    await ensureLoaded();
    // O11: önceki kaydın yerel-öncelikli işareti bu kayda taşınmaz.
    _lastRegistrationLocalOnly = false;
    _lastRegistrationFirebaseError = null;
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
    final shown = _clampDisplayName(
      sanitizedDisplay.isEmpty
          ? (isEmailInput ? userKey : rawTrimmed)
          : sanitizedDisplay,
    );

    var firebaseUid = id;
    var firebaseFailed = false;
    String? firebaseErrorCode;
    await FirebaseBootstrap.ensureInitialized();
    if (FirebaseBootstrap.ready) {
      try {
        final cred = await _linkOrFallbackSignIn(
          fb.EmailAuthProvider.credential(
            email: resolvedEmail,
            password: password,
          ),
          () => _firebaseAuth.createUserWithEmailAndPassword(
            email: resolvedEmail,
            password: password,
          ),
        );
        await cred.user?.updateDisplayName(shown);
        firebaseUid = cred.user?.uid ?? id;
      } on fb.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          throw StateError('Bu kullanıcı adı bulutta da kayıtlı — giriş yap');
        }
        firebaseFailed = true;
        firebaseErrorCode = e.code;
        debugPrint('[lululu] Firebase register: ${e.code} ${e.message}');
        // O11: sessiz yerel-devam YOK — yerel-öncelikli kayıt açıkça
        // işaretlenir (çağırıcı bildirebilir) ve uzlaştırma listesine
        // alınır; çevrimdışı-öncelikli akış korunur (kayıt sürer).
      } catch (e) {
        firebaseFailed = true;
        firebaseErrorCode = 'unknown';
        debugPrint('[lululu] Firebase register failed: $e');
      }
    }
    _lastRegistrationLocalOnly = firebaseFailed;
    _lastRegistrationFirebaseError = firebaseErrorCode;
    if (firebaseFailed) {
      _pendingFirebaseSync.add(userKey);
      unawaited(_persistPendingFirebaseSync());
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
    // Misafir göçü: girişten ÖNCE misafir ilerlemesi yakalanır
    // (kayıt/Google/Apple akışlarıyla aynı desen); her iki başarı
    // yolunda da hesaba birleştirilir.
    final guestSnapshot = await _captureGuestProgressBeforeLink();
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

      // K1 uzlaştırması (W60-6): yerel hesap girişi Firebase'de
      // başarıyla UID verirse kayıtlı hesabın id'si Firebase UID'si
      // olur; yoksa yerel id aynen kalır ve bulut kapısı
      // (CloudSync/Chat) yazımı engeller. Aynı UID başka bir kayıtlı
      // hesabın id'siyse (aynı e-postayla iki yerel hesap) uzlaştırma
      // yapılmaz — hesaplar birbirine karışmasın.
      var firebaseUid = resolvedAccount.id;
      await FirebaseBootstrap.ensureInitialized();
      if (FirebaseBootstrap.ready) {
        try {
          final cred = await _linkOrFallbackSignIn(
            fb.EmailAuthProvider.credential(
              email: authEmail,
              password: password,
            ),
            () => _firebaseAuth.signInWithEmailAndPassword(
              email: authEmail,
              password: password,
            ),
          );
          final uid = cred.user?.uid;
          if (uid != null && uid.isNotEmpty) firebaseUid = uid;
          // O11: Firebase oturumu açıldı — bekleyen uzlaştırma
          // (varsa) çözüldü, hesap bulutta da var demektir.
          if (_pendingFirebaseSync.remove(resolvedAccount.username)) {
            unawaited(_persistPendingFirebaseSync());
          }
        } on fb.FirebaseAuthException catch (e) {
          // O11 uzlaştırması: kayıt sırasında Firebase hesabı hiç
          // oluşmamışsa (uzlaştırma listesinde) ve giriş
          // "kullanıcı yok" ile reddedildiyse, aynı kimlik
          // bilgileriyle Firebase hesabını şimdi oluştur ve UID'yi
          // benimse (aşağıdaki çakışma koruması aynen geçerlidir).
          // E-posta bulutta zaten varsa oluşturma
          // `email-already-in-use` ile reddedilir — üzerine yazma
          // yok, bekleyen kayıt kalır, sonraki girişte tekrar
          // denenir. Yerel giriş her durumda başarılıdır.
          if (_pendingFirebaseSync.contains(resolvedAccount.username) &&
              (e.code == 'user-not-found' ||
                  e.code == 'invalid-credential')) {
            try {
              final created = await _linkOrFallbackSignIn(
                fb.EmailAuthProvider.credential(
                  email: authEmail,
                  password: password,
                ),
                () => _firebaseAuth.createUserWithEmailAndPassword(
                  email: authEmail,
                  password: password,
                ),
              );
              await created.user
                  ?.updateDisplayName(resolvedAccount.displayName);
              final createdUid = created.user?.uid;
              if (createdUid != null && createdUid.isNotEmpty) {
                firebaseUid = createdUid;
              }
              _pendingFirebaseSync.remove(resolvedAccount.username);
              unawaited(_persistPendingFirebaseSync());
            } catch (reconcileError) {
              debugPrint(
                '[lululu] Firebase login uzlaştırma başarısız: $reconcileError',
              );
            }
          } else {
            debugPrint('[lululu] Firebase login (local ok): $e');
          }
        } catch (e) {
          debugPrint('[lululu] Firebase login (local ok): $e');
        }
      }
      if (firebaseUid != resolvedAccount.id &&
          !_accounts.values.any(
            (a) =>
                a.id == firebaseUid &&
                a.username != resolvedAccount.username,
          )) {
        resolvedAccount = RegisteredAccount(
          id: firebaseUid,
          username: resolvedAccount.username,
          displayName: resolvedAccount.displayName,
          salt: resolvedAccount.salt,
          passwordHash: resolvedAccount.passwordHash,
          createdAtMs: resolvedAccount.createdAtMs,
          email: resolvedAccount.email,
        );
        _accounts[resolvedAccount.username] = resolvedAccount;
        await _persistAccounts();
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
      await _mergeGuestProgressIntoAccount(guestSnapshot);
      await _afterSignIn();
      return _user!;
    }

    // No local account — try Firebase, then cache locally.
    await FirebaseBootstrap.ensureInitialized();
    if (FirebaseBootstrap.ready) {
      try {
        final cred = await _linkOrFallbackSignIn(
          fb.EmailAuthProvider.credential(
            email: authEmail,
            password: password,
          ),
          () => _firebaseAuth.signInWithEmailAndPassword(
            email: authEmail,
            password: password,
          ),
        );
        final uid = cred.user?.uid ?? _stableLocalId(userKey);
        final shown = _clampDisplayName(
          cred.user?.displayName?.trim().isNotEmpty == true
              ? cred.user!.displayName!.trim()
              : (isEmailInput ? userKey : rawTrimmed),
        );
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
        // O11: Firebase girişi başarılı — yetim kalmış bekleyen
        // uzlaştırma kaydı (kasa temizlenmişse) çözüldü sayılır.
        if (_pendingFirebaseSync.remove(userKey)) {
          unawaited(_persistPendingFirebaseSync());
        }
        _setUser(
          AuthUser(
            id: uid,
            displayName: shown,
            provider: AuthProviderKind.local,
            email: authEmail,
            username: userKey,
          ),
        );
        await _mergeGuestProgressIntoAccount(guestSnapshot);
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
      guestId = _newGuestId();
      await prefs.setString(_guestIdKey, guestId);
    }

    await FirebaseBootstrap.ensureInitialized();
    if (FirebaseBootstrap.ready) {
      try {
        final cred = await _firebaseAuth.signInAnonymously();
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
    final name =
        _clampDisplayName(sanitizedNick.isEmpty ? 'Misafir' : sanitizedNick);
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

  /// Apple ile giriş. Y4: sağlayıcı hatası/iptali HATA olarak döner —
  /// sahte yerel oturum (`apple_local_*`) üretilmez, önceki oturum
  /// (misafir dahil) aynen korunur. Kullanıcı iptali
  /// [AuthSignInCancelledException] (çağırıcı sessizce yutabilir),
  /// sağlayıcı hatası görünür [StateError] fırlatır.
  ///
  /// Sağlayıcı kimliği doğrulandıktan sonra Firebase bağlantısı
  /// denenir: Firebase hazırsa ve jeton varsa bağlantı hatası da
  /// görünür hatadır (sessiz yerel-devam yok). Firebase hazır
  /// değilse veya jeton yoksa, sağlayıcı-doğrulanmış kimlikle yerel
  /// oturum açılır (çevrimdışı-öncelikli; bulut yazımı CloudSync
  /// kapısında engellenir, sahte kimlik değildir).
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
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthSignInCancelledException(
          provider: AuthProviderKind.apple,
        );
      }
      debugPrint('[lululu] Apple Sign In failed: ${e.code} ${e.message}');
      throw StateError('Apple ile giriş başarısız — tekrar deneyin');
    } catch (e) {
      debugPrint('[lululu] Apple Sign In failed: $e');
      throw StateError('Apple ile giriş başarısız — tekrar deneyin');
    }

    final given = credential.givenName;
    final family = credential.familyName;
    final composed = [
      if (given != null && given.isNotEmpty) given,
      if (family != null && family.isNotEmpty) family,
    ].join(' ');
    final display =
        _clampDisplayName(composed.isEmpty ? 'Apple Oyuncu' : composed);
    final rawIdToken = credential.identityToken;
    // Boş jeton, jeton yok sayılır (doğrudan null kontrolü, `!` yok).
    final idToken = rawIdToken != null && rawIdToken.isNotEmpty
        ? rawIdToken
        : null;
    final userIdentifier = credential.userIdentifier;
    // Y4: ne jeton ne sağlayıcı kimliği varsa doğrulanmış kimlik
    // yoktur — zaman damgalı sentetik id üretilmez, hata döner.
    final String stableId;
    if (idToken != null) {
      stableId = 'apple_${_sha256of(idToken).substring(0, 24)}';
    } else if (userIdentifier != null && userIdentifier.isNotEmpty) {
      stableId = 'apple_$userIdentifier';
    } else {
      debugPrint(
        '[lululu] Apple Sign In: kimlik jetonu ve kullanıcı kimliği yok',
      );
      throw StateError('Apple ile giriş başarısız — tekrar deneyin');
    }

    if (FirebaseBootstrap.ready && idToken != null) {
      try {
        final oauth = fb.OAuthProvider('apple.com').credential(
          idToken: idToken,
          rawNonce: rawNonce,
        );
        final cred = await _linkOrFallbackSignIn(
          oauth,
          () => _firebaseAuth.signInWithCredential(oauth),
        );
        _setUser(
          AuthUser(
            id: cred.user?.uid ?? stableId,
            displayName:
                _clampDisplayName(cred.user?.displayName ?? display),
            provider: AuthProviderKind.apple,
            email: cred.user?.email ?? credential.email,
            username: _normalizeUsername(display),
          ),
        );
        await _mergeGuestProgressIntoAccount(guestSnapshot);
        await _afterSignIn();
        return _user!;
      } catch (e) {
        // Y4: Firebase hazır + jeton varken bağlantı hatası görünür
        // hatadır; sessizce yerel oturuma düşülmez (UID ayrışması).
        debugPrint('[lululu] Firebase Apple link failed: $e');
        throw StateError('Apple ile giriş tamamlanamadı — tekrar deneyin');
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

  /// Google ile giriş. Y4: sağlayıcı hatası/iptali HATA olarak döner —
  /// sahte yerel oturum (`google_local_*`) üretilmez, önceki oturum
  /// aynen korunur. Kullanıcı iptali
  /// [AuthSignInCancelledException] (çağırıcı sessizce yutabilir),
  /// sağlayıcı hatası görünür [StateError] fırlatır. Firebase
  /// bağlantısı hazırsa hatası görünürdür; Firebase hazır değilse
  /// sağlayıcı-doğrulanmış kimlikle yerel oturum açılır (bkz.
  /// [signInWithApple] sözleşmesi).
  Future<AuthUser> signInWithGoogle() async {
    await ensureLoaded();
    final guestSnapshot = await _captureGuestProgressBeforeLink();
    await FirebaseBootstrap.ensureInitialized();
    try {
      await _ensureGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      final rawIdToken = account.authentication.idToken;
      // Boş jeton, jeton yok sayılır (doğrudan null kontrolü, `!` yok).
      final idToken = rawIdToken != null && rawIdToken.isNotEmpty
          ? rawIdToken
          : null;
      final stableId = 'google_${account.id}';

      if (FirebaseBootstrap.ready && idToken != null) {
        try {
          final cred = fb.GoogleAuthProvider.credential(idToken: idToken);
          final userCred = await _linkOrFallbackSignIn(
            cred,
            () => _firebaseAuth.signInWithCredential(cred),
          );
          final resolvedName = _clampDisplayName(
            userCred.user?.displayName ??
                account.displayName ??
                'Google Oyuncu',
          );
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
          // Y4: Firebase hazır + jeton varken bağlantı hatası görünür
          // hatadır; sessizce yerel oturuma düşülmez (UID ayrışması).
          // Dış `catch` tarafından yeniden sarılmaması için
          // [StateError] dışarıda aynen fırlatılır.
          debugPrint('[lululu] Firebase Google link failed: $e');
          throw StateError('Google ile giriş tamamlanamadı — tekrar deneyin');
        }
      }

      final fallbackName =
          _clampDisplayName(account.displayName ?? 'Google Oyuncu');
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
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthSignInCancelledException(
          provider: AuthProviderKind.google,
        );
      }
      debugPrint(
        '[lululu] Google Sign In failed: ${e.code} ${e.description}',
      );
      throw StateError('Google ile giriş başarısız — tekrar deneyin');
    } on AuthSignInCancelledException {
      rethrow;
    } on StateError {
      rethrow;
    } catch (e) {
      debugPrint('[lululu] Google Sign In failed: $e');
      throw StateError('Google ile giriş başarısız — tekrar deneyin');
    }
  }

  /// Updates the signed-in user's display name locally and in Firebase Auth.
  Future<void> updateDisplayName(String name) async {
    await ensureLoaded();
    if (_user == null) return;
    final trimmed = _sanitizeInput(name, fieldLabel: 'Görünen ad');
    if (trimmed.isEmpty) return;
    // K3: görünen ad 32 karaktere sessizce kısalır (kasa + Firebase +
    // oturum, üçü de kısaltılmış değeri alır).
    final clampedName = _clampDisplayName(trimmed);
    final currentUsername = _user!.username;
    _setUser(
      _user!.copyWith(
        displayName: clampedName,
        username: currentUsername,
      ),
    );
    if (currentUsername != null && _accounts.containsKey(currentUsername)) {
      final old = _accounts[currentUsername]!;
      _accounts[currentUsername] = RegisteredAccount(
        id: old.id,
        username: old.username,
        displayName: clampedName,
        salt: old.salt,
        passwordHash: old.passwordHash,
        createdAtMs: old.createdAtMs,
        email: old.email,
      );
      await _persistAccounts();
    }
    if (FirebaseBootstrap.ready) {
      try {
        await _firebaseAuth.currentUser
            ?.updateDisplayName(clampedName);
      } catch (e) {
        debugPrint('[lululu] Firebase updateDisplayName error: $e');
      }
    }
    await _persistSession();
    notifyListeners();
  }

  /// Oturumu açık hesabı siler ve oturumu kapatır; temizlik
  /// sonucunu [AccountDeletionResult] olarak döndürür (O27: kısmi
  /// temizlikler artık yalnız logda kalmaz, çağırıcıya bildirilir).
  ///
  /// Bulut tarafı (tek ifade): Firebase hazırsa ve Firebase oturumu
  /// varsa, [_deleteCloudAccount] önce Firestore profil/skor
  /// belgelerini, sohbet mesajlarını (göç eşlemeli misafir
  /// mesajları dahil) ve Firebase Auth kullanıcısını siler; sonra
  /// yerel kasa temizlenir. Firebase hazır değilse veya Firebase
  /// oturumu yoksa bulut silme denenmez — o durumda bulut kopyası
  /// varsa kalır ve aynı e-postayla yeniden kayıt Firebase'te
  /// `email-already-in-use` ile reddedilebilir.
  /// `requires-recent-login` durumunda fırlatılır ve yerel veri
  /// korunur — kullanıcı yeniden giriş yapıp tekrar dener.
  ///
  /// Cihazda yapılanlar:
  /// * Hesap, yerel hesap kasasından ([_localAccountsKey]) çıkarılır ve
  ///   kalan hesaplar kalıcı hâle getirilir — cihazdaki diğer hesaplara
  ///   dokunulmaz. Sosyal girişlerde (Apple/Google) kasa kaydı olmayabilir;
  ///   o durumda yalnız oturum silinir.
  /// * Silinen hesabın başarısız-giriş sayaçları ve bekleyen Firebase
  ///   uzlaştırma kaydı temizlenir.
  /// * [signOut] ile oturum kapatılır (Firebase + Google oturum sonlandırma
  ///   ve oturum anahtarının silinmesi).
  /// * [CloudSyncService.enableOnlineWhenSignedIn] yeniden değerlendirilir:
  ///   kimse oturumda olmayınca çevrimiçi eşitleme kapanır, bekleyen kuyruk
  ///   gönderilmez.
  ///
  /// Yerel temizlik: [ProgressManager.clearLocalData],
  /// [LeaderboardService.clearLocalData], [ChatService.clearLocalData],
  /// [CloudSyncService.clearLocalData], [EnergyService.clearLocalData],
  /// [DailyChallengeService.clearLocalData],
  /// [CampaignProgressionService.clearLocalData],
  /// [AchievementPassService.clearLocalData],
  /// [AdaptiveDifficultyService.clearLocalData] ve
  /// [BugVideoService.clearLocalData] bu metotta çağrılır; silinen
  /// hesabın cihazdaki ilerleme / liderlik / sohbet / senkron kuyruğu /
  /// enerji / günlük görev / kampanya / başarım-sezon / zorluk geçmişi /
  /// stüdyo kayıtları temizlenir. Ses/titreşim ayarlarına dokunulmaz
  /// (cihaz tercihi). Bir adım başarısız olursa diğer adımlar yine
  /// çalışır; başarısız adımlar sonuçta listelenir.
  ///
  /// Oturum açık değilse veya oturum misafir oturumuysa [StateError] fırlatır
  /// (misafirlerin silinecek hesap kaydı yoktur).
  Future<AccountDeletionResult> deleteAccount() async {
    await ensureLoaded();
    final current = _user;
    if (current == null) {
      throw StateError('Oturum açık değil — silinecek hesap yok');
    }
    if (current.isGuest) {
      throw StateError('Misafir oturumunda silinecek hesap yok');
    }
    // Bulut temizliği yerel silmeden ÖNCE: yeniden giriş gerekirse
    // yerel veri korunur, kullanıcı tekrar deneyebilir.
    final cloudResult = await _deleteCloudAccount();
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
    var pendingChanged = false;
    for (final key in vaultKeys) {
      _accounts.remove(key);
      _clearFailedLoginAttempts(key);
      if (_pendingFirebaseSync.remove(key)) pendingChanged = true;
    }
    if (pendingChanged) {
      unawaited(_persistPendingFirebaseSync());
    }
    if (vaultKeys.isNotEmpty) {
      await _persistAccounts();
    }
    await signOut();
    // Göç kayıtları: silinen hesaba bağlı misafir eşlemeleri gider
    // (misafir kimliğinin kendisi ChatService.clearLocalData ile
    // aşağıda temizlenir).
    await _removeGuestIdentityLinksForUid(accountId);
    // Yerel temizlik: silinen hesabın cihazdaki ilerleme / liderlik /
    // sohbet / senkron kuyruğu kayıtları temizlenir. Her adım ayrı
    // korunur; başarısız adım sonuçta listelenir (O27), ayrıntı
    // logda kalır.
    final failedLocalCleanups = <String>[];
    final failedDetails = <String>[];
    Future<void> runCleanup(String name, Future<void> Function() task) async {
      try {
        await task();
      } catch (e) {
        failedLocalCleanups.add(name);
        failedDetails.add('$name: $e');
      }
    }

    try {
      await runCleanup(
        'ProgressManager',
        ProgressManager.instance.clearLocalData,
      );
      await runCleanup(
        'LeaderboardService',
        LeaderboardService.instance.clearLocalData,
      );
      await runCleanup('ChatService', ChatService.instance.clearLocalData);
      await runCleanup(
        'CloudSyncService',
        CloudSyncService.instance.clearLocalData,
      );
      await runCleanup(
        'EnergyService',
        EnergyService.instance.clearLocalData,
      );
      await runCleanup(
        'DailyChallengeService',
        DailyChallengeService.instance.clearLocalData,
      );
      await runCleanup(
        'CampaignProgressionService',
        CampaignProgressionService.instance.clearLocalData,
      );
      await runCleanup(
        'AchievementPassService',
        AchievementPassService.instance.clearLocalData,
      );
      await runCleanup(
        'AdaptiveDifficultyService',
        AdaptiveDifficultyService.instance.clearLocalData,
      );
      await runCleanup(
        'BugVideoService',
        BugVideoService.instance.clearLocalData,
      );
      // Online "haberdar et" tercihi: servis bildirim göndermez ama
      // tercihi kalıcı saklar; hesap silmede hem bellek-içi durum
      // sıfırlanır hem de kalıcı anahtar kaldırılır (yeni hesap aynı
      // oturumda eski tercihi devralmaz). Anahtar adı
      // OnlineNotifyService._prefsKey ile aynı değerdir (o sabit
      // özeldir; değişirse burası da güncellenmelidir).
      await runCleanup('OnlineNotifyService', () async {
        await OnlineNotifyService.instance.setSubscribed(false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('lululu.online_notify');
      });
    } finally {
      await runCleanup(
        'CloudSyncService.enableOnlineWhenSignedIn',
        CloudSyncService.instance.enableOnlineWhenSignedIn,
      );
    }
    if (failedDetails.isNotEmpty) {
      debugPrint(
        '[lululu] deleteAccount: yerel temizlikte başarısız olanlar: ${failedDetails.join('; ')}',
      );
    }
    return AccountDeletionResult(
      failedLocalCleanups: failedLocalCleanups,
      failedCloudCleanups: cloudResult.failures,
      cloudDeletionAttempted: cloudResult.attempted,
    );
  }

  /// Firebase tarafı hesap silme (Google Play Kullanıcı Verisi
  /// politikası: hesap silme, hesapla ilişkili tüm veriyi silmelidir).
  ///
  /// Sıra: Firestore profil/skor belgeleri → sohbet mesajları →
  /// Firebase Auth kullanıcısı. Belge/mesaj silme başarısız olursa
  /// (kural/ağ) adım adı döndürülen listeye eklenir ama hesap silme
  /// engellenmez — yerel kasa ve Auth silme yine yapılır.
  /// `requires-recent-login` durumunda ise [StateError] fırlatılır;
  /// çağrı noktası yerel veriyi silmeden durur, kullanıcı yeniden
  /// giriş yapıp tekrar dener.
  ///
  /// Yerel-derlemede (Firebase hazır değil) veya Firebase oturumu
  /// yoksa hiçbir şey yapmaz (`attempted: false` döner).
  Future<({bool attempted, List<String> failures})>
      _deleteCloudAccount() async {
    if (!FirebaseBootstrap.ready) {
      return (attempted: false, failures: <String>[]);
    }
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) {
      return (attempted: false, failures: <String>[]);
    }
    final uid = fbUser.uid;
    final failures = <String>[];
    try {
      await CloudSyncService.instance.deleteCloudDataForUid(uid);
    } catch (e) {
      failures.add('CloudSyncService');
      debugPrint('[lululu] deleteAccount: bulut profili silinemedi: $e');
    }
    try {
      await ChatService.instance.deleteMessagesByAuthor(uid);
    } catch (e) {
      failures.add('ChatService');
      debugPrint(
        '[lululu] deleteAccount: bulut sohbet mesajları silinemedi: $e',
      );
    }
    try {
      // Göç eşlemesindeki misafir kimlikleriyle yazılmış bulut
      // mesajları da silinir (gizlilik metniyle tutarlılık); sonra
      // eşleme belgelerinin kendileri gider. Yerel eşleme kaydı
      // deleteAccount'ta aşağıda silinir — sıra önemlidir.
      final links = await guestIdentityLinks();
      final guestIds = links.entries
          .where((entry) => entry.value == uid)
          .map((entry) => entry.key)
          .toList();
      for (final guestId in guestIds) {
        await ChatService.instance.deleteMessagesByAuthor(guestId);
      }
      await ChatService.instance.deleteGuestIdentityLinksCloud(guestIds);
    } catch (e) {
      failures.add('ChatService.guestLinks');
      debugPrint(
        '[lululu] deleteAccount: göç eşlemeli mesajlar silinemedi: $e',
      );
    }
    try {
      await fbUser.delete();
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw StateError(
          'Güvenlik için yeniden giriş yapmanız gerekiyor — çıkış yapıp '
          'tekrar giriş yaptıktan sonra hesap silmeyi yeniden deneyin.',
        );
      }
      failures.add('FirebaseAuth');
      debugPrint(
        '[lululu] deleteAccount: Firebase Auth silme hatası: ${e.code}',
      );
    }
    return (attempted: true, failures: failures);
  }

  Future<void> signOut() async {
    try {
      if (FirebaseBootstrap.ready) {
        await _firebaseAuth.signOut();
      }
      if (_googleReady) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    _setUser(null);
    // K1 (W60-6): çıkışta sohbet bulut dinlemesini kapat (eski kimlikle
    // reddedilen okuma denemesi yapmasın).
    ChatService.instance.refreshCloudBinding();
    await _persistSession();
    notifyListeners();
  }
}
