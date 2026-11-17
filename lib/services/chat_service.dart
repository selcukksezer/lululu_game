import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:cloud_firestore/cloud_firestore.dart';
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

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.utcTicks,
    this.isSystem = false,
    this.channel = ChatChannel.lobby,
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
  final int? stickerTier;
  final String? stickerAsset;
  final String? voiceLine;
  final String? challengeModeId;
  final int? challengeTargetScore;

  bool get isSticker => stickerTier != null || stickerAsset != null;
  bool get isChallenge => challengeModeId != null;

  Map<String, dynamic> toJson() {
    // voiceLine kural sınırı (1..120): yazılan değer her zaman kırpılır.
    final safeVoiceLine =
        voiceLine == null ? null : ChatService.sanitizeVoiceLine(voiceLine!);
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
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
    return ChatMessage(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
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
  static const maxMessages = 200;

  /// Okunmamış yoklamasının pencere boyutu (S2#19): aktif olmayan her
  /// kanal yalnız son bu kadar mesajla dinlenir; sayaç bu sayıyla
  /// sınırlıdır (kesin sayı değil, "yeni mesaj var" işareti).
  static const int unreadProbeLimit = 10;
  static const int maxMessageLength = 240;
  static const int maxVoiceLineLength = 120;
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
  /// değeri yerelde önbellekli mesajlardan alınır.
  ///
  /// TODO (S2#19): Yalnız bellekte tutulur; yeniden başlatmada önbelleğe
  /// girmemiş okunmamışlar sıfırlanır. Kalıcı olması istenirse
  /// SharedPreferences'a yazılmalıdır.
  final Map<ChatChannel, int> _lastSeenTicks = {};

  /// Buluta yazımı başarısız olup yalnız yerelde kalan mesaj kimlikleri.
  final Set<String> _cloudFailedIds = <String>{};

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
    if (hadUnread || advanced) notifyListeners();
  }

  /// Buluta gönderilemeyip yalnız yerelde kalan mesajların kimlikleri.
  Set<String> get cloudFailedIds => Set.unmodifiable(_cloudFailedIds);

  /// Belirli bir mesajın buluta gönderilemediğini bildirir.
  bool isCloudFailed(String messageId) => _cloudFailedIds.contains(messageId);

  /// En az bir mesaj buluta gönderilememişse true (yerel-only çalışma).
  bool get hasCloudFailures => _cloudFailedIds.isNotEmpty;

  /// Geriye dönük uyumlu mesaj listesi (`ChatScreen` tarafından okunur).
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Aktif veya belirtilen kanaldaki mesajlar.
  List<ChatMessage> messagesForChannel(
    ChatChannel channel, {
    bool includeDefaultFeed = true,
  }) {
    final userList = _byChannel[channel] ?? const <ChatMessage>[];
    if (!includeDefaultFeed || userList.isNotEmpty) {
      return List.unmodifiable(userList);
    }
    return List.unmodifiable(_defaultFeedFor(channel));
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

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    _messages.clear();
    _lastSentText = '';
    _lastSentAtMs = 0;
    _recentSendTimestampsMs.clear();
    for (final c in ChatChannel.values) {
      _byChannel[c] = <ChatMessage>[];
    }

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

    _loaded = true;
    _bindCloudStreamIfReady();
    _streamController.add(messages);
    notifyListeners();
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

  void _bindCloudStreamIfReady() {
    _cloudSub?.cancel();
    _cloudSub = null;
    // Yoklamalar da sıfırdan kurulur; bulut yoksa yalnız iptal edilir.
    _bindUnreadProbes();
    if (!FirebaseBootstrap.isAvailable) return;
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
          _lastSeenTicks[_currentChannel] = latest;
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
    if (!FirebaseBootstrap.isAvailable) return;
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
    final ownId = AuthService.instance.isSignedIn
        ? AuthService.instance.playerId
        : 'guest_local';
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
    final cleanBody = sanitizeText(text);
    if (cleanBody.isEmpty) {
      throw ArgumentError('Boş mesaj gönderilemez');
    }
    if (_isSpamming(cleanBody)) {
      throw StateError('Çok hızlı mesaj gönderiyorsun — biraz bekle');
    }

    await AuthService.instance.ensureLoaded();
    final auth = AuthService.instance;
    final authorId = auth.isSignedIn ? auth.playerId : 'guest_local';
    final authorName = auth.isSignedIn ? auth.displayName : 'Sen · LülüSever';
    final targetChannel = channel ?? _currentChannel;

    final msg = ChatMessage(
      id: 'm_${DateTime.now().microsecondsSinceEpoch}',
      authorId: authorId,
      authorName: authorName,
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
    await AuthService.instance.ensureLoaded();
    final auth = AuthService.instance;
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

    final msg = ChatMessage(
      id: 'stk_${DateTime.now().microsecondsSinceEpoch}',
      authorId: auth.isSignedIn ? auth.playerId : 'guest_local',
      authorName: auth.isSignedIn ? auth.displayName : 'Sen · LülüSever',
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
    await AuthService.instance.ensureLoaded();
    final auth = AuthService.instance;
    final safeScore = targetScore.clamp(1, 500000);
    final rawLabel = modeTitle ?? modeId.toUpperCase();
    final label = sanitizeText(rawLabel);
    final bodyText = sanitizeText(
      '⚔️ VS Meydan Okuma: $label modunda $safeScore puanı geçebilir misin?',
    );
    if (_isSpamming(bodyText)) {
      throw StateError('Çok hızlı mesaj gönderiyorsun — biraz bekle');
    }

    final msg = ChatMessage(
      id: 'vs_${DateTime.now().microsecondsSinceEpoch}',
      authorId: auth.isSignedIn ? auth.playerId : 'guest_local',
      authorName: auth.isSignedIn ? auth.displayName : 'Sen · LülüSever',
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

    if (FirebaseBootstrap.isAvailable) {
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
  Future<bool> retryFailedCloudPushes() async {
    if (_cloudFailedIds.isEmpty) return true;
    if (!FirebaseBootstrap.isAvailable) return false;
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
    var allOk = true;
    for (final id in _cloudFailedIds.toList()) {
      final msg = byId[id]!;
      try {
        await FirebaseFirestore.instance
            .collection('chat_channels')
            .doc(msg.channel.id)
            .collection('messages')
            .doc(msg.id)
            .set(msg.toJson());
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
