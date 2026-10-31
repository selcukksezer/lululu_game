import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Decorative CC0 GLB prop marker (bundle includes GLB; no WebView 3D viewer).
enum ArenaPropKind {
  bee('assets/models/prop_Bee.glb', Icons.emoji_nature, Color(0xFFFFB800));

  const ArenaPropKind(this.glbAssetPath, this.icon, this.accent);

  final String glbAssetPath;
  final IconData icon;
  final Color accent;
}

/// Small corner ornament on campaign / Suika screens — GLB shipped for future 3D.
class ArenaPropGlb extends StatelessWidget {
  const ArenaPropGlb({
    super.key,
    this.kind = ArenaPropKind.bee,
    this.size = 52,
  });

  final ArenaPropKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.35),
            border: Border.all(color: kind.accent.withValues(alpha: 0.55), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: kind.accent.withValues(alpha: 0.25),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(kind.icon, color: kind.accent, size: size * 0.45),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -4, duration: 2200.ms, curve: Curves.easeInOut),
      ),
    );
  }
}
