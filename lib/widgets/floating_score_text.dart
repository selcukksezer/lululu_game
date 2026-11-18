import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/lululu_theme.dart';

/// Yüzen skor / kombo etiketi verisi (`+250 KOMBO x4!`, `ŞAK!`, `KAPI X7!`).
class FloatingScoreItem {
  FloatingScoreItem({
    required this.id,
    required this.position,
    required this.points,
    this.combo = 1,
    this.isCritical = false,
    this.comboMultiplier,
    this.customText,
    this.subtitle,
    Color? color,
    int? createdAtMs,
    this.durationMs = 920,
    this.scale = 1.0,
  })  : color = color ?? _defaultColorForCombo(combo, isCritical: isCritical),
        createdAtMs = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;

  final int id;
  final Offset position;
  final int points;
  final int combo;
  final bool isCritical;
  final double? comboMultiplier;
  final String? customText;
  final String? subtitle;
  final Color color;
  final int createdAtMs;
  final int durationMs;
  final double scale;

  /// Ana başlık metni: örn. `+250 KOMBO x4!` veya `+120`.
  String get displayLabel {
    if (customText != null && customText!.trim().isNotEmpty) {
      return customText!.trim();
    }
    final sign = points >= 0 ? '+' : '';
    final critPrefix = isCritical ? 'KRİTİK! ' : '';
    if (combo >= 2) {
      return '$critPrefix$sign$points KOMBO x$combo!';
    }
    return '$critPrefix$sign$points';
  }

  static Color _defaultColorForCombo(int combo, {bool isCritical = false}) {
    if (isCritical) return const Color(0xFFFF1744);
    if (combo >= 5) return LululuColors.cyberFuchsia;
    if (combo >= 3) return LululuColors.coralFlare;
    if (combo >= 2) return LululuColors.liquidGold;
    return LululuColors.warningSolar;
  }
}

/// Yüzen skor yazılarını zero-jank olarak yöneten kontrolcü.
class FloatingScoreController extends ChangeNotifier {
  FloatingScoreController({this.maxItems = 24});

  final int maxItems;
  final List<FloatingScoreItem> _items = <FloatingScoreItem>[];
  int _nextId = 1;

  List<FloatingScoreItem> get items =>
      List<FloatingScoreItem>.unmodifiable(_items);

  /// Yeni bir yüzen skor (`+250 KOMBO x4!`) ekler.
  FloatingScoreItem spawn({
    required Offset position,
    required int points,
    int combo = 1,
    bool isCritical = false,
    double? comboMultiplier,
    String? customText,
    String? subtitle,
    Color? color,
    int durationMs = 920,
    double? scale,
  }) {
    final criticalBoost = isCritical ? 0.18 : 0.0;
    final resolvedScale = scale ??
        (1.0 +
            criticalBoost +
            math.min(0.45, (combo - 1).clamp(0, 8) * 0.08));
    final item = FloatingScoreItem(
      id: _nextId++,
      position: position,
      points: points,
      combo: combo,
      isCritical: isCritical,
      comboMultiplier: comboMultiplier,
      customText: customText,
      subtitle: subtitle,
      color: color,
      durationMs: durationMs,
      scale: resolvedScale,
    );

    if (_items.length >= maxItems) {
      _items.removeAt(0);
    }
    _items.add(item);
    notifyListeners();
    return item;
  }

  /// Süresi dolan yüzen skorları temizler.
  void pruneExpired([int? nowMs]) {
    if (_items.isEmpty) return;
    final current = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final before = _items.length;
    _items.removeWhere((item) => current - item.createdAtMs >= item.durationMs);
    if (_items.length != before) {
      notifyListeners();
    }
  }

  void removeById(int id) {
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length != before) {
      notifyListeners();
    }
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}

