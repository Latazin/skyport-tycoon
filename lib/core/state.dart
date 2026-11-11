import 'dart:math' as math;

import 'data.dart';
import 'paths.dart';

int nowMs() => DateTime.now().millisecondsSinceEpoch;
int dayKey([DateTime? d]) { final t = d ?? DateTime.now(); return t.year * 10000 + t.month * 100 + t.day; }

/// Efeitos que a interface implementa (o estado só avisa).
abstract class Fx {
  void banner(String title, String sub);
  void toast(String msg);
  void sfx(String name, {double pitch = 1});
  void confetti([int n = 60]);
  void flightPaid(int gate, double amount, int pax);
  void stationUp(String id, int from, int to);
}

/// Fases do ciclo de um portão.
class Ph {
  static const empty = 0, landing = 1, taxiIn = 2, boarding = 3, pushback = 4, taxiOut = 5, hold = 6, takeoff = 7;
  static const names = ['Livre', 'Pousando', 'Taxiando', 'Embarcando', 'Pushback', 'Taxiando', 'Aguardando pista', 'Decolando'];
}

/// Estado do portão em tempo de execução (não é salvo).
class GateRt {
  int phase = Ph.empty;
  double t = 0, dur = 1.5;
  double boarded = 0;
  int seats = 30, tier = 0, liv = 0;
  double ticket = 3;
  bool paid = false;
  String flight = '', dest = '';
  double get k => dur <= 0 ? 1.0 : (t / dur).clamp(0.0, 1.0).toDouble();
}

class GameState {
  // ---------- salvo ----------
  double money = 60, earnedCity = 0, earnedAll = 0;
  int gems = 10, city = 0;
  final Map<String, int> lv = {};
  final Set<String> mgr = {};
  int mission = 0, flightsCity = 0, flightsAll = 0;
  int dailyDay = 0, dailyLast = 0;
  int boostUntil = 0, freeAt = 0, landAt = 0, xrayAt = 0, giftAt = 0;
  int tut = 0, ls = 0, buyMode = 1;
  bool music = true, sound = true, vibration = true;

  // ---------- execução ----------
  Fx? fx;
  final List<GateRt> gates = List.generate(6, (_) => GateRt());
  double qc = 0, qs = 0, lounge = 0;
  int runway = -1; // portão usando a pista
  int? gift; // portão onde apareceu o presente VIP
  double clock = 0, rate = 0;
  String bottleneck = 'entrada';
  final _r = math.Random();
  int _flightNo = 100;

  GameState() { reset(); }

  void reset() {
    lv..clear()..addAll({for (final s in stations) s.id: 0});
    for (final id in ['entrada', 'checkin', 'seguranca', 'g0', 'pista', 'torre']) { lv[id] = 1; }
    mgr.clear();
    for (final g in gates) { g.phase = Ph.empty; g.t = 0; g.dur = 1 + _r.nextDouble() * 2; }
    qc = qs = lounge = 0; runway = -1; gift = null;
  }

  // ---------- consultas ----------
  int lvl(String id) => lv[id] ?? 0;
  bool built(String id) => lvl(id) > 0;
  bool hasMgr(String id) => mgr.contains(id);
  bool get boostOn => nowMs() < boostUntil;
  static const maxL = 500;

  double cost(St s, int l) => s.base * math.pow(s.growth, l - 1);
  /// Quantos níveis comprar no modo atual e o custo total.
  (int, double) buyInfo(St s, [int? mode]) {
    final m = mode ?? buyMode, l = lvl(s.id);
    if (s.oneTime || l <= 0 || l >= maxL) return (0, 0);
    var n = 0; var total = 0.0;
    final cap = m == -1 ? maxL : m;
    while (n < cap && l + n < maxL) {
      final c = cost(s, l + n);
      if (m == -1 && total + c > money) break;
      total += c; n++;
    }
    if (m == -1 && n == 0) return (1, cost(s, l));
    return (n, total);
  }
  bool canUp(St s) { final b = buyInfo(s, 1); return b.$1 > 0 && money >= b.$2; }
  bool canUnlock(St s) => !built(s.id) && money >= s.unlock && unlockOk(s);
  /// Portões abrem em ordem.
  bool unlockOk(St s) => s.kind != Kind.gate || s.gate == 0 || built('g${s.gate - 1}');

