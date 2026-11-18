import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tasarım skill & HTML prototype (`LÜLÜLÜ UI/UX Tasarım.html`) palette.
/// Hex values are authoritative and include both the dark/light vault tokens
/// and the warm wood/arcade CSS custom properties.
abstract final class LululuColors {
  // Core HTML :root tokens
  static const carbonVoid = Color(0xFF080B12); // --carbon: #080B12
  static const spaceNavy = Color(0xFF121826); // --navy: #121826
  static const liquidGold = Color(0xFFFFB800); // --gold: #FFB800
  static const goldSoft = Color(0xFFFFD34D); // --gold-soft: #FFD34D
  static const cyberFuchsia = Color(0xFFE01E5A); // --fuchsia: #E01E5A
  static const darkObsidian = Color(0xFF2A3042); // --obsidian: #2A3042
  static const mutedTitanium = Color(0xFF8E9CAE); // --titanium: #8E9CAE
  static const mysticRuby = Color(0xFFE52E2E); // --ruby: #E52E2E
  static const toxicNeon = Color(0xFF00FF66);
  static const neon = Color(0xFF00C853); // --neon: #00C853
  static const coralFlare = Color(0xFFFF6B35); // --coral: #FF6B35
  static const warningSolar = Color(0xFFFFD700); // --solar: #FFD700

  // Warm Wood / Arcade CSS custom property tokens
  // (--bg-deep: #140804, --bg-wood: #2a1308, --bg-card: #3b1c0d,
  //  --gold: #ffcf40, --orange: #ff7a1a, --green: #2ecc40,
  //  --red: #e63946, --cream: #fff7e6)
  static const bgDeep = Color(0xFF140804);
  static const bgWood = Color(0xFF2A1308);
  static const bgCard = Color(0xFF3B1C0D);
  static const gold = Color(0xFFFFCF40);
  static const orange = Color(0xFFFF7A1A);
  static const green = Color(0xFF2ECC40);
  static const red = Color(0xFFE63946);
  static const cream = Color(0xFFFFF7E6);

  // Page / stage tokens from HTML :root
  static const pageBg = Color(0xFF0B0F18);
  static const pagePanel = Color(0xFF141A29);
  static const pagePanel2 = Color(0xFF1B2336);
  static const pageInk = Color(0xFFF2F5FA);
  static const pageMuted = Color(0xFF9AA7BC);
  static const pageLine = Color(0x17FFFFFF);
  static const checker = Color(0xFF2A3042);

  /// Primary title on dark (Vault hero / card titles) — Liquid Gold, not off-palette white.
  static const ink = liquidGold;

  /// Secondary body / captions.
  ///
  /// WCAG AA hesabı (parlaklık formülü, 2026-11-18): `mutedTitanium`
  /// (#8E9CAE, L=0.326) koyu zeminlerde 4.70–7.05 ile AA normal metni
  /// (4.5) geçerken açık zeminlerde kalıyor (paper 2.79, paperSoft 2.58,
  /// cream 2.62 — büyük metin eşiği 3.0'ın bile altında). Tek renk hem
  /// paper hem carbonVoid karşısında 4.5'i sağlayamaz (gerekli L
  /// aralıkları kesişmiyor: paper için L≤0.183, carbonVoid için L≥0.190).
  /// Bu jeton PAYLAŞILDIĞI için koyultulmadı: koyu ekranlar oyunun
  /// çoğunluğu ve koyultma onları 4.5'in altına düşürürdü. Kalıcı çözüm:
  /// zemine özel ayrı body jetonları + açık zeminli ekranlardaki
  /// doğrudan `mutedTitanium` metin kullanımlarının göçü (ayrı iş).
  static const body = mutedTitanium;

  /// Koyu zeminlerdeki gövde metni — [body]/[mutedTitanium] ile aynı
  /// değer (#8E9CAE). Koyu varsayılan; açık zeminlerde [bodyOnLight].
  static const bodyOnDark = mutedTitanium;

  /// Açık zeminlerdeki (paper/paperSoft/cream) gövde metni.
  ///
  /// #68727F (L=0.165): açık zeminlerde 4.51–4.88 ile WCAG AA normal
  /// metni (4.5) geçer. Koyu zeminlerde kullanma — orada [bodyOnDark].
  static const bodyOnLight = Color(0xFF68727F);

  /// Light home canvas (user-requested white hub).
  static const paper = Color(0xFFFFFFFF);
  static const paperSoft = Color(0xFFF4F6FA);

