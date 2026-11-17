import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Boots Firebase when options are configured; otherwise stays local-only
/// with zero crashes and automatic local persistence fallback.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;
  static bool isLocalFallback = true;
  static String status = 'Yerel · bulut kuyruğu hazır';
  static String? lastError;

  static final ValueNotifier<bool> availableNotifier =
      ValueNotifier<bool>(false);

  /// Cloud availability flag for Offline-First + Cloud-Ready services.
  static bool get isAvailable => ready;
  static set isAvailable(bool value) {
    ready = value;
    isLocalFallback = !value;
    availableNotifier.value = value;
  }

  /// Player-facing copy — never show dart-define jargon in UI.
  static String get playerStatus {
    if (ready) return status;
    if (kDebugMode && !DefaultFirebaseOptions.isConfigured) {
      return 'Yerel · bulut kuyruğu hazır';
    }
    if (status.contains('dart-define') ||
        status.contains('Firebase init') ||
        status.contains('Exception')) {
      return 'Yerel · bulut kuyruğu hazır';
    }
    return status;
  }

  /// Safely initializes Firebase on real devices and falls back cleanly
  /// in offline, simulator, or widget-test environments.
  static Future<bool> ensureInitialized() async {
    if (ready) return true;
    if (!DefaultFirebaseOptions.isConfigured) {
      ready = false;
      isLocalFallback = true;
      availableNotifier.value = false;
      status = 'Yerel · bulut kuyruğu hazır';
      debugPrint('[lululu] Firebase dart-define yok · yerel cloud kuyruğu');
      return false;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      ready = true;
      isLocalFallback = false;
      lastError = null;
      availableNotifier.value = true;
      status =
          'Firebase bağlı · ${DefaultFirebaseOptions.currentPlatform.projectId}';
      return true;
    } catch (e) {
      ready = false;
      isLocalFallback = true;
      lastError = e.toString();
      availableNotifier.value = false;
      status = 'Firebase init hata · yerel mod ($e)';
      debugPrint('[lululu] $status');
      return false;
    }
  }

  /// Resets state for isolated unit/widget tests.
  static void resetForTest() {
    ready = false;
    isLocalFallback = true;
    lastError = null;
    availableNotifier.value = false;
    status = 'Yerel · bulut kuyruğu hazır';
  }
}
