import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/lululu_theme.dart';
import '../models/insect_tier.dart';

class MergeEvent {
  final InsectTier tier;
  final double x;
  final double y;

  const MergeEvent({
    required this.tier,
    required this.x,
    required this.y,
  });
}

class InsectParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double size;
  double angle;
  double spin;
  final Color color;

  InsectParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
    this.size = 3.5,
    this.angle = 0,
    this.spin = 0,
  });

  bool update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vx *= 0.965;
    vy = vy * 0.985 + 480 * dt;
    angle += spin * dt;
    spin *= 0.97;
    life -= dt * 1.55;
    return life > 0;
  }
}

class InsectBody {
  final int id;
  InsectTier tier;
  double x;
  double y;
  double prevX;
  double prevY;
  double angle;
  double angularVelocity;
  bool isStatic;
  bool isMarkedForRemoval;
  double spawnScale;

  InsectBody({
    required this.id,
    required this.tier,
    required this.x,
    required this.y,
    double? prevX,
    double? prevY,
    this.angle = 0.0,
    this.angularVelocity = 0.0,
    this.isStatic = false,
    this.isMarkedForRemoval = false,
    this.spawnScale = 0.2,
  })  : prevX = prevX ?? x,
        prevY = prevY ?? y;

  double get radius => tier.radius;
  double get mass => tier.mass;

  InsectBody copy() => InsectBody(
        id: id,
        tier: tier,
        x: x,
        y: y,
        prevX: prevX,
        prevY: prevY,
        angle: angle,
        angularVelocity: angularVelocity,
        isStatic: isStatic,
        isMarkedForRemoval: isMarkedForRemoval,
        spawnScale: spawnScale,
      );

  void respawn({
    required InsectTier nextTier,
    required double nx,
    required double ny,
  }) {
    tier = nextTier;
    x = nx;
    y = ny;
    prevX = nx;
    prevY = ny - 4.5;
    angle = 0;
    angularVelocity = 0;
    isStatic = false;
    isMarkedForRemoval = false;
    spawnScale = 0.2;
  }

  void applyImpulse(double ix, double iy) {
    prevX -= ix / mass;
    prevY -= iy / mass;
  }

  double get speed {
    final vx = x - prevX;
    final vy = y - prevY;
    return sqrt(vx * vx + vy * vy);
  }
}

class ArenaBlock {
  const ArenaBlock(this.x, this.y, this.radius);

  final double x;
  final double y;
  final double radius;
}

class CircularPhysicsEngine {
  Offset arenaCenter;
  double arenaRadius;
  final double gravity;

  /// Flat floor and straight walls. Round bowl when false.
  bool squareArena;
  final List<InsectBody> bodies = [];
  final List<InsectParticle> particles = [];
  final List<ArenaBlock> blocks = [];
  final List<InsectBody> _pool = [];
  int _nextId = 1;

  static const double maxAngularVelocity = 3.5;
  static const double _angularDamping = 0.62;
  /// Below this Verlet step length, body sleeps (stops micro-jitter).
  static const double _sleepSpeed = 0.55;

  CircularPhysicsEngine({
    required this.arenaCenter,
    required this.arenaRadius,
    this.gravity = 980.0,
    this.squareArena = false,
  });

  /// Keep bodies when play-area size changes (HUD / SafeArea reflow).
  void remountLayout(Offset newCenter, double newRadius) {
    if ((newCenter - arenaCenter).distance < 0.5 &&
        (newRadius - arenaRadius).abs() < 0.5) {
      return;
    }
    final oldC = arenaCenter;
    final oldR = arenaRadius;
    final scale = oldR > 1 ? newRadius / oldR : 1.0;
    for (final b in bodies) {
      b.x = newCenter.dx + (b.x - oldC.dx) * scale;
      b.y = newCenter.dy + (b.y - oldC.dy) * scale;
      b.prevX = newCenter.dx + (b.prevX - oldC.dx) * scale;
      b.prevY = newCenter.dy + (b.prevY - oldC.dy) * scale;
    }
    final blockCount = blocks.length;
    arenaCenter = newCenter;
    arenaRadius = newRadius;
    if (blockCount > 0) layoutBlocks(blockCount);
  }

  void clear() {
    for (final b in bodies) {
      b.isMarkedForRemoval = false;
      _pool.add(b);
    }
    bodies.clear();
    particles.clear();
  }

