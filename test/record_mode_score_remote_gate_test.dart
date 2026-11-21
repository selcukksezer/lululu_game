// Dalga 3 ek — `ProgressManager.recordModeScore` uzak/göç kapısı.
//
// Kapsar: `fromRemoteSync: true` artık AntiCheat kapısını atlamaz —
// bilinmeyen mod, negatif skor ve mod tavanı üstü skor uzaktan gelse
// de kayda girmez; meşru uzak skor kabul edilir; iyileştirmeyen uzak
// skor yazılmaz; tavan sınır değeri kabul edilir.
//
// Göç yolu (`AuthService._mergeGuestProgressIntoAccount`) artık
// doğrudan `pm.modeHighScores[...] = ...` yazımı yerine bu kapıdan
// geçer; göç fonksiyonu private + giriş akışına bağlı olduğundan
// uçtan uca göç testi bu dosyada yoktur — kapı birim testleri +
// doğrudan yazımın kalmadığı grep doğrulaması kapsamdadır.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final pm = ProgressManager.instance;

  Future<void> loadSeeded() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lululu_coins': 1000,
      'lululu.energy': 10,
      'lululu.energy_last_refill': nowMs,
      'lululu.energy_last_seen': nowMs,
    });
    await Future<void>.delayed(Duration.zero);
    await EnergyService.instance.load();
    await ProgressManager.instance.load();
  }

  group('recordModeScore uzak yolu da AntiCheat kapısından geçer', () {
    test('uzak tavan üstü skor reddedilir, yazılmaz', () async {
      await loadSeeded();
      // Suika tavanı 250.000, match3 tavanı 300.000.
      expect(
        await pm.recordModeScore('suika', 300000, fromRemoteSync: true),
        isFalse,
      );
      expect(pm.modeHighScores['suika'] ?? 0, 0);
      expect(
        await pm.recordModeScore('match3', 400000, fromRemoteSync: true),
        isFalse,
      );
      expect(pm.modeHighScores['match3'] ?? 0, 0);
    });

    test('uzak bilinmeyen mod reddedilir, boş anahtar yazılmaz', () async {
      await loadSeeded();
      expect(
        await pm.recordModeScore(
          'bilinmeyen_mod',
          1000,
          fromRemoteSync: true,
        ),
        isFalse,
      );
      expect(pm.modeHighScores.containsKey('bilinmeyen_mod'), isFalse);
      expect(pm.modeHighScores.containsKey(''), isFalse);
    });

    test('uzak negatif ve sıfır skor reddedilir', () async {
      await loadSeeded();
      expect(
        await pm.recordModeScore('suika', -500, fromRemoteSync: true),
        isFalse,
      );
      expect(pm.modeHighScores['suika'] ?? 0, 0);
      expect(
        await pm.recordModeScore('suika', 0, fromRemoteSync: true),
        isFalse,
      );
      expect(pm.modeHighScores['suika'] ?? 0, 0);
    });

    test('meşru uzak skor kabul edilir, tavan sınır değeri geçer', () async {
      await loadSeeded();
      expect(
        await pm.recordModeScore('suika', 12000, fromRemoteSync: true),
        isTrue,
      );
      expect(pm.modeHighScores['suika'], 12000);
      expect(
        await pm.recordModeScore('match3', 300000, fromRemoteSync: true),
        isTrue,
      );
      expect(pm.modeHighScores['match3'], 300000);
      expect(
        await pm.recordModeScore('match3', 300001, fromRemoteSync: true),
        isFalse,
      );
      expect(pm.modeHighScores['match3'], 300000);
    });

    test('iyileştirmeyen uzak skor yazılmaz', () async {
      await loadSeeded();
      expect(await pm.recordModeScore('suika', 14500), isTrue);
      expect(
        await pm.recordModeScore('suika', 12000, fromRemoteSync: true),
        isFalse,
      );
      expect(pm.modeHighScores['suika'], 14500);
      expect(
        await pm.recordModeScore('suika', 14500, fromRemoteSync: true),
        isFalse,
      );
      expect(pm.modeHighScores['suika'], 14500);
    });

    test('yerel yol davranışı değişmez', () async {
      await loadSeeded();
      expect(await pm.recordModeScore('suika', 999999), isFalse);
      expect(pm.modeHighScores['suika'] ?? 0, 0);
      expect(await pm.recordModeScore('suika', 14500), isTrue);
      expect(pm.modeHighScores['suika'], 14500);
    });
  });
}
