# 🪳 LÜLÜLÜ: Hamamböceği Evrimi (Cockroach Merge Mania)
## Proje Dokümantasyonu ve Çalıştırma Rehberi

Bu proje, TikTok ve sosyal medyada viral olan **"Lülülü / Pikomotions / Makarayız Abi"** hamamböceği akımı ile **Suika Game (Drop & Merge)** dairesel fizik mekaniklerini birleştiren tam teşekküllü, 10 uzman ajanın ortak çalışmasıyla geliştirilmiş bir mobil (iOS & Android) ve Web oyunudur.

---

### 1. Karakterler & Evrim Hiyerarşisi
Orijinal kaynak görsellerden (`IMG_1521.PNG` – `IMG_1527.PNG`) üretilen 8 farklı seviye bulunmaktadır:

1. **Tier 1 (Bebek Huni Böcek)**: *"Lülülü lülülü!"* tiz ses efekti.
2. **Tier 2 (Tencereli Çırak Böcek)**: *"Vurma kafama usta!"* tava tıkırtısı.
3. **Tier 3 (Makaracı Fan Böcek)**: *"Makarayız abi!"* stadyum düdüğü.
4. **Tier 4 (Pijamalı Dansçı)**: *"Hoppa oyna gülüm!"* zilli tef ritmi.
5. **Tier 5 (Hamam Diva)**: *"Ay bayılazaam rezzillik!"* tiz koket ses.
6. **Tier 6 (Hamam Can - Şovmen)**: *"Sayın seyirciler flaş flaş!"* canlı yayın jingle.
7. **Tier 7 (Kongo Lideri)**: *"Kurban olduğum Kongo istilası!"* vuvuzela tonu.
8. **Tier 8 (Hasta Bilge Böcek)**: *"Dukturu arayın ölüyorum lülülü!"* nihai form.

---

### 2. Öne Çıkan Oyun Mekanikleri
- **Dairesel Akvaryum Fiziği (Verlet Integration)**: Gerçekçi çarpışma esnekliği, açısal dönüşler ve yerçekimi sarsıntıları.
- **Dinamik Ses ve Replik Sistemi**: Her düşüşte tok "pop/squish" sesi; her birleşmede (merge) o karaktere ait Türkçe replik ve kombo çarpanı.
- **Güçlendiriciler (Power-ups)**:
  - **Raid Spreyi**: Sahadaki küçük böcekleri buharlaştırır.
  - **Terlik Sarsıntısı**: Çemberi güçlü bir ivmeyle sarsıp sıkışan böcekleri dağıtır.
- **Üst Evrim Barı**: Keşfedilen böcekleri dinamik olarak aydınlatan HUD.
- **Yüksek Skor & Kalıcılık**: `shared_preferences` ile kaydedilen yerel rekorlar.

---

### 3. Çalıştırma Talimatları

Projeyi çalıştırmak için:
```bash
cd /Users/selcuk/Documents/lululu/lululu_game

# Testleri çalıştırmak için:
flutter test

# Web üzerinde denemek için:
flutter run -d chrome

# iOS veya Android üzerinde çalıştırmak için:
flutter run -d ios      # veya android
```