  void layoutBlocks(int count) {
    blocks.clear();
    if (count <= 0) return;
    for (var i = 0; i < count; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      blocks.add(
        ArenaBlock(
          arenaCenter.dx + side * arenaRadius * (0.28 + (i % 2) * 0.12),
          arenaCenter.dy + arenaRadius * (0.05 + i * 0.18),
          18,
        ),
      );
    }
  }

  /// True when pile is calm enough for the next drop.
  /// Ignores freshly spawning pops; looser speed so micro-jiggle never soft-locks.
  bool get isSettled {
    if (bodies.isEmpty) return true;
    for (final b in bodies) {
      if (b.isMarkedForRemoval) continue;
      if (b.spawnScale < 0.72) continue; // still popping in — don't block
      if (b.speed > 5.5) return false;
    }
    return true;
  }

  double get dangerY => arenaCenter.dy - arenaRadius * 0.72;

  bool get isOverflowing {
    for (final b in bodies) {
      if (!b.isMarkedForRemoval && b.spawnScale >= 0.8) {
        if (b.y - b.radius < dangerY && (b.y - b.prevY).abs() < 0.5) {
          return true;
        }
      }
    }
    return false;
  }

  /// Rest Y if a circle of [radius] were dropped at [x] onto the pile / jar floor.
  double predictRestY(double x, double radius) {
    final dx = (x - arenaCenter.dx).abs().clamp(0.0, arenaRadius - 1);
    final maxDy = sqrt(max(0.0, arenaRadius * arenaRadius - dx * dx));
    var land = arenaCenter.dy + maxDy - radius;
    if (squareArena) {
      land = arenaCenter.dy + arenaRadius - radius - 4;
    }
    for (final b in bodies) {
      if (b.isMarkedForRemoval || b.spawnScale < 0.55) continue;
      if ((b.x - x).abs() > b.radius + radius) continue;
      final sit = b.y - b.radius - radius;
      if (sit < land) land = sit;
    }
    return land;
  }

  /// 0 = safe, 1 = touching danger. For HUD / pulse warning.
  /// Only resting pile bodies — mid-fall drops must NOT flash "yaklaştın".
  double get dangerProximity {
    var worst = 0.0;
    final band = arenaRadius * 0.22;
    for (final b in bodies) {
      if (b.isMarkedForRemoval || b.spawnScale < 0.9) continue;
      // Falling / bouncing: ignore (prevY delta + speed).
      if (b.speed > 4.0) continue;
      if ((b.y - b.prevY).abs() > 1.0) continue;
      final top = b.y - b.radius;
      final gap = top - dangerY;
      if (gap >= band) continue;
      final t = (1.0 - (gap / band)).clamp(0.0, 1.0);
      if (t > worst) worst = t;
    }
    return worst;
  }

  void addBody(InsectTier tier, double x, double y) {
    final InsectBody body;
    if (_pool.isNotEmpty) {
      body = _pool.removeLast();
      body.respawn(nextTier: tier, nx: x, ny: y);
    } else {
      body = InsectBody(
        id: _nextId++,
        tier: tier,
        x: x,
        y: y,
        spawnScale: 0.2,
      );
      body.prevY = y - 4.5;
    }
    bodies.add(body);
  }

  void spawnParticles(double x, double y, Color color, {int count = 15}) {
    final rand = Random();
    // Cap debris so low-RAM phones stay under Eco particle budget.
    final n = min(count, 36);
    for (int i = 0; i < n; i++) {
      final ring = i / n;
      final angle = ring * 2 * pi + (rand.nextDouble() - 0.5) * 0.55;
      final speed = 55.0 + rand.nextDouble() * 160.0 + (i % 4) * 28.0;
      final upBias = -35.0 - rand.nextDouble() * 55.0;
      particles.add(
        InsectParticle(
          x: x + cos(angle) * rand.nextDouble() * 4,
          y: y + sin(angle) * rand.nextDouble() * 4,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed * 0.72 + upBias,
          life: 0.55 + rand.nextDouble() * 0.55,
          color: i.isEven
              ? color
              : Color.lerp(color, Colors.white, 0.35)!,
          size: 1.8 + rand.nextDouble() * 4.2,
          angle: rand.nextDouble() * pi,
          spin: (rand.nextDouble() - 0.5) * 16,
        ),
      );
    }
  }

