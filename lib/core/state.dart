import 'dart:math' as math;

import 'data.dart';
import 'paths.dart';

int nowMs() => DateTime.now().millisecondsSinceEpoch;
int dayKey([DateTime? d]) { final t = d ?? DateTime.now(); return t.year * 10000 + t.month * 100 + t.day; }
int daysSinceEpoch() => DateTime.now().difference(DateTime(2024, 1, 1)).inDays;

/// Efeitos que a interface implementa (o estado só avisa).
abstract class Fx {
  void banner(String title, String sub);
  void toast(String msg);
  void sfx(String name, {double pitch = 1});
  void confetti([int n = 60]);
  void flightPaid(int gate, double amount, int pax, bool vip);
  void stationUp(String id, int from, int to, String gain);
  void levelUp(int lvl);
  void eventStarted(String type);
  void bottleneckFreed(String old);
}

/// Fases do ciclo de um portão.
class Ph {
  static const empty = 0, landing = 1, taxiIn = 2, boarding = 3, pushback = 4, taxiOut = 5, hold = 6, takeoff = 7;
  static const names = ['Livre', 'Pousando', 'Taxiando', 'Embarcando', 'Pushback', 'Taxiando', 'Aguardando pista', 'Decolando'];
}

/// Estado do portão em tempo de execução.
class GateRt {
  int phase = Ph.empty;
  double t = 0, dur = 1.5;
  double boarded = 0;
  int seats = 40, tier = 0, liv = 0;
  double ticket = 4;
  bool paid = false, vip = false, vipTapped = false;
  String flight = '', dest = '', model = 'brisa';
  double get k => dur <= 0 ? 1.0 : (t / dur).clamp(0.0, 1.0).toDouble();
}

/// Evento aleatório ativo.
class Ev {
  final String type;
  final double x, z;
  final double until;
  int taps = 0;
  Ev(this.type, this.x, this.z, this.until);
}

/// Recompensa de baú.
class Loot {
  double coins = 0, miles = 0;
  int gems = 0;
  final List<String> cards = [];
  final List<String> fresh = [];
}

class GameState {
  // ---------- salvo ----------
  double money = 60, earnedCity = 0, earnedAll = 0, xp = 0, miles = 0;
  int gems = 10, city = 0, star = 0, alv = 1;
  final Map<String, int> lv = {};
  final Set<String> mgr = {};
  int mission = 0, flightsCity = 0, flightsAll = 0, collectsCity = 0;
  int dailyDay = 0, dailyLast = 0;
  int boostUntil = 0, rushUntil = 0, turboUntil = 0, freeAt = 0, chestAt = 0, spinDay = 0, landAt = 0, xrayAt = 0, bagAt = 0;
  int tut = 0, ls = 0, buyMode = 1;
  bool music = true, sound = true, vibration = true, autoUp = false;
  final Set<String> research = {}, routesOwned = {}, achClaimed = {};
  final Map<String, int> cards = {}, mlv = {};
  final Map<String, double> cnt = {};
  int dKey = 0, wKey = -1;
  Map<String, double> dBase = {}, wBase = {};
  List<int> dTasks = [], wTasks = [];
  List<bool> dClaimed = [], wClaimed = [];
  bool dBonus = false;
  int sId = -1, sPts = 0;
  final Set<int> sClaimed = {};
  final List<String> chestsQ = [];

  // ---------- execução ----------
  Fx? fx;
  final List<GateRt> gates = List.generate(6, (_) => GateRt());
  final List<double> pile = List.filled(6, 0), pileT = List.filled(6, 0);
  double shopPile = 0, shopPileT = 0;
  double qc = 0, qs = 0, lounge = 0;
  int runway = -1;
  double clock = 0, rate = 0, sat = 70;
  String bottleneck = 'entrada';
  int combo = 0;
  double lastCollect = -10;
  Ev? ev;
  double evNext = 60;
  int vipGate = -1;
  final List<double> history = [];
  double _histAcc = 0, _histEarned = 0, _autoT = 0;
  final _r = math.Random();
  int _flightNo = 100;

  GameState() { reset(); for (final id in ['brisa', 'ceu', 'atlantico']) { mlv[id] = 1; } ensurePeriods(); }

  void reset() {
    lv..clear()..addAll({for (final s in stations) s.id: 0});
    for (final id in ['entrada', 'checkin', 'seguranca', 'g0', 'pista', 'torre']) { lv[id] = 1; }
    mgr.clear();
    for (final g in gates) { g.phase = Ph.empty; g.t = 0; g.dur = 1 + _r.nextDouble() * 2; }
    for (var i = 0; i < 6; i++) { pile[i] = 0; }
    shopPile = 0; qc = qs = lounge = 0; runway = -1; ev = null; vipGate = -1;
  }

  // ---------- consultas ----------
  int lvl(String id) => lv[id] ?? 0;
  bool built(String id) => lvl(id) > 0;
  bool hasMgr(String id) => mgr.contains(id);
  bool has(String research0) => research.contains(research0);
  double c(String k) => cnt[k] ?? 0;
  void inc(String k, [double v = 1]) => cnt[k] = c(k) + v;
  bool get boostOn => nowMs() < boostUntil;
  bool get rushOn => nowMs() < rushUntil;
  bool get turboOn => nowMs() < turboUntil;
  bool get fogOn => ev?.type == 'fog';
  static const maxL = 500;

