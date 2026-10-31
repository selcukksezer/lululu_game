import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Boots Firebase when options are configured; otherwise stays local-only.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool ready = false;
  static String status = 'Yerel · bulut kuyruğu hazır';

  /// Player-facing copy — never show dart-define jargon in UI.
  static String get playerStatus {
    if (ready) return status;
    if (kDebugMode && !DefaultFirebaseOptions.isConfigured) {
      return 'Yerel · bulut kuyruğu hazır';
    }
    if (status.contains('dart-define') || status.contains('Firebase init')) {
      return 'Yerel · bulut kuyruğu hazır';
    }
    return status;
  }

  static Future<bool> ensureInitialized() async {
    if (ready) return true;
    if (!DefaultFirebaseOptions.isConfigured) {
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
      status = 'Firebase bağlı · ${DefaultFirebaseOptions.currentPlatform.projectId}';
      return true;
    } catch (e) {
      ready = false;
      status = 'Firebase init hata · yerel mod ($e)';
      debugPrint('[lululu] $status');
      return false;
    }
  }
}
