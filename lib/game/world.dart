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
class St8 { static const walkCheck = 0, queueCheck = 1, walkSec = 2, queueSec = 3, walkShop = 4, shopping = 5, walkGate = 6, waitGate = 7, boarding = 8, arriving = 9, carousel = 10, leaving = 11; }

/// Passageiro visual (cosmético, segue o ritmo real das estações).
class Agent {
  double x, z, speed;
  final int c;
  bool bag = true, shop;
  int stage = St8.walkCheck, desk = -1, lane = -1, gate = -1, qi = -1, seat = -1, shopI = 0;
  double wait = 0, anim = 0, fade = 1, hx = 1, hz = 0, waitQ = 0, emoT = 0, stuck = 0, y = -1;
  String emo = '';
  bool moving = false, outside = false, gold = false;
  // escada do avião: (x do pé, x do topo, altura)
  (double, double, double)? stairs;
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
  static const corridorZ = 1.8, frontZ = 15.3, backZ = -4.4, leftX = -46.95;
  bool _noBridge(int g, int tier) => !s.ph.bridges || tier < 1;
  /// Porta do avião estacionado (x, z) e raio da fuselagem.
  (double, double, double) planeDoor(int g, int tier) {
    const r = [0.46, 0.62, 0.82], door = [0.2, 0.17, 0.15];
    return (Lay.gates[g] + r[tier], Lay.standNose - planeTypes[tier].len * door[tier], r[tier]);
  }
  /// Vagas de assento na sala de embarque.
  List<(double, double)> seatsAt(int g) {
    final gx = Lay.gates[g];
    final rows = s.ph.wood ? 2 : gateVis(s.lvl('g$g'));
    final dz = s.ph.wood ? 1.4 : 1.3, nx = s.ph.wood ? 5 : 6;
    return [for (var r = 0; r < rows; r++) for (var k = 0; k < nx; k++) (gx - 1.0 + k * 0.7, -2.0 + r * dz + 0.38)];
  }
  double _goldT = -20;
  final List<Set<int>> _taken = List.generate(6, (_) => <int>{});
  /// Limpa passageiros e filas (troca de aeroporto).
  void resetPeople() { agents.clear(); cleaners.clear(); vehicles.clear(); for (final q in deskQ) { q.clear(); } for (final q in laneQ) { q.clear(); } for (final t in _taken) { t.clear(); } }