  double cost(St s, int l) => s.base * math.pow(s.growth, l - 1);
  (int, double) buyInfo(St s, [int? mode]) {
    final m = mode ?? buyMode, l = lvl(s.id);
    if (s.oneTime || l <= 0 || l >= maxL) return (0, 0.0);
    var n = 0; var total = 0.0;
    final cap = m == -1 ? maxL : m;
    while (n < cap && l + n < maxL) {
      final cc = cost(s, l + n);
      if (m == -1 && total + cc > money) break;
      total += cc; n++;
    }
    if (m == -1 && n == 0) return (1, cost(s, l));
    return (n, total);
  }
  bool canUp(St s) { final b = buyInfo(s, 1); return b.$1 > 0 && money >= b.$2; }
  bool starOk(St s) => star >= s.star;
  bool unlockOk(St s) => starOk(s) && (s.kind != Kind.gate || s.gate == 0 || built('g${s.gate - 1}'));
  bool canUnlock(St s) => !built(s.id) && money >= s.unlock && unlockOk(s);

  // ---------- multiplicadores ----------
  double get speed => (1 + 0.035 * (lvl('pista') - 1)).clamp(1.0, 4.0).toDouble() * (hasMgr('diego') ? 1.3 : 1.0) * (has('embarque') ? 1.15 : 1.0) * (turboOn ? 2.0 : 1.0);
  double get lambda => 0.5 * power(lvl('entrada')) * (hasMgr('carla') ? 2 : 1) * (has('expresso') ? 1.5 : 1) * (rushOn ? 3 : 1);
  double get muC => 0.6 * power(lvl('checkin')) * (hasMgr('ana') ? 2 : 1) * (has('online') ? 1.5 : 1) * (has('bio') ? 2 : 1);
  double get muS => 0.55 * power(lvl('seguranca')) * (hasMgr('bruno') ? 2 : 1) * (has('scan') ? 1.5 : 1) * (has('bio') ? 2 : 1);
  double get shopSpend { final l = lvl('lojas'); return l > 0 ? 0.4 * l * math.pow(1.6, milestonesPassed(l)) * (hasMgr('elisa') ? 3 : 1) * (has('premium') ? 2 : 1) : 0.0; }
  double get starMult => math.pow(2, star).toDouble();
  double get tipMult => 0.85 + sat / 100 * 0.3;
  double get revMult => cityMult(city) * (1 + 0.06 * (lvl('torre') - 1)) * (built('hangar') ? 1.5 : 1) * (built('combustivel') ? 1.5 : 1) * (hasMgr('hugo') ? 2 : 1) * (boostOn ? 2 : 1) * starMult * (has('verde') ? 1.5 : 1) * (has('mega') ? 2 : 1) * tipMult;
  double get routeBonus => routes.where((r) => routesOwned.contains(r.id)).fold(0.0, (a, r) => a + r.bonus);
  double fleetBonus(int tier) {
    var b = 0.0;
    for (final m in planeModels) { final l = mlv[m.id] ?? 0; if (m.tier == tier && l > 0) b += rarityBonus[m.rarity] * (1 + 0.5 * (l - 1)); }
    return b;
  }

  int tierFor(int g) => math.min(gateTier(lvl('g$g')), runwayTier(lvl('pista')));
  double seatsFor(int g) { final l = lvl('g$g'); return planeTypes[tierFor(g)].seats * (1 + 0.02 * (l - 1)); }
  double ticketFor(int g) {
    final l = lvl('g$g'), t = tierFor(g);
    return 4 * (1 + 0.2 * (l - 1)) * math.pow(2, milestonesPassed(l)) * planeTypes[t].ticketMul * (1 + 0.04 * lvl('vip')) * (hasMgr('fabio') ? 1.5 : 1) * (has('tarifa') ? 1.3 : 1) * (1 + routeBonus) * (1 + fleetBonus(t));
  }
  double boardRate(double seats) => math.max(4.0, seats / 5);
  double durLanding() => 7 / speed;
  double durTakeoff() => 7 / speed;
  double durPush() => 4 / speed;
  double durTurn() => 2 / speed;
  double durTaxi(double len) => len / (8 * speed);
  double cycle(int g) {
    final seats = seatsFor(g), tier = tierFor(g);
    return durLanding() + durTaxi(Routes.taxiInLen(g, tier)) + seats / boardRate(seats) + 1 + durPush() + durTaxi(Routes.taxiOutLen(g)) + durTakeoff() + durTurn();
  }
  double gateCap(int g) => built('g$g') ? seatsFor(g) / cycle(g) : 0.0;
  int get gatesOpen => List.generate(6, (i) => i).where((i) => built('g$i')).length;
  double get gatesCap { var c0 = 0.0; for (var g = 0; g < 6; g++) { c0 += gateCap(g); } return c0; }
  double get throughput => [lambda, muC, muS, gatesCap].reduce(math.min);

