import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../theme/lululu_theme.dart';

/// Bitiş skoru → PNG kart → sistem paylaşım (Stories / WhatsApp / …).
class ScoreShareCard {
  ScoreShareCard._();
  static final instance = ScoreShareCard._();

  /// Skor kartını render edip sistem paylaşımını açar.
  ///
  /// Başarıda `true` döner. Web'de dosya API'si olmadığı için paylaşım
  /// yapılamaz ve `false` döner (erken dönüş, fırlatma yok); render veya
  /// paylaşım hatasında da `false` döner. Hiçbir durumda fırlatmaz:
  /// çağıran `false` durumunda kullanıcıya görünür bildirim gösterir.
  /// Geçici PNG dosyası paylaşım bitince (başarıda da hatada da) silinir.
  Future<bool> share({
    required AppLocalizations l10n,
    required String modeTitle,
    required int score,
    int? best,
    String? line,
  }) async {
    if (kIsWeb) {
      return false;
    }
    File? tempFile;
    try {
      final bytes = await _renderPng(
        l10n: l10n,
        modeTitle: modeTitle,
        score: score,
        best: best,
        line: line ?? 'Lülülü viral skor',
      );
      final dir = await getTemporaryDirectory();
      tempFile = File(
        '${dir.path}/lululu_score_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: 'image/png')],
          text: modeTitle.toLowerCase().contains('osmantuş')
              ? '$modeTitle · $score puan — Lülülü #lululu #osmantuş #ikili #viral'
              : '$modeTitle · $score puan — Lülülü #lululu #böcek #osmantuş #viral',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[ScoreShareCard] share failed: $e');
      return false;
    } finally {
      final file = tempFile;
      if (file != null) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<List<int>> _renderPng({
    required AppLocalizations l10n,
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
        text: _displayUpper(modeTitle, l10n.locale),
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
        text: best != null && best > 0
            ? '${l10n.gameBestLabel} $best'
            : l10n.gameScoreLabel,
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
    if (byteData == null) {
      throw StateError('Skor kartı PNG baytları üretilemedi');
    }
    return byteData.buffer.asUint8List();
  }
}

/// Dile duyarlı büyük-harf dönüşümü (stüdyo ekranlarındaki desenle aynı).
///
/// TR locale'de Türkçe eşleme (i→İ, ı→I, ...) aynen korunur; EN locale'de
/// düz [String.toUpperCase] kullanılır, aksi hâlde EN metindeki `i`
/// yanlışlıkla `İ` olur.
String _displayUpper(String input, Locale locale) {
  if (locale.languageCode == 'en') {
    return input.toUpperCase();
  }
  return input
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .replaceAll('ğ', 'Ğ')
      .replaceAll('ü', 'Ü')
      .replaceAll('ş', 'Ş')
      .replaceAll('ö', 'Ö')
      .replaceAll('ç', 'Ç')
      .toUpperCase();
}
