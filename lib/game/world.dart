import 'dart:math' as math;
import 'dart:ui';

import '../core/data.dart';
import '../core/paths.dart';
import '../core/state.dart';

const double S = 24;

/// Projeção isométrica (igual ao estúdio): mundo (x, z, altura y) -> pixels do mundo.
Offset iso(double x, double z, [double y = 0]) => Offset((x - z) * 0.70710678 * S, ((x + z) * 0.35355339 - y * 0.8660254) * S);
/// Inversa no chão (y = 0).
(double, double) toGround(double u, double v) { final a = u / (0.70710678 * S), b = v / (0.35355339 * S); return ((a + b) / 2, (b - a) / 2); }

/// Passageiro visual (cosmético, segue o ritmo real das estações).
class Agent {
  double x, z, speed;
  final int c;
  bool bag = true, shop;
  int stage = 0, desk = -1, lane = -1, gate = -1;
  double wait = 0, anim = 0, fade = 1, hx = 1, hz = 0;
  bool moving = false;
  List<(double, double)> path = [];
  Agent(this.x, this.z, this.c, this.speed, this.shop);
}

class Vehicle {
  String kind;
  double x, z, speed, wait = 0, hx = 1, hz = 0;
  List<(double, double)> path;
  int tag;
  Vehicle(this.kind, this.x, this.z, this.speed, this.path, [this.tag = 0]);
}

class Floater {
  final double x, z, y0;
  final String text;
  final Color color;
  double t = 0;
  final double big;
  Floater(this.x, this.z, this.y0, this.text, this.color, [this.big = 1]);
}

class Spark { double x, z, y, vx, vz, vy, t = 0; final Color c; Spark(this.x, this.z, this.y, this.vx, this.vz, this.vy, this.c); }

/// Mundo visual: passageiros, veículos, efeitos e poses dos aviões.
class AirWorld {
  final GameState s;
  AirWorld(this.s);
  final r = math.Random();
  final List<Agent> agents = [];
  final List<Vehicle> vehicles = [];
  final List<Floater> floaters = [];
  final List<Spark> sparks = [];
  final List<List<Agent>> deskQ = List.generate(6, (_) => []);
  final List<List<Agent>> laneQ = List.generate(4, (_) => []);
  final List<double> deskSvc = List.filled(6, 0), laneSvc = List.filled(4, 0);
  double t = 0, _spawnT = 0, _busT = 4, _carT = 1, _tugT = 3;
  int maxAgents = 46;
  final Map<String, double> bump = {}; // estação -> tempo do "pulo" de melhoria

  // ---------- geometria das estações ----------
  int get desks => desksFor(s.lvl('checkin'));
  int get lanes => lanesFor(s.lvl('seguranca'));
  (double, double) deskPos(int d) => (Lay.checkinX0 + d * Lay.checkinDx, Lay.checkinZ);
  (double, double) lanePos(int l) => (Lay.secX0 + l * Lay.secDx, Lay.secZ);
  (double, double) deskSlot(int d, int i) { final p = deskPos(d); return (p.$1 - 0.05, p.$2 + 1.15 + i * 0.72); }
  (double, double) laneSlot(int l, int i) { final p = lanePos(l); return (p.$1 + 0.75, p.$2 + 1.4 + i * 0.72); }

  // ---------- passageiros ----------
  double get _visRate {
    final thr = math.max(0.05, math.min(s.lambda, s.throughput * 1.6));
    return (0.35 + math.log(1 + thr) * 0.22).clamp(0.35, 1.5).toDouble();
  }
  double _svc(double mu, int servers) {
    final v = _visRate, ratio = s.lambda <= 0 ? 1.0 : mu / s.lambda;
    return (servers / (v * ratio)).clamp(0.5, 7.0).toDouble();
  }

