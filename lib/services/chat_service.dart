import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'firebase_bootstrap.dart';

/// Sohbet kanalları: Genel Lobi, Takım & Klan, VS Meydan Okuma.
enum ChatChannel {
  lobby('lobby', 'Genel Lobi'),
  clan('clan', 'Takım & Klan'),
  vsChallenge('vs', 'VS Meydan Okuma');

  const ChatChannel(this.id, this.displayName);
  final String id;
  final String displayName;

  static ChatChannel fromId(String? id) {
    for (final c in ChatChannel.values) {
      if (c.id == id || c.name == id) return c;
    }
    return ChatChannel.lobby;
  }

  // --- English (EN) counterparts: pure additions, TR defaults untouched. ---
  // `displayName` keeps returning Turkish; screens migrate to
  // `displayNameFor(Locale)` in a later wave. `id`/`name` keys are
  // unchanged. No AppLocalizations import: these are pure
  // `Locale`-parameterized accessors, so no import cycle.
  String get displayNameEn {
    switch (this) {
      case ChatChannel.lobby:
        return 'General Lobby';
      case ChatChannel.clan:
        return 'Team & Clan';
      case ChatChannel.vsChallenge:
        return 'VS Challenge';
    }
  }

  String displayNameFor(Locale locale) =>
      locale.languageCode == 'en' ? displayNameEn : displayName;
}

/// Mesaj yazarının türü: kayıtlı kullanıcı veya misafir. Bulut
/// kuralları (`firestore.rules`) bu alana göre yazar doğrulaması yapar:
/// kullanıcıda `authorId == request.auth.uid`, misafirde yapısal
/// doğrulama (kalıcı misafir UUID'si + uzunluk sınırları).
enum ChatAuthorKind {
  user('user'),
  guest('guest');

  const ChatAuthorKind(this.id);
  final String id;

  static ChatAuthorKind fromId(String? id) =>
      id == 'guest' ? ChatAuthorKind.guest : ChatAuthorKind.user;
}

/// Rapor sebepleri (Play UGC politikası: bildirim akışı sebep seçimiyle).
enum ChatReportReason {
  spam('spam'),
  inappropriate('inappropriate'),
  harassment('harassment'),
  other('other');

  const ChatReportReason(this.id);
  final String id;
}

/// Rapor gönderiminin sonucu: buluta yazıldı, çevrimdışı kuyruğa alındı
/// veya bu mesaj daha önce raporlanmış.
enum ChatReportOutcome { sent, queued, alreadyReported }

/// Sohbet şart onayı verilmeden gönderim denendiğinde fırlatılır.
/// Arayüz bu hatayı yakalayıp şart diyaloğunu gösterir; kabul sonrası
/// gönderim tekrar denenir.
class ChatTermsRequiredException implements Exception {
  const ChatTermsRequiredException();

  @override
  String toString() => 'ChatTermsRequiredException';
}

/// Kalıcı misafir kimliği: cihazda saklanan sabit UUID + görünen ad.
/// Aynı misafir her oturumda aynı kimlikle görünür; mesajlar
/// karışmaz, raporlama/engelleme bu kimlik üzerinden çalışır.
/// Görünen ad değiştirilebilir, UUID değişmez.
class GuestChatIdentity {
  const GuestChatIdentity({
    required this.id,
    required this.displayName,
    required this.createdAtMs,
  });

