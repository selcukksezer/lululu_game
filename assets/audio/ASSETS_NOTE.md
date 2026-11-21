# Viral TikTok ses klipleri — kaynak notu

## Kanonik klasör: `assets/audio/` (madde 17)

Bu klasördeki TÜM ses dosyaları kanonik kopyadır. `GameAudio` sabitleri YALIN
dosya adıdır (tam yol değil — Mac birleştirme kuralı, asla bozulmaz); oynatma
anında `AudioManager._normalizeAssetPath` yalın adı `assets/audio/` ile
birleştirir. Eski `assets/design/sounds/` önekiyle gelen tam yollar da aynı
kanonik klasöre çevrilir, böylece eski yol kullanan çağrılar bile tek
klasörden çalar.

DÜZELTME (2026-11-19, D13-doc/F21): `assets/design/sounds/` klasörü bu
kopyada BULUNMUYOR (`ls assets/design/` ile doğrulandı — `sounds/` dizini
yok). Buradaki eski "50 mp3 hâlâ diskte duruyor" cümlesi bayattı ve bu
düzeltmeyle geçersizdir; kanonik klasör yalnız `assets/audio/`'dur.
Pubspec'teki `design/sounds/` girişi KALDIRILDI:
`InsectTier.soundFile`/`voiceFile` (`lib/models/insect_tier.dart`) yalın
dosya adıdır ve `AudioManager._normalizeAssetPath` ile `assets/audio/`'ya
çözülür; `ZeroJankPreloader.criticalSoundAssets`
(`lib/services/zero_jank_preloader.dart`) artık `assets/audio/`'yu gösterir.
Kodda `design/sounds/`'a kalan göndermeler yalnızca yorumlar ile
`AudioManager`'ın eski yolları kanonik klasöre çeviren uyumluluk katmanıdır;
hiçbir ses o klasörden yüklenmez. Eski klasör bu kopyada bulunmadığı için
"silme sonraya bırakıldı" ifadesi de geçersizdir — bu not silme yapmaz,
yalnız mevcut durumu belgeler. Yeni klip
ASLA `design/sounds/` altına eklenmez. Bütünlük testleri
(`test/asset_integrity_test.dart`, grup 2) yalnız kanonik klasörü denetler.

Aşağıdaki 7 klip TikTok videolarından kesildi (mp3, 128k).

Klip → kaynak eşleşmesi (`GameAudio` sabiti parantez içinde):

| Dosya | Kaynak video | Kesim aralığı (sn) | Not |
|---|---|---|---|
| `mezarina_siktigim.mp3` (`mezarinaSiktigim`) | original_4 (video4) | 12.08–13.76 | "mezarına sıçtığım" kesin |
| `diva_sinyal.mp3` (`divaSinyal`) | sim_hamamdaralem_7697726382641614100 | 3.59–5.89 | Diva repliği 1 |
| `diva_yasla.mp3` (`divaYasla`) | sim_hamamdaralem_7697726382641614100 | 6.23–9.69 | Diva repliği 2 |
| `lululu_nakarat.mp3` (`lululuNakarat`) | original_3 (video3) | 0–2.9 | Lülülü nakaratı |
| `duktur.mp3` (`duktur`) | original_2 (video2) | 0–14 | Duktur repliği |
| `kanka.mp3` (`kanka`) | original_5 (video5) | 5.4–13.9 | Kanka ikilisi |
| `hisir_zopa.mp3` (`hisirZopa`) | sim_bocekalem.i_7706225030606146834 | 16.6–22.1 | **ONAYLI Hışır sesi** — Selçuk kulakla onayladı (2026-11-19 19:49: "evet bu kısım doğru seste") |

## Hışır sesi: `hisir_zopa.mp3` (ONAYLI)

Hışır'ın sesi `hisir_zopa.mp3`'tür: sim_bocekalem.i_7706225030606146834
videosunun 16.6–22.1 sn kesimi — "Gemü'ne sıçtığımın garısı, şimdi şahadet
getir, sonra zopayı getir" (5.5 sn). Selçuk kulakla onayladı (2026-11-19
19:49: "evet bu kısım doğru seste"). `GameAudio.hisirZopa` sabiti ve
`voiceForCharacterId('hisir')` bu dosyayı çözer.

