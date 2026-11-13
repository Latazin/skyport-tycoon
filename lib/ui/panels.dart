import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/data.dart';
import '../core/format.dart';
import '../core/state.dart';
import 'kit.dart';

/// Quem abre os painéis (a tela do jogo).
abstract class PanelHost {
  void openPanel(String p);
  void closePanel();
  void refresh();
  void focusStation(String id);
  void doPrestige();
  void resetGame();
  void claimDaily();
  void claimMission();
  void claimStar();
  void flyCash(double amount);
  void flyGemsCenter(int n);
  void openWheel();
  void boostTap();
  void showChests();
  void decorBought(Decor d);
  List<(String, String, String, bool, int)> get games;
  void playGame(String id);
}

Widget buildPanel(String p, GameState s, PanelHost h) {
  if (p.startsWith('st:')) return StationPanel(s: s, h: h, id: p.substring(3));
  switch (p) {
    case 'upgrades': return UpgradesPanel(s: s, h: h);
    case 'stars': return StarsPanel(s: s, h: h);
    case 'missions': return MissionsPanel(s: s, h: h);
    case 'fleet': return FleetPanel(s: s, h: h);
    case 'team': return TeamPanel(s: s, h: h);
    case 'shop': return ShopPanel(s: s, h: h);
    case 'cities': return CitiesPanel(s: s, h: h);
    case 'settings': return SettingsPanel(s: s, h: h);
    case 'games': return GamesPanel(s: s, h: h);
  }
  return const SizedBox.shrink();
}

Color stColor(St st) {
  switch (st.kind) {
    case Kind.gate: return K.gold;
    case Kind.boost: return K.purple;
    case Kind.building: return K.orange;
    case Kind.flow: return K.blue;
    case Kind.shop: return K.orange;
  }
}

String perMin(double v) => '${fmt(v * 60)}/min';
String bottleneckName(String b) => b == 'gates' ? 'Portões' : stationById(b).name;

/// Abas dentro de um painel.
class Tabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final void Function(int) onTap;
  final List<bool> dots;
  const Tabs({super.key, required this.labels, required this.index, required this.onTap, this.dots = const []});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: K.track, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(child: GestureDetector(
              onTap: () { Sfx.click(); onTap(i); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: index == i ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(11), boxShadow: index == i ? K.shadowS : null),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(child: Text(labels[i], textAlign: TextAlign.center, style: body(13.5, color: index == i ? K.ink : K.muted, w: FontWeight.w900), overflow: TextOverflow.ellipsis)),
                  if (i < dots.length && dots[i]) Container(margin: const EdgeInsets.only(left: 4), width: 8, height: 8, decoration: const BoxDecoration(color: K.red, shape: BoxShape.circle)),
                ]),
              ),
            )),
        ]),
      );
}

/// Botões x1 / x10 / x50 / MÁX.
class BuyMode extends StatelessWidget {
  final GameState s;
  final VoidCallback onChange;
  const BuyMode({super.key, required this.s, required this.onChange});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: K.track, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final m in [1, 10, 50, -1])
            GestureDetector(
              onTap: () { Sfx.click(); s.buyMode = m; onChange(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: s.buyMode == m ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(9), boxShadow: s.buyMode == m ? K.shadowS : null),
                child: Text(m == -1 ? 'MÁX' : 'x$m', style: body(13, color: s.buyMode == m ? K.blue : K.muted, w: FontWeight.w900)),
              ),
            ),
        ]),
      );
}

/// Linhas de estatística (atual -> próximo) de uma estação.
List<(String, String, String?)> stationStats(GameState s, St st, int add) {
  final id = st.id, l = s.lvl(id);
  String? nx(String Function() f) {
    if (add <= 0) return null;
    s.lv[id] = l + add; final v = f(); s.lv[id] = l; return v;
  }
  if (st.kind == Kind.shop) {
    final i = shopIds.indexOf(id), m = (s.hasMgr('elisa') ? 3 : 1) * (s.has('premium') ? 2 : 1) * s.perk.shop * s.revMult;
    return [('Esta loja rende', '\$${fmt(s.shopSpendOf(i) * m)}/pax', nx(() => '\$${fmt(s.shopSpendOf(i) * m)}/pax')), ('Todas as lojas juntas', '\$${fmt(s.shopSpend * s.revMult)}/pax', null)];
  }
  switch (id) {
    case 'entrada':
      return [('Chegada de passageiros', perMin(s.lambda), nx(() => perMin(s.lambda))), ('Carros no estacionamento', '${parkCars(l)}', nx(() => '${parkCars(s.lvl(id))}'))];
    case 'checkin':
      return [('Atendimento', perMin(s.muC), nx(() => perMin(s.muC))), ('Balcões abertos', '${desksFor(l)}', nx(() => '${desksFor(s.lvl(id))}'))];
    case 'seguranca':
      return [('Inspeção', perMin(s.muS), nx(() => perMin(s.muS))), ('Faixas de raio-X', '${lanesFor(l)}', nx(() => '${lanesFor(s.lvl(id))}'))];
    case 'pista':
      return [('Velocidade dos voos', 'x${s.speed.toStringAsFixed(2)}', nx(() => 'x${s.speed.toStringAsFixed(2)}')), ('Maior avião', planeTypes[runwayTier(l)].name, nx(() => planeTypes[runwayTier(s.lvl(id))].name))];
    case 'torre':
      return [('Bônus de receita', '+${(6 * (l - 1))}%', nx(() => '+${(6 * (s.lvl(id) - 1))}%'))];
    case 'vip':
      return [('Bônus na passagem', '+${4 * l}%', nx(() => '+${4 * s.lvl(id)}%'))];
    case 'cargas':
      return [('Bônus de receita', '+${5 * l}%', nx(() => '+${5 * s.lvl(id)}%'))];
    case 'esp0':
      return [('Lojas e gorjetas', '+${6 * l}%', nx(() => '+${6 * s.lvl(id)}%'))];
    case 'esp1':
      return [('Diárias', '\$${fmt(s.hotelRate)}/s', nx(() => '\$${fmt(s.hotelRate)}/s')), ('No caixa do hotel', '\$${fmt(s.hotelPile)}', null)];
    case 'esp2':
      return [('Voos internacionais (3x)', '${(s.intlChance * 100).round()}%', nx(() => '${(s.intlChance * 100).round()}%'))];
    case 'esp3':
      return [('Velocidade na neve', 'x${s.snowSpeed.toStringAsFixed(2)}', nx(() => 'x${s.snowSpeed.toStringAsFixed(2)}'))];
    case 'esp4':
      return [('Helicóptero a cada', '${s.heliEvery.round()} s', nx(() => '${s.heliEvery.round()} s')), ('Cada pouso paga', '\$${fmt(s.heliValue)}', nx(() => '\$${fmt(s.heliValue)}'))];
    case 'bombeiros':
      return [('Velocidade dos voos', '+15%', null), ('Velocidade total agora', 'x${s.speed.toStringAsFixed(2)}', null)];
    case 'radar':
      return [('Eventos', '+60% mais frequentes', null), ('Receita', '+15%', null)];
    case 'catering':
      return [('Passagens', '+30%', null)];
    case 'trem':
      return [('Chegada de passageiros', '+50%', null), ('Agora chegam', perMin(s.lambda), null)];
    case 'solar':
      return [('Receita', '+40%', null), ('Ganhos offline', '+50%', null)];
    case 'esp5':
      return [('Onda de turistas', '${s.waveSecs.round()} s', nx(() => '${s.waveSecs.round()} s')), ('Intervalo', '110 s', null)];
  }
  if (st.kind == Kind.gate) {
    final g = st.gate;
    return [
      ('Avião', planeTypes[s.tierFor(g)].name, nx(() => planeTypes[s.tierFor(g)].name)),
      ('Lugares', fmt(s.seatsFor(g)), nx(() => fmt(s.seatsFor(g)))),
      ('Passagem', '\$${fmt(s.ticketFor(g) * s.revMult)}', nx(() => '\$${fmt(s.ticketFor(g) * s.revMult)}')),
    ];
  }
  return [];
}