  void spawnAt(double x, double z) {
    if (agents.length >= maxAgents) return;
    final a = Agent(x, z, r.nextInt(8), 1.9 + r.nextDouble() * 0.7, s.built('lojas') && r.nextDouble() < 0.6);
    // passageiro dourado: aparece de vez em quando, vale um toque
    if (s.tut >= 7 && t - _goldT > 38 && !agents.any((x) => x.gold)) { a.gold = true; _goldT = t + r.nextDouble() * 20; }
    agents.add(a);
    _toCheckin(a);
  }
  void spawnGroup(int n) { for (var i = 0; i < n; i++) { Future.delayed(Duration(milliseconds: 180 * i), () => spawnAt(Lay.busStop.$1 + r.nextDouble() * 3 - 1.5, Lay.busStop.$2 - 1)); } }
  int _shortest(List<List<Agent>> qs, int n) { var best = 0, bl = 1 << 30; for (var i = 0; i < n; i++) { if (qs[i].length < bl) { bl = qs[i].length; best = i; } } return best; }
  void _toCheckin(Agent a) {
    final d = _shortest(deskQ, desks);
    a.desk = d; a.stage = St8.walkCheck; a.qi = -1; deskQ[d].add(a);
    final door = Lay.door;
    a.path = [(door.$1 + r.nextDouble() * 2 - 1, door.$2 - 0.6), (deskSlot(d, 0).$1, frontZ - 1.2)];
  }
  void _toSecurity(Agent a) {
    final l = _shortest(laneQ, lanes);
    a.lane = l; a.stage = St8.walkSec; a.qi = -1; a.waitQ = 0; laneQ[l].add(a);
    final dp = deskPos(a.desk);
    a.path = [(dp.$1 + 1.3, dp.$2 + 1.2), (dp.$1 + 1.3, frontZ), (laneSlot(l, 0).$1, frontZ)];
  }
  void _afterSecurity(Agent a) {
    final lp = lanePos(a.lane);
    final exit = [(lp.$1 + 0.75, lp.$2 - 2.7), (lp.$1 + 0.75, corridorZ)];
    final shops = [for (final i in s.shopsBuilt) if (Lay.shops[i].$1 < s.ph.termX1 - 1.5) i];
    if (a.shop && shops.isNotEmpty) {
      final i = shops[r.nextInt(shops.length)], sh = Lay.shops[i], gap = sh.$1 + 2.35;
      a.shopI = i; a.stage = St8.walkShop; a.wait = 1.4 + r.nextDouble() * 2;
      a.path = [...exit, (gap, corridorZ), (gap, sh.$2 + 3.0), (sh.$1 + r.nextDouble() * 1.6 - 0.8, sh.$2 + 2.6)];
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
    // assento livre (ou em pé ao lado)
    final seats = seatsAt(g);
    final free = [for (var i = 0; i < seats.length; i++) if (!_taken[g].contains(i)) i];
    (double, double) spot;
    if (free.isNotEmpty) { a.seat = free[r.nextInt(free.length)]; _taken[g].add(a.seat); spot = seats[a.seat]; }
    else { a.seat = -1; spot = (Lay.gates[g] + 3.0 + r.nextDouble() * 1.4, -2.6 + r.nextDouble() * 3.6); }
    final p = <(double, double)>[...prefix];
    if (prefix.isEmpty) {
      if (a.stage == St8.walkGate && a.shopI >= 0 && a.z > 5) { final gap = Lay.shops[a.shopI].$1 + 2.35; p.addAll([(gap, a.z), (gap, corridorZ)]); }
      else { p.add((a.x, corridorZ)); }
    }
    p.addAll([(spot.$1, corridorZ), spot]);
    a.path = p;
  }
  void _freeSeat(Agent a) { if (a.gate >= 0 && a.seat >= 0) _taken[a.gate].remove(a.seat); a.seat = -1; }
  void _board(Agent a) {
    final g = a.gate, G = s.gates[g], gx = Lay.gates[g];
    _freeSeat(a);
    a.stage = St8.boarding;
    if (_noBridge(g, G.tier)) {
      final d = planeDoor(g, G.tier);
      a.stairs = (d.$1 + 2.6, d.$1 + 0.35, 1.0 + d.$3 * 1.4);
      a.path = [(gx + 3.2, backZ), (gx + 3.2, -5.7), (d.$1 + 2.8, d.$2), (d.$1 + 0.35, d.$2)];
    } else {
      a.path = [(gx + 3.2, -3.4), (gx + 3.2, -4.7)];
    }
    if (r.nextDouble() < 0.3) { a.emo = '😍'; a.emoT = 1.6; }
  }
  /// Desembarque: um grupo sai do avião, pega a mala e vai embora.
  void arrivals(int g, int pax) {
    final G = s.gates[g], gx = Lay.gates[g];
    final n = math.min(maxAgents + 14 - agents.length, math.min(9, 2 + pax ~/ 14));
    for (var i = 0; i < n; i++) {
      Future.delayed(Duration(milliseconds: 380 * i), () {
        final a = Agent(0, 0, r.nextInt(8), 2.0 + r.nextDouble() * 0.6, false)..bag = false..stage = St8.arriving..fade = 0;
        final p = <(double, double)>[];
        if (_noBridge(g, G.tier)) {
          final d = planeDoor(g, G.tier);
          a.x = d.$1 + 0.35; a.z = d.$2; a.stairs = (d.$1 + 2.6, d.$1 + 0.35, 1.0 + d.$3 * 1.4);
          p.addAll([(d.$1 + 2.8, d.$2), (gx + 3.2, -5.7)]);
        } else { a.x = gx + 3.2; a.z = -4.9; }
        p.addAll([(gx + 3.2, backZ), (leftX, backZ)]);
        if (s.phase >= 1) { p.addAll([(leftX, -0.2), (Lay.carousel.$1 + r.nextDouble() * 2.4 - 1.2, -0.3)]); }
        else { p.add((leftX, frontZ)); }
        a.path = p;
        agents.add(a);
      });
    }
  }
  void _leave(Agent a) {
    a.stage = St8.leaving; a.bag = true;
    a.path = [(leftX, a.z + 0.6), (leftX, frontZ), (-45.5, 17.0), (-47.5 - r.nextDouble() * 3, 19.5)];
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
      if (a.stage == St8.arriving && a.fade < 1) a.fade = math.min(1.0, a.fade + dt * 3);
      final arrived = _walk(a, dt);
      a.outside = a.z < -5.0 && a.z > -16;
      final st = a.stairs;
      if (st != null && a.outside && a.x <= st.$1 + 0.05) { a.y = ((st.$1 - a.x) / (st.$1 - st.$2)).clamp(0.0, 1.0) * st.$3; } else { a.y = -1; }
      if (!arrived) continue;
      switch (a.stage) {
        case St8.walkShop: a.stage = St8.shopping; break;
        case St8.shopping:
          a.wait -= dt;
          if (a.wait <= 0) { if (r.nextDouble() < 0.6) { a.emo = '😃'; a.emoT = 1.6; } _toGate(a); }
          break;
        case St8.walkGate: a.stage = St8.waitGate; a.hx = 0.6; a.hz = 0.8; break;
        case St8.waitGate:
          if (!s.built('g${a.gate}')) { _freeSeat(a); _toGate(a); break; }
          if (s.gates[a.gate].phase == Ph.boarding && r.nextDouble() < dt * 2.5) _board(a);
          break;
        case St8.boarding:
          a.fade -= dt * 3;
          if (a.fade <= 0) agents.remove(a);
          break;
        case St8.arriving:
          if (s.phase >= 1) { a.stage = St8.carousel; a.wait = 1.2 + r.nextDouble() * 1.8; } else { _leave(a); }
          break;
        case St8.carousel:
          a.wait -= dt; a.moving = false;
          if (a.wait <= 0) { if (r.nextDouble() < 0.25) { a.emo = '😃'; a.emoT = 1.4; } _leave(a); }
          break;
        case St8.leaving:
          a.fade -= dt * 2.5;
          if (a.fade <= 0) agents.remove(a);
          break;
      }
    }
    if (agents.length > maxAgents) {
      final w = agents.where((a) => a.stage == St8.waitGate).toList();
      if (w.isNotEmpty) { final a = w.first; _freeSeat(a); a.stage = St8.boarding; a.path = []; }
    }
  }

