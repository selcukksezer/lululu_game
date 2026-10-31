import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tasarım skill palette — hex values are authoritative. No off-palette colors.
abstract final class LululuColors {
  static const carbonVoid = Color(0xFF080B12);
  static const spaceNavy = Color(0xFF121826);
  static const liquidGold = Color(0xFFFFB800);
  static const cyberFuchsia = Color(0xFFE01E5A);
  static const darkObsidian = Color(0xFF2A3042);
  static const mutedTitanium = Color(0xFF8E9CAE);
  static const mysticRuby = Color(0xFFE52E2E);
  static const toxicNeon = Color(0xFF00FF66);
  static const coralFlare = Color(0xFFFF6B35);
  static const warningSolar = Color(0xFFFFD700);

  /// Primary title on dark (Vault hero / card titles) — Liquid Gold, not off-palette white.
  static const ink = liquidGold;

  /// Secondary body / captions.
  static const body = mutedTitanium;

  /// Light home canvas (user-requested white hub).
  static const paper = Color(0xFFFFFFFF);
  static const paperSoft = Color(0xFFF4F6FA);
  /// Readable ink on white — palette carbon.
  static const inkDark = carbonVoid;
  static const inkSoft = darkObsidian;

  /// Dot mesh tint at 5–10% opacity (skill §3).
  static Color dotMesh({double opacity = 0.08}) =>
      mutedTitanium.withValues(alpha: opacity);
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

/// Shared motion tokens (tasarim §5).
abstract final class LululuMotion {
  static const pressScale = 0.94;
  static const pressDuration = Duration(milliseconds: 160);
  static const elastic = Curves.elasticOut;
  static const minTap = 48.0;
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
      bodyMedium: GoogleFonts.exo2(color: LululuColors.body),
      bodySmall: GoogleFonts.exo2(color: LululuColors.mutedTitanium),
      titleLarge: GoogleFonts.exo2(
        color: LululuColors.ink,
        fontWeight: FontWeight.w900,
      ),
      labelLarge: GoogleFonts.exo2(
        color: LululuColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
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
