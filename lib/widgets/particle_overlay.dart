import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/adaptive_quality_scaler.dart';
import '../theme/lululu_theme.dart';

enum ParticleShape {
  chip,
  circle,
  star,
  ring,
  spark,
}

/// 120FPS Nesne Havuzlu (Object-Pooled) hazır parçacık patlama tipleri.
enum ParticleBurstPreset {
  mergeGold,
  bossHit,
  raidSprayMist,
  confettiVictory,
  electricShock,
}

/// Havuzlanabilir (object-pooled) tekil parçacık verisi.
class OverlayParticle {
  OverlayParticle({
    this.x = 0,
    this.y = 0,
    this.vx = 0,
    this.vy = 0,
    this.gravity = 460,
    this.drag = 0.97,
    this.size = 5.0,
    this.angle = 0,
    this.spin = 0,
    this.life = 0,
    this.maxLife = 1.0,
    this.color = LululuColors.liquidGold,
    this.shape = ParticleShape.chip,
    this.active = false,
  });

  double x;
  double y;
  double vx;
  double vy;
  double gravity;
  double drag;
  double size;
  double angle;
  double spin;
  double life;
  double maxLife;
  Color color;
  ParticleShape shape;
  bool active;

  double get normalizedLife =>
      maxLife <= 0 ? 0.0 : (life / maxLife).clamp(0.0, 1.0);

  bool step(double dt) {
    if (!active) return false;
    x += vx * dt;
    y += vy * dt;
    vx *= drag;
    vy = vy * drag + gravity * dt;
    angle += spin * dt;
    spin *= 0.98;
    life -= dt;
    if (life <= 0) {
      active = false;
      return false;
    }
    return true;
  }
}

/// `AdaptiveQualityScaler` ile tam uyumlu, 60Hz / 120Hz ProMotion ekranlarda
/// zero-jank çalışan sabit kapasiteli (`maxParticles = 96`) parçacık patlama kontrolcüsü.
class ParticleOverlayController extends ChangeNotifier {
  ParticleOverlayController({
    int? maxParticles,
    int poolCapacity = defaultMaxParticles,
  }) : _pool = List<OverlayParticle>.generate(
          math.max(8, maxParticles ?? poolCapacity),
          (_) => OverlayParticle(),
          growable: false,
        );

  /// GC (Garbage Collection) baskısını sıfırlayan varsayılan sabit havuz kapasitesi.
  static const int defaultMaxParticles = 96;

  final List<OverlayParticle> _pool;
  final math.Random _rng = math.Random();
  int _activeCount = 0;
  int _cursor = 0;

  /// Sabit parçacık havuzu kapasitesi.
  int get maxParticles => _pool.length;

  /// `AdaptiveQualityScaler` ile ölçeklenmiş etkin aktif parçacık üst sınırı.
  int get effectiveMaxParticles => _effectiveMaxParticles;

  int get activeCount => _activeCount;

  /// Aktif parçacıkların salt-okunur görünümü.
  Iterable<OverlayParticle> get activeParticles =>
      _pool.where((p) => p.active);

  int get _effectiveMaxParticles =>
      math.min(_pool.length, AdaptiveQualityScaler.instance.maxActiveParticles);

  double get _effectiveParticleScale =>
      AdaptiveQualityScaler.instance.particleScale;

  int _scaledCount(int baseCount) {
    final scale = _effectiveParticleScale.clamp(0.4, 1.25);
    return math.max(3, (baseCount * scale).round());
  }

  OverlayParticle _acquireSlot() {
    final cap = math.max(8, _effectiveMaxParticles);
    for (var i = 0; i < _pool.length; i++) {
      final idx = (_cursor + i) % _pool.length;
      final candidate = _pool[idx];
      if (!candidate.active) {
        _cursor = (idx + 1) % _pool.length;
        if (_activeCount < cap) {
          _activeCount++;
          return candidate;
        }
        break;
      }
    }
    // Kapasite doluysa en eski aktif parçacığın üzerine yaz (GC tahsisi yapma).
    for (var i = 0; i < _pool.length; i++) {
      final idx = (_cursor + i) % _pool.length;
      final candidate = _pool[idx];
      if (candidate.active) {
        _cursor = (idx + 1) % _pool.length;
        return candidate;
      }
    }
    final reused = _pool[_cursor];
    _cursor = (_cursor + 1) % _pool.length;
    if (!reused.active && _activeCount < cap) {
      _activeCount++;
    }
    return reused;
  }

