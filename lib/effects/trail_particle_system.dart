import 'dart:math' as math;
import 'package:flutter/material.dart';

enum ParticleType { dirt, smoke, spark, fire }

class TrailParticle {
  double x, y, vx, vy, life, maxLife, size;
  Color color;
  ParticleType type;

  TrailParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.maxLife,
    required this.size,
    required this.color,
    required this.type,
  }) : life = maxLife;
}

class TrailParticleSystem {
  final List<TrailParticle> particles = [];
  final math.Random _rnd = math.Random();

  void emitRoost({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required Color color,
    int count = 3,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = math.pi + (_rnd.nextDouble() - 0.5) * 0.7;
      final speed = 80.0 + _rnd.nextDouble() * 220.0;
      final pvx = vx * 0.15 + math.cos(angle) * speed;
      final pvy = -40.0 - _rnd.nextDouble() * 120.0;
      final size = 2.5 + _rnd.nextDouble() * 4.0;
      particles.add(TrailParticle(
        x: x + (_rnd.nextDouble() - 0.5) * 6,
        y: y + (_rnd.nextDouble() - 0.5) * 4,
        vx: pvx,
        vy: pvy,
        maxLife: 0.4 + _rnd.nextDouble() * 0.45,
        size: size,
        color: color,
        type: ParticleType.dirt,
      ));
    }
    _trim();
  }

  void emitBurnout({
    required double x,
    required double y,
    int count = 2,
  }) {
    for (var i = 0; i < count; i++) {
      particles.add(TrailParticle(
        x: x + (_rnd.nextDouble() - 0.5) * 10,
        y: y + (_rnd.nextDouble() - 0.5) * 4,
        vx: (_rnd.nextDouble() - 0.5) * 40.0,
        vy: -20.0 - _rnd.nextDouble() * 50.0,
        maxLife: 0.6 + _rnd.nextDouble() * 0.5,
        size: 5.0 + _rnd.nextDouble() * 6.0,
        color: const Color(0xCCECEFF1),
        type: ParticleType.smoke,
      ));
    }
    _trim();
  }

  void emitLandingShockwave({
    required double x,
    required double y,
    required Color color,
    int count = 16,
  }) {
    for (var i = 0; i < count; i++) {
      final dir = (i % 2 == 0) ? 1.0 : -1.0;
      final speed = 70.0 + _rnd.nextDouble() * 150.0;
      particles.add(TrailParticle(
        x: x,
        y: y,
        vx: dir * speed + (_rnd.nextDouble() - 0.5) * 30,
        vy: -30.0 - _rnd.nextDouble() * 80,
        maxLife: 0.5 + _rnd.nextDouble() * 0.4,
        size: 4.0 + _rnd.nextDouble() * 4.5,
        color: color,
        type: ParticleType.dirt,
      ));
    }
    _trim();
  }

  void emitSparks({
    required double x,
    required double y,
    required double vx,
    int count = 6,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = -math.pi * 0.6 + (_rnd.nextDouble() - 0.5) * 1.2;
      final speed = 120.0 + _rnd.nextDouble() * 260.0;
      particles.add(TrailParticle(
        x: x,
        y: y,
        vx: vx * 0.4 + math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        maxLife: 0.25 + _rnd.nextDouble() * 0.35,
        size: 2.0 + _rnd.nextDouble() * 2.0,
        color: _rnd.nextBool() ? const Color(0xFFFFD54F) : const Color(0xFFFF6D00),
        type: ParticleType.spark,
      ));
    }
    _trim();
  }

  void emitTurboFlame({
    required double x,
    required double y,
    required double dirX,
    required double dirY,
    int count = 4,
  }) {
    for (var i = 0; i < count; i++) {
      final speed = 180.0 + _rnd.nextDouble() * 160.0;
      final jitterX = (_rnd.nextDouble() - 0.5) * 30.0;
      final jitterY = (_rnd.nextDouble() - 0.5) * 30.0;
      final isCyan = _rnd.nextDouble() < 0.3;
      particles.add(TrailParticle(
        x: x,
        y: y,
        vx: dirX * speed + jitterX,
        vy: dirY * speed + jitterY,
        maxLife: 0.18 + _rnd.nextDouble() * 0.18,
        size: 3.5 + _rnd.nextDouble() * 5.0,
        color: isCyan ? const Color(0xFF00E5FF) : (_rnd.nextBool() ? const Color(0xFFFF9100) : const Color(0xFFFF3D00)),
        type: ParticleType.fire,
      ));
    }
    _trim();
  }

  void emitGenericBurst({
    required double x,
    required double y,
    required int count,
    required Color color,
    required double speed,
  }) {
    for (var i = 0; i < count; i++) {
      final a = _rnd.nextDouble() * 2 * math.pi;
      final s = speed * (0.3 + _rnd.nextDouble());
      particles.add(TrailParticle(
        x: x,
        y: y,
        vx: math.cos(a) * s,
        vy: math.sin(a) * s - 40,
        maxLife: 0.4 + _rnd.nextDouble() * 0.45,
        size: 3.0 + _rnd.nextDouble() * 4.0,
        color: color,
        type: ParticleType.dirt,
      ));
    }
    _trim();
  }

  void update(double dt) {
    for (final p in particles) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;

      switch (p.type) {
        case ParticleType.dirt:
          p.vy += 380.0 * dt; // gravidade na terra
          p.vx *= math.exp(-1.4 * dt);
          break;
        case ParticleType.smoke:
          p.vy -= 15.0 * dt; // fumaça sobe
          p.vx *= math.exp(-2.2 * dt);
          p.size += 14.0 * dt; // expande
          break;
        case ParticleType.spark:
          p.vy += 500.0 * dt;
          p.vx *= math.exp(-1.8 * dt);
          break;
        case ParticleType.fire:
          p.vx *= math.exp(-3.5 * dt);
          p.vy *= math.exp(-3.5 * dt);
          p.size += 8.0 * dt;
          break;
      }
    }
    particles.removeWhere((p) => p.life <= 0);
  }

  void render(Canvas canvas, double camX, double camY) {
    for (final p in particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      final alpha = (t * 220).round();
      final paint = Paint()..color = p.color.withAlpha(alpha);

      final screenPos = Offset(p.x - camX, p.y - camY);
      if (p.type == ParticleType.spark) {
        paint.strokeWidth = p.size;
        paint.strokeCap = StrokeCap.round;
        canvas.drawLine(
          screenPos,
          Offset(screenPos.dx - p.vx * 0.02, screenPos.dy - p.vy * 0.02),
          paint,
        );
      } else {
        canvas.drawCircle(screenPos, p.size * (0.8 + (1 - t) * 0.4), paint);
      }
    }
  }

  void _trim() {
    if (particles.length > 350) {
      particles.removeRange(0, particles.length - 350);
    }
  }

  void clear() {
    particles.clear();
  }
}
