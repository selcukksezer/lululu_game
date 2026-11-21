// Sohbet moderasyonu: kalıcı misafir kimliği, şart onayı, engelleme,
// raporlama ve authorKind kalıcılığı testleri.
//
// Misafir kimliği cihazda saklanan sabit bir UUID + otomatik görünen
// ad'dır; yazar id'si artık paylaşılan 'guest_local' değildir.
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
    if (chat.currentChannel != ChatChannel.lobby) {
      chat.switchChannel(ChatChannel.lobby);
    }
  });

  test('misafir kimliği ilk kullanımda oluşur ve yeniden yüklemede aynı kalır',
      () async {
    final chat = ChatService.instance;
    final first = await chat.ensureGuestIdentity();
    expect(first.id, startsWith('guest_'));
    expect(first.id.length, greaterThan(10));
    expect(
      first.displayName,
      matches(RegExp(r'^(Misafir|Guest)-\d{4}$')),
    );

    await chat.load();
    final second = await chat.ensureGuestIdentity();
    expect(second.id, first.id);
    expect(second.displayName, first.displayName);
    expect(chat.guestIdentity!.id, first.id);
  });

  test('yeni kurulumda her misafir farklı kimlik alır', () async {
    final chat = ChatService.instance;
    final first = await chat.ensureGuestIdentity();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await chat.load();
    final second = await chat.ensureGuestIdentity();
    expect(second.id, isNot(first.id));
  });

  test('görünen ad değiştirilebilir; boş reddedilir, uzunluk sınırlanır',
      () async {
    final chat = ChatService.instance;
    final identity = await chat.ensureGuestIdentity();
    expect(await chat.setGuestDisplayName('  Yeni Ad  '), isTrue);
    expect(chat.guestIdentity!.displayName, 'Yeni Ad');
    expect(chat.guestIdentity!.id, identity.id);
    expect(await chat.setGuestDisplayName('   '), isFalse);
    expect(chat.guestIdentity!.displayName, 'Yeni Ad');
    expect(await chat.setGuestDisplayName('x' * 50), isTrue);
    expect(
      chat.guestIdentity!.displayName.length,
      ChatService.maxGuestDisplayNameLength,
    );
    await chat.load();
    expect(
      chat.guestIdentity!.displayName,
      'x' * ChatService.maxGuestDisplayNameLength,
    );
  });

  test('şart onayı olmadan gönderim reddedilir, onaydan sonra gönderilir',
      () async {
    final chat = ChatService.instance;
    expect(chat.hasAcceptedChatTerms, isFalse);
    await expectLater(
      () => chat.send('merhaba'),
      throwsA(isA<ChatTermsRequiredException>()),
    );
    await chat.acceptChatTerms();
    expect(chat.hasAcceptedChatTerms, isTrue);
    final msg = await chat.send('merhaba');
    expect(msg.body, 'merhaba');
    // Onay kalıcıdır: yeniden yüklemede de geçerli.
    await chat.load();
    expect(chat.hasAcceptedChatTerms, isTrue);
  });

  test(
      'misafir gönderimi kalıcı UUID ile atfedilir, paylaşılan guest_local kullanılmaz',
      () async {
    final chat = ChatService.instance;
    await chat.acceptChatTerms();
    final identity = await chat.ensureGuestIdentity();
    final msg = await chat.send('selam millet');
    expect(msg.authorId, identity.id);
    expect(msg.authorId, isNot('guest_local'));
    expect(msg.authorKind, ChatAuthorKind.guest);
    expect(msg.authorName, identity.displayName);
    expect(chat.isOwnMessage(msg), isTrue);

    await chat.load();
    final again = await chat.send('ikinci mesaj');
    expect(again.authorId, identity.id);
    expect(again.authorKind, ChatAuthorKind.guest);
  });

  test(
      'çıkartma ve meydan okuma gönderimi de misafir kimliği + şart kapısı kullanır',
      () async {
    final chat = ChatService.instance;
    await expectLater(
      () => chat.sendBugSticker(3),
      throwsA(isA<ChatTermsRequiredException>()),
    );
    await chat.acceptChatTerms();
    final identity = await chat.ensureGuestIdentity();
    final sticker = await chat.sendBugSticker(3);
    expect(sticker.authorId, identity.id);
    expect(sticker.authorKind, ChatAuthorKind.guest);
    final vs = await chat.sendVsChallenge(
      modeId: 'suika',
      targetScore: 100,
    );
    expect(vs.authorId, identity.id);
    expect(vs.channel, ChatChannel.vsChallenge);
  });

  test('engelleme mesajları gizler, engel kaldırma geri getirir, kalıcıdır',
      () async {
    final chat = ChatService.instance;
    expect(
      chat.messagesForChannel(ChatChannel.lobby).any(
        (m) => m.authorId == 'npc_kongo',
      ),
      isTrue,
    );
    await chat.blockAuthor('npc_kongo', authorName: 'Kongo Lideri');
    expect(chat.isBlocked('npc_kongo'), isTrue);
    expect(
      chat.messagesForChannel(ChatChannel.lobby).any(
        (m) => m.authorId == 'npc_kongo',
      ),
      isFalse,
    );
    expect(chat.blockedAuthors['npc_kongo'], 'Kongo Lideri');

    await chat.load();
    expect(chat.isBlocked('npc_kongo'), isTrue);
    expect(
      chat.messagesForChannel(ChatChannel.lobby).any(
        (m) => m.authorId == 'npc_kongo',
      ),
      isFalse,
    );

    await chat.unblockAuthor('npc_kongo');
    expect(chat.isBlocked('npc_kongo'), isFalse);
    expect(
      chat.messagesForChannel(ChatChannel.lobby).any(
        (m) => m.authorId == 'npc_kongo',
      ),
      isTrue,
    );
  });

  test('kendi kendini engelleme reddedilir', () async {
    final chat = ChatService.instance;
    final identity = await chat.ensureGuestIdentity();
    await chat.blockAuthor(identity.id);
    expect(chat.isBlocked(identity.id), isFalse);
    expect(chat.blockedAuthorIds, isEmpty);
  });

  test('engel, göçle bağlı kimliğe de uygulanır', () async {
    final chat = ChatService.instance;
    await AuthService.instance.recordGuestIdentityLink(
      'guest_abc123',
      'uid_999',
    );
    await chat.refreshIdentityLinks();
    await chat.blockAuthor('guest_abc123', authorName: 'Eski Misafir');
    expect(chat.isBlocked('uid_999'), isTrue);
    expect(chat.isBlocked('guest_abc123'), isTrue);
  });

  test('raporlama çevrimdışıyken kuyruğa alınır, tekrar rapor engellenir',
      () async {
    final chat = ChatService.instance;
    final message = ChatMessage(
      id: 'm1',
      authorId: 'other_1',
      authorName: 'Biri',
      body: 'rapor edilecek ileti',
      utcTicks: 1,
      channel: ChatChannel.lobby,
      authorKind: ChatAuthorKind.user,
    );
    final first = await chat.reportMessage(message, ChatReportReason.spam);
    // Firebase bu testlerde kapalı: rapor yerel kuyruğa alınır.
    expect(first, ChatReportOutcome.queued);
    final second = await chat.reportMessage(message, ChatReportReason.spam);
    expect(second, ChatReportOutcome.alreadyReported);
    await chat.load();
    final third = await chat.reportMessage(message, ChatReportReason.other);
    expect(third, ChatReportOutcome.alreadyReported);
  });

  test('authorKind JSON turu + eski kayıt uyumluluğu', () async {
    final guest = ChatMessage(
      id: 'g1',
      authorId: 'guest_abcdef0123456789',
      authorName: 'Misafir-1234',
      body: 'merhaba',
      utcTicks: 1,
      authorKind: ChatAuthorKind.guest,
    );
    final round = ChatMessage.fromJson(guest.toJson());
    expect(round.authorKind, ChatAuthorKind.guest);
    expect(round.authorId, guest.authorId);

    final legacy = ChatMessage.fromJson(<String, Object>{
      'id': 'l1',
      'authorId': 'guest_local',
      'authorName': 'Eski',
      'body': 'eski ileti',
      'utcTicks': 2,
      'channel': 'lobby',
    });
    expect(legacy.authorKind, ChatAuthorKind.guest);
    final legacyUser = ChatMessage.fromJson(<String, Object>{
      'id': 'l2',
      'authorId': 'uid_1',
      'authorName': 'Kullanici',
      'body': 'eski ileti',
      'utcTicks': 2,
      'channel': 'lobby',
    });
    expect(legacyUser.authorKind, ChatAuthorKind.user);
  });
}
