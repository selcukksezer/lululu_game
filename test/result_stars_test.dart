// 12Q-stars: arcade yıldızı sabit ölçekle verilir (rekor kırmak tek
// başına 3 yıldız vermez) ve rekor kırma yıldızdan ayrı bir rozetle
// kutlanır. Eski kural `starsFor(score, best)` tur-öncesi rekora
// bakıyordu; mod ekranları `_best`'i tur içinde canlı güncellediği
// (G33) için rekor kıran her tur — ilk tur dahil — otomatik 3 yıldız
// alıyordu.
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/models/lululu_game_mode.dart';
import 'package:lululu_game/screens/result_screen.dart';

void main() {
  group('ResultScoring.starsFor — sabit ölçek', () {
    test('skor 0 ve altı 0 yıldızdır', () {
      expect(ResultScoring.starsFor(score: 0, reference: 4820), 0);
      expect(ResultScoring.starsFor(score: -50, reference: 4820), 0);
    });

    test('çıta ve üstü 3 yıldızdır', () {
      expect(ResultScoring.starsFor(score: 4820, reference: 4820), 3);
      expect(ResultScoring.starsFor(score: 9000, reference: 4820), 3);
    });

    test('çıtanın %60 ve üstü 2 yıldızdır', () {
      // 4820 * 0.6 = 2892.
      expect(ResultScoring.starsFor(score: 2892, reference: 4820), 2);
      expect(ResultScoring.starsFor(score: 4000, reference: 4820), 2);
      expect(ResultScoring.starsFor(score: 2891, reference: 4820), 1);
    });

    test('sıfırdan büyük ama çıtanın %60 altında skor 1 yıldızdır', () {
      expect(ResultScoring.starsFor(score: 1, reference: 4820), 1);
      expect(ResultScoring.starsFor(score: 110, reference: 1760), 1);
    });

    test('bilinmeyen modda (çıta <= 0) sıfırdan büyük skor 1 yıldızdır', () {
      expect(ResultScoring.starsFor(score: 500, reference: 0), 1);
      expect(ResultScoring.starsFor(score: 500, reference: -10), 1);
      expect(ResultScoring.starsFor(score: 0, reference: 0), 0);
    });

    test('rekor kırmak tek başına 3 yıldız vermez', () {
      // Eski kuralda skor >= rekor → 3 yıldızdı. Yeni kuralda 110
      // skor, rekor 290 olsa da çıta 1760 olduğu için 1 yıldızdır
      // (Makarayız karşı kanıtı: 110 skora 1 yıldız).
      expect(ResultScoring.starsFor(score: 110, reference: 1760), 1);
      // Rekor kıran ama çıtanın altında kalan tur da 1-2 yıldızdır.
      expect(ResultScoring.starsFor(score: 2000, reference: 4820), 1);
      expect(ResultScoring.starsFor(score: 3000, reference: 4820), 2);
    });
  });

  group('ResultScoring.starsForMode — mod başına sabit çıta', () {
    test('her modun 3-yıldız çıtası sıfırdan büyüktür', () {
      for (final mode in LululuGameMode.catalog) {
        expect(
          mode.threeStarScore,
          greaterThan(0),
          reason: '${mode.bestScoreKey} çıtasız kalmış',
        );
      }
      expect(LululuGameMode.catalog.length, 11);
    });

    test('2048 çıta tohum 0 olsa da 12480’dir', () {
      final mode = LululuGameMode.byId(LululuGameModeId.grid2048);
      expect(mode.defaultBestScore, 0);
      expect(mode.threeStarScore, 12480);
    });

    test('bilinen mod anahtarları sabit çıtayla yıldız verir', () {
      expect(
        ResultScoring.starsForMode(score: 1760, modeScoreId: 'makarayiz'),
        3,
      );
      expect(
        ResultScoring.starsForMode(score: 1105, modeScoreId: 'makarayiz'),
        2,
      );
      expect(
        ResultScoring.starsForMode(score: 110, modeScoreId: 'makarayiz'),
        1,
      );
      expect(
        ResultScoring.starsForMode(score: 12480, modeScoreId: 'grid_2048'),
        3,
      );
      expect(
        ResultScoring.starsForMode(score: 8640, modeScoreId: 'grid_2048'),
        2,
      );
      expect(
        ResultScoring.starsForMode(score: 4820, modeScoreId: 'suika'),
        3,
      );
      expect(
        ResultScoring.starsForMode(score: 2346, modeScoreId: 'suika'),
        1,
      );
    });

    test('bilinmeyen mod anahtarı 1 yıldız verir', () {
      expect(
        ResultScoring.starsForMode(score: 9999, modeScoreId: 'bilinmeyen'),
        1,
      );
      expect(
        ResultScoring.starsForMode(score: 9999, modeScoreId: ''),
        1,
      );
      expect(
        ResultScoring.starsForMode(score: 0, modeScoreId: 'suika'),
        0,
      );
    });
  });

  group('ResultScoring.isNewRecord — yıldızdan ayrı rekor rozeti', () {
    test('skor tur-öncesi rekoru yakaladıysa/geçtiyse rekor sayılır', () {
      // `best` çağrıcıda tur içinde canlı güncellenmiş
      // max(rekor, skor) değeridir; score >= best tam olarak
      // "rekor yakalandı/geçildi" demektir.
      expect(ResultScoring.isNewRecord(score: 500, best: 500), isTrue);
      expect(ResultScoring.isNewRecord(score: 500, best: 290), isTrue);
    });

    test('skor rekorun altındaysa rekor yoktur', () {
      expect(ResultScoring.isNewRecord(score: 110, best: 290), isFalse);
      expect(ResultScoring.isNewRecord(score: 289, best: 290), isFalse);
    });

    test('skor 0 ise rekor yoktur', () {
      expect(ResultScoring.isNewRecord(score: 0, best: 0), isFalse);
    });

    test('ilk turda (rekor 0) sıfırdan büyük skor rekordur', () {
      expect(ResultScoring.isNewRecord(score: 100, best: 0), isTrue);
    });
  });

  group('GameResultScreen.isNewRecord alanı', () {
    test('varsayılan false, açık verilince true taşınır', () {
      const plain = GameResultScreen();
      expect(plain.isNewRecord, isFalse);
      const record = GameResultScreen(isNewRecord: true);
      expect(record.isNewRecord, isTrue);
    });
  });
}
