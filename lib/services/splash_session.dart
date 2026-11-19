import 'package:flutter/foundation.dart';

import 'splash_session_stub.dart'
    if (dart.library.js_interop) 'splash_session_web.dart' as impl;

/// Oturum bazlı splash bayrağı (12H-splash).
///
/// Aynı tarayıcı oturumunda (sekme yenilemede) splash atlanır, yeni
/// oturumda/sekmede yine gösterilir. Bayrak `sessionStorage`'da tutulur:
/// sekme kapanınca silinir, yenilemede yaşar. `SharedPreferences`
/// kalıcı olur — bilerek kullanılmaz.
///
/// Web-dışı platformlarda (mobil) "oturum" kavramı yoktur: her soğuk
/// açılışta splash gösterilir (stub depolama her zaman `false` döner).
/// Okuma/yazma hatası güvenli varsayılanla karşılanır: bayrak
/// okunamazsa splash gösterilir, yazılamazsa sessizce yoksayılır.
abstract class SplashSessionStorage {
  /// Oturumda splash daha önce tamamlandıysa `true`.
  bool get splashSeen;

  /// Splash tamamlandı olarak işaretle.
  void markSplashSeen();
}

/// Splash oturum bayrağına erişim noktası.
class SplashSession {
  SplashSession._();

  /// `sessionStorage` anahtarı. Adı açık tutulur: oturum bayrağı olduğu
  /// kalıcı bir tercihle karıştırılmasın.
  static const String flagKey = 'lululu_splash_seen_session';

  static final SplashSessionStorage _storage =
      impl.createSplashSessionStorage();

  static SplashSessionStorage? _debugOverride;

  /// Yalnızca testler için: depolamayı sahte bir uygulamayla değiştir.
  /// `null` verilirse gerçek depolamaya dönülür.
  @visibleForTesting
  static void debugOverrideStorage(SplashSessionStorage? storage) {
    _debugOverride = storage;
  }

  /// Oturumda splash daha önce tamamlandıysa `true`. Okuma hatasında
  /// `false` döner (splash gösterilir — güvenli varsayılan).
  static bool get isSeen {
    try {
      return (_debugOverride ?? _storage).splashSeen;
    } catch (_) {
      return false;
    }
  }

  /// Splash tamamlandı olarak işaretle. Yazma hatası sessizce yoksayılır.
  static void markSeen() {
    try {
      (_debugOverride ?? _storage).markSplashSeen();
    } catch (_) {
      // Bayrak yazılamazsa (örn. depolama engelli) sonraki açılışta
      // splash yine gösterilir; boot akışı etkilenmez.
    }
  }
}
