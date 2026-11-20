import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';
import '../services/online_notify_service.dart';
import '../widgets/home/lululu_dock_bar.dart';

/// 1:1 Pixel-Perfect OnlineScreen matching HTML prototype `#scr-online`
/// (`reference-online.png` & `reference-online-spec.json`).
class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  // B7/K19 — bellek-içi `_notified` bool'u kaldırıldı: tercih tek
  // kaynak [OnlineNotifyService]'tedir (kalıcı, hub ile paylaşılır).
  @override
  void initState() {
    super.initState();
    unawaited(OnlineNotifyService.instance.ensureLoaded());
  }

  // CSS filter: grayscale(.85) opacity(.75)
  static const List<double> _grayscale85Opacity75Matrix = <double>[
    0.3307, 0.6079, 0.0614, 0, 0,
    0.1807, 0.7579, 0.0614, 0, 0,
    0.1807, 0.6079, 0.2114, 0, 0,
    0,      0,      0,      0.75, 0,
  ];

  static TextStyle _baloo2({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    ).copyWith(
      fontFamily: 'Baloo 2',
      fontWeight: fontWeight,
      fontFamilyFallback: const ['Nunito'],
    );
  }

  static TextStyle _nunito({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    ).copyWith(
      fontFamily: 'Nunito',
      fontWeight: fontWeight,
      fontFamilyFallback: const ['Baloo 2'],
    );
  }

  void _closeOrPop() {
    AudioManager().playPop();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    // B16-online — yığında ekran yoksa (bağımsız/ilk açılış) hub
    // yedeğine git; gömülü kullanımda kabuk gezinmeyi yönetir.
    if (!widget.embedded) {
      goTo(context, LululuRoutes.hub, replace: true);
    }
  }

  /// B16-online — dock sekmeleri gerçek gezinme yapar: her sekme kendi
  /// rotasına gider (önceden her sekme yalnızca geri/pop yapıyordu).
  void _handleDockSelect(LululuDockTab tab) {
    AudioManager().playPop();
    final route = switch (tab) {
      LululuDockTab.home => LululuRoutes.hub,
      LululuDockTab.modes => LululuRoutes.modes,
      LululuDockTab.family => LululuRoutes.tiers,
      LululuDockTab.shop => LululuRoutes.shop,
      LululuDockTab.scores => LululuRoutes.scores,
    };
    goTo(context, route, replace: true);
  }

  Future<void> _toggleNotify() async {
    AudioManager().playPop();
    final subscribed = await OnlineNotifyService.instance.toggle();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF141B2A),
          content: Text(
            subscribed
                ? context.l10n.onlineNotifySignupSnack
                : context.l10n.onlineNotifyRemovedSnack,
            style: _nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildPageTitle(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: widget.embedded ? 24 : 120,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroCard(),
                          _buildFeatureList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!widget.embedded)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              height: 84,
              child: _OnlineFloatingDock(
                activeTab: LululuDockTab.home,
                onSelectTab: _handleDockSelect,
              ),
            ),
        ],
      ),
    );
  }

  /// `.page-title` -> height: 60, padding: 10px 14px 2px 14px, gap: 10px
  Widget _buildPageTitle() {
    return Container(
      height: 60,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: context.l10n.goBackLabel,
            child: GestureDetector(
            onTap: _closeOrPop,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A141B2A),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/design/ui/back_btn.png',
                width: 29,
                height: 29,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: Color(0xFF141B2A),
                ),
              ),
            ),
          ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                context.l10n.onlineModeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _baloo2(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF141B2A),
                  letterSpacing: -0.1,
                  height: 25.76 / 23.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Transform.rotate(
            angle: -3 * math.pi / 180,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2E000000),
                    offset: Offset(0, 2),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Text(
                context.l10n.comingSoon,
                style: _baloo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4A2E00),
                  letterSpacing: 0.66,
                  height: 17.05 / 11.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `.online-hero` -> margin: 12px 12px 0px (CSS margin collapse with .online-feats 10px), padding: 22px 16px 18px, borderRadius: 22
  Widget _buildHeroCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: CustomPaint(
        painter: const _OnlineBlurredRRectShadowPainter(
          color: Color(0x14141B2A),
          offset: Offset(0, 12),
          sigma: 10.0,
          radius: 22.0,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14141B2A),
                offset: Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix(
                          _grayscale85Opacity75Matrix,
                        ),
                        child: Image.asset(
                          'assets/design/ui/online_locked_bug_exact.webp',
                          width: 118,
                          height: 118,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: CustomPaint(
                        painter: const _OnlineBlurredRRectShadowPainter(
                          color: Color(0x4D000000),
                          offset: Offset(0, 3),
                          sigma: 3.0,
                          radius: 20.0,
                        ),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF141B2A),
                            border: Border.all(
                              color: Colors.white,
                              width: 2.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const CustomPaint(
                            size: Size(20, 20),
                            painter: _LockBadgeIconPainter(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 25.2,
                child: Text(
                  context.l10n.comingVerySoonCaps,
                  textAlign: TextAlign.center,
                  style: _baloo2(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF141B2A),
                    height: 25.2 / 24.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.onlineComingSoonBody,
                textAlign: TextAlign.center,
                style: _nunito(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF66738A),
                  letterSpacing: -0.02,
                  height: 18.6 / 13.5,
                ),
              ),
              const SizedBox(height: 16.0),
              ListenableBuilder(
                listenable: OnlineNotifyService.instance,
                builder: (context, _) {
                  final notified = OnlineNotifyService.instance.isSubscribed;
                  return Semantics(
                    button: true,
                    label: notified
                        ? context.l10n.notifyOnLabel
                        : context.l10n.notifyMe,
                    child: GestureDetector(
                  onTap: _toggleNotify,
                  child: CustomPaint(
                    painter: const _OnlineBlurredRRectShadowPainter(
                      color: Color(0x38000000),
                      offset: Offset(0, 9),
                      sigma: 6.5,
                      radius: 14.0,
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141B2A),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x8C000000),
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icons2/bell.png',
                            width: 21,
                            height: 21,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            notified ? context.l10n.notifyOnCaps : context.l10n.notifyMe,
                            style: _baloo2(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFF6B35),
                              letterSpacing: 0.6,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `.online-feats` -> margin: 10px 12px 0, gap: 10px
  Widget _buildFeatureList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9.9, 12, 10),
      child: Column(
        children: [
          // 12D1: görünür lobi girişi — sohbet lobisi ekranını açar.
          _buildFeatureCard(
            icon: Icons.chat_bubble_rounded,
            gradientColors: const [Color(0xFFF4538B), Color(0xFF9B5DE5)],
            title: context.l10n.chatLobbyTitle,
            subtitle: context.l10n.chatLobbySubtitle,
            onTap: () {
              AudioManager().playPop();
              goTo(context, LululuRoutes.chatLobby);
            },
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            iconAsset: 'assets/icons2/sword.png',
            gradientColors: const [Color(0xFFF4538B), Color(0xFFE01E5A)],
            title: context.l10n.onlineDuelTitle,
            subtitle: context.l10n.onlineDuelSubtitle,
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            iconAsset: 'assets/icons2/shield.png',
            gradientColors: const [Color(0xFF9B5DE5), Color(0xFF7C3AED)],
            title: context.l10n.onlineGuildWarsTitle,
            subtitle: context.l10n.onlineGuildWarsSubtitle,
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            iconAsset: 'assets/icons2/trophy.png',
            gradientColors: const [Color(0xFFFFCF3F), Color(0xFFFFB800)],
            title: context.l10n.onlineTournamentsTitle,
            subtitle: context.l10n.onlineTournamentsSubtitle,
          ),
        ],
      ),
    );
  }

  /// `.online-feat` -> height: 68, padding: 12px 14px, gap: 12px, borderRadius: 18
  ///
  /// 12D1: [onTap] verilirse kart dokunulabilir olur (lobi kartı);
  /// verilmezse eskisi gibi statik kalır. [icon] verilirse
  /// [iconAsset] yerine Material ikonu çizilir.
  Widget _buildFeatureCard({
    String? iconAsset,
    IconData? icon,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final card = Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12141B2A),
            offset: Offset(0, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: const Alignment(-0.34, -0.94),
                end: const Alignment(0.34, 0.94),
                colors: gradientColors,
              ),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 27, color: Colors.white)
                : Image.asset(
                    iconAsset!,
                    width: 27,
                    height: 27,
                    fit: BoxFit.contain,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 16.5,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF141B2A),
                        letterSpacing: -0.05,
                        height: 16.5 / 15.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 16.0,
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF66738A),
                        letterSpacing: 0.0,
                        height: 16.0 / 12.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _OnlineBlurredRRectShadowPainter extends CustomPainter {
  final Color color;
  final Offset offset;
  final double sigma;
  final double radius;

  const _OnlineBlurredRRectShadowPainter({
    required this.color,
    required this.offset,
    required this.sigma,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).shift(offset);
    final paint = Paint()
      ..color = color
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OnlineBlurredRRectShadowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.offset != offset ||
      oldDelegate.sigma != sigma ||
      oldDelegate.radius != radius;
}

class _LockBadgeIconPainter extends CustomPainter {
  const _LockBadgeIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.scale(scale, scale);

    final fillPaint = Paint()
      ..color = const Color(0xFFFFCF3F)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(5, 10.5, 14, 9.5),
        const Radius.circular(2.5),
      ),
      fillPaint,
    );

    final strokePaint = Paint()
      ..color = const Color(0xFFFFCF3F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shackle = Path()
      ..moveTo(8, 10.5)
      ..lineTo(8, 7.8)
      ..arcToPoint(
        const Offset(16, 7.8),
        radius: const Radius.circular(4),
        clockwise: true,
      )
      ..lineTo(16, 10.5);
    canvas.drawPath(shackle, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnlineFloatingDock extends StatelessWidget {
  final LululuDockTab activeTab;
  final ValueChanged<LululuDockTab> onSelectTab;

  const _OnlineFloatingDock({
    required this.activeTab,
    required this.onSelectTab,
  });

  static const _tabs = LululuDockTab.values;

  static String _label(AppLocalizations l10n, LululuDockTab tab) =>
      switch (tab) {
        LululuDockTab.home => l10n.navHome,
        LululuDockTab.modes => l10n.navModes,
        LululuDockTab.family => l10n.navFamily,
        LululuDockTab.shop => l10n.navShop,
        LululuDockTab.scores => l10n.navScores,
      };

  static String _icon(LululuDockTab tab) => switch (tab) {
        LululuDockTab.home => 'assets/icons2/home.png',
        LululuDockTab.modes => 'assets/icons2/target.png',
        LululuDockTab.family => 'assets/icons2/paw.png',
        LululuDockTab.shop => 'assets/icons2/cart.png',
        LululuDockTab.scores => 'assets/icons2/trophy.png',
      };

  static Widget _buildIconWithDropShadow(String asset, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, 2),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x47000000),
                    BlendMode.srcIn,
                  ),
                  child: Image.asset(
                    asset,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _OnlineBlurredRRectShadowPainter(
        color: Color(0x7A080B12),
        offset: Offset(0, 22),
        sigma: 19.0,
        radius: 42.0,
      ),
      child: Container(
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.72],
            colors: [
              Color(0xFF1E2538),
              Color(0xFF080B12),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x47080B12),
              offset: Offset(0, 7),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth =
                  (constraints.maxWidth - 14.0).clamp(100.0, 410.0);
              final tabWidth = usableWidth / _tabs.length;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: _OnlineDockSurfacePainter(),
                    ),
                  ),
                  Positioned(
                    left: 26,
                    right: 26,
                    top: 5,
                    height: 9,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.20),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 7.0 + activeTab.index * tabWidth,
                    top: 7.0,
                    width: tabWidth,
                    height: 64.0,
                    child: CustomPaint(
                      painter: const _OnlineBlurredRRectShadowPainter(
                        color: Color(0x47E01E5A),
                        offset: Offset(0, 10),
                        sigma: 9.0,
                        radius: 32.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xF0FFFFFF),
                            width: 2,
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.40, 0.74, 1.0],
                            colors: [
                              Color(0xFFFFE27A),
                              Color(0xFFFFB800),
                              Color(0xFFFF6B35),
                              Color(0xFFE01E5A),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4D000000),
                              offset: Offset(0, 5),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Stack(
                            children: [
                              const Positioned.fill(
                                child: CustomPaint(
                                  painter: _OnlineDockActiveIndInsetPainter(),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                right: 8,
                                top: 2,
                                height: 9,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0x61FFFFFF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(7),
                    child: Row(
                      children: [
                        for (final tab in _tabs)
                          Expanded(
                            child: Semantics(
                              button: true,
                              label: _label(context.l10n, tab),
                              selected: tab == activeTab,
                              child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelectTab(tab),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: tab == activeTab
                                      ? const Color(0x1FFFB800)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: SizedBox(
                                  height: 64,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.topCenter,
                                    children: [
                                      if (tab == activeTab)
                                        Positioned(
                                          top: 1.8,
                                          width: 42.4,
                                          height: 42.4,
                                          child: CustomPaint(
                                            painter:
                                                const _OnlineBlurredRRectShadowPainter(
                                              color: Color(0x3D000000),
                                              offset: Offset(0, 7),
                                              sigma: 6.0,
                                              radius: 21.2,
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x597A082E),
                                                    offset: Offset(0, 4),
                                                    blurRadius: 0,
                                                  ),
                                                ],
                                              ),
                                              child: ClipOval(
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    const Positioned.fill(
                                                      child: CustomPaint(
                                                        painter:
                                                            _OnlineDockCircleInsetPainter(
                                                          dy: -4.24,
                                                          color:
                                                              Color(0x1F080B12),
                                                        ),
                                                      ),
                                                    ),
                                                    _buildIconWithDropShadow(
                                                      _icon(tab),
                                                      35,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Positioned(
                                          top: 7.0,
                                          width: 40.0,
                                          height: 40.0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0x17FFFFFF),
                                              border: Border.all(
                                                color: const Color(0x2EFFFFFF),
                                                width: 2,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x4D000000),
                                                  offset: Offset(0, 3),
                                                  blurRadius: 0,
                                                ),
                                              ],
                                            ),
                                            child: ClipOval(
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const Positioned.fill(
                                                    child: CustomPaint(
                                                      painter:
                                                          _OnlineDockCircleInsetPainter(
                                                        dy: 2.0,
                                                        color:
                                                            Color(0x29FFFFFF),
                                                      ),
                                                    ),
                                                  ),
                                                  _buildIconWithDropShadow(
                                                    _icon(tab),
                                                    33,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        left: -4,
                                        right: -4,
                                        top: 49.0,
                                        child: Text(
                                          _label(context.l10n, tab),
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style: _OnlineScreenState._baloo2(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            height: 1.0,
                                            letterSpacing: -0.1,
                                            color: tab == activeTab
                                                ? Colors.white
                                                : const Color(0xA8FFFFFF),
                                            shadows: tab == activeTab
                                                ? const [
                                                    Shadow(
                                                      color:
                                                          Color(0x737A082E),
                                                      offset: Offset(0, 2),
                                                      blurRadius: 0,
                                                    ),
                                                  ]
                                                : const [
                                                    Shadow(
                                                      color:
                                                          Color(0xBF000000),
                                                      offset: Offset(0, 1),
                                                      blurRadius: 0,
                                                    ),
                                                  ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OnlineDockSurfacePainter extends CustomPainter {
  const _OnlineDockSurfacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.translate(size.width * 0.18, -size.height * 0.30);
    canvas.scale(size.width * 1.20, size.height * 1.60);
    final radialPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        1.0,
        const [Color(0x38FFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.48],
      );
    canvas.drawRect(const Rect.fromLTRB(-2, -2, 2, 2), radialPaint);
    canvas.restore();

    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    final topInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInsetPath, Paint()..color = const Color(0x29FFFFFF));

    final bottomInsetPath = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -7)),
    );
    canvas.drawPath(bottomInsetPath, Paint()..color = const Color(0x57000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnlineDockActiveIndInsetPainter extends CustomPainter {
  const _OnlineDockActiveIndInsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    final outerPath = Path()..addRRect(RRect.fromRectAndRadius(rect, radius));

    final topInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, 3)),
    );
    canvas.drawPath(topInset, Paint()..color = const Color(0x8CFFFFFF));

    final bottomInset = Path.combine(
      PathOperation.difference,
      outerPath,
      outerPath.shift(const Offset(0, -6)),
    );
    canvas.drawPath(bottomInset, Paint()..color = const Color(0x3D7A082E));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnlineDockCircleInsetPainter extends CustomPainter {
  final double dy;
  final Color color;

  const _OnlineDockCircleInsetPainter({required this.dy, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addOval(Offset.zero & size);
    final crescent = Path.combine(
      PathOperation.difference,
      outer,
      outer.shift(Offset(0, dy)),
    );
    canvas.drawPath(crescent, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _OnlineDockCircleInsetPainter oldDelegate) =>
      oldDelegate.dy != dy || oldDelegate.color != color;
}

