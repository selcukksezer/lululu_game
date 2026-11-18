import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/lululu_game_mode.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';
import '../services/progress_manager.dart';

String _trUpper(String input, Locale locale) {
  if (locale.languageCode != 'tr') {
    return input.toUpperCase();
  }
  return input
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .replaceAll('ğ', 'Ğ')
      .replaceAll('ü', 'Ü')
      .replaceAll('ş', 'Ş')
      .replaceAll('ö', 'Ö')
      .replaceAll('ç', 'Ç')
      .toUpperCase();
}

/// 11 OYUN MODU Screen (`#scr-modes`) — Pixel-perfect 1:1 implementation
/// of `LÜLÜLÜ UI:UX Tasarım.html`.
class ModesScreen extends StatefulWidget {
  final ValueChanged<LululuGameMode>? onSelectMode;
  final VoidCallback? onBack;
  final bool showBottomNav;
  final bool embedded;

  const ModesScreen({
    super.key,
    this.onSelectMode,
    this.onBack,
    this.showBottomNav = true,
    this.embedded = false,
  });

  @override
  State<ModesScreen> createState() => _ModesScreenState();
}

class _ModesScreenState extends State<ModesScreen> {
  String _formatNumber(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _openMode(LululuGameMode mode) {
    AudioManager().playPop();
    if (widget.onSelectMode != null) {
      widget.onSelectMode!(mode);
      return;
    }
    openGameMode(context, mode.kind);
  }

  @override
  Widget build(BuildContext context) {
    final pm = ProgressManager();
    final mqTop = MediaQuery.of(context).padding.top;

    const modes = LululuGameMode.catalog;
    final parentHasExtendBody =
        Scaffold.maybeOf(context)?.widget.extendBody == true;
    final renderDock =
        widget.showBottomNav && !widget.embedded && !parentHasExtendBody;

    return ListenableBuilder(
      listenable: pm,
      builder: (context, _) {
        final l10n = context.l10n;
        final rawCoins = pm.coins;
        final coinsText = _formatNumber(rawCoins);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          // Üst pay zaten mqTop / prototip durum çubuğu ile veriliyor
          // (top: false). Alt çentik payı yalnız bağımsız modda;
          // gömülü modda alt boşluğu HomeShell merkezi verir.
          body: SafeArea(
            top: false,
            bottom: !widget.embedded,
            child: Stack(
              children: [
              Column(
                children: [
                  if (mqTop > 0)
                    SizedBox(height: mqTop)
                  else
                    const _ModesPrototypeStatusBar(),
                  // .page-title { display:flex; align-items:center; gap:10px; padding:10px 14px 2px; height:60px }
                  SizedBox(
                    height: 60,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Semantics(
                            button: true,
                            label: l10n.goBackLabel,
                            child: GestureDetector(
                            onTap: () {
                              AudioManager().playPop();
                              if (widget.onBack != null) {
                                widget.onBack!();
                              } else {
                                Navigator.of(context).maybePop();
                              }
                            },
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
                              child: Center(
                                child: Image.asset(
                                  'assets/design/ui/back_btn.png',
                                  width: 29,
                                  height: 29,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          )),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Transform.translate(
                                offset: const Offset(0, 1.0),
                                child: Text(
                                  l10n.modesTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Baloo 2',
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF141B2A),
                                    letterSpacing: 0,
                                    height: 1.12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // span.pill { background: rgba(8,11,18,.82); color:#fff; padding:5px 12px 5px 6px; border-radius:999px; box-shadow:0 3px 0 rgba(0,0,0,.35) }
                          Container(
                            height: 35,
                            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF33363C),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  offset: Offset(0, 3),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/design/ui/res_coin.png',
                                  width: 25,
                                  height: 25,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  coinsText,
                                  style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                    color: Colors.white,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // #modeList.scroll { padding: 12px 0 120px }
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12.2, 12, 120),
                      itemCount: modes.length,
                      itemBuilder: (context, i) {
                        final m = modes[i];
                        final savedScore = pm.getModeBestScore(m.bestScoreKey);
                        final score =
                            savedScore > 0 ? savedScore : m.defaultBestScore;
                        final bestStr = _formatNumber(score);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9.97),
                          child: _buildModeRow(m, bestStr),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (renderDock)
                const Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  height: 84,
                  child: _ModesFloatingDock(activeIndex: 1),
                ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildModeRow(LululuGameMode mode, String bestStr) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return Semantics(
      button: true,
      label: l10n.modeOpenLabel(
        _trUpper(mode.titleFor(locale), locale),
        mode.subtitleFor(locale),
        bestStr,
      ),
      child: GestureDetector(
      onTap: () => _openMode(mode),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 96.1),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                // .thumb { width:58px; height:58px; border-radius:16px; position:relative; overflow:hidden }
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          color: mode.thumbBgColor,
                          child: Center(
                            child: Image.asset(
                              mode.stickerAsset,
                              width: 56,
                              height: 56,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -5,
                          bottom: -5,
                          width: 29,
                          height: 56,
                          child: Image.asset(
                            mode.badgeIconAsset,
                            width: 29,
                            height: 29,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // .tx { flex:1; min-width:0 }
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 21.08, bottom: 22.0),
                        child: Text(
                          _trUpper(mode.titleFor(locale), locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Baloo 2',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                            color: Color(0xFF141B2A),
                            height: 1.125,
                          ),
                        ),
                      ),
                      Text(
                        l10n.modeBestLine(mode.subtitleFor(locale), bestStr),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: Color(0xFF66738A),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // .go { width:40px; height:40px; border-radius:50%; background:#FFB800; box-shadow:0 3px 0 #B97A00 }
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB800),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFB97A00),
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/icons/play.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // .badge { position:absolute; top:-7px; right:12px; transform:rotate(-4deg) }
          Positioned(
            top: -7,
            right: 12,
            child: Transform.rotate(
              angle: -4 * math.pi / 180,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: mode.badgeColor,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000),
                      offset: Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  mode.badgeLabelFor(locale),
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: true,
                    applyHeightToLastDescent: true,
                  ),
                  style: TextStyle(
                    fontFamily: 'Baloo 2',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.66,
                    color: mode.badgeTextColor,
                    height: 1.64,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class _ModesPrototypeStatusBar extends StatelessWidget {
  const _ModesPrototypeStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '09:41',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                color: Color(0xFF0E1320),
                height: 1.55,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CustomPaint(
                  size: Size(15, 15),
                  painter: _ModesSignalIconPainter(),
                ),
                SizedBox(width: 5),
                CustomPaint(
                  size: Size(15, 15),
                  painter: _ModesBatteryIconPainter(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModesSignalIconPainter extends CustomPainter {
  const _ModesSignalIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = const Color(0xFF0E1320)
      ..style = PaintingStyle.fill;
    canvas.drawRect(const Rect.fromLTWH(2, 17, 3, 4), paint);
    canvas.drawRect(const Rect.fromLTWH(7.5, 13, 3, 8), paint);
    canvas.drawRect(const Rect.fromLTWH(13, 9, 3, 12), paint);
    canvas.drawRect(const Rect.fromLTWH(18.5, 5, 3, 16), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModesBatteryIconPainter extends CustomPainter {
  const _ModesBatteryIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);
    final strokePaint = Paint()
      ..color = const Color(0xFF0E1320)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2.5, 8, 17, 9),
        const Radius.circular(2.5),
      ),
      strokePaint,
    );
    final fillPaint = Paint()
      ..color = const Color(0xFF0E1320)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4.5, 10, 10, 5),
        const Radius.circular(1),
      ),
      fillPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModesDockSurfacePainter extends CustomPainter {
  const _ModesDockSurfacePainter();

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

class _ModesDockActiveIndInsetPainter extends CustomPainter {
  const _ModesDockActiveIndInsetPainter();

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

class _ModesDockCircleInsetPainter extends CustomPainter {
  final double dy;
  final Color color;

  const _ModesDockCircleInsetPainter({required this.dy, required this.color});

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
  bool shouldRepaint(covariant _ModesDockCircleInsetPainter oldDelegate) =>
      oldDelegate.dy != dy || oldDelegate.color != color;
}

class _ModesInactiveDockCirclePainter extends CustomPainter {
  const _ModesInactiveDockCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outerCircle = Path()..addOval(rect);
    final shadowRect = rect.shift(const Offset(0, 3));
    final shadowPath = Path.combine(
      PathOperation.difference,
      Path()..addOval(shadowRect),
      outerCircle,
    );
    canvas.drawPath(
      shadowPath,
      Paint()..color = const Color(0x73000000),
    );

    final innerRect = rect.deflate(2);
    canvas.drawOval(
      innerRect,
      Paint()..color = const Color(0x17FFFFFF),
    );

    final insetTopPath = Path.combine(
      PathOperation.difference,
      Path()..addOval(innerRect),
      Path()..addOval(innerRect.shift(const Offset(0, 2))),
    );
    canvas.drawPath(
      insetTopPath,
      Paint()..color = const Color(0x29FFFFFF),
    );

    final borderPath = Path.combine(
      PathOperation.difference,
      outerCircle,
      Path()..addOval(innerRect),
    );
    canvas.drawPath(
      borderPath,
      Paint()..color = const Color(0x2EFFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ModesFloatingDock extends StatelessWidget {
  final int activeIndex;
  const _ModesFloatingDock({required this.activeIndex});

  // S3#27: dock etiketleri l10n nav* anahtarlarından gelir (build'de
  // `labels`); burada yalnız ikon yolları durur.
  static const _tabIcons = [
    'assets/icons2/home.png',
    'assets/icons2/target.png',
    'assets/icons2/paw.png',
    'assets/icons2/cart.png',
    'assets/icons2/trophy.png',
  ];

  void _onTapTab(BuildContext context, int index) {
    AudioManager().playPop();
    if (index == activeIndex) return;
    final route = switch (index) {
      0 => LululuRoutes.hub,
      1 => LululuRoutes.modes,
      2 => LululuRoutes.tiers,
      3 => LululuRoutes.shop,
      4 => LululuRoutes.scores,
      _ => LululuRoutes.hub,
    };
    goTo(context, route, replace: true);
  }

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
    final l10n = context.l10n;
    final labels = <String>[
      l10n.navHome,
      l10n.navModes,
      l10n.navFamily,
      l10n.navShop,
      l10n.navScores,
    ];
    return Container(
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.72],
          colors: [Color(0xFF1E2538), Color(0xFF080B12)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47080B12),
            offset: Offset(0, 7),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x62080B12),
            offset: Offset(0, 22),
            blurRadius: 38,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final innerW = (constraints.maxWidth - 14.0).clamp(100.0, 410.0);
            final tabW = innerW / _tabIcons.length;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(
                  child: CustomPaint(
                    painter: _ModesDockSurfacePainter(),
                  ),
                ),
                Positioned(
                  left: 26,
                  right: 26,
                  top: 5,
                  height: 9,
                  child: IgnorePointer(
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
                ),
                Positioned(
                  left: 7.0 + activeIndex * tabW,
                  top: 7.0,
                  width: tabW,
                  height: 64.0,
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
                          color: Color(0x26E01E5A),
                          offset: Offset(0, 10),
                          blurRadius: 18,
                        ),
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
                              painter: _ModesDockActiveIndInsetPainter(),
                            ),
                          ),
                          Positioned(
                            left: 10,
                            right: 10,
                            top: 4,
                            height: 9,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xA6FFFFFF),
                                    Color(0x00FFFFFF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Row(
                    children: List.generate(_tabIcons.length, (i) {
                      final active = i == activeIndex;
                      return Expanded(
                        child: Semantics(
                          button: true,
                          label: labels[i],
                          selected: active,
                          child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _onTapTab(context, i),
                          child: SizedBox(
                            height: 64,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                if (active)
                                  Positioned(
                                    top: 1.8,
                                    width: 42.4,
                                    height: 42.4,
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
                                            color: Color(0x52000000),
                                            offset: Offset(0, 7),
                                            blurRadius: 12,
                                          ),
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
                                                    _ModesDockCircleInsetPainter(
                                                  dy: -4.24,
                                                  color: Color(0x1F080B12),
                                                ),
                                              ),
                                            ),
                                            _buildIconWithDropShadow(
                                              _tabIcons[i],
                                              35,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Positioned(
                                    top: 7.0,
                                    width: 40.0,
                                    height: 40.0,
                                    child: CustomPaint(
                                      painter:
                                          const _ModesInactiveDockCirclePainter(),
                                      child: Center(
                                        child: _buildIconWithDropShadow(
                                          _tabIcons[i],
                                          33,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 46.0,
                                  child: Center(
                                    child: Text(
                                      labels[i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textHeightBehavior:
                                          const TextHeightBehavior(
                                        applyHeightToFirstAscent: false,
                                        applyHeightToLastDescent: false,
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Baloo 2',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                        letterSpacing: 0.4,
                                        color: active
                                            ? Colors.white
                                            : const Color(0xA8FFFFFF),
                                        shadows: active
                                            ? const [
                                                Shadow(
                                                  color: Color(0x737A082E),
                                                  offset: Offset(0, 2),
                                                  blurRadius: 0,
                                                ),
                                              ]
                                            : const [
                                                Shadow(
                                                  color: Color(0xBF000000),
                                                  offset: Offset(0, 1),
                                                  blurRadius: 0,
                                                ),
                                              ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
