// 12C2 — MicScream bağlama testleri.
//
// Kapsar:
// - Test/masaüstü/web ortamında `startListening` yedek moda düşer
//   (izin yokmuş gibi davranılır; oyun dokunmatikle oynanabilir kalır).
// - Eşik üstü güç tetikler (dokunmatik çığlık + simüle darbe),
//   eşik altı güç tetiklemez; eşik kelepçelenir (42..90 dB).
// - `pauseListening`/`resumeListening`: askıda dinleme sürer, devam
//   kaldığı yerden açılır (izin yeniden istenmez).
// - Çığlık ekranı: mikrofon düğmesi önce açıklama diyaloğunu açar,
//   onayda servis başlar, yedek modda simge kapalı kalır ve oyun
//   dokunmatikle oynanmaya devam eder.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/mic_scream_service.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = MicScreamService.instance;

  // NOT: flutter_test sahte saat kullanır — `Future.delayed` test
  // gövdesinde ilerlemez. Tetik kapısı (220 ms) gereken yerlerde
  // `tester.runAsync` ile GERÇEK zaman kullanılır; `setUp`/`tearDown`
  // gecikmesizdir.
  setUp(() async {
    await service.stopListening();
  });

  tearDown(() async {
    await service.stopListening();
  });

  group('MicScreamService yedek mod', () {
    test('test ortamında startListening yedek moda düşer', () async {
      final started = await service.startListening();
      expect(started, isTrue);
      expect(service.isListening, isTrue);
      expect(service.isFallbackMode, isTrue);
      expect(service.permissionGranted, isFalse);
      expect(service.statusMessage, isNotEmpty);
    });

    // Tetik kapısı (220 ms) gerçek duvar saatine bakar; sahte saatte
    // ilerlemez — bu test `runAsync` ile gerçek zamanda koşar.
    testWidgets('eşik üstü güç tetikler, eşik altı tetiklemez', (tester) async {
      await tester.runAsync(() async {
        await service.startListening();
        service.thresholdDb = 64;
        await Future<void>.delayed(const Duration(milliseconds: 250));

        // Dokunmatik çığlık her zaman eşiğin üstündedir.
        final touch = service.triggerTouchScream();
        expect(touch.triggeredScream, isTrue);
        expect(touch.normalizedPower, greaterThan(0.0));
        expect(touch.isSimulated, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 250));

        // Simüle darbe de eşiği aşar.
        final pulse = service.stepSimulation(0.08, screamPulse: true);
        expect(pulse.triggeredScream, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 250));

        // Sessiz simüle dalga (32..46 dB) eşiğin altındadır.
        var triggeredBelow = false;
        for (var i = 0; i < 10; i++) {
          final reading = service.stepSimulation(0.08);
          if (reading.triggeredScream) triggeredBelow = true;
        }
        expect(triggeredBelow, isFalse);
      });
    });

    test('eşik 42..90 dB aralığına kelepçelenir', () {
      service.thresholdDb = 200;
      expect(service.thresholdDb, 90.0);
      service.thresholdDb = 10;
      expect(service.thresholdDb, 42.0);
      service.thresholdDb = 64;
      expect(service.thresholdDb, 64.0);
    });

    testWidgets('powerNotifier eşik üstü güçte yükselir', (tester) async {
      await tester.runAsync(() async {
        await service.startListening();
        await Future<void>.delayed(const Duration(milliseconds: 250));
        service.triggerTouchScream();
        expect(service.powerNotifier.value, greaterThan(0.0));
        expect(
          service.powerNotifier.value,
          closeTo(service.normalizedPower, 0.001),
        );
      });
    });
  });

  group('MicScreamService pause/resume', () {
    test('pause askıya alır, resume kaldığı yerden devam ettirir', () async {
      await service.startListening();
      expect(service.isListening, isTrue);
      expect(service.isPaused, isFalse);

      service.pauseListening();
      expect(service.isPaused, isTrue);
      expect(service.isListening, isTrue);

      // Çift pause çift resume istemez.
      service.pauseListening();
      expect(service.isPaused, isTrue);

      await service.resumeListening();
      expect(service.isPaused, isFalse);
      expect(service.isListening, isTrue);
      expect(service.isFallbackMode, isTrue);
    });

    test('stopListening duraklatma durumunu da temizler', () async {
      await service.startListening();
      service.pauseListening();
      await service.stopListening();
      expect(service.isListening, isFalse);
      expect(service.isFallbackMode, isFalse);
      expect(service.isPaused, isFalse);
      expect(service.powerNotifier.value, 0.0);
    });
  });

  group('ScreamRoachScreen mikrofon düğmesi', () {
    Future<void> pumpScream(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = const Size(374, 680);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AudioManager().isMuted = true;
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
      await tester.pumpWidget(wrapWithL10n(const ScreamRoachScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
    }

    testWidgets('önce açıklama diyaloğu, onayda yedek mod + dokunmatik oyun',
        (tester) async {
      await pumpScream(tester);
      expect(find.byTooltip('Bağırarak zıplamayı aç'), findsOneWidget);

      await tester.tap(find.byTooltip('Bağırarak zıplamayı aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // İzin istenmeden önce açıklama + eşik ayarı gösterilir.
      expect(find.text('Bağırarak zıpla?'), findsOneWidget);
      expect(find.textContaining('Çığlık eşiği:'), findsOneWidget);
      expect(find.text('Mikrofonu aç'), findsOneWidget);

      await tester.tap(find.text('Mikrofonu aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Test ortamında yedek mod sessizce devrede: diyalog kapandı,
      // mikrofon simgesi kapalı kalır (ses girişi yok).
      expect(find.text('Bağırarak zıpla?'), findsNothing);
      expect(find.byTooltip('Bağırarak zıplamayı aç'), findsOneWidget);
      expect(service.isFallbackMode, isTrue);
      expect(tester.takeException(), isNull);

      // Dokunmatik oyun yedek modda da çalışır.
      await tester.tapAt(const Offset(190, 390));
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);

      // Kapanış: bekleyen yazı tipi / animasyon geri çağrıları
      // ağaç sökülmeden aksın (ciglik_play_test deseni).
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('açıklama diyaloğunda vazgeçmek mikrofonu açmaz',
        (tester) async {
      await pumpScream(tester);
      await tester.tap(find.byTooltip('Bağırarak zıplamayı aç'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('İptal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Bağırarak zıpla?'), findsNothing);
      expect(service.isListening, isFalse);
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
