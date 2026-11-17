# LÜLÜLÜ — Build & Run Notları

Bu dosya, oyunu kendi bilgisayarında derleyip çalıştıracak kişi (Selçuk) içindir.

## Gereksinimler

- Flutter SDK (`pubspec.yaml` içinde `environment.sdk: ^3.11.5` — bu Dart koşulunu sağlayan sürüm)
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
- `lib/modes/`, `lib/screens/game_screen.dart`, `lib/screens/grid_2048_screen.dart` — 11 oyun modu
- `lib/screens/result_screen.dart` — ahşap temalı animasyonlu sonuç ekranı
- `lib/theme/lululu_theme.dart` — renkler, fontlar (Exo 2 + Bangers), 48dp kuralı
- `tasarim/lululu_tasarim.html` — interaktif tasarım prototipi (referans)

## Bilinen kısıtlar

- Giriş/kayıt cihaz-içi hesap kasasıyla (hash + salt) çalışır; Firebase Auth
  bağlantısı `lib/services/auth_service.dart` içinde hazır ama
  `DefaultFirebaseOptions.isConfigured` kapalıyken bulut girişi devre dışı
  kalır, oyun yerel modda devam eder (`lib/services/firebase_bootstrap.dart`).
- Ödüllü reklam YOK: reklam SDK'sı kurulu değil
  (`IapService.rewardedAdsAvailable == false`); mock oynatıcı
  (`showRewardedAdMock`) silindi — `lib/widgets/ad_mock.dart` yalnızca
  açıklama bırakan 9 satırlık dosyadır; ödül düğmeleri yalnızca
  "yakında" bilgisi gösterir.
- Mağaza satın alımları `in_app_purchase` paketine bağlı gerçek akıştır
  (`IapService`: ürün sorgusu, satın alma, `restorePurchases`); mağaza
  ürünlerinin Play Console / App Store Connect'te tanımlı olması gerekir.
- Günlük görev ilerlemesi gerçek oyun olaylarıyla dolar: 'play' tur
  bitiminde (`finish_run.dart`), 'merge'/'combo' birleşmede, 'video'
  Stüdyo ziyaretinde kaydedilir (`ProgressManager.recordTaskProgress`).
- Tier 9–13 (Millî Formalı, Pembe Ceketli, Beyaz Hayalet, Gri Tişörtlü,
  Pembe Bornozlu) görselleri `assets/design/bugs_new/` altındadır;
  sesleri `assets/audio/` altında mevcuttur (`tier9_ses.mp3`…`tier13_ses.mp3`
  ve `voice_tier9.mp3`…`voice_tier13.mp3`).
- Bu dalgada VM'de derleme koşulmadı; doğrulama kod okuma + dosya varlığı
  ile yapıldı. İlk `flutter run`'da çıkabilecek uyarılar normaldir.

## Tasarım kararları (kalıcı)

- Başlıklar Türkçe TAMAMEN BÜYÜK HARF; kombo yazıları Bangers font.
- Min dokunma hedefi 48dp.
- Parlak 3D çizgi-film stili; hub açık tema (beyaz), oyunlar koyu zemin + aydınlık vurgu.
- Bottom bar floating hap formda, arkası tamamen şeffaf; içerik altından kayar.
- Bildirim/zil ikonu yok (isteğe bağlı, sonra eklenebilir).
