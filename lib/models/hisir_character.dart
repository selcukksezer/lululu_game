/// Hışır — viral "hışır" böcek karakteri.
///
/// Tier dışı özel karakter: Osmantuş kişilerindeki kalıbı izler (sabit
/// kimlik + görsel + replik, ses `GameAudio.voiceForCharacterId` üzerinden
/// 'hisir' kimliğiyle çözülür). InsectTier enum'una eklenmedi: 13 tier'lık
/// birleşme zinciri, testler ve skor dengesi aynen korundu.
///
/// Sesi: GameAudio.husurAday — DOĞRULANMAMIŞ adaydır; transkriptte "huşur"
/// diye geçti, "hışır" olduğu kulakla teyit edilmedi. Teyit gelince ya da
/// gerçek "hışır" klibi kesilince ses dosyası/sabit değişir, bu dosya değişmez.
///
/// Görsel GEÇİCİ: Hışır'a özel çizim yok; tier1 (Bebek Huni) görseli ödünç
/// alınır. Özel görsel gelince yalnız [assetPath] değiştirilecek.
class HisirCharacter {
  HisirCharacter._();

  /// `GameAudio.voiceForCharacterId` içindeki karakter kimliği.
  static const id = 'hisir';

  static const displayName = 'Hışır';

  static const replik = 'Hışır hışır!';

  /// GEÇİCİ görsel (tier1 ödünç). Özel çizim gelince değiştirilecek.
  static const assetPath = 'assets/design/bugs_hd/tier1_hd.png';

  static const lines = <String>['Hışır hışır!', 'Hışır!'];
}
