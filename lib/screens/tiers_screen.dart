import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../navigation/game_routes.dart';
import '../services/audio_manager.dart';

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

/// Nadirlik etiketlerinin EN karşılıkları (TR metin aynen korunur;
/// bu ekranın kendi veri listesindeki yazımlarla birebir eşleşir).
const _kRarityEn = <String, String>{
  'Sıradan': 'Common',
  'Seyrek': 'Uncommon',
  'Nadir': 'Rare',
  'Destansı': 'Epic',
  'Efsanevi': 'Legendary',
  'Mitik': 'Mythic',
  'Gizli': 'Secret',
  'Evrim Kristali': 'Evolution Crystal',
  'EFSANEVİ': 'LEGENDARY',
  'DESTANSI': 'EPIC',
  'MİTİK': 'MYTHIC',
  'KOZMİK': 'COSMIC',
  'ZİRVE': 'SUMMIT',
};

String _rarityLabel(BuildContext context, String rarity) {
  if (Localizations.localeOf(context).languageCode == 'en') {
    return _kRarityEn[rarity] ?? rarity;
  }
  return rarity;
}

class _BugTierInfo {
  final int tier;
  final String name;
  final String rarity;
  final String points;
  final String asset;
  final String quote;

  const _BugTierInfo({
    required this.tier,
    required this.name,
    required this.rarity,
    required this.points,
    required this.asset,
    required this.quote,
  });
}

/// BÖCEK AİLESİ (`#scr-tiers`) — Pixel-perfect 1:1 implementation
/// of `LÜLÜLÜ UI:UX Tasarım.html`.
class TiersScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool showBottomNav;
  final bool embedded;

  const TiersScreen({
    super.key,
    this.onBack,
    this.showBottomNav = true,
    this.embedded = false,
  });

  @override
  State<TiersScreen> createState() => _TiersScreenState();
}

class _TiersScreenState extends State<TiersScreen> {
  List<_BugTierInfo> _tiers(AppLocalizations l10n) => [
    _BugTierInfo(
      tier: 1,
      name: l10n.tierRowName1,
      rarity: 'Sıradan',
      points: '10',
      asset: 'assets/bugs/tier1_hd.png',
      quote: l10n.tierRowQuote1,
    ),
    _BugTierInfo(
      tier: 2,
      name: l10n.tierRowName2,
      rarity: 'Seyrek',
      points: '25',
      asset: 'assets/bugs/tier2_hd.png',
      quote: l10n.tierRowQuote2,
    ),
    _BugTierInfo(
      tier: 3,
      name: l10n.tierRowName3,
      rarity: 'Nadir',
      points: '50',
      asset: 'assets/bugs/tier3_hd.png',
      quote: l10n.tierRowQuote3,
    ),
    _BugTierInfo(
      tier: 4,
      name: l10n.tierRowName4,
      rarity: 'Destansı',
      points: '100',
      asset: 'assets/bugs/tier4_hd.png',
      quote: l10n.tierRowQuote4,
    ),
    _BugTierInfo(
      tier: 5,
      name: l10n.tierRowName5,
      rarity: 'Efsanevi',
      points: '200',
      asset: 'assets/bugs/tier5_hd.webp',
      quote: l10n.tierRowQuote5,
    ),
    _BugTierInfo(
      tier: 6,
      name: l10n.tierRowName6,
      rarity: 'Mitik',
      points: '400',
      asset: 'assets/bugs/tier6_hd.png',
      quote: l10n.tierRowQuote6,
    ),
    _BugTierInfo(
      tier: 7,
      name: l10n.tierRowName7,
      rarity: 'Gizli',
      points: '800',
      asset: 'assets/bugs/tier7_hd.png',
      quote: l10n.tierRowQuote7,
    ),
    _BugTierInfo(
      tier: 8,
      name: l10n.tierRowName8,
      rarity: 'Evrim Kristali',
      points: '1.600',
      asset: 'assets/bugs/tier8_hd.png',
      quote: l10n.tierRowQuote8,
    ),
    _BugTierInfo(
      tier: 9,
      name: l10n.tierRowName9,
      rarity: 'EFSANEVİ',
      points: '3.200',
      asset: 'assets/bugs/tier9_hd.png',
      quote: l10n.tierRowQuote9,
    ),
    _BugTierInfo(
      tier: 10,
      name: l10n.tierRowName10,
      rarity: 'DESTANSI',
      points: '6.400',
      asset: 'assets/bugs/tier10_hd.png',
      quote: l10n.tierRowQuote10,
    ),
    _BugTierInfo(
      tier: 11,
      name: l10n.tierRowName11,
      rarity: 'MİTİK',
      points: '12.800',
      asset: 'assets/bugs/tier11_hd.png',
      quote: l10n.tierRowQuote11,
    ),
    _BugTierInfo(
      tier: 12,
      name: l10n.tierRowName12,
      rarity: 'KOZMİK',
      points: '25.600',
      asset: 'assets/bugs/tier12_hd.png',
      quote: l10n.tierRowQuote12,
    ),
    _BugTierInfo(
      tier: 13,
      name: l10n.tierRowName13,
      rarity: 'ZİRVE',
      points: '51.200',
      asset: 'assets/bugs/tier13_hd.png',
      quote: l10n.tierRowQuote13,
    ),
  ];

