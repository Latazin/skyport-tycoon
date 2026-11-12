import 'dart:math' as math;

/// Layout do aeroporto em unidades do mundo (igual ao estúdio de arte, tool/studio/studio.js).
class Lay {
  static const runwayX0 = -74.0, runwayX1 = 54.0, runwayZ = -37.0;
  static const laneZ = -20.0, connL = -46.0, connR = 38.0, holdZ = -31.0;
  static const standNose = -6.4;
  static const gates = [-38.0, -26.0, -14.0, -2.0, 10.0, 22.0];
  static const checkinX0 = -44.0, checkinZ = 8.0, checkinDx = 2.6;
  static const secX0 = -21.5, secZ = 5.0, secDx = 3.0;
  static const shops = [(-1.5, 8.0), (4.5, 8.0), (10.5, 8.0), (16.5, 8.0)];
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
  final int gate, star; // índice do portão; estrelas necessárias para construir
  const St(this.id, this.name, this.icon, this.desc, this.kind, {this.base = 10, this.growth = 1.13, this.unlock = 0, this.gate = -1, this.star = 0});
  bool get oneTime => kind == Kind.building;
}

const stations = [
  St('entrada', 'Estacionamento', 'bus', 'Ônibus, táxis e carros trazem passageiros. Cada nível estaciona mais um carro e traz mais gente.', Kind.flow, base: 8, growth: 1.16),
  St('checkin', 'Check-in', 'checkin', 'Balcões que atendem e despacham as malas. Novo balcão nos níveis 2, 4, 6, 8, 10, 15 e 20.', Kind.flow, base: 11, growth: 1.165),
  St('seguranca', 'Raio-X', 'security', 'Controle de segurança. Nova faixa nos níveis 3, 6, 10, 15 e 25. Scanner corporal no 20.', Kind.flow, base: 14, growth: 1.17),
  St('g0', 'Portão 1', 'plane', 'Cada portão recebe um avião por vez. Nível sobe o preço da passagem; nos níveis 25 e 75 chegam aviões maiores.', Kind.gate, base: 15, growth: 1.17, gate: 0),
  St('g1', 'Portão 2', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 50, growth: 1.17, unlock: 100, gate: 1),
  St('g2', 'Portão 3', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 1e3, growth: 1.17, unlock: 2e3, gate: 2, star: 1),
  St('g3', 'Portão 4', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 5e4, growth: 1.17, unlock: 1e5, gate: 3, star: 2),
  St('g4', 'Portão 5', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 1.5e6, growth: 1.17, unlock: 3e6, gate: 4, star: 3),
  St('g5', 'Portão 6', 'plane', 'Mais um portão = mais voos ao mesmo tempo.', Kind.gate, base: 4e7, growth: 1.17, unlock: 8e7, gate: 5, star: 4),
  St('lojas', 'Praça de Lojas', 'shop', 'Cada passageiro que passa no raio-X gasta nas lojas. Novo quiosque nos níveis 5, 10 e 15.', Kind.flow, base: 80, growth: 1.18, unlock: 600, star: 1),
  St('pista', 'Pista', 'runway', 'Aviões mais rápidos em pouso, taxi e decolagem. Nível 10 libera jatos médios; nível 30, jatos grandes.', Kind.boost, base: 60, growth: 1.2),
  St('torre', 'Torre de Controle', 'tower', 'Coordena o tráfego: +6% de receita por nível. Cresce nos níveis 15 e 30.', Kind.boost, base: 150, growth: 1.21),
  St('vip', 'Sala VIP', 'crown', 'Passageiros premium: +4% no preço da passagem por nível.', Kind.boost, base: 5e4, growth: 1.2, unlock: 1e5, star: 2),
  St('hangar', 'Hangar', 'hangar', 'Manutenção própria dos aviões: receita x1,5.', Kind.building, unlock: 1e6, star: 3),
  St('combustivel', 'Combustível', 'fuel', 'Posto próprio vende querosene a cada voo: receita x1,5.', Kind.building, unlock: 3e7, star: 4),
];
St stationById(String id) => stations.firstWhere((s) => s.id == id);

