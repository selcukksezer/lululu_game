// 12H-splash: kök widget'ta splash atlama/gösterme dalları (widget testi).
//
// Bayrak varken `BootApp` ilk karede splash'sız boot-yükleme ekranını
// gösterir (doğrudan `_boot()` yolu); bayrak yokken `SplashScreen`
// gösterilir. Bayrağın kendisi `splash_session_skip_test.dart`'ta
// birim testlerle kilitlidir. Depo, `SplashSession.debugOverrideStorage`
// ile sahte depoyla değiştirilir (test sonunda sıfırlanır).
//
// NOT: bu test `_boot()`'u da tetikler (bayrak dalında); boot
// servisleri SharedPreferences sahte değeriyle çalışır, Firebase
// yapılandırılmamış modda hemen yerel dönüş yapar.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/main.dart';
import 'package:lululu_game/screens/splash_screen.dart';
import 'package:lululu_game/services/splash_session.dart';

/// Bellek içi sahte depolama: web `sessionStorage`'ın test ikizi.
class _MemorySplashSessionStorage implements SplashSessionStorage {
  bool _seen = false;

  @override
  bool get splashSeen => _seen;

  @override
  void markSplashSeen() {
    _seen = true;
  }
}

/// `replay_onboarding_6i_test.dart` deseni: üretim fontları testte
/// de yüklenir; yedek font ölçüleriyle splash sayfa 1 taşar.
Future<void> _loadCustomFonts() async {
  final fontMap = <String, List<String>>{
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Regular.ttf',
    ],
    'Bangers': ['assets/fonts/Bangers-Regular.ttf'],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Regular.ttf',
    ],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Regular.ttf',
    ],
  };

  for (final entry in fontMap.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await loader.load();
  }

  for (final w in FontWeight.values) {
    GoogleFonts.baloo2(fontWeight: w);
    GoogleFonts.nunito(fontWeight: w);
    GoogleFonts.bangers(fontWeight: w);
    GoogleFonts.exo2(fontWeight: w);
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
    await loadAppFonts();
    await _loadCustomFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => SplashSession.debugOverrideStorage(null));

  testWidgets('bayrak varken splash atlanır, boot-yükleme gösterilir',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _MemorySplashSessionStorage();
    SplashSession.debugOverrideStorage(storage);
    SplashSession.markSeen();

    await tester.pumpWidget(const BootApp());

    // İlk kare: splash yok, boot-yükleme ekranı var.
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // `_boot` ateşle-unut IAP kontrolünü 6 sn zaman aşımıyla bekler;
    // testte mağaza kanalı yanıtsız kaldığı için zaman aşımı ancak
    // sahte saat ilerleyince ateşlenir. Sökümden önce saat
    // ilerletilir ki asılı Timer kalmasın.
    await tester.pump(const Duration(seconds: 7));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('bayrak yokken splash gösterilir', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SplashSession.debugOverrideStorage(_MemorySplashSessionStorage());

    await tester.pumpWidget(const BootApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
