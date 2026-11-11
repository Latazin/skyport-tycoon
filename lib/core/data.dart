import 'dart:math' as math;

/// Layout do aeroporto em unidades do mundo (igual ao estúdio de arte, tool/studio/studio.js).
class Lay {
  static const runwayX0 = -74.0, runwayX1 = 54.0, runwayZ = -37.0;
  static const laneZ = -20.0, connL = -46.0, connR = 38.0, holdZ = -31.0;
  static const standNose = -6.4;
  static const gates = [-38.0, -26.0, -14.0, -2.0, 10.0, 22.0];
  static const checkinX0 = -43.0, checkinZ = 8.0, checkinDx = 3.0;
  static const secX0 = -21.5, secZ = 5.0, secDx = 3.4;
  static const shops = [(-3.0, 8.0), (3.5, 8.0), (10.0, 8.0), (16.0, 8.0)];
  static const vip = (28.0, 9.0);
  static const door = (-35.0, 16.0);
  static const roadZ = 20.0;
  static const parking = (-24.0, 30.0);
  static const busStop = (-40.0, 18.4);
  static const tower = (46.0, -3.0);
  static const fuel = (50.0, -15.0);
  static const hangar = (-60.0, -13.0);
  static const floorY = 0.35;
  static const termX0 = -48.0, termX1 = 36.0;
}

/// Aviões: comprimento, lugares base e nome.
class PlaneType {
  final String name;
  final double len;
  final int seats;
  final double ticketMul;
  const PlaneType(this.name, this.len, this.seats, this.ticketMul);
}
const planeTypes = [
  PlaneType('Turboélice', 5.6, 40, 1.0),
  PlaneType('Jato médio', 8.4, 120, 1.6),
  PlaneType('Jato grande', 11.2, 260, 2.4),
];

enum Kind { flow, gate, boost, building }

/// Estação do aeroporto (algo que se melhora).
class St {
  final String id, name, icon, desc;
  final Kind kind;
  final double base, growth, unlock;
  final int gate; // índice do portão (só para Kind.gate)
  const St(this.id, this.name, this.icon, this.desc, this.kind, {this.base = 10, this.growth = 1.13, this.unlock = 0, this.gate = -1});
  bool get oneTime => kind == Kind.building;
}

const stations = [
  St('entrada', 'Estacionamento', 'bus', 'Ônibus, táxis e carros trazem passageiros. Mais nível, mais gente chegando.', Kind.flow, base: 8, growth: 1.16),
  St('checkin', 'Check-in', 'checkin', 'Balcões que atendem e despacham as malas. Abre novos balcões nos níveis 10, 25, 50, 75 e 100.', Kind.flow, base: 11, growth: 1.165),
  St('seguranca', 'Raio-X', 'security', 'Controle de segurança. Abre novas faixas nos níveis 15, 40 e 80.', Kind.flow, base: 14, growth: 1.17),
  St('g0', 'Portão 1', 'plane', 'Cada portão recebe um avião por vez. Nível sobe o preço da passagem; nos níveis 25 e 75 chegam aviões maiores.', Kind.gate, base: 15, growth: 1.17, gate: 0),
  St('g1', 'Portão 2', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 50, growth: 1.17, unlock: 100, gate: 1),
  St('g2', 'Portão 3', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 1e3, growth: 1.17, unlock: 2e3, gate: 2),
  St('g3', 'Portão 4', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 5e4, growth: 1.17, unlock: 1e5, gate: 3),
  St('g4', 'Portão 5', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 1.5e6, growth: 1.17, unlock: 3e6, gate: 4),
  St('g5', 'Portão 6', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 4e7, growth: 1.17, unlock: 8e7, gate: 5),
  St('lojas', 'Praça de Lojas', 'shop', 'Cada passageiro que passa pelo raio-X gasta nas lojas. Abre novos quiosques nos níveis 10, 30 e 60.', Kind.flow, base: 80, growth: 1.18, unlock: 600),
  St('pista', 'Pista', 'runway', 'Aviões mais rápidos em pouso, taxi e decolagem. Nível 10 libera jatos médios; nível 30, jatos grandes.', Kind.boost, base: 60, growth: 1.2),
  St('torre', 'Torre de Controle', 'tower', 'Coordena o tráfego: +6% de receita por nível.', Kind.boost, base: 150, growth: 1.21),
  St('vip', 'Sala VIP', 'crown', 'Passageiros premium: +4% no preço da passagem por nível.', Kind.boost, base: 5e4, growth: 1.2, unlock: 1e5),
  St('hangar', 'Hangar', 'hangar', 'Manutenção própria dos aviões: receita x1,5.', Kind.building, unlock: 1e6),
  St('combustivel', 'Combustível', 'fuel', 'Posto próprio vende querosene a cada voo: receita x1,5.', Kind.building, unlock: 3e7),
];
St stationById(String id) => stations.firstWhere((s) => s.id == id);

/// Marcos: cada um dobra a produção da estação.
const milestones = [10, 25, 50, 100, 150, 200, 300, 400, 500];
int milestonesPassed(int l) => milestones.where((m) => l >= m).length;
int? nextMilestone(int l) { for (final m in milestones) { if (l < m) return m; } return null; }
double power(int l) => l <= 0 ? 0.0 : l * math.pow(2, milestonesPassed(l)).toDouble();

