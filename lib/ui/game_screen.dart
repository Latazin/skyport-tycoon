import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/data.dart';
import '../core/format.dart';
import '../core/save.dart';
import '../core/state.dart';
import '../game/art.dart';
import '../game/sky_game.dart';
import '../game/world.dart' show iso;
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
  double _startZoom = 1, pending = 0;
  Offset _lastFocal = Offset.zero;
  int _pausedAt = 0;
  Timer? _hud;

  @override
  void initState() {
    super.initState();
    s.fx = this;
    game = SkyGame(s);
    game.onTap = _onWorldTap;
    game.onAutosave = () => Save.save(s);
    fly.onArrive = (gem, v) { if (!gem) pending = math.max(0, pending - v); _bump = gem ? 'gem' : 'money'; _bumpN++; };
    WidgetsBinding.instance.addObserver(this);
    _hud = Timer.periodic(const Duration(milliseconds: 200), (_) { if (mounted) setState(() {}); });
    if (widget.startPanel != null) Future.delayed(const Duration(seconds: 2), () { if (mounted) openPanel(widget.startPanel!); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.startPanel != null) return;
      if (s.tut == 0) { _welcome(); }
      else if (widget.offlineSecs > 60) { _offerOffline(widget.offlineSecs); }
      else if (s.dailyReady) { Future.delayed(const Duration(milliseconds: 900), () { if (mounted && _modal == null) openPanel('missions'); }); }
    });
  }

  @override
  void dispose() { _hud?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.paused || st == AppLifecycleState.inactive || st == AppLifecycleState.detached) {
      if (_pausedAt == 0) { _pausedAt = nowMs(); Save.save(s); Sfx.pauseMusic(); }
    } else if (st == AppLifecycleState.resumed) {
      Sfx.resumeMusic();
      if (_pausedAt > 0) { final secs = (nowMs() - _pausedAt) / 1000; if (secs > 60) _offerOffline(secs); }
      _pausedAt = 0;
    }
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
  void _flyGems(int n, Offset from) => fly.launch(from, _center(gemKey), math.min(10, 2 + n), n.toDouble(), gem: true);

  @override
  void flightPaid(int g, double amount, int pax) {
    game.w.flightFx(g, amount, '+\$${fmt(amount)}');
    final pose = game.w.planePose(g);
    final o = pose != null ? game.worldToScreen(iso(pose.p.x, pose.p.z, pose.p.y)) : Offset(MediaQuery.of(context).size.width / 2, 200);
    final sz = MediaQuery.of(context).size;
    final onScreen = o.dx > 0 && o.dx < sz.width && o.dy > 0 && o.dy < sz.height;
    if (onScreen) { _flyFrom(o, amount, 6); } else { Sfx.play('coin'); }
    Sfx.play('jet', volume: 0.25);
    if (s.flightsAll == 1) banner('PRIMEIRO VOO!', '$pax passageiros pagaram \$${fmt(amount)}');
  }

  @override
  void stationUp(String id, int from, int to) {
    final st = stationById(id);
    game.w.levelFx(id);
    Sfx.haptic();
    if (from == 0) {
      Sfx.play('build'); confetti(70);
      banner('NOVO!', st.name);
      if (st.kind == Kind.gate) game.focusStation(id);
      return;
    }
    Sfx.play('up', rate: 1 + math.min(to, 60) * 0.008);
    final crossed = milestones.where((m) => from < m && to >= m).toList();
    if (crossed.isNotEmpty) { banner('x2 PRODUÇÃO!', '${st.name} chegou ao nível ${crossed.last}'); Sfx.play('level'); confetti(40); }
    if (id == 'checkin' && desksFor(to) > desksFor(from)) toast('Novo balcão de check-in aberto!');
    if (id == 'seguranca' && lanesFor(to) > lanesFor(from)) toast('Nova faixa de raio-X aberta!');
    if (id == 'lojas' && shopsFor(to) > shopsFor(from)) toast('Novo quiosque na praça!');
    if (id == 'pista' && runwayTier(to) > runwayTier(from)) banner('PISTA MAIOR!', 'Agora a pista recebe ${planeTypes[runwayTier(to)].name}');
    if (st.kind == Kind.gate && gateTier(to) > gateTier(from)) {
      final ok = runwayTier(s.lvl('pista')) >= gateTier(to);
      banner('AVIÃO MAIOR!', ok ? '${st.name} agora recebe ${planeTypes[gateTier(to)].name}' : 'Melhore a Pista para receber ${planeTypes[gateTier(to)].name}');
    }
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
    final sz = MediaQuery.of(context).size;
    if (r.$1 == 'gems') { _flyGems(r.$2.toInt(), Offset(sz.width / 2, sz.height * 0.6)); toast('+${r.$2.toInt()} gemas!'); }
    else if (r.$1 == 'coins') { _flyFrom(Offset(sz.width / 2, sz.height * 0.6), r.$2, 14); }
    else { toast('Lucro x2 por 30 minutos!'); Sfx.play('boost'); }
    Sfx.play('gift'); confetti(50); setState(() {});
  }
  @override
  void claimMission() {
    if (!s.missionReady) return;
    final g = s.missionGems, c = s.missionCoins;
    s.claimMission();
    pending += 0;
    final sz = MediaQuery.of(context).size;
    _flyGems(g, Offset(sz.width / 2, sz.height * 0.7));
    _flyFrom(Offset(sz.width / 2, sz.height * 0.7), c, 10);
    Sfx.play('gift'); confetti(45);
    setState(() {});
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
        await Art.loadBg(cityAt(s.city).bg);
        game.w.agents.clear(); for (final q in game.w.deskQ) { q.clear(); } for (final q in game.w.laneQ) { q.clear(); }
        game.focusWorld(-20, 6, zoomTo: 0.6);
        Save.save(s);
        banner(next.name.toUpperCase(), 'Novo aeroporto! Tudo rende ${fmt(cityMult(s.city))}x');
        Sfx.play('level'); confetti(120);
        setState(() {});
      }, child: Text('VOAR!', style: display(18))),
    ], child: Text('Você começa um aeroporto novo do zero em ${next.name}, mas todo o faturamento lá rende ${fmt(cityMult(s.city + 1))}x. Gerentes e melhorias ficam neste aeroporto. Suas gemas vão com você.', textAlign: TextAlign.center, style: body(15))));
  }
  @override
  void resetGame() async {
    await Save.wipe();
    if (!mounted) return;
    _showModal(GameModal(title: 'Progresso apagado', color: K.red, actions: const [], child: Text('Feche e abra o jogo de novo para recomeçar.', textAlign: TextAlign.center, style: body(15))));
  }

  // ================= mundo =================
  void _onWorldTap(String id) {
    if (id == 'none') { if (panel != null) closePanel(); return; }
    if (id == 'gift') { _openGift(); return; }
    if (id.startsWith('plane:')) {
      final g = int.parse(id.substring(6));
      s.hurry(g, 1.2);
      Sfx.play('tick', rate: 1.3); Sfx.haptic();
      return;
    }
    if (panel == 'st:$id') return;
    focusStation(id);
  }
  void _openGift() {
    final g = s.gift; if (g == null) return;
    final r = s.openGift();
    final o = game.worldToScreen(iso(Lay.gates[g] + 1, -1, 7));
    if (r.$1) { _flyGems(r.$2.toInt(), o); toast('Passageiro VIP deixou ${r.$2.toInt()} gemas!'); }
    else { _flyFrom(o, r.$2, 12); toast('Passageiro VIP deixou uma gorjeta!'); }
    Sfx.play('gift'); confetti(30);
  }

  void _showModal(Widget m) => setState(() => _modal = m);
  void _closeModal() => setState(() => _modal = null);

  void _welcome() {
    _showModal(GameModal(title: 'Bem-vindo ao SkyPort!', icon: 'plane', color: K.blue, actions: [
      GBtn(color: K.green, pulse: true, onTap: () { s.tut = 1; _closeModal(); Sfx.startMusic(); }, padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12), child: Text('VAMOS LÁ!', style: display(22))),
    ], child: Text('Você agora administra o aeroporto de Vale Verde. Os passageiros chegam, fazem check-in, passam no raio-X e embarcam. Cada voo que decola paga as passagens.\n\nMelhore cada etapa e descubra o gargalo (o "!" vermelho) para lucrar mais!', textAlign: TextAlign.center, style: body(15))));
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

  Future<void> _playLanding() async {
    if (!s.landReady) return;
    Sfx.click();
    final res = await Navigator.of(context).push<GameResult>(MaterialPageRoute(builder: (_) => LandingGame(rewardText: _rewardText)));
    _gameReward(res, isLand: true);
  }
  Future<void> _playXray() async {
    if (!s.xrayReady) return;
    Sfx.click();
    final res = await Navigator.of(context).push<GameResult>(MaterialPageRoute(builder: (_) => XrayGame(rewardText: _rewardText)));
    _gameReward(res, isLand: false);
  }
  String _rewardText(int stars) => stars == 0 ? 'Tente de novo daqui a pouco.' : 'Prêmio: \$${fmt(s.gameReward(const [0.0, 60.0, 150.0, 300.0][stars]))}${stars == 3 ? ' + 3 gemas' : ''}';
  void _gameReward(GameResult? r, {required bool isLand}) {
    if (r == null) return;
    if (isLand) { s.landAt = nowMs() + GameState.gameCd; } else { s.xrayAt = nowMs() + GameState.gameCd; }
    if (r.stars > 0) {
      final v = s.gameReward(const [0.0, 60.0, 150.0, 300.0][r.stars]);
      s.earn(v);
      final sz = MediaQuery.of(context).size;
      _flyFrom(Offset(sz.width / 2, sz.height * 0.5), v, 14);
      if (r.stars == 3) { s.gems += 3; _flyGems(3, Offset(sz.width / 2, sz.height * 0.5)); }
      Sfx.play('cash'); confetti(40);
    }
    Save.save(s);
    setState(() {});
  }

  // ================= construção =================
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: const Color(0xFF6FB352),
      body: Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (d) { _startZoom = game.zoom; _lastFocal = d.localFocalPoint; game.dragging = true; game.vel.setZero(); },
            onScaleUpdate: (d) {
              if (d.pointerCount > 1) game.zoomAt(d.localFocalPoint, _startZoom * d.scale / game.zoom);
              final delta = d.localFocalPoint - _lastFocal; game.panBy(delta); _lastFocal = d.localFocalPoint;
              if (d.pointerCount == 1) game.vel.setValues(delta.dx * 60, delta.dy * 60);
            },
            onScaleEnd: (d) { game.dragging = false; final v = d.velocity.pixelsPerSecond; game.vel.setValues(v.dx.clamp(-2500.0, 2500.0), v.dy.clamp(-2500.0, 2500.0)); },
            onTapUp: (d) => game.tapAt(d.localPosition),
            child: RepaintBoundary(child: GameWidget(game: game)),
          ),
        ),
        if (s.boostOn) const IgnorePointer(child: _Vignette(color: Color(0xFFFFC531))),
        if (s.tut == 1 && panel == null && _modal == null) _tutPointer('checkin', 'Toque no Check-in'),
        RepaintBoundary(child: Stack(children: [
          _topBar(pad),
          _sideButtons(pad),
          if (panel == null) _goal(pad),
          _bottomNav(pad),
        ])),
        Positioned(left: 0, right: 0, bottom: 0, child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (c, a) => SlideTransition(position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: c),
          child: panel == null ? const SizedBox.shrink(key: ValueKey('none')) : SafeArea(key: ValueKey(panel), top: false, child: buildPanel(panel!, s, this)),
        )),
        Positioned(top: pad.top + 112, left: 0, right: 0, child: IgnorePointer(child: Column(children: [for (final t in _toasts) _Toast(key: ValueKey(t.$1), text: t.$2)]))),
        Positioned.fill(child: RepaintBoundary(child: FlyLayer(c: fly))),
        Positioned.fill(child: RepaintBoundary(child: ConfettiLayer(c: conf))),
        if (_banner != null) Positioned.fill(child: BannerView(key: ValueKey(_banner), title: _banner!.$1, sub: _banner!.$2, onDone: _nextBanner)),
        if (_modal != null) Positioned.fill(child: Container(color: const Color(0x99101828), alignment: Alignment.center, padding: const EdgeInsets.all(18), child: _modal)),
      ]),
    );
  }

  Widget _tutPointer(String id, String text) {
    final c = game.w.stationCenter(id);
    final o = game.worldToScreen(iso(c.$1, c.$2, c.$3));
    final b = math.sin(DateTime.now().millisecondsSinceEpoch / 160) * 8;
    return Positioned(left: o.dx - 90, top: o.dy - 120 + b, child: IgnorePointer(child: SizedBox(width: 180, child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: K.navy, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.gold, width: 2.5)), child: Text(text, style: display(16))),
      Transform.rotate(angle: math.pi, child: const Ico('up', size: 54)),
    ]))));
  }

  Widget _topBar(EdgeInsets pad) {
    final shown = math.max(0.0, s.money - pending);
    final city = cityAt(s.city);
    return Positioned(
      top: pad.top + 6, left: 8, right: 8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(flex: 6, child: _Res(key: moneyKey, icon: 'coin', value: '\$${fmt(shown)}', sub: '+\$${fmt(s.rate)}/s', bump: _bump == 'money' ? _bumpN : 0, onTap: () => openPanel('upgrades'))),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: _Res(key: gemKey, icon: 'gem', value: '${s.gems}', bump: _bump == 'gem' ? _bumpN : 0, onTap: () => openPanel('shop'))),
          const SizedBox(width: 6),
          GestureDetector(onTap: () => openPanel('settings'), child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xE6182240), border: Border.all(color: const Color(0xFF0E1628), width: 2.5)),
            child: const Padding(padding: EdgeInsets.all(6), child: Ico('gear', size: 30)),
          )),
        ]),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => openPanel('cities'),
          child: Container(
            width: 190, padding: const EdgeInsets.fromLTRB(8, 4, 10, 6),
            decoration: BoxDecoration(color: const Color(0xE6182240), borderRadius: BorderRadius.circular(14), border: Border.all(color: s.canPrestige ? K.gold : const Color(0xFF0E1628), width: 2.5)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Ico('globe', size: 20), const SizedBox(width: 4), Expanded(child: Text(city.name, style: display(13), overflow: TextOverflow.ellipsis))]),
              const SizedBox(height: 3),
              GBar(value: s.prestigeProgress, height: 10, color: s.canPrestige ? K.gold : K.green),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sideButtons(EdgeInsets pad) {
    final now = nowMs();
    String cd(int at) => fmtTime(math.max(0, (at - now) / 1000));
    return Positioned(
      right: 8, top: pad.top + 62,
      child: Column(children: [
        _RoundBtn(icon: 'bolt', label: s.boostOn ? cd(s.boostUntil) : s.freeReady ? 'x2 GRÁTIS' : 'x2', glow: s.freeReady && !s.boostOn, active: s.boostOn, onTap: () { if (s.freeReady) { s.claimFree(); Sfx.play('boost'); banner('LUCRO x2!', 'Por 10 minutos'); setState(() {}); } else { openPanel('shop'); } }),
        const SizedBox(height: 10),
        _RoundBtn(icon: 'landing', label: s.landReady ? 'POUSO' : cd(s.landAt), glow: s.landReady, dim: !s.landReady, onTap: _playLanding),
        const SizedBox(height: 10),
        _RoundBtn(icon: 'xray', label: s.xrayReady ? 'RAIO-X' : cd(s.xrayAt), glow: s.xrayReady, dim: !s.xrayReady, onTap: _playXray),
        if (s.dailyReady) ...[const SizedBox(height: 10), _RoundBtn(icon: 'gift', label: 'DIÁRIO', glow: true, onTap: () => openPanel('missions'))],
      ]),
    );
  }

  Widget _goal(EdgeInsets pad) {
    final done = s.missionsDone;
    final p = s.missionProgress();
    final ready = s.missionReady || (done && s.canPrestige);
    final m = s.curMission;
    return Positioned(
      left: 10, right: 10, bottom: pad.bottom + 90,
      child: Center(child: GestureDetector(
        onTap: () {
          if (done) { openPanel('cities'); return; }
          if (s.missionReady) { claimMission(); return; }
          if (m.type == 'lvl' || m.type == 'unlock') { focusStation(m.target); } else if (m.type == 'manager') { openPanel('managers'); } else { openPanel('missions'); }
        },
        child: _Pulse(active: ready, child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 8),
          decoration: BoxDecoration(color: ready ? const Color(0xFFFFF4C4) : K.cream, borderRadius: BorderRadius.circular(18), border: Border.all(color: ready ? K.goldD : K.navy, width: 3), boxShadow: const [BoxShadow(color: Color(0x44000000), offset: Offset(0, 4))]),
          child: Row(children: [
            Ico(done ? 'globe' : ready ? 'gift' : 'mission', size: 38),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(done ? 'Abra a próxima cidade' : s.missionText(), style: body(15, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              done ? GBar(value: s.prestigeProgress, height: 12, color: K.gold) : GBar(value: p.$1 / p.$2, height: 12, color: K.green, label: ready ? 'PRONTO!' : null),
            ])),
            const SizedBox(width: 8),
            if (!done) Price('${s.missionGems}', icon: 'gem', size: 15),
          ]),
        )),
      )),
    );
  }

  Widget _bottomNav(EdgeInsets pad) {
    final anyUp = stations.any((st) => (s.built(st.id) && !st.oneTime && s.canUp(st)) || s.canUnlock(st));
    final mgrAv = managers.any((m) => !s.hasMgr(m.id) && s.money >= s.mgrCost(m));
    return Positioned(
      left: 6, right: 6, bottom: pad.bottom + 6,
      child: Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.fromLTRB(4, 7, 4, 5),
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF41588F), K.navy]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF0E1628), width: 3)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _NavBtn(icon: 'up', label: 'Melhorar', badge: anyUp ? '!' : null, active: panel == 'upgrades', onTap: () => openPanel('upgrades')),
          _NavBtn(icon: 'cap', label: 'Gerentes', badge: mgrAv ? '!' : null, active: panel == 'managers', onTap: () => openPanel('managers')),
          _NavBtn(icon: 'mission', label: 'Missões', badge: s.missionReady || s.dailyReady ? '!' : null, active: panel == 'missions', onTap: () => openPanel('missions')),
          _NavBtn(icon: 'bag', label: 'Loja', badge: s.freeReady ? '!' : null, active: panel == 'shop', onTap: () => openPanel('shop')),
          _NavBtn(icon: 'globe', label: 'Cidades', badge: s.canPrestige ? '!' : null, active: panel == 'cities', onTap: () => openPanel('cities')),
        ]),
      )),
    );
  }
}

