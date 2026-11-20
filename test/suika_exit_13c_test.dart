import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

import 'test_helpers.dart';

/// W13-C: Suika çıkış akışı — hedefe dokunuş kanıtı.
///
/// Canlı bulgu (playtest-raporu.md §1): duraklatma diyaloğunda çıkış
/// istendiğinde "Leave this round?" onayı çıkıyor, Exit'e basınca
/// diyalog kapanıp GAME PAUSED diyaloğuna dönülüyordu.
///
/// Koordinatör doğrulaması (12V-su5.json + su5-confirm.png): sürücünün
/// Exit tap'i (320,625), Exit düğmesinin (~300-355, ~455-480) ~145px
/// altındaydı — diyalog dışı karartılmış alana düştü. Barrier'a
/// dokununca onay diyaloğu kapanır, tur bitmez, paused diyaloğu kalır;
/// gözlenen davranış bununla birebir uyumlu. Yani şüphe koda değil,
/// ıskalayan tap'e düştü.
///
/// Bu dosya o şüpheyi widget testiyle çözer: Exit düğmesi METİNLE
/// bulunup MERKEZİNE dokunulur (sabit koordinat yok). Hedefe dokununca
/// turdan çıkılıyorsa kod sağlamdır — lib'de değişiklik yoktur.
///
/// Kapsam (canlı akış = altta hub rotası varken, `openGameMode` push):
///  * A — duraklat → pause diyaloğundaki HOME → onayda Exit (hedefe)
///    → hub'a dönülür.
///  * B — duraklat → sistem geri (pageBack) → onayda Exit (hedefe)
///    → hub'a dönülür.
///  * C — onayda Cancel → duraklatılmış oyunda kalınır (aşırı düzeltme
///    yok; `_resumeAfterExitConfirm` erken-dönüşü Cancel için doğrudur:
///    zaten duraklatılmış oyunu devam ettirmemelidir).
///
/// NOT: `_resumeAfterExitConfirm` / `maybePop` zinciri okundu
/// (`game_screen.dart`:1409-1480, 2730): onayda `_exitConfirmed=true`
/// olur, sonraki karede `maybePop()` çağrılır; altta rota varken
/// `PopScope.canPop` true olduğundan pop gerçekleşir. Hedefe dokununca
/// zincir doğru çalışıyor — bu testin A/B geçişi kanıttır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
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
  });

  Widget gameScreen() => GameScreen(
    level: CampaignDatabase.kitchenLevel1,
    arcade: true,
    energyConsumed: true,
  );

  /// Altta hub rotası olan canlı akış: hub stub → OPEN GAME ile push.
  /// Rota kurulumu bir kare gecikmeli olur (debug2 kanıtı): tap sonrası
  /// önce boş `pump()`, sonra 300ms.
  Future<void> pumpHubWithGame(WidgetTester tester) async {
    tester.view.physicalSize = const Size(374, 680);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapWithL10n(
        Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('HUB MARKER'),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => gameScreen()),
                      );
                    },
                    child: const Text('OPEN GAME'),
                  ),
                ],
              ),
            ),
          ),
        ),
        locale: const Locale('en'),
        theme: buildLululuTheme(),
        debugShowCheckedModeBanner: false,
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('OPEN GAME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GameScreen), findsOneWidget);
  }

  /// Birkaç meyve bırakır ki `_dropsMade > 0` olsun (çıkış onayı
  /// ancak o zaman istenir). `suika_play_test.dart` koordinatları.
  Future<void> dropFruits(WidgetTester tester) async {
    for (var drop = 0; drop < 3; drop++) {
      await tester.tapAt(Offset(82 + (drop * 39) % 205, 250));
      for (var frame = 0; frame < 24; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> pauseGame(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.pause_rounded).first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('GAME PAUSED'), findsOneWidget);
  }

  /// Onay diyaloğundaki Exit'e HEDEFE dokunur (metinle bulunur,
  /// merkezine tap — sabit koordinat yok) ve turdan çıkıldığını doğrular.
  Future<void> tapExitExpectHub(WidgetTester tester) async {
    expect(find.text('Leave this round?'), findsOneWidget);
    await tester.tap(find.text('Exit'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('HUB MARKER'), findsOneWidget);
    expect(find.text('GAME PAUSED'), findsNothing);
    expect(tester.takeException(), isNull);
  }

  Future<void> tearDownTree(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    // Sistem yazı tipi bildirimi gerçek-zamanlı platform mesajıyla gelir;
    // sahte-zaman pump'ları onu yakalayamaz. `runAsync` ile gerçek bir
    // boşluk bırakıp ardından kare çalıştırılırsa geri çağrı ağaç
    // ayaktayken akar; yoksa teardown'da "animation is still running"
    // hatası verir (yalnız A'da deterministik görüldü).
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('A: HOME + hedefe Exit hub\'a döndürür', (tester) async {
    await pumpHubWithGame(tester);
    await dropFruits(tester);
    await pauseGame(tester);

    // Duraklatma diyaloğundaki HOME → çıkış onayı açılmalı.
    await tester.tap(find.text('HOME'));
    await tester.pump(const Duration(milliseconds: 300));

    await tapExitExpectHub(tester);
    await tearDownTree(tester);
  });

  testWidgets('B: sistem geri + hedefe Exit hub\'a döndürür', (tester) async {
    await pumpHubWithGame(tester);
    await dropFruits(tester);
    await pauseGame(tester);

    // Sistem geri düğmesi (`pageBack` AppBar geri düğmesi arar —
    // oyun ekranında yok; bağlamın pop rotası işleyicisi kullanılır)
    // → çıkış onayı açılmalı.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 300));

    await tapExitExpectHub(tester);
    await tearDownTree(tester);
  });

  testWidgets('C: Cancel duraklatılmış oyunda bırakır', (tester) async {
    await pumpHubWithGame(tester);
    await dropFruits(tester);
    await pauseGame(tester);

    await tester.tap(find.text('HOME'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Leave this round?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('GAME PAUSED'), findsOneWidget);
    expect(find.text('Leave this round?'), findsNothing);
    expect(tester.takeException(), isNull);
    await tearDownTree(tester);
  });
}
