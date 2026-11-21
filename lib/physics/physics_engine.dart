import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/lululu_theme.dart';
import '../models/insect_tier.dart';

class MergeEvent {
  final InsectTier tier;
  final double x;
  final double y;

  /// Birleşen çiftteki gövdelerden en az biri Hışır derili miydi?
  /// Skor/kademe [tier] üzerinden aynen hesaplanır; bu bayrak yalnız
  /// ses + replik seçimi içindir.
  final bool hisirInvolved;

  const MergeEvent({
    required this.tier,
    required this.x,
    required this.y,
    this.hisirInvolved = false,
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
  bool isMarkedForRemoval;
  double spawnScale;
  double mergeSquash;

  /// Hışır derisi: gövde bu kademenin böceği gibi davranır (fizik,
  /// birleşme, skor aynen), yalnız görseli `hisir_hd.png` olur.
  /// Birleşince doğan üst kademe gövde Hışır değildir.
  bool isHisir;

  /// Kademe-bağımlı açısal sönüm (60 Hz kare başına çarpan; küçük
  /// kademeler daha uzun döner, büyükler daha çabuk durur). Motor
  /// [CircularPhysicsEngine.angularDampingFor] ile doldurur.
  double angularDamping;

  InsectBody({
    required this.id,
    required this.tier,
    required this.x,
    required this.y,
    double? prevX,
    double? prevY,
    this.angle = 0.0,
    this.angularVelocity = 0.0,
    this.isMarkedForRemoval = false,
    this.spawnScale = 0.2,
    this.mergeSquash = 0,
    this.angularDamping = CircularPhysicsEngine.defaultAngularDamping,
    this.isHisir = false,
  }) : prevX = prevX ?? x,
       prevY = prevY ?? y;

  double get radius => tier.radius;
  double get mass => tier.mass;

  void respawn({
    required InsectTier nextTier,
    required double nx,
    required double ny,
    double initialAngle = 0.0,
    double initialAngularVelocity = 0.0,
    bool isHisir = false,
  }) {
    tier = nextTier;
    x = nx;
    y = ny;
    prevX = nx;
    prevY = ny - 4.5;
    angle = initialAngle;
    angularVelocity = initialAngularVelocity;
    angularDamping = CircularPhysicsEngine.angularDampingFor(nextTier);
    isMarkedForRemoval = false;
    spawnScale = 0.2;
    mergeSquash = 0;
    this.isHisir = isHisir;
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
  double arenaWidth;
  double arenaHeight;
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

  /// Eski varsayılan açısal sönüm (kademe tablosu öncesi davranışın
  /// orta noktası); [InsectBody.angularDamping] başlangıç değeri.
  static const double defaultAngularDamping = _angularDamping;

  // ------------------------------------------------------------------
  // 10B — Suika doğal düşüş: kademe-bağımlı düşüş parametreleri.
  //
  // Hepsi kademe numarasından (1 = en küçük, 11+ = en büyük) doğrusal
  // türetilir; sabit sayı sihirli değil, tablonun iki ucudur:
  // küçük kademeler çevik (daha çok sapma / eğim / dönüş, daha az
  // sönüm), büyük kademeler ağır/hantal (az sapma, çabuk duran dönüş).
  // ------------------------------------------------------------------

  /// Kademe numarasını tablo aralığına kelepçeler.
  static int _tierIndex(InsectTier tier) => tier.tier.clamp(1, 11);

  /// Bırakmada x sapması (± px): kademe 1'de 4.0, kademe 11'de 2.0
  /// (Dalga 17: 7.0'dan hafifletildi — bırakma jitter'ı yığını dağıtıyordu).
  static double dropJitterPx(InsectTier tier) =>
      4.0 - (_tierIndex(tier) - 1) * 0.2;

  /// Bırakmada başlangıç eğimi (± radyan): kademe 1'de 0.22, 11'de 0.06.
  static double dropTiltRad(InsectTier tier) =>
      0.22 - (_tierIndex(tier) - 1) * 0.016;

  /// Bırakmada başlangıç açısal hızı (± rad/s): 1'de 1.0, 11'de 0.5
  /// (Dalga 17: 1.6'dan hafifletildi).
  static double dropSpin(InsectTier tier) =>
      1.0 - (_tierIndex(tier) - 1) * 0.05;

  /// Açısal sönüm (60 Hz kare başına çarpan; BÜYÜK = daha uzun dönüş):
  /// kademe 1'de 0.72, kademe 11'de 0.50 (eski sabit 0.62 orta nokta).
  static double angularDampingFor(InsectTier tier) =>
      0.72 - (_tierIndex(tier) - 1) * 0.022;

  /// Yığındaki üst gövdenin yana yuvarlanma isteği (eski 2.6 px
  /// itkinin çarpanı): kademe 1'de 1.15, kademe 11'de 0.60.
  static double tierRollFactor(InsectTier tier) =>
      1.15 - (_tierIndex(tier) - 1) * 0.055;

  /// Tohumlu bırakma rastgeleliği: oyun her tur başında
  /// [setDropSeed] ile tohumlanır; aynı tohum + aynı bırakma sırası
  /// aynı düşüşü verir. Çıplak `Random()` kullanılmaz.
  int _dropSeed = 0;
  Random _dropRng = Random(0);

  /// Bırakma rastgeleliğini [seed] ile sıfırlar. Oyun her tur başında
  /// tur damgasıyla çağırır; testler sabit tohumla determinizmi sınar.
  void setDropSeed(int seed) {
    _dropSeed = seed;
    _dropRng = Random(seed);
  }

  int get dropSeed => _dropSeed;

  /// Below this Verlet step length, body sleeps (stops micro-jitter).
  static const double _sleepSpeed = 0.55;

  /// Below this Verlet step speed a stacked body no longer gets the
  /// roll-off shove (see _resolveBodyCollisions): the pile is settling,
  /// don't keep feeding it sideways energy. 1.0 px/step ≈ 120 px/s at
  /// the 120 Hz fixed step — well above the ~0.1 px/step gravity sag
  /// of a resting body, well below a genuinely rolling one.
  static const double _settleRollSpeed = 1.0;

  /// Dalga 17 — destek "sakin" sayılma eşiği (px/adım): destek bu hızın
  /// altında kıpırdıyorsa üstteki gövde uyuyabilir. [_sleepSpeed] (0,55)
  /// ile veto, tek kıpırdayan böceğin tüm yığını uyanık tutmasına yol
  /// açıyordu; 2,0 px/adım ≈ 240 px/s, hâlâ gerçekten yuvarlanan
  /// desteğin çok altında, dinlenen yığının mikro-kıpırtısının üstünde.
  static const double _supportCalmSpeed = 2.0;
  /// a body resting on its support may sit up to this far above exact
  /// contact after discrete integration + separation (same +2.0 the
  /// perch check already used).
  static const double _supportSlack = 2.0;

  /// Minimum upward component of a support contact's normal (cosine):
  /// the supporter must be meaningfully below the body, not a purely
  /// sideways neighbour. 0.35 ≈ 69° off vertical — wide enough for a
  /// body sitting in a pocket between two lower bodies.
  static const double _supportUpwardCos = 0.35;

  /// Fixed physics step: 120 Hz sub-steps keep behaviour identical across
  /// 60 Hz / 120 Hz displays (see update()).
  static const double _fixedStep = 1.0 / 120.0;
  static const int _maxSubSteps = 3;

  /// Danger line sits this fraction of the arena height below the arena
  /// top — the same relative threshold for bowl and square arenas.
  static const double _dangerLineFraction = 0.12;

  /// Arena obstacle radius as a fraction of [arenaRadius], so blocks
  /// scale with the arena (18 px at the 150 px reference radius).
  static const double _blockRadiusFraction = 0.12;

  /// Max per-step vertical drift still counted as "resting" above the
  /// danger line (see isOverflowing). At the 120 Hz fixed step this is
  /// 120 px/s — well below fall speeds, so fresh drops never trigger it.
  static const double _overflowStillnessPx = 1.0;

  /// Birleşmeden beri geçen süre (sn): birleşme sonrası ilk 0,5 sn
  /// yuvarlanma itkisi bastırılır (Dalga 17) — yeni doğan gövdenin
  /// yerleşme sarsıntısı yığını yana itmesin. [_stepPhysics] her
  /// alt-adımda ilerletir, birleşme sıfırlar.
  double _secondsSinceMerge = 999.0;

  /// Leftover frame time carried into the next update() call.
  double _timeAccumulator = 0.0;

  /// Bodies that already merged during the current update() frame.
  /// A body may merge at most once per frame: without this lock a body
  /// upgraded mid-pass could merge again in the same j-loop or in a
  /// later solver iteration / sub-step and skip several tiers at once.
  /// Locked pairs still get positional separation, just no second merge.
  final Set<InsectBody> _mergedThisFrame = <InsectBody>{};

  CircularPhysicsEngine({
    required this.arenaCenter,
    required this.arenaRadius,
    double? arenaWidth,
    double? arenaHeight,
    this.gravity = 980.0,
    this.squareArena = false,
  }) : arenaWidth = arenaWidth ?? arenaRadius * 2,
       arenaHeight = arenaHeight ?? arenaRadius * 2;

  /// Keep bodies when play-area size changes (HUD / SafeArea reflow).
  void remountLayout(
    Offset newCenter,
    double newRadius, {
    double? newArenaWidth,
    double? newArenaHeight,
  }) {
    final nextWidth = newArenaWidth ?? newRadius * 2;
    final nextHeight = newArenaHeight ?? newRadius * 2;
    if ((newCenter - arenaCenter).distance < 0.5 &&
        (newRadius - arenaRadius).abs() < 0.5 &&
        (nextWidth - arenaWidth).abs() < 0.5 &&
        (nextHeight - arenaHeight).abs() < 0.5) {
      return;
    }
    final oldC = arenaCenter;
    final scaleX = arenaWidth > 1 ? nextWidth / arenaWidth : 1.0;
    final scaleY = arenaHeight > 1 ? nextHeight / arenaHeight : 1.0;
    for (final b in bodies) {
      b.x = newCenter.dx + (b.x - oldC.dx) * scaleX;
      b.y = newCenter.dy + (b.y - oldC.dy) * scaleY;
      b.prevX = newCenter.dx + (b.prevX - oldC.dx) * scaleX;
      b.prevY = newCenter.dy + (b.prevY - oldC.dy) * scaleY;
    }
    final blockCount = blocks.length;
    arenaCenter = newCenter;
    arenaRadius = newRadius;
    arenaWidth = nextWidth;
    arenaHeight = nextHeight;
    if (blockCount > 0) layoutBlocks(blockCount);
  }

  Rect get arenaBounds => Rect.fromCenter(
    center: arenaCenter,
    width: arenaWidth,
    height: arenaHeight,
  );

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
          arenaRadius * _blockRadiusFraction,
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

  double get dangerY {
    if (squareArena) {
      return arenaBounds.top + arenaHeight * _dangerLineFraction;
    }
    return arenaCenter.dy - arenaRadius + arenaRadius * 2 * _dangerLineFraction;
  }

  /// True when a settled-enough body pokes above the danger line. The
  /// stillness check is intentionally loose: a pile creeping above the
  /// line must accumulate overflow instead of escaping via micro-motion.
  /// Fast drops are still excluded (their per-step fall far exceeds
  /// [_overflowStillnessPx]) and game_screen's grace timer still gates
  /// the actual defeat.
  bool get isOverflowing {
    for (final b in bodies) {
      if (!b.isMarkedForRemoval && b.spawnScale >= 0.8) {
        if (b.y - b.radius < dangerY &&
            (b.y - b.prevY).abs() < _overflowStillnessPx) {
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
      // Taban kenetiyle tutarlı: çizim yarı-yüksekliği 1.55r
      // (bkz. _resolveSquareBounds) — 490 - 12*1.55 - 4 = 467.4.
      land = arenaBounds.bottom - radius * 1.55 - 4;
    }
    for (final b in bodies) {
      if (b.isMarkedForRemoval || b.spawnScale < 0.55) continue;
      if ((b.x - x).abs() > b.radius + radius) continue;
      final sit = b.y - b.radius - radius;
      if (sit < land) land = sit;
    }
    for (final block in blocks) {
      final reach = block.radius + radius;
      final bdx = (block.x - x).abs();
      if (bdx > reach) continue;
      // Circle-on-circle rest: exact contact height for a circle
      // landing on a round obstacle.
      final sit = block.y - sqrt(max(0.0, reach * reach - bdx * bdx));
      if (sit < land) land = sit;
    }
    return land;
  }

  /// 0 = safe, 1 = touching danger. For HUD / pulse warning.
  /// Only resting pile bodies — mid-fall drops must NOT flash "yaklaştın".
  double get dangerProximity {
    var worst = 0.0;
    final band = squareArena ? arenaHeight * 0.12 : arenaRadius * 0.22;
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

  void addBody(
    InsectTier tier,
    double x,
    double y, {
    double initialAngle = 0.0,
    double initialAngularVelocity = 0.0,
    bool isHisir = false,
  }) {
    final InsectBody body;
    if (_pool.isNotEmpty) {
      body = _pool.removeLast();
      body.respawn(
        nextTier: tier,
        nx: x,
        ny: y,
        initialAngle: initialAngle,
        initialAngularVelocity: initialAngularVelocity,
        isHisir: isHisir,
      );
    } else {
      body = InsectBody(
        id: _nextId++,
        tier: tier,
        x: x,
        y: y,
        spawnScale: 0.2,
        angle: initialAngle,
        angularVelocity: initialAngularVelocity,
        angularDamping: angularDampingFor(tier),
        isHisir: isHisir,
      );
      body.prevY = y - 4.5;
    }
    bodies.add(body);
  }

  /// Doğal bırakma: [aimX] çevresinde tohumlu küçük x sapması +
  /// başlangıç eğimi / dönüş (kademe tablosundan). Sapmış x, doğma
  /// taşması payıyla (yarıçap × 1.06 + 2 px) arena sınırları içinde
  /// kelepçelenir — bırakma asla duvar dışına taşmaz.
  InsectBody addDropBody(
    InsectTier tier,
    double aimX,
    double y, {
    bool isHisir = false,
  }) {
    final jitter = dropJitterPx(tier);
    final dx = (_dropRng.nextDouble() * 2 - 1) * jitter;
    final tilt = (_dropRng.nextDouble() * 2 - 1) * dropTiltRad(tier);
    final spin = (_dropRng.nextDouble() * 2 - 1) * dropSpin(tier);
    var x = aimX + dx;
    final margin = tier.radius * 1.06 + 2.0;
    if (squareArena) {
      final minX = arenaBounds.left + margin;
      final maxX = arenaBounds.right - margin;
      x = minX > maxX ? (minX + maxX) / 2 : x.clamp(minX, maxX);
    } else {
      final dxc = x - arenaCenter.dx;
      final dyc = y - arenaCenter.dy;
      final maxR = arenaRadius - margin;
      final distSq = dxc * dxc + dyc * dyc;
      if (distSq > maxR * maxR && distSq > 0.0001) {
        final dist = sqrt(distSq);
        x = arenaCenter.dx + dxc / dist * maxR;
      }
    }
    addBody(tier, x, y, initialAngle: tilt, initialAngularVelocity: spin, isHisir: isHisir);
    return bodies.last;
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
          color: i.isEven ? color : Color.lerp(color, Colors.white, 0.35)!,
          size: 1.8 + rand.nextDouble() * 4.2,
          angle: rand.nextDouble() * pi,
          spin: (rand.nextDouble() - 0.5) * 16,
        ),
      );
    }
  }

  /// Step the physics simulation using Verlet Integration
  /// Returns merge events (tier + arena position) for audio/juice triggers.
  ///
  /// Fixed-timestep: frame time accumulates and is consumed in 120 Hz
  /// sub-steps (at most [_maxSubSteps] per call); the remainder carries
  /// over to the next call instead of being dropped. The signature is
  /// unchanged for the game_screen caller.
  List<MergeEvent> update(double dt) {
    // New frame: every body may merge once again (see _mergedThisFrame).
    _mergedThisFrame.clear();
    if (dt < 0) dt = 0;
    if (dt > 0.033) dt = 0.033; // clamp dt to avoid explosions
    _timeAccumulator += dt;
    // Spiral-of-death guard: never carry more than one frame of steps.
    final maxAccum = _fixedStep * _maxSubSteps;
    if (_timeAccumulator > maxAccum) _timeAccumulator = maxAccum;

    final mergeEvents = <MergeEvent>[];
    var steps = 0;
    while (_timeAccumulator >= _fixedStep && steps < _maxSubSteps) {
      mergeEvents.addAll(_stepPhysics(_fixedStep));
      _timeAccumulator -= _fixedStep;
      steps++;
    }

    // Particles tick once per frame with the full frame dt (unchanged).
    particles.removeWhere((p) => !p.update(dt));

    return mergeEvents;
  }

  /// One fixed-size Verlet step. Damping factors are dt-scaled so a
  /// 120 Hz sub-step behaves exactly like half of a 60 Hz frame.
  List<MergeEvent> _stepPhysics(double dt) {
    _secondsSinceMerge += dt;
    // Damping is defined per 60 Hz frame; scale it to this step's dt so
    // behaviour is identical at any step rate.
    final damping = pow(0.972, dt * 60).toDouble();
    final restDampingX = pow(0.9, dt * 60).toDouble();
    final restDampingY = pow(0.94, dt * 60).toDouble();

    // 1. Verlet position update
    for (final b in bodies) {
      // Mild pop-in — avoid large overshoot (radius flicker = collision jitter).
      if (b.spawnScale < 1.0) {
        b.spawnScale = min(1.06, b.spawnScale + dt * 5.0);
      } else if (b.spawnScale > 1.0) {
        b.spawnScale = max(1.0, b.spawnScale - dt * 4.5);
      }
      b.mergeSquash = max(0, b.mergeSquash - dt * 5.5);

      var vx = (b.x - b.prevX) * damping;
      var vy = (b.y - b.prevY) * damping + (gravity * dt * dt);

      // Mild rest damping — keep enough energy to roll off neighbors.
      final spd = sqrt(vx * vx + vy * vy);
      if (spd < 1.4) {
        vx *= restDampingX;
        vy *= restDampingY;
      }

      b.prevX = b.x;
      b.prevY = b.y;

      b.x += vx;
      b.y += vy;

      b.angle += b.angularVelocity * dt;
      // Kademe-bağımlı açısal sönüm (küçük kademe daha uzun döner).
      b.angularVelocity *= pow(b.angularDamping, dt * 60).toDouble();
      if (b.angularVelocity.abs() < 0.18) {
        b.angularVelocity = 0;
      } else {
        b.angularVelocity = b.angularVelocity.clamp(
          -maxAngularVelocity,
          maxAngularVelocity,
        );
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

    // Sleep ONLY when truly calm AND supported (floor / bowl wall /
    // block / another body below). An unsupported body must never
    // sleep: one Verlet gravity step adds only ~0.068 px, far below
    // _sleepSpeed (0.55), so a mid-air body that slows down could
    // never re-accumulate enough speed to wake — it froze in mid-air
    // forever (Suika videosu: havada asılı tier-1'ler; birleşen gövde
    // birleşme noktasında donuyor; desteği birleşmeyle kaybolan uyuyan
    // gövde havada kalıyor). Destekli gövde, destekleri de sakinse
    // uyur — tünemiş gövde desteği sakinken uyur (diğer işçinin
    // düzeltmesi aynen korunur), destek hareketliyken yuvarlanmaya
    // devam eder. Desteği kaybolan uyuyan gövde ayrıca uyandırılmaz:
    // destek yoksa bu geçişte uyutulmaz, yerçekimi 2-3 adımda yeniden
    // hız kazandırır.
    for (final b in bodies) {
      if (b.isMarkedForRemoval) continue;
      if (b.spawnScale < 0.95) continue;
      if (b.speed >= _sleepSpeed) continue;
      if (!_isSupportedAndCalm(b)) continue;
      b.prevX = b.x;
      b.prevY = b.y;
      b.angularVelocity = 0;
    }

    _removeMarkedBodies();

    return mergeEvents;
  }

  /// Recycle every body flagged for removal back into [_pool].
  /// Single choke point for all removals (merge cleanup in [_stepPhysics]
  /// and the booster clears below) so removed bodies are always reused
  /// instead of dropped.
  void _removeMarkedBodies() {
    for (var i = bodies.length - 1; i >= 0; i--) {
      final b = bodies[i];
      if (!b.isMarkedForRemoval) continue;
      b.isMarkedForRemoval = false;
      _pool.add(b);
      bodies.removeAt(i);
    }
  }

  /// 10B — yumuşak iniş: sert temas anında (iniş hızına bağlı) kısa
  /// squash bırakır; çizici bunu mevcut `mergeSquash` deseniyle çizer
  /// (aynı alan, yeni asset yok). [closingSpeed] adım başına px'tir
  /// (4 px/adım ≈ 480 px/s); altı sessiz temas sayılır, squash yok.
  void _registerImpact(InsectBody b, double closingSpeed) {
    if (closingSpeed <= 4.0) return;
    final s = (closingSpeed / 14.0).clamp(0.0, 0.85);
    if (s > b.mergeSquash) b.mergeSquash = s;
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
        // S1#4 (kalan): tam çakışan gövde-engel çifti (distSq ≤ 0.0001)
        // eskiden bütünüyle yoksayılıyordu: engel merkezine oturan gövde
        // hiç ayrıştırılmıyor, engelin içinde takılı kalıyordu. Cisim-cisim
        // çözümündeki gibi 0.01 px etkin mesafe + deterministik +x normali
        // kullanılır; çakışma dışı çiftlerde davranış birebir aynıdır.
        final coincident = distSq <= 0.0001;
        if (distSq >= minDist * minDist) continue;
        final dist = coincident ? 0.01 : sqrt(distSq);
        final nx = coincident ? 1.0 : dx / dist;
        final ny = coincident ? 0.0 : dy / dist;
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
        final vnOut = vx * nx + vy * ny;
        if (vnOut > 0) _registerImpact(b, vnOut);
        b.prevX = b.x - vx * 0.28;
        b.prevY = b.y - vy * 0.22;
      }
    }
  }

  void _resolveSquareBounds() {
    final bounds = arenaBounds;
    final left = bounds.left;
    final right = bounds.right;
    final floorY = bounds.bottom;
    // Görsel yarı-yükseklik: çizim fizik yarıçapının 1.55 katı
    // (GameArenaPainter._spriteVisualScale ile aynı olmalı) — taban
    // keneti görsel boyuta göre yapılmazsa dibe oturan böcek çizimi
    // 0.55r kadar arena dışına taşar ve sert kırpılır (Dalga 15/13b).
    const visualScale = 1.55;
    for (final b in bodies) {
      final r = b.radius * b.spawnScale;
      // Wall clamp applies above the rim too: a body overhanging the
      // ceiling must not drift outside the side walls before it drops in.
      if (b.x < left + r) {
        b.x = left + r;
        if (b.prevX < b.x) b.prevX = b.x;
      } else if (b.x > right - r) {
        b.x = right - r;
        if (b.prevX > b.x) b.prevX = b.x;
      }
      if (b.y > floorY - r * visualScale) {
        final vx = b.x - b.prevX;
        final vy = b.y - b.prevY;
        if (vy > 0) _registerImpact(b, vy);
        b.y = floorY - r * visualScale;
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

        final touch = targetDist + 4;
        // S1#4: tam çakışan çiftler (distSq ≤ 0.0001, yani merkezler
        // arası ≤ 0.01 px) eskiden bütünüyle yoksayılıyordu: aynı
        // yerçekimiyle kilit-adım hareket eden çift hiç ayrılmıyor,
        // aynı kademedeyse hiç birleşmiyordu (uyku bloğu hızları
        // sıfırlayınca kalıcı takılma). Çakışma durumunda 0.01 px
        // etkin mesafe + deterministik +x normali kullanılır; birleşme
        // ve ayrıştırma normal yoldan işler.
        final coincident = distSq <= 0.0001;
        if (distSq < touch * touch) {
          final dist = coincident ? 0.01 : sqrt(distSq);

          if (b1.tier == b2.tier &&
              b1.tier.nextTier != null &&
              !_mergedThisFrame.contains(b1) &&
              !_mergedThisFrame.contains(b2)) {
            final next = b1.tier.nextTier!;
            final midX = (b1.x + b2.x) / 2;
            final midY = (b1.y + b2.y) / 2;
            // Hışır derisi birleşmeye katıldıysa olay bunu taşır; doğan
            // üst kademe gövde artık Hışır değildir (deri tek kullanımlık).
            final hisirInvolved = b1.isHisir || b2.isHisir;

            b1.tier = next;
            b1.isHisir = false;
            // Birleşen gövde yeni kademenin dönüş karakterini alır.
            b1.angularDamping = angularDampingFor(next);
            // One merge per body per frame — lock b1 for this frame.
            // A locked pair falls through to separation below instead.
            _mergedThisFrame.add(b1);
            b1.x = midX;
            b1.y = midY;
            // Settle in place — no upward launch.
            b1.prevX = midX;
            b1.prevY = midY;
            b1.spawnScale = 0.55;
            b1.mergeSquash = 1;
            b1.angularVelocity = 0;
            // Dalga 17: birleşme saati sıfırlanır — ilk 0,5 sn
            // yuvarlanma itkisi bastırılır (aşağıdaki _resolveBodyCollisions
            // yuvarlanma dalı).
            _secondsSinceMerge = 0.0;
            // Merkeze doğru itki: yatay merkezleme aynen, dikey bileşen
            // asla yukarı kaldırmasın. Arenanın merkezi yığının
            // üstündedir; cy < 0 her birleşmede gövdeyi kütleye bağlı
            // ~1.5-3.7 px/adım (~180-450 px/s) yukarı fırlatıyordu —
            // videoda birleşme (+50) sonrası böceklerin "uçması" bu
            // (yerdeki kademe-1→2 birleşmede |cy| ≈ 350 px, iy ≈ -5.6,
            // kütle 1.5 → 3.7 px/adım yukarı). Merkez alttaysa (yığın
            // merkezin üstünde) aşağı itki aynen durur.
            final cx = arenaCenter.dx - midX;
            final cy = arenaCenter.dy - midY;
            b1.applyImpulse(cx * 0.012, max(0.0, cy * 0.016));

            b2.isMarkedForRemoval = true;
            spawnParticles(midX, midY, next.color, count: 8 + next.tier);
            _nudgeNeighborsFromMerge(midX, midY, next.radius * 1.6);
            merges.add(
              MergeEvent(
                tier: next,
                x: midX,
                y: midY,
                hisirInvolved: hisirInvolved,
              ),
            );
            continue;
          }

          final overlap = targetDist - dist;
          // Çakışmada normal tanımsızdır (dx = dy = 0); deterministik
          // +x yönü çifti yatayda ayırır.
          final nx = coincident ? 1.0 : dx / dist;
          final ny = coincident ? 0.0 : dy / dist;

          // Yaklaşma hızı (normal bileşen): sert iniş/temas squash'ı
          // + aşağıdaki yavaş-temas sönümü aynı değerden beslenir.
          final rvx = (b2.x - b2.prevX) - (b1.x - b1.prevX);
          final rvy = (b2.y - b2.prevY) - (b1.y - b1.prevY);
          final vn = rvx * nx + rvy * ny;
          if (vn < 0) {
            _registerImpact(b1, -vn);
            _registerImpact(b2, -vn);
          }

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
          final stacked =
              ny.abs() > 0.5 &&
              upper.y < lower.y &&
              (lower.y - upper.y) < targetDist * 1.05;
          if (stacked) {
            final dxOff = upper.x - lower.x;
            final balance = lower.radius * 0.38;
            if (dxOff.abs() < balance) {
              // Dalga 15 — yerleşmiş cisimleri itme: üstteki cisim zaten
              // yavaşsa (dibe oturmuş yığın) yuvarlanma itkisi verme,
              // yoksa dibe oturan böcekler sürekli yana kayar. Hızlı /
              // yeni düşen cisimlerde organik boşluk doldurma aynen sürer.
              // Dalga 17: birleşme sonrası ilk 0,5 sn yuvarlanma itkisi
              // bastırılır — yeni doğan gövdenin yerleşme sarsıntısı
              // yığını yana itmesin.
              if (upper.speed > _settleRollSpeed &&
                  _secondsSinceMerge > 0.5) {
                final dir = dxOff.abs() < 0.6 ? _freerSide(upper) : dxOff.sign;
                // 10B: küçük kademe daha istekli yuvarlanır, büyük daha
                // ağır oturur — boşluklar ızgara gibi değil, organik dolar.
                upper.prevX = upper.x - dir * 2.6 * tierRollFactor(upper.tier);
              }
            } else {
              // Keep rolling off the shoulder; light friction only.
              final ux = upper.x - upper.prevX;
              upper.prevX = upper.x - ux * 0.96;
            }
          }

          // Kill bounce (normal), keep tangential settle.
          if (b1.speed < 2.2 && b2.speed < 2.2) {
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

  /// True if [b] rests on something that can hold it against gravity
  /// AND every such support is calm. No support → false: the body must
  /// keep falling, never sleep (see the sleep pass in _stepPhysics).
  /// Static supports (floor / bowl wall / block) always count as calm;
  /// a body support vetoes sleep only while it moves faster than
  /// [_supportCalmSpeed] (Dalga 17: eskiden [_sleepSpeed] eşiğiyle veto
  /// ediliyordu — tek kıpırdayan böcek tüm yığını uyanık tutuyordu).
  /// A body in a pocket between two lower bodies counts as supported
  /// (each contact's normal has an upward component > [_supportUpwardCos]);
  /// a purely sideways neighbour does not support.
  bool _isSupportedAndCalm(InsectBody b) {
    final br = b.radius * b.spawnScale;
    if (squareArena) {
      // Flat floor holds unconditionally (it never moves).
      // Dalga 16 (F-P2): taban keneti görsel yarı-yüksekliğe (1.55r)
      // göre yapılır (bkz. _resolveSquareBounds), o yüzden destek
      // testi de 1.55r kullanır; aksi hâlde dibe oturan gövde asla
      // taban-destekli sayılmazdı.
      if (b.y >= arenaBounds.bottom - br * 1.55 - _supportSlack) {
        return true;
      }
    } else {
      // Bowl wall holds only where its normal points sufficiently
      // upward — i.e. the body is meaningfully below arena center
      // (screen y grows downward, so wall normal's up-component is
      // dyc / dist). A body touching the wall up at rim height slides
      // down instead of sleeping on the rim.
      final dxc = b.x - arenaCenter.dx;
      final dyc = b.y - arenaCenter.dy;
      final distC = sqrt(dxc * dxc + dyc * dyc);
      if (distC > 0.0001 &&
          distC >= arenaRadius - br - _supportSlack &&
          dyc / distC > _supportUpwardCos) {
        return true;
      }
    }
    // Static blocks: a block below holds the body.
    for (final block in blocks) {
      final dx = b.x - block.x;
      final dy = b.y - block.y;
      final reach = br + block.radius + _supportSlack;
      if (dx * dx + dy * dy > reach * reach) continue;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist <= 0.0001) continue; // coincident: no defined normal
      if (-dy / dist > _supportUpwardCos) return true;
    }
    // Body supports. _perchSupport keeps the Dalga-15 perch rule
    // (nearly-atop a calm support may sleep; a moving perch blocks
    // sleep); the loop below adds pocket support between two lower
    // bodies, which the narrow perch check misses.
    var supported = false;
    final perch = _perchSupport(b);
    if (perch != null) {
      if (perch.speed >= _supportCalmSpeed) return false;
      supported = true;
    }
    for (final o in bodies) {
      if (identical(o, b) || identical(o, perch)) continue;
      if (o.isMarkedForRemoval) continue;
      final dx = b.x - o.x;
      final dy = b.y - o.y;
      final reach = br + o.radius * o.spawnScale + _supportSlack;
      if (dx * dx + dy * dy > reach * reach) continue;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist <= 0.0001) continue;
      if (-dy / dist <= _supportUpwardCos) continue;
      if (o.speed >= _supportCalmSpeed) return false;
      supported = true;
    }
    return supported;
  }

  /// The body [b] is nearly sitting on top of, if any (null
  /// otherwise). A perched body must keep rolling while its support
  /// moves, but may sleep once the support is calm too (see the
  /// sleep pass in _stepPhysics).
  InsectBody? _perchSupport(InsectBody b) {
    final br = b.radius * b.spawnScale;
    for (final o in bodies) {
      if (identical(o, b) || o.isMarkedForRemoval) continue;
      if (o.y <= b.y) continue;
      final dx = b.x - o.x;
      final dy = b.y - o.y;
      final reach = br + o.radius * o.spawnScale + 2.0;
      if (dx * dx + dy * dy > reach * reach) continue;
      if (dx.abs() < o.radius * 0.65) return o;
    }
    return null;
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
  void applyMergeBlast(double ox, double oy, double force, {double? radius}) {
    final blastR = radius ?? arenaRadius * 0.42;
    for (final b in bodies) {
      if (b.isMarkedForRemoval) continue;
      final dx = b.x - ox;
      final dy = b.y - oy;
      final distSq = dx * dx + dy * dy;
      if (distSq < 0.25 || distSq > blastR * blastR) continue;
      final dist = sqrt(distSq);
      final falloff = 1.0 - dist / blastR;
      final w = falloff * falloff;
      final nx = dx / dist;
      final ny = dy / dist;
      // No mass factor here: applyImpulse divides by mass, so this true
      // impulse leaves heavy tiers moving less (light tiers unchanged).
      final ix = nx * force * w * 0.28;
      var iy = (ny * 0.35 - 0.15) * force * w * 0.22;
      final maxUp = force * 0.22 * 0.22;
      final maxDown = force * 0.2 * 0.22;
      iy = iy.clamp(-maxUp, maxDown);
      b.applyImpulse(ix, iy);
      b.angularVelocity = (b.angularVelocity * 0.7).clamp(
        -maxAngularVelocity,
        maxAngularVelocity,
      );
    }
  }

  /// Tiny contact shove when two insects merge (physics step, no juice).
  void _nudgeNeighborsFromMerge(double ox, double oy, double reach) {
    for (final b in bodies) {
      if (b.isMarkedForRemoval) continue;
      final dx = b.x - ox;
      final dy = b.y - oy;
      final distSq = dx * dx + dy * dy;
      if (distSq < 1.0 || distSq > reach * reach) continue;
      final dist = sqrt(distSq);
      final w = 1.0 - dist / reach;
      // No mass factor: applyImpulse already divides by mass.
      b.applyImpulse(dx / dist * 2.2 * w, dy / dist * 1.2 * w);
    }
  }

  /// "Anne Terliği" — hedef böceği ezer ve çevresini sarsar.
  InsectBody? crushTargetInsect({double? targetX}) {
    final active = bodies.where((b) => !b.isMarkedForRemoval).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) {
      if (targetX != null) {
        final da = (a.x - targetX).abs() + a.y * 0.25;
        final db = (b.x - targetX).abs() + b.y * 0.25;
        return da.compareTo(db);
      }
      // En üstteki (en tehlikeli) böceği ez
      return a.y.compareTo(b.y);
    });
    final target = active.first;
    target.isMarkedForRemoval = true;
    spawnParticles(target.x, target.y, LululuColors.warningSolar, count: 22);
    applyMergeBlast(target.x, target.y, 16, radius: arenaRadius * 0.85);
    _removeMarkedBodies();
    return target;
  }

  /// "F-16 Bombardıman" — küçük böcekleri (T1..T4) hava bombardımanıyla patlatır.
  List<InsectBody> f16Bombardment({int maxCount = 3}) {
    final active = bodies.where((b) => !b.isMarkedForRemoval).toList();
    if (active.isEmpty) return const [];
    final small = active.where((b) => b.tier.tier <= 4).toList()
      ..sort((a, b) => a.tier.tier.compareTo(b.tier.tier));
    final pool = small.isNotEmpty ? small : active;
    final blasted = pool.take(maxCount).toList();
    for (final b in blasted) {
      b.isMarkedForRemoval = true;
      spawnParticles(b.x, b.y, LululuColors.warningSolar, count: 22);
      applyMergeBlast(b.x, b.y, 12, radius: b.radius * 3.5);
    }
    _removeMarkedBodies();
    return blasted;
  }

  /// "Şuraları Bir Aydınlat Hele!" Mega Airstrike/Spotlight Bonus
  /// Clears a random 50% of the eligible bodies (tier <= 6) and explodes
  /// with cosmic particles. Higher tiers are untouched.
  int executeAydinlatAirstrike() {
    final eligible = bodies
        .where((b) => b.tier.tier <= 6 && !b.isMarkedForRemoval)
        .toList();
    // Random half; ceil so a lone eligible body is still cleared.
    final target = (eligible.length / 2).ceil();
    eligible.shuffle(Random());
    int cleared = 0;
    for (final b in eligible.take(target)) {
      b.isMarkedForRemoval = true;
      spawnParticles(b.x, b.y, LululuColors.warningSolar, count: 25);
      cleared++;
    }
    _removeMarkedBodies();
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
    _removeMarkedBodies();
    return vaporized;
  }
}