int desksFor(int l) => 1 + [10, 25, 50, 75, 100].where((m) => l >= m).length;
int lanesFor(int l) => 1 + [15, 40, 80].where((m) => l >= m).length;
int shopsFor(int l) => l <= 0 ? 0 : 1 + [10, 30, 60].where((m) => l >= m).length;
int parkTier(int l) => 1 + [10, 25, 50].where((m) => l >= m).length;
int towerTier(int l) => 1 + [15, 40].where((m) => l >= m).length;
int vipTier(int l) => 1 + [10, 30].where((m) => l >= m).length;
int gateTier(int l) => l >= 75 ? 2 : l >= 25 ? 1 : 0;
int runwayTier(int l) => l >= 30 ? 2 : l >= 10 ? 1 : 0;
int aidsTier(int l) => 1 + [10, 30].where((m) => l >= m).length;

/// Cidades (cada nova cidade reinicia o aeroporto com multiplicador maior).
class City {
  final String name, sub;
  final int bg;
  const City(this.name, this.sub, this.bg);
}
const cities = [
  City('Vale Verde', 'Aeroporto regional no interior', 0),
  City('Porto Azul', 'Capital movimentada à beira do rio', 1),
  City('SkyPort Internacional', 'Hub internacional no litoral', 2),
  City('Serra Alta', 'Aeroporto da serra', 0),
  City('Rio Dourado', 'Metrópole do norte', 1),
  City('Costa Esmeralda', 'Paraíso turístico', 2),
];
City cityAt(int i) => i < cities.length ? cities[i] : City('Mega Hub ${i - cities.length + 2}', 'Rota global', i % 3);
double cityMult(int i) => math.pow(6, i).toDouble();
double cityTarget(int i) => 2e9 * math.pow(400, i).toDouble();

/// Gerentes: bônus permanentes no aeroporto atual.
class Manager {
  final String id, name, role, effect;
  final double cost;
  const Manager(this.id, this.name, this.role, this.effect, this.cost);
}
const managers = [
  Manager('ana', 'Ana', 'Chefe de Check-in', 'Check-in 2x mais rápido', 2e3),
  Manager('bruno', 'Bruno', 'Chefe de Segurança', 'Raio-X 2x mais rápido', 6e3),
  Manager('carla', 'Carla', 'Transportes', 'Chegam 2x mais passageiros', 2e4),
  Manager('diego', 'Diego', 'Operações', 'Voos 30% mais rápidos', 1e5),
  Manager('elisa', 'Elisa', 'Comercial', 'Lojas faturam 3x', 5e5),
  Manager('fabio', 'Fábio', 'Bilheteria', 'Passagens 50% mais caras', 3e6),
  Manager('gabi', 'Gabi', 'Plantão', 'Ganhos offline 2x e até 8h', 2e7),
  Manager('hugo', 'Hugo', 'Diretor', 'Receita total 2x', 2e8),
];

/// Missões (sequência por cidade).
class Mission {
  final String type, target;
  final double n;
  const Mission(this.type, this.target, this.n);
}
const missionList = [
  Mission('lvl', 'checkin', 3), Mission('lvl', 'entrada', 3), Mission('lvl', 'g0', 5), Mission('lvl', 'seguranca', 5),
  Mission('unlock', 'g1', 1), Mission('flights', '', 10), Mission('lvl', 'checkin', 10), Mission('unlock', 'lojas', 1),
  Mission('lvl', 'pista', 5), Mission('lvl', 'entrada', 15), Mission('unlock', 'g2', 1), Mission('lvl', 'torre', 5),
  Mission('lvl', 'seguranca', 15), Mission('manager', '', 2), Mission('lvl', 'pista', 10), Mission('lvl', 'g0', 25),
  Mission('unlock', 'vip', 1), Mission('flights', '', 60), Mission('unlock', 'g3', 1), Mission('lvl', 'checkin', 25),
  Mission('unlock', 'hangar', 1), Mission('lvl', 'lojas', 30), Mission('lvl', 'pista', 30), Mission('unlock', 'g4', 1),
  Mission('lvl', 'seguranca', 40), Mission('manager', '', 5), Mission('unlock', 'combustivel', 1), Mission('lvl', 'g1', 75),
  Mission('unlock', 'g5', 1), Mission('lvl', 'entrada', 100), Mission('flights', '', 400), Mission('lvl', 'torre', 50),
];

/// Recompensas diárias (dia 1..7).
const dailyRewards = [
  ('coins', 300.0), ('gems', 5.0), ('coins', 900.0), ('gems', 10.0), ('boost', 1800.0), ('gems', 15.0), ('gems', 40.0),
];

const destinations = ['São Paulo', 'Rio de Janeiro', 'Brasília', 'Salvador', 'Recife', 'Fortaleza', 'Belo Horizonte', 'Porto Alegre', 'Curitiba', 'Manaus', 'Belém', 'Florianópolis', 'Natal', 'Lisboa', 'Buenos Aires', 'Santiago', 'Miami', 'Paris', 'Nova York', 'Madri', 'Tóquio', 'Cancún'];
const airlines = ['SkyPort', 'Laranja Air', 'Verde Linhas'];
