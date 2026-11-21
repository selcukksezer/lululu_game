import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'insect_tier.dart';

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

  /// Hışır'ın 11 modda da nadir böcek olarak belirme olasılığı.
  ///
  /// Terlik Tap'teki mevcut %8 cameo aynen kalır; diğer modlarda tek
  /// olasılık buradan okunur (modlara gömülü magic number yok).
  static const double spawnChance = 0.05;

  /// Terlik Tap'teki mevcut Hışır olasılığı (%8) — aynen korunur;
  /// diğer modlar [spawnChance] (%5) kullanır.
  static const double terlikSpawnChance = 0.08;

  /// Test dikişi: `true` iken [roll] her zaman `true` döner; widget
  /// testleri Hışır'ı zorla belirtebilir. Üretimde `false` kalır.
  @visibleForTesting
  static bool debugForceHisir = false;

  /// [spawnChance] olasılığıyla `true` döner.
  static bool roll(math.Random rng, {double chance = spawnChance}) {
    if (debugForceHisir) return true;
    return rng.nextDouble() < chance;
  }

  /// Izgara (int) tabanlı modlarda Hışır derisi kodlaması: Hışır
  /// görünümlü bir hücre, yerini aldığı kademe + [gridValueOffset]
  /// değerini taşır. Kademe 1..13, bomba/Match3 bias'ı en fazla 10
  /// olduğundan 100 hiçbir meşru değerle çakışmaz; eşleşme/birleşme/
  /// skor her zaman [baseTier] üzerinden okunur, denge bozulmaz.
  static const int gridValueOffset = 100;

  /// [tier] (1..13) Hışır olarak belirirse kodlanmış ızgara değeri,
  /// yoksa [tier] aynen.
  static int encodeGridValue(int tier, math.Random rng) =>
      roll(rng) ? tier + gridValueOffset : tier;

  /// Kodlanmış (Hışır) değerler dahil her ızgara değerinin kademesi.
  static int baseTier(int value) =>
      value > gridValueOffset ? value - gridValueOffset : value;

  /// [value] Hışır kodlu bir hücre mi?
  static bool isEncoded(int value) => value > gridValueOffset;

  /// Görsel: Hışır ise [assetPath], değilse [tier] görseli.
  static String assetFor({required bool isHisir, required InsectTier tier}) =>
      isHisir ? assetPath : tier.assetPath;
}
