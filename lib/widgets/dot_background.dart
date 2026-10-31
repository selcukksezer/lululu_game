import 'package:flutter/material.dart';
import '../theme/lululu_theme.dart';

/// Carbon void base + muted-titanium dot mesh (tasarım skill §3).
class DotBackground extends StatelessWidget {
  const DotBackground({
    super.key,
    required this.child,
    this.baseColor = LululuColors.carbonVoid,
    this.dotOpacity = 0.08,
    this.spacing = 14,
    this.dotRadius = 1.2,
    this.gradient,
  });

  final Widget child;
  final Color baseColor;
  final double dotOpacity;
  final double spacing;
  final double dotRadius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: baseColor,
        gradient: gradient,
      ),
      child: CustomPaint(
        painter: _DotMeshPainter(
          color: LululuColors.dotMesh(opacity: dotOpacity),
          spacing: spacing,
          dotRadius: dotRadius,
        ),
        child: child,
      ),
    );
  }
}

class _DotMeshPainter extends CustomPainter {
  _DotMeshPainter({
    required this.color,
    required this.spacing,
    required this.dotRadius,
  });

  final Color color;
  final double spacing;
  final double dotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;

    final paint = Paint()..color = color;
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotMeshPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.dotRadius != dotRadius;
  }
}
