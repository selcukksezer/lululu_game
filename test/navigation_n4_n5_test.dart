import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/l10n/app_localizations.dart';
import 'package:lululu_game/navigation/game_routes.dart';
import 'package:lululu_game/screens/game_selector_screen.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/modes_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/energy_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';
import 'package:lululu_game/widgets/home/lululu_dock_bar.dart';

// 5F — N4 çift-shell + N5 HomeShell geri işleme davranış testleri.
//
// N4: bağımsız ekrandaki dock'tan `goTo(hub, replace: true)` ile
// dönüldüğünde eski `pushReplacement` yığında eski shell'i bırakıyor,
// yeni shell üstüne açılıyor, geri tuşu eski shell'e dönüyordu.
// Düzeltme: hub + replace yığını tek HomeShell'e indirir
// (`pushAndRemoveUntil`). Bu test, iki derinlikli yığından hub'a
// gidildiğinde yığında tek rota kaldığını gözleyiciyle kanıtlar.
//
// N5: hub-dışı sekmede geri hub sekmesine döner; hub sekmesinde geri
// varsayılan davranıştır (çıkış). `PopScope` bunu `HomeShell`
// içinde uygular.

/// Gözlenen rota yığınını aynen tutan gözleyici: N4 iddiası
/// (tek shell rotası) doğrudan yığın uzunluğuyla denetlenir.
class _StackObserver extends NavigatorObserver {
  final List<Route<dynamic>> stack = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    stack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) stack.remove(oldRoute);
    if (newRoute != null) stack.add(newRoute);
  }
}

/// N4 düzeneği: A sayfası B sayfasını `push` ile açar (yığın
/// derinliği 2 — eski shell + bağımsız ekran senaryosu); B sayfası
/// dock davranışını taklit edip `goTo(target, replace: true)` çağırır.
class _PageA extends StatelessWidget {
  const _PageA({required this.target});

  final String target;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _PageB(target: target),
          ),
        ),
        child: const Text('PUSH_B'),
      ),
    );
  }
}

class _PageB extends StatelessWidget {
  const _PageB({required this.target});

  final String target;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () => goTo(context, target, replace: true),
        child: const Text('GO_TARGET'),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Yalnız audioplayers kanalları mock'lanır (route_fallback_test
    // deseni). 'flutter/platform' ASLA mock'lanmaz: mock'lu kanalda
    // SystemChrome mesajları (setSystemUIOverlayStyle /
    // setApplicationSwitcherDescription) test mesajlaşmasında
    // çözümlenemez ve her pump'ta 'Message corrupted' fırlatır.
    // N5 hub sekmesinde geri: kök rota pop edilemeyince
    // SystemNavigator.pop çağrılır; işleyicisiz kanalda yutulur
    // (null döner), mock gerekmez.
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

  void setViewSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget buildTestApp({
    required Widget home,
    List<NavigatorObserver> observers = const [],
  }) {
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
      navigatorObservers: observers,
      home: home,
    );
  }

  // Bekleyen geçici kare geri çağrılarını tüket (en fazla 5 kare).
  // Sistem yazı tipi bildirimi (_SystemFontsNotifier) ağaç atıldıktan
  // sonra bile bir geri çağrı bırakabilir; tüketilmezse postTest
  // değişmez kontrolü ("animation is still running") hatası verir.
  Future<void> flushTransientCallbacks(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      if (tester.binding.transientCallbackCount == 0) break;
      await tester.pump();
    }
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await flushTransientCallbacks(tester);
    // Bildirim gövde sonrasındaki çerçeve pompasından sonra da
    // gelebilir; bu yüzden aynı boşaltma tearDown'da da koşar:
    // testWidgets, postTest'i ilk tearDown olarak kaydettiğinden
    // kullanıcı tearDown'ları değişmez kontrolünden ÖNCE çalışır.
    addTearDown(() => flushTransientCallbacks(tester));
  }

  group('N4 çift-shell', () {
    testWidgets('hub + replace iki derinlikli yığını tek HomeShell yapar',
        (tester) async {
      setViewSize(tester);
      final observer = _StackObserver();
      await tester.pumpWidget(
        buildTestApp(
          home: const _PageA(target: LululuRoutes.hub),
          observers: [observer],
        ),
      );
      await tester.pump();

      // Bağımsız ekran senaryosu: yığın [A, B].
      await tester.tap(find.text('PUSH_B'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(observer.stack, hasLength(2));

      // Dock'tan hub'a dönüş (replace: true).
      await tester.tap(find.text('GO_TARGET'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomeShell), findsOneWidget);
      expect(observer.stack, hasLength(1));
      expect(observer.stack.single.settings.name, LululuRoutes.hub);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets('bilinmeyen rota + replace yedeği de tek HomeShell yapar',
        (tester) async {
      setViewSize(tester);
      final observer = _StackObserver();
      await tester.pumpWidget(
        buildTestApp(
          home: const _PageA(target: 'bilinmeyen-rota-5f'),
          observers: [observer],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('PUSH_B'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(observer.stack, hasLength(2));

      await tester.tap(find.text('GO_TARGET'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HomeShell), findsOneWidget);
      expect(observer.stack, hasLength(1));
      expect(observer.stack.single.settings.name, LululuRoutes.hub);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets('hub-dışı hedef + replace yalnız üst rotayı değiştirir',
        (tester) async {
      setViewSize(tester);
      final observer = _StackObserver();
      await tester.pumpWidget(
        buildTestApp(
          home: const _PageA(target: LululuRoutes.modes),
          observers: [observer],
        ),
      );
      await tester.pump();

      await tester.tap(find.text('PUSH_B'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(observer.stack, hasLength(2));

      await tester.tap(find.text('GO_TARGET'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Kapsam kilidi: N4 düzeltmesi yalnız hub hedefini etkiler;
      // hub-dışı replace'te alttaki rota korunur.
      expect(find.byType(ModesScreen), findsOneWidget);
      expect(observer.stack, hasLength(2));
      expect(observer.stack.last.settings.name, LululuRoutes.modes);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });
  });

  group('N5 HomeShell geri işleme', () {
    testWidgets('hub-dışı sekmede geri hub sekmesine döner',
        (tester) async {
      setViewSize(tester);
      await tester.pumpWidget(
        buildTestApp(
          home: const HomeShell(initialTab: LululuDockTab.modes),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ModesScreen), findsOneWidget);
      expect(find.byType(GameSelectorScreen), findsNothing);

      final handled = await tester.binding.handlePopRoute();
      await tester.pump();

      expect(handled, isTrue);
      expect(find.byType(GameSelectorScreen), findsOneWidget);
      expect(find.byType(ModesScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });

    testWidgets('hub sekmesinde geri varsayılan davranıştır (çıkış denemesi)',
        (tester) async {
      setViewSize(tester);
      await tester.pumpWidget(
        buildTestApp(home: const HomeShell()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(GameSelectorScreen), findsOneWidget);

      // Kök rota pop edilemez: PopScope canPop=true olduğundan geri
      // shell tarafından yutulmaz, sistem çıkışına düşer (testte
      // kanal yutulur); shell ağaçta kalır, sekme değişmez.
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(GameSelectorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tearDownTree(tester);
    });
  });
}