  void _emit({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double size,
    required double life,
    required Color color,
    ParticleShape shape = ParticleShape.chip,
    double gravity = 460,
    double drag = 0.97,
    double angle = 0,
    double spin = 0,
  }) {
    final slot = _acquireSlot();
    slot
      ..x = x
      ..y = y
      ..vx = vx
      ..vy = vy
      ..gravity = gravity
      ..drag = drag
      ..size = size * _effectiveParticleScale
      ..angle = angle
      ..spin = spin
      ..life = life
      ..maxLife = life
      ..color = color
      ..shape = shape
      ..active = true;
  }

  /// `ParticleBurstPreset` tabanlı birleşik patlama tetikleyicisi.
  void spawnPreset(
    ParticleBurstPreset preset,
    Offset position, {
    int tier = 1,
    int combo = 1,
    Size arenaSize = const Size(360, 640),
    Color? color,
  }) {
    switch (preset) {
      case ParticleBurstPreset.mergeGold:
        spawnMergeGold(
          position,
          tier: tier,
          combo: combo,
          color: color,
        );
      case ParticleBurstPreset.bossHit:
        spawnBossHit(position, combo: combo);
      case ParticleBurstPreset.raidSprayMist:
        spawnRaidSprayMist(position);
      case ParticleBurstPreset.confettiVictory:
        spawnVictoryConfetti(arenaSize, origin: position);
      case ParticleBurstPreset.electricShock:
        spawnElectricShock(position, combo: combo);
    }
  }

  /// Altın birleşim patlaması (`ParticleBurstPreset.mergeGold`).
  void spawnMergeGold(
    Offset position, {
    int tier = 3,
    int combo = 1,
    Color? color,
  }) {
    spawnMergeBurst(
      position,
      tier: tier,
      combo: combo,
      color: color ?? LululuColors.liquidGold,
    );
  }

