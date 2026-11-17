# LÜLÜLÜ — Böcek Sesleri & SFX Kataloğu

Hazırlanma & Doğrulama: 2026-11-04. Kaynaklar:
- `/Users/selcuk/Documents/lululu/raw_tiktok_audio/` (`7700956420036054293.mp3`, `7701016952956849429.mp3`, `7701289255338921237.mp3`, `7701817537155190023.mp3`)
- `/Users/selcuk/LULULU-prototip/assets/sounds/` (`tier1_ses.mp3`..`tier8_ses.mp3`)
- `/Users/selcuk/Desktop/LÜLÜLÜ UI:UX Tasarım.html` (F16 Jet Roar + Bomb WebAudio sentezi ve Aydınlat Hele base64 ses kaydı)

## Tier 1–13 Böcek Sesleri (`tierN_ses.mp3` & `voice_tierN.mp3`)

Replik sütunu 2026-11-18'de `lib/models/insect_tier.dart` içindeki `viralReplik` değerleriyle karşılaştırılıp kodla uyumlu hâle getirildi (kod esastır).

| Dosya (`design/sounds/` & `audio/`) | Böcek | İmza Replik (`viralReplik`) | Süre | Ortalama / Tepe Seviye | Kaynak TikTok Bölümü |
|---|---|---|---|---|---|
| `tier1_ses.mp3` / `voice_tier1.mp3` | Bebek Huni | "Lülülü bebek!" | 3.20 sn | -19.6 dB / -5.6 dB | `7701817537155190023` (00:00.2) |
| `tier2_ses.mp3` / `voice_tier2.mp3` | Tencereli Çırak | "Vurma kafama usta!" | 3.00 sn | -18.8 dB / -9.2 dB | `7701817537155190023` (00:15.0) |
| `tier3_ses.mp3` / `voice_tier3.mp3` | Makaracı Fan | "Makarayız abi!" | 3.50 sn | -19.1 dB / -8.5 dB | `7701817537155190023` (00:28.0) |
| `tier4_ses.mp3` / `voice_tier4.mp3` | Pijamalı Dansçı | "Hoppa oyna gülüm!" | 3.00 sn | -19.0 dB / -8.3 dB | `7701016952956849429` (00:12.0) |
| `tier5_ses.mp3` / `voice_tier5.mp3` | Hamam Diva | "Ben divayım ayol! Divalar yemek yapmaz!" | 3.50 sn | -17.5 dB / -8.3 dB | `7701016952956849429` (00:45.0) |
| `tier6_ses.mp3` / `voice_tier6.mp3` | Hamam Can | "Sayın seyirciler flaş flaş!" | 3.50 sn | -17.8 dB / -4.3 dB | `7700956420036054293` (00:05.0) |
| `tier7_ses.mp3` / `voice_tier7.mp3` | Kongo Lideri | "Kurban olduğum Kongo istilası!" | 3.80 sn | -19.7 dB / -4.9 dB | `7701289255338921237` (00:08.0) |
| `tier8_ses.mp3` / `voice_tier8.mp3` | Hasta Bilge | "Dukturu arayın ölüyorum lülülü!" | 4.00 sn | -19.5 dB / -10.2 dB | `7701817537155190023` (01:10.0) |
| `tier9_ses.mp3` / `voice_tier9.mp3` | Millî Formalı | "Sahaya çıktık!" | 3.20 sn | -16.9 dB / -5.8 dB | `7701289255338921237` (00:18.0) |
| `tier10_ses.mp3` / `voice_tier10.mp3` | Pembe Ceketli | "Tarzımsın!" | 3.20 sn | -17.7 dB / -6.0 dB | `7700956420036054293` (00:35.0) |
| `tier11_ses.mp3` / `voice_tier11.mp3` | Beyaz Hayalet | "Görünmezim!" | 3.20 sn | -17.7 dB / -7.2 dB | `7701016952956849429` (00:25.0) |
| `tier12_ses.mp3` / `voice_tier12.mp3` | Gri Tişörtlü | "Rahatına bak!" | 3.20 sn | -18.1 dB / -8.5 dB | `7701817537155190023` (00:49.0) |
| `tier13_ses.mp3` / `voice_tier13.mp3` | Pembe Bornozlu | "Zirvedeyim!" | 3.50 sn | -17.7 dB / -7.0 dB | `7701016952956849429` (01:05.0) |

## Özel Karakter Replikleri & Mod Sesleri (`assets/audio/` & `assets/design/sounds/`)

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
