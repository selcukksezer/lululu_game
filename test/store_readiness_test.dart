import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/auth_service.dart';
import 'package:lululu_game/services/bug_video_service.dart';
import 'package:lululu_game/services/chat_service.dart';
import 'package:lululu_game/services/cloud_sync_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/iap_service.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Directory projectRoot = _resolveProjectRoot();
  late Directory tempDocsDir;

  const List<MethodChannel> pathProviderChannels = <MethodChannel>[
    MethodChannel('plugins.flutter.io/path_provider'),
    MethodChannel('plugins.flutter.io/path_provider_macos'),
    MethodChannel('plugins.flutter.io/path_provider_foundation'),
  ];

  setUp(() async {
    tempDocsDir = await Directory.systemTemp.createTemp('lululu_store_test_');
    for (final channel in pathProviderChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        return tempDocsDir.path;
      });
    }

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AuthService.instance.load();
    await AuthService.instance.signOut();
    await EnergyService.instance.load();
    await ProgressManager.instance.load();
    await LeaderboardService.instance.load();
    await ChatService.instance.load();
    await BugVideoService.instance.load();
    await CloudSyncService.instance.ensureLoaded();
    await IapService.instance.ensureLoaded();
  });

  tearDown(() async {
    for (final channel in pathProviderChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
    if (tempDocsDir.existsSync()) {
      await tempDocsDir.delete(recursive: true);
    }
  });

  group('1. Core Services Lifecycle, Persistence, Offline/Online & Reset', () {
    test(
      'ProgressManager initializes, persists economy/levels/modes/tasks/settings, and resets cleanly',
      () async {
        final pm = ProgressManager.instance;
        expect(pm.unlockedLevel, 1);
        expect(pm.coins, ProgressManager.defaultCoins);
        expect(pm.unlockedTiers, containsAll(<int>[1, 2, 3, 4, 5, 6, 7, 8]));

        // Level progress + stars + coin grant
        await pm.recordLevelResult(levelId: 1, score: 2450, stars: 3);
        expect(pm.getStarCount(1), 3);
        expect(pm.getHighScore(1), 2450);
        expect(pm.unlockedLevel, 2);
        expect(pm.totalStars, 3);

        // Mode high scores across 11 modes
        final recorded = await pm.recordModeScore('suika', 8900);
        expect(recorded, isTrue);
        expect(pm.getModeHighScore('suika'), 8900);
        expect(pm.total11ModesScore, 8900);

        // Boosters & bundles
        final boughtBooster = await pm.buyBooster('f16', 100);
        expect(boughtBooster, isTrue);
        final f16Before = pm.f16Count;
        final usedBooster = await pm.useBooster('f16');
        expect(usedBooster, isTrue);
        expect(pm.f16Count, f16Before - 1);

        // Tier unlock
        final tierUnlocked = await pm.unlockTier(9);
        expect(tierUnlocked, isTrue);
        expect(pm.isTierUnlocked(9), isTrue);

        // Daily task & gift box
        await pm.recordTaskProgress('play', delta: 3);
        expect(pm.getTaskProgress('play'), 3);
        final taskClaimed = await pm.claimDailyTaskReward(
          'play',
          target: 3,
          coinReward: 150,
          energyReward: 1,
        );
        expect(taskClaimed, isTrue);
        expect(pm.isTaskClaimed('play'), isTrue);

        final gift = await pm.claimDailyGiftBox();
        expect(gift, isNotNull);
        expect(gift!.coins, greaterThanOrEqualTo(500));

        // Settings persistence
        await pm.setSfxEnabled(false);
        await pm.setVibrationEnabled(false);

        // Reload from SharedPreferences to verify persistence
        await pm.load();
        expect(pm.unlockedLevel, 2);
        expect(pm.getStarCount(1), 3);
        expect(pm.getHighScore(1), 2450);
        expect(pm.getModeHighScore('suika'), 8900);
        expect(pm.isTierUnlocked(9), isTrue);
        expect(pm.sfxEnabled, isFalse);
        expect(pm.vibrationEnabled, isFalse);

        // Reset via clean SharedPreferences + reload
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await pm.load();
        expect(pm.unlockedLevel, 1);
        expect(pm.coins, ProgressManager.defaultCoins);
        expect(pm.getStarCount(1), 0);
        expect(pm.getModeHighScore('suika'), 0);
      },
    );

    test(
      'EnergyService initializes, consumes, regenerates/refills, persists, and resets',
      () async {
        final energy = EnergyService.instance;
        expect(energy.isLoaded, isTrue);
        expect(energy.energy, EnergyService.defaultEnergy);

        final consumed = await energy.tryConsume(2);
        expect(consumed, isTrue);
        expect(energy.energy, EnergyService.defaultEnergy - 2);

        energy.addEnergy(5);
        expect(energy.energy, EnergyService.defaultEnergy + 3);

        await energy.refillFull();
        expect(energy.energy, EnergyService.maxEnergy);
        expect(energy.isFull, isTrue);
        expect(energy.formattedTimeToNext, 'DOLU');

        // Persist & reload
        await energy.load();
        expect(energy.energy, EnergyService.maxEnergy);

        // Reset
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await energy.load();
        expect(energy.energy, EnergyService.defaultEnergy);
      },
    );

    test(
      'AuthService handles guest, registration, login, profile updates, persistence, and signOut reset',
      () async {
        final auth = AuthService.instance;
        expect(auth.isSignedIn, isFalse);
        expect(auth.isGuest, isTrue);

        // Guest session
        final guest = await auth.signInAsGuest(nickname: 'Misafir Böcek');
        expect(guest.isGuest, isTrue);
        expect(auth.isSignedIn, isTrue);
        expect(auth.displayName, 'Misafir Böcek');

        await auth.signOut();
        expect(auth.isSignedIn, isFalse);

        // Register & update profile
        final user = await auth.registerWithEmail(
          email: 'kongo@lululu.app',
          password: 'password123',
          username: 'kongo_lider',
          displayName: 'Kongo Lideri',
        );
        expect(user.username, 'kongo_lider');
        expect(auth.isSignedIn, isTrue);
        expect(auth.isGuest, isFalse);

        await auth.updateDisplayName('Kongo Kralı');
        expect(auth.displayName, 'Kongo Kralı');

        // Reload from SharedPreferences to verify session persistence
        await auth.load();
        expect(auth.isSignedIn, isTrue);
        expect(auth.displayName, 'Kongo Kralı');
        expect(auth.username, 'kongo_lider');

        // Sign out & log back in
        await auth.signOut();
        expect(auth.isSignedIn, isFalse);

        final relogin = await auth.signInWithEmail(
          email: 'kongo@lululu.app',
          password: 'password123',
        );
        expect(relogin.id, user.id);
        expect(relogin.displayName, 'Kongo Kralı');

        // Reset
        await auth.signOut();
        expect(auth.isSignedIn, isFalse);
      },
    );

    test(
      'LeaderboardService & CloudSyncService record 11-mode scores, handle offline/online transitions, and reset',
      () async {
        final auth = AuthService.instance;
        final board = LeaderboardService.instance;
        final sync = CloudSyncService.instance;

        // Offline guest state
        await sync.enableOnlineWhenSignedIn();
        expect(sync.onlineEnabled, isFalse);

        // Sign in with registered account -> transitions to onlineEnabled = true
        await auth.register(username: 'arena_sampiyon', password: 'pass1234');
        await board.onAuthChanged();
        await sync.enableOnlineWhenSignedIn();
        expect(sync.onlineEnabled, isTrue);

        // Submit scores across multiple modes
        expect(LeaderboardService.allModeIds.length, 11);
        final okSuika = await board.submitScore(
          LeaderboardService.modeSuika,
          14200,
        );
        final ok2048 = await board.submitScore(
          LeaderboardService.mode2048,
          9600,
        );
        expect(okSuika, isTrue);
        expect(ok2048, isTrue);
        expect(board.getBest(LeaderboardService.modeSuika), 14200);
        expect(board.getBest(LeaderboardService.mode2048), 9600);
        expect(board.total11ModesScore, 14200 + 9600);

        // Ladders & categories
        board.setCategory(LeaderboardCategory.global);
        expect(board.activeCategory, LeaderboardCategory.global);
        expect(board.getTurkeyTop100(limit: 20), isNotEmpty);
        expect(board.getGlobalTop(limit: 20), isNotEmpty);
        expect(board.get11ModeTotalTop(limit: 20), isNotEmpty);

        // CloudSync queue & flush in offline/test environment.
        // Offline flush yazamaz: sözleşme gereği kuyruk korunur
        // (CloudSyncFlushResult dokümanı: "Kuyruk, reddedilişte korunur").
        // Kayıt sırasındaki göç + skor gönderimleri de kuyruğa paket
        // eklediğinden, beklenen: 0 yazım + kuyruk boş değil.
        final pendingBefore = sync.pending.length;
        await sync.enqueueProgressPush();
        await sync.enqueueLeaderboardPush();
        final flushed = await sync.flushPending();
        expect(flushed, 0);
        expect(sync.pending.length, greaterThanOrEqualTo(pendingBefore + 2));

        // Reload & verify persistence
        await board.load();
        expect(board.getBest(LeaderboardService.modeSuika), 14200);

        // Reset
        await auth.signOut();
        await sync.enableOnlineWhenSignedIn();
        expect(sync.onlineEnabled, isFalse);
        // Reset: prefs silinir; PM de boş prefs'ten yeniden yüklenir
        // (gerçek sıfırlama akışı SettingsScreen.resetAll ile aynı).
        // K2 düzeltmesinden beri tahta yüklemesi PM skorlarını
        // temizlemez; getBest tahtada kayıt yoksa PM'ye düştüğünden
        // yalnız tahtayı yeniden yüklemek 0 vermez.
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await ProgressManager.instance.load();
        await board.load();
        expect(board.getBest(LeaderboardService.modeSuika), 0);
      },
    );

    test(
      'ChatService loads channels, filters profanity/spam, sends text/stickers/VS challenges, persists, and resets',
      () async {
        final chat = ChatService.instance;
        await chat.load();
        // Gönderim önkoşulu: sohbet şart onayı.
        await chat.acceptChatTerms();

        // Default feed available when channel has no user messages yet
        expect(chat.messagesForChannel(ChatChannel.lobby), isNotEmpty);
        expect(chat.messagesForChannel(ChatChannel.clan), isNotEmpty);
        expect(chat.messagesForChannel(ChatChannel.vsChallenge), isNotEmpty);

        // Profanity & spam sanitization
        final sanitized = ChatService.sanitizeText('Selam   amk   harikaaaaa!!!!');
        expect(sanitized.contains('amk'), isFalse);
        expect(sanitized.contains('***'), isTrue);
        expect(sanitized.contains('aaaaa'), isFalse);

        // Send text message
        final textMsg = await chat.sendText(
          'Yeni Suika rekorum 15.000!',
          channel: ChatChannel.lobby,
        );
        expect(textMsg.body, 'Yeni Suika rekorum 15.000!');
        expect(textMsg.channel, ChatChannel.lobby);

        // Send bug sticker (Tier 1..13)
        final stickerMsg = await chat.sendBugSticker(
          5,
          channel: ChatChannel.clan,
        );
        expect(stickerMsg.isSticker, isTrue);
        expect(stickerMsg.stickerTier, 5);
        expect(stickerMsg.channel, ChatChannel.clan);

        // Send VS challenge
        final vsMsg = await chat.sendVsChallenge(
          modeId: 'suika',
          targetScore: 15000,
          modeTitle: 'Suika Arena',
        );
        expect(vsMsg.isChallenge, isTrue);
        expect(vsMsg.challengeTargetScore, 15000);
        expect(vsMsg.channel, ChatChannel.vsChallenge);

        // Channel switch
        chat.switchChannel(ChatChannel.clan);
        expect(chat.currentChannel, ChatChannel.clan);

        // Reload & verify persistence
        await chat.load();
        expect(
          chat
              .messagesForChannel(ChatChannel.lobby, includeDefaultFeed: false)
              .any((m) => m.id == textMsg.id),
          isTrue,
        );

        // Reset
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await chat.load();
        expect(
          chat.messagesForChannel(ChatChannel.lobby, includeDefaultFeed: false),
          isEmpty,
        );
      },
    );

    test(
      'IapService initializes catalog, processes sandbox purchases, coin purchases, rewarded ads unavailable without SDK, and restore',
      () async {
        final iap = IapService.instance;
        final pm = ProgressManager.instance;
        await iap.ensureLoaded();

        expect(IapService.packs.length, 3);
        expect(IapService.storeCatalog.length, greaterThanOrEqualTo(7));
        expect(IapService.productIds, isNotEmpty);

        // Sandbox purchase grant
        final coinsBefore = pm.coins;
        final boughtPack = await iap.purchase('coins_small');
        expect(boughtPack, isTrue);
        expect(pm.coins, coinsBefore + 500);

        // Buy catalog item with coins
        final f16Before = pm.f16Count;
        final boughtWithCoins = await iap.buyWithCoins('f16_x3');
        expect(boughtWithCoins, isTrue);
        expect(pm.f16Count, f16Before + 3);

        // Insufficient coins rejected gracefully
        pm.coins = 10;
        final failedBuy = await iap.buyWithCoins('mega_starter_pack');
        expect(failedBuy, isFalse);

        // Rewarded ad claim: reklam SDK'sı kurulu değil
        // (IapService.rewardedAdsAvailable == false), bu yüzden
        // claimWithRewardedAd ödül vermez ve false döner.
        final terlikBefore = pm.terlikCount;
        expect(IapService.rewardedAdsAvailable, isFalse);
        final adClaimed = await iap.claimWithRewardedAd('terlik_x5');
        expect(adClaimed, isFalse);
        expect(pm.terlikCount, terlikBefore);

        // Restore purchases safe in offline/sandbox mode
        await iap.restorePurchases();
        expect(iap.status, isNotEmpty);
      },
    );

    test(
      'AudioManager initializes safely in test environment, toggles channels, plays tier voices 1..13, and disposes',
      () async {
        final audio = AudioManager();
        audio.initialize();

        audio.setSfxEnabled(true);
        audio.setVoiceEnabled(true);
        audio.setVibrationEnabled(true);
        expect(audio.sfxEnabled, isTrue);
        expect(audio.voiceEnabled, isTrue);
        expect(audio.vibrationEnabled, isTrue);

        for (int tier = 1; tier <= 13; tier++) {
          await audio.playTierVoice(tier);
        }
        await audio.playMerge(tier: InsectTier.diva, comboCount: 3);
        await audio.playSlipperSmash(tier: InsectTier.cone, comboCount: 3);
        await audio.playOsmantusBeat(isPersonB: true, perfect: true);
        await audio.playMakaraSpin(bug: InsectTier.fan, comboCount: 2);

        var completed = false;
        final played = await audio.playScreamRoach(
          bug: InsectTier.kongo,
          onComplete: () => completed = true,
        );
        expect(played, isTrue);
        expect(completed, isTrue);

        audio.toggleMute();
        expect(audio.isMuted, isTrue);
        audio.toggleMute();
        expect(audio.isMuted, isFalse);

        await audio.stopAll();
        audio.dispose();
      },
    );

    test(
      'BugVideoService initializes, imports video for signed-in user, toggles visibility, persists, and resets',
      () async {
        final videos = BugVideoService.instance;
        final auth = AuthService.instance;
        await videos.load();
        expect(videos.all, isEmpty);

        // Unsigned upload rejected
        final sampleVideo = File('${tempDocsDir.path}/sample_source.mp4')
          ..writeAsBytesSync(<int>[0, 1, 2, 3, 4, 5, 6, 7]);
        expect(
          () => videos.addFromPicker(
            sourcePath: sampleVideo.path,
            title: 'Test Video',
            isPublic: true,
          ),
          throwsA(isA<StateError>()),
        );

        // Sign in and upload
        await auth.register(username: 'video_ustasi', password: 'pass1234');
        final post = await videos.addFromPicker(
          sourcePath: sampleVideo.path,
          title: 'Diva Mutfak Şovu',
          isPublic: true,
        );
        expect(post.title, 'Diva Mutfak Şovu');
        expect(File(post.filePath).existsSync(), isTrue);
        expect(videos.all.length, 1);
        expect(videos.publicFeed.length, 1);
        expect(videos.mine().length, 1);

        // Toggle public visibility
        await videos.setPublic(post.id, false);
        expect(videos.publicFeed, isEmpty);

        // Reload & verify persistence
        await videos.load();
        expect(videos.all.length, 1);
        expect(videos.all.first.title, 'Diva Mutfak Şovu');

        // Reset
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await videos.load();
        expect(videos.all, isEmpty);
      },
    );
  });

  group('2. 80 CampaignLevels & 13 InsectTiers Certification', () {
    test('all 80 CampaignLevels across 4 chapters have valid objectives, star thresholds, and bounds', () {
      expect(CampaignDatabase.totalLevels, 80);
      expect(CampaignDatabase.chapterCount, 4);
      expect(CampaignDatabase.levelsPerChapter, 20);
      expect(CampaignDatabase.allLevels.length, 80);

      for (int ch = 1; ch <= CampaignDatabase.chapterCount; ch++) {
        final chLevels = CampaignDatabase.getLevelsForChapter(ch);
        expect(chLevels.length, 20, reason: 'Chapter $ch must have 20 levels');
      }

      for (int i = 0; i < CampaignDatabase.allLevels.length; i++) {
        final level = CampaignDatabase.allLevels[i];
        expect(level.id, i + 1);
        expect(level.chapter, inInclusiveRange(1, 4));
        expect(level.chapterName, isNotEmpty);
        expect(level.title, isNotEmpty);
        expect(level.objectiveDescription, isNotEmpty);
        expect(level.allowedMoves, greaterThan(0));
        expect(level.targetScore, greaterThan(0));
        expect(level.star1Score, greaterThan(0));
        expect(level.star2Score, greaterThanOrEqualTo(level.star1Score));
        expect(level.star3Score, greaterThanOrEqualTo(level.star2Score));
        expect(level.backgroundPath, startsWith('assets/'));

        if (level.objectiveType == ObjectiveType.mergeTargetTier) {
          expect(level.targetTier, isNotNull);
        }
        if (level.objectiveType == ObjectiveType.survivalTimer) {
          expect(level.isSurvival, isTrue);
          expect(level.timeLimitSeconds, greaterThan(0));
        }
      }
    });

    test('all 13 InsectTier values have valid progression, physics attributes, voices, and assets', () {
      const tiers = InsectTier.values;
      expect(tiers.length, 13);

      for (int i = 0; i < tiers.length; i++) {
        final t = tiers[i];
        expect(t.tier, i + 1);
        expect(t.name, isNotEmpty);
        expect(t.title, isNotEmpty);
        expect(t.viralReplik, isNotEmpty);
        expect(t.soundFile, endsWith('.mp3'));
        expect(t.assetPath, startsWith('assets/'));
        expect(t.radius, greaterThan(0));
        expect(t.mass, greaterThan(0));
        expect(t.scoreValue, greaterThan(0));

        if (i > 0) {
          final prev = tiers[i - 1];
          expect(
            t.radius,
            greaterThan(prev.radius),
            reason: 'Tier ${t.tier} radius must exceed tier ${prev.tier}',
          );
          expect(
            t.mass,
            greaterThan(prev.mass),
            reason: 'Tier ${t.tier} mass must exceed tier ${prev.tier}',
          );
          expect(
            t.scoreValue,
            greaterThan(prev.scoreValue),
            reason: 'Tier ${t.tier} scoreValue must exceed tier ${prev.tier}',
          );
        }

        if (i < tiers.length - 1) {
          expect(t.nextTier, tiers[i + 1]);
        } else {
          expect(t.nextTier, isNull);
        }
      }
    });
  });

  group('3. App Store (Info.plist) & Google Play (AndroidManifest.xml) Store-Readiness Audit', () {
    test('ios/Runner/Info.plist is well-formed XML/plist and contains required App Store keys and permissions', () {
      final plistFile = File('${projectRoot.path}/ios/Runner/Info.plist');
      expect(plistFile.existsSync(), isTrue);
      final content = plistFile.readAsStringSync();
      expect(content, isNotEmpty);

      // Structural XML / PropertyList checks
      expect(content, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(content, contains('<!DOCTYPE plist'));
      expect(content, contains('<plist version="1.0">'));
      expect(content, contains('</plist>'));

      final openDicts = '<dict>'.allMatches(content).length;
      final closeDicts = '</dict>'.allMatches(content).length;
      expect(
        openDicts,
        equals(closeDicts),
        reason: 'Info.plist <dict> and </dict> tags must be balanced',
      );

      final openKeys = '<key>'.allMatches(content).length;
      final closeKeys = '</key>'.allMatches(content).length;
      expect(openKeys, equals(closeKeys));
      expect(openKeys, greaterThanOrEqualTo(18));

      // Required App Store bundle, versioning, orientation & privacy keys
      const requiredPlistKeys = <String>[
        'CFBundleDisplayName',
        'CFBundleExecutable',
        'CFBundleIdentifier',
        'CFBundleName',
        'CFBundlePackageType',
        'CFBundleShortVersionString',
        'CFBundleVersion',
        'LSRequiresIPhoneOS',
        'UILaunchStoryboardName',
        'UISupportedInterfaceOrientations',
        'ITSAppUsesNonExemptEncryption',
        'NSPhotoLibraryUsageDescription',
        'NSPhotoLibraryAddUsageDescription',
        'NSCameraUsageDescription',
        'NSMicrophoneUsageDescription',
      ];

      for (final key in requiredPlistKeys) {
        expect(
          content,
          contains('<key>$key</key>'),
          reason: 'Info.plist missing required App Store key: $key',
        );
      }

      // Verify non-empty privacy usage descriptions after each NS*UsageDescription key
      for (final privacyKey in const <String>[
        'NSPhotoLibraryUsageDescription',
        'NSPhotoLibraryAddUsageDescription',
        'NSCameraUsageDescription',
        'NSMicrophoneUsageDescription',
      ]) {
        final match = RegExp(
          '<key>$privacyKey</key>\\s*<string>([^<]+)</string>',
        ).firstMatch(content);
        expect(
          match,
          isNotNull,
          reason: '$privacyKey must have a non-empty <string> description',
        );
        expect(match!.group(1)!.trim().length, greaterThan(10));
      }
    });

    test('android/app/src/main/AndroidManifest.xml is valid XML and contains required Play Store permissions & metadata', () {
      final manifestFile = File(
        '${projectRoot.path}/android/app/src/main/AndroidManifest.xml',
      );
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();
      expect(content, isNotEmpty);

      // Structural XML checks
      expect(
        content,
        contains(
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        ),
      );
      expect(content, contains('</manifest>'));
      expect(content, contains('<application'));
      expect(content, contains('</application>'));
      expect(content, contains('<activity'));
      expect(content, contains('</activity>'));

      // Required Play Store permissions. READ_MEDIA_VIDEO ve
      // READ_EXTERNAL_STORAGE bilinçli olarak YOK: kullanılmayan izinler
      // Play Store uyum düzeltmesinde (f761283) kaldırıldı.
      const requiredPermissions = <String>[
        'android.permission.INTERNET',
        'android.permission.ACCESS_NETWORK_STATE',
        'android.permission.RECORD_AUDIO',
        'android.permission.VIBRATE',
      ];
      for (final perm in requiredPermissions) {
        expect(
          content,
          contains(perm),
          reason: 'AndroidManifest.xml missing permission: $perm',
        );
      }
      const removedPermissions = <String>[
        'android.permission.READ_MEDIA_VIDEO',
        'android.permission.READ_EXTERNAL_STORAGE',
      ];
      for (final perm in removedPermissions) {
        expect(
          content,
          isNot(contains(perm)),
          reason: 'AndroidManifest.xml must not re-add unused permission: $perm',
        );
      }

      // Required Activity / Play Store Android 12+ exported attribute & Flutter v2 embedding
      // S3#45: marka adı tek biçim 'LÜLÜLÜ' — eski Türkçe uzun ad kilitlenmez.
      expect(content, contains('android:label="LÜLÜLÜ"'));
      expect(
        content,
        isNot(contains('Böcek Birleştirme Maniası')),
        reason: 'AndroidManifest.xml must not lock the old Turkish long name',
      );
      expect(content, contains('android:exported="true"'));
      expect(content, contains('android.intent.action.MAIN'));
      expect(content, contains('android.intent.category.LAUNCHER'));
      expect(content, contains('android:name="flutterEmbedding"'));
      expect(content, contains('android:value="2"'));
    });

    test('pubspec.yaml defines valid semantic store version and build number', () {
      final pubspecFile = File('${projectRoot.path}/pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);
      final pubspec = pubspecFile.readAsStringSync();
      final versionMatch = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(
        versionMatch,
        isNotNull,
        reason: 'pubspec.yaml must declare version: X.Y.Z+BUILD',
      );
    });

    test('S3#44: launcher icons exist and are non-empty on Android, iOS and web', () {
      // Android: all 5 density buckets must ship a launcher icon.
      for (final density in const <String>[
        'mdpi',
        'hdpi',
        'xhdpi',
        'xxhdpi',
        'xxxhdpi',
      ]) {
        final icon = File(
          '${projectRoot.path}/android/app/src/main/res/mipmap-$density/ic_launcher.png',
        );
        expect(
          icon.existsSync(),
          isTrue,
          reason: 'missing Android launcher icon: mipmap-$density',
        );
        expect(
          icon.lengthSync(),
          greaterThan(0),
          reason: 'empty Android launcher icon: mipmap-$density',
        );
      }

      // iOS: 1024px App Store icon must exist and be non-empty.
      final iosIcon = File(
        '${projectRoot.path}/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      );
      expect(iosIcon.existsSync(), isTrue);
      expect(iosIcon.lengthSync(), greaterThan(0));

      // Web: 512px PWA icon must exist and be non-empty.
      final webIcon = File('${projectRoot.path}/web/icons/Icon-512.png');
      expect(webIcon.existsSync(), isTrue);
      expect(webIcon.lengthSync(), greaterThan(0));

      // S3#44 scope note: no screenshot check — no store screenshots are
      // committed yet, so asserting them would only paint the suite red.
    });

    test('S3#44: privacy policy screen exists and is reachable from Settings', () {
      // No named route exists for privacy (LululuRoutes carries no privacy
      // entry); navigation is a MaterialPageRoute pushed from Settings, so
      // the check asserts the screen plus its Settings wiring, not a route.
      final privacyFile = File(
        '${projectRoot.path}/lib/screens/privacy_policy_screen.dart',
      );
      expect(privacyFile.existsSync(), isTrue);
      final privacyContent = privacyFile.readAsStringSync();
      expect(privacyContent, contains('class PrivacyPolicyScreen'));
      // Başlık + giriş metni l10n anahtarıyla çizilir (8f9e5ed gizlilik
      // metni hizalaması); sabit 'GİZLİLİK POLİTİKASI' yazımı yok.
      expect(privacyContent, contains('privacyTitle'));
      expect(privacyContent, contains('privacyIntro'));

      final settingsFile = File(
        '${projectRoot.path}/lib/screens/settings_screen.dart',
      );
      expect(settingsFile.existsSync(), isTrue);
      final settingsContent = settingsFile.readAsStringSync();
      expect(settingsContent, contains('PrivacyPolicyScreen'));
      expect(settingsContent, contains('_openPrivacyPolicy'));
    });

    test('S3#44: pubspec.yaml description is real copy, not the Flutter template', () {
      // Depends on W10-1 replacing the template description; red until that
      // lands, by design — this test exists to reject the template text.
      final pubspecFile = File('${projectRoot.path}/pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);
      final pubspec = pubspecFile.readAsStringSync();
      final descriptionMatch = RegExp(
        r'^description:\s*(.+?)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(
        descriptionMatch,
        isNotNull,
        reason: 'pubspec.yaml must declare a description',
      );
      var description = descriptionMatch!.group(1)!.trim();
      if ((description.startsWith('"') && description.endsWith('"')) ||
          (description.startsWith("'") && description.endsWith("'"))) {
        description = description.substring(1, description.length - 1).trim();
      }
      expect(description, isNotEmpty);
      expect(
        description.toLowerCase(),
        isNot(contains('a new flutter project')),
        reason: 'pubspec.yaml description must not be the Flutter template text',
      );
      expect(
        description.length,
        greaterThanOrEqualTo(10),
        reason: 'pubspec.yaml description must be real store-facing copy',
      );
    });

    test('S3#45: brand name is exactly LÜLÜLÜ in manifest, plist, web title and MaterialApp title', () {
      final manifest = File(
        '${projectRoot.path}/android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:label="LÜLÜLÜ"'));

      final plist = File(
        '${projectRoot.path}/ios/Runner/Info.plist',
      ).readAsStringSync();
      expect(plist, contains('<key>CFBundleDisplayName</key>'));
      expect(
        plist,
        contains('<string>LÜLÜLÜ</string>'),
        reason: 'CFBundleDisplayName/CFBundleName must be exactly LÜLÜLÜ',
      );

      final webIndex = File(
        '${projectRoot.path}/web/index.html',
      ).readAsStringSync();
      expect(webIndex, contains('<title>LÜLÜLÜ</title>'));

      final mainDart = File(
        '${projectRoot.path}/lib/main.dart',
      ).readAsStringSync();
      expect(mainDart, contains("title: 'LÜLÜLÜ'"));
      expect(
        mainDart,
        isNot(contains('Lülülü Hamamböceği')),
        reason: 'MaterialApp title must not use the old Turkish long name',
      );
    });
  });
}

Directory _resolveProjectRoot() {
  final cwd = Directory.current;
  if (File('${cwd.path}/pubspec.yaml').existsSync()) {
    return cwd;
  }
  final sub = Directory('${cwd.path}/lululu_game');
  if (File('${sub.path}/pubspec.yaml').existsSync()) {
    return sub;
  }
  return Directory('/Users/selcuk/Documents/lululu/lululu_game');
}
