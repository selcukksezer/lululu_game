// Dalga 12B-q19 — çift-ses D1: tek-çalma çalışma-zamanı kanıtı.
//
// 6A (`audio_single_source_6a_test.dart`) tek kaynağı KAYNAK düzeyinde
// kilitler: 11 mod dosyasında `playWin`/`playLose` yok, sonuç ekranında
// birer kez var. Bu dosya eksik kalanı kapatır: `GameResultScreen`
// `initState`'i gerçekten TEK KEZ çalar mı? Dalga 11 P2-1 dikişi
// (`playerFactory` + `forcePlaybackForTesting`) üzerinden sahte
// oyuncularla hangi asset'in kaç kez çaldığı sayılır.
//
// Üretim davranışı değişmez: `result_screen.dart` içindeki test
// atlaması yalnız `forcePlaybackForTesting` açıkken (yalnız testte)
// kalkar; bayrak varsayılanı kapalıdır.
//
// Kilitlenen kurallar:
//   (a) `won: true` ekranı `sfx_victory.mp3`'ü tam 1 kez, `sfx_gameover`
//       0 kez çalar (zafer sesi + `tier8_ses.mp3` ses katmanı da 1 kez).
//   (b) `won: false` ekranı `sfx_gameover.mp3`'ü tam 1 kez, zaferi 0 kez
//       çalar.
//   (c) Aynı State'in yeniden çizimi (rebuild) sesi tekrar çalmaz:
//       `initState` bir kez çalışır, sayı 1'de kalır.
//   (d) Dikiş kapalıysa (varsayılan) testte ses hiç çalmaz — diğer
//       sonuç ekranı testleri etkilenmez.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';

import 'test_helpers.dart';

/// Sahte oyuncu (Dalga 11 P2-1 deseni): hangi asset'in çaldığını
/// kaydeder; gerçek ses çalmaz. `playerId` bilerek sabittir
/// (`p0..p8`): `AudioPlayer` kurucusu her oyuncu için
/// `xyz.luan/audioplayers/events/<playerId>` olay kanalına `listen`
/// gönderir; kanal adı önceden bilinirse testte mock'lanabilir ve
/// `MissingPluginException` widget testini düşürmez.
class _FakeAudioPlayer extends AudioPlayer {
  _FakeAudioPlayer(String id, this.log) : id = id, super(playerId: id);

  final String id;
  final List<String> log;

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPlaybackRate(double playbackRate) async {}

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    final asset = source is AssetSource ? source.path : source.toString();
    log.add('play:$id:$asset');
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final created = <_FakeAudioPlayer>[];
  final log = <String>[];

  int playsOf(String assetFileName) => log
      .where(
        (entry) =>
            entry.startsWith('play:') && entry.endsWith(assetFileName),
      )
      .length;

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => null,
      );
    }
    // Olay kanalları (`listen`/`cancel`): global + 8 havuz + 1 ses
    // kanalı oyuncusu. Mock'suz `MissingPluginException` widget
    // testini düşürür (düz `test()`'te sessiz kalır).
    for (final channel in [
      'xyz.luan/audioplayers.global/events',
      for (var i = 0; i < 9; i++) 'xyz.luan/audioplayers/events/p$i',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => null,
      );
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFonts.config.allowRuntimeFetching = false;
    created.clear();
    log.clear();
    final audio = AudioManager();
    audio.dispose();
    audio.playerFactory = () {
      final fake = _FakeAudioPlayer('p${created.length}', log);
      created.add(fake);
      return fake;
    };
    audio.forcePlaybackForTesting = true;
    audio.isMuted = false;
    audio.sfxEnabled = true;
    audio.voiceEnabled = true;
    audio.vibrationEnabled = false;
    audio.initialize();
    expect(created.length, 8, reason: 'havuz 8 sahte oyuncuyla kurulmalı');
  });

  tearDown(() {
    final audio = AudioManager();
    audio.dispose();
    audio.forcePlaybackForTesting = false;
  });

  /// `initState`'teki ateşle-unut çalma zincirini boşaltır.
  /// Ekrandaki tekrarlı animasyonlar testte kapalıdır (`isTesting`
  /// korumalı), bu yüzden settle takılmaz.
  Future<void> flushPlayback(WidgetTester tester) async {
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  /// Ağacı kaldırıp bekleyen kare geri çağrılarını boşaltır: motorun
  /// 'fontsChange' bildirimi gerçek zamanlı gelir
  /// (`result_first_clear_extras_test.dart` deseni) — FakeAsync
  /// dışında bekleyip bildirimin gelmesini sağla, sonra ağacı kaldırıp
  /// planlanan geri çağrıyı pompalarla akıt; yoksa test sonu denetimi
  /// "animation is still running" ile düşer.
  Future<void> disposeResult(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
  }

  testWidgets('zafer ekranı zafer sesini tam 1 kez çalar', (tester) async {
    await pumpWithL10n(
      tester,
      const GameResultScreen(score: 500, coins: 5, stars: 2, won: true),
    );
    await flushPlayback(tester);

    expect(playsOf('sfx_victory.mp3'), 1);
    expect(playsOf('sfx_gameover.mp3'), 0);
    // Zafer sesi katmanı (tier8 ses) de tek kez.
    expect(playsOf('tier8_ses.mp3'), 1);
    await disposeResult(tester);
  });

  testWidgets('yenilgi ekranı gameover sesini tam 1 kez çalar', (
    tester,
  ) async {
    await pumpWithL10n(
      tester,
      const GameResultScreen(score: 0, coins: 0, stars: 0, won: false),
    );
    await flushPlayback(tester);

    expect(playsOf('sfx_gameover.mp3'), 1);
    expect(playsOf('sfx_victory.mp3'), 0);
    expect(playsOf('tier8_ses.mp3'), 0);
    await disposeResult(tester);
  });

  testWidgets('aynı sonuç ekranının yeniden çizimi sesi tekrar çalmaz', (
    tester,
  ) async {
    await pumpWithL10n(
      tester,
      const GameResultScreen(score: 500, coins: 5, stars: 2, won: true),
    );
    await flushPlayback(tester);
    expect(playsOf('sfx_victory.mp3'), 1);

    // Aynı State, yeni skorla rebuild: initState yeniden çalışmaz.
    await pumpWithL10n(
      tester,
      const GameResultScreen(score: 600, coins: 6, stars: 3, won: true),
    );
    await flushPlayback(tester);
    expect(playsOf('sfx_victory.mp3'), 1);
    expect(playsOf('sfx_gameover.mp3'), 0);
    await disposeResult(tester);
  });

  testWidgets('dikiş kapalıyken testte ses hiç çalmaz', (tester) async {
    AudioManager().forcePlaybackForTesting = false;
    await pumpWithL10n(
      tester,
      const GameResultScreen(score: 500, coins: 5, stars: 2, won: true),
    );
    await flushPlayback(tester);

    expect(playsOf('sfx_victory.mp3'), 0);
    expect(playsOf('sfx_gameover.mp3'), 0);
    await disposeResult(tester);
  });
}