  void _estimate() {
    var cap = 0.0, wt = 0.0;
    for (var g = 0; g < 6; g++) { final c0 = gateCap(g); cap += c0; wt += c0 * ticketFor(g); }
    final vals = {'entrada': lambda, 'checkin': muC, 'seguranca': muS, 'gates': cap};
    var best = 'entrada';
    vals.forEach((k, v) { if (v < vals[best]!) best = k; });
    if (best != bottleneck && clock > 3) fx?.bottleneckFreed(bottleneck);
    bottleneck = best;
    final thr = vals[best]!;
    final avg = cap > 0 ? wt / cap : 0.0;
    rate = thr * (avg + shopSpend) * revMult;
  }
  void estimate() => _estimate();
  double get queueCapC => 10.0 + 5 * desksFor(lvl('checkin'));
  double get queueCapS => 10.0 + 5 * lanesFor(lvl('seguranca'));
  double get loungeCap => 30.0 + 40 * gatesOpen + 0.3 * gates.fold(0.0, (a, g) => a + g.seats);
  bool get qcFull => qc >= queueCapC * 0.9;
  bool get qsFull => qs >= queueCapS * 0.9;

  // ---------- dinheiro ----------
  void earn(double v) { money += v; earnedCity += v; earnedAll += v; _histEarned += v; }
  bool spend(double v) { if (money + 1e-9 < v) return false; money -= v; return true; }
  double get pilesTotal => pile.fold(0.0, (a, b) => a + b) + shopPile;

  String _gainText(String id, double before, double after) {
    final d = after - before;
    if (d <= 0) return '';
    switch (id) {
      case 'entrada': case 'checkin': case 'seguranca': return '+${_short(d * 60)} pax/min';
      case 'lojas': return '+\$${_short(d * revMult)}/pax';
      case 'pista': return '+${(d * 100).round()}% velocidade';
      case 'torre': case 'vip': return '+${(d * 100).round()}% receita';
    }
    return '+\$${_short(d * revMult)}/passagem';
  }
  double _statOf(String id) {
    switch (id) {
      case 'entrada': return lambda;
      case 'checkin': return muC;
      case 'seguranca': return muS;
      case 'lojas': return shopSpend;
      case 'pista': return speed;
      case 'torre': return 1 + 0.06 * (lvl('torre') - 1);
      case 'vip': return 1 + 0.04 * lvl('vip');
    }
    if (id.startsWith('g')) return ticketFor(int.parse(id.substring(1)));
    return 0;
  }
  static String _short(double v) {
    if (v < 1000) return v < 10 ? v.toStringAsFixed(1) : v.round().toString();
    const s = ['K', 'M', 'B', 'T', 'aa', 'ab'];
    var i = -1; while (v >= 1000 && i < s.length - 1) { v /= 1000; i++; }
    return '${v.toStringAsFixed(v >= 100 ? 0 : 1)}${s[i]}';
  }

  bool upgrade(String id) {
    final s = stationById(id); final b = buyInfo(s);
    if (b.$1 <= 0 || !spend(b.$2)) { fx?.sfx('nope'); return false; }
    final before = _statOf(id);
    final from = lvl(id); lv[id] = from + b.$1;
    final after = _statOf(id);
    inc('upgrades', b.$1.toDouble());
    addXp(b.$1.toDouble());
    _estimate();
    fx?.stationUp(id, from, from + b.$1, _gainText(id, before, after));
    return true;
  }
  bool unlock(String id) {
    final s = stationById(id);
    if (built(id) || !unlockOk(s) || !spend(s.unlock)) { fx?.sfx('nope'); return false; }
    lv[id] = 1;
    if (s.kind == Kind.gate) { gates[s.gate]..phase = Ph.empty..t = 0..dur = 1; }
    if (tut == 5 && id == 'g1') tut = 6;
    addXp(8);
    _estimate();
    fx?.stationUp(id, 0, 1, '');
    return true;
  }
  double mgrCost(Manager m) => m.cost * cityMult(city) / (city == 0 ? 1 : 2);
  bool hire(Manager m) {
    if (hasMgr(m.id) || !spend(mgrCost(m))) { fx?.sfx('nope'); return false; }
    mgr.add(m.id); if (tut == 6) tut = 7; _estimate(); return true;
  }

  /// Melhor compra agora: a mais barata que ataca o gargalo.
  (String, double, bool)? bestBuy() {
    final cands = <(String, double, bool)>[];
    void addUp(String id) { final s = stationById(id); if (!built(id) || s.oneTime) return; cands.add((id, cost(s, lvl(id)), false)); }
    void addUnlock(String id) { final s = stationById(id); if (!built(id) && unlockOk(s)) cands.add((id, s.unlock, true)); }
    if (bottleneck == 'gates') {
      for (var g = 0; g < 6; g++) { addUp('g$g'); addUnlock('g$g'); }
      if (runwayTier(lvl('pista')) < [for (var g = 0; g < 6; g++) if (built('g$g')) gateTier(lvl('g$g'))].fold(0, math.max)) addUp('pista');
    } else {
      addUp(bottleneck);
    }
    if (cands.isEmpty) { for (final s in stations) { addUp(s.id); } }
    cands.sort((a, b) => a.$2.compareTo(b.$2));
    return cands.isEmpty ? null : cands.first;
  }
  bool buyBest() {
    final b = bestBuy(); if (b == null || money < b.$2) { fx?.sfx('nope'); return false; }
    if (b.$3) return unlock(b.$1);
    final m = buyMode; buyMode = 1; final ok = upgrade(b.$1); buyMode = m; return ok;
  }