/// Próxima novidade visual da estação.
String? nextVisual(St st, int l) {
  int? nx(List<int> m) { for (final x in m) { if (l < x) return x; } return null; }
  if (st.kind == Kind.shop) { final n = nx([10, 25]); return n == null ? null : n == 10 ? 'Vira loja moderna no nível 10' : 'Vira loja de luxo no nível 25'; }
  if (st.id == 'checkin' || st.id == 'seguranca') { final t = nx([25, 50]); final small = nx(st.id == 'checkin' ? [2, 4, 6, 8, 10, 15, 20] : [3, 6, 10, 15, 20, 25]); if (t != null && (small == null || t <= small)) return t == 25 ? 'Evolui para o visual moderno no nível 25' : 'Evolui para o visual de luxo no nível 50'; }
  switch (st.id) {
    case 'checkin': final n = nx([2, 4, 6, 8, 10, 15, 20]); final p = props.where((p) => p.st == 'checkin' && p.lvl > l).map((p) => p.lvl).fold<int?>(null, (a, b) => a == null || b < a ? b : a); final m = [n, p].whereType<int>().fold<int?>(null, (a, b) => a == null || b < a ? b : a); return m == null ? null : m == n ? 'Novo balcão no nível $n' : 'Decoração nova no nível $m';
    case 'seguranca': final n = nx([3, 6, 10, 15, 20, 25]); return n == null ? null : n == 20 ? 'Scanner corporal no nível 20' : 'Nova faixa no nível $n';
    case 'entrada': return l < 23 ? 'Mais um carro a cada nível · ônibus mais frequentes' : null;

    case 'pista': final n = nx([10, 30]); return n == null ? null : 'Pista maior e luzes novas no nível $n';
    case 'torre': final n = nx([15, 30]); return n == null ? null : 'Torre mais alta no nível $n';
  }
  if (st.kind == Kind.gate) { final n = nx([5, 10, 20, 25, 40, 75]); return n == null ? null : n == 25 || n == 75 ? 'Avião maior no nível $n' : 'Sala de embarque nova no nível $n'; }
  return null;
}

class StationPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  final String id;
  const StationPanel({super.key, required this.s, required this.h, required this.id});
  @override
  State<StationPanel> createState() => _StationPanelState();
}

class _StationPanelState extends State<StationPanel> {
  GameState get s => widget.s;
  @override
  Widget build(BuildContext context) {
    final st = stationById(widget.id), l = s.lvl(st.id);
    if (l <= 0) {
      final starOk = s.starOk(st), orderOk = s.unlockOk(st);
      return Sheet(title: st.name, subtitle: 'Ainda não construído', icon: st.icon, color: stColor(st), onClose: widget.h.closePanel, child: Column(children: [
        GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(st.desc, style: body(15, w: FontWeight.w700)),
          if (!starOk || !orderOk) const SizedBox(height: 10),
          if (!starOk) Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: K.purpleL, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Ico('star', size: 26), const SizedBox(width: 8), Expanded(child: Text('Libera com ${st.star} estrela${st.star > 1 ? 's' : ''} (você tem ${s.star}).', style: body(14, color: K.purple)))]))
          else if (!orderOk) Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: K.redL, borderRadius: BorderRadius.circular(12)), child: Text('Abra o ${stationById('g${st.gate - 1}').name} primeiro.', style: body(14, color: K.red))),
        ])),
        if (!starOk) GBtn(color: K.purple, onTap: () => widget.h.openPanel('stars'), child: Text('VER ESTRELAS', style: display(18)))
        else GBtn(
          color: K.green, enabled: s.canUnlock(st), pulse: s.canUnlock(st),
          onTap: () { if (s.unlock(st.id)) widget.h.refresh(); },
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Construir  ', style: display(19)), Price(fmt(st.unlock), size: 19)]),
        ),
      ]));
    }
    if (st.oneTime) {
      final ss = stationStats(s, st, 0);
      return Sheet(title: st.name, subtitle: 'Construído', icon: st.icon, color: stColor(st), onClose: widget.h.closePanel, child: Column(children: [
        GCard(child: Text(st.desc, style: body(15, w: FontWeight.w700))),
        if (ss.isNotEmpty) const SizedBox(height: 8),
        if (ss.isNotEmpty) GCard(child: Column(children: [
          for (final r in ss) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
            Expanded(child: Text(r.$1, style: body(14, color: K.muted, w: FontWeight.w800))),
            Text(r.$2, style: body(15, color: K.greenD, w: FontWeight.w900)),
          ])),
        ])),
      ]));
    }
    final b = s.buyInfo(st);
    final can = b.$1 > 0 && s.money >= b.$2;
    final nm = nextMilestone(l);
    final prev = milestones.lastWhere((m) => m <= l, orElse: () => 0);
    final stats = stationStats(s, st, b.$1);
    final isBott = s.bottleneck == st.id || (s.bottleneck == 'gates' && st.kind == Kind.gate);
    final G = st.kind == Kind.gate ? s.gates[st.gate] : null;
    final vis = nextVisual(st, l);
    return Sheet(title: st.name, subtitle: 'Nível $l${nm != null ? '  ·  produção x2 no nível $nm' : ''}', icon: st.icon, color: stColor(st), onClose: widget.h.closePanel, child: Column(children: [
      if (isBott)
        Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: K.redL, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [const Icon(Icons.warning_amber_rounded, color: K.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(st.kind == Kind.gate ? 'Portões são o gargalo: abra mais portões ou suba o nível.' : 'Gargalo! Esta é a etapa mais lenta. Melhorar aqui aumenta o lucro.', style: body(13.5, color: K.red)))]),
        )
      else if (st.kind == Kind.flow)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Gargalo atual: ${bottleneckName(s.bottleneck)}', style: body(13, color: K.muted))),
      GCard(child: Column(children: [
        for (final r in stats) InfoRow(r.$1, r.$2, next: r.$3 != null && r.$3 != r.$2 ? '→ ${r.$3}' : null),
        if (G != null) InfoRow('Agora', G.phase == Ph.empty ? 'Aguardando avião' : '${Ph.names[G.phase]} · ${G.flight}${G.dest.isNotEmpty && G.phase >= Ph.boarding ? ' → ${G.dest}' : ''}'),
        if (nm != null) ...[
          const SizedBox(height: 10),
          Row(children: [const Ico('bolt', size: 20), const SizedBox(width: 4), Text('Produção x2 no nível $nm', style: body(13, color: K.muted)), const Spacer(), Text('$l/$nm', style: body(13, w: FontWeight.w900))]),
          const SizedBox(height: 6),
          GBar(value: (l - prev) / (nm - prev), color: K.gold, height: 9),
        ],
      ])),
      if (vis != null) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: K.purpleL, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.auto_awesome_rounded, color: K.purple, size: 18), const SizedBox(width: 8), Expanded(child: Text(vis, style: body(13.5, color: K.purple, w: FontWeight.w900)))])),
      Row(children: [
        BuyMode(s: s, onChange: () => setState(() {})),
        const SizedBox(width: 8),
        Expanded(child: GBtn(
          color: K.green, enabled: can, pulse: can && s.tut == 2, repeat: true,
          onTap: () { if (s.upgrade(st.id)) { if (s.tut == 2) s.tut = 3; widget.h.refresh(); setState(() {}); } },
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l >= GameState.maxL ? 'Nível máximo' : 'Melhorar +${b.$1}', style: display(17)),
            if (l < GameState.maxL) Price(fmt(b.$2), size: 16),
          ]),
        )),
      ]),
    ]));
  }
}

class UpgradesPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  const UpgradesPanel({super.key, required this.s, required this.h});
  @override
  State<UpgradesPanel> createState() => _UpgradesPanelState();
}

