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
  void flyCash(double amount);
}

Widget buildPanel(String p, GameState s, PanelHost h) {
  if (p.startsWith('st:')) return StationPanel(s: s, h: h, id: p.substring(3));
  switch (p) {
    case 'upgrades': return UpgradesPanel(s: s, h: h);
    case 'managers': return ManagersPanel(s: s, h: h);
    case 'missions': return MissionsPanel(s: s, h: h);
    case 'shop': return ShopPanel(s: s, h: h);
    case 'cities': return CitiesPanel(s: s, h: h);
    case 'settings': return SettingsPanel(s: s, h: h);
  }
  return const SizedBox.shrink();
}

Color stColor(St st) {
  switch (st.kind) {
    case Kind.gate: return K.gold;
    case Kind.boost: return K.purple;
    case Kind.building: return K.orange;
    case Kind.flow: return K.blue;
  }
}

String perMin(double v) => '${fmt(v * 60)}/min';

/// Botões x1 / x10 / MÁX.
class BuyMode extends StatelessWidget {
  final GameState s;
  final VoidCallback onChange;
  const BuyMode({super.key, required this.s, required this.onChange});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: K.navy, borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final m in [1, 10, -1])
            GestureDetector(
              onTap: () { Sfx.click(); s.buyMode = m; onChange(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: s.buyMode == m ? K.gold : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                child: Text(m == -1 ? 'MÁX' : 'x$m', style: display(14, color: s.buyMode == m ? K.navy : Colors.white, outline: false)),
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
  switch (id) {
    case 'entrada':
      return [('Chegada de passageiros', perMin(s.lambda), nx(() => perMin(s.lambda))), ('Estacionamento', '${[5, 10, 16, 24][parkTier(l) - 1]} vagas', null)];
    case 'checkin':
      return [('Atendimento', perMin(s.muC), nx(() => perMin(s.muC))), ('Balcões abertos', '${desksFor(l)}', nx(() => '${desksFor(s.lvl(id))}'))];
    case 'seguranca':
      return [('Inspeção', perMin(s.muS), nx(() => perMin(s.muS))), ('Faixas de raio-X', '${lanesFor(l)}', nx(() => '${lanesFor(s.lvl(id))}'))];
    case 'lojas':
      return [('Gasto por passageiro', '\$${fmt(s.shopSpend * s.revMult)}', nx(() => '\$${fmt(s.shopSpend * s.revMult)}')), ('Quiosques', '${shopsFor(l)}', nx(() => '${shopsFor(s.lvl(id))}'))];
    case 'pista':
      return [('Velocidade dos voos', 'x${s.speed.toStringAsFixed(2)}', nx(() => 'x${s.speed.toStringAsFixed(2)}')), ('Maior avião', planeTypes[runwayTier(l)].name, nx(() => planeTypes[runwayTier(s.lvl(id))].name))];
    case 'torre':
      return [('Bônus de receita', '+${(6 * (l - 1))}%', nx(() => '+${(6 * (s.lvl(id) - 1))}%'))];
    case 'vip':
      return [('Bônus na passagem', '+${4 * l}%', nx(() => '+${4 * s.lvl(id)}%'))];
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

String bottleneckName(String b) => b == 'gates' ? 'Portões' : stationById(b).name;

/// Painel de uma estação: nível, números e botão de melhorar.
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
    final title = st.name;
    if (l <= 0) {
      final orderOk = s.unlockOk(st);
      return Sheet(title: title, icon: st.icon, color: stColor(st), onClose: widget.h.closePanel, child: Column(children: [
        GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(st.desc, style: body(15)),
          const SizedBox(height: 10),
          if (!orderOk) Text('Abra o ${stationById('g${st.gate - 1}').name} primeiro.', style: body(14, color: K.red)),
        ])),
        GBtn(
          color: K.green, enabled: s.canUnlock(st), pulse: s.canUnlock(st),
          onTap: () { if (s.unlock(st.id)) { widget.h.refresh(); } },
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text('CONSTRUIR  ', style: display(20)), Price(fmt(st.unlock), size: 20)]),
        ),
      ]));
    }
    if (st.oneTime) {
      return Sheet(title: title, icon: st.icon, color: stColor(st), onClose: widget.h.closePanel, child: GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(st.desc, style: body(15)), const SizedBox(height: 8), Text('Construído', style: body(16, color: K.greenD, w: FontWeight.w900)),
      ])));
    }
    final b = s.buyInfo(st);
    final can = b.$1 > 0 && s.money >= b.$2;
    final nm = nextMilestone(l);
    final prev = milestones.lastWhere((m) => m <= l, orElse: () => 0);
    final stats = stationStats(s, st, b.$1);
    final isBott = s.bottleneck == st.id || (s.bottleneck == 'gates' && st.kind == Kind.gate);
    final G = st.kind == Kind.gate ? s.gates[st.gate] : null;
    return Sheet(title: '$title  ·  Nv $l', icon: st.icon, color: stColor(st), onClose: widget.h.closePanel, child: Column(children: [
      if (isBott && s.bottleneck != 'none')
        Container(
          width: double.infinity, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFFFE1E1), borderRadius: BorderRadius.circular(14), border: Border.all(color: K.red, width: 2)),
          child: Text(st.kind == Kind.gate ? 'Os portões são o gargalo: mais portões ou aviões maiores aumentam a vazão.' : 'Esta é a etapa mais lenta do aeroporto agora. Melhorar aqui aumenta seu lucro!', style: body(14, color: const Color(0xFFB3261E))),
        )
      else if (st.kind == Kind.flow && st.id != 'lojas')
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Gargalo atual: ${bottleneckName(s.bottleneck)}', style: body(13, color: K.muted))),
      GCard(child: Column(children: [
        for (final r in stats) InfoRow(r.$1, r.$2, next: r.$3 != null && r.$3 != r.$2 ? '→ ${r.$3}' : null),
        if (G != null) InfoRow('Agora', G.phase == Ph.empty ? 'Aguardando avião' : '${Ph.names[G.phase]} · ${G.flight}${G.dest.isNotEmpty && G.phase >= Ph.boarding ? ' → ${G.dest}' : ''}'),
        if (nm != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Text('Bônus x2 no nível $nm', style: body(13, color: K.muted)),
            const Spacer(),
            Text('$l/$nm', style: body(13, w: FontWeight.w900)),
          ]),
          const SizedBox(height: 4),
          GBar(value: (l - prev) / (nm - prev), color: K.gold, height: 14),
        ],
      ])),
      Text(st.desc, style: body(13, color: K.muted, w: FontWeight.w600), textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Row(children: [
        BuyMode(s: s, onChange: () => setState(() {})),
        const SizedBox(width: 10),
        Expanded(child: GBtn(
          color: K.green, enabled: can, pulse: can && s.tut == 2,
          onTap: () { if (s.upgrade(st.id)) { if (s.tut == 2) s.tut = 3; widget.h.refresh(); setState(() {}); } },
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l >= GameState.maxL ? 'NÍVEL MÁXIMO' : 'MELHORAR +${b.$1}', style: display(17)),
            if (l < GameState.maxL) Price(fmt(b.$2), size: 16),
          ]),
        )),
      ]),
    ]));
  }
}

