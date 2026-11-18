// Madde 95 [P1]: Türkçe yerelleştirme tablosu (el yazımı, codegen yok).
// Varsayılan dil TR'dir. Anahtar listesi için bkz. app_localizations.dart.
//
// Değerler mevcut gömülü metinlerden aynen alındı: sekme etiketleri
// home_shell.dart (_label), 'HEMEN OYNA' game_selector_screen.dart,
// 'Yükleniyor…', 'Tekrar Dene', 'Bir şeyler ters gitti.' ve çevrimdışı
// uyarısı main.dart'tan.

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr() : super(const Locale('tr'));

  @override
  String get appName => 'LÜLÜLÜ';

  @override
  String get navHome => 'ANA SAYFA';

  @override
  String get navModes => 'MODLAR';

  @override
  String get navFamily => 'AİLEM';

  @override
  String get navShop => 'MAĞAZA';

  @override
  String get navScores => 'SKORLAR';

  @override
  String get play => 'OYNA';

  @override
  String get playNow => 'HEMEN OYNA';

  @override
  String get continueAction => 'DEVAM';

  @override
  String get back => 'GERİ';

  @override
  String get close => 'KAPAT';

  @override
  String get settings => 'AYARLAR';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get cancel => 'İptal';

  @override
  String get confirm => 'Onayla';

  @override
  String get save => 'Kaydet';

  @override
  String get loading => 'Yükleniyor…';

  @override
  String get ok => 'Tamam';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

  @override
  String get next => 'İleri';

  @override
  String get skip => 'Atla';

  @override
  String get start => 'Başla';

  @override
  String get pause => 'Duraklat';

  @override
  String get resume => 'Devam Et';

  @override
  String get restart => 'Yeniden Başlat';

  @override
  String get quit => 'Çık';

  @override
  String get profile => 'Profil';

  @override
  String get tasks => 'Görevler';

  @override
  String get errorGeneric => 'Bir şeyler ters gitti.';

  @override
  String get offlineWarning =>
      'Bazı veriler yüklenemedi. Çevrimdışı devam ediliyor.';

  // --- Dalga 10 göçü: ortak ---
  // Değerler göçen ekranlardaki gömülü metinlerden aynen alındı
  // (TR görünümünde fark yoktur).

  @override
  String get goBackLabel => 'Geri';

  @override
  String get comingSoon => 'YAKINDA';

  @override
  String get claimedShort => 'ALINDI';

  @override
  String get claimedWithCheck => '✓ ALINDI';

  @override
  String get claimReward => 'ÖDÜLÜ AL';

  // --- Dalga 10 göçü: Modlar ekranı ---

  @override
  String get modesTitle => 'OYUN MODLARI';

  @override
  String modeOpenLabel(String title, String subtitle, String best) =>
      '$title oyununu aç: $subtitle, rekor $best';

  @override
  String modeBestLine(String subtitle, String best) =>
      '$subtitle · Rekor $best';

  // --- Dalga 10 göçü: Görevler ---

  @override
  String get dailyTasksTitle => 'GÜNLÜK GÖREVLER';

  @override
  String get taskPlay3Games => '3 OYUN OYNA';

  @override
  String get taskMerge5 => '5 BİRLEŞTİRME YAP';

  @override
  String get taskWatch1Video => '1 VİDEO İZLE';

  @override
  String get taskCombo4 => 'X4 KOMBO YAP';

  @override
  String rewardCoins(int amount) => 'Ödül: +$amount COIN';

  @override
  String bossFirstClearBonus(int amount) =>
      'Boss ilk geçiş bonusu: +$amount COIN';

  @override
  String rewardEnergy(int amount) => 'Ödül: +$amount ENERJİ';

  @override
  String get todaysTasks => 'BUGÜNÜN GÖREVLERİ';

  @override
  String get tasksHeroSubtitle =>
      'Görevleri bitir, ödülü kap — yarın yenileri gelir!';

  @override
  String get tasksNotePrefix =>
      'İlerleme bu oturumda oynadıkça dolar. Tamamlanan görevde ';

  @override
  String get tasksNoteSuffix =>
      ' belirir; coin cüzdanına, enerji kalbine anında işler.';

  @override
  String claimTaskLabel(String title, String reward) =>
      'Ödülü al: $title, $reward';

  // --- Dalga 10 göçü: Ana sayfa (game_selector) ---

  @override
  String get dailyRewardClaimedSnack => 'Günlük ödül alındı: +500 coin';

  @override
  String get rewardedAdsComingSoon =>
      'Ödüllü reklamlar yakında — şimdilik kullanılamıyor.';

  @override
  String get dailyEnergyClaimedSnack =>
      'Günlük enerji alındı: +5 enerji eklendi!';

  @override
  String get dailyEnergyAlreadyClaimedSnack =>
      'Günlük enerji bugün zaten alındı.';

  @override
  String get hbEnergyTag => '-1 ENERJİ';

  @override
  String get chestClaimFailed => 'Sandık açılamadı. Tekrar dene.';

  @override
  String boosterOutOfStockToast(String label) =>
      '$label kalmadı! Mağazadan alabilirsin.';

  @override
  String levelLockedMessage(int previousLevel) =>
      'Önce $previousLevel. seviyeyi tamamla.';

  @override
  String taskRewardClaimedSnack(String rewardText) => '$rewardText alındı!';

  @override
  String get onlineNotifySignupSnack =>
      'Kaydın alındı! Online mod açılır açılmaz sana haber vereceğiz.';

  @override
  String get seeAllArrow => 'Tümü →';

  @override
  String get studioTitle => 'STÜDYO';

  @override
  String get studioWatchTitle => 'VİDEO İZLE';

  @override
  String get studioWatchSubtitle => 'Böcek klipleri ve rekorlar';

  @override
  String get studioCreateTitle => 'VİDEO YAP';

  @override
  String get studioCreateSubtitle => 'Kırp, yazı ve sticker ekle';

  @override
  String get studioUploadTitle => 'YÜKLE';

  @override
  String get studioUploadSubtitle => 'Klibini herkesle paylaş';

  @override
  String get studioGifTitle => 'GIF OLUŞTUR';

  @override
  String get studioGifSubtitle => 'Böceğini hareketlendir';

  @override
  String get studioDownloadsTitle => 'İNDİRİLENLER';

  @override
  String get studioDownloadsSubtitle => 'Çevrimdışı arşivin';

  @override
  String get badgeHot => 'HOT';

  @override
  String get suikaArenaTitle => 'SUİKA ARENA';

  @override
  String get heroSubtitleLine1 => 'Aynı böcekleri çarpıştır, Pembe';

  @override
  String get heroSubtitleLine2 => "Bornozlu'ya kadar evrimleştir!";

  @override
  String get dailyRewardTitle => 'GÜNLÜK ÖDÜL';

  @override
  String get dailyRewardSubtitle => '3. gün · 500 coin seni bekliyor';

  @override
  String get claim500 => 'AL · 500';

  @override
  String get claimEnergy5 => 'ENERJİ AL · +5';

  @override
  String get onlineModeTitle => 'ONLİNE MOD';

  @override
  String get onlineModeSubtitle =>
      'Çok yakında arkadaşlarınla çevrimiçi oyna!';

  @override
  String get notifyMe => 'HABERDAR ET';

  @override
  String get chatTitle => 'SOHBET';

  @override
  String get onlineCount5 => '5 ÇEVRİMİÇİ';

  @override
  String get chatSubtitle => 'Lonca muhabbet et, rekorları konuş';

  @override
  String get hubTasksSubtitle => 'Görevleri bitir, ödülü kap!';

  @override
  String get seeAllButton => 'TÜMÜNÜ GÖR';

  @override
  String get suikaArenaSubtitle => 'Birleştirme klasiği';

  @override
  String get grid2048Title => '2048 GRİD';

  @override
  String get grid2048Subtitle => 'Kaydır, birleştir, 2048 yap';

  @override
  String get balloonPopTitle => 'BALON PATLAT';

  @override
  String get balloonPopSubtitle => 'Nişan al, 3 aynı balonu patlat';

  @override
  String get badgeBonus => 'BONUS';

  @override
  String get match3Title => 'MATCH 3';

  @override
  String get match3Subtitle => "Komşuyu kaydır, 3'lü patlat";

  @override
  String get badgeNeon => 'NEON';

  @override
  String recordWithValue(String best) => 'Rekor: $best';

  // --- Dalga 10 göçü: Profil ekranı ---

  @override
  String get signInOrUpLabel => 'Giriş yap veya kayıt ol';

  @override
  String get signInOrUpButton => 'GİRİŞ YAP / KAYIT OL';

  @override
  String get guestSignInExplanation =>
      'Giriş yaparsan skorların ve ilerlemen hesabına bağlanır.';

  @override
  String get guestName => 'Misafir';

  @override
  String get guestHandleNotSignedIn => 'Misafir · giriş yapmadın';

  @override
  String get appleHandle => '@apple · Apple ile giriş yapıldı';

  @override
  String get guestSessionHandle => '@misafir · Misafir oturumu';

  @override
  String get badgeComboKing => 'KOMBO KRALI';

  @override
  String get badgeComboKingReq => '5× kombo yap';

  @override
  String get badgeMarathon => 'MARATONCU';

  @override
  String get badgeMarathonReq => '50 oyun oyna';

  @override
  String get badgeVideoBuff => 'VİDEO KURDU';

  @override
  String get badgeVideoBuffReq => '1 video izle';

  @override
  String get badgeGoldenFinger => 'ALTIN PARMAK';

  @override
  String get badgeGoldenFingerReq => '10.000 toplam skor';

  @override
  String get badgeTaskHunter => 'GÖREV AVCISI';

  @override
  String get badgeTaskHunterReq => 'Tüm görev ödüllerini al';

  @override
  String get badgeEvolutionMaster => 'EVRİM USTASI';

  @override
  String get badgeEvolutionMasterReq => "Pembe Bornozlu'ya\nulaş";

  @override
  String get badgeEarned => 'Kazanıldı';

  @override
  String get playerProfileTitle => 'OYUNCU PROFİLİ';

  @override
  String get levelLabel => 'SEVİYE';

  @override
  String get nextLevel => 'SONRAKİ SEVİYE';

  @override
  String get totalScoreLabel => 'TOPLAM SKOR';

  @override
  String get gamesPlayedLabel => 'OYNANAN OYUN';

  @override
  String get bestComboLabel => 'EN YÜKSEK KOMBO';

  @override
  String get myBadges => 'ROZETLERİM';

  @override
  String get profilePassRowSub => 'Başarımlarını ve sezon biletini görüntüle';

  @override
  String get profileInviteRowTitle => 'Arkadaşını Davet Et';

  @override
  String get profileInviteRowSub => 'Davet kodunu paylaş, rakibini çağır';

  @override
  String get profileInviteFailed => 'Davet paylaşılamadı. Tekrar dene.';

  @override
  String get profileRoyalCapeBadge => 'Kral Pelerini';

  @override
  String badgesEarnedCount(int count) => '$count/6 KAZANILDI';

  @override
  String get lockedLabel => 'KİLİTLİ';

  // --- Dalga 15 göçü: Tanıtım ekranı (onboarding_screen) ---
  // Değerler göçen ekrandaki gömülü metinlerden aynen alındı
  // (TR görünümünde fark yoktur).

  @override
  String get onboardingTagline => 'COCKROACH MERGE MANIA';

  @override
  String onboardingPageLabel(int page) => 'Tanıtım sayfası $page / 3';

  @override
  String get onboardingNextLabel => 'Sonraki adım';

  @override
  String get onboardingNextStep => 'SONRAKİ ADIM →';

  @override
  String get onboardingSkipLabel => 'Tanıtımı atla';

  @override
  String get onboardingSlide1Title => 'Böcekleri Birleştir, Evrimleştir!';

  @override
  String get onboardingSlide1Body =>
      "Aynı seviyedeki böcekleri çarpıştırarak 13 aşamalı evrim zincirinde efsanevi Pembe Bornozlu'ya ulaş!";

  @override
  String tierLabel(int tier) => 'Tier $tier';

  @override
  String get onboardingSlide2Title => "11 Farklı Oyun Modu & 3'er Bonus!";

  @override
  String get onboardingSlide2Body =>
      'Suika, 2048, Match-3, Balon Patlat ve daha fazlası! Sıkıştığında F16, Raid ve Anne Terliği güçlendiricilerini ateşle.';

  @override
  String get boosterF16Sub => 'Hava Saldırısı';

  @override
  String get boosterRaidSub => 'Sprey Fırtınası';

  @override
  String get boosterSlipperTitle => 'Terlik';

  @override
  String get boosterSlipperSub => 'Anne Terliği';

  @override
  String get onboardingSlide3Title => 'Böcek Stüdyo, GIF & Liderlik!';

  @override
  String get onboardingSlide3Body =>
      'Kendi böceğini giydir, komik GIF ve çıkartmalar üret, arkadaşlarınla paylaş ve liderlik tablosunda zirveye çık!';

  @override
  String get onboardingStudioTitle => 'Stüdyo';

  @override
  String get onboardingStudioSub => 'Böcek Tasarla';

  @override
  String get onboardingGifTitle => 'GIF Üret';

  @override
  String get onboardingGifSub => 'Stories Paylaş';

  @override
  String get onboardingLeaderboardTitle => 'Liderlik';

  @override
  String get onboardingLeaderboardSub => 'Haftalık Lig';

  @override
  String get onboardingLoadingText =>
      'Böcek sesleri ve 11 oyun sahnesi hazırlanıyor...';

  @override
  String get onboardingTapToStartLabel => 'Dokun ve başla';

  @override
  String get onboardingTapToStart => 'DOKUN VE BAŞLA!';

  @override
  String get onboardingVersionLine =>
      'v3.0 · Mobil & Masaüstü Dokunmatik Uyumlu';

  // --- Dalga 15 göçü: Açılış ekranı (splash_screen) ---

  @override
  String splashLoadMessage(int index) => switch (index) {
        0 => 'Hamam ısıtılıyor…',
        1 => 'Böcekler sıraya giriyor…',
        2 => 'Terlikler parlatılıyor…',
        3 => 'Kapılar açılıyor…',
        _ => 'Hazır! Macera başlıyor…',
      };

  @override
  String get splashSkip => 'GEÇ ›';

  @override
  String get splashStartButton => 'BAŞLA ›';

  @override
  String get splashContinueButton => 'DEVAM ›';

  @override
  String get splashVersionLabel => 'v1.0 · Tasarım Prototipi';

  @override
  String get splashKicker1 => 'YENİ MACERA';

  @override
  String get splashKicker2 => '11 OYUN MODU';

  @override
  String get splashKicker3 => 'SON ADIM';

  @override
  String get splashTitle1Line1 => 'BÖCEKLERİ BİRLEŞTİR,\n';

  @override
  String get splashTitle1Line2 => 'EFSANEYİ YARAT!';

  @override
  String get splashSubtitle1 =>
      "Aynı böcekleri çarpıştır, 13 aşamalı evrim\nzincirinde Pembe Bornozlu'ya kadar\nyüksel.";

  @override
  String get splashBubbleText => 'LİDER KONUŞTU!';

  @override
  String get linkPopTitle => 'BAĞLA PATLAT';

  @override
  String get stackDropTitle => 'STACK DROP';

  @override
  String get slipperTapTitle => 'TERLİK TAP';

  @override
  String get osmantusTitle => 'OSMANTUŞ';

  @override
  String get screamBugTitle => 'ÇIĞLIK BÖCEK';

  @override
  String get makarayizTitle => 'MAKARAYIZ';

  @override
  String get splashTitle2Line1 => 'HER GÜN YENİ\n';

  @override
  String get splashTitle2Line2 => 'BİR MACERA!';

  @override
  String get splashTitle3Line1 => 'MACERAYA\n';

  @override
  String get splashTitle3Line2 => 'HAZIR MISIN?';

  @override
  String get splashStarting => 'BAŞLIYOR!';

  @override
  String splashLoadingPercent(int percent) => 'YÜKLENİYOR… %$percent';

  @override
  String get splashStartAdventure => 'MACERAYA BAŞLA';

  @override
  String get splashPressToStart => 'Başlamak için butona bas!';

  // --- Dalga 15 göçü: Üst bar (top_bar) ---

  @override
  String levelBadge(int level, bool compact) =>
      compact ? 'LVL$level' : 'LVL $level';

  @override
  String get energyFull => 'DOLU';

  // --- Dalga 15 göçü: Hesap ekranı (auth_screen) ---

  @override
  String get authSessionOpen => 'Oturum açık';

  @override
  String get accountTitle => 'HESAP';

  @override
  String get authCardSubtitle =>
      'Kullanıcı adı + şifre ile gerçek hesap. Skorlar sıralamaya bağlanır.';

  @override
  String get usernameHint => 'Kullanıcı adı';

  @override
  String get passwordHint => 'Şifre';

  @override
  String get continueWithApple => 'Apple ile devam';

  @override
  String get continueWithGoogle => 'Google ile devam';

  @override
  String get authHeaderRegister => 'KAYIT';

  @override
  String get authHeaderLogin => 'GİRİŞ';

  @override
  String get closeLabel => 'Kapat';

  @override
  String get signOutButton => 'Çıkış';

  @override
  String get loginTab => 'Giriş';

  @override
  String get registerTab => 'Kayıt';

  @override
  String get createAccountButton => 'HESAP OLUŞTUR';

  @override
  String get signInButton => 'GİRİŞ YAP';

  @override
  String get authUsernameRequired => 'Kullanıcı adı gir.';

  @override
  String get authUsernameInvalid =>
      'Kullanıcı adı 3–20 karakter olmalı; yalnızca küçük harf, rakam ve alt çizgi kullan.';

  @override
  String get authPasswordRequired => 'Şifre gir.';

  @override
  String get authPasswordTooShort => 'Şifre en az 6 karakter olmalı.';

  @override
  String get authPasswordTooLong => 'Şifre en fazla 128 karakter olabilir.';

  @override
  String get authPasswordInvalid => 'Şifre geçersiz karakter içeriyor.';

  @override
  String get authGenericFailed => 'İşlem tamamlanamadı. Tekrar dene.';

  @override
  String get authWrongPassword => 'Şifre yanlış.';

  @override
  String get authUserNotFound => 'Kullanıcı bulunamadı — önce kayıt ol.';

  @override
  String get authUsernameTaken => 'Bu kullanıcı adı zaten kayıtlı — giriş yap.';

  @override
  String get authTooManyAttempts =>
      'Çok fazla başarısız deneme. Biraz bekleyip tekrar dene.';

  @override
  String get authSignOutFailed => 'Oturum kapatılamadı. Tekrar dene.';

  @override
  String get authSignInSuccess => 'Giriş yapıldı.';

  @override
  String get authRegisterSuccess => 'Hesabın oluşturuldu, giriş yapıldı.';

  @override
  String get authRegisterLocalOnly =>
      'Hesabın bu cihazda oluşturuldu; bulut kaydı bir sonraki girişte tamamlanacak.';

  @override
  String get settingsResetFailed => 'İlerleme sıfırlanamadı. Tekrar dene.';

  @override
  String get settingsResetDone => 'İlerleme sıfırlandı.';

  @override
  String get onboardingSaveFailed => 'Kaydedilemedi. Tekrar dene.';

  @override
  String get orDivider => 'VEYA';

  // --- Dalga 20 göçü: Oyun + sonuç ekranı (game_screen, result_screen) ---

  @override
  String get comboTimeoutReason => 'SÜRE DOLDU';

  @override
  String get comboMissReason => 'ISKA';

  @override
  String comboBreakToast(String reason) => 'KOMBO BİTTİ: $reason';

  @override
  String milestoneToast(String title) => 'YENİ: $title';

  @override
  String get speechAydinlat =>
      'Kurban olduğum şuraları bir aydınlat hele!';

  @override
  String get speechSlipper => 'Şılapp! Anne Terliği indi!';

  @override
  String get speechSpray => 'Fısss! Raid tertemiz etti!';

  @override
  String get howToTitle => 'Suika Arena — Nasıl Oynanır?';

  @override
  String get howToBody =>
      'Alana dokun — sıradaki böcek tam oraya düşer. Aynı tier iki böcek çarpışınca bir üst tier doğar, skor katlanır. Yığın kırmızı tehlike çizgisini aşarsa oyun biter.\n\nGüçlendiriciler:\n• Raid Spreyi küçük böcekleri temizler.\n• Sarsıntı yığını yeniden yerleştirir.\n• Aydınlat Hele! ise F16 ile gelip alanı bombalar.';

  @override
  String get understoodButton => 'ANLADIM';

  @override
  String get gameScoreLabel => 'SKOR';

  @override
  String get gameBestLabel => 'REKOR';

  @override
  String get gameNextLabel => 'SIRADAKİ';

  @override
  String get gamePausedTitle => 'OYUN DURAKLATILDI';

  @override
  String pausedScoreLine(int score) => 'Duraklatıldı · Skor $score';

  @override
  String get resumeButtonCaps => 'DEVAM ET';

  @override
  String get restartLevelButton => 'YENİDEN BAŞLA';

  @override
  String get finishGameButton => 'OYUNU BİTİR';

  @override
  String get surviveLabel => 'HAYATTA KAL';

  @override
  String bossLabel(String name) => '👑 BOSS: $name';

  @override
  String chapterLabel(int id) => 'Bölüm $id';

  @override
  String overflowingCountdown(String seconds) => 'TAŞIYOR! ${seconds}s';

  @override
  String get nearLineWarning => 'ÇİZGİYE YAKLAŞTIN';

  @override
  String comboToast(int count) => 'KOMBO x$count!';

  @override
  String get boosterRaidLabel => 'RAİD SPREYİ';

  @override
  String get boosterShakeLabel => 'SARSINTI';

  @override
  String get boosterLightLabel => 'AYDINLAT';

  @override
  String boosterCountLabel(String label, int count) =>
      '$label. $count adet';

  @override
  String shareScoreSnack(int score) =>
      'Skorun panoya kopyalandı: $score Puan! #LululuGame';

  @override
  String scoreShareText(int score) =>
      'Lülülü skorum: $score puan! #LululuGame';

  @override
  String get resultSubtitle =>
      "Zirveye, Pembe Bornozlu'ya bir adım daha yaklaştın!";

  @override
  String get levelCompleteTitle => 'SEVİYE TAMAM!';

  @override
  String get resultGameOverTitle => 'OYUN BİTTİ!';

  @override
  String get resultGameOverSubtitle =>
      'Bir daha dene — bir sonraki tur senin!';

  @override
  String get bestComboResultLabel => 'EN İYİ KOMBO';

  @override
  String get mergesLabel => 'BİRLEŞTİRME';

  @override
  String get goldEarnedLabel => 'KAZANILAN ALTIN';

  @override
  String get continueWithAdSoon => 'REKLAMLA DEVAM ET · YAKINDA';

  @override
  String get doubleGoldAdSoon => 'REKLAMLA 2X ALTIN · YAKINDA';

  @override
  String get playAgainButton => 'TEKRAR OYNA';

  @override
  String get sharedButton => 'PAYLAŞILDI!';

  @override
  String get shareButton => 'PAYLAŞ';

  @override
  String get shareScoreFailed => 'Skor kartı paylaşılamadı.';

  // --- Dalga 20 göçü: Ayarlar (settings_screen) ---

  @override
  String get resetProgressTitle => 'İLERLEMEYİ SIFIRLA';

  @override
  String get resetProgressBody =>
      'Tüm altın, seviye, yüksek skor ve güçlendirici ilerlemeniz sıfırlanacak. Emin misiniz?';

  @override
  String get cancelCaps => 'İPTAL';

  @override
  String get resetButton => 'SIFIRLA';

  @override
  String accountDeletedPartialSnack(int failedCount) =>
      'Hesabın silindi, ancak $failedCount temizlik adımı tamamlanamadı.';

  @override
  String accountDeleteFailed(String error) => 'Hesap silinemedi: $error';

  @override
  String get accountDeletedSnack => 'Hesabın silindi. Oturum kapatıldı.';

  @override
  String signedInAs(String displayName) => '$displayName · Oturum açık';

  @override
  String get signInOrUpSlash => 'Giriş yap / kayıt ol';

  @override
  String get sfxTitle => 'Ses Efektleri';

  @override
  String get sfxSubtitle => 'Birleştirme ve tıklama sesleri';

  @override
  String get vibrationTitle => 'Titreşim';

  @override
  String get vibrationSubtitle => 'Birleştirmede hafif titreşim';

  @override
  String get languageTitle => 'Dil';

  @override
  String get languageSubtitle => 'Oyun dili: Türkçe veya English';

  @override
  String get dangerLineLabel => 'TEHLİKE HATTI';

  @override
  String get dangerAlertLabel => 'TEHLİKE!';

  @override
  String get privacyTitle => 'GİZLİLİK POLİTİKASI';

  @override
  String get privacySubtitle => 'Toplanan veriler ve saklama';

  @override
  String get deletingLabel => 'SİLİNİYOR…';

  @override
  String get confirmDeleteAgain => 'EMİN MİSİN? TEKRAR DOKUN';

  @override
  String get deleteAccountButton => 'Hesabı Sil';

  @override
  String get pleaseWait => 'Lütfen bekle…';

  @override
  String get deleteAccountArmedSub =>
      'Hesabın silinecek ve oturum kapatılacak';

  @override
  String get deleteAccountSub => 'Hesabı sil ve oturumu kapat';

  @override
  String get voiceTitle => 'Böcek Seslendirmeleri';

  @override
  String get voiceSubtitle => 'Karakter replikleri ve efektleri';

  @override
  String get howToPlayRowTitle => 'NASIL OYNANIR';

  @override
  String get howToPlayRowSub => 'Oyun kuralları, birleştirme ve güçler';

  @override
  String get resetProgressRowTitle => 'İlerlemeyi Sıfırla';

  @override
  String get resetProgressRowSub =>
      'Tüm kayıtlı oyun verilerini temizle';

  // --- Dalga 20 göçü: Gizlilik politikası (privacy_policy_screen) ---

  @override
  String get deleteAccountCaps => 'HESABI SİL';

  @override
  String get privacyIntro =>
      'LÜLÜLÜ, oyunu oynamak için gereken verileri işler. Bu metin, oyunun hangi verileri topladığını, nerede sakladığını ve verilerini nasıl silebileceğini açıklar.';

  @override
  String get privacySection1Title => '1. Topladığımız veriler';

  @override
  String get privacySection1Body1 =>
      'Hesap bilgileri: kayıt olurken veya giriş yaparken verdiğin kullanıcı adı, görünen ad ve e-posta adresi. Apple veya Google ile girişte, o servisin paylaştığı ad ve e-posta kullanılır.';

  @override
  String get privacySection1Body2 =>
      'Oyun verileri: skorların, coin ve seviye ilerlemen, görev durumun ve oyun ayarların (müzik, ses, titreşim).';

  @override
  String get privacySection1Body3 =>
      'Sohbet mesajları: yalnızca sohbet özelliğini kullanırsan, gönderdiğin mesajlar.';

  @override
  String get privacySection1Body4 =>
      'Mikrofon ses düzeyi: yalnızca Çığlık Böceği modunda ve izninle; oyun sesin şiddetini (desibel) ölçer. Ses kaydı tutulmaz ve ses dosyası gönderilmez.';

  @override
  String get privacySection2Title => '2. Veriler nerede saklanır';

  @override
  String get privacySection2Body1 =>
      'Cihazında: oturum, ilerleme ve ayarlar cihazındaki yerel kayıtta tutulur.';

  @override
  String get privacySection2Body2 =>
      'Bulutta (yalnızca giriş yaptıysan ve çevrimiçi eşitleme açıksa): skorların, görünen adın ve sohbet mesajların Firebase (Auth + Firestore) üzerinde saklanır. Firebase yapılandırılmadıysa veriler yalnızca cihazında kalır.';

  @override
  String get privacySection2Body3 =>
      'Çevrimdışıyken gönderilemeyen skor ve ilerleme güncellemeleri cihazında kuyrukta bekler, bağlantı gelince gönderilir.';

  @override
  String get privacySection3Title => '3. Paylaşım ve takip';

  @override
  String get privacySection3Body1 =>
      'Oyun, verilerini üçüncü taraf reklam veya analitik şirketleriyle paylaşmaz; bu sürümde analitik ya da reklam takip SDK’sı bulunmaz.';

  @override
  String get privacySection3Body2 =>
      'Reklam gösterimi bu sürümde yalnızca cihaz içi bir yer tutucudur; gerçek bir reklam ağına bağlanılmaz.';

  @override
  String get privacySection4Title => '4. Satın almalar';

  @override
  String get privacySection4Body1 =>
      'Oyun içi satın almalar uygulama mağazası (App Store / Google Play) üzerinden yapılır. Ödeme bilgilerin oyun tarafından toplanmaz.';

  @override
  String get privacySection5Title => '5. Verilerini silme';

  @override
  String get privacySection5Body1 =>
      'Cihazındaki ilerlemeyi Ayarlar > İlerlemeyi Sıfırla ile temizleyebilirsin.';

  @override
  String get privacySection5Body2 =>
      'Uygulamayı kaldırmak cihazındaki yerel oyun verilerini siler.';

  @override
  String get privacySection5Body3 =>
      'Hesabını aşağıdaki düğmeyle silebilirsin: cihazındaki hesap kaydı ve oyun ilerlemen silinir, oturumun kapatılır; giriş yaptıysan bulutta saklanan profil, skor ve sohbet mesajı kopyaların da silinir ve hesap kaydın kapatılır.';

  @override
  String get privacySection6Title => '6. Değişiklikler';

  @override
  String get privacySection6Body1 =>
      'Bu metin değişirse güncellenmiş hâli oyun içinde yayınlanır.';

  // --- Dalga 20 göçü: Bölüm haritası (campaign_map_screen + campaign_map_sheet) ---

  @override
  String get campaignSuikaHeader => '🪳 SUIKA ARENASI (80 BÖLÜM)';

  @override
  String get campaign2048Header => '🔢 LÜLÜLÜ 2048';

  @override
  String get campaignMapTitle => 'Bölüm Haritası';

  @override
  String chapterLabelCaps(int id) => 'BÖLÜM $id';

  @override
  String get levelGoalTitle => '🎯 BÖLÜM HEDEFİ';

  @override
  String secondsLabel(int seconds) => '$seconds sn';

  @override
  String movesLabel(int moves) => '$moves atış';

  @override
  String pointsLabel(int points) => '$points puan';

  @override
  String get bareTierLabel => 'Tier';

  @override
  String get upNextLabel => 'SIRADA';

  @override
  String chestUnlockedToast(
    int stars,
    int coins,
    int boosterCount,
    String boosterName,
  ) =>
      '🎁 $stars⭐ Sandığı Açıldı: +$coins Altın & +$boosterCount $boosterName!';

  @override
  String get campaignSheetTitle => '80 SEVİYE KAMPANYA HARİTASI';

  @override
  String get campaignSheetSubtitle =>
      '8 Bölüm · 8 Boss Savaşı · 24 Yıldız Sandığı';

  @override
  String chapterBannerTitle(int index, String title) =>
      'BÖLÜM $index: $title';

  @override
  String bossBannerLine(int id, String bossName, int hp, String hazard) =>
      '👑 Boss #$id: $bossName ($hp HP) · Tehlike: $hazard';

  @override
  String levelRangeShort(int start, int end) => 'Sv $start-$end';

  @override
  String chestStarsLabel(int stars) => '$stars⭐ Sandık';

  @override
  String get claimedPlain => 'Alındı';

  @override
  String chestRewardLine(int coins, int count) => '+$coins🪙 +$count⚡';

  @override
  String get bossShort => 'BOSS';

  // --- Dalga 20 göçü: Sohbet (chat_lobby_screen, chat_screen) ---

  @override
  String onlinePlayersCount(int count) => '$count ÇEVRİMİÇİ';

  @override
  String levelShort(int level) => 'Sv. $level';

  @override
  String get messageHint => 'Mesaj yaz…';

  @override
  String get messageSendFailed => 'Mesaj gönderilemedi. Tekrar dene.';

  @override
  String get stickerSendFailed => 'Çıkartma gönderilemedi. Tekrar dene.';

  @override
  String get quickStickerTitle => 'HIZLI BÖCEK ÇIKARTMASI GÖNDER';

  @override
  String get notSentLocalOnly => '⚠ Gönderilemedi · Yalnız bu cihazda';

  @override
  String get cloudSendFailedNote =>
      'Buluta gönderilemedi — mesajların yalnız bu cihazda görünüyor.';

  @override
  String get retryCaps => 'TEKRAR DENE';

  @override
  String get guildMessageHint => 'Loncaya mesaj yaz…';

  // --- Dalga 20 göçü: Başarım toast'ı + pass (achievement_toast_overlay) ---

  @override
  String get achievementUnlockedTitle => 'BAŞARIM AÇILDI!';

  @override
  String achievementRewardLine(int coins, int xp) =>
      '+$coins 🪙 · +$xp XP';

  @override
  String titleRewardLine(String title) => 'Unvan: $title';

  @override
  String get masteryPassTitle => 'USTALIK & LÜLÜLÜ PASS';

  @override
  String masteryHeaderLine(String title, int unlocked, int total) =>
      'Unvan: $title · $unlocked/$total Başarım';

  @override
  String seasonTierLine(int tier, int xp, int nextXp) =>
      'Sezon Kademesi: $tier / 20  ($xp / $nextXp XP)';

  @override
  String get goldPassActive => 'ALTIN BİLET AKTİF';

  @override
  String get goldPassOpen => 'ALTIN BİLET AÇ';

  @override
  String achievementsCountLine(int unlocked) =>
      '30 Başarım ($unlocked/30)';

  @override
  String passTierLabel(int tier) => 'Lülülü Pass ($tier/20)';

  @override
  String get allAchievementsLabel => 'Tümü (30)';

  @override
  String achievementRewardCompact(int coins, int xp) =>
      '+$coins🪙 +${xp}XP';

  @override
  String get unlockedShort => 'AÇILDI';

  @override
  String get freeTrackTitle => 'ÜCRETSİZ';

  @override
  String get goldPassTitle => 'ALTIN BİLET';

  @override
  String get collectButton => 'TOPLA';

  // --- Dalga 20 göçü: Skor tablosu (leaderboard_screen) ---

  @override
  String get leaderboardTitle => 'SKOR TABLOSU';

  @override
  String get weeklyLabel => 'Haftalık';

  @override
  String get leaderboardLoadingLabel => 'Skor tablosu yükleniyor';

  @override
  String get noScoresYet => 'Henüz kaydedilmiş skor yok';

  @override
  String get noScoresHint =>
      'Bir oyun oyna — skorun kaydedilince burada görünecek.';

  // --- Dalga 20 göçü: Hesap (auth_screen, auth_panel) ---

  @override
  String get applePlayerFallback => 'Apple Oyuncu · apple';

  @override
  String get guestContinueLabel => 'Misafir olarak devam et';

  @override
  String get guestContinueButton => 'MİSAFİR DEVAM ET';

  @override
  String get registerButtonShort => 'KAYIT OL';

  @override
  String get loginButtonShort => 'GİRİŞ';

  @override
  String get usernameHintDetailed => 'Kullanıcı adın (min 3 karakter)';

  @override
  String get passwordHintDetailed => 'Şifre (min 6 karakter)';

  // --- Dalga 20 göçü: Stüdyo (studio_screens) ---

  @override
  String get linkCopiedToast => 'Bağlantı kopyalandı — paylaşmaya hazır';

  @override
  String get videoPreviewBadge => 'ÖNİZLEME';

  @override
  String get videoSharedToast => 'Video paylaşıldı';

  @override
  String get videoTextCopiedToast => 'Video bilgisi panoya kopyalandı';

  @override
  String get videoAddedToDownloadsToast => "Video İndirilenler'e eklendi";

  @override
  String videoPlayPauseLabel(bool isPlaying, String title) =>
      isPlaying ? 'Duraklat: $title' : 'Oynat: $title';

  @override
  String likeLabel(String count, bool liked) =>
      liked ? 'Beğen: $count beğeni, beğenildi' : 'Beğen: $count beğeni';

  @override
  String get shareLabel => 'Paylaş';

  @override
  String get downloadLabel => 'İndir';

  @override
  String get upNextVideosTitle => 'SIRADAKİ VİDEOLAR';

  @override
  String playVideoLabel(String title, String meta) =>
      '$title videosunu oynat, $meta';

  @override
  String get draftSavedToast =>
      'Taslak kaydedildi! Yükle ekranından paylaşabilirsin.';

  @override
  String get studioToolTrim => 'KIRP';

  @override
  String get studioToolText => 'YAZI';

  @override
  String get studioToolSticker => 'STİCKER';

  @override
  String get trimClipTitle => 'KLİBİ KIRP';

  @override
  String get trimEndLabel => 'Kırpma, seçili bölümün bitişi';

  @override
  String get selectedSectionPrefix => 'Seçili bölüm: ';

  @override
  String get totalDurationSuffix => ' · Toplam 0:47';

  @override
  String get addTextTitle => 'YAZI EKLE';

  @override
  String get videoCaptionHint => 'Videona yazı yaz…';

  @override
  String get captionPreviewNote => 'Yazı, önizlemede anında görünür.';

  @override
  String get chooseStickerTitle => 'STİCKER SEÇ';

  @override
  String stickerLabel(int index) => 'Sticker $index';

  @override
  String get saveAndPreviewLabel => 'Kaydet ve önizle';

  @override
  String get saveAndPreviewButton => 'KAYDET VE ÖNİZLE';

  @override
  String get draftShareableNote =>
      'Taslak, Yükle ekranından paylaşılabilir.';

  @override
  String get uploadDefaultTitle => 'Böcek Birleştirme Rekorum!';

  @override
  String get videoUploadedSnack => "Video başarıyla Stüdyo'ya yüklendi!";

  @override
  String get chooseFileLabel =>
      'Dosya seç: MP4 veya MOV, en fazla 500 MB';

  @override
  String get chooseFileButton => 'DOSYA SEÇ';

  @override
  String get fileConstraintsNote => 'MP4 veya MOV · en fazla 500 MB';

  @override
  String get videoTitleLabel => 'VİDEO BAŞLIĞI';

  @override
  String get videoTitleHint => 'örn. Rekor birleştirme anım!';

  @override
  String get startUploadLabel => 'Yüklemeyi başlat';

  @override
  String get startUploadButton => 'YÜKLEMEYİ BAŞLAT';

  @override
  String get gifDefaultCaption => 'DANS ZAMANI!';

  @override
  String get gifCreatedSnack => 'GIF oluşturuldu ve kaydedildi!';

  @override
  String get chooseFramesTitle => 'KARELERİ SEÇ';

  @override
  String get selectedFramesNote =>
      'Seçili kareler önizlemede sırayla oynar.';

  @override
  String get textAndSpeedTitle => 'METİN & HIZ';

  @override
  String get speedSlow => 'YAVAŞ';

  @override
  String get speedNormal => 'NORMAL';

  @override
  String get speedFast => 'HIZLI';

  @override
  String get createGifLabel => 'GIF oluştur';

  @override
  String deletedItemSnack(String title) => 'Silindi: $title';

  @override
  String get storageTitle => 'DEPOLAMA';

  @override
  String storageUsedSuffix(int count) =>
      ' kullanıldı · 4 GB toplam · $count öğe';

  @override
  String playItemLabel(String title) => 'Oynat: $title';

  @override
  String nowPlayingLabel(String title) => 'Oynatılıyor: $title';

  @override
  String deleteItemLabel(String title) => 'Sil: $title';

  @override
  String get deleteDownloadTitle => 'İndirilen dosyayı sil?';

  @override
  String deleteDownloadConfirm(String title) =>
      '"$title" indirilenlerden silinecek. Emin misin?';

  // --- Dalga 33 göçü (W33-1): erişilebilirlik etiketleri ---
  // Yalnız anahtar eklendi; UI göçü sonraki dalgada (kaynak metinler
  // lululu_dock_bar.dart, top_bar.dart, auth_panel.dart ve
  // shop_dialog.dart'ta gömülü duruyor).

  @override
  String dockUnreadLabel(String label, String badge) =>
      '$label, $badge okunmamış mesaj';

  @override
  String get energyLabel => 'Enerji';

  @override
  String get showPasswordLabel => 'Şifreyi göster';

  @override
  String get hidePasswordLabel => 'Şifreyi gizle';

  @override
  String get addCoinPackLabel => 'Coin paketi ekle';

  @override
  String shopBuyItemLabel(String title, String priceText) =>
      '$title satın al, $priceText';

  @override
  String shopBuyPowerUpLabel(String name, int cost) =>
      '$name satın al, $cost coin';

  // --- Dalga 55 göçü (W55-3): Mağaza (shop_dialog) — yalnız anahtar ---

  @override
  String get shopModeSuikaArena => 'Suika Arena';

  @override
  String get shopPowerRaidSprayName => 'Raid Spreyi';

  @override
  String get shopPowerRaidSprayDesc => 'Küçük böcekleri temizler';

  @override
  String get shopPowerSlipperShakeName => 'Terlik Sarsıntısı';

  @override
  String get shopPowerSlipperShakeDesc => 'Alanı sarsıp yerleşimi düzeltir';

  @override
  String get shopPowerLightItUpName => 'Aydınlat Hele!';

  @override
  String get shopPowerLightItUpDesc => 'F16 bombardımanı — 3 böceği yakıp geçer';

  @override
  String get shopModeGrid2048 => '2048 Grid';

  @override
  String get shopPowerUndoName => 'Geri Al';

  @override
  String get shopPowerUndoNameCaps => 'GERİ AL';

  @override
  String get shopPowerUndoDesc => 'Son hamleyi geri alır';

  @override
  String get shopPowerShuffleName => 'Karıştır';

  @override
  String get shopPowerShuffleNameCaps => 'KARIŞTIR';

  @override
  String get shopPowerShuffleDesc => "Izgara'yı karıştırır, kilidi açar";

  @override
  String get shopPowerMergePairName => 'Çiftleştir';

  @override
  String get shopPowerMergePairNameCaps => 'ÇİFTLEŞTİR';

  @override
  String get shopPowerMergePairDesc => 'Rastgele iki aynı karoyu birleştirir';

  @override
  String get shopModeBalloonPop => 'Balon Patlat';

  @override
  String get shopPowerTripleArrowName => 'Üçlü Ok';

  @override
  String get shopPowerTripleArrowDesc => 'Tek atışta 3 balonu deler';

  @override
  String get shopPowerBombBalloonName => 'Bomba Balon';

  @override
  String get shopPowerBombBalloonDesc => 'Alan patlatması yapar';

  @override
  String get shopPowerSlowName => 'Yavaşlat';

  @override
  String get shopPowerSlowNameCaps => 'YAVAŞLAT';

  @override
  String get shopPowerSlowBalloonDesc => 'Balonları 10 sn yavaşlatır';

  @override
  String get shopModeMatch3 => 'Match 3';

  @override
  String get shopPowerHammerName => 'Çekiç';

  @override
  String get shopPowerHammerDesc => 'Tek karo kırar';

  @override
  String get shopPowerBombName => 'Bomba';

  @override
  String get shopPowerBombDesc => '3×3 alanı patlatır';

  @override
  String get shopPowerColorHunterName => 'Renk Avcısı';

  @override
  String get shopPowerColorHunterDesc => 'Bir türün hepsini toplar';

  @override
  String get shopModeLinkPop => 'Bağla Patlat';

  @override
  String get shopPowerChainExtenderName => 'Zincir Uzatıcı';

  @override
  String get shopPowerChainExtenderDesc => 'Zincir hakkını artırır';

  @override
  String get shopPowerLightningName => 'Yıldırım';

  @override
  String get shopPowerLightningDesc => 'Rastgele bir zincir oluşturur';

  @override
  String get shopPowerMagnetName => 'Mıknatıs';

  @override
  String get shopPowerMagnetDesc => 'Aynı türü birbirine çeker';

  @override
  String get shopModeStackDrop => 'Stack Drop';

  @override
  String get shopPowerFreezeName => 'Dondur';

  @override
  String get shopPowerFreezeNameCaps => 'DONDUR';

  @override
  String get shopPowerFreezeDesc => 'Sallantıyı durdurur';

  @override
  String get shopPowerWidenName => 'Genişlet';

  @override
  String get shopPowerWidenNameCaps => 'GENİŞLET';

  @override
  String get shopPowerWidenDesc => 'Dilimi büyütür';

  @override
  String get shopPowerSlowStackDesc => 'Düşüş hızını azaltır';

  @override
  String get shopModeSlipperTap => 'Terlik Tap';

  @override
  String get shopPowerDoubleSlipperName => 'Çift Terlik';

  @override
  String get shopPowerDoubleSlipperNameCaps => 'ÇİFT TERLİK';

  @override
  String get shopPowerDoubleSlipperDesc => 'Tek dokunuşta çift vuruş';

  @override
  String get shopPowerGoldenSlipperName => 'Altın Terlik';

  @override
  String get shopPowerGoldenSlipperNameCaps => 'ALTIN TERLİK';

  @override
  String get shopPowerGoldenSlipperDesc => 'Süreli 2x puan';

  @override
  String get shopPowerBugSprayName => 'Böcek İlacı';

  @override
  String get shopPowerBugSprayDesc => 'Ekrandaki böcekleri temizler';

  @override
  String get shopModeNestDefense => 'Yuva Savunması';

  @override
  String get shopPowerNestShieldName => 'Yuva Kalkanı';

  @override
  String get shopPowerNestShieldDesc => 'Bir kaçışı affeder';

  @override
  String get shopModeOsmantus => 'Osmantuş';

  @override
  String get shopPowerDikkisBoostName => 'Dıkkış Boost';

  @override
  String get shopPowerDikkisBoostDesc => 'Tempo artışı — halka yavaşlar';

  @override
  String get shopPowerWideRingName => 'Geniş Halka';

  @override
  String get shopPowerWideRingDesc => 'Hedef halkayı büyütür';

  @override
  String get shopPowerMicrophoneName => 'Mikrofon';

  @override
  String get shopPowerMicrophoneDesc => 'Komboyu bir hatada korur';

  @override
  String get shopModeScreamBug => 'Çığlık Böcek';

  @override
  String get shopPowerJumpBootsName => 'Zıplama Botu';

  @override
  String get shopPowerJumpBootsDesc => 'Engelleri aşar';

  @override
  String get shopPowerShieldName => 'Kalkan';

  @override
  String get shopPowerShieldDesc => 'Bir hatayı affeder';

  @override
  String get shopPowerNitroName => 'Nitro';

  @override
  String get shopPowerNitroNameCaps => 'NİTRO';

  @override
  String get shopPowerNitroDesc => 'Hız ve puan artışı';

  @override
  String get shopModeMakarayiz => 'Makarayız';

  @override
  String get shopPowerBeatFreezeName => 'Beat Dondur';

  @override
  String get shopPowerBeatFreezeDesc => 'Ritmi yavaşlatır';

  @override
  String get shopPowerAutoReelName => 'Oto Makara';

  @override
  String get shopPowerAutoReelDesc => 'Kısa süre otomatik oynar';

  @override
  String get shopPowerScoreMultiplierName => 'Puan Çarpanı';

  @override
  String get shopPowerScoreMultiplierDesc => 'Süreli 2x puan';

  @override
  String get shopGoldenWeekendTitle => 'ALTIN HAFTA SONU';

  @override
  String get shopGoldenWeekendSubtitle => 'Tüm coin paketlerinde %50 bonus';

  @override
  String get shopFreeChestTitle => 'ÜCRETSİZ SANDIK';

  @override
  String get shopFreeChestDesc => 'Ödüllü reklamlar yakında: ücretsiz Ahşap Sandık + rastgele 1 güçlendirici burada olacak.';

  @override
  String get shopEnergyTitle => 'ENERJİ';

  @override
  String get shopEnergyRefillNote => '5 dk = +1 kalp';

  @override
  String get shopPowerUpsTitle => 'GÜÇLENDİRİCİLER';

  @override
  String get shopPowerUpsNote => 'Moda özel · 33 çeşit';

  @override
  String get shopCoinPacksTitle => 'COİN PAKETLERİ';

  @override
  String get shopChestsAndPotionsTitle => 'SANDIKLAR VE İKSİRLER';

  @override
  String get shopBadgeBest => 'EN İYİ';

  @override
  String get shopBadgeDeal => 'FIRSAT';

  @override
  String get shopBadgeLucky => 'ŞANSLI';

  @override
  String get shopItemEnergyPackTitle => 'Enerji Paketi';

  @override
  String get shopItemEnergyPackDesc => '+10 enerji · anında dolar, bekleme yok';

  @override
  String get shopItemEnergyDepotTitle => 'Enerji Deposu';

  @override
  String get shopItemEnergyDepotDesc => 'Kalbi 30/30 fulle · tek seferde tam enerji';

  @override
  String get shopItemStarPackTitle => 'Yıldız Paketi';

  @override
  String get shopItemStarPackDesc => '1.000 coin + F16 x1';

  @override
  String get shopItemSurpriseBoxTitle => 'Sürpriz Kutu';

  @override
  String get shopItemSurpriseBoxDesc => 'Anne Terliği x1 + Raid x1';

  @override
  String get shopItemHandfulTitle => 'Bir Avuç';

  @override
  String get shopItemHandfulDesc => '1.250 coin';

  @override
  String get shopItemCrateTitle => 'Bir Kasa';

  @override
  String get shopItemCrateDesc => '7.500 coin · +%50 bonus';

  @override
  String get shopItemCoinsMidTitle => 'Makara Paket';

  @override
  String get shopItemCoinsMidDesc => '1.500 coin';

  @override
  String get shopItemCoinsBigTitle => 'Kongo Sandık';

  @override
  String get shopItemCoinsBigDesc => '5.000 coin';

  @override
  String get shopItemRoyalCapeTitle => 'Kraliyet Pelerini';

  @override
  String get shopItemRoyalCapeDesc => 'Efsanevi Kraliyet Pelerini kozmetik görünümü';

  @override
  String get shopCosmeticsTitle => 'Kozmetik';

  @override
  String get shopRoyalCapeOwnedLabel => 'Sahip Olundu';

  @override
  String get shopItemWoodenChestTitle => 'Ahşap Sandık';

  @override
  String get shopItemWoodenChestDesc => 'Anne Terliği x1 + 250 coin';

  @override
  String get shopItemGoldenChestTitle => 'Altın Sandık';

  @override
  String get shopItemGoldenChestDesc => 'Garantili nadir ödül içerir';

  @override
  String get shopItemDoubleCoinTitle => 'Çifte Coin';

  @override
  String get shopItemDoubleCoinDesc => 'Makarayız Puan Çarpanı x2';

  @override
  String get shopItemLuckPotionTitle => 'Şans İksiri';

  @override
  String get shopItemLuckPotionDesc => '2048 Çiftleştir x1';

  @override
  String get shopNotEnoughGoldToast => 'Yetersiz altın! Oyun oynayarak altın kazanabilirsin.';

  @override
  String get shopAddedCoinPackToast => 'Coin paketi sepete eklendi';

  @override
  String get shopEnergyRegenToast => 'Enerji 5 dakikada 1 yenilenir — paketle beklemeden oyna';

  @override
  String get shopEnergyAddedToast => '+10 enerji eklendi — kalbin doldu!';

  @override
  String get shopStoreUnavailableToast => 'Mağaza kullanılamıyor — satın alma yapılamadı.';

  @override
  String get shopEnergyFullToast => 'Enerji 30/30 doldu!';

  @override
  String get shopPowerUpModeOnlyToast => 'Her modun güçlendiricisi yalnızca o modda kullanılır';

  @override
  String get shopAddedStarPackToast => 'Yıldız Paketi sepete eklendi';

  @override
  String get shopAddedSurpriseBoxToast => 'Sürpriz Kutu sepete eklendi';

  @override
  String get shopAddedWoodenChestToast => 'Ahşap Sandık sepete eklendi';

  @override
  String get shopAddedGoldenChestToast => 'Altın Sandık sepete eklendi';

  @override
  String get shopAddedDoubleCoinToast => 'Çifte Coin sepete eklendi';

  @override
  String get shopAddedLuckPotionToast => 'Şans İksiri sepete eklendi';

  @override
  String get energyPackBoughtToast => '+5 enerji eklendi!';

  @override
  String get energyRefundNotice => 'Hiç hamle yapılmadı — 1 enerji iade edildi.';

  @override
  String get shopPurchaseFailedRefundToast => 'Satın alma başarısız oldu, altınların iade edildi.';

  @override
  String get shopPurchaseConfirmTitle => 'Satın almayı onayla';

  @override
  String get shopEnergyEmptyConfirmBody => '+5 enerji için 100 coin harcamak istiyor musun?';

  @override
  String get shopRestorePurchasesLabel => 'Satın alımları geri yükle';

  @override
  String get shopRestoreStartedToast => 'Geri yükleme başlatıldı — satın alımların geri yüklenecek.';

  @override
  String get shopRestoreUnavailableToast => 'Geri yükleme kullanılamıyor — mağaza yok.';

  @override
  String get shopAddedRoyalCapeToast => 'Kraliyet Pelerini sepete eklendi';

  @override
  String shopPurchaseConfirmBody(String itemName, String priceLabel) =>
      '"$itemName" ürününü $priceLabel karşılığında almak istiyor musun?';

  @override
  String shopCoinPriceLabel(int cost) => '$cost coin';

  @override
  String shopPowerUpDescModeSuffix(String desc, String modeName) => '$desc · yalnızca $modeName modunda';

  @override
  String shopPowerUpAddedToCartToast(String name, String modeName) => '$name sepete eklendi ($modeName)';

  @override
  String shopPowerGroupBonusCount(int count) => '$count bonus';

  // --- Dalga 59 (W59-2): erişilebilirlik etiketleri, 2. tur ---

  @override
  String get helpButtonLabel => 'Nasıl oynanır';

  @override
  String get sendMessageLabel => 'Mesajı gönder';

  @override
  String get sendStickerHint => 'Uzun bas: sticker gönder';

  @override
  String get finishRoundLabel => 'Bitir';

  @override
  String profilePillLabel(String name, int level) =>
      'Profil: $name, $level. seviye';

  @override
  String coinPillLabel(String value) => 'Coin: $value, coin paketi ekle';

  // --- W60-2: §3 paylaşılan anahtarlar (i18n göç planı) ---
  @override
  String get pausedStatusCaps => 'DURAKLATILDI';

  @override
  String get finishCaps => 'BİTİR';

  @override
  String get finishLabel => 'Bitir';

  @override
  String get tryAgainCaps => 'YENİDEN';

  @override
  String get retryShort => 'TEKRAR';

  @override
  String get viralBadge => 'VİRAL';

  @override
  String get moveLabel => 'HAMLE';

  @override
  String get timeLabel => 'SÜRE';

  @override
  String get livesLabel => 'CAN';

  @override
  String get newBadge => 'YENİ';

  @override
  String get missedCaps => 'KAÇIRDIN';

  @override
  String get perfectCaps => 'MÜKEMMEL!';

  @override
  String get comboBrokenShort => 'KOMBO KIRILDI';

  @override
  String get understoodLabel => 'Anladım';

  @override
  String get connectTargetHit => 'Hedef tuttu.';

  @override
  String get powerShieldCaps => 'KALKAN';

  @override
  String get statusLabel => 'DURUM';

  @override
  String get resultComplete => 'TAMAM';

  @override
  String get resultOver => 'BİTTİ';

  @override
  String get modeBadgeTitle => 'MOD ROZETİ';

  @override
  String get doubleGoldEarnedCaps => '2X ALTIN KAZANILDI';

  @override
  String perfectCombo(int combo) => 'MÜKEMMEL! X$combo';

  @override
  String comboBrokenReason(String reason) => '$reason · KOMBO KIRILDI';

  @override
  String pauseScoreComboLine(int score, int combo) => 'Skor $score · Kombo x$combo';

  @override
  String arcadeMilestoneScore(int m) => 'SKOR $m!';

  @override
  String featuredBannerLabel(String badge) => 'ÖNE ÇIKAN · $badge';

  @override
  String featuredEndsToday(String clock) => 'Bugün bitiş · $clock';

  // --- W60-2: G2 connect_pop (i18n göç planı) ---
  @override
  String get connectHintIdle => 'Aynı böceği çiz. Kare = o türün hepsi.';

  @override
  String get connectChainPrototype => 'ZİNCİR X2 · +150';

  @override
  String get connectBoardRefreshed => 'Tahta yenilendi.';

  @override
  String get connectLoopHint => 'İpucu: kare yap, türün hepsi gider.';

  @override
  String get connectGroupHint => 'İpucu: bu grubu bağla.';

  @override
  String get connectLoopReady => 'KARE · bırak, hepsi silinsin';

  @override
  String get connectSquareClear => 'KARE TEMİZLİK';

  @override
  String get connectLinesOut => 'Çizgi hakkın bitti.';

  @override
  String get connectChainExtenderHint => 'Zincir Uzatıcı aktif · +3 çizgi hakkı!';

  @override
  String get connectChainExtenderMilestone => 'ZİNCİR UZATICI · +3 ÇİZGİ!';

  @override
  String get connectMagnetHint => 'Mıknatıs / Bomba Halkası kare zinciri kurdu!';

  @override
  String get connectMagnetMilestone => 'MIKNATIS HALKASI · KARE HAZIR!';

  @override
  String get connectChainTag => 'ZİNCİR';

  @override
  String get connectLineStat => 'ÇİZGİ';

  @override
  String get connectWonTitle => 'BAĞLANDI';

  @override
  String get connectLostTitle => 'HAK BİTTİ';

  @override
  String get powerChainPlus => 'ZİNCİR +';

  @override
  String connectSelectedOne(int minLen) => 'Seçili 1 · en az $minLen';

  @override
  String connectSelectedCount(int count) => 'Seçili $count';

  @override
  String connectLongChain(int len) => 'Uzun zincir! $len';

  @override
  String connectMinLength(int minLen) => 'En az $minLen böcek bağla.';

  @override
  String connectSquareHint(int streak, int gained) => 'Kare! x$streak · +$gained';

  @override
  String connectBonusDrop(int points) => 'Bonus düşüş +$points';

  @override
  String connectSquareChain(int gained) => 'KARE · +$gained';

  @override
  String connectChainText(int streak, int gained) => 'ZİNCİR X$streak · +$gained';

  @override
  String connectLoseHint(int target, int lines, int streak) => 'Hedef $target · $lines çizgi · streak x$streak';

  @override
  String connectStatsLine(int cleared, int loops, int streak, int longest) => 'Temiz $cleared · Kare $loops · Max streak x$streak · En uzun $longest';

  @override
  String connectBoltHint(int count) => 'Yıldırım / Tür Temizleyici $count böceği çarptı!';

  @override
  String connectBoltMilestone(int gained) => 'YILDIRIM · +$gained PUAN!';

  @override
  String connectTargetLine(int longest) => 'HEDEF 1.600 · EN UZUN ZİNCİR $longest';

  // --- W60-2: G3 makarayiz (i18n göç planı) ---
  @override
  String get makaraHintIdle => 'Nota beat çizgisine gelince şeride dokun ya da kaydır.';

  @override
  String get makaraBeatLine => 'BEAT ÇİZGİSİNDE BAS!';

  @override
  String get makaraReelOut => 'Makara bitti. Yeniden çek!';

  @override
  String get makaraWrongLane => 'YANLIŞ ŞERİT';

  @override
  String get makaraEarlyTap => 'ERKEN DOKUNDUN';

  @override
  String get makaraFreezeHint => 'BEAT DONDUR · 8 sn notalar dondu!';

  @override
  String get makaraFreezeCallout => 'BEAT DONDUR!';

  @override
  String get makaraAutoHint => 'OTO MAKARA · 6 sn otomatik vuruş!';

  @override
  String get makaraAutoCallout => 'OTO MAKARA!';

  @override
  String get makaraX2Hint => 'PUAN X2 · 12 sn çift puan!';

  @override
  String get makaraX2Active => 'PUAN X2 AKTİF!';

  @override
  String get makaraEndedTitle => 'MAKARA BİTTİ';

  @override
  String get makaraShareLine => 'Makarayız abi!';

  @override
  String get makaraTaglineCaps => 'MAKARAYIZ ABİ!';

  @override
  String get powerScoreX2 => 'PUAN X2';

  @override
  String makaraMissWindow(String reason, int windowMs) => '$reason — vuruş penceresi: ±$windowMs ms';

  @override
  String makaraResultMessage(int bestCombo, int hits, int misses) => 'En iyi kombo x$bestCombo · $hits vuruş · $misses kaçan';

  @override
  String makaraFillPercent(int pct) => 'MAKARA %$pct DOLDU';

  // --- W60-2: G5 osmantus (i18n göç planı) ---
  @override
  String get osmantusHintIdle => 'Halka yeşile dönünce dokun!';

  @override
  String get osmantusDikkisChant => 'DIKKIŞ DIKKIŞ!';

  @override
  String get osmantusHowToBody1 => 'Ritim halkası yeşile döndüğünde İKİLİ TUŞ butonuna dokun! ';

  @override
  String get osmantusHintResume => 'Devam! Halka yeşile dönünce dokun.';

  @override
  String get osmantusPressGreen => 'YEŞİLDE BAS!';

  @override
  String get osmantusMicSaved => 'Mikrofon tuttu, can gitmedi.';

  @override
  String get osmantusDefeatHint => 'Bitti. Osman & Tuş seni yendi.';

  @override
  String get osmantusJustInTime => 'Tam zamanında!';

  @override
  String get osmantusEarlyPress => 'ERKEN BASTIN';

  @override
  String get osmantusWaitGreen => 'Bekle, halka yeşile dönsün.';

  @override
  String get osmantusDikkisBoost => 'DIKKIŞ 2X PUAN!';

  @override
  String get osmantusDikkisHint => 'DIKKIŞ aktif · 12 sn 2X sahne puanı ve geniş ritim!';

  @override
  String get osmantusRingActive => 'HALKA + AKTİF!';

  @override
  String get osmantusRingHint => 'Halka + aktif · 12 sn geniş zamanlama penceresi!';

  @override
  String get osmantusMicShieldCallout => 'MİKROFON KALKANI!';

  @override
  String get osmantusMicShieldHint => 'Mikrofon kalkanı hazır · sıradaki kaçışta can gitmez!';

  @override
  String get osmantusDuoWonTitle => 'İKİLİ YENDİ';

  @override
  String get osmantusHowToBody2 => 'Zamanında basarak kombo yap ve özel sahne güçlerini kullan.';

  @override
  String get powerDikkis => 'DIKKIŞ';

  @override
  String get powerRingPlus => 'HALKA +';

  @override
  String get osmantusCardSub1 => 'Tuşçu · işaretçi';

  @override
  String get osmantusCardSub2 => 'Makara · dinleyen';

  @override
  String get osmantusPressGreenButton => 'YEŞİLDE\nBAS!';

  @override
  String get osmantusDuoButton => 'İKİLİ TUŞ';

  @override
  String osmantusComboBroken(String reason) => 'KOMBO BOZULDU · $reason';

  @override
  String osmantusLateBy(int delta) => 'Biraz geç (+${delta}ms)';

  @override
  String osmantusWarmupMiss(String reason) => '$reason · ısınma turu, can gitmedi';

  @override
  String goodCombo(int combo) => 'İYİ! X$combo';

  @override
  String osmantusEarlyBy(int delta) => 'Biraz erken (${-delta}ms)';

  @override
  String osmantusStatsLine(int maxCombo, int streak) => 'Max combo x$maxCombo · Günlük streak $streak';

  // --- W60-2: G6 terlik_tap (i18n göç planı) ---
  @override
  String get terlikHintIdle => 'Uçan böceği terlikle ez!';

  @override
  String get terlikHowToBody =>
      'Deliklerden çıkan böceklere dokunarak ez. Her vuruş puan verir; kombo büyüdükçe her vuruş daha çok puan getirir. Kaçan böcek komboyu kırar, her 3 ıskada 1 can gider; 3 can bitince tur biter. Boş deliğe dokunmak yalnız komboyu kırar, can almaz. Skor 220’yi geçince tuzaklar belirir: tuzağa dokunmak ıska sayılır, süresinin dolmasını beklersen ceza yoktur. Güçler: Çift Terlik bir sonraki vuruşta fazladan bir böcek daha ezer, Altın Terlik 20 saniye boyunca puanları ikiye katlar, İlaç ekrandaki tüm hedefleri temizler. BİTİR düğmesiyle turu erken bitirebilirsin.';

  @override
  String get terlikEnergyRefundNotice =>
      'Hiç vuruş yapmadan çıktığın için 1 enerjin iade edildi.';

  @override
  String get terlikBonusComboSlipper => 'COMBO x8 TERLİK +1';

  @override
  String get terlikTrapPassed => 'TUZAK GEÇTİ';

  @override
  String get terlikEscaped => 'KAÇTI';

  @override
  String get terlikTrapReplik => 'CIZZT! Tuzağa basma!';

  @override
  String get terlikLuckBurst => 'ŞANS PATLAMA';

  @override
  String get terlikBonusSlipper => 'TERLİK +1';

  // --- W103-2: bonus efekt yazıları (bonus_fx.dart) ---
  @override
  String get effectSlap => 'ŞAK!';

  @override
  String get effectCombo => 'KOMBO!';

  @override
  String get terlikMissedHit => 'BOŞA VURDUN';

  @override
  String get terlikSteppedTrap => 'TUZAĞA BASTIN';

  @override
  String get terlikDoubleReadyHint => 'ÇİFT TERLİK HAZIR · SONRAKİ VURUŞ ÇİFT BÖCEK EZER!';

  @override
  String get terlikDoubleCallout => 'ÇİFT TERLİK!';

  @override
  String get terlikGoldHint => 'ALTIN TERLİK AKTİF · 20 SN BOYUNCA 2X PUAN!';

  @override
  String get terlikGoldCallout => 'ALTIN TERLİK 2X!';

  @override
  String get terlikSprayCallout => 'İLAÇ TEMİZLİĞİ!';

  @override
  String get powerSprayCaps => 'İLAÇ';

  @override
  String get terlikHoleInstruction => 'DELİKTEN ÇIKANI ANINDA EZ!';

  @override
  String get terlikOutTitle => 'TERLİK BİTTİ';

  @override
  String get terlikEmptyHole => 'Boş delik';

  @override
  String get terlikTrapTag => 'TUZAK!';

  @override
  String terlikBonusComboSpray(int combo) => 'COMBO x$combo SPREY +1';

  @override
  String terlikOutOfSlippers(int smashed, int combo, int coins) => 'Terlik yetmedi. Ezilen $smashed · max x$combo · +$coins💰';

  @override
  String terlikHitHint(int combo, int gain) => 'VURUŞ · COMBO X$combo · +$gain';

  @override
  String terlikComboBreakLives(String reason, int remaining) => '$reason · KOMBO KIRILDI · $remaining KAÇIŞA KADAR CAN';

  @override
  String terlikComboBreakLifeLost(String reason, int lives) => '$reason · -1 CAN · KOMBO KIRILDI · $lives CAN KALDI';

  @override
  String terlikStatsLine1(int smashed, int missed, int combo) => 'Ezilen $smashed · Kaçan $missed · Max combo x$combo\n';

  @override
  String terlikStatsLine2(int coins, int slippers, int sprays) => '+$coins coin · terlik +$slippers · sprey +$sprays';

  @override
  String terlikSprayHint(int cleared) => 'İLAÇ SIKILDI · $cleared HEDEF TEMİZLENDİ!';

  @override
  String terlikPauseScore(int score, int smashed) => 'Skor $score · Ezilen $smashed';

  @override
  String terlikSpeedMultiplier(String rate) => 'HIZ X$rate';

  @override
  String terlikHitsChip(int smashed) => 'VURUŞ $smashed';

  @override
  String terlikMissedChip(int missed) => 'KAÇAN $missed!';

  @override
  String terlikHoleSemantics(int hole) => 'Böceği ez, delik $hole';

  // --- W60-2: ek anahtarlar (günlük ödül serisi + chat rozeti) ---
  @override
  String dailyRewardSubtitleStreak(int streak) => '$streak. gün · 500 coin seni bekliyor';

  @override
  String chatBadgeUnreadLabel(String badge) => '$badge okunmamış mesaj';

  // --- W65-1: G7 scream_roach (i18n göç planı) ---
  @override
  String get screamHintIdle => 'Spam dokun = zıpla. Terlik · sprey · tava arasından geç!';

  @override
  String get screamHowToBody =>
      'Dokunarak böceği zıplat; dokunmadığın sürece yer çekimiyle düşer. Puan yalnız kapıların arasından geçerek kazanılır; ne kadar çok zıplarsan kapı başına o kadar çok puan alırsın. İlk 15 saniye oyun daha yavaş ve kapı aralıkları daha geniştir. Kapıya çarparsan veya yerde çok beklersen tur biter. Mikrofon isteğe bağlıdır: mikrofon düğmesiyle açarsan bağırarak da zıplatabilirsin; izin verilmezse dokunarak oynamaya devam edersin. Güçler: Zıplama güçlü bir sıçrama yapar ve bir kapı çarpmasını affeder, Kalkan bir ölümü affeder, Nitro 8 saniye boyunca hızlandırır ve kapı başına +25 puan verir. BİTİR düğmesiyle turu erken bitirebilirsin.';

  @override
  String get screamGatePrototype => 'KAPI X7!';

  @override
  String get screamIdleGround => 'Çimde uyudun! Zıpla / spam et.';

  @override
  String get screamShieldSaved => 'Kalkan tuttu.';

  @override
  String get screamMicPermissionSettings => 'Ses kontrolü için Ayarlar’dan mikrofon izni ver.';

  @override
  String get screamMicDeniedHint => 'Ses izni verilmedi · dokunarak zıplayabilirsin.';

  @override
  String get screamMegaJumpCallout => 'MEGA ZIPLAMA!';

  @override
  String get screamMegaJumpHint => 'Mega zıplama aktif · ilk engel sıyırır!';

  @override
  String get screamShieldBalloonCallout => 'KALKAN BALONU!';

  @override
  String get screamShieldBalloonHint => 'Kalkan balonu aktif · çarpışmayı korur!';

  @override
  String get screamNitroCallout => 'NİTRO ÇIĞLIK!';

  @override
  String get screamNitroHint => 'Nitro aktif · 8 sn hızlı uçuş ve +25 kapı bonusu!';

  @override
  String get powerJumpCaps => 'ZIPLAMA';

  @override
  String get screamMicOffLabel => 'Mikrofonu kapat';

  @override
  String get screamMicOnLabel => 'Bağırarak zıplamayı aç';

  @override
  String get screamVoicePower => 'SES GÜCÜ';

  @override
  String get screamGateStat => 'KAPI';

  @override
  String get screamCrushedTitle => 'EZİLDİN';

  @override
  String get gateTerlikDeath => 'Terlik şılapp!';

  @override
  String get gateTerlikPass => 'Terlik sıyırdı!';

  @override
  String get gateRaidDeath => 'Raid bulutu!';

  @override
  String get gateRaidPass => 'Spreyi geçtin!';

  @override
  String get gateTavaDeath => 'Tava tokattı!';

  @override
  String get gateTavaPass => 'Tava altından!';

  @override
  String get gateTuzakDeath => 'Yapışkan tuzak!';

  @override
  String get gateTuzakPass => 'Tuzaktan kaçtın!';

  @override
  String get gateHamamDeath => 'Tas kafaya!';

  @override
  String get gateHamamPass => 'Hamam tas geçti!';

  @override
  String get gateVuvuzelaDeath => 'Vuvuzela ezdi!';

  @override
  String get gateVuvuzelaPass => 'Kongo koridoru!';

  @override
  String screamDeathLine(String deathLine, int gates) => '$deathLine Kapı $gates';

  @override
  String screamGateStreak(int streak) => 'KAPI X$streak!';

  @override
  String screamCrushedHint(int gates, int streak) => 'Ezildin! Kapı $gates · max spam x$streak';

  @override
  String screamStatsLine(int gates, int streak, int dayStreak) => 'Kapı $gates · Max spam x$streak · Streak $dayStreak';

  @override
  String screamNextGate(int gate) => 'SONRAKİ: KAPI $gate';

  @override
  String screamShoutingPercent(int percent) => '%$percent · BAĞIRIYOR';

  @override
  String screamArcadeHint(String hint) => 'Dokun veya mikrofonu açıp bağırarak zıpla. $hint';

  @override
  String screamPauseScore(int score, int gates) => 'Skor $score · Kapı $gates';
  // --- W65-1: G8 stack_drop (i18n göç planı) ---
  @override
  String get stackHintIdle => 'Dokun. Tam ortala = combo. Kenar kesilir.';

  @override
  String get stackHelpBody =>
      'Dokunarak sallanan bloğu kulenin üstüne bırak. Tam ortala, combo artsın; taşan kenar kesilir. Kuleyi kaçırırsan ya da dilim çok incelirse tur biter!';

  @override
  String get stackPerfectPrototype => 'MÜKEMMEL İSABET! X3';

  @override
  String get stackMissedFall => 'Kaçırdın. Kule yıkıldı.';

  @override
  String get stackSliceThin => 'Dilim çok inceldi.';

  @override
  String get stackMagnetHint => 'Mıknatıs Hizalama & Dondur (4 sn) aktif!';

  @override
  String get stackMagnetMilestone => 'MIKNATIS HİZALAMA & DONDUR!';

  @override
  String get stackWidenHint => 'Geniş Blok aktif · Kule tabanı genişledi!';

  @override
  String get stackWidenMilestone => 'GENİŞ BLOK AKTİF!';

  @override
  String get stackSlowHint => 'Yavaşlatıcı aktif (8 sn)!';

  @override
  String get stackSlowMilestone => 'YAVAŞLATICI AKTİF (8 SN)!';

  @override
  String get stackTowerTag => 'KULE';

  @override
  String get stackFloorStat => 'KAT';

  @override
  String get stackTowerFellTitle => 'KULE DÜŞTÜ';

  @override
  String stackDirectHit(int combo, int gain) => 'TAM İSABET x$combo · +$gain';

  @override
  String stackPerfectHit(int combo) => 'MÜKEMMEL İSABET! X$combo';

  @override
  String stackNearHint(int gain, int floors) => 'Neredeyse · +$gain · kat $floors';

  @override
  String stackNearCallout(int gain) => 'YAKIN! +$gain';

  @override
  String stackEdgeCutHint(int gain, int floors) => 'Kenar kesildi. +$gain · kat $floors';

  @override
  String stackEdgeCutCallout(int gain) => 'KENAR KESİLDİ · +$gain';

  @override
  String stackMilestoneFloors(int m) => '$m KAT!';

  @override
  String stackStatsLine(int floors, int perfects, int nears, int combo) => 'Kat $floors · Perfect $perfects · Near $nears · Max combo x$combo';

  @override
  String stackTutorialHint(String hint) => 'İlk 15 saniye öğretici tempoda. $hint';

  @override
  String stackFloorLabel(int floor) => 'KAT $floor';
  // --- W65-1: G9 yuva_defense (i18n göç planı) ---
  @override
  String get yuvaHintIdle => 'Yuvaya yaklaşan böcekleri durdur!';

  @override
  String get yuvaShieldSaved => 'KALKAN YUVAYI KORUDU · BÖCEK GERİ PÜSKÜRTÜLDÜ!';

  @override
  String get yuvaFellHint => 'Yuva düştü · bir dokunuşla yeniden başla';

  @override
  String get yuvaDoubleHint => 'ÇİFT TERLİK AKTİF · 3 VURUŞ ÇİFT HEDEF EZER!';

  @override
  String get yuvaGoldHint => 'ALTIN TERLİK AKTİF · 12 SN BOYUNCA 2X PUAN!';

  @override
  String get yuvaShieldIceHint => 'KALKAN & BUZ BARİYERİ AKTİF · BÖCEKLER YAVAŞLADI!';

  @override
  String get yuvaMissHint => 'Iska! Kombo sıfırlandı';

  @override
  String get yuvaTitleNewSemantic => 'YUVA SAVUNMASI, YENİ';

  @override
  String get yuvaHowToBody1 => 'Yuvaya ulaşmadan böceklere dokun. ';

  @override
  String get yuvaHowToBody2 => 'Hızlı vuruşlarla kombonu büyüt; üç kaçışta oyun biter.';

  @override
  String get yuvaFellTitle => 'YUVA DÜŞTÜ';

  @override
  String yuvaBugEntered(int lives) => 'Böcek orta deliğe girdi · $lives kaçış hakkı kaldı';

  @override
  String yuvaWaveHit(int wave, int points, int combo) => 'DALGA $wave · VURUŞ +$points · KOMBO x$combo';

  @override
  String yuvaHitHint(int points, int combo) => 'VURUŞ +$points  ·  KOMBO x$combo';

  @override
  String yuvaPauseScore(int score, int hits) => 'Skor $score · Vuruş $hits';

  @override
  String yuvaResultScore(int score, int combo) => 'SKOR $score · KOMBO x$combo';

  @override
  String yuvaHitsPainter(int hits) => 'VURUŞ $hits';

  @override
  String yuvaMissedPainter(int misses) => 'KAÇAN $misses!';
  // --- W65-1: G10 grid_2048 (i18n göç planı) ---
  @override
  String get gridSuperCombo => 'SÜPER!';

  @override
  String get gridTarget2048 => 'HEDEF: 2048 BÖCEK';

  @override
  String get gridHowToTitle => '2048 GRİD NASIL OYNANIR?';

  @override
  String get gridHowToBody1 => 'Tahtayı 4 yöne kaydır — aynı tier böcekler çarpışınca birleşir, yeni böcek doğar. 2048\'e ulaş!\n\n';

  @override
  String get gridHowToBody2 => '• GERİ AL: Son hamleyi geri alır.\n';

  @override
  String get gridHowToBody3 => '• KARIŞTIR: Tahtadaki tüm böceklerin yerlerini karıştırır.\n';

  @override
  String get gridHowToBody4 => '• ÇİFTLEŞTİR: En yüksek eşleşen iki böceği anında birleştirir.';

  @override
  String get gridBoosterNoEffect => 'Bu tahtada güçlendiricinin etkisi yok.';

  @override
  String gridSuperMergeSpeech(String title) => 'LÜLÜLÜ! SÜPER BİRLEŞİM! ($title)';

  @override
  String gridHighestTile(int value) => 'EN YÜKSEK TAŞ: $value';

  @override
  String gridMovesCount(int count) => 'HAMLE $count';

  @override
  String gridPauseStats(int moves, int merges, int streak) => 'Hamle $moves · Birleşim $merges · Seri x$streak';

  // --- W69-1: L10N anahtar dalgası 3 ---

  @override
  String get campaignChapter1 => 'Mutfak Tezgahı';

  @override
  String get campaignChapter2 => 'Diva Malikanesi';

  @override
  String get campaignChapter3 => 'Pikomotions Sahnesi';

  @override
  String get campaignChapter4 => 'Kongo İstilası';

  @override
  String get welcomeStatusReadFail => 'Karşılama durumu okunamadı.';

  @override
  String get welcomeSkipFail => 'Karşılama ekranı atlanmadı. Tekrar deneyin.';

  @override
  String get continueToHomeAnyway => 'Yine de ana ekrana devam et';

  @override
  String get energyLoadTimeout =>
      'Enerji durumu okunamadı. Varsayılan enerjiyle devam ediliyor.';

  @override
  String get bugFamilyTitle => 'BÖCEK AİLESİ';

  @override
  String get bugFamilySubtitle =>
      'İki aynı tier çarpışır, bir üst tier doğar. Zincirin sonu: Pembe Bornozlu. Bir böceğe dokun — sesini duy, repliğini gör.';

  @override
  String get tierRowName1 => 'Bebek Huni';

  @override
  String get tierRowName2 => 'Tencereli Çırak';

  @override
  String get tierRowName3 => 'Makaracı Fan';

  @override
  String get tierRowName4 => 'Pijamalı Dansçı';

  @override
  String get tierRowName5 => 'Hamam Diva';

  @override
  String get tierRowName6 => 'Hamam Can';

  @override
  String get tierRowName7 => 'Kongo Lideri';

  @override
  String get tierRowName8 => 'Hasta Bilge';

  @override
  String get tierRowName9 => 'Millî Formalı';

  @override
  String get tierRowName10 => 'Pembe Ceketli';

  @override
  String get tierRowName11 => 'Beyaz Hayalet';

  @override
  String get tierRowName12 => 'Gri Tişörtlü';

  @override
  String get tierRowName13 => 'Pembe Bornozlu';

  @override
  String get tierRowQuote1 => 'HOP, GELDİM!';

  @override
  String get tierRowQuote2 => 'TENCERE KAFADA, HAZIRIZ!';

  @override
  String get tierRowQuote3 => 'MAKARAYIZ ABİ!';

  @override
  String get tierRowQuote4 => 'DANS PİSTİNE!';

  @override
  String get tierRowQuote5 => 'DİVA GELDİ!';

  @override
  String get tierRowQuote6 => 'HERKES HAVUZDAN ÇIKSIN!';

  @override
  String get tierRowQuote7 => 'LİDER KONUŞTU!';

  @override
  String get tierRowQuote8 => 'BİLGE YORGUN AMA EFSANE!';

  @override
  String get tierRowQuote9 => 'GOLLL LÜLÜLÜ!';

  @override
  String get tierRowQuote10 => 'PEMBE CEKETİM YAKIYOR!';

  @override
  String get tierRowQuote11 => 'BUUUUU! KORKTUN MU?';

  @override
  String get tierRowQuote12 => 'SPORCU BÖCEK GELİYOR!';

  @override
  String get tierRowQuote13 => 'BORNOZUMU GİYDİM KEYİFTEYİM!';

  @override
  String get energyEmptyTitle => 'ENERJİN BİTTİ!';

  @override
  String get energyEmptyBodyStart => 'Kalbin ';

  @override
  String get energyEmptyBodyMiddle =>
      ' — oynamak için 1 enerji gerekir.\nSonraki enerji: ';

  @override
  String get energyEmptyBodyEnd => ' · her 5 dakikada +1 dolar.';

  @override
  String get rewardedAdsSoonCaps => 'ÖDÜLLÜ REKLAMLAR YAKINDA';

  @override
  String get shopEnergyPackButton => 'MAĞAZA · ENERJİ PAKETİ';

  @override
  String get waitForTimerCaps => 'SAYACI BEKLE';

  @override
  String get splashSkipPlain => 'GEÇ';

  @override
  String get splashStartButtonPlain => 'BAŞLA';

  @override
  String get splashContinueButtonPlain => 'DEVAM';

  @override
  String get play2048Label => 'Lülülü 2048 oyununu aç';

  @override
  String get doubleRewardLabel => '2 kat ödül, yakında';

  @override
  String get watchAdChestLabel => 'Reklam izle, ücretsiz sandık aç';

  @override
  String get notifyOnLabel => 'Bildirim açık';

  @override
  String levelTileLabel(int id, int stars, bool locked) =>
      '$id. seviye, $stars yıldız${locked ? ' · Kilitli' : ''}';

  @override
  String chapterTabLabel(int index, int stars) =>
      'Bölüm $index, $stars/30 yıldız';

  @override
  String chestClaimLabel(int stars, String state) => state == 'claimed'
      ? 'Alındı'
      : state == 'locked'
          ? 'Kilitli'
          : 'Ödülü al: $stars yıldız sandığı';

  @override
  String channelSelectLabel(String name) => '$name kanalını seç';

  @override
  String sendStickerLabel(String name) => '$name stickerını gönder';

  @override
  String featuredModeLabel(String title, String subtitle) =>
      '$title modunu oyna: $subtitle';

  // W75-3: L10N anahtar dalgası 4.
  @override
  String get howToPlaySuffix => '— NASIL OYNANIR?';

  @override
  String get connectChainBadge => 'ZİNCİR';

  @override
  String get stackTowerBadge => 'KULE';

  // W79-3: L10N anahtar dalgası 5 (online_screen + leaderboard).
  // TR değerleri online_screen.dart / leaderboard_screen.dart'taki
  // gömülü metinlerden aynen alındı.
  @override
  String get onlineNotifyRemovedSnack => 'Bildirim tercihi kaldırıldı.';

  @override
  String get comingVerySoonCaps => 'ÇOK YAKINDA!';

  @override
  String get onlineComingSoonBody =>
      'Arkadaşlarınla çevrimiçi kapış, loncanla aynı arenada buluş. Online mod yapım aşamasında — açıldığı gün ilk sen öğren.';

  @override
  String get notifyOnCaps => 'BİLDİRİM AÇIK';

  @override
  String get onlineDuelTitle => '1V1 DÜELLO';

  @override
  String get onlineDuelSubtitle => 'Arkadaşına meydan oku, arenada kapış';

  @override
  String get onlineGuildWarsTitle => 'LONCA SAVAŞLARI';

  @override
  String get onlineGuildWarsSubtitle =>
      'Loncanla takım kur, haftalık savaşlara katıl';

  @override
  String get onlineTournamentsTitle => 'CANLI TURNUVALAR';

  @override
  String get onlineTournamentsSubtitle =>
      'Sezonluk turnuvalarda büyük ödülleri topla';

  @override
  String levelWithValue(int level) => 'Seviye $level';

  @override
  String youAsName(String name) => 'SEN · $name';

  @override
  String get continueWithAd => 'REKLAMLA DEVAM ET';

  @override
  String get doubleGoldWithAd => 'REKLAMLA 2X ALTIN';

  @override
  String get ceilingLabel => 'TAVAN';

  @override
  String get balloonHintDrift => 'balonlar süzülüyor · 3 aynı balon patlar';

  @override
  String get balloonHelpBody =>
      'Sürükleyerek nişan al, bırakarak ateş et. 3 aynı balonu birleştirerek patlat; balonlar atıcıya ulaşmadan tahtayı temizle!';

  @override
  String get balloonHintRowDropped =>
      'balonlar süzülüyor · bir sıra daha indi';

  @override
  String balloonRowsInShots(int shots) => '$shots atışta sıra iner';

  @override
  String get holdAimRelease => 'TUT · NİŞAN AL · BIRAK';

  @override
  String get laserAimActive => 'LAZER NİŞAN AKTİF';

  @override
  String get slowColorBombActive => 'YAVAŞLAT & RENK BOMBASI AKTİF!';

  @override
  String get powerTripleArrowCaps => 'ÜÇLÜ OK';

  @override
  String get powerBombCaps => 'BOMBA';

  @override
  String get powerHammerCaps => 'ÇEKİÇ';

  @override
  String get powerHunterCaps => 'AVCI';

  @override
  String get powerLightningCaps => 'YILDIRIM';

  @override
  String get powerMagnetCaps => 'MIKNATIS';

  @override
  String get powerMedicineCaps => 'İLAÇ';

  @override
  String get powerMicrophoneCaps => 'MİKROFON';

  @override
  String get powerBeatFreezeCaps => 'BEAT DONDUR';

  @override
  String get powerAutoReelCaps => 'OTO MAKARA';

  @override
  String get movesLabelCaps => 'HAMLE';

  @override
  String get targetTitle => 'HEDEF';

  @override
  String get movesOutTitle => 'HAMLE BİTTİ';

  @override
  String targetWithValue(String value) => 'HEDEF $value';

  @override
  String get linesLabel => 'ÇİZGİ';


  @override
  String get terlikInstruction => 'DELİKTEN ÇIKANI ANINDA EZ!';


  @override
  String missLifeLost(String reason) => '$reason · -1 CAN · KOMBO KIRILDI';


  @override
  String get yuvaBanner => 'YUVA SAVUNMASI · 360°';

  @override
  String get osmantusDoubleButton => 'İKİLİ TUŞ';

  @override
  String get osmanRoleSub => 'Tuşçu · işaretçi';

  @override
  String get tusRoleSub => 'Makara · dinleyen';

  @override
  String get osmantusRhythmHint =>
      'Ritim halkası yeşile döndüğünde İKİLİ TUŞ butonuna dokun! '
      'Zamanında basarak kombo yap ve özel sahne güçlerini kullan.';

  @override
  String screamTapPercent(int percent) => '%$percent · DOKUN';

  @override
  String get screamSlowStart => ' · İLK 15 SN YAVAŞ';

  @override
  String get balloonMissedAim => 'Iskaladın. Tekrar nişan al.';

  @override
  String get balloonNoStickAim => 'Tutunamadı. Tekrar nişan al.';

  @override
  String balloonPoppedStreak(int streak, int gained) =>
      'Patladı x$streak · +$gained';

  @override
  String balloonPiercingShot(int pierced, int streak) =>
      'Delici atış $pierced balonu deldi · seri x$streak korundu.';

  @override
  String get balloonStuckNeed3 => 'Yapıştı. 3 aynı lazım.';

  @override
  String terlikDropSlipper(int count) => ' · terlik+$count';

  @override
  String terlikDropSpray(int count) => ' · sprey+$count';

  String get balloonCeilingDropped => 'Tavan bir sıra indi.';
  String get balloonLoseReached => 'Balonlar nişancıya dayandı.';
  String get balloonLoseCeiling => 'Tavan indi, yer kalmadı.';
  String get balloonTripleActive => 'Üçlü Ok / Lazer Nişan aktif · 3 balonu deler!';
  String get balloonWaveActive => 'Renk Dalgası & Yavaşlatma (10 sn) aktif!';
  String balloonFireballShot(int take) => 'Ateş Topu / Bomba $take balonu uçurdu!';

  String get balloonOverflowTitle => 'TAŞTI';
  String get balloonComboBrokenMiss => 'KOMBO KIRILDI · ıskaladın';
  String get balloonFireballMilestone => 'ATEŞ TOPU · BOMBA PATLADI!';
  String balloonSuperPop(int popped) => 'SÜPER PATLAMA · $popped';
  String balloonStatsLine(int pop, int fall, int maxStreak, int biggest) =>
      'Patlama $pop · Düşen $fall · Max streak x$maxStreak · En büyük $biggest';

  @override
  String videoViewsShort(int thousands) => '$thousands B görüntülenme';

  @override
  String daysAgo(int days) => '$days gün önce';

  @override
  String weeksAgo(int weeks) => '$weeks hafta önce';

  @override
  String downloadedTodayAt(String time) => 'Bugün $time';

  @override
  String downloadedYesterdayAt(String time) => 'Dün $time';

  @override
  String downloadedDayMonth(int day, String month) => '$day $month';

  @override
  String monthShortName(int month) => const [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ][(month - 1).clamp(0, 11)];

  @override
  String monthFullName(int month) => const [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ][(month - 1).clamp(0, 11)];

  @override
  String get match3HintIdle => 'Komşuyu kaydır. 3 patlar · 4 = bomba.';
  String get match3NoMovesShuffle => 'Hamle kalmadı. Tahta karıştı.';
  String get match3NoMatchCancel => 'Eşleşme yok — hamle iptal.';
  String get match3BombFormed => 'BOMBA oluştu!';
  String get match3HammerGain => '+48 ÇEKİÇ!';
  String get match3HammerBroke => 'Çekiç seçili taşı kırdı!';
  String get match3HammerStrike => 'ÇEKİÇ DARBESİ!';
  String get match3RocketFx => 'ROKET & 3x3 BOMBA!';
  String get match3SphereCallout => 'RENK KÜRESİ!';
  String get osmantusDuoWonHint => 'Bitti. Osman & Tuş seni yendi.';
  String get osmantusMicReady => 'Mikrofon kalkanı hazır · sıradaki kaçışta can gitmez!';
  String get makaraOverTitle => 'MAKARA BİTTİ';
  String get bonusLifePlus => 'CAN +1';
  String get gotItPlay => 'ANLADIM, OYNA!';
  String get chatReportAction => 'Raporla';
  String get chatBlockAction => 'Engelle';
  String get chatUnblockAction => 'Engeli kaldır';
  String get chatReportTitle => 'Mesajı raporla';
  String get chatReportReasonSpam => 'Spam';
  String get chatReportReasonInappropriate => 'Uygunsuz içerik';
  String get chatReportReasonHarassment => 'Taciz';
  String get chatReportReasonOther => 'Diğer';
  String get chatReportSent => 'Raporun gönderildi. Teşekkürler.';
  String get chatReportQueued => 'Raporun kaydedildi, bağlantı gelince gönderilecek.';
  String get chatReportAlreadySent => 'Bu mesajı zaten raporladın.';
  String get chatUserBlocked => 'Kullanıcı engellendi.';
  String get chatUserUnblocked => 'Engel kaldırıldı.';
  String get chatBlockedTitle => 'Engellenenler';
  String get chatBlockedEmpty => 'Engellediğin kimse yok.';
  String get chatTermsTitle => 'Sohbet kuralları';
  String get chatTermsBody => 'Sohbette saygılı ol: hakaret, taciz ve spam yasaktır. Kurallara uymayan mesajlar raporlanabilir ve kaldırılabilir.';
  String get chatTermsAccept => 'Kabul ediyorum';
  String get chatTermsDecline => 'Kabul etmiyorum';
  String get chatTermsRequired => 'Mesaj göndermek için önce sohbet kurallarını kabul et.';
  String get chatGuestBadge => 'MİSAFİR';
  String get chatGuestNameTitle => 'Görünen adını değiştir';
  String get chatGuestNameHint => 'Görünen ad';
  String get chatGuestNameEmpty => 'Ad boş olamaz.';
  String get chatGuestNameSaved => 'Adın kaydedildi.';
  String get chatActionFailed => 'İşlem tamamlanamadı. Tekrar dene.';
  String get chatEmptyChannel => 'Bu kanalda henüz mesaj yok.';
  String get chatOptionsLabel => 'Sohbet seçenekleri';
  String get chatChangeNameAction => 'Adını değiştir';
  String get chatBlockedListAction => 'Engellenenleri gör';
  String get chatDeleteAction => 'Sil';
  String get chatDeleteTitle => 'Mesajı sil?';
  String get chatDeleteBody =>
      'Bu mesaj silinecek. Bu işlem geri alınamaz.';
  String get chatMessageDeleted => 'Mesaj silindi.';
  String get chatDeleteLocalOnly =>
      'Mesaj bu cihazdan silindi; bulut kopyası kalmış olabilir.';
  String match3StatsLine(int merge, int chain, int made, int fired) => 'Birleşim $merge · Max zincir x$chain · Bomba $made/$fired';
  String match3RocketBombGain(int gained) => '+$gained ROKET BOMBA!';
  String match3RocketHint(int n) => 'Satır Roketi & 3x3 Bomba $n taşı uçurdu!';
  String match3HunterGain(int gained) => '+$gained AVCI!';
  String match3SphereHint(int n) => 'Renk Küresi / Avcı $n aynı tür böceği temizledi!';
  String match3SphereFx(int n) => 'RENK KÜRESİ · $n BÖCEK!';
  String osmantusLifeStatus(String reason, int lives) => lives > 0 ? '$reason · $lives can kaldı' : '$reason · son can gitti';
  String terlikSprayedTargets(int cleared) => 'İLAÇ SIKILDI · $cleared HEDEF TEMİZLENDİ!';
  String scoreMilestone(int m) => 'SKOR $m!';
  String balloonBombGain(int gained) => '+$gained BOMBA!';
  String makaraComboBroken(String reason) => 'KOMBO KIRILDI · $reason';
  String osmantusLastError(String reason) => 'Son hata: $reason';
}
