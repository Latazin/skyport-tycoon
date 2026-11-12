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
  /// Mesmo caminho com as quinas arredondadas (curvas suaves para os aviões).
  factory Path3.round(List<P3> raw, double radius) {
    if (raw.length < 3) return Path3(raw);
    final out = <P3>[raw.first];
    for (var i = 1; i < raw.length - 1; i++) {
      final a = raw[i - 1], b = raw[i], c = raw[i + 1];
      final la = a.dist(b), lc = b.dist(c);
      final r = math.min(radius, math.min(la, lc) * 0.45);
      if (r < 0.2) { out.add(b); continue; }
      final p0 = b.lerp(a, r / la), p2 = b.lerp(c, r / lc);
      for (var k = 0; k <= 8; k++) {
        final t = k / 8, u = 1 - t;
        out.add(P3(u * u * p0.x + 2 * u * t * b.x + t * t * p2.x, u * u * p0.y + 2 * u * t * b.y + t * t * p2.y, u * u * p0.z + 2 * u * t * b.z + t * t * p2.z));
      }
    }
    out.add(raw.last);
    return Path3(out);
  }
  double get length => acc.last;
  Pose at(double d) {
    if (pts.length == 1) return Pose(pts[0], 0);
    d = d.clamp(0.0, length).toDouble();
    var lo = 1, hi = pts.length - 1;
    while (lo < hi) { final m = (lo + hi) >> 1; if (acc[m] < d) { lo = m + 1; } else { hi = m; } }
    final i = lo;
    final a = pts[i - 1], b = pts[i], seg = acc[i] - acc[i - 1];
    final t = seg <= 1e-6 ? 1.0 : (d - acc[i - 1]) / seg;
    return Pose(a.lerp(b, t), math.atan2(b.x - a.x, b.z - a.z));
  }
}

/// Rotas dos aviões para cada portão (dependem da fase do aeroporto).
class Routes {
  static double parkZ(int tier) => Lay.standNose - planeTypes[tier].len / 2;
  static final Map<String, Path3> _c = {};
  static Path3 _k(String k, Path3 Function() f) => _c[k] ??= f();
  static double connR(int ph) => phases[ph].connR;
  static Path3 landing(int ph) => _k('ld$ph', () => Path3([
        const P3(Lay.runwayX0 - 80, 16, Lay.runwayZ),
        const P3(Lay.runwayX0 + 12, 0, Lay.runwayZ),
        P3(connR(ph) - 4, 0, Lay.runwayZ),
      ]));
  static Path3 taxiIn(int gate, int tier, int ph) => _k('in$gate$tier$ph', () {
        final gx = Lay.gates[gate], cr = connR(ph);
        return Path3.round([
          P3(cr - 4, 0, Lay.runwayZ),
          P3(cr, 0, Lay.runwayZ),
          P3(cr, 0, Lay.laneZ),
          P3(gx, 0, Lay.laneZ),
          P3(gx, 0, parkZ(tier)),
        ], 3.2);
      });
  static Path3 pushback(int gate, int tier) => _k('pb$gate$tier', () { final gx = Lay.gates[gate]; return Path3([P3(gx, 0, parkZ(tier)), P3(gx, 0, Lay.laneZ)]); });
  static Path3 taxiOut(int gate, int ph) => _k('out$gate', () {
        final gx = Lay.gates[gate];
        return Path3.round([P3(gx, 0, Lay.laneZ), const P3(Lay.connL, 0, Lay.laneZ), const P3(Lay.connL, 0, Lay.holdZ)], 3.2);
      });
  /// Decolagem: entra na pista, acelera e sobe. Sai do chão em [liftoffAt].
  static final Path3 takeoff = Path3.round([
    const P3(Lay.connL, 0, Lay.holdZ),
    const P3(Lay.connL, 0, Lay.runwayZ),
    const P3(Lay.connL + 50, 0, Lay.runwayZ),
    const P3(Lay.connL + 110, 16, Lay.runwayZ),
    const P3(Lay.connL + 230, 52, Lay.runwayZ),
  ], 3.0);
  static final double liftoffAt = takeoff.acc[takeoff.pts.indexWhere((p) => p.x >= Lay.connL + 50 - 1e-6)];
  static double taxiInLen(int gate, int tier, int ph) => taxiIn(gate, tier, ph).length;
  static double taxiOutLen(int gate, int ph) => taxiOut(gate, ph).length;
}
