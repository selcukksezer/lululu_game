/// Hışır — viral "hışır" böcek karakteri.
///
/// Tier dışı özel karakter: Osmantuş kişilerindeki kalıbı izler (sabit
/// kimlik + görsel + replik, ses `GameAudio.voiceForCharacterId` üzerinden
/// 'hisir' kimliğiyle çözülür). InsectTier enum'una eklenmedi: 13 tier'lık
/// birleşme zinciri, testler ve skor dengesi aynen korundu.
///
/// Sesi: GameAudio.hisirZopa — ONAYLI Hışır sesi (Selçuk kulakla onayladı,
/// 2026-11-19 19:49): sim_bocekalem.i_7706225030606146834, 16.6–22.1 sn,
/// "Gemü'ne sıçtığımın garısı, şimdi şahadet getir, sonra zopayı getir".
/// Eski aday `husur_aday.mp3` artık kullanılmıyor; bu dosya değişmez.
///
/// Görsel: Hışır'a özel üretildi (`assets/design/bugs_hd/hisir_hd.png`) —
/// kasketli köy dedesi (kırışık yüz, yelek, baston), videolardaki gerçekçi
/// tarzda, şeffaf zeminli. Selçuk'un seçimi (2026-11-17).
class HisirCharacter {
  HisirCharacter._();

  /// `GameAudio.voiceForCharacterId` içindeki karakter kimliği.
  static const id = 'hisir';

  static const displayName = 'Hışır';

  static const replik = 'Hışır hışır!';

  /// Hışır'a özel görsel (şeffaf zeminli).
  static const assetPath = 'assets/design/bugs_hd/hisir_hd.png';

  static const lines = <String>['Hışır hışır!', 'Hışır!'];
}
