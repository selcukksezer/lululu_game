import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';

/// Oyun sonu sonuç ekranı (tam sayfa, dialog değil).
///
/// Skor sıfırdan sayarak yükselir, 10 coin kavis çizerek kasaya uçar
/// (her inişte kasa zıplar), yıldızlar patlayarak açılır, konfeti yağar,
/// böcek karakter dans eder.
///
/// `true` dönerse "TEKRAR OYNA" seçildi (aynı modu yeniden aç sinyali),
/// `false` dönerse "ANA SAYFA" seçildi — çağıran eski davranışına devam eder.
Future<bool> showGameResult(
  BuildContext context, {
  required int score,
  required int coins,
  required int stars,
}) async {
  final replay = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => _GameResultPage(
        score: score,
        coins: coins,
        stars: stars.clamp(0, 3),
      ),
    ),
  );
  return replay ?? false;
}

/// Coin/yıldız ekonomisi olmayan modlar için sonuç skorlama yardımcısı.
abstract final class ResultScoring {
  /// Skor → altın (100 skorda 1).
  static int coinsFor(int score) => max(0, score ~/ 100);

  /// Skor/rekor karşılaştırmasıyla 0–3 yıldız.
  static int starsFor({required int score, required int best}) {
    if (score <= 0) return 0;
    if (best > 0 && score >= best) return 3;
    if (best > 0 && score >= (best * 0.6).ceil()) return 2;
    return 1;
  }
}

// Ahşap tema tonları.
const _woodDeep = Color(0xFF4A2C15);
const _wood = Color(0xFF7A4E22);
const _woodLight = Color(0xFFA9743B);
const _woodEdge = Color(0xFF2E1A0B);

class _GameResultPage extends StatefulWidget {
  const _GameResultPage({
    required this.score,
    required this.coins,
    required this.stars,
  });

  final int score;
  final int coins;
  final int stars;

  @override
  State<_GameResultPage> createState() => _GameResultPageState();
}