  void spawnAt(double x, double z) {
    if (agents.length >= maxAgents) return;
    final a = Agent(x, z, r.nextInt(8), 1.8 + r.nextDouble() * 0.7, s.built('lojas') && r.nextDouble() < 0.55);
    agents.add(a);
    _toCheckin(a);
  }
  void _toCheckin(Agent a) {
    var best = 0; var bl = 1 << 30;
    for (var d = 0; d < desks; d++) { if (deskQ[d].length < bl) { bl = deskQ[d].length; best = d; } }
    a.desk = best; a.stage = 1; deskQ[best].add(a);
    final door = Lay.door;
    a.path = [(door.$1 + r.nextDouble() * 2 - 1, door.$2 - 0.6), (deskSlot(best, 6).$1, 12.4)];
  }
  void _toSecurity(Agent a) {
    var best = 0; var bl = 1 << 30;
    for (var l = 0; l < lanes; l++) { if (laneQ[l].length < bl) { bl = laneQ[l].length; best = l; } }
    a.lane = best; a.stage = 3; laneQ[best].add(a);
    final dp = deskPos(a.desk);
    a.path = [(dp.$1 + 1.1, dp.$2 + 1.4), (dp.$1 + 1.1, 12.6), (laneSlot(best, 7).$1, 12.6)];
  }
  void _afterSecurity(Agent a) {
    final lp = lanePos(a.lane);
    a.path = [(lp.$1 + 0.75, lp.$2 - 2.7)];
    final shops = shopsFor(s.lvl('lojas'));
    if (a.shop && shops > 0) {
      final sh = Lay.shops[r.nextInt(shops)];
      a.stage = 5; a.wait = 1.4 + r.nextDouble() * 2;
      a.path.addAll([(lp.$1 + 0.75, 1.2), (sh.$1 + r.nextDouble() * 1.6 - 0.8, sh.$2 + 2.0)]);
    } else {
      _toGate(a, [(lp.$1 + 0.75, lp.$2 - 2.7), (lp.$1 + 0.75, 1.2)]);
    }
  }
  void _toGate(Agent a, [List<(double, double)> prefix = const []]) {
    final open = [for (var g = 0; g < 6; g++) if (s.built('g$g')) g];
    // prefere portões com avião chegando ou embarcando
    final soon = open.where((g) { final p = s.gates[g].phase; return p >= Ph.landing && p <= Ph.boarding; }).toList();
    final g = (soon.isNotEmpty && r.nextDouble() < 0.75 ? soon : open)[r.nextInt((soon.isNotEmpty ? soon : open).length)];
    a.gate = g; a.stage = 6;
    final gx = Lay.gates[g];
    a.path = [...prefix, (gx + r.nextDouble() * 3.4 - 1.2, -0.6 + r.nextDouble() * 1.9)];
  }
  void _board(Agent a) {
    final gx = Lay.gates[a.gate];
    a.stage = 7;
    a.path = [(gx + 2.0, -3.4), (gx + 3.2, -4.6)];
  }

  bool _walk(Agent a, double dt) {
    if (a.path.isEmpty) { a.moving = false; return true; }
    final tgt = a.path.first;
    final dx = tgt.$1 - a.x, dz = tgt.$2 - a.z, d = math.sqrt(dx * dx + dz * dz);
    final step = a.speed * dt;
    if (d <= step) { a.x = tgt.$1; a.z = tgt.$2; a.path.removeAt(0); }
    else { a.x += dx / d * step; a.z += dz / d * step; }
    a.moving = d > 0.03;
    if (a.moving) { a.hx = dx / d; a.hz = dz / d; a.anim += dt * a.speed * 2.6; }
    return a.path.isEmpty;
  }

  void _agentsTick(double dt) {
    // filas: cada um anda até sua vaga
    for (var d = 0; d < 6; d++) {
      final q = deskQ[d];
      for (var i = 0; i < q.length; i++) {
        final a = q[i];
        if (a.stage == 1 && a.path.length <= 1) { a.stage = 2; }
        if (a.stage == 2) { final sl = deskSlot(d, i); a.path = [sl]; }
      }
      if (q.isNotEmpty && q.first.stage == 2 && q.first.path.isEmpty) {
        deskSvc[d] += dt;
        if (deskSvc[d] > _svc(s.muC, desks)) { deskSvc[d] = 0; final a = q.removeAt(0); a.bag = false; _toSecurity(a); }
      }
    }
    for (var l = 0; l < 4; l++) {
      final q = laneQ[l];
      for (var i = 0; i < q.length; i++) {
        final a = q[i];
        if (a.stage == 3 && a.path.length <= 1) { a.stage = 4; }
        if (a.stage == 4) { final sl = laneSlot(l, i); a.path = [sl]; }
      }
      if (q.isNotEmpty && q.first.stage == 4 && q.first.path.isEmpty) {
        laneSvc[l] += dt;
        if (laneSvc[l] > _svc(s.muS, lanes)) { laneSvc[l] = 0; final a = q.removeAt(0); a.stage = 41; _afterSecurity(a); }
      }
    }
    for (final a in [...agents]) {
      // filas desfeitas (balcão/faixa fechou com nível menor) não acontecem; só garante limites
      if (a.stage == 1 && a.desk >= desks) { deskQ[a.desk].remove(a); _toCheckin(a); }
      final arrived = _walk(a, dt);
      if (!arrived) continue;
      switch (a.stage) {
        case 41: _toGate(a); break;
        case 5:
          a.wait -= dt;
          if (a.wait <= 0) {
            if (r.nextDouble() < 0.5) floaters.add(Floater(a.x, a.z, 2.2, '+\$', const Color(0xFFFFE27A), 0.7));
            _toGate(a);
          }
          break;
        case 6:
          final ph = s.gates[a.gate].phase;
          if (!s.built('g${a.gate}')) { _toGate(a); break; }
          if (ph == Ph.boarding) { _board(a); }
          break;
        case 7:
          a.fade -= dt * 3;
          if (a.fade <= 0) agents.remove(a);
          break;
      }
    }
    // excesso: os que esperam demais no portão somem (avião cheio)
    if (agents.length > maxAgents) {
      final w = agents.where((a) => a.stage == 6).toList();
      if (w.isNotEmpty) { final a = w.first; a.stage = 7; a.path = []; }
    }
  }

