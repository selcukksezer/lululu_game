# LÜLÜLÜ — Play Store Listing Draft (TASLAK)

> **TASLAK ONLY — store işlemi yapılmadı.** Bu dosya yalnızca metin taslağıdır;
> Play Console'a girilmedi, gönderilmedi. Hazırlayan: W10-6 (ÇEKİRDEK-WEB),
> 2026-11-18 gece çalışması. Tüm doğrular `README.md` + koddan alındı, uydurma
> yok — kaynaklar en alttaki TR notlarında dosya:satır kanıtlıdır.

---

## Title (Play limiti: 30 karakter)

**A — önerilen (29 karakter):**

```text
LÜLÜLÜ: Cockroach Merge Mania
```

**B — saf marka (6 karakter, Selçuk isterse):**

```text
LÜLÜLÜ
```

Not: Uygulama içi marka adı her yerde tek biçim `LÜLÜLÜ` kalır (manifest,
plist, web başlığı, `MaterialApp.title`). A seçeneğindeki İngilizce tanımlayıcı
yalnızca mağaza listeleme başlığında keşfedilebilirlik içindir.

---

## Short description (Play limiti: 80 karakter, bu metin 69 karakter)

```text
Merge cockroaches, evolve 13 tiers, and play 11 arcade modes. LÜLÜLÜ!
```

---

## Full description (Play limiti: 4000 karakter, bu metin 1872 karakter)

```text
🪳 LÜLÜLÜ is here! The viral cockroach craze meets Suika-style merge madness.

Drop cockroaches into the jar, bump matching bugs together, and evolve them through 13 hilarious tiers — from Baby Huni all the way to the Pink-Robed peak. Every merge pops with a viral Turkish voice line: "Lülülü bebek!", "Makarayız abi!", "Ben divayım ayol!"

EVOLVE 13 TIERS
Merge two of the same bug to evolve to the next tier. 13 tiers in one chain: Bebek Huni, Tencereli Çırak, Makaracı Fan, Pijamalı Dansçı, Hamam Diva, Hamam Can, Kongo Lideri, Hasta Bilge, Millî Formalı, Pembe Ceketli, Beyaz Hayalet, Gri Tişörtlü, Pembe Bornozlu.

MEET HIŞIR
Hışır, the flat-capped village grandpa, is a special guest outside the 13-tier chain. Watch for him as a rare special target in Terlik Tap!

11 ARCADE MODES
• Suika Arena — the drop-and-merge classic
• 2048 Grid — slide and merge on a 4x4 board
• Balloon Pop — aim and pop 3 matching balloons
• Match 3 — swap neighbours, blast 3 in a row
• Connect Blast — draw a chain of the same bug
• Stack Drop — drop swaying blocks in a perfect tower
• Slipper Tap (Terlik Tap) — slap what pops out of the holes, dodge the bombs
• Nest Defense (Yuva Savunması) — protect the cake
• Osmantuş — catch the shrinking ring on the green line
• Scream Bug (Çığlık Böcek) — shout into the microphone, or hold, to fly through the gates
• Makarayız — catch rhythm notes on the beat

80 CAMPAIGN LEVELS
Play through 4 chapters of 20 levels, each with its own target score and star ratings.

PLAY YOUR WAY
• Play as a guest — no account needed. Your progress is saved on your device.
• Sign in to sync scores and chat with other players.
• Compare your best scores across all 11 modes on the leaderboards.
• Power-ups: Raid Spray clears small bugs; Slipper Shake shakes the jar loose.
• Optional in-app purchases (coin packs and boosters).

LÜLÜLÜ — merge them all!
```

---

## TR notları (Selçuk / koordinatör için)

### Kaynaklar (uydurma yok — her iddia aşağıdakilerden)

- 13 kademe, kademe adları, replikler, 11 mod ve mod açıklamaları, güçlendiriciler,
  yerel rekor kaydı: `README.md` §1–§3.