/// Lista com todas as estações para melhorar rápido.
class UpgradesPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  const UpgradesPanel({super.key, required this.s, required this.h});
  @override
  State<UpgradesPanel> createState() => _UpgradesPanelState();
}

class _UpgradesPanelState extends State<UpgradesPanel> {
  GameState get s => widget.s;
  @override
  Widget build(BuildContext context) {
    final list = stations.where((st) => s.built(st.id) || (s.unlockOk(st))).toList();
    return Sheet(title: 'Melhorias', icon: 'up', color: K.green, onClose: widget.h.closePanel, child: Column(children: [
      Row(children: [
        Expanded(child: Text('Gargalo: ${bottleneckName(s.bottleneck)}', style: body(14, color: K.red, w: FontWeight.w900))),
        BuyMode(s: s, onChange: () => setState(() {})),
      ]),
      const SizedBox(height: 10),
      for (final st in list) _row(st),
    ]));
  }
  Widget _row(St st) {
    final l = s.lvl(st.id);
    final locked = l <= 0;
    final b = locked ? (1, st.unlock) : s.buyInfo(st);
    final can = !locked ? (b.$1 > 0 && s.money >= b.$2 && !st.oneTime) : s.canUnlock(st);
    final bott = s.bottleneck == st.id || (s.bottleneck == 'gates' && st.kind == Kind.gate);
    return GCard(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), child: Row(children: [
      GestureDetector(onTap: () => widget.h.focusStation(st.id), child: Ico(st.icon, size: 44)),
      const SizedBox(width: 8),
      Expanded(child: GestureDetector(
        onTap: () => widget.h.focusStation(st.id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(st.name, style: body(16, w: FontWeight.w900), overflow: TextOverflow.ellipsis)),
            if (bott) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: K.red, borderRadius: BorderRadius.circular(8)), child: Text('GARGALO', style: display(10, outline: false))),
          ]),
          Text(locked ? 'Não construído' : st.oneTime ? 'Construído' : 'Nível $l${nextMilestone(l) != null ? '  ·  x2 no ${nextMilestone(l)}' : ''}', style: body(12, color: K.muted)),
        ]),
      )),
      if (!st.oneTime || locked)
        GBtn(
          color: locked ? K.blue : K.green, enabled: can, radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          onTap: () { final ok = locked ? s.unlock(st.id) : s.upgrade(st.id); if (ok) { widget.h.refresh(); setState(() {}); } },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(locked ? 'CONSTRUIR' : '+${b.$1}', style: display(13)),
            Price(fmt(b.$2), size: 13),
          ]),
        ),
    ]));
  }
}

