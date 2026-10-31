import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../services/energy_service.dart';
import '../services/progress_manager.dart';
import '../services/score_share_card.dart';
import '../theme/lululu_theme.dart';
import '../widgets/ad_mock.dart';

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

  /// 2X ALTIN ödülüyle katlanabilen altın sayacı.
  late int _coins;
  bool _continueRewardUsed = false;
  bool _doubleRewardUsed = false;

  @override
  void initState() {
    super.initState();
    _coins = widget.coins;
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
            // Gerçek ahşap arka plan (assets/design).
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(
                  'assets/design/backgrounds/result_wood_bg.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _miniStat('En İyi Kombo', '×6')),
              const SizedBox(width: 10),
              Expanded(child: _miniStat('Birleştirme', '18')),
            ],
          ),
        ],
      ),
    );
  }

  /// Prototip istatistik satırı (lbl + değer).
  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _woodDeep.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _woodEdge, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: LululuColors.paper.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.exo2(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: LululuColors.warningSolar,
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
    const chestH = 110.0;
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
    final shownCoins = (_coins * landed / 10).round();

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

  /// Dans eden böcek — gerçek tasarım dosyası.
  Widget _buildDancer() {
    return Image.asset(
      'assets/design/bugs_hd/tier1_hd.png',
      height: 96,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(),
    )
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

  /// REKLAM İZLE, DEVAM ET — ad izletir, +1 can verir, oyuna devam
  /// (çağıran için replay sinyali) olarak kapatır.
  Future<void> _watchContinueAd() async {
    if (_continueRewardUsed) return;
    final watched = await showRewardedAdMock(
      context,
      rewardLabel: '+1 CAN / EKSTRA HAMLE',
    );
    if (!watched || !mounted) return;
    setState(() => _continueRewardUsed = true);
    AudioManager().playWin();
    EnergyService.instance.addEnergy(1);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// REKLAM İZLE, 2X ALTIN KAZAN — ad izletir, altını ikiye katlar.
  /// Taban altın recordLevelResult ile zaten işlendi; farkı ekler.
  Future<void> _watchDoubleGoldAd() async {
    if (_doubleRewardUsed) return;
    final watched = await showRewardedAdMock(
      context,
      rewardLabel: '2X ALTIN',
    );
    if (!watched || !mounted) return;
    setState(() {
      _doubleRewardUsed = true;
      _coins = _coins * 2;
    });
    AudioManager().playWin();
    await ProgressManager().addCoins(widget.coins);
  }

  /// PAYLAŞ — skor kartını share_plus üzerinden paylaşır.
  Future<void> _shareScore() async {
    await ScoreShareCard.instance.share(
      modeTitle: 'LÜLÜLÜ',
      score: widget.score,
      line: 'Kazanılan altın: $_coins',
    );
  }

  /// Reklam butonu — prototip ad-btn: koyu zemin, altın çerçeve, REKLAM çipi.
  Widget _adButton({
    required String label,
    required bool used,
    required VoidCallback onPressed,
  }) {
    return Opacity(
      opacity: used ? 0.45 : 1,
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: used ? null : onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: LululuColors.carbonVoid.withValues(alpha: 0.55),
            foregroundColor: LululuColors.paper,
            side: const BorderSide(color: LululuColors.liquidGold, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: LululuColors.cyberFuchsia,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'REKLAM',
                  style: GoogleFonts.exo2(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: LululuColors.paper,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.play_arrow_rounded, size: 20),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  used ? 'KULLANILDI' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _adButton(
            label: 'REKLAM İZLE, DEVAM ET',
            used: _continueRewardUsed,
            onPressed: _watchContinueAd,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            child: Text(
              'Kaldığın yerden devam: +1 can / ekstra hamle',
              style: GoogleFonts.exo2(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _woodEdge,
              ),
            ),
          ),
          _adButton(
            label: 'REKLAM İZLE, 2X ALTIN KAZAN',
            used: _doubleRewardUsed,
            onPressed: _watchDoubleGoldAd,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _shareScore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LululuColors.cyberFuchsia,
                      foregroundColor: LululuColors.paper,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: LululuColors.cyberFuchsia
                          .withValues(alpha: 0.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'PAYLAŞ',
                          style: GoogleFonts.exo2(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

/// Uçan altın coin — gerçek tasarım dosyası.
class _CoinDot extends StatelessWidget {
  const _CoinDot();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/design/ui/icon_coin.png',
      width: 30,
      height: 30,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: LululuColors.liquidGold,
        ),
      ),
    );
  }
}

/// Ahşap kasa — gerçek tasarım dosyası.
class _Chest extends StatelessWidget {
  const _Chest();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/design/backgrounds/chest_wood.png',
      width: 120,
      height: 110,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox(width: 120, height: 110),
    );
  }
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
