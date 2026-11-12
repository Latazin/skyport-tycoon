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

/// Etapas do passageiro visual.
class St8 { static const walkCheck = 0, queueCheck = 1, walkSec = 2, queueSec = 3, walkShop = 4, shopping = 5, walkGate = 6, waitGate = 7, boarding = 8; }

/// Passageiro visual (cosmético, segue o ritmo real das estações).
class Agent {
  double x, z, speed;
  final int c;
  bool bag = true, shop;
  int stage = St8.walkCheck, desk = -1, lane = -1, gate = -1, qi = -1;
  double wait = 0, anim = 0, fade = 1, hx = 1, hz = 0, waitQ = 0, emoT = 0, stuck = 0;
  String emo = '';
  bool moving = false;
  List<(double, double)> path = [];
  Agent(this.x, this.z, this.c, this.speed, this.shop);
}

class Cleaner { double x, z, hx = 1, hz = 0, anim = 0; (double, double) tgt; bool moving = true; double pause = 0; Cleaner(this.x, this.z, this.tgt); }

class Vehicle {
  String kind;
  double x, z, speed, wait = 0, hx = 1, hz = 0;
  List<(double, double)> path;
  Vehicle(this.kind, this.x, this.z, this.speed, this.path);
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
class Puff { final double x, z, s; double t = 0; Puff(this.x, this.z, this.s); }

/// Mundo visual: passageiros, veículos, efeitos e poses dos aviões.
class AirWorld {
  final GameState s;
  AirWorld(this.s);
  final r = math.Random();
  final List<Agent> agents = [];
  final List<Cleaner> cleaners = [];
  final List<Vehicle> vehicles = [];
  final List<Floater> floaters = [];
  final List<Spark> sparks = [];
  final List<Puff> puffs = [];
  final List<List<Agent>> deskQ = List.generate(8, (_) => []);
  final List<List<Agent>> laneQ = List.generate(6, (_) => []);
  final List<double> deskSvc = List.filled(8, 0), laneSvc = List.filled(6, 0);
  double t = 0, _spawnT = 0, _busT = 4, _carT = 1, _tugT = 3, served = 0;
  int maxAgents = 52;
  final Map<String, double> bump = {};

  // ---------- geometria ----------
  int get desks => desksFor(s.lvl('checkin'));
  int get lanes => lanesFor(s.lvl('seguranca'));
  (double, double) deskPos(int d) => (Lay.checkinX0 + d * Lay.checkinDx, Lay.checkinZ);
  (double, double) lanePos(int l) => (Lay.secX0 + l * Lay.secDx, Lay.secZ);
  (double, double) deskSlot(int d, int i) { final p = deskPos(d); return (p.$1 - 0.05 + (i > 4 ? (i.isOdd ? 0.35 : -0.35) : 0), p.$2 + 1.15 + math.min(i, 9) * 0.62); }
  (double, double) laneSlot(int l, int i) { final p = lanePos(l); return (p.$1 + 0.75, p.$2 + 1.5 + math.min(i, 9) * 0.62); }
  double deskProgress(int d) => deskQ[d].isEmpty ? 0 : (deskSvc[d] / _svcC()).clamp(0.0, 1.0).toDouble();
  double laneProgress(int l) => laneQ[l].isEmpty ? 0 : (laneSvc[l] / _svcS()).clamp(0.0, 1.0).toDouble();

  // ---------- ritmo ----------
  double get _visRate {
    final thr = math.max(0.05, math.min(s.lambda, s.throughput * 1.6));
    return (0.4 + math.log(1 + thr) * 0.25).clamp(0.4, 1.7).toDouble();
  }
  double _svc(double mu, int servers) {
    final v = _visRate, ratio = s.lambda <= 0 ? 1.0 : mu / s.lambda;
    return (servers / (v * ratio)).clamp(0.45, 6.0).toDouble();
  }
  double _svcC() => _svc(s.muC, desks);
  double _svcS() => _svc(s.muS, lanes);

