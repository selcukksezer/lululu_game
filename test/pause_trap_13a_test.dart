import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// W13-A — Duraklatma tuzağı, YENİDEN DEĞERLENDİRME (W13-B + koordinatör
/// doğrulaması).
///
/// Playtest V (§4/§6) bulgusu: ⏸ → "DURAKLATILDI" overlay + CONTINUE
/// çıkıyor ama CONTINUE'ye basmak hiçbir şey yapmıyor; 4 oturumda 10+
/// dokunuş, kareler bayt bayt aynı. Koordinatörün kare + JSON
/// doğrulaması: sürücünün resume tap'leri hep (215,605) — oysa
/// CONTINUE düğmesinin merkezi Match3'te y≈512, Stack Drop'ta y≈561
/// (bu dosyada ölçülür). Yani tap'ler düğmenin 44–88 px ALTINDAKİ
/// boş overlay alanına düştü; boş overlay'e dokunmak tasarım gereği
/// hiçbir şey yapmaz (alttaki oyuna girdi gitmesin diye). `_busy`
/// Çığlık/Makara'da hiç geçmiyor, Match3'te de takassız açılışta
/// tekrar üreyen tuzakla uyumsuz — `_busy` suçlu değil.
///
/// Bu dosya HEDEFE dokunuşu test eder: düğme metin ile bulunup
/// merkezine tap yapılır (sabit koordinat YOK). Hedefe dokununca
/// overlay kapanıyorsa kod sağlamdır, sürücü ıskalamıştır.
/// lib/'de bu görevde DEĞİŞİKLİK YOKTUR (base ile birebir — `diff -r`
/// ile doğrulandı); `_togglePause` / `_busy` korumasına dokunulmadı.
///
/// Canlı koşu 430x932'de tekrarlanır.
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

  Future<void> pumpAt430x932(
    WidgetTester tester,
    Widget child, {
    bool useTheme = false,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
        await binding.pump();
      }
    });
    await tester.pumpWidget(
      wrapWithL10n(child, theme: useTheme ? buildLululuTheme() : null),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// `finishRun` asenkron iş yapar (ödeme/liderlik); sonuç diyaloğu
  /// birkaç pump sonra belirir. Periyodik zamanlayıcılar yüzünden
  /// `pumpAndSettle` kullanılmaz — sınırlı döngüyle beklenir.
  Future<bool> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int maxPumps = 40,
  }) async {
    for (var i = 0; i < maxPumps; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> pauseMatch3(WidgetTester tester) async {
    await pumpAt430x932(tester, const Match3Screen());
    expect(find.text('DURAKLATILDI'), findsNothing);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('DURAKLATILDI'), findsOneWidget);
  }

  Future<void> pauseStack(WidgetTester tester) async {
    await pumpAt430x932(tester, const StackDropScreen(), useTheme: true);
    expect(find.text('DURAKLATILDI'), findsNothing);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('DURAKLATILDI'), findsOneWidget);
  }

  group('Match 3 — hedefe dokunuş (13A)', () {
    testWidgets('13A-M3: DEVAM düğmesine hedefe dokununca devam eder', (
      tester,
    ) async {
      await pauseMatch3(tester);
      // HEDEFE dokunuş: düğme metin ile bulunur, merkezine tap
      // yapılır — sürücünün (215,600) sabit koordinatı kullanılmaz.
      final center = tester.getCenter(find.text('DEVAM'));
      debugPrint('13A-M3 DEVAM merkezi: $center');
      expect(center.dx, closeTo(215.0, 1.0));
      expect(center.dy, closeTo(512.0, 2.0));
      await tester.tap(find.text('DEVAM'));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('13A-M3: duraklat → devam → duraklat turu hedefe dokunuşla',
        (tester) async {
      await pauseMatch3(tester);
      await tester.tap(find.text('DEVAM'));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsNothing);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      await tester.tap(find.text('DEVAM'));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('13A-M3: sürücünün (215,600) tap\'i düğmeyi ıskalar', (
      tester,
    ) async {
      await pauseMatch3(tester);
      // Kanıt: düğme merkezi y≈512; (215,600) düğmenin ~88 px
      // altındaki boş overlay/tahta alanıdır. Boş alana dokunmak
      // tasarım gereği hiçbir şey yapmaz — overlay açık kalır.
      // Bu, canlıdaki "CONTINUE ölü" görüntüsünün açıklamasıdır.
      final center = tester.getCenter(find.text('DEVAM'));
      debugPrint('13A-M3 DEVAM merkezi: $center');
      expect(center.dy, closeTo(512.0, 2.0));
      await tester.tapAt(const Offset(215, 600));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  });

  group('Stack Drop — hedefe dokunuş (13A)', () {
    testWidgets('13A-ST: DEVAM düğmesine hedefe dokununca devam eder', (
      tester,
    ) async {
      await pauseStack(tester);
      final center = tester.getCenter(find.text('DEVAM'));
      debugPrint('13A-ST DEVAM merkezi: $center');
      expect(center.dx, closeTo(215.0, 1.0));
      expect(center.dy, closeTo(561.0, 2.0));
      await tester.tap(find.text('DEVAM'));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('13A-ST: sürücünün (215,605) tap\'i düğmeyi ıskalar', (
      tester,
    ) async {
      await pauseStack(tester);
      // Kanıt: düğme merkezi y≈561; (215,605) düğmenin ~44 px
      // altındaki boş overlay alanıdır — overlay açık kalır.
      final center = tester.getCenter(find.text('DEVAM'));
      debugPrint('13A-ST DEVAM merkezi: $center');
      expect(center.dy, closeTo(561.0, 2.0));
      await tester.tapAt(const Offset(215, 605));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('13A-ST: ⏸ ile duraklat, ⏸ ile devam eder', (tester) async {
      await pauseStack(tester);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.text('DURAKLATILDI'), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('13A-ST: duraklatmada BİTİR sonuç ekranını açar', (
      tester,
    ) async {
      await pauseStack(tester);
      await tester.tap(find.text('BİTİR'));
      final shown = await pumpUntilFound(tester, find.text('TEKRAR OYNA'));
      expect(shown, isTrue, reason: 'BİTİR sonuç ekranını açmalı');
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  });
}
