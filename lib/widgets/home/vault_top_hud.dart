import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../services/progress_manager.dart';
import '../../theme/lululu_theme.dart';

/// White-hub top bar — brand + currency + profile.
class VaultTopHud extends StatelessWidget {
  const VaultTopHud({
    super.key,
    required this.progress,
    this.onShopTap,
    this.onProfileTap,
  });

  final ProgressManager progress;
  final VoidCallback? onShopTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final stars = progress.totalStars;
    final coins = progress.coins;
    final level = progress.unlockedLevel.clamp(1, 80);

    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final auth = AuthService.instance;
        final name = auth.isSignedIn ? auth.displayName : 'Giriş';
        return Column(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  LululuGradients.paperHero.createShader(bounds),
              child: Text(
                'LÜLÜLÜ',
                textAlign: TextAlign.center,
                style: GoogleFonts.exo2(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.5,
                  height: 1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cockroach Merge Mania',
              style: GoogleFonts.exo2(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: LululuColors.mutedTitanium,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Pill(
                    icon: Icons.star_rounded,
                    iconColor: LululuColors.liquidGold,
                    label: 'YILDIZ',
                    value: _fmt(stars),
                    border: LululuColors.liquidGold,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onProfileTap,
                  behavior: HitTestBehavior.opaque,
                  child: _Profile(
                    name: name,
                    level: level,
                    signedIn: auth.isSignedIn,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onShopTap,
                    behavior: HitTestBehavior.opaque,
                    child: _Pill(
                      icon: Icons.diamond_rounded,
                      iconColor: LululuColors.cyberFuchsia,
                      label: 'COİN',
                      value: _fmt(coins),
                      border: LululuColors.cyberFuchsia,
                      trailing: Icons.add_circle_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.border,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color border;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: LululuMotion.minTap),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LululuColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: border.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.exo2(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: LululuColors.mutedTitanium,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.exo2(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.inkDark,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) Icon(trailing, size: 18, color: border),
        ],
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({
    required this.name,
    required this.level,
    required this.signedIn,
  });

  final String name;
  final int level;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LululuGradients.paperHero,
              boxShadow: [
                BoxShadow(
                  color: LululuColors.cyberFuchsia.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: const BoxDecoration(
                color: LululuColors.paper,
                shape: BoxShape.circle,
              ),
              child: Icon(
                signedIn ? Icons.pest_control_rounded : Icons.login_rounded,
                color: LululuColors.cyberFuchsia,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            signedIn ? name : 'Giriş',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: LululuColors.inkDark,
            ),
          ),
          Text(
            'Lv $level',
            style: GoogleFonts.exo2(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: LululuColors.coralFlare,
            ),
          ),
        ],
      ),
    );
  }
}
