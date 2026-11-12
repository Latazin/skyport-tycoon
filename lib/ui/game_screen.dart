import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/data.dart';
import '../core/format.dart';
import '../core/notify.dart';
import '../core/save.dart';
import '../core/state.dart';
import '../game/art.dart';
import '../game/sky_game.dart';
import '../game/world.dart' show iso, Floater, Puff;
import 'effects.dart';
import 'kit.dart';
import 'minigames.dart';
import 'modals.dart';
import 'panels.dart';

class GameScreen extends StatefulWidget {
  final GameState s;
  final double offlineSecs;
  final String? startPanel;
  const GameScreen({super.key, required this.s, this.offlineSecs = 0, this.startPanel});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver implements Fx, PanelHost {
  GameState get s => widget.s;
  late final SkyGame game;
  final fly = FlyController(), conf = ConfettiController();
  final moneyKey = GlobalKey(), gemKey = GlobalKey();
  String? panel;
  final List<(String, String)> _bq = [];
  (String, String)? _banner;
  final List<(int, String)> _toasts = [];
  int _tid = 0;
  Widget? _modal;
  double _startZoom = 1, pending = 0, shownMoney = 0;
  Offset _lastFocal = Offset.zero;
  int _pausedAt = 0, _lastTapMs = 0, _multiUntil = 0;
  Offset _lastTapPos = Offset.zero;
  Timer? _hud;
  double _tut3 = 0;
  int _comboShow = 0, _holdUntil = 0;

  @override
  void initState() {
    super.initState();
    s.fx = this;
    shownMoney = s.money;
    game = SkyGame(s);
    game.onTap = _onWorldTap;
    game.onAutosave = () => Save.save(s);
    fly.onArrive = (gem, v) { if (!gem) pending = math.max(0, pending - v); _bump = gem ? 'gem' : 'money'; _bumpN++; };
    WidgetsBinding.instance.addObserver(this);
    _hud = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    if (widget.startPanel != null && widget.startPanel != 'none') Future.delayed(const Duration(seconds: 2), () { if (mounted) openPanel(widget.startPanel!); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.startPanel != null) return;
      if (s.tut == 0) { _welcome(); }
      else if (widget.offlineSecs > 60) { _offerOffline(widget.offlineSecs); }
      else if (s.dailyReady && s.tut >= 7) { Future.delayed(const Duration(milliseconds: 900), () { if (mounted && _modal == null) openPanel('missions'); }); }
    });
  }

