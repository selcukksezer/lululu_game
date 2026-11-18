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
  String get dailyEnergyAlreadyClaimedSnack;
  String get hbEnergyTag;
  String get chestClaimFailed;
  String boosterOutOfStockToast(String label);
  String levelLockedMessage(int previousLevel);
  String taskRewardClaimedSnack(String rewardText);
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
  String get authUsernameRequired;
  String get authUsernameInvalid;
  String get authPasswordRequired;
  String get authPasswordTooShort;
  String get authPasswordTooLong;
  String get authPasswordInvalid;
  String get authGenericFailed;
  String get authWrongPassword;
  String get authUserNotFound;
  String get authUsernameTaken;
  String get authTooManyAttempts;
  String get authSignOutFailed;
  String get settingsResetFailed;
  String get onboardingSaveFailed;
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
  String get resultGameOverTitle;
  String get resultGameOverSubtitle;

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
  String get shareScoreFailed;

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
  String get sfxTitle;
  String get sfxSubtitle;
  String get vibrationTitle;
  String get vibrationSubtitle;
  String get languageTitle;
  String get languageSubtitle;
  String get dangerLineLabel;
  String get dangerAlertLabel;
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
  String get shopPowerUndoNameCaps;
  String get shopPowerUndoDesc;
  String get shopPowerShuffleName;
  String get shopPowerShuffleNameCaps;
  String get shopPowerShuffleDesc;
  String get shopPowerMergePairName;
  String get shopPowerMergePairNameCaps;
  String get shopPowerMergePairDesc;
  String get shopModeBalloonPop;
  String get shopPowerTripleArrowName;
  String get shopPowerTripleArrowDesc;
  String get shopPowerBombBalloonName;
  String get shopPowerBombBalloonDesc;
  String get shopPowerSlowName;
  String get shopPowerSlowNameCaps;
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
  String get shopPowerFreezeNameCaps;
  String get shopPowerFreezeDesc;
  String get shopPowerWidenName;
  String get shopPowerWidenNameCaps;
  String get shopPowerWidenDesc;
  String get shopPowerSlowStackDesc;
  String get shopModeSlipperTap;
  String get shopPowerDoubleSlipperName;
  String get shopPowerDoubleSlipperNameCaps;
  String get shopPowerDoubleSlipperDesc;
  String get shopPowerGoldenSlipperName;
  String get shopPowerGoldenSlipperNameCaps;
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
  String get shopPowerNitroNameCaps;
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
  String get energyPackBoughtToast;
  String get shopPurchaseFailedRefundToast;

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

  // --- W60-2: §3 paylaşılan anahtarlar (i18n göç planı) ---
  String get pausedStatusCaps;
  String get finishCaps;
  String get finishLabel;
  String get tryAgainCaps;
  String get retryShort;
  String get viralBadge;
  String get moveLabel;
  String get timeLabel;
  String get livesLabel;
  String get newBadge;
  String get missedCaps;
  String get perfectCaps;
  String get comboBrokenShort;
  String get understoodLabel;
  String get connectTargetHit;
  String get powerShieldCaps;
  String get statusLabel;
  String get resultComplete;
  String get resultOver;
  String get modeBadgeTitle;
  String get doubleGoldEarnedCaps;
  String perfectCombo(int combo);
  String comboBrokenReason(String reason);
  String pauseScoreComboLine(int score, int combo);
  String arcadeMilestoneScore(int m);
  String featuredBannerLabel(String badge);
  String featuredEndsToday(String clock);
  // --- W60-2: G2 connect_pop (i18n göç planı) ---
  String get connectHintIdle;
  String get connectChainPrototype;
  String get connectBoardRefreshed;
  String get connectLoopHint;
  String get connectGroupHint;
  String get connectLoopReady;
  String get connectSquareClear;
  String get connectLinesOut;
  String get connectChainExtenderHint;
  String get connectChainExtenderMilestone;
  String get connectMagnetHint;
  String get connectMagnetMilestone;
  String get connectChainTag;
  String get connectLineStat;
  String get connectWonTitle;
  String get connectLostTitle;
  String get powerChainPlus;
  String connectSelectedOne(int minLen);
  String connectSelectedCount(int count);
  String connectLongChain(int len);
  String connectMinLength(int minLen);
  String connectSquareHint(int streak, int gained);
  String connectBonusDrop(int points);
  String connectSquareChain(int gained);
  String connectChainText(int streak, int gained);
  String connectLoseHint(int target, int lines, int streak);
  String connectStatsLine(int cleared, int loops, int streak, int longest);
  String connectBoltHint(int count);
  String connectBoltMilestone(int gained);
  String connectTargetLine(int longest);
  // --- W60-2: G3 makarayiz (i18n göç planı) ---
  String get makaraHintIdle;
  String get makaraBeatLine;
  String get makaraReelOut;
  String get makaraWrongLane;
  String get makaraEarlyTap;
  String get makaraFreezeHint;
  String get makaraFreezeCallout;
  String get makaraAutoHint;
  String get makaraAutoCallout;
  String get makaraX2Hint;
  String get makaraX2Active;
  String get makaraEndedTitle;
  String get makaraShareLine;
  String get makaraTaglineCaps;
  String get powerScoreX2;
  String makaraMissWindow(String reason, int windowMs);
  String makaraResultMessage(int bestCombo, int hits, int misses);
  String makaraFillPercent(int pct);
  // --- W60-2: G5 osmantus (i18n göç planı) ---
  String get osmantusHintIdle;
  String get osmantusDikkisChant;
  String get osmantusHowToBody1;
  String get osmantusHintResume;
  String get osmantusPressGreen;
  String get osmantusMicSaved;
  String get osmantusDefeatHint;
  String get osmantusJustInTime;
  String get osmantusEarlyPress;
  String get osmantusWaitGreen;
  String get osmantusDikkisBoost;
  String get osmantusDikkisHint;
  String get osmantusRingActive;
  String get osmantusRingHint;
  String get osmantusMicShieldCallout;
  String get osmantusMicShieldHint;
  String get osmantusDuoWonTitle;
  String get osmantusHowToBody2;
  String get powerDikkis;
  String get powerRingPlus;
  String get osmantusCardSub1;
  String get osmantusCardSub2;
  String get osmantusPressGreenButton;
  String get osmantusDuoButton;
  String osmantusComboBroken(String reason);
  String osmantusLateBy(int delta);
  String osmantusWarmupMiss(String reason);
  String goodCombo(int combo);
  String osmantusEarlyBy(int delta);
  String osmantusStatsLine(int maxCombo, int streak);
  // --- W60-2: G6 terlik_tap (i18n göç planı) ---
  String get terlikHintIdle;
  String get terlikBonusComboSlipper;
  String get terlikTrapPassed;
  String get terlikEscaped;
  String get terlikTrapReplik;
  String get terlikLuckBurst;
  String get terlikBonusSlipper;
  // --- W103-2: bonus efekt yazıları (bonus_fx.dart) ---
  String get effectSlap;
  String get effectCombo;
  String get terlikMissedHit;
  String get terlikSteppedTrap;
  String get terlikDoubleReadyHint;
  String get terlikDoubleCallout;
  String get terlikGoldHint;
  String get terlikGoldCallout;
  String get terlikSprayCallout;
  String get powerSprayCaps;
  String get terlikHoleInstruction;
  String get terlikOutTitle;
  String get terlikEmptyHole;
  String get terlikTrapTag;
  String terlikBonusComboSpray(int combo);
  String terlikOutOfSlippers(int smashed, int combo, int coins);
  String terlikHitHint(int combo, int gain);
  String terlikComboBreakLives(String reason, int remaining);
  String terlikComboBreakLifeLost(String reason, int lives);
  String terlikStatsLine1(int smashed, int missed, int combo);
  String terlikStatsLine2(int coins, int slippers, int sprays);
  String terlikSprayHint(int cleared);
  String terlikPauseScore(int score, int smashed);
  String terlikSpeedMultiplier(String rate);
  String terlikHitsChip(int smashed);
  String terlikMissedChip(int missed);
  String terlikHoleSemantics(int hole);
  // --- W60-2: ek anahtarlar (günlük ödül serisi + chat rozeti) ---
  String dailyRewardSubtitleStreak(int streak);
  String chatBadgeUnreadLabel(String badge);
  // --- W65-1: G7 scream_roach (i18n göç planı) ---
  String get screamHintIdle;
  String get screamGatePrototype;
  String get screamIdleGround;
  String get screamShieldSaved;
  String get screamMicPermissionSettings;
  String get screamMicDeniedHint;
  String get screamMegaJumpCallout;
  String get screamMegaJumpHint;
  String get screamShieldBalloonCallout;
  String get screamShieldBalloonHint;
  String get screamNitroCallout;
  String get screamNitroHint;
  String get powerJumpCaps;
  String get screamMicOffLabel;
  String get screamMicOnLabel;
  String get screamVoicePower;
  String get screamGateStat;
  String get screamCrushedTitle;
  String get gateTerlikDeath;
  String get gateTerlikPass;
  String get gateRaidDeath;
  String get gateRaidPass;
  String get gateTavaDeath;
  String get gateTavaPass;
  String get gateTuzakDeath;
  String get gateTuzakPass;
  String get gateHamamDeath;
  String get gateHamamPass;
  String get gateVuvuzelaDeath;
  String get gateVuvuzelaPass;
  String screamDeathLine(String deathLine, int gates);
  String screamGateStreak(int streak);
  String screamCrushedHint(int gates, int streak);
  String screamStatsLine(int gates, int streak, int dayStreak);
  String screamNextGate(int gate);
  String screamShoutingPercent(int percent);
  String screamArcadeHint(String hint);
  String screamPauseScore(int score, int gates);
  // --- W65-1: G8 stack_drop (i18n göç planı) ---
  String get stackHintIdle;
  String get stackPerfectPrototype;
  String get stackMissedFall;
  String get stackSliceThin;
  String get stackMagnetHint;
  String get stackMagnetMilestone;
  String get stackWidenHint;
  String get stackWidenMilestone;
  String get stackSlowHint;
  String get stackSlowMilestone;
  String get stackTowerTag;
  String get stackFloorStat;
  String get stackTowerFellTitle;
  String stackDirectHit(int combo, int gain);
  String stackPerfectHit(int combo);
  String stackNearHint(int gain, int floors);
  String stackNearCallout(int gain);
  String stackEdgeCutHint(int gain, int floors);
  String stackEdgeCutCallout(int gain);
  String stackMilestoneFloors(int m);
  String stackStatsLine(int floors, int perfects, int nears, int combo);
  String stackTutorialHint(String hint);
  String stackFloorLabel(int floor);
  // --- W65-1: G9 yuva_defense (i18n göç planı) ---
  String get yuvaHintIdle;
  String get yuvaShieldSaved;
  String get yuvaFellHint;
  String get yuvaDoubleHint;
  String get yuvaGoldHint;
  String get yuvaShieldIceHint;
  String get yuvaMissHint;
  String get yuvaTitleNewSemantic;
  String get yuvaHowToBody1;
  String get yuvaHowToBody2;
  String get yuvaFellTitle;
  String yuvaBugEntered(int lives);
  String yuvaWaveHit(int wave, int points, int combo);
  String yuvaHitHint(int points, int combo);
  String yuvaPauseScore(int score, int hits);
  String yuvaResultScore(int score, int combo);
  String yuvaHitsPainter(int hits);
  String yuvaMissedPainter(int misses);
  // --- W65-1: G10 grid_2048 (i18n göç planı) ---
  String get gridSuperCombo;
  String get gridTarget2048;
  String get gridHowToTitle;
  String get gridHowToBody1;
  String get gridHowToBody2;
  String get gridHowToBody3;
  String get gridHowToBody4;
  String gridSuperMergeSpeech(String title);
  String gridHighestTile(int value);
  String gridMovesCount(int count);
  String gridPauseStats(int moves, int merges, int streak);

  // --- W69-1: L10N anahtar dalgası 3 (G13 + G15 + G12 + G17 + splash
  // ›-suz + semantics eksik 10 + arcade görünür) ---
  // Yalnız anahtar; UI göçü sonraki dalgada. W89-2: G17 gövde
  // `energyEmptyBody` 3 parçaya açıldı — "dolar" 'dolmak' fiilinin
  // çekimidir (koordinatör kararı: metin aynen korunur, para birimi
  // anlamı yok); G10 gizli '2048 Grid' (Opacity(0) test-finder) göç dışı.

  // G13: bölüm adları (campaign_map_screen.dart:31-34 yerel liste).
  String get campaignChapter1;
  String get campaignChapter2;
  String get campaignChapter3;
  String get campaignChapter4;

  // G15: main.dart karşılama hata ekranı (375/385/402).
  String get welcomeStatusReadFail;
  String get welcomeSkipFail;
  String get continueToHomeAnyway;

  // Ş14: main.dart boot enerji zaman aşımı uyarı bandı detayı.
  String get energyLoadTimeout;

  // G12: tiers_screen.dart başlık + alt başlık (258/279).
  String get bugFamilyTitle;
  String get bugFamilySubtitle;

  // W85-2: tiers_screen.dart satır name + quote (T1–T13).
  String get tierRowName1;
  String get tierRowName2;
  String get tierRowName3;
  String get tierRowName4;
  String get tierRowName5;
  String get tierRowName6;
  String get tierRowName7;
  String get tierRowName8;
  String get tierRowName9;
  String get tierRowName10;
  String get tierRowName11;
  String get tierRowName12;
  String get tierRowName13;
  String get tierRowQuote1;
  String get tierRowQuote2;
  String get tierRowQuote3;
  String get tierRowQuote4;
  String get tierRowQuote5;
  String get tierRowQuote6;
  String get tierRowQuote7;
  String get tierRowQuote8;
  String get tierRowQuote9;
  String get tierRowQuote10;
  String get tierRowQuote11;
  String get tierRowQuote12;
  String get tierRowQuote13;

  // G17: energy_empty_popup.dart (178/229/249/269).
  String get energyEmptyTitle;
  String get energyEmptyBodyStart;
  String get energyEmptyBodyMiddle;
  String get energyEmptyBodyEnd;
  String get rewardedAdsSoonCaps;
  String get shopEnergyPackButton;
  String get waitForTimerCaps;

  /// Splash ›-suz temiz değerler: [splashSkip], [splashStartButton]
  /// ve [splashContinueButton] '›' içerir; Semantics etiketleri
  /// temiz değeri kullanır (mevcut anahtarlara dokunulmadı).
  String get splashSkipPlain;
  String get splashStartButtonPlain;
  String get splashContinueButtonPlain;

  // Semantics eksik 10 (W65-3 raporu D-4/D-38/D-40/D-41/D-42/D-44/
  // D-45/D-49/D-52/D-54).
  String get play2048Label;
  String get doubleRewardLabel;
  String get watchAdChestLabel;
  String get notifyOnLabel;

  /// Seviye karosu erişilebilirlik etiketi: seviye no + yıldız;
  /// kilitliyse ' · Kilitli' eklenir.
  String levelTileLabel(int id, int stars, bool locked);
  String chapterTabLabel(int index, int stars);

  /// Sandık erişilebilirlik etiketi. [state]: 'claimable' (alınabilir),
  /// 'claimed' (alındı) veya 'locked' (kilitli); bilinmeyen değerde
  /// alınabilir dalı döner.
  String chestClaimLabel(int stars, String state);
  String channelSelectLabel(String name);
  String sendStickerLabel(String name);
  String featuredModeLabel(String title, String subtitle);

  // --- W75-3: L10N anahtar dalgası 4 (yalnız anahtar; bağlama yok) ---
  // howToPlaySuffix: arcade_chrome.dart:111 başlık soneki
  // ('${title.toUpperCase()} — NASIL OYNANIR?'). Rozet anahtarları
  // _resolvedBadge dönüşleri için tag anahtarlarından ayrıldı;
  // değerleri connectChainTag/stackTowerTag ile aynı.
  String get howToPlaySuffix;
  String get connectChainBadge;
  String get stackTowerBadge;

  // --- W79-3: L10N anahtar dalgası 5 (online_screen + leaderboard;
  // yalnız anahtar; bağlama yok) ---
  // Online adları i18n-goc-plani.md G11'deki önerilen adlar; EN
  // karşılıkları plan tablosundan (lonca/turnuva EN'i planda yoktu,
  // doğru çeviri yazıldı). 'Seviye N' için planda ad önerisi yoktu
  // (tohum içerik, plan Ek B); plan örneğindeki `levelLabel(int)`
  // mevcut `levelLabel` getter'ı ('SEVİYE') ile çakışır, o yüzden
  // recordWithValue kalıbıyla `levelWithValue` açıldı.
  String get onlineNotifyRemovedSnack;
  String get comingVerySoonCaps;
  String get onlineComingSoonBody;
  String get notifyOnCaps;
  String get onlineDuelTitle;
  String get onlineDuelSubtitle;
  String get onlineGuildWarsTitle;
  String get onlineGuildWarsSubtitle;
  String get onlineTournamentsTitle;
  String get onlineTournamentsSubtitle;

  /// Skor tablosu satırındaki 'Seviye 24' etiketi; kısaltmalı
  /// [levelShort] ('Sv. 24') ve rozetli [levelBadge] ('LVL 24')
  /// biçimlerinden farklıdır. Tek şablon, koşulsuz metot.
  String levelWithValue(int level);

  /// Skor tablosu SEN satırındaki ad: 'SEN · LülüSever' biçimi.
  /// [name] görünen addır ([AuthService.displayName]); giriş
  /// yoksa 'LülüSever' yedeği verilir (leaderboard_service.dart
  /// :577-578'deki yedekle aynı). Tek şablon, koşulsuz metot.
  String youAsName(String name);

  /// Sonuç ekranı reklam düğmeleri (COMING SOON rozeti ayrı gösterilir).
  String get continueWithAd;
  String get doubleGoldWithAd;

  /// Balon modu: tavan etiketi, ipucu satırları, nişan etiketi.
  String get ceilingLabel;
  String get balloonHintDrift;
  String get balloonHelpBody;
  String get balloonHintRowDropped;
  String balloonRowsInShots(int shots);
  String get holdAimRelease;
  String get laserAimActive;
  String get slowColorBombActive;

  /// Güçlendirme etiketleri (büyük harf biçimi, oyun içi çubuk).
  String get powerTripleArrowCaps;
  String get powerBombCaps;
  String get powerHammerCaps;
  String get powerHunterCaps;
  String get powerLightningCaps;
  String get powerMagnetCaps;
  String get powerMedicineCaps;
  String get powerMicrophoneCaps;
  String get powerBeatFreezeCaps;
  String get powerAutoReelCaps;

  /// Match-3: hamle/hedef etiketleri ve diyalog başlıkları.
  String get movesLabelCaps;
  String get targetTitle;
  String get movesOutTitle;
  String targetWithValue(String value);

  /// Bağlantı modu: çizgi etiketi, zincir/kare geri bildirimleri.
  String get linesLabel;

  /// Terlik modu: yönerge + can kaybı bildirimi (hız/vuruş/kaçan/
  /// istatistik/kaçma şablonları mevcut terlik* anahtarlarındadır).
  String get terlikInstruction;
  String missLifeLost(String reason);

  /// Yuva savunması: arena başlık bandı.
  String get yuvaBanner;

  /// Osmantuş: ikili tuş, rol alt yazıları, ritim ipucu.
  String get osmantusDoubleButton;
  String get osmanRoleSub;
  String get tusRoleSub;
  String get osmantusRhythmHint;

  /// Çığlık modu: ses gücü ipucu (yüzde + dokun + eğitim yavaşlığı).
  String screamTapPercent(int percent);
  String get screamSlowStart;

  /// Balon modu: oyun içi ipucu varyantları (ıskalama/yapışma/patlama).
  String get balloonMissedAim;
  String get balloonNoStickAim;
  String balloonPoppedStreak(int streak, int gained);
  String balloonPiercingShot(int pierced, int streak);
  String get balloonStuckNeed3;

  /// Terlik modu: düşen güçlendirici sonekleri (ipucu satırı sonu).
  String terlikDropSlipper(int count);
  String terlikDropSpray(int count);

  String get balloonCeilingDropped;
  String get balloonLoseReached;
  String get balloonLoseCeiling;
  String get balloonTripleActive;
  String get balloonWaveActive;
  String balloonFireballShot(int take);

  String get balloonOverflowTitle;
  String get balloonComboBrokenMiss;
  String get balloonFireballMilestone;
  String balloonSuperPop(int popped);
  String balloonStatsLine(int pop, int fall, int maxStreak, int biggest);

  /// Stüdyo: video meta satırı (görüntülenme + zaman).
  String videoViewsShort(int thousands);
  String daysAgo(int days);
  String weeksAgo(int weeks);

  /// Stüdyo indirmeler: tarih etiketleri + kısa ay adı.
  String downloadedTodayAt(String time);
  String downloadedYesterdayAt(String time);
  String downloadedDayMonth(int day, String month);
  String monthShortName(int month);
  String monthFullName(int month);
  String get match3HintIdle;
  String get match3NoMovesShuffle;
  String get match3NoMatchCancel;
  String get match3BombFormed;
  String get match3HammerGain;
  String get match3HammerBroke;
  String get match3HammerStrike;
  String get match3RocketFx;
  String get match3SphereCallout;
  String get osmantusDuoWonHint;
  String get osmantusMicReady;
  String get makaraOverTitle;
  String get bonusLifePlus;
  String get gotItPlay;

  /// Sohbet moderasyonu: raporla/engelle + misafir kimliği + şart onayı.
  String get chatReportAction;
  String get chatBlockAction;
  String get chatUnblockAction;
  String get chatReportTitle;
  String get chatReportReasonSpam;
  String get chatReportReasonInappropriate;
  String get chatReportReasonHarassment;
  String get chatReportReasonOther;
  String get chatReportSent;
  String get chatReportQueued;
  String get chatReportAlreadySent;
  String get chatUserBlocked;
  String get chatUserUnblocked;
  String get chatBlockedTitle;
  String get chatBlockedEmpty;
  String get chatTermsTitle;
  String get chatTermsBody;
  String get chatTermsAccept;
  String get chatTermsDecline;
  String get chatTermsRequired;
  String get chatGuestBadge;
  String get chatGuestNameTitle;
  String get chatGuestNameHint;
  String get chatGuestNameEmpty;
  String get chatGuestNameSaved;
  String get chatActionFailed;
  String get chatEmptyChannel;
  String get chatOptionsLabel;
  String get chatChangeNameAction;
  String get chatBlockedListAction;
  String match3StatsLine(int merge, int chain, int made, int fired);
  String match3RocketBombGain(int gained);
  String match3RocketHint(int n);
  String match3HunterGain(int gained);
  String match3SphereHint(int n);
  String match3SphereFx(int n);
  String osmantusLifeStatus(String reason, int lives);
  String terlikSprayedTargets(int cleared);
  String scoreMilestone(int m);
  String balloonBombGain(int gained);
  String makaraComboBroken(String reason);
  String osmantusLastError(String reason);
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
