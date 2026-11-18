import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/insect_tier.dart';
import '../physics/physics_engine.dart';
import '../theme/lululu_theme.dart';

class GameArenaPainter extends CustomPainter {
  /// Görsel/fizik oranı: karakter PNG'leri dik portre (tier1 en-boy
  /// 0.37, tier5 0.50) — çarpışma dairesi boyunda çizilince böcekler
  /// olduğundan küçük ve ayrık görünüyordu (Selçuk, 2026-11-18:
  /// "arada çok boşluk var"). Fizik aynen durur; yalnız çizim
  /// büyütülür, komşular görselde birbirine değer.
  static const double _spriteVisualScale = 1.55;

  final CircularPhysicsEngine engine;
  final Map<String, ImageInfo?> insectImages;
  final double dangerPulse;
  final double dangerProximity;
  final bool transparentSquareArena;
  final double coneSpriteScale;
  final double? dropperX;
  final InsectTier? currentDropperTier;
  final bool showDropperPreview;
  final String dangerLineLabel;
  final String dangerAlertLabel;

  GameArenaPainter({
    required this.engine,
    required this.insectImages,
    this.dangerPulse = 0,
    this.dangerProximity = 0,
    this.transparentSquareArena = false,
    this.coneSpriteScale = 1,
    this.dropperX,
    this.currentDropperTier,
    this.showDropperPreview = false,
    required this.dangerLineLabel,
    required this.dangerAlertLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = engine.arenaCenter;
    final radius = engine.arenaRadius;
    final bin = engine.arenaBounds;

    if (engine.squareArena) {
      if (!transparentSquareArena) {
        final bgPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x3D111923), Color(0x4D111923), Color(0xB0111923)],
            stops: [0, 0.52, 1],
          ).createShader(bin);
        canvas.drawRect(bin, bgPaint);
      }
    } else {
      final bgPaint = Paint()
        ..shader = const RadialGradient(
          colors: [LululuColors.darkObsidian, LululuColors.carbonVoid],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, bgPaint);
    }

    if (!engine.squareArena) {
      final borderGlow = Paint()
        ..color = LululuColors.coralFlare.withValues(
          alpha: 0.3 + dangerProximity * 0.35,
        )
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
      canvas.drawCircle(center, radius, borderGlow);
      canvas.drawCircle(center, radius, borderPaint);
    }

    // Danger line — pulse when near overflow.
    final dangerTopY = engine.dangerY;
    final pulse = 0.35 + dangerProximity * 0.45 + math.sin(dangerPulse) * 0.12;
    final dangerPaint = Paint()
      ..color = LululuColors.mysticRuby.withValues(
        alpha: pulse.clamp(0.2, 0.95),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 + dangerProximity * 2.5;
    if (engine.squareArena) {
      _drawDashedLine(
        canvas,
        Offset(bin.left + 8, dangerTopY),
        Offset(bin.right - 8, dangerTopY),
        dangerPaint,
      );
    } else {
      canvas.drawLine(
        Offset(center.dx - radius * 0.65, dangerTopY),
        Offset(center.dx + radius * 0.65, dangerTopY),
        dangerPaint,
      );
    }

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
    if (dangerProximity > 0.55 || showDropperPreview) {
      final warn = TextPainter(
        text: TextSpan(
          text: dangerProximity > 0.55 ? dangerAlertLabel : dangerLineLabel,
          style: TextStyle(
            color: LululuColors.mysticRuby.withValues(
              alpha: dangerProximity > 0.55 ? 0.92 : 0.62,
            ),
            fontSize: dangerProximity > 0.55 ? 11 : 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final tx = engine.squareArena
          ? (bin.right - warn.width - 10)
          : (center.dx - warn.width / 2);
      final ty = engine.squareArena
          ? math.max(2.0, dangerTopY + 4)
          : (dangerTopY - 18);
      warn.paint(canvas, Offset(tx, ty));
    }

    // Nişan kılavuz çizgisi (dropGuide) + hayalet önizleme + üstteki bırakılacak böcek (dropPreview)
    if (showDropperPreview &&
        dropperX != null &&
        currentDropperTier != null) {
      final tier = currentDropperTier!;
      final clampedX = engine.squareArena
          ? dropperX!.clamp(bin.left + tier.radius, bin.right - tier.radius)
          : dropperX!.clamp(
              center.dx - radius + tier.radius,
              center.dx + radius - tier.radius,
            );
      final restY = engine.predictRestY(clampedX, tier.radius);
      final previewY = math.max(tier.radius + 4, dangerTopY + 14);

      if (restY > previewY + 8) {
        final guidePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;
        _drawDashedLine(
          canvas,
          Offset(clampedX, previewY + tier.radius * 0.65),
          Offset(clampedX, restY),
          guidePaint,
        );

        // Hedef noktada yarı saydam önizleme (showGhost)
        final ghostRing = Paint()
          ..color = tier.color.withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawCircle(Offset(clampedX, restY), tier.radius * 0.92, ghostRing);
        _drawInsectSprite(
          canvas,
          clampedX,
          restY,
          tier,
          0,
          0.95,
          opacity: 0.34,
        );
      }

      // Üstte bırakılacak aktif böcek (dropPreview)
      _drawInsectSprite(
        canvas,
        clampedX,
        previewY,
        tier,
        0,
        1.0,
        opacity: 0.96,
      );
    }

    for (final body in engine.bodies) {
      _drawInsectSprite(
        canvas,
        body.x,
        body.y,
        body.tier,
        body.angle,
        body.spawnScale,
        squash: body.mergeSquash,
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
    double scale, {
    double opacity = 1.0,
    double squash = 0,
  }) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    final impact = squash.clamp(0.0, 1.0);
    final tierScale = tier == InsectTier.cone ? coneSpriteScale : 1;
    canvas.scale(
      scale * tierScale * (1 + impact * 0.16),
      scale * tierScale * (1 - impact * 0.12),
    );

    final r = tier.radius;
    final imgInfo = insectImages[tier.assetPath];
    if (imgInfo != null) {
      final img = imgInfo.image;
      final srcRect = Rect.fromLTWH(
        0,
        0,
        img.width.toDouble(),
        img.height.toDouble(),
      );
      final maxSide = r * 2 * _spriteVisualScale;
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
      final dstRect = Rect.fromCenter(
        center: Offset.zero,
        width: dw,
        height: dh,
      );
      final spritePaint = Paint()..filterQuality = FilterQuality.medium;
      if (opacity < 1.0) {
        spritePaint.color = Color.fromRGBO(255, 255, 255, opacity);
      }
      canvas.drawImageRect(img, srcRect, dstRect, spritePaint);
    } else {
      final blob = Paint()
        ..color = tier.color.withValues(alpha: 0.85 * opacity);
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
