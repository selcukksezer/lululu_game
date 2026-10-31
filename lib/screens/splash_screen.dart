import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';

/// 3 sayfalık animasyonlu açılış.
///
/// Sayfa 1: büyük LÜLÜLÜ logosu + soldan sekerek giren böcek + tier sesi.
/// Sayfa 2: böcek geçidi (birkaç tier yan yana yürür, sesleri sırayla).
/// Sayfa 3: "MACERAYA BAŞLA" butonu + animasyonlu loading bar
/// (0→100, üstünde yürüyen böcekler) → %100'de [onDone].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  // Sayfa 2 geçidi.
  Timer? _paradeTimer;
  int _paradeStep = -1;
  static const _paradeTiers = [1, 2, 3, 4, 5];

  // Sayfa 3 yükleme çubuğu.
  Timer? _loadTimer;
  double _progress = 0;
  bool _loading = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Sayfa 1 tier sesi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AudioManager().playMerge(tierNumber: 1));
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _paradeTimer?.cancel();
    _loadTimer?.cancel();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _pageIndex = index);
    _paradeTimer?.cancel();
    if (index == 1) {
      _paradeStep = -1;
      _paradeTimer =
          Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (!mounted) return;
        _paradeStep++;
        final tier =
            _paradeTiers[_paradeStep % _paradeTiers.length];
        unawaited(AudioManager().playMerge(tierNumber: tier));
        if (mounted) setState(() {});
      });
    }
    if (index == 2 && !_loading) _startLoading();
  }

  void _skipToEnd() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _startLoading() {
    if (_loading) return;
    setState(() {
      _loading = true;
      _progress = 0;
    });
    _loadTimer?.cancel();
    _loadTimer = Timer.periodic(const Duration(milliseconds: 45), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _progress += 2.5);
      if (_progress >= 100) {
        t.cancel();
        _finish();
      }
    });
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LululuGradients.paperHero,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  _pageWelcome(),
                  _pageParade(),
                  _pageStart(),
                ],
              ),
              // Nokta göstergesi.
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 4),
                        width: _pageIndex == i ? 26 : 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _pageIndex == i
                              ? LululuColors.carbonVoid
                              : LululuColors.paper
                                  .withValues(alpha: 0.6),
                          borderRadius:
                              BorderRadius.circular(5),
                        ),
                      ),
                  ],
                ),
              ),
              // GEÇ butonu.
              if (_pageIndex < 2)
                Positioned(
                  top: 8,
                  right: 12,
                  child: TextButton(
                    onPressed: _skipToEnd,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(
                          LululuMotion.minTap,
                          LululuMotion.minTap),
                    ),
                    child: Text(
                      'GEÇ ›',
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: LululuColors.carbonVoid,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sayfa 1: logo + soldan sekerek giren böcek.
  Widget _pageWelcome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'YENİ MACERA',
            style: GoogleFonts.bangers(
              fontSize: 44,
              color: LululuColors.paper,
              letterSpacing: 1.8,
            ),
          ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 16),
          Image.asset(
            'assets/design/ui/logo_lululu.png',
            height: 150,
            errorBuilder: (_, __, ___) => Text(
              'LÜLÜLÜ',
              style: GoogleFonts.bangers(
                fontSize: 72,
                color: LululuColors.paper,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.elasticOut),
          const SizedBox(height: 12),
          // Soldan sekerek giren böcek.
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/design/bugs_hd/tier1_hd.png',
              width: 110,
              height: 110,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.bug_report_rounded,
                size: 100,
                color: LululuColors.paper,
              ),
            )
                .animate()
                .slideX(
                  begin: -1.8,
                  end: 0,
                  duration: 750.ms,
                  curve: Curves.bounceOut,
                )
                .then(delay: 200.ms)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(
                  begin: 0,
                  end: -10,
                  duration: 420.ms,
                  curve: Curves.easeInOut,
                ),
          ),
          const SizedBox(height: 20),
          Text(
            'BÖCEKLERİ BİRLEŞTİR, EFSANEYİ YARAT!',
            textAlign: TextAlign.center,
            style: GoogleFonts.bangers(
              fontSize: 32,
              color: LululuColors.paper,
              letterSpacing: 1.2,
            ),
          )
              .animate()
              .fadeIn(delay: 500.ms, duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Aynı böcekleri çarpıştır, 13 aşamalı evrim zincirinde '
            "Pembe Bornozlu'ya kadar yüksel.",
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: LululuColors.carbonVoid,
            ),
          )
              .animate()
              .fadeIn(delay: 700.ms, duration: 400.ms),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  /// Sayfa 2: böcek geçidi.
  Widget _pageParade() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'BÖCEK GEÇİDİ',
            style: GoogleFonts.bangers(
              fontSize: 40,
              color: LululuColors.paper,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 6),
          Text(
            'LİDER KONUŞTU! 10 OYUN MODU HER GÜN YENİ BİR MACERA!',
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: LululuColors.carbonVoid,
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _paradeTiers.length; i++)
                _paradeBug(
                    _paradeTiers[i], i <= _paradeStep % _paradeTiers.length),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ModeChip('Suika Arena'),
              _ModeChip('2048 Grid'),
              _ModeChip('Balon Patlat'),
              _ModeChip('Match 3'),
              _ModeChip('Bağla Patlat'),
              _ModeChip('Stack Drop'),
              _ModeChip('Terlik Tap'),
              _ModeChip('Osmantuş'),
              _ModeChip('Çığlık Böcek'),
              _ModeChip('Makarayız'),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _paradeBug(int tier, bool revealed) {
    final size = 54.0 + tier * 6.0;
    return AnimatedScale(
      scale: revealed ? 1.0 : 0.7,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: Opacity(
        opacity: revealed ? 1.0 : 0.45,
        child: Image.asset(
          'assets/design/bugs_hd/tier${tier}_hd.png',
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => Icon(
            Icons.bug_report_rounded,
            size: size,
            color: LululuColors.paper,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(
              begin: 0,
              end: -8,
              duration: (300 + tier * 40).ms,
              curve: Curves.easeInOut,
            ),
      ),
    );
  }

  /// Sayfa 3: MACERAYA BAŞLA + loading bar.
  Widget _pageStart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'SON ADIM',
            style: GoogleFonts.bangers(
              fontSize: 44,
              color: LululuColors.paper,
              letterSpacing: 1.8,
            ),
          ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 10),
          Text(
            'MACERAYA HAZIR MISIN?',
            textAlign: TextAlign.center,
            style: GoogleFonts.bangers(
              fontSize: 38,
              color: LululuColors.paper,
              letterSpacing: 1.2,
            ),
          ).animate().fadeIn(duration: 350.ms),
          const SizedBox(height: 8),
          Text(
            'Başlamak için butona bas!',
            style: GoogleFonts.exo2(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: LululuColors.carbonVoid,
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startLoading,
              style: ElevatedButton.styleFrom(
                backgroundColor: LululuColors.carbonVoid,
                foregroundColor: LululuColors.liquidGold,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(LululuRadii.pill),
                ),
                elevation: 6,
              ),
              child: _loading
                  ? Text(
                      '%${_progress.clamp(0, 100).round()}',
                      style: GoogleFonts.bangers(fontSize: 24),
                    )
                  : Text(
                      'MACERAYA BAŞLA',
                      style: GoogleFonts.bangers(
                        fontSize: 26,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          _loadingBar(),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _loadingBar() {
    final frac = (_progress / 100).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final barW = constraints.maxWidth;
        return Column(
          children: [
            SizedBox(
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Üstünde yürüyen böcekler.
                  Positioned(
                    left: frac * (barW - 44),
                    bottom: 14,
                    child: Image.asset(
                      'assets/design/bugs_hd/tier1_hd.png',
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink(),
                    )
                        .animate(
                            onPlay: (c) => c.repeat(reverse: true))
                        .moveY(
                          begin: 0,
                          end: -6,
                          duration: 260.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                  Positioned(
                    left: (frac * (barW - 44) - 44)
                        .clamp(0.0, barW - 36),
                    bottom: 14,
                    child: Image.asset(
                      'assets/design/bugs_hd/tier2_hd.png',
                      width: 34,
                      height: 34,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink(),
                    )
                        .animate(
                            onPlay: (c) => c.repeat(reverse: true))
                        .moveY(
                          begin: -4,
                          end: 2,
                          duration: 300.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                  // Çubuk.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: LululuColors.carbonVoid
                            .withValues(alpha: 0.35),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: frac,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient:
                                LululuGradients.neonToGold,
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '%${_progress.clamp(0, 100).round()}',
              style: GoogleFonts.exo2(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: LululuColors.carbonVoid,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: LululuColors.paper.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.exo2(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: LululuColors.carbonVoid,
        ),
      ),
    );
  }
}
