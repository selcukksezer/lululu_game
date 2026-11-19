import 'splash_session.dart';

/// Web-dışı platformlar için depolama: "oturum" kavramı yoktur, her soğuk
/// açılışta splash gösterilir. Okuma her zaman `false`, yazma no-op'tur.
SplashSessionStorage createSplashSessionStorage() =>
    _StubSplashSessionStorage();

class _StubSplashSessionStorage implements SplashSessionStorage {
  @override
  bool get splashSeen => false;

  @override
  void markSplashSeen() {}
}
