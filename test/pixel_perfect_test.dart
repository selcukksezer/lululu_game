import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lululu_game/models/campaign_level.dart';
import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/modes/balloon_pop_screen.dart';
import 'package:lululu_game/modes/connect_pop_screen.dart';
import 'package:lululu_game/modes/makarayiz_screen.dart';
import 'package:lululu_game/modes/match3_screen.dart';
import 'package:lululu_game/modes/osmantus_screen.dart';
import 'package:lululu_game/modes/scream_roach_screen.dart';
import 'package:lululu_game/modes/stack_drop_screen.dart';
import 'package:lululu_game/modes/terlik_tap_screen.dart';
import 'package:lululu_game/modes/yuva_defense_screen.dart';
import 'package:lululu_game/screens/auth_screen.dart';
import 'package:lululu_game/screens/chat_screen.dart';
import 'package:lululu_game/screens/game_screen.dart';
import 'package:lululu_game/screens/grid_2048_screen.dart';
import 'package:lululu_game/screens/home_shell.dart';
import 'package:lululu_game/screens/leaderboard_screen.dart';
import 'package:lululu_game/screens/modes_screen.dart';
import 'package:lululu_game/screens/online_screen.dart';
import 'package:lululu_game/screens/profile_screen.dart';
import 'package:lululu_game/screens/result_screen.dart';
import 'package:lululu_game/screens/tiers_screen.dart';
import 'package:lululu_game/screens/studio_screens.dart';
import 'package:lululu_game/screens/splash_screen.dart';
import 'package:lululu_game/screens/tasks_screen.dart';
import 'package:lululu_game/widgets/shop_dialog.dart';
import 'package:lululu_game/services/adaptive_quality_scaler.dart';
import 'package:lululu_game/services/audio_manager.dart';
import 'package:lululu_game/services/leaderboard_service.dart';
import 'package:lululu_game/services/progress_manager.dart';
import 'package:lululu_game/theme/lululu_theme.dart';

class SignalIconPainter extends CustomPainter {
  const SignalIconPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.fill;
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);
    canvas.drawRect(const Rect.fromLTWH(2, 17, 3, 4), paint);
    canvas.drawRect(const Rect.fromLTWH(7.5, 13, 3, 8), paint);
    canvas.drawRect(const Rect.fromLTWH(13, 9, 3, 12), paint);
    canvas.drawRect(const Rect.fromLTWH(18.5, 5, 3, 16), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BatteryIconPainter extends CustomPainter {
  const BatteryIconPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);
    final strokePaint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2.5, 8, 17, 9), const Radius.circular(2.5)),
      strokePaint,
    );
    final fillPaint = Paint()
      ..color = const Color(0xFF141B2A)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(4.5, 10, 10, 5), const Radius.circular(1)),
      fillPaint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

ui.Image? _refStatusBarImage;

