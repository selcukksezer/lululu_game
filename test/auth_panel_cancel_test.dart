// 2E-(a): AuthPanel Apple/Google iptal sessizliği sözleşme testleri.
//
// Davranışsal widget testi mümkün değil: `_signInProvider`, enjeksiyon
// noktası olmayan `AuthService.instance` singleton'ını doğrudan çağırır
// ve iptal, yerel sağlayıcı SDK'larından (SignInWithApple / GoogleSignIn)
// gelir; iptali taklit edecek dikiş yok. Sözleşme bu yüzden
// `store_readiness_test.dart` desenindeki gibi kaynak okuyarak kilitlenir:
// sessiz dal var, genel catch'ten önce gelir, hata bandına yazmaz,
// `_busy` sıfırlar; diğer hatalar mevcut davranışta kalır.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/services/auth_service.dart';

void main() {
  final Directory projectRoot = _resolveProjectRoot();
  late String panelSource;
  late String providerBody;

  setUpAll(() {
    panelSource = File(
      '${projectRoot.path}/lib/widgets/auth_panel.dart',
    ).readAsStringSync();
    final start = panelSource.indexOf('Future<void> _signInProvider(');
    final end = panelSource.indexOf(
      '@override\n  Widget build(',
      start,
    );
    expect(start, isNot(-1));
    expect(end, greaterThan(start));
    providerBody = panelSource.substring(start, end);
  });

  test('iptal istisnası nötr ileti taşır (genel catch bandına yazardı)', () {
    const cancelled = AuthSignInCancelledException(
      provider: AuthProviderKind.google,
    );
    expect(cancelled.toString(), 'Giriş iptal edildi');
    expect(cancelled.message, 'Giriş iptal edildi');
  });

  test('_signInProvider iptal için sessiz dal içerir, genel catchten önce', () {
    final cancelIndex = providerBody.indexOf(
      'on AuthSignInCancelledException',
    );
    final catchIndex = providerBody.indexOf('} catch (e) {');
    expect(cancelIndex, isNot(-1));
    expect(catchIndex, isNot(-1));
    expect(cancelIndex, lessThan(catchIndex));
  });

  test('sessiz dal: busy sıfırlanır, hata bandı yazılmaz, form açık kalır', () {
    final cancelIndex = providerBody.indexOf(
      'on AuthSignInCancelledException',
    );
    final catchIndex = providerBody.indexOf('} catch (e) {');
    final silentBranch = providerBody.substring(cancelIndex, catchIndex);
    expect(silentBranch, contains('_busy = false'));
    expect(silentBranch, contains('_error = null'));
    expect(silentBranch, isNot(contains('_error = e')));
    expect(silentBranch, isNot(contains('onSuccess')));
  });

  test('diğer hatalar mevcut davranışta: genel catch hata bandına yazar', () {
    final catchIndex = providerBody.indexOf('} catch (e) {');
    final genericCatch = providerBody.substring(catchIndex);
    expect(genericCatch, contains('_busy = false'));
    expect(genericCatch, contains('_error = e'));
  });

  test('kapsam: iptal dalı dosyada tek adet (yalnız sağlayıcı yolu)', () {
    final matches =
        'on AuthSignInCancelledException'.allMatches(panelSource);
    expect(matches.length, 1);
  });

  test('referans desen sağlam: auth_screen _run da sessiz dal içerir', () {
    final screenSource = File(
      '${projectRoot.path}/lib/screens/auth_screen.dart',
    ).readAsStringSync();
    expect(screenSource, contains('on AuthSignInCancelledException'));
  });
}

Directory _resolveProjectRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) {
    return cwd;
  }
  final sub = Directory('${cwd.path}/lululu_game');
  if (File('${sub.path}/pubspec.yaml').existsSync()) {
    return sub;
  }
  return Directory('/Users/selcuk/Documents/lululu/lululu_game');
}
