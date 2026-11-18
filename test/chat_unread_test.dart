import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/chat_service.dart';
import 'package:lululu_game/services/firebase_bootstrap.dart';

// Sohbet okunmamış sayacı — BULUT GEREKTİRMEYEN yollar:
// lib/services/chat_service.dart:258-281 (`unreadCounts`, `unreadCountFor`,
// `totalUnreadCount`, `hasUnread`, `markChannelRead`).
//
// Pozitif sayım yalnız bulut yoklamasıyla olur: `_bindUnreadProbes` /
// `_updateUnreadFromProbe` (aynı dosya:588-645) özeldir ve Firestore
// `QuerySnapshot` ister; bulutsuz ortamda sayaç 0 kalır. Bu dosya o yolu
// test etmez — pozitif sayım için kanca/fake gerektirir (bkz. rapor).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FirebaseBootstrap.resetForTest();
    final chat = ChatService.instance;
    await chat.load();
    if (chat.currentChannel != ChatChannel.lobby) {
      chat.switchChannel(ChatChannel.lobby);
    }
  });

  test('yükleme sonrası tüm kanallarda okunmamış 0 olur', () {
    final chat = ChatService.instance;

    for (final channel in ChatChannel.values) {
      expect(
        chat.unreadCountFor(channel),
        0,
        reason: '${channel.id} kanalı 0 başlamalı',
      );
      expect(chat.hasUnread(channel), isFalse);
      expect(chat.unreadCounts[channel], 0);
    }
    expect(chat.unreadCounts.length, ChatChannel.values.length);
    expect(chat.totalUnreadCount, 0);
  });

  test('unreadCounts değiştirilemez bir görünümdür', () {
    final chat = ChatService.instance;

    expect(
      () => chat.unreadCounts[ChatChannel.lobby] = 5,
      throwsUnsupportedError,
    );
    expect(chat.unreadCountFor(ChatChannel.lobby), 0);
  });

  test('totalUnreadCount kanal sayaçlarının toplamıdır', () {
    final chat = ChatService.instance;

    final sum = chat.unreadCounts.values.fold(0, (a, b) => a + b);
    expect(chat.totalUnreadCount, sum);

    for (final channel in ChatChannel.values) {
      chat.markChannelRead(channel);
    }
    expect(chat.totalUnreadCount, 0);
  });

  test('markChannelRead gönderilen mesajdan sonra da sayacı 0 tutar', () async {
    final chat = ChatService.instance;
    await chat.send(
      'Okunmamış sayacı testi: klan mesajı',
      channel: ChatChannel.clan,
    );
    expect(chat.unreadCountFor(ChatChannel.clan), 0);
    expect(chat.totalUnreadCount, 0);

    // Görülen zaman ilk çağrıda ilerlediği için bir bildirim gelir;
    // ikinci çağrıda ilerleme olmadığı için bildirim gelmez.
    var notifications = 0;
    void onNotify() {
      notifications++;
    }

    chat.addListener(onNotify);
    try {
      chat.markChannelRead(ChatChannel.clan);
      expect(notifications, 1);
      expect(chat.unreadCountFor(ChatChannel.clan), 0);

      chat.markChannelRead(ChatChannel.clan);
      expect(notifications, 1);
    } finally {
      chat.removeListener(onNotify);
    }
  });

  test('switchChannel iki kanalı da okundu sayar ve sayacı 0 bırakır',
      () async {
    final chat = ChatService.instance;
    await chat.send(
      'Okunmamış sayacı testi: kanal geçişi',
      channel: ChatChannel.clan,
    );

    chat.switchChannel(ChatChannel.clan);
    expect(chat.currentChannel, ChatChannel.clan);
    expect(chat.unreadCountFor(ChatChannel.clan), 0);
    expect(chat.totalUnreadCount, 0);

    chat.switchChannel(ChatChannel.lobby);
    expect(chat.currentChannel, ChatChannel.lobby);
    expect(chat.totalUnreadCount, 0);

    // Aynı kanala geçiş erken döner (no-op), durum değişmez.
    chat.switchChannel(ChatChannel.lobby);
    expect(chat.currentChannel, ChatChannel.lobby);
    expect(chat.totalUnreadCount, 0);
  });

  test('kendi mesajı okunmamış sayılmaz (bulut yokken sayaç 0 kalır)',
      () async {
    final chat = ChatService.instance;
    expect(chat.currentChannel, ChatChannel.lobby);

    await chat.send(
      'Okunmamış sayacı testi: kendi klan mesajım',
      channel: ChatChannel.clan,
    );
    await chat.send(
      'Okunmamış sayacı testi: kendi VS mesajım',
      channel: ChatChannel.vsChallenge,
    );

    expect(chat.unreadCountFor(ChatChannel.clan), 0);
    expect(chat.unreadCountFor(ChatChannel.vsChallenge), 0);
    expect(chat.hasUnread(ChatChannel.clan), isFalse);
    expect(chat.totalUnreadCount, 0);
  });

  test('okunmamış yoklama penceresi 10 mesajla sınırlıdır', () {
    expect(ChatService.unreadProbeLimit, 10);
  });
}
