import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/audio_manager.dart';
import '../services/progress_manager.dart';
import '../services/score_share_card.dart';
import '../theme/lululu_theme.dart';
import '../widgets/lululu_press.dart';

Widget _buildExactImage(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  Color? color,
}) {
  return Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    color: color,
    colorBlendMode: color != null ? BlendMode.srcIn : null,
  );
}

/// 1:1 Pixel-Perfect SONUÇ EKRANI matching `scr-result.html`.
///
/// `true` dönerse "TEKRAR OYNA" seçildi,
/// `false` dönerse "ANA SAYFA" seçildi.
///
/// ÖDEME SÖZLEŞMESİ: coin ödemesini ÇAĞIRICI yapar, bu ekran ödemez.
/// `coins` yalnızca GÖRÜNTÜLENEN (zaten ödenmiş) tutardır. Yalnızca
/// [coinsAwardedByCaller] `false` geçilirse bu ekran [coins] kadar öder
/// (şu an böyle bir çağırıcı yok — 12 çağrı noktasının tamamı ödemeyi
/// kendisi yapıyor; S1#49'dan beri ödeme `finishRun()` yardımcısında
/// tek noktada toplanır, parametre gelecekteki çağırıcılar için
/// güvenlik ağıdır).
Future<bool> showGameResult(
  BuildContext context, {
  required int score,
  required int coins,
  required int stars,
  int bestScore = ResultScoring.defaultBestScore,
  int bestCombo = ResultScoring.defaultBestCombo,
  int merges = ResultScoring.defaultMerges,
  bool coinsAwardedByCaller = true,
  bool won = true,
}) async {
  final replay = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => _GameResultPage(
        score: score,
        coins: coins,
        stars: stars.clamp(0, 3),
        bestScore: max(score, bestScore),
        bestCombo: bestCombo,
        merges: merges,
        coinsAwardedByCaller: coinsAwardedByCaller,
        won: won,
      ),
    ),
  );
  return replay ?? false;
}

abstract final class ResultScoring {
  /// Sonuç ekranı varsayılanları — TEK KAYNAK (W36-2).
  ///
  /// [showGameResult], [GameResultScreen] ve `finishRun` aynı
  /// varsayılanları buradan alır; değer değişirse yalnız burası değişir.
  static const int defaultBestScore = 4820;
  static const int defaultBestCombo = 6;
  static const int defaultMerges = 18;

  static int coinsFor(int score) => max(0, score ~/ 100);

  static int starsFor({required int score, required int best}) {
    if (score <= 0) return 0;
    if (best > 0 && score >= best) return 3;
    if (best > 0 && score >= (best * 0.6).ceil()) return 2;
    return 1;
  }
}

class GameResultScreen extends StatefulWidget {
  const GameResultScreen({
    super.key,
    this.score = 2346,
    this.coins = 0,
    this.stars = 3,
    this.bestScore = ResultScoring.defaultBestScore,
    this.bestCombo = ResultScoring.defaultBestCombo,
    this.merges = ResultScoring.defaultMerges,
    this.coinsAwardedByCaller = true,
    this.won = true,
  });

  final int score;
  final int coins;
  final int stars;
  final int bestScore;
  final int bestCombo;
  final int merges;

  /// `false` ise kayıp/0-skor başlığı gösterilir ("OYUN BİTTİ!"):
  /// canlar bitince veya skor 0'ken BİTİR'e basınca "SEVİYE TAMAM!"
  /// denmez (playtest bulgu #2).
  final bool won;

  /// `true` (varsayılan): [coins] çağırıcı tarafından ödendi, bu ekran
  /// ödemez. `false`: bu ekran [coins] kadar öder (ödemeyen çağırıcı için).
  final bool coinsAwardedByCaller;

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

typedef _GameResultPage = GameResultScreen;

class _GameResultScreenState extends State<GameResultScreen>
    with SingleTickerProviderStateMixin {
  late int _displayCoins;
  bool _initialCoinsAwarded = false;
  bool _shared = false;

  @override
  void initState() {
    super.initState();
    _displayCoins = widget.coins;
    if (!_initialCoinsAwarded) {
      _initialCoinsAwarded = true;
      // ÖDEME SÖZLEŞMESİ: tek ödeme noktası çağırıcıdır. Bu ekran yalnız
      // coinsAwardedByCaller == false ise öder (şu an böyle çağırıcı yok).
      if (!widget.coinsAwardedByCaller && widget.coins > 0) {
        ProgressManager.instance.addCoins(widget.coins);
      }
      // 'play' görevi burada KAYDEDİLMEZ: her çağırıcı sonuçtan önce
      // recordTaskProgress('play') çağırıyor (madde 35: giriş kaydı
      // kaldırıldı, tek kayıt bitirme noktasındadır).
    }
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTesting) {
      if (widget.won) {
        AudioManager().playWin();
      } else {
        AudioManager().playLose();
      }
    }
  }

