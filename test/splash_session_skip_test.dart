import 'package:flutter_test/flutter_test.dart';
import 'package:lululu_game/services/splash_session.dart';

/// Bellek içi sahte depolama: web `sessionStorage`'ın test ikizi.
/// Sekme yenileme senaryosu, aynı sahte örneğin iki okuması arasında
/// bayrağın korunmasıyla modellenir.
class FakeSplashSessionStorage implements SplashSessionStorage {
  bool _seen = false;

  @override
  bool get splashSeen => _seen;

  @override
  void markSplashSeen() {
    _seen = true;
  }
}

/// Hata fırlatan depolama: engelli tarayıcı depolamasını modeller.
class ThrowingSplashSessionStorage implements SplashSessionStorage {
  @override
  bool get splashSeen => throw StateError('depolama engelli');

  @override
  void markSplashSeen() {
    throw StateError('depolama engelli');
  }
}

void main() {
  tearDown(() => SplashSession.debugOverrideStorage(null));

  test('bayrak yokken splash gösterilir (isSeen false)', () {
    SplashSession.debugOverrideStorage(FakeSplashSessionStorage());
    expect(SplashSession.isSeen, isFalse);
  });

  test('markSeen sonrası aynı oturumda splash atlanır (isSeen true)', () {
    final storage = FakeSplashSessionStorage();
    SplashSession.debugOverrideStorage(storage);
    SplashSession.markSeen();
    // Aynı depolama örneği = aynı oturum: bayrak korunur.
    expect(SplashSession.isSeen, isTrue);
    expect(storage.splashSeen, isTrue);
  });

  test('yeni oturumda (yeni depolama) bayrak yoktur', () {
    final firstSession = FakeSplashSessionStorage();
    SplashSession.debugOverrideStorage(firstSession);
    SplashSession.markSeen();
    expect(SplashSession.isSeen, isTrue);

    // Yeni sekme/oturum = yeni depolama örneği: bayrak taşınmaz.
    SplashSession.debugOverrideStorage(FakeSplashSessionStorage());
    expect(SplashSession.isSeen, isFalse);
  });

  test('okuma hatasında güvenli varsayılan: splash gösterilir', () {
    SplashSession.debugOverrideStorage(ThrowingSplashSessionStorage());
    expect(SplashSession.isSeen, isFalse);
  });

  test('yazma hatası fırlatmaz, boot akışını bozmaz', () {
    SplashSession.debugOverrideStorage(ThrowingSplashSessionStorage());
    expect(SplashSession.markSeen, returnsNormally);
  });

  test('bayrak anahtarı oturum bayrağı olduğunu açıkça söyler', () {
    expect(SplashSession.flagKey, 'lululu_splash_seen_session');
  });

  test('test ortamında (web-dışı stub) varsayılan davranış: splash gösterilir',
      () {
    SplashSession.debugOverrideStorage(null);
    expect(SplashSession.isSeen, isFalse);
  });
}
