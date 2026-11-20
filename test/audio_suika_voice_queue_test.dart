// Suika birleşme replik kuyruğu — sıralı, tek ses (Selçuk kuralı,
// 2026-11-20 20:24): Suika'da karakter sesleri birbirine girmeyecek,
// arka arkaya çalacak; bir ses bitmeden yenisi başlamaz.
//
// Kapsam: YALNIZ Suika birleşme akışı (`playMergeQueued` +
// `enqueueSuikaVoice`). `playMerge`/`playMergeHisir` aynen durur —
// Dalga 12K'nın üst üste binme davranışı diğer modlarda korunur, bu
// dosya o davranışı değiştirmez (bkz. audio_voice_channel_11_test.dart).
//
// Kilitlenen davranış:
//   (a) Hızlı ardışık 3 birleşme: aynı anda SADECE 1 tier sesi çalar,
//       hepsi AYNI adanmış oyuncuda, sırayla (tier 2 → 4 → 6); bir
//       sonraki, önceki doğal bitmeden başlamaz.
//   (b) Kuyruk sınırı: çalan + en fazla 2 bekleyen; 5 hızlı birleşmede
//       en eski bekleyenler düşer (tier 3/4 hiç çalmaz), en yeniler
//       korunur (sıra: 2 → 5 → 6).
//   (c) `onStart` geri çağrıları başlama sırasıyla, birer birer gelir.
//   (d) Kuyruk boşalınca `onSuikaVoiceQueueDrained` bir kez çağrılır.
//   (e) `playMergeQueued`: chime anında havuzda çalar, tier sesi
//       kuyruğa girer; Hışır'lı birleşmede `hisir_zopa.mp3` kuyruğa girer.
//   (f) `stopAll()`: bekleyenler düşer, çalan susturulur, drained çağrılır.
//   (g) Ses kapalıyken ses çıkmaz ama `onStart` sırayla yine çağrılır
//       (toast sırası korunur).
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/audio_manager.dart';

/// Sahte oyuncu: 12K testindekiyle aynı desen — hangi asset'in hangi
/// oyuncuda çaldığını + `stop()` çağrılarını kaydeder; gerçek ses çalmaz.
class _FakeAudioPlayer extends AudioPlayer {
  _FakeAudioPlayer(this.id, this.log);

  final String id;
  final List<String> log;

  String? currentAsset;
  int stopCalls = 0;
  int playCalls = 0;

  StreamController<void>? _completeController;

  @override
  Stream<void> get onPlayerComplete =>
      (_completeController ??= StreamController<void>.broadcast()).stream;

  /// Doğal bitişi simüle et.
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

  final created = <_FakeAudioPlayer>[];
  final log = <String>[];

