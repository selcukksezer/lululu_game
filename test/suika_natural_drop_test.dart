// 10B — Suika doğal düşüş: tohumlu bırakma rastgeleliği + kademe
// tablosu + yumuşak iniş squash'ı testleri.
//
// Kapsam: `CircularPhysicsEngine.addDropBody` / `setDropSeed` ve
// kademe-bağımlı parametre tablosu (lib/physics/physics_engine.dart).
// Birleşme / skor / tehlike çizgisi kurallarına dokunulmadığı için bu
// testler yalnız düşüş hissini sınar; denge testleri ayrı dosyalardadır.
import 'package:flutter_test/flutter_test.dart';

import 'package:lululu_game/models/insect_tier.dart';
import 'package:lululu_game/physics/physics_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 600x600 kare arena, merkez (300, 300), zemin y = 600.
  CircularPhysicsEngine squareEngine() => CircularPhysicsEngine(
    arenaCenter: const Offset(300, 300),
    arenaRadius: 300,
    arenaWidth: 600,
    arenaHeight: 600,
    squareArena: true,
  );

  List<List<Object?>> snapshot(CircularPhysicsEngine engine) => [
    for (final b in engine.bodies)
      [
        b.id,
        b.tier.index,
        b.x,
        b.y,
        b.prevX,
        b.prevY,
        b.angle,
        b.angularVelocity,
        b.spawnScale,
        b.mergeSquash,
      ],
  ];

  group('10B dogal dusus — kademe tablosu', () {
    test('kucuk kademe daha ceviktir: sapma / egim / donus buyuk', () {
      const small = InsectTier.cone; // kademe 1
      const big = InsectTier.pinkJacket; // kademe 10
      expect(
        CircularPhysicsEngine.dropJitterPx(small),
        greaterThan(CircularPhysicsEngine.dropJitterPx(big)),
      );
      expect(
        CircularPhysicsEngine.dropTiltRad(small),
        greaterThan(CircularPhysicsEngine.dropTiltRad(big)),
      );
      expect(
        CircularPhysicsEngine.dropSpin(small),
        greaterThan(CircularPhysicsEngine.dropSpin(big)),
      );
      // Açısal sönüm çarpanı BÜYÜK = dönüş daha uzun sürer.
      expect(
        CircularPhysicsEngine.angularDampingFor(small),
        greaterThan(CircularPhysicsEngine.angularDampingFor(big)),
      );
      expect(
        CircularPhysicsEngine.tierRollFactor(small),
        greaterThan(CircularPhysicsEngine.tierRollFactor(big)),
      );
    });

    test('tablo uclari: kademe 1 sapma 7 px, kademe 10 sapma 2.5 px', () {
      expect(CircularPhysicsEngine.dropJitterPx(InsectTier.cone), 7.0);
      expect(
        CircularPhysicsEngine.dropJitterPx(InsectTier.pinkJacket),
        closeTo(2.5, 0.001),
      );
      expect(CircularPhysicsEngine.dropSpin(InsectTier.cone), 1.6);
      expect(
        CircularPhysicsEngine.angularDampingFor(InsectTier.cone),
        closeTo(0.72, 0.001),
      );
    });
  });

  group('10B dogal dusus — birakma sinirlari', () {
    test('sapma tablo sinirinda kalir, govde arena disina tasamaz', () {
      final engine = squareEngine();
      engine.setDropSeed(42);
      const aims = [60.0, 150.0, 300.0, 450.0, 540.0];
      const tiers = [
        InsectTier.cone,
        InsectTier.helmet,
        InsectTier.fan,
        InsectTier.dancer,
        InsectTier.diva,
      ];
      for (var i = 0; i < aims.length; i++) {
        final tier = tiers[i];
        final body = engine.addDropBody(tier, aims[i], 60);
        final jitter = CircularPhysicsEngine.dropJitterPx(tier);
        expect(
          (body.x - aims[i]).abs(),
          lessThanOrEqualTo(jitter + 0.001),
          reason: 'sapma kademe sapma tablosunu asamaz',
        );
        expect(
          body.angle.abs(),
          lessThanOrEqualTo(
            CircularPhysicsEngine.dropTiltRad(tier) + 0.001,
          ),
        );
        expect(
          body.angularVelocity.abs(),
          lessThanOrEqualTo(
            CircularPhysicsEngine.dropSpin(tier) + 0.001,
          ),
        );
        // Doğma taşması payıyla arena içinde.
        final margin = tier.radius * 1.06 + 2.0;
        expect(body.x, greaterThanOrEqualTo(margin - 0.001));
        expect(body.x, lessThanOrEqualTo(600 - margin + 0.001));
      }
    });

    test('duz addBody degismedi: egim / donus sifir', () {
      final engine = squareEngine();
      engine.addBody(InsectTier.cone, 300, 100);
      final body = engine.bodies.single;
      expect(body.angle, 0.0);
      expect(body.angularVelocity, 0.0);
      expect(
        body.angularDamping,
        closeTo(
          CircularPhysicsEngine.angularDampingFor(InsectTier.cone),
          0.001,
        ),
      );
    });
  });

  group('10B dogal dusus — determinizm', () {
    test('ayni tohum + ayni birakma sirasi ayni dususu verir', () {
      CircularPhysicsEngine build() {
        final engine = squareEngine();
        engine.setDropSeed(20261119);
        const tiers = [
          InsectTier.cone,
          InsectTier.helmet,
          InsectTier.fan,
          InsectTier.dancer,
          InsectTier.diva,
          InsectTier.cone,
        ];
        for (var i = 0; i < tiers.length; i++) {
          engine.addDropBody(tiers[i], 150.0 + i * 60.0, 60);
          for (var f = 0; f < 40; f++) {
            engine.update(1 / 60);
          }
        }
        return engine;
      }

      final a = build();
      final b = build();
      expect(snapshot(a), snapshot(b));
    });

    test('farkli tohum farkli birakma verir', () {
      final a = squareEngine()..setDropSeed(1);
      final b = squareEngine()..setDropSeed(2);
      final bodyA = a.addDropBody(InsectTier.cone, 300, 60);
      final bodyB = b.addDropBody(InsectTier.cone, 300, 60);
      expect(
        bodyA.x != bodyB.x || bodyA.angle != bodyB.angle,
        isTrue,
        reason: 'tohum degisince sapma / egim degismeli',
      );
    });
  });

  group('10B dogal dusus — yumusak inis', () {
    test('yuksekten inen bocek temas aninda squash alir', () {
      final engine = squareEngine();
      engine.setDropSeed(7);
      engine.addDropBody(InsectTier.cone, 300, 80);
      var maxSquash = 0.0;
      for (var f = 0; f < 240; f++) {
        engine.update(1 / 60);
        for (final b in engine.bodies) {
          if (b.mergeSquash > maxSquash) maxSquash = b.mergeSquash;
        }
        if (engine.bodies.single.spawnScale >= 1.0 &&
            engine.bodies.single.speed < 0.6) {
          break;
        }
      }
      expect(maxSquash, greaterThan(0.2));
      // Zemin üstünde durdu, tavana / duvara fırlamadı.
      final body = engine.bodies.single;
      expect(body.y, greaterThan(500));
      expect(body.y, lessThanOrEqualTo(600 - body.radius + 1));
    });
  });
}
