import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/lululu_theme.dart';

/// Bitiş skoru → PNG kart → sistem paylaşım (Stories / WhatsApp / …).
class ScoreShareCard {
  ScoreShareCard._();
  static final instance = ScoreShareCard._();

  Future<void> share({
    required String modeTitle,
    required int score,
    int? best,
    String? line,
  }) async {
    final bytes = await _renderPng(
      modeTitle: modeTitle,
      score: score,
      best: best,
      line: line ?? 'Lülülü viral skor',
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/lululu_score_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: modeTitle.toLowerCase().contains('osmantuş')
            ? '$modeTitle · $score puan — Lülülü #lululu #osmantuş #ikili #viral'
            : '$modeTitle · $score puan — Lülülü #lululu #böcek #osmantuş #viral',
      ),
    );
  }

  Future<List<int>> _renderPng({
    required String modeTitle,
    required int score,
    int? best,
    required String line,
  }) async {
    const w = 1080.0;
    const h = 1350.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          LululuColors.carbonVoid,
          LululuColors.spaceNavy,
          Color(0xFF2A1020),
        ],
      ).createShader(const Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), bg);

    // Dot mesh
    final dot = Paint()..color = LululuColors.mutedTitanium.withValues(alpha: 0.12);
    for (double y = 40; y < h; y += 28) {
      for (double x = 40; x < w; x += 28) {
        canvas.drawCircle(Offset(x, y), 2.2, dot);
      }
    }

    final brand = TextPainter(
      text: TextSpan(
        text: 'LÜLÜLÜ',
        style: TextStyle(
          color: LululuColors.liquidGold,
          fontSize: 72,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 120);
    brand.paint(canvas, Offset((w - brand.width) / 2, 120));

    final mode = TextPainter(
      text: TextSpan(
        text: modeTitle.toUpperCase(),
        style: TextStyle(
          color: LululuColors.cyberFuchsia,
          fontSize: 42,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 120);
    mode.paint(canvas, Offset((w - mode.width) / 2, 230));

    final scoreTp = TextPainter(
      text: TextSpan(
        text: '$score',
        style: TextStyle(
          color: LululuColors.liquidGold,
          fontSize: 180,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 80);
    scoreTp.paint(canvas, Offset((w - scoreTp.width) / 2, 480));

    final sub = TextPainter(
      text: TextSpan(
        text: best != null && best > 0 ? 'REKOR $best' : 'SKOR',
        style: TextStyle(
          color: LululuColors.mutedTitanium,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 120);
    sub.paint(canvas, Offset((w - sub.width) / 2, 700));

    final lineTp = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          color: LululuColors.toxicNeon,
          fontSize: 40,
          fontWeight: FontWeight.w800,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 160);
    lineTp.paint(canvas, Offset((w - lineTp.width) / 2, 820));

    final foot = TextPainter(
      text: const TextSpan(
        text: 'lululu · viral böcek',
        style: TextStyle(
          color: LululuColors.mutedTitanium,
          fontSize: 28,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 120);
    foot.paint(canvas, Offset((w - foot.width) / 2, 1180));

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return byteData!.buffer.asUint8List();
  }
}