/// Marcos: cada um dobra a produção da estação.
const milestones = [10, 25, 50, 100, 150, 200, 300, 400, 500];
int milestonesPassed(int l) => milestones.where((m) => l >= m).length;
int? nextMilestone(int l) { for (final m in milestones) { if (l < m) return m; } return null; }
double power(int l) => l <= 0 ? 0.0 : l * math.pow(2, milestonesPassed(l)).toDouble();

int desksFor(int l) => 1 + [2, 4, 6, 8, 10, 15, 20].where((m) => l >= m).length;
int lanesFor(int l) => 1 + [3, 6, 10, 15, 25].where((m) => l >= m).length;
int shopsFor(int l) => l <= 0 ? 0 : 1 + [5, 10, 15].where((m) => l >= m).length;
int parkCars(int l) => math.min(24, 1 + l);
int parkTier(int l) => 1 + [10, 25, 50].where((m) => l >= m).length;
int towerTier(int l) => 1 + [15, 30].where((m) => l >= m).length;
int vipTier(int l) => 1 + [10, 30].where((m) => l >= m).length;
int gateVis(int l) => 1 + [10, 40].where((m) => l >= m).length;
int gateTier(int l) => l >= 75 ? 2 : l >= 25 ? 1 : 0;
int runwayTier(int l) => l >= 30 ? 2 : l >= 10 ? 1 : 0;
int aidsTier(int l) => 1 + [10, 30].where((m) => l >= m).length;
int cleanersFor(int l) => [15, 40].where((m) => l >= m).length;

/// Enfeites que aparecem com o nível de uma estação (posição no mundo).
class Prop {
  final String st, sprite;
  final int lvl;
  final double x, z;
  const Prop(this.st, this.lvl, this.sprite, this.x, this.z);
}
const props = [
  Prop('checkin', 3, 'plant', -46.3, 13.6), Prop('checkin', 5, 'totem', -46.2, 11.4), Prop('checkin', 7, 'bench', -41.0, 14.6),
  Prop('checkin', 9, 'totem', -46.2, 9.6), Prop('checkin', 12, 'ledboard', -38.5, 3.6), Prop('checkin', 14, 'plant_big', -46.3, 3.4),
  Prop('checkin', 18, 'infodesk', -27.0, 13.6), Prop('checkin', 22, 'vending', -24.4, 3.2), Prop('checkin', 26, 'bench', -30.5, 14.6),
  Prop('checkin', 32, 'ledboard', -30.0, 3.6), Prop('checkin', 45, 'atm', -24.4, 12.6),
  Prop('seguranca', 4, 'plant', -23.3, 1.2), Prop('seguranca', 8, 'dog', -23.2, 9.8), Prop('seguranca', 12, 'plant', -23.3, 11.4),
  Prop('seguranca', 30, 'plant_big', -5.2, 11.6),
  Prop('lojas', 2, 'plant', -3.6, 13.8), Prop('lojas', 4, 'bench', 1.5, 13.6), Prop('lojas', 7, 'vending', 6.2, 13.4),
  Prop('lojas', 12, 'atm', 8.2, 13.4), Prop('lojas', 20, 'fountain', 12.8, 13.1), Prop('lojas', 25, 'plant_big', 19.6, 13.8),
  Prop('lojas', 35, 'bench', 16.5, 13.6), Prop('lojas', 50, 'vending', 21.0, 12.2),
];

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

/// Tarefas genéricas (missões, estrelas, diárias).
class Mission {
  final String type, target;
  final double n;
  const Mission(this.type, this.target, this.n);
}

