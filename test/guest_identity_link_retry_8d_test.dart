// DEL-1 (göç eşlemesi kalıcı retry kuyruğu) testleri.
//
// Çevrimdışı göçte `guest_identity_links` belgesi yazılamazsa eşleme
// kalıcı kuyruğa alınmalı; uygulama açılışında geri yüklenmeli;
// çevrimiçi olunca yazılmalı ve kuyruktan silinmeli; yazım başarısız
// olursa kuyrukta kalmalıdır. `AuthService.recordGuestIdentityLink`
// imzası ve yerel eşleme davranışı aynen korunur.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/chat_service.dart';
import 'package:lululu_game/services/firebase_bootstrap.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const guestId = 'guest_0123456789abcdef0123';
  const guestId2 = 'guest_fedcba9876543210fedc';
  const uid = 'uid_test_8d';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FirebaseBootstrap.resetForTest();
    ChatService.debugCloudLinkWriter = null;
    await ProgressManager.instance.load();
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await ChatService.instance.load();
  });

  tearDown(() {
    ChatService.debugCloudLinkWriter = null;
    FirebaseBootstrap.resetForTest();
  });

  test('çevrimdışı göç eşlemesi kalıcı kuyruğa yazılır', () async {
    final chat = ChatService.instance;
    expect(FirebaseBootstrap.isAvailable, isFalse);

    await chat.recordGuestIdentityLinkCloud(guestId, uid);

    expect(chat.pendingIdentityLinks.length, 1);
    expect(chat.pendingIdentityLinks.first.guestId, guestId);
    expect(chat.pendingIdentityLinks.first.uid, uid);
    expect(chat.hasPendingIdentityLinks, isTrue);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('LululuChatPendingIdentityLinksV1');
    expect(raw, isNotNull);
    expect(raw, contains(guestId));
    expect(raw, contains(uid));
  });

  test('yeniden yüklemede kuyruk geri gelir, çevrimdışı drain düşürmez',
      () async {
    final chat = ChatService.instance;
    await chat.recordGuestIdentityLinkCloud(guestId, uid);
    expect(chat.pendingIdentityLinks.length, 1);

    // Yeniden başlatma simülasyonu: load kuyruğu prefs'ten geri yükler,
    // açılıştaki drain çevrimdışı olduğu için kaydı düşürmez.
    await chat.load();
    expect(chat.pendingIdentityLinks.length, 1);
    expect(chat.pendingIdentityLinks.first.guestId, guestId);

    final drained = await chat.retryPendingIdentityLinks();
    expect(drained, isFalse);
    expect(chat.pendingIdentityLinks.length, 1);
  });

  test('çevrimiçi olunca kuyruk yazılır ve boşalır', () async {
    final chat = ChatService.instance;
    await chat.recordGuestIdentityLinkCloud(guestId, uid);
    await chat.recordGuestIdentityLinkCloud(guestId2, uid);
    expect(chat.pendingIdentityLinks.length, 2);

    // Çevrimiçi yazım simülasyonu (test kancası: Firestore test
    // ortamında başlatılamaz).
    ChatService.debugCloudLinkWriter = (_, _) async => true;
    final drained = await chat.retryPendingIdentityLinks();

    expect(drained, isTrue);
    expect(chat.pendingIdentityLinks, isEmpty);
    expect(chat.hasPendingIdentityLinks, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('LululuChatPendingIdentityLinksV1'), isNull);
  });

  test('yazım başarısız olursa kuyruk korunur', () async {
    final chat = ChatService.instance;
    await chat.recordGuestIdentityLinkCloud(guestId, uid);

    ChatService.debugCloudLinkWriter = (_, _) async => false;
    final drained = await chat.retryPendingIdentityLinks();

    expect(drained, isFalse);
    expect(chat.pendingIdentityLinks.length, 1);
    expect(chat.pendingIdentityLinks.first.guestId, guestId);
  });

  test('aynı misafir iki kez kuyruğa girmez; kap en-eskisi-atılır', () async {
    final chat = ChatService.instance;
    await chat.recordGuestIdentityLinkCloud(guestId, uid);
    await chat.recordGuestIdentityLinkCloud(guestId, 'uid_baska');
    expect(chat.pendingIdentityLinks.length, 1);
    expect(
      chat.pendingIdentityLinks.first.uid,
      uid,
      reason: 'ilk kayıt korunur (ilk-yazım-kazanır)',
    );

    // Kap: 200'ü aşan kayıtta en eski atılır.
    for (var i = 0; i < 205; i++) {
      await chat.recordGuestIdentityLinkCloud(
        'guest_${i.toString().padLeft(20, '0')}',
        'uid_$i',
      );
    }
    expect(
      chat.pendingIdentityLinks.length,
      ChatService.maxPendingIdentityLinks,
    );
    expect(
      chat.pendingIdentityLinks.any((e) => e.guestId == guestId),
      isFalse,
      reason: 'en eski kayıt kap aşımında atıldı',
    );
    expect(
      chat.pendingIdentityLinks.last.guestId,
      'guest_${204.toString().padLeft(20, '0')}',
    );
  });

  test('recordGuestIdentityLink yerel eşlemeyi yazar, bulut kopyasını '
      'kuyruğa alır (imza ve yerel davranış aynen)', () async {
    final auth = AuthService.instance;
    final chat = ChatService.instance;

    await auth.recordGuestIdentityLink(guestId, uid);
    final links = await auth.guestIdentityLinks();
    expect(links[guestId], uid);

    // Bulut yazımı ateşle-unut çalışır: kuyruğa düşmesi için bekle.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      chat.pendingIdentityLinks.any((e) => e.guestId == guestId),
      isTrue,
    );

    // Tekrarı yerel eşlemede değişim yapmaz (idempotent).
    await auth.recordGuestIdentityLink(guestId, 'uid_baska');
    final linksAgain = await auth.guestIdentityLinks();
    expect(linksAgain[guestId], uid);
    expect(linksAgain.length, 1);
  });
}
