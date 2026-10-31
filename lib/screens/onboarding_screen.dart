import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/lululu_theme.dart';
import '../widgets/dot_scaffold.dart';
import '../widgets/sticker_image.dart';
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
  final _page = PageController();
  int _index = 0;

  static const _pages = [
    (
      'LÜLÜLÜ',
      'Viral hamamböceği. Merge, ritm, çığlık.',
      'assets/images/stickers/sticker_tier1_cone.png',
    ),
    (
      'OYNA',
      'Suika + 8 arcade mod. Kampanya 80 seviye.',
      'assets/images/stickers/sticker_tier6_can.png',
    ),
    (
      'PAYLAŞ',
      'Skor kartı, GIF, böcek videosu. Stories’e at.',
      'assets/images/stickers/sticker_tier3_fan.png',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.prefsKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DotScaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final p = _pages[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(28, 48, 28, 16),
                  child: Column(
                    children: [
                      const Spacer(),
                      StickerImage(assetPath: p.$3, size: 160),
                      const SizedBox(height: 28),
                      Text(
                        p.$1,
                        style: GoogleFonts.exo2(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: LululuColors.liquidGold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        p.$2,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.exo2(
                          fontSize: 16,
                          height: 1.35,
                          color: LululuColors.mutedTitanium,
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) {
              final on = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: on ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: on
                      ? LululuColors.liquidGold
                      : LululuColors.darkObsidian,
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  if (_index >= _pages.length - 1) {
                    _finish();
                  } else {
                    _page.nextPage(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: LululuColors.cyberFuchsia,
                  foregroundColor: LululuColors.ink,
                ),
                child: Text(
                  _index >= _pages.length - 1 ? 'BAŞLA' : 'DEVAM',
                  style: GoogleFonts.exo2(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
