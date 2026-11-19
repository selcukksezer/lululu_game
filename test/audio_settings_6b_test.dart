import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/screens/settings_screen.dart';
import 'package:lululu_game/services/achievement_pass_service.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/haptic_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/achievement_toast_overlay.dart';
import 'package:lululu_game/widgets/shop_dialog.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

// Dalga 6B (Faz 3): ses denetimi düzeltmeleri D2/D3/D6/D7/D12/D13-doc.
//
// NOT (ses gözlemlenebilirliği): `AudioManager._canPlayAsset` test
// ortamında her zaman `false` döner, yani `playWin`/`playPop` testlerde
// sessiz no-op'tur. D6/D7 için davranış testleri, sesi içeren DALIN
// çalıştığını (başarı toast'ı / coin hareketi / banner görünümü)
// kanıtlar; ses satırının o dalda durduğunu ise aşağıdaki yapısal
// (kaynak okuyan) testler kilitler. İkisi birlikte kanıttır; tek
// başına hiçbiri "ses duyuldu" iddiasında bulunmaz.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SemanticsHandle semanticsHandle;
  late dynamic prevOnError;

  setUpAll(() async {
    await loadAppFonts();
    await loadTestFonts();
    semanticsHandle = TestWidgetsFlutterBinding.instance.ensureSemantics();
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
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  tearDownAll(() {
    semanticsHandle.dispose();
  });

  setUp(() async {
    // Eksik görsel yükleme hataları (shop_confirm_test ile aynı koruma).
    prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('Unable to load asset')) {
        return;
      }
      prevOnError?.call(details);
    };
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Kalıcı yazım YAPMADAN bayrak sıfırlama: AudioManager setter'ları
    // SharedPreferences'a yazdığı için burada kullanılmaz; yoksa
    // "geri-yazma yok" iddiası kurulumun kendi yazımıyla kirlenirdi.
    // ProgressManager bildirimcileri üzerinden ayna (AudioManager'ın
    // `_bindProgressManagerListeners` dinleyicileri) kalıcı yazımsız
    // senkron tutar. Zıt değere önce yazmak, bildirimcinin değişim
    // bildirimini garantiler.
    final pm = ProgressManager.instance;
    final audio = AudioManager();
    audio.isMuted = false;
    pm.sfxEnabled = false;
    pm.sfxNotifier.value = false;
    pm.sfxEnabled = true;
    pm.sfxNotifier.value = true;
    pm.vibrationEnabled = false;
    pm.vibrationNotifier.value = false;
    pm.vibrationEnabled = true;
    pm.vibrationNotifier.value = true;
    audio.setVoiceEnabled(true);
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'LululuSetSfx',
      'lululu_sfx_enabled',
      'LululuSetVoice',
      'lululu_voice_enabled',
      'LululuSetVib',
      'lululu_vibration_enabled',
    ]) {
      await prefs.remove(key);
    }
    await pm.load();
    await EnergyService.instance.load();
  });

  tearDown(() {
    FlutterError.onError = prevOnError;
  });

  /// Motor bildirimlerini (sistem fontu değişimi) tüketir: bildirimler
  /// GERÇEK zamanda ulaşır, sahte zamanlı pump'lar onları beklemez;
  /// bekleyen çerçeve geri çağrısı teardown'da "animation is still
  /// running" istisnasına dönüşür. Bu ortam sorunu bu kopyada
  /// `missing_screens_test`'te de 3 testi düşürür (önceden var).
  /// Kısa gerçek bekleme + 3 pump, bildirimi ve tetiklediği geri
  /// çağrıyı her widget testinin sonunda güvenle tüketir.
  Future<void> flushEngineNotifications(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapWithL10n(const SettingsScreen(), theme: buildLululuTheme()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('D2 (F3) — SFX anahtarı voice\'u susturmaz', () {
    testWidgets(
      'SFX kapatmak isMuted yazmaz; voice bayrağı ve kapısı bağımsız kalır',
      (tester) async {
        await pumpSettings(tester);
        final audio = AudioManager();
        expect(audio.isMuted, isFalse);
        expect(audio.sfxEnabled, isTrue);
        expect(audio.voiceEnabled, isTrue);

        await tester.ensureVisible(find.text('Ses Efektleri'));
        await tester.tap(find.text('Ses Efektleri'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // SFX kanalı kapandı ama master mute yazılmadı ve voice bayrağı
        // aynen duruyor: `_voiceAudible = !_isMuted && _voiceEnabled`
        // formülüyle voice kapısı açık kalır (audio_manager.dart).
        expect(audio.sfxEnabled, isFalse);
        expect(ProgressManager.instance.sfxEnabled, isFalse);
        expect(audio.isMuted, isFalse);
        expect(audio.voiceEnabled, isTrue);
        expect(!audio.isMuted && audio.voiceEnabled, isTrue);

        // Geri açmak da isMuted'a dokunmaz.
        await tester.tap(find.text('Ses Efektleri'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(audio.sfxEnabled, isTrue);
        expect(audio.isMuted, isFalse);
        expect(audio.voiceEnabled, isTrue);

        await flushEngineNotifications(tester);
      },
    );
  });

  group('D3 (F4) — Titreşim varsayılanı ve geri-yazma', () {
    testWidgets(
      'Ayarlar açılışı titreşimi kapatmaz ve tercih yazmaz',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('LululuSetVib'), isNull);
        expect(prefs.getBool('lululu_vibration_enabled'), isNull);

        await pumpSettings(tester);

        // Hiçbir titreşim anahtarı yazılmadı (eski kod ikisini de
        // `false` yazıyordu) ve bayraklar varsayılan `true`'da kaldı.
        expect(prefs.getBool('LululuSetVib'), isNull);
        expect(prefs.getBool('lululu_vibration_enabled'), isNull);
        expect(AudioManager().vibrationEnabled, isTrue);
        expect(ProgressManager.instance.vibrationEnabled, isTrue);
        expect(HapticService.instance.isEnabled, isTrue);

        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'yalnız lululu_vibration_enabled yazılmışsa yedek anahtar okunur',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('lululu_vibration_enabled', true);
        await prefs.remove('LululuSetVib');

        await pumpSettings(tester);

        // Eski kod (`LululuSetVib ?? false`) burada titreşimi
        // kapatıyordu; yedek anahtar okununca açık kalır.
        expect(AudioManager().vibrationEnabled, isTrue);
        expect(ProgressManager.instance.vibrationEnabled, isTrue);
        expect(prefs.getBool('lululu_vibration_enabled'), isTrue);
        expect(prefs.getBool('LululuSetVib'), isNull);

        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'eski anahtar false ise titreşim kapanır ve değişim yazılır',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('LululuSetVib', false);
        await prefs.remove('lululu_vibration_enabled');

        await pumpSettings(tester);

        expect(AudioManager().vibrationEnabled, isFalse);
        expect(ProgressManager.instance.vibrationEnabled, isFalse);
        expect(HapticService.instance.isEnabled, isFalse);
        // Değişim olduğu için çift anahtar kalıcı yazılır.
        expect(prefs.getBool('LululuSetVib'), isFalse);
        expect(prefs.getBool('lululu_vibration_enabled'), isFalse);

        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'titreşim anahtarına dokunmak ayarı kalıcı yazar',
      (tester) async {
        await pumpSettings(tester);
        expect(AudioManager().vibrationEnabled, isTrue);

        await tester.ensureVisible(find.text('Titreşim'));
        await tester.tap(find.text('Titreşim'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(AudioManager().vibrationEnabled, isFalse);
        expect(ProgressManager.instance.vibrationEnabled, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('LululuSetVib'), isFalse);
        expect(prefs.getBool('lululu_vibration_enabled'), isFalse);

        await flushEngineNotifications(tester);
      },
    );
  });

  group('7C — Settings isMuted okumaları kalktı + koşullu yazımlar', () {
    testWidgets(
      'isMuted açıkken Ayarlar açılırsa SFX açık görünür, pref yazılmaz',
      (tester) async {
        final audio = AudioManager();
        // Yaşam-döngüsü master mute'unu simüle et (pause durumu):
        // bu, SFX tercihi DEĞİLDİR — eski kod SFX anahtarını kapatıp
        // `false` yazıyordu.
        audio.isMuted = true;
        expect(audio.sfxEnabled, isTrue);
        expect(audio.voiceEnabled, isTrue);

        await pumpSettings(tester);

        // Anahtarlar yalnız kendi tercihlerinden beslenir.
        expect(audio.sfxEnabled, isTrue);
        expect(audio.voiceEnabled, isTrue);
        // Anahtar UI'da da açık görünür (initState isMuted okumaz):
        // SFX satırındaki anahtar yeşildir (açık = 0xFF12B76A).
        final sfxRow = find.ancestor(
          of: find.text('Ses Efektleri'),
          matching: find.byType(Row),
        );
        final sfxSwitch = find.descendant(
          of: sfxRow,
          matching: find.byType(AnimatedContainer),
        );
        expect(sfxSwitch, findsOneWidget);
        final switchWidget = tester.widget<AnimatedContainer>(sfxSwitch);
        final switchDecoration = switchWidget.decoration as BoxDecoration?;
        expect(switchDecoration?.color, const Color(0xFF12B76A));
        // Değer değişmediği için hiçbir ses anahtarı yazılmadı.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('LululuSetSfx'), isNull);
        expect(prefs.getBool('lululu_sfx_enabled'), isNull);
        expect(prefs.getBool('LululuSetVoice'), isNull);
        expect(prefs.getBool('lululu_voice_enabled'), isNull);

        audio.isMuted = false;
        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'tek anahtar yazılıysa _loadPrefs diğer anahtara geri-yazma yapmaz',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('LululuSetSfx', true);
        await prefs.setBool('LululuSetVoice', true);

        await pumpSettings(tester);

        // Değerler bellek-içi değerle aynı → hiç yazım yok, yedek
        // anahtarlar boş kalır (eski koşulsuz yazım ikisini de yazardı).
        expect(prefs.getBool('lululu_sfx_enabled'), isNull);
        expect(prefs.getBool('lululu_voice_enabled'), isNull);
        expect(AudioManager().sfxEnabled, isTrue);
        expect(AudioManager().voiceEnabled, isTrue);

        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'SFX anahtarı voice kanalına yazmaz',
      (tester) async {
        await pumpSettings(tester);
        final audio = AudioManager();
        expect(audio.voiceEnabled, isTrue);

        await tester.ensureVisible(find.text('Ses Efektleri'));
        await tester.tap(find.text('Ses Efektleri'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(audio.sfxEnabled, isFalse);
        expect(audio.voiceEnabled, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('LululuSetSfx'), isFalse);
        expect(prefs.getBool('lululu_sfx_enabled'), isFalse);
        // Voice kanalı hiç yazılmadı.
        expect(prefs.getBool('LululuSetVoice'), isNull);
        expect(prefs.getBool('lululu_voice_enabled'), isNull);

        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'voice anahtarı SFX kanalına yazmaz',
      (tester) async {
        await pumpSettings(tester);
        final audio = AudioManager();
        expect(audio.sfxEnabled, isTrue);

        await tester.ensureVisible(find.text('Böcek Seslendirmeleri'));
        await tester.tap(find.text('Böcek Seslendirmeleri'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(audio.voiceEnabled, isFalse);
        expect(audio.sfxEnabled, isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('LululuSetVoice'), isFalse);
        expect(prefs.getBool('lululu_voice_enabled'), isFalse);
        // SFX kanalı hiç yazılmadı.
        expect(prefs.getBool('LululuSetSfx'), isNull);
        expect(prefs.getBool('lululu_sfx_enabled'), isNull);

        await flushEngineNotifications(tester);
      },
    );
  });

  group('D6 (F8) — Mağaza başarı / başarısızlık dalları', () {
    setUp(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lululu_coins', 1000);
      await prefs.setInt('LululuCoinBalance', 1000);
      await prefs.setBool('lululu_royal_cape', false);
      final pm = ProgressManager.instance;
      pm.hasRoyalCape = false;
      pm.ownedCosmetics.clear();
      await pm.load();
      await EnergyService.instance.load();
      EnergyService.instance.energy = 5;
    });

    Future<void> pumpShop(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpWithL10n(
        tester,
        const ShopScreen(showBottomNav: false, embedded: true),
        debugShowCheckedModeBanner: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    Future<void> scrollToLabel(WidgetTester tester, String label) async {
      await tester.dragUntilVisible(
        find.bySemanticsLabel(label),
        find.byType(ListView),
        const Offset(0, -400),
      );
      await tester.pump();
    }

    Future<void> tapLabel(WidgetTester tester, String label) async {
      await scrollToLabel(tester, label);
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> tapDialogButton(WidgetTester tester, String text) async {
      await tester.tap(find.text(text));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
      'coin alımı başarısı: coin harcanır, başarı toast\'ı görünür '
      '(playWin dalı)',
      (tester) async {
        await pumpShop(tester);
        expect(ProgressManager.instance.coins, 1000);

        await tapLabel(tester, 'Ahşap Sandık satın al, 200');
        await tapDialogButton(tester, 'Onayla');
        await tester.pump(const Duration(milliseconds: 300));

        // 200 harcama + 250 sandık ödülü; başarı dalı çalıştı.
        expect(ProgressManager.instance.coins, 1050);
        expect(find.text('Ahşap Sandık sepete eklendi'), findsOneWidget);

        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'yetersiz bakiye: coin değişmez, yetersiz-bakiye toast\'ı görünür '
      '(sessiz pop dalı)',
      (tester) async {
        await pumpShop(tester);
        expect(
          await ProgressManager.instance.spendCoins(900),
          isTrue,
        );
        expect(ProgressManager.instance.coins, 100);

        await tapLabel(tester, 'Ahşap Sandık satın al, 200');
        await tapDialogButton(tester, 'Onayla');
        await tester.pump(const Duration(milliseconds: 300));

        expect(ProgressManager.instance.coins, 100);
        expect(
          find.text(
            'Yetersiz altın! Oyun oynayarak altın kazanabilirsin.',
          ),
          findsOneWidget,
        );

        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'IAP onayı: sandbox teslimatı çalışır (playWin dalı)',
      (tester) async {
        await pumpShop(tester);

        await tapLabel(tester, 'Makara Paket satın al, ₺79,99');
        await tapDialogButton(tester, 'Onayla');
        // IAP ensureLoaded 6 sn zaman aşımıyla mağaza kanalını
        // bekleyebilir; sahte saat ilerletilmeden teslimat tamamlanmaz.
        await tester.pump(const Duration(seconds: 7));
        await tester.pump(const Duration(milliseconds: 300));

        // Sandbox teslimatı: coins_mid 1500 coin verir.
        expect(ProgressManager.instance.coins, 2500);

        await flushEngineNotifications(tester);
      },
    );
  });

  group('D7 (F9) — Başarım toast gösterimi', () {
    setUp(() async {
      await AchievementPassService.instance.resetForTesting();
      await AchievementPassService.instance.load();
    });

    Future<void> pumpToastBanner(WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWithL10n(
          const Scaffold(
            body: Stack(
              children: [
                AchievementToastBanner(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'mount anında aktif toast banner ile görünür (initState yolu)',
      (tester) async {
        final service = AchievementPassService.instance;
        expect(await service.unlockAchievement('merge_first'), isTrue);

        await pumpToastBanner(tester);

        expect(find.text('BAŞARIM AÇILDI!'), findsOneWidget);
        expect(
          find.byKey(const Key('achievement_toast_merge_first')),
          findsOneWidget,
        );

        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'bildirimci değişimiyle gelen toast banner ile görünür '
      '(dinleyici yolu)',
      (tester) async {
        await pumpToastBanner(tester);
        expect(find.text('BAŞARIM AÇILDI!'), findsNothing);

        final service = AchievementPassService.instance;
        expect(await service.unlockAchievement('merge_100'), isTrue);
        await tester.pumpAndSettle();

        expect(find.text('BAŞARIM AÇILDI!'), findsOneWidget);
        expect(
          find.byKey(const Key('achievement_toast_merge_100')),
          findsOneWidget,
        );

        await flushEngineNotifications(tester);
      },
    );

    testWidgets(
      'kuyruktaki ikinci toast kapatınca görünür, dinleyici çökmez',
      (tester) async {
        final service = AchievementPassService.instance;
        expect(await service.unlockAchievement('merge_first'), isTrue);
        expect(await service.unlockAchievement('merge_1000'), isTrue);

        await pumpToastBanner(tester);
        expect(
          find.byKey(const Key('achievement_toast_merge_first')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('achievement_toast_close_btn')),
        );
        await tester.pumpAndSettle();

        expect(service.activeToastNotifier.value?.id, 'merge_1000');
        expect(
          find.byKey(const Key('achievement_toast_merge_first')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('achievement_toast_merge_1000')),
          findsOneWidget,
        );

        await flushEngineNotifications(tester);
      },
    );
  });

  group('D12 (F7) — Deprecated işaretli metotlar derlenir ve çalışır', () {
    test('ölü alias metotlar çağrılabilir (imzalar korunur)', () async {
      final audio = AudioManager();
      // ignore: deprecated_member_use
      await audio.playMergeSfx(tier: 1);
      // ignore: deprecated_member_use
      await audio.playDropSfx();
      // ignore: deprecated_member_use
      await audio.playSlapSfx(tier: InsectTier.cone);
      // ignore: deprecated_member_use
      await audio.playSpraySfx();
      // ignore: deprecated_member_use
      await audio.playAydinlatVoice();
      // ignore: deprecated_member_use
      audio.triggerLightHaptic();
      // playExclusiveSfx @visibleForTesting'tir: testten çağrı meşrudur.
      var exclusiveDone = false;
      final exclusiveOk = await audio.playExclusiveSfx(
        GameAudio.sfxPop,
        onComplete: () => exclusiveDone = true,
      );
      expect(exclusiveOk, isTrue);
      expect(exclusiveDone, isTrue);
    });
  });

  group('Yapısal kilitler — ses satırları doğru dallarda', () {
    Directory resolveProjectRoot() {
      final cwd = Directory.current;
      if (File('${cwd.path}/pubspec.yaml').existsSync()) return cwd;
      final sub = Directory('${cwd.path}/lululu_game');
      if (File('${sub.path}/pubspec.yaml').existsSync()) return sub;
      throw StateError('pubspec.yaml bulunamadı: ${cwd.path}');
    }

    String readSource(String relativePath) {
      final root = resolveProjectRoot();
      final file = File('${root.path}/$relativePath');
      expect(file.existsSync(), isTrue, reason: '$relativePath yok');
      return file.readAsStringSync();
    }

    /// Yalnız tam-satır `//` yorumlarını atar (D2/D6 yorumları eski
    /// kodu alıntılar; kod iddiaları yorum metnine dayanmamalı).
    String codeOnly(String source) {
      return source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
    }

    int countOccurrences(String source, String needle) {
      return RegExp(RegExp.escape(needle)).allMatches(source).length;
    }

    String sliceBetween(String source, String start, String end) {
      final startIndex = source.indexOf(start);
      expect(startIndex, isNot(-1), reason: 'başlangıç yok: $start');
      final endIndex = source.indexOf(end, startIndex + start.length);
      expect(endIndex, isNot(-1), reason: 'bitiş yok: $end');
      return source.substring(startIndex, endIndex);
    }

    test('D2: _onSfxChanged isMuted yazmaz, yalnız setSfxEnabled yazar', () {
      final code = codeOnly(
        readSource('lib/screens/settings_screen.dart'),
      );
      final handler = sliceBetween(
        code,
        'void _onSfxChanged',
        'void _onVoiceChanged',
      );
      expect(handler.contains('isMuted'), isFalse);
      expect(handler.contains('setSfxEnabled(v)'), isTrue);
    });

    test('D3: titreşim okuması yedek anahtarlı ve varsayılan true', () {
      final code = codeOnly(
        readSource('lib/screens/settings_screen.dart'),
      );
      final loadPrefs = sliceBetween(
        code,
        'Future<void> _loadPrefs()',
        // 7C: `_savePref` kaldırıldı (setter'lar çift anahtarı yazar);
        // `_loadPrefs`'i artık `_onSfxChanged` izler.
        'void _onSfxChanged',
      );
      final vibRead = sliceBetween(
        loadPrefs,
        "vib = prefs.getBool('LululuSetVib')",
        ';',
      ).replaceAll(RegExp(r'\s+'), ' ');
      expect(
        vibRead.contains("prefs.getBool('lululu_vibration_enabled')"),
        isTrue,
      );
      expect(vibRead.contains('?? true'), isTrue);
      expect(loadPrefs.contains('vibrationEnabled != vib'), isTrue);
    });

    test('D6: playWin yalnız iki satın alma başarı dalında, playLose yok',
        () {
      final code = codeOnly(readSource('lib/widgets/shop_dialog.dart'));
      expect(countOccurrences(code, 'AudioManager().playWin();'), 2);
      expect(code.contains('playLose'), isFalse);
      final iap = sliceBetween(
        code,
        'Future<void> _buyIapProduct(',
        'Future<void> _watchFreeChestAd()',
      );
      expect(iap.contains('AudioManager().playWin();'), isTrue);
      final coin = sliceBetween(
        code,
        'Future<void> _buyCoinItem(',
        'Future<void> _restorePurchases()',
      );
      expect(coin.contains('AudioManager().playWin();'), isTrue);
      // Geri yükleme kapsam dışıdır: ses eklenmedi.
      final restore = sliceBetween(
        code,
        'Future<void> _restorePurchases()',
        'Widget _buildStatusBar()',
      );
      expect(restore.contains('playWin'), isFalse);
    });

    test('D7: toast dinleyicisi playWin çalar, claim sesi korunur', () {
      final code = codeOnly(
        readSource('lib/widgets/achievement_toast_overlay.dart'),
      );
      expect(countOccurrences(code, 'AudioManager().playWin();'), 2);
      expect(code.contains('addListener(_onToastChanged)'), isTrue);
      expect(code.contains('removeListener(_onToastChanged)'), isTrue);
      final listener = sliceBetween(
        code,
        'void _onToastChanged()',
        'void _syncVisibility()',
      );
      expect(listener.contains('AudioManager().playWin();'), isTrue);
    });

    test('D12: 6 metot @Deprecated, playExclusiveSfx internal, '
        'toggleMute işaretli değil', () {
      final code = codeOnly(readSource('lib/services/audio_manager.dart'));
      expect(countOccurrences(code, '@Deprecated('), 6);
      expect(code.contains('@visibleForTesting'), isTrue);
      final exclusiveIndex = code.indexOf('Future<bool> playExclusiveSfx(');
      expect(exclusiveIndex, isNot(-1));
      final beforeExclusive = code.substring(
        exclusiveIndex - 600 < 0 ? 0 : exclusiveIndex - 600,
        exclusiveIndex,
      );
      expect(beforeExclusive.contains('@visibleForTesting'), isTrue);
      // toggleMute'un test çağrıcısı var (store_readiness_test): işaretlenmez.
      final toggleIndex = code.indexOf('void toggleMute()');
      expect(toggleIndex, isNot(-1));
      final beforeToggle = code.substring(
        toggleIndex - 400 < 0 ? 0 : toggleIndex - 400,
        toggleIndex,
      );
      expect(beforeToggle.contains('@Deprecated'), isFalse);
    });

    test('D13-doc: ASSETS_NOTE düzeltmesi + design/sounds klasörü yok', () {
      final root = resolveProjectRoot();
      final note = readSource('assets/audio/ASSETS_NOTE.md');
      expect(note.contains('D13-doc/F21'), isTrue);
      expect(note.contains('silme henüz YAPILMADI'), isFalse);
      expect(
        Directory('${root.path}/assets/design/sounds').existsSync(),
        isFalse,
      );
    });

    test('7C: settings_screen kodunda isMuted okuması yok', () {
      final code = codeOnly(
        readSource('lib/screens/settings_screen.dart'),
      );
      // Yorum satırları codeOnly ile atılır: kalan `isMuted` bir
      // okuma/yazım olurdu. initState + `_loadPrefs` yedeği kalktı;
      // `isMuted` artık yalnız AppLifecycleGuard'da yazılır.
      expect(code.contains('isMuted'), isFalse);
    });

    test('7C: _loadPrefs SFX/voice yalnız değişimde yazar', () {
      final code = codeOnly(
        readSource('lib/screens/settings_screen.dart'),
      );
      final loadPrefs = sliceBetween(
        code,
        'Future<void> _loadPrefs()',
        'void _onSfxChanged',
      );
      expect(loadPrefs.contains('sfxEnabled != sfx'), isTrue);
      expect(loadPrefs.contains('voiceEnabled != voice'), isTrue);
      // Yedek yoksa bellek-içi değer korunur (isMuted varsayılanı yok).
      expect(loadPrefs.contains('_audio.sfxEnabled'), isTrue);
      expect(loadPrefs.contains('_audio.voiceEnabled'), isTrue);
    });

    test('7C: AudioManager setter\'ları değişim yoksa yazmaz', () {
      final code = codeOnly(readSource('lib/services/audio_manager.dart'));
      final sfxSetter = sliceBetween(
        code,
        'set sfxEnabled(bool value) {',
        'set voiceEnabled(bool value) {',
      );
      expect(sfxSetter.contains('if (_sfxEnabled == value) return;'), isTrue);
      final voiceSetter = sliceBetween(
        code,
        'set voiceEnabled(bool value) {',
        'set vibrationEnabled(bool value) {',
      );
      expect(
        voiceSetter.contains('if (_voiceEnabled == value) return;'),
        isTrue,
      );
      final vibSetter = sliceBetween(
        code,
        'set vibrationEnabled(bool value) {',
        'void setSfxEnabled(bool enabled)',
      );
      expect(
        vibSetter.contains('if (_vibrationEnabled == value) return;'),
        isTrue,
      );
      final muteSetter = sliceBetween(
        code,
        'set isMuted(bool value) {',
        'bool get sfxEnabled',
      );
      expect(muteSetter.contains('if (_isMuted == value) return;'), isTrue);
    });

    test('7C: toggle handler\'ları yalnız kendi setter\'ını yazar', () {
      final code = codeOnly(
        readSource('lib/screens/settings_screen.dart'),
      );
      final sfxHandler = sliceBetween(
        code,
        'void _onSfxChanged',
        'void _onVoiceChanged',
      );
      expect(sfxHandler.contains('setSfxEnabled(v)'), isTrue);
      expect(sfxHandler.contains('ProgressManager'), isFalse);
      expect(sfxHandler.contains('_savePref'), isFalse);
      final voiceHandler = sliceBetween(
        code,
        'void _onVoiceChanged',
        'void _onVibrationChanged',
      );
      expect(voiceHandler.contains('setVoiceEnabled(v)'), isTrue);
      expect(voiceHandler.contains('_savePref'), isFalse);
      final vibHandler = sliceBetween(
        code,
        'void _onVibrationChanged',
        'void _onLanguageChanged',
      );
      expect(vibHandler.contains('setVibrationEnabled(v)'), isTrue);
      // Titreşim servisi ayrıdır, setter'a girmez — korunur.
      expect(
        vibHandler.contains('HapticService.instance.setEnabled(v)'),
        isTrue,
      );
      expect(vibHandler.contains('_savePref'), isFalse);
      expect(vibHandler.contains('ProgressManager'), isFalse);
    });
  });
}