  /// Readable ink on white — palette carbon.
  static const inkDark = carbonVoid;
  static const inkSoft = darkObsidian;

  /// CSS custom property lookup table for 100% parity with HTML variables.
  static const Map<String, Color> cssVariables = {
    '--bg-deep': bgDeep,
    '--bg-wood': bgWood,
    '--bg-card': bgCard,
    '--gold': gold,
    '--gold-soft': goldSoft,
    '--orange': orange,
    '--green': green,
    '--red': red,
    '--cream': cream,
    '--carbon': carbonVoid,
    '--navy': spaceNavy,
    '--obsidian': darkObsidian,
    '--fuchsia': cyberFuchsia,
    '--ruby': mysticRuby,
    '--neon': neon,
    '--coral': coralFlare,
    '--solar': warningSolar,
    '--titanium': mutedTitanium,
    '--paper': paper,
    '--paper-soft': paperSoft,
    '--page-bg': pageBg,
    '--page-panel': pagePanel,
    '--page-panel2': pagePanel2,
    '--page-ink': pageInk,
    '--page-muted': pageMuted,
    '--checker': checker,
  };

  /// Dot mesh tint at 5–10% opacity (skill §3).
  static Color dotMesh({double opacity = 0.08}) =>
      mutedTitanium.withValues(alpha: opacity);
}

/// Authoritative typography tokens (`--font-display: 'Fredoka'`, `'Baloo 2'`,
/// `'Bangers'`, `--font-body: 'Nunito'`).
abstract final class LululuTypography {
  static const String fontDisplay = 'Fredoka';
  static const String fontDisplayAlt = 'Baloo 2';
  static const String fontAccent = 'Bangers';
  static const String fontBody = 'Nunito';

  static const List<String> displayFallback = [
    'Fredoka',
    'Baloo 2',
    'Nunito',
    'Exo 2',
  ];

  static const List<String> bodyFallback = [
    'Nunito',
    'Exo 2',
    'sans-serif',
  ];

  static const List<String> accentFallback = [
    'Bangers',
    'Baloo 2',
    'Nunito',
    'Exo 2',
  ];

  /// Yazı tipi çekme davranışını ayarlar. Varsayılan çevrimdışıdır
  /// ([allowRuntimeFetching] `false`): gömülü aileler (`pubspec.yaml`:
  /// Fredoka, Baloo 2, Bangers, Nunito, Exo 2) kullanılır, çevrimiçi çekme
  /// yapılmaz. `buildLululuTheme()` her çağrıda bunu uygular, böylece tema
  /// kurulduktan sonra çalışan doğrudan `GoogleFonts` çağrıları da aynı
  /// varsayılanı görür.
  static void configureFonts({bool allowRuntimeFetching = false}) {
    GoogleFonts.config.allowRuntimeFetching = allowRuntimeFetching;
  }

  /// Tüm yardımcıların paylaştığı geri dönüş anahtarı: çevrimiçi çekme
  /// kapalıyken gömülü aileyle `TextStyle` döndürülür.
  static bool get _useBundledFonts =>
      !GoogleFonts.config.allowRuntimeFetching;

  /// Gömülü aileyle tek geri dönüş dalı — dört yardımcı da bunu kullanır.
  static TextStyle _bundled({
    required String fontFamily,
    required List<String> fontFamilyFallback,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  /// Display style (`--font-display: 'Fredoka'` with `'Baloo 2'` fallback).
  static TextStyle display({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w800,
    Color color = LululuColors.cream,
    double? height = 1.12,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    if (_useBundledFonts) {
      return _bundled(
        fontFamily: fontDisplayAlt,
        fontFamilyFallback: displayFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );
    }
    return GoogleFonts.fredoka(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    ).copyWith(fontFamilyFallback: displayFallback);
  }

  /// Body style (`--font-body: 'Nunito'`).
  static TextStyle body({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w700,
    Color color = LululuColors.cream,
    double? height = 1.45,
    double? letterSpacing,
  }) {
    if (_useBundledFonts) {
      return _bundled(
        fontFamily: fontBody,
        fontFamilyFallback: bodyFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: bodyFallback);
  }

  /// Baloo 2 heading helper matching `h1, h2, h3, .disp` in HTML.
  static TextStyle baloo({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w800,
    Color color = LululuColors.ink,
    double? height = 1.12,
  }) {
    if (_useBundledFonts) {
      return _bundled(
        fontFamily: fontDisplayAlt,
        fontFamilyFallback: displayFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    }
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    ).copyWith(fontFamilyFallback: displayFallback);
  }

  /// Bangers arcade combo/title helper.
  static TextStyle bangers({
    double fontSize = 28,
    Color color = LululuColors.gold,
    double? letterSpacing = 0.8,
    List<Shadow>? shadows,
  }) {
    if (_useBundledFonts) {
      return _bundled(
        fontFamily: fontAccent,
        fontFamilyFallback: accentFallback,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );
    }
    return GoogleFonts.bangers(
      fontSize: fontSize,
      color: color,
      letterSpacing: letterSpacing,
      shadows: shadows,
    ).copyWith(fontFamilyFallback: accentFallback);
  }
}

/// Spacing / radius tokens (refs 1–8 card language).
abstract final class LululuRadii {
  static const card = 20.0;
  static const panel = 22.0;
  static const pill = 14.0;
  static const chip = 10.0;
  static const dock = 22.0;
}

abstract final class LululuGradients {
  static const carbonToNavy = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [LululuColors.carbonVoid, LululuColors.spaceNavy],
  );

  static const navyToCarbon = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [LululuColors.spaceNavy, LululuColors.carbonVoid],
  );

  static const fuchsiaToGold = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [LululuColors.cyberFuchsia, LululuColors.liquidGold],
  );

  static const rubyToFuchsia = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [LululuColors.mysticRuby, LululuColors.cyberFuchsia],
  );