  // ---------- veículos ----------
  void _vehiclesTick(double dt) {
    _busT -= dt; _carT -= dt; _tugT -= dt;
    final el = s.lvl('entrada');
    if (_busT <= 0) {
      _busT = math.max(9, 26 - el * 0.25) + r.nextDouble() * 6;
      vehicles.add(Vehicle('bus', -100.0, 18.6, 9.0, [(Lay.busStop.$1 + 1, 18.6), (110.0, 18.6)]));
    }
    if (_carT <= 0) {
      _carT = math.max(1.2, 5 - el * 0.05) + r.nextDouble() * 3;
      final dir = r.nextBool();
      vehicles.add(Vehicle(r.nextDouble() < 0.25 ? 'taxi' : 'car', dir ? -100.0 : 110.0, dir ? 18.9 : 21.4, 11 + r.nextDouble() * 4, [(dir ? 110.0 : -100.0, dir ? 18.9 : 21.4)], r.nextInt(6)));
    }
    if (_tugT <= 0 && s.gatesOpen >= 2 && vehicles.where((v) => v.kind == 'tug').length < 2) {
      _tugT = 8 + r.nextDouble() * 8;
      final open = [for (var g = 0; g < 6; g++) if (s.built('g$g')) g];
      final a = Lay.gates[open[r.nextInt(open.length)]], b = Lay.gates[open[r.nextInt(open.length)]];
      vehicles.add(Vehicle('tug', a + 4.6, -10.0, 5.0, [(a + 4.6, -23.0), (b + 4.6, -23.0), (b + 4.6, -10.0), (b + 4.6, -10.01)]));
    }
    if (_tugT <= 0 && s.built('combustivel') && !vehicles.any((v) => v.kind == 'fuel')) {
      final open = [for (var g = 0; g < 6; g++) if (s.built('g$g')) g];
      final b = Lay.gates[open[r.nextInt(open.length)]];
      vehicles.add(Vehicle('fuel', Lay.fuel.$1 - 5, -23.0, 6.0, [(b + 4.6, -23.0), (b + 4.6, -12.0), (b + 4.6, -23.0), (Lay.fuel.$1 - 5, -23.0)]));
    }
    for (final v in [...vehicles]) {
      if (v.wait > 0) { v.wait -= dt; continue; }
      if (v.path.isEmpty) { vehicles.remove(v); continue; }
      final tg = v.path.first;
      final dx = tg.$1 - v.x, dz = tg.$2 - v.z, d = math.sqrt(dx * dx + dz * dz), st = v.speed * dt;
      if (d > 0.01) { v.hx = dx / d; v.hz = dz / d; }
      if (d <= st) {
        v.x = tg.$1; v.z = tg.$2; v.path.removeAt(0);
        if (v.kind == 'bus' && v.path.length == 1) { v.wait = 2.5; final n = 2 + r.nextInt(3 + math.min(4, el ~/ 20)); for (var i = 0; i < n; i++) { Future.delayed(Duration(milliseconds: 300 * i), () => spawnAt(Lay.busStop.$1 + r.nextDouble() * 2, Lay.busStop.$2 - 1.2)); } }
        if ((v.kind == 'tug' || v.kind == 'fuel') && v.path.length == 1) v.wait = 3;
      } else { v.x += dx / d * st; v.z += dz / d * st; }
    }
  }

