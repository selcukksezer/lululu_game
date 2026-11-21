// 9A — davet kodu karşılama (redeem) testleri.
//
// Kapsar: biçim geçerli/geçersiz (tireli, tiresiz, küçük harf, boş),
// kendi kodu reddi, çift kullanım reddi (ikinci çağrıda coin artmaz),
// başarıda +100 coin bir kez, prefs kalıcılığı (önbellek sıfırlanınca
// aynı kod yine reddedilir), geçersiz kodda coin değişmez.
//
// Kurulum deseni test/progress_manager_faz2_test.dart'tan alındı:
// `setMockInitialValues` + olay döngüsüne bir tur +
// `ProgressManager.load()` ile singleton sıfırlama.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/friend_invite_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Prefs tohumunu kurup singleton'ları tohumdan yükler.
  Future<void> loadSeeded({int coins = 1000}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lululu_coins': coins,
    });
    // Bir önceki testin bekletilmeyen yazılarının tohumun üstüne
    // binmemesi için olay döngüsüne bir tur verilir.
    await Future<void>.delayed(Duration.zero);
    await ProgressManager.instance.load();
    FriendInviteService.instance.debugResetRedeemedCache();
  }

  /// Biçim-geçerli sabit kod; kendi koduyla çakışmadığı doğrulanır.
  String validCode() {
    const code = 'LULU-AB12345';
    assert(
      FriendInviteService.normalizeCode(
            FriendInviteService.instance.inviteCode,
          ) !=
          FriendInviteService.normalizeCode(code),
      'test kodu kendi koduyla çakıştı',
    );
    return code;
  }

  group('biçim', () {
    test('tireli kod kabul edilir, +100 coin', () async {
      await loadSeeded();
      final outcome = await FriendInviteService.instance.redeemCode(
        validCode(),
      );
      expect(outcome.result, InviteRedeemResult.success);
      expect(outcome.rewardCoins, 100);
      expect(ProgressManager.instance.coins, 1100);
    });

    test('tiresiz kod kabul edilir', () async {
      await loadSeeded();
      final outcome = await FriendInviteService.instance.redeemCode(
        'LULUCD67890',
      );
      expect(outcome.result, InviteRedeemResult.success);
      expect(outcome.rewardCoins, 100);
      expect(ProgressManager.instance.coins, 1100);
    });

    test('küçük harf + baştaki/sondaki boşluk normalize edilir', () async {
      await loadSeeded();
      final outcome = await FriendInviteService.instance.redeemCode(
        '  lulu-ab12345  ',
      );
      expect(outcome.result, InviteRedeemResult.success);
      expect(ProgressManager.instance.coins, 1100);
    });

    test('geçersiz kodlar reddedilir, coin değişmez', () async {
      await loadSeeded();
      const invalid = <String>[
        '', // boş
        'LULU-AB12', // kısa
        'LULU-AB1234', // 4 harf + 4 hane (uzunluk tutmuyor)
        'LULU-ABCDEFG', // hane yerinde harf
        'LULU-AB12C45', // hane yerinde harf
        'XXXX-AB12345', // yanlış önek
        'LULU-AB123456', // uzun
        'LULU-AB 12345', // iç boşluk
      ];
      for (final code in invalid) {
        final outcome = await FriendInviteService.instance.redeemCode(code);
        expect(
          outcome.result,
          InviteRedeemResult.invalidFormat,
          reason: 'kod: "$code"',
        );
        expect(outcome.rewardCoins, 0, reason: 'kod: "$code"');
      }
      expect(ProgressManager.instance.coins, 1000);
    });
  });

  group('kendi kodu', () {
    test('kendi kodu reddedilir, coin değişmez', () async {
      await loadSeeded();
      final own = FriendInviteService.instance.inviteCode;
      final outcome = await FriendInviteService.instance.redeemCode(own);
      expect(outcome.result, InviteRedeemResult.ownCode);
      expect(ProgressManager.instance.coins, 1000);
    });
  });

  group('tek kullanım', () {
    test('çift kullanım reddedilir, ikinci çağrıda coin artmaz', () async {
      await loadSeeded();
      final service = FriendInviteService.instance;
      final first = await service.redeemCode(validCode());
      expect(first.result, InviteRedeemResult.success);
      expect(ProgressManager.instance.coins, 1100);

      final second = await service.redeemCode(validCode());
      expect(second.result, InviteRedeemResult.alreadyRedeemed);
      expect(ProgressManager.instance.coins, 1100);
    });

    test('prefs kalıcılığı: önbellek sıfırlanınca aynı kod yine reddedilir',
        () async {
      await loadSeeded();
      final service = FriendInviteService.instance;
      final first = await service.redeemCode(validCode());
      expect(first.result, InviteRedeemResult.success);

      // Uygulama yeniden başlatmayı simüle et: bellek önbelleği boş,
      // liste prefs'ten yeniden okunur.
      service.debugResetRedeemedCache();
      final second = await service.redeemCode(validCode());
      expect(second.result, InviteRedeemResult.alreadyRedeemed);
      expect(ProgressManager.instance.coins, 1100);

      // Kod kalıcı listede normalize edilmiş hâliyle durur.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(
          FriendInviteService.redeemedCodesPrefKey,
        ),
        contains('LULUAB12345'),
      );
    });

    test('ödül kod başına bir kez: farklı kod ikinci kez +100 verir',
        () async {
      await loadSeeded();
      final service = FriendInviteService.instance;
      final first = await service.redeemCode('LULU-AB12345');
      expect(first.result, InviteRedeemResult.success);
      expect(ProgressManager.instance.coins, 1100);

      final second = await service.redeemCode('LULU-CD67890');
      expect(second.result, InviteRedeemResult.success);
      expect(second.rewardCoins, 100);
      expect(ProgressManager.instance.coins, 1200);
    });
  });

  group('yardımcılar', () {
    test('normalizeCode + isValidFormat', () {
      expect(
        FriendInviteService.normalizeCode('  lulu-ab12345 '),
        'LULUAB12345',
      );
      expect(
        FriendInviteService.isValidFormat('LULUAB12345'),
        isTrue,
      );
      expect(FriendInviteService.isValidFormat('LULUAB12'), isFalse);
      expect(FriendInviteService.isValidFormat('LULUAB1234'), isFalse);
      expect(FriendInviteService.isValidFormat('LULUABCDEFG'), isFalse);
    });
  });
}