/// Tek bir yüzen skor/kombo yazısını (`+250 KOMBO x4!`) 60/120 FPS akıcılıkta
/// yukarı süzülerek (`Curves.easeOutCubic`) ve elastik büyüyerek (`Curves.elasticOut`)
/// çizen widget.
class FloatingScoreText extends StatefulWidget {
  const FloatingScoreText({
    super.key,
    required this.text,
    this.subtitle,
    this.combo = 1,
    this.isCritical = false,
    this.comboMultiplier,
    this.color = LululuColors.liquidGold,
    this.duration = const Duration(milliseconds: 900),
    this.riseDistance = 54.0,
    this.baseFontSize = 24.0,
    this.scaleCurve = Curves.elasticOut,
    this.fadeAndRiseCurve = Curves.easeOutCubic,
    this.animate = true,
    this.onCompleted,
  });

  factory FloatingScoreText.fromScore({
    Key? key,
    required int points,
    int combo = 1,
    bool isCritical = false,
    double? comboMultiplier,
    String? subtitle,
    Color? color,
    Duration duration = const Duration(milliseconds: 900),
    bool animate = true,
    VoidCallback? onCompleted,
  }) {
    final sign = points >= 0 ? '+' : '';
    final critPrefix = isCritical ? 'KRİTİK! ' : '';
    final label = combo >= 2
        ? '$critPrefix$sign$points KOMBO x$combo!'
        : '$critPrefix$sign$points';
    return FloatingScoreText(
      key: key,
      text: label,
      subtitle: subtitle,
      combo: combo,
      isCritical: isCritical,
      comboMultiplier: comboMultiplier,
      color: color ??
          FloatingScoreItem._defaultColorForCombo(
            combo,
            isCritical: isCritical,
          ),
      duration: duration,
      animate: animate,
      onCompleted: onCompleted,
    );
  }

  final String text;
  final String? subtitle;
  final int combo;
  final bool isCritical;
  final double? comboMultiplier;
  final Color color;
  final Duration duration;
  final double riseDistance;
  final double baseFontSize;
  final Curve scaleCurve;
  final Curve fadeAndRiseCurve;
  final bool animate;
  final VoidCallback? onCompleted;

  @override
  State<FloatingScoreText> createState() => _FloatingScoreTextState();
}

class _FloatingScoreTextState extends State<FloatingScoreText>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: widget.duration,
      )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onCompleted?.call();
          }
        });
      _controller!.forward();
    }
  }

  @override
  void didUpdateWidget(covariant FloatingScoreText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration && _controller != null) {
      _controller!.duration = widget.duration;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comboBoost = math.min(8.0, (widget.combo - 1).clamp(0, 6) * 2.0);
    final criticalBoost = widget.isCritical ? 4.0 : 0.0;
    final fontSize = widget.baseFontSize + comboBoost + criticalBoost;

    final content = _FloatingScoreBadge(
      text: widget.text,
      subtitle: widget.subtitle,
      color: widget.color,
      fontSize: fontSize,
      isHighCombo: widget.combo >= 2 || widget.isCritical,
      isCritical: widget.isCritical,
      comboMultiplier: widget.comboMultiplier,
    );

    if (!widget.animate || _controller == null) {
      return IgnorePointer(child: content);
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller!,
          builder: (context, child) {
            final t = _controller!.value;
            final double targetPeak = widget.isCritical ? 1.24 : 1.12;
            final double scale;
            if (t < 0.42) {
              final p = (t / 0.42).clamp(0.0, 1.0);
              final elasticValue = widget.scaleCurve.transform(p);
              scale = (0.52 + elasticValue * (targetPeak - 0.52)).clamp(
                0.35,
                1.48,
              );
            } else if (t < 0.68) {
              final p = ((t - 0.42) / 0.26).clamp(0.0, 1.0);
              scale = targetPeak - p * (targetPeak - 1.0);
            } else {
              scale = 1.0;
            }

            final riseProgress = widget.fadeAndRiseCurve.transform(t);
            final dy = -riseProgress * widget.riseDistance;
            final opacity = t < 0.65
                ? 1.0
                : (1.0 -
                        widget.fadeAndRiseCurve.transform(
                          ((t - 0.65) / 0.35).clamp(0.0, 1.0),
                        ))
                    .clamp(0.0, 1.0);

            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            );
          },
          child: content,
        ),
      ),
    );
  }
}

