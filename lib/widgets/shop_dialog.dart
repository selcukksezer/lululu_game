import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/audio_manager.dart';
import '../theme/lululu_theme.dart';
import 'ad_mock.dart';
import 'lululu_press.dart';

/// MAĞAZA sekmesi. Dock tab `embedded` kullanır; coin hapı [ShopDialog.show]
/// ile açar. Tüm satın almalar mock — IapService'e dokunulmaz.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.embedded = true});

  final bool embedded;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class ShopDialog {
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, _, _) => const ShopScreen(embedded: false),
        transitionsBuilder: (_, anim, _, child) {
          final curved =
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _ShopScreenState extends State<ShopScreen> {
  // Mock enerji durumu.
  int _energy = 24;
  static const _energyMax = 30;

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _watchAdForEnergy() async {
    final ok = await showRewardedAdMock(
      context,
      rewardLabel: '+10 ENERJİ',
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _energy = (_energy + 10).clamp(0, _energyMax));
      AudioManager().playWin();
      _toast('Ödül alındı: +10 enerji');
    }
  }

  void _mockBuy(String title) {
    AudioManager().playPop();
    _toast('$title yakında satışta — mock');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          'MAĞAZA',
          style: GoogleFonts.exo2(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionTitle(title: 'ENERJİ'),
          _ProductCard(
            icon: Icons.bolt_rounded,
            accent: LululuColors.liquidGold,
            title: 'ENERJİ PAKETİ',
            subtitle: '+10 enerji — reklam izle',
            action: _AdButton(onTap: _watchAdForEnergy),
          ),
          const SizedBox(height: 10),
          _ProductCard(
            icon: Icons.favorite_rounded,
            accent: LululuColors.cyberFuchsia,
            title: 'ENERJİ DEPOSU',
            subtitle: '$_energy/$_energyMax kalp',
            action: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: LululuColors.mutedTitanium.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _energy >= _energyMax ? 'DOLU' : 'DOLUYOR',
                style: GoogleFonts.exo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.mutedTitanium,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'COİN'),
          _ProductCard(
            icon: Icons.monetization_on_rounded,
            accent: LululuColors.warningSolar,
            title: 'KÜÇÜK KESE',
            subtitle: '500 coin',
            action: _BuyButton(
              label: '29,99 ₺',
              onTap: () => _mockBuy('Küçük Kese'),
            ),
          ),
          const SizedBox(height: 10),
          _ProductCard(
            icon: Icons.account_balance_wallet_rounded,
            accent: LululuColors.coralFlare,
            title: 'BÜYÜK KASA',
            subtitle: '2.500 coin + 250 bonus',
            action: _BuyButton(
              label: '99,99 ₺',
              onTap: () => _mockBuy('Büyük Kasa'),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'KOSTÜM'),
          _ProductCard(
            icon: Icons.bug_report_rounded,
            accent: LululuColors.liquidGold,
            title: 'ALTIN BÖCEK KOSTÜMÜ',
            subtitle: 'Böceklerin altın zırhı — 1.500 coin',
            action: _BuyButton(
              label: 'SATIN AL',
              onTap: () => _mockBuy('Altın Böcek Kostümü'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.exo2(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: LululuColors.inkDark,
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LululuColors.paper,
        borderRadius: BorderRadius.circular(LululuRadii.card),
        border: Border.all(
          color: LululuColors.mutedTitanium.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.inkDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          action,
        ],
      ),
    );
  }
}

class _BuyButton extends StatelessWidget {
  const _BuyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 88),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LululuGradients.fuchsiaToGold,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: LululuColors.paper,
          ),
        ),
      ),
    );
  }
}

class _AdButton extends StatelessWidget {
  const _AdButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LululuPress(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LululuColors.inkDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              color: LululuColors.liquidGold,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'REKLAM İZLE',
              style: GoogleFonts.exo2(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: LululuColors.paper,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