/// Estrelas do aeroporto: tarefas de cada estrela (os níveis escalam por cidade só no texto).
const starTasks = [
  [Mission('lvl', 'checkin', 10), Mission('lvl', 'entrada', 10), Mission('lvl', 'seguranca', 10), Mission('unlock', 'g1', 1), Mission('flights', '', 15)],
  [Mission('lvl', 'g0', 25), Mission('unlock', 'lojas', 1), Mission('unlock', 'g2', 1), Mission('lvl', 'pista', 10), Mission('manager', '', 1)],
  [Mission('lvl', 'checkin', 50), Mission('unlock', 'vip', 1), Mission('unlock', 'g3', 1), Mission('lvl', 'torre', 25), Mission('flights', '', 120)],
  [Mission('unlock', 'hangar', 1), Mission('lvl', 'g1', 75), Mission('unlock', 'g4', 1), Mission('lvl', 'seguranca', 75), Mission('lvl', 'lojas', 50)],
  [Mission('unlock', 'combustivel', 1), Mission('unlock', 'g5', 1), Mission('lvl', 'pista', 50), Mission('lvl', 'entrada', 100), Mission('flights', '', 600)],
];
const starNames = ['Aeródromo', 'Aeroporto Regional', 'Aeroporto Nacional', 'Aeroporto Internacional', 'Hub Global', 'Lenda dos Céus'];

/// Missões curtas em sequência.
const missionList = [
  Mission('lvl', 'checkin', 2), Mission('collect', '', 1), Mission('lvl', 'entrada', 3), Mission('lvl', 'g0', 3), Mission('lvl', 'seguranca', 3),
  Mission('unlock', 'g1', 1), Mission('flights', '', 8), Mission('lvl', 'checkin', 6), Mission('collect', '', 8), Mission('lvl', 'entrada', 10),
  Mission('lvl', 'pista', 5), Mission('lvl', 'seguranca', 10), Mission('star', '', 1), Mission('unlock', 'lojas', 1), Mission('lvl', 'g1', 10),
  Mission('lvl', 'torre', 10), Mission('unlock', 'g2', 1), Mission('manager', '', 2), Mission('lvl', 'pista', 10), Mission('lvl', 'g0', 25),
  Mission('star', '', 2), Mission('unlock', 'vip', 1), Mission('lvl', 'checkin', 25), Mission('unlock', 'g3', 1), Mission('lvl', 'lojas', 20),
  Mission('flights', '', 150), Mission('star', '', 3), Mission('unlock', 'hangar', 1), Mission('lvl', 'pista', 30), Mission('unlock', 'g4', 1),
  Mission('manager', '', 5), Mission('star', '', 4), Mission('unlock', 'combustivel', 1), Mission('unlock', 'g5', 1), Mission('star', '', 5),
];

/// Gerentes: bônus no aeroporto atual.
class Manager {
  final String id, name, role, effect;
  final double cost;
  const Manager(this.id, this.name, this.role, this.effect, this.cost);
}
const managers = [
  Manager('lia', 'Lia', 'Tesouraria', 'Coleta o dinheiro sozinha', 600),
  Manager('ana', 'Ana', 'Chefe de Check-in', 'Check-in 2x mais rápido', 2e3),
  Manager('bruno', 'Bruno', 'Chefe de Segurança', 'Raio-X 2x mais rápido', 6e3),
  Manager('carla', 'Carla', 'Transportes', 'Chegam 2x mais passageiros', 2e4),
  Manager('diego', 'Diego', 'Operações', 'Voos 30% mais rápidos', 1e5),
  Manager('elisa', 'Elisa', 'Comercial', 'Lojas faturam 3x', 5e5),
  Manager('fabio', 'Fábio', 'Bilheteria', 'Passagens 50% mais caras', 3e6),
  Manager('gabi', 'Gabi', 'Plantão', 'Ganhos offline 2x e até 8h', 2e7),
  Manager('hugo', 'Hugo', 'Diretor', 'Receita total 2x', 2e8),
];

