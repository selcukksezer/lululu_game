import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';

/// 1:1 Pixel-Perfect Rewarded Ad overlay matching `#adOverlay` in `LÜLÜLÜ UI:UX Tasarım.html`.
Future<bool> showRewardedAdMock(
  BuildContext context, {
  required String rewardLabel,
}) async {
  AudioManager().playPop();
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xFF05070C),
    useSafeArea: false,
    builder: (_) => _AdMockOverlay(rewardLabel: rewardLabel),
  );
  return result ?? false;
}

class _AdMockOverlay extends StatefulWidget {
  const _AdMockOverlay({required this.rewardLabel});

  final String rewardLabel;

  @override
  State<_AdMockOverlay> createState() => _AdMockOverlayState();
}

class _AdMockOverlayState extends State<_AdMockOverlay>
    with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 5;
  int _remaining = _totalSeconds;
  Timer? _timer;
  late final AnimationController _progCtl;

  @override
  void initState() {
    super.initState();
    _progCtl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalSeconds),
    )..forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        setState(() => _remaining = 0);
        t.cancel();
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progCtl.dispose();
    super.dispose();
  }

  void _claim() {
    if (_remaining > 0) return;
    AudioManager().playPop();
    Navigator.of(context).pop(true);
  }

  String _resolveRewardAsset(String label) {
    final upper = label.toUpperCase();
    if (upper.contains('ENERJ') || upper.contains('DEVAM')) {
      return 'assets/design/ui/hub_3_ep-heart.webp';
    }
    if (upper.contains('ALTIN') || upper.contains('COİN') || upper.contains('COIN')) {
      return 'assets/res_coin.png';
    }
    return 'assets/icons2/chest_gold.png';
  }

  @override
  Widget build(BuildContext context) {
    final ready = _remaining == 0;
    final topPad = MediaQuery.of(context).viewPadding.top;

    return Material(
      color: const Color(0xFF05070C),
      child: Column(
        children: [
          // `.ad-topbar`
          Container(
            padding: EdgeInsets.fromLTRB(14, topPad + 14, 14, 10),
            color: const Color(0xFF05070C),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE01E5A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'REKLAM',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.99,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ready ? 'Reklam bitti' : 'Ödül için $_remaining sn izle',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xD9FFFFFF),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: ready ? _claim : null,
                  child: Opacity(
                    opacity: ready ? 1.0 : 0.85,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ready
                            ? const Color(0xFFE52E2E)
                            : const Color(0x24FFFFFF),
                        border: Border.all(
                          color: ready
                              ? const Color(0xFFFF8A8A)
                              : const Color(0x59FFFFFF),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        ready ? '✕' : '$_remaining',
                        style: GoogleFonts.baloo2(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // `.ad-body`
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // `img.bgimg`
                Positioned.fill(
                  child: Image.asset(
                    'assets/design/splash/bg_splash.webp',
                    fit: BoxFit.cover,
                  ),
                ),
                // `.shade`
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.4, 1.0],
                        colors: [
                          Color(0x40080B12),
                          Color(0x0D080B12),
                          Color(0xE0080B12),
                        ],
                      ),
                    ),
                  ),
                ),
                // `.ad-promo`
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // `img.logo` (`width: 72%; max-width: 250px`)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 250),
                          child: FractionallySizedBox(
                            widthFactor: 0.72,
                            child: Container(
                              decoration: const BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x80000000),
                                    offset: Offset(0, 8),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/design/splash/splash_logo.webp',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        // `.bug` (`104x104`, `margin-bottom: 2px`)
                        Container(
                          width: 104,
                          height: 104,
                          margin: const EdgeInsets.only(bottom: 2),
                          child: Image.asset(
                            'assets/design/splash/splash_mascot.webp',
                            width: 104,
                            height: 104,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // `h3`
                        Text(
                          'LÜLÜLÜ · Cockroach Merge Mania',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.baloo2(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.12,
                            shadows: const [
                              Shadow(
                                color: Color(0x73000000),
                                offset: Offset(0, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // `p`
                        Text(
                          "Böcekleri birleştir, Pembe Bornozlu'ya kadar evrimleştir!\n10 oyun modu · Ücretsiz oyna",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xEBFFFFFF),
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 14),
                        // `.btn` (`ŞİMDİ OYNA`)
                        Container(
                          constraints: const BoxConstraints(
                            minHeight: 52,
                            minWidth: 190,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.0, 0.55, 1.0],
                              colors: [
                                Color(0xFFFFCF3F),
                                Color(0xFFFFB800),
                                Color(0xFFF59E00),
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFFB97A00),
                                offset: Offset(0, 5),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: Color(0x47000000),
                                offset: Offset(0, 10),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          width: 190,
                          child: Text(
                            'ŞİMDİ OYNA',
                            style: GoogleFonts.baloo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.36,
                              height: 1.0,
                              shadows: const [
                                Shadow(
                                  color: Color(0x59784000),
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
                // `.ad-reward` overlay when ready
                if (ready)
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xE005070C),
                      padding: const EdgeInsets.all(26),
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: const BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x80000000),
                                      offset: Offset(0, 8),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  _resolveRewardAsset(widget.rewardLabel),
                                  width: 88,
                                  height: 88,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Text(
                                'ÖDÜLÜN HAZIR!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.bangers(
                                  fontSize: 40,
                                  letterSpacing: 1.0,
                                  color: const Color(0xFFFFB800),
                                  height: 1.05,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0xE6080B12),
                                      offset: Offset(0, 3),
                                      blurRadius: 0,
                                    ),
                                    Shadow(
                                      color: Color(0x99FF6B35),
                                      offset: Offset.zero,
                                      blurRadius: 22,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.rewardLabel} kazandın!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xE6FFFFFF),
                                ),
                              ),
                              const SizedBox(height: 18),
                              GestureDetector(
                                onTap: _claim,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 52,
                                    minWidth: 210,
                                  ),
                                  width: 210,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 26,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: [0.0, 0.55, 1.0],
                                      colors: [
                                        Color(0xFF37E08B),
                                        Color(0xFF12B76A),
                                        Color(0xFF0A9553),
                                      ],
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0xFF066C3C),
                                        offset: Offset(0, 5),
                                        blurRadius: 0,
                                      ),
                                      BoxShadow(
                                        color: Color(0x47000000),
                                        offset: Offset(0, 10),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'ÖDÜLÜ AL',
                                    style: GoogleFonts.baloo2(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.36,
                                      height: 1.0,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x59784000),
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
                  ),
              ],
            ),
          ),
          // `.ad-progress`
          Container(
            height: 6,
            width: double.infinity,
            color: const Color(0x2EFFFFFF),
            alignment: Alignment.centerLeft,
            child: AnimatedBuilder(
              animation: _progCtl,
              builder: (context, _) {
                return FractionallySizedBox(
                  widthFactor: _progCtl.value.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFFB800),
                          Color(0xFFFF6B35),
                        ],
                      ),
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
}
