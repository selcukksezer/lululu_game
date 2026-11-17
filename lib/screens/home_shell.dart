import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';
import '../widgets/home/lululu_dock_bar.dart';
import '../widgets/shop_dialog.dart';
import 'game_selector_screen.dart';
import 'leaderboard_screen.dart';
import 'modes_screen.dart';
import 'tiers_screen.dart';

/// Root shell: 5 sekme — ANA SAYFA / MODLAR / AİLEM / MAĞAZA / SKORLAR.
///
/// Floating dock, Scaffold'un bottomNavigationBar'ı yerine
/// `extendBody: true` + Stack ile içeriğin ÜSTÜNE konur; içerik dock'un
/// altından kayar. ANA SAYFA açık tema (paper), diğer sekmeler koyu.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = LululuDockTab.home});

  final LululuDockTab initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late LululuDockTab _tab = widget.initialTab;

  @override
  void didUpdateWidget(covariant HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tab = widget.initialTab;
    }
  }

  bool get _lightHome => _tab == LululuDockTab.home;

  void _select(LululuDockTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  Widget _buildActiveTab() => switch (_tab) {
    LululuDockTab.home => GameSelectorScreen(
      onOpenShop: () => _select(LululuDockTab.shop),
    ),
    LululuDockTab.modes => const ModesScreen(embedded: true),
    LululuDockTab.family => const TiersScreen(embedded: true),
    LululuDockTab.shop => const ShopScreen(embedded: true),
    LululuDockTab.scores => const LeaderboardScreen(embedded: true),
  };

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        extendBody: true,
        backgroundColor:
            _lightHome ? LululuColors.paper : LululuColors.carbonVoid,
        body: Stack(
          children: [
            // İçerik: dock'un altından kayar.
            Positioned.fill(
              child: _buildActiveTab(),
            ),
            // Floating dock: içeriğin üstünde (etkileşim katmanı).
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.0,
                child: LululuDockBar(
                  selected: _tab,
                  onSelect: _select,
                ),
              ),
            ),
            // CSS v5 dock specular highlights + active label color (--paper)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: _DockVisualOverlay(selected: _tab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockVisualOverlay extends StatelessWidget {
  const _DockVisualOverlay({required this.selected});

  final LululuDockTab selected;

  static const _tabs = LululuDockTab.values;

  static String _label(LululuDockTab tab) => switch (tab) {
    LululuDockTab.home => 'ANA SAYFA',
    LululuDockTab.modes => 'MODLAR',
    LululuDockTab.family => 'AİLEM',
    LululuDockTab.shop => 'MAĞAZA',
    LululuDockTab.scores => 'SKORLAR',
  };

  static String _assetIcon(LululuDockTab tab) => switch (tab) {
    LululuDockTab.home => 'assets/design/ui/icons2/home.png',
    LululuDockTab.modes => 'assets/design/ui/icons2/target.png',
    LululuDockTab.family => 'assets/design/ui/icons2/paw.png',
    LululuDockTab.shop => 'assets/design/ui/icons2/cart.png',
    LululuDockTab.scores => 'assets/design/ui/icons2/trophy.png',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: CustomPaint(
            painter: const _DockRealShadowPainter(
              radius: 42,
              shadows: [
                BoxShadow(
                  color: Color(0x7A080B12),
                  blurRadius: 38,
                  offset: Offset(0, 22),
                ),
                BoxShadow(
                  color: Color(0x47080B12),
                  blurRadius: 0,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Container(
              width: double.infinity,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 3),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.72],
                  colors: [Color(0xFF2A3042), Color(0xFF080B12)],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: CustomPaint(
                  painter: const _DockShellHighlightPainter(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // .dock::before
                      Positioned(
                        left: 23,
                        right: 23,
                        top: 5,
                        height: 9,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(7),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final usableWidth =
                                constraints.maxWidth.clamp(100.0, 390.0);
                            final tabWidth = usableWidth / _tabs.length;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: selected.index * tabWidth,
                                  top: 0,
                                  width: tabWidth,
                                  height: 64,
                                  child: CustomPaint(
                                    painter: const _DockRealShadowPainter(
                                      radius: 32,
                                      shadows: [
                                        BoxShadow(
                                          color: Color(0x47E01E5A),
                                          blurRadius: 18,
                                          offset: Offset(0, 10),
                                        ),
                                        BoxShadow(
                                          color: Color(0x4D000000),
                                          blurRadius: 0,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xF0FFFFFF),
                                          width: 2,
                                        ),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: [0.0, 0.40, 0.74, 1.0],
                                          colors: [
                                            Color(0xFFFFD34D),
                                            Color(0xFFFFB800),
                                            Color(0xFFFF6B35),
                                            Color(0xFFE01E5A),
                                          ],
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        child: Stack(
                                          children: [
                                            const Positioned(
                                              left: 0,
                                              right: 0,
                                              top: 0,
                                              height: 3,
                                              child: ColoredBox(
                                                color: Color(0x8CFFFFFF),
                                              ),
                                            ),
                                            const Positioned(
                                              left: 0,
                                              right: 0,
                                              bottom: 0,
                                              height: 6,
                                              child: ColoredBox(
                                                color: Color(0x3D7A082E),
                                              ),
                                            ),
                                            Positioned(
                                              left: 8,
                                              right: 8,
                                              top: 2,
                                              height: 9,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0x61FFFFFF),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    999,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    for (final tab in _tabs)
                                      Expanded(
                                        child: SizedBox(
                                          height: 64,
                                          child: _buildItem(
                                            tab: tab,
                                            active: tab == selected,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem({required LululuDockTab tab, required bool active}) {
    final label = _label(tab);
    final iconAsset = _assetIcon(tab);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: active ? const Color(0x1FFFB800) : Colors.transparent,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 7,
            left: 0,
            right: 0,
            child: Center(
              child: Transform.translate(
                offset: Offset(0, active ? -4 : 0),
                child: Transform.scale(
                  scale: active ? 1.06 : 1.0,
                  child: CustomPaint(
                    painter: _DockRealShadowPainter(
                      radius: 20,
                      shadows: active
                          ? const [
                              BoxShadow(
                                color: Color(0x3D000000),
                                blurRadius: 12,
                                offset: Offset(0, 7),
                              ),
                              BoxShadow(
                                color: Color(0x597A082E),
                                blurRadius: 0,
                                offset: Offset(0, 4),
                              ),
                            ]
                          : const [
                              BoxShadow(
                                color: Color(0x4D000000),
                                blurRadius: 0,
                                offset: Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? Colors.white : const Color(0x17FFFFFF),
                        border: Border.all(
                          color:
                              active ? Colors.white : const Color(0x2EFFFFFF),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (active)
                              const Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                height: 4,
                                child: ColoredBox(color: Color(0x1F080B12)),
                              )
                            else
                              const Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: 2,
                                child: ColoredBox(color: Color(0x29FFFFFF)),
                              ),
                            Image.asset(
                              iconAsset,
                              width: 33,
                              height: 33,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.star_rounded,
                                size: 26,
                                color: active
                                    ? const Color(0xFF141B2A)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 49.0,
            left: 0,
            right: 0,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: GoogleFonts.baloo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: 0,
                    color: active ? Colors.white : const Color(0xA8FFFFFF),
                    shadows: active
                        ? const [
                            Shadow(
                              color: Color(0x737A082E),
                              offset: Offset(0, 2),
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DockRealShadowPainter extends CustomPainter {
  const _DockRealShadowPainter({
    required this.radius,
    required this.shadows,
  });

  final double radius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (final s in shadows) {
      final spreadRect = rect.inflate(s.spreadRadius).shift(s.offset);
      final rrect = RRect.fromRectAndRadius(
        spreadRect,
        Radius.circular((radius + s.spreadRadius).clamp(0.0, 999.0)),
      );
      final paint = Paint()..color = s.color;
      if (s.blurRadius > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, s.blurSigma);
      }
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DockRealShadowPainter oldDelegate) => false;
}

class _DockShellHighlightPainter extends CustomPainter {
  const _DockShellHighlightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(999));

    // radial-gradient(120% 160% at 18% -30%, rgba(255,255,255,.22), rgba(255,255,255,0) 48%)
    canvas.save();
    final cx = size.width * 0.18;
    final cy = -size.height * 0.30;
    final rx = size.width * 1.20 * 0.48;
    final ry = size.height * 1.60 * 0.48;
    canvas.translate(cx, cy);
    canvas.scale(1.0, ry / rx);
    final radialPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx));
    canvas.drawCircle(Offset.zero, rx, radialPaint);
    canvas.restore();

    // inset 0 3px 0 rgba(255,255,255,.16)
    final topInsetPath = Path.combine(
      PathOperation.difference,
      Path()..addRRect(rrect),
      Path()..addRRect(rrect.shift(const Offset(0, 3))),
    );
    canvas.drawPath(topInsetPath, Paint()..color = const Color(0x29FFFFFF));

    // inset 0 -7px 0 rgba(0,0,0,.34)
    final bottomInsetPath = Path.combine(
      PathOperation.difference,
      Path()..addRRect(rrect),
      Path()..addRRect(rrect.shift(const Offset(0, -7))),
    );
    canvas.drawPath(bottomInsetPath, Paint()..color = const Color(0x57000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