  static const neonToGold = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [LululuColors.toxicNeon, LululuColors.liquidGold],
  );

  static const woodToDeep = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [LululuColors.bgWood, LululuColors.bgDeep],
  );

  static const goldToOrange = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [LululuColors.gold, LululuColors.orange],
  );

  /// Brighter hub surfaces — palette mix, less void-black.
  static final liftedBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.lerp(LululuColors.spaceNavy, LululuColors.mutedTitanium, 0.22)!,
      LululuColors.spaceNavy,
      Color.lerp(LululuColors.spaceNavy, LululuColors.darkObsidian, 0.55)!,
    ],
  );

  static final elevatedCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(LululuColors.darkObsidian, LululuColors.mutedTitanium, 0.28)!,
      Color.lerp(LululuColors.spaceNavy, LululuColors.darkObsidian, 0.35)!,
    ],
  );

  static final warmFeature = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(LululuColors.coralFlare, LululuColors.liquidGold, 0.35)!,
      Color.lerp(LululuColors.cyberFuchsia, LululuColors.coralFlare, 0.4)!,
      Color.lerp(LululuColors.spaceNavy, LululuColors.darkObsidian, 0.2)!,
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  /// White hub hero — vivid fuchsia → gold wash.
  static const paperHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      LululuColors.cyberFuchsia,
      LululuColors.coralFlare,
      LululuColors.liquidGold,
    ],
  );

  static const paperSky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      LululuColors.paper,
      LululuColors.paperSoft,
      LululuColors.paper,
    ],
  );
}

/// Shared motion tokens (tasarim §5 & HTML `@keyframes scrIn`).
abstract final class LululuMotion {
  static const pressScale = 0.94;
  static const pressDuration = Duration(milliseconds: 160);
  static const screenTransitionDuration = Duration(milliseconds: 280);
  static const screenReverseDuration = Duration(milliseconds: 220);
  static const elastic = Curves.elasticOut;
  static const smoothOut = Curves.easeOutCubic;
  static const minTap = 48.0;
}

/// Zero-jank page transition builder matching HTML `@keyframes scrIn`
/// (`opacity: 0 -> 1`, `translateX(14px) -> 0` in 280ms ease).
class ZeroJankPageTransitionsBuilder extends PageTransitionsBuilder {
  const ZeroJankPageTransitionsBuilder();

  static final CurveTween _smoothOutCurveTween = CurveTween(
    curve: LululuMotion.smoothOut,
  );
  static final Tween<Offset> _slideTween = Tween<Offset>(
    begin: const Offset(0.035, 0),
    end: Offset.zero,
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = animation.drive(_smoothOutCurveTween);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: _slideTween.animate(curved),
        child: RepaintBoundary(child: child),
      ),
    );
  }
}

enum KenneyPalette {
  yellow('Yellow'),
  red('Red'),
  green('Green'),
  blue('Blue'),
  grey('Grey');

  const KenneyPalette(this.folder);
  final String folder;
}

abstract final class LululuKenneyAssets {
  static const _root = 'assets/ui/kenney';

  static String buttonRectDepthGradient(
    KenneyPalette palette, {
    bool doubleResolution = false,
  }) {
    final tier = doubleResolution ? 'Double' : 'Default';
    return '$_root/${palette.folder}/$tier/button_rectangle_depth_gradient.png';
  }

