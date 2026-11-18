// B27 — kendi mesajını silme (3G): tek-mesaj silme servisi.
//
// Kapsam: `ChatService.deleteMessage` sözleşmesi — kendi mesajı
// silinir + kalıcıdır, olmayan kimlik `false` döner, başkasının /
// sistem mesajı silinemez, toplu silme API'si (`deleteMessagesByAuthor`)
// etkilenmez, bulut işareti temizlenir. Bulut silme yolu bu testlerde
// kapalıdır (Firebase hazır değil); kapı davranışı
// `lastDeleteCloudFailed` bayrağı üzerinden denetlenir.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/chat_service.dart';
import 'package:lululu_game/services/firebase_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FirebaseBootstrap.resetForTest();
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    final chat = ChatService.instance;
    await chat.load();
    await chat.acceptChatTerms();
    if (chat.currentChannel != ChatChannel.lobby) {
      chat.switchChannel(ChatChannel.lobby);
    }
  });

  /// Kalıcı blobları üretim yükleme yoluyla besler. Anahtar adları
  /// `ChatService` özel sabitlerinin değerleridir
  /// (`_prefsKey` / `_channelsPrefsKey` / `_guestIdentityPrefsKey`);
  /// mesaj + kimlik JSON'u üretim `toJson` çıkışıyla aynıdır.
  Future<void> seedStoredMessages(
    List<ChatMessage> messages,
    GuestChatIdentity identity,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'LululuChatLobbyV1',
      jsonEncode(messages.map((m) => m.toJson()).toList()),
    );
    final byChannel = <String, List<Map<String, dynamic>>>{};
    for (final m in messages) {
      byChannel.putIfAbsent(m.channel.id, () => []).add(m.toJson());
    }
    await prefs.setString('LululuChatChannelsV2', jsonEncode(byChannel));
    await prefs.setString(
      'LululuChatGuestIdentityV1',
      jsonEncode(identity.toJson()),
    );
    await ChatService.instance.load();
  }

  test('kendi mesajı silinir: listeden çıkar, bildirim + akış gelir, '
      'ikinci silme false döner', () async {
    final chat = ChatService.instance;
    final first = await chat.send('silinecek ilk mesaj');
    final second = await chat.send('kalacak ikinci mesaj');

    var notifications = 0;
    void onNotify() => notifications++;
    chat.addListener(onNotify);
    final streamEvents = <List<ChatMessage>>[];
    final subscription = chat.messageStream.listen(streamEvents.add);
    try {
      expect(await chat.deleteMessage(first.id), isTrue);
      await Future<void>.delayed(Duration.zero);
    } finally {
      chat.removeListener(onNotify);
      await subscription.cancel();
    }

    expect(notifications, 1);
    expect(streamEvents, isNotEmpty);
    expect(streamEvents.last.any((m) => m.id == first.id), isFalse);
    expect(
      chat.messagesForChannel(ChatChannel.lobby, includeDefaultFeed: false),
      hasLength(1),
    );
    expect(
      chat.messagesForChannel(ChatChannel.lobby, includeDefaultFeed: false)
          .single
          .id,
      second.id,
    );
    expect(chat.messages.any((m) => m.id == first.id), isFalse);
    // İkinci deneme: mesaj artık yok.
    expect(await chat.deleteMessage(first.id), isFalse);
    expect(chat.lastDeleteCloudFailed, isFalse);
  });

  test('silme kalıcıdır: yeniden yüklemede geri gelmez', () async {
    final chat = ChatService.instance;
    final deleted = await chat.send('kalıcı silme denemesi');
    final kept = await chat.send('kalıcı kalan mesaj');

    expect(await chat.deleteMessage(deleted.id), isTrue);

    await chat.load();
    expect(chat.messages.any((m) => m.id == deleted.id), isFalse);
    expect(
      chat.messagesForChannel(ChatChannel.lobby, includeDefaultFeed: false)
          .any((m) => m.id == deleted.id),
      isFalse,
    );
    expect(chat.messages.any((m) => m.id == kept.id), isTrue);
  });

  test('olmayan kimlik ve boş kimlik false döner, liste değişmez',
      () async {
    final chat = ChatService.instance;
    final kept = await chat.send('silinmeyecek mesaj');

    expect(await chat.deleteMessage('olmayan_kimlik'), isFalse);
    expect(chat.lastDeleteCloudFailed, isFalse);
    expect(await chat.deleteMessage(''), isFalse);
    expect(chat.lastDeleteCloudFailed, isFalse);

    expect(chat.messages.any((m) => m.id == kept.id), isTrue);
    expect(chat.messages, hasLength(1));
  });

  test('boş sohbette silme false döner', () async {
    final chat = ChatService.instance;
    expect(chat.messages, isEmpty);
    expect(await chat.deleteMessage('herhangi_bir_kimlik'), isFalse);
  });

  test('başkasının ve sistem mesajı silinemez; tohumlanmış kendi '
      'mesajı silinir', () async {
    final chat = ChatService.instance;
    const identity = GuestChatIdentity(
      id: 'guest_abcdef0123456789',
      displayName: 'Misafir-1234',
      createdAtMs: 1,
    );
    final own = ChatMessage(
      id: 'own_seed',
      authorId: identity.id,
      authorName: identity.displayName,
      body: 'tohumlanmış kendi mesajım',
      utcTicks: 10,
      channel: ChatChannel.lobby,
      authorKind: ChatAuthorKind.guest,
    );
    final other = ChatMessage(
      id: 'other_seed',
      authorId: 'uid_baskasi',
      authorName: 'Baskasi',
      body: 'baskasinin mesaji',
      utcTicks: 11,
      channel: ChatChannel.lobby,
      authorKind: ChatAuthorKind.user,
    );
    final system = ChatMessage(
      id: 'sys_seed',
      authorId: 'system',
      authorName: 'Lülülü',
      body: 'sistem mesaji',
      utcTicks: 12,
      isSystem: true,
      channel: ChatChannel.lobby,
    );
    await seedStoredMessages([own, other, system], identity);

    expect(chat.isOwnMessage(own), isTrue);
    expect(chat.isOwnMessage(other), isFalse);
    expect(chat.isOwnMessage(system), isFalse);

    expect(await chat.deleteMessage(other.id), isFalse);
    expect(await chat.deleteMessage(system.id), isFalse);
    expect(
      chat.messagesForChannel(ChatChannel.lobby, includeDefaultFeed: false),
      hasLength(3),
    );

    expect(await chat.deleteMessage(own.id), isTrue);
    // Firebase bu testlerde kapalı: bulut kapısı kapalı olduğundan
    // bulut kopyası kalmış olabilir bayrağı kalkar.
    expect(chat.lastDeleteCloudFailed, isTrue);
    expect(
      chat.messagesForChannel(ChatChannel.lobby, includeDefaultFeed: false)
          .map((m) => m.id),
      containsAll(['other_seed', 'sys_seed']),
    );
  });

  test('toplu silme API etkilenmez: yerel listeye dokunmaz, '
      'sonrasında tekli silme çalışır', () async {
    final chat = ChatService.instance;
    final msg = await chat.send('toplu silme etkilenmez denemesi');

    // Firebase kapalı: toplu yol erken döner, yerel durum aynı kalır.
    await chat.deleteMessagesByAuthor('uid_baskasi');
    expect(chat.messages.any((m) => m.id == msg.id), isTrue);
    await chat.deleteMessagesByAuthor(msg.authorId);
    expect(chat.messages.any((m) => m.id == msg.id), isTrue);

    expect(await chat.deleteMessage(msg.id), isTrue);
    expect(chat.messages.any((m) => m.id == msg.id), isFalse);
  });

  test('buluta ulaşmamış mesaj silinince başarısız işareti temizlenir '
      've bulut bayrağı kalkmaz', () async {
    final chat = ChatService.instance;
    final msg = await chat.send('bulut isareti temizleme denemesi');
    // Firebase kapalı: gönderim bulut işareti alır.
    expect(chat.isCloudFailed(msg.id), isTrue);

    expect(await chat.deleteMessage(msg.id), isTrue);
    expect(chat.isCloudFailed(msg.id), isFalse);
    expect(chat.cloudFailedIds, isNot(contains(msg.id)));
    // Mesaj buluta hiç ulaşmadı: bulut kopyası kaygısı yok.
    expect(chat.lastDeleteCloudFailed, isFalse);

    await chat.load();
    expect(chat.isCloudFailed(msg.id), isFalse);
  });

  test('kanal listesinden de silinir: klan mesajı silinince kanal '
      'boşalır', () async {
    final chat = ChatService.instance;
    final msg = await chat.send(
      'klan kanali silme denemesi',
      channel: ChatChannel.clan,
    );
    expect(chat.hasUserMessages(ChatChannel.clan), isTrue);

    expect(await chat.deleteMessage(msg.id), isTrue);
    expect(chat.hasUserMessages(ChatChannel.clan), isFalse);
    expect(
      chat.messagesForChannel(ChatChannel.clan, includeDefaultFeed: false),
      isEmpty,
    );

    await chat.load();
    expect(chat.hasUserMessages(ChatChannel.clan), isFalse);
  });
}
