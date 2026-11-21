// FAZ 2 / 3E — ChatService kalıcı testleri: 2F (O8, O12).
//
// ChatService davranışı değiştirilmez; testler mevcut API ile yazıldı.
// Kurulum deseni test/chat_unread_test.dart'tan alındı:
// `setMockInitialValues` + `FirebaseBootstrap.resetForTest()` +
// `ChatService.load()` — bulut kapıları kapalı, Firestore gerektirmez.
//
// SINIRLAMA (dürüst not): ChatService'te singleton reset / yeni örnek
// kancası YOKTUR (özel kurucu + statik `instance`; kodda reset metodu
// yok). Yeniden başlatma, aynı prefs'ten ikinci `load()` çağrısıyla
// simüle edilir: `load()` bellek içi sohbet durumunu (`_messages`,
// `_byChannel`, `_cloudFailedIds`) temizleyip prefs'ten yeniden kurar,
// yani kalıcı durum için gerçek yeniden-yükleme yoludur.
//
// Prefs anahtar sabitleri (`LululuChatLobbyV1`, `LululuChatCloudFailedV1`)
// ChatService'te özeldir; buradaki yazımlar
// lib/services/chat_service.dart'taki sabitlerden aynen kopyalandı.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/chat_service.dart';
import 'package:lululu_game/services/firebase_bootstrap.dart';

/// Geçerli bir mesajın kalıcı JSON karşılığı (`ChatMessage.toJson`
/// çıktısı — el yazımı blob değil).
Map<String, dynamic> _validMessageJson(String id, {int ticks = 1000}) =>
    ChatMessage(
      id: id,
      authorId: 'user-1',
      authorName: 'Ali',
      body: 'merhaba',
      utcTicks: ticks,
    ).toJson();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Prefs tohumunu kurup sohbet servisini tohumdan yükler.
  Future<ChatService> loadSeeded(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    FirebaseBootstrap.resetForTest();
    // Bir önceki testin bekletilmeyen yazılarının tohumun üstüne
    // binmemesi için olay döngüsüne bir tur verilir.
    await Future<void>.delayed(Duration.zero);
    final chat = ChatService.instance;
    await chat.load();
    return chat;
  }

  group('O8: kısmi yükleme', () {
    test('bozuk kayıt atlanır, sağlam kayıtlar yüklenir', () async {
      final blob = jsonEncode([
        _validMessageJson('msg-ok-1', ticks: 1000),
        'bozuk-kayit',
        42,
        {'id': 123, 'authorId': 'user-1', 'body': 'x', 'utcTicks': 1},
        {'id': '', 'authorId': 'user-1', 'body': 'x', 'utcTicks': 1},
        {'authorId': 'user-1', 'body': 'x', 'utcTicks': 1},
        _validMessageJson('msg-ok-2', ticks: 2000),
      ]);
      final chat = await loadSeeded({'LululuChatLobbyV1': blob});

      expect(chat.messages.map((m) => m.id).toList(), ['msg-ok-1', 'msg-ok-2']);
      expect(
        chat.messagesForChannel(ChatChannel.lobby).map((m) => m.id).toList(),
        ['msg-ok-1', 'msg-ok-2'],
      );
    });

    test('tamamen bozuk blob yüklemeyi patlatmaz, boş yüklenir', () async {
      final chat = await loadSeeded({'LululuChatLobbyV1': '[[bozuk-json'});

      expect(chat.messages, isEmpty);
    });
  });

  group('O12: retry listesi kalıcıdır', () {
    test('yeniden yüklemede kaybolmaz; bilinmeyen kimlik budanır', () async {
      final blob = jsonEncode([_validMessageJson('msg-retry-1')]);
      final chat = await loadSeeded(<String, Object>{
        'LululuChatLobbyV1': blob,
        'LululuChatCloudFailedV1': ['msg-retry-1', 'msg-silinmis'],
      });

      // Yalnız yüklenen mesajda karşılığı olan kimlik tutulur.
      expect(chat.cloudFailedIds, {'msg-retry-1'});
      expect(chat.isCloudFailed('msg-retry-1'), isTrue);
      expect(chat.hasCloudFailures, isTrue);

      // Bekletilmeyen retry'nin yerleşmesi için olay döngüsüne tur
      // verilir; kapı kapalı olduğundan liste değişmeden kalır.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('LululuChatCloudFailedV1'), ['msg-retry-1']);

      // Yeniden başlatma simülasyonu: aynı prefs'ten tekrar yükle —
      // liste bellek içi bayrak değil, kalıcı kayıttır.
      await chat.load();

      expect(chat.cloudFailedIds, {'msg-retry-1'});
      expect(chat.isCloudFailed('msg-retry-1'), isTrue);
      expect(chat.messages.map((m) => m.id).toList(), ['msg-retry-1']);
      await Future<void>.delayed(Duration.zero);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('LululuChatCloudFailedV1'), ['msg-retry-1']);
    });
  });
}