  /// Step the physics simulation using Verlet Integration
  /// Returns merge events (tier + arena position) for audio/juice triggers.
  List<MergeEvent> update(double dt) {
    if (dt > 0.033) dt = 0.033; // clamp dt to avoid explosions

    // 1. Verlet position update
    for (final b in bodies) {
      if (b.isStatic) continue;

      // Mild pop-in — avoid large overshoot (radius flicker = collision jitter).
      if (b.spawnScale < 1.0) {
        b.spawnScale = min(1.06, b.spawnScale + dt * 5.0);
      } else if (b.spawnScale > 1.0) {
        b.spawnScale = max(1.0, b.spawnScale - dt * 4.5);
      }

      var vx = (b.x - b.prevX) * 0.972;
      var vy = (b.y - b.prevY) * 0.972 + (gravity * dt * dt);

      // Mild rest damping — keep enough energy to roll off neighbors.
      final spd = sqrt(vx * vx + vy * vy);
      if (spd < 1.4) {
        vx *= 0.9;
        vy *= 0.94;
      }

      b.prevX = b.x;
      b.prevY = b.y;

      b.x += vx;
      b.y += vy;

      b.angle += b.angularVelocity * dt;
      b.angularVelocity *= _angularDamping;
      if (b.angularVelocity.abs() < 0.18) {
        b.angularVelocity = 0;
      } else {
        b.angularVelocity =
            b.angularVelocity.clamp(-maxAngularVelocity, maxAngularVelocity);
      }
    }

    // 5 iterations: solid packing without the old freeze-stack vibration.
    final mergeEvents = <MergeEvent>[];
    const iterations = 5;
    for (int it = 0; it < iterations; it++) {
      _resolveArenaBounds();
      _resolveBlocks();
      mergeEvents.addAll(_resolveBodyCollisions());
    }

    // Sleep only when truly calm and not perched on another circle.
    for (final b in bodies) {
      if (b.isStatic || b.isMarkedForRemoval) continue;
      if (b.spawnScale < 0.95) continue;
      if (b.speed >= _sleepSpeed) continue;
      if (_isPerched(b)) continue;
      b.prevX = b.x;
      b.prevY = b.y;
      b.angularVelocity = 0;
    }

    for (var i = bodies.length - 1; i >= 0; i--) {
      final b = bodies[i];
      if (!b.isMarkedForRemoval) continue;
      b.isMarkedForRemoval = false;
      _pool.add(b);
      bodies.removeAt(i);
    }

    // 4. Update particles
    particles.removeWhere((p) => !p.update(dt));

    return mergeEvents;
  }

  void _resolveBlocks() {
    for (final b in bodies) {
      if (b.isMarkedForRemoval) continue;
      final br = b.radius * b.spawnScale;
      for (final block in blocks) {
        final dx = b.x - block.x;
        final dy = b.y - block.y;
        final distSq = dx * dx + dy * dy;
        final minDist = br + block.radius;
        if (distSq >= minDist * minDist || distSq < 0.0001) continue;
        final dist = sqrt(distSq);
        final nx = dx / dist;
        final ny = dy / dist;
        b.x = block.x + nx * minDist;
        b.y = block.y + ny * minDist;
        final vx = b.x - b.prevX;
        final vy = b.y - b.prevY;
        final vn = vx * nx + vy * ny;
        if (vn < 0) {
          b.prevX = b.x - (vx - vn * nx) * 0.35;
          b.prevY = b.y - (vy - vn * ny) * 0.2;
        }
      }
    }
  }

  void _resolveArenaBounds() {
    if (squareArena) {
      _resolveSquareBounds();
      return;
    }
    for (final b in bodies) {
      final dx = b.x - arenaCenter.dx;
      final dy = b.y - arenaCenter.dy;
      final dist = sqrt(dx * dx + dy * dy);
      final maxDist = arenaRadius - (b.radius * b.spawnScale);

      if (dist > maxDist && dist > 0.0001) {
        final nx = dx / dist;
        final ny = dy / dist;

        b.x = arenaCenter.dx + nx * maxDist;
        b.y = arenaCenter.dy + ny * maxDist;

        // Kill most bounce energy so bowl walls don't ping-pong the pile.
        final vx = b.x - b.prevX;
        final vy = b.y - b.prevY;
        b.prevX = b.x - vx * 0.28;
        b.prevY = b.y - vy * 0.22;
      }
    }
  }