  // ---------- aviões ----------
  final Map<String, Path3> _pc = {};
  Path3 _p(String k, Path3 Function() f) => _pc[k] ??= f();
  /// Pose do avião do portão g (nulo se não há avião).
  Pose? planePose(int g) {
    final G = s.gates[g];
    final k = G.k;
    switch (G.phase) {
      case Ph.landing:
        final p = Routes.landingPath; final u = 1 - (1 - k) * (1 - k);
        return p.at(p.length * (0.15 * k + 0.85 * u));
      case Ph.taxiIn:
        final p = _p('in$g${G.tier}', () => Routes.taxiIn(g, G.tier));
        return p.at(p.length * _smooth(k));
      case Ph.boarding:
        return Pose(P3(Lay.gates[g], 0, Routes.parkZ(G.tier)), 0);
      case Ph.pushback:
        final p = _p('pb$g${G.tier}', () => Routes.pushback(g, G.tier));
        return Pose(p.at(p.length * _smooth(k)).p, 0);
      case Ph.taxiOut:
        final p = _p('out$g', () => Routes.taxiOut(g));
        final pose = p.at(p.length * _smooth(k));
        if (k < 0.08) return Pose(pose.p, -math.pi / 2 * (k / 0.08));
        return pose;
      case Ph.hold:
        return Pose(const P3(Lay.connL, 0, Lay.holdZ), math.pi);
      case Ph.takeoff:
        final p = Routes.takeoff;
        final d = p.length * math.pow(k, 1.7);
        final pose = p.at(d.toDouble());
        if (d < p.acc[1]) return pose;
        return Pose(pose.p, math.pi / 2);
    }
    return null;
  }
  double _smooth(double k) => k * k * (3 - 2 * k);

  // ---------- efeitos ----------
  void burst(double x, double z, double y, int n, List<Color> cols) {
    for (var i = 0; i < n; i++) {
      final a = r.nextDouble() * math.pi * 2, sp = 2 + r.nextDouble() * 4;
      sparks.add(Spark(x, z, y, math.cos(a) * sp, math.sin(a) * sp, 5 + r.nextDouble() * 6, cols[i % cols.length]));
    }
  }
  /// Centro visual de cada estação (x, z, altura do rótulo).
  (double, double, double) stationCenter(String id) {
    switch (id) {
      case 'entrada': return (Lay.parking.$1, Lay.parking.$2, 3.0);
      case 'checkin': return (Lay.checkinX0 + (math.max(desks, 3) - 1) * Lay.checkinDx / 2, Lay.checkinZ, 4.2);
      case 'seguranca': return (Lay.secX0 + (math.max(lanes, 2) - 1) * Lay.secDx / 2, Lay.secZ, 4.0);
      case 'lojas': return (6.5, 8.0, 4.4);
      case 'vip': return (Lay.vip.$1, Lay.vip.$2, 3.4);
      case 'pista': return (-10.0, Lay.runwayZ, 1.0);
      case 'torre': return (Lay.tower.$1, Lay.tower.$2, 6.0);
      case 'hangar': return (Lay.hangar.$1, Lay.hangar.$2, 7.0);
      case 'combustivel': return (Lay.fuel.$1, Lay.fuel.$2, 5.0);
    }
    if (id.startsWith('g')) { final g = int.parse(id.substring(1)); return (Lay.gates[g] - 1, -1.5, 4.2); }
    return (0.0, 0.0, 0.0);
  }
  void levelFx(String id) {
    final c = stationCenter(id);
    bump[id] = t;
    burst(c.$1, c.$2, c.$3 * 0.5, 22, const [Color(0xFFFFE27A), Color(0xFF3FD46B), Color(0xFFFFFFFF), Color(0xFF3E8BFF)]);
  }
  void flightFx(int g, double amount, String text) {
    final pose = planePose(g);
    final p = pose?.p ?? const P3(Lay.connL + 50, 3, Lay.runwayZ);
    floaters.add(Floater(p.x, p.z, p.y + 3, text, const Color(0xFFFFE27A), 1.4));
  }

  // ---------- passo ----------
  void update(double dt) {
    t += dt;
    _spawnT -= dt;
    if (_spawnT <= 0) {
      _spawnT = 1 / _visRate * (0.7 + r.nextDouble() * 0.6);
      if (r.nextDouble() < 0.7) spawnAt(Lay.parking.$1 + 10 + r.nextDouble() * 4, 23.5);
    }
    _agentsTick(dt);
    _vehiclesTick(dt);
    for (final f in [...floaters]) { f.t += dt; if (f.t > 1.6) floaters.remove(f); }
    for (final sp in [...sparks]) {
      sp.t += dt; sp.vy -= 16 * dt; sp.x += sp.vx * dt; sp.z += sp.vz * dt; sp.y = math.max(0.0, sp.y + sp.vy * dt);
      if (sp.t > 1.1) sparks.remove(sp);
    }
  }
}
