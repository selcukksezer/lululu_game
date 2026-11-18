# 🪳 LÜLÜLÜ: Hamamböceği Evrimi (Cockroach Merge Mania)
## Proje Dokümantasyonu ve Çalıştırma Rehberi

Bu proje, TikTok ve sosyal medyada viral olan **"Lülülü / Pikomotions / Makarayız Abi"** hamamböceği akımı ile **Suika Game (Drop & Merge)** dairesel fizik mekaniklerini birleştiren tam teşekküllü bir mobil (iOS & Android) ve Web oyunudur.

---

### 1. Karakterler & Evrim Hiyerarşisi
Birleşme zincirinde 13 kademe bulunmaktadır (`lib/models/insect_tier.dart`). İlk 8 kademe ana evrim zinciri, 9–13 arası kademeler zincirin devamıdır. Aynı kademeden iki böcek birleşince bir üst kademeye evrimleşir.

1. **Tier 1 (Bebek Huni)**: *"Lülülü bebek!"* — Sıradan.
2. **Tier 2 (Tencereli Çırak)**: *"Vurma kafama usta!"* — Seyrek.
3. **Tier 3 (Makaracı Fan)**: *"Makarayız abi!"* — Nadir.
4. **Tier 4 (Pijamalı Dansçı)**: *"Hoppa oyna gülüm!"* — Destansı.
5. **Tier 5 (Hamam Diva)**: *"Ben divayım ayol! Divalar yemek yapmaz!"* — Efsanevi.
6. **Tier 6 (Hamam Can)**: *"Sayın seyirciler flaş flaş!"* — Mitik.
7. **Tier 7 (Kongo Lideri)**: *"Kurban olduğum Kongo istilası!"* — Gizli.
8. **Tier 8 (Hasta Bilge)**: *"Dukturu arayın ölüyorum lülülü!"* — Evrim Kristali.
9. **Tier 9 (Millî Formalı)**: *"Sahaya çıktık!"* — Süper.
10. **Tier 10 (Pembe Ceketli)**: *"Tarzımsın!"* — Ultra.
11. **Tier 11 (Beyaz Hayalet)**: *"Görünmezim!"* — Kozmik.
12. **Tier 12 (Gri Tişörtlü)**: *"Rahatına bak!"* — Kadim.
13. **Tier 13 (Pembe Bornozlu)**: *"Zirvedeyim!"* — Mutlak, evrimin zirvesi.

Not: **Hışır** (kasketli köy dedesi) kademe dışı özel bir karakterdir; 13 kademelik birleşme zincirine dahil değildir (`lib/models/hisir_character.dart`).

---

### 2. Oyun Modları
`lib/models/lululu_game_mode.dart` kataloğunda 11 oynanabilir arcade modu vardır:

1. **Suika Arena** — Birleştirme klasiği: böcekleri kavanoza bırak, aynı seviyeleri çarpıştırarak üst kademelere ulaş.
2. **2048 Grid** — Kaydır, birleştir, 2048 yap: 4x4 tahtayı 4 yöne kaydır, eşleşen böcekler bir üst seviyeye evrimleşir.
3. **Balon Patlat** — Nişan al, 3 aynı balonu patlat.
4. **Match 3** — Komşuyu kaydır, 3'lü patlat.
5. **Bağla Patlat** — Aynı böceği çiz, zinciri patlat.
6. **Stack Drop** — Kuleyi diz, kenarı kesme: sallanan böcek bloklarını tam üst üste bırak.
7. **Terlik Tap** — Delikten çıkanı terlikle ez; bombalara dokunma.
8. **Yuva Savunması** — Yuvaya ulaşanı terlikle ez, pastayı koru.
9. **Osmantuş** — Yeşil halkada ikili tuş: daralan zamanlama halkasını tam yeşil çizgide yakala.
10. **Çığlık Böcek** — Bağır, kapılardan geç, ezilme: mikrofona bağırarak veya basılı tutarak böceği uçur.
11. **Makarayız** — Beat'te kaydır, makarayı sar: ritim notalarını çizgide yakala, kombo çarpanını katla.

---

### 3. Öne Çıkan Oyun Mekanikleri
- **Dairesel Akvaryum Fiziği (Verlet Integration)**: Gerçekçi çarpışma esnekliği, açısal dönüşler ve yerçekimi sarsıntıları.
- **Dinamik Ses ve Replik Sistemi**: Her düşüşte tok "pop/squish" sesi; her birleşmede (merge) o karaktere ait Türkçe replik ve kombo çarpanı.
- **Güçlendiriciler (Power-ups)**:
  - **Raid Spreyi**: Sahadaki küçük böcekleri buharlaştırır.
  - **Terlik Sarsıntısı**: Çemberi güçlü bir ivmeyle sarsıp sıkışan böcekleri dağıtır.
- **Üst Evrim Barı**: Keşfedilen böcekleri dinamik olarak aydınlatan HUD.
- **Yüksek Skor & Kalıcılık**: `shared_preferences` ile kaydedilen yerel rekorlar.

---

### 4. Çalıştırma Talimatları

Gereksinim: Flutter SDK (`pubspec.yaml` içindeki `environment.sdk: ^3.11.5` koşulunu sağlayan sürüm).

Proje kök dizininde:

```bash
# Bağımlılıkları kurmak için:
flutter pub get

# Testleri çalıştırmak için:
flutter test

# Web üzerinde denemek için:
flutter run -d chrome

# Web derlemesi üretmek için (çıktı: build/web):
flutter build web --release

# iOS veya Android üzerinde çalıştırmak için:
flutter run
```
