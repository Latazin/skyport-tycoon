import 'package:flutter_test/flutter_test.dart';
import 'package:skyport_tycoon/core/data.dart';
import 'package:skyport_tycoon/core/state.dart';

void main() {
  test('estado inicial opera e gera receita', () {
    final s = GameState();
    expect(s.built('g0'), true);
    expect(s.built('g1'), false);
    s.estimate();
    expect(s.rate > 0, true);
  });

  test('voos acontecem e pagam passagens', () {
    final s = GameState();
    s.money = 0;
    for (var i = 0; i < 20 * 60 * 10; i++) { s.tick(0.1); }
    expect(s.flightsCity > 3, true);
    expect(s.money > 0, true);
  });

  test('melhorar custa e sobe o nível', () {
    final s = GameState()..money = 1e6;
    final before = s.lvl('checkin');
    expect(s.upgrade('checkin'), true);
    expect(s.lvl('checkin'), before + 1);
    expect(s.money < 1e6, true);
  });

  test('portões abrem em ordem e pedem estrelas', () {
    final s = GameState()..money = 1e12;
    expect(s.unlock('g2'), false);
    expect(s.unlock('g1'), true);
    expect(s.unlock('g2'), false);
    s.star = 1;
    expect(s.unlock('g2'), true);
  });

  test('dinheiro dos voos cai na pilha e pode ser coletado', () {
    final s = GameState();
    for (var i = 0; i < 6000; i++) { s.tick(0.1); if (s.pile[0] > 0) break; }
    expect(s.pile[0] > 0, true);
    final before = s.money;
    final v = s.collect(0);
    expect(v > 0, true);
    expect(s.money > before, true);
  });

  test('baú dá cartas e recompensas', () {
    final s = GameState();
    final l = s.openChest('chest');
    expect(l.cards.length, 3);
    expect(s.gems > 10, true);
  });

  test('estrela exige tarefas', () {
    final s = GameState()..money = 1e15;
    expect(s.starReady, false);
    for (final id in ['checkin', 'entrada', 'seguranca']) { s.lv[id] = 10; }
    s.unlock('g1'); s.flightsCity = 20;
    expect(s.starReady, true);
    s.claimStar();
    expect(s.star, 1);
  });

  test('modo MÁX compra vários níveis', () {
    final s = GameState()..money = 1e5..buyMode = -1;
    final b = s.buyInfo(stationById('entrada'));
    expect(s.bestBuy() != null, true);
    expect(b.$1 > 5, true);
    expect(b.$2 <= 1e5, true);
  });

  test('salvar e carregar', () {
    final s = GameState()..money = 1234..gems = 77;
    s.lv['checkin'] = 9;
    final t = GameState()..loadJson(s.toJson());
    expect(t.money, 1234);
    expect(t.gems, 77);
    expect(t.lvl('checkin'), 9);
  });
}