class ManagersPanel extends StatefulWidget {
  final GameState s;
  final PanelHost h;
  const ManagersPanel({super.key, required this.s, required this.h});
  @override
  State<ManagersPanel> createState() => _ManagersPanelState();
}

class _ManagersPanelState extends State<ManagersPanel> {
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Sheet(title: 'Gerentes', icon: 'cap', color: K.navy2, onClose: widget.h.closePanel, child: Column(children: [
      Text('Gerentes trabalham no aeroporto atual e dão bônus permanentes.', style: body(13, color: K.muted), textAlign: TextAlign.center),
      const SizedBox(height: 10),
      for (final m in managers) GCard(color: s.hasMgr(m.id) ? const Color(0xFFE6F8EA) : null, child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFDDE8FF), border: Border.all(color: K.navy, width: 2.5)),
          child: Stack(alignment: Alignment.center, children: [const Ico('pax', size: 40), Positioned(top: 0, child: Ico('cap', size: 22))]),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m.name} · ${m.role}', style: body(15, w: FontWeight.w900)),
          Text(m.effect, style: body(13, color: K.greenD)),
        ])),
        if (s.hasMgr(m.id)) Text('NA EQUIPE', style: body(12, color: K.greenD, w: FontWeight.w900))
        else GBtn(
          color: K.purple, radius: 14, enabled: s.money >= s.mgrCost(m),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          onTap: () { if (s.hire(m)) { Sfx.play('level'); widget.h.refresh(); setState(() {}); } },
          child: Column(mainAxisSize: MainAxisSize.min, children: [Text('CONTRATAR', style: display(12)), Price(fmt(s.mgrCost(m)), size: 13)]),
        ),
      ])),
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
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Sheet(title: 'Missões', icon: 'mission', color: K.orange, onClose: widget.h.closePanel, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Prêmio diário'),
      GCard(child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 7; i++) _day(s, i),
        ]),
        const SizedBox(height: 10),
        GBtn(color: K.gold, enabled: s.dailyReady, pulse: s.dailyReady, onTap: () { widget.h.claimDaily(); setState(() {}); }, child: Text(s.dailyReady ? 'PEGAR PRÊMIO DO DIA' : 'VOLTE AMANHÃ', style: display(17))),
      ])),
      const SectionTitle('Missão atual'),
      if (s.missionsDone)
        GCard(child: Text('Você completou todas as missões desta cidade! Vá em Cidades para abrir um aeroporto novo.', style: body(15)))
      else ...[
        _mission(s, s.curMission, current: true),
        const SectionTitle('Próximas'),
        for (var i = s.mission + 1; i < math.min(missionList.length, s.mission + 4); i++) _mission(s, missionList[i]),
      ],
    ]));
  }
  Widget _day(GameState s, int i) {
    final r = dailyRewards[i];
    final cur = i == s.dailyDay % 7;
    final done = i < s.dailyDay % 7;
    return Container(
      width: 40, padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: cur ? const Color(0xFFFFF0A8) : done ? const Color(0xFFDFF5E3) : const Color(0xFFF3EEDF), borderRadius: BorderRadius.circular(10), border: Border.all(color: cur ? K.goldD : const Color(0xFFE0D3B0), width: 2)),
      child: Column(children: [
        Text('D${i + 1}', style: body(10, color: K.muted)),
        Ico(r.$1 == 'gems' ? 'gem' : r.$1 == 'boost' ? 'bolt' : 'coin', size: 22),
        Text(r.$1 == 'gems' ? '${r.$2.toInt()}' : r.$1 == 'boost' ? '30m' : '\$', style: body(10, w: FontWeight.w900)),
      ]),
    );
  }
  Widget _mission(GameState s, Mission m, {bool current = false}) {
    final p = s.missionProgress(m);
    final ready = current && s.missionReady;
    return GCard(color: current ? null : const Color(0xFFF6F1E4), child: Row(children: [
      Ico(m.type == 'lvl' || m.type == 'unlock' ? stationById(m.target).icon : m.type == 'flights' ? 'plane' : 'cap', size: 38),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.missionText(m), style: body(15, w: FontWeight.w900, color: current ? K.ink : K.muted)),
        if (current) ...[const SizedBox(height: 4), GBar(value: p.$1 / p.$2, height: 14, label: '${fmt(math.min(p.$1, p.$2))}/${fmt(p.$2)}')],
      ])),
      if (current) ...[
        const SizedBox(width: 8),
        ready
            ? GBtn(color: K.green, pulse: true, radius: 14, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), onTap: () { widget.h.claimMission(); setState(() {}); }, child: Row(mainAxisSize: MainAxisSize.min, children: [Text('PEGAR ', style: display(13)), Price('${s.missionGems}', icon: 'gem', size: 13)]))
            : GBtn(color: K.blue, radius: 14, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), onTap: () { if (m.type == 'lvl' || m.type == 'unlock') { widget.h.focusStation(m.target); } else if (m.type == 'manager') { widget.h.openPanel('managers'); } else { widget.h.closePanel(); } }, child: Text('IR', style: display(14))),
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
    final freeIn = (s.freeAt - nowMs()) / 1000;
    Widget item(String ico, String title, String sub, Widget btn) => GCard(child: Row(children: [
          Ico(ico, size: 46), const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: body(16, w: FontWeight.w900)), Text(sub, style: body(12, color: K.muted))])),
          btn,
        ]));
    Widget gemBtn(int cost, VoidCallback onBuy) => GBtn(color: K.purple, radius: 14, enabled: s.gems >= cost, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: onBuy, child: Price('$cost', icon: 'gem', size: 16));
    return Sheet(title: 'Loja', icon: 'bag', color: K.purple, onClose: widget.h.closePanel, child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Você tem ', style: body(15)), Price('${s.gems}', icon: 'gem', size: 18), Text('  · ganhe gemas em missões, prêmios e minijogos', style: body(12, color: K.muted))]),
      const SizedBox(height: 10),
      item('bolt', 'Lucro x2 por 10 min', s.freeReady ? 'Grátis agora!' : 'Grátis de novo em ${fmtTime(freeIn)}', GBtn(color: K.green, radius: 14, enabled: s.freeReady, pulse: s.freeReady, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: () { s.claimFree(); Sfx.play('boost'); widget.h.refresh(); setState(() {}); }, child: Text('GRÁTIS', style: display(15)))),
      item('bolt', 'Lucro x2 por 30 min', s.boostOn ? 'Ativo: soma ao tempo restante' : 'Dobra tudo que o aeroporto fatura', gemBtn(20, () { if (s.buyBoost(20, 30)) { Sfx.play('boost'); widget.h.refresh(); setState(() {}); } })),
      item('cash', 'Maleta de dinheiro', '\$${fmt(s.cashPack(2))} (2 horas de lucro)', gemBtn(30, () { final v = s.cashPack(2); if (s.buyCash(30, 2)) { widget.h.flyCash(v); setState(() {}); } })),
      item('cash', 'Cofre de dinheiro', '\$${fmt(s.cashPack(8))} (8 horas de lucro)', gemBtn(90, () { final v = s.cashPack(8); if (s.buyCash(90, 8)) { widget.h.flyCash(v); setState(() {}); } })),
    ]));
  }
}