class _FloatingScoreBadge extends StatelessWidget {
  const _FloatingScoreBadge({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.isHighCombo,
    this.isCritical = false,
    this.comboMultiplier,
    this.subtitle,
  });

  final String text;
  final String? subtitle;
  final Color color;
  final double fontSize;
  final bool isHighCombo;
  final bool isCritical;
  final double? comboMultiplier;

  String? get _formattedMultiplierBadge {
    final mult = comboMultiplier;
    if (mult == null || mult <= 1.0) return null;
    final clean = mult == mult.roundToDouble()
        ? mult.toStringAsFixed(1)
        : mult.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
    return 'x$clean ÇARPAN';
  }

  @override
  Widget build(BuildContext context) {
    final strokeStyle = GoogleFonts.bangers(
      fontSize: fontSize,
      height: 1.05,
      letterSpacing: 0.8,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCritical ? 4.8 : (isHighCombo ? 4.2 : 3.2)
        ..strokeJoin = StrokeJoin.round
        ..color = LululuColors.carbonVoid,
    );

    final fillStyle = GoogleFonts.bangers(
      fontSize: fontSize,
      height: 1.05,
      letterSpacing: 0.8,
      color: color,
      shadows: <Shadow>[
        const Shadow(
          color: Color(0xE6080B12),
          offset: Offset(0, 2.5),
          blurRadius: 0,
        ),
        if (isHighCombo)
          Shadow(
            color: color.withValues(alpha: 0.65),
            offset: Offset.zero,
            blurRadius: isCritical ? 14 : 10,
          ),
      ],
    );

    final multiplierBadge = _formattedMultiplierBadge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isCritical || multiplierBadge != null) ...<Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF1744),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: LululuColors.warningSolar,
                      width: 1.2,
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      'KRİTİK VURUŞ!',
                      style: GoogleFonts.baloo2(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (isCritical && multiplierBadge != null)
                const SizedBox(width: 4),
              if (multiplierBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: LululuColors.carbonVoid.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: LululuColors.liquidGold,
                      width: 1.2,
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      multiplierBadge,
                      style: GoogleFonts.baloo2(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: LululuColors.liquidGold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
        ],
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ExcludeSemantics(
              child: Text(text, textAlign: TextAlign.center, style: strokeStyle),
            ),
            ExcludeSemantics(
              child: Text(text, textAlign: TextAlign.center, style: fillStyle),
            ),
          ],
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: LululuColors.carbonVoid.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: color.withValues(alpha: 0.75),
                width: 1.2,
              ),
            ),
            child: ExcludeSemantics(
              child: Text(
                subtitle!,
                style: GoogleFonts.baloo2(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bir `FloatingScoreController` içindeki tüm aktif yüzen skorları sahne üzerinde gösterir.
class FloatingScoreOverlay extends StatelessWidget {
  const FloatingScoreOverlay({
    super.key,
    required this.controller,
  });

  final FloatingScoreController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final items = controller.items;
            if (items.isEmpty) return const SizedBox.expand();
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (final item in items)
                  Positioned(
                    key: ValueKey<int>(item.id),
                    left: item.position.dx - 100,
                    top: item.position.dy - 28,
                    width: 200,
                    child: Center(
                      child: FloatingScoreText(
                        text: item.displayLabel,
                        subtitle: item.subtitle,
                        combo: item.combo,
                        isCritical: item.isCritical,
                        comboMultiplier: item.comboMultiplier,
                        color: item.color,
                        duration: Duration(milliseconds: item.durationMs),
                        onCompleted: () => controller.removeById(item.id),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
