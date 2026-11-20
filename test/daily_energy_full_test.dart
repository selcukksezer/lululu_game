// Dalga 16 ek bulgu — GET ENERGY · +5, enerji 30/30 FULL iken.
//
// Canlı retest (240d917): enerji FULL iken butona iki kez tıklanınca
// HİÇBİR mesaj çıkmadı, buton aktif görünmeye devam etti. Satır satır
// okuma + repro şunları gösterdi:
//  * İşleyici (`_claimDailyEnergy`) her dalda snackbar gösteriyordu
//    (harness'ta doğrulandı) — ama FULL dalı YOKTU: FULL'da talep
//    günlük hakkı tüketip +0'a "+5 eklendi" diyordu (yanlış mesaj +
//    boşa giden hak).
//  * Butonun talep-edilmiş/devre-dışı görünümü hiç yoktu (onTap hep
//    bağlı, hep yeşil) — hediye kutusu düğmesinin aksine.
// Düzeltme (yalnız game_selector_screen.dart, UI tarafı):
//  * FULL'da talep yapılmaz, "Enerji 30/30 doldu!" bildirilir, hak kalır.
//  * Düğme kalıcı kaynaktan talep-edilmiş görünür (ALINDI + soluk +
//    dokunmaz), hediye kutusu deseniyle aynı.
// Servis notu (backend ekibine, DOKUNULMADI): `canClaimDailyFreeEnergy`
// (progress_manager.dart:503) doluluğa bakmaz; `claimDailyFreeEnergy`
// (progress_manager.dart:519) +0 eklenmesine rağmen true döner.
// Bu dosya hub düzeyindeki kilit davranışı sınar.
//
// Kurulum deseni test/daily_reward_exploit_test.dart ile aynıdır
// (setMockInitialValues + load(), MaterialApp + Scaffold + hub).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_localizations.dart';
import 'package:lululu_game/l10n/app_tr.dart';
import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

String _todayKey() => _dayKey(DateTime.now());

final _tr = AppLocalizationsTr();

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
  });

  Future<void> loadSeeded({
    int energy = 10,
    String? lastFreeEnergyDay,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'lululu.energy': energy,
      'lululu.energy_last_refill': nowMs,
      'lululu.energy_last_seen': nowMs,
      if (lastFreeEnergyDay != null)
        'lululu_daily_free_energy_day': lastFreeEnergyDay,
      if (lastFreeEnergyDay != null) 'lululu_daily_free_energy_claims': 1,
    });
    await EnergyService.instance.load();
    await ProgressManager.instance.load();
  }

  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // 6D deseni (stack_play_test.dart): tembel GoogleFonts yüklemeleri
    // `fontsChange` bildirimiyle transient frame callback bırakır;
    // sökme sonrası denetime takılmaması için pump'la tüketilir.
    addTearDown(() async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      for (var i = 0; i < 3 && binding.transientCallbackCount > 0; i++) {
        await binding.pump();
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLululuTheme(),
        locale: const Locale('tr'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback:
            AppLocalizations.localeResolutionCallback,
        home: const Scaffold(body: GameSelectorScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> settleClaim(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  group('GET ENERGY FULL dalı (Dalga 16 ek bulgu)', () {
    testWidgets('kontrol: enerji dolu değilken talep +5 verir ve snackbar çıkar',
        (tester) async {
      await loadSeeded(energy: 10);
      final pm = ProgressManager.instance;
      expect(pm.canClaimDailyFreeEnergy, isTrue);
      expect(EnergyService.instance.energy, 10);

      await pumpHub(tester);
      expect(find.text(_tr.claimEnergy5), findsOneWidget);

      await tester.tap(find.text(_tr.claimEnergy5));
      await settleClaim(tester);

      expect(EnergyService.instance.energy, 15);
      expect(pm.canClaimDailyFreeEnergy, isFalse);
      expect(find.text(_tr.dailyEnergyClaimedSnack), findsOneWidget);
      // Talep sonrası düğme talep-edilmiş duruma döner (hediye kutusu
      // deseni): 'ENERJİ AL · +5' yok, 'ALINDI' var.
      expect(find.text(_tr.claimEnergy5), findsNothing);
      expect(find.text(_tr.claimedShort), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets('FULL + hak duruyorken: tap DOLU bildirir, hak tükenmez',
        (tester) async {
      await loadSeeded(energy: 30);
      final pm = ProgressManager.instance;
      expect(pm.canClaimDailyFreeEnergy, isTrue);
      expect(EnergyService.instance.energy, 30);

      await pumpHub(tester);
      expect(find.text(_tr.claimEnergy5), findsOneWidget);

      await tester.tap(find.text(_tr.claimEnergy5));
      await settleClaim(tester);

      // FULL'da eklenen 0'dır: doğru bildirim "dolu"dur, "+5 eklendi"
      // DEĞİL; günlük hak tüketilmez (enerji düşünce kullanılmak
      // üzere kalır), düğme talep-edilebilir görünür.
      expect(EnergyService.instance.energy, 30);
      expect(find.text(_tr.shopEnergyFullToast), findsOneWidget);
      expect(find.text(_tr.dailyEnergyClaimedSnack), findsNothing);
      expect(pm.canClaimDailyFreeEnergy, isTrue);
      expect(find.text(_tr.claimEnergy5), findsOneWidget);

      // İkinci tap da aynı DOLU bildirimini verir (canlı retestte
      // iki tap da sessiz kalmıştı).
      await tester.tap(find.text(_tr.claimEnergy5));
      await settleClaim(tester);
      expect(find.text(_tr.shopEnergyFullToast), findsOneWidget);
      expect(pm.canClaimDailyFreeEnergy, isTrue);
      expect(EnergyService.instance.energy, 30);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets('FULL + hak zaten kullanılmışken: düğme ALINDI görünür',
        (tester) async {
      await loadSeeded(energy: 30, lastFreeEnergyDay: _todayKey());
      final pm = ProgressManager.instance;
      expect(pm.canClaimDailyFreeEnergy, isFalse);
      expect(EnergyService.instance.energy, 30);

      await pumpHub(tester);
      // Hak kullanılmış: düğme devre dışı (ALINDI) görünür, canlı
      // görünmez — dokunma hiçbir şey yapmaz (hediye kutusu deseni).
      expect(find.text(_tr.claimEnergy5), findsNothing);
      expect(find.text(_tr.claimedShort), findsOneWidget);

      await tester.tap(
        find.text(_tr.claimedShort),
        warnIfMissed: false,
      );
      await settleClaim(tester);

      expect(EnergyService.instance.energy, 30);
      expect(find.text(_tr.dailyEnergyClaimedSnack), findsNothing);
      expect(find.text(_tr.dailyEnergyAlreadyClaimedSnack), findsNothing);
      expect(find.text(_tr.shopEnergyFullToast), findsNothing);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });
  });
}