class _UpgradesPanelState extends State<UpgradesPanel> {
  GameState get s => widget.s;
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final list = stations.where((st) => s.built(st.id) || s.unlockOk(st)).toList();
    final next = stations.where((st) => !s.built(st.id) && s.here(st)).take(4).toList();
    return Sheet(title: 'Melhorias', subtitle: '${s.ph.name} · lucro \$${fmt(s.rate)}/s', icon: 'up', color: K.green, onClose: widget.h.closePanel, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tabs(labels: const ['Aeroporto', 'Decoração'], index: tab, dots: [false, decors.any((d) => !s.decor.contains(d.id) && s.decorOk(d) && s.money >= s.decorCost(d))], onTap: (i) => setState(() => tab = i)),
      if (tab == 1) ..._decor() else ...[
      Row(children: [
        Expanded(child: Row(children: [const Icon(Icons.speed_rounded, color: K.red, size: 18), const SizedBox(width: 4), Flexible(child: Text('Gargalo: ${bottleneckName(s.bottleneck)}', style: body(13.5, color: K.red, w: FontWeight.w900)))])),
        BuyMode(s: s, onChange: () => setState(() {})),
      ]),
      if (s.has('auto')) Padding(padding: const EdgeInsets.only(top: 6), child: GCard(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), child: SwitchListTile(dense: true, value: s.autoUp, onChanged: (v) { s.autoUp = v; setState(() {}); }, title: Text('Melhoria automática', style: body(15)), subtitle: Text('Compra sozinho a melhor opção', style: body(12, color: K.muted)), activeThumbColor: K.green))),
      const SizedBox(height: 8),
      for (final st in list) _row(st),
      if (next.isNotEmpty) ...[
        const SectionTitle('Próximos desbloqueios'),
        SizedBox(height: 98, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final st in next) Container(
            width: 112, margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.line), boxShadow: K.shadowS),
            child: Column(children: [
              Opacity(opacity: s.starOk(st) ? 1 : 0.45, child: Ico(st.icon, size: 40)),
              Text(st.name, style: body(12, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              s.starOk(st) ? Price(fmt(st.unlock), size: 12) : Row(mainAxisSize: MainAxisSize.min, children: [const Ico('star', size: 16), Text(' ${st.star} estrelas', style: body(11, color: K.purple))]),
            ]),
          ),
        ])),
      ],
      ],
    ]));
  }
  List<Widget> _decor() => [
        Text('Cada peça deixa o aeroporto mais bonito e dá +3% de receita nesta cidade.', textAlign: TextAlign.center, style: body(13, color: K.muted)),
        const SizedBox(height: 8),
        for (final d in decors) () {
          final own = s.decor.contains(d.id), ok = s.decorOk(d), cost = s.decorCost(d);
          return GCard(color: own ? K.greenL : null, padding: const EdgeInsets.all(10), child: Row(children: [
            IcoBox('decor', color: own ? K.green : K.teal, size: 46, opacity: ok || own ? 1 : 0.4),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: body(15, w: FontWeight.w900)),
              Text(own ? 'Instalado · +3% receita' : ok ? '+3% de receita' : 'Compre a anterior primeiro', style: body(12, color: own ? K.greenD : K.muted)),
            ])),
            if (own) const Icon(Icons.check_circle_rounded, color: K.green, size: 28)
            else GBtn(color: K.teal, radius: 12, enabled: ok && s.money >= cost, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), onTap: () { if (s.buyDecor(d)) { Sfx.play('build'); widget.h.decorBought(d); setState(() {}); } }, child: Price(fmt(cost), size: 13)),
          ]));
        }(),
      ];
  Widget _row(St st) {
    final l = s.lvl(st.id);
    final locked = l <= 0;
    final b = locked ? (1, st.unlock) : s.buyInfo(st);
    final can = !locked ? (b.$1 > 0 && s.money >= b.$2 && !st.oneTime) : s.canUnlock(st);
    final bott = s.bottleneck == st.id || (s.bottleneck == 'gates' && st.kind == Kind.gate);
    final best = s.bestBuy()?.$1 == st.id;
    return GCard(color: best ? K.greenL : null, border: best ? K.green.withValues(alpha: 0.5) : null, padding: const EdgeInsets.all(9), child: Row(children: [
      GestureDetector(onTap: () => widget.h.focusStation(st.id), child: IcoBox(st.icon, color: stColor(st), size: 46)),
      const SizedBox(width: 8),
      Expanded(child: GestureDetector(
        onTap: () => widget.h.focusStation(st.id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(st.name, style: body(16, w: FontWeight.w900), overflow: TextOverflow.ellipsis)),
            if (bott) Tag('GARGALO', K.red),
            if (best && !bott) Tag('MELHOR', K.greenD),
          ]),
          Text(locked ? 'Não construído' : st.oneTime ? 'Construído' : 'Nível $l${nextMilestone(l) != null ? '  ·  x2 no ${nextMilestone(l)}' : ''}', style: body(12, color: K.muted)),
        ]),
      )),
      if (!st.oneTime || locked)
        GBtn(
          color: locked ? K.blue : K.green, enabled: can, radius: 14, repeat: !locked,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          onTap: () { final ok = locked ? s.unlock(st.id) : s.upgrade(st.id); if (ok) { widget.h.refresh(); setState(() {}); } },
          child: Column(mainAxisSize: MainAxisSize.min, children: [Text(locked ? 'Construir' : '+${b.$1}', style: display(12.5)), Price(fmt(b.$2), size: 13)]),
        ),
    ]));
  }
}

/// Estrelas do aeroporto.
class StarsPanel extends StatelessWidget {
  final GameState s;
  final PanelHost h;
  const StarsPanel({super.key, required this.s, required this.h});
  @override
  Widget build(BuildContext context) {
    final tasks = s.starNow;
    final nextPh = s.star < 5 ? phaseFor(s.city, s.star + 1) : s.phase;
    return Sheet(title: 'Estrelas', subtitle: starNames[math.min(s.star, 5)], icon: 'star', color: K.purple, onClose: h.closePanel, child: Column(children: [
      GCard(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < 5; i++) Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Opacity(opacity: i < s.star ? 1 : 0.18, child: Ico('star', size: i == 2 ? 46 : 38)))]),
        const SizedBox(height: 6),
        Text('Cada estrela dobra a receita (agora x${fmt(s.starMult)}) e libera novas áreas.', textAlign: TextAlign.center, style: body(13, color: K.muted)),
        if (nextPh != s.phase) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: K.blueL, borderRadius: BorderRadius.circular(12)), child: Row(children: [
            const Ico('hangar', size: 34), const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Próxima estrela: obra de expansão!', style: body(14, color: K.blue, w: FontWeight.w900)),
              Text('${phases[s.phase].name} → ${phases[nextPh].name}: ${phases[nextPh].desc.toLowerCase()}', style: body(12.5, color: K.navy2)),
            ])),
          ])),
        ],
      ])),
      if (s.star >= 5) GCard(child: Column(children: [
        Text('Aeroporto 5 estrelas! Hora de abrir a próxima cidade.', textAlign: TextAlign.center, style: body(15)),
        const SizedBox(height: 8),
        GBtn(color: K.green, pulse: true, onTap: () => h.openPanel('cities'), child: Text('Ver cidades', style: display(17))),
      ]))
      else ...[
        SectionTitle('Para a ${s.star + 1}ª estrela'),
        for (final m in tasks) _task(m),
        const SizedBox(height: 6),
        GBtn(color: K.purple, enabled: s.starReady, pulse: s.starReady, onTap: h.claimStar, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 13), child: Text(s.starReady ? 'Ganhar estrela!' : 'Complete as tarefas', style: display(18))),
        const SizedBox(height: 8),
        Text('Libera: ${stations.where((st) => st.star == s.star + 1 && s.here(st)).map((st) => st.name).join(', ')}', textAlign: TextAlign.center, style: body(13, color: K.purple)),
      ],
    ]));
  }
  Widget _task(Mission m) {
    final p = s.progress(m), done = p.$1 >= p.$2;
    return GCard(color: done ? K.greenL : null, padding: const EdgeInsets.all(10), child: Row(children: [
      done ? Container(width: 40, height: 40, decoration: const BoxDecoration(color: K.green, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 26)) : IcoBox((m.type == 'lvl' || m.type == 'unlock') ? stationById(m.target).icon : m.type == 'flights' ? 'plane' : 'pax', color: K.purple, size: 40),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.missionText(m), style: body(15, w: FontWeight.w900)),
        const SizedBox(height: 3),
        GBar(value: p.$1 / p.$2, height: 12, color: done ? K.green : K.gold, label: '${fmt(math.min(p.$1, p.$2))}/${fmt(p.$2)}'),
      ])),
      if (!done && (m.type == 'lvl' || m.type == 'unlock')) ...[const SizedBox(width: 6), GBtn(color: K.blue, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), onTap: () => h.focusStation(m.target), child: Text('Ir', style: display(14)))],
    ]));
  }
}

class MissionsPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  const MissionsPanel({super.key, required this.s, required this.h});
  @override
  State<MissionsPanel> createState() => _MissionsPanelState();
}

class _MissionsPanelState extends State<MissionsPanel> {
  int tab = 0;
  GameState get s => widget.s;
  @override
  Widget build(BuildContext context) {
    final dDots = s.dailyReady || s.missionReady || List.generate(s.dTasks.length, (i) => !s.dClaimed[i] && s.dailyDone(i)).any((x) => x) || List.generate(s.wTasks.length, (i) => !s.wClaimed[i] && s.weeklyDone(i)).any((x) => x);
    final aDots = achievements.any(s.achReady);
    final pDots = List.generate(s.seasonTier, (t) => !s.sClaimed.contains(t)).any((x) => x);
    return Sheet(title: 'Missões', subtitle: 'Prêmios diários, passe e conquistas', icon: 'mission', color: K.orange, onClose: widget.h.closePanel, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tabs(labels: const ['Tarefas', 'Passe', 'Conquistas'], index: tab, dots: [dDots, pDots, aDots], onTap: (i) => setState(() => tab = i)),
      if (tab == 0) ..._tasks(),
      if (tab == 1) ..._pass(),
      if (tab == 2) ..._ach(),
    ]));
  }
  List<Widget> _tasks() => [
        const SectionTitle('Prêmio diário'),
        GCard(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (var i = 0; i < 7; i++) _day(i)]),
          const SizedBox(height: 10),
          GBtn(color: K.gold, enabled: s.dailyReady, pulse: s.dailyReady, onTap: () { widget.h.claimDaily(); setState(() {}); }, child: Text(s.dailyReady ? 'Pegar prêmio do dia' : 'Volte amanhã', style: display(16))),
        ])),
        if (s.weekend) ...[
          const SectionTitle('Evento de fim de semana'),
          GCard(color: K.goldL, border: K.gold.withValues(alpha: 0.5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Ico('gift', size: 40), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Feriadão no aeroporto!', style: body(16, w: FontWeight.w900)),
              Text('+25% de passageiros o fim de semana todo. Faça ${GameState.wkNeed} voos e ganhe um baú de ouro + 25 gemas.', style: body(12.5, color: K.navy2)),
            ]))]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GBar(value: s.wkDone / GameState.wkNeed, color: K.gold, label: '${math.min(s.wkDone, GameState.wkNeed)}/${GameState.wkNeed}')),
              const SizedBox(width: 8),
              s.wkClaimed ? Text('Pego', style: body(13, color: K.greenD, w: FontWeight.w900))
                  : GBtn(color: K.gold, enabled: s.wkReady, pulse: s.wkReady, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), onTap: () { s.claimWeekend(); widget.h.flyGemsCenter(25); widget.h.showChests(); setState(() {}); }, child: Text('Pegar', style: display(13))),
            ]),
          ])),
        ],
        if (!s.missionsDone) ...[const SectionTitle('Missão atual'), _mission(s.curMission)],
        SectionTitle('Diárias  ·  ${s.dClaimed.where((x) => x).length}/5 (todas = baú)'),
        for (var i = 0; i < s.dTasks.length; i++) _period(s.dailyTask(i), s.dClaimed[i], s.dailyDone(i), 3, () { s.claimDailyTask(i); widget.h.flyGemsCenter(3); widget.h.showChests(); setState(() {}); }),
        const SectionTitle('Semanais (baú + 15 gemas)'),
        for (var i = 0; i < s.wTasks.length; i++) _period(s.weeklyTask(i), s.wClaimed[i], s.weeklyDone(i), 15, () { s.claimWeeklyTask(i); widget.h.flyGemsCenter(15); widget.h.showChests(); setState(() {}); }),
      ];
  Widget _period((String, double, double) t, bool claimed, bool done, int gems, VoidCallback onClaim) => GCard(color: claimed ? K.surface : null, padding: const EdgeInsets.fromLTRB(12, 10, 10, 10), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.$1, style: body(14, w: FontWeight.w900, color: claimed ? K.muted : K.ink)),
          const SizedBox(height: 3),
          GBar(value: t.$2 / t.$3, height: 8, color: K.green, label: '${fmt(math.min(t.$2, t.$3))}/${fmt(t.$3)}'),
        ])),
        const SizedBox(width: 8),
        claimed ? const Icon(Icons.check_circle_rounded, color: K.green, size: 26)
            : GBtn(color: K.green, enabled: done, pulse: done, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), onTap: onClaim, child: Price('$gems', icon: 'gem', size: 13)),
      ]));
  Widget _day(int i) {
    final r = dailyRewards[i];
    final cur = i == s.dailyDay % 7, done = i < s.dailyDay % 7;
    return Container(
      width: 40, padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: cur ? K.goldL : done ? K.greenL : K.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: cur ? K.gold : Colors.transparent, width: 1.6)),
      child: Column(children: [
        Text('D${i + 1}', style: body(10, color: K.muted)),
        Ico(r.$1 == 'gems' ? 'gem' : r.$1 == 'boost' ? 'bolt' : r.$1 == 'chest' ? 'chest_gold' : 'coin', size: 22),
        Text(r.$1 == 'gems' ? '${r.$2.toInt()}' : r.$1 == 'boost' ? '30m' : r.$1 == 'chest' ? 'baú' : '\$', style: body(10, w: FontWeight.w900)),
      ]),
    );
  }
  Widget _mission(Mission m) {
    final p = s.missionProgress(m), ready = s.missionReady;
    return GCard(child: Row(children: [
      IcoBox(m.type == 'lvl' || m.type == 'unlock' ? stationById(m.target).icon : m.type == 'flights' ? 'plane' : m.type == 'star' ? 'star' : m.type == 'collect' ? 'cash' : 'cap', color: K.orange, size: 44),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.missionText(m), style: body(15, w: FontWeight.w900)),
        const SizedBox(height: 5), GBar(value: p.$1 / p.$2, height: 8, label: '${fmt(math.min(p.$1, p.$2))}/${fmt(p.$2)}'),
      ])),
      const SizedBox(width: 8),
      ready ? GBtn(color: K.green, pulse: true, radius: 14, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), onTap: () { widget.h.claimMission(); setState(() {}); }, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Pegar ', style: display(13)), Price('${s.missionGems}', icon: 'gem', size: 13)]))
          : GBtn(color: K.blue, radius: 14, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), onTap: () { if (m.type == 'lvl' || m.type == 'unlock') { widget.h.focusStation(m.target); } else if (m.type == 'manager') { widget.h.openPanel('team'); } else if (m.type == 'star') { widget.h.openPanel('stars'); } else { widget.h.closePanel(); } }, child: Text('Ir', style: display(14))),
    ]));
  }
  List<Widget> _pass() {
    final tier = s.seasonTier, theme = seasonThemes[s.sId % seasonThemes.length];
    final inTier = (s.sPts % seasonPts) / seasonPts;
    return [
      GCard(color: K.purpleL, child: Column(children: [
        Row(children: [const Ico('pass', size: 44), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Passe: $theme', style: body(16, w: FontWeight.w900)), Text('Nível $tier/30 · ganhe pontos com missões, estrelas e níveis', style: body(12, color: K.muted))]))]),
        const SizedBox(height: 6),
        GBar(value: tier >= 30 ? 1 : inTier, height: 9, color: K.purple, track: Colors.white, label: tier >= 30 ? 'Completo' : '${s.sPts % seasonPts}/$seasonPts'),
      ])),
      for (var t = 0; t < 30; t++) _passRow(t),
    ];
  }
  Widget _passRow(int t) {
    final r = seasonReward(t), got = s.sClaimed.contains(t), ok = s.seasonReady(t);
    final ic = r.$1 == 'gems' ? 'gem' : r.$1 == 'coins' ? 'coin' : r.$1 == 'miles' ? 'miles' : r.$1;
    final label = r.$1 == 'gems' ? '${r.$2.toInt()} gemas' : r.$1 == 'coins' ? 'Dinheiro' : r.$1 == 'miles' ? '${r.$2.toInt()} milhas' : r.$1 == 'chest_gold' ? 'Baú de ouro' : 'Baú';
    return Opacity(opacity: t < s.seasonTier || t == s.seasonTier ? 1 : 0.55, child: GCard(color: got ? K.surface : null, padding: const EdgeInsets.fromLTRB(10, 7, 10, 7), child: Row(children: [
      Container(width: 30, height: 30, alignment: Alignment.center, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: t < s.seasonTier ? K.purple : K.purpleL, shape: BoxShape.circle), child: Text('${t + 1}', style: body(13, color: t < s.seasonTier ? Colors.white : K.purple, w: FontWeight.w900))),
      Ico(ic, size: 32), const SizedBox(width: 8),
      Expanded(child: Text(label, style: body(14, w: FontWeight.w900))),
      got ? const Icon(Icons.check_circle_rounded, color: K.green, size: 24)
          : GBtn(color: K.purple, enabled: ok, pulse: ok, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), onTap: () { final res = s.claimSeason(t); if (res.$1 == 'coins') widget.h.flyCash(res.$2); if (res.$1 == 'gems') widget.h.flyGemsCenter(res.$2.toInt()); widget.h.showChests(); Sfx.play('gift'); setState(() {}); }, child: Text('Pegar', style: display(12.5))),
    ])));
  }
  List<Widget> _ach() => [
        for (final a in achievements) () {
          final cur = a.key == 'city' ? s.city.toDouble() : s.c(a.key), done = s.achDone(a), got = s.achClaimed.contains(a.id);
          return GCard(color: got ? K.surface : null, padding: const EdgeInsets.fromLTRB(10, 9, 10, 9), child: Row(children: [
            IcoBox(a.icon, color: K.gold, size: 42, opacity: done ? 1 : 0.45), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name, style: body(15, w: FontWeight.w900)),
              const SizedBox(height: 3),
              GBar(value: cur / a.n, height: 8, color: K.gold, label: '${fmt(math.min(cur, a.n))}/${fmt(a.n)}'),
            ])),
            const SizedBox(width: 8),
            got ? const Icon(Icons.check_circle_rounded, color: K.green, size: 26)
                : GBtn(color: K.green, enabled: done, pulse: done, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), onTap: () { s.claimAch(a); widget.h.flyGemsCenter(a.gems); Sfx.play('level'); setState(() {}); }, child: Price('${a.gems}', icon: 'gem', size: 13)),
          ]));
        }(),
      ];
}