  static String starFilled(
    KenneyPalette palette, {
    bool doubleResolution = false,
  }) {
    final tier = doubleResolution ? 'Double' : 'Default';
    return '$_root/${palette.folder}/$tier/star.png';
  }

  static String starOutline(
    KenneyPalette palette, {
    bool doubleResolution = false,
  }) {
    final tier = doubleResolution ? 'Double' : 'Default';
    return '$_root/${palette.folder}/$tier/star_outline.png';
  }

  static String buttonRectDepthBorder(
    KenneyPalette palette, {
    bool doubleResolution = false,
  }) {
    final tier = doubleResolution ? 'Double' : 'Default';
    return '$_root/${palette.folder}/$tier/button_rectangle_depth_border.png';
  }

  static String buttonRectDepthFlat(
    KenneyPalette palette, {
    bool doubleResolution = false,
  }) {
    final tier = doubleResolution ? 'Double' : 'Default';
    return '$_root/${palette.folder}/$tier/button_rectangle_depth_flat.png';
  }

  static String buttonRoundDepthGradient(
    KenneyPalette palette, {
    bool doubleResolution = false,
  }) {
    final tier = doubleResolution ? 'Double' : 'Default';
    return '$_root/${palette.folder}/$tier/button_round_depth_gradient.png';
  }
}

ThemeData buildLululuTheme() {
  // Varsayılan: çevrimiçi yazı tipi çekme kapalı; gömülü aileler kullanılır.
  // Tema ilk ekran çizilmeden önce kurulduğu için bu ayar, doğrudan
  // GoogleFonts çağrılarının da varsayılanını belirler (paket, çekme
  // kapalıyken gömülü aile adına geri döner; bkz. LululuTypography).
  LululuTypography.configureFonts();
  const scheme = ColorScheme.dark(
    surface: LululuColors.spaceNavy,
    onSurface: LululuColors.ink,
    primary: LululuColors.liquidGold,
    onPrimary: LululuColors.carbonVoid,
    secondary: LululuColors.cyberFuchsia,
    onSecondary: LululuColors.ink,
    error: LululuColors.mysticRuby,
    tertiary: LululuColors.toxicNeon,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: LululuColors.carbonVoid,
    colorScheme: scheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: ZeroJankPageTransitionsBuilder(),
        TargetPlatform.android: ZeroJankPageTransitionsBuilder(),
        TargetPlatform.macOS: ZeroJankPageTransitionsBuilder(),
      },
    ),
    // Custom vault dock only — never ship Material NavigationBar chrome.
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: LululuColors.carbonVoid,
      indicatorColor: LululuColors.darkObsidian,
      height: 0,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: LululuColors.carbonVoid,
      foregroundColor: LululuColors.ink,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: LululuColors.spaceNavy,
      elevation: 8,
      shadowColor: LululuColors.liquidGold.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: LululuColors.cyberFuchsia.withValues(alpha: 0.35),
        ),
      ),
    ),
    dividerColor: LululuColors.darkObsidian,
    textTheme: GoogleFonts.exo2TextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: LululuColors.body,
      displayColor: LululuColors.ink,
      decoration: TextDecoration.none,
    ).copyWith(
      displayLarge: LululuTypography.display(
        fontSize: 34,
        color: LululuColors.ink,
      ),
      displayMedium: LululuTypography.display(
        fontSize: 28,
        color: LululuColors.ink,
      ),
      displaySmall: LululuTypography.display(
        fontSize: 22,
        color: LululuColors.ink,
      ),
      bodyLarge: LululuTypography.body(
        fontSize: 16,
        color: LululuColors.cream,
      ),
      bodyMedium: GoogleFonts.exo2(color: LululuColors.body).copyWith(
        fontFamilyFallback: LululuTypography.bodyFallback,
      ),
      bodySmall: GoogleFonts.exo2(color: LululuColors.mutedTitanium).copyWith(
        fontFamilyFallback: LululuTypography.bodyFallback,
      ),
      titleLarge: GoogleFonts.exo2(
        color: LululuColors.ink,
        fontWeight: FontWeight.w900,
      ).copyWith(fontFamilyFallback: LululuTypography.displayFallback),
      labelLarge: GoogleFonts.exo2(
        color: LululuColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ).copyWith(fontFamilyFallback: LululuTypography.bodyFallback),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: LululuColors.darkObsidian,
      contentTextStyle: const TextStyle(color: LululuColors.ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LululuRadii.pill),
      ),
    ),
  );
}