/// Frota colecionável.
class PlaneModel {
  final String id, name;
  final int tier, liv, rarity; // raridade 0 comum, 1 raro, 2 épico, 3 lendário
  const PlaneModel(this.id, this.name, this.tier, this.liv, this.rarity);
}
const rarityNames = ['Comum', 'Raro', 'Épico', 'Lendário'];
const rarityBonus = [0.05, 0.10, 0.20, 0.40];
const planeModels = [
  PlaneModel('brisa', 'Brisa T-40', 0, 0, 0), PlaneModel('laranja', 'Laranjinha T-40', 0, 1, 0), PlaneModel('arara', 'Arara T-40', 0, 2, 1),
  PlaneModel('rubi', 'Rubi T-40', 0, 5, 1), PlaneModel('ouro0', 'Pepita T-40', 0, 3, 2),
  PlaneModel('ceu', 'Céu J-120', 1, 0, 0), PlaneModel('sol', 'Pôr do Sol J-120', 1, 1, 0), PlaneModel('mata', 'Mata J-120', 1, 2, 1),
  PlaneModel('violeta', 'Violeta J-120', 1, 4, 2), PlaneModel('real', 'Real J-120', 1, 3, 3),
  PlaneModel('atlantico', 'Atlântico W-260', 2, 0, 1), PlaneModel('fenix', 'Fênix W-260', 2, 5, 2), PlaneModel('dourado', 'Dourado W-260', 2, 3, 3),
];
PlaneModel modelById(String id) => planeModels.firstWhere((m) => m.id == id);
const cardsToLevel = [0, 2, 4, 8, 16, 32, 64];

/// Pesquisa (permanente entre cidades), paga com milhas.
class Research {
  final String id, name, desc, icon;
  final double cost;
  const Research(this.id, this.name, this.desc, this.icon, this.cost);
}
const researchList = [
  Research('online', 'Check-in online', 'Check-in +50%', 'checkin', 20),
  Research('scan', 'Raio-X inteligente', 'Raio-X +50%', 'security', 40),
  Research('expresso', 'Ônibus expresso', 'Chegada de passageiros +50%', 'bus', 70),
  Research('embarque', 'Embarque rápido', 'Aviões 15% mais rápidos', 'plane', 110),
  Research('premium', 'Lojas premium', 'Lojas faturam 2x', 'shop', 160),
  Research('auto', 'Auto-melhoria', 'Libera o botão que melhora sozinho', 'auto', 220),
  Research('tarifa', 'Tarifa dinâmica', 'Passagens +30%', 'ticket', 320),
  Research('cofre', 'Cofre maior', 'Ganhos offline até +4h', 'cash', 450),
  Research('satelite', 'Radar meteorológico', 'Eventos 2x mais frequentes', 'cloud', 600),
  Research('bio', 'Embarque biométrico', 'Check-in e raio-X 2x', 'shield', 850),
  Research('verde', 'Combustível verde', 'Receita +50%', 'fuel', 1200),
  Research('mega', 'Megahub', 'Receita 2x', 'globe', 2000),
];

/// Rotas (permanentes entre cidades).
class Route {
  final String id, name;
  final double cost, bonus;
  final int star;
  final bool intl;
  final double mx, my; // posição no mapa (0..1)
  const Route(this.id, this.name, this.cost, this.bonus, this.star, this.intl, this.mx, this.my);
}
const routes = [
  Route('sp', 'São Paulo', 300, 0.10, 0, false, 0.38, 0.62), Route('rj', 'Rio de Janeiro', 1500, 0.10, 0, false, 0.45, 0.6),
  Route('bh', 'Belo Horizonte', 8e3, 0.10, 1, false, 0.42, 0.55), Route('ssa', 'Salvador', 4e4, 0.12, 1, false, 0.5, 0.47),
  Route('rec', 'Recife', 2e5, 0.12, 2, false, 0.56, 0.4), Route('poa', 'Porto Alegre', 8e5, 0.12, 2, false, 0.3, 0.75),
  Route('mao', 'Manaus', 4e6, 0.15, 2, false, 0.22, 0.33), Route('bue', 'Buenos Aires', 1.5e7, 0.25, 3, true, 0.2, 0.8),
  Route('lis', 'Lisboa', 8e7, 0.30, 3, true, 0.82, 0.22), Route('mia', 'Miami', 4e8, 0.30, 4, true, 0.12, 0.12),
  Route('par', 'Paris', 2e9, 0.35, 4, true, 0.9, 0.12), Route('tok', 'Tóquio', 1e10, 0.50, 5, true, 0.97, 0.3),
];