/// Frota (cartas de avião) e rotas.
class FleetPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  const FleetPanel({super.key, required this.s, required this.h});
  @override
  State<FleetPanel> createState() => _FleetPanelState();
}

class _FleetPanelState extends State<FleetPanel> {
  int tab = 0;
  GameState get s => widget.s;
  static const rarCol = [Color(0xFF8A93A6), Color(0xFF3E8BFF), Color(0xFF8F62F8), Color(0xFFFFB020)];
  @override
  Widget build(BuildContext context) {
    final canLvl = planeModels.any((m) => s.canLevelModel(m.id));
    final canRoute = routes.any((r) => !s.routesOwned.contains(r.id) && s.routeReqOk(r) && s.money >= s.routeCost(r));
    return Sheet(title: 'Frota', subtitle: 'Aviões, rotas e contratos', icon: 'plane', color: K.blue, onClose: widget.h.closePanel, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tabs(labels: const ['Aviões', 'Rotas', 'Contratos'], index: tab, dots: [canLvl, canRoute, s.ctReady || s.ctOfferReady], onTap: (i) => setState(() => tab = i)),
      if (tab == 0) ..._planes() else if (tab == 1) ..._routes() else ..._contracts(),
    ]));
  }
  static const livCol = [Color(0xFF2F6BFF), Color(0xFFFF7A1A), Color(0xFF18B48D), Color(0xFFFFB627), Color(0xFF8B5CF6), Color(0xFFE8343B)];
  List<Widget> _contracts() {
    if (s.ctAir >= 0) {
      final a = airlines[s.ctAir], left = math.max(0, s.ctUntil - nowMs()) / 1000;
      return [
        GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: livCol[a.$2].withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)), child: Ico('pm_1_${a.$2}', size: 42)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Contrato ${a.$1}', style: body(17, w: FontWeight.w900)),
              Text(s.ctReady ? 'Concluído! Pegue o prêmio.' : 'Faça ${s.ctNeed} voos com aviões ${a.$1} · ${fmtTime(left)}', style: body(12.5, color: K.muted)),
            ])),
          ]),
          const SizedBox(height: 10),
          GBar(value: s.ctDone / s.ctNeed, color: livCol[a.$2], label: '${math.min(s.ctDone, s.ctNeed)}/${s.ctNeed}'),
          const SizedBox(height: 10),
          Row(children: [
            Price('${s.ctGems}', icon: 'gem', size: 15), const SizedBox(width: 10), Price('${s.ctNeed}', icon: 'miles', size: 15), const SizedBox(width: 10), Ico(s.ctNeed >= 30 ? 'chest_gold' : 'chest', size: 26),
            const Spacer(),
            if (s.ctReady) GBtn(color: K.green, pulse: true, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), onTap: () { final g = s.ctGems; s.claimContract(); widget.h.flyGemsCenter(g); widget.h.showChests(); Sfx.play('level'); setState(() {}); }, child: Text('Pegar', style: display(15)))
            else GBtn(color: K.grey, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), onTap: () { s.dropContract(); setState(() {}); }, child: Text('Desistir', style: display(13))),
          ]),
        ])),
        Text('Aviões da companhia aparecem mais vezes enquanto o contrato estiver ativo.', textAlign: TextAlign.center, style: body(12.5, color: K.muted)),
      ];
    }
    if (!s.ctOfferReady) {
      return [GCard(child: Column(children: [
        const Ico('contract', size: 54),
        const SizedBox(height: 6),
        Text(s.tut < 7 ? 'Termine o tutorial para receber propostas.' : 'Novas propostas em ${fmtTime(math.max(0, s.ctNext - nowMs()) / 1000)}', textAlign: TextAlign.center, style: body(14, color: K.muted)),
      ]))];
    }
    return [
      Text('Companhias aéreas querem operar no seu aeroporto. Escolha um contrato:', textAlign: TextAlign.center, style: body(13, color: K.muted)),
      const SizedBox(height: 8),
      for (final o in s.ctOffers()) GCard(padding: const EdgeInsets.all(10), child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: livCol[airlines[o.$1].$2].withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)), child: Ico('pm_1_${airlines[o.$1].$2}', size: 42)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(airlines[o.$1].$1, style: body(15, w: FontWeight.w900)),
          Text('${o.$2} voos em ${o.$3} min', style: body(12.5, color: K.muted)),
          const SizedBox(height: 3),
          Row(children: [Price('${o.$4}', icon: 'gem', size: 13), const SizedBox(width: 8), Ico(o.$2 >= 30 ? 'chest_gold' : 'chest', size: 20)]),
        ])),
        GBtn(color: K.blue, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: () { s.takeContract(o); Sfx.play('ding'); widget.h.refresh(); setState(() {}); }, child: Text('Aceitar', style: display(14))),
      ])),
    ];
  }
  List<Widget> _planes() => [
        Text('Cada avião da coleção aumenta o preço das passagens dos voos do seu tamanho. Cartas repetidas sobem o nível. Ganhe cartas em baús.', style: body(13, color: K.muted), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        for (var t = 0; t < 3; t++) ...[
          SectionTitle('${planeTypes[t].name}  ·  bônus +${(s.fleetBonus(t) * 100).round()}%'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final m in planeModels.where((m) => m.tier == t)) _card(m)]),
          const SizedBox(height: 8),
        ],
      ];
  Widget _card(PlaneModel m) {
    final l = s.mlv[m.id] ?? 0, owned = l > 0, cards = s.cards[m.id] ?? 0;
    final need = l < cardsToLevel.length ? cardsToLevel[l] : 0;
    final can = s.canLevelModel(m.id);
    return GestureDetector(
      onTap: () { if (can && s.levelModel(m.id)) { Sfx.play('level'); widget.h.refresh(); setState(() {}); } },
      child: Container(
        width: 104, padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: owned ? Colors.white : K.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: owned ? rarCol[m.rarity].withValues(alpha: 0.6) : K.line, width: owned ? 2 : 1), boxShadow: owned ? K.shadowS : null),
        child: Column(children: [
          Text(rarityNames[m.rarity].toUpperCase(), style: body(9, color: rarCol[m.rarity], w: FontWeight.w900)),
          Container(height: 62, width: 86, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: owned ? rarCol[m.rarity].withValues(alpha: 0.12) : K.track), child: Opacity(opacity: owned ? 1 : 0.4, child: Ico('pm_${m.tier}_${m.liv}', size: 62))),
          Text(m.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, w: FontWeight.w900)),
          Text(owned ? 'Nv $l · +${(rarityBonus[m.rarity] * (1 + 0.5 * (l - 1)) * 100).round()}%' : 'Não tem', style: body(10, color: K.muted)),
          if (owned && l < cardsToLevel.length) Padding(padding: const EdgeInsets.only(top: 4), child: can ? Container(padding: const EdgeInsets.symmetric(vertical: 2), decoration: BoxDecoration(color: K.green, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: Text('Subir!', style: display(11))) : GBar(value: need == 0 ? 1 : cards / need, height: 6, color: K.blue, label: '$cards/$need')),
        ]),
      ),
    );
  }
  List<Widget> _routes() => [
        _RouteMap(s: s),
        const SizedBox(height: 8),
        Text('Cada rota aumenta o preço de todas as passagens e manda voos para novos destinos. Rotas valem para todas as cidades.', style: body(13, color: K.muted), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        for (final r in routes) () {
          final own = s.routesOwned.contains(r.id), ok = s.routeReqOk(r);
          return GCard(color: own ? K.greenL : null, padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), child: Row(children: [
            IcoBox(r.intl ? 'globe' : 'route', color: K.blue, size: 40), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: body(15, w: FontWeight.w900)),
              Text('+${(r.bonus * 100).round()}% nas passagens${r.intl ? ' · internacional' : ''}', style: body(12, color: K.muted)),
            ])),
            own ? const Tag('ATIVA', K.green)
                : !ok ? Row(mainAxisSize: MainAxisSize.min, children: [const Ico('star', size: 18), Text(' ${r.star}', style: body(13, color: K.purple, w: FontWeight.w900))])
                : GBtn(color: K.green, enabled: s.money >= s.routeCost(r), radius: 12, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), onTap: () { if (s.buyRoute(r)) { Sfx.play('level'); widget.h.refresh(); setState(() {}); } }, child: Price(fmt(s.routeCost(r)), size: 13)),
          ]));
        }(),
      ];
}