  // ---------- XP / nível do aeroporto ----------
  double needXp([int? l]) => 15 * math.pow(1.28, (l ?? alv) - 1).toDouble();
  void addXp(double v) {
    xp += v;
    while (xp >= needXp()) {
      xp -= needXp(); alv++;
      chestsQ.add(alv % 5 == 0 ? 'chest_gold' : 'chest');
      sPts += 10;
      fx?.levelUp(alv);
    }
  }

  // ---------- pilhas de dinheiro ----------
  double get comboMult => 1 + 0.1 * (math.max(1, combo) - 1);
  double collect(int g) {
    final v0 = g < 0 ? shopPile : pile[g];
    if (v0 <= 0) return 0;
    combo = clock - lastCollect < 2.5 ? math.min(10, combo + 1) : 1;
    lastCollect = clock;
    final v = v0 * comboMult;
    if (g < 0) { shopPile = 0; } else { pile[g] = 0; }
    earn(v); inc('collects'); collectsCity++;
    if (tut == 4) tut = 5;
    return v;
  }
  void depositAll() { for (var g = 0; g < 6; g++) { if (pile[g] > 0) { earn(pile[g]); pile[g] = 0; } } if (shopPile > 0) { earn(shopPile); shopPile = 0; } }

  // ---------- simulação ----------
  double _acc = 0;
  void tick(double dt) {
    clock += dt;
    _acc += dt;
    if (_acc > 0.5) { _acc = 0; _estimate(); _satTick(); }
    qc = math.min(queueCapC, qc + lambda * dt);
    var c0 = math.min(qc, muC * dt); c0 = math.min(c0, math.max(0.0, queueCapS - qs));
    qc -= c0; qs += c0;
    var sv = math.min(qs, muS * dt); sv = math.min(sv, math.max(0.0, loungeCap - lounge));
    qs -= sv; lounge += sv;
    if (sv > 0 && shopSpend > 0) { if (shopPile <= 0) shopPileT = clock; shopPile += sv * shopSpend * revMult; }
    for (var g = 0; g < 6; g++) { if (built('g$g')) _gateTick(g, dt); }
    // depósito automático (gerente Lia: 2 s; senão 20 s)
    final wait = hasMgr('lia') ? 2.0 : 20.0;
    for (var g = 0; g < 6; g++) { if (pile[g] > 0 && clock - pileT[g] > wait) { earn(pile[g]); pile[g] = 0; } }
    if (shopPile > 0 && clock - shopPileT > wait) { earn(shopPile); shopPile = 0; }
    _eventsTick();
    _histAcc += dt;
    if (_histAcc >= 30) { _histAcc = 0; history.add(_histEarned); _histEarned = 0; if (history.length > 20) history.removeAt(0); }
    if (autoUp && has('auto')) { _autoT += dt; if (_autoT > 1.2) { _autoT = 0; final b = bestBuy(); if (b != null && money >= b.$2) buyBest(); } }
  }
  void _satTick() {
    final t = (80 - (qcFull ? 15 : 0) - (qsFull ? 15 : 0) - (lounge >= loungeCap * 0.95 ? 10 : 0) + (built('lojas') ? 8 : 0) + (built('vip') ? 7 : 0) + cleanersFor(lvl('checkin')) * 4.0).clamp(30.0, 100.0);
    sat += (t - sat) * 0.08;
  }

  void _gateTick(int g, double dt) {
    final G = gates[g];
    G.t += dt;
    switch (G.phase) {
      case Ph.empty:
        if (G.t >= G.dur && runway < 0 && !fogOn) { _start(g, Ph.landing); runway = g; }
        break;
      case Ph.landing:
        if (G.t >= G.dur) { if (runway == g) runway = -1; _start(g, Ph.taxiIn); }
        break;
      case Ph.taxiIn:
        if (G.t >= G.dur) _start(g, Ph.boarding);
        break;
      case Ph.boarding:
        final take = math.min(lounge, math.min(boardRate(G.seats.toDouble()) * dt, G.seats - G.boarded));
        if (take > 0) { lounge -= take; G.boarded += take; }
        if ((G.boarded >= G.seats - 0.01 && G.t > 1.5) || G.t >= G.dur) {
          if (G.boarded < 1 && G.t < G.dur + 20) break;
          _start(g, Ph.pushback);
        }
        break;
      case Ph.pushback:
        if (G.t >= G.dur) _start(g, Ph.taxiOut);
        break;
      case Ph.taxiOut:
        if (G.t >= G.dur) _start(g, Ph.hold);
        break;
      case Ph.hold:
        if (runway < 0 && !fogOn) { runway = g; _start(g, Ph.takeoff); }
        break;
      case Ph.takeoff:
        if (!G.paid && G.t >= G.dur * 0.62) {
          G.paid = true;
          final pax = G.boarded.round();
          final amount = G.boarded * G.ticket * revMult * (G.vip ? 10 : 1);
          if (pax > 0) {
            if (pile[g] <= 0) pileT[g] = clock;
            pile[g] += amount; flightsCity++; flightsAll++; inc('flights');
            miles += 1 + G.tier + (G.vip ? 5 : 0);
            addXp(2.0 + G.tier * 2 + (G.vip ? 10 : 0));
            fx?.flightPaid(g, amount, pax, G.vip);
          }
        }
        if (G.t >= G.dur * 0.75 && runway == g) runway = -1;
        if (G.t >= G.dur) { G.phase = Ph.empty; G.t = 0; G.dur = durTurn(); G.vip = false; }
        break;
    }
  }

