// Misafir → hesap göçü: yerel ilerleme/coin birleşmesi, kalıcı
// kimlik eşlemesi, idempotency ve çıkışta veri korunması testleri.
//
// Birleşme kuralı (belgeli): skor/ilerleme/coin/stokta YÜKSEK olan
// kazanır (toplama yok — tekrar çalışmada çift sayma olmaz), kozmetik
// ve tier'lerde birleşim (union) alınır. Yerel veri, bulut yazımı
// onaylanmadan silinmez; bulut kapalıysa kuyruğa yazılır.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/chat_service.dart';
import 'package:lululu_game/services/firebase_bootstrap.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FirebaseBootstrap.resetForTest();
    await ProgressManager.instance.load();
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await ChatService.instance.load();
  });

  Future<void> setLocalProgress({int coins = 5000, int level = 9}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_coins', coins);
    await prefs.setInt('lululu_unlocked_level', level);
    await ProgressManager.instance.load();
  }

  test('kayıt, misafir ilerlemesini boş hesaba aynen taşır', () async {
    await setLocalProgress(coins: 5000, level: 7);
    expect(ProgressManager.instance.coins, 5000);
    expect(ProgressManager.instance.unlockedLevel, 7);

    final user =
        await AuthService.instance.register(username: 'miguser1', password: 'abcdef');
    expect(AuthService.instance.isSignedIn, isTrue);
    expect(user.id, isNotEmpty);
    expect(ProgressManager.instance.coins, 5000);
    expect(ProgressManager.instance.unlockedLevel, 7);
  });

  test('giriş, misafir ilerlemesini birleştirir ve kimlik eşlemesi kaydeder',
      () async {
    final auth = AuthService.instance;
    final user =
        await auth.register(username: 'miguser2', password: 'abcdef');
    final uid = user.id;
    await auth.signOut();

    final chat = ChatService.instance;
    final identity = await chat.ensureGuestIdentity();
    await setLocalProgress(coins: 5000, level: 9);

    await auth.login(username: 'miguser2', password: 'abcdef');
    expect(auth.isSignedIn, isTrue);
    expect(ProgressManager.instance.coins, 5000);
    expect(ProgressManager.instance.unlockedLevel, 9);
    final links = await auth.guestIdentityLinks();
    expect(links[identity.id], uid);
  });

  test('birleşmede yüksek olan kazanır (bellek içi değer prefs değerini geçer)',
      () async {
    final auth = AuthService.instance;
    await auth.register(username: 'miguser3', password: 'abcdef');
    await auth.signOut();

    // prefs: seviye 9; bellek içi ilerleme: seviye 12 → 12 kazanmalı.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lululu_unlocked_level', 9);
    await ProgressManager.instance.load();
    ProgressManager.instance.unlockedLevel = 12;

    await auth.login(username: 'miguser3', password: 'abcdef');
    expect(ProgressManager.instance.unlockedLevel, 12);
    expect(prefs.getInt('lululu_unlocked_level'), 12);
  });

  test('göç idempotent: ikinci giriş çift sayma yapmaz, eşleme tek kalır',
      () async {
    final auth = AuthService.instance;
    final user =
        await auth.register(username: 'miguser4', password: 'abcdef');
    final uid = user.id;
    await auth.signOut();

    final chat = ChatService.instance;
    final identity = await chat.ensureGuestIdentity();
    await setLocalProgress(coins: 5000, level: 9);
    await auth.login(username: 'miguser4', password: 'abcdef');
    expect(ProgressManager.instance.coins, 5000);

    await auth.signOut();
    await auth.login(username: 'miguser4', password: 'abcdef');
    expect(ProgressManager.instance.coins, 5000);
    expect(ProgressManager.instance.unlockedLevel, 9);
    final links = await auth.guestIdentityLinks();
    expect(links.length, 1);
    expect(links[identity.id], uid);
  });

  test('bulut kapalıyken giriş yerel veriyi korur', () async {
    // Firebase bu testlerde kapalı (resetForTest): göç yerel
    // prefs üzerinde tamamlanır, hiçbir değer silinmez.
    final auth = AuthService.instance;
    await auth.register(username: 'miguser5', password: 'abcdef');
    await auth.signOut();
    await setLocalProgress(coins: 5000, level: 9);

    await auth.login(username: 'miguser5', password: 'abcdef');
    expect(auth.isSignedIn, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('lululu_coins'), 5000);
    expect(prefs.getInt('lululu_unlocked_level'), 9);
    expect(ProgressManager.instance.coins, 5000);
  });

  test('çıkış, misafir kimliği + yerel veriyi aynen korur', () async {
    final auth = AuthService.instance;
    final chat = ChatService.instance;
    final identity = await chat.ensureGuestIdentity();
    await setLocalProgress(coins: 5000, level: 9);
    await auth.register(username: 'miguser6', password: 'abcdef');
    await auth.signOut();

    await chat.load();
    expect(chat.guestIdentity!.id, identity.id);
    expect(chat.guestIdentity!.displayName, identity.displayName);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('lululu_coins'), 5000);
    expect(prefs.getInt('lululu_unlocked_level'), 9);
  });

  test('eski mesajlar misafir UUID ile kalır, yeni mesajlar hesap kimliğiyle gider',
      () async {
    final auth = AuthService.instance;
    final chat = ChatService.instance;
    await chat.acceptChatTerms();
    final identity = await chat.ensureGuestIdentity();
    final guestMsg = await chat.send('misafir mesaji');

    final user =
        await auth.register(username: 'miguser7', password: 'abcdef');
    final all = chat.messagesForChannel(
      ChatChannel.lobby,
      includeDefaultFeed: false,
    );
    expect(
      all.any(
        (m) =>
            m.id == guestMsg.id &&
            m.authorId == identity.id &&
            m.authorKind == ChatAuthorKind.guest,
      ),
      isTrue,
    );

    final userMsg = await chat.send('hesap mesaji');
    expect(userMsg.authorId, user.id);
    expect(userMsg.authorKind, ChatAuthorKind.user);
    expect(chat.isOwnMessage(userMsg), isTrue);

    final links = await auth.guestIdentityLinks();
    expect(links[identity.id], user.id);
  });
}
