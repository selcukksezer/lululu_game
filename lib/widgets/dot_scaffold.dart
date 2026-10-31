import 'package:flutter/material.dart';
import '../theme/lululu_theme.dart';

/// Dot mesh scaffold. [light] = white hub canvas for Ana sayfa.
class DotScaffold extends StatelessWidget {
  const DotScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.appBar,
    this.safeArea = true,
    this.lifted = true,
    this.light = false,
  });

  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;
  final bool safeArea;
  final bool lifted;
  final bool light;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (safeArea) {
      content = SafeArea(child: content);
    }
    return Scaffold(
      backgroundColor: light ? LululuColors.paper : LululuColors.spaceNavy,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: light
                  ? LululuGradients.paperSky
                  : (lifted
                      ? LululuGradients.liftedBg
                      : LululuGradients.carbonToNavy),
            ),
          ),
          CustomPaint(painter: _DotPainter(light: light)),
          content,
        ],
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({required this.light});

  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final step = light ? 20.0 : 18.0;
    final paint = Paint()
      ..color = light
          ? LululuColors.mutedTitanium.withValues(alpha: 0.08)
          : LululuColors.mutedTitanium.withValues(alpha: 0.11);
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), light ? 1.4 : 1.25, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter oldDelegate) =>
      oldDelegate.light != light;
}
