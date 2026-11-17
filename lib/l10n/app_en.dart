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
  String get musicTitle => 'Music';

  @override
  String get musicSubtitle => 'Background music';

  @override
  String get sfxTitle => 'Sound Effects';

  @override
  String get sfxSubtitle => 'Merge and tap sounds';

  @override
  String get vibrationTitle => 'Vibration';

  @override
  String get vibrationSubtitle => 'Gentle vibration on merge';

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
}