  setUpAll(() {
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

  /// Kuyruk pompasının mikro görevlerini ilerlet.
  Future<void> settleQueue() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  String tierVoiceAsset(int tier) =>
      'audio/${GameAudio.designSoundForTier(tier)}';

  /// Adanmış kuyruk oyuncusu (havuzun 8'inden sonra yaratılan ilk oyuncu).
  _FakeAudioPlayer queuePlayer() => created[8];

  /// Şu an çalan ses sayısı (havuz + kuyruk oyuncusu dahil).
  int playingCount() =>
      created.where((p) => p.currentAsset != null).length;

  group('Suika replik kuyruğu — sıralı, tek ses', () {
    test('(a) 3 hızlı birleşme: tek ses, aynı oyuncu, sırayla', () async {
      final audio = AudioManager();
      final started = <String>[];
      audio.enqueueSuikaVoice(
        GameAudio.designSoundForTier(2)!,
        onStart: () => started.add('tier2'),
      );
      audio.enqueueSuikaVoice(
        GameAudio.designSoundForTier(4)!,
        onStart: () => started.add('tier4'),
      );
      audio.enqueueSuikaVoice(
        GameAudio.designSoundForTier(6)!,
        onStart: () => started.add('tier6'),
      );
      await settleQueue();

      expect(created.length, 9, reason: 'kuyruk tek adanmış oyuncu açmalı');
      expect(
        queuePlayer().currentAsset,
        tierVoiceAsset(2),
        reason: 'önce tier 2 başlamalı',
      );
      expect(started, ['tier2'], reason: 'yalnız ilk öğe başlamış olmalı');
      expect(audio.suikaVoicePendingCount, 2, reason: '2 öğe beklemeli');
      expect(audio.suikaVoiceBusy, isTrue);
      expect(playingCount(), 1, reason: 'aynı anda tek ses çalmalı');

      queuePlayer().complete();
      await settleQueue();
      expect(queuePlayer().currentAsset, tierVoiceAsset(4));
      expect(started, ['tier2', 'tier4']);
      expect(playingCount(), 1);

      queuePlayer().complete();
      await settleQueue();
      expect(queuePlayer().currentAsset, tierVoiceAsset(6));
      expect(started, ['tier2', 'tier4', 'tier6']);
      expect(playingCount(), 1);

      queuePlayer().complete();
      await settleQueue();
      expect(playingCount(), 0);
      expect(audio.suikaVoiceBusy, isFalse);
      expect(audio.suikaVoicePendingCount, 0);
    });

    test('(b) kuyruk sınırı: 5 hızlı birleşmede en eskiler düşer', () async {
      final audio = AudioManager();
      for (final tier in [2, 3, 4, 5, 6]) {
        audio.enqueueSuikaVoice(GameAudio.designSoundForTier(tier)!);
      }
      await settleQueue();

      expect(queuePlayer().currentAsset, tierVoiceAsset(2));
      // Çalan (2) + bekleyen en fazla 2: 3 ve 4 düştü, 5 ve 6 kaldı.
      expect(audio.suikaVoicePendingCount, 2);

      queuePlayer().complete();
      await settleQueue();
      expect(
        queuePlayer().currentAsset,
        tierVoiceAsset(5),
        reason: 'düşen 3/4 atlanmalı, sıra 5\'te olmalı',
      );

      queuePlayer().complete();
      await settleQueue();
      expect(queuePlayer().currentAsset, tierVoiceAsset(6));

      final voicePlays = log
          .where((e) => e.startsWith('play:p8:'))
          .map((e) => e.split(':').last)
          .toList();
      expect(
        voicePlays,
        [tierVoiceAsset(2), tierVoiceAsset(5), tierVoiceAsset(6)],
        reason: 'tier 3/4 hiç çalmamalı; sıra 2 → 5 → 6 olmalı',
      );
    });

    test('(c) onStart sırayla, birer birer gelir', () async {
      final audio = AudioManager();
      final started = <String>[];
      audio.enqueueSuikaVoice(
        GameAudio.designSoundForTier(2)!,
        onStart: () => started.add('2'),
      );
      audio.enqueueSuikaVoice(
        GameAudio.designSoundForTier(4)!,
        onStart: () => started.add('4'),
      );
      await settleQueue();
      expect(started, ['2']);
      queuePlayer().complete();
      await settleQueue();
      expect(started, ['2', '4']);
    });

    test('(d) kuyruk boşalınca drained bir kez çağrılır', () async {
      final audio = AudioManager();
      var drained = 0;
      audio.onSuikaVoiceQueueDrained = () => drained++;
      audio.enqueueSuikaVoice(GameAudio.designSoundForTier(2)!);
      audio.enqueueSuikaVoice(GameAudio.designSoundForTier(4)!);
      await settleQueue();
      expect(drained, 0, reason: 'kuyruk doluyken çağrılmamalı');
      queuePlayer().complete();
      await settleQueue();
      expect(drained, 0, reason: 'henüz 1 öğe bekliyor');
      queuePlayer().complete();
      await settleQueue();
      expect(drained, 1, reason: 'kuyruk boşalınca tam bir kez çağrılmalı');
    });

    test('(e) playMergeQueued: chime anında, tier sesi kuyrukta', () async {
      final audio = AudioManager();
      final started = <String>[];
      await audio.playMergeQueued(
        tierNumber: 2,
        comboCount: 2,
        onVoiceStart: () => started.add('tier2'),
      );
      await audio.playMergeQueued(
        tierNumber: 4,
        comboCount: 2,
        onVoiceStart: () => started.add('tier4'),
      );
      await settleQueue();

      // Chime'lar havuzda anında çaldı (iki ayrı havuz oyuncusu).
      final chimePlays = log
          .where((e) => e.contains(GameAudio.sfxMergeChime))
          .toList();
      expect(chimePlays.length, 2, reason: 'her birleşmede chime çalmalı');
      // Tier sesleri: yalnız ilki çalıyor, ikincisi kuyrukta bekliyor.
      expect(queuePlayer().currentAsset, tierVoiceAsset(2));
      expect(started, ['tier2']);
      expect(audio.suikaVoicePendingCount, 1);

      queuePlayer().complete();
      await settleQueue();
      expect(queuePlayer().currentAsset, tierVoiceAsset(4));
      expect(started, ['tier2', 'tier4']);
    });

    test('(e2) playMergeQueued hisir: hisir_zopa kuyruğa girer', () async {
      final audio = AudioManager();
      await audio.playMergeQueued(
        tierNumber: 5,
        hisirInvolved: true,
      );
      await settleQueue();
      expect(
        queuePlayer().currentAsset,
        'audio/${GameAudio.hisirZopa}',
        reason: 'Hışır\'lı birleşmede onaylı Hışır klibi kuyruğa girmeli',
      );
    });

    test('(f) stopAll: bekleyenler düşer, çalan susturulur', () async {
      final audio = AudioManager();
      var drained = 0;
      audio.onSuikaVoiceQueueDrained = () => drained++;
      audio.enqueueSuikaVoice(GameAudio.designSoundForTier(2)!);
      audio.enqueueSuikaVoice(GameAudio.designSoundForTier(4)!);
      await settleQueue();
      expect(queuePlayer().currentAsset, tierVoiceAsset(2));

      await audio.stopAll();
      expect(audio.suikaVoicePendingCount, 0);
      expect(audio.suikaVoiceBusy, isFalse);
      expect(queuePlayer().currentAsset, isNull);
      expect(queuePlayer().stopCalls, 1, reason: 'çalan kuyruk sesi durmalı');
      expect(drained, 1, reason: 'boşaltma drained bildirmeli');
    });

    test('(h) stopAll sonrası eski iş yeni kuşağın sesini bozmaz', () async {
      final audio = AudioManager();
      // Eski iş sessiz-beklemede (900 ms) takılı kalır: ses kapalıyken
      // kuyruk öğesi ses çıkarmadan bekler.
      audio.voiceEnabled = false;
      audio.enqueueSuikaVoice(GameAudio.designSoundForTier(2)!);
      await settleQueue();
      expect(audio.suikaVoiceBusy, isTrue);

      // Kuşak değişir (stopAll) ve yeni kuşakta yeni ses başlar.
      await audio.stopAll();
      expect(audio.suikaVoiceBusy, isFalse);
      audio.voiceEnabled = true;
      final started = <String>[];
      audio.enqueueSuikaVoice(
        GameAudio.designSoundForTier(4)!,
        onStart: () => started.add('4'),
      );
      await settleQueue();
      expect(queuePlayer().currentAsset, tierVoiceAsset(4));
      expect(audio.suikaVoiceBusy, isTrue);

      // Eski işin 900 ms beklemesi dolar: eski finally çalışır ama
      // güncel kuşağın busy bayrağına dokunmamalı.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(
        audio.suikaVoiceBusy,
        isTrue,
        reason: 'eski işin finallysi çalan yeni sesi boşa çıkarmamalı',
      );
      expect(queuePlayer().currentAsset, tierVoiceAsset(4));

      queuePlayer().complete();
      await settleQueue();
      expect(audio.suikaVoiceBusy, isFalse);
      expect(started, ['4']);
    });

    test('(g) ses kapalıyken ses çıkmaz ama onStart sırayla gelir',
        () async {
      final audio = AudioManager();
      audio.voiceEnabled = false;
      final started = <String>[];
      audio.enqueueSuikaVoice(
        GameAudio.designSoundForTier(2)!,
        onStart: () => started.add('tier2'),
      );
      await settleQueue();
      expect(started, ['tier2'], reason: 'toast sırası ses kapalıyken de ilerlemeli');
      expect(
        log.where((e) => e.startsWith('play:')).toList(),
        isEmpty,
        reason: 'ses kapalıyken hiçbir çalma olmamalı',
      );
    });
  });
}
