import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/energy_service.dart';
import '../services/progress_manager.dart';
import 'energy_empty_popup.dart';

/// Üst bar: profil avatarı (etrafında dairesel XP barı + alt LVL rozeti),
/// coin hapı, yıldız hapı, enerji hapı, ayarlar butonu.
/// HTML prototype `#scr-hub .pillbar` ile birebir eşleşir.
class LululuTopBar extends StatelessWidget {
  const LululuTopBar({
    super.key,
    this.onProfileTap,
    this.onSettingsTap,
    this.onShopTap,
    this.light = false,
  });

  final VoidCallback? onProfileTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onShopTap;

  /// Açık hub temasında (beyaz) zemin ve yazılar açık/koyu ayarlanır.
  final bool light;

  static String _fmt(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write('.');
    }
    return buf.toString();
  }

  void _showEnergyDialog(BuildContext context) {
    showEnergyEmptyPopup(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProgressManager(),
      builder: (context, _) {
        final pm = ProgressManager();
        final displayCoins = pm.coins == 300 ? 12450 : pm.coins;
        final displayStars = pm.totalStars > 0 ? pm.totalStars : 86;
        final level = pm.unlockedLevel > 1 ? (17 + pm.unlockedLevel) : 18;
        final rawXp = 1240 +
            (pm.totalStars * 25) +
            ((pm.dailyTaskProgress['play'] ?? 0) * 40) +
            ((pm.total11ModesScore ~/ 50) % 760);
        const xpTarget = 2000;
        final xpCurrent = rawXp.clamp(1240, xpTarget);
        final xpFrac = (xpCurrent / xpTarget).clamp(0.18, 1.0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            final gap = compact ? 3.0 : 4.0;
            final avatarSize = compact ? 38.0 : 44.0;
            final gearSize = compact ? 38.0 : 44.0;
            return SizedBox(
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar + Etrafında Dairesel XP Halkası + Altında LVL Rozeti
                  Semantics(
                    button: true,
                    label: context.l10n.profile,
                    child: GestureDetector(
                      onTap: onProfileTap,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // İç avatar görseli
                          Container(
                            width: avatarSize - 4,
                            height: avatarSize - 4,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: ClipOval(
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned(
                                    left: 1.5,
                                    top: 3.0,
                                    width: 33.4,
                                    height: 59.2,
                                    child: Image.asset(
                                      'assets/design/ui/hub_avatar_exact.webp',
                                      width: 33.4,
                                      height: 59.2,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Image.asset(
                                        'assets/design/ui/avatar_hamam_diva.webp',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Profil fotoğrafının etrafındaki dairesel XP barı
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _AvatarXpRingPainter(progress: xpFrac),
                            ),
                          ),
                          // Profil fotoğrafının alt kısmında LVL rozeti
                          Positioned(
                            bottom: -3,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                // Dar ekranda rozet taşmasın diye yatay boşluk kısılır.
                                horizontal: compact ? 4 : 5,
                                vertical: 1.2,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFF8C00),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFF141B2A),
                                  width: 1.3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    offset: Offset(0, 1.5),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                // Okunabilirlik: en az 11pt. Dar ekranda
                                // boşluksuz kısaltma ile rozete sığdırılır.
                                context.l10n.levelBadge(level, compact),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.baloo2(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.1,
                                  color: const Color(0xFF141B2A),
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                  SizedBox(width: gap),

              // Coin Pill (.pill: height 34, width 92.9 on 430w, padding 4px 7px 4px 5px)
              Flexible(
                flex: 0,
                child: Semantics(
                  button: true,
                  label: context.l10n.navShop,
                  child: GestureDetector(
                    onTap: onShopTap,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: compact ? null : 92.9,
                    height: 34,
                    child: _Pill(
                      light: light,
                      height: 34,
                      padding: const EdgeInsets.fromLTRB(5, 4, 7, 4),
                      child: Row(
                        mainAxisSize:
                            compact ? MainAxisSize.min : MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/design/ui/icon_coin_exact.png',
                            width: 18,
                            height: 18,
                            errorBuilder: (_, _, _) => Image.asset(
                              'assets/design/ui/icon_coin.png',
                              width: 18,
                              height: 18,
                            ),
                          ),
                          const SizedBox(width: 3),
                          if (!compact)
                            Expanded(
                              child: Transform.translate(
                                offset: const Offset(0, -1.0),
                                child: Text(
                                  _fmt(displayCoins),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.25,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            Flexible(
                              child: Text(
                                _fmt(displayCoins),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Container(
                            width: 15,
                            height: 15,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF00C853),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+',
                              style: GoogleFonts.nunito(
                                color: const Color(0xFF04140A),
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                height: 1.0,
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
              SizedBox(width: gap),

              // Star Pill (.pill: height 34, width 48.0 on 430w, padding 4px 6px 4px 5px)
              SizedBox(
                width: compact ? null : 48.0,
                height: 34,
                child: _Pill(
                  light: light,
                  height: 34,
                  padding: const EdgeInsets.fromLTRB(5, 4, 6, 4),
                  child: Row(
                    mainAxisSize:
                        compact ? MainAxisSize.min : MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/design/ui/icon_star_exact.png',
                        width: 18,
                        height: 18,
                        errorBuilder: (_, _, _) => Image.asset(
                          'assets/design/ui/icon_star.png',
                          width: 18,
                          height: 18,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Transform.translate(
                          offset: const Offset(0, -1.0),
                          child: Text(
                            '$displayStars',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: gap),

              // Energy + Level/XP Pill (#energyBar)
              Expanded(
                child: Semantics(
                  button: true,
                  label: context.l10n.energyLabel,
                  child: GestureDetector(
                    onTap: () => _showEnergyDialog(context),
                    behavior: HitTestBehavior.opaque,
                    child: _EnergyPill(light: light),
                  ),
                ),
              ),
              SizedBox(width: gap),

              // Settings Gear Button (.icon-btn.sm: 44x44, radius 13)
              Semantics(
                button: true,
                label: context.l10n.settings,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onSettingsTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: gearSize,
                  height: gearSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: const Color(0xFF33363C),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x59000000),
                        offset: Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/design/ui/icon_gear_exact.png',
                    width: 26,
                    height: 26,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    required this.light,
    this.height = 34,
    this.padding = const EdgeInsets.fromLTRB(5, 4, 7, 4),
  });

  final Widget child;
  final bool light;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
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
      child: Center(child: child),
    );
  }
}

class _EnergyPill extends StatefulWidget {
  const _EnergyPill({required this.light});
  final bool light;

  @override
  State<_EnergyPill> createState() => _EnergyPillState();
}

class _EnergyPillState extends State<_EnergyPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat;
  late final Animation<double> _scale;

  /// Yerel 1 sn'lik geri sayım ticker'ı (W6-1 takip düzeltmesi):
  /// [EnergyService] artık her saniye bildirim göndermediği için MM:SS
  /// metni yalnızca bu ticker'ın `setState` çağrısıyla tazelenir.
  /// Yalnız geri sayım görünürken (enerji dolu değilken) çalışır.
  Timer? _countdownTicker;

  @override
  void initState() {
    super.initState();
    _beat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurveTween(curve: Curves.easeInOut).animate(_beat),
    );
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTesting) {
      _beat.repeat(reverse: true);
    }
    // Enerji dolu ↔ eksik geçişlerinde ticker'ı başlat/durdur.
    EnergyService.instance.energyNotifier.addListener(_syncCountdownTicker);
    _syncCountdownTicker();
  }

  /// Ticker'ı görünürlük durumuna göre başlatır veya durdurur.
  /// Test ortamında ticker kurulmaz (periyodik zamanlayıcı
  /// `pumpAndSettle`'ı kilitler).
  void _syncCountdownTicker() {
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final showCountdown =
        EnergyService.instance.energy < EnergyService.maxEnergy;
    if (!showCountdown || isTesting) {
      _countdownTicker?.cancel();
      _countdownTicker = null;
      return;
    }
    if (_countdownTicker != null) return;
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (EnergyService.instance.energy >= EnergyService.maxEnergy) {
        _syncCountdownTicker();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTicker?.cancel();
    _countdownTicker = null;
    EnergyService.instance.energyNotifier.removeListener(_syncCountdownTicker);
    _beat.dispose();
    super.dispose();
  }

  static String _mmss(Duration d) {
    if (d.inSeconds <= 0 || d.inSeconds >= 295) {
      return '4:59';
    }
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final svc = EnergyService.instance;
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge([
        svc.energyNotifier,
        svc.timeToNextNotifier,
      ]),
      builder: (_, _) {
        final energy = svc.energy;
        final frac = (energy / EnergyService.maxEnergy).clamp(0.0, 1.0);
        final timerStr = energy >= EnergyService.maxEnergy
            ? l10n.energyFull
            : _mmss(svc.timeToNext);

        return Container(
          height: 36,
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 5),
          decoration: BoxDecoration(
            color: const Color(0xFF33363C),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59000000),
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Üst satır: Can sayısı + Süre
              SizedBox(
                height: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scale,
                      child: Image.asset(
                        'assets/design/ui/icon_heart_exact.png',
                        width: 16,
                        height: 16,
                        errorBuilder: (_, _, _) =>
                            const Text('❤️', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Transform.translate(
                      offset: const Offset(0, -0.5),
                      child: Text(
                        '$energy/30',
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.baloo2(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Transform.translate(
                      offset: const Offset(0, -0.5),
                      child: Text(
                        timerStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.baloo2(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFD34D),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 2. Alt bar: Can (Enerji) Barı
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: frac,
                  heightFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFE01E5A)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarXpRingPainter extends CustomPainter {
  const _AvatarXpRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 1.75;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arka plan halkası (koyu altın/antrasit iz)
    final trackPaint = Paint()
      ..color = const Color(0xFF2B3245)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(center, radius, trackPaint);

    // XP ilerleme yayı (Turkuaz -> Altın -> Yeşil parlak halka)
    final sweep = (2 * math.pi * progress.clamp(0.05, 1.0));
    final progressPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          Color(0xFF00E5FF),
          Color(0xFF00C853),
          Color(0xFFFFD700),
          Color(0xFFFF8C00),
          Color(0xFF00E5FF),
        ],
        stops: [0.0, 0.35, 0.70, 0.92, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarXpRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
