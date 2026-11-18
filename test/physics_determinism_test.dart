// W44-1: Fizik motoru determinizm / gerileme testleri.
//
// Kapsam: `CircularPhysicsEngine` (lib/physics/physics_engine.dart).
// Bu gece eklenen 120 Hz alt-adım akümülatörü (W2-1) ve gevşetilen hız
// eşiklerinin davranış gerilemesine yol açmasını önlemek için yazıldı.
//
// Kurallar: düz `test()` (widget pump YOK), sabit girdiler (rastgele tohum
// YOK). Karşılaştırmalar cisim durumu + birleşim olayları üzerinden yapılır;
// `engine.particles` karşılaştırmaya dahil DEĞİLDİR çünkü `spawnParticles`
// tohumlanmamış `Random` kullanır ve parçacıklar cisim durumunu etkilemez.
//
// Alt-adım sayısı doğrudan gözlenemez (`_fixedStep` / `_timeAccumulator`
// özeldir, adım sayacı yoktur); bu yüzden (f) kapsamı gözlenebilir
// davranışla sınanır: akümülatör birikimi, bölünmüş dt eşitliği ve
// 60 Hz / 120 Hz güncelleme örüntüsü eşitliği.
import 'package:flutter/material.dart';
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

  /// Cisim durumunun tamamı: determinizm karşılaştırması için kullanılır.
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
        b.isMarkedForRemoval,
      ],
  ];

  List<List<Object?>> eventSnapshot(List<MergeEvent> events) => [
    for (final e in events) [e.tier.index, e.x, e.y],
  ];

  group('fizik determinizmi (W44-1)', () {
    test('aynı girdilerle iki çalıştırma birebir aynı sonucu verir', () {
      CircularPhysicsEngine build() {
        final engine = squareEngine();
        engine.layoutBlocks(2);
        engine.addBody(InsectTier.cone, 300, 200);
        engine.addBody(InsectTier.cone, 302, 200);
        engine.addBody(InsectTier.helmet, 200, 150);
        engine.addBody(InsectTier.fan, 400, 120);
        engine.addBody(InsectTier.cone, 250, 100);
        return engine;
      }

      final engineA = build();
      final engineB = build();
      final eventsA = <MergeEvent>[];
      final eventsB = <MergeEvent>[];
      for (var i = 0; i < 30; i++) {
        eventsA.addAll(engineA.update(1 / 60));
        eventsB.addAll(engineB.update(1 / 60));
      }

      expect(snapshot(engineA), equals(snapshot(engineB)));
      expect(eventSnapshot(eventsA), equals(eventSnapshot(eventsB)));
      // Senaryo birleşme de içermeli ki birleşim yolu da sınanmış olsun.
      expect(eventsA, isNotEmpty);
    });

    test('duran cisim tek 120 Hz alt-adımında azıcık düşer, yana kaymaz', () {
      final engine = squareEngine();
      // Doğrudan kurulum: prev == pos, yani başlangıç hızı sıfır.
      // (addBody başlangıç hızı verir: prevY = y - 4.5.)
      engine.bodies.add(
        InsectBody(id: 1, tier: InsectTier.cone, x: 300, y: 100),
      );

      engine.update(1 / 120);

      final body = engine.bodies.single;
      expect(body.x, 300.0);
      // Tek alt-adım: vy = g*dt^2 ≈ 0.068 px, sönümle ≈ 0.066 px.
      expect(body.y, greaterThan(100.0));
      expect(body.y, lessThan(100.5));
    });

    test('sabit dt ile 30 alt-adım sonrası düşüş beklenen aralıktadır', () {
      final engine = squareEngine();
      engine.bodies.add(
        InsectBody(id: 1, tier: InsectTier.cone, x: 300, y: 100),
      );

      for (var i = 0; i < 30; i++) {
        engine.update(1 / 120);
      }

      final body = engine.bodies.single;
      expect(body.x, 300.0);
      // 0.25 sn serbest düşüş (sönümlü Verlet): ~21-28 px. Aralık, model
      // belirsizliğine karşı iki kat payla geniş tutuldu.
      expect(body.y, greaterThan(110.0));
      expect(body.y, lessThan(160.0));
    });

    test('düşen cisim kare arena zemininde durur ve sakinleşir', () {
      final engine = squareEngine();
      engine.addBody(InsectTier.cone, 300, 100);

      for (var i = 0; i < 240; i++) {
        engine.update(1 / 60);
      }

      expect(engine.bodies, hasLength(1));
      final body = engine.bodies.single;
      expect(body.x, closeTo(300.0, 0.001));
      // Zemin y = 600, cone yarıçapı 23: dinlenme y ≈ 577 (spawnScale
      // salınımı ±%6). Aralık payla geniş tutuldu.
      expect(body.y, greaterThan(570.0));
      expect(body.y, lessThan(580.0));
      expect(engine.isSettled, isTrue);
    });

    test('çakışan iki aynı-tier cisim birleşir', () {
      final engine = squareEngine();
      engine.addBody(InsectTier.cone, 300, 300);
      engine.addBody(InsectTier.cone, 300, 300);

      final events = engine.update(1 / 120);

      expect(events, hasLength(1));
      expect(events.single.tier, InsectTier.helmet);
      expect(events.single.x, closeTo(300.0, 1e-9));
      // Birleşim noktası: iki cismin Verlet sonrası ortak noktası
      // (başlangıç hızıyla ~304.5). Aralık payla geniş tutuldu.
      expect(events.single.y, greaterThan(300.0));
      expect(events.single.y, lessThan(310.0));
      expect(engine.bodies, hasLength(1));
      expect(engine.bodies.single.tier, InsectTier.helmet);
      expect(engine.bodies.single.mergeSquash, 1);
    });

    test('farklı-tier cisimler birleşmez', () {
      final engine = squareEngine();
      engine.addBody(InsectTier.cone, 300, 300);
      engine.addBody(InsectTier.helmet, 300, 300);

      final allEvents = <MergeEvent>[];
      for (var i = 0; i < 10; i++) {
        allEvents.addAll(engine.update(1 / 60));
      }

      expect(allEvents, isEmpty);
      expect(engine.bodies, hasLength(2));
      expect(
        engine.bodies.map((b) => b.tier),
        containsAll([InsectTier.cone, InsectTier.helmet]),
      );
    });

    test('en üst tier (pinkRobe) kendiyle birleşmez', () {
      final engine = squareEngine();
      engine.addBody(InsectTier.pinkRobe, 300, 300);
      engine.addBody(InsectTier.pinkRobe, 300, 300);

      final allEvents = <MergeEvent>[];
      for (var i = 0; i < 3; i++) {
        allEvents.addAll(engine.update(1 / 60));
      }

      // nextTier == null: birleşim koşulu hiç sağlanamaz.
      expect(allEvents, isEmpty);
      expect(engine.bodies, hasLength(2));
      expect(
        engine.bodies.every((b) => b.tier == InsectTier.pinkRobe),
        isTrue,
      );
    });

    test('tehlike çizgisi: dangerY formülü ve isOverflowing', () {
      // Kare arena: üst + yükseklik * 0.12 → 10 + 480 * 0.12 = 67.6.
      final square = CircularPhysicsEngine(
        arenaCenter: const Offset(100, 250),
        arenaRadius: 100,
        arenaWidth: 200,
        arenaHeight: 480,
        squareArena: true,
      );
      expect(square.dangerY, closeTo(67.6, 0.001));

      // Kâse arena: merkez - yarıçap + 2 * yarıçap * 0.12
      // → 300 - 150 + 300 * 0.12 = 186.
      final bowl = CircularPhysicsEngine(
        arenaCenter: const Offset(200, 300),
        arenaRadius: 150,
      );
      expect(bowl.dangerY, closeTo(186.0, 0.001));

      // 600x600 kare arenada dangerY = 0 + 600 * 0.12 = 72.
      final engine = squareEngine();
      expect(engine.dangerY, closeTo(72.0, 0.001));
      expect(engine.isOverflowing, isFalse);
      expect(engine.dangerProximity, 0.0);

      // Çizginin üstünde duran (sakin, olgun) cisim: taşma.
      final stillAbove = squareEngine()
        ..bodies.add(
          InsectBody(
            id: 1,
            tier: InsectTier.cone,
            x: 300,
            y: 72,
            spawnScale: 1.0,
          ),
        );
      expect(stillAbove.isOverflowing, isTrue);

      // Çizginin üstünde DÜŞEN cisim: taşma sayılmaz (hız filtresi).
      final fallingAbove = squareEngine()
        ..bodies.add(
          InsectBody(
            id: 1,
            tier: InsectTier.cone,
            x: 300,
            y: 72,
            prevY: 67.0,
            spawnScale: 1.0,
          ),
        );
      expect(fallingAbove.isOverflowing, isFalse);

      // Çizginin altında duran cisim: taşma yok.
      final stillBelow = squareEngine()
        ..bodies.add(
          InsectBody(
            id: 1,
            tier: InsectTier.cone,
            x: 300,
            y: 200,
            spawnScale: 1.0,
          ),
        );
      expect(stillBelow.isOverflowing, isFalse);

      // Yeni beliren (spawnScale < 0.8) cisim çizginin üstünde olsa da
      // taşma sayılmaz.
      final freshAbove = squareEngine()
        ..bodies.add(
          InsectBody(
            id: 1,
            tier: InsectTier.cone,
            x: 300,
            y: 72,
            spawnScale: 0.2,
          ),
        );
      expect(freshAbove.isOverflowing, isFalse);

      // Çizgiye yaklaşan sakin cisim yakınlık uyarısı üretir.
      final approaching = squareEngine()
        ..bodies.add(
          InsectBody(
            id: 1,
            tier: InsectTier.cone,
            x: 300,
            y: 105,
            spawnScale: 1.0,
          ),
        );
      expect(approaching.dangerProximity, greaterThan(0.5));
      expect(approaching.dangerProximity, lessThan(1.0));
    });

    test('akümülatör: eşik altı dt ilerletmez, bölünmüş dt birebir eşittir',
        () {
      // Eşik altı dt (1/120 sn ≈ 0.00833'ten küçük) hiç alt-adım atmaz.
      final idle = squareEngine();
      idle.addBody(InsectTier.cone, 300, 100);
      final before = snapshot(idle);
      idle.update(0.004);
      expect(snapshot(idle), equals(before));

      // 2 x 0.005 sn = tek 1/120 sn çağrısıyla aynı tek alt-adım.
      CircularPhysicsEngine singleDrop() {
        final engine = squareEngine();
        engine.addBody(InsectTier.cone, 300, 100);
        return engine;
      }

      final split = singleDrop();
      split.update(0.005);
      split.update(0.005);
      final whole = singleDrop();
      whole.update(1 / 120);
      expect(snapshot(split), equals(snapshot(whole)));

      // 1 x (1/60) = 2 x (1/120): ikisi de 2 alt-adım.
      final sixty = singleDrop();
      sixty.update(1 / 60);
      final twice = singleDrop();
      twice.update(1 / 120);
      twice.update(1 / 120);
      expect(snapshot(sixty), equals(snapshot(twice)));
    });

    test('60 Hz ve 120 Hz güncelleme örüntüleri aynı durumu verir', () {
      // Birleşmesiz senaryo: birleşim kilidi (_mergedThisFrame) her
      // update() çağrısında sıfırlanır, bu yüzden birleşimli senaryolarda
      // örüntü eşitliği beklenmez; tek düşen cisimde beklenir.
      CircularPhysicsEngine singleDrop() {
        final engine = squareEngine();
        engine.addBody(InsectTier.cone, 300, 100);
        return engine;
      }

      final at60 = singleDrop();
      for (var i = 0; i < 60; i++) {
        at60.update(1 / 60);
      }
      final at120 = singleDrop();
      for (var i = 0; i < 120; i++) {
        at120.update(1 / 120);
      }
      // İki örüntü de 120 alt-adım atar: durum birebir aynı olmalı.
      expect(snapshot(at60), equals(snapshot(at120)));
    });

    test('dt kıskaçları: negatif dt no-op, dev dt en fazla 3 alt-adım', () {
      final negative = squareEngine();
      negative.addBody(InsectTier.cone, 300, 100);
      final before = snapshot(negative);
      negative.update(-0.5);
      expect(snapshot(negative), equals(before));

      // update(1.0): dt 0.033'e kısılır, akümülatör 3 alt-adımda
      // sınırlanır → 3 x update(1/120) ile birebir aynı durum.
      CircularPhysicsEngine singleDrop() {
        final engine = squareEngine();
        engine.addBody(InsectTier.cone, 300, 100);
        return engine;
      }

      final huge = singleDrop();
      huge.update(1.0);
      final three = singleDrop();
      for (var i = 0; i < 3; i++) {
        three.update(1 / 120);
      }
      expect(snapshot(huge), equals(snapshot(three)));
    });

    test('birleşim kilidi: bir cisim tek update() çağrısında bir kez birleşir',
        () {
      final engine = squareEngine();
      for (var i = 0; i < 4; i++) {
        engine.addBody(InsectTier.cone, 300, 300);
      }

      // Tek update(1/60) = 2 alt-adım ama TEK kilit penceresi: 4 cone
      // 2 helmet'e iner; kilit kalkmadığı için fan oluşmaz.
      final events = engine.update(1 / 60);

      expect(events, hasLength(2));
      expect(events.every((e) => e.tier == InsectTier.helmet), isTrue);
      expect(engine.bodies, hasLength(2));
      expect(engine.bodies.every((b) => b.tier == InsectTier.helmet), isTrue);

      // Bir sonraki çağrıda kilit kalkar ama ayrışma savrulması çifti
      // temas mesafesinin dışına ittiği için zincirleme birleşme olmaz.
      final moreEvents = engine.update(1 / 120);
      expect(moreEvents, isEmpty);
      expect(engine.bodies, hasLength(2));
      expect(engine.bodies.every((b) => b.tier == InsectTier.helmet), isTrue);
    });
  });
}