/// Missões diárias/semanais (contadores).
const dailyPool = [
  ('flights', 'Faça {n} voos', 20.0), ('upgrades', 'Compre {n} melhorias', 25.0), ('collects', 'Colete dinheiro {n} vezes', 12.0),
  ('minigames', 'Jogue {n} minijogo', 1.0), ('events', 'Aproveite {n} eventos', 3.0), ('chests', 'Abra {n} baú', 1.0), ('taps', 'Toque em {n} aviões', 15.0),
];
const weeklyPool = [
  ('flights', 'Faça {n} voos', 300.0), ('upgrades', 'Compre {n} melhorias', 250.0), ('collects', 'Colete dinheiro {n} vezes', 120.0), ('minigames', 'Jogue {n} minijogos', 10.0), ('events', 'Aproveite {n} eventos', 25.0),
];

/// Conquistas permanentes.
class Ach {
  final String id, name, key, icon;
  final double n;
  final int gems;
  const Ach(this.id, this.name, this.key, this.n, this.gems, this.icon);
}
const achievements = [
  Ach('f10', 'Primeiros voos', 'flights', 10, 5, 'plane'), Ach('f100', 'Ponte aérea', 'flights', 100, 10, 'plane'),
  Ach('f1k', 'Céu movimentado', 'flights', 1000, 25, 'plane'), Ach('f10k', 'Torre de babel', 'flights', 10000, 60, 'plane'),
  Ach('u50', 'Reformador', 'upgrades', 50, 5, 'up'), Ach('u500', 'Construtor', 'upgrades', 500, 15, 'up'), Ach('u3k', 'Engenheiro-chefe', 'upgrades', 3000, 40, 'up'),
  Ach('c50', 'Mão rápida', 'collects', 50, 5, 'cash'), Ach('c500', 'Cofre cheio', 'collects', 500, 20, 'cash'),
  Ach('e10', 'Imprevistos', 'events', 10, 8, 'cloud'), Ach('e100', 'Gestor de crises', 'events', 100, 30, 'cloud'),
  Ach('m10', 'Piloto de teste', 'minigames', 10, 10, 'landing'), Ach('m50', 'Ás dos ares', 'minigames', 50, 30, 'landing'),
  Ach('ch10', 'Caçador de baús', 'chests', 10, 10, 'chest'), Ach('ch50', 'Colecionador', 'chests', 50, 30, 'chest'),
  Ach('s5', 'Cinco estrelas', 'stars', 5, 30, 'star'), Ach('s15', 'Constelação', 'stars', 15, 80, 'star'),
  Ach('city2', 'Viajante', 'city', 1, 25, 'globe'), Ach('city4', 'Magnata dos ares', 'city', 3, 80, 'globe'),
];

/// Passe de temporada (30 níveis, grátis).
const seasonThemes = ['Verão no Litoral', 'Carnaval nos Céus', 'Festa Junina Aérea', 'Férias de Julho', 'Primavera das Flores', 'Natal no Hangar'];
(String, double) seasonReward(int tier) {
  if ((tier + 1) % 10 == 0) return ('chest_gold', 1);
  if ((tier + 1) % 5 == 0) return ('chest', 1);
  if (tier % 3 == 0) return ('gems', 5.0 + tier);
  if (tier % 3 == 1) return ('coins', 120.0 + tier * 60);
  return ('miles', 10.0 + tier * 4);
}
const seasonPts = 100;

/// Roleta diária.
const wheelPrizes = [('coins', 180.0), ('gems', 5.0), ('miles', 25.0), ('chest', 1.0), ('coins', 600.0), ('gems', 15.0), ('boost', 900.0), ('chest_gold', 1.0)];

const destinationsBase = ['Campinas', 'Ribeirão Preto', 'Londrina', 'Uberlândia', 'Goiânia', 'Vitória'];

/// Recompensas de login (dia 1..7).
const dailyRewards = [
  ('coins', 300.0), ('gems', 5.0), ('coins', 900.0), ('gems', 10.0), ('boost', 1800.0), ('gems', 15.0), ('chest', 1.0),
];