Eski aday `husur_aday.mp3` (sim_bocekalem.i_7704406490743901448, 2.16–3.62;
transkripte "huşur" diye geçen sesin kesimi) artık hiçbir yerde
referanslanmıyor. Dosya assets'te duruyor; silinip silinmeyeceğine
koordinatör karar verecek.

## Telif notu

Selçuk'un kararı (2026-11-17): sesler yapay zekâ üretimidir, telif kaygısı
yoktur, aynen kullanılacaktır.

## Kullanım

Oynatma metotları `lib/services/audio_manager.dart` içindedir:
`playMezarinaSiktigim`, `playDivaSinyal`, `playDivaYasla`,
`playLululuNakarat`, `playDuktur`, `playKanka`, `playHusurAday`.
Tümü ses ayarlarına (`voiceEnabled` + `sfxEnabled`) saygı duyar.

Yeni klip eklerken: dosyayı YALNIZ `assets/audio/` altına koy, `GameAudio`'ya
yalın dosya adıyla sabit ekle, `viralOneShots`/`allAssets` listesine dahil et.
`assets/design/sounds/` altına kopya ekleme.

## Böcek Sesleri & SFX Kataloğu (kaynak: sounds_listesi.md)

Hazırlanma & Doğrulama: 2026-11-04. Kaynaklar:
- `/Users/selcuk/Documents/lululu/raw_tiktok_audio/` (`7700956420036054293.mp3`, `7701016952956849429.mp3`, `7701289255338921237.mp3`, `7701817537155190023.mp3`)
- `/Users/selcuk/LULULU-prototip/assets/sounds/` (`tier1_ses.mp3`..`tier8_ses.mp3`)
- `/Users/selcuk/Desktop/LÜLÜLÜ UI:UX Tasarım.html` (F16 Jet Roar + Bomb WebAudio sentezi ve Aydınlat Hele base64 ses kaydı)

### Tier 1–13 Böcek Sesleri (`tierN_ses.mp3` — tekil set; 12A'da bayt-birebir kopya `voice_tierN.mp3` seti silindi)

Replik sütunu 2026-11-18'de `lib/models/insect_tier.dart` içindeki `viralReplik` değerleriyle karşılaştırılıp kodla uyumlu hâle getirildi (kod esastır).

| Dosya (`assets/audio/`) | Böcek | İmza Replik (`viralReplik`) | Süre | Ortalama / Tepe Seviye | Kaynak TikTok Bölümü |
|---|---|---|---|---|---|
| `tier1_ses.mp3` | Bebek Huni | "Lülülü bebek!" | 3.20 sn | -19.6 dB / -5.6 dB | `7701817537155190023` (00:00.2) |
| `tier2_ses.mp3` | Tencereli Çırak | "Vurma kafama usta!" | 3.00 sn | -18.8 dB / -9.2 dB | `7701817537155190023` (00:15.0) |
| `tier3_ses.mp3` | Makaracı Fan | "Makarayız abi!" | 3.50 sn | -19.1 dB / -8.5 dB | `7701817537155190023` (00:28.0) |
| `tier4_ses.mp3` | Pijamalı Dansçı | "Hoppa oyna gülüm!" | 3.00 sn | -19.0 dB / -8.3 dB | `7701016952956849429` (00:12.0) |
| `tier5_ses.mp3` | Hamam Diva | "Ben divayım ayol! Divalar yemek yapmaz!" | 3.50 sn | -17.5 dB / -8.3 dB | `7701016952956849429` (00:45.0) |
| `tier6_ses.mp3` | Hamam Can | "Sayın seyirciler flaş flaş!" | 3.50 sn | -17.8 dB / -4.3 dB | `7700956420036054293` (00:05.0) |
| `tier7_ses.mp3` | Kongo Lideri | "Kurban olduğum Kongo istilası!" | 3.80 sn | -19.7 dB / -4.9 dB | `7701289255338921237` (00:08.0) |
| `tier8_ses.mp3` | Hasta Bilge | "Dukturu arayın ölüyorum lülülü!" | 4.00 sn | -19.5 dB / -10.2 dB | `7701817537155190023` (01:10.0) |
| `tier9_ses.mp3` | Millî Formalı | "Sahaya çıktık!" | 3.20 sn | -16.9 dB / -5.8 dB | `7701289255338921237` (00:18.0) |
| `tier10_ses.mp3` | Pembe Ceketli | "Tarzımsın!" | 3.20 sn | -17.7 dB / -6.0 dB | `7700956420036054293` (00:35.0) |
| `tier11_ses.mp3` | Beyaz Hayalet | "Görünmezim!" | 3.20 sn | -17.7 dB / -7.2 dB | `7701016952956849429` (00:25.0) |
| `tier12_ses.mp3` | Gri Tişörtlü | "Rahatına bak!" | 3.20 sn | -18.1 dB / -8.5 dB | `7701817537155190023` (00:49.0) |
| `tier13_ses.mp3` | Pembe Bornozlu | "Zirvedeyim!" | 3.50 sn | -17.7 dB / -7.0 dB | `7701016952956849429` (01:05.0) |

