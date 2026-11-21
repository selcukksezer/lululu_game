// Dalga 12C — Hışır ses yolu kilidi.
//
// Selçuk'un kulak onayı (2026-11-19 19:49: "evet bu kısım doğru seste")
// sonrası Hışır sesi `hisir_zopa.mp3`'tür. Bu dosya tek yolun
// (`GameAudio.voiceForCharacterId('hisir')`) yeni dosyayı çözdüğünü,
// klibin `viralOneShots`/`allAssets` içinde önceden yüklendiğini ve eski
// aday `husur_aday.mp3`'e kodda artık referans kalmadığını kilitler.
// Eski aday dosyası assets'te duruyor (silme kararı koordinatörde);
// bu test yalnız kod referansını kilitler, dosya varlığını değil.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/services/audio_manager.dart';

void main() {
  test('Hışır sesi hisir_zopa.mp3 dosyasını çözer', () {
    expect(GameAudio.hisirZopa, 'hisir_zopa.mp3');
    expect(GameAudio.voiceForCharacterId('hisir'), 'hisir_zopa.mp3');

    expect(GameAudio.viralOneShots, contains('hisir_zopa.mp3'));
    expect(GameAudio.allAssets, contains('hisir_zopa.mp3'));

    final clip = File('assets/audio/hisir_zopa.mp3');
    expect(clip.existsSync(), isTrue, reason: 'hisir_zopa.mp3 eksik');
    expect(clip.lengthSync(), greaterThan(0));
  });

  test('eski aday husur_aday artık kodda referanslanmıyor', () {
    final source = File('lib/services/audio_manager.dart').readAsStringSync();
    // Kod düzeyinde kilit: eski dosya adı artık bir string literali olarak
    // ve eski sabit adı artık bir bildirim olarak geçmiyor. (Tarihçe
    // notundaki backtick'li `husur_aday.mp3` sözü yorumdur, kod değil.)
    expect(source.contains("'husur_aday.mp3'"), isFalse);
    expect(source.contains('static const husurAday'), isFalse);
    expect(source.contains('GameAudio.husurAday'), isFalse);
  });
}