  void _resolveSquareBounds() {
    final left = arenaCenter.dx - arenaRadius;
    final right = arenaCenter.dx + arenaRadius;
    final top = arenaCenter.dy - arenaRadius;
    final floorY = arenaCenter.dy + arenaRadius;
    for (final b in bodies) {
      final r = b.radius * b.spawnScale;
      final inBin = b.y + r > top;
      if (inBin && b.x < left + r) {
        b.x = left + r;
        if (b.prevX < b.x) b.prevX = b.x;
      } else if (inBin && b.x > right - r) {
        b.x = right - r;
        if (b.prevX > b.x) b.prevX = b.x;
      }
      if (b.y > floorY - r) {
        final vx = b.x - b.prevX;
        b.y = floorY - r;
        b.prevY = b.y;
        b.prevX = b.x - vx * 0.9;
      }
    }
  }

  List<MergeEvent> _resolveBodyCollisions() {
    final merges = <MergeEvent>[];
    final count = bodies.length;

    for (int i = 0; i < count; i++) {
      final b1 = bodies[i];
      if (b1.isMarkedForRemoval) continue;

      for (int j = i + 1; j < count; j++) {
        final b2 = bodies[j];
        if (b2.isMarkedForRemoval) continue;

        final dx = b2.x - b1.x;
        final dy = b2.y - b1.y;
        final distSq = dx * dx + dy * dy;
        final r1 = b1.radius * b1.spawnScale;
        final r2 = b2.radius * b2.spawnScale;
        final targetDist = r1 + r2;

        final touch = targetDist + 1.5;
        if (distSq < touch * touch && distSq > 0.0001) {
          final dist = sqrt(distSq);

          if (b1.tier == b2.tier && b1.tier.nextTier != null) {
            final next = b1.tier.nextTier!;
            final midX = (b1.x + b2.x) / 2;
            final midY = (b1.y + b2.y) / 2;

            b1.tier = next;
            b1.x = midX;
            b1.y = midY;
            // Settle in place — no upward launch.
            b1.prevX = midX;
            b1.prevY = midY;
            b1.spawnScale = 0.55;
            b1.angularVelocity = 0;
            final cx = arenaCenter.dx - midX;
            final cy = arenaCenter.dy - midY;
            b1.applyImpulse(cx * 0.012, cy * 0.016);

            b2.isMarkedForRemoval = true;
            spawnParticles(midX, midY, next.color, count: 8 + next.tier);
            _nudgeNeighborsFromMerge(midX, midY, next.radius * 1.6);
            merges.add(MergeEvent(tier: next, x: midX, y: midY));
            continue;
          }

          final overlap = targetDist - dist;
          final nx = dx / dist;
          final ny = dy / dist;

          if (overlap > 0) {
            final totalMass = b1.mass + b2.mass;
            final m1Ratio = b2.mass / totalMass;
            final m2Ratio = b1.mass / totalMass;

            // Positional separation only — do not inject Verlet velocity.
            b1.x -= nx * overlap * m1Ratio;
            b1.y -= ny * overlap * m1Ratio;
            b2.x += nx * overlap * m2Ratio;
            b2.y += ny * overlap * m2Ratio;
          }

          // Unstable perch: roll toward freer side so pile fills gaps.
          final upper = b1.y <= b2.y ? b1 : b2;
          final lower = identical(upper, b1) ? b2 : b1;
          final stacked = ny.abs() > 0.5 &&
              upper.y < lower.y &&
              (lower.y - upper.y) < targetDist * 1.05;
          if (stacked) {
            final dxOff = upper.x - lower.x;
            final balance = lower.radius * 0.38;
            if (dxOff.abs() < balance) {
              final dir = dxOff.abs() < 0.6
                  ? _freerSide(upper)
                  : dxOff.sign;
              upper.prevX = upper.x - dir * 2.6;
            } else {
              // Keep rolling off the shoulder; light friction only.
              final ux = upper.x - upper.prevX;
              upper.prevX = upper.x - ux * 0.96;
            }
          }

          // Kill bounce (normal), keep tangential settle.
          if (b1.speed < 2.2 && b2.speed < 2.2) {
            final rvx = (b2.x - b2.prevX) - (b1.x - b1.prevX);
            final rvy = (b2.y - b2.prevY) - (b1.y - b1.prevY);
            final vn = rvx * nx + rvy * ny;
            if (vn < 0) {
              b1.prevX = b1.x - ((b1.x - b1.prevX) - nx * vn * 0.55);
              b1.prevY = b1.y - ((b1.y - b1.prevY) - ny * vn * 0.55);
              b2.prevX = b2.x - ((b2.x - b2.prevX) + nx * vn * 0.55);
              b2.prevY = b2.y - ((b2.y - b2.prevY) + ny * vn * 0.55);
            }
            b1.angularVelocity *= 0.35;
            b2.angularVelocity *= 0.35;
          }
        }
      }
    }
    return merges;
  }