// ================= widgets do HUD =================
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
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  int _last = 0;
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (widget.bump != _last) { _last = widget.bump; a.forward(from: 0); }
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(animation: a, builder: (_, c) => Transform.scale(scale: 1 + math.sin(a.value * math.pi) * 0.08, child: c), child: Container(
        height: 48, padding: const EdgeInsets.only(left: 2, right: 10),
        decoration: BoxDecoration(color: const Color(0xE6182240), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF0E1628), width: 2.5)),
        child: Row(children: [
          Ico(widget.icon, size: 40),
          const SizedBox(width: 2),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(widget.value, style: display(20))),
            if (widget.sub != null) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(widget.sub!, style: body(11, color: const Color(0xFF8FF0A4)))),
          ])),
        ]),
      )),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final String icon, label;
  final bool glow, dim, active;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.label, required this.onTap, this.glow = false, this.dim = false, this.active = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: _Pulse(active: glow, child: SizedBox(width: 64, child: Column(children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: glow || active ? K.gold : K.navy, width: 3), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: dim ? [const Color(0xFF8A93A6), const Color(0xFF5D6578)] : active ? [const Color(0xFFFFE27A), K.goldD] : [const Color(0xFF6FA8FF), const Color(0xFF2F5FD0)]), boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 4))]),
            child: Padding(padding: const EdgeInsets.all(7), child: Opacity(opacity: dim ? 0.7 : 1, child: Ico(icon, size: 40))),
          ),
          const SizedBox(height: 2),
          FittedBox(child: Text(label, style: display(12))),
        ]))),
      );
}