  /// Dev Boss / Anne Terliği / F16 ağır darbe patlaması (`ParticleBurstPreset.bossHit`).
  void spawnBossHit(Offset position, {int combo = 1}) {
    final count = _scaledCount(20 + combo.clamp(1, 10) * 2);
    const palette = <Color>[
      Color(0xFFFF1744),
      LululuColors.coralFlare,
      LululuColors.warningSolar,
      Colors.white,
    ];

    _emit(
      x: position.dx,
      y: position.dy,
      vx: 0,
      vy: 0,
      size: 36,
      life: 0.36,
      color: const Color(0xFFFF1744),
      shape: ParticleShape.ring,
      gravity: 0,
      drag: 1.0,
    );

    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + (_rng.nextDouble() - 0.5) * 0.3;
      final speed = 95 + _rng.nextDouble() * 215;
      _emit(
        x: position.dx,
        y: position.dy,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 40,
        size: 4.2 + _rng.nextDouble() * 4.8,
        life: 0.40 + _rng.nextDouble() * 0.32,
        color: palette[i % palette.length],
        shape: i % 3 == 0 ? ParticleShape.star : ParticleShape.spark,
        gravity: 340,
        angle: angle,
        spin: (_rng.nextDouble() - 0.5) * 14,
      );
    }
    notifyListeners();
  }

  /// Raid Böcek İlacı aerosol sis bulutu (`ParticleBurstPreset.raidSprayMist`).
  void spawnRaidSprayMist(Offset position) {
    final count = _scaledCount(18);
    const mistPalette = <Color>[
      Color(0xFF00E5FF),
      LululuColors.toxicNeon,
      Color(0xFFB2FF59),
      Colors.white,
    ];

    _emit(
      x: position.dx,
      y: position.dy,
      vx: 0,
      vy: 0,
      size: 26,
      life: 0.38,
      color: const Color(0xFF00E5FF),
      shape: ParticleShape.ring,
      gravity: 0,
      drag: 0.96,
    );

    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 35 + _rng.nextDouble() * 115;
      _emit(
        x: position.dx + (_rng.nextDouble() - 0.5) * 14,
        y: position.dy + (_rng.nextDouble() - 0.5) * 14,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 30,
        size: 4.5 + _rng.nextDouble() * 5.0,
        life: 0.46 + _rng.nextDouble() * 0.34,
        color: mistPalette[i % mistPalette.length],
        shape: ParticleShape.circle,
        gravity: -45, // Hafif yukarı süzülen aerosol buharı
        drag: 0.94,
      );
    }
    notifyListeners();
  }

  /// Elektrik şoku / yıldırım ark kıvılcımı (`ParticleBurstPreset.electricShock`).
  void spawnElectricShock(Offset position, {int combo = 1}) {
    final count = _scaledCount(16 + combo.clamp(1, 8) * 2);
    const shockPalette = <Color>[
      Color(0xFF00E5FF),
      Color(0xFFE040FB),
      LululuColors.warningSolar,
      Colors.white,
    ];

    _emit(
      x: position.dx,
      y: position.dy,
      vx: 0,
      vy: 0,
      size: 30,
      life: 0.28,
      color: const Color(0xFF00E5FF),
      shape: ParticleShape.ring,
      gravity: 0,
      drag: 1.0,
    );

    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + (_rng.nextDouble() - 0.5) * 0.5;
      final speed = 120 + _rng.nextDouble() * 230;
      _emit(
        x: position.dx,
        y: position.dy,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: 4.0 + _rng.nextDouble() * 4.5,
        life: 0.28 + _rng.nextDouble() * 0.26,
        color: shockPalette[i % shockPalette.length],
        shape: i % 4 == 0 ? ParticleShape.star : ParticleShape.spark,
        gravity: 90,
        drag: 0.92,
        angle: angle,
        spin: (_rng.nextDouble() - 0.5) * 18,
      );
    }
    notifyListeners();
  }

  /// Böcek birleşimi parçacık patlaması.
  void spawnMergeBurst(
    Offset position, {
    required int tier,
    int combo = 1,
    Color? color,
  }) {
    final baseColor = color ?? _colorForTier(tier, combo);
    final rawCount = 10 + combo.clamp(1, 8) * 4 + tier.clamp(1, 13) * 2;
    final count = _scaledCount(rawCount);

    // Merkez şok halkası
    _emit(
      x: position.dx,
      y: position.dy,
      vx: 0,
      vy: 0,
      size: 20 + tier * 2.5,
      life: 0.34,
      color: baseColor,
      shape: ParticleShape.ring,
      gravity: 0,
      drag: 1.0,
    );

    for (var i = 0; i < count; i++) {
      final theta = (i / count) * math.pi * 2 + (_rng.nextDouble() - 0.5) * 0.4;
      final speed = 75 + _rng.nextDouble() * (145 + combo * 18);
      final shape = (i % 4 == 0)
          ? ParticleShape.star
          : (i % 2 == 0 ? ParticleShape.chip : ParticleShape.circle);
      final c = i.isEven ? baseColor : LululuColors.liquidGold;
      _emit(
        x: position.dx,
        y: position.dy,
        vx: math.cos(theta) * speed,
        vy: math.sin(theta) * speed - 45,
        size: 3.8 + _rng.nextDouble() * 4.2,
        life: 0.42 + _rng.nextDouble() * 0.32,
        color: c,
        shape: shape,
        angle: _rng.nextDouble() * math.pi * 2,
        spin: (_rng.nextDouble() - 0.5) * 11,
      );
    }
    notifyListeners();
  }

  /// Kombo (`x2`, `x4`, `x8`) yıldız ve kıvılcım patlaması.
  void spawnComboExplosion(Offset position, {required int combo}) {
    final count = _scaledCount(14 + combo.clamp(2, 12) * 3);
    const palette = <Color>[
      LululuColors.warningSolar,
      LululuColors.cyberFuchsia,
      LululuColors.toxicNeon,
      LululuColors.liquidGold,
    ];

    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 95 + _rng.nextDouble() * 210;
      _emit(
        x: position.dx,
        y: position.dy,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 60,
        size: 4.5 + _rng.nextDouble() * 4.5,
        life: 0.48 + _rng.nextDouble() * 0.35,
        color: palette[i % palette.length],
        shape: i % 3 == 0 ? ParticleShape.star : ParticleShape.spark,
        angle: angle,
        spin: (_rng.nextDouble() - 0.5) * 14,
      );
    }
    notifyListeners();
  }

  /// Anne Terliği şaplağı (`ŞAK!`) toz ve darbe halkası.
  void spawnSlipperImpact(Offset position, {bool golden = false}) {
    final count = _scaledCount(golden ? 22 : 14);
    final ringColor =
        golden ? LululuColors.liquidGold : LululuColors.coralFlare;

    _emit(
      x: position.dx,
      y: position.dy,
      vx: 0,
      vy: 0,
      size: golden ? 32 : 24,
      life: 0.30,
      color: ringColor,
      shape: ParticleShape.ring,
      gravity: 0,
    );

    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = 60 + _rng.nextDouble() * 140;
      _emit(
        x: position.dx,
        y: position.dy,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 25,
        size: 3.5 + _rng.nextDouble() * 4.0,
        life: 0.36 + _rng.nextDouble() * 0.24,
        color: golden
            ? LululuColors.warningSolar
            : (i.isEven ? LululuColors.mutedTitanium : ringColor),
        shape: golden && i % 3 == 0 ? ParticleShape.star : ParticleShape.circle,
        gravity: 260,
      );
    }
    notifyListeners();
  }

  /// F16 Bombardımanı ("Aydınlat Hele!") ateş ve şok dalgası patlaması.
  void spawnF16Explosion(Offset position) {
    final count = _scaledCount(28);
    const firePalette = <Color>[
      LululuColors.warningSolar,
      LululuColors.coralFlare,
      LululuColors.mysticRuby,
      Colors.white,
    ];

    _emit(
      x: position.dx,
      y: position.dy,
      vx: 0,
      vy: 0,
      size: 42,
      life: 0.42,
      color: LululuColors.liquidGold,
      shape: ParticleShape.ring,
      gravity: 0,
    );

    for (var i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2 + (_rng.nextDouble() - 0.5) * 0.25;
      final speed = 110 + _rng.nextDouble() * 240;
      _emit(
        x: position.dx,
        y: position.dy,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 50,
        size: 4.5 + _rng.nextDouble() * 5.5,
        life: 0.45 + _rng.nextDouble() * 0.38,
        color: firePalette[i % firePalette.length],
        shape: i % 3 == 0 ? ParticleShape.spark : ParticleShape.chip,
        gravity: 380,
        angle: angle,
        spin: (_rng.nextDouble() - 0.5) * 15,
      );
    }
    notifyListeners();
  }

  /// Seviye tamamlama konfeti yağmuru (`ParticleBurstPreset.confettiVictory`).
  void spawnVictoryConfetti(Size arenaSize, {Offset? origin}) {
    final count = _scaledCount(36);
    const colors = <Color>[
      LululuColors.liquidGold,
      LululuColors.cyberFuchsia,
      LululuColors.toxicNeon,
      LululuColors.coralFlare,
      Color(0xFF38BDF8),
    ];

    for (var i = 0; i < count; i++) {
      final x = origin != null
          ? origin.dx + (_rng.nextDouble() - 0.5) * 80.0
          : _rng.nextDouble() * math.max(120.0, arenaSize.width);
      final y = origin != null
          ? origin.dy + (_rng.nextDouble() - 0.5) * 20.0
          : _rng.nextDouble() * 40.0;
      _emit(
        x: x,
        y: y,
        vx: (_rng.nextDouble() - 0.5) * 140,
        vy: origin != null
            ? -80 + _rng.nextDouble() * 160
            : 60 + _rng.nextDouble() * 140,
        size: 5.0 + _rng.nextDouble() * 4.0,
        life: 0.85 + _rng.nextDouble() * 0.55,
        color: colors[i % colors.length],
        shape: i % 4 == 0 ? ParticleShape.star : ParticleShape.chip,
        gravity: 240,
        drag: 0.99,
        angle: _rng.nextDouble() * math.pi * 2,
        spin: (_rng.nextDouble() - 0.5) * 10,
      );
    }
    notifyListeners();
  }

  /// Parçacık fiziğini `dt` saniye ilerletir (60Hz / 120Hz uyumlu).
  void update(double dt) {
    if (_activeCount <= 0) return;
    final clampedDt = dt.clamp(0.0, 0.033);
    if (clampedDt <= 0) return;

    var alive = 0;
    for (var i = 0; i < _pool.length; i++) {
      final p = _pool[i];
      if (!p.active) continue;
      if (p.step(clampedDt)) {
        alive++;
      }
    }
    _activeCount = alive;
    notifyListeners();
  }

  void clear() {
    if (_activeCount == 0) return;
    for (final p in _pool) {
      p.active = false;
    }
    _activeCount = 0;
    notifyListeners();
  }

  static Color _colorForTier(int tier, int combo) {
    if (tier >= 7 || combo >= 5) return LululuColors.cyberFuchsia;
    if (tier >= 5 || combo >= 3) return LululuColors.coralFlare;
    if (tier >= 3 || combo >= 2) return LululuColors.liquidGold;
    return LululuColors.toxicNeon;
  }
}