  final String id;
  final String displayName;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'createdAtMs': createdAtMs,
      };

  factory GuestChatIdentity.fromJson(Map<String, dynamic> json) {
    return GuestChatIdentity(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  GuestChatIdentity copyWith({String? displayName}) => GuestChatIdentity(
        id: id,
        displayName: displayName ?? this.displayName,
        createdAtMs: createdAtMs,
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.utcTicks,
    this.isSystem = false,
    this.channel = ChatChannel.lobby,
    this.authorKind = ChatAuthorKind.user,
    this.stickerTier,
    this.stickerAsset,
    this.voiceLine,
    this.challengeModeId,
    this.challengeTargetScore,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final int utcTicks;
  final bool isSystem;
  final ChatChannel channel;
  final ChatAuthorKind authorKind;
  final int? stickerTier;
  final String? stickerAsset;
  final String? voiceLine;
  final String? challengeModeId;
  final int? challengeTargetScore;

  bool get isSticker => stickerTier != null || stickerAsset != null;
  bool get isChallenge => challengeModeId != null;
  bool get isGuestAuthor => authorKind == ChatAuthorKind.guest;

  Map<String, dynamic> toJson() {
    // voiceLine kural sınırı (1..120): yazılan değer her zaman kırpılır.
    final safeVoiceLine =
        voiceLine == null ? null : ChatService.sanitizeVoiceLine(voiceLine!);
    // K3: authorName kural sınırı (1..32, firestore.rules:301): ham ad
    // yazılırsa 32 karakteri aşan adla TÜM sohbet yazımları reddedilir.
    // Ad kesilir, reddedilmez.
    final safeAuthorName = ChatService.sanitizeAuthorName(authorName);
    return {
      'id': id,
      'authorId': authorId,
      'authorKind': authorKind.id,
      'authorName': safeAuthorName,
      'body': body,
      'utcTicks': utcTicks,
      'isSystem': isSystem,
      'channel': channel.id,
      if (stickerTier != null) 'stickerTier': stickerTier,
      if (stickerAsset != null) 'stickerAsset': stickerAsset,
      if (safeVoiceLine != null && safeVoiceLine.isNotEmpty)
        'voiceLine': safeVoiceLine,
      if (challengeModeId != null) 'challengeModeId': challengeModeId,
      if (challengeTargetScore != null)
        'challengeTargetScore': challengeTargetScore,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Gösterim yolu: buluttan/yerelden gelen metinler de sanitize edilir
    // (küfür filtresi yalnız gönderimde değil, okurken de uygulanır).
    final safeAuthorName =
        ChatService.sanitizeText(json['authorName'] as String? ?? '');
    final rawVoiceLine = json['voiceLine'] as String?;
    final safeVoiceLine = rawVoiceLine == null
        ? null
        : ChatService.sanitizeVoiceLine(rawVoiceLine);
    // Eski kayıtlarda `authorKind` yok: yazar kimliğinden türetilir
    // (paylaşılan 'guest_local' ve 'guest_*' kimlikler misafirdir).
    final rawAuthorId = json['authorId'] as String? ?? '';
    final rawKind = json['authorKind'] as String?;
    final authorKind = rawKind != null
        ? ChatAuthorKind.fromId(rawKind)
        : (rawAuthorId == 'guest_local' || rawAuthorId.startsWith('guest_')
            ? ChatAuthorKind.guest
            : ChatAuthorKind.user);
    return ChatMessage(
      id: json['id'] as String? ?? '',
      authorId: rawAuthorId,
      authorKind: authorKind,
      authorName: safeAuthorName.isEmpty ? '?' : safeAuthorName,
      body: ChatService.sanitizeText(json['body'] as String? ?? ''),
      utcTicks: (json['utcTicks'] as num?)?.toInt() ?? 0,
      isSystem: json['isSystem'] as bool? ?? false,
      channel: ChatChannel.fromId(json['channel'] as String?),
      stickerTier: (json['stickerTier'] as num?)?.toInt(),
      stickerAsset: json['stickerAsset'] as String?,
      voiceLine:
          safeVoiceLine == null || safeVoiceLine.isEmpty ? null : safeVoiceLine,
      challengeModeId: json['challengeModeId'] as String?,
      challengeTargetScore: (json['challengeTargetScore'] as num?)?.toInt(),
    );
  }
}

/// Offline-First + Cloud-Ready Çok Kanallı Sohbet Servisi:
/// - Genel Lobi, Takım & Klan ve VS Meydan Okuma kanalları
/// - Okunmamış sayacı: aktif olmayan kanallar hafif yoklamayla dinlenir
///   (bkz. [ChatService.unreadCounts]); aktif kanal tam dinlenir.
/// - Böcek çıkartması (Tier 1..13) ve viral replik gönderme
/// - Küfür ve spam filtresi
/// - Gerçek zamanlı Stream + Firestore senkronizasyonu
class ChatService extends ChangeNotifier {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const _prefsKey = 'LululuChatLobbyV1';
  static const _channelsPrefsKey = 'LululuChatChannelsV2';

  /// Kanal başına görülen en yeni mesaj zamanı (utcTicks) — kalıcı
  /// (S2#19): [markChannelRead] ve bulut akışı ilerlettikçe yazılır,
  /// [load] başlangıçta önbellekten türetilen değerle birleştirilir
  /// (büyük olan kazanır).
  static const _lastSeenPrefsKey = 'LululuChatLastSeenV1';

  /// Kalıcı misafir kimliği (UUID + görünen ad) — tek JSON belge.
  static const _guestIdentityPrefsKey = 'LululuChatGuestIdentityV1';

  /// Sohbet şart onayı (tek seferlik, kalıcı).
  static const _termsPrefsKey = 'LululuChatTermsAcceptedV1';

  /// Engellenen yazarlar: yazar kimliği -> görünen ad (JSON harita).
  static const _blockedPrefsKey = 'LululuChatBlockedV1';

  /// Raporlanmış mesaj kimlikleri (tekrar raporu önler).
  static const _reportedPrefsKey = 'LululuChatReportedV1';

  /// Buluta yazılamayıp kuyrukta bekleyen raporlar (JSON liste).
  static const _pendingReportsPrefsKey = 'LululuChatPendingReportsV1';

  /// Misafir görünen adı üst sınırı (kural sınırı 32; ekranda 20 yeterli).
  static const int maxGuestDisplayNameLength = 20;

  static const maxMessages = 200;

  /// Okunmamış yoklamasının pencere boyutu (S2#19): aktif olmayan her
  /// kanal yalnız son bu kadar mesajla dinlenir; sayaç bu sayıyla
  /// sınırlıdır (kesin sayı değil, "yeni mesaj var" işareti).
  static const int unreadProbeLimit = 10;
  static const int maxMessageLength = 240;
  static const int maxVoiceLineLength = 120;
  /// K3: kural `authorName` 1..32 ister (firestore.rules:301).
  static const int maxAuthorNameLength = 32;
  static const int duplicateRateLimitMs = 1500;
  static const int burstWindowMs = 10000;
  static const int maxMessagesPerBurstWindow = 6;

  /// Böcek çıkartması isimleri ve replikleri (Tier 1..8+).
  static const Map<int, ({String name, String line, String asset})>
      bugStickerCatalog = {
    1: (
      name: 'Bebek Huni',
      line: 'HOP, GELDİM!',
      asset: 'assets/design/bugs_hd/tier1_hd.png',
    ),
    2: (
      name: 'Tencereli Çırak',
      line: 'TENCERE KAFADA, HAZIRIZ!',
      asset: 'assets/design/bugs_hd/tier2_hd.png',
    ),
    3: (
      name: 'Makaracı Fan',
      line: 'MAKARAYIZ ABİ!',
      asset: 'assets/design/bugs_hd/tier3_hd.png',
    ),
    4: (
      name: 'Pijamalı Dansçı',
      line: 'DANS PİSTİNE!',
      asset: 'assets/design/bugs_hd/tier4_hd.png',
    ),
    5: (
      name: 'Hamam Diva',
      line: 'AY BAYILAZAAM — DİVA GELDİ! ✨',
      asset: 'assets/design/bugs_hd/tier5_hd.png',
    ),
    6: (
      name: 'Hamam Can',
      line: 'HERKES HAVUZDAN ÇIKSIN!',
      asset: 'assets/design/bugs_hd/tier6_hd.png',
    ),
    7: (
      name: 'Kongo Lideri',
      line: 'KURBAN OLDUĞUM KONGO İSTİLASI!',
      asset: 'assets/design/bugs_hd/tier7_hd.png',
    ),
    8: (
      name: 'Hasta Bilge',
      line: 'BİLGE YORGUN AMA EFSANE!',
      asset: 'assets/design/bugs_hd/tier8_hd.png',
    ),
  };

  // --- English (EN) sticker names: pure additions, TR catalog untouched. ---
  // Names mirror `InsectTier.nameEn` (same characters, tiers 1..8).
  // `line` (viral catchphrases) deliberately has NO English counterpart:
  // the lines are character identity and stay Turkish in every locale,
  // same as `InsectTier.viralReplik`. Screens migrate to
  // `bugStickerNameFor(tier, locale)` in a later wave; `bugStickerCatalog`
  // keeps returning Turkish names. Tiers 9..13 (not in the catalog) use
  // the same fallback shape as `sendBugSticker`: 'Tier <n> Böcek' in TR,
  // 'Tier <n> Bug' in EN. No AppLocalizations import.
  static const Map<int, String> bugStickerNameEn = {
    1: 'Baby Funnel',
    2: 'Pot-Wearing Apprentice',
    3: 'Reel Fan',
    4: 'Pajama Dancer',
    5: 'Bathhouse Diva',
    6: 'Bathhouse Can',
    7: 'Kongo Leader',
    8: 'Ailing Sage',
  };

  static String bugStickerNameFor(int tier, Locale locale) {
    if (locale.languageCode == 'en') {
      return bugStickerNameEn[tier] ?? 'Tier $tier Bug';
    }
    return bugStickerCatalog[tier]?.name ?? 'Tier $tier Böcek';
  }

  static const List<String> _blockedWords = [
    'amk',
    'aq',
    'oç',
    'oc',
    'orospu',
    'piç',
    'pic',
    'sik',
    'siktir',
    'sikik',
    'yarrak',
    'yarak',
    'göt',
    'gotveren',
    'ibne',
    'pezevenk',
    'kahpe',
    'kaltak',
    'gavat',
    'puşt',
    'pust',
    'aptal',
    'gerizekalı',
    'gerizekali',
    'salak',
    'mal',
    'hıyar',
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'dick',
    'bastard',
  ];

  final List<ChatMessage> _messages = [];
  final Map<ChatChannel, List<ChatMessage>> _byChannel = {
    for (final c in ChatChannel.values) c: <ChatMessage>[],
  };

  ChatChannel _currentChannel = ChatChannel.lobby;
  bool _loaded = false;

  /// Devam eden `load()` çağrısı (uçuş koruması): eşzamanlı
  /// `load()`/`ensureLoaded()` çağrıları aynı yüklemeyi paylaşır.
  Future<void>? _loadFuture;
  String _lastSentText = '';
  int _lastSentAtMs = 0;
  final List<int> _recentSendTimestampsMs = <int>[];

  final StreamController<List<ChatMessage>> _streamController =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<ChatMessage> _newMessageController =
      StreamController<ChatMessage>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cloudSub;

  /// Aktif olmayan kanalların hafif okunmamış yoklamaları (S2#19).
  final Map<ChatChannel,
          StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _unreadSubs = {};
  final Map<ChatChannel, int> _unreadCounts = {
    for (final c in ChatChannel.values) c: 0,
  };

  /// Kanal başına görülen en yeni mesaj zamanı (utcTicks). Okunmamış
  /// sayımı, bu zamandan yeni + başkasına ait mesajları sayar. Başlangıç
  /// değeri yerelde önbellekli mesajlardan alınır ve kalıcı
  /// [_lastSeenPrefsKey] kaydıyla birleştirilir (büyük olan kazanır),
  /// böylece yeniden başlatmada önbelleğe girmemiş okunmamışlar
  /// sıfırlanmaz (S2#19 notu çözüldü).
  final Map<ChatChannel, int> _lastSeenTicks = {};

  /// Buluta yazımı başarısız olup yalnız yerelde kalan mesaj kimlikleri.
  final Set<String> _cloudFailedIds = <String>{};

  /// Kalıcı misafir kimliği (yüklemede okunur, ilk kullanımda oluşur).
  GuestChatIdentity? _guestIdentity;

  /// Sohbet şart onayı verilmiş mi.
  bool _termsAccepted = false;

  /// Engellenen yazarlar: kimlik -> görünen ad.
  final Map<String, String> _blockedAuthors = {};

  /// Raporlanmış mesaj kimlikleri.
  final Set<String> _reportedIds = <String>{};

  /// Buluta yazılamayıp kuyrukta bekleyen rapor belgeleri.
  final List<Map<String, dynamic>> _pendingReports = [];

  /// Misafir UUID'si -> hesap UID eşlemesi (göçte yazılır,
  /// [AuthService.guestIdentityLinksKey] altında saklanır).
  Map<String, String> _identityLinks = {};

  ChatChannel get currentChannel => _currentChannel;

  /// Kanal başına okunmamış mesaj sayısı (yalnız bulut dinlenirken
  /// güncellenir; aktif kanal her zaman 0'dır). Arayüz bu sayacı
  /// `ChangeNotifier` dinleyerek okur.
  Map<ChatChannel, int> get unreadCounts => Map.unmodifiable(_unreadCounts);

  /// Belirli bir kanaldaki okunmamış mesaj sayısı.
  int unreadCountFor(ChatChannel channel) => _unreadCounts[channel] ?? 0;

  /// Tüm kanallardaki toplam okunmamış mesaj sayısı.
  int get totalUnreadCount =>
      _unreadCounts.values.fold(0, (sum, count) => sum + count);

  /// Belirli bir kanalda okunmamış mesaj olup olmadığı.
  bool hasUnread(ChatChannel channel) => unreadCountFor(channel) > 0;

  /// Kanalı okundu sayar: sayacı sıfırlar, görülen zamanı kanaldaki en
  /// yeni mesaja ilerletir. Kanal değişiminde otomatik çağrılır.
  void markChannelRead(ChatChannel channel) {
    final list = _byChannel[channel] ?? const <ChatMessage>[];
    var latest = _lastSeenTicks[channel] ?? 0;
    for (final m in list) {
      if (m.utcTicks > latest) latest = m.utcTicks;
    }
    final hadUnread = (_unreadCounts[channel] ?? 0) > 0;
    final advanced = latest != (_lastSeenTicks[channel] ?? 0);
    _lastSeenTicks[channel] = latest;
    _unreadCounts[channel] = 0;
    if (advanced) unawaited(_persistLastSeenTicks());
    if (hadUnread || advanced) notifyListeners();
  }

  /// Görülen zamanları kalıcı kayda yazar (S2#19).
  Future<void> _persistLastSeenTicks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastSeenPrefsKey,
      jsonEncode({
        for (final entry in _lastSeenTicks.entries) entry.key.id: entry.value,
      }),
    );
  }

  /// Buluta gönderilemeyip yalnız yerelde kalan mesajların kimlikleri.
  Set<String> get cloudFailedIds => Set.unmodifiable(_cloudFailedIds);

  /// Belirli bir mesajın buluta gönderilemediğini bildirir.
  bool isCloudFailed(String messageId) => _cloudFailedIds.contains(messageId);

  /// En az bir mesaj buluta gönderilememişse true (yerel-only çalışma).
  bool get hasCloudFailures => _cloudFailedIds.isNotEmpty;

  /// Geriye dönük uyumlu mesaj listesi (`ChatScreen` tarafından okunur).
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Aktif veya belirtilen kanaldaki mesajlar (engellenen yazarlar
  /// çıkarılmış hâliyle — depolanan liste değişmez, yalnız görünüm
  /// filtrelenir).
  List<ChatMessage> messagesForChannel(
    ChatChannel channel, {
    bool includeDefaultFeed = true,
  }) {
    final userList = _byChannel[channel] ?? const <ChatMessage>[];
    if (!includeDefaultFeed || userList.isNotEmpty) {
      return List.unmodifiable(_visibleMessages(userList));
    }
    return List.unmodifiable(_visibleMessages(_defaultFeedFor(channel)));
  }

  /// Kanalda kullanıcı/bulut mesajı var mı (engelleme filtresinden
  /// ÖNCE bakılır): arayüz, boş kanal ile "hepsi engelli" kanalı
  /// ayırır — ilkinde tohum içerik, ikincisinde boş durum gösterilir.
  bool hasUserMessages(ChatChannel channel) =>
      (_byChannel[channel] ?? const <ChatMessage>[]).isNotEmpty;

  /// Okunmamış rozet etiketi: yoklama penceresiyle sınırlı olduğundan
  /// sınırda "10+" gösterilir; kesin sayı iddia edilmez.
  static String unreadLabel(int count) {
    if (count >= unreadProbeLimit) {
      return '$unreadProbeLimit+';
    }
    return '$count';
  }

  /// Engellenen yazarların mesajlarını çıkarır (bağlı kimlikler dahil:
  /// engellenen misafir UUID'sinin hesaba bağlı UID'si de gizlenir).
  List<ChatMessage> _visibleMessages(List<ChatMessage> source) {
    if (_blockedAuthors.isEmpty) return source;
    return source.where((m) => !isBlocked(m.authorId)).toList();
  }

  /// Gerçek zamanlı mesaj akışı.
  Stream<List<ChatMessage>> get messageStream => _streamController.stream;
  Stream<ChatMessage> get onNewMessage => _newMessageController.stream;

  void switchChannel(ChatChannel channel) {
    if (_currentChannel == channel) return;
    // Ayrılınan kanalda görülenler okundu sayılır; yoklama, dönüşte
    // bunları tekrar saymaz.
    markChannelRead(_currentChannel);
    _currentChannel = channel;
    markChannelRead(channel);
    _bindCloudStreamIfReady();
    _streamController.add(messagesForChannel(_currentChannel));
    notifyListeners();
  }

  /// XSS/HTML tag temizliği, küfür/argo maskeleme ve 240 karakter sınırını uygular.
  static String sanitizeText(String raw) {
    var cleaned = raw;
    if (cleaned.isEmpty) return '';

    // 1. XSS ve tehlikeli script/style bloklarını ve HTML etiketlerini temizle.
    cleaned = cleaned.replaceAll(
      RegExp(
        r'<\s*(script|style|iframe|object|embed|svg|math)[^>]*>.*?<\s*/\s*\1\s*>',
        caseSensitive: false,
        dotAll: true,
      ),
      ' ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');
    cleaned = cleaned.replaceAll(
      RegExp(
        r'(javascript\s*:|vbscript\s*:|data\s*:\s*text/html|on\w+\s*=)',
        caseSensitive: false,
      ),
      '',
    );
    // Köşeli açı parantezlerini ve kontrol karakterlerini temizle.
    cleaned = cleaned
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    cleaned = cleaned.trim();
    if (cleaned.isEmpty) return '';

    // 2. 240 karakter sınırını zorunlu kıl.
    if (cleaned.length > maxMessageLength) {
      cleaned = cleaned.substring(0, maxMessageLength).trimRight();
    }

    // 3. 4'ten fazla tekrarlayan karakterleri kısalt (spam koruması).
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(.)\1{4,}', caseSensitive: false),
      (m) => '${m[1]}${m[1]}${m[1]}',
    );

    // 4. Küfür/argo filtresi (kelime bazlı maskeleme).
    for (final bad in _blockedWords) {
      final pattern = RegExp(
        '(^|[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ])(${RegExp.escape(bad)})(?=\$|[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ])',
        caseSensitive: false,
      );
      cleaned = cleaned.replaceAllMapped(
        pattern,
        (m) => '${m[1]}${'*' * bad.length}',
      );
    }

    if (cleaned.length > maxMessageLength) {
      cleaned = cleaned.substring(0, maxMessageLength);
    }
    return cleaned;
  }

  /// Çıkartma ses satırı temizliği: `sanitizeText` + firestore.rules
  /// `voiceLine` 1..120 sınırına kırpma.
  static String sanitizeVoiceLine(String raw) {
    final cleaned = sanitizeText(raw);
    if (cleaned.length > maxVoiceLineLength) {
      return cleaned.substring(0, maxVoiceLineLength).trimRight();
    }
    return cleaned;
  }

  /// K3: sohbet `authorName` kelepçesi — `firestore.rules` 1..32 ister.
  /// [CloudSyncService.sanitizeDisplayName] ile aynı sınır (32): kontrol
  /// karakterleri atılır, kırpılır, 32 karaktere kesilir, boşsa 'Oyuncu'
  /// döner. Kesme sessizdir, reddetme yok. `toJson` buradan geçer; metin,
  /// çıkartma ve meydan okuma dahil tüm yazım yolları korunur.
  static String sanitizeAuthorName(String raw) {
    final safe = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (safe.isEmpty) return 'Oyuncu';
    return safe.length > maxAuthorNameLength
        ? safe.substring(0, maxAuthorNameLength)
        : safe;
  }

  bool _isSpamming(String cleanBody) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentSendTimestampsMs.removeWhere((ts) => (now - ts) > burstWindowMs);
    if (_recentSendTimestampsMs.length >= maxMessagesPerBurstWindow) {
      return true;
    }
    if (cleanBody == _lastSentText &&
        (now - _lastSentAtMs) < duplicateRateLimitMs) {
      return true;
    }
    _lastSentText = cleanBody;
    _lastSentAtMs = now;
    _recentSendTimestampsMs.add(now);
    return false;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Kalıcı sohbeti yükler. Eşzamanlı çağrılar aynı yüklemeyi
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
    final raw = prefs.getString(_prefsKey);
    _messages.clear();
    _lastSentText = '';
    _lastSentAtMs = 0;
    _recentSendTimestampsMs.clear();
    for (final c in ChatChannel.values) {
      _byChannel[c] = <ChatMessage>[];
    }
    _guestIdentity = null;
    _termsAccepted = false;
    _blockedAuthors.clear();
    _reportedIds.clear();
    _pendingReports.clear();
    _identityLinks = {};

    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          final msg = ChatMessage.fromJson(e as Map<String, dynamic>);
          _messages.add(msg);
          _byChannel[msg.channel]?.add(msg);
        }
      } catch (_) {
        _messages.clear();
      }
    }

    final rawChannels = prefs.getString(_channelsPrefsKey);
    if (rawChannels != null && rawChannels.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawChannels) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          final channel = ChatChannel.fromId(key);
          final list = (value as List<dynamic>)
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
          _byChannel[channel] = list;
        });
      } catch (_) {}
    }

    // Okunmamış yoklaması başlangıcı: önbellekteki mesajlar okunmuş sayılır.
    for (final c in ChatChannel.values) {
      var latest = 0;
      for (final m in _byChannel[c] ?? const <ChatMessage>[]) {
        if (m.utcTicks > latest) latest = m.utcTicks;
      }
      _lastSeenTicks[c] = latest;
      _unreadCounts[c] = 0;
    }

    // Kalıcı görülen zamanlar: önbelleğe girmemiş ama okunmuş sayılan
    // mesajlar yeniden başlatmada okunmamış sayılmaz (S2#19). Her
    // kanalda büyük olan kazanır — görülen zaman yalnız ilerler.
    final lastSeenRaw = prefs.getString(_lastSeenPrefsKey);
    if (lastSeenRaw != null && lastSeenRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(lastSeenRaw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is num) {
            final channel = ChatChannel.fromId(key);
            final stored = value.toInt();
            if (stored > (_lastSeenTicks[channel] ?? 0)) {
              _lastSeenTicks[channel] = stored;
            }
          }
        });
      } catch (_) {}
    }

    // Moderasyon durumu: misafir kimliği, şart onayı, engel/rapor
    // kayıtları ve kimlik eşlemesi her yüklemede prefs'ten okunur
    // (bellek durumu prefs'i yansıtır; test izolasyonu da korunur).
    _termsAccepted = prefs.getBool(_termsPrefsKey) ?? false;
    final rawIdentity = prefs.getString(_guestIdentityPrefsKey);
    if (rawIdentity != null && rawIdentity.isNotEmpty) {
      try {
        final identity = GuestChatIdentity.fromJson(
          jsonDecode(rawIdentity) as Map<String, dynamic>,
        );
        if (identity.id.isNotEmpty && identity.displayName.isNotEmpty) {
          _guestIdentity = identity;
        }
      } catch (_) {}
    }
    final rawBlocked = prefs.getString(_blockedPrefsKey);
    if (rawBlocked != null && rawBlocked.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBlocked) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is String) _blockedAuthors[key] = value;
        });
      } catch (_) {}
    }
    final rawReported = prefs.getStringList(_reportedPrefsKey);
    if (rawReported != null) _reportedIds.addAll(rawReported);
    final rawPending = prefs.getString(_pendingReportsPrefsKey);
    if (rawPending != null && rawPending.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPending) as List<dynamic>;
        for (final e in decoded) {
          if (e is Map<String, dynamic>) _pendingReports.add(e);
        }
      } catch (_) {}
    }
    await _loadIdentityLinks(prefs);

    _loaded = true;
    _bindCloudStreamIfReady();
    _streamController.add(messages);
    notifyListeners();
  }

  /// Hesap silme için yerel sohbet verisini temizler (hesap-silme,
  /// yerel-temizlik): mesajlar, kanal önbellekleri, okunmamış sayaçlar
  /// ve görülen zamanlar (kalıcı anahtarları dahil) silinir; bulut
  /// abonelikleri kapatılır. Bulut mesajları
  /// [deleteMessagesByAuthor] ile silinir (AuthService.deleteAccount
  /// çağırır).
  Future<void> clearLocalData() async {
    await _cloudSub?.cancel();
    _cloudSub = null;
    for (final sub in _unreadSubs.values) {
      sub.cancel();
    }
    _unreadSubs.clear();
    _messages.clear();
    for (final c in ChatChannel.values) {
      _byChannel[c] = <ChatMessage>[];
      _unreadCounts[c] = 0;
    }
    _lastSeenTicks.clear();
    _cloudFailedIds.clear();
    _lastSentText = '';
    _lastSentAtMs = 0;
    _recentSendTimestampsMs.clear();
    _guestIdentity = null;
    _termsAccepted = false;
    _blockedAuthors.clear();
    _reportedIds.clear();
    _pendingReports.clear();
    _identityLinks = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_channelsPrefsKey);
    await prefs.remove(_lastSeenPrefsKey);
    await prefs.remove(_guestIdentityPrefsKey);
    await prefs.remove(_termsPrefsKey);
    await prefs.remove(_blockedPrefsKey);
    await prefs.remove(_reportedPrefsKey);
    await prefs.remove(_pendingReportsPrefsKey);
    _loaded = false;
    _streamController.add(messages);
    notifyListeners();
  }

  /// Hesap silme için bulut sohbet mesajlarını Firestore'dan siler:
  /// bütün kanallardaki (`lobby`, `clan`, `vs` + eski `vsChallenge`
  /// adı) `authorId`/`senderId` değeri [uid] olan mesajlar. Kural
  /// gereği yalnız mesajın göndereni silebilir (bkz. firestore.rules).
  /// Firebase hazır değilse hiçbir şey yapmaz.
  Future<void> deleteMessagesByAuthor(String uid) async {
    if (!FirebaseBootstrap.isAvailable) return;
    final db = FirebaseFirestore.instance;
    final channelIds = <String>{
      for (final c in ChatChannel.values) c.id,
      'vsChallenge',
    };
    for (final channelId in channelIds) {
      for (final field in const ['authorId', 'senderId']) {
        final snap = await db
            .collection('chat_channels')
            .doc(channelId)
            .collection('messages')
            .where(field, isEqualTo: uid)
            .get();
        if (snap.docs.isEmpty) continue;
        final batch = db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
  }

  List<ChatMessage> _defaultFeedFor(ChatChannel channel) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    switch (channel) {
      case ChatChannel.lobby:
        return [
          ChatMessage(
            id: 'sys_lobby',
            authorId: 'system',
            authorName: 'Lülülü',
            body: 'Genel Lobi sohbetine hoş geldin! Kombolarını paylaş.',
            utcTicks: now - 60000,
            isSystem: true,
            channel: ChatChannel.lobby,
          ),
          ChatMessage(
            id: 'bot_kongo',
            authorId: 'npc_kongo',
            authorName: 'Kongo Lideri',
            body: 'Kurban olduğum Kongo istilası! Kim Suika rekor kıracak?',
            utcTicks: now - 45000,
            channel: ChatChannel.lobby,
          ),
          ChatMessage(
            id: 'bot_diva',
            authorId: 'npc_diva',
            authorName: 'Hamam Diva',
            body: 'Ay bayılazaam — Match3 komboları flaş flaş ✨',
            utcTicks: now - 30000,
            channel: ChatChannel.lobby,
          ),
        ];
      case ChatChannel.clan:
        return [
          ChatMessage(
            id: 'clan_1',
            authorId: 'npc_huni',
            authorName: 'HuniKafa',
            body: 'Lonca turnuvası cumartesi 20.00\'da. Herkes arenada olsun!',
            utcTicks: now - 40000,
            channel: ChatChannel.clan,
          ),
          ChatMessage(
            id: 'clan_2',
            authorId: 'npc_dede',
            authorName: 'BilgeDede',
            body: 'Klan sandığı için son 3 yıldız kaldı gençler!',
            utcTicks: now - 20000,
            channel: ChatChannel.clan,
          ),
        ];
      case ChatChannel.vsChallenge:
        return [
          ChatMessage(
            id: 'vs_1',
            authorId: 'npc_terlik',
            authorName: 'TerlikUstası',
            body: '⚔️ VS Meydan Okuma: Suika Arena · Hedef 8.540 puan!',
            utcTicks: now - 25000,
            channel: ChatChannel.vsChallenge,
            challengeModeId: 'suika',
            challengeTargetScore: 8540,
          ),
        ];
    }
  }

  /// Bulut okuma kapısı: Firebase hazır + Firebase oturumu var.
  /// Kayıtlı kullanıcıda UID uyumu da şart (K1/K4); misafirde anonim
  /// oturum yeterlidir — misafir yazıları kuralca yapısal doğrulanır
  /// (`authorKind == 'guest'` + kalıcı misafir UUID'si).
  bool get _cloudIdentityAligned {
    if (!_cloudAuthReady) return false;
    try {
      final auth = AuthService.instance;
      if (auth.isSignedIn && !(auth.user?.isGuest ?? true)) {
        return fb.FirebaseAuth.instance.currentUser?.uid == auth.playerId;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Firebase oturumu var mı (anonim dahil).
  bool get _cloudAuthReady {
    if (!FirebaseBootstrap.isAvailable) return false;
    try {
      return fb.FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Mesaj bazında bulut yazım kapısı: kullanıcı mesajında UID uyumu,
  /// misafir mesajında oturum varlığı yeterlidir.
  bool _canPushMessage(ChatMessage msg) {
    if (!_cloudAuthReady) return false;
    if (msg.authorKind == ChatAuthorKind.user) {
      try {
        return fb.FirebaseAuth.instance.currentUser?.uid == msg.authorId;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Misafir bulut yazımı için anonim Firebase oturumunu sağlar
  /// (en iyi çaba; başarısızlık sessizce yerel-only durumuna düşer).
  /// Anonim oturum yalnız taşıma kimliğidir, yazar kimliğini
  /// değiştirmez — atıf her zaman kalıcı misafir UUID'sine yapılır.
  Future<void> _ensureGuestCloudCredential() async {
    if (!FirebaseBootstrap.isAvailable || _cloudAuthReady) return;
    try {
      await AuthService.instance.signInAsGuest();
    } catch (e) {
      debugPrint('[lululu] Chat guest cloud credential fallback: $e');
    }
  }

  /// Oturum değişiminden sonra bulut dinlemesini kapıya göre yeniden
  /// kurar (girişte bağlan, çıkışta/uyumsuzlukta kapat). Giriş anında
  /// kapı açılır ama kanal değiştirilmezse akışın kendiliğinden
  /// bağlanması için [AuthService] burayı çağırır. Kuyruktaki
  /// raporlar da bu noktada tekrar denenir.
  void refreshCloudBinding() {
    _bindCloudStreamIfReady();
    unawaited(retryPendingReports());
  }

  /// Misafir->hesap eşlemesini prefs'ten tazeler (giriş sonrası
  /// [AuthService] çağırır; engel çözümlemesi güncel kalır).
  Future<void> refreshIdentityLinks() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadIdentityLinks(prefs);
    notifyListeners();
  }

  Future<void> _loadIdentityLinks(SharedPreferences prefs) async {
    _identityLinks = {};
    final raw = prefs.getString(AuthService.guestIdentityLinksKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((key, value) {
        if (value is String && value.isNotEmpty) {
          _identityLinks[key] = value;
        }
      });
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // Misafir kimliği, şart onayı, engelleme, raporlama (UGC moderasyonu)
  // ---------------------------------------------------------------

  /// Yüklü misafir kimliği (yoksa null; [ensureGuestIdentity] oluşturur).
  GuestChatIdentity? get guestIdentity => _guestIdentity;

  /// Şart onayı verilmiş mi.
  bool get hasAcceptedChatTerms => _termsAccepted;

  /// Şart onayını kalıcı kaydeder.
  Future<void> acceptChatTerms() async {
    _termsAccepted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_termsPrefsKey, true);
    notifyListeners();
  }

  /// Gönderim için şart kapısı: onaysız gönderim denemesi
  /// [ChatTermsRequiredException] fırlatır.
  void _requireTermsAccepted() {
    if (!_termsAccepted) {
      throw const ChatTermsRequiredException();
    }
  }

  /// Kalıcı misafir kimliğini döndürür; yoksa oluşturup saklar.
  /// Kimlik oturumlar arasında aynı kalır (UUID değişmez).
  Future<GuestChatIdentity> ensureGuestIdentity() async {
    final existing = _guestIdentity;
    if (existing != null) return existing;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestIdentityPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final identity = GuestChatIdentity.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (identity.id.isNotEmpty && identity.displayName.isNotEmpty) {
          _guestIdentity = identity;
          return identity;
        }
      } catch (_) {}
    }
    final id = _newGuestId();
    final created = GuestChatIdentity(
      id: id,
      displayName: _defaultGuestDisplayName(id),
      createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    _guestIdentity = created;
    await prefs.setString(
      _guestIdentityPrefsKey,
      jsonEncode(created.toJson()),
    );
    notifyListeners();
    return created;
  }

  /// Yeni misafir UUID'si: `guest_` + 20 güvenli rastgele hex karakter.
  /// Kural deseniyle (`^guest_[0-9a-f]{8,64}$`) uyumludur.
  static String _newGuestId() {
    final random = Random.secure();
    const hex = '0123456789abcdef';
    final suffix =
        List.generate(20, (_) => hex[random.nextInt(hex.length)]).join();
    return 'guest_$suffix';
  }

  /// Varsayılan görünen ad: dile göre `Misafir-4821` / `Guest-4821`.
  /// Sonek kimlikten türetilir (kararlı, çakışması düşük); ad sonradan
  /// değiştirilebilir.
  static String _defaultGuestDisplayName(String guestId) {
    var hash = 0;
    for (final unit in guestId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final suffix = 1000 + (hash % 9000);
    final locale = PlatformDispatcher.instance.locale;
    return locale.languageCode == 'en'
        ? 'Guest-$suffix'
        : 'Misafir-$suffix';
  }

  /// Misafir görünen adını değiştirir: boş olamaz, kırpılır,
  /// [maxGuestDisplayNameLength] ile sınırlanır. UUID değişmez.
  /// Geçersiz adlarda false döner, kayıt değişmez.
  Future<bool> setGuestDisplayName(String raw) async {
    final identity = await ensureGuestIdentity();
    final cleaned =
        raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
    if (cleaned.isEmpty) return false;
    final clamped = cleaned.length > maxGuestDisplayNameLength
        ? cleaned.substring(0, maxGuestDisplayNameLength).trimRight()
        : cleaned;
    if (clamped.isEmpty) return false;
    if (clamped == identity.displayName) return true;
    final updated = identity.copyWith(displayName: clamped);
    _guestIdentity = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _guestIdentityPrefsKey,
      jsonEncode(updated.toJson()),
    );
    notifyListeners();
    return true;
  }

  /// Gönderimde kullanılacak yazar kimliği: kayıtlı kullanıcıda hesap
  /// kimliği, misafirde (oturumsuz veya anonim misafir oturumu) kalıcı
  /// misafir kimliği. Anonim Firebase oturumu yalnız taşıma kimliğidir,
  /// yazar kimliği değildir — atıf her zaman kararlı misafir UUID'sine
  /// yapılır.
  Future<({String authorId, String authorName, ChatAuthorKind kind})>
      _resolveSender() async {
    await AuthService.instance.ensureLoaded();
    final auth = AuthService.instance;
    if (auth.isSignedIn && !(auth.user?.isGuest ?? true)) {
      return (
        authorId: auth.playerId,
        authorName: auth.displayName,
        kind: ChatAuthorKind.user,
      );
    }
    final identity = await ensureGuestIdentity();
    return (
      authorId: identity.id,
      authorName: identity.displayName,
      kind: ChatAuthorKind.guest,
    );
  }

  /// Bu cihazın güncel yazar kimliği (eşzamanlı): kayıtlı kullanıcıda
  /// hesap id'si, misafirde yüklü kimlik id'si, yüklenmemişse null.
  /// [isOwnMessage] ve okunmamış sayımı buradan okur.
  String? get currentAuthorId {
    final auth = AuthService.instance;
    if (auth.isSignedIn && !(auth.user?.isGuest ?? true)) {
      return auth.playerId;
    }
    return _guestIdentity?.id;
  }

  /// Mesaj bu cihazın yazarına mı ait.
  bool isOwnMessage(ChatMessage message) {
    final own = currentAuthorId;
    return own != null && own.isNotEmpty && message.authorId == own;
  }

  /// Engellenen yazarlar: kimlik -> görünen ad (salt okunur görünüm).
  Map<String, String> get blockedAuthors => Map.unmodifiable(_blockedAuthors);

  /// Engellenen yazar kimlikleri.
  Set<String> get blockedAuthorIds => Set.unmodifiable(_blockedAuthors.keys);

  /// Yazar engelli mi (bağlı kimlikler dahil: engellenen misafir
  /// UUID'sinin hesaba bağlı UID'si de engelli sayılır ve tersi).
  bool isBlocked(String authorId) {
    if (_blockedAuthors.containsKey(authorId)) return true;
    for (final linked in _linkedCounterparts(authorId)) {
      if (_blockedAuthors.containsKey(linked)) return true;
    }
    return false;
  }

  /// Kimliğin göçle bağlı karşılıkları (misafir UUID <-> hesap UID).
  Set<String> _linkedCounterparts(String authorId) {
    final out = <String>{};
    final linked = _identityLinks[authorId];
    if (linked != null) out.add(linked);
    _identityLinks.forEach((guestId, uid) {
      if (uid == authorId) out.add(guestId);
    });
    return out;
  }

  /// Yazarı engeller: mesajları sohbette gizlenir. Engel cihazda
  /// kalıcıdır; kendi kimliği engellenemez.
  Future<void> blockAuthor(String authorId, {String? authorName}) async {
    if (authorId.isEmpty || authorId == currentAuthorId) return;
    _blockedAuthors[authorId] = authorName ?? authorId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_blockedPrefsKey, jsonEncode(_blockedAuthors));
    notifyListeners();
  }

  /// Yazarın engelini kaldırır. Engel kaydı kimlik bazlıdır; bağlı
  /// kimliğin engeli ayrıca kaldırılır.
  Future<void> unblockAuthor(String authorId) async {
    if (_blockedAuthors.remove(authorId) == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_blockedPrefsKey, jsonEncode(_blockedAuthors));
    notifyListeners();
  }

  /// Mesajı raporlar: `chat_reports` koleksiyonuna yazılır (bulut
  /// hazırsa hemen, değilse kuyruğa alınıp bağlantı gelince
  /// gönderilir). Aynı mesaj iki kez raporlanmaz; sonuç
  /// [ChatReportOutcome] ile bildirilir. Raporlama şart onayı istemez.
  Future<ChatReportOutcome> reportMessage(
    ChatMessage message,
    ChatReportReason reason,
  ) async {
    await ensureLoaded();
    if (_reportedIds.contains(message.id)) {
      return ChatReportOutcome.alreadyReported;
    }
    final sender = await _resolveSender();
    var body = sanitizeText(message.body);
    if (body.isEmpty) body = '-';
    final report = <String, dynamic>{
      'messageId': message.id,
      'channelId': message.channel.id,
      'reportedAuthorId': message.authorId,
      'reportedAuthorKind': message.authorKind.id,
      'reportedAuthorName': sanitizeAuthorName(message.authorName),
      'messageBody': body,
      'reason': reason.id,
      'reporterId': sender.authorId,
      'reporterKind': sender.kind.id,
      'createdAtMs': DateTime.now().toUtc().millisecondsSinceEpoch,
    };
    _reportedIds.add(message.id);
    _pendingReports.add(report);
    await _persistReportState();
    if (_cloudAuthReady) {
      try {
        await FirebaseFirestore.instance
            .collection('chat_reports')
            .add(report);
        _pendingReports.remove(report);
        await _persistReportState();
        return ChatReportOutcome.sent;
      } catch (e) {
        debugPrint('[lululu] Chat report queued: $e');
      }
    }
    return ChatReportOutcome.queued;
  }

  /// Kuyruktaki raporları buluta göndermeyi dener.
  Future<void> retryPendingReports() async {
    if (_pendingReports.isEmpty || !_cloudAuthReady) return;
    final remaining = <Map<String, dynamic>>[];
    for (final report in _pendingReports) {
      try {
        await FirebaseFirestore.instance
            .collection('chat_reports')
            .add(report);
      } catch (_) {
        remaining.add(report);
      }
    }
    if (remaining.length != _pendingReports.length) {
      _pendingReports
        ..clear()
        ..addAll(remaining);
      await _persistReportState();
    }
  }

  Future<void> _persistReportState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_reportedPrefsKey, _reportedIds.toList());
    await prefs.setString(
      _pendingReportsPrefsKey,
      jsonEncode(_pendingReports),
    );
  }

  void _bindCloudStreamIfReady() {
    _cloudSub?.cancel();
    _cloudSub = null;
    // Yoklamalar da sıfırdan kurulur; bulut yoksa yalnız iptal edilir.
    _bindUnreadProbes();
    if (!FirebaseBootstrap.isAvailable || !_cloudIdentityAligned) return;
    try {
      _cloudSub = FirebaseFirestore.instance
          .collection('chat_channels')
          .doc(_currentChannel.id)
          .collection('messages')
          .orderBy('utcTicks', descending: false)
          .limitToLast(maxMessages)
          .snapshots()
          .listen((snapshot) {
        var addedAny = false;
        final list = _byChannel[_currentChannel] ?? <ChatMessage>[];
        for (final doc in snapshot.docs) {
          final msg = ChatMessage.fromJson(doc.data());
          if (msg.id.isEmpty) continue;
          if (!list.any((m) => m.id == msg.id)) {
            list.add(msg);
            if (_currentChannel == ChatChannel.lobby &&
                !_messages.any((m) => m.id == msg.id)) {
              _messages.add(msg);
            }
            addedAny = true;
          }
        }
        if (addedAny) {
          // Aktif kanalda görülenler okundu sayılır (S2#19): kanaldan
          // ayrılınınca yoklama bunları tekrar saymaz.
          _unreadCounts[_currentChannel] = 0;
          var latest = _lastSeenTicks[_currentChannel] ?? 0;
          for (final m in list) {
            if (m.utcTicks > latest) latest = m.utcTicks;
          }
          final advanced = latest != (_lastSeenTicks[_currentChannel] ?? 0);
          _lastSeenTicks[_currentChannel] = latest;
          if (advanced) unawaited(_persistLastSeenTicks());
          _streamController.add(messages);
          notifyListeners();
        }
      }, onError: (Object e) {
        debugPrint('[lululu] Chat cloud stream fallback: $e');
      });
    } catch (e) {
      debugPrint('[lululu] Chat cloud stream bind error: $e');
    }
  }

  /// Aktif olmayan kanalları hafif dinler (S2#19): yalnız son
  /// [unreadProbeLimit] mesaj okunur, mesaj listelerine yazılmaz, yalnız
  /// okunmamış sayacı güncellenir. Sayaç bu pencereyle sınırlıdır.
  void _bindUnreadProbes() {
    for (final sub in _unreadSubs.values) {
      sub.cancel();
    }
    _unreadSubs.clear();
    // K1/K4 (W60-6): kimlik uyumsuzken okunmamış yoklaması da kurulmaz.
    if (!FirebaseBootstrap.isAvailable || !_cloudIdentityAligned) return;
    for (final channel in ChatChannel.values) {
      if (channel == _currentChannel) continue;
      try {
        _unreadSubs[channel] = FirebaseFirestore.instance
            .collection('chat_channels')
            .doc(channel.id)
            .collection('messages')
            .orderBy('utcTicks', descending: false)
            .limitToLast(unreadProbeLimit)
            .snapshots()
            .listen(
          (snapshot) => _updateUnreadFromProbe(channel, snapshot),
          onError: (Object e) {
            debugPrint('[lululu] Chat okunmamış yoklama hatası '
                '(${channel.id}): $e');
          },
        );
      } catch (e) {
        debugPrint('[lululu] Chat okunmamış yoklama bağlanamadı '
            '(${channel.id}): $e');
      }
    }
  }

  /// Yoklama anlık görüntüsünden okunmamış sayısını hesaplar: görülen
  /// zamandan yeni + başkasına ait + yerelde bilinmeyen mesajlar sayılır.
  void _updateUnreadFromProbe(
    ChatChannel channel,
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (channel == _currentChannel) return;
    final seen = _lastSeenTicks[channel] ?? 0;
    final ownId = currentAuthorId ?? '';
    final knownIds = <String>{
      for (final m in _byChannel[channel] ?? const <ChatMessage>[]) m.id,
    };
    var count = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final id = data['id'] as String? ?? doc.id;
      final ticks = (data['utcTicks'] as num?)?.toInt() ?? 0;
      final authorId = data['authorId'] as String? ?? '';
      if (ticks > seen && authorId != ownId && !knownIds.contains(id)) {
        count++;
      }
    }
    if ((_unreadCounts[channel] ?? 0) != count) {
      _unreadCounts[channel] = count;
      notifyListeners();
    }
  }

  /// Metin mesajı gönderir (`send` için alias).
  Future<ChatMessage> sendText(
    String text, {
    ChatChannel? channel,
  }) =>
      send(text, channel: channel);

  Future<ChatMessage> send(
    String text, {
    ChatChannel? channel,
  }) async {
    await ensureLoaded();
    _requireTermsAccepted();
    final cleanBody = sanitizeText(text);
    if (cleanBody.isEmpty) {
      throw ArgumentError('Boş mesaj gönderilemez');
    }
    if (_isSpamming(cleanBody)) {
      throw StateError('Çok hızlı mesaj gönderiyorsun — biraz bekle');
    }

    final sender = await _resolveSender();
    final targetChannel = channel ?? _currentChannel;

    final msg = ChatMessage(
      id: 'm_${DateTime.now().microsecondsSinceEpoch}',
      authorId: sender.authorId,
      authorName: sender.authorName,
      authorKind: sender.kind,
      body: cleanBody,
      utcTicks: DateTime.now().toUtc().millisecondsSinceEpoch,
      channel: targetChannel,
    );

    await _appendAndPersist(msg);
    return msg;
  }

  /// Böcek çıkartması ve repliği gönderir (Tier 1..8+).
  Future<ChatMessage> sendBugSticker(
    int tier, {
    ChatChannel? channel,
    String? customLine,
  }) async {
    await ensureLoaded();
    _requireTermsAccepted();
    final clampedTier = tier.clamp(1, 13);
    final info = bugStickerCatalog[clampedTier] ??
        (
          name: 'Tier $clampedTier Böcek',
          line: 'LÜLÜLÜ SAHNEDE!',
          asset: clampedTier <= 8
              ? 'assets/design/bugs_hd/tier${clampedTier}_hd.png'
              : 'assets/design/bugs_new/tier${clampedTier}_hd.png',
        );
    // Ses satırı firestore.rules voiceLine 1..120 sınırına kırpılır.
    final spoken = (customLine != null && customLine.trim().isNotEmpty)
        ? sanitizeVoiceLine(customLine)
        : sanitizeVoiceLine(info.line);
    final targetChannel = channel ?? _currentChannel;
    final bodyText = sanitizeText('🪳 [T$clampedTier ${info.name}] "$spoken"');
    if (_isSpamming(bodyText)) {
      throw StateError('Çok hızlı mesaj gönderiyorsun — biraz bekle');
    }

    final sender = await _resolveSender();
    final msg = ChatMessage(
      id: 'stk_${DateTime.now().microsecondsSinceEpoch}',
      authorId: sender.authorId,
      authorName: sender.authorName,
      authorKind: sender.kind,
      body: bodyText,
      utcTicks: DateTime.now().toUtc().millisecondsSinceEpoch,
      channel: targetChannel,
      stickerTier: clampedTier,
      stickerAsset: info.asset,
      voiceLine: spoken,
    );

    await _appendAndPersist(msg);
    return msg;
  }

  /// VS Meydan Okuma kanalına düello davet mesajı gönderir.
  Future<ChatMessage> sendVsChallenge({
    required String modeId,
    required int targetScore,
    String? modeTitle,
  }) async {
    await ensureLoaded();
    _requireTermsAccepted();
    final safeScore = targetScore.clamp(1, 500000);
    final rawLabel = modeTitle ?? modeId.toUpperCase();
    final label = sanitizeText(rawLabel);
    final bodyText = sanitizeText(
      '⚔️ VS Meydan Okuma: $label modunda $safeScore puanı geçebilir misin?',
    );
    if (_isSpamming(bodyText)) {
      throw StateError('Çok hızlı mesaj gönderiyorsun — biraz bekle');
    }

    final sender = await _resolveSender();
    final msg = ChatMessage(
      id: 'vs_${DateTime.now().microsecondsSinceEpoch}',
      authorId: sender.authorId,
      authorName: sender.authorName,
      authorKind: sender.kind,
      body: bodyText,
      utcTicks: DateTime.now().toUtc().millisecondsSinceEpoch,
      channel: ChatChannel.vsChallenge,
      challengeModeId: modeId,
      challengeTargetScore: safeScore,
    );

    await _appendAndPersist(msg);
    return msg;
  }

  Future<void> _appendAndPersist(ChatMessage msg) async {
    _messages.add(msg);
    if (_messages.length > maxMessages) {
      _messages.removeRange(0, _messages.length - maxMessages);
    }

    final channelList = _byChannel.putIfAbsent(msg.channel, () => <ChatMessage>[]);
    channelList.add(msg);
    if (channelList.length > maxMessages) {
      channelList.removeRange(0, channelList.length - maxMessages);
    }

    await _save();
    _newMessageController.add(msg);
    _streamController.add(messages);
    notifyListeners();

    // Misafir bulut yazımı anonim oturum ister: yoksa en iyi çabayla
    // sağlanır (başarısızlık yerel-only durumuna düşer).
    if (msg.authorKind == ChatAuthorKind.guest) {
      await _ensureGuestCloudCredential();
    }
    // Mesaj bazında kapı: kullanıcıda UID uyumu, misafirde oturum
    // varlığı. Kapalıysa mesaj yerelde kalır ve başarısız işaretli
    // kalır (çevrimdışı kuyruk, [retryFailedCloudPushes]).
    if (_canPushMessage(msg)) {
      try {
        await FirebaseFirestore.instance
            .collection('chat_channels')
            .doc(msg.channel.id)
            .collection('messages')
            .doc(msg.id)
            .set(msg.toJson());
        _cloudFailedIds.remove(msg.id);
      } catch (e) {
        // Sessiz yutma yok: başarısızlık işaretlenir, arayüz gösterir.
        _cloudFailedIds.add(msg.id);
        debugPrint('[lululu] Chat cloud push fallback: $e');
        notifyListeners();
      }
    } else {
      // Bulut kapalı: mesaj yalnız yerelde — durum görünür olsun.
      _cloudFailedIds.add(msg.id);
      notifyListeners();
    }
  }

  /// Buluta gönderilemeyen mesajları yeniden göndermeyi dener.
  /// Tümü yazılırsa true döner; başarısız kalanlar işaretli kalır.
  /// Kapı mesaj bazındadır: kapalı kimlikteki mesajlar kuyrukta kalır.
  Future<bool> retryFailedCloudPushes() async {
    if (_cloudFailedIds.isEmpty) return true;
    final byId = <String, ChatMessage>{};
    for (final m in _messages) {
      byId[m.id] = m;
    }
    for (final list in _byChannel.values) {
      for (final m in list) {
        byId[m.id] = m;
      }
    }
    // Artık bellekte olmayan mesajların işaretini temizle.
    for (final id in _cloudFailedIds.toList()) {
      if (!byId.containsKey(id)) _cloudFailedIds.remove(id);
    }
    if (byId.values
        .any((m) => m.authorKind == ChatAuthorKind.guest)) {
      await _ensureGuestCloudCredential();
    }
    var allOk = true;
    for (final id in _cloudFailedIds.toList()) {
      final msg = byId[id]!;
      if (!_canPushMessage(msg)) {
        allOk = false;
        continue;
      }
      try {
        final ref = FirebaseFirestore.instance
            .collection('chat_channels')
            .doc(msg.channel.id)
            .collection('messages')
            .doc(msg.id);
        // Y1 (W60-6): kural `update: false` — ilk yazım sunucuda
        // tamamlanıp yanıtı kaybolmuşsa belge zaten vardır; yeniden
        // `.set()` update sayılıp reddedilir. Varsa yazmadan başarılı say.
        final existing = await ref.get();
        if (existing.exists) {
          _cloudFailedIds.remove(msg.id);
          continue;
        }
        await ref.set(msg.toJson());
        _cloudFailedIds.remove(msg.id);
      } catch (e) {
        allOk = false;
        debugPrint('[lululu] Chat cloud retry fallback: $e');
      }
    }
    notifyListeners();
    return allOk;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_messages.map((m) => m.toJson()).toList()),
    );
    final channelMap = <String, dynamic>{
      for (final entry in _byChannel.entries)
        entry.key.id: entry.value.map((m) => m.toJson()).toList(),
    };
    await prefs.setString(_channelsPrefsKey, jsonEncode(channelMap));
  }

  @override
  void dispose() {
    _cloudSub?.cancel();
    for (final sub in _unreadSubs.values) {
      sub.cancel();
    }
    _unreadSubs.clear();
    _streamController.close();
    _newMessageController.close();
    super.dispose();
  }
}