  // ---------- faxineiros ----------
  static const _cleanSpots = [(-40.0, 12.0), (-30.0, 3.0), (-15.0, 11.0), (-9.0, 1.5), (2.0, 12.0), (14.0, 3.0), (-36.0, -4.3), (-9.0, -4.3), (18.0, -4.3), (24.0, 12.0)];
  void _cleanersTick(double dt) {
    final want = cleanersFor(s.lvl('checkin'));
    final spots = _cleanSpots.where((p) => p.$1 < s.ph.termX1 - 1.5).toList();
    while (cleaners.length < want) { final p = spots[r.nextInt(spots.length)]; cleaners.add(Cleaner(p.$1, p.$2, spots[r.nextInt(spots.length)])); }
    for (final c in cleaners) {
      if (c.pause > 0) { c.pause -= dt; c.moving = false; continue; }
      final dx = c.tgt.$1 - c.x, dz = c.tgt.$2 - c.z, d = math.sqrt(dx * dx + dz * dz), st = 1.3 * dt;
      if (d <= st) { c.x = c.tgt.$1; c.z = c.tgt.$2; c.pause = 1.5 + r.nextDouble() * 2; c.tgt = spots[r.nextInt(spots.length)]; }
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
    const svc = -5.9;
    if (_tugT <= 0 && s.gatesOpen >= 2 && vehicles.where((v) => v.kind == 'tug').length < 2) {
      _tugT = 8 + r.nextDouble() * 8;
      final open = [for (var g = 0; g < 6; g++) if (s.built('g$g')) g];
      final a = Lay.gates[open[r.nextInt(open.length)]] + 4.7, b = Lay.gates[open[r.nextInt(open.length)]] + 4.7;
      if (s.built('cargas') && r.nextBool()) {
        vehicles.add(Vehicle('tug', 43.0, -3.0, 5.0, [(43.0, svc), (b, svc), (b, -10.5), (b, svc), (43.0, svc), (43.0, -3.0)]));
      } else if ((a - b).abs() > 1) {
        vehicles.add(Vehicle('tug', a, -10.5, 5.0, [(a, svc), (b, svc), (b, -10.5), (b, -10.51)]));
      }
    }
    if (_tugT <= 0 && s.built('combustivel') && !vehicles.any((v) => v.kind == 'fuel')) {
      final open = [for (var g = 0; g < 6; g++) if (s.built('g$g')) g];
      final b = Lay.gates[open[r.nextInt(open.length)]] + 4.7;
      vehicles.add(Vehicle('fuel', 44.0, -11.0, 6.0, [(44.0, svc), (b, svc), (b, -11.0), (b, svc), (44.0, svc), (44.0, -11.0)]));
    }
    for (final v in [...vehicles]) {
      if (v.wait > 0) { v.wait -= dt; continue; }
      if (v.path.isEmpty) { vehicles.remove(v); continue; }
      final tg = v.path.first;
      final dx = tg.$1 - v.x, dz = tg.$2 - v.z, d = math.sqrt(dx * dx + dz * dz), st = v.speed * dt;
      if (d > 0.01) { v.hx = dx / d; v.hz = dz / d; }
      if (d <= st) {
        v.x = tg.$1; v.z = tg.$2; v.path.removeAt(0);
        if (v.kind == 'bus' && v.path.length == 1) { v.wait = 2.5; final n = 1 + r.nextInt(2 + math.min(5, el ~/ 15)); for (var i = 0; i < n; i++) { Future.delayed(Duration(milliseconds: 280 * i), () => spawnAt(Lay.busStop.$1 + r.nextDouble() * 2, Lay.busStop.$2 - 1.2)); } }
        if ((v.kind == 'tug' || v.kind == 'fuel') && v.path.length == 3 && v.z < -9) v.wait = 3;
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
  Pose? planePose(int g) {
    final G = s.gates[g];
    final k = G.k, ph = s.phase;
    switch (G.phase) {
      case Ph.landing:
        final p = Routes.landing(ph); final u = 1 - (1 - k) * (1 - k);
        return p.at(p.length * (0.15 * k + 0.85 * u));
      case Ph.taxiIn:
        final p = Routes.taxiIn(g, G.tier, ph);
        return p.at(p.length * _ease(k));
      case Ph.boarding:
        return Pose(P3(Lay.gates[g], 0, Routes.parkZ(G.tier)), 0);
      case Ph.pushback:
        final p = Routes.pushback(g, G.tier);
        return Pose(p.at(p.length * _smooth(k)).p, 0);
      case Ph.taxiOut:
        final p = Routes.taxiOut(g, ph);
        // gira no lugar (rebocador) e depois taxia
        const turn = 0.16;
        if (k < turn) { final u = _smooth(k / turn); return Pose(p.pts.first, -math.pi / 2 * u); }
        final pose = p.at(p.length * _ease((k - turn) / (1 - turn)));
        return pose;
      case Ph.hold:
        return Pose(const P3(Lay.connL, 0, Lay.holdZ), math.pi);
      case Ph.takeoff:
        final p = Routes.takeoff;
        final d = p.length * math.pow(k, 1.7);
        return p.at(d.toDouble());
    }
    return null;
  }
  /// Partida e chegada suaves sem parar no meio.
  double _ease(double k) { const a = 0.12; if (k < a) return k * k / (2 * a * (1 - a)); if (k > 1 - a) return 1 - (1 - k) * (1 - k) / (2 * a * (1 - a)); return (k - a / 2) / (1 - a); }

  /// Controle de tráfego: avião que tem outro logo à frente espera.
  final Map<int, Pose> _poses = {};
  void _traffic() {
    _poses.clear();
    for (var g = 0; g < 6; g++) { if (!s.built('g$g')) continue; final p = planePose(g); if (p != null && p.p.y < 0.4) _poses[g] = p; }
    final moving = <int, (double, double)>{};
    for (final e in _poses.entries) {
      final G = s.gates[e.key];
      if (G.phase != Ph.taxiIn && G.phase != Ph.pushback && G.phase != Ph.taxiOut) continue;
      // direção do movimento (pushback anda de ré)
      double dx, dz;
      if (G.phase == Ph.pushback) { dx = 0; dz = -1; }
      else if (G.phase == Ph.taxiOut && G.k < 0.16) { dx = -1; dz = 0; }
      else { dx = math.sin(e.value.heading); dz = math.cos(e.value.heading); }
      moving[e.key] = (dx, dz);
    }
    final blockedBy = <int, int>{};
    for (final m in moving.entries) {
      final g = m.key, me = _poses[g]!.p, len = planeTypes[s.gates[g].tier].len;
      final look = len * 0.5 + 2.2;
      final lx = me.x + m.value.$1 * look, lz = me.z + m.value.$2 * look;
      for (final o in _poses.entries) {
        if (o.key == g) continue;
        final op = o.value.p, olen = planeTypes[s.gates[o.key].tier].len;
        final d = math.sqrt((op.x - lx) * (op.x - lx) + (op.z - lz) * (op.z - lz));
        // só conta quem está à frente
        final ahead = (op.x - me.x) * m.value.$1 + (op.z - me.z) * m.value.$2;
        if (ahead > 0 && d < olen * 0.5 + 1.6) { blockedBy[g] = o.key; break; }
      }
    }
    // impasse: quem está fazendo pushback cede
    for (final e in [...blockedBy.entries]) {
      if (blockedBy[e.value] == e.key) {
        final a = s.gates[e.key].phase, b = s.gates[e.value].phase;
        final yield0 = a == Ph.pushback ? e.key : b == Ph.pushback ? e.value : math.max(e.key, e.value);
        blockedBy.remove(yield0 == e.key ? e.value : e.key);
      }
    }
    for (var g = 0; g < 6; g++) { s.gates[g].blocked = blockedBy.containsKey(g); }
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
      case 'lojas': case 'loja1': case 'loja2': case 'loja3': case 'loja4': case 'loja5': final i = shopIds.indexOf(id); return (Lay.shops[i].$1, Lay.shops[i].$2, 3.6 + visTier(id, s.lvl(id)) * 1.1);
      case 'vip': return (Lay.vip.$1, Lay.vip.$2, 3.4);
      case 'pista': return (-30.0, Lay.runwayZ, 1.0);
      case 'torre': return (Lay.tower.$1, Lay.tower.$2, 6.0);
      case 'cargas': return (Lay.cargo.$1, Lay.cargo.$2, 5.0);
      case 'esp0': case 'esp1': case 'esp2': case 'esp3': case 'esp4': case 'esp5': return (Lay.special.$1, Lay.special.$2, id == 'esp1' ? 9.5 : 5.0);
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
      if (r.nextDouble() < 0.55) spawnAt(Lay.parking.$1 + 10 + r.nextDouble() * 4, 23.5);
    }
    _traffic();
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