  @override
  void dispose() { _hud?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  void _tick() {
    if (!mounted) return;
    // dinheiro "rolando"
    final target = math.max(0.0, s.money - pending);
    shownMoney += (target - shownMoney) * 0.35;
    if ((target - shownMoney).abs() < 1) shownMoney = target;
    // tutorial
    if (s.tut == 3) { _tut3 += 0.1; if (_tut3 > 6) { s.tut = 4; toast('Quando um avião decolar, toque no dinheiro!'); } }
    if (s.tut == 4 && s.pile[0] <= 0 && s.pilesTotal <= 0 && s.flightsAll > 2) s.tut = 5;
    game.scene.hint = _hint();
    if (_modal == null && s.chestsQ.isNotEmpty && panel == null && s.tut >= 7 && nowMs() > _holdUntil) showChests();
    s.ensurePeriods();
    setState(() {});
  }
  String? _hint() {
    if (panel != null || _modal != null) return null;
    switch (s.tut) {
      case 1: return 'checkin';
      case 4: return s.pile[0] > 0 ? 'pile' : null;
      case 5: return s.canUnlock(stationById('g1')) ? 'g1' : null;
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused || st == AppLifecycleState.inactive || st == AppLifecycleState.detached) {
      if (_pausedAt == 0) { _pausedAt = nowMs(); Save.save(s); Sfx.pauseMusic(); _scheduleReminders(); }
    } else if (st == AppLifecycleState.resumed) {
      Sfx.resumeMusic(); Notify.cancel();
      if (_pausedAt > 0) { final secs = (nowMs() - _pausedAt) / 1000; if (secs > 60) _offerOffline(secs); }
      _pausedAt = 0;
    }
  }

  void _scheduleReminders() {
    final now = nowMs();
    final items = <(int, String, String, Duration)>[
      (1, 'Cofre cheio no ${cityAt(s.city).name}!', 'Seu aeroporto lotou o cofre. Venha coletar os lucros ✈️', Duration(seconds: s.offlineCapSecs.round())),
      if (s.chestAt > now) (2, 'Baú grátis pronto!', 'Abra o baú e ganhe cartas de avião.', Duration(milliseconds: s.chestAt - now)),
      (3, 'A roleta do dia voltou', 'Gire e ganhe gemas, dinheiro ou um baú de ouro.', const Duration(hours: 22)),
    ];
    Notify.schedule(items);
  }

  // ================= Fx =================
  String _bump = ''; int _bumpN = 0;
  @override
  void banner(String title, String sub) { _bq.add((title, sub)); if (_banner == null) _nextBanner(); }
  void _nextBanner() { if (mounted) setState(() => _banner = _bq.isEmpty ? null : _bq.removeAt(0)); }
  @override
  void toast(String msg) { final id = ++_tid; setState(() { _toasts.add((id, msg)); if (_toasts.length > 3) _toasts.removeAt(0); }); Future.delayed(const Duration(milliseconds: 2600), () { if (mounted) setState(() => _toasts.removeWhere((t) => t.$1 == id)); }); }
  @override
  void sfx(String name, {double pitch = 1}) => Sfx.play(name, rate: pitch);
  @override
  void confetti([int n = 60]) => conf.burst(MediaQuery.of(context).size, n);
  Offset _center(GlobalKey k) { final b = k.currentContext?.findRenderObject() as RenderBox?; if (b == null) return Offset.zero; return b.localToGlobal(Offset(24, b.size.height / 2)); }
  void _flyFrom(Offset from, double amount, int coins) {
    pending += amount;
    final sz = MediaQuery.of(context).size;
    fly.launch(Offset(from.dx.clamp(20, sz.width - 20), from.dy.clamp(90, sz.height - 90)), _center(moneyKey), coins, amount);
  }
  @override
  void flyCash(double amount) { final sz = MediaQuery.of(context).size; _flyFrom(Offset(sz.width / 2, sz.height * 0.5), amount, 16); Sfx.play('cash'); }
  @override
  void flyGemsCenter(int n) { final sz = MediaQuery.of(context).size; _flyGems(n, Offset(sz.width / 2, sz.height * 0.55)); }
  void _flyGems(int n, Offset from) => fly.launch(from, _center(gemKey), math.min(10, 2 + n), n.toDouble(), gem: true);

  @override
  void flightPaid(int g, double amount, int pax, bool vip) {
    game.w.flightFx(g, vip ? 'VIP! +\$${fmt(amount)}' : '+\$${fmt(amount)}', vip);
    Sfx.play('jet', volume: 0.22);
    if (vip) { banner('VOO VIP!', 'Passagens x10: \$${fmt(amount)}'); Sfx.play('level'); confetti(50); }
    if (s.flightsAll == 1) banner('Primeiro voo!', 'Toque no dinheiro no portão para coletar');
  }

  @override
  void stationUp(String id, int from, int to, String gain) {
    final st = stationById(id);
    game.w.levelFx(id, gain);
    Sfx.haptic();
    if (from == 0) {
      Sfx.play('build'); confetti(70);
      banner('NOVO!', st.name);
      game.focusStation(id);
      return;
    }
    Sfx.play('up', rate: 1 + math.min(to, 60) * 0.008);
    final crossed = milestones.where((m) => from < m && to >= m).toList();
    if (crossed.isNotEmpty) { banner('x2 PRODUÇÃO!', '${st.name} chegou ao nível ${crossed.last}'); Sfx.play('level'); confetti(40); }
    if (id == 'checkin' && desksFor(to) > desksFor(from)) banner('NOVO BALCÃO!', '${desksFor(to)} balcões de check-in');
    if (id == 'seguranca' && lanesFor(to) > lanesFor(from)) banner('NOVA FAIXA!', '${lanesFor(to)} faixas de raio-X');
    if (id == 'seguranca' && from < 20 && to >= 20) toast('Scanners corporais instalados!');
    if (id == 'lojas' && shopsFor(to) > shopsFor(from)) banner('NOVO QUIOSQUE!', '${shopsFor(to)} lojas na praça');
    if (id == 'pista' && runwayTier(to) > runwayTier(from)) banner('PISTA MAIOR!', 'Agora a pista recebe ${planeTypes[runwayTier(to)].name}');
    if (id == 'torre' && towerTier(to) > towerTier(from)) banner('TORRE NOVA!', 'Controle de tráfego ampliado');
    if (id == 'entrada' && parkTier(to) > parkTier(from)) toast('Estacionamento ampliado!');
    if (st.kind == Kind.gate && gateTier(to) > gateTier(from)) {
      final ok = runwayTier(s.lvl('pista')) >= gateTier(to);
      banner('AVIÃO MAIOR!', ok ? '${st.name} agora recebe ${planeTypes[gateTier(to)].name}' : 'Melhore a Pista para receber ${planeTypes[gateTier(to)].name}');
    }
    if (props.any((p) => p.st == id && from < p.lvl && to >= p.lvl)) toast('Decoração nova em ${st.name}!');
  }
  @override
  void levelUp(int lvl) { banner('NÍVEL $lvl!', 'Aeroporto subiu de nível · ganhou um baú'); Sfx.play('level'); confetti(80); }
  @override
  void eventStarted(String type) {
    Sfx.play('ding');
    final t = GameState.evNames[type] ?? '';
    if (type == 'vip') { banner('AVIÃO VIP!', 'O próximo voo de um portão paga x10'); return; }
    toast('$t Toque no balão!');
    final e = s.ev; if (e != null) game.focusWorld(e.x, e.z);
  }
  @override
  void bottleneckFreed(String old) {
    if (old == 'none') return;
    final name = bottleneckName(old);
    final c = old == 'gates' ? game.w.stationCenter('g0') : game.w.stationCenter(old);
    game.w.floaters.add(Floater(c.$1, c.$2, c.$3 + 2.5, 'LIBEROU! $name', const Color(0xFF3FD46B), 1.2));
  }

  @override
  void phaseUp(int ph) {
    final P = phases[ph];
    _holdUntil = nowMs() + 2200;
    Art.loadBg(Art.bgKey(cityAt(s.city).bg, ph));
    if (ph < 3) Art.loadBg(Art.bgKey(cityAt(s.city).bg, ph + 1));
    // a obra: poeira por todo o terminal novo e câmera mostrando o crescimento
    for (var i = 0; i < 40; i++) {
      final x = -46 + game.w.r.nextDouble() * (P.termX1 + 46), z = -4 + game.w.r.nextDouble() * 20;
      Future.delayed(Duration(milliseconds: 60 * i), () { game.w.puffs.add(Puff(x, z, 1.2 + game.w.r.nextDouble())); });
    }
    game.focusWorld((P.camX0 + P.camX1) / 2, -4, zoomTo: 0.32);
    Sfx.play('build');
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      _showModal(GameModal(title: P.name, icon: 'hangar', color: K.blue, actions: [GBtn(color: K.green, pulse: true, onTap: () { _closeModal(); showChests(); }, child: Text('Ver o aeroporto', style: display(18)))],
          child: Text('O aeroporto cresceu! ${P.desc}.\n\nA pista e o terminal ficaram maiores e novas áreas apareceram no mapa.', textAlign: TextAlign.center, style: body(15, w: FontWeight.w700))));
      confetti(120);
    });
  }
  @override
  void arrivals(int gate, int pax) => game.w.arrivals(gate, pax);
  @override
  void decorBought(Decor d) {
    game.w.bump[d.id] = game.w.t;
    game.w.burst(d.x, d.z, 1.5, 24, const [Color(0xFFFFE27A), Color(0xFF3FD46B), Color(0xFFFFFFFF)]);
    game.focusWorld(d.x, d.z, zoomTo: 0.6);
    closePanel();
    banner('Decoração nova!', '${d.name} · +3% de receita');
    confetti(40);
  }

  // ================= PanelHost =================
  @override
  void refresh() { if (mounted) setState(() {}); }
  @override
  void openPanel(String p) {
    Sfx.click();
    setState(() => panel = panel == p ? null : p);
    game.scene.selected = panel != null && panel!.startsWith('st:') ? panel!.substring(3) : null;
    if (panel != null && panel!.startsWith('st:')) {
      game.focusStation(panel!.substring(3), sheet: true);
      if (s.tut == 1 && panel == 'st:checkin') s.tut = 2;
    }
  }
  @override
  void closePanel() { setState(() => panel = null); game.scene.selected = null; }
  @override
  void focusStation(String id) => openPanel('st:$id');
  @override
  void claimDaily() {
    if (!s.dailyReady) return;
    final r = s.claimDaily();
    if (r.$1 == 'gems') { flyGemsCenter(r.$2.toInt()); toast('+${r.$2.toInt()} gemas!'); }
    else if (r.$1 == 'coins') { flyCash(r.$2); }
    else if (r.$1 == 'boost') { toast('Lucro x2 por 30 minutos!'); Sfx.play('boost'); }
    Sfx.play('gift'); confetti(50); setState(() {});
  }
  @override
  void claimMission() {
    if (!s.missionReady) return;
    final g = s.missionGems, c = s.missionCoins;
    s.claimMission();
    final sz = MediaQuery.of(context).size;
    _flyGems(g, Offset(sz.width / 2, sz.height * 0.75));
    _flyFrom(Offset(sz.width / 2, sz.height * 0.75), c, 10);
    Sfx.play('gift'); confetti(35);
    setState(() {});
  }
  @override
  void claimStar() {
    if (!s.starReady) return;
    s.claimStar();
    closePanel();
    final n = s.star;
    if (phaseFor(s.city, n) != phaseFor(s.city, n - 1)) { Sfx.play('level'); confetti(80); return; }
    _showModal(GameModal(title: '$n estrela${n > 1 ? 's' : ''}!', color: K.purple, actions: [GBtn(color: K.green, pulse: true, onTap: () { _closeModal(); showChests(); }, child: Text('Incrível!', style: display(20)))],
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < 5; i++) TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 500 + i * 180), curve: Curves.elasticOut, builder: (_, v, c) => Transform.scale(scale: i < n ? v : 1, child: c), child: Opacity(opacity: i < n ? 1 : 0.2, child: const Ico('star', size: 52)))]),
          const SizedBox(height: 8),
          Text(starNames[math.min(n, 5)], style: body(22, color: K.purple, w: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Toda a receita agora rende x${fmt(s.starMult)}!${n < 5 ? '\nNovas áreas liberadas: ${stations.where((st) => st.star == n).map((st) => st.name).join(', ')}.' : '\nPróxima cidade liberada!'}', textAlign: TextAlign.center, style: body(15)),
        ])));
    Sfx.play('level'); confetti(140); Sfx.haptic(60);
  }
  @override
  void showChests() {
    if (s.chestsQ.isEmpty || _modal != null) return;
    final type = s.chestsQ.removeAt(0);
    _showModal(ChestModal(key: ValueKey('chest${s.chestsQ.length}$type${nowMs()}'), type: type, left: s.chestsQ.length, open: () { final l = s.openChest(type); confetti(60); return l; }, onDone: () { _closeModal(); Save.save(s); if (s.chestsQ.isNotEmpty) Future.delayed(const Duration(milliseconds: 250), showChests); }));
  }
  @override
  void openWheel() {
    if (!s.spinReady) return;
    closePanel();
    _showModal(WheelModal(spin: s.spin, apply: (i) {
      final r = s.applyWheel(i);
      switch (r.$1) {
        case 'coins': flyCash(r.$2); return '\$${fmt(r.$2)}!';
        case 'gems': flyGemsCenter(r.$2.toInt()); return '${r.$2.toInt()} gemas!';
        case 'miles': return '${r.$2.toInt()} milhas!';
        case 'boost': return 'Lucro x2 por 15 min!';
        case 'chest_gold': return 'Baú de ouro!';
      }
      return 'Baú de cartas!';
    }, onClose: () { _closeModal(); Save.save(s); showChests(); }));
  }
  @override
  void doPrestige() {
    if (!s.canPrestige) return;
    final next = cityAt(s.city + 1);
    _showModal(GameModal(title: 'Voar para ${next.name}?', icon: 'globe', color: K.teal, actions: [
      GBtn(color: K.grey, onTap: _closeModal, child: Text('AINDA NÃO', style: display(16))),
      GBtn(color: K.green, pulse: true, onTap: () async {
        _closeModal(); closePanel();
        s.prestige();
        await Art.loadBg(Art.bgKey(cityAt(s.city).bg, s.phase));
        game.w.agents.clear(); for (final q in game.w.deskQ) { q.clear(); } for (final q in game.w.laneQ) { q.clear(); }
        game.focusWorld(-20, 6, zoomTo: 0.6);
        Save.save(s);
        banner(next.name.toUpperCase(), 'Novo aeroporto! Tudo rende ${fmt(cityMult(s.city))}x');
        Sfx.play('level'); confetti(120);
        setState(() {});
      }, child: Text('VOAR!', style: display(18))),
    ], child: Text('Você começa um aeroporto novo em ${next.name}, mas tudo rende ${fmt(cityMult(s.city + 1))}x. Pesquisa, rotas, frota, gemas e milhas vão com você. Melhorias, gerentes e estrelas ficam aqui.', textAlign: TextAlign.center, style: body(15))));
  }
  @override
  void resetGame() async {
    await Save.wipe();
    if (!mounted) return;
    _showModal(GameModal(title: 'Progresso apagado', color: K.red, child: Text('Feche e abra o jogo de novo para recomeçar.', textAlign: TextAlign.center, style: body(15))));
  }

  // ================= mundo =================
  void _onWorldTap(String id) {
    if (id == 'none') { if (panel != null) closePanel(); return; }
    if (id == 'ev') { _tapEvent(); return; }
    if (id.startsWith('pile:')) { _collect(id == 'pile:shop' ? -1 : int.parse(id.substring(5))); return; }
    if (id.startsWith('vip:')) { final g = int.parse(id.substring(4)); final n = s.tapVip(g); if (n > 0) { _flyGems(n, game.worldToScreen(iso(Lay.gates[g], -10, 5))); Sfx.play('gift'); toast('Passageiro VIP deixou $n gemas!'); } return; }
    if (id.startsWith('plane:')) { final g = int.parse(id.substring(6)); s.hurry(g, 1.2); Sfx.play('tick', rate: 1.3); Sfx.haptic(); return; }
    if (panel == 'st:$id') return;
    focusStation(id);
  }
  void _collect(int g) {
    final pos = g < 0 ? iso(7.5, 11.6, 1) : iso(game.w.pilePos(g).$1, game.w.pilePos(g).$2, 1);
    final v = s.collect(g); if (v <= 0) return;
    pending += 0;
    final o = game.worldToScreen(pos);
    _flyFrom(o, v, math.min(14, 5 + s.combo));
    Sfx.play('cash', rate: 1 + s.combo * 0.06); Sfx.haptic(s.combo >= 5 ? 30 : 10);
    if (s.combo >= 2) { _comboShow = nowMs(); }
    game.w.floaters.add(Floater(g < 0 ? 7.5 : game.w.pilePos(g).$1, g < 0 ? 11.6 : game.w.pilePos(g).$2, 2.5, s.combo >= 2 ? 'COMBO x${s.combo}! +\$${fmt(v)}' : '+\$${fmt(v)}', const Color(0xFFFFE27A), s.combo >= 2 ? 1.3 : 1.0));
  }
  void _tapEvent() {
    final e = s.ev; if (e == null) return;
    final type = e.type;
    final r = s.tapEvent();
    final o = game.worldToScreen(iso(e.x, e.z, 4));
    if (r.$1 > 0) _flyFrom(o, r.$1, 12);
    if (r.$2 > 0) { _flyGems(r.$2, o); toast('Achou ${r.$2} gemas!'); }
    if (type == 'fog') { Sfx.play(r.$3 ? 'level' : 'pop'); if (r.$3) toast('Pista liberada!'); return; }
    if (type == 'tourists') { game.w.spawnGroup(12); banner('HORA DO RUSH!', '3x passageiros por 1 minuto'); }
    if (type == 'celeb') toast('Fãs lotaram o terminal!');
    Sfx.play('gift'); confetti(30);
  }
  void _doubleTapCheck(Offset p) {
    final now = nowMs();
    if (now - _lastTapMs < 320 && (p - _lastTapPos).distance < 40) { game.overview(); _lastTapMs = 0; return; }
    _lastTapMs = now; _lastTapPos = p;
  }

  void _showModal(Widget m) => setState(() => _modal = m);
  void _closeModal() => setState(() => _modal = null);

  void _welcome() {
    _showModal(GameModal(title: 'Bem-vindo ao SkyPort!', icon: 'plane', color: K.blue, actions: [
      GBtn(color: K.green, pulse: true, onTap: () { s.tut = 1; _closeModal(); Sfx.startMusic(); }, padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12), child: Text('Vamos lá!', style: display(20))),
    ], child: Text('Você herdou o Aeroclube de Vale Verde: uma pista de terra e um barracão de madeira.\n\nPassageiros fazem check-in, passam na revista e embarcam. Cada voo deixa dinheiro no portão.\n\nConquiste estrelas para transformar o barracão em terminal, depois em aeroporto e, um dia, num hub internacional!', textAlign: TextAlign.center, style: body(15, w: FontWeight.w700))));
  }
  void _offerOffline(double secs) {
    final v = s.offlineFor(secs); if (v < 1) return;
    _showModal(OfflineModal(secs: secs, amount: v, gems: s.gems, onClaim: (x3) {
      if (x3) { if (s.gems < 15) return; s.gems -= 15; }
      final a = x3 ? v * 3 : v;
      s.earn(a); _closeModal();
      final sz = MediaQuery.of(context).size;
      _flyFrom(Offset(sz.width / 2, sz.height * 0.5), a, 18); Sfx.play('cash'); confetti(40);
    }));
  }

  Future<void> _playGame(String which) async {
    final at0 = {'land': s.landAt, 'xray': s.xrayAt, 'bag': s.bagAt, 'atc': s.atcAt, 'yard': s.yardAt}[which]!;
    if (nowMs() < at0) { toast('Disponível em ${fmtTime(math.max(0, (at0 - nowMs()) / 1000))}'); return; }
    Sfx.click();
    final page = switch (which) {
      'land' => LandingGame(rewardText: _rewardText, level: s.landingLevel) as Widget,
      'xray' => XrayGame(rewardText: _rewardText),
      'atc' => AtcGame(rewardText: _rewardText),
      'yard' => YardGame(rewardText: _rewardText),
      _ => BagGame(rewardText: _rewardText),
    };
    final res = await Navigator.of(context).push<GameResult>(MaterialPageRoute(builder: (_) => page));
    if (res == null || !mounted) return;
    final at = nowMs() + GameState.gameCd;
    switch (which) {
      case 'land': s.landAt = at; if (res.stars > 0) s.inc('landings'); break;
      case 'xray': s.xrayAt = at; break;
      case 'atc': s.atcAt = at; break;
      case 'yard': s.yardAt = at; break;
      default: s.bagAt = at;
    }
    s.inc('minigames'); s.sPts += 5;
    if (res.stars > 0) {
      final v = s.gameReward(const [0.0, 60.0, 150.0, 300.0][res.stars]);
      s.earn(v); flyCash(v);
      if (res.stars == 3) { s.gems += 3; flyGemsCenter(3); s.chestsQ.add('chest'); }
      s.addXp(res.stars * 3.0);
      confetti(40);
    }
    Save.save(s);
    setState(() {});
  }
  String _rewardText(int stars) => stars == 0 ? 'Tente de novo daqui a pouco.' : 'Prêmio: \$${fmt(s.gameReward(const [0.0, 60.0, 150.0, 300.0][stars]))}${stars == 3 ? ' + 3 gemas + baú' : ''}';

  // ================= construção =================
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: const Color(0xFF86C963),
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) { _startZoom = game.zoom; _lastFocal = d.localFocalPoint; game.dragging = true; game.vel.setZero(); if (d.pointerCount > 1) _multiUntil = nowMs() + 350; },
            onScaleUpdate: (d) {
              if (d.pointerCount > 1) { _multiUntil = nowMs() + 350; game.zoomAt(d.localFocalPoint, _startZoom * d.scale / game.zoom); }
              final delta = d.localFocalPoint - _lastFocal; _lastFocal = d.localFocalPoint;
              // ao tirar um dedo o ponto focal pula: ignora esse salto
              if (delta.distance < 120) game.panBy(delta);
            },
            onScaleEnd: (d) {
              game.dragging = false;
              final v = d.velocity.pixelsPerSecond;
              if (nowMs() < _multiUntil || d.pointerCount > 0 || v.distance < 150) { game.vel.setZero(); return; }
              game.vel.setValues(v.dx.clamp(-2200.0, 2200.0), v.dy.clamp(-2200.0, 2200.0));
            },
            onTapUp: (d) { final id = game.tapAt(d.localPosition); if (id == 'none') { _doubleTapCheck(d.localPosition); } else { _lastTapMs = 0; } },
            child: RepaintBoundary(child: GameWidget(game: game)),
          ),
        ),
        if (s.boostOn) const IgnorePointer(child: _Vignette(color: Color(0xFFFFC531))),
        if (s.rushOn) const IgnorePointer(child: _Vignette(color: Color(0xFFFF5A5F))),
        if (s.turboOn) const IgnorePointer(child: _Vignette(color: Color(0xFF3E8BFF))),
        if (s.tut == 3 && panel == null && _modal == null) Positioned(top: pad.top + 160, left: 30, right: 30, child: IgnorePointer(child: _TipCard(text: 'Veja: mais balcões, fila andando mais rápido!'))),
        if (s.tut == 6 && panel == null && _modal == null) Positioned(bottom: pad.bottom + 150, left: 30, right: 30, child: IgnorePointer(child: _TipCard(text: 'Contrate a Lia na Equipe: ela coleta o dinheiro sozinha!'))),
        Positioned.fill(child: RepaintBoundary(child: Stack(children: [
          _topBar(pad),
          _sideButtons(pad),
          if (panel == null) _abilities(pad),
          if (panel == null) _goal(pad),
          if (panel == null) _bestButton(pad),
          _bottomNav(pad),
        ]))),
        if (nowMs() - _comboShow < 1200 && s.combo >= 2) Positioned(top: MediaQuery.of(context).size.height * 0.3, left: 0, right: 0, child: IgnorePointer(child: Center(child: TweenAnimationBuilder<double>(key: ValueKey(s.combo), tween: Tween(begin: 1.6, end: 1), duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, builder: (_, v, c) => Transform.scale(scale: v, child: c), child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), decoration: BoxDecoration(color: K.gold, borderRadius: BorderRadius.circular(18), boxShadow: K.shadow), child: Text('Combo x${s.combo}', style: display(30))))))),
        Positioned(left: 0, right: 0, bottom: 0, child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: c),
          child: panel == null ? const SizedBox.shrink(key: ValueKey('none')) : SafeArea(key: ValueKey(panel), top: false, child: buildPanel(panel!, s, this)),
        )),
        Positioned(top: pad.top + 118, left: 0, right: 0, child: IgnorePointer(child: Column(children: [for (final t in _toasts) _Toast(key: ValueKey(t.$1), text: t.$2)]))),
        Positioned.fill(child: RepaintBoundary(child: FlyLayer(c: fly))),
        Positioned.fill(child: RepaintBoundary(child: ConfettiLayer(c: conf))),
        if (_banner != null) Positioned.fill(child: BannerView(key: ValueKey(_banner), title: _banner!.$1, sub: _banner!.$2, onDone: _nextBanner)),
        if (_modal != null) Positioned.fill(child: Container(color: const Color(0x8C1F2A44), alignment: Alignment.center, padding: const EdgeInsets.all(18), child: _modal)),
      ]),
    );
  }

  Widget _topBar(EdgeInsets pad) {
    final city = cityAt(s.city);
    return Positioned(
      top: pad.top + 8, left: 10, right: 10,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(flex: 6, child: _Res(key: moneyKey, icon: 'coin', value: '\$${fmt(shownMoney)}', sub: '+\$${fmt(s.rate)}/s', bump: _bump == 'money' ? _bumpN : 0, onTap: () => openPanel('upgrades'))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: _Res(key: gemKey, icon: 'gem', value: '${s.gems}', bump: _bump == 'gem' ? _bumpN : 0, onTap: () => openPanel('shop'))),
          const SizedBox(width: 8),
          _Circle(onTap: () => openPanel('settings'), child: const Icon(Icons.settings_rounded, color: K.navy2, size: 24)),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => openPanel('stars'),
            child: Container(
              width: 186, padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: K.shadow, border: s.starReady ? Border.all(color: K.purple, width: 2) : null),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  for (var i = 0; i < 5; i++) Opacity(opacity: i < s.star ? 1 : 0.2, child: const Ico('star', size: 16)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(city.name, style: body(12.5, w: FontWeight.w900), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: K.purple, borderRadius: BorderRadius.circular(7)), child: Text('Nv ${s.alv}', style: body(11, color: Colors.white, w: FontWeight.w900))),
                  const SizedBox(width: 6),
                  Expanded(child: GBar(value: s.xp / s.needXp(), height: 7, color: K.purple)),
                ]),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Wrap(spacing: 4, runSpacing: 4, children: [
            if (s.boostOn) _chip('bolt', 'x2 ${fmtTime((s.boostUntil - nowMs()) / 1000)}', K.gold),
            if (s.rushOn) _chip('rush', 'Rush ${fmtTime((s.rushUntil - nowMs()) / 1000)}', K.red),
            if (s.turboOn) _chip('turbo', 'Turbo ${fmtTime((s.turboUntil - nowMs()) / 1000)}', K.blue),
            for (final a in abilities) if (s.abilOn(a.mgr)) _chip(a.icon, '${a.name} ${fmtTime(((s.abilUntil[a.mgr] ?? 0) - nowMs()) / 1000)}', K.purple),
            if (s.weekend) _chip('gift', 'Fim de semana +25%', K.orange),
            if (s.ctAir >= 0) GestureDetector(onTap: () => openPanel('fleet'), child: _chip('contract', '${airlines[s.ctAir].$1} ${math.min(s.ctDone, s.ctNeed)}/${s.ctNeed}', s.ctReady ? K.green : K.teal)),
          ])),
        ]),
      ]),
    );
  }
  Widget _chip(String ic, String t, Color c) => Container(
        padding: const EdgeInsets.fromLTRB(3, 2, 9, 2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: K.shadowS),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Ico(ic, size: 20), const SizedBox(width: 2), Text(t, style: body(11.5, color: c, w: FontWeight.w900))]),
      );

  Widget _sideButtons(EdgeInsets pad) {
    final now = nowMs();
    String cd(int at) => fmtTime(math.max(0, (at - now) / 1000));
    return Positioned(
      right: 10, top: pad.top + 74,
      child: Column(children: [
        _RoundBtn(icon: 'bolt', label: s.freeReady ? 'x2 grátis' : 'Turbinas', ready: s.freeReady, onTap: () { if (s.freeReady) { s.claimFree(); Sfx.play('boost'); banner('Lucro x2!', 'Por 10 minutos'); setState(() {}); } else { openPanel('shop'); } }),
        if (s.spinReady) _RoundBtn(icon: 'wheel', label: 'Roleta', ready: true, onTap: openWheel),
        _RoundBtn(icon: 'chest', label: s.chestReady ? 'Baú' : cd(s.chestAt), ready: s.chestReady, dim: !s.chestReady, onTap: () { if (s.chestReady) { s.takeFreeChest(); showChests(); } else { toast('Baú grátis em ${cd(s.chestAt)}'); } }),
        _RoundBtn(icon: 'landing', label: s.landReady ? 'Pouso' : cd(s.landAt), ready: s.landReady, dim: !s.landReady, onTap: () => _playGame('land')),
        _RoundBtn(icon: 'xray', label: s.xrayReady ? 'Raio-X' : cd(s.xrayAt), ready: s.xrayReady, dim: !s.xrayReady, onTap: () => _playGame('xray')),
        _RoundBtn(icon: 'bags', label: s.bagReady ? 'Malas' : cd(s.bagAt), ready: s.bagReady, dim: !s.bagReady, onTap: () => _playGame('bag')),
        if (s.phase >= 1) _RoundBtn(icon: 'tower', label: s.atcReady ? 'Torre' : cd(s.atcAt), ready: s.atcReady, dim: !s.atcReady, onTap: () => _playGame('atc')),
        if (s.phase >= 2) _RoundBtn(icon: 'route', label: s.yardReady ? 'Pátio' : cd(s.yardAt), ready: s.yardReady, dim: !s.yardReady, onTap: () => _playGame('yard')),
      ]),
    );
  }

  /// Habilidades dos gerentes contratados (lado esquerdo).
  Widget _abilities(EdgeInsets pad) {
    final list = s.myAbilities;
    if (list.isEmpty || s.tut < 7) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    return Positioned(
      left: 10, top: pad.top + 132,
      child: Column(children: [
        for (final a in list) _AbilityBtn(a: a, s: s, onTap: () {
          if (!s.abilReady(a)) { toast('${a.name} recarrega em ${fmtTime(s.abilLeft(a) / 1000)}'); return; }
          final t = s.useAbility(a);
          Sfx.play('boost'); Sfx.haptic(20);
          if (a.mgr == 'carla') game.w.spawnGroup(14);
          if (a.mgr == 'lia') { final sz = MediaQuery.of(context).size; _flyFrom(Offset(sz.width / 2, sz.height * 0.45), 0, 10); }
          banner(a.name, t);
          setState(() {});
        }),
      ]),
    );
  }

  Widget _bestButton(EdgeInsets pad) {
    final b = s.bestBuy();
    if (b == null || s.tut < 3) return const Positioned(right: 0, bottom: 0, child: SizedBox.shrink());
    final can = s.money >= b.$2;
    final st = stationById(b.$1);
    return Positioned(
      right: 12, bottom: pad.bottom + 158,
      child: GBtn(
        color: can ? K.green : const Color(0xFF9AA4B8), enabled: true, pulse: can, radius: 18,
        padding: const EdgeInsets.fromLTRB(6, 5, 12, 6),
        onTap: () { if (!can) { toast('Falta \$${fmt(b.$2 - s.money)} para ${st.name}'); return; } s.buyBest(); setState(() {}); },
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.all(3), child: Ico(st.icon, size: 32)),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(b.$3 ? 'Construir' : 'Melhor compra', style: display(10.5).copyWith(color: Colors.white.withValues(alpha: 0.85))),
            Text(st.name, style: display(14)),
            Price(fmt(b.$2), size: 12),
          ]),
        ]),
      ),
    );
  }

  Widget _goal(EdgeInsets pad) {
    final done = s.missionsDone;
    final p = s.missionProgress();
    final ready = s.missionReady || (done && s.canPrestige) || s.starReady;
    final m = s.curMission;
    final starTxt = s.starReady ? 'Estrela ${s.star + 1} pronta!' : null;
    void go() {
      if (s.starReady) { claimStar(); return; }
      if (done) { openPanel(s.canPrestige ? 'cities' : 'stars'); return; }
      if (s.missionReady) { claimMission(); return; }
      if (m.type == 'lvl' || m.type == 'unlock') { focusStation(m.target); } else if (m.type == 'manager') { openPanel('team'); } else if (m.type == 'star') { openPanel('stars'); } else { openPanel('missions'); }
    }
    return Positioned(
      left: 12, right: 12, bottom: pad.bottom + 92,
      child: Center(child: GestureDetector(
        onTap: go,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: K.shadow),
          child: Row(children: [
            IcoBox(s.starReady ? 'star' : done ? 'globe' : ready ? 'gift' : 'mission', color: s.starReady ? K.purple : ready ? K.green : K.orange, size: 42),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(starTxt ?? (done ? 'Complete as estrelas do aeroporto' : s.missionText()), style: body(14, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              done || starTxt != null ? GBar(value: s.star / 5, height: 7, color: K.purple, label: '${s.star}/5') : GBar(value: p.$1 / p.$2, height: 7, color: K.green, label: '${fmt(math.min(p.$1, p.$2))}/${fmt(p.$2)}'),
            ])),
            const SizedBox(width: 8),
            if (ready) GBtn(color: s.starReady ? K.purple : K.green, pulse: true, radius: 12, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), onTap: go, child: Text(s.starReady ? 'Ganhar' : done ? 'Ver' : 'Pegar', style: display(14)))
            else if (!done) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: K.purpleL, borderRadius: BorderRadius.circular(10)), child: Price('${s.missionGems}', icon: 'gem', size: 13, color: K.purple)),
          ]),
        ),
      )),
    );
  }

  Widget _bottomNav(EdgeInsets pad) {
    final anyUp = stations.any((st) => (s.built(st.id) && !st.oneTime && s.canUp(st)) || s.canUnlock(st));
    final team = managers.any((m) => !s.hasMgr(m.id) && s.money >= s.mgrCost(m)) || researchList.any(s.canResearch);
    final fleet = planeModels.any((m) => s.canLevelModel(m.id)) || routes.any((r) => !s.routesOwned.contains(r.id) && s.routeReqOk(r) && s.money >= s.routeCost(r)) || s.ctReady || s.ctOfferReady;
    final cl = s.claimables + (s.dailyReady ? 1 : 0) + (s.wkReady ? 1 : 0);
    return Positioned(
      left: 10, right: 10, bottom: pad.bottom + 10,
      child: Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x261F2A44), blurRadius: 20, offset: Offset(0, 6))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _NavBtn(icon: 'up', label: 'Melhorar', dot: anyUp, active: panel == 'upgrades', onTap: () => openPanel('upgrades')),
          _NavBtn(icon: 'star', label: 'Estrelas', dot: s.starReady, active: panel == 'stars', onTap: () => openPanel('stars')),
          _NavBtn(icon: 'mission', label: 'Missões', badge: cl > 0 ? '$cl' : null, active: panel == 'missions', onTap: () => openPanel('missions')),
          _NavBtn(icon: 'plane', label: 'Frota', dot: fleet, active: panel == 'fleet', onTap: () => openPanel('fleet')),
          _NavBtn(icon: 'pax', label: 'Equipe', dot: team, active: panel == 'team', onTap: () => openPanel('team')),
          _NavBtn(icon: 'bag', label: 'Loja', dot: s.freeReady || s.chestReady || s.spinReady, active: panel == 'shop', onTap: () => openPanel('shop')),
        ]),
      )),
    );
  }
}

