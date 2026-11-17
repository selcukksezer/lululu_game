// W37-1: 'makara' -> 'makarayiz' normalizasyonunun gerileme koruması.
//
// W35-1 düzeltmesi: `ProgressManager.normalizeModeId`
// (lib/services/progress_manager.dart:313) ve
// `LeaderboardService.normalizeModeId`
// (lib/services/leaderboard_service.dart:94) artık `case 'makara'`
// içeriyor ve kanonik 'makarayiz' döndürüyor.
//
// Her iki fonksiyon da `static` ve salt metin dönüşümüdür
// (`modeId.trim().toLowerCase()` + switch): singleton kurulumu,
// `load()` çağrısı ve mock prefs GEREKMEZ. Kurucular da boştur
// (`ProgressManager._internal()`, `LeaderboardService._()`), bu yüzden
// testler yalnız statik çağrı yapar; widget pump yoktur.
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressManager.normalizeModeId', () {
    test("'makara' kanonik 'makarayiz' olur", () {
      expect(ProgressManager.normalizeModeId('makara'), 'makarayiz');
    });

    test("'makara' büyük harf / boşluk varyantlarına dayanıklıdır", () {
      expect(ProgressManager.normalizeModeId('MAKARA'), 'makarayiz');
      expect(ProgressManager.normalizeModeId(' Makara '), 'makarayiz');
      expect(ProgressManager.normalizeModeId('  MAKARA  '), 'makarayiz');
      expect(ProgressManager.normalizeModeId('MaKaRa'), 'makarayiz');
    });

    test("'makarayiz' girdisi aynen 'makarayiz' döner", () {
      expect(ProgressManager.normalizeModeId('makarayiz'), 'makarayiz');
      expect(ProgressManager.normalizeModeId('MAKARAYIZ'), 'makarayiz');
      expect(ProgressManager.normalizeModeId(' makarayiz '), 'makarayiz');
    });

    test('mevcut aliaslar hâlâ çalışır', () {
      expect(ProgressManager.normalizeModeId('2048'), 'grid_2048');
      expect(ProgressManager.normalizeModeId('grid2048'), 'grid_2048');
      expect(ProgressManager.normalizeModeId('grid_2048'), 'grid_2048');
      expect(ProgressManager.normalizeModeId('terlik'), 'terlik_tap');
      expect(ProgressManager.normalizeModeId('terlik_tap'), 'terlik_tap');
    });
  });

  group('LeaderboardService.normalizeModeId', () {
    test("'makara' modeMakarayiz sabitine ('makarayiz') döner", () {
      expect(LeaderboardService.modeMakarayiz, 'makarayiz');
      expect(
        LeaderboardService.normalizeModeId('makara'),
        LeaderboardService.modeMakarayiz,
      );
      expect(LeaderboardService.normalizeModeId('makara'), 'makarayiz');
    });

    test("'makara' büyük harf / boşluk varyantlarına dayanıklıdır", () {
      expect(
        LeaderboardService.normalizeModeId('MAKARA'),
        LeaderboardService.modeMakarayiz,
      );
      expect(
        LeaderboardService.normalizeModeId(' Makara '),
        LeaderboardService.modeMakarayiz,
      );
    });

    test("'makarayiz' girdisi aynen 'makarayiz' döner", () {
      expect(
        LeaderboardService.normalizeModeId('makarayiz'),
        LeaderboardService.modeMakarayiz,
      );
      expect(
        LeaderboardService.normalizeModeId('MAKARAYIZ'),
        LeaderboardService.modeMakarayiz,
      );
    });

    test('mevcut aliaslar hâlâ çalışır', () {
      expect(
        LeaderboardService.normalizeModeId('2048'),
        LeaderboardService.mode2048,
      );
      expect(
        LeaderboardService.normalizeModeId('2048'),
        'grid_2048',
      );
      expect(
        LeaderboardService.normalizeModeId('terlik'),
        LeaderboardService.modeTerlik,
      );
      expect(
        LeaderboardService.normalizeModeId('terlik'),
        'terlik_tap',
      );
    });
  });

  group('normalizeModeId tutarlılığı', () {
    test('iki servis aynı girdilerde aynı kanonik kimliği döner', () {
      const inputs = [
        'makara',
        'MAKARA',
        ' Makara ',
        'makarayiz',
        '2048',
        'grid2048',
        'terlik',
        'terlik_tap',
        'balloon',
        'scream',
        'yuva',
        'suika',
        'match3',
      ];
      for (final input in inputs) {
        expect(
          LeaderboardService.normalizeModeId(input),
          ProgressManager.normalizeModeId(input),
          reason: "'$input' için iki servis ayrıştı",
        );
      }
    });
  });
}
