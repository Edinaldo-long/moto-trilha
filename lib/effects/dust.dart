import 'package:flutter/material.dart';

/// Partícula (poeira, brilho de moeda, explosão).
class Dust {
  double x, y, vx, vy, life;
  final double maxLife, size;
  final Color color;

  Dust(this.x, this.y, this.vx, this.vy, this.maxLife, this.size, this.color)
      : life = maxLife;
}
