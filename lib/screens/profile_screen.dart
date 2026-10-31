import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';

/// Oyuncu profili: avatar, isim, seviye + XP, istatistikler, rozetler.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // Mock profil verisi (gerçek profil servisi sonraki faz).
  static const _name = 'Apple Oyuncu';
  static const _level = 18;
  static const _xpNow = 1258;
  static const _xpMax = 2000;
  static const _totalScore = '7.915';
  static const _gamesPlayed = '48';
  static const _bestCombo = '×6';

  static const _badges = <_Badge>[
    _Badge(icon: Icons.rocket_launch_rounded, label: 'İLK UÇUŞ', unlocked: true),
    _Badge(icon: Icons.bolt_rounded, label: 'KOMBO X4', unlocked: true),
    _Badge(icon: Icons.merge_rounded, label: 'BİRLEŞTİRİCİ', unlocked: true),
    _Badge(icon: Icons.emoji_events_rounded, label: 'REKORCU', unlocked: false),
    _Badge(icon: Icons.videocam_rounded, label: 'YÖNETMEN', unlocked: false),
    _Badge(icon: Icons.diamond_rounded, label: 'ZENGİN', unlocked: false),
  ];

  @override
  Widget build(BuildContext context) {
    final xpT = (_xpNow / _xpMax).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: LululuColors.paper,
      appBar: AppBar(
        backgroundColor: LululuColors.paper,
        foregroundColor: LululuColors.inkDark,
        elevation: 0,
        title: Text(
          'OYUNCU PROFİLİ',
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LululuGradients.paperHero,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LululuColors.paper,
                    border: Border.all(
                      color: LululuColors.paper,
                      width: 3,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/design/bugs_hd/tier5_hd.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: LululuColors.mutedTitanium,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _name,
                  style: GoogleFonts.exo2(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: LululuColors.paper,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@apple · Apple ile giriş yapıldı',
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LululuColors.paper.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: LululuColors.inkDark.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'SEVİYE $_level',
                    style: GoogleFonts.exo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: LululuColors.liquidGold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: xpT),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 12,
                      backgroundColor:
                          LululuColors.paper.withValues(alpha: 0.25),
                      color: LululuColors.liquidGold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'XP $_xpNow / $_xpMax',
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: LululuColors.paper,
                      ),
                    ),
                    Text(
                      'SONRAKİ SEVİYE',
                      style: GoogleFonts.exo2(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color:
                            LululuColors.paper.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: _StatTile(
                  label: 'TOPLAM SKOR',
                  value: _totalScore,
                  icon: Icons.star_rounded,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'OYNANAN OYUN',
                  value: _gamesPlayed,
                  icon: Icons.sports_esports_rounded,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'EN YÜKSEK KOMBO',
                  value: _bestCombo,
                  icon: Icons.bolt_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ROZETLERİM',
                  style: GoogleFonts.exo2(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: LululuColors.inkDark,
                  ),
                ),
              ),
              Text(
                '3/6',
                style: GoogleFonts.exo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: LululuColors.mutedTitanium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: _badges.length,
            itemBuilder: (context, i) => _BadgeTile(badge: _badges[i]),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: LululuColors.paperSoft,
        borderRadius: BorderRadius.circular(LululuRadii.card),
      ),
      child: Column(
        children: [
          Icon(icon, color: LululuColors.cyberFuchsia, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.exo2(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: LululuColors.inkDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.exo2(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: LululuColors.mutedTitanium,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge {
  const _Badge({
    required this.icon,
    required this.label,
    required this.unlocked,
  });

  final IconData icon;
  final String label;
  final bool unlocked;
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: badge.unlocked
            ? LululuColors.liquidGold.withValues(alpha: 0.14)
            : LululuColors.paperSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badge.unlocked
              ? LululuColors.liquidGold.withValues(alpha: 0.5)
              : LululuColors.mutedTitanium.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                badge.icon,
                size: 36,
                color: badge.unlocked
                    ? LululuColors.liquidGold
                    : LululuColors.mutedTitanium.withValues(alpha: 0.5),
              ),
              if (!badge.unlocked)
                const Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: LululuColors.mutedTitanium,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.exo2(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: badge.unlocked
                  ? LululuColors.inkDark
                  : LululuColors.mutedTitanium,
            ),
          ),
        ],
      ),
    );
  }
}
