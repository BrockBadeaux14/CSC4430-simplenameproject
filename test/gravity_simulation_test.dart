import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:simplenameproject/gravity_simulation.dart';

void main() {
  GravitySimulation scene() => GravitySimulation()
    ..layout(const Size(800, 500), const [
      Size(480, 110),
      Size(88, 80),
      Size(56, 56),
    ]);

  void advance(GravitySimulation simulation, double seconds, [int fps = 60]) {
    for (var i = 0; i < seconds * fps; i++) {
      simulation.advance(1 / fps);
    }
  }

  test('gravity makes bodies fall, bounce, then settle inside the arena', () {
    final simulation = scene();
    final body = simulation.bodies.last;
    final startY = body.position.dy;
    advance(simulation, 0.1);
    expect(body.position.dy, greaterThan(startY));
    expect(body.velocity.dy, greaterThan(0));

    body.position = const Offset(720, 440);
    body.velocity = const Offset(0, 400);
    simulation.advance(1 / 60);
    expect(body.velocity.dy, lessThan(0));

    advance(simulation, 20);
    for (final body in simulation.bodies) {
      expect(body.rect.left, greaterThanOrEqualTo(0));
      expect(body.rect.right, lessThanOrEqualTo(800));
      expect(body.rect.bottom, lessThanOrEqualTo(500));
      expect(body.velocity.distance, lessThan(3));
    }
    for (var a = 0; a < simulation.bodies.length; a++) {
      for (var b = a + 1; b < simulation.bodies.length; b++) {
        final overlap = simulation.bodies[a].rect.intersect(
          simulation.bodies[b].rect,
        );
        expect(overlap.width <= 0 || overlap.height < 1, isTrue);
      }
    }
  });

  test('bodies transfer momentum on collision', () {
    final simulation = scene();
    final a = simulation.bodies[1];
    final b = simulation.bodies[2];
    a.position = const Offset(100, 50);
    b.position = const Offset(189, 50);
    a.velocity = const Offset(500, 0);
    b.velocity = Offset.zero;
    simulation.bodies.first.position = const Offset(0, 350);
    simulation.advance(1 / 120);
    expect(b.velocity.dx, greaterThan(100));
    expect(a.velocity.dx, lessThan(400));
    expect(a.rect.right, lessThanOrEqualTo(b.rect.left + 0.01));
  });

  test('physics is consistent at different rendering frame rates', () {
    final at30 = scene();
    final at120 = scene();
    advance(at30, 2, 30);
    advance(at120, 2, 120);
    for (var i = 0; i < at30.bodies.length; i++) {
      expect(
        (at30.bodies[i].position - at120.bodies[i].position).distance,
        lessThan(0.1),
      );
    }
  });

  test('resize and long frame gaps keep every body within reach', () {
    final simulation = scene();
    simulation.applyImpulse(const Offset(2000, -2000));
    simulation.advance(30);
    simulation.layout(const Size(320, 260), const [
      Size(288, 130),
      Size(88, 80),
      Size(56, 56),
    ]);
    advance(simulation, 3);
    for (final body in simulation.bodies) {
      expect(body.rect.left, greaterThanOrEqualTo(0));
      expect(body.rect.top, greaterThanOrEqualTo(0));
      expect(body.rect.right, lessThanOrEqualTo(320));
      expect(body.rect.bottom, lessThanOrEqualTo(260));
    }
  });

  test('held elements resist gravity and window impulses', () {
    final simulation = scene();
    final body = simulation.bodies.first..held = true;
    final initial = body.position;
    simulation.applyImpulse(const Offset(900, -900));
    advance(simulation, 0.2);
    expect(body.position, initial);
  });

  test('window acceleration and stopping produce opposite inertia', () {
    final motion = WindowMotion();
    expect(motion.sample(Offset.zero, 0), Offset.zero);
    final starting = motion.sample(const Offset(20, 10), 1 / 60);
    expect(starting.dx, lessThan(0));
    expect(starting.dy, lessThan(0));
    final stopping = motion.sample(const Offset(20, 10), 2 / 60);
    expect(stopping.dx, greaterThan(0));
    expect(stopping.dy, greaterThan(0));
    for (var i = 3; i < 40; i++) {
      motion.sample(const Offset(20, 10), i / 60);
    }
    expect(motion.sample(const Offset(20, 10), 40 / 60), Offset.zero);
    expect(motion.sample(const Offset(900, 900), 10), Offset.zero);
  });
}
