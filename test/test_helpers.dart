// test/test_helpers.dart — W124-3 tasarımı (W125-1 uyguladı).
//
// Amaç: bütün widget testlerinde üretimle aynı l10n bağlantısını kurmak
// (lib/main.dart:331-336 + test/daily_reward_exploit_test.dart `pumpHub`).
// Kök neden: `localizationsDelegates` verilmeyen pump'ta
// `AppLocalizations.of(context)` null döner ve `!` patlar
// (lib/l10n/app_localizations.dart). Liste açıkça verilince Flutter
// varsayılan Global delegate'leri ezildiği için dördü birden listelenir.
//
// Kapsam: YALNIZ l10n. View boyutu, tema seçimi, mock kurulumu ve
// pump/settle zamanlaması burada değildir; her test kendi düzenini korur.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/l10n/app_localizations.dart';

/// Üretim bağlantısıyla aynı l10n kurulumunu yapan [MaterialApp].
///
/// Yalnız l10n ekler; başka hiçbir varsayılanı değiştirmez:
/// * [theme], [builder], [debugShowCheckedModeBanner] olduğu gibi
///   geçirilir. Özellikle [builder] içindeki MediaQuery
///   (430x932, textScaler 0.85) aynen korunmalıdır — helper bunu ezmez.
/// * [locale] varsayılanı TR'dir; EN isteyen test açıkça
///   `locale: const Locale('en')` geçirir.
/// * View boyutu (`tester.view.physicalSize`) burada ayarlanmaz.
Widget wrapWithL10n(
  Widget child, {
  Locale locale = const Locale('tr'),
  ThemeData? theme,
  TransitionBuilder? builder,
  bool debugShowCheckedModeBanner = true,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    theme: theme,
    builder: builder,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    localeResolutionCallback: AppLocalizations.localeResolutionCallback,
    home: child,
  );
}

/// [wrapWithL10n] ile sarıp pump eder.
///
/// `tester.view` kurulumu ve pump/settle zamanlaması çağıranda kalır
/// (her testin boyutu ve zamanlaması farklıdır).
Future<void> pumpWithL10n(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('tr'),
  ThemeData? theme,
  TransitionBuilder? builder,
  bool debugShowCheckedModeBanner = true,
}) async {
  await tester.pumpWidget(
    wrapWithL10n(
      child,
      locale: locale,
      theme: theme,
      builder: builder,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    ),
  );
}
