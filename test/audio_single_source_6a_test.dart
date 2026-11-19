// Dalga 6A — ses tek-kaynak kilidi (A6 denetimi: D1/D4/D5/D8/D9).
//
// Ses, test ortamında kapalıdır (`AudioManager` test bağlamını algılayıp
// çalmaz; `GameResultScreen.initState` de testte sesi atlar) ve Playwright
// sesi duyamaz. Bu yüzden bu dosya KAYNAK düzeyinde kilitler: hangi
// dosyada hangi ses çağrısının bulunduğunu/bulunmadığını sayar. Sayılar
// değişirse test düşer ve çift-ses regresyonu kodda yakalanır.
//
// Kilitlenen kurallar:
//   (a) D1: win/lose sesi TEK KAYNAK — yalnız `GameResultScreen.initState`
//       çalar. 11 mod dosyasındaki bitiş yolları ayrıca çalmaz. İSTİSNA:
//       2048'deki 2 `playWin`, bitiş yolu DEĞİLDİR (kademe-11'e ulaşma
//       anındaki orta-oyun jingle'ı; oyun devam eder, sonuç ekranı yalnız
//       `_gameOver` kenarında açılır) — korunur, sayısı kilitlidir.
//   (b) D4: Suika'da Hışır belirme + dokunuş `playHusurAday` çalar;
//       `_playMilestoneOneShot`'taki `playMezarinaSiktigim` korunur.
//   (c) D5: Çığlık modunda güç tam dolduğu an `sfxScreamRoach` ek katmanı
//       çalar (kenar tetik). D8: Terlik tuzak sesi `playSlipper()`,
//       sprey güçlendirici sesi `playSpray()`.
//   (d) D9: 5 mod dosyasındaki 15 doğrudan `playSfx(buttonTap)` çağrısı
//       `playButtonTap()`'e çevrildi; doğrudan çağrı kalmadı.
//   Koruma: stüdyo/claim `playWin`'lerine dokunulmadı.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lululu_game/services/audio_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Directory projectRoot = _resolveProjectRoot();

  String read(String relativePath) {
    final file = File('${projectRoot.path}/$relativePath');
    expect(file.existsSync(), isTrue, reason: '$relativePath bulunamadı');
    return file.readAsStringSync();
  }

  int count(String source, String needle) =>
      needle.allMatches(source).length;

  /// `startMarker` ile `endMarker` arasındaki kaynak dilimini döndürür.
  String slice(String source, String startMarker, String endMarker) {
    final start = source.indexOf(startMarker);
    expect(start, isNot(-1), reason: 'başlangıç bulunamadı: $startMarker');
    final end = source.indexOf(endMarker, start + startMarker.length);
    expect(end, isNot(-1), reason: 'bitiş bulunamadı: $endMarker');
    return source.substring(start, end);
  }

  const modeFiles = <String>[
    'lib/modes/balloon_pop_screen.dart',
    'lib/modes/connect_pop_screen.dart',
    'lib/modes/makarayiz_screen.dart',
    'lib/modes/match3_screen.dart',
    'lib/modes/osmantus_screen.dart',
    'lib/modes/scream_roach_screen.dart',
    'lib/modes/stack_drop_screen.dart',
    'lib/modes/terlik_tap_screen.dart',
    'lib/modes/yuva_defense_screen.dart',
  ];

  group('D1 — bitiş sesi tek kaynak: sonuç ekranı', () {
    test('sonuç ekranı win/lose çağrısını birer kez içerir', () {
      final result = read('lib/screens/result_screen.dart');
      expect(count(result, 'AudioManager().playWin()'), 1);
      expect(count(result, 'AudioManager().playLose()'), 1);
      // initState içinde oldukları: çağrılar initState diliminde.
      final init = slice(result, 'void initState()', 'void _showRewards');
      expect(count(init, 'AudioManager().playWin()'), 1);
      expect(count(init, 'AudioManager().playLose()'), 1);
    });

    test('9 mod dosyasında bitiş sesi çağrısı kalmadı', () {
      for (final path in modeFiles) {
        final source = read(path);
        expect(
          count(source, 'playWin('),
          0,
          reason: '$path içinde playWin kaldı',
        );
        expect(
          count(source, 'playLose('),
          0,
          reason: '$path içinde playLose kaldı',
        );
      }
    });

    test('Suika bitiş yollarında bitiş sesi çağrısı kalmadı', () {
      final game = read('lib/screens/game_screen.dart');
      expect(count(game, 'playWin('), 0);
      expect(count(game, 'playLose('), 0);
      // Nakarat korunur: zaferde sonuç ekranı öncesi tek ek katman.
      expect(count(game, 'playLululuNakarat()'), 1);
    });

    test('2048 istisnası: yalnız 2 orta-oyun playWin, playLose yok', () {
      final grid = read('lib/screens/grid_2048_screen.dart');
      expect(count(grid, 'AudioManager().playWin()'), 2);
      expect(count(grid, 'playLose('), 0);
      // Sonuç ekranı yalnız _gameOver kenarında açılır — _won tek başına
      // sonuç göstermez, bu yüzden 2 playWin bitiş yolu değildir.
      expect(grid.contains('if (_gameOver && !_resultShown)'), isTrue);
    });

    test('her mod bitiş yolu finishRun zincirine bağlı', () {
      // Bitiş bayrağı → build kenarı → _presentResult → finishRun zinciri
      // koparsa sonuç ekranı (ve tek-kaynak ses) hiç açılmaz.
      for (final path in [...modeFiles, 'lib/screens/grid_2048_screen.dart']) {
        final source = read(path);
        expect(source.contains('finishRun('), isTrue, reason: path);
        expect(source.contains('_presentResult'), isTrue, reason: path);
      }
      final game = read('lib/screens/game_screen.dart');
      expect(game.contains('finishRun('), isTrue);
      final finishRun = read('lib/services/finish_run.dart');
      expect(finishRun.contains('showGameResult('), isTrue);
    });

    test('stüdyo/claim seslerine dokunulmadı', () {
      expect(
        count(read('lib/screens/game_selector_screen.dart'), 'playWin()'),
        3,
      );
      expect(
        count(read('lib/screens/campaign_map_screen.dart'), 'playWin()'),
        greaterThanOrEqualTo(1),
      );
      expect(
        count(read('lib/screens/tasks_screen.dart'), 'playVictorySfx('),
        2,
      );
      // 6B D7 birleşmesi: toast gösterim sesi (`_onToastChanged`, 6B)
      // + claim sesi (`_claimTier`, önceden var) = 2. D1 bu dosyaya
      // dokunmadı; beklenti birleşmiş ağaca göre güncellendi.
      final toastCode =
          read('lib/widgets/achievement_toast_overlay.dart');
      expect(count(toastCode, 'playWin()'), 2);
      expect(toastCode.contains('void _onToastChanged()'), isTrue);
      expect(toastCode.contains('Future<void> _claimTier('), isTrue);
    });
  });

  group('D4 — Suika Hışır kablolaması', () {
    test('_showHisir Hışır sesini çalar, mezarına çalmaz', () {
      final game = read('lib/screens/game_screen.dart');
      final show = slice(
        game,
        'void _showHisir()',
        'void _onHisirTapDown',
      );
      expect(count(show, 'playHusurAday()'), 1);
      expect(show.contains('playMezarinaSiktigim'), isFalse);
      // Onaylı-klip notu kod yorumunda korunur (12C: Selçuk kulakla
      // onayladı, 2026-11-19 — eski "doğrulanmamış aday" notu kalktı).
      expect(show.contains('hisir_zopa'), isTrue);
    });

    test('_onHisirTapDown Hışır sesini çalar', () {
      final game = read('lib/screens/game_screen.dart');
      final tap = slice(
        game,
        'void _onHisirTapDown',
        'void _playMilestoneOneShot',
      );
      expect(count(tap, 'playHusurAday()'), 1);
      expect(tap.contains('_score += 150'), isTrue);
    });

    test('milestone mezarına sesi korunur (Hışır bağlamı değil)', () {
      final game = read('lib/screens/game_screen.dart');
      final milestone = slice(
        game,
        'void _playMilestoneOneShot',
        'int _calculateStars()',
      );
      expect(count(milestone, 'playMezarinaSiktigim()'), 1);
      // Dosyada başka mezarına çağrısı kalmadı.
      expect(count(game, 'playMezarinaSiktigim()'), 1);
    });
  });

  group('D5 + D8 — çığlık eşiği ve Terlik eşlemesi', () {
    test('sfx_scream_roach asset sabiti ve warmup listesinde', () {
      expect(GameAudio.sfxScreamRoach, 'sfx_scream_roach.mp3');
      expect(GameAudio.allAssets.contains(GameAudio.sfxScreamRoach), isTrue);
    });

    test('çığlık gücü tam dolduğu an ek katman çalar (kenar tetik)', () {
      final scream = read('lib/modes/scream_roach_screen.dart');
      expect(
        count(scream, 'playSfx(GameAudio.sfxScreamRoach'),
        1,
      );
      final screamFn = slice(scream, 'void _scream()', 'Future<void> _toggleVoiceInput');
      expect(screamFn.contains('wasFull'), isTrue);
      expect(screamFn.contains('!wasFull && _power >= 1.0'), isTrue);
    });

    test('Terlik tuzak sesi terlik tokadı, sprey sesi playSpray', () {
      final terlik = read('lib/modes/terlik_tap_screen.dart');
      expect(count(terlik, 'playSfx(GameAudio.sfxSpray)'), 0);
      expect(count(terlik, 'playSlipper()'), 1);
      expect(count(terlik, 'playSpray()'), 1);
      // Tuzak dalı: steppedTrap bağlamının hemen ardından terlik sesi.
      final trapAt = terlik.indexOf('terlikSteppedTrap');
      expect(trapAt, isNot(-1));
      final trapWindow = terlik.substring(
        trapAt,
        (trapAt + 400).clamp(0, terlik.length),
      );
      expect(trapWindow.contains('playSlipper()'), isTrue);
    });
  });

  group('D9 — playButtonTap çevrimleri', () {
    test('5 mod dosyasında doğrudan playSfx(buttonTap) kalmadı', () {
      const files = <String>[
        'lib/modes/makarayiz_screen.dart',
        'lib/modes/osmantus_screen.dart',
        'lib/modes/scream_roach_screen.dart',
        'lib/modes/terlik_tap_screen.dart',
        'lib/modes/yuva_defense_screen.dart',
      ];
      for (final path in files) {
        expect(
          read(path).contains('playSfx(GameAudio.sfxButtonTap)'),
          isFalse,
          reason: path,
        );
      }
    });

    test('playButtonTap sayıları: 4+4+4+3+4 = 19', () {
      // 10D: her dosyaya bir _togglePause playButtonTap eklendi (+1);
      // yuva kalkan kurtarması playButtonTap → playSlipperSmash (−1),
      // net yuva 4'te kaldı.
      expect(
        count(read('lib/modes/makarayiz_screen.dart'), 'playButtonTap()'),
        4,
      );
      expect(
        count(read('lib/modes/osmantus_screen.dart'), 'playButtonTap()'),
        4,
      );
      expect(
        count(read('lib/modes/scream_roach_screen.dart'), 'playButtonTap()'),
        4,
      );
      expect(
        count(read('lib/modes/terlik_tap_screen.dart'), 'playButtonTap()'),
        3,
      );
      expect(
        count(read('lib/modes/yuva_defense_screen.dart'), 'playButtonTap()'),
        4,
      );
    });

    test('kapsamdaki dosyalarda tek doğrudan playSfx D5 ek katmanı', () {
      var total = 0;
      for (final path in [
        ...modeFiles,
        'lib/screens/game_screen.dart',
        'lib/screens/grid_2048_screen.dart',
      ]) {
        total += count(read(path), '.playSfx(');
      }
      expect(total, 1);
    });
  });
}

Directory _resolveProjectRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) {
    return cwd;
  }
  final sub = Directory('${cwd.path}/lululu_game');
  if (File('${sub.path}/pubspec.yaml').existsSync()) {
    return sub;
  }
  return cwd;
}
