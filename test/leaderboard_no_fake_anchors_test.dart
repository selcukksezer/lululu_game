import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

/// Dalga 3 — sahte liderlik çapaları kaldırıldı.
///
/// Kural: Türkiye Top 100 / Global / 11-Mod Toplam merdivenleri yalnız
/// gerçek bulut/yerel veriyi döner. Hard-coded sahte rakip
/// (tr_1..tr_99 "KongoKralı" vb., gl_1..gl_99, "LülüAvcısı_N" /
/// "GlobalOyuncu_N") üretilmez; gerçek kayıt yoksa merdiven boş döner.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LeaderboardService board;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    board = LeaderboardService.instance;
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await board.load();
  });

  group('boş merdiven boş döner', () {
    test('hiç skor yokken üç merdiven de boştur', () {
      expect(board.getTurkeyTop100(), isEmpty);
      expect(board.getGlobalTop(), isEmpty);
      expect(board.get11ModeTotalTop(), isEmpty);
      expect(board.getOverallTop(), isEmpty);
    });

    test('skoru olmayan oyuncunun 0\'lık SEN satırı merdiven sayılmaz',
        () {
      final turkey = board.getTurkeyTop100(limit: 20);
      final global = board.getGlobalTop(limit: 20);
      final total = board.get11ModeTotalTop(limit: 20);
      expect(turkey, isEmpty);
      expect(global, isEmpty);
      expect(total, isEmpty);
    });

    test('oynanmamış modun merdiveni boştur', () {
      expect(board.getTurkeyTop100(modeId: 'match3'), isEmpty);
      expect(board.getGlobalTop(modeId: 'suika'), isEmpty);
    });
  });

  group('merdivende yalnız gerçek kayıtlar', () {
    test('tek gerçek skor: merdivende yalnız oyuncunun kendi satırı',
        () async {
      final ok = await board.submitScore(
        LeaderboardService.modeSuika,
        5000,
      );
      expect(ok, isTrue);

      for (final ladder in <List<LeaderboardEntry>>[
        board.getTurkeyTop100(limit: 20),
        board.getGlobalTop(limit: 20),
        board.get11ModeTotalTop(limit: 20),
      ]) {
        expect(ladder.length, 1);
        expect(ladder.first.isLocalPlayer, isTrue);
        expect(ladder.first.score, 5000);
      }
      // Mod filtreli merdiven: oynanan modda SEN satırı, oynanmamış
      // modda boş.
      expect(board.getTurkeyTop100(modeId: 'suika').length, 1);
      expect(board.getTurkeyTop100(modeId: 'match3'), isEmpty);
    });

    test('iki modda gerçek skor: toplam merdiven yalnız SEN satırı',
        () async {
      expect(
        await board.submitScore(LeaderboardService.modeSuika, 5000),
        isTrue,
      );
      expect(
        await board.submitScore(LeaderboardService.mode2048, 3000),
        isTrue,
      );

      final total = board.get11ModeTotalTop(limit: 20);
      expect(total.length, 1);
      expect(total.first.isLocalPlayer, isTrue);
      expect(total.first.score, 8000);

      final turkey = board.getTurkeyTop100(limit: 20);
      expect(turkey.length, 1);
      expect(turkey.first.isLocalPlayer, isTrue);
      expect(turkey.first.score, 8000);
    });

    test('sahte çapa kimlikleri/isimeri asla görünmez', () async {
      expect(
        await board.submitScore(LeaderboardService.modeSuika, 5000),
        isTrue,
      );
      const fakeNames = <String>{
        'KongoKralı',
        'HamamCan_34',
        'DivaNur',
        'TokyoSuika_JP',
        'RoachMaster_KR',
      };
      for (final ladder in <List<LeaderboardEntry>>[
        board.getTurkeyTop100(),
        board.getGlobalTop(),
        board.get11ModeTotalTop(),
      ]) {
        for (final entry in ladder) {
          expect(fakeNames.contains(entry.playerName), isFalse);
          expect(entry.playerId.startsWith('tr_'), isFalse);
          expect(entry.playerId.startsWith('gl_'), isFalse);
          expect(entry.playerName.startsWith('LülüAvcısı_'), isFalse);
          expect(entry.playerName.startsWith('GlobalOyuncu_'), isFalse);
        }
      }
    });
  });
}
