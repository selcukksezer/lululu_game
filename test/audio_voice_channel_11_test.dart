// Dalga 11 P2-1 — tier sesi özel kanalı: hızlı ardışık birleşmelerde
// tier sesi havuzda dolanıp başka tier'ın sesini duyurmasın.
//
// HATA (Selçuk 2026-11-19 doğruladı): "Üst üste binebilir sıralı çalınca
// bu sefer başka karakterde başka ses çalmış oluyor."
// MEKANİZMA: `playMerge` her birleşmede chime + (kombo>1 ise combo) +
// tier sesini 8 oyunculu round-robin havuza paralel atar. Hızlı ardışık
// birleşmelerde havuz ~3 birleşmede dolanır: yeni birleşmenin
// chime/combo'su önceki birleşmenin tier sesini çalan oyuncuyu durdurur
// ve aynı anda 2-3 tier sesi üst üste çalar.
//
// Ses testte kapalıdır (`_canPlayAsset` test ortamında false döner) ve
// Playwright sesi duyamaz — bu yüzden bu dosya mock'lu birim testidir:
// `AudioManager`'daki `@visibleForTesting` dikiş (oyuncu fabrikası +
// çalmayı zorlayan bayrak) üzerinden sahte oyuncularla hangi asset'in
// hangi oyuncuda çaldığı ve `stop()` çağrıları kaydedilir.
//
// DÜZELTME (beklenen davranış):
//   (a) Hızlı ardışık 4+ birleşme bitince aynı anda çalan tier sesi TAM 1'dir
//       ve o ses SON birleşmenin tier sesidir.
//   (b) Birleşme chime/combo'su tier sesi oyuncusuna hiç `stop()` göndermez.
//   (c) `playTierVoice` çalan bir merge sesini temiz şekilde değiştirir
//       (son ses = playTierVoice'un tier'ı).
//   (d) `stopAll()` sonrası hiçbir tier sesi çalmıyordur.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/audio_manager.dart';

/// Sahte oyuncu: hangi asset'in hangi oyuncuda çaldığını + `stop()`
/// çağrılarını kaydeder; gerçek ses çalmaz. `AudioPlayer`'ı genişletir
/// (sınıf `final` değildir), platform çağrısı yapan metotlar no-op'tur.
class _FakeAudioPlayer extends AudioPlayer {
  _FakeAudioPlayer(this.id, this.log);

  final String id;
  final List<String> log;

  /// Şu an bu oyuncuda çaldığı varsayılan asset (`stop()` ile silinir).
  String? currentAsset;
  int stopCalls = 0;
  int playCalls = 0;

  @override
  Future<void> stop() async {
    log.add('stop:$id:${currentAsset ?? '-'}');
    stopCalls++;
    currentAsset = null;
  }

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
    playCalls++;
    currentAsset = asset;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Fabrika üzerinden yaratılan tüm sahte oyuncular (sırayla: önce
  /// havuzun 8'i, sonra — düzeltmeden sonra — özel kanal oyuncusu).
  final created = <_FakeAudioPlayer>[];

  /// Paylaşılan olay günlüğü: `play:<id>:<asset>` / `stop:<id>:<asset>`.
  final log = <String>[];

  setUpAll(() {
    // Gerçek `AudioPlayer` kurulumunun platform çağrıları (6B ile aynı).
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => null,
      );
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    created.clear();
    log.clear();
    final audio = AudioManager();
    // Singleton havuzu + bayrakları sıfırla, sahte oyuncularla yeniden kur.
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
    // Titreşim bu testin konusu değil; haptik yolunu kapat.
    audio.vibrationEnabled = false;
    audio.initialize();
    expect(created.length, 8, reason: 'havuz 8 sahte oyuncuyla kurulmalı');
  });

  tearDown(() {
    final audio = AudioManager();
    audio.dispose();
    audio.forcePlaybackForTesting = false;
  });

  /// Şu an çaldığı varsayılan tier sesi olan oyuncular.
  List<_FakeAudioPlayer> playingTierVoices() => created
      .where(
        (p) =>
            p.currentAsset != null &&
            GameAudio.isVoiceAsset(p.currentAsset!),
      )
      .toList();

  /// (b) denetimi: logda tier sesi çalan bir oyuncuyu durduran `stop()`'un
  /// ardından o oyuncuda gelen çalma yine bir tier sesi mi? Chime/combo
  /// bir tier sesini keserse false döner. `stopAll()` sonrası çalma
  /// gelmemesi kesme sayılmaz.
  bool noTierVoiceKilledBySfx() {
    for (var i = 0; i < log.length; i++) {
      final entry = log[i];
      if (!entry.startsWith('stop:')) continue;
      final parts = entry.split(':');
      if (parts.length < 3) continue;
      final id = parts[1];
      final stoppedAsset = parts.sublist(2).join(':');
      if (stoppedAsset == '-' || !GameAudio.isVoiceAsset(stoppedAsset)) {
        continue;
      }
      final nextPlay = log.skip(i + 1).firstWhere(
            (e) => e.startsWith('play:$id:'),
            orElse: () => '',
          );
      if (nextPlay.isEmpty) continue;
      final nextAsset = nextPlay.substring('play:$id:'.length);
      if (!GameAudio.isVoiceAsset(nextAsset)) return false;
    }
    return true;
  }

  /// Hızlı ardışık 4 birleşme: tier 2/4/6/8, hepsi kombo>1, arada bekleme yok.
  Future<void> fourRapidMerges(AudioManager audio) async {
    await audio.playMerge(tierNumber: 2, comboCount: 2);
    await audio.playMerge(tierNumber: 4, comboCount: 2);
    await audio.playMerge(tierNumber: 6, comboCount: 2);
    await audio.playMerge(tierNumber: 8, comboCount: 2);
  }

  String tierVoiceAsset(int tier) =>
      'audio/${GameAudio.designSoundForTier(tier)}';

  group('Dalga 11 P2-1 — tier sesi özel kanalı', () {
    test('(a) 4 hızlı birleşme bitince çalan tier sesi TAM 1 ve son tier',
        () async {
      final audio = AudioManager();
      await fourRapidMerges(audio);

      final playing = playingTierVoices();
      expect(
        playing.map((p) => p.currentAsset).toList(),
        [tierVoiceAsset(8)],
        reason: 'yalnız son birleşmenin (tier 8) sesi çalmalı',
      );
    });

    test('(b) birleşme chime/combo\'su tier sesi oyuncusunu durdurmaz',
        () async {
      final audio = AudioManager();
      await fourRapidMerges(audio);

      expect(
        noTierVoiceKilledBySfx(),
        isTrue,
        reason: 'chime/combo bir tier sesini kesmemeli; log: $log',
      );
    });

    test('(c) playTierVoice çalan merge sesini temiz değiştirir', () async {
      final audio = AudioManager();
      await audio.playMerge(tierNumber: 4, comboCount: 2);
      await audio.playTierVoice(6);

      final playing = playingTierVoices();
      expect(
        playing.map((p) => p.currentAsset).toList(),
        [tierVoiceAsset(6)],
        reason: 'yalnız playTierVoice\'un tier 6 sesi çalmalı',
      );
    });

    test('(d) stopAll() sonrası hiçbir tier sesi çalmıyordur', () async {
      final audio = AudioManager();
      await fourRapidMerges(audio);
      await audio.stopAll();

      expect(playingTierVoices(), isEmpty);
    });
  });
}
