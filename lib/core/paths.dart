import 'dart:math' as math;

import 'data.dart';

/// Ponto 3D simples (x, y = altura, z).
class P3 {
  final double x, y, z;
  const P3(this.x, this.y, this.z);
  P3 lerp(P3 o, double t) => P3(x + (o.x - x) * t, y + (o.y - y) * t, z + (o.z - z) * t);
  double dist(P3 o) => math.sqrt((o.x - x) * (o.x - x) + (o.y - y) * (o.y - y) + (o.z - z) * (o.z - z));
}

/// Pose: posição e direção (ângulo no plano xz; 0 = +z).
class Pose {
  final P3 p;
  final double heading;
  const Pose(this.p, this.heading);
}

/// Caminho poligonal percorrido por distância.
class Path3 {
  final List<P3> pts;
  late final List<double> acc;
  Path3(this.pts) {
    acc = [0];
    for (var i = 1; i < pts.length; i++) { acc.add(acc.last + pts[i - 1].dist(pts[i])); }
  }
  double get length => acc.last;
  Pose at(double d) {
    if (pts.length == 1) return Pose(pts[0], 0);
    d = d.clamp(0.0, length).toDouble();
    var i = 1;
    while (i < pts.length - 1 && acc[i] < d) { i++; }
    final a = pts[i - 1], b = pts[i], seg = acc[i] - acc[i - 1];
    final t = seg <= 1e-6 ? 1.0 : (d - acc[i - 1]) / seg;
    return Pose(a.lerp(b, t), math.atan2(b.x - a.x, b.z - a.z));
  }
}

/// Rotas dos aviões para cada portão.
class Routes {
  static double parkZ(int tier) => Lay.standNose - planeTypes[tier].len / 2;
  static Path3 landing() => Path3([
        const P3(Lay.runwayX0 - 80, 16, Lay.runwayZ),
        const P3(Lay.runwayX0 + 12, 0, Lay.runwayZ),
        const P3(Lay.connR, 0, Lay.runwayZ),
      ]);
  static Path3 taxiIn(int gate, int tier) {
    final gx = Lay.gates[gate];
    return Path3([
      const P3(Lay.connR, 0, Lay.runwayZ),
      const P3(Lay.connR, 0, Lay.laneZ),
      P3(gx, 0, Lay.laneZ),
      P3(gx, 0, parkZ(tier)),
    ]);
  }
  static Path3 pushback(int gate, int tier) {
    final gx = Lay.gates[gate];
    return Path3([P3(gx, 0, parkZ(tier)), P3(gx, 0, Lay.laneZ)]);
  }
  static Path3 taxiOut(int gate) {
    final gx = Lay.gates[gate];
    return Path3([P3(gx, 0, Lay.laneZ), const P3(Lay.connL, 0, Lay.laneZ), const P3(Lay.connL, 0, Lay.holdZ)]);
  }
  /// Decolagem: entra na pista, acelera e sobe. Sai do chão em [liftoffAt].
  static final Path3 takeoff = Path3([
    const P3(Lay.connL, 0, Lay.holdZ),
    const P3(Lay.connL, 0, Lay.runwayZ),
    const P3(Lay.connL + 50, 0, Lay.runwayZ),
    const P3(Lay.connL + 110, 16, Lay.runwayZ),
    const P3(Lay.connL + 230, 52, Lay.runwayZ),
  ]);
  static final double liftoffAt = takeoff.acc[2];
  static final Path3 landingPath = landing();
  static double taxiInLen(int gate, int tier) => taxiIn(gate, tier).length;
  static double taxiOutLen(int gate) => taxiOut(gate).length;
}
