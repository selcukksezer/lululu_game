import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/insect_tier.dart';
import 'haptic_service.dart';
import 'progress_manager.dart';

/// Asset filenames under the single canonical folder `assets/audio/`
/// (madde 17: the byte-identical legacy duplicates were deleted; only
/// `assets/audio/` remains — see `assets/audio/ASSETS_NOTE.md`).
/// Every constant here is a BARE filename, never a full path
/// (Mac merge rule); [_normalizeAssetPath] joins it with `audio/`
/// at playback time.
abstract final class GameAudio {
  static const sfxAydinlatBeam = 'sfx_aydinlat_beam.mp3';
  static const sfxButtonTap = 'sfx_button_tap.mp3';
  static const sfxCombo = 'sfx_combo.mp3';
  static const sfxDrop = 'sfx_drop.mp3';
  static const sfxF16 = 'sfx_f16.mp3';
  static const sfxGameOver = 'sfx_gameover.mp3';
  static const sfxMakaraSpin = 'sfx_makara_spin.mp3';
  static const sfxMergeChime = 'sfx_merge_chime.mp3';
  static const sfxOsmantusBeat = 'sfx_osmantus_beat.mp3';
  static const sfxPop = 'sfx_pop.mp3';
  static const sfxScreamRoach = 'sfx_scream_roach.mp3';
  static const sfxSlipper = 'sfx_slipper.mp3';
  static const sfxSpray = 'sfx_spray.mp3';
  static const sfxVictory = 'sfx_victory.mp3';

  static const voiceAydinlat = 'voice_aydinlat.mp3';

  /// Prototype design sound naming (`tier1_ses.mp3`..`tier13_ses.mp3`).
  static const tier1Ses = 'tier1_ses.mp3';
  static const tier2Ses = 'tier2_ses.mp3';
  static const tier3Ses = 'tier3_ses.mp3';
  static const tier4Ses = 'tier4_ses.mp3';
  static const tier5Ses = 'tier5_ses.mp3';
  static const tier6Ses = 'tier6_ses.mp3';
  static const tier7Ses = 'tier7_ses.mp3';
  static const tier8Ses = 'tier8_ses.mp3';
  static const tier9Ses = 'tier9_ses.mp3';
  static const tier10Ses = 'tier10_ses.mp3';
  static const tier11Ses = 'tier11_ses.mp3';
  static const tier12Ses = 'tier12_ses.mp3';
  static const tier13Ses = 'tier13_ses.mp3';

  /// Dedicated Osmantuş person lines extracted from original viral TikTok audio.
  static const voiceOsmanA = 'voice_osman_a.mp3';
  static const voiceOsmanB = 'voice_osman_b.mp3';

  /// Viral one-shot lines cut from TikTok clips (see `assets/audio/ASSETS_NOTE.md`
  /// for source video ids and cut ranges). Filenames are bare, like every other
  /// entry here: consumers join them with `assets/audio/` themselves.
  static const mezarinaSiktigim = 'mezarina_siktigim.mp3';
  static const divaSinyal = 'diva_sinyal.mp3';
  static const divaYasla = 'diva_yasla.mp3';
  static const lululuNakarat = 'lululu_nakarat.mp3';
  static const duktur = 'duktur.mp3';
  static const kanka = 'kanka.mp3';

  /// Hışır'ın sesi — onaylı klip: sim_bocekalem.i_7706225030606146834
  /// 16.6–22.1 sn kesimi ("Gemü'ne sıçtığımın garısı, şimdi şahadet getir,
  /// sonra zopayı getir"). Selçuk kulakla onayladı (2026-11-19 19:49:
  /// "evet bu kısım doğru seste"). Eski aday `husur_aday.mp3` artık
  /// kullanılmıyor; dosya assets'te duruyor, silme kararı koordinatörde.
  static const hisirZopa = 'hisir_zopa.mp3';

  /// Viral one-shot clips, spread into [allAssets] for warmup + integrity checks.
  static const viralOneShots = [
    mezarinaSiktigim,
    divaSinyal,
    divaYasla,
    lululuNakarat,
    duktur,
    kanka,
    hisirZopa,
  ];

  static const allAssets = [
    sfxAydinlatBeam,
    sfxButtonTap,
    sfxCombo,
    sfxDrop,
    sfxF16,
    sfxGameOver,
    sfxMakaraSpin,
    sfxMergeChime,
    sfxOsmantusBeat,
    sfxPop,
    sfxScreamRoach,
    sfxSlipper,
    sfxSpray,
    sfxVictory,
    voiceAydinlat,
    voiceOsmanA,
    voiceOsmanB,
    ...viralOneShots,
    tier1Ses,
    tier2Ses,
    tier3Ses,
    tier4Ses,
    tier5Ses,
    tier6Ses,
    tier7Ses,
    tier8Ses,
    tier9Ses,
    tier10Ses,
    tier11Ses,
    tier12Ses,
    tier13Ses,
  ];

  /// Design sound `tierN_ses.mp3` for tier 1–13; null if out of range.
  ///
  /// The single canonical tier-voice set (12A): the byte-identical
  /// `voice_tierN.mp3` duplicates were deleted, so every tier/merge
  /// voice resolves here (see `AudioManager._resolveMergeVoice`).
  static String? designSoundForTier(int tier) {
    if (tier < 1 || tier > 13) return null;
    return 'tier${tier}_ses.mp3';
  }

  /// Tap/squash character id → voice filename under `assets/audio/`.
  ///
  /// `tier_N` ids resolve to the tier's design sound (`tierN_ses.mp3`,
  /// [designSoundForTier]); the byte-identical `voice_tierN.mp3`
  /// duplicates were deleted in 12A.
  static String? voiceForCharacterId(String characterId) {
    switch (characterId) {
      case 'tier_1':
        return designSoundForTier(1);
      case 'tier_2':
        return designSoundForTier(2);
      case 'tier_3':
        return designSoundForTier(3);
      case 'tier_4':
        return designSoundForTier(4);
      case 'tier_5':
        return designSoundForTier(5);
      case 'tier_6':
        return designSoundForTier(6);
      case 'tier_7':
        return designSoundForTier(7);
      case 'tier_8':
        return designSoundForTier(8);
      case 'tier_9':
        return designSoundForTier(9);
      case 'tier_10':
        return designSoundForTier(10);
      case 'tier_11':
        return designSoundForTier(11);
      case 'tier_12':
        return designSoundForTier(12);
      case 'tier_13':
        return designSoundForTier(13);
      case 'osman_a':
      case 'osman':
        return voiceOsmanA;
      case 'osman_b':
      case 'tus':
        return voiceOsmanB;
      case 'hisir':
        return hisirZopa;
      default:
        return null;
    }
  }

  static String characterIdForTier(InsectTier tier) => 'tier_${tier.tier}';

  /// Whether [assetName] is a character voice clip rather than generic SFX.
  static bool isVoiceAsset(String assetName) {
    final base = assetName.split('/').last;
    return base.startsWith('voice_') ||
        base.endsWith('_ses.mp3') ||
        viralOneShots.contains(base);
  }
}