class CitiesPanel extends StatelessWidget {
  final GameState s;
  final PanelHost h;
  const CitiesPanel({super.key, required this.s, required this.h});
  @override
  Widget build(BuildContext context) {
    final cur = cityAt(s.city), next = cityAt(s.city + 1);
    return Sheet(title: 'Cidades', icon: 'globe', color: K.teal, onClose: h.closePanel, child: Column(children: [
      GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Você está em ${cur.name}', style: body(17, w: FontWeight.w900)),
        Text(cur.sub, style: body(13, color: K.muted)),
        const SizedBox(height: 10),
        Text('Fature \$${fmt(cityTarget(s.city))} aqui para abrir ${next.name}', style: body(14)),
        const SizedBox(height: 6),
        GBar(value: s.prestigeProgress, height: 18, color: K.green, label: '\$${fmt(s.earnedCity)} / \$${fmt(cityTarget(s.city))}'),
      ])),
      GCard(color: const Color(0xFFEAF6FF), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Ico('plane', size: 34), const SizedBox(width: 8), Expanded(child: Text('Próximo: ${next.name}', style: body(16, w: FontWeight.w900)))]),
        const SizedBox(height: 4),
        Text('Começa do zero, mas tudo rende ${cityMult(s.city + 1) ~/ cityMult(s.city)}x mais. Você ganha ${25 + (s.city + 1) * 10} gemas e mantém as gemas que já tem.', style: body(13)),
        const SizedBox(height: 10),
        Center(child: GBtn(color: K.green, enabled: s.canPrestige, pulse: s.canPrestige, onTap: h.doPrestige, child: Text('VOAR PARA ${next.name.toUpperCase()}', style: display(16)))),
      ])),
      const SectionTitle('Rota'),
      for (var i = 0; i < math.max(cities.length, s.city + 2); i++)
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
          Ico(i < s.city ? 'trophy' : i == s.city ? 'plane' : 'lock', size: 28), const SizedBox(width: 8),
          Expanded(child: Text(cityAt(i).name, style: body(15, color: i <= s.city ? K.ink : K.muted, w: i == s.city ? FontWeight.w900 : FontWeight.w700))),
          Text('x${fmt(cityMult(i))}', style: body(13, color: K.greenD)),
        ])),
    ]));
  }
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
    return Sheet(title: 'Ajustes', icon: 'gear', color: K.grey, onClose: widget.h.closePanel, child: Column(children: [
      GCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [
        sw('Música', s.music, (x) { s.music = Sfx.music = x; x ? Sfx.startMusic() : Sfx.stopMusic(); }),
        sw('Efeitos sonoros', s.sound, (x) => s.sound = Sfx.sound = x),
        sw('Vibração', s.vibration, (x) => s.vibration = Sfx.vibration = x),
      ])),
      GCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Estatísticas', style: body(15, w: FontWeight.w900)),
        InfoRow('Voos realizados', fmt(s.flightsAll)),
        InfoRow('Faturamento total', '\$${fmt(s.earnedAll)}'),
        InfoRow('Cidade', '${s.city + 1}: ${cityAt(s.city).name}'),
      ])),
      if (!confirm) GBtn(color: K.red, onTap: () => setState(() => confirm = true), child: Text('RECOMEÇAR DO ZERO', style: display(15)))
      else GCard(color: const Color(0xFFFFE1E1), child: Column(children: [
        Text('Apagar todo o progresso? Não dá para desfazer.', style: body(15, color: const Color(0xFFB3261E)), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GBtn(color: K.grey, onTap: () => setState(() => confirm = false), child: Text('CANCELAR', style: display(14))),
          const SizedBox(width: 10),
          GBtn(color: K.red, onTap: widget.h.resetGame, child: Text('APAGAR', style: display(14))),
        ]),
      ])),
      const SizedBox(height: 8),
      Text('SkyPort Tycoon v1.0', style: body(12, color: K.muted)),
    ]));
  }
}
