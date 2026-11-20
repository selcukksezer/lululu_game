// `AudioManager.initialize()` yeniden-dene kilidi — 2048 sessizliği
// araştırması (2026-11-20): `_initialized` eskiden havuz kurulmadan ÖNCE
// yazılıyordu. 8 fabrika çağrısı da atarsa havuz boş kalır ama bayrak
// `true` olur, sonraki `initialize()` erken döner ve `_playPooled`
// içindeki yeniden-dene yolu işe yaramaz: kalıcı sessizlik.
//
// Kilitlenen davranış: fabrika atarsa havuz boş kalır ve bayrak
// yazılmaz; fabrika düzelince sonraki `initialize()` havuzu kurar.
// Normal yol aynen: havuz doluyken ikinci `initialize()` oyuncu eklemez.
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/audio_manager.dart';

/// Sahte oyuncu: `audio_suika_voice_queue_test.dart` ile aynı desen —
/// hangi oyuncunun kurulduğunu sayar; gerçek ses çalmaz.
class _FakeAudioPlayer extends AudioPlayer {
  _FakeAudioPlayer(this.id);

  final String id;

  StreamController<void>? _completeController;

  @override
  Stream<void> get onPlayerComplete =>
      (_completeController ??= StreamController<void>.broadcast()).stream;

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
  }) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final created = <_FakeAudioPlayer>[];

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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    created.clear();
    final audio = AudioManager();
    audio.dispose();
    audio.forcePlaybackForTesting = true;
    audio.isMuted = false;
    audio.sfxEnabled = true;
    audio.voiceEnabled = true;
    audio.vibrationEnabled = false;
  });

  tearDown(() {
    final audio = AudioManager();
    audio.dispose();
    audio.forcePlaybackForTesting = false;
  });

  test('fabrika atarsa havuz boş kalır, düzelince initialize yeniden kurar',
      () {
    final audio = AudioManager();
    audio.playerFactory = () => throw StateError('fabrika bozuk');
    audio.initialize();
    expect(created.length, 0,
        reason: 'atan fabrika oyuncu kurmamalı, bayrak yazılmamalı');

    audio.playerFactory = () {
      final fake = _FakeAudioPlayer('p${created.length}');
      created.add(fake);
      return fake;
    };
    audio.initialize();
    expect(created.length, 8,
        reason: 'fabrika düzelince ikinci initialize havuzu kurmalı');

    audio.initialize();
    expect(created.length, 8,
        reason: 'havuz doluyken ikinci initialize oyuncu eklememeli');
  });
}