/// Parçacık efektlerini `RepaintBoundary` ve `CustomPainter` ile zero-jank çizen katman.
class ParticleOverlay extends StatefulWidget {
  const ParticleOverlay({
    super.key,
    required this.controller,
    this.maxParticles = ParticleOverlayController.defaultMaxParticles,
    this.autoTick = true,
    this.child,
  });

  final ParticleOverlayController controller;
  final int maxParticles;

  /// `true` ise aktif parçacık varken dahili `Ticker` ile kendini günceller.
  /// Oyun ekranı zaten kendi `Ticker` döngüsünde `controller.update(dt)`
  /// çağırıyorsa `false` verilebilir.
  final bool autoTick;
  final Widget? child;

  @override
  State<ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<ParticleOverlay>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    if (widget.autoTick) {
      _ticker = createTicker(_onTick);
      _syncTickerState();
    }
  }

  @override
  void didUpdateWidget(covariant ParticleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (widget.autoTick && _ticker == null) {
      _ticker = createTicker(_onTick);
    } else if (!widget.autoTick && _ticker != null && _ticker!.isActive) {
      _ticker!.stop();
    }
    _syncTickerState();
  }

  void _onControllerChanged() {
    _syncTickerState();
  }

  void _syncTickerState() {
    final ticker = _ticker;
    if (ticker == null || !widget.autoTick) return;
    if (widget.controller.activeCount > 0 && !ticker.isActive) {
      _lastElapsed = Duration.zero;
      ticker.start();
    } else if (widget.controller.activeCount == 0 && ticker.isActive) {
      ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;
    widget.controller.update(dt);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painterLayer = IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ParticleOverlayPainter(controller: widget.controller),
          size: Size.infinite,
        ),
      ),
    );

    if (widget.child == null) {
      return painterLayer;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child!,
        Positioned.fill(child: painterLayer),
      ],
    );
  }
}

