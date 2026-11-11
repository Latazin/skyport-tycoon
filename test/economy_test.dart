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

  test('portões abrem em ordem', () {
    final s = GameState()..money = 1e12;
    expect(s.unlock('g2'), false);
    expect(s.unlock('g1'), true);
    expect(s.unlock('g2'), true);
  });

  test('modo MÁX compra vários níveis', () {
    final s = GameState()..money = 1e5..buyMode = -1;
    final b = s.buyInfo(stationById('entrada'));
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
