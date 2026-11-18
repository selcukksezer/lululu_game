// Madde 95 [P1]: İngilizce yerelleştirme tablosu (el yazımı, codegen yok).
// Anahtar listesi için bkz. app_localizations.dart.

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn() : super(const Locale('en'));

  @override
  String get appName => 'LÜLÜLÜ';

  @override
  String get navHome => 'HOME';

  @override
  String get navModes => 'MODES';

  @override
  String get navFamily => 'FAMILY';

  @override
  String get navShop => 'SHOP';

  @override
  String get navScores => 'SCORES';

  @override
  String get play => 'PLAY';

  @override
  String get playNow => 'PLAY NOW';

  @override
  String get continueAction => 'CONTINUE';

  @override
  String get back => 'BACK';

  @override
  String get close => 'CLOSE';

  @override
  String get settings => 'SETTINGS';

  @override
  String get retry => 'Try Again';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get save => 'Save';

  @override
  String get loading => 'Loading…';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get start => 'Start';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get restart => 'Restart';

  @override
  String get quit => 'Exit';

  @override
  String get profile => 'Profile';

  @override
  String get tasks => 'Tasks';

  @override
  String get errorGeneric => 'Something went wrong.';

  @override
  String get offlineWarning =>
      'Some data could not be loaded. Continuing offline.';

  // --- Dalga 10 göçü: ortak ---

  @override
  String get goBackLabel => 'Back';

  @override
  String get comingSoon => 'COMING SOON';

  @override
  String get claimedShort => 'CLAIMED';

  @override
  String get claimedWithCheck => '✓ CLAIMED';

  @override
  String get claimReward => 'CLAIM REWARD';

  // --- Dalga 10 göçü: Modlar ekranı ---

  @override
  String get modesTitle => 'GAME MODES';

  @override
  String modeOpenLabel(String title, String subtitle, String best) =>
      'Open $title game: $subtitle, best $best';

  @override
  String modeBestLine(String subtitle, String best) =>
      '$subtitle · Best $best';

  // --- Dalga 10 göçü: Görevler ---

  @override
  String get dailyTasksTitle => 'DAILY TASKS';

  @override
  String get taskPlay3Games => 'PLAY 3 GAMES';

  @override
  String get taskMerge5 => 'MAKE 5 MERGES';

  @override
  String get taskWatch1Video => 'WATCH 1 VIDEO';

  @override
  String get taskCombo4 => 'GET AN X4 COMBO';

  @override
  String rewardCoins(int amount) => 'Reward: +$amount COIN';

  @override
  String rewardEnergy(int amount) => 'Reward: +$amount ENERGY';

  @override
  String get todaysTasks => "TODAY'S TASKS";

  @override
  String get tasksHeroSubtitle =>
      'Finish tasks, grab the reward — new ones arrive tomorrow!';

  @override
  String get tasksNotePrefix =>
      'Progress fills as you play this session. On a completed task, ';

  @override
  String get tasksNoteSuffix =>
      ' appears; coins go to your wallet and energy to your heart instantly.';

  @override
  String claimTaskLabel(String title, String reward) =>
      'Claim reward: $title, $reward';

  // --- Dalga 10 göçü: Ana sayfa (game_selector) ---

  @override
  String get dailyRewardClaimedSnack =>
      'Daily reward claimed: +500 coins';

  @override
  String get rewardedAdsComingSoon =>
      'Rewarded ads are coming soon — unavailable for now.';

  @override
  String get dailyEnergyClaimedSnack =>
      'Daily energy claimed: +5 energy added!';

  @override
  String get onlineNotifySignupSnack =>
      "You're signed up! We'll let you know as soon as Online mode opens.";

  @override
  String get seeAllArrow => 'See all →';

  @override
  String get studioTitle => 'STUDIO';

  @override
  String get studioWatchTitle => 'WATCH VIDEOS';

  @override
  String get studioWatchSubtitle => 'Bug clips and records';

  @override
  String get studioCreateTitle => 'MAKE A VIDEO';

  @override
  String get studioCreateSubtitle => 'Trim, add text and stickers';

  @override
  String get studioUploadTitle => 'UPLOAD';

  @override
  String get studioUploadSubtitle => 'Share your clip with everyone';

  @override
  String get studioGifTitle => 'MAKE A GIF';

  @override
  String get studioGifSubtitle => 'Animate your bug';

  @override
  String get studioDownloadsTitle => 'DOWNLOADS';

  @override
  String get studioDownloadsSubtitle => 'Your offline archive';

  @override
  String get badgeHot => 'HOT';

  @override
  String get suikaArenaTitle => 'SUIKA ARENA';

  @override
  String get heroSubtitleLine1 => 'Merge matching bugs, evolve to the';

  @override
  String get heroSubtitleLine2 => 'Pink Bathrobe!';

  @override
  String get dailyRewardTitle => 'DAILY REWARD';

  @override
  String get dailyRewardSubtitle => 'Day 3 · 500 coins are waiting for you';

  @override
  String get claim500 => 'CLAIM · 500';

  @override
  String get claimEnergy5 => 'GET ENERGY · +5';

  @override
  String get onlineModeTitle => 'ONLINE MODE';

  @override
  String get onlineModeSubtitle =>
      'Play online with your friends very soon!';

  @override
  String get notifyMe => 'NOTIFY ME';

  @override
  String get chatTitle => 'CHAT';

  @override
  String get onlineCount5 => '5 ONLINE';

  @override
  String get chatSubtitle => 'Hang out with the guild, talk records';

  @override
  String get hubTasksSubtitle => 'Finish tasks, grab the reward!';

  @override
  String get seeAllButton => 'SEE ALL';

  @override
  String get suikaArenaSubtitle => 'The merging classic';

  @override
  String get grid2048Title => '2048 GRID';

  @override
  String get grid2048Subtitle => 'Slide, merge, make 2048';

  @override
  String get balloonPopTitle => 'BALLOON POP';

  @override
  String get balloonPopSubtitle => 'Aim and pop 3 matching balloons';

  @override
  String get badgeBonus => 'BONUS';

  @override
  String get match3Title => 'MATCH 3';

  @override
  String get match3Subtitle => 'Slide a neighbour, pop 3 in a row';

  @override
  String get badgeNeon => 'NEON';

  @override
  String recordWithValue(String best) => 'Best: $best';

  // --- Dalga 10 göçü: Profil ekranı ---

  @override
  String get signInOrUpLabel => 'Sign in or sign up';

  @override
  String get signInOrUpButton => 'SIGN IN / SIGN UP';

  @override
  String get guestSignInExplanation =>
      'If you sign in, your scores and progress will be linked to your account.';

  @override
  String get guestName => 'Guest';

  @override
  String get guestHandleNotSignedIn => 'Guest · not signed in';

  @override
  String get appleHandle => '@apple · Signed in with Apple';

  @override
  String get guestSessionHandle => '@guest · Guest session';

  @override
  String get badgeComboKing => 'COMBO KING';

  @override
  String get badgeComboKingReq => 'Get a 5× combo';

  @override
  String get badgeMarathon => 'MARATHONER';

  @override
  String get badgeMarathonReq => 'Play 50 games';

  @override
  String get badgeVideoBuff => 'VIDEO BUFF';

  @override
  String get badgeVideoBuffReq => 'Watch 1 video';

  @override
  String get badgeGoldenFinger => 'GOLDEN FINGER';

  @override
  String get badgeGoldenFingerReq => '10.000 total score';

  @override
  String get badgeTaskHunter => 'TASK HUNTER';

  @override
  String get badgeTaskHunterReq => 'Claim all task rewards';

  @override
  String get badgeEvolutionMaster => 'EVOLUTION MASTER';

  @override
  String get badgeEvolutionMasterReq => 'Reach the Pink\nBathrobe';

  @override
  String get badgeEarned => 'Earned';

  @override
  String get playerProfileTitle => 'PLAYER PROFILE';

  @override
  String get levelLabel => 'LEVEL';

  @override
  String get nextLevel => 'NEXT LEVEL';

  @override
  String get totalScoreLabel => 'TOTAL SCORE';

  @override
  String get gamesPlayedLabel => 'GAMES PLAYED';

  @override
  String get bestComboLabel => 'BEST COMBO';

  @override
  String get myBadges => 'MY BADGES';

  @override
  String badgesEarnedCount(int count) => '$count/6 EARNED';

  @override
  String get lockedLabel => 'LOCKED';

  // --- Dalga 15 göçü: Tanıtım ekranı (onboarding_screen) ---

  @override
  String get onboardingTagline => 'COCKROACH MERGE MANIA';

  @override
  String onboardingPageLabel(int page) => 'Intro page $page / 3';

  @override
  String get onboardingNextLabel => 'Next step';

  @override
  String get onboardingNextStep => 'NEXT STEP →';

  @override
  String get onboardingSkipLabel => 'Skip the intro';

  @override
  String get onboardingSlide1Title => 'Merge Bugs, Evolve Them!';

  @override
  String get onboardingSlide1Body =>
      'Crash same-level bugs together and climb the 13-stage evolution chain to the legendary Pink Bathrobe!';

  @override
  String tierLabel(int tier) => 'Tier $tier';

  @override
  String get onboardingSlide2Title =>
      '11 Different Game Modes & 3 Bonuses Each!';

  @override
  String get onboardingSlide2Body =>
      'Suika, 2048, Match-3, Balloon Pop and more! When you get stuck, fire the F16, Raid and Mum Slipper boosters.';

  @override
  String get boosterF16Sub => 'Air Strike';

  @override
  String get boosterRaidSub => 'Spray Storm';

  @override
  String get boosterSlipperTitle => 'Slipper';

  @override
  String get boosterSlipperSub => "Mum's Slipper";

  @override
  String get onboardingSlide3Title => 'Bug Studio, GIFs & Leaderboard!';

  @override
  String get onboardingSlide3Body =>
      'Dress up your own bug, make funny GIFs and stickers, share them with friends and climb to the top of the leaderboard!';

  @override
  String get onboardingStudioTitle => 'Studio';

  @override
  String get onboardingStudioSub => 'Design a Bug';

  @override
  String get onboardingGifTitle => 'Make a GIF';

  @override
  String get onboardingGifSub => 'Share to Stories';

  @override
  String get onboardingLeaderboardTitle => 'Leaderboard';

  @override
  String get onboardingLeaderboardSub => 'Weekly League';

  @override
  String get onboardingLoadingText =>
      'Preparing bug sounds and 11 game scenes...';

  @override
  String get onboardingTapToStartLabel => 'Tap to start';

  @override
  String get onboardingTapToStart => 'TAP TO START!';

  @override
  String get onboardingVersionLine =>
      'v3.0 · Touch-friendly on mobile & desktop';

  // --- Dalga 15 göçü: Açılış ekranı (splash_screen) ---

  @override
  String splashLoadMessage(int index) => switch (index) {
        0 => 'Warming up the bathhouse…',
        1 => 'Bugs are lining up…',
        2 => 'Slippers are being polished…',
        3 => 'Doors are opening…',
        _ => 'Ready! The adventure begins…',
      };

  @override
  String get splashSkip => 'SKIP ›';

  @override
  String get splashStartButton => 'START ›';

  @override
  String get splashContinueButton => 'CONTINUE ›';

  @override
  String get splashVersionLabel => 'v1.0 · Design Prototype';

  @override
  String get splashKicker1 => 'NEW ADVENTURE';

  @override
  String get splashKicker2 => '11 GAME MODES';

  @override
  String get splashKicker3 => 'FINAL STEP';

  @override
  String get splashTitle1Line1 => 'MERGE THE BUGS,\n';

  @override
  String get splashTitle1Line2 => 'CREATE THE LEGEND!';

  @override
  String get splashSubtitle1 =>
      'Crash the same bugs together and climb\nthe 13-stage evolution chain all the way\nto the Pink Bathrobe.';

  @override
  String get splashBubbleText => 'THE LEADER HAS SPOKEN!';

  @override
  String get linkPopTitle => 'LINK & POP';

  @override
  String get stackDropTitle => 'STACK DROP';

  @override
  String get slipperTapTitle => 'SLIPPER TAP';

  @override
  String get osmantusTitle => 'OSMANTUŞ';

  @override
  String get screamBugTitle => 'SCREAM BUG';

  @override
  String get makarayizTitle => 'MAKARAYIZ';

  @override
  String get splashTitle2Line1 => 'A NEW ADVENTURE\n';

  @override
  String get splashTitle2Line2 => 'EVERY DAY!';

  @override
  String get splashTitle3Line1 => 'READY FOR\n';

  @override
  String get splashTitle3Line2 => 'THE ADVENTURE?';

  @override
  String get splashStarting => 'STARTING!';

  @override
  String splashLoadingPercent(int percent) => 'LOADING… %$percent';

  @override
  String get splashStartAdventure => 'START THE ADVENTURE';

  @override
  String get splashPressToStart => 'Press the button to start!';

  // --- Dalga 15 göçü: Üst bar (top_bar) ---

  @override
  String levelBadge(int level, bool compact) =>
      compact ? 'LVL$level' : 'LVL $level';

  @override
  String get energyFull => 'FULL';

  // --- Dalga 15 göçü: Hesap ekranı (auth_screen) ---

  @override
  String get authSessionOpen => 'Session open';

  @override
  String get accountTitle => 'ACCOUNT';

  @override
  String get authCardSubtitle =>
      'A real account with username + password. Scores link to the leaderboard.';

  @override
  String get usernameHint => 'Username';

  @override
  String get passwordHint => 'Password';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get authHeaderRegister => 'SIGN UP';

  @override
  String get authHeaderLogin => 'SIGN IN';

  @override
  String get closeLabel => 'Close';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get loginTab => 'Sign in';

  @override
  String get registerTab => 'Sign up';

  @override
  String get createAccountButton => 'CREATE ACCOUNT';

  @override
  String get signInButton => 'SIGN IN';

  @override
  String get orDivider => 'OR';

  // --- Dalga 20 göçü: Oyun + sonuç ekranı (game_screen, result_screen) ---

  @override
  String get comboTimeoutReason => 'TIME UP';

  @override
  String get comboMissReason => 'MISS';

  @override
  String comboBreakToast(String reason) => 'COMBO OVER: $reason';

  @override
  String milestoneToast(String title) => 'NEW: $title';

  @override
  String get speechAydinlat =>
      "Light up the place, for heaven's sake!";

  @override
  String get speechSlipper => "Slap! Mum's slipper strikes!";

  @override
  String get speechSpray => 'Psss! Raid cleaned it all up!';

  @override
  String get howToTitle => 'Suika Arena — How to Play?';

  @override
  String get howToBody =>
      'Tap the field — the next bug drops right there. When two bugs of the same tier collide, the next tier is born and the score multiplies. If the pile crosses the red danger line, the game ends.\n\nBoosters:\n• Raid Spray clears small bugs.\n• Shake rearranges the pile.\n• Light It Up! brings in the F16 to bomb the field.';

  @override
  String get understoodButton => 'GOT IT';

  @override
  String get gameScoreLabel => 'SCORE';

  @override
  String get gameBestLabel => 'BEST';

  @override
  String get gameNextLabel => 'NEXT UP';

  @override
  String get gamePausedTitle => 'GAME PAUSED';

  @override
  String pausedScoreLine(int score) => 'Paused · Score $score';

  @override
  String get resumeButtonCaps => 'RESUME';

  @override
  String get restartLevelButton => 'RESTART';

  @override
  String get finishGameButton => 'END GAME';

  @override
  String get surviveLabel => 'SURVIVE';

  @override
  String bossLabel(String name) => '👑 BOSS: $name';

  @override
  String chapterLabel(int id) => 'Chapter $id';

  @override
  String overflowingCountdown(String seconds) =>
      'OVERFLOWING! ${seconds}s';

  @override
  String get nearLineWarning => 'NEAR THE LINE!';

  @override
  String comboToast(int count) => 'COMBO x$count!';

  @override
  String get boosterRaidLabel => 'RAID SPRAY';

  @override
  String get boosterShakeLabel => 'SHAKE';

  @override
  String get boosterLightLabel => 'LIGHT UP';

  @override
  String boosterCountLabel(String label, int count) =>
      '$label. $count left';

  @override
  String shareScoreSnack(int score) =>
      'Your score was copied to the clipboard: $score points! #LululuGame';

  @override
  String get resultSubtitle =>
      'One step closer to the top — the Pink Bathrobe!';

  @override
  String get levelCompleteTitle => 'LEVEL COMPLETE!';

  @override
  String get bestComboResultLabel => 'BEST COMBO';

  @override
  String get mergesLabel => 'MERGES';

  @override
  String get goldEarnedLabel => 'GOLD EARNED';

  @override
  String get continueWithAdSoon => 'CONTINUE WITH AD · COMING SOON';

  @override
  String get doubleGoldAdSoon => '2X GOLD WITH AD · COMING SOON';

  @override
  String get playAgainButton => 'PLAY AGAIN';

  @override
  String get sharedButton => 'SHARED!';

  @override
  String get shareButton => 'SHARE';

  // --- Dalga 20 göçü: Ayarlar (settings_screen) ---

  @override
  String get resetProgressTitle => 'RESET PROGRESS';

  @override
  String get resetProgressBody =>
      'All your gold, level, high score and booster progress will be reset. Are you sure?';

  @override
  String get cancelCaps => 'CANCEL';

  @override
  String get resetButton => 'RESET';

  @override
  String accountDeleteFailed(String error) =>
      'Account could not be deleted: $error';

  @override
  String get accountDeletedSnack =>
      'Your account was deleted. You have been signed out.';

  @override
  String signedInAs(String displayName) => '$displayName · Signed in';

  @override
  String get signInOrUpSlash => 'Sign in / sign up';

  @override
  String get sfxTitle => 'Sound Effects';

  @override
  String get sfxSubtitle => 'Merge and tap sounds';

  @override
  String get vibrationTitle => 'Vibration';

  @override
  String get vibrationSubtitle => 'Gentle vibration on merge';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'Game language: Türkçe or English';

  @override
  String get privacyTitle => 'PRIVACY POLICY';

  @override
  String get privacySubtitle => 'Collected data and storage';

  @override
  String get deletingLabel => 'DELETING…';

  @override
  String get confirmDeleteAgain => 'ARE YOU SURE? TAP AGAIN';

  @override
  String get deleteAccountButton => 'Delete Account';

  @override
  String get pleaseWait => 'Please wait…';

  @override
  String get deleteAccountArmedSub =>
      'Your account will be deleted and you will be signed out';

  @override
  String get deleteAccountSub => 'Delete your account and sign out';

  @override
  String get voiceTitle => 'Bug Voice Lines';

  @override
  String get voiceSubtitle => 'Character lines and effects';

  @override
  String get howToPlayRowTitle => 'HOW TO PLAY';

  @override
  String get howToPlayRowSub => 'Game rules, merging and powers';

  @override
  String get resetProgressRowTitle => 'Reset Progress';

  @override
  String get resetProgressRowSub => 'Clear all saved game data';

  // --- Dalga 20 göçü: Gizlilik politikası (privacy_policy_screen) ---

  @override
  String get deleteAccountCaps => 'DELETE ACCOUNT';

  @override
  String get privacyIntro =>
      'LÜLÜLÜ processes the data needed to play the game. This text explains what data the game collects, where it stores it, and how you can delete your data.';

  @override
  String get privacySection1Title => '1. Data we collect';

  @override
  String get privacySection1Body1 =>
      'Account info: the username, display name and email address you provide when signing up or signing in. When signing in with Apple or Google, the name and email shared by that service are used.';

  @override
  String get privacySection1Body2 =>
      'Game data: your scores, coin and level progress, task status and game settings (music, sound, vibration).';

  @override
  String get privacySection1Body3 =>
      'Chat messages: only if you use the chat feature, the messages you send.';

  @override
  String get privacySection1Body4 =>
      'Microphone volume: only in Scream Bug mode and with your permission; the game measures how loud your voice is (decibels). No voice recording is kept and no audio file is sent.';

  @override
  String get privacySection2Title => '2. Where your data is stored';

  @override
  String get privacySection2Body1 =>
      'On your device: your session, progress and settings are kept in local storage on your device.';

  @override
  String get privacySection2Body2 =>
      'In the cloud (only if you are signed in and online sync is on): your scores, display name and chat messages are stored on Firebase (Auth + Firestore). If Firebase is not configured, your data stays only on your device.';

  @override
  String get privacySection2Body3 =>
      'Score and progress updates that could not be sent while offline wait in a queue on your device and are sent once the connection returns.';

  @override
  String get privacySection3Title => '3. Sharing and tracking';

  @override
  String get privacySection3Body1 =>
      'The game does not share your data with third-party advertising or analytics companies; this version contains no analytics or ad tracking SDK.';

  @override
  String get privacySection3Body2 =>
      'Ad display in this version is only an on-device placeholder; no connection to a real ad network is made.';

  @override
  String get privacySection4Title => '4. Purchases';

  @override
  String get privacySection4Body1 =>
      'In-game purchases are made through the app store (App Store / Google Play). Your payment details are not collected by the game.';

  @override
  String get privacySection5Title => '5. Deleting your data';

  @override
  String get privacySection5Body1 =>
      'You can clear the progress on your device with Settings > Reset Progress.';

  @override
  String get privacySection5Body2 =>
      'Uninstalling the app deletes the local game data on your device.';

  @override
  String get privacySection5Body3 =>
      'You can delete your account with the button below: the account record on your device is deleted and you are signed out. Your game progress and copies stored in the cloud are not deleted separately.';

  @override
  String get privacySection6Title => '6. Changes';

  @override
  String get privacySection6Body1 =>
      'If this text changes, the updated version will be published in the game.';

  // --- Dalga 20 göçü: Bölüm haritası (campaign_map_screen + campaign_map_sheet) ---

  @override
  String get campaignSuikaHeader => '🪳 SUIKA ARENA (80 CHAPTERS)';

  @override
  String get campaign2048Header => '🔢 LÜLÜLÜ 2048';

  @override
  String get campaignMapTitle => 'Chapter Map';

  @override
  String chapterLabelCaps(int id) => 'CHAPTER $id';

  @override
  String get levelGoalTitle => '🎯 CHAPTER GOAL';

  @override
  String secondsLabel(int seconds) => '${seconds}s';

  @override
  String movesLabel(int moves) => '$moves shots';

  @override
  String pointsLabel(int points) => '$points points';

  @override
  String get bareTierLabel => 'Tier';

  @override
  String get upNextLabel => 'UP NEXT';

  @override
  String chestUnlockedToast(
    int stars,
    int coins,
    int boosterCount,
    String boosterName,
  ) =>
      '🎁 $stars⭐ Chest Unlocked: +$coins Gold & +$boosterCount $boosterName!';

  @override
  String get campaignSheetTitle => '80-LEVEL CAMPAIGN MAP';

  @override
  String get campaignSheetSubtitle =>
      '8 Chapters · 8 Boss Battles · 24 Star Chests';

  @override
  String chapterBannerTitle(int index, String title) =>
      'CHAPTER $index: $title';

  @override
  String bossBannerLine(int id, String bossName, int hp, String hazard) =>
      '👑 Boss #$id: $bossName ($hp HP) · Hazard: $hazard';

  @override
  String levelRangeShort(int start, int end) => 'Lv $start-$end';

  @override
  String chestStarsLabel(int stars) => '$stars⭐ Chest';

  @override
  String get claimedPlain => 'Claimed';

  @override
  String chestRewardLine(int coins, int count) => '+$coins🪙 +$count⚡';

  @override
  String get bossShort => 'BOSS';

  // --- Dalga 20 göçü: Sohbet (chat_lobby_screen, chat_screen) ---

  @override
  String onlinePlayersCount(int count) => '$count ONLINE';

  @override
  String levelShort(int level) => 'Lv. $level';

  @override
  String get messageHint => 'Write a message…';

  @override
  String get messageSendFailed =>
      'Message could not be sent. Try again.';

  @override
  String get stickerSendFailed =>
      'Sticker could not be sent. Try again.';

  @override
  String get quickStickerTitle => 'SEND A QUICK BUG STICKER';

  @override
  String get notSentLocalOnly => '⚠ Not sent · On this device only';

  @override
  String get cloudSendFailedNote =>
      'Could not be sent to the cloud — your messages are only visible on this device.';

  @override
  String get retryCaps => 'TRY AGAIN';

  @override
  String get guildMessageHint => 'Write to the guild…';

  // --- Dalga 20 göçü: Başarım toast'ı + pass (achievement_toast_overlay) ---

  @override
  String get achievementUnlockedTitle => 'ACHIEVEMENT UNLOCKED!';

  @override
  String achievementRewardLine(int coins, int xp) =>
      '+$coins 🪙 · +$xp XP';

  @override
  String titleRewardLine(String title) => 'Title: $title';

  @override
  String get masteryPassTitle => 'MASTERY & LÜLÜLÜ PASS';

  @override
  String masteryHeaderLine(String title, int unlocked, int total) =>
      'Title: $title · $unlocked/$total Achievements';

  @override
  String seasonTierLine(int tier, int xp, int nextXp) =>
      'Season Tier: $tier / 20  ($xp / $nextXp XP)';

  @override
  String get goldPassActive => 'GOLD PASS ACTIVE';

  @override
  String get goldPassOpen => 'UNLOCK GOLD PASS';

  @override
  String achievementsCountLine(int unlocked) =>
      '30 Achievements ($unlocked/30)';

  @override
  String passTierLabel(int tier) => 'Lülülü Pass ($tier/20)';

  @override
  String get allAchievementsLabel => 'All (30)';

  @override
  String achievementRewardCompact(int coins, int xp) =>
      '+$coins🪙 +${xp}XP';

  @override
  String get unlockedShort => 'UNLOCKED';

  @override
  String get freeTrackTitle => 'FREE';

  @override
  String get goldPassTitle => 'GOLD PASS';

  @override
  String get collectButton => 'COLLECT';

  // --- Dalga 20 göçü: Skor tablosu (leaderboard_screen) ---

  @override
  String get leaderboardTitle => 'LEADERBOARD';

  @override
  String get weeklyLabel => 'Weekly';

  @override
  String get leaderboardLoadingLabel => 'Loading the leaderboard';

  @override
  String get noScoresYet => 'No scores saved yet';

  @override
  String get noScoresHint =>
      'Play a game — your score will show up here once it is saved.';

  // --- Dalga 20 göçü: Hesap (auth_screen, auth_panel) ---

  @override
  String get applePlayerFallback => 'Apple Player · apple';

  @override
  String get guestContinueLabel => 'Continue as guest';

  @override
  String get guestContinueButton => 'CONTINUE AS GUEST';

  @override
  String get registerButtonShort => 'SIGN UP';

  @override
  String get loginButtonShort => 'SIGN IN';

  @override
  String get usernameHintDetailed => 'Your username (min 3 characters)';

  @override
  String get passwordHintDetailed => 'Password (min 6 characters)';

  // --- Dalga 20 göçü: Stüdyo (studio_screens) ---

  @override
  String get linkCopiedToast => 'Link copied — ready to share';

  @override
  String get videoAddedToDownloadsToast => 'Video added to Downloads';

  @override
  String videoPlayPauseLabel(bool isPlaying, String title) =>
      isPlaying ? 'Pause: $title' : 'Play: $title';

  @override
  String likeLabel(String count, bool liked) =>
      liked ? 'Like: $count likes, liked' : 'Like: $count likes';

  @override
  String get shareLabel => 'Share';

  @override
  String get downloadLabel => 'Download';

  @override
  String get upNextVideosTitle => 'UP NEXT VIDEOS';

  @override
  String playVideoLabel(String title, String meta) =>
      'Play the video $title, $meta';

  @override
  String get draftSavedToast =>
      'Draft saved! You can share it from the Upload screen.';

  @override
  String get studioToolTrim => 'TRIM';

  @override
  String get studioToolText => 'TEXT';

  @override
  String get studioToolSticker => 'STICKER';

  @override
  String get trimClipTitle => 'TRIM THE CLIP';

  @override
  String get trimEndLabel => 'Trim, end of the selected section';

  @override
  String get selectedSectionPrefix => 'Selected section: ';

  @override
  String get totalDurationSuffix => ' · Total 0:47';

  @override
  String get addTextTitle => 'ADD TEXT';

  @override
  String get videoCaptionHint => 'Write text on your video…';

  @override
  String get captionPreviewNote =>
      'The text appears instantly in the preview.';

  @override
  String get chooseStickerTitle => 'CHOOSE A STICKER';

  @override
  String stickerLabel(int index) => 'Sticker $index';

  @override
  String get saveAndPreviewLabel => 'Save and preview';

  @override
  String get saveAndPreviewButton => 'SAVE AND PREVIEW';

  @override
  String get draftShareableNote =>
      'The draft can be shared from the Upload screen.';

  @override
  String get uploadDefaultTitle => 'My Bug Merge Record!';

  @override
  String get videoUploadedSnack =>
      'Video uploaded to the Studio successfully!';

  @override
  String get chooseFileLabel =>
      'Choose a file: MP4 or MOV, max 500 MB';

  @override
  String get chooseFileButton => 'CHOOSE FILE';

  @override
  String get fileConstraintsNote => 'MP4 or MOV · max 500 MB';

  @override
  String get videoTitleLabel => 'VIDEO TITLE';

  @override
  String get videoTitleHint => 'e.g. My record merge moment!';

  @override
  String get startUploadLabel => 'Start the upload';

  @override
  String get startUploadButton => 'START UPLOAD';

  @override
  String get gifDefaultCaption => 'DANCE TIME!';

  @override
  String get gifCreatedSnack => 'GIF created and saved!';

  @override
  String get chooseFramesTitle => 'CHOOSE FRAMES';

  @override
  String get selectedFramesNote =>
      'The selected frames play in order in the preview.';

  @override
  String get textAndSpeedTitle => 'TEXT & SPEED';

  @override
  String get speedSlow => 'SLOW';

  @override
  String get speedNormal => 'NORMAL';

  @override
  String get speedFast => 'FAST';

  @override
  String get createGifLabel => 'Create a GIF';

  @override
  String deletedItemSnack(String title) => 'Deleted: $title';

  @override
  String get storageTitle => 'STORAGE';

  @override
  String storageUsedSuffix(int count) =>
      ' used · 4 GB total · $count items';

  @override
  String playItemLabel(String title) => 'Play: $title';

  @override
  String nowPlayingLabel(String title) => 'Now playing: $title';

  @override
  String deleteItemLabel(String title) => 'Delete: $title';

  // --- Dalga 33 göçü (W33-1): erişilebilirlik etiketleri ---
  // Yalnız anahtar eklendi; UI göçü sonraki dalgada (kaynak metinler
  // lululu_dock_bar.dart, top_bar.dart, auth_panel.dart ve
  // shop_dialog.dart'ta gömülü duruyor).

  @override
  String dockUnreadLabel(String label, String badge) =>
      '$label, $badge unread messages';

  @override
  String get energyLabel => 'Energy';

  @override
  String get showPasswordLabel => 'Show password';

  @override
  String get hidePasswordLabel => 'Hide password';

  @override
  String get addCoinPackLabel => 'Add coin pack';

  @override
  String shopBuyItemLabel(String title, String priceText) =>
      'Buy $title, $priceText';

  @override
  String shopBuyPowerUpLabel(String name, int cost) =>
      'Buy $name, $cost coins';

  // --- Dalga 55 göçü (W55-3): Mağaza (shop_dialog) — yalnız anahtar ---

  @override
  String get shopModeSuikaArena => 'Suika Arena';

  @override
  String get shopPowerRaidSprayName => 'Raid Spray';

  @override
  String get shopPowerRaidSprayDesc => 'Clears small bugs';

  @override
  String get shopPowerSlipperShakeName => 'Slipper Shake';

  @override
  String get shopPowerSlipperShakeDesc => 'Shakes the area and fixes the layout';

  @override
  String get shopPowerLightItUpName => 'Light It Up!';

  @override
  String get shopPowerLightItUpDesc => 'F16 bombardment — burns through 3 bugs';

  @override
  String get shopModeGrid2048 => '2048 Grid';

  @override
  String get shopPowerUndoName => 'Undo';

  @override
  String get shopPowerUndoNameCaps => 'UNDO';

  @override
  String get shopPowerUndoDesc => 'Undoes the last move';

  @override
  String get shopPowerShuffleName => 'Shuffle';

  @override
  String get shopPowerShuffleNameCaps => 'SHUFFLE';

  @override
  String get shopPowerShuffleDesc => 'Shuffles the grid, unlocks it';

  @override
  String get shopPowerMergePairName => 'Pair Up';

  @override
  String get shopPowerMergePairNameCaps => 'PAIR UP';

  @override
  String get shopPowerMergePairDesc => 'Merges two random matching tiles';

  @override
  String get shopModeBalloonPop => 'Balloon Pop';

  @override
  String get shopPowerTripleArrowName => 'Triple Arrow';

  @override
  String get shopPowerTripleArrowDesc => 'Pops 3 balloons in one shot';

  @override
  String get shopPowerBombBalloonName => 'Bomb Balloon';

  @override
  String get shopPowerBombBalloonDesc => 'Blasts an area';

  @override
  String get shopPowerSlowName => 'Slow Down';

  @override
  String get shopPowerSlowNameCaps => 'SLOW DOWN';

  @override
  String get shopPowerSlowBalloonDesc => 'Slows balloons for 10 sec';

  @override
  String get shopModeMatch3 => 'Match 3';

  @override
  String get shopPowerHammerName => 'Hammer';

  @override
  String get shopPowerHammerDesc => 'Breaks a single tile';

  @override
  String get shopPowerBombName => 'Bomb';

  @override
  String get shopPowerBombDesc => 'Blasts a 3×3 area';

  @override
  String get shopPowerColorHunterName => 'Color Hunter';

  @override
  String get shopPowerColorHunterDesc => 'Collects all of one type';

  @override
  String get shopModeLinkPop => 'Link Pop';

  @override
  String get shopPowerChainExtenderName => 'Chain Extender';

  @override
  String get shopPowerChainExtenderDesc => 'Increases chain allowance';

  @override
  String get shopPowerLightningName => 'Lightning';

  @override
  String get shopPowerLightningDesc => 'Creates a random chain';

  @override
  String get shopPowerMagnetName => 'Magnet';

  @override
  String get shopPowerMagnetDesc => 'Pulls the same type together';

  @override
  String get shopModeStackDrop => 'Stack Drop';

  @override
  String get shopPowerFreezeName => 'Freeze';

  @override
  String get shopPowerFreezeNameCaps => 'FREEZE';

  @override
  String get shopPowerFreezeDesc => 'Stops the wobble';

  @override
  String get shopPowerWidenName => 'Widen';

  @override
  String get shopPowerWidenNameCaps => 'WIDEN';

  @override
  String get shopPowerWidenDesc => 'Enlarges the slice';

  @override
  String get shopPowerSlowStackDesc => 'Reduces fall speed';

  @override
  String get shopModeSlipperTap => 'Slipper Tap';

  @override
  String get shopPowerDoubleSlipperName => 'Double Slipper';

  @override
  String get shopPowerDoubleSlipperNameCaps => 'DOUBLE SLIPPER';

  @override
  String get shopPowerDoubleSlipperDesc => 'Double hit in one tap';

  @override
  String get shopPowerGoldenSlipperName => 'Golden Slipper';

  @override
  String get shopPowerGoldenSlipperNameCaps => 'GOLDEN SLIPPER';

  @override
  String get shopPowerGoldenSlipperDesc => '2x points for a limited time';

  @override
  String get shopPowerBugSprayName => 'Bug Spray';

  @override
  String get shopPowerBugSprayDesc => 'Clears the bugs on screen';

  @override
  String get shopModeNestDefense => 'Nest Defense';

  @override
  String get shopPowerNestShieldName => 'Nest Shield';

  @override
  String get shopPowerNestShieldDesc => 'Forgives one escape';

  @override
  String get shopModeOsmantus => 'Osmantuş';

  @override
  String get shopPowerDikkisBoostName => 'Dıkkış Boost';

  @override
  String get shopPowerDikkisBoostDesc => 'Tempo boost — the ring slows down';

  @override
  String get shopPowerWideRingName => 'Wide Ring';

  @override
  String get shopPowerWideRingDesc => 'Enlarges the target ring';

  @override
  String get shopPowerMicrophoneName => 'Microphone';

  @override
  String get shopPowerMicrophoneDesc => 'Protects the combo on one mistake';

  @override
  String get shopModeScreamBug => 'Scream Bug';

  @override
  String get shopPowerJumpBootsName => 'Jump Boots';

  @override
  String get shopPowerJumpBootsDesc => 'Clears obstacles';

  @override
  String get shopPowerShieldName => 'Shield';

  @override
  String get shopPowerShieldDesc => 'Forgives one mistake';

  @override
  String get shopPowerNitroName => 'Nitro';

  @override
  String get shopPowerNitroNameCaps => 'NITRO';

  @override
  String get shopPowerNitroDesc => 'Speed and score boost';

  @override
  String get shopModeMakarayiz => 'Makarayız';

  @override
  String get shopPowerBeatFreezeName => 'Beat Freeze';

  @override
  String get shopPowerBeatFreezeDesc => 'Slows the rhythm';

  @override
  String get shopPowerAutoReelName => 'Auto Reel';

  @override
  String get shopPowerAutoReelDesc => 'Plays automatically for a short while';

  @override
  String get shopPowerScoreMultiplierName => 'Score Multiplier';

  @override
  String get shopPowerScoreMultiplierDesc => '2x points for a limited time';

  @override
  String get shopGoldenWeekendTitle => 'GOLDEN WEEKEND';

  @override
  String get shopGoldenWeekendSubtitle => '50% bonus on all coin packs';

  @override
  String get shopFreeChestTitle => 'FREE CHEST';

  @override
  String get shopFreeChestDesc => 'Rewarded ads coming soon: a free Wooden Chest + 1 random power-up will be here.';

  @override
  String get shopEnergyTitle => 'ENERGY';

  @override
  String get shopEnergyRefillNote => '5 min = +1 heart';

  @override
  String get shopPowerUpsTitle => 'POWER-UPS';

  @override
  String get shopPowerUpsNote => 'Mode-specific · 33 kinds';

  @override
  String get shopCoinPacksTitle => 'COIN PACKS';

  @override
  String get shopChestsAndPotionsTitle => 'CHESTS & POTIONS';

  @override
  String get shopBadgeBest => 'BEST';

  @override
  String get shopBadgeDeal => 'DEAL';

  @override
  String get shopBadgeLucky => 'LUCKY';

  @override
  String get shopItemEnergyPackTitle => 'Energy Pack';

  @override
  String get shopItemEnergyPackDesc => '+10 energy · fills instantly, no waiting';

  @override
  String get shopItemEnergyDepotTitle => 'Energy Depot';

  @override
  String get shopItemEnergyDepotDesc => 'Fill hearts to 30/30 · full energy in one go';

  @override
  String get shopItemStarPackTitle => 'Star Pack';

  @override
  String get shopItemStarPackDesc => '25 stars + 1,000 coins';

  @override
  String get shopItemSurpriseBoxTitle => 'Surprise Box';

  @override
  String get shopItemSurpriseBoxDesc => '1 power-up from a random mode';

  @override
  String get shopItemHandfulTitle => 'A Handful';

  @override
  String get shopItemHandfulDesc => '1,250 coins';

  @override
  String get shopItemCrateTitle => 'A Crate';

  @override
  String get shopItemCrateDesc => '7,500 coins · +50% bonus';

  @override
  String get shopItemWoodenChestTitle => 'Wooden Chest';

  @override
  String get shopItemWoodenChestDesc => 'Random power-up + coins';

  @override
  String get shopItemGoldenChestTitle => 'Golden Chest';

  @override
  String get shopItemGoldenChestDesc => 'Contains a guaranteed rare reward';

  @override
  String get shopItemDoubleCoinTitle => 'Double Coins';

  @override
  String get shopItemDoubleCoinDesc => '2× coins for 30 minutes';

  @override
  String get shopItemLuckPotionTitle => 'Luck Potion';

  @override
  String get shopItemLuckPotionDesc => 'Increases crit chance on merges';

  @override
  String get shopNotEnoughGoldToast => 'Not enough gold! Play games to earn gold.';

  @override
  String get shopAddedCoinPackToast => 'Coin pack added to cart';

  @override
  String get shopEnergyRegenToast => 'Energy refills 1 every 5 minutes — play without waiting with a pack';

  @override
  String get shopEnergyAddedToast => '+10 energy added — your heart is full!';

  @override
  String get shopStoreUnavailableToast => 'Store unavailable — purchase could not be completed.';

  @override
  String get shopEnergyFullToast => 'Energy is full at 30/30!';

  @override
  String get shopPowerUpModeOnlyToast => 'Each mode\'s power-ups can only be used in that mode';

  @override
  String get shopAddedStarPackToast => 'Star Pack added to cart';

  @override
  String get shopAddedSurpriseBoxToast => 'Surprise Box added to cart';

  @override
  String get shopAddedWoodenChestToast => 'Wooden Chest added to cart';

  @override
  String get shopAddedGoldenChestToast => 'Golden Chest added to cart';

  @override
  String get shopAddedDoubleCoinToast => 'Double Coins added to cart';

  @override
  String get shopAddedLuckPotionToast => 'Luck Potion added to cart';

  @override
  String shopPowerUpDescModeSuffix(String desc, String modeName) => '$desc · only in $modeName mode';

  @override
  String shopPowerUpAddedToCartToast(String name, String modeName) => '$name added to cart ($modeName)';

  @override
  String shopPowerGroupBonusCount(int count) => '$count bonus';

  // --- Dalga 59 (W59-2): erişilebilirlik etiketleri, 2. tur ---

  @override
  String get helpButtonLabel => 'How to play';

  @override
  String get sendMessageLabel => 'Send message';

  @override
  String get sendStickerHint => 'Long press: send a sticker';

  @override
  String get finishRoundLabel => 'Finish';

  @override
  String profilePillLabel(String name, int level) =>
      'Profile: $name, level $level';

  @override
  String coinPillLabel(String value) => 'Coin: $value, add coin pack';

  // --- W60-2: §3 paylaşılan anahtarlar (i18n göç planı) ---
  @override
  String get pausedStatusCaps => 'PAUSED';

  @override
  String get finishCaps => 'FINISH';

  @override
  String get finishLabel => 'Finish';

  @override
  String get tryAgainCaps => 'TRY AGAIN';

  @override
  String get retryShort => 'RETRY';

  @override
  String get viralBadge => 'VIRAL';

  @override
  String get moveLabel => 'MOVE';

  @override
  String get timeLabel => 'TIME';

  @override
  String get livesLabel => 'LIVES';

  @override
  String get newBadge => 'NEW';

  @override
  String get missedCaps => 'MISSED';

  @override
  String get perfectCaps => 'PERFECT!';

  @override
  String get comboBrokenShort => 'COMBO BROKEN';

  @override
  String get understoodLabel => 'Got it';

  @override
  String get connectTargetHit => 'Target reached.';

  @override
  String get powerShieldCaps => 'SHIELD';

  @override
  String get statusLabel => 'STATUS';

  @override
  String get resultComplete => 'COMPLETE';

  @override
  String get resultOver => 'OVER';

  @override
  String get modeBadgeTitle => 'MODE BADGE';

  @override
  String get doubleGoldEarnedCaps => '2X GOLD EARNED';

  @override
  String perfectCombo(int combo) => 'PERFECT! X$combo';

  @override
  String comboBrokenReason(String reason) => '$reason · COMBO BROKEN';

  @override
  String pauseScoreComboLine(int score, int combo) => 'Score $score · Combo x$combo';

  @override
  String arcadeMilestoneScore(int m) => 'SCORE $m!';

  @override
  String featuredBannerLabel(String badge) => 'FEATURED · $badge';

  @override
  String featuredEndsToday(String clock) => 'Ends today · $clock';

  // --- W60-2: G2 connect_pop (i18n göç planı) ---
  @override
  String get connectHintIdle => 'Draw the same bug. Square = all of that kind.';

  @override
  String get connectChainPrototype => 'CHAIN X2 · +150';

  @override
  String get connectBoardRefreshed => 'Board refreshed.';

  @override
  String get connectLoopHint => 'Tip: make a square, the whole kind goes.';

  @override
  String get connectGroupHint => 'Tip: link this group.';

  @override
  String get connectLoopReady => 'SQUARE · release, clear them all';

  @override
  String get connectSquareClear => 'SQUARE CLEAR';

  @override
  String get connectLinesOut => 'Out of line chances.';

  @override
  String get connectChainExtenderHint => 'Chain Extender active · +3 line chances!';

  @override
  String get connectChainExtenderMilestone => 'CHAIN EXTENDER · +3 LINES!';

  @override
  String get connectMagnetHint => 'Magnet / Bomb Ring built a square chain!';

  @override
  String get connectMagnetMilestone => 'MAGNET RING · SQUARE READY!';

  @override
  String get connectChainTag => 'CHAIN';

  @override
  String get connectLineStat => 'LINE';

  @override
  String get connectWonTitle => 'LINKED';

  @override
  String get connectLostTitle => 'OUT OF CHANCES';

  @override
  String get powerChainPlus => 'CHAIN +';

  @override
  String connectSelectedOne(int minLen) => 'Selected 1 · at least $minLen';

  @override
  String connectSelectedCount(int count) => 'Selected $count';

  @override
  String connectLongChain(int len) => 'Long chain! $len';

  @override
  String connectMinLength(int minLen) => 'Link at least $minLen bugs.';

  @override
  String connectSquareHint(int streak, int gained) => 'Square! x$streak · +$gained';

  @override
  String connectBonusDrop(int points) => 'Bonus drop +$points';

  @override
  String connectSquareChain(int gained) => 'SQUARE · +$gained';

  @override
  String connectChainText(int streak, int gained) => 'CHAIN X$streak · +$gained';

  @override
  String connectLoseHint(int target, int lines, int streak) => 'Target $target · $lines lines · streak x$streak';

  @override
  String connectStatsLine(int cleared, int loops, int streak, int longest) => 'Cleared $cleared · Squares $loops · Max streak x$streak · Longest $longest';

  @override
  String connectBoltHint(int count) => 'Lightning / Kind Cleanser zapped $count bugs!';

  @override
  String connectBoltMilestone(int gained) => 'LIGHTNING · +$gained POINTS!';

  @override
  String connectTargetLine(int longest) => 'TARGET 1,600 · LONGEST CHAIN $longest';

  // --- W60-2: G3 makarayiz (i18n göç planı) ---
  @override
  String get makaraHintIdle => 'When the note reaches the beat line, tap or swipe the lane.';

  @override
  String get makaraBeatLine => 'TAP ON THE BEAT LINE!';

  @override
  String get makaraReelOut => 'Reel over. Pull again!';

  @override
  String get makaraWrongLane => 'WRONG LANE';

  @override
  String get makaraEarlyTap => 'TAPPED TOO EARLY';

  @override
  String get makaraFreezeHint => 'BEAT FREEZE · notes frozen for 8 sec!';

  @override
  String get makaraFreezeCallout => 'BEAT FREEZE!';

  @override
  String get makaraAutoHint => 'AUTO REEL · 6 sec auto hits!';

  @override
  String get makaraAutoCallout => 'AUTO REEL!';

  @override
  String get makaraX2Hint => 'SCORE X2 · double points for 12 sec!';

  @override
  String get makaraX2Active => 'SCORE X2 ACTIVE!';

  @override
  String get makaraEndedTitle => 'REEL OVER';

  @override
  String get makaraShareLine => 'Makarayız, bro!';

  @override
  String get makaraTaglineCaps => 'MAKARAYIZ, BRO!';

  @override
  String get powerScoreX2 => 'SCORE X2';

  @override
  String makaraMissWindow(String reason, int windowMs) => '$reason — hit window: ±$windowMs ms';

  @override
  String makaraResultMessage(int bestCombo, int hits, int misses) => 'Best combo x$bestCombo · $hits hits · $misses missed';

  @override
  String makaraFillPercent(int pct) => 'REEL $pct% FULL';

  // --- W60-2: G5 osmantus (i18n göç planı) ---
  @override
  String get osmantusHintIdle => 'Tap when the ring turns green!';

  @override
  String get osmantusDikkisChant => 'DIKKIS DIKKIS!';

  @override
  String get osmantusHowToBody1 => 'When the rhythm ring turns green, tap the DUO KEY button! ';

  @override
  String get osmantusHintResume => 'Go on! Tap when the ring turns green.';

  @override
  String get osmantusPressGreen => 'TAP ON GREEN!';

  @override
  String get osmantusMicSaved => 'The mic saved you, no life lost.';

  @override
  String get osmantusDefeatHint => 'Over. Osman & Tuş beat you.';

  @override
  String get osmantusJustInTime => 'Just in time!';

  @override
  String get osmantusEarlyPress => 'PRESSED TOO EARLY';

  @override
  String get osmantusWaitGreen => 'Wait for the ring to turn green.';

  @override
  String get osmantusDikkisBoost => 'DIKKIS 2X POINTS!';

  @override
  String get osmantusDikkisHint => 'DIKKIS active · 12 sec 2X stage points and wide rhythm!';

  @override
  String get osmantusRingActive => 'RING + ACTIVE!';

  @override
  String get osmantusRingHint => 'Ring + active · 12 sec wide timing window!';

  @override
  String get osmantusMicShieldCallout => 'MIC SHIELD!';

  @override
  String get osmantusMicShieldHint => 'Mic shield ready · no life lost on the next miss!';

  @override
  String get osmantusDuoWonTitle => 'THE DUO WON';

  @override
  String get osmantusHowToBody2 => 'Tap on time to build combos and use special stage powers.';

  @override
  String get powerDikkis => 'DIKKIS';

  @override
  String get powerRingPlus => 'RING +';

  @override
  String get osmantusCardSub1 => 'Keyman · pointer';

  @override
  String get osmantusCardSub2 => 'Reel · listener';

  @override
  String get osmantusPressGreenButton => 'TAP ON\nGREEN!';

  @override
  String get osmantusDuoButton => 'DUO KEY';

  @override
  String osmantusComboBroken(String reason) => 'COMBO BROKEN · $reason';

  @override
  String osmantusLateBy(int delta) => 'A bit late (+${delta}ms)';

  @override
  String osmantusWarmupMiss(String reason) => '$reason · warm-up round, no life lost';

  @override
  String goodCombo(int combo) => 'GOOD! X$combo';

  @override
  String osmantusEarlyBy(int delta) => 'A bit early (${-delta}ms)';

  @override
  String osmantusStatsLine(int maxCombo, int streak) => 'Max combo x$maxCombo · Daily streak $streak';

  // --- W60-2: G6 terlik_tap (i18n göç planı) ---
  @override
  String get terlikHintIdle => 'Smash the flying bug with the slipper!';

  @override
  String get terlikBonusComboSlipper => 'COMBO x8 SLIPPER +1';

  @override
  String get terlikTrapPassed => 'TRAP PASSED';

  @override
  String get terlikEscaped => 'ESCAPED';

  @override
  String get terlikTrapReplik => 'CIZZT! Don\'t step on the trap!';

  @override
  String get terlikLuckBurst => 'LUCK BURST';

  @override
  String get terlikBonusSlipper => 'SLIPPER +1';

  // --- W103-2: bonus efekt yazıları (bonus_fx.dart) ---
  @override
  String get effectSlap => 'SLAP!';

  @override
  String get effectCombo => 'COMBO!';

  @override
  String get terlikMissedHit => 'YOU MISSED';

  @override
  String get terlikSteppedTrap => 'STEPPED ON A TRAP';

  @override
  String get terlikDoubleReadyHint => 'DOUBLE SLIPPER READY · NEXT HIT SMASHES TWO BUGS!';

  @override
  String get terlikDoubleCallout => 'DOUBLE SLIPPER!';

  @override
  String get terlikGoldHint => 'GOLDEN SLIPPER ACTIVE · 2X POINTS FOR 20 SEC!';

  @override
  String get terlikGoldCallout => 'GOLDEN SLIPPER 2X!';

  @override
  String get terlikSprayCallout => 'SPRAY CLEAN-UP!';

  @override
  String get powerSprayCaps => 'SPRAY';

  @override
  String get terlikHoleInstruction => 'SMASH WHATEVER POPS OUT OF THE HOLE AT ONCE!';

  @override
  String get terlikOutTitle => 'OUT OF SLIPPERS';

  @override
  String get terlikEmptyHole => 'Empty hole';

  @override
  String get terlikTrapTag => 'TRAP!';

  @override
  String terlikBonusComboSpray(int combo) => 'COMBO X$combo SPRAY +1';

  @override
  String terlikOutOfSlippers(int smashed, int combo, int coins) => 'Out of slippers. Smashed $smashed · max x$combo · +$coins💰';

  @override
  String terlikHitHint(int combo, int gain) => 'HIT · COMBO X$combo · +$gain';

  @override
  String terlikComboBreakLives(String reason, int remaining) => '$reason · COMBO BROKEN · $remaining ESCAPES BEFORE A LIFE IS LOST';

  @override
  String terlikComboBreakLifeLost(String reason, int lives) => '$reason · -1 LIFE · COMBO BROKEN · $lives LIVES LEFT';

  @override
  String terlikStatsLine1(int smashed, int missed, int combo) => 'Smashed $smashed · Escaped $missed · Max combo x$combo\n';

  @override
  String terlikStatsLine2(int coins, int slippers, int sprays) => '+$coins coins · slippers +$slippers · sprays +$sprays';

  @override
  String terlikSprayHint(int cleared) => 'SPRAY APPLIED · $cleared TARGETS CLEARED!';

  @override
  String terlikPauseScore(int score, int smashed) => 'Score $score · Smashed $smashed';

  @override
  String terlikSpeedMultiplier(String rate) => 'SPEED X$rate';

  @override
  String terlikHitsChip(int smashed) => 'HITS $smashed';

  @override
  String terlikMissedChip(int missed) => 'ESCAPED $missed!';

  @override
  String terlikHoleSemantics(int hole) => 'Smash the bug, hole $hole';

  // --- W60-2: ek anahtarlar (günlük ödül serisi + chat rozeti) ---
  @override
  String dailyRewardSubtitleStreak(int streak) => 'Day $streak · 500 coins are waiting for you';

  @override
  String chatBadgeUnreadLabel(String badge) => '$badge unread messages';

  // --- W65-1: G7 scream_roach (i18n göç planı) ---
  @override
  String get screamHintIdle => 'Spam-tap = jump. Get through slipper · spray · pan!';

  @override
  String get screamGatePrototype => 'GATE X7!';

  @override
  String get screamIdleGround => 'You fell asleep on the grass! Jump / spam-tap.';

  @override
  String get screamShieldSaved => 'Shield held.';

  @override
  String get screamMicPermissionSettings => 'Allow microphone permission from Settings for voice control.';

  @override
  String get screamMicDeniedHint => 'Voice permission not granted · you can jump by tapping.';

  @override
  String get screamMegaJumpCallout => 'MEGA JUMP!';

  @override
  String get screamMegaJumpHint => 'Mega jump active · first obstacle grazes by!';

  @override
  String get screamShieldBalloonCallout => 'SHIELD BALLOON!';

  @override
  String get screamShieldBalloonHint => 'Shield balloon active · protects from collision!';

  @override
  String get screamNitroCallout => 'NITRO SCREAM!';

  @override
  String get screamNitroHint => 'Nitro active · 8 sec fast flight and +25 gate bonus!';

  @override
  String get powerJumpCaps => 'JUMP';

  @override
  String get screamMicOffLabel => 'Turn off the microphone';

  @override
  String get screamMicOnLabel => 'Turn on shout-to-jump';

  @override
  String get screamVoicePower => 'VOICE POWER';

  @override
  String get screamGateStat => 'GATE';

  @override
  String get screamCrushedTitle => 'CRUSHED';

  @override
  String get gateTerlikDeath => 'Slipper slap!';

  @override
  String get gateTerlikPass => 'Slipped past the slipper!';

  @override
  String get gateRaidDeath => 'Raid cloud!';

  @override
  String get gateRaidPass => 'You passed the spray!';

  @override
  String get gateTavaDeath => 'Pan smack!';

  @override
  String get gateTavaPass => 'Under the pan!';

  @override
  String get gateTuzakDeath => 'Sticky trap!';

  @override
  String get gateTuzakPass => 'You escaped the trap!';

  @override
  String get gateHamamDeath => 'Bowl to the head!';

  @override
  String get gateHamamPass => 'Passed the hammam bowl!';

  @override
  String get gateVuvuzelaDeath => 'Vuvuzela crushed!';

  @override
  String get gateVuvuzelaPass => 'Congo corridor!';

  @override
  String screamDeathLine(String deathLine, int gates) => '$deathLine Gate $gates';

  @override
  String screamGateStreak(int streak) => 'GATE X$streak!';

  @override
  String screamCrushedHint(int gates, int streak) => 'Crushed! Gate $gates · max spam x$streak';

  @override
  String screamStatsLine(int gates, int streak, int dayStreak) => 'Gate $gates · Max spam x$streak · Streak $dayStreak';

  @override
  String screamNextGate(int gate) => 'NEXT: GATE $gate';

  @override
  String screamShoutingPercent(int percent) => '%$percent · SHOUTING';

  @override
  String screamArcadeHint(String hint) => 'Tap or turn on the mic and shout to jump. $hint';

  @override
  String screamPauseScore(int score, int gates) => 'Score $score · Gate $gates';
  // --- W65-1: G8 stack_drop (i18n göç planı) ---
  @override
  String get stackHintIdle => 'Tap. Dead centre = combo. The edge gets cut.';

  @override
  String get stackPerfectPrototype => 'PERFECT HIT! X3';

  @override
  String get stackMissedFall => 'You missed. The tower fell.';

  @override
  String get stackSliceThin => 'The slice got too thin.';

  @override
  String get stackMagnetHint => 'Magnet Alignment & Freeze (4 sec) active!';

  @override
  String get stackMagnetMilestone => 'MAGNET ALIGNMENT & FREEZE!';

  @override
  String get stackWidenHint => 'Wide Block active · Tower base widened!';

  @override
  String get stackWidenMilestone => 'WIDE BLOCK ACTIVE!';

  @override
  String get stackSlowHint => 'Slowdown active (8 sec)!';

  @override
  String get stackSlowMilestone => 'SLOWDOWN ACTIVE (8 SEC)!';

  @override
  String get stackTowerTag => 'TOWER';

  @override
  String get stackFloorStat => 'FLOOR';

  @override
  String get stackTowerFellTitle => 'TOWER FELL';

  @override
  String stackDirectHit(int combo, int gain) => 'DEAD ON x$combo · +$gain';

  @override
  String stackPerfectHit(int combo) => 'PERFECT HIT! X$combo';

  @override
  String stackNearHint(int gain, int floors) => 'Almost · +$gain · floor $floors';

  @override
  String stackNearCallout(int gain) => 'CLOSE! +$gain';

  @override
  String stackEdgeCutHint(int gain, int floors) => 'Edge cut. +$gain · floor $floors';

  @override
  String stackEdgeCutCallout(int gain) => 'EDGE CUT · +$gain';

  @override
  String stackMilestoneFloors(int m) => '$m FLOORS!';

  @override
  String stackStatsLine(int floors, int perfects, int nears, int combo) => 'Floor $floors · Perfect $perfects · Near $nears · Max combo x$combo';

  @override
  String stackTutorialHint(String hint) => 'First 15 seconds at tutorial pace. $hint';

  @override
  String stackFloorLabel(int floor) => 'FLOOR $floor';
  // --- W65-1: G9 yuva_defense (i18n göç planı) ---
  @override
  String get yuvaHintIdle => 'Stop the bugs closing in on the nest!';

  @override
  String get yuvaShieldSaved => 'SHIELD SAVED THE NEST · BUG REPELLED!';

  @override
  String get yuvaFellHint => 'The nest fell · restart with one tap';

  @override
  String get yuvaDoubleHint => 'DOUBLE SLIPPER ACTIVE · 3 HITS SMASH DOUBLE TARGETS!';

  @override
  String get yuvaGoldHint => 'GOLDEN SLIPPER ACTIVE · 2X POINTS FOR 12 SEC!';

  @override
  String get yuvaShieldIceHint => 'SHIELD & ICE BARRIER ACTIVE · BUGS SLOWED DOWN!';

  @override
  String get yuvaMissHint => 'Miss! Combo reset';

  @override
  String get yuvaTitleNewSemantic => 'NEST DEFENSE, NEW';

  @override
  String get yuvaHowToBody1 => 'Tap the bugs before they reach the nest. ';

  @override
  String get yuvaHowToBody2 => 'Grow your combo with fast hits; three escapes end the game.';

  @override
  String get yuvaFellTitle => 'NEST FELL';

  @override
  String yuvaBugEntered(int lives) => 'A bug entered the middle hole · $lives escapes left';

  @override
  String yuvaWaveHit(int wave, int points, int combo) => 'WAVE $wave · HIT +$points · COMBO x$combo';

  @override
  String yuvaHitHint(int points, int combo) => 'HIT +$points  ·  COMBO x$combo';

  @override
  String yuvaPauseScore(int score, int hits) => 'Score $score · Hits $hits';

  @override
  String yuvaResultScore(int score, int combo) => 'SCORE $score · COMBO x$combo';

  @override
  String yuvaHitsPainter(int hits) => 'HITS $hits';

  @override
  String yuvaMissedPainter(int misses) => 'MISSED $misses!';
  // --- W65-1: G10 grid_2048 (i18n göç planı) ---
  @override
  String get gridSuperCombo => 'SUPER!';

  @override
  String get gridTarget2048 => 'TARGET: 2048 BUG';

  @override
  String get gridHowToTitle => 'HOW TO PLAY 2048 GRID?';

  @override
  String get gridHowToBody1 => 'Slide the board in 4 directions — same-tier bugs merge when they collide, a new bug is born. Reach 2048!\n\n';

  @override
  String get gridHowToBody2 => '• UNDO: Undoes the last move.\n';

  @override
  String get gridHowToBody3 => '• SHUFFLE: Shuffles all the bugs on the board.\n';

  @override
  String get gridHowToBody4 => '• PAIR UP: Instantly merges the two highest matching bugs.';

  @override
  String gridSuperMergeSpeech(String title) => 'LULULU! SUPER MERGE! ($title)';

  @override
  String gridHighestTile(int value) => 'HIGHEST TILE: $value';

  @override
  String gridMovesCount(int count) => 'MOVES $count';

  @override
  String gridPauseStats(int moves, int merges, int streak) => 'Moves $moves · Merges $merges · Streak x$streak';

  // --- W69-1: L10N anahtar dalgası 3 ---

  @override
  String get campaignChapter1 => 'Kitchen Counter';

  @override
  String get campaignChapter2 => 'Diva Mansion';

  @override
  String get campaignChapter3 => 'Pikomotions Stage';

  @override
  String get campaignChapter4 => 'Congo Invasion';

  @override
  String get welcomeStatusReadFail => 'Welcome status could not be read.';

  @override
  String get welcomeSkipFail =>
      'The welcome screen was not skipped. Please try again.';

  @override
  String get continueToHomeAnyway => 'Continue to home anyway';

  @override
  String get bugFamilyTitle => 'BUG FAMILY';

  @override
  String get bugFamilySubtitle =>
      'Two same-tier bugs collide and the next tier is born. The end of the chain: Pink Robe. Tap a bug — hear its sound, see its line.';

  @override
  String get tierRowName1 => 'Baby Funnel';

  @override
  String get tierRowName2 => 'Pot-Wearing Apprentice';

  @override
  String get tierRowName3 => 'Reel Fan';

  @override
  String get tierRowName4 => 'Pajama Dancer';

  @override
  String get tierRowName5 => 'Bathhouse Diva';

  @override
  String get tierRowName6 => 'Bathhouse Can';

  @override
  String get tierRowName7 => 'Kongo Leader';

  @override
  String get tierRowName8 => 'Ailing Sage';

  @override
  String get tierRowName9 => 'National Jersey Bug';

  @override
  String get tierRowName10 => 'Pink Jacket Bug';

  @override
  String get tierRowName11 => 'White Ghost';

  @override
  String get tierRowName12 => 'Gray T-Shirt Bug';

  @override
  String get tierRowName13 => 'Pink Robe Bug';

  @override
  String get tierRowQuote1 => "HOP, I'M HERE!";

  @override
  String get tierRowQuote2 => 'POT ON HEAD, WE ARE READY!';

  @override
  String get tierRowQuote3 => 'MAKARAYIZ, BRO!';

  @override
  String get tierRowQuote4 => 'TO THE DANCE FLOOR!';

  @override
  String get tierRowQuote5 => 'THE DIVA IS HERE!';

  @override
  String get tierRowQuote6 => 'EVERYONE OUT OF THE POOL!';

  @override
  String get tierRowQuote7 => 'THE LEADER HAS SPOKEN!';

  @override
  String get tierRowQuote8 => 'THE SAGE IS TIRED BUT LEGENDARY!';

  @override
  String get tierRowQuote9 => 'GOOOAL, LULULU!';

  @override
  String get tierRowQuote10 => 'MY PINK JACKET IS ON FIRE!';

  @override
  String get tierRowQuote11 => 'BOOOO! SCARED YOU?';

  @override
  String get tierRowQuote12 => 'THE SPORTY BUG IS COMING!';

  @override
  String get tierRowQuote13 => 'ROBE ON, FEELING GREAT!';

  @override
  String get energyEmptyTitle => 'OUT OF ENERGY!';

  @override
  String get energyEmptyBodyStart => 'Your energy ';

  @override
  String get energyEmptyBodyMiddle =>
      ' — you need 1 energy to play.\nNext energy: ';

  @override
  String get energyEmptyBodyEnd => ' · +1 every 5 minutes.';

  @override
  String get rewardedAdsSoonCaps => 'REWARDED ADS COMING SOON';

  @override
  String get shopEnergyPackButton => 'SHOP · ENERGY PACK';

  @override
  String get waitForTimerCaps => 'WAIT FOR THE TIMER';

  @override
  String get splashSkipPlain => 'SKIP';

  @override
  String get splashStartButtonPlain => 'START';

  @override
  String get splashContinueButtonPlain => 'CONTINUE';

  @override
  String get play2048Label => 'Open the Lülülü 2048 game';

  @override
  String get doubleRewardLabel => 'Double reward, coming soon';

  @override
  String get watchAdChestLabel => 'Watch an ad, open a free chest';

  @override
  String get notifyOnLabel => 'Notifications on';

  @override
  String levelTileLabel(int id, int stars, bool locked) =>
      'Level $id, $stars stars${locked ? ' · Locked' : ''}';

  @override
  String chapterTabLabel(int index, int stars) =>
      'Chapter $index, $stars/30 stars';

  @override
  String chestClaimLabel(int stars, String state) => state == 'claimed'
      ? 'Claimed'
      : state == 'locked'
          ? 'Locked'
          : 'Claim reward: $stars-star chest';

  @override
  String channelSelectLabel(String name) => 'Select the $name channel';

  @override
  String sendStickerLabel(String name) => 'Send the $name sticker';

  @override
  String featuredModeLabel(String title, String subtitle) =>
      'Play the $title mode: $subtitle';

  // W75-3: L10N anahtar dalgası 4.
  @override
  String get howToPlaySuffix => '— HOW TO PLAY?';

  @override
  String get connectChainBadge => 'CHAIN';

  @override
  String get stackTowerBadge => 'TOWER';

  // W79-3: L10N anahtar dalgası 5 (online_screen + leaderboard).
  // Online EN karşılıkları i18n-goc-plani.md G11'den (lonca/turnuva
  // EN'i planda yoktu, doğru çeviri yazıldı).
  @override
  String get onlineNotifyRemovedSnack => 'Notification preference removed.';

  @override
  String get comingVerySoonCaps => 'COMING VERY SOON!';

  @override
  String get onlineComingSoonBody =>
      'Battle friends online and meet your guild in the same arena. Online mode is under construction — you\'ll be the first to know when it opens.';

  @override
  String get notifyOnCaps => 'NOTIFICATIONS ON';

  @override
  String get onlineDuelTitle => '1V1 DUEL';

  @override
  String get onlineDuelSubtitle => 'Challenge a friend and battle in the arena';

  @override
  String get onlineGuildWarsTitle => 'GUILD WARS';

  @override
  String get onlineGuildWarsSubtitle =>
      'Team up with your guild and join the weekly wars';

  @override
  String get onlineTournamentsTitle => 'LIVE TOURNAMENTS';

  @override
  String get onlineTournamentsSubtitle =>
      'Collect big rewards in seasonal tournaments';

  @override
  String levelWithValue(int level) => 'Level $level';

  @override
  String youAsName(String name) => 'YOU · $name';
}
