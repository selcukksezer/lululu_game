# LÜLÜLÜ Ekran Envanteri — Prototip vs Flutter

Kaynak: `tasarim/lululu_tasarim.html` (16.8 MB, 2026-10-31 13:25 export) → `lib/`
Tarih: 2026-10-31. Yöntem: prototip Python ile parse edildi (section id'leri + metin çıkarımı), her Dart dosyası incelendi.
Satır sayıları 2026-11-18'de `wc -l` ile güncellendi.

## Ekran listesi

| # | Prototip ekran | Temel öğeler | Flutter karşılığı | Durum |
|---|---|---|---|---|
| 1 | Açılış (3 sayfa) | GEÇ, "YENİ MACERA / BÖCEKLERİ BİRLEŞTİR", LİDER KONUŞTU, 10 mod çipi, "MACERAYA BAŞLA", animasyonlu loading bar (%0→%100) | `lib/screens/splash_screen.dart` (1488 satır) | ✅ tamam |
| 2 | Hub (ANA SAYFA) | Top bar (profil foto, coin 12.450+, yıldız 86, enerji 5/30 + 05:00, ayarlar — zil YOK); hero (HOT Suika Arena + HEMEN OYNA); **Günlük Ödül** (3. gün·500 coin, AL·500, REKLAM 2X·1.000, ENERJİ AL·+5); Günlük Görevler özeti + TÜMÜNÜ GÖR; STÜDYO (5 kart); Oyun Modları listesi | `lib/screens/game_selector_screen.dart` | ✅ Günlük Ödül bölümü hub'da satır içi blok olarak mevcut (`dailyRewardTitle` + `_claimDailyReward`/`_claimDoubleDailyReward`); diyalog dosyası hâlâ çağrılmıyor (bkz. 10) |
| 3 | 10 oyun modu | Suika Arena, 2048 Grid, Balon Patlat, Match 3, Bağla Patlat, Stack Drop, Terlik Tap, Osmantuş, Çığlık Böcek, Makarayız — her birinde HUD (Skor/Rekor/Sıradaki), duraklatma, 3 bonus | `lib/screens/game_screen.dart` + `lib/screens/grid_2048_screen.dart` + `lib/modes/*.dart` (9 dosya) | ✅ çoğu tamam — duraklatma overlay'i 4 butonlu (bkz. 13) |
| 4 | Ahşap sonuç ekranı | SEVİYE TAMAM!, SKOR (sayaç), Rekor 4.820, En İyi Kombo ×6, Birleştirme 18, Kazanılan Altın, **REKLAM İZLE DEVAM ET**, **REKLAM İZLE 2X ALTIN**, TEKRAR OYNA, **PAYLAŞ**, ANA SAYFA | `lib/screens/result_screen.dart` (1277 satır) | ✅ butonlar mevcut — REKLAMLA DEVAM ET / 2X ALTIN yalnızca "yakında" bilgisi gösterir (reklam SDK'sı yok), PAYLAŞ satırı var |
| 5 | Profil | Oyuncu Profili, Apple Oyuncu @apple, SEVİYE 18, XP 1.240/2.000, Toplam Skor 7.915, Oynanan 48, En Yüksek Kombo ×6, Rozetlerim | `lib/screens/profile_screen.dart` (1690 satır) | ✅ tamam (SEVİYE/XP mevcut) |
| 6 | Ayarlar + Hesap | Ayarlar: HESAP (Giriş yap/kayıt ol ›), Müzik, Ses Efektleri, Titreşim, KAPAT. HESAP → tam ekran: GİRİŞ başlık, oturum kartı (Apple Oyuncu·apple + Çıkış), Giriş/Kayıt sekmeleri, GİRİŞ YAP, MİSAFİR DEVAM ET, Apple/Google | `lib/screens/settings_screen.dart` + `lib/widgets/auth_panel.dart` | ✅ tamam |
| 7 | Mağaza | Ücretsiz Sandık (REKLAM→İZLE), Enerji Paketi ₺29,99 (+10), Enerji Deposu ₺59,99 (30/30), Yıldız Paketi ₺149,99, Sürpriz Kutu 350 coin, Bir Avuç ₺59,99, Bir Kasa ₺249,99 (+%50), Ahşap Sandık 200, Altın Sandık 750, Çifte Coin 400, Şans İksiri 180 | `lib/widgets/shop_dialog.dart` (2485 satır) | ✅ prototip ürünleri ve fiyatları mevcut (Enerji Paketi ₺29,99 … Şans İksiri 180, kodda birebir) |
| 8 | Skorlar | Skor Tablosu, Haftalık sekmesi, 5 giriş (sıra, ad, seviye, skor) | `lib/screens/leaderboard_screen.dart` (1502 satır) | ✅ tamam (başlık 'SKOR TABLOSU' — `leaderboardTitle`; haftalık görünüm mevcut — `weeklyLabel`) |
| 9 | Ailem (13 tier) | Böcek Ailesi, 13 tier kartı (1 Bebek Huni … 13 Pembe Bornozlu), dokununca ses+replik | `lib/screens/tiers_screen.dart` (1073 satır) | ✅ tamam (13 tier mevcut) |
| 10 | Günlük ödül | 3. gün · 500 coin, AL·500, REKLAM 2X·1.000, ENERJİ AL·+5 | `lib/widgets/daily_reward_dialog.dart` (613 satır) | ⚠️ dosya var ama `showDailyRewardDialog` **hiçbir yerden çağrılmıyor**; hub'daki ödül satır içi blokla veriliyor (bkz. 2) |
| 11 | Günlük görevler | 4 görev (3 OYUN OYNA, 5 BİRLEŞTİRME YAP, 1 VİDEO İZLE, X4 KOMBO YAP), ilerleme çubuğu, ÖDÜLÜ AL | `lib/screens/tasks_screen.dart` (1445 satır) | ✅ tamam |
| 12 | Enerji popup'ı | "Enerjin Bitti!" 0/30, sonraki enerji 05:00, REKLAM İZLE·+5 ENERJİ, MAĞAZA·ENERJİ PAKETİ, SAYACI BEKLE | `lib/widgets/energy_empty_popup.dart` + `lib/services/energy_service.dart` | ✅ tamam |
| 13 | Duraklatma overlay'i | Duraklatıldı → DEVAM ET, YENİDEN BAŞLA, OYUNU BİTİR, ANA SAYFA | `lib/screens/game_screen.dart` (`_buildPauseOverlay`, ~1627. satır) | ✅ 4 buton mevcut (DEVAM ET / YENİDEN BAŞLA / OYUNU BİTİR / ANA SAYFA) |
| 14 | Reklam mock'u | 5 sn kilitli X, "Ödül için 5 sn izle", sahte reklam içeriği, ÖDÜLÜ AL | `lib/widgets/ad_mock.dart` (9 satır — yalnızca açıklama) | ❌ kaldırıldı (Dalga 15) — dosya yalnızca açıklama içeriyor; mock yeniden canlandırılmayacak |
| 15 | STÜDYO (5 ekran) | Video İzle (video listesi), Video Yap (kırp/yazı/sticker), Yükle (dosya+başlık+yükleme), GIF Oluştur (kare seç+hız), İndirilenler (liste+depolama) | `lib/screens/studio_screens.dart` (3178 satır: `StudioWatchScreen`, `StudioCreateScreen`, `StudioUploadScreen`, `StudioGifScreen`, `StudioDownloadsScreen`); hub'daki 5 kart doğrudan bu ekranlara gider; `lib/screens/bug_video_hub_screen.dart` + `lib/screens/sticker_gif_screen.dart` bu ekranlara yönlendiren ince sarmalayıcılardır | ✅ 5 kart da gerçek ekrana bağlı |
| 16 | Modlar listesi | Oyun Modları, 10 mod kartı | `lib/screens/modes_screen.dart` (1019 satır) | ✅ tamam (katalogdan 11 kart çizer) |
| 17 | Bonus efektleri | Her bonusa özel efekt (terlik fırlar, sprey sis, bomba patlar…), biten bonus söner | `lib/widgets/bonus_fx.dart` (824 satır), Suika + 2048'de bağlı; `lib/widgets/mode_bonus_bar.dart` 8 mod ekranında bağlı (Balon, Bağla, Makarayız, Match 3, Osmantuş, Çığlık, Stack, Terlik) | ✅ altyapı + butonlar bağlı (yalnız Yuva Savunması'nda bonus çubuğu yok) |
| 18 | **YENİ** Online Mod Yakında (blok) | "ONLİNE MOD" başlık + "YAKINDA" rozeti, kilitli böcek görseli (gri ton), "HABERDAR ET" butonu → "Bildirimler açılınca haber vereceğiz" toast'ı | `lib/screens/game_selector_screen.dart` (`_buildOnlineCard`) → `lib/screens/online_screen.dart` — asset: `assets/design/ui/online_locked_bug_exact.webp` (yedek: `online_locked_bug.webp`) | ✅ yeni eklendi |
| 19 | **YENİ** Sohbet (lobi) | "SOHBET" başlık, 5 çevrimiçi oyuncu (avatar+isim+seviye), gelen/giden baloncuklar, 48dp yazma alanı + gönder butonu, mock mesajlar + otomatik cevap | `lib/screens/chat_lobby_screen.dart` (574 satır) — hub'da `_buildChatCard` ile erişim; assetler: `assets/design/bugs_hd/tier1/3/4/5/6/7_hd.png` (avatarlar) | ✅ yeni eklendi |

## Kapanacak farklar (öncelik sırası)
1. ~~Hub'a **Günlük Ödül** bölümü ekle~~ — ✅ satır içi blok mevcut; `daily_reward_dialog.dart` diyaloğunu bağlama açık (`showDailyRewardDialog` çağrılmıyor, bkz. 10).
2. ~~**Mağazayı** prototip bölümlerine/ürünlerine göre yeniden yaz~~ — ✅ tamamlandı (ürünler + fiyatlar kodda birebir).
3. ~~**Duraklatma overlay'ini** 4 butonlu yap~~ — ✅ tamamlandı (`_buildPauseOverlay`, 4 buton mevcut).
4. ~~**Sonuç ekranına** reklam butonları (DEVAM ET / 2X ALTIN) + PAYLAŞ ekle~~ — ✅ butonlar mevcut ("yakında" bilgisi; gerçek reklam için SDK gerekir).
5. ~~**Stüdyo** 5 kartını gerçek ekranlara bağla~~ — ✅ tamamlandı (`studio_screens.dart`, 5 gerçek ekran).
6. ~~Leaderboard başlığını 'SKOR TABLOSU' yap, haftalık görünümü doğrula~~ — ✅ tamamlandı (`leaderboardTitle` = 'SKOR TABLOSU', `weeklyLabel` mevcut).

## Asset eşleşmesi — birebir (Selçuk kuralı)

Tüm görseller `Image.asset` ile doğrudan `assets/design/` dosyalarından yüklenir. Placeholder/renkli kutu YOK.

| Ekran | Kullanılan asset dosyaları |
|---|---|
| Açılış (splash) | `assets/design/backgrounds/bg_splash.jpg`, `assets/design/bugs_hd/tier7_hd.png` (Kongo Lideri), `assets/design/bugs_hd/tier1–8_hd.png` (geçit), `assets/design/ui/logo_lululu.png` |
| Hub | `assets/design/ui/logo_lululu.png`, `assets/design/ui/icon_coin.png`, `assets/design/ui/icon_star.png`, `assets/design/backgrounds/bg_hub_hero.jpg` (hero), `assets/design/bugs_hd/tier*_hd.png` (mod kartları) |
| 10 oyun modu | Arka planlar: `backgrounds/suika_kitchen.webp` (Suika), `2048_casino.webp` (2048), `balloon_fair.webp` (Balon), `match3_lab.webp` (Match3), `connect_workshop.webp` (Bağla), `stack_nightcity.webp` (Stack), `terlik_livingroom.webp` (Terlik), `osmantus_mansion.webp` (Osmantuş), `scream_sky.webp` (Çığlık), `makarayiz_stage.webp` (Makarayız). Böcekler: `bugs_hd/tier1–8_hd.png` + `bugs_new/tier9–13_hd.png`. Engeller: `obstacles/obstacle-bush.png`, `obstacle-pipes.png`, `obstacle-spikes.png` |
| Sonuç ekranı | `assets/design/backgrounds/result_wood_bg.webp`, `assets/design/backgrounds/chest_wood.png`, `assets/design/ui/icon_coin.png`, `assets/design/ui/icon_star.png` |
| Profil | `assets/design/bugs_hd/tier5_hd.png` (avatar) |
| Ayarlar/Hesap | `assets/design/bugs_hd/tier*_hd.png` (oturum avatarı) |
| Mağaza | `assets/design/ui/icon_coin.png`, `assets/design/ui/icon_star.png`, `assets/design/ui/powerup_aydinlat.png`, `powerup_raid_spreyi.png`, `powerup_terlik.png`, `assets/design/backgrounds/chest_wood.png` |
| Skorlar | `assets/design/bugs_hd/tier*_hd.png` (sıralama avatarları) |
| Ailem (13 tier) | `assets/design/bugs_hd/tier1–8_hd.png`, `assets/design/bugs_new/tier9–13_hd.png` |
| Günlük ödül | `assets/design/ui/icon_coin.png` |
| Günlük görevler | rozet ikonları: `assets/design/icons/extra_icons/` |
| Enerji popup'ı | kalp ikonu (Material) + `assets/design/ui/icon_coin.png` |
| Duraklatma | oyun arka planı (bölüm üstü kararır) |
| Reklam mock'u | `assets/design/ui/logo_lululu.png` |
| STÜDYO | `assets/design/backgrounds/*.webp` (video küçük resimleri) |
| Sohbet (yeni) | `assets/design/bugs_hd/tier1/3/4/5/6/7_hd.png` (oyuncu avatarları) |
| Online Mod (yeni) | `assets/design/ui/online_locked_bug_exact.webp` (yedek: `online_locked_bug.webp`) (kilitli böcek görseli) |
| Sesler | `assets/audio/tier1_ses.mp3` … `tier8_ses.mp3` (kanonik klasör; `assets/design/sounds/` altında bayt-birebir kopyalar duruyor, pubspec'te yok) (birleşme, sonuç, açılış, tier sesi) |
| Uygulama ikonu | `assets/design/app_icons/app_icon_{48,72,96,144,192}.png` → Android mipmap; 1024'ten türetilen iOS appiconset |

### Karşılığı olmayanlar (tasarım setinde yok — raporda açıkça)
- `assets/images/scream/grass_tile.png`, `sky_strip.png`, `terrain_grass.png` — Çığlık Böcek modunun prosedürel zemin karoları; tasarım setinde muadili yok, oyun içi üretilmiş tile'lar.
- `assets/models/prop_Bee.glb` — 3D arı modeli (arena dekoru); 2D tasarım seti dışında.
- `assets/ui/kenney/` — Kenney UI çerçeve paketi (buton/panel 9-patch'leri); tasarım seti dışında.
- `assets/audio/sfx_*.mp3`, `voice_aydinlat.mp3`, `voice_osman_*.mp3` — oyun SFX'leri; tasarım ses setinde (tier1–8) yok.