  List<String> get destinations => [...destinationsBase, for (final r in routes) if (routesOwned.contains(r.id)) r.name];
  String pickModel(int tier) {
    final owned = planeModels.where((m) => m.tier == tier && (mlv[m.id] ?? 0) > 0).toList();
    return owned.isEmpty ? planeModels.firstWhere((m) => m.tier == tier).id : owned[_r.nextInt(owned.length)].id;
  }
  void _start(int g, int ph) {
    final G = gates[g];
    G.phase = ph; G.t = 0;
    switch (ph) {
      case Ph.landing:
        G.tier = tierFor(g); G.seats = seatsFor(g).round(); G.ticket = ticketFor(g); G.boarded = 0; G.paid = false; G.vipTapped = false;
        G.vip = vipGate == g; if (G.vip) vipGate = -1;
        G.model = pickModel(G.tier); G.liv = G.vip ? 3 : modelById(G.model).liv;
        final d = destinations; G.dest = d[_r.nextInt(d.length)];
        G.flight = '${G.vip ? 'VIP' : ['SP', 'LA', 'VL', 'OU', 'RX', 'RB'][G.liv]} ${_flightNo++}';
        G.dur = durLanding();
        break;
      case Ph.taxiIn: G.dur = durTaxi(Routes.taxiInLen(g, G.tier)); break;
      case Ph.boarding: G.dur = 14 / speed + 3; break;
      case Ph.pushback: G.dur = durPush(); break;
      case Ph.taxiOut: G.dur = durTaxi(Routes.taxiOutLen(g)); break;
      case Ph.hold: G.dur = 0; break;
      case Ph.takeoff: G.dur = durTakeoff(); break;
    }
  }
  void hurry(int g, double secs) {
    final G = gates[g]; if (G.phase == Ph.hold || G.phase == Ph.empty) return;
    G.t = math.min(G.dur, G.t + secs); inc('taps');
  }

  // ---------- eventos ----------
  static const evNames = {'vip': 'Avião VIP dourado!', 'celeb': 'Celebridade no terminal!', 'fog': 'Neblina fechou a pista!', 'bag': 'Mala esquecida!', 'tourists': 'Excursão de turistas!'};
  void _eventsTick() {
    final e = ev;
    if (e != null) {
      if (clock > e.until) { if (e.type == 'fog') fx?.toast('A neblina passou sozinha'); ev = null; }
      return;
    }
    if (tut < 7 || clock < evNext) return;
    evNext = clock + (70 + _r.nextDouble() * 80) / (has('satelite') ? 2 : 1);
    final types = ['vip', 'celeb', 'bag', 'tourists', if (gatesOpen >= 1) 'fog'];
    final t = types[_r.nextInt(types.length)];
    switch (t) {
      case 'vip':
        final open = [for (var g = 0; g < 6; g++) if (built('g$g')) g];
        vipGate = open[_r.nextInt(open.length)];
        inc('events');
        break;
      case 'celeb': ev = Ev('celeb', -10 + _r.nextDouble() * 24, 9.5 + _r.nextDouble() * 3, clock + 30); break;
      case 'bag': ev = Ev('bag', -44 + _r.nextDouble() * 40, 1 + _r.nextDouble() * 12, clock + 25); break;
      case 'tourists': ev = Ev('tourists', Lay.busStop.$1, Lay.busStop.$2, clock + 25); break;
      case 'fog': ev = Ev('fog', -12, Lay.runwayZ, clock + 45); break;
    }
    fx?.eventStarted(t);
  }
  /// Toque no evento: devolve (moedas, gemas, terminou).
  (double, int, bool) tapEvent() {
    final e = ev; if (e == null) return (0.0, 0, true);
    switch (e.type) {
      case 'celeb': ev = null; inc('events'); final v = math.max(rate * 90, 300.0 * cityMult(city)); earn(v); return (v, 0, true);
      case 'bag': ev = null; inc('events'); final n = 2 + _r.nextInt(3); gems += n; return (0.0, n, true);
      case 'tourists': ev = null; inc('events'); rushUntil = math.max(nowMs(), rushUntil) + 60000; _estimate(); return (0.0, 0, true);
      case 'fog':
        e.taps++;
        if (e.taps >= 5) { ev = null; inc('events'); final v = math.max(rate * 30, 100.0 * cityMult(city)); earn(v); return (v, 0, true); }
        return (0.0, 0, false);
    }
    return (0.0, 0, true);
  }
  int tapVip(int g) { final G = gates[g]; if (!G.vip || G.vipTapped) return 0; G.vipTapped = true; gems += 3; return 3; }