  void _onTapTier(_BugTierInfo info) {
    if (info.tier >= 1 && info.tier <= 8) {
      AudioManager().playTierVoice(info.tier);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${info.name}: “${info.quote}”',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          duration: const Duration(milliseconds: 1800),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF141B2A),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mqTop = MediaQuery.of(context).padding.top;
    final parentHasExtendBody =
        Scaffold.maybeOf(context)?.widget.extendBody == true;
    final renderDock =
        widget.showBottomNav && !widget.embedded && !parentHasExtendBody;
    final tiers = _tiers(context.l10n);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mqTop > 0)
                SizedBox(height: mqTop)
              else
                const _TiersPrototypeStatusBar(),
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
                        label: context.l10n.goBackLabel,
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
                      ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Transform.translate(
                          offset: const Offset(0, 1.0),
                          child: Text(
                            context.l10n.bugFamilyTitle,
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
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 2.8, 16, 0),
                child: Text(
                  context.l10n.bugFamilySubtitle,
                  strutStyle: StrutStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    height: 1.62,
                    forceStrutHeight: true,
                  ),
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF66738A),
                    letterSpacing: 0,
                    height: 1.55,
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 134),
                  children: [
                    for (int i = 0; i < tiers.length; i++) ...[
                      _buildEvoRow(tiers[i]),
                      if (i < tiers.length - 1) _buildEvoArrow(),
                    ],
                  ],
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
              child: _TiersFloatingDock(activeIndex: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildEvoRow(_BugTierInfo t) {
    return Semantics(
      button: true,
      label: '${context.l10n.tierLabel(t.tier)}, ${_trUpper(t.name, Localizations.localeOf(context))}, ${_rarityLabel(context, t.rarity)}',
      child: GestureDetector(
        onTap: () => _onTapTier(t),
        child: Container(
          height: 72,
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F141B2A),
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // .evo-tno
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF080B12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Transform.translate(
                  offset: const Offset(0, -1.0),
                  child: Text(
                    'T${t.tier}',
                    style: const TextStyle(
                      fontFamily: 'Baloo 2',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFB800),
                      letterSpacing: 0.48,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // .evo-bug
              Image.asset(
                t.asset,
                width: 56,
                height: 56,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              // .evo-tx
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -1.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _trUpper(t.name, Localizations.localeOf(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Baloo 2',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          color: Color(0xFF141B2A),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _rarityLabel(context, t.rarity),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          color: Color(0xFF66738A),
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // .evo-pts
              Transform.translate(
                offset: const Offset(0, -1.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/design/ui/res_star.png',
                      width: 21,
                      height: 21,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 5),
                    Transform.translate(
                      offset: const Offset(0, -1.0),
                      child: Text(
                        '+${t.points}',
                        style: const TextStyle(
                          fontFamily: 'Baloo 2',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          color: Color(0xFF8A6D00),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvoArrow() {
    return const SizedBox(
      height: 26,
      child: Center(
        child: CustomPaint(
          size: Size(20, 20),
          painter: _EvoArrowPainter(),
        ),
      ),
    );
  }
}

class _TiersPrototypeStatusBar extends StatelessWidget {
  const _TiersPrototypeStatusBar();

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
                  painter: _TiersSignalIconPainter(),
                ),
                SizedBox(width: 5),
                CustomPaint(
                  size: Size(15, 15),
                  painter: _TiersBatteryIconPainter(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TiersSignalIconPainter extends CustomPainter {
  const _TiersSignalIconPainter();

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

class _TiersBatteryIconPainter extends CustomPainter {
  const _TiersBatteryIconPainter();

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

class _EvoArrowPainter extends CustomPainter {
  const _EvoArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFB800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * (size.width / 24.0)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    final path = Path()
      ..moveTo(12 * sx, 4 * sy)
      ..lineTo(12 * sx, 17 * sy)
      ..moveTo(12 * sx, 17 * sy)
      ..lineTo(17.5 * sx, 11.5 * sy)
      ..moveTo(12 * sx, 17 * sy)
      ..lineTo(6.5 * sx, 11.5 * sy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TiersDockSurfacePainter extends CustomPainter {
  const _TiersDockSurfacePainter();

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

class _TiersDockActiveIndInsetPainter extends CustomPainter {
  const _TiersDockActiveIndInsetPainter();

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

class _TiersDockCircleInsetPainter extends CustomPainter {
  final double dy;
  final Color color;

  const _TiersDockCircleInsetPainter({required this.dy, required this.color});

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
  bool shouldRepaint(covariant _TiersDockCircleInsetPainter oldDelegate) =>
      oldDelegate.dy != dy || oldDelegate.color != color;
}

class _TiersInactiveDockCirclePainter extends CustomPainter {
  const _TiersInactiveDockCirclePainter();

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

class _TiersFloatingDock extends StatelessWidget {
  final int activeIndex;
  const _TiersFloatingDock({required this.activeIndex});

  // S3#27: dock etiketleri tek kaynaktan (nav* anahtarları); bu
  // dosyadaki tekrar kaldırıldı. İkonlar const kalır, etiketler
  // build'de l10n'den okunur.
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
                    painter: _TiersDockSurfacePainter(),
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
                              painter: _TiersDockActiveIndInsetPainter(),
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
                                                    _TiersDockCircleInsetPainter(
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
                                          const _TiersInactiveDockCirclePainter(),
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
                        ),
                        ),
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
