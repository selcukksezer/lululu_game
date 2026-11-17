// W42-2: `ResultScoring` skor varsayılanlarının gerileme koruması.
//
// `ResultScoring` (lib/screens/result_screen.dart) skor varsayılanlarının
// TEK KAYNAĞI (W36-2): `defaultBestScore = 4820`, `defaultBestCombo = 6`,
// `defaultMerges = 18`. `showGameResult` varsayılanları, `GameResultScreen`
// kurucu varsayılanları ve `finishRun` geri dönüşleri bu sabitlere bağlı.
// Bu dosya yalnız 1+2'yi kilitler:
//   1. Sabitlerin değerleri (4820/6/18).
//   2. Varsayılan kurulan `GameResultScreen` widget'ının
//      `bestScore`/`bestCombo`/`merges` alanlarının bu sabitlere eşitliği.
//
// KURUCU İMZASI (result_screen.dart'tan okunup doğrulandı, 2026-11-18):
// `GameResultScreen` kurucusunda `required` parametre YOKTUR; tamamı
// varsayılanlıdır: `score = 2346`, `coins = 0`, `stars = 3`,
// `bestScore = ResultScoring.defaultBestScore`,
// `bestCombo = ResultScoring.defaultBestCombo`,
// `merges = ResultScoring.defaultMerges`, `coinsAwardedByCaller = true`
// (+ isteğe bağlı `super.key`). Bu yüzden sıfır argümanla kurulum da
// (`const GameResultScreen()`), yalnız `score`/`coins`/`stars` verilerek
// kurulum da geçerlidir; her iki yol da aşağıda kapsanır.
// (`showGameResult` ise farklıdır: orada `score`/`coins`/`stars`
// `required`, skor varsayılanları yine `ResultScoring` sabitleridir.)
//
// PUMP YOKTUR: Bu dosyada `testWidgets` ve `tester.pump` kullanılmaz.
// Yalnız düz `test()` ile widget İNŞASI düzeyinde alan okuma yapılır;
// `State` hiç oluşturulmadığı için `initState` yan etkileri (ses,
// ödeme) tetiklenmez. `showGameResult` varsayılanları doğrudan test
// edilmez (BuildContext + navigation gerektirir); `finishRun` geri
// dönüş mantığı da bu dosyanın kapsamı dışındadır.
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/screens/result_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResultScoring sabit değer kilidi', () {
    test('defaultBestScore 4820', () {
      expect(ResultScoring.defaultBestScore, 4820);
    });

    test('defaultBestCombo 6', () {
      expect(ResultScoring.defaultBestCombo, 6);
    });

    test('defaultMerges 18', () {
      expect(ResultScoring.defaultMerges, 18);
    });
  });

  group('GameResultScreen varsayılanları (inşa düzeyi, pump yok)', () {
    test('sıfır argümanla kurulan widget skor alanları ResultScoring sabitlerine eşittir', () {
      // Kurucuda required parametre yoktur; const kurulum derlenir ve
      // varsayılanların derleme zamanı sabitleri olduğunu da kanıtlar.
      const screen = GameResultScreen();

      expect(screen.bestScore, ResultScoring.defaultBestScore);
      expect(screen.bestCombo, ResultScoring.defaultBestCombo);
      expect(screen.merges, ResultScoring.defaultMerges);
      // Kilidi somut değerlere de bağla: sabit değişirse bu test de düşer.
      expect(screen.bestScore, 4820);
      expect(screen.bestCombo, 6);
      expect(screen.merges, 18);
    });

    test('yalnız score/coins/stars verilince skor alanları hâlâ ResultScoring sabitleridir', () {
      const screen = GameResultScreen(score: 100, coins: 5, stars: 2);

      expect(screen.score, 100);
      expect(screen.coins, 5);
      expect(screen.stars, 2);
      expect(screen.bestScore, ResultScoring.defaultBestScore);
      expect(screen.bestCombo, ResultScoring.defaultBestCombo);
      expect(screen.merges, ResultScoring.defaultMerges);
      expect(screen.bestScore, 4820);
      expect(screen.bestCombo, 6);
      expect(screen.merges, 18);
    });

    test('sıfır argümanla kurulan widget diğer kurucu varsayılanlarını da taşır', () {
      const screen = GameResultScreen();

      expect(screen.score, 2346);
      expect(screen.coins, 0);
      expect(screen.stars, 3);
      expect(screen.coinsAwardedByCaller, isTrue);
    });

    test('açıkça verilen bestScore/bestCombo/merges varsayılanları ezer', () {
      const screen = GameResultScreen(
        score: 100,
        coins: 5,
        stars: 2,
        bestScore: 9999,
        bestCombo: 12,
        merges: 42,
      );

      expect(screen.bestScore, 9999);
      expect(screen.bestCombo, 12);
      expect(screen.merges, 42);
      // Sabitlerin kendisi değişmemiştir.
      expect(ResultScoring.defaultBestScore, 4820);
      expect(ResultScoring.defaultBestCombo, 6);
      expect(ResultScoring.defaultMerges, 18);
    });
  });
}
