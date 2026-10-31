# LÜLÜLÜ — Build & Run Notları

Bu dosya, oyunu kendi bilgisayarında derleyip çalıştıracak kişi (Selçuk) içindir.

## Gereksinimler

- Flutter SDK 3.11+ (Dart 3.x ile birlikte gelir)
- Android Studio / Xcode veya VS Code + Flutter eklentisi
- Bir cihaz veya emülatör (Android emülatör / iOS simülatör)

## Çalıştırma

```bash
cd lululu_game_clone
flutter pub get
flutter run
```

İlk açılışta 3 sayfalık animasyonlu splash gelir (GEÇ ile atlanabilir),
ardından ana sayfa (hub) açılır.

## Proje yapısı (kısa)

- `lib/main.dart` — açılış akışı: Splash → boot → HomeShell
- `lib/screens/home_shell.dart` — 5 sekmeli ana kabuk (floating şeffaf bottom bar):
  ANA SAYFA (hub), MODLAR, AİLEM, MAĞAZA, SKORLAR
- `lib/screens/splash_screen.dart` — 3 sayfalık animasyonlu açılış + loading bar
- `lib/services/energy_service.dart` — enerji (5/30, 5 dakikada +1, oyun başında −1)
- `lib/screens/game_selector_screen.dart` — hub: STÜDYO bloğu + günlük görevler bloğu
- `lib/modes/`, `lib/screens/game_screen.dart`, `lib/screens/grid_2048_screen.dart` — 10 oyun modu
- `lib/screens/result_screen.dart` — ahşap temalı animasyonlu sonuç ekranı
- `lib/theme/lululu_theme.dart` — renkler, fontlar (Exo 2 + Bangers), 48dp kuralı
- `tasarim/lululu_tasarim.html` — interaktif tasarım prototipi (referans)

## Bilinen kısıtlar / mock'lar

- Giriş/kayıt (Ayarlar → Hesap) şu an mock'tur; Firebase Auth bağlantısı
  `lib/services/auth_service.dart` içinde hazır ama prod keyleri girilmeden
  gerçek giriş yapmaz.
- Ödüllü reklamlar mock oynatıcıdır (5 sn kilitli sahte reklam).
- Mağaza satın alımları mock'tur (IAP bağlı değil).
- Günlük görev ilerlemesi şu an mock state ile dolar; gerçek oyun olayı
  bağlantısı sonraki fazda yapılacak.
- Tier 9–13 (Millî Formalı, Pembe Ceketli, Beyaz Hayalet, Gri Tişörtlü,
  Pembe Bornozlu) görselleri `assets/design/bugs_new/` altındadır;
  sesleri henüz yok (sessizler).
- Bu VM'de Flutter SDK olmadığı için kod derlenerek test edilmedi;
  tüm `.dart` dosyaları `dart_bracket_check.py` ile sözdizimi yönünden
  kontrol edildi. İlk `flutter run`'da çıkabilecek uyarılar normaldir.

## Tasarım kararları (kalıcı)

- Başlıklar Türkçe TAMAMEN BÜYÜK HARF; kombo yazıları Bangers font.
- Min dokunma hedefi 48dp.
- Parlak 3D çizgi-film stili; hub açık tema (beyaz), oyunlar koyu zemin + aydınlık vurgu.
- Bottom bar floating hap formda, arkası tamamen şeffaf; içerik altından kayar.
- Bildirim/zil ikonu yok (isteğe bağlı, sonra eklenebilir).