  // ---------- baús e frota ----------
  Loot openChest(String type) {
    final gold = type == 'chest_gold';
    final l = Loot();
    l.coins = math.max(rate * (gold ? 480 : 120), (gold ? 1500.0 : 300.0) * cityMult(city));
    l.gems = gold ? 10 + _r.nextInt(6) : 2 + _r.nextInt(3);
    l.miles = gold ? 40 : 12;
    final w = gold ? [40, 35, 20, 5] : [62, 27, 9, 2];
    for (var i = 0; i < (gold ? 6 : 3); i++) {
      var roll = _r.nextInt(100), rar = 0;
      while (rar < 3 && roll >= w[rar]) { roll -= w[rar]; rar++; }
      final pool = planeModels.where((m) => m.rarity == rar).toList();
      final m = pool[_r.nextInt(pool.length)];
      if ((mlv[m.id] ?? 0) == 0) { mlv[m.id] = 1; l.fresh.add(m.id); } else { cards[m.id] = (cards[m.id] ?? 0) + 1; }
      l.cards.add(m.id);
    }
    earn(l.coins); gems += l.gems; miles += l.miles; inc('chests');
    _estimate();
    return l;
  }
  bool canLevelModel(String id) { final l = mlv[id] ?? 0; return l > 0 && l < cardsToLevel.length && (cards[id] ?? 0) >= cardsToLevel[l]; }
  bool levelModel(String id) {
    if (!canLevelModel(id)) return false;
    final l = mlv[id]!; cards[id] = cards[id]! - cardsToLevel[l]; mlv[id] = l + 1; _estimate(); return true;
  }
  bool get chestReady => nowMs() >= chestAt;
  void takeFreeChest() { chestAt = nowMs() + 4 * 3600000; chestsQ.add('chest'); }

  // ---------- pesquisa e rotas ----------
  bool canResearch(Research r) => !has(r.id) && miles >= r.cost;
  bool doResearch(Research r) { if (!canResearch(r)) return false; miles -= r.cost; research.add(r.id); _estimate(); return true; }
  double routeCost(Route r) => r.cost * cityMult(city);
  bool routeReqOk(Route r) => city > 0 ? r.star <= 5 : star >= r.star;
  bool buyRoute(Route r) { if (routesOwned.contains(r.id) || !routeReqOk(r) || !spend(routeCost(r))) return false; routesOwned.add(r.id); _estimate(); return true; }

  // ---------- estrelas ----------
  List<Mission> get starNow => star < starTasks.length ? starTasks[star] : const [];
  bool get starReady => star < 5 && starNow.every((m) { final p = progress(m); return p.$1 >= p.$2; });
  void claimStar() {
    if (!starReady) return;
    star++; inc('stars'); sPts += 50; addXp(40); gems += 10 + star * 5;
    chestsQ.add(star >= 4 ? 'chest_gold' : 'chest');
    _estimate();
  }

  // ---------- missões curtas ----------
  bool get missionsDone => mission >= missionList.length;
  Mission get curMission => missionList[math.min(mission, missionList.length - 1)];
  (double, double) progress(Mission m) {
    switch (m.type) {
      case 'lvl': return (lvl(m.target).toDouble(), m.n);
      case 'unlock': return (built(m.target) ? 1.0 : 0.0, 1.0);
      case 'flights': return (flightsCity.toDouble(), m.n);
      case 'manager': return (mgr.length.toDouble(), m.n);
      case 'collect': return (collectsCity.toDouble(), m.n);
      case 'star': return (star.toDouble(), m.n);
    }
    return (0.0, 1.0);
  }
  (double, double) missionProgress([Mission? m]) => progress(m ?? curMission);
  bool get missionReady { if (missionsDone) return false; final p = missionProgress(); return p.$1 >= p.$2; }
  int get missionGems => 3 + mission ~/ 4;
  double get missionCoins => math.max(80.0 * cityMult(city), rate * 45);
  void claimMission() { if (!missionReady) return; gems += missionGems; earn(missionCoins); mission++; sPts += 10; addXp(5); }
  String missionText([Mission? m]) {
    m ??= curMission;
    switch (m.type) {
      case 'lvl': return '${stationById(m.target).name} no nível ${m.n.toInt()}';
      case 'unlock': return 'Construa: ${stationById(m.target).name}';
      case 'flights': return 'Faça ${m.n.toInt()} voos';
      case 'manager': return 'Contrate ${m.n.toInt()} gerente${m.n > 1 ? 's' : ''}';
      case 'collect': return 'Toque no dinheiro ${m.n.toInt()} vez${m.n > 1 ? 'es' : ''}';
      case 'star': return 'Conquiste a ${m.n.toInt()}ª estrela';
    }
    return '';
  }