/// Suika birleşme replik kuyruğu öğesi: çalınacak ses + çalmaya
/// başlarken çağrılacak geri çağrı (Suika ekranı yazıyı bununla yazar).
class _SuikaVoiceJob {
  _SuikaVoiceJob(this.assetName, this.onStart);
  final String assetName;
  final void Function()? onStart;
}

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;
  factory AudioManager() => _instance;
  AudioManager._internal() {
    _bindProgressManagerListeners();
  }

  final List<AudioPlayer> _playersPool = [];
  int _poolIndex = 0;
  static const int _poolSize = 8;

  /// Test dikişi (Dalga 11 P2-1): oyuncu fabrikası + testte çalmayı
  /// zorlayan bayrak. Üretim varsayılanları: gerçek [AudioPlayer]'lar,
  /// zorlama kapalı — üretim davranışı değişmez.
  ///
  /// 12B-q19: bayraktaki `@visibleForTesting` kaldırıldı — sonuç
  /// ekranı (`result_screen.dart` `initState`) test atlamasını bu
  /// bayrağa göre açar; üretim kodu bayrağı okuduğu için işaret
  /// `invalid_use_of_visible_for_testing_member` uyarısı veriyordu.
  /// Bayrak yalnız testte açılır, üretimde hep `false` kalır.
  @visibleForTesting
  AudioPlayer Function() playerFactory = AudioPlayer.new;

  bool forcePlaybackForTesting = false;

  bool _isMuted = false;
  bool _sfxEnabled = true;
  bool _voiceEnabled = true;
  bool _vibrationEnabled = true;
  bool _initialized = false;
  bool _listenersBound = false;
  bool _syncingWithProgress = false;

  /// Effective audibility: the single master mute flag ([_isMuted]) ANDed
  /// with each channel's own preference. Mute/unmute never rewrites the
  /// channel preferences — [toggleMute] flips only [_isMuted], so unmuting
  /// restores exactly the mix the user had before muting. Every playback
  /// gate in this file derives from these getters (S2#7 / S2#9).
  ///
  /// 7C: [_isMuted] is a TRANSIENT lifecycle mute — its only writer is
  /// [AppLifecycleGuard] (pause → mute, resume → restore) plus
  /// [toggleMute]. No settings toggle reads or writes it, so the
  /// `!_isMuted` factor here cannot collapse the two channels into one
  /// switch: SFX off never silences voice and voice off never silences
  /// SFX outside a lifecycle pause. The settings-screen `isMuted` reads
  /// (initState + `_loadPrefs` fallback) were removed for the same reason.
  bool get _sfxAudible => !_isMuted && _sfxEnabled;
  bool get _voiceAudible => !_isMuted && _voiceEnabled;

  void _bindProgressManagerListeners() {
    if (_listenersBound) return;
    _listenersBound = true;
    final pm = ProgressManager.instance;
    _sfxEnabled = pm.sfxEnabled;
    _vibrationEnabled = pm.vibrationEnabled;

    pm.sfxNotifier.addListener(_onProgressSfxChanged);
    pm.vibrationNotifier.addListener(_onProgressVibrationChanged);
  }

  /// Mirror of [_bindProgressManagerListeners]: removes exactly the two
  /// listeners registered there and clears [_listenersBound] so a later
  /// [initialize] can bind again. Called from [dispose] (S2#8). The flag is
  /// cleared first so a re-entrant bind cannot double-register.
  void _unbindProgressManagerListeners() {
    if (!_listenersBound) return;
    _listenersBound = false;
    try {
      final pm = ProgressManager.instance;
      pm.sfxNotifier.removeListener(_onProgressSfxChanged);
      pm.vibrationNotifier.removeListener(_onProgressVibrationChanged);
    } catch (_) {}
  }

  void _onProgressSfxChanged() {
    if (_syncingWithProgress) return;
    final next = ProgressManager.instance.sfxEnabled;
    if (_sfxEnabled != next) {
      _sfxEnabled = next;
      if (!next && !_voiceEnabled) {
        unawaited(stopAll());
      }
    }
  }

  void _onProgressVibrationChanged() {
    if (_syncingWithProgress) return;
    final next = ProgressManager.instance.vibrationEnabled;
    if (_vibrationEnabled != next) {
      _vibrationEnabled = next;
    }
  }

  Future<void> _persistDualBool(
    String primaryKey,
    String legacyKey,
    bool value,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(primaryKey, value);
      await prefs.setBool(legacyKey, value);
    } catch (_) {}
  }

  /// Synchronizes flags two-way with [ProgressManager.instance] and `SharedPreferences`.
  Future<void> syncWithProgressManager() async {
    _bindProgressManagerListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final pm = ProgressManager.instance;

      final resolvedSfx = prefs.getBool('lululu_sfx_enabled') ??
          prefs.getBool('LululuSetSfx') ??
          pm.sfxEnabled;
      final resolvedVoice = prefs.getBool('lululu_voice_enabled') ??
          prefs.getBool('LululuSetVoice') ??
          _voiceEnabled;
      final resolvedVib = prefs.getBool('lululu_vibration_enabled') ??
          prefs.getBool('LululuSetVib') ??
          pm.vibrationEnabled;

      _syncingWithProgress = true;
      _sfxEnabled = resolvedSfx;
      _voiceEnabled = resolvedVoice;
      _vibrationEnabled = resolvedVib;

      if (pm.sfxEnabled != resolvedSfx) {
        await pm.setSfxEnabled(resolvedSfx);
      }
      if (pm.vibrationEnabled != resolvedVib) {
        await pm.setVibrationEnabled(resolvedVib);
      }
    } catch (_) {
    } finally {
      _syncingWithProgress = false;
    }
  }

  /// Master mute flag — transient lifecycle mute, NOT a settings toggle.
  ///
  /// The single mute switch (S2#7): setting it never rewrites
  /// [sfxEnabled]/[voiceEnabled] — those stay as user
  /// preferences and take effect again on unmute via the derived
  /// [_sfxAudible]/[_voiceAudible] gates. Callers that snapshot/restore
  /// around lifecycle pauses (AppLifecycleGuard) rely on this.
  /// 7C: no-change writes are no-ops (guard restores can re-write the
  /// same value without re-stopping playback).
  bool get isMuted => _isMuted;
  set isMuted(bool value) {
    if (_isMuted == value) return;
    _isMuted = value;
    if (value) {
      unawaited(stopAll());
    }
  }

  /// Settings screen toggle: Sound Effects (`sfxEnabled`).
  bool get sfxEnabled => _sfxEnabled;
  set sfxEnabled(bool value) {
    // 7C: no-change writes are no-ops — the setter is idempotent, so
    // `_loadPrefs` / toggle repeats never re-persist or re-notify.
    if (_sfxEnabled == value) return;
    _sfxEnabled = value;
    if (!value && !_voiceEnabled) {
      unawaited(stopAll());
    }
    final pm = ProgressManager.instance;
    if (pm.sfxEnabled != value) {
      _syncingWithProgress = true;
      pm.sfxEnabled = value;
      pm.sfxNotifier.value = value;
      _syncingWithProgress = false;
      unawaited(pm.setSfxEnabled(value).catchError((_) {}));
    }
    unawaited(_persistDualBool('lululu_sfx_enabled', 'LululuSetSfx', value));
  }

  /// Settings screen toggle: Viral Bug Voices (`voiceEnabled`).
  bool get voiceEnabled => _voiceEnabled;
  set voiceEnabled(bool value) {
    // 7C: no-change writes are no-ops (see [sfxEnabled]).
    if (_voiceEnabled == value) return;
    _voiceEnabled = value;
    if (!value && _exclusiveBusy) {
      unawaited(_stopExclusivePlayer());
    }
    unawaited(
      _persistDualBool('lululu_voice_enabled', 'LululuSetVoice', value),
    );
  }

  /// Settings screen toggle: Haptic Vibration (`vibrationEnabled`).
  bool get vibrationEnabled => _vibrationEnabled;
  set vibrationEnabled(bool value) {
    // 7C: no-change writes are no-ops (see [sfxEnabled]).
    if (_vibrationEnabled == value) return;
    _vibrationEnabled = value;
    final pm = ProgressManager.instance;
    if (pm.vibrationEnabled != value) {
      _syncingWithProgress = true;
      pm.vibrationEnabled = value;
      pm.vibrationNotifier.value = value;
      _syncingWithProgress = false;
      unawaited(pm.setVibrationEnabled(value).catchError((_) {}));
    }
    unawaited(
      _persistDualBool('lululu_vibration_enabled', 'LululuSetVib', value),
    );
  }

  void setSfxEnabled(bool enabled) => sfxEnabled = enabled;
  void setVoiceEnabled(bool enabled) => voiceEnabled = enabled;
  void setVibrationEnabled(bool enabled) => vibrationEnabled = enabled;

  /// Bumped by [stopAll] so in-flight [playSfx] calls abort after leave-screen.
  int _playGeneration = 0;

  /// One-at-a-time voice/SFX channel (Çığlık etc.). Separate from pool.
  AudioPlayer? _exclusivePlayer;
  StreamSubscription<void>? _exclusiveCompleteSub;
  void Function()? _exclusiveOnComplete;
  bool _exclusiveBusy = false;

  /// Tier voices play on a per-play player (Dalga 12K — 12K-sound-overlap).
  ///
  /// Selçuk'un güncel isteği (2026-11-19 20:24, 2048 videosu): bir sonraki
  /// hamlede önceki ses KESİLMEYECEK, ses tam çalacak; yeni ses eskisinin
  /// üstüne başlar (örtüşme kabul). Bu, Dalga 11 P2-1'in TERSİDİR (orada
  /// tek tier-sesi kanalı + yeni ses eskisini durduruyordu).
  ///
  /// Her tier sesi [playerFactory] ile yeni bir oyuncuda çalar ve doğal
  /// bitişte ([onPlayerComplete]) bırakılır — hiçbir çalma başka bir çalmayı
  /// durdurmaz. Eşzamanlı tier sesi [_maxConcurrentVoices] ile sınırlıdır:
  /// sınır doluysa YENİ ses düşer (eski ses asla kesilmez). [stopAll] /
  /// [dispose] yollarındaki kasıtlı susturma aynen durur: onlar bu kümedeki
  /// her oyuncuyu durdurur/bırakır.
  final Set<AudioPlayer> _voicePlayers = {};

  /// [_voicePlayers] üyelerinin tamamlanma abonelikleri — bırakma anında
  /// iptal edilir ([_releaseVoicePlayer]).
  final Map<AudioPlayer, StreamSubscription<void>> _voiceCompleteSubs = {};

  /// En fazla eşzamanlı tier sesi (12K). Sınır dolunca yeni ses düşer.
  static const int _maxConcurrentVoices = 4;

  /// SFX havuzunda şu an çalan oyuncular (12K): [playSfx] boş oyuncu
  /// seçer; havuz doluysa yeni SFX düşer, çalan SFX asla kesilmez.
  /// Tamamlanma ([onPlayerComplete]) oyuncuyu boşaltır; [stopAll] her
  /// durdurduğu oyuncuyu buradan çıkarır.
  final Set<AudioPlayer> _busyPoolPlayers = {};

  /// Havuz oyuncularının tamamlanma abonelikleri ([dispose] iptal eder).
  final List<StreamSubscription<void>> _poolCompleteSubs = [];

  /// Suika birleşme replik kuyruğu — sıralı, tek ses (Selçuk kuralı,
  /// 2026-11-20 20:24): Suika'da karakter sesleri birbirine girmeyecek,
  /// arka arkaya çalacak; bir ses bitmeden yenisi başlamaz.
  ///
  /// YALNIZ Suika birleşme akışı ([playMergeQueued] + [enqueueSuikaVoice])
  /// bu kuyruğu kullanır. [playMerge]/[playMergeHisir] ve diğer modların
  /// ses yolları aynen kalır (12K örtüşme davranışı onlara dokunulmaz).
  /// Hışır belirme/dokunma sesi ([playHusurAday] doğrudan çağrıları)
  /// kuyruğa girmez — onaylı klip aynen çalar; nadir Hışır belirmesi
  /// kuyruktaki bir replikle çakışabilir (bilinçli, kural dışı bırakıldı).
  ///
  /// Kuyruk tek adanmış oyuncuda ([_suikaVoicePlayer]) çalar; doğal
  /// bitiş ([onPlayerComplete], 10 sn güvenlik zaman aşımıyla) bir
  /// sonraki öğeyi başlatır. Bekleyen en fazla [_maxSuikaVoicePending]
  /// öğedir (çalan + 2 bekleyen = en fazla 3 uçuşta); sınır dolunca EN
  /// ESKİ bekleyen düşer (çalan asla kesilmez, en yeni korunur).
  /// Ses kapalıysa / testte çalma zorlanmıyorsa öğe ses çıkarmadan
  /// [_suikaVoiceMutedHold] bekler — toast sırası yine korunur.
  final List<_SuikaVoiceJob> _suikaVoiceQueue = [];
  bool _suikaVoiceBusy = false;
  AudioPlayer? _suikaVoicePlayer;
  int _suikaVoiceGen = 0;
  static const int _maxSuikaVoicePending = 2;
  static const Duration _suikaVoiceMaxClip = Duration(seconds: 10);
  static const Duration _suikaVoiceMutedHold = Duration(milliseconds: 900);

  /// Kuyruk boşaldığında çağrılır (son ses bittiğinde / [stopAll] /
  /// [clearSuikaVoiceQueue] ile boşaltıldığında). Suika ekranı bu
  /// geri çağrıyla replik bandını temizler.
  VoidCallback? onSuikaVoiceQueueDrained;

  /// Test dikişi: bekleyen (henüz başlamamış) kuyruk öğesi sayısı.
  @visibleForTesting
  int get suikaVoicePendingCount => _suikaVoiceQueue.length;

  /// Test dikişi: kuyrukta şu an bir ses çalıyor mu.
  @visibleForTesting
  bool get suikaVoiceBusy => _suikaVoiceBusy;

  /// True while [playExclusiveSfx] clip is still playing.
  bool get isExclusivePlaying => _exclusiveBusy;

  /// Detects `FlutterTest` / headless test runner so native platform channels
  /// never throw unhandled exceptions or leak timers during automated tests.
  bool get _isTestEnvironment {
    try {
      if (Zone.current[#test.declarer] != null) return true;
      final bindingType = WidgetsBinding.instance.runtimeType.toString();
      if (bindingType.contains('TestWidgetsFlutterBinding') ||
          bindingType.contains('AutomatedTestWidgetsFlutterBinding') ||
          bindingType.contains('LiveTestWidgetsFlutterBinding')) {
        return true;
      }
    } catch (_) {
      return true;
    }
    return false;
  }

  void initialize() {
    _bindProgressManagerListeners();
    if (!_isTestEnvironment) {
      unawaited(syncWithProgressManager());
    }
    if (_initialized ||
        _isMuted ||
        (_isTestEnvironment && !forcePlaybackForTesting)) {
      return;
    }
    // iOS AudioSession çakışmalarını (Code 561015905) önlemek için global ambient/mixWithOthers context ayarla
    try {
      AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } catch (_) {}

    for (int i = 0; i < _poolSize; i++) {
      try {
        final p = playerFactory();
        unawaited(p.setReleaseMode(ReleaseMode.stop).catchError((_) {}));
        _playersPool.add(p);
        // 12K: doğal bitiş oyuncuyu boşaltır — havuz dolunca çalan sesin
        // üstüne yazılmaz, boş oyuncu beklenir.
        _poolCompleteSubs.add(
          p.onPlayerComplete.listen((_) {
            _busyPoolPlayers.remove(p);
          }),
        );
      } catch (_) {}
    }

    // 2048 sessizliği araştırması (2026-11-20): `_initialized` eskiden
    // havuz kurulmadan ÖNCE yazılıyordu — 8 fabrika çağrısı da atarsa
    // havuz boş kalır ama bayrak `true` olur, sonraki `initialize()`
    // erken döner ve `_playPooled` içindeki yeniden-dene yolu işe
    // yaramaz: uygulama yeniden başlayana dek kalıcı sessizlik. Bayrak
    // yalnız havuzda en az 1 oyuncu varsa yazılır; boşsa sonraki çağrı
    // yeniden dener.
    if (_playersPool.isNotEmpty) _initialized = true;
  }

  Future<void> _stopExclusivePlayer() async {
    _exclusiveBusy = false;
    _exclusiveOnComplete = null;
    final exclusiveSub = _exclusiveCompleteSub;
    _exclusiveCompleteSub = null;
    try {
      await exclusiveSub?.cancel();
    } catch (_) {}
    final exclusive = _exclusivePlayer;
    if (exclusive != null) {
      try {
        await exclusive.stop();
      } catch (_) {}
    }
  }

  /// Kasıtlı susturma (12K: aynen kalır): kümedeki her tier sesi
  /// oyuncusunu durdurur ve bırakır. Çalma yolundan çağrılmaz.
  Future<void> _stopVoicePlayer() async {
    if (_voicePlayers.isEmpty) return;
    final players = _voicePlayers.toList();
    for (final player in players) {
      await _releaseVoicePlayer(player, stopFirst: true);
    }
  }

  /// [player] oyuncusunu tier sesi kümesinden çıkarır, tamamlanma
  /// aboneliğini iptal eder ve oyuncuyu bırakır. [stopFirst] ise önce
  /// durdurur ([stopAll] yolu); yoksa ses zaten doğal bitti.
  /// İki kez çağrılmak güvenlidir (küme/eşleme çıkarma + yakalanan
  /// hatalar idempotenttir).
  Future<void> _releaseVoicePlayer(
    AudioPlayer player, {
    bool stopFirst = false,
  }) async {
    final sub = _voiceCompleteSubs.remove(player);
    try {
      await sub?.cancel();
    } catch (_) {}
    _voicePlayers.remove(player);
    if (stopFirst) {
      try {
        await player.stop();
      } catch (_) {}
    }
    try {
      await player.dispose();
    } catch (_) {}
  }

  /// Stop every pooled player. Call from game-screen [State.dispose]
  /// so SFX / voice do not leak into home / menu after route pop.
  ///
  /// Does not dispose the singleton pool — next screen reuses players.
  Future<void> stopAll() async {
    _playGeneration++;
    final gen = _playGeneration;
    // Suika replik kuyruğu da boşaltılır: bekleyenler düşer, çalan
    // susturulur (kasıtlı susturma — [dispose]/ekran çıkışı yolu).
    _suikaVoiceGen++;
    _suikaVoiceQueue.clear();
    _suikaVoiceBusy = false;
    final suikaPlayer = _suikaVoicePlayer;
    if (suikaPlayer != null) {
      try {
        await suikaPlayer.stop();
      } catch (_) {}
    }
    // Kuyruk boşaldı (havuz boşsa bile aşağıdaki erken dönüşten önce).
    onSuikaVoiceQueueDrained?.call();
    await _stopExclusivePlayer();
    await _stopVoicePlayer();
    if (_playersPool.isEmpty) return;
    for (final p in _playersPool) {
      if (gen != _playGeneration) return;
      try {
        await p.stop();
      } catch (_) {
        // Platform / already released
      }
      // 12K: durdurulan oyuncu boştur — çalma yolunda bir daha
      // seçilebilsin (stop() tamamlanma olayı üretmez).
      _busyPoolPlayers.remove(p);
    }
  }

  /// Flips only the master mute flag (S2#7). Channel preferences
  /// ([sfxEnabled], [voiceEnabled]) are left untouched, so
  /// unmuting restores the exact pre-mute mix. Delegates
  /// to the [isMuted] setter so mute/unmute has a single mutation path.
  void toggleMute() {
    isMuted = !_isMuted;
  }

  bool _canPlayAsset(String assetName, {bool? isVoiceOverride}) {
    if (_isTestEnvironment && !forcePlaybackForTesting) return false;
    final isVoice = isVoiceOverride ?? GameAudio.isVoiceAsset(assetName);
    // S2#9: a voice clip needs only the voice channel (plus master mute,
    // folded into [_voiceAudible]); requiring SFX as well made the voice
    // toggle dead whenever SFX was off. Viral one-shots reach here with
    // `isVoice: true` (and [GameAudio.isVoiceAsset] also matches them).
    if (isVoice) {
      return _voiceAudible;
    }
    return _sfxAudible;
  }

  String _normalizeAssetPath(String assetName) {
    // Tolerate a leading 'assets/' (e.g. values written as full asset paths):
    // audioplayers already prefixes with 'assets/', so strip it first.
    final name = assetName.startsWith('assets/')
        ? assetName.substring('assets/'.length)
        : assetName;
    if (name.startsWith('audio/')) {
      return name;
    }
    // Canonical folder is `assets/audio/` (madde 17): the legacy duplicate
    // folders were deleted, so every name resolves here. Bare filenames
    // (every `GameAudio` constant) take the `audio/` prefix below.
    return 'audio/$name';
  }

  /// 12K — çalma öncesi `stop()` yok: seçilen oyuncu çalıyorsa üstüne
  /// yazılmaz; [_nextFreePoolPlayer] boş oyuncu arar, havuz doluysa yeni
  /// SFX düşer (çalan ses tam biter). Çalma-sonrası kuşak denetimindeki
  /// `stop()` kasıtlı susturmadır ([stopAll] araya girdiyse) ve kalır.
  Future<void> playSfx(
    String assetName, {
    double volume = 1.0,
    double playbackRate = 1.0,
    bool? isVoice,
  }) async {
    if (!_canPlayAsset(assetName, isVoiceOverride: isVoice)) return;
    final gen = _playGeneration;
    AudioPlayer? player;
    try {
      if (_playersPool.isEmpty) initialize();
      if (_playersPool.isEmpty || gen != _playGeneration) return;
      player = _nextFreePoolPlayer();
      if (player == null) return;
      _busyPoolPlayers.add(player);
      if (gen != _playGeneration) {
        _busyPoolPlayers.remove(player);
        return;
      }
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.setPlaybackRate(playbackRate.clamp(0.7, 1.45));
      if (gen != _playGeneration) {
        _busyPoolPlayers.remove(player);
        return;
      }
      await player.play(AssetSource(_normalizeAssetPath(assetName)));
      if (gen != _playGeneration) {
        try {
          await player.stop();
        } catch (_) {}
        _busyPoolPlayers.remove(player);
      }
    } catch (_) {
      // Çalma kurulamadıysa oyuncu boş sayılır — havuz daralmasın.
      if (player != null) _busyPoolPlayers.remove(player);
      // Graceful fallback for headless / test / platform audio constraints
    }
  }

  /// Round-robin sıradaki BOŞ havuz oyuncusu; hepsi çalıyorsa null.
  /// [_poolIndex] seçilen oyuncunun bir sonrasına ilerler.
  AudioPlayer? _nextFreePoolPlayer() {
    for (var i = 0; i < _playersPool.length; i++) {
      final candidate = _playersPool[(_poolIndex + i) % _playersPool.length];
      if (!_busyPoolPlayers.contains(candidate)) {
        _poolIndex = (_poolIndex + i + 1) % _playersPool.length;
        return candidate;
      }
    }
    return null;
  }

  /// One clip at a time. Returns `false` if another exclusive clip is active.
  ///
  /// [onComplete] runs only on natural end — not after [stopAll] / route pop.
  /// Mute or test mode: no audio; [onComplete] still runs so callers can unlock UI.
  ///
  /// D12 (F7): internal-only — no external callers besides [playScreamRoach]
  /// in this file; not part of the public playback API.
  @visibleForTesting
  Future<bool> playExclusiveSfx(
    String assetName, {
    double volume = 1.0,
    double playbackRate = 1.0,
    void Function()? onComplete,
  }) async {
    if (!_canPlayAsset(assetName)) {
      onComplete?.call();
      return true;
    }
    if (_exclusiveBusy) return false;

    final gen = _playGeneration;
    _exclusiveBusy = true;
    _exclusiveOnComplete = onComplete;

    try {
      // 12M dikişi: özel oyuncu da [playerFactory] üzerinden kurulur
      // (varsayılanı `AudioPlayer.new` — üretim davranışı aynen);
      // testte sahte oyuncu ile bitiş (`onComplete`) tetiklenebilir.
      _exclusivePlayer ??= playerFactory()
        ..setReleaseMode(ReleaseMode.stop);
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
      await player.setVolume(volume.clamp(0.0, 1.0));
      await player.setPlaybackRate(playbackRate.clamp(0.7, 1.45));
      if (gen != _playGeneration) {
        _exclusiveBusy = false;
        _exclusiveOnComplete = null;
        return false;
      }
      await player.play(AssetSource(_normalizeAssetPath(assetName)));
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
      onComplete?.call();
      return false;
    }
  }

  /// Plays the viral insect voice for [tier] (1..8+, up to 13+).
  ///
  /// Same resolution as the merge flow ([_resolveMergeVoice]): the tier's
  /// design sound (`tierN_ses.mp3`). Tiers > 13 gracefully clamp to tier 13.
  Future<void> playTierVoice(
    int tier, {
    double volume = 1.0,
    double playbackRate = 1.0,
  }) async {
    if (tier < 1 || !_voiceAudible) return;
    final clampedTier = tier.clamp(1, 13);
    final voiceAsset =
        _resolveMergeVoice(tierNumber: clampedTier) ?? GameAudio.tier8Ses;
    await _playVoiceChannel(
      voiceAsset,
      volume: volume,
      playbackRate: playbackRate,
    );
  }

  /// Plays [assetName] on a FRESH per-play player (Dalga 12K) — never on
  /// the SFX pool and never by stopping another voice.
  ///
  /// Each call creates its own player via [playerFactory]: a new tier
  /// voice starts immediately on top of the previous one, and the old one
  /// finishes on its own ([onPlayerComplete] releases the player). No
  /// pre-play `stop()` anywhere on this path. At most
  /// [_maxConcurrentVoices] tier voices overlap; past the cap the NEW
  /// voice is dropped (the playing ones are never cut). The
  /// [_playGeneration] guard mirrors [playSfx]: an in-flight voice aborts
  /// after [stopAll] / leave-screen (intentional silencing, kept).
  Future<void> _playVoiceChannel(
    String assetName, {
    double volume = 1.0,
    double playbackRate = 1.0,
  }) async {
    if (!_canPlayAsset(assetName, isVoiceOverride: true)) return;
    final gen = _playGeneration;
    AudioPlayer? player;
    try {
      if (_voicePlayers.length >= _maxConcurrentVoices) return;
      final created = playerFactory();
      player = created;
      _voicePlayers.add(created);
      unawaited(created.setReleaseMode(ReleaseMode.stop).catchError((_) {}));
      _voiceCompleteSubs[created] = created.onPlayerComplete.listen(
        (_) => unawaited(_releaseVoicePlayer(created)),
      );
      if (gen != _playGeneration) {
        await _releaseVoicePlayer(created, stopFirst: true);
        return;
      }
      await created.setVolume(volume.clamp(0.0, 1.0));
      await created.setPlaybackRate(playbackRate.clamp(0.7, 1.45));
      if (gen != _playGeneration) {
        await _releaseVoicePlayer(created, stopFirst: true);
        return;
      }
      await created.play(AssetSource(_normalizeAssetPath(assetName)));
      if (gen != _playGeneration) {
        await _releaseVoicePlayer(created, stopFirst: true);
      }
    } catch (_) {
      // Kurulamadı/yarıda kesildi: oyuncu bırakılır — küme daralmasın.
      if (player != null) {
        await _releaseVoicePlayer(player);
      }
      // Graceful fallback for headless / test / platform audio constraints
    }
  }

  /// Suika birleşme karakter sesini sıralı kuyruğa ekler (yalnız Suika
  /// birleşme akışı — diğer modlar [playMerge]/[playSfx] yolunu kullanır).
  ///
  /// [onStart] öğe çalmaya BAŞLARKEN çağrılır (Suika ekranı replik
  /// yazısını bununla yazar). Kuyruk doluysa ([_maxSuikaVoicePending]
  /// bekleyen) en eski BEKLEYEN düşer — çalan asla kesilmez, en yeni
  /// korunur. Ses kapalıysa öğe sessizce [_suikaVoiceMutedHold] bekler,
  /// sonra sıra bir sonrakine geçer.
  void enqueueSuikaVoice(String assetName, {void Function()? onStart}) {
    if (_suikaVoiceQueue.length >= _maxSuikaVoicePending) {
      _suikaVoiceQueue.removeAt(0);
    }
    _suikaVoiceQueue.add(_SuikaVoiceJob(assetName, onStart));
    _pumpSuikaVoiceQueue();
  }

  /// Suika birleşmesi (kuyruklu): chime/kombo SFX anında çalar
  /// (karakter sesi değil, birleşme anıyla eşzamanlı kalır), tier/Hışır
  /// karakter sesi sıralı kuyruğa girer — bir ses bitmeden yenisi
  /// başlamaz. [onVoiceStart] kuyruktaki ses çalmaya başlarken çağrılır
  /// (Suika ekranı replik yazısını bununla yazar).
  ///
  /// [playMerge]/[playMergeHisir] aynen durur (diğer modlar + eski
  /// davranış); yalnız Suika ekranı bu yöntemi çağırır.
  Future<void> playMergeQueued({
    InsectTier? tier,
    int? tierNumber,
    int comboCount = 1,
    bool hisirInvolved = false,
    void Function()? onVoiceStart,
  }) async {
    final resolvedTier = (tier?.tier ?? tierNumber ?? 1).clamp(1, 13);
    if (vibrationEnabled) {
      unawaited(
        HapticService.instance.onMerge(tier: resolvedTier, combo: comboCount),
      );
    }
    final plays = <Future<void>>[
      if (_sfxEnabled) playSfx(GameAudio.sfxMergeChime, isVoice: false),
    ];
    if (_sfxEnabled && comboCount > 1) {
      plays.add(playSfx(GameAudio.sfxCombo, volume: 0.85, isVoice: false));
    }
    final voiceAsset = hisirInvolved
        ? (GameAudio.voiceForCharacterId('hisir') ?? GameAudio.hisirZopa)
        : _resolveMergeVoice(tier: tier, tierNumber: tierNumber);
    if (voiceAsset != null) {
      enqueueSuikaVoice(voiceAsset, onStart: onVoiceStart);
    }
    if (plays.isNotEmpty) {
      await Future.wait(plays);
    }
  }

  /// Suika replik kuyruğunu boşaltır (yeni tur / ekran değişimi):
  /// bekleyenler düşer, çalan susturulur, bant temizliği için
  /// [onSuikaVoiceQueueDrained] çağrılır. SFX havuzuna dokunmaz.
  void clearSuikaVoiceQueue() {
    _suikaVoiceGen++;
    _suikaVoiceQueue.clear();
    _suikaVoiceBusy = false;
    final player = _suikaVoicePlayer;
    if (player != null) {
      unawaited(player.stop().catchError((_) {}));
    }
    onSuikaVoiceQueueDrained?.call();
  }

  void _pumpSuikaVoiceQueue() {
    if (_suikaVoiceBusy || _suikaVoiceQueue.isEmpty) return;
    final job = _suikaVoiceQueue.removeAt(0);
    _suikaVoiceBusy = true;
    unawaited(_runSuikaVoiceJob(job));
  }

  Future<void> _runSuikaVoiceJob(_SuikaVoiceJob job) async {
    final gen = _suikaVoiceGen;
    try {
      job.onStart?.call();
      if (_canPlayAsset(job.assetName, isVoiceOverride: true)) {
        await _playSuikaVoiceClip(job.assetName, gen);
      } else {
        await Future<void>.delayed(_suikaVoiceMutedHold);
      }
    } catch (_) {
      // Bir öğedeki hata kuyruğu tıkamaz — sıra bir sonrakine geçer.
    } finally {
      if (gen == _suikaVoiceGen) {
        _suikaVoiceBusy = false;
        if (_suikaVoiceQueue.isEmpty) {
          onSuikaVoiceQueueDrained?.call();
        }
        _pumpSuikaVoiceQueue();
      }
      // Kuşak değiştiyse (stopAll/clear/dispose): bu iş artık sahipsiz —
      // busy bayrağı ve pompa güncel kuşağa aittir, dokunulmaz. Eski
      // işin finally'si bayrağı sıfırlasaydı, o sırada çalan yeni
      // kuşağın sesi varken ikinci bir ses başlayabilirdi.
    }
  }

  /// Tek kuyruk klibini adanmış oyuncuda çalar; doğal bitişte (veya
  /// 10 sn güvenlik zaman aşımında) döner. Kuşak değişmişse
  /// ([stopAll]/[clearSuikaVoiceQueue]/[dispose]) erken döner.
  Future<void> _playSuikaVoiceClip(String assetName, int gen) async {
    final player = _suikaVoicePlayer ??= _createSuikaVoicePlayer();
    final completer = Completer<void>();
    late final StreamSubscription<void> sub;
    Timer? watchdog;
    void finish() {
      watchdog?.cancel();
      unawaited(sub.cancel().catchError((_) {}));
      if (!completer.isCompleted) completer.complete();
    }

    sub = player.onPlayerComplete.listen((_) => finish());
    watchdog = Timer(_suikaVoiceMaxClip, finish);
    try {
      await player.setVolume(1.0);
      await player.setPlaybackRate(1.0);
      if (gen != _suikaVoiceGen) {
        finish();
        return;
      }
      await player.play(AssetSource(_normalizeAssetPath(assetName)));
      if (gen != _suikaVoiceGen) {
        // Kuşak değişti: oyuncu stopAll/clear ile zaten susturuldu ya da
        // yeni kuşağın klibi çalıyor — buradaki stop() yeni klibi keserdi.
        finish();
        return;
      }
      await completer.future;
    } catch (_) {
      finish();
    }
  }

  AudioPlayer _createSuikaVoicePlayer() {
    final created = playerFactory();
    unawaited(created.setReleaseMode(ReleaseMode.stop).catchError((_) {}));
    return created;
  }

  /// Merge juice: merge SFX (+ optional combo) together with the new tier's
  /// design sound ([_resolveMergeVoice]).
  ///
  /// Prefer [tier]; else [tierNumber] 1–13 resolves the same way.
  Future<void> playMerge({
    InsectTier? tier,
    int? tierNumber,
    int comboCount = 1,
  }) async {
    final resolvedTier = (tier?.tier ?? tierNumber ?? 1).clamp(1, 13);
    if (vibrationEnabled) {
      unawaited(
        HapticService.instance.onMerge(tier: resolvedTier, combo: comboCount),
      );
    }
    final voiceAsset = _resolveMergeVoice(tier: tier, tierNumber: tierNumber);
    final plays = <Future<void>>[
      if (_sfxEnabled) playSfx(GameAudio.sfxMergeChime, isVoice: false),
    ];
    if (_sfxEnabled && comboCount > 1) {
      plays.add(playSfx(GameAudio.sfxCombo, volume: 0.85, isVoice: false));
    }
    if (_voiceAudible && voiceAsset != null) {
      // Tier sesi havuza değil çalma başına oyuncuya (Dalga 12K):
      // chime/combo onu kesemez, yeni birleşme eskisinin üstüne başlar,
      // eski ses kendi bitirir.
      plays.add(_playVoiceChannel(voiceAsset));
    }
    if (plays.isNotEmpty) {
      await Future.wait(plays);
    }
  }

  /// Hışır birleşme/patlama sesi: birleşme chime'ı (+ kombo SFX) ile
  /// Hışır'ın onaylı sesi (`hisir_zopa.mp3`) birlikte çalar.
  ///
  /// [playMerge] buradan çağrılmaz: o, kademe sesini çalma başına
  /// oyuncuya yazar (Dalga 12K). Hışır sesi tek yoldan
  /// ([playHusurAday]) havuzdan çalar — 12K düzeninde hiçbir çalma
  /// başka çalmayı durdurmadığı için Hışır klibi kesilmeden tam çalar.
  /// Skor/kademe bu seste taşınmaz; çağıran skor hesabını aynen korur.
  Future<void> playMergeHisir({
    int? tierNumber,
    int comboCount = 1,
  }) async {
    final resolvedTier = (tierNumber ?? 1).clamp(1, 13);
    if (vibrationEnabled) {
      unawaited(
        HapticService.instance.onMerge(tier: resolvedTier, combo: comboCount),
      );
    }
    final plays = <Future<void>>[
      if (_sfxEnabled) playSfx(GameAudio.sfxMergeChime, isVoice: false),
    ];
    if (_sfxEnabled && comboCount > 1) {
      plays.add(playSfx(GameAudio.sfxCombo, volume: 0.85, isVoice: false));
    }
    if (_voiceAudible) {
      plays.add(playHusurAday());
    }
    if (plays.isNotEmpty) {
      await Future.wait(plays);
    }
  }

  /// Prototype alias for merge sound effects (`playMergeSfx`).
  @Deprecated(
    'D12 (F7): dead alias with no external callers; use playMerge instead.',
  )
  Future<void> playMergeSfx({
    int? tier,
    InsectTier? insectTier,
    int comboCount = 1,
  }) =>
      playMerge(
        tier: insectTier,
        tierNumber: tier,
        comboCount: comboCount,
      );

  /// Resolves the sound for a merge/tier event: the tier's design sound
  /// (`InsectTier.soundFile`, `tierN_ses.mp3`) — the single canonical
  /// tier-voice set since 12A deleted the byte-identical `voice_tierN.mp3`
  /// duplicates. All names stay bare filenames — [_normalizeAssetPath]
  /// joins them.
  String? _resolveMergeVoice({InsectTier? tier, int? tierNumber}) {
    if (tier != null) {
      if (GameAudio.allAssets.contains(tier.soundFile)) {
        return tier.soundFile;
      }
      return null;
    }
    if (tierNumber != null && tierNumber >= 1) {
      final clamped = tierNumber.clamp(1, 13);
      final design = GameAudio.designSoundForTier(clamped);
      if (design != null && GameAudio.allAssets.contains(design)) {
        return design;
      }
      return null;
    }
    return null;
  }

  Future<void> playDrop() {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.lightImpact());
    }
    return playSfx(GameAudio.sfxDrop, isVoice: false);
  }

  /// Prototype alias for drop sound effect (`playDropSfx`).
  @Deprecated(
    'D12 (F7): dead alias with no external callers; use playDrop instead.',
  )
  Future<void> playDropSfx() => playDrop();

  Future<void> playWin() => playVictorySfx();

  /// Celebratory victory sound + Hasta Bilge / Lülülü victory voice.
  Future<void> playVictorySfx({bool includeVoice = true}) async {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.onLevelComplete());
    }
    final plays = <Future<void>>[
      if (_sfxEnabled) playSfx(GameAudio.sfxVictory, isVoice: false),
      if (includeVoice && _voiceAudible)
        playSfx(GameAudio.tier8Ses, isVoice: true),
    ];
    if (plays.isNotEmpty) {
      await Future.wait(plays);
    }
  }

  Future<void> playLose() {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.onGameOver());
    }
    return playSfx(GameAudio.sfxGameOver, isVoice: false);
  }

  Future<void> playPop() {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.lightImpact());
    }
    return playSfx(GameAudio.sfxPop, isVoice: false);
  }

  /// UI button tap feedback (`playButtonTap`).
  Future<void> playButtonTap() {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.selectionClick());
    }
    return playSfx(GameAudio.sfxButtonTap, isVoice: false);
  }

  /// D12 (F7): dead method with no external callers. `voice_aydinlat.mp3`
  /// still plays through `playF16Sfx(includeVoice: true)`.
  @Deprecated(
    'D12 (F7): dead method with no external callers; voice_aydinlat plays via playF16Sfx.',
  )
  Future<void> playAydinlatVoice() =>
      playSfx(GameAudio.voiceAydinlat, isVoice: true);

  /// Viral one-shot: "mezarına sıçtığım" (TikTok video4 kesimi).
  Future<void> playMezarinaSiktigim() =>
      playSfx(GameAudio.mezarinaSiktigim, isVoice: true);

  /// Viral one-shot: Diva "sinyal" repliği (TikTok 7697726382641614100).
  Future<void> playDivaSinyal() =>
      playSfx(GameAudio.divaSinyal, isVoice: true);

  /// Viral one-shot: Diva "yasla" repliği (TikTok 7697726382641614100).
  Future<void> playDivaYasla() => playSfx(GameAudio.divaYasla, isVoice: true);

  /// Viral one-shot: Lülülü nakaratı (TikTok video3 kesimi).
  Future<void> playLululuNakarat() =>
      playSfx(GameAudio.lululuNakarat, isVoice: true);

  /// Viral one-shot: Duktur repliği (TikTok video2 kesimi).
  Future<void> playDuktur() => playSfx(GameAudio.duktur, isVoice: true);

  /// Viral one-shot: Kanka ikilisi (TikTok video5 kesimi).
  Future<void> playKanka() => playSfx(GameAudio.kanka, isVoice: true);

  /// Hışır'ın sesi — tek Hışır ses yolu. Onaylı klip `hisir_zopa.mp3`
  /// (Selçuk kulakla onayladı, 2026-11-19; bkz. assets/audio/ASSETS_NOTE.md).
  ///
  /// Resolves through [GameAudio.voiceForCharacterId] (`'hisir'`), the same
  /// map Terlik Tap uses via [playSlipperSmash]; the [GameAudio.hisirZopa]
  /// constant is only the fallback if the map ever drops the id. The clip
  /// stays preloaded via [GameAudio.viralOneShots] / [GameAudio.allAssets].
  Future<void> playHusurAday() async {
    final asset =
        GameAudio.voiceForCharacterId('hisir') ?? GameAudio.hisirZopa;
    await playSfx(asset, isVoice: true);
  }

  Future<void> playAydinlatBeam() {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.heavyImpact());
    }
    return playSfx(GameAudio.sfxAydinlatBeam, isVoice: false);
  }

  /// Prototype F16 bombardment / "Aydınlat Hele!" jet roar + explosion + voice.
  Future<void> playF16Sfx({bool includeVoice = true}) async {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.onF16Bombardment());
    }
    final plays = <Future<void>>[
      if (_sfxEnabled) playSfx(GameAudio.sfxF16, isVoice: false),
      if (_sfxEnabled)
        playSfx(GameAudio.sfxAydinlatBeam, volume: 0.85, isVoice: false),
      if (includeVoice && _voiceAudible)
        playSfx(GameAudio.voiceAydinlat, isVoice: true),
    ];
    if (plays.isNotEmpty) {
      await Future.wait(plays);
    }
  }

  Future<void> playSlipper() {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.onSlipperSlap());
    }
    return playSfx(GameAudio.sfxSlipper, isVoice: false);
  }

  /// Prototype alias for slipper slap (`playSlapSfx`).
  @Deprecated(
    'D12 (F7): dead alias with no external callers; use playSlipperSmash or playSlipper instead.',
  )
  Future<void> playSlapSfx({
    String? characterId,
    InsectTier? tier,
    int comboCount = 1,
  }) {
    if (characterId != null || tier != null) {
      return playSlipperSmash(
        characterId: characterId,
        tier: tier,
        comboCount: comboCount,
      );
    }
    return playSlipper();
  }

  /// Terlik tap smash: slipper SFX + that character's voice (not a generic merge).
  ///
  /// Resolve order: [characterId] map → [tier] voice → pop fallback + log.
  /// `'hisir'` plays through [playHusurAday], the single Hışır voice path.
  Future<void> playSlipperSmash({
    String? characterId,
    InsectTier? tier,
    int comboCount = 1,
  }) async {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.onSlipperSlap(combo: comboCount));
    }
    final plays = <Future<void>>[
      if (_sfxEnabled) playSfx(GameAudio.sfxSlipper, isVoice: false),
    ];

    String? voice;
    if (characterId != null && characterId.isNotEmpty) {
      voice = GameAudio.voiceForCharacterId(characterId);
    }
    voice ??= _resolveMergeVoice(tier: tier, tierNumber: tier?.tier);

    if (characterId == 'hisir') {
      // Single Hışır voice path: resolve + play via [playHusurAday] so the
      // 'hisir' mapping lives in exactly one place.
      if (_voiceAudible) {
        plays.add(playHusurAday());
      }
    } else if (voice != null) {
      if (_voiceAudible) {
        plays.add(playSfx(voice, isVoice: true));
      }
    } else if (_sfxEnabled) {
      debugPrint(
        '[Audio] slipper smash missing voice '
        'id=$characterId tier=${tier?.tier} — fallback pop',
      );
      plays.add(playSfx(GameAudio.sfxPop, volume: 0.7, isVoice: false));
    }

    if (_sfxEnabled && comboCount >= 3) {
      plays.add(playSfx(GameAudio.sfxCombo, volume: 0.85, isVoice: false));
    }
    if (plays.isNotEmpty) {
      await Future.wait(plays);
    }
  }

  Future<void> playSpray() {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.onRaidSpray());
    }
    return playSfx(GameAudio.sfxSpray, isVoice: false);
  }

  /// Prototype alias for Raid spray (`playSpraySfx`).
  @Deprecated(
    'D12 (F7): dead alias with no external callers; use playSpray instead.',
  )
  Future<void> playSpraySfx() => playSpray();

  /// Çığlık Böcek mode scream audio (`playScreamRoach`).
  Future<bool> playScreamRoach({
    InsectTier? bug,
    int? tier,
    double power = 1.0,
    double? playbackRate,
    void Function()? onComplete,
  }) {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.onScreamRoach(power: power));
    }
    final asset = bug?.soundFile ??
        (tier != null
            ? GameAudio.designSoundForTier(tier.clamp(1, 13))
            : null) ??
        GameAudio.sfxScreamRoach;
    final volume = (0.82 + power.clamp(0.0, 1.0) * 0.18).clamp(0.0, 1.0);
    final rate = (playbackRate ?? (0.92 + power.clamp(0.0, 1.0) * 0.22))
        .clamp(0.7, 1.45);
    return playExclusiveSfx(
      asset,
      volume: volume,
      playbackRate: rate,
      onComplete: onComplete,
    );
  }

  /// Osmantuş mode rhythmic green-ring beat hit + duo voice (`playOsmantusBeat`).
  Future<void> playOsmantusBeat({
    bool isPersonB = false,
    bool perfect = false,
    int comboCount = 1,
    bool includeVoice = true,
  }) async {
    if (vibrationEnabled) {
      unawaited(
        HapticService.instance.onOsmantusBeat(
          perfect: perfect,
          combo: comboCount,
        ),
      );
    }
    final plays = <Future<void>>[
      if (_sfxEnabled)
        playSfx(
          GameAudio.sfxOsmantusBeat,
          volume: perfect ? 1.0 : 0.85,
          playbackRate: perfect ? 1.08 : 1.0,
          isVoice: false,
        ),
    ];
    if (includeVoice && _voiceAudible) {
      final voice = isPersonB ? GameAudio.voiceOsmanB : GameAudio.voiceOsmanA;
      plays.add(playSfx(voice, volume: 0.9, isVoice: true));
    }
    if (_sfxEnabled && comboCount >= 3) {
      plays.add(playSfx(GameAudio.sfxCombo, volume: 0.8, isVoice: false));
    }
    if (plays.isNotEmpty) {
      await Future.wait(plays);
    }
  }

  /// Makarayız mode reel spin & lane beat hit (`playMakaraSpin`).
  Future<void> playMakaraSpin({
    int? tier,
    InsectTier? bug,
    int comboCount = 1,
    double playbackRate = 1.0,
  }) async {
    if (vibrationEnabled) {
      unawaited(HapticService.instance.onMakaraSpin(combo: comboCount));
    }
    final plays = <Future<void>>[
      if (_sfxEnabled)
        playSfx(
          GameAudio.sfxMakaraSpin,
          volume: 0.9,
          playbackRate: playbackRate,
          isVoice: false,
        ),
    ];
    final voice = bug?.soundFile ??
        (tier != null
            ? GameAudio.designSoundForTier(tier.clamp(1, 13))
            : null);
    if (voice != null && _voiceAudible) {
      plays.add(
        playSfx(
          voice,
          playbackRate: playbackRate,
          isVoice: true,
        ),
      );
    }
    if (_sfxEnabled && comboCount >= 3) {
      plays.add(playSfx(GameAudio.sfxCombo, volume: 0.85, isVoice: false));
    }
    if (plays.isNotEmpty) {
      await Future.wait(plays);
    }
  }

  /// Light impact — drop / soft feedback.
  @Deprecated(
    'D12 (F7): no external callers; use triggerHaptic instead.',
  )
  void triggerLightHaptic() {
    if (!vibrationEnabled ||
        !ProgressManager.instance.vibrationEnabled ||
        _isTestEnvironment) {
      return;
    }
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium impact — standard merge feedback.
  void triggerMediumHaptic() {
    if (!vibrationEnabled ||
        !ProgressManager.instance.vibrationEnabled ||
        _isTestEnvironment) {
      return;
    }
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact — high combo / big merge.
  void triggerHeavyHaptic() {
    if (!vibrationEnabled ||
        !ProgressManager.instance.vibrationEnabled ||
        _isTestEnvironment) {
      return;
    }
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Alias for [triggerLightHaptic] (existing call sites).
  void triggerHaptic() => triggerLightHaptic();

  /// Releases the pooled players and the exclusive player, cancels the
  /// completion subscription, and unbinds the [ProgressManager] listeners
  /// (S2#8: listener registration and removal are now symmetric — see
  /// [_bindProgressManagerListeners] / [_unbindProgressManagerListeners]).
  ///
  /// Idempotent and re-initializable: calling [initialize] afterwards
  /// rebinds the listeners and rebuilds the pool. Safe to call when never
  /// initialized. Channel preferences ([sfxEnabled],
  /// [voiceEnabled], [vibrationEnabled]) and [isMuted] are intentionally
  /// left untouched so a later [initialize] resumes the same mix.
  ///
  /// NOTE (S2#8, wiring — for the agent that owns app teardown): nothing
  /// in `lib/` calls this yet; `main.dart` calls only
  /// `AudioManager().initialize()`. App teardown should call
  /// `AudioManager.instance.dispose()` (e.g. from the root widget's
  /// dispose / app-detach path). Do NOT call it from per-screen dispose —
  /// screens use [stopAll]; the singleton pool is shared across screens.
  void dispose() {
    _unbindProgressManagerListeners();
    _syncingWithProgress = false;
    _playGeneration++;
    _suikaVoiceGen++;
    _suikaVoiceQueue.clear();
    _suikaVoiceBusy = false;
    onSuikaVoiceQueueDrained = null;
    final suikaPlayer = _suikaVoicePlayer;
    _suikaVoicePlayer = null;
    try {
      suikaPlayer?.dispose();
    } catch (_) {}
    _poolIndex = 0;
    _exclusiveBusy = false;
    _exclusiveOnComplete = null;
    unawaited(_exclusiveCompleteSub?.cancel() ?? Future<void>.value());
    _exclusiveCompleteSub = null;
    final exclusive = _exclusivePlayer;
    _exclusivePlayer = null;
    try {
      exclusive?.dispose();
    } catch (_) {}
    for (final sub in _voiceCompleteSubs.values) {
      unawaited(sub.cancel().catchError((_) {}));
    }
    _voiceCompleteSubs.clear();
    final voices = _voicePlayers.toList();
    _voicePlayers.clear();
    for (final voice in voices) {
      try {
        voice.dispose();
      } catch (_) {}
    }
    for (final sub in _poolCompleteSubs) {
      unawaited(sub.cancel().catchError((_) {}));
    }
    _poolCompleteSubs.clear();
    _busyPoolPlayers.clear();
    for (final p in _playersPool) {
      try {
        p.dispose();
      } catch (_) {}
    }
    _playersPool.clear();
    _initialized = false;
  }
}