  /// True if [b] sits nearly atop another body (should keep rolling, not sleep).
  bool _isPerched(InsectBody b) {
    final br = b.radius * b.spawnScale;
    for (final o in bodies) {
      if (identical(o, b) || o.isMarkedForRemoval) continue;
      if (o.y <= b.y) continue;
      final dx = b.x - o.x;
      final dy = b.y - o.y;
      final reach = br + o.radius * o.spawnScale + 2.0;
      if (dx * dx + dy * dy > reach * reach) continue;
      if (dx.abs() < o.radius * 0.65) return true;
    }
    return false;
  }

  /// +1 right / -1 left — side with more open space in the bowl.
  double _freerSide(InsectBody b) {
    var leftHits = 0;
    var rightHits = 0;
    for (final o in bodies) {
      if (identical(o, b) || o.isMarkedForRemoval) continue;
      final dy = (o.y - b.y).abs();
      if (dy > b.radius * 2.2) continue;
      if (o.x < b.x) leftHits++;
      if (o.x > b.x) rightHits++;
    }
    if (leftHits == rightHits) {
      // Prefer bowl center so pile packs inward.
      return b.x >= arenaCenter.dx ? -1.0 : 1.0;
    }
    return leftHits > rightHits ? 1.0 : -1.0;
  }

  /// Soft radial blast from a merge epicenter — mostly lateral, little lift.
  void applyMergeBlast(
    double ox,
    double oy,
    double force, {
    double? radius,
  }) {
    final blastR = radius ?? arenaRadius * 0.42;
    for (final b in bodies) {
      if (b.isMarkedForRemoval || b.isStatic) continue;
      final dx = b.x - ox;
      final dy = b.y - oy;
      final distSq = dx * dx + dy * dy;
      if (distSq < 0.25 || distSq > blastR * blastR) continue;
      final dist = sqrt(distSq);
      final falloff = 1.0 - dist / blastR;
      final w = falloff * falloff;
      final nx = dx / dist;
      final ny = dy / dist;
      final ix = nx * force * w * b.mass * 0.28;
      var iy = (ny * 0.35 - 0.15) * force * w * b.mass * 0.22;
      final maxUp = force * 0.22 * b.mass * 0.22;
      final maxDown = force * 0.2 * b.mass * 0.22;
      iy = iy.clamp(-maxUp, maxDown);
      b.applyImpulse(ix, iy);
      b.angularVelocity =
          (b.angularVelocity * 0.7).clamp(-maxAngularVelocity, maxAngularVelocity);
    }
  }

  /// Tiny contact shove when two insects merge (physics step, no juice).
  void _nudgeNeighborsFromMerge(double ox, double oy, double reach) {
    for (final b in bodies) {
      if (b.isMarkedForRemoval || b.isStatic) continue;
      final dx = b.x - ox;
      final dy = b.y - oy;
      final distSq = dx * dx + dy * dy;
      if (distSq < 1.0 || distSq > reach * reach) continue;
      final dist = sqrt(distSq);
      final w = 1.0 - dist / reach;
      b.applyImpulse(dx / dist * 2.2 * w * b.mass, dy / dist * 1.2 * w * b.mass);
    }
  }

  @Deprecated('Use applyMergeBlast — random full-field shake launches insects off-screen')
  void applyShakeImpulse(double force) {
    applyMergeBlast(arenaCenter.dx, arenaCenter.dy, force * 0.35);
  }

  /// "Şuraları Bir Aydınlat Hele!" Mega Airstrike/Spotlight Bonus
  /// Clears 50% of the field and explodes with cosmic particles
  int executeAydinlatAirstrike() {
    int cleared = 0;
    for (final b in bodies) {
      if (b.tier.tier <= 6 && !b.isMarkedForRemoval) {
        b.isMarkedForRemoval = true;
        spawnParticles(b.x, b.y, LululuColors.warningSolar, count: 25);
        cleared++;
      }
    }
    return cleared;
  }

  int sprayVaporizeSmallest(int count) {
    bodies.sort((a, b) => a.tier.index.compareTo(b.tier.index));
    int vaporized = 0;
    for (final b in bodies) {
      if (b.tier.tier <= 3 && !b.isMarkedForRemoval) {
        b.isMarkedForRemoval = true;
        spawnParticles(b.x, b.y, LululuColors.cyberFuchsia, count: 20);
        vaporized++;
        if (vaporized >= count) break;
      }
    }
    return vaporized;
  }
}