class _ParticleOverlayPainter extends CustomPainter {
  _ParticleOverlayPainter({required this.controller})
      : super(repaint: controller);

  final ParticleOverlayController controller;

  @override
  void paint(Canvas canvas, Size size) {
    if (controller.activeCount <= 0) return;
    final enableGlow = AdaptiveQualityScaler.instance.shadowsEnabled &&
        AdaptiveQualityScaler.instance.shadowQuality >= 2;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()..style = PaintingStyle.stroke;

    for (final p in controller._pool) {
      if (!p.active) continue;
      final a = p.normalizedLife;
      if (a <= 0.01) continue;

      switch (p.shape) {
        case ParticleShape.ring:
          final progress = 1.0 - a;
          final radius = p.size * (0.45 + progress * 1.65);
          strokePaint
            ..color = p.color.withValues(alpha: a * 0.78)
            ..strokeWidth = (4.5 * a).clamp(1.0, 5.0);
          canvas.drawCircle(Offset(p.x, p.y), radius, strokePaint);

        case ParticleShape.circle:
          fillPaint.color = p.color.withValues(alpha: a);
          canvas.drawCircle(
            Offset(p.x, p.y),
            p.size * (0.5 + a * 0.5),
            fillPaint,
          );
          if (enableGlow) {
            fillPaint.color = Colors.white.withValues(alpha: a * 0.45);
            canvas.drawCircle(Offset(p.x, p.y), p.size * 0.28 * a, fillPaint);
          }

        case ParticleShape.chip:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.angle);
          fillPaint.color = p.color.withValues(alpha: a);
          final w = p.size * (1.2 + a * 0.5);
          final h = p.size * 0.58;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 2),
              const Radius.circular(1.5),
            ),
            fillPaint,
          );
          canvas.restore();

        case ParticleShape.spark:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.angle);
          strokePaint
            ..color = p.color.withValues(alpha: a)
            ..strokeWidth = (2.4 * a).clamp(1.0, 3.0)
            ..strokeCap = StrokeCap.round;
          final len = p.size * (1.5 + (1.0 - a));
          canvas.drawLine(Offset(-len, 0), Offset(len, 0), strokePaint);
          canvas.restore();

        case ParticleShape.star:
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.angle);
          fillPaint.color = p.color.withValues(alpha: a);
          _drawFourPointStar(canvas, p.size * (0.65 + a * 0.45), fillPaint);
          canvas.restore();
      }
    }
  }

  void _drawFourPointStar(Canvas canvas, double r, Paint paint) {
    final inner = r * 0.38;
    final path = Path()
      ..moveTo(0, -r)
      ..lineTo(inner, -inner)
      ..lineTo(r, 0)
      ..lineTo(inner, inner)
      ..lineTo(0, r)
      ..lineTo(-inner, inner)
      ..lineTo(-r, 0)
      ..lineTo(-inner, -inner)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ParticleOverlayPainter oldDelegate) =>
      oldDelegate.controller != controller;
}
