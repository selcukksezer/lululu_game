import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_localizations.dart';
import 'package:lululu_game/navigation/game_routes.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/modes_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/home/lululu_dock_bar.dart';

// 12O — alt bar regresyon testleri.
//
// (1) Hap sekme değiştirirken simge+yazı katmanının ARKASINDA kayar:
//     hapı taşıyan AnimatedPositioned, Stack'te Row'dan ÖNCE gelir.
// (2) Etiket her zaman görünürken hover ipucu (Tooltip) gösterilmez.
// (3) Kaydırılabilir içerik barın altında kalmaz: görünümün alt
//     kenarı dock üstünden yukarıda biter, son kart tam görünür.
//
// Not: (1)/(2) hafif testlerde yalnız LululuDockBar pompalanır;
// tam HomeShell testi ağır grafiğiyle ayrıca koşar.

/// Seçili sekmeyi tutan ince sarmalayıcı (yalnız dock testi için).
class _ProbeDock extends StatefulWidget {
  const _ProbeDock();

  @override
  State<_ProbeDock> createState() => _ProbeDockState();
}

class _ProbeDockState extends State<_ProbeDock> {
  LululuDockTab _tab = LululuDockTab.home;

  @override
  Widget build(BuildContext context) {
    return LululuDockBar(
      selected: _tab,
      onSelect: (tab) => setState(() => _tab = tab),
    );
  }
}

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
    SharedPreferences.setMockInitialValues({});
    await ProgressManager.instance.load();
    await EnergyService.instance.load();
  });

  void setViewSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildTestApp(Widget home) {
    return MaterialApp(
      theme: buildLululuTheme(),
      locale: const Locale('tr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: AppLocalizations.localeResolutionCallback,
      onGenerateRoute: LululuRoutes.onGenerateRoute,
      home: home,
    );
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      if (tester.binding.transientCallbackCount == 0) break;
      await tester.pump();
    }
    addTearDown(() async {
      for (var i = 0; i < 5; i++) {
        if (tester.binding.transientCallbackCount == 0) break;
        await tester.pump();
      }
    });
  }

  /// Hap + sekme satırını birlikte taşıyan Stack'ler: doğrudan
  /// AnimatedPositioned çocuğu VE doğrudan Row çocuğu olanlar.
  List<Stack> dockPillStacks(WidgetTester tester, Finder scope) {
    final stacks = tester.widgetList<Stack>(
      find.descendant(of: scope, matching: find.byType(Stack)),
    );
    return stacks
        .where(
          (s) =>
              s.children.any((c) => c is AnimatedPositioned) &&
              s.children.any((c) => c is Row),
        )
        .toList();
  }

  /// İlke: hap Stack'in Row'dan ÖNCE gelir — simge+yazı hapın
  /// üstünde boyanır. Sıra bozulursa bu test düşer.
  void expectPillBehindLabels(WidgetTester tester, Finder scope) {
    final found = dockPillStacks(tester, scope);
    expect(found, isNotEmpty, reason: 'hap tasiyan Stack bulunamadi');
    for (final stack in found) {
      final pillIndex =
          stack.children.indexWhere((c) => c is AnimatedPositioned);
      final rowIndex = stack.children.indexWhere((c) => c is Row);
      expect(
        pillIndex,
        lessThan(rowIndex),
        reason: 'hap Row\'dan once gelmeli (arka katman)',
      );
    }
  }

  group('12O dock hap + ipucu (yalniz bar)', () {
    testWidgets('hap kayarken etiketler ustte kalir, hap arka katmanda',
        (tester) async {
      setViewSize(tester, const Size(430, 200));
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            backgroundColor: Color(0xFFF4F6FA),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: _ProbeDock(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final stacks = dockPillStacks(tester, find.byType(LululuDockBar));
      expect(stacks, hasLength(1));
      expectPillBehindLabels(tester, find.byType(LululuDockBar));

      // Başlangıç konumu (ANA SAYFA): rendered left global
      // koordinattır (bar kenarlığı + pay içerir) — bu yüzden
      // yalnız FARK denetlenir.
      final pillHome = dockPillStacks(tester, find.byType(LululuDockBar))
          .single
          .children
          .firstWhere((c) => c is AnimatedPositioned) as AnimatedPositioned;
      final tabWidth = pillHome.width!;
      final leftHome = tester.getRect(find.byWidget(pillHome)).left;

      // Kayma: MAĞAZA'ya dokun, hap hareket hâlinde olmalı
      // (60ms'de yerinden oynamış, 125ms'de hâlâ yolda, 300ms'de
      // hedefte). easeOutBack taşmalı olduğundan ara değer hedefi
      // aşabilir; yalnız hareket + yerleşme denetlenir.
      await tester.tap(find.text('MAĞAZA'));
      // Animasyon denetleyicisi ilk karede başlar; süreli pump
      // ancak ondan sonra ilerletir (aksi hâlde 60ms'de değer 0 kalır).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final pill60 = dockPillStacks(tester, find.byType(LululuDockBar))
          .single
          .children
          .firstWhere((c) => c is AnimatedPositioned) as AnimatedPositioned;
      final left60 = tester.getRect(find.byWidget(pill60)).left;
      expect(
        left60 - leftHome,
        greaterThan(0),
        reason: 'hap 60ms\'de yerinden oynamali',
      );

      await tester.pump(const Duration(milliseconds: 65));
      final pill125 = dockPillStacks(tester, find.byType(LululuDockBar))
          .single
          .children
          .firstWhere((c) => c is AnimatedPositioned) as AnimatedPositioned;
      final left125 = tester.getRect(find.byWidget(pill125)).left;
      expect(
        left125,
        isNot(left60),
        reason: 'hap 125ms\'de hâlâ kayiyor olmali',
      );

      await tester.pump(const Duration(milliseconds: 300));
      final pillSettled = dockPillStacks(tester, find.byType(LululuDockBar))
          .single
          .children
          .firstWhere((c) => c is AnimatedPositioned) as AnimatedPositioned;
      final leftSettled = tester.getRect(find.byWidget(pillSettled)).left;
      expect(
        leftSettled - leftHome,
        closeTo(3 * tabWidth, 0.5),
        reason: 'hap MAĞAZA sekmesine yerleşmeli',
      );

      // Etiketler kayma boyunca ağaçta ve bar sınırları içinde.
      final barRect = tester.getRect(find.byType(LululuDockBar));
      for (final label in [
        'ANA SAYFA',
        'MODLAR',
        'AİLEM',
        'MAĞAZA',
        'SKORLAR',
      ]) {
        final labelFinder = find.text(label);
        expect(labelFinder, findsWidgets, reason: '$label gorunur olmali');
        final labelRect = tester.getRect(labelFinder.first);
        expect(
          barRect.contains(
            Offset(labelRect.center.dx, labelRect.center.dy),
          ),
          isTrue,
          reason: '$label bar sinirlari icinde olmali',
        );
      }
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('yazi varken hover ipucu gosterilmez', (tester) async {
      setViewSize(tester, const Size(430, 200));
      await tester.pumpWidget(
        buildTestApp(
          const Scaffold(
            backgroundColor: Color(0xFFF4F6FA),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: _ProbeDock(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dock içinde hiç Tooltip yok: etiket zaten görünür.
      expect(
        find.descendant(
          of: find.byType(LululuDockBar),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );

      // Masaüstü hover + uzun bekleme de ipucu çıkarmaz.
      final gesture =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await gesture.addPointer(
        location: tester.getCenter(find.text('MAĞAZA')),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.descendant(
          of: find.byType(LululuDockBar),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
      // Erişilebilirlik etiketi Semantics'te durur.
      expect(find.bySemanticsLabel('MAĞAZA'), findsWidgets);
      expect(tester.takeException(), isNull);
      await gesture.removePointer();
      await tearDownTree(tester);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('12O alt pay (shell kosullari + ModesScreen)', () {
    // HomeShell'in yaptığı: içerik Positioned.fill + 106 alt pay;
    // dock 84 yükseklik + 10 alt pay = 94. İçerik görünümü dock
    // üstünde bitmeli, son kart tam görünmeli.
    const dockClearance = 106.0;
    const dockHeight = 94.0;

    Future<void> pumpModesWithDock(
      WidgetTester tester,
      Size size,
    ) async {
      setViewSize(tester, size);
      await tester.pumpWidget(
        buildTestApp(
          Scaffold(
            extendBody: true,
            backgroundColor: const Color(0xFFF4F6FA),
            body: Stack(
              children: [
                const Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: dockClearance),
                    child: ModesScreen(embedded: true),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: dockHeight,
                  child: Container(
                    key: const ValueKey('dock-marker'),
                    color: Colors.red.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> expectLastCardFullyVisible(WidgetTester tester) async {
      final listFinder = find.byType(ListView).first;
      await tester.scrollUntilVisible(
        find.text('MAKARAYIZ'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final viewportRect = tester.getRect(listFinder);
      final dockRect =
          tester.getRect(find.byKey(const ValueKey('dock-marker')));
      // (3a) görünüm dock üstünde biter.
      expect(
        viewportRect.bottom,
        lessThanOrEqualTo(dockRect.top),
        reason: 'liste gorunumu dock ustunde bitmeli',
      );
      // (3b) son kartın tamamı görünür: kartın alt kenarı görünüm
      // altından yukarıda kalır (başlığın en yakın Stack atası karttır).
      final cardRect = tester.getRect(
        find
            .ancestor(
              of: find.text('MAKARAYIZ'),
              matching: find.byType(Stack),
            )
            .first,
      );
      expect(
        cardRect.bottom,
        lessThanOrEqualTo(viewportRect.bottom),
        reason: 'son kart (MAKARAYIZ) tam gorunur olmali',
      );
      expect(cardRect.bottom, lessThanOrEqualTo(dockRect.top));
      expect(tester.takeException(), isNull);
    }

    testWidgets('son kart tam gorunur (430x932)', (tester) async {
      await pumpModesWithDock(tester, const Size(430, 932));
      await expectLastCardFullyVisible(tester);
      await tearDownTree(tester);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('son kart tam gorunur (360x640)', (tester) async {
      await pumpModesWithDock(tester, const Size(360, 640));
      await expectLastCardFullyVisible(tester);
      await tearDownTree(tester);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('son kart tam gorunur (608x440 masaustu)', (tester) async {
      await pumpModesWithDock(tester, const Size(608, 440));
      await expectLastCardFullyVisible(tester);
      await tearDownTree(tester);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  group('12O tam HomeShell', () {
    testWidgets('gercek shell: hap arkada kayar, ipucu yok, son kart acik',
        (tester) async {
      setViewSize(tester, const Size(430, 932));
      await tester.pumpWidget(
        buildTestApp(const HomeShell()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // (2) gerçek shell'de de dock içi Tooltip yok.
      expect(
        find.descendant(
          of: find.byType(LululuDockBar),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );

      // (1) etkileşim katmanında hap Row'dan önce.
      expectPillBehindLabels(tester, find.byType(LululuDockBar));

      // (1) görünür katman da kayar: 430 genişlikte sekme 78,
      // hap 78x64. İki katman (etkileşim + görünür kopya) da
      // kayıyor olmalı. Kayma MODLAR ile denetlenir: MAĞAZA
      // sekmesi ShopScreen açar; onun bandı test yazı tipiyle
      // 16px taşar (mevcut shop testleri loadAppFonts ile çözer),
      // bu testin konusu değil.
      const tabWidth = 78.0;
      List<AnimatedPositioned> dockPills() {
        return tester
            .widgetList<AnimatedPositioned>(
              find.descendant(
                of: find.byType(HomeShell),
                matching: find.byType(AnimatedPositioned),
              ),
            )
            .where(
              (p) =>
                  p.width != null &&
                  (p.width! - tabWidth).abs() < 0.5 &&
                  p.height == 64,
            )
            .toList();
      }

      final homePills = dockPills();
      expect(homePills, hasLength(2), reason: 'etkilesim + gorunur katman');
      final homeLefts = homePills
          .map((p) => tester.getRect(find.byWidget(p)).left)
          .toList();

      await tester.tap(find.text('MODLAR').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final sliding = dockPills();
      expect(sliding, hasLength(2), reason: 'etkilesim + gorunur katman');
      for (var i = 0; i < sliding.length; i++) {
        expect(
          tester.getRect(find.byWidget(sliding[i])).left - homeLefts[i],
          greaterThan(0),
          reason: 'her iki hap da kayiyor olmali',
        );
      }
      await tester.pump(const Duration(milliseconds: 400));
      final settled = dockPills();
      for (var i = 0; i < settled.length; i++) {
        expect(
          tester.getRect(find.byWidget(settled[i])).left - homeLefts[i],
          closeTo(1 * tabWidth, 0.5),
          reason: 'haplar MODLAR sekmesine yerleşmeli',
        );
      }

      // (3) modlar sekmesinde son kart tam görünür (zaten MODLAR'dayız).
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ModesScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('MAKARAYIZ'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final viewportRect = tester.getRect(find.byType(ListView).first);
      final dockRect = tester.getRect(find.byType(LululuDockBar).first);
      expect(
        viewportRect.bottom,
        lessThanOrEqualTo(dockRect.top),
        reason: 'liste gorunumu dock ustunde bitmeli',
      );
      final cardRect = tester.getRect(
        find
            .ancestor(
              of: find.text('MAKARAYIZ'),
              matching: find.byType(Stack),
            )
            .first,
      );
      expect(
        cardRect.bottom,
        lessThanOrEqualTo(viewportRect.bottom),
        reason: 'son kart (MAKARAYIZ) tam gorunur olmali',
      );
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
