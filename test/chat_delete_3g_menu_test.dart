// B27 — kendi mesajını silme UI menüsü (3G).
//
// Uzun basma menüsü: kendi mesajında yalnız "Sil", başkasının
// mesajında raporla/engelle; onay diyaloğunda iptal mesajı korur,
// onay silip kısa bildirim gösterir. Servis sözleşmesi
// `test/chat_delete_3g_test.dart` dosyasındadır.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/chat_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/chat_service.dart';
import 'package:lululu_game/services/firebase_bootstrap.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    AudioManager().isMuted = true;
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

  /// Kalıcı blobları üretim yükleme yoluyla besler (anahtar adları
  /// `ChatService` özel sabitlerinin değerleridir), ardından kendi
  /// mesajını gönderim yoluyla ekler.
  Future<({ChatMessage own, ChatMessage other})> seedChat() async {
    final chat = ChatService.instance;
    final identity = await chat.ensureGuestIdentity();
    final other = ChatMessage(
      id: 'other_menu_seed',
      authorId: 'uid_baskasi',
      authorName: 'Baskasi',
      body: 'Baskasinin menusu deneme mesaji',
      utcTicks: 10,
      channel: ChatChannel.lobby,
      authorKind: ChatAuthorKind.user,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'LululuChatLobbyV1',
      jsonEncode([other.toJson()]),
    );
    await prefs.setString(
      'LululuChatChannelsV2',
      jsonEncode({'lobby': [other.toJson()]}),
    );
    await prefs.setString(
      'LululuChatGuestIdentityV1',
      jsonEncode(identity.toJson()),
    );
    await chat.load();
    final own = await chat.send('Silme menusu deneme mesaji bir');
    return (own: own, other: other);
  }

  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpWithL10n(tester, const ChatScreen());
    await settleFrames(tester);
  }

  testWidgets('kendi mesajında menüde yalnız Sil var; iptal korur, '
      'onay siler ve bildirim gösterir', (tester) async {
    final seeded = await seedChat();
    await pumpChat(tester);

    expect(find.text(seeded.own.body), findsOneWidget);

    // Menü: yalnız Sil.
    await tester.longPress(find.text(seeded.own.body));
    await settleFrames(tester);
    expect(find.text('Sil'), findsOneWidget);
    expect(find.text('Raporla'), findsNothing);
    expect(find.text('Engelle'), findsNothing);

    // İptal: mesaj yerinde kalır.
    await tester.tap(find.text('Sil'));
    await settleFrames(tester);
    expect(find.text('Mesajı sil?'), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await settleFrames(tester);
    expect(find.text(seeded.own.body), findsOneWidget);

    // Onay: mesaj kaybolur, kısa bildirim görünür.
    await tester.longPress(find.text(seeded.own.body));
    await settleFrames(tester);
    await tester.tap(find.text('Sil'));
    await settleFrames(tester);
    await tester.tap(find.text('Sil'));
    await settleFrames(tester);
    expect(find.text(seeded.own.body), findsNothing);
    expect(find.text('Mesaj silindi.'), findsOneWidget);
    expect(
      ChatService.instance.messages.any((m) => m.id == seeded.own.id),
      isFalse,
    );
    await flushPendingFrames(tester);
  });

  testWidgets('başkasının mesajında menüde Sil yok; raporla ve '
      'engelle var', (tester) async {
    final seeded = await seedChat();
    await pumpChat(tester);

    expect(find.text(seeded.other.body), findsOneWidget);

    await tester.longPress(find.text(seeded.other.body));
    await settleFrames(tester);
    expect(find.text('Sil'), findsNothing);
    expect(find.text('Raporla'), findsOneWidget);
    expect(find.text('Engelle'), findsOneWidget);

    // Rapor diyaloğu açılır, iptal mesajı korur.
    await tester.tap(find.text('Raporla'));
    await settleFrames(tester);
    expect(find.text('Mesajı raporla'), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await settleFrames(tester);
    expect(find.text(seeded.other.body), findsOneWidget);
    await flushPendingFrames(tester);
  });
}

/// Alt sayfa/diyaloğu kapatmadan önce bekleyen yazı tipi yükleme
/// bildirimlerini boşaltır: geç gelen sistem-fontu geri çağrısı ağaç
/// dispose edildikten sonra kare isterse zamanlayıcı hatası verir.
Future<void> flushPendingFrames(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Alt sayfa/diyalog animasyonlarını sonlu karelerle ilerletir
/// (`pumpAndSettle` yerine: ekrandaki olası süresiz animasyonlar
/// yerleşmeyi kilitlemesin).
Future<void> settleFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}