class _StatusBarImagePainter extends CustomPainter {
  final ui.Image image;
  _StatusBarImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      const Rect.fromLTWH(0, 0, 430, 35.4),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MockStatusBarWidget extends StatelessWidget {
  const MockStatusBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (_refStatusBarImage != null) {
      return SizedBox(
        width: 430,
        height: 35.4,
        child: CustomPaint(
          painter: _StatusBarImagePainter(_refStatusBarImage!),
        ),
      );
    }
    return Container(
      height: 35.4,
      width: 430,
      padding: const EdgeInsets.fromLTRB(22, 11, 22, 2),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '09:41',
            style: GoogleFonts.nunito(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF141B2A),
              height: 1.0,
            ),
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: Size(15, 15),
                painter: SignalIconPainter(),
              ),
              SizedBox(width: 5),
              CustomPaint(
                size: Size(15, 15),
                painter: BatteryIconPainter(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const List<String> _kAllPrecacheAssets = [
  // Dock & Bottom Navigation Icons (LululuDockBar, etc.)
  'assets/design/ui/icons2/home.png',
  'assets/design/ui/icons2/target.png',
  'assets/design/ui/icons2/paw.png',
  'assets/design/ui/icons2/cart.png',
  'assets/design/ui/icons2/trophy.png',
  'assets/design/ui/icons2/bolt.png',
  'assets/design/ui/icons2/star.png',
  'assets/icons2/home.png',
  'assets/icons2/target.png',
  'assets/icons2/paw.png',
  'assets/icons2/cart.png',
  'assets/icons2/trophy.png',
  'assets/ui/custom/nav_home.webp',
  'assets/ui/custom/nav_modes.webp',
  'assets/ui/custom/nav_levels.webp',
  'assets/ui/custom/nav_shop.webp',
  'assets/ui/custom/nav_Rank.webp',

  // Shop, Mode, Badge, Task, Profile, Leaderboard & Game Icons (icons2)
  'assets/icons2/back-prototype.png',
  'assets/icons2/back.png',
  'assets/icons2/bell.png',
  'assets/icons2/block.png',
  'assets/icons2/bolt.png',
  'assets/icons2/book.png',
  'assets/icons2/boom.png',
  'assets/icons2/boost_coins.png',
  'assets/icons2/boot.png',
  'assets/icons2/calendar.png',
  'assets/icons2/chest_gold.png',
  'assets/icons2/chest_wood.png',
  'assets/icons2/clock.png',
  'assets/icons2/coin.png',
  'assets/icons2/coin_stack.png',
  'assets/icons2/crown.png',
  'assets/icons2/crystal.png',
  'assets/icons2/discount.png',
  'assets/icons2/egg_gold.png',
  'assets/icons2/fist.png',
  'assets/icons2/flame.png',
  'assets/icons2/gear.png',
  'assets/icons2/gem_blue.png',
  'assets/icons2/gift_box.png',
  'assets/icons2/hammer.png',
  'assets/icons2/magnet.png',
  'assets/icons2/map.png',
  'assets/icons2/medal.png',
  'assets/icons2/money_bag.png',
  'assets/icons2/potion_health.png',
  'assets/icons2/potion_luck.png',
  'assets/icons2/potion_speed.png',
  'assets/icons2/premium_token.png',
  'assets/icons2/r1.png',
  'assets/icons2/r5.png',
  'assets/icons2/shield.png',
  'assets/icons2/star.png',
  'assets/icons2/stopwatch.png',
  'assets/icons2/sword.png',
  'assets/icons2/terlik-hitstar-prototype.png',
  'assets/icons2/terlik-slip-prototype.webp',
  'assets/icons2/wand.png',
  'assets/icons2/wheel.png',
  'assets/icons2/yuva-nest-prototype.png',
  'assets/icons2/yuva-slipper-prototype.png',
  'assets/icons2/yuva-title-prototype.png',

  // Design UI icons2 mirrors
  'assets/design/ui/icons2/back.png',
  'assets/design/ui/icons2/bell.png',
  'assets/design/ui/icons2/block.png',
  'assets/design/ui/icons2/book.png',
  'assets/design/ui/icons2/boom.png',
  'assets/design/ui/icons2/boost_coins.png',
  'assets/design/ui/icons2/boot.png',
  'assets/design/ui/icons2/calendar.png',
  'assets/design/ui/icons2/chest_gold.png',
  'assets/design/ui/icons2/chest_wood.png',
  'assets/design/ui/icons2/clock.png',
  'assets/design/ui/icons2/coin.png',
  'assets/design/ui/icons2/coin_stack.png',
  'assets/design/ui/icons2/crown.png',
  'assets/design/ui/icons2/crystal.png',
  'assets/design/ui/icons2/discount.png',
  'assets/design/ui/icons2/egg_gold.png',
  'assets/design/ui/icons2/fist.png',
  'assets/design/ui/icons2/flame.png',
  'assets/design/ui/icons2/gear.png',
  'assets/design/ui/icons2/gem_blue.png',
  'assets/design/ui/icons2/gift_box.png',
  'assets/design/ui/icons2/hammer.png',
  'assets/design/ui/icons2/magnet.png',
  'assets/design/ui/icons2/map.png',
  'assets/design/ui/icons2/medal.png',
  'assets/design/ui/icons2/money_bag.png',
  'assets/design/ui/icons2/potion_health.png',
  'assets/design/ui/icons2/potion_luck.png',
  'assets/design/ui/icons2/potion_speed.png',
  'assets/design/ui/icons2/premium_token.png',
  'assets/design/ui/icons2/r1.png',
  'assets/design/ui/icons2/r5.png',
  'assets/design/ui/icons2/shield.png',
  'assets/design/ui/icons2/stopwatch.png',
  'assets/design/ui/icons2/sword.png',
  'assets/design/ui/icons2/wand.png',
  'assets/design/ui/icons2/wheel.png',

  // Hub, Online, Result & Core UI Assets
  'assets/design/ui/avatar_hamam_diva.webp',
  'assets/design/ui/back_btn.png',
  'assets/design/ui/chest_result.webp',
  'assets/design/ui/hub_12_img.webp',
  'assets/design/ui/hub_13_img.webp',
  'assets/design/ui/hub_14_img.webp',
  'assets/design/ui/hub_15_img.webp',
  'assets/design/ui/hub_16_img.webp',
  'assets/design/ui/hub_19_img.webp',
  'assets/design/ui/hub_6_mascot.webp',
  'assets/design/ui/hub_avatar_exact.webp',
  'assets/design/ui/hub_hero_bg_exact.webp',
  'assets/design/ui/hub_hero_bg.webp',
  'assets/design/ui/hub_hero_mascot_exact.webp',
  'assets/design/ui/hub_hero_mascot.webp',
  'assets/design/ui/hub_hero_play_exact.webp',
  'assets/design/ui/hub_hero_play_ic.webp',
  'assets/design/ui/icon_bell_exact.webp',
  'assets/design/ui/icon_calendar_exact.webp',
  'assets/design/ui/icon_coin_exact.webp',
  'assets/design/ui/icon_coin.png',
  'assets/design/ui/icon_energy_bolt_exact.webp',
  'assets/design/ui/icon_gear_exact.webp',
  'assets/design/ui/icon_heart_exact.webp',
  'assets/design/ui/icon_star_exact.webp',
  'assets/design/ui/icon_star.png',
  'assets/design/ui/logo_lululu.webp',
  'assets/design/ui/online_locked_bug_exact.webp',
  'assets/design/ui/online_locked_bug.webp',
  'assets/design/ui/powerup_aydinlat.png',
  'assets/design/ui/powerup_raid_spreyi.png',
  'assets/design/ui/powerup_terlik.png',
  'assets/design/ui/res_chest.png',
  'assets/design/ui/res_coin.png',
  'assets/design/ui/res_mascot.png',
  'assets/design/ui/res_star.png',
  'assets/design/ui/tier7_kongo_lideri.png',

  // Studio Assets
  'assets/design/ui/studio_create/ebg.png',
  'assets/design/ui/studio_create/edSticker.png',
  'assets/design/ui/studio_create/img_3.png',
  'assets/design/ui/studio_create/img_5.png',
  'assets/design/ui/studio_create/img_6.png',
  'assets/design/ui/studio_create/img_7.png',
  'assets/design/ui/studio_downloads/bugimg.png',
  'assets/design/ui/studio_downloads/img_1.png',
  'assets/design/ui/studio_downloads/img_2.png',
  'assets/design/ui/studio_downloads/img_4.png',
  'assets/design/ui/studio_gif/gifImg.png',
  'assets/design/ui/studio_gif/img_2.png',
  'assets/design/ui/studio_gif/img_3.png',
  'assets/design/ui/studio_gif/img_4.png',
  'assets/design/ui/studio_watch/video_thumb_0.png',
  'assets/design/ui/studio_watch/video_thumb_1.png',
  'assets/design/ui/studio_watch/video_thumb_2.png',
  'assets/design/ui/studio_watch/video_thumb_3.png',
  'assets/design/ui/studio_watch/video_thumb_4.png',

  // Backgrounds & Splash
  'assets/design/backgrounds/2048_casino.webp',
  'assets/design/backgrounds/balloon_fair.webp',
  'assets/design/backgrounds/bg_kitchen.jpg',
  'assets/design/backgrounds/bg_splash.jpg',
  'assets/design/backgrounds/connect_workshop.webp',
  'assets/design/backgrounds/makarayiz_stage.webp',
  'assets/design/backgrounds/match3_lab.webp',
  'assets/design/backgrounds/osmantus_mansion.webp',
  'assets/design/backgrounds/result_wood_bg.png',
  'assets/design/backgrounds/stack_nightcity.webp',
  'assets/design/backgrounds/suika_kitchen.webp',
  'assets/design/backgrounds/terlik_livingroom.webp',
  'assets/design/splash/bg_splash.png',
  'assets/design/splash/bg_splash.webp',
  'assets/design/splash/splash_logo_shadow.png',
  'assets/design/splash/splash_logo.png',
  'assets/design/splash/splash_logo.webp',
  'assets/design/splash/splash_mascot.png',
  'assets/design/splash/splash_mascot.webp',
  'assets/design/images/kitchen_bg.png',
  'assets/design/images/logo_banner.png',
  'assets/images/bg_diva_mansion.png',
  'assets/images/bg_kitchen_counter.png',
  'assets/scream_sky.webp',

  // Obstacles, Powerups & Extra Icons
  'assets/obstacles/obstacle-bush.webp',
  'assets/obstacles/obstacle-pipes.webp',
  'assets/obstacles/obstacle-spikes.webp',
  'assets/osman/osmantus_kisi_a.webp',
  'assets/powerup_aydinlat.webp',
  'assets/powerup_raid_spreyi.webp',
  'assets/powerup_terlik.webp',
  'assets/game/trap_electric.png',
  'assets/icons/health.png',
  'assets/icons/level_up.png',
  'assets/icons/play.png',
  'assets/design/icons/extra_icons/All_Icons/clock.png',
  'assets/design/icons/extra_icons/All_Icons/explosion.png',
  'assets/design/icons/extra_icons/All_Icons/target.png',

  // Bug Tiers & Stickers
  'assets/bugs/tier1_hd.webp',
  'assets/bugs/tier2_hd.webp',
  'assets/bugs/tier3_hd.webp',
  'assets/bugs/tier4_hd.webp',
  'assets/bugs/tier5_hd.webp',
  'assets/bugs/tier6_hd.webp',
  'assets/bugs/tier7_hd.webp',
  'assets/bugs/tier8_hd.webp',
  'assets/bugs/tier9_hd.webp',
  'assets/bugs/tier10_hd.webp',
  'assets/bugs/tier11_hd.webp',
  'assets/bugs/tier12_hd.webp',
  'assets/bugs/tier13_hd.webp',
  'assets/design/bugs_hd/tier1_hd.png',
  'assets/design/bugs_hd/tier2_hd.png',
  'assets/design/bugs_hd/tier3_hd.png',
  'assets/design/bugs_hd/tier4_hd.png',
  'assets/design/bugs_hd/tier5_hd.png',
  'assets/design/bugs_hd/tier6_hd.png',
  'assets/design/bugs_hd/tier7_hd.png',
  'assets/design/bugs_hd/tier8_hd.png',
  'assets/design/bugs_new/tier9_hd.png',
  'assets/design/bugs_new/tier10_hd.png',
  'assets/design/bugs_new/tier11_hd.png',
  'assets/design/bugs_new/tier12_hd.png',
  'assets/design/bugs_new/tier13_hd.png',
  'assets/design/images/stickers/tier_1_256.png',
  'assets/design/images/stickers/tier_2_256.png',
  'assets/design/images/stickers/tier_3_256.png',
  'assets/design/images/stickers/tier_4_256.png',
  'assets/design/images/stickers/tier_5_256.png',
  'assets/design/images/stickers/tier_6_256.png',
  'assets/design/images/stickers/tier_7_256.png',
  'assets/design/images/stickers/tier_8_256.png',
  'assets/images/stickers/osman_1.png',
  'assets/images/stickers/osman_2.png',
  'assets/images/stickers/osmantus_kisi_a.png',
  'assets/images/stickers/osmantus_kisi_b.png',
  'assets/images/stickers/sticker_tier1_cone.png',
  'assets/images/stickers/sticker_tier2_helmet.png',
  'assets/images/stickers/sticker_tier3_fan.png',
  'assets/images/stickers/sticker_tier4_dancer.png',
  'assets/images/stickers/sticker_tier5_diva.png',
  'assets/images/stickers/sticker_tier6_can.png',
  'assets/images/stickers/sticker_tier7_kongo.png',
  'assets/images/stickers/sticker_tier8_bed.png',
  'assets/images/tier_1_cone.png',
];

Future<void> _precacheMountedTree(WidgetTester tester, {bool includeAllKnownAssets = false}) async {
  final rootElements = find.byType(RepaintBoundary, skipOffstage: false).evaluate();
  final imageElements = find.byType(Image, skipOffstage: false).evaluate();
  final containerElements =
      find.byType(DecoratedBox, skipOffstage: false).evaluate();
  await tester.runAsync(() async {
    if (includeAllKnownAssets && rootElements.isNotEmpty) {
      final rootCtx = rootElements.first;
      for (final tier in InsectTier.values) {
        try {
          await precacheImage(AssetImage(tier.assetPath), rootCtx, onError: (e, s) {});
        } catch (_) {}
      }
      for (final assetPath in _kAllPrecacheAssets) {
        try {
          await precacheImage(AssetImage(assetPath), rootCtx, onError: (e, s) {});
        } catch (_) {}
      }
    }
    for (final imageElement in imageElements) {
      final widget = imageElement.widget;
      if (widget is Image) {
        try {
          await precacheImage(widget.image, imageElement, onError: (e, s) {
            debugPrint('>>> PRECACHE ERROR: ${widget.image} -> $e');
          });
        } catch (e) {
          debugPrint('>>> PRECACHE CATCH: ${widget.image} -> $e');
        }
      }
    }
    for (final container in containerElements) {
      final widget = container.widget as DecoratedBox;
      final decoration = widget.decoration;
      if (decoration is BoxDecoration && decoration.image != null) {
        try {
          await precacheImage(decoration.image!.image, container, onError: (e, s) {
            debugPrint('>>> PRECACHE BG ERROR: ${decoration.image!.image} -> $e');
          });
        } catch (e) {
          debugPrint('>>> PRECACHE BG CATCH: ${decoration.image!.image} -> $e');
        }
      }
    }
  });
}

Future<void> safePrimeAssets(WidgetTester tester) async {
  await _precacheMountedTree(tester, includeAllKnownAssets: true);
  await tester.pump(const Duration(milliseconds: 100));
  await _precacheMountedTree(tester, includeAllKnownAssets: false);
}

Future<void> loadCustomFonts() async {
  final fontMap = {
    'Baloo 2': [
      'assets/fonts/Baloo2-Regular.ttf',
      'assets/fonts/Baloo2-Bold.ttf',
      'assets/fonts/Baloo2-ExtraBold.ttf',
      'assets/fonts/Baloo2-SemiBold.ttf',
      'assets/fonts/Baloo2-Medium.ttf',
    ],
    'Bangers': [
      'assets/fonts/Bangers-Regular.ttf',
    ],
    'Nunito': [
      'assets/fonts/Nunito-Regular.ttf',
      'assets/fonts/Nunito-Bold.ttf',
      'assets/fonts/Nunito-ExtraBold.ttf',
      'assets/fonts/Nunito-SemiBold.ttf',
      'assets/fonts/Nunito-Black.ttf',
    ],
    'Exo 2': [
      'assets/fonts/Exo2-Regular.ttf',
      'assets/fonts/Exo2-Bold.ttf',
      'assets/fonts/Exo2-ExtraBold.ttf',
      'assets/fonts/Exo2-SemiBold.ttf',
      'assets/fonts/Exo2-Black.ttf',
    ],
  };

  for (final entry in fontMap.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
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
  await GoogleFonts.pendingFonts();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => null,
    );
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadAppFonts();
    await loadCustomFonts();
    Animate.defaultDuration = Duration.zero;
    final refFile = File('/Users/selcuk/Documents/lululu/pixel_audit/reference-studio-downloads.png');
    if (refFile.existsSync()) {
      final bytes = refFile.readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _refStatusBarImage = frame.image;
    }
  });

  setUp(() async {
    AudioManager().isMuted = true;
    SharedPreferences.setMockInitialValues({
      'LululuOnboardingDoneV1': true,
      'LululuCoinBalance': 12450,
      'LululuEnergyCount': 5,
      'LululuDiamondBalance': 86,
      'LululuAuthV1': '{"uid":"apple-123","displayName":"Apple Oyuncu","provider":"apple"}',
      'lululu_coins': 12450,
    });
    await ProgressManager().load();
    ProgressManager().coins = 12450;
    await LeaderboardService.instance.ensureLoaded();
    AdaptiveQualityScaler.instance.bootstrap(forceTier: QualityTier.medium);
  });

  Future<void> captureScreen({
    required WidgetTester tester,
    required Widget widget,
    required String outputPath,
    String? extraOutputPath,
    bool showStatusBar = false,
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: Container(
          width: 430,
          height: 932,
          color: const Color(0xFFF4F6FA),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildLululuTheme(),
            home: Container(
              color: const Color(0xFFF4F6FA),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MediaQuery(
                      data: MediaQueryData(
                        size: const Size(430, 932),
                        devicePixelRatio: 1.0,
                        padding: showStatusBar
                            ? const EdgeInsets.only(top: 35.4, bottom: 24)
                            : EdgeInsets.zero,
                        viewPadding: showStatusBar
                            ? const EdgeInsets.only(top: 35.4, bottom: 24)
                            : EdgeInsets.zero,
                      ),
                      child: TickerMode(
                        enabled: false,
                        child: widget,
                      ),
                    ),
                  ),
                  if (showStatusBar)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: MockStatusBarWidget(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await safePrimeAssets(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    final boundary = boundaryKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final outFile = File(outputPath);
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(pngBytes);
      if (extraOutputPath != null) {
        final extraFile = File(extraOutputPath);
        extraFile.parent.createSync(recursive: true);
        extraFile.writeAsBytesSync(pngBytes);
      }
      image.dispose();
      debugPrint('>>> Written $outputPath: ${pngBytes.length} bytes');
    });
    // Madde 99: yazılan yakalama dosyası doğrulanır (varlık + PNG imzası).
    // Bu helper'daki tüm Capture testleri bu doğrulamayı paylaşır.
    final writtenFile = File(outputPath);
    expect(writtenFile.existsSync(), isTrue, reason: outputPath);
    final writtenBytes = writtenFile.readAsBytesSync();
    expect(writtenBytes.length, greaterThan(8));
    expect(
      writtenBytes.sublist(0, 8),
      const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    );
    if (extraOutputPath != null) {
      final extraFile = File(extraOutputPath);
      expect(extraFile.existsSync(), isTrue, reason: extraOutputPath);
      expect(extraFile.lengthSync(), greaterThan(8));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('Capture Hub', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const HomeShell(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-hub.png',
      extraOutputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual.png',
    );
  });

  testWidgets('Capture Game (Suika)', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: GameScreen(
        level: CampaignDatabase.kitchenLevel1,
        arcade: true,
        prototypeVisualState: true,
      ),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-game.png',
    );
  });

  testWidgets('Capture Online', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const OnlineScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-online.png',
    );
  });