### Özel Karakter Replikleri & Mod Sesleri (`assets/audio/` & `assets/design/sounds/`)

| Dosya | Açıklama | Süre | Ortalama / Tepe Seviye |
|---|---|---|---|
| `voice_aydinlat.mp3` | "Şuraları aydınlat hele!" mega güçlendirici repliği (`7701289255338921237` 00:02.0 & HTML base64) | 4.00 sn | -19.0 dB / -7.9 dB |
| `voice_osman_a.mp3` | Osmantuş Kişi A (Osman — "OSMAN TUŞ! / DIKKIŞ DIKKIŞ!") orijinal TikTok kesiti | 3.00 sn | -17.5 dB / -3.9 dB |
| `voice_osman_b.mp3` | Osmantuş Kişi B (Tuş — "ARMUT PİŞ! / LÜLÜLÜ!") orijinal TikTok kesiti | 3.00 sn | -17.9 dB / -6.2 dB |
| `sfx_scream_roach.mp3` | Çığlık Böcek modu yüksek enerjili viral çığlık kesiti (`7701289255338921237` 00:12.0) | 2.20 sn | -18.1 dB / -4.7 dB |
| `sfx_makara_spin.mp3` | Makarayız modu makara sarma & ritim vuruş kesiti (`7701817537155190023` 00:28.0) | 1.50 sn | -18.1 dB / -7.3 dB |
| `sfx_osmantus_beat.mp3` | Osmantuş yeşil halka "Dıkkış / Tuş" ritmik vuruş SFX | 0.22 sn | -17.5 dB / -5.3 dB |
| `sfx_f16.mp3` | HTML prototip `jetRoar()` + `boomSnd()` birebir F16 jet uğultusu ve çift bomba patlaması | 1.85 sn | -20.6 dB / -5.3 dB |
| `sfx_aydinlat_beam.mp3` | Aydınlat Hele lazer / hava saldırısı ışın SFX | 0.80 sn | -13.1 dB / -2.5 dB |
| `sfx_merge_chime.mp3` | Böcek birleşim chime SFX | 0.20 sn | -11.8 dB / -2.9 dB |
| `sfx_combo.mp3` | Kombo ("Kombo makara!") SFX | 0.78 sn | -18.4 dB / -1.7 dB |
| `sfx_drop.mp3` | Böcek bırakma (drop bubble) SFX | 0.12 sn | -14.8 dB / -3.6 dB |
| `sfx_pop.mp3` | Balon / UI pop SFX | 0.10 sn | -11.8 dB / -2.9 dB |
| `sfx_button_tap.mp3` | UI buton dokunma (tap) SFX | 0.09 sn | -16.8 dB / -5.0 dB |
| `sfx_slipper.mp3` | Terlik şaplağı (`playSlapSfx` / `playSlipper`) SFX | 0.25 sn | -11.8 dB / -2.9 dB |
| `sfx_spray.mp3` | Raid böcek ilacı sprey (`playSpraySfx`) SFX | 0.35 sn | -17.0 dB / -3.0 dB |
| `sfx_victory.mp3` | Zafer / seviye tamamlama arpej fanfar SFX (`playVictorySfx`) | 0.95 sn | -18.7 dB / -6.2 dB |
| `sfx_gameover.mp3` | Oyun bitti ("Taştı taştı dukturu çağırın!") SFX | 1.78 sn | -18.8 dB / -4.5 dB |