- 80 seviye / 4 bölüm / bölüm başı 20: `lib/models/campaign_level.dart:282,285,286`
  (`totalLevels = 80`, `chapterCount = 4`, `levelsPerChapter = 20`); seviye başına
  hedef skor + yıldız eşikleri `test/store_readiness_test.dart` grup 2'de denetleniyor.
  Not: kodda ayrıca 8 temalı bölüm × 10 seviye sistemi vardır
  (`themedChapterCount = 8`, `levelsPerThemedChapter = 10`,
  `lib/models/campaign_level.dart:289,290`); 4×20 kampanya haritası ekranının
  gruplamasıdır (`lib/screens/campaign_map_screen.dart:29`), 8×10 ise ilerleme
  servisinin (`lib/services/campaign_progression_service.dart`) ve
  `CampaignDatabase` temalı bölüm sorgularının (`getLevelsForThemedChapter`)
  gruplamasıdır. Listeleme metni harita ekranının
  4 bölüm sunumunu kullanır.
- Hışır: kademe dışı özel karakter, kasketli köy dedesi —
  `lib/models/hisir_character.dart` + `README.md` §1 notu; Terlik Tap'te nadir özel
  hedef — `lib/modes/terlik_tap_screen.dart:466` ("~8% Hışır özel hedefi").
- Misafir oyunu + cihazda kayıt + çevrimdışı-öncelikli: `lib/services/auth_service.dart:179`
  ("Offline-First + Cloud-Ready") ve `:1170` (`signInAsGuest`); ilerleme
  `shared_preferences` ile cihazda (`README.md` §3). Bulut eşitleme yalnızca giriş
  yapınca ve Firebase yapılandırılmışken (`lib/screens/privacy_policy_screen.dart` §2).
- Liderlik tablosu 11 mod: `LeaderboardService.allModeIds.length == 11`
  (`test/store_readiness_test.dart` grup 1'de denetleniyor).
- Uygulama içi satın alma: `IapService` 3 coin paketi + mağaza kataloğu
  (`test/store_readiness_test.dart` grup 1'de denetleniyor).

### Bilerek YAZILMAYANLAR (doğrulanmadı / uydurma olurdu)

- **"Tamamen çevrimdışı" iddiası yok.** Taslakta yalnızca "misafir oyna, ilerleme
  cihazında saklanır" yazıyor; `README.md` "tamamen çevrimdışı" demiyor, kod
  çevrimdışı-öncelikli + isteğe bağlı bulut eşitlemeli.
- **Hışır'ın sesi iddia edilmedi.** `GameAudio.husurAday` doğrulanmamış adaydır
  (transkriptte "huşur" diye geçti — `lib/models/hisir_character.dart` başlığı).
  Taslakta Hışır yalnızca görünümü ve Terlik Tap görünümüyle anılıyor.
- **İngilizce/Türkçe arayüz iddiası yok.** `lib/main.dart` EN + TR
  altyapısını bağlıyor (`localizationsDelegates` + `supportedLocales`) ve
  çeviri tablosu kapsaması EN/TR eşliği `test/l10n_parity_test.dart`'ta
  denetleniyor); listeleme
  metnine dil iddiası yine de eklenmedi.
- **Reklam iddiası yok.** Bu sürümde reklam SDK'sı yok
  (`IapService.rewardedAdsAvailable == false`; gizlilik metni: reklam gösterimi
  yalnızca cihaz içi yer tutucu).
- İndirme/puan/yorum sayısı, yaş derecelendirmesi, çıkış tarihi, web sitesi ve
  sosyal medya bağlantısı yazılmadı — hiçbiri doğrulanmadı.

### Selçuk'ta bekleyen kararlar / eksikler

1. Başlık: A mı B mi (yukarıda)?
2. Kategori: öneri "Arcade" — yalnızca öneri, karar Selçuk'ta.
3. **Gizlilik politikası URL'si:** mağaza sayfası için gereken herkese açık URL
   Selçuk tarafından sağlanacak (`lib/screens/privacy_policy_screen.dart` başlığında
   yazılı; bu dosyaya URL eklenmedi, uydurulmadı).
4. Ekran görüntüleri + feature graphic: repoda yok — çekilip hazırlanması gerek.
   (Bu yüzden `test/store_readiness_test.dart`'a ekran görüntüsü denetimi eklenmedi.)
5. İçerik derecelendirmesi: Play anketiyle belirlenecek.
6. IAP fiyat/içerik teyidi: paket ve güçlendirici içerikleri gönderim öncesi
   Play Console'daki ürünlerle birebir eşleşmeli.