  // ---------- diárias, semanais, conquistas, passe ----------
  void ensurePeriods() {
    final dk = dayKey();
    if (dKey != dk) {
      dKey = dk; dBase = Map.of(cnt); dClaimed = List.filled(5, false); dBonus = false;
      final r = math.Random(dk); final idx = List.generate(dailyPool.length, (i) => i)..shuffle(r); dTasks = idx.take(5).toList();
    }
    final wk = daysSinceEpoch() ~/ 7;
    if (wKey != wk) {
      wKey = wk; wBase = Map.of(cnt); wClaimed = List.filled(3, false);
      final r = math.Random(wk * 31); final idx = List.generate(weeklyPool.length, (i) => i)..shuffle(r); wTasks = idx.take(3).toList();
    }
    final si = daysSinceEpoch() ~/ 28;
    if (sId != si) { sId = si; sPts = 0; sClaimed.clear(); }
  }
  (String, double, double) dailyTask(int i) { final p = dailyPool[dTasks[i]]; return (p.$2.replaceAll('{n}', p.$3.toInt().toString()), c(p.$1) - (dBase[p.$1] ?? 0), p.$3); }
  (String, double, double) weeklyTask(int i) { final p = weeklyPool[wTasks[i]]; return (p.$2.replaceAll('{n}', p.$3.toInt().toString()), c(p.$1) - (wBase[p.$1] ?? 0), p.$3); }
  bool dailyDone(int i) { final t = dailyTask(i); return t.$2 >= t.$3; }
  bool weeklyDone(int i) { final t = weeklyTask(i); return t.$2 >= t.$3; }
  void claimDailyTask(int i) { if (dClaimed[i] || !dailyDone(i)) return; dClaimed[i] = true; gems += 3; sPts += 15; if (dClaimed.every((x) => x) && !dBonus) { dBonus = true; chestsQ.add('chest'); } }
  void claimWeeklyTask(int i) { if (wClaimed[i] || !weeklyDone(i)) return; wClaimed[i] = true; gems += 15; sPts += 40; chestsQ.add('chest'); }
  bool achDone(Ach a) => (a.key == 'city' ? city.toDouble() : c(a.key)) >= a.n;
  bool achReady(Ach a) => achDone(a) && !achClaimed.contains(a.id);
  void claimAch(Ach a) { if (!achReady(a)) return; achClaimed.add(a.id); gems += a.gems; }
  int get seasonTier => math.min(30, sPts ~/ seasonPts);
  bool seasonReady(int t) => t < seasonTier && !sClaimed.contains(t);
  (String, double) claimSeason(int t) {
    if (!seasonReady(t)) return ('', 0.0);
    sClaimed.add(t);
    final r = seasonReward(t);
    switch (r.$1) {
      case 'gems': gems += r.$2.toInt(); break;
      case 'coins': final v = math.max(r.$2 * cityMult(city), rate * 60); earn(v); return ('coins', v);
      case 'miles': miles += r.$2; break;
      default: chestsQ.add(r.$1);
    }
    return r;
  }
  int get claimables {
    var n = 0;
    if (missionReady) n++;
    if (starReady) n++;
    for (var i = 0; i < dTasks.length; i++) { if (!dClaimed[i] && dailyDone(i)) n++; }
    for (var i = 0; i < wTasks.length; i++) { if (!wClaimed[i] && weeklyDone(i)) n++; }
    for (final a in achievements) { if (achReady(a)) n++; }
    for (var t = 0; t < seasonTier; t++) { if (!sClaimed.contains(t)) n++; }
    return n;
  }

  // ---------- bônus, roleta, minijogos ----------
  bool get freeReady => nowMs() >= freeAt;
  void claimFree() { if (!freeReady) return; boostUntil = math.max(nowMs(), boostUntil) + 10 * 60000; freeAt = nowMs() + 4 * 3600000; _estimate(); }
  bool buyBoost(int gemsCost, int minutes) { if (gems < gemsCost) return false; gems -= gemsCost; boostUntil = math.max(nowMs(), boostUntil) + minutes * 60000; _estimate(); return true; }
  bool buyTurbo(int gemsCost) { if (gems < gemsCost) return false; gems -= gemsCost; turboUntil = math.max(nowMs(), turboUntil) + 5 * 60000; _estimate(); return true; }
  bool buyRush(int gemsCost) { if (gems < gemsCost) return false; gems -= gemsCost; rushUntil = math.max(nowMs(), rushUntil) + 5 * 60000; _estimate(); return true; }
  bool buyChest(int gemsCost, String type) { if (gems < gemsCost) return false; gems -= gemsCost; chestsQ.add(type); return true; }
  double cashPack(double hours) => math.max(500.0 * cityMult(city), rate * 3600 * hours);
  bool buyCash(int gemsCost, double hours) { if (gems < gemsCost) return false; gems -= gemsCost; earn(cashPack(hours)); return true; }
  bool get spinReady => spinDay != dayKey();
  int spin() { spinDay = dayKey(); return _r.nextInt(wheelPrizes.length); }
  (String, double) applyWheel(int i) {
    final p = wheelPrizes[i];
    switch (p.$1) {
      case 'coins': final v = math.max(p.$2 * cityMult(city), rate * p.$2 / 3); earn(v); return ('coins', v);
      case 'gems': gems += p.$2.toInt(); break;
      case 'miles': miles += p.$2; break;
      case 'boost': boostUntil = math.max(nowMs(), boostUntil) + p.$2.toInt() * 1000; _estimate(); break;
      default: chestsQ.add(p.$1);
    }
    return p;
  }
  static const gameCd = 4 * 60000;
  bool get landReady => nowMs() >= landAt;
  bool get xrayReady => nowMs() >= xrayAt;
  bool get bagReady => nowMs() >= bagAt;
  double gameReward(double secs) => math.max(200.0 * cityMult(city), rate * secs);
  int get landingLevel => (c('landings') ~/ 3).clamp(0, 4);

  // ---------- offline ----------
  double get offlineCapSecs => (hasMgr('gabi') ? 8 * 3600.0 : 4 * 3600.0) + (has('cofre') ? 4 * 3600.0 : 0.0);
  double offlineFor(double secs) { _estimate(); return rate / (boostOn ? 2 : 1) * math.min(secs, offlineCapSecs) * (hasMgr('gabi') ? 1.0 : 0.5); }