class _RouteMap extends StatefulWidget {
  final GameState s;
  const _RouteMap({required this.s});
  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(height: 190, child: AnimatedBuilder(animation: a, builder: (_, __) => CustomPaint(painter: _MapPainter(widget.s, a.value), size: Size.infinite))));
}

class _MapPainter extends CustomPainter {
  final GameState s;
  final double t;
  _MapPainter(this.s, this.t);
  @override
  void paint(Canvas c, Size z) {
    c.drawRect(Offset.zero & z, Paint()..color = const Color(0xFF7CC4F5));
    final land = Paint()..color = const Color(0xFFA6DB86);
    // continentes estilizados
    c.drawOval(Rect.fromLTWH(z.width * 0.08, z.height * 0.28, z.width * 0.52, z.height * 0.7), land);
    c.drawOval(Rect.fromLTWH(z.width * 0.0, z.height * 0.0, z.width * 0.3, z.height * 0.3), land);
    c.drawOval(Rect.fromLTWH(z.width * 0.72, z.height * 0.0, z.width * 0.3, z.height * 0.45), land);
    final home = Offset(z.width * 0.4, z.height * 0.66);
    for (final r in routes) {
      final p = Offset(r.mx * z.width, r.my * z.height);
      final own = s.routesOwned.contains(r.id);
      final ctrl = Offset((home.dx + p.dx) / 2, math.min(home.dy, p.dy) - 30);
      final path = Path()..moveTo(home.dx, home.dy)..quadraticBezierTo(ctrl.dx, ctrl.dy, p.dx, p.dy);
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = own ? 2.5 : 1.2..color = own ? const Color(0xFFFFC531) : const Color(0x66FFFFFF));
      c.drawCircle(p, own ? 5 : 3.5, Paint()..color = own ? Colors.white : const Color(0x99FFFFFF));
      if (own) {
        final k = (t + r.mx) % 1;
        final q = Offset.lerp(Offset.lerp(home, ctrl, k)!, Offset.lerp(ctrl, p, k)!, k)!;
        c.drawCircle(q, 4, Paint()..color = const Color(0xFF1E2A47));
        c.drawCircle(q, 2.5, Paint()..color = Colors.white);
      }
    }
    c.drawCircle(home, 8, Paint()..color = const Color(0xFFE8343B));
    c.drawCircle(home, 4, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}

/// Equipe: gerentes e pesquisa.
class TeamPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  const TeamPanel({super.key, required this.s, required this.h});
  @override
  State<TeamPanel> createState() => _TeamPanelState();
}

class _TeamPanelState extends State<TeamPanel> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final mAv = managers.any((m) => !s.hasMgr(m.id) && s.money >= s.mgrCost(m));
    final rAv = researchList.any(s.canResearch);
    return Sheet(title: 'Equipe', subtitle: 'Gerentes com habilidades e pesquisa', icon: 'cap', color: K.purple, onClose: widget.h.closePanel, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tabs(labels: const ['Gerentes', 'Pesquisa'], index: tab, dots: [mAv, rAv], onTap: (i) => setState(() => tab = i)),
      if (tab == 0) ...[
        Text('Gerentes trabalham no aeroporto atual. Cada um tem uma habilidade especial (botões no canto esquerdo da tela).', style: body(13, color: K.muted), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        for (final m in managers) () {
          final ab = abilities.where((a) => a.mgr == m.id).toList();
          final has = s.hasMgr(m.id);
          return GCard(color: has ? K.greenL : null, padding: const EdgeInsets.all(10), child: Row(children: [
            Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: has ? Colors.white : K.purpleL), padding: const EdgeInsets.all(5), child: const Ico('pax', size: 40)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m.name} · ${m.role}', style: body(15, w: FontWeight.w900)),
              Text(m.effect, style: body(12.5, color: K.greenD)),
              if (ab.isNotEmpty) Text('Habilidade: ${ab.first.name} — ${ab.first.desc}', style: body(11.5, color: K.purple)),
            ])),
            if (has) const Icon(Icons.check_circle_rounded, color: K.green, size: 28)
            else GBtn(color: K.purple, radius: 12, enabled: s.money >= s.mgrCost(m), pulse: s.tut == 6 && s.money >= s.mgrCost(m), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), onTap: () { if (s.hire(m)) { Sfx.play('level'); widget.h.refresh(); setState(() {}); } }, child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Contratar', style: display(12)), Price(fmt(s.mgrCost(m)), size: 13)])),
          ]));
        }(),
      ] else ...[
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Você tem ', style: body(15)), Price(fmt(s.miles), icon: 'miles', size: 18), Text(' milhas', style: body(15))]),
        Text('Ganhe milhas a cada voo. A pesquisa vale para sempre, em todas as cidades.', style: body(12, color: K.muted), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        for (final r in researchList) GCard(color: s.has(r.id) ? K.greenL : null, padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), child: Row(children: [
          IcoBox(r.icon, color: K.blue, size: 42), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.name, style: body(15, w: FontWeight.w900)), Text(r.desc, style: body(12, color: K.greenD))])),
          s.has(r.id) ? const Icon(Icons.check_circle_rounded, color: K.green, size: 26)
              : GBtn(color: K.blue, radius: 12, enabled: s.canResearch(r), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), onTap: () { if (s.doResearch(r)) { Sfx.play('level'); widget.h.refresh(); setState(() {}); } }, child: Price(fmt(r.cost), icon: 'miles', size: 13)),
        ])),
      ],
    ]));
  }
}

class ShopPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  const ShopPanel({super.key, required this.s, required this.h});
  @override
  State<ShopPanel> createState() => _ShopPanelState();
}

class _ShopPanelState extends State<ShopPanel> {
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    String left(int at) => fmtTime(math.max(0, (at - nowMs()) / 1000));
    Widget item(String ico, String title, String sub, Widget btn) => GCard(padding: const EdgeInsets.all(10), child: Row(children: [
          IcoBox(ico, color: K.purple, size: 48), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: body(16, w: FontWeight.w900)), Text(sub, style: body(12, color: K.muted))])),
          btn,
        ]));
    Widget gemBtn(int cost, VoidCallback onBuy) => GBtn(color: K.purple, radius: 14, enabled: s.gems >= cost, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: onBuy, child: Price('$cost', icon: 'gem', size: 16));
    Widget free(bool ready, VoidCallback onTap) => GBtn(color: K.green, radius: 14, enabled: ready, pulse: ready, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: onTap, child: Text('Grátis', style: display(15)));
    return Sheet(title: 'Loja', subtitle: 'Você tem ${s.gems} gemas', icon: 'bag', color: K.purple, onClose: widget.h.closePanel, child: Column(children: [
      Text('Gemas vêm de missões, estrelas, contratos, baús, eventos e minijogos.', textAlign: TextAlign.center, style: body(12.5, color: K.muted)),
      const SizedBox(height: 4),
      const SectionTitle('Grátis'),
      item('wheel', 'Roleta do dia', s.spinReady ? 'Gire agora!' : 'Volte amanhã', free(s.spinReady, widget.h.openWheel)),
      item('chest', 'Baú grátis', s.chestReady ? 'Pronto para abrir!' : 'De novo em ${left(s.chestAt)}', free(s.chestReady, () { s.takeFreeChest(); widget.h.showChests(); setState(() {}); })),
      item('bolt', 'Lucro x2 por 10 min', s.boostOn ? 'Ativo: ${left(s.boostUntil)}' : 'Dobre o lucro agora', free(!s.boostOn, () { widget.h.closePanel(); widget.h.boostTap(); })),
      const SectionTitle('Turbinas'),
      item('bolt', 'Lucro x2 por 30 min', s.boostOn ? 'Ativo: ${left(s.boostUntil)}' : 'Dobra tudo que o aeroporto fatura', gemBtn(20, () { if (s.buyBoost(20, 30)) { Sfx.play('boost'); widget.h.refresh(); setState(() {}); } })),
      item('rush', 'Hora do rush (5 min)', s.rushOn ? 'Ativo: ${left(s.rushUntil)}' : 'Chegam 3x mais passageiros', gemBtn(12, () { if (s.buyRush(12)) { Sfx.play('boost'); widget.h.refresh(); setState(() {}); } })),
      item('turbo', 'Turbo pista (5 min)', s.turboOn ? 'Ativo: ${left(s.turboUntil)}' : 'Voos 2x mais rápidos', gemBtn(12, () { if (s.buyTurbo(12)) { Sfx.play('boost'); widget.h.refresh(); setState(() {}); } })),
      const SectionTitle('Baús e dinheiro'),
      item('chest', 'Baú de cartas', '3 cartas de avião + prêmios', gemBtn(25, () { if (s.buyChest(25, 'chest')) { widget.h.showChests(); setState(() {}); } })),
      item('chest_gold', 'Baú de ouro', '6 cartas com mais chance de lendários', gemBtn(80, () { if (s.buyChest(80, 'chest_gold')) { widget.h.showChests(); setState(() {}); } })),
      item('cash', 'Maleta de dinheiro', '\$${fmt(s.cashPack(2))} (2 horas de lucro)', gemBtn(30, () { final v = s.cashPack(2); if (s.buyCash(30, 2)) { widget.h.flyCash(v); setState(() {}); } })),
      item('cash', 'Cofre de dinheiro', '\$${fmt(s.cashPack(8))} (8 horas de lucro)', gemBtn(90, () { final v = s.cashPack(8); if (s.buyCash(90, 8)) { widget.h.flyCash(v); setState(() {}); } })),
    ]));
  }
}

/// Rede de aeroportos: o atual, o próximo à venda e o álbum de todos.
class CitiesPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  const CitiesPanel({super.key, required this.s, required this.h});
  @override
  State<CitiesPanel> createState() => _CitiesPanelState();
}

class _CitiesPanelState extends State<CitiesPanel> {
  GameState get s => widget.s;
  static const themeCol = [Color(0xFF3FAE5A), Color(0xFF2F6BFF), Color(0xFF7C5CFA), Color(0xFF5BA8D8), Color(0xFFE0A21A), Color(0xFF14B8A6)];
  @override
  Widget build(BuildContext context) {
    final h = widget.h;
    final cur = cityAt(s.city), next = cityAt(s.city + 1);
    final pk = s.perk, pn = perkFor(s.city + 1), en = specialFor(s.city + 1), ec = specialFor(s.city);
    final price = s.nextPrice, have = s.money + s.pilesTotal;
    return Sheet(title: 'Rede de aeroportos', subtitle: '${s.city + 1} aeroporto${s.city > 0 ? 's' : ''} · você está em ${cur.name}', icon: 'network', color: K.teal, onClose: h.closePanel, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (s.city > 0) GCard(color: K.greenL, child: Row(children: [
        const IcoBox('network', color: K.green, size: 46),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Lucro dos outros aeroportos', style: body(14.5, w: FontWeight.w900)),
          Text('+\$${fmt(s.netRate)}/s · guarda até 2 horas', style: body(12, color: K.greenD)),
          const SizedBox(height: 5),
          GBar(value: s.netRate > 0 ? s.netPile / (s.netRate * GameState.netCap) : 0, height: 7, color: K.green),
        ])),
        const SizedBox(width: 8),
        GBtn(color: K.green, radius: 12, enabled: s.netPile > 0, pulse: s.netReady, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), onTap: () { final v = s.collectNet(); if (v > 0) { h.flyCash(v); Sfx.play('cash'); setState(() {}); } }, child: Price(fmt(s.netPile), size: 13)),
      ])),
      GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IcoBox(ec.icon, color: themeCol[s.city % 6], size: 52),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cur.name, style: body(17, w: FontWeight.w900)),
            Text(cur.sub, style: body(12.5, color: K.muted)),
            Row(children: [for (var i = 0; i < 5; i++) Opacity(opacity: i < s.star ? 1 : 0.2, child: const Ico('star', size: 18)), const SizedBox(width: 6), Text(s.ph.name, style: body(12, color: K.purple))]),
          ])),
        ]),
        const SizedBox(height: 8),
        _feat(Icons.place_rounded, K.blue, pk.name, pk.desc),
        _feat(Icons.apartment_rounded, themeCol[s.city % 6], 'Exclusivo: ${ec.name}', s.built(ec.id) ? 'Nível ${s.lvl(ec.id)}' : 'Libera com 1 estrela, ao lado da estrada'),
      ])),
      const SectionTitle('À venda'),
      GCard(border: s.star >= 5 ? K.green.withValues(alpha: 0.6) : null, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IcoBox(en.icon, color: themeCol[(s.city + 1) % 6], size: 52),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(next.name, style: body(17, w: FontWeight.w900)),
            Text(next.sub, style: body(12.5, color: K.muted)),
            Text('Tudo rende ${cityMult(s.city + 1) ~/ cityMult(s.city)}x mais', style: body(12.5, color: K.greenD)),
          ])),
        ]),
        const SizedBox(height: 8),
        _feat(Icons.place_rounded, K.blue, pn.name, pn.desc),
        _feat(Icons.apartment_rounded, themeCol[(s.city + 1) % 6], 'Exclusivo: ${en.name}', en.desc.replaceFirst(RegExp(r'^Só [^.]*\. '), '')),
        _feat(Icons.card_giftcard_rounded, K.purple, 'Bônus de compra', '${25 + (s.city + 1) * 10} gemas, baú de ouro e +20% de lucro passivo do aeroporto atual'),
        const SizedBox(height: 4),
        Text('Você começa o novo aeroporto do zero. Pesquisas, rotas, frota, gemas e milhas vão junto. ${cur.name} continua rendendo na sua rede.', style: body(12, color: K.muted)),
        const SizedBox(height: 10),
        if (s.star < 5) Row(children: [const Icon(Icons.lock_rounded, color: K.muted, size: 18), const SizedBox(width: 6), Expanded(child: Text('Conquiste as 5 estrelas de ${cur.name} para poder comprar (${s.star}/5)', style: body(13, color: K.muted)))])
        else ...[
          GBar(value: have / price, height: 8, color: K.green, label: '\$${fmt(math.min(have, price))} / \$${fmt(price)}'),
          const SizedBox(height: 10),
          Center(child: GBtn(color: K.green, enabled: s.canPrestige, pulse: s.canPrestige, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), onTap: h.doPrestige, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Comprar  ', style: display(17)), Price(fmt(price), size: 17)]))),
        ],
      ])),
      const SectionTitle('Álbum da rede'),
      for (var i = 0; i < math.max(cities.length, s.city + 2); i++) () {
        final own = i < s.city, here = i == s.city, e = specialFor(i);
        return GCard(color: here ? K.blueL : null, padding: const EdgeInsets.all(9), child: Row(children: [
          IcoBox(e.icon, color: themeCol[i % 6], size: 44, opacity: i <= s.city + 1 ? 1 : 0.35),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Flexible(child: Text(cityAt(i).name, style: body(14.5, color: i <= s.city + 1 ? K.ink : K.muted, w: FontWeight.w900), overflow: TextOverflow.ellipsis)), if (own) const Tag('SEU', K.green), if (here) const Tag('ATUAL', K.blue)]),
            Text('${e.name} · ${perkFor(i).name}', style: body(12, color: K.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Text('x${fmt(cityMult(i))}', style: body(13, color: K.greenD, w: FontWeight.w900)),
          const SizedBox(width: 6),
          Icon(own ? Icons.emoji_events_rounded : here ? Icons.flight_takeoff_rounded : Icons.lock_rounded, color: own ? K.gold : here ? K.blue : K.grey, size: 22),
        ]));
      }(),
    ]));
  }
  Widget _feat(IconData ic, Color c, String t, String d) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)), child: Icon(ic, color: c, size: 17)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: body(13.5, w: FontWeight.w900)), Text(d, style: body(12, color: K.muted))])),
      ]));
}

class SettingsPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  const SettingsPanel({super.key, required this.s, required this.h});
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool confirm = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    Widget sw(String label, bool v, void Function(bool) f) => SwitchListTile(value: v, onChanged: (x) { f(x); setState(() {}); widget.h.refresh(); }, title: Text(label, style: body(16)), activeThumbColor: K.green, dense: true);
    final hist = s.history;
    final mx = hist.isEmpty ? 1.0 : hist.reduce(math.max);
    return Sheet(title: 'Ajustes', subtitle: 'Som, estatísticas e progresso', icon: 'gear', color: K.navy2, onClose: widget.h.closePanel, child: Column(children: [
      GCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [
        sw('Música', s.music, (x) { s.music = Sfx.music = x; x ? Sfx.startMusic() : Sfx.stopMusic(); }),
        sw('Efeitos sonoros', s.sound, (x) => s.sound = Sfx.sound = x),
        sw('Vibração', s.vibration, (x) => s.vibration = Sfx.vibration = x),
      ])),
      GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Ico('stats', size: 28), const SizedBox(width: 6), Text('Estatísticas', style: body(16, w: FontWeight.w900))]),
        const SizedBox(height: 6),
        InfoRow('Chegada', perMin(s.lambda)), InfoRow('Check-in', perMin(s.muC)), InfoRow('Raio-X', perMin(s.muS)), InfoRow('Portões', perMin(s.gatesCap)),
        InfoRow('Gargalo', bottleneckName(s.bottleneck)),
        InfoRow('Satisfação', '${s.sat.round()}%  (gorjeta x${s.tipMult.toStringAsFixed(2)})'),
        InfoRow('Fase', s.ph.name),
        InfoRow('Decoração', '+${(s.decor.length * 3)}% receita'),
        InfoRow('Lucro', '\$${fmt(s.rate * 60)}/min'),
        const SizedBox(height: 8),
        Text('Faturamento (últimos 10 min)', style: body(12, color: K.muted)),
        const SizedBox(height: 4),
        SizedBox(height: 60, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final v in hist) Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1), height: 4 + 56 * (mx <= 0 ? 0 : v / mx), decoration: BoxDecoration(color: K.green, borderRadius: BorderRadius.circular(3)))),
          if (hist.isEmpty) Expanded(child: Center(child: Text('Coletando dados...', style: body(12, color: K.muted)))),
        ])),
        const SizedBox(height: 8),
        InfoRow('Voos realizados', fmt(s.flightsAll)),
        InfoRow('Faturamento total', '\$${fmt(s.earnedAll)}'),
        InfoRow('Nível do aeroporto', '${s.alv}'),
      ])),
      if (!confirm) GBtn(color: K.red, onTap: () => setState(() => confirm = true), child: Text('Recomeçar do zero', style: display(15)))
      else GCard(color: K.redL, child: Column(children: [
        Text('Apagar todo o progresso? Não dá para desfazer.', style: body(15, color: K.red), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GBtn(color: K.grey, onTap: () => setState(() => confirm = false), child: Text('Cancelar', style: display(14))),
          const SizedBox(width: 10),
          GBtn(color: K.red, onTap: widget.h.resetGame, child: Text('Apagar', style: display(14))),
        ]),
      ])),
      const SizedBox(height: 8),
      Text('SkyPort Tycoon v3.4', style: body(12, color: K.muted)),
    ]));
  }
}

/// Minijogos: cada um rende dinheiro, gemas e baús; recarga de 4 minutos.
class GamesPanel extends StatelessWidget {
  final GameState s;
  final PanelHost h;
  const GamesPanel({super.key, required this.s, required this.h});
  static const desc = {
    'land': 'Segure para descer e solte no ponto certo da pista',
    'xray': 'Ache os itens proibidos nas malas',
    'bag': 'Arraste cada mala para o avião da cor dela',
    'atc': 'Autorize os pousos um de cada vez',
    'yard': 'Mande cada avião para o portão da cor certa',
  };
  @override
  Widget build(BuildContext context) {
    final list = h.games;
    return Sheet(title: 'Minijogos', subtitle: 'Até 3 estrelas: dinheiro, gemas e baú', icon: 'landing', color: K.orange, onClose: h.closePanel, child: Column(children: [
      for (final g in list) GCard(padding: const EdgeInsets.all(10), child: Row(children: [
        IcoBox(g.$3, color: K.orange, size: 50),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g.$2, style: body(16, w: FontWeight.w900)),
          Text(desc[g.$1] ?? '', style: body(12.5, color: K.muted)),
        ])),
        const SizedBox(width: 8),
        GBtn(color: K.green, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: () => h.playGame(g.$1), child: Row(mainAxisSize: MainAxisSize.min, children: [if (!g.$4) ...[const Icon(Icons.play_circle_fill_rounded, size: 18), const SizedBox(width: 4)], Text('Jogar', style: display(14))])),
      ])),
      if (s.phase < 2) Text(s.phase < 1 ? 'Novos jogos chegam quando o aeroporto crescer: Torre (2ª fase) e Pátio (3ª fase).' : 'O jogo do Pátio chega na próxima fase do aeroporto.', textAlign: TextAlign.center, style: body(12.5, color: K.muted)),
    ]));
  }
}