// ================= widgets do HUD =================
class _TipCard extends StatelessWidget {
  final String text;
  const _TipCard({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: K.shadow),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 30, height: 30, decoration: const BoxDecoration(color: K.orange, shape: BoxShape.circle), child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: body(15, w: FontWeight.w900))),
        ]),
      );
}

class _Circle extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Circle({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: () { Sfx.click(); onTap(); }, child: Container(width: 46, height: 46, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: K.shadow), child: Center(child: child)));
}

class _Res extends StatefulWidget {
  final String icon, value;
  final String? sub;
  final int bump;
  final VoidCallback? onTap;
  const _Res({super.key, required this.icon, required this.value, this.sub, this.bump = 0, this.onTap});
  @override
  State<_Res> createState() => _ResState();
}

class _ResState extends State<_Res> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  int _last = 0;
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (widget.bump != _last) { _last = widget.bump; a.forward(from: 0); }
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 46, padding: const EdgeInsets.only(left: 4, right: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23), boxShadow: K.shadow),
        child: Row(children: [
          AnimatedBuilder(animation: a, builder: (_, c) => Transform.scale(scale: 1 + math.sin(a.value * math.pi) * 0.18, child: c), child: Ico(widget.icon, size: 38)),
          const SizedBox(width: 4),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(widget.value, style: body(19, w: FontWeight.w900))),
            if (widget.sub != null) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(widget.sub!, style: body(11, color: K.green, w: FontWeight.w900))),
          ])),
        ]),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final String icon, label;
  final bool ready, dim;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.label, required this.onTap, this.ready = false, this.dim = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(width: 56, child: Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: K.shadow, border: ready ? Border.all(color: K.green, width: 2.2) : null),
              padding: const EdgeInsets.all(6),
              child: Opacity(opacity: dim ? 0.45 : 1, child: Ico(icon, size: 34)),
            ),
            if (ready) Positioned(right: -1, top: -1, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: K.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
          ]),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(8)),
            child: FittedBox(child: Text(label, style: body(10.5, color: ready ? K.greenD : K.navy2, w: FontWeight.w900))),
          ),
        ]))),
      );
}

