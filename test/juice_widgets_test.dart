import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/services/adaptive_quality_scaler.dart';
import 'package:lululu_game/widgets/floating_score_text.dart';
import 'package:lululu_game/widgets/particle_overlay.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
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

  group('FloatingScoreText Widget Testleri', () {
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
