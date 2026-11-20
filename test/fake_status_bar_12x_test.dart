// 12X — sahte durum çubuğu kaldırma kilidi.
//
// Brif: oyunun her ekranındaki prototipten kalma sahte durum çubuğu
// (sabit '09:41' + çizim sinyal/wifi/pil) kaldırıldı; gerçek telefonda
// zaten gerçek durum çubuğu var. Bu test iki şeyi kilitler:
//  1. lib altında '09:41' (ve sahte çubuk izleri) kalmadı (kaynak taraması).
//  2. En az 3 ana ekranda (hub / mod listesi / Suika) sahte çubuk
//     widget'ı yok: '09:41' metni ve çizim sinyal/pil ikonları
//     hiçbir ekranda çizilmiyor.
// Gerçek cihaz saati eklenmez; görev/ödül zamanlayıcılarına dokunulmaz.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/screens/modes_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'font_loader_helper.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    await loadTestFonts();
  });

  setUp(() {
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

  Directory resolveProjectRoot() {
    final cwd = Directory.current;
    if (File('${cwd.path}/pubspec.yaml').existsSync()) return cwd;
    final sub = Directory('${cwd.path}/lululu_game');
    if (File('${sub.path}/pubspec.yaml').existsSync()) return sub;
    throw StateError('pubspec.yaml bulunamadı: ${cwd.path}');
  }

  test('12X: lib altında sahte durum çubuğu izi yok', () {
    final root = resolveProjectRoot();
    final libDir = Directory('${root.path}/lib');
    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files.isNotEmpty, isTrue, reason: 'lib/*.dart bulunamadı');
    final offenders = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final needle in [
        '09:41',
        'showStatusBar',
        'PrototypeStatusBar',
        '_prototypeStatusBar',
        'signal_cellular_alt_rounded',
        'battery_full_rounded',
      ]) {
        if (source.contains(needle)) {
          offenders.add('${file.path}: $needle');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  testWidgets('12X: hub ekranında sahte durum çubuğu yok', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithL10n(
        const Scaffold(body: GameSelectorScreen()),
        theme: buildLululuTheme(),
        debugShowCheckedModeBanner: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Hub animasyonları + font geri aramaları bitsin (widget_test deseni:
    // dispose öncesi kareler tüketilmezse scheduler "animation is still
    // running" hatası verir).
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('09:41'), findsNothing);
    expect(find.byIcon(Icons.signal_cellular_alt_rounded), findsNothing);
    expect(find.byIcon(Icons.battery_full_rounded), findsNothing);

    // Hub ilk çizimde tembel font yükler; bildirimi ilk ağaçta tüketip
    // ikinci kez pompalayınca dispose temiz olur (aksi hâlde scheduler
    // son kareden sonra gelen font bildiriminde takılır — hub_catalog
    // ve widget_test'te de aynı ortam sorunu var).
    await tester.pumpWidget(
      wrapWithL10n(
        const Scaffold(body: GameSelectorScreen()),
        theme: buildLululuTheme(),
        debugShowCheckedModeBanner: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('09:41'), findsNothing);
    expect(find.byIcon(Icons.signal_cellular_alt_rounded), findsNothing);
    expect(find.byIcon(Icons.battery_full_rounded), findsNothing);
    expect(tester.takeException(), isNull);

    // Dispose sonrası kalan transient callback'leri tüket: font
    // yüklemeleri GERÇEK async I/O ile tamamlanır — sahte saatli
    // pump'lar gerçek event loop'a yol vermez, bildirim hep son
    // kareden sonra gelirdi. runAsync + gerçek gecikme bildirimin
    // gelmesini sağlar, sonraki pump callback'i çalıştırır.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump();
  });

  testWidgets('12X: mod listesi ekranında sahte durum çubuğu yok', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithL10n(
        const Scaffold(body: ModesScreen()),
        theme: buildLululuTheme(),
        debugShowCheckedModeBanner: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('09:41'), findsNothing);
    expect(find.byIcon(Icons.signal_cellular_alt_rounded), findsNothing);
    expect(find.byIcon(Icons.battery_full_rounded), findsNothing);
    expect(tester.takeException(), isNull);

    // runAsync + gercek gecikme: font bildirimleri gercek async ile
    // gelir; sahte saatli pump'lar tek basina yetmez (hub testindeki
    // ayni tuzak).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump();
  });

  testWidgets('12X: Suika ekranında sahte durum çubuğu yok', (tester) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpWithL10n(
      tester,
      GameScreen(level: CampaignDatabase.kitchenLevel1, arcade: true),
      debugShowCheckedModeBanner: false,
      theme: buildLululuTheme(),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('09:41'), findsNothing);
    expect(find.byIcon(Icons.signal_cellular_alt_rounded), findsNothing);
    expect(find.byIcon(Icons.battery_full_rounded), findsNothing);
    expect(tester.takeException(), isNull);

    // runAsync + gercek gecikme: font bildirimleri gercek async ile
    // gelir; sahte saatli pump'lar tek basina yetmez (hub testindeki
    // ayni tuzak).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump();
  });
}