  // ---------- diário (login) ----------
  bool get dailyReady => dailyLast != dayKey();
  (String, double) claimDaily() {
    final r = dailyRewards[dailyDay % 7];
    double v = r.$2;
    if (r.$1 == 'coins') { v = math.max(r.$2 * cityMult(city), rate * 60 * (dailyDay % 7 + 1)); earn(v); }
    if (r.$1 == 'gems') gems += r.$2.toInt();
    if (r.$1 == 'boost') { boostUntil = math.max(nowMs(), boostUntil) + r.$2.toInt() * 1000; }
    if (r.$1 == 'chest') chestsQ.add('chest_gold');
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    dailyDay = dailyLast == yesterday || dailyLast == 0 ? dailyDay + 1 : 1;
    dailyLast = dayKey();
    return (r.$1, v);
  }

  // ---------- nova cidade ----------
  bool get canPrestige => star >= 5;
  void prestige() {
    if (!canPrestige) return;
    depositAll();
    city++; money = 60; earnedCity = 0; mission = 0; flightsCity = 0; collectsCity = 0; star = 0;
    gems += 25 + city * 10; inc('city');
    chestsQ.add('chest_gold');
    reset(); _estimate();
  }

  // ---------- salvar ----------
  Map<String, dynamic> toJson() => {
        'v': 2, 'money': money + pilesTotal, 'ec': earnedCity, 'ea': earnedAll, 'gems': gems, 'city': city, 'star': star, 'alv': alv, 'xp': xp, 'miles': miles,
        'lv': lv, 'mgr': mgr.toList(), 'mission': mission, 'fc': flightsCity, 'fa': flightsAll, 'cc': collectsCity, 'dd': dailyDay, 'dl': dailyLast,
        'bu': boostUntil, 'ru': rushUntil, 'tu': turboUntil, 'fr': freeAt, 'ca': chestAt, 'sd': spinDay, 'la': landAt, 'xa': xrayAt, 'ba': bagAt,
        'tut': tut, 'ls': nowMs(), 'bm': buyMode, 'mu': music, 'so': sound, 'vi': vibration, 'au': autoUp,
        'res': research.toList(), 'rot': routesOwned.toList(), 'ach': achClaimed.toList(), 'cards': cards, 'mlv': mlv, 'cnt': cnt,
        'dk': dKey, 'wk': wKey, 'db': dBase, 'wb': wBase, 'dt': dTasks, 'wt': wTasks, 'dc': dClaimed, 'wc': wClaimed, 'dbo': dBonus,
        'si': sId, 'sp': sPts, 'sc': sClaimed.toList(), 'cq': chestsQ,
      };
  void loadJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    Map<String, double> md(String k) => {for (final e in ((j[k] as Map?) ?? {}).entries) e.key as String: (e.value as num).toDouble()};
    Map<String, int> mi(String k) => {for (final e in ((j[k] as Map?) ?? {}).entries) e.key as String: (e.value as num).toInt()};
    List<String> ls0(String k) => ((j[k] as List?) ?? []).cast<String>();
    money = d('money', 60); earnedCity = d('ec', 0); earnedAll = d('ea', 0); gems = i('gems', 10); city = i('city', 0); star = i('star', 0);
    alv = i('alv', 1); xp = d('xp', 0); miles = d('miles', 0);
    final l = (j['lv'] as Map?) ?? {};
    for (final s in stations) { if (l[s.id] != null) lv[s.id] = (l[s.id] as num).toInt(); }
    mgr..clear()..addAll(ls0('mgr'));
    mission = i('mission', 0); flightsCity = i('fc', 0); flightsAll = i('fa', 0); collectsCity = i('cc', 0); dailyDay = i('dd', 0); dailyLast = i('dl', 0);
    boostUntil = i('bu', 0); rushUntil = i('ru', 0); turboUntil = i('tu', 0); freeAt = i('fr', 0); chestAt = i('ca', 0); spinDay = i('sd', 0);
    landAt = i('la', 0); xrayAt = i('xa', 0); bagAt = i('ba', 0); tut = i('tut', 0);
    ls = i('ls', 0); buyMode = i('bm', 1); music = j['mu'] as bool? ?? true; sound = j['so'] as bool? ?? true; vibration = j['vi'] as bool? ?? true; autoUp = j['au'] as bool? ?? false;
    research..clear()..addAll(ls0('res')); routesOwned..clear()..addAll(ls0('rot')); achClaimed..clear()..addAll(ls0('ach'));
    cards..clear()..addAll(mi('cards'));
    final m0 = mi('mlv'); if (m0.isNotEmpty) { mlv..clear()..addAll(m0); }
    cnt..clear()..addAll(md('cnt'));
    dKey = i('dk', 0); wKey = i('wk', -1); dBase = md('db'); wBase = md('wb');
    dTasks = ((j['dt'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
    wTasks = ((j['wt'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
    dClaimed = ((j['dc'] as List?) ?? []).cast<bool>().toList(); wClaimed = ((j['wc'] as List?) ?? []).cast<bool>().toList();
    if (dTasks.length != 5 || dClaimed.length != 5) dKey = 0;
    if (wTasks.length != 3 || wClaimed.length != 3) wKey = -1;
    dBonus = j['dbo'] as bool? ?? false;
    sId = i('si', -1); sPts = i('sp', 0); sClaimed..clear()..addAll(((j['sc'] as List?) ?? []).map((e) => (e as num).toInt()));
    chestsQ..clear()..addAll(ls0('cq'));
    ensurePeriods();
    _estimate();
  }
}