  // ---------- passageiros ----------
  void spawnAt(double x, double z) {
    if (agents.length >= maxAgents) return;
    final a = Agent(x, z, r.nextInt(8), 1.9 + r.nextDouble() * 0.7, s.built('lojas') && r.nextDouble() < 0.55);
    agents.add(a);
    _toCheckin(a);
  }
  void spawnGroup(int n) { for (var i = 0; i < n; i++) { Future.delayed(Duration(milliseconds: 180 * i), () => spawnAt(Lay.busStop.$1 + r.nextDouble() * 3 - 1.5, Lay.busStop.$2 - 1)); } }
  int _shortest(List<List<Agent>> qs, int n) { var best = 0, bl = 1 << 30; for (var i = 0; i < n; i++) { if (qs[i].length < bl) { bl = qs[i].length; best = i; } } return best; }
  void _toCheckin(Agent a) {
    final d = _shortest(deskQ, desks);
    a.desk = d; a.stage = St8.walkCheck; a.qi = -1; deskQ[d].add(a);
    final door = Lay.door;
    a.path = [(door.$1 + r.nextDouble() * 2 - 1, door.$2 - 0.6), (deskSlot(d, 0).$1, 13.6)];
  }
  void _toSecurity(Agent a) {
    final l = _shortest(laneQ, lanes);
    a.lane = l; a.stage = St8.walkSec; a.qi = -1; a.waitQ = 0; laneQ[l].add(a);
    final dp = deskPos(a.desk);
    a.path = [(dp.$1 + 1.2, dp.$2 + 1.2), (dp.$1 + 1.2, 14.2), (laneSlot(l, 0).$1, 14.2)];
  }
  void _afterSecurity(Agent a) {
    final lp = lanePos(a.lane);
    final exit = [(lp.$1 + 0.75, lp.$2 - 2.7), (lp.$1 + 0.75, 1.0)];
    final shops = shopsFor(s.lvl('lojas'));
    if (a.shop && shops > 0) {
      final sh = Lay.shops[r.nextInt(shops)];
      a.stage = St8.walkShop; a.wait = 1.4 + r.nextDouble() * 2;
      a.path = [exit[0], (lp.$1 + 0.75, 2.2), (sh.$1 + r.nextDouble() * 1.6 - 0.8, sh.$2 + 2.1)];
    } else {
      _toGate(a, exit);
    }
  }
  void _toGate(Agent a, [List<(double, double)> prefix = const []]) {
    final open = [for (var g = 0; g < 6; g++) if (s.built('g$g')) g];
    final soon = open.where((g) { final p = s.gates[g].phase; return p >= Ph.landing && p <= Ph.boarding; }).toList();
    final pool = soon.isNotEmpty && r.nextDouble() < 0.8 ? soon : open;
    final g = pool[r.nextInt(pool.length)];
    a.gate = g; a.stage = St8.walkGate;
    final gx = Lay.gates[g];
    a.path = [...prefix, (a.x, 0.9), (gx + r.nextDouble() * 3.4 - 1.2, -0.7 + r.nextDouble() * 1.9)];
    if (prefix.isNotEmpty) a.path.removeAt(prefix.length);
  }
  void _board(Agent a) {
    final gx = Lay.gates[a.gate];
    a.stage = St8.boarding;
    a.path = [(gx + 2.0, -3.4), (gx + 3.2, -4.6)];
    if (r.nextDouble() < 0.3) { a.emo = '😍'; a.emoT = 1.6; }
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
  double _dist(Agent a, (double, double) p) => math.sqrt((a.x - p.$1) * (a.x - p.$1) + (a.z - p.$2) * (a.z - p.$2));

  /// Avança uma fila: cada um vai à sua vaga; o primeiro é atendido quando chega.
  void _queue(List<Agent> q, int waitStage, int qStage, (double, double) Function(int) slot, List<double> svc, int idx, double svcTime, void Function(Agent) done, double dt) {
    for (var i = 0; i < q.length; i++) {
      final a = q[i];
      if (a.stage == waitStage && a.path.length <= 1) { a.stage = qStage; a.qi = -1; }
      if (a.stage != qStage) continue;
      a.waitQ += dt;
      if (a.qi != i) { a.qi = i; a.path = [slot(i)]; }
      if (a.waitQ > 9 && a.emoT <= 0 && r.nextDouble() < 0.01) { a.emo = '😡'; a.emoT = 2; }
    }
    if (q.isEmpty) { svc[idx] = 0; return; }
    final f = q.first;
    if (f.stage != qStage) { f.stuck += dt; if (f.stuck > 8) { f.stage = qStage; f.qi = -1; f.stuck = 0; } return; }
    if (_dist(f, slot(0)) > 0.15 && f.path.isNotEmpty) { f.stuck += dt; if (f.stuck < 6) return; f.x = slot(0).$1; f.z = slot(0).$2; f.path.clear(); }
    f.stuck = 0;
    svc[idx] += dt;
    if (svc[idx] >= svcTime) { svc[idx] = 0; q.removeAt(0); served++; done(f); }
  }

  void _agentsTick(double dt) {
    final sc = _svcC(), ss = _svcS();
    for (var d = 0; d < 8; d++) {
      if (d >= desks && deskQ[d].isNotEmpty) { final moved = [...deskQ[d]]; deskQ[d].clear(); for (final a in moved) { _toCheckin(a); } continue; }
      _queue(deskQ[d], St8.walkCheck, St8.queueCheck, (i) => deskSlot(d, i), deskSvc, d, sc, (a) { a.bag = false; _toSecurity(a); }, dt);
    }
    for (var l = 0; l < 6; l++) {
      if (l >= lanes && laneQ[l].isNotEmpty) { final moved = [...laneQ[l]]; laneQ[l].clear(); for (final a in moved) { a.desk = 0; _toSecurity(a); } continue; }
      _queue(laneQ[l], St8.walkSec, St8.queueSec, (i) => laneSlot(l, i), laneSvc, l, ss, _afterSecurity, dt);
    }
    for (final a in [...agents]) {
      if (a.emoT > 0) a.emoT -= dt;
      final arrived = _walk(a, dt);
      if (!arrived) continue;
      switch (a.stage) {
        case St8.walkShop: a.stage = St8.shopping; break;
        case St8.shopping:
          a.wait -= dt;
          if (a.wait <= 0) { if (r.nextDouble() < 0.6) { a.emo = '😃'; a.emoT = 1.6; } _toGate(a); }
          break;
        case St8.walkGate: a.stage = St8.waitGate; break;
        case St8.waitGate:
          if (!s.built('g${a.gate}')) { _toGate(a); break; }
          if (s.gates[a.gate].phase == Ph.boarding) _board(a);
          break;
        case St8.boarding:
          a.fade -= dt * 3;
          if (a.fade <= 0) agents.remove(a);
          break;
      }
    }
    if (agents.length > maxAgents) {
      final w = agents.where((a) => a.stage == St8.waitGate).toList();
      if (w.isNotEmpty) { final a = w.first; a.stage = St8.boarding; a.path = []; }
    }
  }

  // ---------- faxineiros ----------
  static const _cleanSpots = [(-40.0, 12.0), (-30.0, 3.0), (-15.0, 11.0), (-8.0, 1.5), (2.0, 12.0), (14.0, 3.0), (-36.0, -2.4), (-6.0, -2.4), (18.0, -2.4), (24.0, 12.0)];
  void _cleanersTick(double dt) {
    final want = cleanersFor(s.lvl('checkin'));
    while (cleaners.length < want) { final p = _cleanSpots[r.nextInt(_cleanSpots.length)]; cleaners.add(Cleaner(p.$1, p.$2, _cleanSpots[r.nextInt(_cleanSpots.length)])); }
    for (final c in cleaners) {
      if (c.pause > 0) { c.pause -= dt; c.moving = false; continue; }
      final dx = c.tgt.$1 - c.x, dz = c.tgt.$2 - c.z, d = math.sqrt(dx * dx + dz * dz), st = 1.3 * dt;
      if (d <= st) { c.x = c.tgt.$1; c.z = c.tgt.$2; c.pause = 1.5 + r.nextDouble() * 2; c.tgt = _cleanSpots[r.nextInt(_cleanSpots.length)]; }
      else { c.x += dx / d * st; c.z += dz / d * st; c.hx = dx / d; c.hz = dz / d; c.anim += dt * 3; c.moving = true; }
    }
  }

  // ---------- veículos ----------
  void _vehiclesTick(double dt) {
    _busT -= dt; _carT -= dt; _tugT -= dt;
    final el = s.lvl('entrada');
    if (_busT <= 0) {
      _busT = math.max(7.0, 24 - el * 0.3) + r.nextDouble() * 5;
      vehicles.add(Vehicle('bus', -100.0, 18.6, 9.0, [(Lay.busStop.$1 + 1, 18.6), (110.0, 18.6)]));
    }
    if (_carT <= 0) {
      _carT = math.max(1.0, 5 - el * 0.06) + r.nextDouble() * 3;
      final dir = r.nextBool();
      final kind = r.nextDouble() < 0.25 ? 'taxi' : 'car${r.nextInt(6)}';
      vehicles.add(Vehicle(kind, dir ? -100.0 : 110.0, dir ? 18.9 : 21.4, 11 + r.nextDouble() * 4, [(dir ? 110.0 : -100.0, dir ? 18.9 : 21.4)]));
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
        if (v.kind == 'bus' && v.path.length == 1) { v.wait = 2.5; final n = 2 + r.nextInt(3 + math.min(5, el ~/ 15)); for (var i = 0; i < n; i++) { Future.delayed(Duration(milliseconds: 280 * i), () => spawnAt(Lay.busStop.$1 + r.nextDouble() * 2, Lay.busStop.$2 - 1.2)); } }
        if ((v.kind == 'tug' || v.kind == 'fuel') && v.path.length == 1) v.wait = 3;
      } else { v.x += dx / d * st; v.z += dz / d * st; }
    }
  }