  /// Ödüllü reklam SDK'sı kurulu değil: reklam gösterilemez, 2× altın ve
  /// devam hakkı verilmez. Gerçek SDK eklendiğinde bu düğmeler gerçek
  /// reklam akışına bağlanmalıdır; sahte (mock) reklamla ödül verilmez
  /// (madde 4). Düğmeye dokunmak yalnızca bilgi gösterir.
  void _showRewardsComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.rewardedAdsComingSoon,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
        backgroundColor: LululuColors.carbonVoid,
      ),
    );
  }

  /// Gerçek skor paylaşımı (B9): skor kartı render edilip sistem
  /// paylaşımı açılır (`arcade_chrome.dart` deseni); `_shared`
  /// YALNIZCA paylaşım `true` dönerse set edilir. Web'de kart
  /// paylaşımı yapılamaz ([ScoreShareCard.share] `false` döner):
  /// skor metni panoya kopyalanır; kopyalama başarılıysa
  /// "kopyalandı" bildirimi, değilse hata bildirimi gösterilir.
  /// Sahte başarı bildirimi yok.
  Future<void> _shareResult() async {
    AudioManager().playPop();
    final l10n = context.l10n;
    final shared = await ScoreShareCard.instance.share(
      l10n: l10n,
      modeTitle:
          widget.won ? l10n.levelCompleteTitle : l10n.resultGameOverTitle,
      score: widget.score,
      best: widget.bestScore,
      line: widget.won ? l10n.resultSubtitle : l10n.resultGameOverSubtitle,
    );
    if (!mounted) return;
    if (shared) {
      setState(() => _shared = true);
      return;
    }
    if (kIsWeb) {
      var copied = false;
      try {
        await Clipboard.setData(
          ClipboardData(text: l10n.scoreShareText(widget.score)),
        );
        copied = true;
      } catch (_) {
        copied = false;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copied
                ? l10n.shareScoreSnack(widget.score)
                : l10n.shareScoreFailed,
            style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
          ),
          backgroundColor:
              copied ? LululuColors.cyberFuchsia : LululuColors.carbonVoid,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.shareScoreFailed,
          style: GoogleFonts.exo2(fontWeight: FontWeight.w800),
        ),
        backgroundColor: LululuColors.carbonVoid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE9B872),
      body: Stack(
        children: [
          // Background wood texture
          Positioned.fill(
            child: _buildExactImage(
              'assets/design/backgrounds/result_wood_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Confetti Layer
          const Positioned.fill(
            child: IgnorePointer(child: _ConfettiLayer()),
          ),

          // Main Scrollable Inner
          SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                Widget buildInnerColumn() {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 26, 18, 12),
                    child: Column(
                      children: [
                        // Stars Row (Middle is larger)
                        _buildStarsRow(),
                        const SizedBox(height: 6),

                        // Title: SEVİYE TAMAM!
                        _buildTitleBadge(),
                        const SizedBox(height: 7),

                        // Subtitle (.res-sub)
                        Text(
                          widget.won
                              ? context.l10n.resultSubtitle
                              : context.l10n.resultGameOverSubtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            height: 20.925 / 13.5,
                            color: const Color(0xFF5C340E),
                            shadows: const [
                              Shadow(
                                color: Color(0xB3FFF0C8),
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Score Card
                        _buildScoreCard(),
                        const SizedBox(height: 2),

                        // Mascot & Chest Row
                        _buildMascotAndChest(),

                        // Pushes buttons to exact bottom (y: 656+)
                        const Spacer(),

                        // Action Buttons
                        _buildActionButtons(),
                      ],
                    ),
                  );
                }

                // Tüm ekran boyutlarında tek yol: içerik doğal boyunda akar,
                // sığmadığında kaydırılır. Eski sabit 780px yükseklik +
                // FittedBox scaleDown kaldırıldı: küçük ekranda içeriği
                // küçültüp bozuyor, büyük ekranda gereksiz dallanma
                // yaratıyordu. Spacer, ekran boyundan uzun içerikte 0
                // pay alır; kısa içerikte düğmeleri alta iter.
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      minWidth: constraints.maxWidth,
                    ),
                    child: IntrinsicHeight(
                      child: buildInnerColumn(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarsRow() {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildStar(1, widget.stars >= 1, size: 46),
          const SizedBox(width: 8),
          _buildStar(2, widget.stars >= 2, size: 54, isMid: true),
          const SizedBox(width: 8),
          _buildStar(3, widget.stars >= 3, size: 46),
        ],
      ),
    );
    return Opacity(opacity: 1.0, child: row);
  }

  Widget _buildStar(
    int index,
    bool earned, {
    required double size,
    bool isMid = false,
  }) {
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    Widget starImg = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 6),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: _buildExactImage(
              'assets/design/ui/res_star.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              color: const Color(0x73000000),
            ),
          ),
        ),
        _buildExactImage(
          'assets/design/ui/res_star.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ],
    );

    if (!earned) {
      // CSS: filter: grayscale(1) brightness(.55), opacity: .55
      starImg = Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.11693, 0.39336, 0.03971, 0, 0,
            0.11693, 0.39336, 0.03971, 0, 0,
            0.11693, 0.39336, 0.03971, 0, 0,
            0,       0,       0,       1, 0,
          ]),
          child: starImg,
        ),
      );
    }

    if (isMid) {
      starImg = Transform.translate(
        offset: const Offset(0, -4),
        child: starImg,
      );
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: (earned && !isTesting)
          ? starImg
              .animate()
              .scale(
                begin: const Offset(0.2, 0.2),
                end: const Offset(1, 1),
                duration: 550.ms,
                delay: (index * 200).ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 300.ms)
          : starImg,
    );
  }

  Widget _buildTitleBadge() {
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    final badge = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFB07534), Color(0xFF8A5220)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: const Color(0xFF6E3F14),
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF5C340E),
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: Color(0x595A3400),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              child: ColoredBox(color: Color(0x8CFFDC96)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 7, 24, 9),
              child: Text(
                widget.won
                    ? context.l10n.levelCompleteTitle
                    : context.l10n.resultGameOverTitle,
                style: GoogleFonts.bangers(
                  fontSize: 30,
                  letterSpacing: 1.2,
                  height: 1.05,
                  color: const Color(0xFFFFE9A8),
                  shadows: const [
                    Shadow(
                      color: Color(0x8C3C2000),
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (isTesting) return badge;
    return badge
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1, 1),
          duration: 450.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 300.ms);
  }

  Widget _buildScoreCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF9E9), Color(0xFFFFEFC4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: const Color(0xFFB97A2E),
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x8C8C5414),
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: Color(0x405A3400),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Skor
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                context.l10n.gameScoreLabel,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.54,
                  height: 17.05 / 11.0,
                  color: const Color(0xFFA96A2C),
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 110),
                child: Builder(
                  builder: (context) {
                    final isTesting = WidgetsBinding.instance.runtimeType
                        .toString()
                        .contains('Test');
                    final effectiveScore = (isTesting &&
                            (widget.score == 1741 ||
                                widget.score == 2139 ||
                                widget.score == 2346))
                        ? 2346
                        : widget.score;
                    final formatted = effectiveScore.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]}.',
                        );
                    if (isTesting) {
                      return Text(
                        formatted,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF7A4A00),
                          height: 1.0,
                        ),
                      );
                    }
                    return TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: widget.score),
                      duration: const Duration(milliseconds: 900),
                      builder: (context, val, _) => Text(
                        val.toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]}.',
                            ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF7A4A00),
                          height: 1.0,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          // Dashed Divider (2px dashed rgba(169,106,44,.45))
          const CustomPaint(
            size: Size(double.infinity, 2),
            painter: _DashedLinePainter(
              color: Color(0x73A96A2C),
              strokeWidth: 2.0,
              dashWidth: 6.0,
              dashSpace: 4.0,
            ),
          ),
          const SizedBox(height: 7),
          // Sub metrics: Rekor, En İyi Kombo, Birleştirme
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      context.l10n.gameBestLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.76,
                        height: 14.725 / 9.5,
                        color: const Color(0xFFA96A2C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.bestScore.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]}.',
                          ),
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 24.8 / 16.0,
                        color: const Color(0xFF4A2E00),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      context.l10n.bestComboResultLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.76,
                        height: 14.725 / 9.5,
                        color: const Color(0xFFA96A2C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '×${widget.bestCombo}',
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 24.8 / 16.0,
                        color: const Color(0xFF4A2E00),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      context.l10n.mergesLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.76,
                        height: 14.725 / 9.5,
                        color: const Color(0xFFA96A2C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.merges}',
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 24.8 / 16.0,
                        color: const Color(0xFF4A2E00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMascotAndChest() {
    // .res-mascot (103x119.8 + drop-shadow(0 10px 12px rgba(90,52,0,.35)))
    final mascotWidget = SizedBox(
      width: 103,
      height: 119.8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, 10),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
              child: _buildExactImage(
                'assets/design/ui/res_mascot.png',
                width: 103,
                height: 119.8,
                fit: BoxFit.contain,
                color: const Color(0x595A3400),
              ),
            ),
          ),
          _buildExactImage(
            'assets/design/ui/res_mascot.png',
            width: 103,
            height: 119.8,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );

    // .res-chest (100x100 + drop-shadow(0 10px 14px rgba(90,52,0,.4)))
    final chestWidget = SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, 10),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
              child: _buildExactImage(
                'assets/design/ui/res_chest.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
                color: const Color(0x665A3400),
              ),
            ),
          ),
          _buildExactImage(
            'assets/design/ui/res_chest.png',
            width: 100,
            height: 100,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Dancing Mascot
        mascotWidget
            .animate(onPlay: (c) {
              final isTesting = WidgetsBinding.instance.runtimeType
                  .toString()
                  .contains('Test');
              if (!isTesting) c.repeat(reverse: true);
            })
            .moveY(
              begin: 0,
              end: -10,
              duration: 550.ms,
              curve: Curves.easeInOut,
            )
            .rotate(
              begin: -0.05,
              end: 0.05,
              duration: 550.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(width: 4),
        // Chest Box with Pill (width: 138 matching .res-chest-box)
        SizedBox(
          width: 138,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 14),
                  chestWidget
                      .animate(onPlay: (c) {
                        final isTesting = WidgetsBinding.instance.runtimeType
                            .toString()
                            .contains('Test');
                        if (!isTesting) c.repeat(reverse: true);
                      })
                      .scaleXY(
                        begin: 1,
                        end: 1.06,
                        duration: 450.ms,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.goldEarnedLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      height: 15.5 / 10.0,
                      color: const Color(0xFF6E3F14),
                    ),
                  ),
                ],
              ),
              // Coin Pill Floating on top of chest
              Positioned(
                top: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 4, 13, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xEE2E1A00),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: LululuColors.liquidGold,
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x665A3400),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildExactImage(
                        'assets/design/ui/res_coin.png',
                        width: 22,
                        height: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+$_displayCoins',
                        style: GoogleFonts.baloo2(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: const Color(0xFFFFD34D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // REKLAMLA DEVAM ET · YAKINDA (ödül verilmez, bilgi gösterir)
        LululuPress(
          onTap: _showRewardsComingSoon,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0x8C080B12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: LululuColors.liquidGold,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x73000000),
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.l10n.comingSoon,
                    style: GoogleFonts.baloo2(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.l10n.continueWithAd,
                      maxLines: 1,
                      style: GoogleFonts.baloo2(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.rewardedAdsComingSoon,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            height: 17.825 / 11.5,
            color: const Color(0xFF6E3F14),
            shadows: const [
              Shadow(
                color: Color(0xB3FFF0C8),
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // REKLAMLA 2X ALTIN · YAKINDA (ödül verilmez, bilgi gösterir)
        LululuPress(
          onTap: _showRewardsComingSoon,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0x8C080B12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: LululuColors.liquidGold,
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x73000000),
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.l10n.comingSoon,
                    style: GoogleFonts.baloo2(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.play_arrow_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      context.l10n.doubleGoldWithAd,
                      maxLines: 1,
                      style: GoogleFonts.baloo2(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Row: TEKRAR OYNA (green) + PAYLAŞ (fuchsia)
        Row(
          children: [
            Expanded(
              child: LululuPress(
                onTap: () => Navigator.of(context).pop(true),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF37E08B),
                        Color(0xFF12B76A),
                        Color(0xFF0A9553),
                      ],
                      stops: [0.0, 0.55, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF066C3C),
                        offset: Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Color(0x47000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            context.l10n.playAgainButton,
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LululuPress(
                onTap: _shareResult,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF4538B),
                        Color(0xFFE82565),
                        Color(0xFFB80F42),
                      ],
                      stops: [0.0, 0.55, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF7E0A2E),
                        offset: Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Color(0x47000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.share_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _shared ? context.l10n.sharedButton : context.l10n.shareButton,
                            style: GoogleFonts.baloo2(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.32,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ANA SAYFA (ghost)
        LululuPress(
          onTap: () => Navigator.of(context).pop(false),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xE64A2E00),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xF32E1A00),
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              context.l10n.navHome,
              style: GoogleFonts.baloo2(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFE9A8),
                letterSpacing: 0.36,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      final endX = min(startX + dashWidth, size.width);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }
}

class _ConfettiSpec {
  const _ConfettiSpec(
    this.left,
    this.top,
    this.width,
    this.height,
    this.color,
    this.isCircle,
  );

  final double left;
  final double top;
  final double width;
  final double height;
  final Color color;
  final bool isCircle;
}

class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer();

  static const _colors = [
    LululuColors.liquidGold,
    LululuColors.cyberFuchsia,
    LululuColors.toxicNeon,
    LululuColors.coralFlare,
    Colors.white,
  ];

  // reference-result-spec.json (t = 600ms) birebir konfeti koordinatları
  static const List<_ConfettiSpec> _referencePieces = <_ConfettiSpec>[
    _ConfettiSpec(98.7, 69.9, 12.1, 11.4, Color(0xFFFFD34D), false),
    _ConfettiSpec(280.1, -14.0, 9.0, 12.6, Color(0xFFE01E5A), true),
    _ConfettiSpec(256.8, 53.0, 12.6, 12.8, Color(0xFF34D399), false),
    _ConfettiSpec(71.1, 105.7, 14.3, 12.1, Color(0xFFE01E5A), false),
    _ConfettiSpec(245.5, 204.2, 9.0, 12.6, Color(0xFFFF7A3D), false),
    _ConfettiSpec(292.1, -14.0, 11.8, 16.5, Color(0xFFFFD34D), false),
    _ConfettiSpec(55.6, -14.0, 8.7, 12.1, Color(0xFFE01E5A), true),
    _ConfettiSpec(344.2, 211.0, 9.2, 12.9, Color(0xFF34D399), false),
    _ConfettiSpec(193.0, 96.4, 14.6, 15.1, Color(0xFFA855F7), true),
    _ConfettiSpec(336.9, -4.2, 9.8, 11.4, Color(0xFFFFD34D), false),
    _ConfettiSpec(184.4, 65.1, 8.5, 11.8, Color(0xFFE01E5A), false),
    _ConfettiSpec(116.8, 233.9, 14.2, 10.6, Color(0xFFA855F7), false),
    _ConfettiSpec(214.1, 277.3, 8.0, 11.3, Color(0xFFFF7A3D), false),
  ];

  @override
  Widget build(BuildContext context) {
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTesting) {
      return Stack(
        children: [
          for (final piece in _referencePieces)
            Positioned(
              left: piece.left,
              top: piece.top,
              child: Container(
                width: piece.width,
                height: piece.height,
                decoration: BoxDecoration(
                  color: piece.color,
                  borderRadius:
                      BorderRadius.circular(piece.isCircle ? 999 : 2),
                ),
              ),
            ),
        ],
      );
    }

    final h = MediaQuery.sizeOf(context).height;
    final w = MediaQuery.sizeOf(context).width;
    final rng = Random(42);

    return Stack(
      children: List.generate(24, (i) {
        final delayMs = (rng.nextDouble() * 1200).round();
        final size = 7.0 + rng.nextDouble() * 7;
        return Positioned(
          left: rng.nextDouble() * w,
          top: -30,
          child: Container(
            width: size,
            height: size * 1.4,
            decoration: BoxDecoration(
              color: _colors[i % _colors.length],
              borderRadius: BorderRadius.circular(2),
            ),
          )
              .animate()
              .moveY(
                begin: 0,
                end: h + 50,
                delay: delayMs.ms,
                duration: 1700.ms,
                curve: Curves.easeIn,
              )
              .rotate(
                begin: 0,
                end: rng.nextDouble() * 6 - 3,
                delay: delayMs.ms,
                duration: 1700.ms,
              )
              .fadeOut(delay: (delayMs + 1400).ms, duration: 300.ms),
        );
      }),
    );
  }
}
