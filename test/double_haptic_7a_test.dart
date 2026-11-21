// Dalga 7A — çift-haptic tekilleştirme kilidi (Faz 3 6A bayrağı: D8+D9).
//
// D9, 15 doğrudan `playSfx(buttonTap)` çağrısını `playButtonTap()`'e
// çevirdi; `playButtonTap()` kendi haptic'ini (`selectionClick`) zaten
// tetiklediği için çağrı yerlerindeki açık `triggerMediumHaptic()` /
// `heavyImpact()` satırları çift titreşime dönüştü. D8'de terlik tuzak
// (`playSlipper()`), smash (`playSlipperSmash()`) ve sprey (`playSpray()`)
// çağrılarının yanındaki açık haptic satırları da aynı çifti üretiyordu
// (üç ses yöntemi de kendi haptic'ini tetikler: `onSlipperSlap` /
// `onRaidSpray`, bkz. lib/services/audio_manager.dart).
//
// Bu dosya KAYNAK düzeyinde kilitler (6A deseni — ses test ortamında
// duyulamaz, titreşim ölçülemediği için sayı + bitişiklik denetlenir):
//   (a) açık haptic çağrı satırı sayısı lib genelinde 13'tür (7A'da 37'ydi;
//       10C'de 22 satır silindi: match3 4 + connect 5 + balon 5 + makara 1 +
//       osmantus 1 + stack 4 + 2048 2; 7A'da 20 satır silinmişti: 15 D9 +
//       terlik tuzak/sprey 2 + smash if/else bloğu 2 + yuva smash 1;
//       10D'de 2 satır daha silindi: Suika kombo≥3 triggerHeavyHaptic
//       (playMerge onMerge'i zaten ağırlaştırır) + 2048 Geri Al
//       triggerMediumHaptic (yerine ses taşıyan playButtonTap). Yeni
//       `trigger*Haptic` eklenmedi — kilit sayısı artırılmaz, azaltılır.)
//   (b) 5 mod dosyasında haptic-carrying ses çağrısının bitişiğinde
//       açık haptic satırı kalmadı (bitişiklik: önceki 3 anlamlı satır).
//   (c) ses çağrıları: playButtonTap 19, playSlipper 1,
//       playSlipperSmash 4, playSpray 1 (davranış: tek titreşim, ses
//       tarafında; ses susturulmadı, haptic yöntemi silinmedi).
//       10D değişimi: duraklatma 11 modda playButtonTap aldı (+5 bu
//       5 dosyada); yuva kalkan kurtarması playButtonTap →
//       playSlipperSmash (−1 tap, +1 smash); yuva kaçışına
//       playSlipperSmash eklendi (+1 smash). 15→19 tap, 2→4 smash.
//
// KAPSAM DIŞI (bilinçli dokunulmadı, koordinatör kararı bekler):
// `playMerge` bitişiğindeki açık haptic satırları (balon 3, connect 4,
// match3 3, stack 3 = 13 site) + osmantus beat-hit üçlüsü
// (`triggerHaptic` + `triggerMediumHaptic` + `playOsmantusBeat`,
// osmantus_screen.dart _onTapDown) — çekirdek oyun hissi, ayrı dalga.
//
// 10C (Faz 4 Dalga 10C — P0-4): o "ayrı dalga" budur; yukarıdaki 13 site +
// osmantus üçlüsü + 2048/makara/balon-fırlatma/stack-bırakma çiftleri
// tekilleştirildi. Sayı kilidi 37 -> 15 (10C'de 22 açık satır silindi;
// `triggerHaptic()` satırları bu sayımda yok — osmantus üçlüsündeki
// `triggerHaptic` + `triggerMediumHaptic` ikilisinden yalnız ikincisi
// sayılır). Kalan tek istisna: Suika (game_screen.dart, 1 satır) — 10B
// aynı dosyada çalıştığı için 10D'ye kaldı, dokunulmadı.
//
// 10D (Faz 4 Dalga 10D): Suika istisnası kapatıldı — kombo≥3
// triggerHeavyHaptic silindi (playMerge onMerge'i zaten ağırlaştırır)
// ve bırakmadaki triggerHaptic silindi (playDrop içi lightImpact
// yeter; triggerHaptic sayımda yok, toplamı değiştirmez). 2048 Geri
// Al'daki triggerMediumHaptic de playButtonTap ile değiştirildi
// (ses + tek titreşim). Sayı kilidi 15 -> 13.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Directory projectRoot = _resolveProjectRoot();

  String read(String relativePath) {
    final file = File('${projectRoot.path}/$relativePath');
    expect(file.existsSync(), isTrue, reason: '$relativePath bulunamadı');
    return file.readAsStringSync();
  }

  int count(String source, String needle) => needle.allMatches(source).length;

  /// Açık haptic çağrı satırları: servis tanımlarının dışındaki
  /// `triggerMediumHaptic()`, `triggerHeavyHaptic()` ve
  /// `HapticService.instance.heavyImpact()` çağrıları.
  int explicitHapticLines(String source) {
    var n = 0;
    for (final line in source.split('\n')) {
      final t = line.trim();
      if (t.startsWith('//')) continue;
      if (t.contains('triggerMediumHaptic()') ||
          t.contains('triggerHeavyHaptic()') ||
          t.contains('HapticService.instance.heavyImpact()')) {
        n++;
      }
    }
    return n;
  }

  /// Haptic-carrying ses çağrısının bitişiğinde açık haptic var mı?
  /// Bitişiklik: ses satırından önceki 3 anlamlı (boş/yorum olmayan)
  /// satırdan birinde açık haptic çağrısı.
  List<String> adjacentHapticPairs(String source, String path) {
    final lines = source.split('\n');
    final found = <String>[];
    bool isHaptic(String line) {
      final t = line.trim();
      if (t.startsWith('//')) return false;
      return t.contains('triggerMediumHaptic()') ||
          t.contains('triggerHeavyHaptic()') ||
          t.contains('HapticService.instance.heavyImpact()') ||
          t.contains('triggerHaptic()');
    }

    bool isSound(String line) =>
        line.contains('playButtonTap(') ||
        line.contains('playSlipper(') ||
        line.contains('playSlipperSmash(') ||
        line.contains('playSpray(');
    for (var i = 0; i < lines.length; i++) {
      if (!isSound(lines[i])) continue;
      var checked = 0;
      var j = i - 1;
      while (j >= 0 && checked < 3) {
        final t = lines[j].trim();
        if (t.isEmpty || t.startsWith('//')) {
          j--;
          continue;
        }
        checked++;
        if (isHaptic(lines[j])) {
          found.add('$path:${j + 1} -> ses ${i + 1}');
        }
        j--;
      }
    }
    return found;
  }

  const touchedFiles = <String>[
    'lib/modes/makarayiz_screen.dart',
    'lib/modes/osmantus_screen.dart',
    'lib/modes/scream_roach_screen.dart',
    'lib/modes/terlik_tap_screen.dart',
    'lib/modes/yuva_defense_screen.dart',
  ];

  const allLibFiles = <String>[
    'lib/modes/balloon_pop_screen.dart',
    'lib/modes/connect_pop_screen.dart',
    'lib/modes/makarayiz_screen.dart',
    'lib/modes/match3_screen.dart',
    'lib/modes/osmantus_screen.dart',
    'lib/modes/scream_roach_screen.dart',
    'lib/modes/stack_drop_screen.dart',
    'lib/modes/terlik_tap_screen.dart',
    'lib/modes/yuva_defense_screen.dart',
    'lib/screens/game_screen.dart',
    'lib/screens/grid_2048_screen.dart',
  ];

  group('7A — çift-haptic tekilleştirme (D8+D9)', () {
    test('açık haptic satırı sayısı lib genelinde 13 (7A: 37, 10C: 15)', () {
      var total = 0;
      final perFile = <String, int>{};
      for (final path in allLibFiles) {
        final n = explicitHapticLines(read(path));
        perFile[path] = n;
        total += n;
      }
      expect(total, 13, reason: 'per-file: $perFile');
      // Dokunulan 5 dosyanın kalan sayıları (yalnız tekil haptic'ler):
      // 10C: makara isabet + osmantus beat-hit çiftleri de tekilleşti.
      expect(perFile['lib/modes/makarayiz_screen.dart'], 1);
      expect(perFile['lib/modes/osmantus_screen.dart'], 1);
      expect(perFile['lib/modes/scream_roach_screen.dart'], 1);
      expect(perFile['lib/modes/terlik_tap_screen.dart'], 1);
      expect(perFile['lib/modes/yuva_defense_screen.dart'], 1);
    });

    test('5 dosyada ses bitişiğinde açık haptic kalmadı', () {
      for (final path in touchedFiles) {
        final pairs = adjacentHapticPairs(read(path), path);
        expect(pairs, isEmpty, reason: '$path çiftleri: $pairs');
      }
    });

    test('ses çağrıları aynen durur (tek titreşim ses tarafında)', () {
      var buttonTap = 0;
      var slipper = 0;
      var smash = 0;
      var spray = 0;
      for (final path in touchedFiles) {
        final src = read(path);
        buttonTap += count(src, 'playButtonTap()');
        slipper += count(src, 'AudioManager().playSlipper()');
        smash += count(src, 'playSlipperSmash(');
        spray += count(src, 'AudioManager().playSpray()');
      }
      // 10D: duraklatma +5 tap (5 dosyada birer _togglePause); yuva
      // kalkan −1 tap / +1 smash; yuva kaçışı +1 smash.
      expect(buttonTap, 19, reason: 'D9: 15 + 10D duraklatma 5 − kalkan 1');
      expect(slipper, 1, reason: 'D8: terlik tuzak sesi');
      expect(smash, 4, reason: 'terlik smash + yuva isabet + kalkan + kaçış');
      expect(spray, 1, reason: 'D8: sprey güçlendirici sesi');
    });

    // 10C: 7A'da "dokunulmayan" sayılan bu dosyalar 10C kapsamıdır
    // (yalnız game_screen.dart/Suika dokunulmadı — 10D'ye kaldı).
    test('10C dosyalarında haptic sayısı tekilleştirilmiş değerlerde', () {
      expect(explicitHapticLines(read('lib/modes/balloon_pop_screen.dart')), 2);
      expect(explicitHapticLines(read('lib/modes/connect_pop_screen.dart')), 2);
      expect(explicitHapticLines(read('lib/modes/match3_screen.dart')), 2);
      expect(explicitHapticLines(read('lib/modes/stack_drop_screen.dart')), 1);
      // 10D: Suika kombo≥3 triggerHeavyHaptic silindi (0 kaldı);
      // 2048 Geri Al triggerMediumHaptic playButtonTap oldu (1 kaldı).
      expect(explicitHapticLines(read('lib/screens/game_screen.dart')), 0);
      expect(explicitHapticLines(read('lib/screens/grid_2048_screen.dart')), 1);
    });
  });
}

Directory _resolveProjectRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('pubspec.yaml bulunamadı: ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}
