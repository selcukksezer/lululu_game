// Dalga 12M — Hışır 11 modda böcek.
//
// Kapsam:
//   (a) HisirCharacter: zar / ızgara kodlaması / görsel seçimi.
//   (b) Fizik motoru: Hışır gövde birleşir, olay bayrağı taşınır,
//       doğan üst kademe Hışır değildir, kademe/skor aynen kalır.
//   (c) Ses (12K düzeni, mock'lu): playMergeHisir chime + hisir_zopa
//       çalar, hiçbir çalmayı durdurmaz; ardından gelen tier sesi de
//       Hışır klibini kesmez.
//   (d) Widget: debugForceHisir ile 11 modun tamamında Hışır görseli
//       ağaçta belirir.
//
// NOT: ses testte kapalıdır, Playwright sesi duyamaz — (c) 12K testinin
// mock oyuncu dikişini (playerFactory + forcePlaybackForTesting) kullanır.
import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/models/hisir_character.dart';
import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/modes/yuva_defense_screen.dart';
import 'package:lululu_game/physics/physics_engine.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

/// Sahte oyuncu (12K testindeki dikişin aynısı): hangi asset'in hangi
/// oyuncuda çaldığını + `stop()` çağrılarını kaydeder.
class _FakeAudioPlayer extends AudioPlayer {
  _FakeAudioPlayer(this.id, this.log);

  final String id;
  final List<String> log;

  String? currentAsset;
  int stopCalls = 0;

  StreamController<void>? _completeController;

  @override
  Stream<void> get onPlayerComplete =>
      (_completeController ??= StreamController<void>.broadcast()).stream;

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
    currentAsset = asset;
  }

  @override
  Future<void> dispose() async {}
}

/// Hışır görselini taşıyan bir Image (StickerImage da Image kurar).
Finder _hisirImage() => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is AssetImage &&
      (w.image as AssetImage).assetName == HisirCharacter.assetPath,
);

