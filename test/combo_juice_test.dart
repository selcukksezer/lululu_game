import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/services/adaptive_quality_scaler.dart';
import 'package:lululu_game/services/combo_juice_service.dart';
import 'package:lululu_game/widgets/floating_score_text.dart';
import 'package:lululu_game/widgets/particle_overlay.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ComboJuiceService - Türkçe Viral Kombo Anons ve Çarpan Testleri', () {
    test('Kombo basamakları doğru Türkçe viral başlık ve renkleri üretir', () {
      expect(ComboJuiceService.titleForCombo(1), isNull);

      expect(ComboJuiceService.titleForCombo(2), 'İKİLİ KOMBO!');
      expect(ComboJuiceService.colorForCombo(2), const Color(0xFFFFD54F));

      expect(ComboJuiceService.titleForCombo(3), 'ÜÇLÜ PATLAMA!');
      expect(ComboJuiceService.colorForCombo(3), const Color(0xFFFF9800));

      expect(ComboJuiceService.titleForCombo(4), 'HARİKA EZİŞ!');
      expect(ComboJuiceService.colorForCombo(4), const Color(0xFFFF5722));

      expect(ComboJuiceService.titleForCombo(5), 'EFSANE LÜLÜLÜ!');
      expect(ComboJuiceService.colorForCombo(5), const Color(0xFFE040FB));
      expect(ComboJuiceService.titleForCombo(6), 'EFSANE LÜLÜLÜ!');
      expect(ComboJuiceService.colorForCombo(6), const Color(0xFFE040FB));

      expect(ComboJuiceService.titleForCombo(7), 'OSMAN ÇILDIRDI!');
      expect(ComboJuiceService.colorForCombo(7), const Color(0xFF00E5FF));
      expect(ComboJuiceService.titleForCombo(9), 'OSMAN ÇILDIRDI!');
      expect(ComboJuiceService.colorForCombo(9), const Color(0xFF00E5FF));

      expect(
        ComboJuiceService.titleForCombo(10),
        'MAKARA KOPTU! ULTRA KOMBO!',
      );
      expect(ComboJuiceService.colorForCombo(10), const Color(0xFFFF1744));
      expect(
        ComboJuiceService.titleForCombo(15),
        'MAKARA KOPTU! ULTRA KOMBO!',
      );
      expect(ComboJuiceService.colorForCombo(15), const Color(0xFFFF1744));
    });

    test('Kombo zaman aşımı penceresi (2800ms) ve çarpan (1.0 .. 3.5x) çalışır', () {
      final service = ComboJuiceService();
      expect(service.comboWindowMs, 2800);
      expect(service.comboCount, 0);
      expect(service.comboMultiplier, 1.0);

      // İlk vuruş (t = 1000ms)
      service.registerMerge(tier: 2, nowMs: 1000, triggerFeedback: false);
      expect(service.comboCount, 1);
      expect(service.isComboActive, isFalse);
      expect(service.comboMultiplier, 1.0);

      // Pencere içinde ikinci vuruş (t = 3500ms, fark = 2500ms <= 2800ms)
      service.registerMerge(tier: 3, nowMs: 3500, triggerFeedback: false);
      expect(service.comboCount, 2);
      expect(service.isComboActive, isTrue);
      expect(service.currentTitle, 'İKİLİ KOMBO!');
      expect(service.comboMultiplier, greaterThan(1.0));

      // 10x komboya kadar zincirleme
      var timestamp = 3500;
      for (var i = 3; i <= 12; i++) {
        timestamp += 400;
        service.registerMerge(tier: 4, nowMs: timestamp, triggerFeedback: false);
      }
      expect(service.comboCount, 12);
      expect(service.maxCombo, 12);
      expect(service.comboMultiplier, 3.5);
      expect(service.currentTitle, 'MAKARA KOPTU! ULTRA KOMBO!');

      // 2800ms aşılınca kombo sıfırlanır / 1'den başlar
      final expired = service.checkTimeout(nowMs: timestamp + 2801);
      expect(expired, isTrue);
      expect(service.comboCount, 0);
    });

    test('Sönümlü harmonik kamera sarsıntısı (computeShakeOffset) matematiği', () {
      final service = ComboJuiceService();

      expect(service.computeShakeOffset(0.0, intensity: 10.0), Offset.zero);
      expect(service.computeShakeOffset(1.0, intensity: 10.0), Offset.zero);
      expect(service.computeShakeOffset(0.3, intensity: 0.0), Offset.zero);

      final early = service.computeShakeOffset(0.08, intensity: 12.0);
      final late = service.computeShakeOffset(0.82, intensity: 12.0);

      expect(early.distance, greaterThan(0.0));
      expect(early.distance, greaterThan(late.distance));
    });
  });

  group('ParticleOverlay & Sabit Havuz (maxParticles = 96) Testleri', () {
    test('ParticleOverlayController 96 kapasiteli havuz ve presetleri çalıştırır', () {
      AdaptiveQualityScaler.instance.setTier(QualityTier.high);
      final controller = ParticleOverlayController();
      expect(controller.maxParticles, 96);

      for (final preset in ParticleBurstPreset.values) {
        controller.spawnPreset(
          preset,
          const Offset(180, 320),
          tier: 4,
          combo: 3,
        );
        expect(controller.activeCount, greaterThan(0));
        expect(controller.activeCount, lessThanOrEqualTo(96));
      }

      // Fizik güncellemesi sonrası parçacıklar ilerler ve temizlenir
      controller.update(0.016);
      expect(controller.activeCount, greaterThan(0));

      controller.clear();
      expect(controller.activeCount, 0);
    });

    testWidgets('ParticleOverlay RepaintBoundary ile zero-jank çizilir', (tester) async {
      final controller = ParticleOverlayController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParticleOverlay(
              controller: controller,
              child: const SizedBox(width: 300, height: 500),
            ),
          ),
        ),
      );

      controller.spawnPreset(
        ParticleBurstPreset.electricShock,
        const Offset(150, 250),
        combo: 4,
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(ParticleOverlay), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });
  });

  group('FloatingScoreText & ScreenShakeWrapper Widget Testleri', () {
    testWidgets('FloatingScoreText kritik vuruş ve kombo rozetini gösterir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FloatingScoreText.fromScore(
                points: 450,
                combo: 5,
                isCritical: true,
                comboMultiplier: 2.5,
                subtitle: 'EFSANE LÜLÜLÜ!',
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('KRİTİK VURUŞ!'), findsOneWidget);
      expect(find.text('x2.5 ÇARPAN'), findsOneWidget);
      expect(find.text('EFSANE LÜLÜLÜ!'), findsOneWidget);
    });

    testWidgets('ScreenShakeWrapper kombo tetiklendiğinde sarsıntı uygular', (tester) async {
      final service = ComboJuiceService();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenShakeWrapper(
              service: service,
              child: const Text('ARENA'),
            ),
          ),
        ),
      );

      service.registerMerge(tier: 2, nowMs: 1000, triggerFeedback: false);
      service.registerMerge(tier: 3, nowMs: 1500, triggerFeedback: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('ARENA'), findsOneWidget);
    });
  });

  group('Fixer 14 - GameScreen & Grid2048Screen HUD (<430px) ve Sonuç Modal Testleri', () {
    testWidgets('GameScreen (arcade) 360x640 ve 430x932 çözünürlükte SIRADAKİ taşması olmadan çizilir', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            level: CampaignDatabase.kitchenLevel1,
            arcade: true,
            prototypeVisualState: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('SIRADAKİ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Grid2048Screen 360x640 dar ekranda taşmasız çizilir ve BİTİR tek modal açar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Grid2048Screen(prototypeVisualState: true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('2048 GRİD'), findsOneWidget);
      expect(find.text('BİTİR'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