class _GameResultPageState extends State<_GameResultPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_wood, _woodDeep],
          ),
        ),
        child: Stack(
          children: [
            // Ahşap plank çizgileri.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _PlankPainter()),
              ),
            ),
            // Konfeti yağmuru.
            const Positioned.fill(
              child: IgnorePointer(child: _ConfettiRain()),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    'SEVİYE TAMAM!',
                    style: GoogleFonts.bangers(
                      fontSize: 46,
                      color: LululuColors.warningSolar,
                      letterSpacing: 1.5,
                      shadows: const [
                        Shadow(
                          color: _woodEdge,
                          blurRadius: 0,
                          offset: Offset(3, 4),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .scaleXY(
                        begin: 0.4,
                        end: 1,
                        duration: 450.ms,
                        curve: Curves.elasticOut,
                      ),
                  Text(
                    "Zirveye, Pembe Bornozlu'ya bir adım daha yaklaştın!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: LululuColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildScorePanel(),
                  const SizedBox(height: 6),
                  // Kasa + uçan coinler.
                  SizedBox(
                    height: 216,
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, _) => _buildTreasureZone(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStars(),
                  const Spacer(),
                  _buildDancer(),
                  const SizedBox(height: 10),
                  _buildButtons(),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScorePanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_woodLight, _wood],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _woodEdge, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _woodEdge,
            blurRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SKOR',
            style: GoogleFonts.exo2(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: _woodEdge,
            ),
          ),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: widget.score),
            duration: const Duration(milliseconds: 900),
            builder: (context, value, _) => Text(
              '$value',
              style: GoogleFonts.exo2(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: LululuColors.warningSolar,
                shadows: const [
                  Shadow(
                    color: _woodEdge,
                    blurRadius: 0,
                    offset: Offset(2, 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 10 coin kasaya uçar; her inişte kasa zıplar, sayaç artar.
  Widget _buildTreasureZone(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    const zoneH = 216.0;
    const chestW = 120.0;
    const chestH = 92.0;
    final chestCx = w / 2;
    final chestCy = zoneH - 40;
    final t = _ctrl.value;

    double bounce = 0;
    int landed = 0;
    final coinWidgets = <Widget>[];
    for (int i = 0; i < 10; i++) {
      final tStart = 0.08 + i * 0.05;
      const tDur = 0.30;
      final p = ((t - tStart) / tDur).clamp(0.0, 1.0);
      if (p >= 1.0) {
        landed++;
      } else if (p >= 0.92) {
        bounce += sin((p - 0.92) / 0.08 * pi);
      }
      final pe = p * p; // ease-in
      final x0 = w * (0.12 + 0.76 * i / 9);
      const y0 = 8.0;
      final cx = (x0 + chestCx) / 2;
      final cy = min(y0, chestCy) - 70;
      final x = (1 - pe) * (1 - pe) * x0 +
          2 * (1 - pe) * pe * cx +
          pe * pe * chestCx;
      final y = (1 - pe) * (1 - pe) * y0 +
          2 * (1 - pe) * pe * cy +
          pe * pe * chestCy;
      final visible = p > 0 && p < 1;
      coinWidgets.add(
        Positioned(
          left: x - 15,
          top: y - 15,
          child: Opacity(
            opacity: visible ? 1 : 0,
            child: const _CoinDot(),
          ),
        ),
      );
    }
    final chestScale = 1 + 0.20 * bounce.clamp(0.0, 1.4);
    final shownCoins = (widget.coins * landed / 10).round();

    return Stack(
      children: [
        ...coinWidgets,
        Positioned(
          left: chestCx - chestW / 2,
          top: chestCy - chestH / 2 - 8,
          child: Transform.scale(
            scale: chestScale,
            alignment: Alignment.bottomCenter,
            child: const _Chest(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'KAZANILAN ALTIN',
                style: GoogleFonts.exo2(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: _woodEdge,
                ),
              ),
              Text(
                '+$shownCoins 🪙',
                style: GoogleFonts.exo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.warningSolar,
                  shadows: const [
                    Shadow(
                      color: _woodEdge,
                      blurRadius: 0,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Yıldızlar sırayla patlayarak açılır.
  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final earned = i < widget.stars;
        final star = Icon(
          earned ? Icons.star_rounded : Icons.star_border_rounded,
          size: 58,
          color: earned
              ? LululuColors.warningSolar
              : _woodEdge.withValues(alpha: 0.55),
          shadows: earned
              ? const [
                  Shadow(color: _woodEdge, blurRadius: 0, offset: Offset(2, 3)),
                ]
              : null,
        );
        if (!earned) return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: star,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LululuColors.warningSolar.withValues(alpha: 0.5),
                ),
              )
                  .animate()
                  .fadeIn(duration: 1.ms, delay: (1650 + i * 260).ms)
                  .scaleXY(
                    begin: 0.2,
                    end: 1.6,
                    delay: (1650 + i * 260).ms,
                    duration: 420.ms,
                    curve: Curves.easeOut,
                  )
                  .fadeOut(delay: (1950 + i * 260).ms, duration: 240.ms),
              star
                  .animate()
                  .fadeIn(duration: 1.ms, delay: (1650 + i * 260).ms)
                  .scaleXY(
                    begin: 0,
                    end: 1.25,
                    delay: (1650 + i * 260).ms,
                    duration: 420.ms,
                    curve: Curves.elasticOut,
                  ),
            ],
          ),
        );
      }),
    );
  }

  /// Dans eden böcek.
  Widget _buildDancer() {
    return const Text('🪳', style: TextStyle(fontSize: 72))
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -18,
          duration: 420.ms,
          curve: Curves.easeInOut,
        )
        .rotate(
          begin: -0.18,
          end: 0.18,
          duration: 420.ms,
          curve: Curves.easeInOut,
        );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: LululuColors.liquidGold,
                foregroundColor: _woodEdge,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                'TEKRAR OYNA',
                style: GoogleFonts.exo2(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: LululuColors.ink,
                side: const BorderSide(color: _woodEdge, width: 2.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'ANA SAYFA',
                style: GoogleFonts.exo2(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uçan altın coin.
class _CoinDot extends StatelessWidget {
  const _CoinDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFE066), LululuColors.liquidGold],
        ),
        border: Border.all(color: _woodEdge, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: LululuColors.warningSolar,
            blurRadius: 10,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '★',
          style: TextStyle(fontSize: 14, color: _woodEdge),
        ),
      ),
    );
  }
}

/// Ahşap kasa.
class _Chest extends StatelessWidget {
  const _Chest();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 92,
      child: Stack(
        children: [
          // Gövde.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_woodLight, _wood],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _woodEdge, width: 3),
              ),
            ),
          ),
          // Kapak çizgisi.
          Positioned(
            top: 26,
            left: 6,
            right: 6,
            child: Container(height: 4, color: _woodEdge.withValues(alpha: 0.6)),
          ),
          // Metal kuşaklar.
          for (final dx in [18.0, 86.0])
            Positioned(
              top: 6,
              bottom: 6,
              left: dx,
              child: Container(
                width: 14,
                decoration: BoxDecoration(
                  color: _woodEdge.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          // Kilit.
          Positioned(
            top: 34,
            left: 47,
            child: Container(
              width: 26,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    LululuColors.warningSolar,
                    LululuColors.liquidGold,
                  ],
                ),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _woodEdge, width: 2.5),
              ),
              child: const Center(
                child: Icon(Icons.key_rounded, size: 15, color: _woodEdge),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ahşap plank dokusu.
class _PlankPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = _woodEdge.withValues(alpha: 0.35)
      ..strokeWidth = 2.5;
    for (double y = 90; y < size.height; y += 120) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final grain = Paint()
      ..color = _woodEdge.withValues(alpha: 0.12)
      ..strokeWidth = 1.2;
    final rng = Random(11);
    for (int i = 0; i < 14; i++) {
      final y = rng.nextDouble() * size.height;
      final x = rng.nextDouble() * size.width * 0.7;
      canvas.drawLine(Offset(x, y), Offset(x + 40 + rng.nextDouble() * 60, y), grain);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Konfeti yağmuru.
class _ConfettiRain extends StatelessWidget {
  const _ConfettiRain();

  static const _colors = [
    LululuColors.liquidGold,
    LululuColors.cyberFuchsia,
    LululuColors.toxicNeon,
    LululuColors.coralFlare,
    LululuColors.warningSolar,
    Colors.white,
  ];

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final w = MediaQuery.sizeOf(context).width;
    final rng = Random(42);
    return Stack(
      children: List.generate(26, (i) {
        final delayMs = (rng.nextDouble() * 1500).round();
        const fallMs = 1600;
        final size = 6 + rng.nextDouble() * 7;
        final round = rng.nextBool();
        return Positioned(
          left: rng.nextDouble() * w,
          top: -30,
          child: Container(
            width: size,
            height: round ? size : size * 1.5,
            decoration: BoxDecoration(
              color: _colors[i % _colors.length],
              shape: round ? BoxShape.circle : BoxShape.rectangle,
              borderRadius:
                  round ? null : BorderRadius.circular(2),
            ),
          )
              .animate()
              .moveY(
                begin: 0,
                end: h + 60,
                delay: delayMs.ms,
                duration: fallMs.ms,
                curve: Curves.easeIn,
              )
              .rotate(
                begin: 0,
                end: rng.nextDouble() * 6 - 3,
                delay: delayMs.ms,
                duration: fallMs.ms,
              )
              .fadeOut(delay: (delayMs + fallMs - 250).ms, duration: 250.ms),
        );
      }),
    );
  }
}