  // ---------- estacionamento ----------
  /// Vagas: (x, z, direção 0..3, cor).
  static final List<(double, double, int, int)> parkSlots = [
    for (var row = 0; row < 3; row++)
      for (var c = 0; c < 8; c++) (Lay.parking.$1 - 10.5 + c * 3.0, Lay.parking.$2 - 4 + row * 4.2 + (row == 1 ? -0.4 : 0), row.isOdd ? 0 : 2, (c * 3 + row * 5) % 6),
  ];

  // ---------- aviões ----------
  final Map<String, Path3> _pc = {};
  Path3 _p(String k, Path3 Function() f) => _pc[k] ??= f();
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
  /// Onde fica a pilha de dinheiro do portão.
  (double, double) pilePos(int g) => (Lay.gates[g] + 3.6, -0.6);
  static const shopPilePos = (7.5, 11.6);

  // ---------- efeitos ----------
  void burst(double x, double z, double y, int n, List<Color> cols) {
    for (var i = 0; i < n; i++) {
      final a = r.nextDouble() * math.pi * 2, sp = 2 + r.nextDouble() * 4;
      sparks.add(Spark(x, z, y, math.cos(a) * sp, math.sin(a) * sp, 5 + r.nextDouble() * 6, cols[i % cols.length]));
    }
  }
  (double, double, double) stationCenter(String id) {
    switch (id) {
      case 'entrada': return (Lay.parking.$1, Lay.parking.$2, 3.0);
      case 'checkin': return (Lay.checkinX0 + (math.max(desks, 3) - 1) * Lay.checkinDx / 2, Lay.checkinZ, 4.2);
      case 'seguranca': return (Lay.secX0 + (math.max(lanes, 2) - 1) * Lay.secDx / 2, Lay.secZ, 4.0);
      case 'lojas': return (7.5, 8.0, 4.4);
      case 'vip': return (Lay.vip.$1, Lay.vip.$2, 3.4);
      case 'pista': return (-10.0, Lay.runwayZ, 1.0);
      case 'torre': return (Lay.tower.$1, Lay.tower.$2, 6.0);
      case 'hangar': return (Lay.hangar.$1, Lay.hangar.$2, 7.0);
      case 'combustivel': return (Lay.fuel.$1, Lay.fuel.$2, 5.0);
    }
    if (id.startsWith('g')) { final g = int.parse(id.substring(1)); return (Lay.gates[g] - 1, -1.5, 4.2); }
    return (0.0, 0.0, 0.0);
  }
  void levelFx(String id, String gain) {
    final c = stationCenter(id);
    bump[id] = t;
    burst(c.$1, c.$2, c.$3 * 0.5, 22, const [Color(0xFFFFE27A), Color(0xFF3FD46B), Color(0xFFFFFFFF), Color(0xFF3E8BFF)]);
    for (var i = 0; i < 6; i++) { puffs.add(Puff(c.$1 + r.nextDouble() * 4 - 2, c.$2 + r.nextDouble() * 3 - 1.5, 0.8 + r.nextDouble() * 0.8)); }
    if (gain.isNotEmpty) floaters.add(Floater(c.$1, c.$2, c.$3 + 1.5, gain, const Color(0xFF8FF0A4), 1.15));
  }
  void flightFx(int g, String text, bool vip) {
    final pose = planePose(g);
    final p = pose?.p ?? const P3(Lay.connL + 50, 3, Lay.runwayZ);
    floaters.add(Floater(p.x, p.z, p.y + 3, text, vip ? const Color(0xFFFFC531) : const Color(0xFFFFE27A), vip ? 1.8 : 1.3));
    if (vip) burst(p.x, p.z, p.y + 2, 30, const [Color(0xFFFFE27A), Color(0xFFFFC531), Color(0xFFFFFFFF)]);
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
    _cleanersTick(dt);
    _vehiclesTick(dt);
    for (final f in [...floaters]) { f.t += dt; if (f.t > 1.8) floaters.remove(f); }
    for (final p in [...puffs]) { p.t += dt; if (p.t > 0.9) puffs.remove(p); }
    for (final sp in [...sparks]) {
      sp.t += dt; sp.vy -= 16 * dt; sp.x += sp.vx * dt; sp.z += sp.vz * dt; sp.y = math.max(0.0, sp.y + sp.vy * dt);
      if (sp.t > 1.1) sparks.remove(sp);
    }
  }
}
