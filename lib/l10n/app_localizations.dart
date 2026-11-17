// Madde 95 [P1]: El yazımı yerelleştirme altyapısı — codegen YOK
// (l10n.yaml / .arb dosyası kullanılmaz).
//
// Kapsam: altyapı + çekirdek anahtarlar (uygulama adı, ana gezinme
// sekmeleri, ortak düğmeler) + Dalga 10 göçü (home_shell, modes,
// game_selector, tasks, profile ekranları). Diğer ekranların metin
// göçü bu maddenin dışında; sıradaki dosyalar görev raporunda
// listelendi.
//
// Kullanım (göç eden ekranlarda):
//   final l10n = AppLocalizations.of(context);
//   Text(l10n.play)
// veya kısayol: `context.l10n.play` (aşağıdaki extension).
//
// Dil seçimi: cihaz dili EN ise İngilizce, TR ise Türkçe; desteklenmeyen
// bütün dillerde varsayılan Türkçe'dir
// (bkz. [AppLocalizations.localeResolutionCallback]).

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_en.dart';
import 'app_tr.dart';

/// Desteklenen diller için el yazımı yerelleştirme tablosu.
///
/// Her yeni anahtar buraya bir getter olarak eklenir ve EN + TR
/// uygulamalarında (app_en.dart / app_tr.dart) karşılığı yazılır.
/// Yeni anahtarın tek bir dilde kalması derleme hatası verir — bu,
/// eksik çevirinin gözden kaçmasını engellemek için bilinçli tercihtir.
///
/// Sayı / değişken içeren bileşik metinler (rekor satırı, ödül metni,
/// rozet sayacı, erişilebilirlik etiketleri) istisna olarak metotla
/// tanımlanır: kelime sırası dile göre değiştiği için parçaları
/// ekranda birleştirmek EN cümlesini bozar. Metot gövdeleri de EN + TR
/// dosyalarında birebir aynı sırayla yazılır.
abstract class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  /// Bu widget ağacı için geçerli yerelleştirme tablosu.
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// [MaterialApp.localizationsDelegates] listesine eklenecek delegate.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Desteklenen diller (bildirim sırası; varsayılan dil seçimi
  /// [localeResolutionCallback] ile yapılır, bu sıranın ilk
  /// elemanı varsayılan sayılmaz).
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Cihaz dili -> uygulama dili çözümü.
  ///
  /// Cihaz dili İngilizce ise EN, aksi hâlde TR (TR cihaz dili de
  /// dahil; desteklenmeyen dillerde varsayılan TR'dir).
  /// Bölge kodu dikkate alınmaz: `en-US`, `en-GB` vb. hepsi EN'dir.
  static Locale localeResolutionCallback(
    Locale? locale,
    Iterable<Locale> supportedLocales,
  ) {
    if (locale != null && locale.languageCode == 'en') {
      return const Locale('en');
    }
    return const Locale('tr');
  }

  /// Bir [Locale] için doğru tabloyu döndürür; bilinmeyen dilde TR.
  static AppLocalizations lookup(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return AppLocalizationsEn();
      case 'tr':
      default:
        return AppLocalizationsTr();
    }
  }

  // --- Uygulama adı ---

  String get appName;

  // --- Ana gezinme sekmeleri (HomeShell dock etiketleri) ---

  String get navHome;
  String get navModes;
  String get navFamily;
  String get navShop;
  String get navScores;

  // --- Ortak düğmeler / eylemler ---

  String get play;
  String get playNow;
  String get continueAction;
  String get back;
  String get close;
  String get settings;
  String get retry;
  String get cancel;
  String get confirm;
  String get save;
  String get loading;
  String get ok;
  String get yes;
  String get no;
  String get next;
  String get skip;
  String get start;
  String get pause;
  String get resume;
  String get restart;
  String get quit;
  String get profile;
  String get tasks;

  // --- Ortak durum / hata metinleri ---

  String get errorGeneric;
  String get offlineWarning;

  // --- Dalga 10 göçü: ortak ---

  /// Geri düğmesinin erişilebilirlik etiketi (cümle içi yazım;
  /// [back] düğme etiketi olan büyük harfli 'GERİ'den farklıdır).
  String get goBackLabel;
  String get comingSoon;
  String get claimedShort;
  String get claimedWithCheck;
  String get claimReward;

  // --- Dalga 10 göçü: Modlar ekranı ---

  String get modesTitle;

  /// Mod satırının erişilebilirlik etiketi: başlık (büyük harfli),
  /// alt başlık ve rekor. Başlık/alt başlık model verisidir
  /// (henüz çevrilmedi); yalnız şablon çevrilir.
  String modeOpenLabel(String title, String subtitle, String best);

  /// Mod satırı alt metni: alt başlık + rekor.
  String modeBestLine(String subtitle, String best);

  // --- Dalga 10 göçü: Görevler (tasks_screen + ana sayfa özeti) ---

  String get dailyTasksTitle;
  String get taskPlay3Games;
  String get taskMerge5;
  String get taskWatch1Video;
  String get taskCombo4;

  /// Görev ödül metni: 'Ödül: +150 COIN' biçimi korunur.
  String rewardCoins(int amount);
  String rewardEnergy(int amount);

  String get todaysTasks;
  String get tasksHeroSubtitle;
  String get tasksNotePrefix;
  String get tasksNoteSuffix;

  /// Tamamlanan görevin 'ÖDÜLÜ AL' düğmesi erişilebilirlik etiketi.
  String claimTaskLabel(String title, String reward);

  // --- Dalga 10 göçü: Ana sayfa (game_selector) ---

  String get dailyRewardClaimedSnack;
  String get rewardedAdsComingSoon;
  String get dailyEnergyClaimedSnack;
  String get onlineNotifySignupSnack;
  String get seeAllArrow;
  String get studioTitle;
  String get studioWatchTitle;
  String get studioWatchSubtitle;
  String get studioCreateTitle;
  String get studioCreateSubtitle;
  String get studioUploadTitle;
  String get studioUploadSubtitle;
  String get studioGifTitle;
  String get studioGifSubtitle;
  String get studioDownloadsTitle;
  String get studioDownloadsSubtitle;
  String get badgeHot;
  String get suikaArenaTitle;

  /// Hero kartı alt metninin iki satırı (yerleşim iki ayrı Text
  /// ister; satır bölünmesi korunur).
  String get heroSubtitleLine1;
  String get heroSubtitleLine2;
  String get dailyRewardTitle;
  String get dailyRewardSubtitle;
  String get claim500;
  String get claimEnergy5;
  String get onlineModeTitle;
  String get onlineModeSubtitle;
  String get notifyMe;
  String get chatTitle;
  String get onlineCount5;
  String get chatSubtitle;
  String get hubTasksSubtitle;
  String get seeAllButton;
  String get suikaArenaSubtitle;
  String get grid2048Title;
  String get grid2048Subtitle;
  String get balloonPopTitle;
  String get balloonPopSubtitle;
  String get badgeBonus;
  String get match3Title;
  String get match3Subtitle;
  String get badgeNeon;

  /// Mod kartı rekor satırı: 'Rekor: 4.820' biçimi korunur.
  String recordWithValue(String best);

  // --- Dalga 10 göçü: Profil ekranı ---

  String get signInOrUpLabel;
  String get signInOrUpButton;
  String get guestSignInExplanation;
  String get guestName;
  String get guestHandleNotSignedIn;
  String get appleHandle;
  String get guestSessionHandle;
  String get badgeComboKing;
  String get badgeComboKingReq;
  String get badgeMarathon;
  String get badgeMarathonReq;
  String get badgeVideoBuff;
  String get badgeVideoBuffReq;
  String get badgeGoldenFinger;
  String get badgeGoldenFingerReq;
  String get badgeTaskHunter;
  String get badgeTaskHunterReq;
  String get badgeEvolutionMaster;

  /// 'Pembe Bornozlu'ya ulaş' koşulu; satır sonu (\n) yerleşim
  /// hesabında kullanılır, EN karşılığında da korunur.
  String get badgeEvolutionMasterReq;
  String get badgeEarned;
  String get playerProfileTitle;
  String get levelLabel;
  String get nextLevel;
  String get totalScoreLabel;
  String get gamesPlayedLabel;
  String get bestComboLabel;
  String get myBadges;

  /// Rozet sayacı: '2/6 KAZANILDI' biçimi korunur.
  String badgesEarnedCount(int count);
  String get lockedLabel;

  // --- Dalga 15 göçü: Tanıtım ekranı (onboarding_screen) ---

  /// Başlık altı slogan; iki dilde de İngilizce yazılır (marka sloganı).
  String get onboardingTagline;

  /// Tanıtım noktalarının erişilebilirlik etiketi: sayfa numarası (1-3).
  String onboardingPageLabel(int page);
  String get onboardingNextLabel;
  String get onboardingNextStep;
  String get onboardingSkipLabel;
  String get onboardingSlide1Title;
  String get onboardingSlide1Body;

  /// Tier kutusu etiketi: 'Tier 1' biçimi korunur.
  String tierLabel(int tier);
  String get onboardingSlide2Title;
  String get onboardingSlide2Body;
  String get boosterF16Sub;
  String get boosterRaidSub;
  String get boosterSlipperTitle;
  String get boosterSlipperSub;
  String get onboardingSlide3Title;
  String get onboardingSlide3Body;
  String get onboardingStudioTitle;
  String get onboardingStudioSub;
  String get onboardingGifTitle;
  String get onboardingGifSub;
  String get onboardingLeaderboardTitle;
  String get onboardingLeaderboardSub;
  String get onboardingLoadingText;
  String get onboardingTapToStartLabel;
  String get onboardingTapToStart;
  String get onboardingVersionLine;

  // --- Dalga 15 göçü: Açılış ekranı (splash_screen) ---

  /// Yükleme döngü mesajı (0-4). Çağıran taraf sayaç uzunluğunu
  /// splash_screen.dart içindeki `_loadMessageCount` (5) ile tutar;
  /// bilinmeyen indekste son mesaj döner.
  String splashLoadMessage(int index);
  String get splashSkip;
  String get splashStartButton;
  String get splashContinueButton;
  String get splashVersionLabel;
  String get splashKicker1;

  /// Mod sayısı: 11 (GameModeKind 11 değer; README/store ile tutarlı).
  String get splashKicker2;
  String get splashKicker3;

  /// Sayfa 1 başlığının iki satırı; satır 1 sonundaki (\n) yerleşim
  /// içindir, EN karşılığında da korunur.
  String get splashTitle1Line1;
  String get splashTitle1Line2;

  /// Sayfa 1 alt başlığı; iki (\n) ile üç satıra bölünür, EN
  /// karşılığında da üç satır korunur.
  String get splashSubtitle1;
  String get splashBubbleText;
  String get linkPopTitle;
  String get stackDropTitle;
  String get slipperTapTitle;
  String get osmantusTitle;
  String get screamBugTitle;
  String get makarayizTitle;

  /// Sayfa 2 başlığının iki satırı; satır 1 sonundaki (\n) korunur.
  String get splashTitle2Line1;
  String get splashTitle2Line2;

  /// Sayfa 3 başlığının iki satırı; satır 1 sonundaki (\n) korunur.
  String get splashTitle3Line1;
  String get splashTitle3Line2;
  String get splashStarting;

  /// Yükleme düğmesi yüzde metni: 'YÜKLENİYOR… %42' biçimi korunur.
  String splashLoadingPercent(int percent);
  String get splashStartAdventure;
  String get splashPressToStart;

  // --- Dalga 15 göçü: Üst bar (top_bar) ---

  /// Seviye rozeti: dar ekranda boşluksuz ('LVL18'), geniş ekranda
  /// boşluklu ('LVL 18'). [compact] dar ekran kısaltmasını seçer.
  String levelBadge(int level, bool compact);
  String get energyFull;

  // --- Dalga 15 göçü: Hesap ekranı (auth_screen) ---

  String get authSessionOpen;
  String get accountTitle;
  String get authCardSubtitle;
  String get usernameHint;
  String get passwordHint;
  String get continueWithApple;
  String get continueWithGoogle;
  String get authHeaderRegister;
  String get authHeaderLogin;

  /// Kapat düğmesinin erişilebilirlik etiketi / ipucu (cümle içi
  /// yazım; [close] düğme etiketi olan büyük harfli 'KAPAT'tan
  /// farklıdır).
  String get closeLabel;
  String get signOutButton;
  String get loginTab;
  String get registerTab;
  String get createAccountButton;
  String get signInButton;
  String get orDivider;

  // --- Dalga 20 göçü: Oyun + sonuç ekranı (game_screen, result_screen) ---

  String get comboTimeoutReason;
  String get comboMissReason;
  String comboBreakToast(String reason);
  String milestoneToast(String title);
  String get speechAydinlat;
  String get speechSlipper;
  String get speechSpray;
  String get howToTitle;
  String get howToBody;
  String get understoodButton;
  String get gameScoreLabel;
  String get gameBestLabel;
  String get gameNextLabel;
  String get gamePausedTitle;
  String pausedScoreLine(int score);

  /// Büyük harfli 'DEVAM ET' düğme etiketi; cümle içi yazımlı
  /// [resume] ('Devam Et') düğmesinden farklıdır.
  String get resumeButtonCaps;

  /// Büyük harfli 'YENİDEN BAŞLA' düğme etiketi; [restart]
  /// ('Yeniden Başlat') düğmesinden farklıdır.
  String get restartLevelButton;
  String get finishGameButton;
  String get surviveLabel;
  String bossLabel(String name);
  String chapterLabel(int id);
  String overflowingCountdown(String seconds);
  String get nearLineWarning;
  String comboToast(int count);
  String get boosterRaidLabel;
  String get boosterShakeLabel;
  String get boosterLightLabel;
  String boosterCountLabel(String label, int count);
  String shareScoreSnack(int score);
  String get resultSubtitle;
  String get levelCompleteTitle;

  /// Sonuç ekranındaki 'EN İYİ KOMBO' etiketi; profil ekranındaki
  /// [bestComboLabel] ('EN YÜKSEK KOMBO') etiketinden farklıdır.
  String get bestComboResultLabel;
  String get mergesLabel;
  String get goldEarnedLabel;
  String get continueWithAdSoon;
  String get doubleGoldAdSoon;
  String get playAgainButton;
  String get sharedButton;
  String get shareButton;

  // --- Dalga 20 göçü: Ayarlar (settings_screen) ---

  String get resetProgressTitle;
  String get resetProgressBody;

  /// Büyük harfli 'İPTAL' düğme etiketi; cümle içi yazımlı
  /// [cancel] ('İptal') düğmesinden farklıdır.
  String get cancelCaps;
  String get resetButton;
  String accountDeleteFailed(String error);
  String get accountDeletedSnack;
  String signedInAs(String displayName);

  /// 'Giriş yap / kayıt ol'; [signInOrUpLabel] ('Giriş yap veya
  /// kayıt ol') metninden farklıdır.
  String get signInOrUpSlash;
  String get musicTitle;
  String get musicSubtitle;
  String get sfxTitle;
  String get sfxSubtitle;
  String get vibrationTitle;
  String get vibrationSubtitle;
  String get privacyTitle;
  String get privacySubtitle;
  String get deletingLabel;
  String get confirmDeleteAgain;
  String get deleteAccountButton;
  String get pleaseWait;
  String get deleteAccountArmedSub;
  String get deleteAccountSub;
  String get voiceTitle;
  String get voiceSubtitle;
  String get howToPlayRowTitle;
  String get howToPlayRowSub;
  String get resetProgressRowTitle;
  String get resetProgressRowSub;

  // --- Dalga 20 göçü: Gizlilik politikası (privacy_policy_screen) ---
  // (Silme düğmesi anahtarları ayarlar bölümüyle paylaşılır.)

  /// Büyük harfli 'HESABI SİL' düğme etiketi; ayarlar ekranındaki
  /// [deleteAccountButton] ('Hesabı Sil') etiketinden farklıdır.
  String get deleteAccountCaps;
  String get privacyIntro;
  String get privacySection1Title;
  String get privacySection1Body1;
  String get privacySection1Body2;
  String get privacySection1Body3;
  String get privacySection1Body4;
  String get privacySection2Title;
  String get privacySection2Body1;
  String get privacySection2Body2;
  String get privacySection2Body3;
  String get privacySection3Title;
  String get privacySection3Body1;
  String get privacySection3Body2;
  String get privacySection4Title;
  String get privacySection4Body1;
  String get privacySection5Title;
  String get privacySection5Body1;
  String get privacySection5Body2;
  String get privacySection5Body3;
  String get privacySection6Title;
  String get privacySection6Body1;

  // --- Dalga 20 göçü: Bölüm haritası (campaign_map_screen + campaign_map_sheet) ---
  // Bölüm/boss adları model verisidir (CampaignChapterMeta.titleFor /
  // bossNameFor); burada yalnız şablonlar çevrilir.

  String get campaignSuikaHeader;
  String get campaign2048Header;
  String get campaignMapTitle;

  /// Büyük harfli 'BÖLÜM $id' etiketi; oyun ekranındaki
  /// [chapterLabel] ('Bölüm $id') etiketinden farklıdır.
  String chapterLabelCaps(int id);
  String get levelGoalTitle;
  String secondsLabel(int seconds);
  String movesLabel(int moves);
  String pointsLabel(int points);
  String get bareTierLabel;
  String get upNextLabel;

  /// [boosterName] çağrı noktasında büyük harfe çevrilmiş güçlendirici
  /// anahtarıdır (örn. 'RAID').
  String chestUnlockedToast(
    int stars,
    int coins,
    int boosterCount,
    String boosterName,
  );
  String get campaignSheetTitle;
  String get campaignSheetSubtitle;
  String chapterBannerTitle(int index, String title);
  String bossBannerLine(int id, String bossName, int hp, String hazard);
  String levelRangeShort(int start, int end);
  String chestStarsLabel(int stars);

  /// Cümle içi yazımlı 'Alındı'; büyük harfli [claimedShort]
  /// ('ALINDI') etiketinden farklıdır.
  String get claimedPlain;
  String chestRewardLine(int coins, int count);
  String get bossShort;

  // --- Dalga 20 göçü: Sohbet (chat_lobby_screen, chat_screen) ---
  // Tohum (seed) mesajlar ve oyuncu adları kullanıcı içeriğidir;
  // anahtar yapılmadı.

  String onlinePlayersCount(int count);
  String levelShort(int level);
  String get messageHint;
  String get messageSendFailed;
  String get stickerSendFailed;
  String get quickStickerTitle;
  String get notSentLocalOnly;
  String get cloudSendFailedNote;

  /// Büyük harfli 'TEKRAR DENE' düğme etiketi; cümle içi yazımlı
  /// [retry] ('Tekrar Dene') düğmesinden farklıdır.
  String get retryCaps;
  String get guildMessageHint;

  // --- Dalga 20 göçü: Başarım toast'ı + pass (achievement_toast_overlay) ---

  String get achievementUnlockedTitle;
  String achievementRewardLine(int coins, int xp);
  String titleRewardLine(String title);
  String get masteryPassTitle;
  String masteryHeaderLine(String title, int unlocked, int total);

  /// 'Sezon Kademesi: $tier / 20  ($xp / $nextXp XP)' — '/ 20' ile
  /// parantez arasındaki çift boşluk kaynak metindeki gibidir.
  String seasonTierLine(int tier, int xp, int nextXp);
  String get goldPassActive;
  String get goldPassOpen;
  String achievementsCountLine(int unlocked);
  String passTierLabel(int tier);
  String get allAchievementsLabel;
  String achievementRewardCompact(int coins, int xp);
  String get unlockedShort;
  String get freeTrackTitle;
  String get goldPassTitle;
  String get collectButton;

  // --- Dalga 20 göçü: Skor tablosu (leaderboard_screen) ---
  // Tohum (seed) skor satırları const veridir; anahtar yapılmadı.

  String get leaderboardTitle;
  String get weeklyLabel;
  String get leaderboardLoadingLabel;
  String get noScoresYet;
  String get noScoresHint;

  // --- Dalga 20 göçü: Hesap (auth_screen, auth_panel) ---

  String get applePlayerFallback;
  String get guestContinueLabel;
  String get guestContinueButton;
  String get registerButtonShort;
  String get loginButtonShort;
  String get usernameHintDetailed;
  String get passwordHintDetailed;

  // --- Dalga 20 göçü: Stüdyo (studio_screens) ---
  // Tohum video başlıkları/meta satırları ve kare adları içerik
  // verisidir; anahtar yapılmadı.

  String get linkCopiedToast;
  String get videoAddedToDownloadsToast;
  String videoPlayPauseLabel(bool isPlaying, String title);
  String likeLabel(String count, bool liked);
  String get shareLabel;
  String get downloadLabel;
  String get upNextVideosTitle;
  String playVideoLabel(String title, String meta);
  String get draftSavedToast;
  String get studioToolTrim;
  String get studioToolText;
  String get studioToolSticker;
  String get trimClipTitle;
  String get trimEndLabel;

  /// 'Seçili bölüm: ' sonundaki boşluk yerleşim içindir (ardından
  /// süre aralığı gelir); EN karşılığında da korunur.
  String get selectedSectionPrefix;

  /// ' · Toplam 0:47' başındaki boşluk yerleşim içindir; EN
  /// karşılığında da korunur.
  String get totalDurationSuffix;
  String get addTextTitle;
  String get videoCaptionHint;
  String get captionPreviewNote;
  String get chooseStickerTitle;
  String stickerLabel(int index);
  String get saveAndPreviewLabel;
  String get saveAndPreviewButton;
  String get draftShareableNote;
  String get uploadDefaultTitle;
  String get videoUploadedSnack;
  String get chooseFileLabel;
  String get chooseFileButton;
  String get fileConstraintsNote;
  String get videoTitleLabel;
  String get videoTitleHint;
  String get startUploadLabel;
  String get startUploadButton;
  String get gifDefaultCaption;
  String get gifCreatedSnack;
  String get chooseFramesTitle;
  String get selectedFramesNote;
  String get textAndSpeedTitle;
  String get speedSlow;
  String get speedNormal;
  String get speedFast;
  String get createGifLabel;
  String deletedItemSnack(String title);
  String get storageTitle;

  /// Başındaki boşluk yerleşim içindir (önce GB değeri gelir);
  /// EN karşılığında da korunur.
  String storageUsedSuffix(int count);
  String playItemLabel(String title);
  String nowPlayingLabel(String title);
  String deleteItemLabel(String title);

  // --- Dalga 33 göçü (W33-1): erişilebilirlik etiketleri ---
  // Yalnız anahtar eklendi; UI göçü sonraki dalgada (kaynak metinler
  // lululu_dock_bar.dart, top_bar.dart, auth_panel.dart ve
  // shop_dialog.dart'ta gömülü duruyor).

  /// Dock sekmesinin okunmamış rozetli erişilebilirlik etiketi.
  /// [label] zaten çevrilmiş sekme etiketi, [badge] rozet metnidir
  /// ('5' veya sınırda '5+'); bu yüzden [badge] String'dir.
  String dockUnreadLabel(String label, String badge);

  /// Üst bar enerji hapının erişilebilirlik etiketi.
  String get energyLabel;

  /// Şifre alanındaki göster/gizle düğmesinin erişilebilirlik etiketi.
  String get showPasswordLabel;
  String get hidePasswordLabel;

  /// Mağaza üstündeki coin hapının erişilebilirlik etiketi.
  String get addCoinPackLabel;

  /// Mağaza ürün düğmesinin erişilebilirlik etiketi: ürün başlığı +
  /// görüntülenen fiyat metni.
  String shopBuyItemLabel(String title, String priceText);

  /// Güçlendirici düğmesinin erişilebilirlik etiketi: güçlendirici
  /// adı + coin bedeli. TR şablon kaynak metindeki gibi 'coin'
  /// (tekil) kullanır.
  String shopBuyPowerUpLabel(String name, int cost);

  // --- Dalga 55 göçü (W55-3): Mağaza (shop_dialog) — yalnız anahtar ---
  // Envanter: goals/lululu-game-ui-ux-design/hidden_files/
  // shop-dialog-tr-envanteri.md (124 benzersiz TR metin; 3'ü mevcut
  // anahtarla karşılanır: navShop, comingSoon, rewardedAdsComingSoon).
  // UI göçü bu dalgada YOK; metinler shop_dialog.dart'ta gömülü duruyor.

  String get shopModeSuikaArena;
  String get shopPowerRaidSprayName;
  String get shopPowerRaidSprayDesc;
  String get shopPowerSlipperShakeName;
  String get shopPowerSlipperShakeDesc;
  String get shopPowerLightItUpName;
  String get shopPowerLightItUpDesc;
  String get shopModeGrid2048;
  String get shopPowerUndoName;
  String get shopPowerUndoDesc;
  String get shopPowerShuffleName;
  String get shopPowerShuffleDesc;
  String get shopPowerMergePairName;
  String get shopPowerMergePairDesc;
  String get shopModeBalloonPop;
  String get shopPowerTripleArrowName;
  String get shopPowerTripleArrowDesc;
  String get shopPowerBombBalloonName;
  String get shopPowerBombBalloonDesc;
  String get shopPowerSlowName;
  String get shopPowerSlowBalloonDesc;
  String get shopModeMatch3;
  String get shopPowerHammerName;
  String get shopPowerHammerDesc;
  String get shopPowerBombName;
  String get shopPowerBombDesc;
  String get shopPowerColorHunterName;
  String get shopPowerColorHunterDesc;
  String get shopModeLinkPop;
  String get shopPowerChainExtenderName;
  String get shopPowerChainExtenderDesc;
  String get shopPowerLightningName;
  String get shopPowerLightningDesc;
  String get shopPowerMagnetName;
  String get shopPowerMagnetDesc;
  String get shopModeStackDrop;
  String get shopPowerFreezeName;
  String get shopPowerFreezeDesc;
  String get shopPowerWidenName;
  String get shopPowerWidenDesc;
  String get shopPowerSlowStackDesc;
  String get shopModeSlipperTap;
  String get shopPowerDoubleSlipperName;
  String get shopPowerDoubleSlipperDesc;
  String get shopPowerGoldenSlipperName;
  String get shopPowerGoldenSlipperDesc;
  String get shopPowerBugSprayName;
  String get shopPowerBugSprayDesc;
  String get shopModeNestDefense;
  String get shopPowerNestShieldName;
  String get shopPowerNestShieldDesc;
  String get shopModeOsmantus;
  String get shopPowerDikkisBoostName;
  String get shopPowerDikkisBoostDesc;
  String get shopPowerWideRingName;
  String get shopPowerWideRingDesc;
  String get shopPowerMicrophoneName;
  String get shopPowerMicrophoneDesc;
  String get shopModeScreamBug;
  String get shopPowerJumpBootsName;
  String get shopPowerJumpBootsDesc;
  String get shopPowerShieldName;
  String get shopPowerShieldDesc;
  String get shopPowerNitroName;
  String get shopPowerNitroDesc;
  String get shopModeMakarayiz;
  String get shopPowerBeatFreezeName;
  String get shopPowerBeatFreezeDesc;
  String get shopPowerAutoReelName;
  String get shopPowerAutoReelDesc;
  String get shopPowerScoreMultiplierName;
  String get shopPowerScoreMultiplierDesc;
  String get shopGoldenWeekendTitle;
  String get shopGoldenWeekendSubtitle;
  String get shopFreeChestTitle;
  String get shopFreeChestDesc;
  String get shopEnergyTitle;
  String get shopEnergyRefillNote;
  String get shopPowerUpsTitle;
  String get shopPowerUpsNote;
  String get shopCoinPacksTitle;
  String get shopChestsAndPotionsTitle;
  String get shopBadgeBest;
  String get shopBadgeDeal;
  String get shopBadgeLucky;
  String get shopItemEnergyPackTitle;
  String get shopItemEnergyPackDesc;
  String get shopItemEnergyDepotTitle;
  String get shopItemEnergyDepotDesc;
  String get shopItemStarPackTitle;
  String get shopItemStarPackDesc;
  String get shopItemSurpriseBoxTitle;
  String get shopItemSurpriseBoxDesc;
  String get shopItemHandfulTitle;
  String get shopItemHandfulDesc;
  String get shopItemCrateTitle;
  String get shopItemCrateDesc;
  String get shopItemWoodenChestTitle;
  String get shopItemWoodenChestDesc;
  String get shopItemGoldenChestTitle;
  String get shopItemGoldenChestDesc;
  String get shopItemDoubleCoinTitle;
  String get shopItemDoubleCoinDesc;
  String get shopItemLuckPotionTitle;
  String get shopItemLuckPotionDesc;
  String get shopNotEnoughGoldToast;
  String get shopAddedCoinPackToast;
  String get shopEnergyRegenToast;
  String get shopEnergyAddedToast;
  String get shopStoreUnavailableToast;
  String get shopEnergyFullToast;
  String get shopPowerUpModeOnlyToast;
  String get shopAddedStarPackToast;
  String get shopAddedSurpriseBoxToast;
  String get shopAddedWoodenChestToast;
  String get shopAddedGoldenChestToast;
  String get shopAddedDoubleCoinToast;
  String get shopAddedLuckPotionToast;

  /// Güç satırı açıklama satırı: çevrilmiş açıklama + çevrilmiş mod adı.
  /// [desc] ve [modeName] zaten çevrilmiş değerlerdir.
  String shopPowerUpDescModeSuffix(String desc, String modeName);

  /// Güç satın alma toast'ı: çevrilmiş güç adı + çevrilmiş mod adı.
  String shopPowerUpAddedToCartToast(String name, String modeName);

  /// Güç grubu rozeti: gruptaki güç sayısı (hâlen hep 3).
  String shopPowerGroupBonusCount(int count);

  // --- Dalga 59 göçü (W59-2): erişilebilirlik etiketleri, 2. tur ---
  // W46-2 semantics denetiminin P1 listesinden kalan noktalar
  // (W55-5 kotası dolduğu için bırakılanlar) + P0 üst-bar hapları
  // için şablonlar. [finishRoundLabel], [profilePillLabel] ve
  // [coinPillLabel] bu dalgada yalnız anahtar olarak eklenir;
  // UI kullanımı sonraki dalgada (BİTİR düğmeleri, vault_top_hud
  // satır-içi etiketlerinin göçü).

  /// '?' yardım düğmesinin erişilebilirlik etiketi.
  String get helpButtonLabel;

  /// Sohbet gönder düğmesinin erişilebilirlik etiketi.
  String get sendMessageLabel;

  /// Gönder düğmesinin uzun basma ipucu (sticker sayfasını açar);
  /// [Semantics.onLongPressHint] içinde kullanılır.
  String get sendStickerHint;

  /// Tur sonu 'BİTİR' düğmesinin erişilebilirlik etiketi.
  String get finishRoundLabel;

  /// Üst bar profil hapının erişilebilirlik etiketi: oyuncu adı +
  /// seviye. [name] görüntülenen ad, [level] seviye numarasıdır.
  String profilePillLabel(String name, int level);

  /// Üst bar coin hapının erişilebilirlik etiketi: biçimlendirilmiş
  /// bakiye ([value], örn. '12.450') + coin paketi ekleme eylemi.
  String coinPillLabel(String value);
}

/// [AppLocalizations.of] kısayolu: `context.l10n.play`.
extension AppLocalizationsExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'en' || locale.languageCode == 'tr';
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations.lookup(locale),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
