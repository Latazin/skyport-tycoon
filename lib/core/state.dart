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
  void phaseUp(int phase);
  void arrivals(int gate, int pax);
  void special(String kind, int gate);
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
  // controle de tráfego visual: o mundo avisa quando há avião na frente
  bool blocked = false;
  double vf = 1, blockT = 0;
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
  int boostUntil = 0, rushUntil = 0, turboUntil = 0, freeAt = 0, chestAt = 0, spinDay = 0, landAt = 0, xrayAt = 0, bagAt = 0, atcAt = 0, yardAt = 0;
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
  final Set<String> decor = {};
  final Map<String, int> abilAt = {}, abilUntil = {};
  // prédio exclusivo e rede de aeroportos
  double hotelPile = 0, netPile = 0, heliNext = 60, waveNext = 90, waveUntil = 0;
  bool heliOn = false;
  // contrato com companhia aérea
  int ctAir = -1, ctNeed = 0, ctUntil = 0, ctGems = 0, ctBase = 0, ctNext = 0;
  // fim de semana
  int wkEnd = 0, wkBase = 0;
  bool wkClaimed = false;

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
  int get phase => phaseFor(city, star);
  Phase get ph => phases[phase];
  CityPerk get perk => perkFor(city);
  bool abilOn(String m) => nowMs() < (abilUntil[m] ?? 0);
  bool get weekend => DateTime.now().weekday >= DateTime.saturday;
  double get decorMult => 1 + 0.03 * decor.length;
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
  bool here(St s) => s.only < 0 || s.only == city % 6;
  bool starOk(St s) => here(s) && star >= s.star;
  /// Nível do prédio exclusivo desta cidade.
  int get esp => lvl('esp${city % 6}');
  int get kind6 => city % 6;
  bool get snow => kind6 == 3;
  /// Hotel: diária por segundo.
  double get hotelRate => kind6 == 1 && esp > 0 ? rate * (0.10 + 0.02 * esp) : 0;
  double get intlChance => kind6 == 2 && esp > 0 ? math.min(0.6, 0.10 + 0.02 * esp) : 0;
  double get snowSpeed => !snow ? 1 : math.min(1.3, 0.6 + 0.035 * esp);
  double get heliEvery => math.max(35.0, 100.0 - 2.5 * esp);
  double get heliValue => math.max(rate * 45, 200.0 * cityMult(city)) * (1 + 0.1 * esp);
  double get waveSecs => math.min(60.0, 10.0 + 1.5 * esp);
  double get netRate => city <= 0 ? 0 : rate * 0.2 * city;
  static const netCap = 7200.0;
  bool unlockOk(St s) {
    if (!starOk(s)) return false;
    if (s.kind == Kind.gate) return s.gate == 0 || built('g${s.gate - 1}');
    if (s.kind == Kind.shop) { final i = shopIds.indexOf(s.id); return i == 0 || built(shopIds[i - 1]); }
    return true;
  }
  List<int> get shopsBuilt => [for (var i = 0; i < shopIds.length; i++) if (built(shopIds[i])) i];
  double shopSpendOf(int i) { final l = lvl(shopIds[i]); return l > 0 ? shopBase[i] * l * math.pow(1.6, milestonesPassed(l)).toDouble() : 0; }
  bool canUnlock(St s) => !built(s.id) && money >= s.unlock && unlockOk(s);

  // ---------- multiplicadores ----------
  double get speed => (1 + 0.035 * (lvl('pista') - 1)).clamp(1.0, 4.0).toDouble() * (hasMgr('diego') ? 1.3 : 1.0) * (has('embarque') ? 1.15 : 1.0) * (turboOn ? 2.0 : 1.0) * snowSpeed * (built('bombeiros') ? 1.15 : 1.0);
  double get lambda => 0.5 * power(lvl('entrada')) * (hasMgr('carla') ? 2 : 1) * (has('expresso') ? 1.5 : 1) * (rushOn || clock < waveUntil ? 3 : 1) * perk.lambda * (weekend ? 1.25 : 1) * (built('trem') ? 1.5 : 1);
  double get muC => 0.6 * power(lvl('checkin')) * (hasMgr('ana') ? 2 : 1) * (has('online') ? 1.5 : 1) * (has('bio') ? 2 : 1) * (abilOn('ana') ? 3 : 1);
  double get muS => 0.55 * power(lvl('seguranca')) * (hasMgr('bruno') ? 2 : 1) * (has('scan') ? 1.5 : 1) * (has('bio') ? 2 : 1) * (abilOn('bruno') ? 3 : 1);
  double get shopSpend { var t = 0.0; for (var i = 0; i < shopIds.length; i++) { t += shopSpendOf(i); } return t * (hasMgr('elisa') ? 3 : 1) * (has('premium') ? 2 : 1) * perk.shop * (abilOn('elisa') ? 5 : 1) * (kind6 == 0 ? 1 + 0.06 * esp : 1); }
  double get starMult => math.pow(2, star).toDouble();
  double get tipMult => 0.85 + sat / 100 * 0.3;
  double get revMult => cityMult(city) * (1 + 0.06 * (lvl('torre') - 1)) * (built('hangar') ? 1.5 : 1) * (built('combustivel') ? 1.5 : 1) * (hasMgr('hugo') ? 2 : 1) * (boostOn ? 2 : 1) * starMult * (has('verde') ? 1.5 : 1) * (has('mega') ? 2 : 1) * tipMult * decorMult * (1 + 0.05 * lvl('cargas')) * (abilOn('hugo') ? 3 : 1) * (frenzyOn ? 2 : 1) * (tripleOn ? 3 : 1) * (built('radar') ? 1.15 : 1) * (built('solar') ? 1.4 : 1);
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
    return 4 * (1 + 0.2 * (l - 1)) * math.pow(2, milestonesPassed(l)) * planeTypes[t].ticketMul * (1 + 0.04 * lvl('vip')) * (hasMgr('fabio') ? 1.5 : 1) * (has('tarifa') ? 1.3 : 1) * (1 + routeBonus) * (1 + fleetBonus(t)) * perk.ticket * (abilOn('fabio') ? 2 : 1) * (built('catering') ? 1.3 : 1);
  }
  double boardRate(double seats) => math.max(4.0, seats / 5);
  double durLanding() => 7 / speed;
  double durTakeoff() => 7 / speed;
  double durPush() => 4 / speed;
  double durTurn() => 2 / speed;
  double durTaxi(double len) => len / (8 * speed);
  double cycle(int g) {
    final seats = seatsFor(g), tier = tierFor(g);
    return durLanding() + durTaxi(Routes.taxiInLen(g, tier, phase)) + seats / boardRate(seats) + 1 + durPush() + durTaxi(Routes.taxiOutLen(g, phase)) + durTakeoff() + durTurn();
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
  void earn(double v) { money += v; earnedCity += v; earnedAll += v; _histEarned += v; if (tut >= 7) piggy = math.min(piggyCap, piggy + v * 0.15); }

  // ---------- frenesi, cofrinho, passageiro dourado e oferta relâmpago ----------
  double frenzy = 0, frenzyUntil = 0, piggy = 0;
  int offerUntil = 0, offerNext = 0, offerKind = 0, adsToday = 0, adsDay = 0;
  bool get frenzyOn => clock < frenzyUntil;
  double get piggyCap => math.max(rate * 1500, 500.0 * cityMult(city));
  bool get piggyFull => piggy >= piggyCap * 0.999;
  /// Cada toque útil enche a barra; cheia, a receita dobra por 20 s.
  void addFrenzy(double v) {
    if (frenzyOn || tut < 7) return;
    frenzy += v;
    if (frenzy >= 1) { frenzy = 0; frenzyUntil = clock + 20; inc('frenzy'); _estimate(); fx?.special('frenzy', 0); }
  }
  double breakPiggy() { final v = piggy; if (v <= 0) return 0; piggy = 0; money += v; earnedCity += v; earnedAll += v; inc('piggy'); return v; }
  /// Passageiro dourado: devolve (moedas, gemas).
  (double, int) goldTap() {
    inc('gold'); addFrenzy(0.15);
    if (_r.nextDouble() < 0.2) { gems += 2; return (0.0, 2); }
    final v = math.max(rate * 25, 40.0 * cityMult(city)); earn(v); return (v, 0);
  }
  static const offerNames = ['Lucro x3 por 5 minutos', 'Baú de ouro', 'Rush de passageiros por 10 minutos'];
  static const offerGems = [8, 20, 6];
  bool get offerOn => nowMs() < offerUntil;
  void _offerTick() {
    if (tut < 7 || offerOn) return;
    if (offerNext == 0) offerNext = nowMs() + 4 * 60000;
    if (nowMs() >= offerNext) { offerKind = _r.nextInt(3); offerUntil = nowMs() + 3 * 60000; offerNext = offerUntil + (18 + _r.nextInt(10)) * 60000; fx?.special('offer', 0); }
  }
  /// Entrega a oferta (paga com gemas ou anúncio; quem chama cobra).
  void grantOffer() {
    switch (offerKind) {
      case 0: tripleUntil = math.max(nowMs(), tripleUntil) + 5 * 60000; break;
      case 1: chestsQ.add('chest_gold'); break;
      case 2: rushUntil = math.max(nowMs(), rushUntil) + 10 * 60000; break;
    }
    offerUntil = 0; inc('offers'); _estimate();
  }
  int tripleUntil = 0;
  bool get tripleOn => nowMs() < tripleUntil;
  void adWatched() { if (adsDay != dayKey()) { adsDay = dayKey(); adsToday = 0; } adsToday++; inc('ads'); sPts += 5; }
  bool spend(double v) { if (money + 1e-9 < v) return false; money -= v; return true; }
  double get pilesTotal => pile.fold(0.0, (a, b) => a + b) + shopPile;

  String _gainText(String id, double before, double after) {
    final d = after - before;
    if (d <= 0) return '';
    if (id.startsWith('esp')) return const ['+6% lojas', '+diária', '+2% voos 3x', '+velocidade', '+helicópteros', '+1,5 s de onda'][int.parse(id.substring(3))];
    if (shopIds.contains(id)) return '+\$${_short(d * revMult)}/pax';
    switch (id) {
      case 'entrada': case 'checkin': case 'seguranca': return '+${_short(d * 60)} pax/min';

      case 'pista': return '+${(d * 100).round()}% velocidade';
      case 'torre': case 'vip': case 'cargas': return '+${(d * 100).round()}% receita';
    }
    return '+\$${_short(d * revMult)}/passagem';
  }
  double _statOf(String id) {
    switch (id) {
      case 'entrada': return lambda;
      case 'checkin': return muC;
      case 'seguranca': return muS;

      case 'pista': return speed;
      case 'torre': return 1 + 0.06 * (lvl('torre') - 1);
      case 'vip': return 1 + 0.04 * lvl('vip');
      case 'cargas': return 1 + 0.05 * lvl('cargas');
    }
    if (id.startsWith('esp')) return lvl(id).toDouble();
    if (shopIds.contains(id)) return shopSpend;
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
    mgr.add(m.id); if (tut == 6) { tut = 7; chestsQ.add('chest_gold'); giftAt = nowMs() + 30000; } _estimate(); return true;
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
      // baú só nos níveis marcantes (a cada 5); nos outros, só gemas — menos baú na tela
      if (alv % 5 == 0) chestsQ.add(alv % 10 == 0 ? 'chest_epic' : 'chest_gold');
      gems += 2 + alv ~/ 4;
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
    addFrenzy(0.1);
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
    if (_acc == 0) { _ctTick(); _wkTick(); _offerTick(); }
    if (frenzy > 0 && !frenzyOn) frenzy = math.max(0, frenzy - dt * 0.012);
    _specialTick(dt);
    _histAcc += dt;
    if (_histAcc >= 30) { _histAcc = 0; history.add(_histEarned); _histEarned = 0; if (history.length > 20) history.removeAt(0); }
    if (autoUp && has('auto')) { _autoT += dt; if (_autoT > 1.2) { _autoT = 0; final b = bestBuy(); if (b != null && money >= b.$2) buyBest(); } }
  }
  void _satTick() {
    final t = (80 - (qcFull ? 15 : 0) - (qsFull ? 15 : 0) - (lounge >= loungeCap * 0.95 ? 10 : 0) + (shopsBuilt.length * 3.0) + (built('vip') ? 7 : 0) + cleanersFor(lvl('checkin')) * 4.0).clamp(30.0, 100.0);
    sat += (t - sat) * 0.08;
  }

  void _gateTick(int g, double dt) {
    final G = gates[g];
    final moving = G.phase == Ph.taxiIn || G.phase == Ph.pushback || G.phase == Ph.taxiOut;
    if (moving) {
      if (G.blocked) { G.blockT += dt; } else { G.blockT = 0; }
      final want = G.blocked && G.blockT < 10 ? 0.0 : 1.0;
      G.vf += (want - G.vf) * math.min(1.0, dt * 3.5);
      if (want > 0 && G.vf > 0.97) G.vf = 1;
      G.t += dt * G.vf;
    } else {
      G.vf = 1; G.blockT = 0;
      G.t += dt;
    }
    switch (G.phase) {
      case Ph.empty:
        if (G.t >= G.dur && runway < 0 && !fogOn) { _start(g, Ph.landing); runway = g; }
        break;
      case Ph.landing:
        if (G.t >= G.dur) { if (runway == g) runway = -1; _start(g, Ph.taxiIn); }
        break;
      case Ph.taxiIn:
        if (G.t >= G.dur) {
          _start(g, Ph.boarding);
          // desembarque: quem chegou passa pelas lojas antes de sair
          final arr = (G.seats * (0.55 + _r.nextDouble() * 0.35)).round();
          if (shopSpend > 0) { if (shopPile <= 0) shopPileT = clock; shopPile += arr * shopSpend * 0.35 * revMult; }
          fx?.arrivals(g, arr);
        }
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
          final intl = !G.vip && intlChance > 0 && _r.nextDouble() < intlChance;
          final amount = G.boarded * G.ticket * revMult * (G.vip ? 10 : 1) * (intl ? 3 : 1);
          if (intl) { inc('intl'); fx?.special('intl', g); }
          if (pax > 0) {
            if (pile[g] <= 0) pileT[g] = clock;
            pile[g] += amount; flightsCity++; flightsAll++; inc('flights');
            miles += 1 + G.tier + (G.vip ? 5 : 0);
            addXp(2.0 + G.tier * 2 + (G.vip ? 10 : 0));
            fx?.flightPaid(g, amount, pax, G.vip);
            if (ctAir >= 0 && G.liv == airlines[ctAir].$2) inc('ct');
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
        if (!G.vip && ctAir >= 0 && _r.nextDouble() < 0.45) G.liv = airlines[ctAir].$2;
        final d = destinations; G.dest = d[_r.nextInt(d.length)];
        G.flight = '${G.vip ? 'VIP' : ['SP', 'LA', 'VL', 'OU', 'RX', 'RB'][G.liv]} ${_flightNo++}';
        G.dur = durLanding();
        break;
      case Ph.taxiIn: G.dur = durTaxi(Routes.taxiInLen(g, G.tier, phase)); break;
      case Ph.boarding: G.dur = 14 / speed + 3; break;
      case Ph.pushback: G.dur = durPush(); break;
      case Ph.taxiOut: G.dur = durTaxi(Routes.taxiOutLen(g, phase)); break;
      case Ph.hold: G.dur = 0; break;
      case Ph.takeoff: G.dur = durTakeoff(); break;
    }
  }
  void hurry(int g, double secs) {
    final G = gates[g]; if (G.phase == Ph.hold || G.phase == Ph.empty) return;
    G.t = math.min(G.dur, G.t + secs); inc('taps'); addFrenzy(0.035);
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
    evNext = clock + (70 + _r.nextDouble() * 80) / (has('satelite') ? 2 : 1) / perk.events / (built('radar') ? 1.6 : 1);
    final types = ['vip', 'celeb', 'bag', 'tourists', if (gatesOpen >= 1) 'fog', if (city % 6 == 0) 'tourists', if (city % 6 == 3) 'fog', if (city % 6 == 2) 'vip'];
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
      case 'celeb': ev = null; inc('events'); final v = math.max(rate * 90, 300.0 * cityMult(city)) * (city % 6 == 3 ? 2 : 1); earn(v); return (v, 0, true);
      case 'bag': ev = null; inc('events'); final n = 2 + _r.nextInt(3); gems += n; return (0.0, n, true);
      case 'tourists': ev = null; inc('events'); rushUntil = math.max(nowMs(), rushUntil) + 60000; _estimate(); return (0.0, 0, true);
      case 'fog':
        e.taps++;
        if (e.taps >= 5) { ev = null; inc('events'); final v = math.max(rate * 30, 100.0 * cityMult(city)) * (city % 6 == 3 ? 2 : 1); earn(v); return (v, 0, true); }
        return (0.0, 0, false);
    }
    return (0.0, 0, true);
  }
  int tapVip(int g) { final G = gates[g]; if (!G.vip || G.vipTapped) return 0; G.vipTapped = true; gems += 3; return 3; }

  // ---------- baús e frota ----------
  Loot openChest(String type) {
    final tier = type == 'chest_epic' ? 2 : type == 'chest_gold' ? 1 : 0;
    final gold = tier >= 1;
    final l = Loot();
    l.coins = math.max(rate * const [120, 480, 1500][tier], const [300.0, 1500.0, 6000.0][tier] * cityMult(city));
    l.gems = const [2, 10, 28][tier] + _r.nextInt(const [3, 6, 10][tier]);
    l.miles = const [12.0, 40.0, 120.0][tier];
    final w = const [[62, 27, 9, 2], [40, 35, 20, 5], [10, 40, 35, 15]][tier];
    final n = const [3, 6, 9][tier];
    for (var i = 0; i < n; i++) {
      var roll = _r.nextInt(100), rar = 0;
      while (rar < 3 && roll >= w[rar]) { roll -= w[rar]; rar++; }
      if (tier == 2 && i == 0) rar = 2 + (_r.nextDouble() < 0.35 ? 1 : 0);
      if (tier == 1 && i == 0 && rar < 1) rar = 1;
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

  // ---------- presentes da sessão (intervalos curtos no começo, depois maiores) ----------
  int giftAt = 0, giftN = 0, giftDay = 0;
  static const giftWait = [30, 60, 120, 180, 300, 480, 720, 1200, 1800];
  bool get giftReady => tut >= 7 && nowMs() >= giftAt;
  int get giftLeft => math.max(0, giftAt - nowMs());
  /// Próximo presente: 'coins', 'gems', 'chest', 'chest_gold', 'boost'.
  String get giftKind => const ['coins', 'gems', 'coins', 'chest', 'gems', 'coins', 'chest_gold', 'boost', 'gems', 'chest_epic'][giftN % 10];
  (String, double) claimGift() {
    if (!giftReady) return ('', 0);
    if (giftDay != dayKey()) { giftDay = dayKey(); giftN = 0; }
    final k = giftKind;
    double v = 0;
    switch (k) {
      case 'coins': v = math.max(rate * (45 + giftN * 20), 120.0 * cityMult(city) * (giftN + 1)); earn(v); break;
      case 'gems': v = (3 + giftN).toDouble(); gems += v.toInt(); break;
      case 'boost': v = 600; boostUntil = math.max(nowMs(), boostUntil) + 600000; _estimate(); break;
      default: chestsQ.add(k); v = 1;
    }
    giftN++; inc('gifts');
    giftAt = nowMs() + giftWait[math.min(giftN, giftWait.length - 1)] * 1000;
    return (k, v);
  }
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
    final p0 = phase;
    star++; inc('stars'); sPts += 50; addXp(40); gems += 10 + star * 5;
    chestsQ.add(star >= 4 ? 'chest_gold' : 'chest');
    _estimate();
    if (phase != p0) fx?.phaseUp(phase);
  }

  // ---------- prédio exclusivo e rede ----------
  void _specialTick(double dt) {
    if (hotelRate > 0) hotelPile = math.min(hotelPile + hotelRate * dt, hotelRate * 600);
    if (netRate > 0) netPile = math.min(netPile + netRate * dt, netRate * netCap);
    if (esp <= 0 || tut < 7) return;
    if (kind6 == 4 && !heliOn && clock >= heliNext) { heliOn = true; fx?.special('heli', 0); }
    if (kind6 == 5 && clock >= waveNext) { waveNext = clock + 110; waveUntil = clock + waveSecs; _estimate(); fx?.special('wave', 0); }
  }
  double collectHotel() { final v = hotelPile; if (v <= 0) return 0; hotelPile = 0; earn(v); inc('hotel'); return v; }
  double tapHeli() { if (!heliOn) return 0; heliOn = false; heliNext = clock + heliEvery; final v = heliValue; earn(v); inc('heli'); gems += 1; return v; }
  double collectNet() { final v = netPile; if (v <= 0) return 0; netPile = 0; earn(v); inc('net'); return v; }
  bool get netReady => netRate > 0 && netPile >= netRate * 600;

  // ---------- decoração ----------
  double decorCost(Decor d) => d.cost * cityMult(city);
  bool decorOk(Decor d) => decors.indexOf(d) <= decor.length;
  bool buyDecor(Decor d) { if (decor.contains(d.id) || !decorOk(d) || !spend(decorCost(d))) { fx?.sfx('nope'); return false; } decor.add(d.id); addXp(4); _estimate(); return true; }

  // ---------- habilidades dos gerentes ----------
  List<Ability> get myAbilities => abilities.where((a) => hasMgr(a.mgr)).toList();
  bool abilReady(Ability a) => hasMgr(a.mgr) && nowMs() >= (abilAt[a.mgr] ?? 0);
  int abilLeft(Ability a) => math.max(0, (abilAt[a.mgr] ?? 0) - nowMs());
  /// Usa a habilidade; devolve o texto do efeito.
  String useAbility(Ability a) {
    if (!abilReady(a)) return '';
    abilAt[a.mgr] = nowMs() + (abilityCooldown * 1000).round();
    if (a.secs > 0) abilUntil[a.mgr] = nowMs() + (a.secs * 1000).round();
    inc('abil');
    switch (a.mgr) {
      case 'lia': var tot = 0.0; for (var g = 0; g < 6; g++) { tot += pile[g]; } tot += shopPile; depositAll(); _estimate(); return tot > 0 ? '+\$${_short(tot)}' : 'Tudo recolhido';
      case 'carla': qc = math.min(queueCapC, qc + 20); return '+20 passageiros';
      case 'diego': for (var g = 0; g < 6; g++) { if (built('g$g')) hurry(g, 10); } return 'Voos adiantados';
    }
    _estimate();
    return a.desc;
  }

  // ---------- contratos ----------
  bool get ctActive => ctAir >= 0 && nowMs() < ctUntil;
  int get ctDone => (c('ct') - ctBase).toInt();
  bool get ctReady => ctAir >= 0 && ctDone >= ctNeed;
  bool get ctOfferReady => ctAir < 0 && nowMs() >= ctNext && tut >= 7;
  /// Ofertas do momento (3 companhias, metas diferentes).
  List<(int, int, int, int)> ctOffers() {
    final r = math.Random(dayKey() * 7 + ctNext ~/ 60000);
    final ids = List.generate(airlines.length, (i) => i)..shuffle(r);
    final base = math.max(6, gatesOpen * 6);
    return [for (var k = 0; k < 3; k++) (ids[k], base * (k + 1), 20 + k * 15, 8 + k * 9)];
  }
  void takeContract((int, int, int, int) o) { ctAir = o.$1; ctNeed = o.$2; ctUntil = nowMs() + o.$3 * 60000; ctGems = o.$4; ctBase = c('ct').toInt(); }
  void claimContract() { if (!ctReady) return; gems += ctGems; miles += ctNeed.toDouble(); sPts += 30; chestsQ.add(ctNeed >= 30 ? 'chest_gold' : 'chest'); ctAir = -1; ctNext = nowMs() + 3 * 60000; inc('contracts'); }
  void dropContract() { ctAir = -1; ctNext = nowMs() + 60000; }
  void _ctTick() { if (ctAir >= 0 && !ctReady && nowMs() >= ctUntil) { ctAir = -1; ctNext = nowMs() + 2 * 60000; fx?.toast('O contrato expirou'); } }

  // ---------- fim de semana ----------
  static const wkNeed = 150;
  int get wkDone => (c('flights') - wkBase).toInt();
  void _wkTick() {
    if (!weekend) return;
    final k = daysSinceEpoch() ~/ 7;
    if (wkEnd != k) { wkEnd = k; wkBase = c('flights').toInt(); wkClaimed = false; }
  }
  bool get wkReady => weekend && !wkClaimed && wkDone >= wkNeed;
  void claimWeekend() { if (!wkReady) return; wkClaimed = true; chestsQ.add('chest_gold'); gems += 25; sPts += 60; }

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
  void claimFree() { boostUntil = math.max(nowMs(), boostUntil) + 10 * 60000; _estimate(); }
  bool buyBoost(int gemsCost, int minutes) { if (gems < gemsCost) return false; gems -= gemsCost; boostUntil = math.max(nowMs(), boostUntil) + minutes * 60000; _estimate(); return true; }
  bool buyTurbo(int gemsCost) { if (gems < gemsCost) return false; gems -= gemsCost; turboUntil = math.max(nowMs(), turboUntil) + 5 * 60000; _estimate(); return true; }
  bool buyRush(int gemsCost) { if (gems < gemsCost) return false; gems -= gemsCost; rushUntil = math.max(nowMs(), rushUntil) + 5 * 60000; _estimate(); return true; }
  bool buyChest(int gemsCost, String type) { if (gems < gemsCost) return false; gems -= gemsCost; chestsQ.add(type); return true; }
  double cashPack(double hours) => math.max(500.0 * cityMult(city), rate * 3600 * hours);
  bool buyCash(int gemsCost, double hours) { if (gems < gemsCost) return false; gems -= gemsCost; earn(cashPack(hours)); return true; }
  bool get spinReady => spinDay != dayKey();
  int spin() { spinDay = dayKey(); var r = _r.nextInt(wheelWeights.fold(0, (a, b) => a + b)); for (var i = 0; i < wheelWeights.length; i++) { if (r < wheelWeights[i]) return i; r -= wheelWeights[i]; } return 0; }
  /// Texto do prêmio de cada setor (para desenhar na roleta).
  String wheelLabel(int i) { final p = wheelPrizes[i]; switch (p.$1) { case 'coins': return '\$${_short(math.max(p.$2 * cityMult(city), rate * p.$2 / 3))}'; case 'gems': return '${p.$2.toInt()}'; case 'miles': return '${p.$2.toInt()}'; case 'boost': return 'x2 ${p.$2 ~/ 60}m'; case 'chest_epic': return 'ÉPICO'; } return ''; }
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
  bool get atcReady => nowMs() >= atcAt;
  bool get yardReady => nowMs() >= yardAt;
  double gameReward(double secs) => math.max(200.0 * cityMult(city), rate * secs);
  int get landingLevel => (c('landings') ~/ 3).clamp(0, 4);

  // ---------- offline ----------
  double get offlineCapSecs => (hasMgr('gabi') ? 8 * 3600.0 : 4 * 3600.0) + (has('cofre') ? 4 * 3600.0 : 0.0);
  double offlineFor(double secs) { _estimate(); return rate / (boostOn ? 2 : 1) * math.min(secs, offlineCapSecs) * (hasMgr('gabi') ? 1.0 : 0.5) * (built('solar') ? 1.5 : 1.0); }

  // ---------- diário (login) ----------
  bool get dailyReady => dailyLast != dayKey();
  (String, double) claimDaily() {
    final r = dailyRewards[dailyDay % 7];
    double v = r.$2;
    if (r.$1 == 'coins') { v = math.max(r.$2 * cityMult(city), rate * 60 * (dailyDay % 7 + 1)); earn(v); }
    if (r.$1 == 'gems') gems += r.$2.toInt();
    if (r.$1 == 'boost') { boostUntil = math.max(nowMs(), boostUntil) + r.$2.toInt() * 1000; }
    if (r.$1 == 'chest') chestsQ.add('chest_epic');
    final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));
    dailyDay = dailyLast == yesterday || dailyLast == 0 ? dailyDay + 1 : 1;
    dailyLast = dayKey();
    return (r.$1, v);
  }

  // ---------- nova cidade ----------
  double get nextPrice => airportPrice(city + 1);
  bool get canPrestige => star >= 5 && money + pilesTotal >= nextPrice;
  void prestige() {
    if (!canPrestige) return;
    depositAll();
    hotelPile = 0; heliOn = false; heliNext = clock + 60; waveNext = clock + 90; waveUntil = 0;
    city++; money = 60; earnedCity = 0; mission = 0; flightsCity = 0; collectsCity = 0; star = 0; decor.clear();
    gems += 25 + city * 10; inc('city');
    chestsQ.add('chest_gold');
    reset(); _estimate();
  }

  // ---------- salvar ----------
  Map<String, dynamic> toJson() => {
        'v': 3, 'money': money + pilesTotal, 'ec': earnedCity, 'ea': earnedAll, 'gems': gems, 'city': city, 'star': star, 'alv': alv, 'xp': xp, 'miles': miles,
        'lv': lv, 'mgr': mgr.toList(), 'mission': mission, 'fc': flightsCity, 'fa': flightsAll, 'cc': collectsCity, 'dd': dailyDay, 'dl': dailyLast,
        'bu': boostUntil, 'ru': rushUntil, 'tu': turboUntil, 'fr': freeAt, 'ca': chestAt, 'sd': spinDay, 'la': landAt, 'xa': xrayAt, 'ba': bagAt, 'atc': atcAt, 'yd': yardAt,
        'tut': tut, 'ls': nowMs(), 'bm': buyMode, 'mu': music, 'so': sound, 'vi': vibration, 'au': autoUp,
        'res': research.toList(), 'rot': routesOwned.toList(), 'ach': achClaimed.toList(), 'cards': cards, 'mlv': mlv, 'cnt': cnt,
        'dk': dKey, 'wk': wKey, 'db': dBase, 'wb': wBase, 'dt': dTasks, 'wt': wTasks, 'dc': dClaimed, 'wc': wClaimed, 'dbo': dBonus,
        'si': sId, 'sp': sPts, 'sc': sClaimed.toList(), 'cq': chestsQ, 'gf': [giftAt, giftN, giftDay],
        'pg': piggy, 'on': offerNext, 'tru': tripleUntil, 'hp': hotelPile, 'np': netPile, 'dec': decor.toList(), 'aa': abilAt, 'ct': [ctAir, ctNeed, ctUntil, ctGems, ctBase, ctNext], 'wke': [wkEnd, wkBase, wkClaimed ? 1 : 0],
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
    landAt = i('la', 0); xrayAt = i('xa', 0); bagAt = i('ba', 0); atcAt = i('atc', 0); yardAt = i('yd', 0); tut = i('tut', 0);
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
    final gf = ((j['gf'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
    if (gf.length == 3) { giftAt = gf[0]; giftN = gf[1]; giftDay = gf[2]; }
    decor..clear()..addAll(ls0('dec'));
    piggy = ((j['pg'] as num?) ?? 0).toDouble(); offerNext = ((j['on'] as num?) ?? 0).toInt(); tripleUntil = ((j['tru'] as num?) ?? 0).toInt();
    hotelPile = ((j['hp'] as num?) ?? 0).toDouble(); netPile = ((j['np'] as num?) ?? 0).toDouble();
    abilAt..clear()..addAll(mi('aa'));
    final ct = ((j['ct'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
    if (ct.length == 6) { ctAir = ct[0]; ctNeed = ct[1]; ctUntil = ct[2]; ctGems = ct[3]; ctBase = ct[4]; ctNext = ct[5]; }
    final wk = ((j['wke'] as List?) ?? []).map((e) => (e as num).toInt()).toList();
    if (wk.length == 3) { wkEnd = wk[0]; wkBase = wk[1]; wkClaimed = wk[2] == 1; }
    ensurePeriods();
    _estimate();
  }
}
