import 'dart:math' as math;
import 'dart:ui';

Offset limitSpeed(Offset velocity, double maximum) {
  final speed = velocity.distance;
  return speed > maximum ? velocity * (maximum / speed) : velocity;
}

class GravityBody {
  GravityBody(this.size, {this.mass = 1});

  Size size;
  final double mass;
  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
  bool held = false;

  Rect get rect => position & size;
  double get inverseMass => held ? 0 : 1 / mass;
}

/// Small axis-aligned rigid bodies, simulated at a fixed 120 Hz.
class GravitySimulation {
  static const _step = 1 / 120;
  static const _gravity = Offset(0, 1400);
  static const _restitution = 0.52;
  final List<GravityBody> bodies = [];
  Size bounds = Size.zero;
  double _accumulator = 0;

  void layout(Size newBounds, List<Size> sizes) {
    if (bodies.isEmpty) {
      bounds = newBounds;
      for (var i = 0; i < sizes.length; i++) {
        bodies.add(GravityBody(sizes[i], mass: i == 0 ? 3 : 1));
      }
      reset();
      return;
    }
    bounds = newBounds;
    for (var i = 0; i < bodies.length; i++) {
      bodies[i].size = sizes[i];
      contain(bodies[i]);
    }
  }

  void reset() {
    _accumulator = 0;
    for (var i = 0; i < bodies.length; i++) {
      final body = bodies[i];
      body.held = false;
      body.position = Offset(
        (bounds.width - body.size.width) * [0.5, 0.5, 0.92][i],
        (bounds.height - body.size.height) * [0.18, 0.5, 0.74][i],
      );
      body.velocity = Offset([-45.0, 36.0, -90.0][i], 0);
      contain(body);
    }
  }

  void applyImpulse(Offset impulse) {
    for (final body in bodies) {
      if (!body.held) {
        body.velocity = limitSpeed(body.velocity + impulse, 2400);
      }
    }
  }

  void advance(double elapsedSeconds) {
    if (bounds.isEmpty || elapsedSeconds <= 0) return;
    // Avoid tunnelling and large jumps after a suspended/backgrounded frame.
    _accumulator += elapsedSeconds.clamp(0, 0.05);
    while (_accumulator >= _step) {
      _accumulator -= _step;
      for (final body in bodies) {
        if (body.held) continue;
        body.velocity =
            (body.velocity + _gravity * _step) * math.exp(-0.45 * _step);
        body.position += body.velocity * _step;
        contain(body);
      }
      // Multiple passes let stacked bodies settle without sinking together.
      for (var pass = 0; pass < 8; pass++) {
        for (var a = 0; a < bodies.length; a++) {
          for (var b = a + 1; b < bodies.length; b++) {
            _collide(bodies[a], bodies[b]);
          }
        }
        for (final body in bodies) {
          contain(body);
        }
      }
      for (final body in bodies) {
        if (!body.held && body.rect.bottom >= bounds.height) {
          body.velocity = Offset(
            body.velocity.dx * math.exp(-5 * _step),
            body.velocity.dy,
          );
        }
      }
    }
  }

  void contain(GravityBody body) {
    final maxX = math.max(0.0, bounds.width - body.size.width);
    final maxY = math.max(0.0, bounds.height - body.size.height);
    var vx = body.velocity.dx;
    var vy = body.velocity.dy;
    if ((body.position.dx < 0 && vx < 0) ||
        (body.position.dx > maxX && vx > 0)) {
      vx = vx.abs() < 55 ? 0 : -vx * _restitution;
    }
    if ((body.position.dy < 0 && vy < 0) ||
        (body.position.dy > maxY && vy > 0)) {
      vy = vy.abs() < 55 ? 0 : -vy * _restitution;
    }
    body.position = Offset(
      body.position.dx.clamp(0, maxX),
      body.position.dy.clamp(0, maxY),
    );
    body.velocity = Offset(vx, vy);
  }

  void _collide(GravityBody a, GravityBody b) {
    final overlapX =
        math.min(a.rect.right, b.rect.right) -
        math.max(a.rect.left, b.rect.left);
    final overlapY =
        math.min(a.rect.bottom, b.rect.bottom) -
        math.max(a.rect.top, b.rect.top);
    final inverseMass = a.inverseMass + b.inverseMass;
    if (overlapX <= 0 || overlapY <= 0 || inverseMass == 0) return;

    final horizontal = overlapX < overlapY;
    final normal = horizontal
        ? Offset(a.rect.center.dx < b.rect.center.dx ? 1 : -1, 0)
        : Offset(0, a.rect.center.dy < b.rect.center.dy ? 1 : -1);
    final penetration = horizontal ? overlapX : overlapY;
    final correction = normal * (penetration / inverseMass);
    a.position -= correction * a.inverseMass;
    b.position += correction * b.inverseMass;

    final relative = b.velocity - a.velocity;
    final closingSpeed = relative.dx * normal.dx + relative.dy * normal.dy;
    if (closingSpeed >= 0) return;
    final bounce = closingSpeed.abs() < 55 ? 0.0 : _restitution;
    final impulse = normal * (-(1 + bounce) * closingSpeed / inverseMass);
    a.velocity -= impulse * a.inverseMass;
    b.velocity += impulse * b.inverseMass;
  }
}

/// Converts screen-space window acceleration into opposite body impulses.
class WindowMotion {
  Offset? _lastPosition;
  double? _lastTime;
  Offset _velocity = Offset.zero;

  Offset sample(Offset position, double time) {
    final previousPosition = _lastPosition;
    final previousTime = _lastTime;
    _lastPosition = position;
    _lastTime = time;
    if (previousPosition == null || previousTime == null) return Offset.zero;
    final dt = time - previousTime;
    if (dt <= 0 || dt > 0.25) {
      _velocity = Offset.zero;
      return Offset.zero;
    }
    final measured = limitSpeed((position - previousPosition) / dt, 2400);
    // Filter noisy OS samples; stationary tail samples also model the stop.
    var next = Offset.lerp(_velocity, measured, 1 - math.exp(-dt / 0.045))!;
    if (next.distance < 1 && measured == Offset.zero) next = Offset.zero;
    final impulse = _velocity - next;
    _velocity = next;
    return impulse;
  }
}
