import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/insect_tier.dart';

/// Asset filenames under `assets/audio/`.
abstract final class GameAudio {
  static const sfxAydinlatBeam = 'sfx_aydinlat_beam.mp3';
  static const sfxCombo = 'sfx_combo.mp3';
  static const sfxDrop = 'sfx_drop.mp3';
  static const sfxGameOver = 'sfx_gameover.mp3';
  static const sfxMergeChime = 'sfx_merge_chime.mp3';
  static const sfxPop = 'sfx_pop.mp3';
  static const sfxSlipper = 'sfx_slipper.mp3';
  static const sfxSpray = 'sfx_spray.mp3';
  static const voiceAydinlat = 'voice_aydinlat.mp3';
  static const voiceTier1 = 'voice_tier1.mp3';
  static const voiceTier2 = 'voice_tier2.mp3';
  static const voiceTier3 = 'voice_tier3.mp3';
  static const voiceTier4 = 'voice_tier4.mp3';
  static const voiceTier5 = 'voice_tier5.mp3';
  static const voiceTier6 = 'voice_tier6.mp3';
  static const voiceTier7 = 'voice_tier7.mp3';
  static const voiceTier8 = 'voice_tier8.mp3';

  /// Dedicated Osmantuş person lines — not on disk yet; map falls back below.
  static const voiceOsmanA = 'voice_osman_a.mp3';
  static const voiceOsmanB = 'voice_osman_b.mp3';

  static const allAssets = [
    sfxAydinlatBeam,
    sfxCombo,
    sfxDrop,
    sfxGameOver,
    sfxMergeChime,
    sfxPop,
    sfxSlipper,
    sfxSpray,
    voiceAydinlat,
    voiceTier1,
    voiceTier2,
    voiceTier3,
    voiceTier4,
    voiceTier5,
    voiceTier6,
    voiceTier7,
    voiceTier8,
  ];

  /// Verified `voice_tierN.mp3` for merge tier 1–8; null if out of range.
  static String? voiceForTier(int tier) {
    switch (tier) {
      case 1:
        return voiceTier1;
      case 2:
        return voiceTier2;
      case 3:
        return voiceTier3;
      case 4:
        return voiceTier4;
      case 5:
        return voiceTier5;
      case 6:
        return voiceTier6;
      case 7:
        return voiceTier7;
      case 8:
        return voiceTier8;
      default:
        return null;
    }
  }

  /// Tap/squash character id → voice filename under `assets/audio/`.
  ///
  /// Osmantuş A/B: preferred dedicated files; until present, map to distinct
  /// existing tier voices (A→tier6 Can, B→tier5 Diva) so each person differs.
  static String? voiceForCharacterId(String characterId) {
    switch (characterId) {
      case 'tier_1':
        return voiceTier1;
      case 'tier_2':
        return voiceTier2;
      case 'tier_3':
        return voiceTier3;
      case 'tier_4':
        return voiceTier4;
      case 'tier_5':
        return voiceTier5;
      case 'tier_6':
        return voiceTier6;
      case 'tier_7':
        return voiceTier7;
      case 'tier_8':
        return voiceTier8;
      case 'osman_a':
        // Missing on disk: voice_osman_a.mp3 — fallback Hamam Can.
        return voiceTier6;
      case 'osman_b':
        // Missing on disk: voice_osman_b.mp3 — fallback Hamam Diva.
        return voiceTier5;
      default:
        return null;
    }
  }

