import 'dart:math' as math;
import 'bump.dart';

/// Terreno infinito gerado por senos + lombadas.
class Terrain {
  final double s1, s2, s3, amp;
  final List<Bump> bumps = [];

  Terrain(math.Random r, this.amp)
      : s1 = r.nextDouble() * 2000,
        s2 = r.nextDouble() * 2000,
        s3 = r.nextDouble() * 2000;

  /// Relevo base (começa plano e fica mais difícil com a distância).
  double base(double x) {
    final f = (x / 900).clamp(0.0, 1.0).toDouble();
    final d = (1 + (x / 12000).clamp(0.0, 1.0).toDouble()) * amp;
    return -f *
        (math.sin((x + s1) * 0.0040) * 70 * d +
            math.sin((x + s2) * 0.0115) * 30 * d +
            math.sin((x + s3) * 0.0300) * 5);
  }

  double bump(double x) {
    double b = 0;
    for (final k in bumps) {
      final t = (x - k.x) / k.w;
      if (t > -3 && t < 3) b -= k.h * math.exp(-t * t);
    }
    return b;
  }

  double y(double x) => base(x) + bump(x);

  double slope(double x) => (y(x + 1) - y(x - 1)) / 2;
}