class _AbilityBtn extends StatelessWidget {
  final Ability a;
  final GameState s;
  final VoidCallback onTap;
  const _AbilityBtn({required this.a, required this.s, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final ready = s.abilReady(a);
    final k = ready ? 1.0 : 1 - s.abilLeft(a) / (abilityCooldown * 1000);
    return GestureDetector(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(width: 50, height: 50, child: Stack(alignment: Alignment.center, children: [
        Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: K.shadow)),
        SizedBox(width: 46, height: 46, child: CircularProgressIndicator(value: k, strokeWidth: 3.5, color: ready ? K.purple : K.grey, backgroundColor: K.track)),
        Opacity(opacity: ready ? 1 : 0.45, child: Ico(a.icon, size: 30)),
        if (ready) Positioned(right: 0, top: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: K.purple, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
      ]))),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String icon, label;
  final String? badge;
  final bool active, dot;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.label, required this.onTap, this.badge, this.active = false, this.dot = false});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: active ? K.blueL : Colors.transparent, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedScale(scale: active ? 1.08 : 1, duration: const Duration(milliseconds: 180), child: Ico(icon, size: 32)),
              const SizedBox(height: 1),
              FittedBox(child: Text(label, style: body(11, color: active ? K.blue : K.muted, w: FontWeight.w900))),
            ]),
          ),
          if (badge != null) Positioned(top: -3, right: 6, child: Container(
            constraints: const BoxConstraints(minWidth: 19), height: 19, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: K.red, border: Border.all(color: Colors.white, width: 2)),
            child: Text(badge!, style: body(10, color: Colors.white, w: FontWeight.w900)),
          ))
          else if (dot) Positioned(top: 0, right: 12, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: K.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
        ]),
      ));
}

class _Toast extends StatelessWidget {
  final String text;
  const _Toast({super.key, required this.text});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * -8), child: c)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xF21F2A44), borderRadius: BorderRadius.circular(14)),
          child: Text(text, style: body(14, color: Colors.white, w: FontWeight.w900)),
        ),
      );
}

class _Vignette extends StatelessWidget {
  final Color color;
  const _Vignette({required this.color});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: RadialGradient(radius: 1.15, colors: [Colors.transparent, Colors.transparent, color.withValues(alpha: 0.18)], stops: const [0, 0.78, 1])));
}
