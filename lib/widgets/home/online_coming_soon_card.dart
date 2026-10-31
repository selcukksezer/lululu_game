import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/cloud_sync_service.dart';
import '../../services/firebase_bootstrap.dart';
import '../../services/friend_invite_service.dart';
import '../../theme/lululu_theme.dart';

/// Ana sayfa: Online mod yakında + sohbet / giriş CTA.
class OnlineComingSoonCard extends StatefulWidget {
  const OnlineComingSoonCard({
    super.key,
    this.onChat,
    this.onAuth,
  });

  final VoidCallback? onChat;
  final VoidCallback? onAuth;

  @override
  State<OnlineComingSoonCard> createState() => _OnlineComingSoonCardState();
}

class _OnlineComingSoonCardState extends State<OnlineComingSoonCard> {
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    CloudSyncService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    CloudSyncService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sync = CloudSyncService.instance;
    final linked = sync.onlineEnabled;
    return AnimatedScale(
      scale: _pressed ? LululuMotion.pressScale : 1,
      duration: LululuMotion.pressDuration,
      curve: LululuMotion.elastic,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(LululuRadii.card),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LululuColors.spaceNavy,
              LululuColors.carbonVoid,
              LululuColors.cyberFuchsia.withValues(alpha: 0.28),
            ],
          ),
          border: Border.all(
            color: LululuColors.toxicNeon.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: LululuColors.toxicNeon.withValues(alpha: 0.2),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LululuRadii.card),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _DotsPainter()),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: LululuColors.warningSolar.withValues(
                              alpha: 0.18,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: LululuColors.warningSolar.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                          child: Text(
                            linked
                                ? (FirebaseBootstrap.ready
                                    ? 'BAĞLI'
                                    : 'KUYRUK')
                                : 'GİRİŞ',
                            style: GoogleFonts.exo2(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: linked
                                  ? LululuColors.toxicNeon
                                  : LululuColors.warningSolar,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          linked
                              ? Icons.cloud_done_rounded
                              : Icons.wifi_tethering_rounded,
                          color: LululuColors.toxicNeon,
                          size: 18,
                        ),
                        const Spacer(),
                        Text(
                          'ONLINE',
                          style: GoogleFonts.exo2(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: LululuColors.mutedTitanium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      linked ? 'Senkron Hazır' : 'Online Lobby',
                      style: GoogleFonts.exo2(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: LululuColors.ink,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sync.status,
                      style: GoogleFonts.exo2(
                        fontSize: 12,
                        height: 1.35,
                        color: LululuColors.mutedTitanium,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _CtaButton(
                            label: 'GİRİŞ YAP',
                            accent: LululuColors.liquidGold,
                            onTap: widget.onAuth,
                            primary: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CtaButton(
                            label: 'SOHBET',
                            accent: LululuColors.cyberFuchsia,
                            onTap: widget.onChat,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _CtaButton(
                            label: 'DAVET / RİVAL',
                            accent: LululuColors.toxicNeon,
                            onTap: () => FriendInviteService.instance.shareInvite(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CtaButton(
                            label: 'LOBİ SYNC',
                            accent: LululuColors.warningSolar,
                            onTap: () async {
                              await CloudSyncService.instance
                                  .enableOnlineWhenSignedIn();
                              await CloudSyncService.instance
                                  .enqueueLeaderboardPush();
                              await CloudSyncService.instance.enqueueChatPush();
                              await CloudSyncService.instance.flushPending();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 420.ms)
        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);
  }
}

class _CtaButton extends StatefulWidget {
  const _CtaButton({
    required this.label,
    required this.accent,
    this.onTap,
    this.primary = false,
  });

  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool primary;

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          constraints: const BoxConstraints(minHeight: LululuMotion.minTap),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: widget.primary
                ? const LinearGradient(
                    colors: [
                      LululuColors.liquidGold,
                      LululuColors.warningSolar,
                    ],
                  )
                : null,
            color: widget.primary ? null : LululuColors.darkObsidian,
            borderRadius: BorderRadius.circular(LululuRadii.pill),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: LululuColors.liquidGold.withValues(alpha: 0.42),
                      blurRadius: 16,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                    ),
                  ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.exo2(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: widget.primary
                  ? LululuColors.carbonVoid
                  : LululuColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 13.0;
    final paint = Paint()..color = LululuColors.dotMesh(opacity: 0.1);
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
