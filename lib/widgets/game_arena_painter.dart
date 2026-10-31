import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/insect_tier.dart';
import '../physics/physics_engine.dart';
import '../theme/lululu_theme.dart';

class GameArenaPainter extends CustomPainter {
  final CircularPhysicsEngine engine;
  final double dropperX;
  final InsectTier dropTier;
  final bool isDropping;
  final Map<String, ImageInfo?> insectImages;
  final double dangerPulse;
  final double dangerProximity;

  GameArenaPainter({
    required this.engine,
    required this.dropperX,
    required this.dropTier,
    required this.isDropping,
    required this.insectImages,
    this.dangerPulse = 0,
    this.dangerProximity = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = engine.arenaCenter;
    final radius = engine.arenaRadius;
    final bin = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2,
    );

    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          LululuColors.darkObsidian,
          LululuColors.carbonVoid,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    if (engine.squareArena) {
      canvas.drawRect(bin, bgPaint);
    } else {
      canvas.drawCircle(center, radius, bgPaint);
    }

    final borderGlow = Paint()
      ..color = (engine.squareArena
              ? LululuColors.cyberFuchsia
              : LululuColors.coralFlare)
          .withValues(alpha: 0.3 + dangerProximity * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final borderPaint = Paint()
      ..color = Color.lerp(
            LululuColors.liquidGold,
            LululuColors.mysticRuby,
            dangerProximity,
          )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    if (engine.squareArena) {
      canvas.drawRect(bin, borderGlow);
      canvas.drawRect(bin, borderPaint);
    } else {
      canvas.drawCircle(center, radius, borderGlow);
      canvas.drawCircle(center, radius, borderPaint);
    }

    // Danger line — pulse when near overflow.
    final dangerTopY = engine.dangerY;
    final pulse = 0.35 + dangerProximity * 0.45 + math.sin(dangerPulse) * 0.12;
    final dangerPaint = Paint()
      ..color = LululuColors.mysticRuby.withValues(alpha: pulse.clamp(0.2, 0.95))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 + dangerProximity * 2.5;
    canvas.drawLine(
      Offset(center.dx - radius * 0.65, dangerTopY),
      Offset(center.dx + radius * 0.65, dangerTopY),
      dangerPaint,
    );

    final blockPaint = Paint()..color = LululuColors.darkObsidian;
    final blockEdge = Paint()
      ..color = LululuColors.coralFlare
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final block in engine.blocks) {
      final rect = Rect.fromCircle(
        center: Offset(block.x, block.y),
        radius: block.radius,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        blockPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        blockEdge,
      );
    }
    if (dangerProximity > 0.55) {
      final warn = TextPainter(
        text: TextSpan(
          text: 'TEHLİKE',
          style: TextStyle(
            color: LululuColors.mysticRuby.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      warn.paint(
        canvas,
        Offset(center.dx - warn.width / 2, dangerTopY - 18),
      );
    }

    final clampedDropperX =
        dropperX.clamp(center.dx - radius * 0.7, center.dx + radius * 0.7);

    // Dashed aim guide.
    final guidePaint = Paint()
      ..color = dropTier.color.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    _drawDashedLine(
      canvas,
      Offset(clampedDropperX, center.dy - radius - 20),
      Offset(clampedDropperX, center.dy + radius * 0.55),
      guidePaint,
    );

    // Ghost landing silhouette — predicted rest on pile / jar floor.
    if (!isDropping) {
      final ghostY = engine.predictRestY(clampedDropperX, dropTier.radius);
      canvas.saveLayer(
        null,
        Paint()..color = const Color(0x55FFFFFF),
      );
      _drawInsectSprite(
        canvas,
        clampedDropperX,
        ghostY,
        dropTier,
        0,
        0.55,
      );
      canvas.restore();
      // Shorten aim dash to ghost.
      final tipPaint = Paint()
        ..color = dropTier.color.withValues(alpha: 0.55)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(clampedDropperX, ghostY), 5, tipPaint);
    }

    final funnelPaint = Paint()..color = LululuColors.warningSolar;
    final funnelPath = Path()
      ..moveTo(clampedDropperX - 16, center.dy - radius - 4)
      ..lineTo(clampedDropperX + 16, center.dy - radius - 4)
      ..lineTo(clampedDropperX, center.dy - radius + 12)
      ..close();
    canvas.drawPath(funnelPath, funnelPaint);

    if (!isDropping) {
      final dropY = center.dy - radius - 45;
      _drawInsectSprite(canvas, clampedDropperX, dropY, dropTier, 0.0, 1.0);
    }

    for (final body in engine.bodies) {
      _drawInsectSprite(
        canvas,
        body.x,
        body.y,
        body.tier,
        body.angle,
        body.spawnScale,
      );
    }

    for (final p in engine.particles) {
      final a = p.life.clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.angle);
      final chip = Paint()
        ..color = p.color.withValues(alpha: a)
        ..style = PaintingStyle.fill;
      final w = p.size * (1.1 + a * 0.6);
      final h = p.size * 0.55;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w * 2.4, height: h * 2),
          const Radius.circular(1.2),
        ),
        chip,
      );
      canvas.drawCircle(
        Offset.zero,
        p.size * 0.32 * a,
        Paint()..color = const Color(0x88FFFFFF).withValues(alpha: a * 0.45),
      );
      canvas.restore();
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 8.0;
    const gap = 6.0;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final nx = dx / len;
    final ny = dy / len;
    var t = 0.0;
    while (t < len) {
      final t2 = math.min(t + dash, len);
      canvas.drawLine(
        Offset(a.dx + nx * t, a.dy + ny * t),
        Offset(a.dx + nx * t2, a.dy + ny * t2),
        paint,
      );
      t += dash + gap;
    }
  }

  void _drawInsectSprite(
    Canvas canvas,
    double x,
    double y,
    InsectTier tier,
    double angle,
    double scale,
  ) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.scale(scale);

    final r = tier.radius;
    final imgInfo = insectImages[tier.assetPath];
    if (imgInfo != null) {
      final img = imgInfo.image;
      final srcRect =
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
      final maxSide = r * 2.15;
      final aspect = img.width / img.height;
      final double dw;
      final double dh;
      if (aspect >= 1) {
        dw = maxSide;
        dh = maxSide / aspect;
      } else {
        dh = maxSide;
        dw = maxSide * aspect;
      }
      final dstRect =
          Rect.fromCenter(center: Offset.zero, width: dw, height: dh);
      canvas.drawImageRect(
        img,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      final blob = Paint()..color = tier.color.withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: r * 1.7, height: r * 2.1),
          const Radius.circular(8),
        ),
        blob,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GameArenaPainter oldDelegate) => true;
}
