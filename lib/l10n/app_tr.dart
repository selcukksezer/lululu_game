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
  String get resultSubtitle =>
      "Zirveye, Pembe Bornozlu'ya bir adım daha yaklaştın!";

  @override
  String get levelCompleteTitle => 'SEVİYE TAMAM!';

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
  String accountDeleteFailed(String error) => 'Hesap silinemedi: $error';

  @override
  String get accountDeletedSnack => 'Hesabın silindi. Oturum kapatıldı.';

  @override
  String signedInAs(String displayName) => '$displayName · Oturum açık';

  @override
  String get signInOrUpSlash => 'Giriş yap / kayıt ol';

  @override
  String get musicTitle => 'Müzik';

  @override
  String get musicSubtitle => 'Arkaplan müziği';

  @override
  String get sfxTitle => 'Ses Efektleri';

  @override
  String get sfxSubtitle => 'Birleştirme ve tıklama sesleri';

  @override
  String get vibrationTitle => 'Titreşim';

  @override
  String get vibrationSubtitle => 'Birleştirmede hafif titreşim';

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
      'Hesabını aşağıdaki düğmeyle silebilirsin: cihazındaki hesap kaydı silinir ve oturumun kapatılır. Oyun ilerlemen ve bulutta saklanan kopyalar ayrıca silinmez.';

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
  String get shopPowerUndoDesc => 'Son hamleyi geri alır';

  @override
  String get shopPowerShuffleName => 'Karıştır';

  @override
  String get shopPowerShuffleDesc => 'Izgarayı karıştırır, kilidi açar';

  @override
  String get shopPowerMergePairName => 'Çiftleştir';

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
  String get shopPowerFreezeDesc => 'Sallantıyı durdurur';

  @override
  String get shopPowerWidenName => 'Genişlet';

  @override
  String get shopPowerWidenDesc => 'Dilimi büyütür';

  @override
  String get shopPowerSlowStackDesc => 'Düşüş hızını azaltır';

  @override
  String get shopModeSlipperTap => 'Terlik Tap';

  @override
  String get shopPowerDoubleSlipperName => 'Çift Terlik';

  @override
  String get shopPowerDoubleSlipperDesc => 'Tek dokunuşta çift vuruş';

  @override
  String get shopPowerGoldenSlipperName => 'Altın Terlik';

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
  String get shopPowerScoreMultiplierDesc => 'Süreli x2 puan';

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
  String get shopPowerUpsNote => 'Moda özel · 30 çeşit';

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
  String get shopItemStarPackDesc => '25 yıldız + 1.000 coin';

  @override
  String get shopItemSurpriseBoxTitle => 'Sürpriz Kutu';

  @override
  String get shopItemSurpriseBoxDesc => 'Rastgele moddan 1 güçlendirici';

  @override
  String get shopItemHandfulTitle => 'Bir Avuç';

  @override
  String get shopItemHandfulDesc => '1.250 coin';

  @override
  String get shopItemCrateTitle => 'Bir Kasa';

  @override
  String get shopItemCrateDesc => '7.500 coin · +%50 bonus';

  @override
  String get shopItemWoodenChestTitle => 'Ahşap Sandık';

  @override
  String get shopItemWoodenChestDesc => 'Rastgele güçlendirici + coin';

  @override
  String get shopItemGoldenChestTitle => 'Altın Sandık';

  @override
  String get shopItemGoldenChestDesc => 'Garantili nadir ödül içerir';

  @override
  String get shopItemDoubleCoinTitle => 'Çifte Coin';

  @override
  String get shopItemDoubleCoinDesc => '30 dakika boyunca 2× coin';

  @override
  String get shopItemLuckPotionTitle => 'Şans İksiri';

  @override
  String get shopItemLuckPotionDesc => 'Birleşmede kritik şansı artar';

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
}