  double get speed => (1 + 0.035 * (lvl('pista') - 1)).clamp(1.0, 4.0).toDouble() * (hasMgr('diego') ? 1.3 : 1.0);
  double get lambda => 0.5 * power(lvl('entrada')) * (hasMgr('carla') ? 2 : 1);
  double get muC => 0.6 * power(lvl('checkin')) * (hasMgr('ana') ? 2 : 1);
  double get muS => 0.55 * power(lvl('seguranca')) * (hasMgr('bruno') ? 2 : 1);
  double get shopSpend { final l = lvl('lojas'); return l > 0 ? 0.4 * l * math.pow(1.6, milestonesPassed(l)) * (hasMgr('elisa') ? 3 : 1) : 0.0; }
  double get revMult => cityMult(city) * (1 + 0.06 * (lvl('torre') - 1)) * (built('hangar') ? 1.5 : 1) * (built('combustivel') ? 1.5 : 1) * (hasMgr('hugo') ? 2 : 1) * (boostOn ? 2 : 1);

  int tierFor(int g) => math.min(gateTier(lvl('g$g')), runwayTier(lvl('pista')));
  double seatsFor(int g) { final l = lvl('g$g'); return planeTypes[tierFor(g)].seats * (1 + 0.02 * (l - 1)); }
  double ticketFor(int g) {
    final l = lvl('g$g');
    return 4 * (1 + 0.2 * (l - 1)) * math.pow(2, milestonesPassed(l)) * planeTypes[tierFor(g)].ticketMul * (1 + 0.04 * lvl('vip')) * (hasMgr('fabio') ? 1.5 : 1);
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

  /// Vazão estimada (passageiros/s) e gargalo.
  double get throughput {
    var cap = 0.0; for (var g = 0; g < 6; g++) { cap += gateCap(g); }
    return [lambda, muC, muS, cap].reduce(math.min);
  }
  void _estimate() {
    var cap = 0.0, wt = 0.0;
    for (var g = 0; g < 6; g++) { final c = gateCap(g); cap += c; wt += c * ticketFor(g); }
    final vals = {'entrada': lambda, 'checkin': muC, 'seguranca': muS, 'gates': cap};
    var best = 'entrada';
    vals.forEach((k, v) { if (v < vals[best]!) best = k; });
    bottleneck = best;
    final thr = vals[best]!;
    final avg = cap > 0 ? wt / cap : 0.0;
    rate = thr * (avg + shopSpend) * revMult;
  }
  double get queueCapC => 14.0 + 6 * desksFor(lvl('checkin'));
  double get queueCapS => 14.0 + 6 * lanesFor(lvl('seguranca'));
  double get loungeCap => 30.0 + 40 * gatesOpen + 0.3 * gates.fold(0.0, (a, g) => a + g.seats);
  bool get qcFull => qc >= queueCapC * 0.95;
  bool get qsFull => qs >= queueCapS * 0.95;

  // ---------- dinheiro ----------
  void earn(double v) { money += v; earnedCity += v; earnedAll += v; }
  bool spend(double v) { if (money + 1e-9 < v) return false; money -= v; return true; }

  bool upgrade(String id) {
    final s = stationById(id); final b = buyInfo(s);
    if (b.$1 <= 0 || !spend(b.$2)) { fx?.sfx('nope'); return false; }
    final from = lvl(id); lv[id] = from + b.$1;
    _estimate();
    fx?.stationUp(id, from, from + b.$1);
    return true;
  }
  bool unlock(String id) {
    final s = stationById(id);
    if (built(id) || !unlockOk(s) || !spend(s.unlock)) { fx?.sfx('nope'); return false; }
    lv[id] = 1;
    if (s.kind == Kind.gate) { gates[s.gate]..phase = Ph.empty..t = 0..dur = 1; }
    _estimate();
    fx?.stationUp(id, 0, 1);
    return true;
  }
  bool hire(Manager m) {
    if (hasMgr(m.id) || !spend(m.cost * cityMult(city) / (city == 0 ? 1 : 2))) { fx?.sfx('nope'); return false; }
    mgr.add(m.id); _estimate(); return true;
  }
  double mgrCost(Manager m) => m.cost * cityMult(city) / (city == 0 ? 1 : 2);

  // ---------- simulação ----------
  double _acc = 0;
  void tick(double dt) {
    clock += dt;
    _acc += dt;
    if (_acc > 0.5) { _acc = 0; _estimate(); }
    // fluxo de passageiros (contagens contínuas)
    qc = math.min(queueCapC, qc + lambda * dt);
    var c = math.min(qc, muC * dt); c = math.min(c, math.max(0.0, queueCapS - qs));
    qc -= c; qs += c;
    var sv = math.min(qs, muS * dt); sv = math.min(sv, math.max(0.0, loungeCap - lounge));
    qs -= sv; lounge += sv;
    if (sv > 0 && shopSpend > 0) earn(sv * shopSpend * revMult);
    for (var g = 0; g < 6; g++) { if (built('g$g')) _gateTick(g, dt); }
    // presente VIP
    final now = nowMs();
    if (giftAt == 0) giftAt = now + 90000;
    if (gift == null && now >= giftAt) {
      final open = [for (var g = 0; g < 6; g++) if (built('g$g')) g];
      gift = open[_r.nextInt(open.length)];
    }
  }

  void _gateTick(int g, double dt) {
    final G = gates[g];
    G.t += dt;
    switch (G.phase) {
      case Ph.empty:
        if (G.t >= G.dur && runway < 0) { _start(g, Ph.landing); runway = g; }
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
          if (G.boarded < 1 && G.t < G.dur + 20) break; // espera alguém embarcar
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
        if (runway < 0) { runway = g; _start(g, Ph.takeoff); }
        break;
      case Ph.takeoff:
        if (!G.paid && G.t >= G.dur * 0.62) {
          G.paid = true;
          final pax = G.boarded.round();
          final amount = G.boarded * G.ticket * revMult;
          if (pax > 0) { earn(amount); flightsCity++; flightsAll++; fx?.flightPaid(g, amount, pax); }
        }
        if (G.t >= G.dur * 0.75 && runway == g) runway = -1;
        if (G.t >= G.dur) { G.phase = Ph.empty; G.t = 0; G.dur = durTurn(); }
        break;
    }
  }

  void _start(int g, int ph) {
    final G = gates[g];
    G.phase = ph; G.t = 0;
    switch (ph) {
      case Ph.landing:
        G.tier = tierFor(g); G.seats = seatsFor(g).round(); G.ticket = ticketFor(g); G.boarded = 0; G.paid = false;
        G.liv = _r.nextInt(3); G.dest = destinations[_r.nextInt(destinations.length)];
        G.flight = '${['SP', 'LA', 'VL'][G.liv]} ${_flightNo++}';
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
  /// Toque no avião: adianta a fase atual.
  void hurry(int g, double secs) { final G = gates[g]; if (G.phase == Ph.hold || G.phase == Ph.empty) return; G.t = math.min(G.dur, G.t + secs); }

  // ---------- presente, bônus e minijogos ----------
  double get giftCoins => math.max(150.0 * cityMult(city), rate * 90);
  (bool, double) openGift() {
    gift = null; giftAt = nowMs() + 150000 + _r.nextInt(110000);
    if (_r.nextDouble() < 0.3) { final n = 2 + _r.nextInt(4); gems += n; return (true, n.toDouble()); }
    final v = giftCoins; earn(v); return (false, v);
  }
  bool get freeReady => nowMs() >= freeAt;
  void claimFree() { if (!freeReady) return; boostUntil = math.max(nowMs(), boostUntil) + 10 * 60000; freeAt = nowMs() + 4 * 3600000; _estimate(); }
  bool buyBoost(int gemsCost, int minutes) { if (gems < gemsCost) return false; gems -= gemsCost; boostUntil = math.max(nowMs(), boostUntil) + minutes * 60000; _estimate(); return true; }
  double cashPack(double hours) => math.max(500.0 * cityMult(city), rate * 3600 * hours);
  bool buyCash(int gemsCost, double hours) { if (gems < gemsCost) return false; gems -= gemsCost; earn(cashPack(hours)); return true; }
  static const gameCd = 4 * 60000;
  bool get landReady => nowMs() >= landAt;
  bool get xrayReady => nowMs() >= xrayAt;
  double gameReward(double secs) => math.max(200.0 * cityMult(city), rate * secs);

  // ---------- offline ----------
  double get offlineCapSecs => hasMgr('gabi') ? 8 * 3600.0 : 4 * 3600.0;
  double offlineFor(double secs) { _estimate(); return rate / (boostOn ? 2 : 1) * math.min(secs, offlineCapSecs) * (hasMgr('gabi') ? 1.0 : 0.5); }

  // ---------- missões ----------
  bool get missionsDone => mission >= missionList.length;
  Mission get curMission => missionList[math.min(mission, missionList.length - 1)];
  (double, double) missionProgress([Mission? m]) {
    m ??= curMission;
    switch (m.type) {
      case 'lvl': return (lvl(m.target).toDouble(), m.n);
      case 'unlock': return (built(m.target) ? 1.0 : 0.0, 1.0);
      case 'flights': return (flightsCity.toDouble(), m.n);
      case 'manager': return (mgr.length.toDouble(), m.n);
    }
    return (0.0, 1.0);
  }
  bool get missionReady { if (missionsDone) return false; final p = missionProgress(); return p.$1 >= p.$2; }
  int get missionGems => 3 + mission ~/ 4;
  double get missionCoins => math.max(80.0 * cityMult(city), rate * 45);
  void claimMission() {
    if (!missionReady) return;
    gems += missionGems; earn(missionCoins); mission++;
  }
  String missionText([Mission? m]) {
    m ??= curMission;
    switch (m.type) {
      case 'lvl': return '${stationById(m.target).name} no nível ${m.n.toInt()}';
      case 'unlock': return 'Construa: ${stationById(m.target).name}';
      case 'flights': return 'Faça ${m.n.toInt()} voos';
      case 'manager': return 'Contrate ${m.n.toInt()} gerentes';
    }
    return '';
  }

  // ---------- diário ----------
  bool get dailyReady => dailyLast != dayKey();
  (String, double) claimDaily() {
    final r = dailyRewards[dailyDay % 7];
    double v = r.$2;
    if (r.$1 == 'coins') { v = math.max(r.$2 * cityMult(city), rate * 60 * (dailyDay % 7 + 1)); earn(v); }
    if (r.$1 == 'gems') gems += r.$2.toInt();
    if (r.$1 == 'boost') { boostUntil = math.max(nowMs(), boostUntil) + r.$2.toInt() * 1000; }
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    dailyDay = dailyLast == yesterday || dailyLast == 0 ? dailyDay + 1 : 1;
    dailyLast = dayKey();
    return (r.$1, v);
  }

  // ---------- nova cidade (prestígio) ----------
  bool get canPrestige => earnedCity >= cityTarget(city);
  double get prestigeProgress => (earnedCity / cityTarget(city)).clamp(0.0, 1.0).toDouble();
  void prestige() {
    if (!canPrestige) return;
    city++; money = 60; earnedCity = 0; mission = 0; flightsCity = 0;
    gems += 25 + city * 10;
    reset(); _estimate();
  }

  // ---------- salvar ----------
  Map<String, dynamic> toJson() => {
        'v': 1, 'money': money, 'ec': earnedCity, 'ea': earnedAll, 'gems': gems, 'city': city, 'lv': lv, 'mgr': mgr.toList(),
        'mission': mission, 'fc': flightsCity, 'fa': flightsAll, 'dd': dailyDay, 'dl': dailyLast, 'bu': boostUntil, 'fr': freeAt,
        'la': landAt, 'xa': xrayAt, 'ga': giftAt, 'tut': tut, 'ls': nowMs(), 'bm': buyMode, 'mu': music, 'so': sound, 'vi': vibration,
      };
  void loadJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    money = d('money', 60); earnedCity = d('ec', 0); earnedAll = d('ea', 0); gems = i('gems', 10); city = i('city', 0);
    final l = (j['lv'] as Map?) ?? {};
    for (final s in stations) { if (l[s.id] != null) lv[s.id] = (l[s.id] as num).toInt(); }
    mgr..clear()..addAll(((j['mgr'] as List?) ?? []).cast<String>());
    mission = i('mission', 0); flightsCity = i('fc', 0); flightsAll = i('fa', 0); dailyDay = i('dd', 0); dailyLast = i('dl', 0);
    boostUntil = i('bu', 0); freeAt = i('fr', 0); landAt = i('la', 0); xrayAt = i('xa', 0); giftAt = i('ga', 0); tut = i('tut', 0);
    ls = i('ls', 0); buyMode = i('bm', 1); music = j['mu'] as bool? ?? true; sound = j['so'] as bool? ?? true; vibration = j['vi'] as bool? ?? true;
    _estimate();
  }
  void estimate() => _estimate();
}