  static String characterIdForTier(InsectTier tier) => 'tier_${tier.tier}';
}

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final List<AudioPlayer> _playersPool = [];
  int _poolIndex = 0;
  static const int _poolSize = 8;
  bool isMuted = false;
  bool _initialized = false;

  /// Bumped by [stopAll] so in-flight [playSfx] calls abort after leave-screen.
  int _playGeneration = 0;

  /// One-at-a-time voice/SFX channel (Çığlık etc.). Separate from pool.
  AudioPlayer? _exclusivePlayer;
  StreamSubscription<void>? _exclusiveCompleteSub;
  void Function()? _exclusiveOnComplete;
  bool _exclusiveBusy = false;

  /// True while [playExclusiveSfx] clip is still playing.
  bool get isExclusivePlaying => _exclusiveBusy;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    for (int i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.stop);
      _playersPool.add(p);
    }
    _preloadAssets();
  }

  Future<void> _preloadAssets() async {
    final preloader = AudioPlayer();
    try {
      for (final assetName in GameAudio.allAssets) {
        await preloader.setSource(AssetSource('audio/$assetName'));
      }
    } catch (_) {
      // Web / missing asset — runtime play still attempts fallback
    } finally {
      await preloader.dispose();
    }
  }

  /// Stop every pooled player. Call from game-screen [State.dispose]
  /// so SFX / voice do not leak into home / menu after route pop.
  ///
  /// Does not dispose the singleton pool — next screen reuses players.
  Future<void> stopAll() async {
    _playGeneration++;
    final gen = _playGeneration;
    _exclusiveBusy = false;
    _exclusiveOnComplete = null;
    final exclusiveSub = _exclusiveCompleteSub;
    _exclusiveCompleteSub = null;
    unawaited(exclusiveSub?.cancel() ?? Future<void>.value());
    final exclusive = _exclusivePlayer;
    if (exclusive != null) {
      try {
        await exclusive.stop();
      } catch (_) {
        // Platform / already released
      }
    }
    if (_playersPool.isEmpty) return;
    for (final p in _playersPool) {
      if (gen != _playGeneration) return;
      try {
        await p.stop();
      } catch (_) {
        // Platform / already released
      }
    }
  }

  Future<void> playSfx(
    String assetName, {
    double volume = 1.0,
    double playbackRate = 1.0,
  }) async {
    if (isMuted) return;
    final gen = _playGeneration;
    try {
      if (_playersPool.isEmpty) initialize();
      if (gen != _playGeneration) return;
      final player = _playersPool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _playersPool.length;
      await player.stop();
      if (gen != _playGeneration) return;
      await player.setVolume(volume);
      await player.setPlaybackRate(playbackRate.clamp(0.7, 1.45));
      if (gen != _playGeneration) return;
      await player.play(AssetSource('audio/$assetName'));
      if (gen != _playGeneration) {
        try {
          await player.stop();
        } catch (_) {}
      }
    } catch (e) {
      // Audio fallback or web policy
    }
  }

  /// One clip at a time. Returns `false` if another exclusive clip is active.
  ///
  /// [onComplete] runs only on natural end — not after [stopAll] / route pop.
  /// Mute: no audio; [onComplete] still runs so callers can unlock UI.
  Future<bool> playExclusiveSfx(
    String assetName, {
    double volume = 1.0,
    double playbackRate = 1.0,
    void Function()? onComplete,
  }) async {
    if (isMuted) {
      onComplete?.call();
      return true;
    }
    if (_exclusiveBusy) return false;

    final gen = _playGeneration;
    _exclusiveBusy = true;
    _exclusiveOnComplete = onComplete;

    try {
      _exclusivePlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      final player = _exclusivePlayer!;
      await _exclusiveCompleteSub?.cancel();
      _exclusiveCompleteSub = player.onPlayerComplete.listen((_) {
        _exclusiveBusy = false;
        final cb = _exclusiveOnComplete;
        _exclusiveOnComplete = null;
        if (gen != _playGeneration) return;
        cb?.call();
      });

      if (gen != _playGeneration) {
        _exclusiveBusy = false;
        _exclusiveOnComplete = null;
        return false;
      }
      await player.stop();
      if (gen != _playGeneration) {
        _exclusiveBusy = false;
        _exclusiveOnComplete = null;
        return false;
      }
      await player.setVolume(volume);
      await player.setPlaybackRate(playbackRate.clamp(0.7, 1.45));
      if (gen != _playGeneration) {
        _exclusiveBusy = false;
        _exclusiveOnComplete = null;
        return false;
      }
      await player.play(AssetSource('audio/$assetName'));
      if (gen != _playGeneration) {
        try {
          await player.stop();
        } catch (_) {}
        _exclusiveBusy = false;
        _exclusiveOnComplete = null;
        return false;
      }
      return true;
    } catch (_) {
      _exclusiveBusy = false;
      _exclusiveOnComplete = null;
      return false;
    }
  }

  /// Merge juice: merge SFX (+ optional combo) together with `voice_tierN`.
  ///
  /// Prefer [tier]; else [tierNumber] 1–8 maps to verified `GameAudio.voiceTierN`.
  Future<void> playMerge({
    InsectTier? tier,
    int? tierNumber,
    int comboCount = 1,
  }) async {
    final voiceAsset = _resolveMergeVoice(tier: tier, tierNumber: tierNumber);
    final plays = <Future<void>>[
      playSfx(GameAudio.sfxMergeChime),
    ];
    if (comboCount > 1) {
      plays.add(playSfx(GameAudio.sfxCombo, volume: 0.85));
    }
    if (voiceAsset != null) {
      plays.add(playSfx(voiceAsset));
    }
    await Future.wait(plays);
  }

  String? _resolveMergeVoice({InsectTier? tier, int? tierNumber}) {
    if (tier != null) {
      final fromTier = GameAudio.voiceForTier(tier.tier);
      if (fromTier != null) return fromTier;
      // Fall back to model path only when it matches a known asset name.
      if (GameAudio.allAssets.contains(tier.voiceFile)) {
        return tier.voiceFile;
      }
      return null;
    }
    if (tierNumber != null) {
      return GameAudio.voiceForTier(tierNumber);
    }
    return null;
  }

  Future<void> playDrop() => playSfx(GameAudio.sfxDrop);

  Future<void> playWin() => playSfx(GameAudio.voiceTier8);

  Future<void> playLose() => playSfx(GameAudio.sfxGameOver);

  Future<void> playPop() => playSfx(GameAudio.sfxPop);

  Future<void> playAydinlatVoice() => playSfx(GameAudio.voiceAydinlat);

  Future<void> playAydinlatBeam() => playSfx(GameAudio.sfxAydinlatBeam);

  Future<void> playSlipper() => playSfx(GameAudio.sfxSlipper);

  /// Terlik tap smash: slipper SFX + that character's voice (not a generic merge).
  ///
  /// Resolve order: [characterId] map → [tier] voice → pop fallback + log.
  Future<void> playSlipperSmash({
    String? characterId,
    InsectTier? tier,
    int comboCount = 1,
  }) async {
    final plays = <Future<void>>[
      playSfx(GameAudio.sfxSlipper),
    ];

    String? voice;
    if (characterId != null && characterId.isNotEmpty) {
      voice = GameAudio.voiceForCharacterId(characterId);
    }
    voice ??= _resolveMergeVoice(tier: tier, tierNumber: tier?.tier);

    if (voice != null) {
      plays.add(playSfx(voice));
    } else {
      debugPrint(
        '[Audio] slipper smash missing voice '
        'id=$characterId tier=${tier?.tier} — fallback pop',
      );
      plays.add(playSfx(GameAudio.sfxPop, volume: 0.7));
    }

    if (comboCount >= 3) {
      plays.add(playSfx(GameAudio.sfxCombo, volume: 0.85));
    }
    await Future.wait(plays);
  }

  Future<void> playSpray() => playSfx(GameAudio.sfxSpray);

  /// Light impact — drop / soft feedback.
  void triggerLightHaptic() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium impact — standard merge feedback.
  void triggerMediumHaptic() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact — high combo / big merge.
  void triggerHeavyHaptic() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Alias for [triggerLightHaptic] (existing call sites).
  void triggerHaptic() => triggerLightHaptic();

  void dispose() {
    _playGeneration++;
    _exclusiveBusy = false;
    _exclusiveOnComplete = null;
    unawaited(_exclusiveCompleteSub?.cancel() ?? Future<void>.value());
    _exclusiveCompleteSub = null;
    final exclusive = _exclusivePlayer;
    _exclusivePlayer = null;
    exclusive?.dispose();
    for (final p in _playersPool) {
      p.dispose();
    }
    _playersPool.clear();
    _initialized = false;
  }
}
