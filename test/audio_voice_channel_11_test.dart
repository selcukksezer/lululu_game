// Dalga 12K — sesler kesilmesin: üst üste binebilsin (12K-sound-overlap).
//
// Selçuk'un GÜNCEL isteği (2026-11-19 20:24, 2048 videosu): bir sonraki
// hamlede önceki ses kesiliyor; ses TAM çalacak. Bu, Dalga 11 P2-1'in
// TERSİDİR — P2-1'de tek tier-sesi kanalı + yeni ses eskisini durduruyordu
// ("başka karakterde başka ses çalmış oluyor" kaygısıyla). Güncel istek:
// yeni ses anında başlasın, eski ses kendi bitirsin (örtüşme kabul).
//
// Bu yüzden P2-1'in (a) "çalan tier sesi TAM 1 ve son tier" ve (c) "tek
// ses" beklentileri KALDIRILDI — artık çelişen beklenti kilitlenmiyor,
// tersi kilitleniyor: hızlı ardışık birleşmelerde HER tier sesi çalmaya
// devam eder.
//
// Ses testte kapalıdır (`_canPlayAsset` test ortamında false döner) ve
// Playwright sesi duyamaz — bu yüzden bu dosya mock'lu birim testidir:
// `AudioManager`'daki `@visibleForTesting` dikiş (oyuncu fabrikası +
// çalmayı zorlayan bayrak) üzerinden sahte oyuncularla hangi asset'in
// hangi oyuncuda çaldığı ve `stop()` çağrıları kaydedilir.
//
// DÜZELTME (beklenen davranış, 12K):
//   (a) Hızlı ardışık 4 birleşme bitince 4 tier sesi de çalmaya devam
//       eder (tier 2/4/6/8) — hiçbiri durmadı.
//   (b) 4 hızlı birleşme boyunca çalma yolunda HİÇ `stop()` çağrılmaz
//       (chime/combo bir tier sesini kesemez; havuz da çalan SFX'i
//       kesemez).
//   (c) `playTierVoice`, çalan merge sesinin ÜSTÜNE başlar — eski ses
//       durmaz, ikisi de çalar.
//   (d) `stopAll()` sonrası hiçbir tier sesi çalmıyordur (kasıtlı
//       susturma aynen durur).
//   (e) Hızlı ardışık iki `playMerge`'de İLK ses durmaz: ilk tier sesini
//       taşıyan oyuncuda `stop()` çağrısı yoktur, sesi hâlâ çalıyordur.
//   (f) SFX havuzu dolunca yeni SFX düşer, çalan SFX kesilmez; bir oyuncu
//       doğal bitince (`complete()`) sonraki SFX o oyuncuda çalar.
import 'dart:async';

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

  /// Tamamlanma akışı: temel sınıf kurucusu `onPlayerComplete`'i
  /// dinlediğinden denetleyici tembel kurulur (alan başlatıcıları üst
  /// kurucudan sonra çalışır).
  StreamController<void>? _completeController;

  @override
  Stream<void> get onPlayerComplete =>
      (_completeController ??= StreamController<void>.broadcast()).stream;

  /// Doğal bitişi simüle et: `AudioManager`'daki tamamlanma dinleyicisi
  /// oyuncuyu boşaltır/bırakır; çalan asset silinir.
  void complete() {
    currentAsset = null;
    _completeController?.add(null);
  }

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
  /// havuzun 8'i, sonra çalma başına tier sesi oyuncuları).
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

  /// Hızlı ardışık 4 birleşme: tier 2/4/6/8, hepsi kombo>1, arada bekleme yok.
  /// NOT: 4 birleşme = 8 SFX (havuz tam dolar) + 4 tier sesi (eşzamanlı
  /// ses sınırı tam dolar) — 5. birleşme testte SFX/tier sesi düşürür,
  /// çünkü sahte oyuncular hiç bitmez; üretimde kısa klipler biter ve
  /// oyuncu boşalır.
  Future<void> fourRapidMerges(AudioManager audio) async {
    await audio.playMerge(tierNumber: 2, comboCount: 2);
    await audio.playMerge(tierNumber: 4, comboCount: 2);
    await audio.playMerge(tierNumber: 6, comboCount: 2);
    await audio.playMerge(tierNumber: 8, comboCount: 2);
  }

  String tierVoiceAsset(int tier) =>
      'audio/${GameAudio.designSoundForTier(tier)}';

  group('Dalga 12K — sesler kesilmesin, üst üste binsin', () {
    test('(a) 4 hızlı birleşme bitince 4 tier sesi de çalıyor', () async {
      final audio = AudioManager();
      await fourRapidMerges(audio);

      final playing = playingTierVoices();
      expect(
        playing.map((p) => p.currentAsset).toList(),
        [
          tierVoiceAsset(2),
          tierVoiceAsset(4),
          tierVoiceAsset(6),
          tierVoiceAsset(8),
        ],
        reason: 'hiçbir tier sesi kesilmemeli; 4\'ü de üst üste çalmalı',
      );
    });

    test('(b) 4 hızlı birleşme boyunca çalma yolunda stop() yok', () async {
      final audio = AudioManager();
      await fourRapidMerges(audio);

      expect(
        log.where((e) => e.startsWith('stop:')).toList(),
        isEmpty,
        reason: 'chime/combo/havuz hiçbir çalan sesi kesmemeli; log: $log',
      );
    });

    test('(c) playTierVoice çalan merge sesinin üstüne başlar', () async {
      final audio = AudioManager();
      await audio.playMerge(tierNumber: 4, comboCount: 2);
      await audio.playTierVoice(6);

      final playing = playingTierVoices();
      expect(
        playing.map((p) => p.currentAsset).toList(),
        [tierVoiceAsset(4), tierVoiceAsset(6)],
        reason: 'eski tier 4 sesi durmamalı, tier 6 üstüne başlamalı',
      );
    });

    test('(d) stopAll() sonrası hiçbir tier sesi çalmıyordur', () async {
      final audio = AudioManager();
      await fourRapidMerges(audio);
      await audio.stopAll();

      expect(playingTierVoices(), isEmpty);
      expect(
        created.where((p) => p.currentAsset != null).toList(),
        isEmpty,
        reason: 'stopAll havuz + tier sesi oyuncularını susturmalı',
      );
    });

    test('(e) iki hızlı playMerge: İLK ses durmadı', () async {
      final audio = AudioManager();
      await audio.playMerge(tierNumber: 2, comboCount: 2);
      final firstVoicePlayer = playingTierVoices().singleWhere(
        (p) => p.currentAsset == tierVoiceAsset(2),
      );
      await audio.playMerge(tierNumber: 4, comboCount: 2);

      expect(
        firstVoicePlayer.stopCalls,
        0,
        reason: 'ikinci birleşme ilk tier sesini durdurmamalı',
      );
      expect(
        firstVoicePlayer.currentAsset,
        tierVoiceAsset(2),
        reason: 'ilk ses hâlâ çalıyordur',
      );
      expect(
        playingTierVoices().map((p) => p.currentAsset).toList(),
        [tierVoiceAsset(2), tierVoiceAsset(4)],
        reason: 'iki ses de üst üste çalmalı',
      );
    });

    test('(f) SFX havuzu dolunca yeni SFX düşer, biten oyuncu yeniden '
        'kullanılır', () async {
      final audio = AudioManager();
      const sfx = GameAudio.sfxPop;
      for (var i = 0; i < 8; i++) {
        await audio.playSfx(sfx, isVoice: false);
      }
      final poolPlays =
          log.where((e) => e.startsWith('play:')).toList();
      expect(poolPlays.length, 8, reason: 'havuzun 8 oyuncusu da dolmalı');
      expect(
        poolPlays.map((e) => e.split(':')[1]).toSet().length,
        8,
        reason: 'her SFX ayrı oyuncuda çalmalı',
      );

      // 9. SFX: havuz dolu — çalan ses kesilmez, yeni ses düşer.
      await audio.playSfx(sfx, isVoice: false);
      expect(
        log.where((e) => e.startsWith('play:')).length,
        8,
        reason: 'dolu havuzda 9. SFX çalmamalı',
      );
      expect(
        log.where((e) => e.startsWith('stop:')).toList(),
        isEmpty,
        reason: 'dolu havuzda hiçbir çalan SFX durdurulmamalı',
      );

      // Bir oyuncu doğal bitince sonraki SFX o oyuncuda çalar.
      final freed = created[2];
      freed.complete();
      await Future<void>.delayed(Duration.zero);
      await audio.playSfx(sfx, isVoice: false);
      expect(
        log.last,
        'play:${freed.id}:audio/$sfx',
        reason: 'boşalan oyuncu yeniden kullanılmalı',
      );
    });
  });
}
