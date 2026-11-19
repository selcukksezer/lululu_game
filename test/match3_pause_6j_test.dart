import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// 6J — Match3 duraklatma (A8d G45).
///
/// Kök neden: ⏸ düğmesi kodda doğru bağlıydı (`onTap: _togglePause`,
/// lib/modes/match3_screen.dart) ama görünür daire 48 px (x 219-267,
/// merkez 243) iken canlı denetim tıklaması (215,120) dairenin 4 px
/// solundaki ölü boşluğa düştü — REKOR kutusu x<=208'de biter, daire
/// x>=219'da başlar, arada hiçbir GestureDetector yok. Düzeltme:
/// görsel daire aynen 48 px kalır, dokunma alanı 64 px'e genişletildi
/// (x 211-275); merkez (243, 122.6) değişmez, komşu kutulara taşmaz.
///
/// Bu testler canlı koşuyu 430x932'de (denetim viewport'u) tekrarlar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    AudioManager().isMuted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (call) async => null,
        );
  });

  Future<void> pumpMatch3(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Teardown flake tahliyesi (responsive_modes_n7_6d deseni): ilk kez
    // kullanılan bir font varyantı `fontsChange` bildirimi gönderir;
    // bildirim test gövdesinin son pump'ından sonra gelirse
    // `RelayoutWhenSystemFontsChangeMixin` callback'i `postTest`
    // denetimine takılır ("animation is still running"). addTearDown
    // `postTest`'ten ÖNCE çalışır; bekleyen frame callback'ini işletir.
    addTearDown(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
        await binding.pump();
      }
    });
    await tester.pumpWidget(wrapWithL10n(const Match3Screen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// HUD istatistik kutusundaki sayısal değeri etiketine göre okur
  /// (binlik ayracı '.' kaldırılır) — match3_play_test ile aynı yöntem.
  int statValue(WidgetTester tester, String label) {
    final labelFinder = find.text(label);
    expect(labelFinder, findsOneWidget, reason: 'Etiket "$label" bulunamadı');
    final columnFinder = find.ancestor(
      of: labelFinder,
      matching: find.byType(Column),
    );
    final texts = find
        .descendant(of: columnFinder.first, matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .toList();
    expect(texts, hasLength(2), reason: 'HUD kutusu "$label" + değer olmalı');
    return int.parse(texts.last.replaceAll('.', ''));
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets(
    '6J: canlı denetim koordinatı (215,120) DURAKLATILDI katmanını açar',
    (tester) async {
      await pumpMatch3(tester);
      expect(find.text('DURAKLATILDI'), findsNothing);
      final scoreBefore = statValue(tester, 'SKOR');
      final movesBefore = statValue(tester, 'HAMLE');
      expect(movesBefore, 30);

      // A8d'de ölü sanılan tıklama: artık dokunma alanının içinde.
      await tester.tapAt(const Offset(215, 120));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      expect(find.text('DEVAM'), findsOneWidget);

      // Duraklatmada skor/hamle donar: tahta üstüne dokun + 5 sn pompa.
      // (60,300) tahtanın sol-üst hücresidir — ortalanmış DEVAM
      // düğmesine değmez.
      await tester.tapAt(const Offset(60, 300));
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      expect(statValue(tester, 'SKOR'), scoreBefore);
      expect(statValue(tester, 'HAMLE'), movesBefore);

      // DEVAM ile katman kapanır, oyun devam eder.
      await tester.tap(find.text('DEVAM'));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsNothing);
      expect(statValue(tester, 'SKOR'), scoreBefore);
      expect(statValue(tester, 'HAMLE'), movesBefore);

      // Devamdan sonra girdi geri gelir (kilitlenme yok).
      await tester.tapAt(const Offset(60, 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    },
  );

  testWidgets('6J: ⏸ simgesi yerinde, dokunma alanı 64 px genişliğinde', (
    tester,
  ) async {
    await pumpMatch3(tester);
    final icon = find.byIcon(Icons.pause_rounded);
    expect(icon, findsOneWidget);

    // Görsel merkez canlı kareyle aynı: (243, 122.6).
    final center = tester.getCenter(icon);
    expect(center.dx, closeTo(243.0, 2.0));
    expect(center.dy, closeTo(122.6, 2.0));

    // Dokunma alanı görsel daireden (48 px) geniştir: 64x48.
    final detector = find.ancestor(
      of: icon,
      matching: find.byType(GestureDetector),
    );
    expect(detector, findsOneWidget);
    expect(tester.getSize(detector), const Size(64, 48));

    // Simge merkezine dokunuş da katmanı açar.
    await tester.tap(icon);
    await tester.pump();
    expect(find.text('DURAKLATILDI'), findsOneWidget);
    await tester.tap(find.text('DEVAM'));
    await tester.pump();
    expect(find.text('DURAKLATILDI'), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });
}