Future<void> _pumpMode(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(374, 680),
  ThemeData? theme,
  bool textScaler85 = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  // 6D deseni: test sırasındaki tembel GoogleFonts yüklemeleri motorun
  // `fontsChange` bildirimi göndermesine yol açar; bildirim gövdenin son
  // pump'ından sonra gelirse bıraktığı transient frame callback'i
  // `postTest` denetimine takılır ("animation is still running").
  // Üretim kodu hatası değildir.
  addTearDown(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
      await binding.pump();
    }
  });
  await tester.pumpWidget(
    wrapWithL10n(
      child,
      theme: theme,
      // wrapPlayable kalıbı (grid_2048 testi): üretim 0.85 metin
      // ölçeği; verilmezse HUD satırları test görünümünde taşar.
      builder: textScaler85
          ? (context, c) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(0.85)),
              child: c ?? const SizedBox.shrink(),
            )
          : null,
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// Test sonu: ekranı kaldır (ticker/zamanlayıcı temiz kapansın), sonra
/// istisna denetimi. Mevcut oynanış testlerinin kapanış kalıbı.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HisirCharacter — zar ve ızgara kodlaması', () {
    setUp(() => HisirCharacter.debugForceHisir = false);
    tearDown(() => HisirCharacter.debugForceHisir = false);

    test('sabitler: %5 genel, Terlik %8 aynen', () {
      expect(HisirCharacter.spawnChance, 0.05);
      expect(HisirCharacter.terlikSpawnChance, 0.08);
      expect(HisirCharacter.id, 'hisir');
      expect(HisirCharacter.assetPath, 'assets/design/bugs_hd/hisir_hd.png');
    });

    test('roll: zorlama açıkken hep true, kapalıyken tohumlu zar', () {
      HisirCharacter.debugForceHisir = true;
      expect(HisirCharacter.roll(Random(1)), isTrue);
      HisirCharacter.debugForceHisir = false;
      expect(HisirCharacter.roll(Random(7), chance: 1.0), isTrue);
      expect(HisirCharacter.roll(Random(7), chance: 0.0), isFalse);
      final seeded = Random(7).nextDouble() < 0.05;
      expect(HisirCharacter.roll(Random(7)), seeded);
    });

    test('ızgara kodlaması: kademe korunur, çakışma yok', () {
      HisirCharacter.debugForceHisir = true;
      for (var tier = 1; tier <= 13; tier++) {
        final encoded = HisirCharacter.encodeGridValue(tier, Random());
        expect(encoded, tier + 100);
        expect(HisirCharacter.isEncoded(encoded), isTrue);
        expect(HisirCharacter.baseTier(encoded), tier);
      }
      for (var tier = 1; tier <= 13; tier++) {
        expect(HisirCharacter.isEncoded(tier), isFalse);
        expect(HisirCharacter.baseTier(tier), tier);
      }
      expect(
        HisirCharacter.assetFor(isHisir: true, tier: InsectTier.cone),
        HisirCharacter.assetPath,
      );
      expect(
        HisirCharacter.assetFor(isHisir: false, tier: InsectTier.cone),
        InsectTier.cone.assetPath,
      );
    });
  });

  group('Fizik motoru — Hışır birleşmesi', () {
    CircularPhysicsEngine squareEngine() => CircularPhysicsEngine(
      arenaCenter: const Offset(300, 300),
      arenaRadius: 300,
      arenaWidth: 600,
      arenaHeight: 600,
      squareArena: true,
    );

    test('Hışır + aynı kademe birleşir, bayrak taşınır, doğan düz kademe', () {
      final engine = squareEngine();
      engine.addBody(InsectTier.cone, 300, 300, isHisir: true);
      engine.addBody(InsectTier.cone, 300, 300);

      final events = engine.update(1 / 120);

      expect(events, hasLength(1));
      expect(events.single.tier, InsectTier.helmet);
      expect(events.single.hisirInvolved, isTrue);
      expect(engine.bodies, hasLength(1));
      expect(engine.bodies.single.tier, InsectTier.helmet);
      // Doğan üst kademe Hışır değildir (13 tier zinciri bozulmaz).
      expect(engine.bodies.single.isHisir, isFalse);
    });

    test('Hışırsız birleşmede bayrak false', () {
      final engine = squareEngine();
      engine.addBody(InsectTier.cone, 300, 300);
      engine.addBody(InsectTier.cone, 300, 300);

      final events = engine.update(1 / 120);

      expect(events, hasLength(1));
      expect(events.single.tier, InsectTier.helmet);
      expect(events.single.hisirInvolved, isFalse);
    });
  });

  group('Ses — playMergeHisir, 12K düzeni (mock oyuncu)', () {
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
    });

    tearDown(() {
      final audio = AudioManager();
      audio.dispose();
      audio.forcePlaybackForTesting = false;
    });

    test('hisir kimliği hisir_zopa.mp3 çözer', () {
      expect(GameAudio.voiceForCharacterId('hisir'), 'hisir_zopa.mp3');
      expect(GameAudio.hisirZopa, 'hisir_zopa.mp3');
    });

    test('playHusurAday hisir_zopa çalar, hiçbir şeyi durdurmaz', () async {
      final audio = AudioManager();
      await audio.playHusurAday();

      expect(log.any((e) => e.contains('hisir_zopa.mp3')), isTrue);
      expect(log.any((e) => e.startsWith('stop:')), isFalse);
    });

    test('playMergeHisir: chime + hisir_zopa, durduran yok', () async {
      final audio = AudioManager();
      await audio.playMergeHisir(tierNumber: 3, comboCount: 2);

      expect(log.any((e) => e.contains(GameAudio.sfxMergeChime)), isTrue);
      expect(log.any((e) => e.contains(GameAudio.sfxCombo)), isTrue);
      expect(log.any((e) => e.contains('hisir_zopa.mp3')), isTrue);
      expect(log.any((e) => e.startsWith('stop:')), isFalse);
    });

    test('playMergeHisir sonrası tier sesi Hışır klibini kesmez (12K)', () async {
      final audio = AudioManager();
      await audio.playMergeHisir(tierNumber: 3);
      await audio.playMerge(tierNumber: 4, comboCount: 1);

      expect(log.any((e) => e.startsWith('stop:')), isFalse);
      final playing = created
          .where((p) => p.currentAsset != null)
          .map((p) => p.currentAsset!)
          .toList();
      expect(playing, contains('audio/hisir_zopa.mp3'));
      expect(
        playing,
        contains('audio/${GameAudio.designSoundForTier(4)}'),
      );
    });
  });

  group('Widget — 11 modda Hışır belirir (debugForceHisir)', () {
    setUp(() {
      HisirCharacter.debugForceHisir = true;
      AudioManager().isMuted = true;
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
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

    tearDown(() {
      HisirCharacter.debugForceHisir = false;
    });

    testWidgets('2048: ilk taşlar Hışır', (tester) async {
      await _pumpMode(
        tester,
        const Grid2048Screen(),
        size: const Size(430, 932),
        theme: buildLululuTheme(),
        textScaler85: true,
      );
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Match3: ilk dağıtımda Hışır hücreleri', (tester) async {
      await _pumpMode(tester, const Match3Screen());
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Link Pop: ilk dolumda Hışır hücreleri', (tester) async {
      await _pumpMode(tester, const ConnectPopScreen());
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Balloon Pop: ilk ızgarada Hışır balonları', (tester) async {
      await _pumpMode(tester, const BalloonPopScreen());
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Suika: sıradaki önizlemede Hışır', (tester) async {
      tester.view.physicalSize = const Size(374, 680);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        wrapWithL10n(
          GameScreen(level: CampaignDatabase.kitchenLevel1, arcade: true),
          debugShowCheckedModeBanner: false,
          theme: buildLululuTheme(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Stack Drop: yerleşen dilim Hışır olur', (tester) async {
      await _pumpMode(
        tester,
        const StackDropScreen(),
        theme: buildLululuTheme(),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.text('?'));
      await tester.pump();
      await tester.tap(find.text('ANLADIM'));
      await tester.pump();
      // İlk dilimi yerleştir: yeni dilim zarı Hışır verir.
      await tester.tapAt(const Offset(187, 350));
      for (var i = 0; i < 32; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Yuva: doğan savunma böceği Hışır', (tester) async {
      await _pumpMode(tester, const YuvaDefenseScreen());
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (_hisirImage().evaluate().isNotEmpty) break;
      }
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Scream Bug: çığlık sonrası böcek Hışır', (tester) async {
      // İlk böcek helmet'tır; Hışır sıradaki böcektir ve yalnız ses
      // bitişinde (`_onVoiceComplete`) gelir. Testte ses bitmez —
      // sahte oyuncu ile bitiş tetiklenir (12K dikişi).
      final created = <_FakeAudioPlayer>[];
      final audioLog = <String>[];
      final audio = AudioManager();
      audio.dispose();
      audio.playerFactory = () {
        final fake = _FakeAudioPlayer('p${created.length}', audioLog);
        created.add(fake);
        return fake;
      };
      audio.forcePlaybackForTesting = true;
      audio.isMuted = false;
      audio.sfxEnabled = true;
      audio.voiceEnabled = true;
      audio.vibrationEnabled = false;
      audio.initialize();
      addTearDown(() {
        audio.dispose();
        audio.forcePlaybackForTesting = false;
        audio.initialize();
      });
      await _pumpMode(tester, const ScreamRoachScreen());
      await tester.tapAt(const Offset(187, 400));
      await tester.pump(const Duration(milliseconds: 200));
      for (final fake in created.where((p) => p.currentAsset != null)) {
        fake.complete();
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Makarayız: akan notalarda Hışır', (tester) async {
      await _pumpMode(tester, const MakarayizScreen());
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        if (_hisirImage().evaluate().isNotEmpty) break;
      }
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Osmantus: Hışır vuruşunda figür Hışır', (tester) async {
      var nowMs = 0;
      tester.view.physicalSize = const Size(374, 680);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      addTearDown(() async {
        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
          await binding.pump();
        }
      });
      await tester.pumpWidget(
        wrapWithL10n(
          OsmantusScreen(clockForTesting: () => nowMs),
          theme: buildLululuTheme(),
        ),
      );
      await tester.pump();
      // Öğretici 15 sn: sahte saati ileri al, vuruşlar Hışır'a döner.
      nowMs = 20000;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        nowMs += 2000;
        if (_hisirImage().evaluate().isNotEmpty) break;
      }
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });

    testWidgets('Terlik Tap: doğan hedef Hışır', (tester) async {
      await _pumpMode(
        tester,
        const TerlikTapScreen(initialTargetForTesting: true),
        size: const Size(430, 932),
        theme: buildLululuTheme(),
        textScaler85: true,
      );
      expect(_hisirImage(), findsWidgets);
      await _finish(tester);
    });
  });
}