class _NavBtn extends StatelessWidget {
  final String icon, label;
  final String? badge;
  final bool active;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.label, required this.onTap, this.badge, this.active = false});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(color: active ? const Color(0x55FFFFFF) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Transform.translate(offset: Offset(0, active ? -4 : 0), child: Ico(icon, size: 38)),
              FittedBox(child: Text(label, style: display(12))),
            ]),
          ),
          if (badge != null) Positioned(top: -4, right: 6, child: Container(
            width: 22, height: 22, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: K.red, border: Border.all(color: Colors.white, width: 2)),
            child: Text(badge!, style: display(12, outline: false)),
          )),
        ]),
      ));
}

class _Pulse extends StatefulWidget {
  final bool active;
  final Widget child;
  const _Pulse({required this.active, required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..repeat(reverse: true);
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => !widget.active ? widget.child : AnimatedBuilder(animation: a, builder: (_, c) => Transform.scale(scale: 1 + a.value * 0.06, child: c), child: widget.child);
}

class _Toast extends StatelessWidget {
  final String text;
  const _Toast({super.key, required this.text});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 250),
        builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * -10), child: c)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xEE1E2A47), borderRadius: BorderRadius.circular(16), border: Border.all(color: K.gold, width: 2)),
          child: Text(text, style: display(15)),
        ),
      );
}

class _Vignette extends StatelessWidget {
  final Color color;
  const _Vignette({required this.color});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(gradient: RadialGradient(radius: 1.1, colors: [Colors.transparent, Colors.transparent, color.withValues(alpha: 0.28)], stops: const [0, 0.72, 1])));
}
