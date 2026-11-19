import 'package:web/web.dart';

import 'splash_session.dart';

/// Web depolaması: bayrak `sessionStorage`'da tutulur — sekme yenilemede
/// yaşar, sekme/oturum kapanınca silinir. Tarayıcı depolamayı engellerse
/// (örn. gizli mod kısıtı) okuma `false`, yazma no-op olur.
SplashSessionStorage createSplashSessionStorage() =>
    _WebSplashSessionStorage();

class _WebSplashSessionStorage implements SplashSessionStorage {
  @override
  bool get splashSeen {
    try {
      return window.sessionStorage.getItem(SplashSession.flagKey) == '1';
    } catch (_) {
      return false;
    }
  }

  @override
  void markSplashSeen() {
    try {
      window.sessionStorage.setItem(SplashSession.flagKey, '1');
    } catch (_) {
      // Yazılamazsa sonraki açılışta splash yine gösterilir.
    }
  }
}