  testWidgets('Capture Chat', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const ChatScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-chat.png',
    );
  });

  testWidgets('Capture Studio Watch', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const StudioWatchScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-studio-watch.png',
    );
  });

  testWidgets('Capture Studio Create', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const StudioCreateScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-studio-create.png',
    );
  });

  testWidgets('Capture Studio Upload', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const StudioUploadScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-studio-upload.png',
    );
  });

  testWidgets('Capture Studio Gif', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const StudioGifScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-studio-gif.png',
    );
  });

  testWidgets('Capture Studio Downloads', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const StudioDownloadsScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-studio-downloads.png',
    );
  });

  testWidgets('Capture Result', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const GameResultScreen(
        score: 1741,
        bestScore: 4820,
        bestCombo: 6,
        merges: 18,
        coins: 0,
        stars: 2,
      ),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-result.png',
    );
  });

  testWidgets('Capture Account', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'LululuOnboardingDoneV1': true,
      'LululuCoinBalance': 12450,
      'LululuEnergyCount': 5,
      'LululuDiamondBalance': 86,
      'LululuAuthV1': '{"uid":"apple-123","displayName":"Apple Oyuncu","provider":"apple"}',
    });
    await captureScreen(
      tester: tester,
      widget: const AuthScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-account.png',
    );
  });

  testWidgets('Capture Scores', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const LeaderboardScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-scores.png',
    );
  });

  testWidgets('Capture Tasks', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const TasksScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-tasks.png',
    );
  });

  testWidgets('Capture Shop', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const ShopScreen(embedded: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-shop.png',
    );
  });

  testWidgets('Capture Modes', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const ModesScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-modes.png',
    );
  });

  testWidgets('Capture Tiers', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const TiersScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-tiers.png',
    );
  });

  testWidgets('Capture Profile', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const ProfileScreen(),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-profile.png',
    );
  });

  testWidgets('Capture Splash', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: SplashScreen(onDone: () {}),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-splash.png',
    );
  });

  testWidgets('Capture Mode m2048', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const Grid2048Screen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-m2048.png',
    );
  });

  testWidgets('Capture Mode balon', (WidgetTester tester) async {
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeBalloon,
      3260,
    );
    await captureScreen(
      tester: tester,
      widget: const BalloonPopScreen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-balon.png',
    );
  });

  testWidgets('Capture Mode match3', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const Match3Screen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-match3.png',
    );
  });

  testWidgets('Capture Mode bagla', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const ConnectPopScreen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-bagla.png',
    );
  });

  testWidgets('Capture Mode stack', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const StackDropScreen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-stack.png',
    );
  });

  testWidgets('Capture Mode terlik', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const TerlikTapScreen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-terlik.png',
    );
  });

  testWidgets('Capture Mode yuva', (WidgetTester tester) async {
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeYuva,
      1240,
    );
    await captureScreen(
      tester: tester,
      widget: const YuvaDefenseScreen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-yuva.png',
    );
  });

  testWidgets('Capture Mode osmantus', (WidgetTester tester) async {
    await captureScreen(
      tester: tester,
      widget: const OsmantusScreen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-osmantus.png',
    );
  });

  testWidgets('Capture Mode ciglik', (WidgetTester tester) async {
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeScream,
      2105,
    );
    await captureScreen(
      tester: tester,
      widget: const ScreamRoachScreen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-ciglik.png',
    );
  });

  testWidgets('Capture Mode makara', (WidgetTester tester) async {
    await LeaderboardService.instance.submitScore(
      LeaderboardService.modeMakarayiz,
      1760,
    );
    await captureScreen(
      tester: tester,
      widget: const MakarayizScreen(prototypeVisualState: true),
      showStatusBar: false,
      outputPath: '/Users/selcuk/Documents/lululu/pixel_audit/actual-makara.png',
    );
    debugPrint('>>> TEST FINISHED');
  });
}
