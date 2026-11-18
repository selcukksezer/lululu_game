import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/services/anti_cheat_service.dart';
import 'package:lululu_game/services/app_lifecycle_guard.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/cloud_sync_service.dart';
import 'package:lululu_game/services/game_telemetry_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GameTelemetryService.instance.reset();
    AppLifecycleGuard.instance.resetForTesting();
    AntiCheatService.instance.resetRewardHistory();
    AudioManager.instance.isMuted = false;
    AudioManager.instance.sfxEnabled = true;
    CloudSyncService.instance.pending.clear();
  });

  group('GameTelemetryService — 120FPS, P99, Jank & Ring Buffer Tests', () {
    test('calculates average FPS, P99 frame time, and 120Hz/60Hz jank counts',
        () {
      final telemetry = GameTelemetryService.instance;

      // 98 frames at ~120 FPS (4ms build + 3ms raster = 7ms <= 8.33ms)
      for (var i = 0; i < 98; i++) {
        telemetry.recordFrameTiming(
          const Duration(milliseconds: 4),
          const Duration(milliseconds: 3),
        );
      }

      // 1 frame with mild jank (> 8.33ms, <= 16.67ms): 6ms + 5ms = 11ms
      telemetry.recordFrameTiming(
        const Duration(milliseconds: 6),
        const Duration(milliseconds: 5),
      );

      // 1 frame with severe jank (> 16.67ms): 12ms + 10ms = 22ms
      telemetry.recordFrameTiming(
        const Duration(milliseconds: 12),
        const Duration(milliseconds: 10),
      );

      expect(telemetry.totalFramesRecorded, 100);
      expect(telemetry.bufferedFrameCount, 100);

      // 2 frames exceeded 8.33ms (11ms and 22ms)
      expect(telemetry.jankCount120Hz, 2);
      // 1 frame exceeded 16.67ms (22ms)
      expect(telemetry.jankCount60Hz, 1);
      expect(telemetry.jankCount, 1);

      // P99 of 100 samples (index 98 -> 99th value is 11.0ms, 100th is 22.0ms)
      expect(telemetry.p99FrameTimeMs, closeTo(11.0, 0.01));
      expect(telemetry.p95FrameTimeMs, closeTo(7.0, 0.01));

      // Average frame time = (98*7 + 11 + 22) / 100 = 7.19ms -> ~120 FPS (clamped at 120)
      expect(telemetry.averageFrameTimeMs, closeTo(7.19, 0.01));
      expect(telemetry.averageFps, closeTo(120.0, 0.01));
    });

    test('enforces fixed ring-buffer limit of 200 entries without memory leak',
        () {
      final telemetry = GameTelemetryService.instance;

      for (var i = 1; i <= 260; i++) {
        telemetry.recordFrameTiming(
          Duration(microseconds: 3000 + i),
          const Duration(microseconds: 2000),
        );
        telemetry.recordBreadcrumb(
          'gameplay',
          'step_$i',
          meta: <String, Object?>{'index': i},
        );
      }

      expect(telemetry.totalFramesRecorded, 260);
      expect(
        telemetry.bufferedFrameCount,
        GameTelemetryService.maxRingBufferSize,
      );
      expect(telemetry.frameSamples.length, 200);

      expect(telemetry.totalBreadcrumbsRecorded, 260);
      expect(
        telemetry.bufferedBreadcrumbCount,
        GameTelemetryService.maxRingBufferSize,
      );
      expect(telemetry.breadcrumbs.length, 200);

      // Oldest 60 entries (1..60) must be evicted; first buffered is step_61, last is step_260
      expect(telemetry.breadcrumbs.first.action, 'step_61');
      expect(telemetry.breadcrumbs.last.action, 'step_260');
      expect(telemetry.frameSamples.first.buildDuration.inMicroseconds, 3061);
      expect(telemetry.frameSamples.last.buildDuration.inMicroseconds, 3260);
    });

    test('records mode start, shop purchase, booster use, error & exports summary',
        () {
      final telemetry = GameTelemetryService.instance;

      telemetry.recordModeStart('suika', levelId: 5);
      telemetry.recordPurchase('f16_x3', cost: 450, success: true);
      telemetry.recordBoosterUse('f16', modeId: 'suika', remainingCount: 2);
      telemetry.recordError(
        StateError('physics_overflow'),
        stackTrace: StackTrace.current,
      );

      final summary = telemetry.exportDiagnosticsSummary();
      expect(summary['ringBufferCapacity'], 200);

      final breadcrumbsMap = summary['breadcrumbs'] as Map<String, Object?>;
      expect(breadcrumbsMap['bufferedCount'], 4);
      expect(breadcrumbsMap['errorCount'], 1);

      final items = breadcrumbsMap['items'] as List<Object?>;
      expect(items.length, 4);

      final jsonReport = telemetry.exportDiagnosticsJson();
      expect(jsonReport, contains('physics_overflow'));
      expect(jsonReport, contains('f16_x3'));
    });
  });

  group('AppLifecycleGuard — Lifecycle, Audio Pause & Accessibility Tests', () {
    test('pauses AudioManager, triggers auto-pause & syncs on background/call',
        () async {
      final guard = AppLifecycleGuard.instance;
      final audio = AudioManager.instance;
      final cloud = CloudSyncService.instance;

      expect(audio.isMuted, isFalse);
      expect(guard.shouldAutoPauseGame, isFalse);

      final t0 = DateTime.utc(2026, 11, 4, 18, 0, 0);
      await guard.onAppPaused(reason: 'incoming_call', timestamp: t0);

      expect(guard.shouldAutoPauseGame, isTrue);
      expect(guard.isAudioPausedByLifecycle, isTrue);
      expect(audio.isMuted, isTrue);
      expect(guard.pauseCount, 1);
      expect(guard.syncTriggerCount, 1);
      expect(
        cloud.pending.any((tag) => tag.startsWith('progress:')),
        isTrue,
      );

      // Resume after 45 seconds
      final t1 = t0.add(const Duration(seconds: 45));
      await guard.onAppResumed(timestamp: t1);

      expect(guard.currentState, AppLifecycleState.resumed);
      expect(guard.isAudioPausedByLifecycle, isFalse);
      expect(audio.isMuted, isFalse);
      expect(guard.lastBackgroundDuration, const Duration(seconds: 45));
      expect(guard.isSessionValid, isTrue);
      expect(guard.lastSessionValidationReason, 'ok');

      // Game remains paused until user acknowledges pause dialog
      expect(guard.shouldAutoPauseGame, isTrue);
      guard.acknowledgeAutoPause();
      expect(guard.shouldAutoPauseGame, isFalse);
    });

    test('detects clock rollback and expired background sessions on resume',
        () async {
      final guard = AppLifecycleGuard.instance;
      final t0 = DateTime.utc(2026, 11, 4, 18, 0, 0);

      await guard.onAppPaused(timestamp: t0);

      // Simulate clock rollback (resumed timestamp earlier than paused timestamp)
      await guard.onAppResumed(
        timestamp: t0.subtract(const Duration(minutes: 5)),
      );
      expect(guard.isSessionValid, isFalse);
      expect(guard.lastSessionValidationReason, 'clock_rollback_detected');

      // Simulate expired session (> 6 hours in background)
      await guard.onAppPaused(timestamp: t0);
      await guard.onAppResumed(
        timestamp: t0.add(const Duration(hours: 7)),
      );
      expect(guard.isSessionValid, isFalse);
      expect(guard.lastSessionValidationReason, 'session_expired');
    });

    test('handles WidgetsBindingObserver didChangeAppLifecycleState transitions',
        () async {
      final guard = AppLifecycleGuard.instance;

      guard.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await Future<void>.delayed(Duration.zero);
      expect(guard.isInBackground, isTrue);
      expect(guard.shouldAutoPauseGame, isTrue);
      expect(AudioManager.instance.isMuted, isTrue);

      guard.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(guard.isInBackground, isFalse);
      expect(guard.currentState, AppLifecycleState.resumed);
      expect(AudioManager.instance.isMuted, isFalse);
    });

    test('persists and reloads AccessibilityPreferences via SharedPreferences',
        () async {
      final guard = AppLifecycleGuard.instance;

      expect(guard.reducedMotion, isFalse);
      expect(guard.highContrast, isFalse);
      expect(guard.colorblindAssist, isFalse);
      expect(guard.largeTouchTargets, isFalse);
      expect(guard.accessibility.touchTargetScale, 1.0);

      await guard.setReducedMotion(true);
      await guard.setHighContrast(true);
      await guard.setColorblindAssist(true);
      await guard.setLargeTouchTargets(true);

      expect(guard.reducedMotion, isTrue);
      expect(guard.highContrast, isTrue);
      expect(guard.colorblindAssist, isTrue);
      expect(guard.largeTouchTargets, isTrue);
      expect(guard.accessibility.touchTargetScale, 1.25);
      expect(guard.accessibility.minTouchTargetSize, 56.0);
      expect(guard.accessibility.animationDurationScale, 0.25);
      expect(guard.accessibility.symbolForTier(1), isNotEmpty);
      expect(
        guard.accessibility.symbolForTier(1),
        isNot(equals(guard.accessibility.symbolForTier(2))),
      );

      // Reset in-memory state and reload from SharedPreferences
      guard.resetForTesting();
      expect(guard.reducedMotion, isFalse);

      final loaded = await guard.loadAccessibilityPreferences();
      expect(loaded.reducedMotion, isTrue);
      expect(loaded.highContrast, isTrue);
      expect(loaded.colorblindAssist, isTrue);
      expect(loaded.largeTouchTargets, isTrue);
    });
  });

  group('ProgressManager & AntiCheatService End-to-End Integration', () {
    test('validates mode scores, economy transactions, state signature & telemetry',
        () async {
      final pm = ProgressManager.instance;
      final antiCheat = AntiCheatService.instance;
      final telemetry = GameTelemetryService.instance;

      await pm.load();
      final initialCoins = pm.coins;

      // 1. Mode start & valid score validation
      telemetry.recordModeStart('suika', levelId: 1);
      final validScoreCheck = antiCheat.validateGameScore(
        'suika',
        14500,
        elapsed: const Duration(seconds: 45),
      );
      expect(validScoreCheck.isValid, isTrue);
      expect(validScoreCheck.sanitizedScore, 14500);

      final recorded = await pm.recordModeScore(
        'suika',
        validScoreCheck.sanitizedScore,
      );
      expect(recorded, isTrue);
      expect(pm.modeHighScores['suika'], 14500);
      expect(pm.verifyStateIntegrity(), isTrue);

      // 2. Reject impossible/cheated score spike
      final cheatedScoreCheck = antiCheat.validateGameScore(
        'suika',
        9999999,
        elapsed: const Duration(seconds: 2),
      );
      expect(cheatedScoreCheck.isValid, isFalse);

      // 3. Valid coin grant + booster purchase + booster consumption + telemetry
      final coinCheck = antiCheat.validateCoinDelta(
        500,
        currentBalance: pm.coins,
      );
      expect(coinCheck.isValid, isTrue);
      await pm.addCoins(coinCheck.sanitizedDelta);
      expect(pm.coins, initialCoins + 500);

      final f16Before = pm.f16Count;
      final bought = await pm.buyBooster('f16', 200);
      expect(bought, isTrue);
      expect(pm.f16Count, f16Before + 1);
      telemetry.recordPurchase('f16', cost: 200, success: bought);

      final consumed = await pm.useBooster('f16');
      expect(consumed, isTrue);
      expect(pm.f16Count, f16Before);
      telemetry.recordBoosterUse('f16', modeId: 'suika', remainingCount: pm.f16Count);

      // 4. Verify HMAC state signature via AntiCheatService
      final statePayload = antiCheat.buildStatePayload(
        coins: pm.coins,
        energy: 5,
        highScore: pm.modeHighScores['suika'] ?? 0,
        modeHighScores: pm.modeHighScores,
        unlockedTiers: pm.unlockedTiers,
        powerCounts: <String, int>{
          'raid': pm.raidCount,
          'terlik': pm.terlikCount,
          'f16': pm.f16Count,
        },
      );
      final signature = antiCheat.computeStateSignature(statePayload);
      expect(antiCheat.verifyStateSignature(statePayload, signature), isTrue);

      // Tampering with coins invalidates HMAC signature
      final tamperedState = Map<String, dynamic>.from(statePayload)
        ..['coins'] = 9999999;
      expect(antiCheat.verifyStateSignature(tamperedState, signature), isFalse);

      // 5. Verify diagnostics summary captures the full flow
      final summary = telemetry.exportDiagnosticsSummary();
      final crumbs =
          (summary['breadcrumbs'] as Map<String, Object?>)['items'] as List<Object?>;
      expect(crumbs.length, 3);
    });
  });
}
