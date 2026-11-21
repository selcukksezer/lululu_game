import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_tr.dart';
import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/screens/online_screen.dart';
import 'package:lululu_game/screens/tasks_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/daily_challenge_service.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/online_notify_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

// FAZ 2 Dalga 3H: K2-UI (günlük challenge kartı + talep), K3-giriş
// (kampanya girişi), K17-hub (davet girişi), B7/K19 (kalıcı
// haberdar-et, tek kaynak), S13 (hub kart sesleri — davranış
// değişimi yok, ses çağrıları grep ile denetlenir).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => null,
      );
    }
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ProgressManager.instance.load();
    ProgressManager.instance.coins = 1000;
    ProgressManager.instance.modeHighScores.clear();
    await EnergyService.instance.load();
    await DailyChallengeService.instance.load();
    await OnlineNotifyService.instance.load();
  });

  Future<void> pumpTasks(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapWithL10n(
        const Scaffold(body: TasksScreen(embedded: true)),
        theme: buildLululuTheme(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> pumpHub(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithL10n(
        const Scaffold(body: GameSelectorScreen()),
        theme: buildLululuTheme(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Sliver içeriği görünüm dışındayken ağaçta yoktur: bulunana dek
  /// sürükleyerek kaydır (hub_catalog_test deseni), sonra görünür kıl.
  Future<void> scrollToFinder(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 16 && finder.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, -280),
      );
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    // Önce bekleyen snackbar animasyonlarının bitmesine izin ver:
    // ağaç görünür snackbar ile sökülürse binding'de bekleyen kare
    // geri çağrısı kalıyor (zamanlayıcı istisnası). Sonra ağacı sök
    // (hub_catalog_test deseni).
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pumpOnline(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapWithL10n(
        const Scaffold(body: OnlineScreen()),
        theme: buildLululuTheme(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('B7/K19 — OnlineNotifyService kalıcılığı', () {
    test('yaz → yeniden yükle → oku: tercih korunur', () async {
      final notify = OnlineNotifyService.instance;
      await notify.load();
      expect(notify.isSubscribed, isFalse);

      await notify.setSubscribed(true);
      await notify.load();
      expect(notify.isSubscribed, isTrue);

      await notify.setSubscribed(false);
      await notify.load();
      expect(notify.isSubscribed, isFalse);
    });

    test('toggle yeni durumu döner ve kalıcı yazar', () async {
      final notify = OnlineNotifyService.instance;
      await notify.load();
      expect(await notify.toggle(), isTrue);
      await notify.load();
      expect(notify.isSubscribed, isTrue);
      expect(await notify.toggle(), isFalse);
      await notify.load();
      expect(notify.isSubscribed, isFalse);
    });
  });

  group('K2-UI — görev ekranı challenge talebi', () {
    testWidgets('talep edilebilir → talep sonrası kapalı durum + coin ödülü',
        (tester) async {
      final daily = DailyChallengeService.instance;
      daily.completedToday = true;
      final reward = daily.nextClaimRewardCoins;
      final coinsBefore = ProgressManager.instance.coins;
      final l10n = AppLocalizationsTr();

      await pumpTasks(tester);
      final claimFinder = find.byKey(
        const Key('daily_challenge_claim_tasks'),
      );
      await tester.ensureVisible(claimFinder);
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(claimFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(ProgressManager.instance.coins, coinsBefore + reward);
      expect(daily.canClaimToday, isFalse);
      expect(find.byKey(const Key('daily_challenge_claim_tasks')), findsNothing);
      expect(find.text(l10n.claimedWithCheck), findsOneWidget);
      expect(
        find.text(l10n.dailyChallengeClaimedSnack(reward)),
        findsOneWidget,
      );
      await tearDownTree(tester);
    });

    testWidgets('tamamlanmamış challenge talep edilemez (kapı: iki koşul)',
        (tester) async {
      // canClaimToday yalnız lastClaimDay'e bakar: tamamlanmamış
      // günde true döner; UI kapısı completedToday'i de denetler.
      expect(DailyChallengeService.instance.completedToday, isFalse);
      expect(DailyChallengeService.instance.canClaimToday, isTrue);
      final l10n = AppLocalizationsTr();

      await pumpTasks(tester);
      await tester.ensureVisible(find.text(l10n.dailyChallengeTitle));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('daily_challenge_claim_tasks')),
        findsNothing,
      );
      expect(find.text(l10n.dailyChallengeHint), findsOneWidget);
      await tearDownTree(tester);
    });
  });

  group('K2-UI — hub challenge talebi', () {
    testWidgets('talep edilebilir → talep sonrası ALINDI durumu',
        (tester) async {
      final daily = DailyChallengeService.instance;
      daily.completedToday = true;
      final reward = daily.nextClaimRewardCoins;
      final coinsBefore = ProgressManager.instance.coins;
      final l10n = AppLocalizationsTr();

      await pumpHub(tester);
      final claimFinder = find.byKey(const Key('daily_challenge_claim_hub'));
      await scrollToFinder(tester, claimFinder);

      await tester.tap(claimFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(ProgressManager.instance.coins, coinsBefore + reward);
      expect(daily.canClaimToday, isFalse);
      expect(find.byKey(const Key('daily_challenge_claim_hub')), findsOneWidget);
      expect(find.text(l10n.claimedShort), findsOneWidget);
      expect(
        find.text(l10n.dailyChallengeClaimedSnack(reward)),
        findsOneWidget,
      );
      await tearDownTree(tester);
    });
  });

  group('K3-giriş / K17-hub — hub giriş kartları', () {
    testWidgets('kampanya ve davet girişleri görünür', (tester) async {
      final l10n = AppLocalizationsTr();
      await pumpHub(tester);
      await scrollToFinder(tester, find.byKey(const Key('hub_campaign_entry')));
      expect(find.byKey(const Key('hub_campaign_entry')), findsOneWidget);
      expect(find.byKey(const Key('hub_invite_entry')), findsOneWidget);
      expect(find.text(l10n.campaignMapTitle), findsOneWidget);
      expect(find.text(l10n.profileInviteRowTitle), findsOneWidget);
      await tearDownTree(tester);
    });
  });

  group('B7/K19 — online ekranı haberdar-et düğmesi', () {
    testWidgets('düğme tercihi çevirir ve yeniden yüklemede korunur',
        (tester) async {
      final l10n = AppLocalizationsTr();
      await pumpOnline(tester);
      expect(find.text(l10n.notifyMe), findsOneWidget);

      await tester.tap(find.text(l10n.notifyMe));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(OnlineNotifyService.instance.isSubscribed, isTrue);
      expect(find.text(l10n.notifyOnCaps), findsOneWidget);

      await OnlineNotifyService.instance.load();
      expect(OnlineNotifyService.instance.isSubscribed, isTrue);
      await tester.pump();
      expect(find.text(l10n.notifyOnCaps), findsOneWidget);
      await tearDownTree(tester);
    });
  });
}
