import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../theme/lululu_theme.dart';
import 'home_shell.dart';

/// İlk açılış 3 ekran — marka / oyun / viral.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const prefsKey = 'LululuOnboardingDoneV1';

  static Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKey) ?? false;
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int _index = 0;
  double _progress = 0.78;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.prefsKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  void _nextSlide() {
    if (_index < 2) {
      _page.animateToPage(
        _index + 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() => _index = 0);
      _page.animateToPage(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LululuColors.carbonVoid,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // WebP ikizi (283 KB, 3.2 MB PNG ile piksel-birebir aynı kare;
          // S2#34): preloader da bu dosyayı ısıtıyor.
          Image.asset(
            'assets/design/splash/bg_splash.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: LululuColors.carbonVoid),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x88080B12),
                  Color(0xD8080B12),
                  Color(0xF2080B12),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 700;
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        isCompact ? 6 : 12,
                        18,
                        isCompact ? 8 : 14,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 1. Header: LÜLÜLÜ banner logo + h1 + COCKROACH MERGE MANIA subtitle
                          _buildHeader(isCompact: isCompact),
                          SizedBox(height: isCompact ? 6 : 10),

                          // 2. Center 3-slide onb-card
                          _buildOnboardingCard(isCompact: isCompact),
                          SizedBox(height: isCompact ? 8 : 12),

                          // 3. Bottom splash-loader + DOKUN VE BAŞLA! + version
                          _buildBottomSection(),
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

  Widget _buildHeader({bool isCompact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: isCompact ? 68 : 92,
          child: Image.asset(
            // WebP ikizi (81 KB, PNG ile piksel-birebir aynı; S2#34).
            'assets/design/splash/splash_logo.webp',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.appName,
          style: GoogleFonts.bangers(
            fontSize: isCompact ? 32 : 38,
            letterSpacing: 2.0,
            height: 1.0,
            color: const Color(0xFFFFD34D),
            shadows: const [
              Shadow(
                color: Color(0xB3000000),
                offset: Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          context.l10n.onboardingTagline,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
            color: const Color(0xFFE01E5A),
          ),
        ),
      ],
    );
  }

  Widget _buildOnboardingCard({bool isCompact = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        16,
        isCompact ? 10 : 14,
        16,
        isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xD9121826),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0x4DFFD34D),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: isCompact ? 220 : 250,
            child: PageView(
              controller: _page,
              onPageChanged: (i) => setState(() => _index = i),
              children: [
                _buildSlide1(),
                _buildSlide2(),
                _buildSlide3(),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // onb-dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final active = i == _index;
              return Semantics(
                button: true,
                selected: active,
                label: context.l10n.onboardingPageLabel(i + 1),
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => _page.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 26 : 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFFFB800)
                        : const Color(0x4DFFFFFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // SONRAKİ ADIM → / Atla buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Semantics(
                  button: true,
                  label: context.l10n.onboardingNextLabel,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: _nextSlide,
                  child: Container(
                    height: 48,
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFCF3F), Color(0xFFF59E00)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF9E6500),
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.l10n.onboardingNextStep,
                        style: GoogleFonts.baloo2(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2E1A00),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Semantics(
                  button: true,
                  label: context.l10n.onboardingSkipLabel,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: _finish,
                  child: Container(
                    height: 48,
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0x4DFFFFFF),
                        width: 1.5,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        context.l10n.skip,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Slayt 1 (1 / 3): Böcekleri Birleştir, Evrimleştir! + tier 1 → 2 → 8 görsel akışı + açıklama
  Widget _buildSlide1() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepBadge('1 / 3'),
        const SizedBox(height: 8),
        Text(
          context.l10n.onboardingSlide1Title,
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFFD34D),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTierBox('assets/design/bugs_hd/tier1_hd.png', context.l10n.tierLabel(1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '→',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFB800),
                ),
              ),
            ),
            _buildTierBox('assets/design/bugs_hd/tier2_hd.png', context.l10n.tierLabel(2)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '→',
                style: GoogleFonts.baloo2(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE01E5A),
                ),
              ),
            ),
            _buildTierBox(
              'assets/design/bugs_hd/tier8_hd.png',
              context.l10n.tierLabel(8),
              highlight: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.onboardingSlide1Body,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xD9FFFFFF),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  // Slayt 2 (2 / 3): 11 Farklı Oyun Modu & 3'er Bonus! + F16, Raid, Terlik mini kartları + açıklama
  Widget _buildSlide2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepBadge('2 / 3'),
        const SizedBox(height: 8),
        Text(
          context.l10n.onboardingSlide2Title,
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFFD34D),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBoosterMiniCard('✈️', 'F16', context.l10n.boosterF16Sub),
            const SizedBox(width: 8),
            _buildBoosterMiniCard('🧴', 'Raid', context.l10n.boosterRaidSub),
            const SizedBox(width: 8),
            _buildBoosterMiniCard(
              '🩴',
              context.l10n.boosterSlipperTitle,
              context.l10n.boosterSlipperSub,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.onboardingSlide2Body,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xD9FFFFFF),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  // Slayt 3 (3 / 3): Böcek Stüdyo, GIF & Liderlik! + stüdyo önizleme kartları + açıklama
  Widget _buildSlide3() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepBadge('3 / 3'),
        const SizedBox(height: 8),
        Text(
          context.l10n.onboardingSlide3Title,
          textAlign: TextAlign.center,
          style: GoogleFonts.baloo2(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFFD34D),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBoosterMiniCard(
              '🎨',
              context.l10n.onboardingStudioTitle,
              context.l10n.onboardingStudioSub,
            ),
            const SizedBox(width: 8),
            _buildBoosterMiniCard(
              '🎬',
              context.l10n.onboardingGifTitle,
              context.l10n.onboardingGifSub,
            ),
            const SizedBox(width: 8),
            _buildBoosterMiniCard(
              '🏆',
              context.l10n.onboardingLeaderboardTitle,
              context.l10n.onboardingLeaderboardSub,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.onboardingSlide3Body,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xD9FFFFFF),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildStepBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE01E5A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.baloo2(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildTierBox(String asset, String label, {bool highlight = false}) {
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: highlight ? const Color(0x33FFB800) : const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? const Color(0xFFFFB800) : const Color(0x40FFFFFF),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            asset,
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.bug_report_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.baloo2(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: highlight ? const Color(0xFFFFD34D) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoosterMiniCard(String emoji, String title, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0x40FFFFFF),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              title,
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFD34D),
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xB3FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    final pct = (_progress * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // splash-loader (%78 progress bar)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x99121826),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.onboardingLoadingText,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xD9FFFFFF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '%$pct',
                    style: GoogleFonts.baloo2(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFD34D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 10,
                  width: double.infinity,
                  child: ColoredBox(
                    color: const Color(0x33FFFFFF),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: _progress.clamp(0.0, 1.0),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFFB800),
                              Color(0xFFFF6B4A),
                              Color(0xFFE01E5A),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // DOKUN VE BAŞLA! (btn-green)
        Semantics(
          button: true,
          label: context.l10n.onboardingTapToStartLabel,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () {
              setState(() => _progress = 1.0);
              _finish();
            },
          child: Container(
            width: double.infinity,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF37E08B),
                  Color(0xFF12B76A),
                  Color(0xFF0A9553),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF066C3C),
                  offset: Offset(0, 5),
                ),
                BoxShadow(
                  color: Color(0x59000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              context.l10n.onboardingTapToStart,
              style: GoogleFonts.baloo2(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        ),
        const SizedBox(height: 10),

        // Version text
        Text(
          context.l10n.onboardingVersionLine,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0x8CFFFFFF),
          ),
        ),
      ],
    );
  }
}
