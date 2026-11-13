import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/audio.dart';
import '../core/data.dart';
import '../core/format.dart';
import '../core/state.dart';
import '../game/art.dart';
import 'kit.dart';

/// Janela central genérica (título, conteúdo e botões).
class GameModal extends StatelessWidget {
  final String title;
  final String? icon;
  final Widget child;
  final List<Widget> actions;
  final Color color;
  const GameModal({super.key, required this.title, this.icon, required this.child, this.actions = const [], this.color = K.blue});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1), duration: const Duration(milliseconds: 340), curve: Curves.easeOutBack,
        builder: (_, v, c) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: 0.88 + 0.12 * v, child: c)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x401F2A44), blurRadius: 40, offset: Offset(0, 12))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Material(
              color: Colors.white,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(height: 6, color: color),
                Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 6), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) Container(width: 92, height: 92, margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), padding: const EdgeInsets.all(10), child: Ico(icon!, size: 72)),
                  Text(title, textAlign: TextAlign.center, style: body(24, w: FontWeight.w900)),
                  const SizedBox(height: 10),
                  DefaultTextStyle(style: body(15, w: FontWeight.w700), textAlign: TextAlign.center, child: child),
                ])),
                Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 18), child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: actions)),
              ]),
            ),
          ),
        ),
      );
}

class OfflineModal extends StatelessWidget {
  final double secs, amount;
  final int gems;
  final bool first;
  /// 0 = pegar, 1 = dobrar (anúncio; grátis na primeira vez), 2 = triplicar com gemas.
  final void Function(int mode) onClaim;
  const OfflineModal({super.key, required this.secs, required this.amount, required this.gems, required this.onClaim, this.first = false});
  @override
  Widget build(BuildContext context) => GameModal(
        title: 'Bem-vindo de volta!', icon: 'cash', color: K.green,
        actions: [
          GBtn(color: K.grey, onTap: () => onClaim(0), child: Text('Pegar', style: display(16))),
          GBtn(color: K.purple, enabled: gems >= 15, onTap: () => onClaim(2), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('x3  ', style: display(16)), const Price('15', icon: 'gem', size: 15)])),
          GBtn(color: K.green, pulse: true, onTap: () => onClaim(1), child: Row(mainAxisSize: MainAxisSize.min, children: [if (!first) ...[const Icon(Icons.play_circle_fill_rounded, size: 20), const SizedBox(width: 6)], Text('Pegar em dobro', style: display(16))])),
        ],
        child: Column(children: [
          Text('Seu aeroporto operou por ${fmtTime(secs)} enquanto você estava fora e faturou:', textAlign: TextAlign.center, style: body(15)),
          const SizedBox(height: 8),
          Price('\$${fmt(amount)}', size: 30),
        ]),
      );
}

/// Baú: toque para abrir, depois mostra moedas, gemas, milhas e cartas.
/// Partícula simples (moedas, gemas, faíscas) para as telas de prêmio.
class _P {
  double x, y, vx, vy, life, rot, vr, size;
  final int kind; // 0 moeda, 1 gema, 2 faísca, 3 confete
  final Color color;
  _P(this.x, this.y, this.vx, this.vy, this.life, this.kind, this.color, this.size, this.rot, this.vr);
}

class _PPainter extends CustomPainter {
  final List<_P> ps;
  _PPainter(this.ps) : super();
  @override
  void paint(Canvas c, Size z) {
    for (final p in ps) {
      final a = p.life.clamp(0.0, 1.0);
      c.save(); c.translate(p.x, p.y); c.rotate(p.rot);
      switch (p.kind) {
        case 0:
          c.scale(1, 0.55 + 0.45 * math.cos(p.rot * 3).abs());
          c.drawCircle(Offset.zero, p.size, Paint()..color = const Color(0xFFE08A00).withValues(alpha: a));
          c.drawCircle(Offset.zero, p.size * 0.78, Paint()..color = const Color(0xFFFFC531).withValues(alpha: a));
          c.drawCircle(Offset(-p.size * 0.25, -p.size * 0.25), p.size * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.7 * a));
          break;
        case 1:
          final path = Path()..moveTo(0, -p.size)..lineTo(p.size * 0.8, -p.size * 0.2)..lineTo(0, p.size)..lineTo(-p.size * 0.8, -p.size * 0.2)..close();
          c.drawPath(path, Paint()..color = p.color.withValues(alpha: a));
          c.drawPath(Path()..moveTo(0, -p.size)..lineTo(p.size * 0.8, -p.size * 0.2)..lineTo(0, -p.size * 0.1)..close(), Paint()..color = Colors.white.withValues(alpha: 0.55 * a));
          break;
        case 2:
          final pth = Path()..moveTo(0, -p.size)..quadraticBezierTo(p.size * 0.15, -p.size * 0.15, p.size, 0)..quadraticBezierTo(p.size * 0.15, p.size * 0.15, 0, p.size)..quadraticBezierTo(-p.size * 0.15, p.size * 0.15, -p.size, 0)..quadraticBezierTo(-p.size * 0.15, -p.size * 0.15, 0, -p.size);
          c.drawPath(pth, Paint()..color = p.color.withValues(alpha: a));
          break;
        default:
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), const Radius.circular(2)), Paint()..color = p.color.withValues(alpha: a));
      }
      c.restore();
    }
  }
  @override
  bool shouldRepaint(covariant _PPainter o) => true;
}

/// Sistema de partículas que roda com o ticker do modal.
mixin _Particles<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  final List<_P> parts = [];
  final rnd = math.Random();
  late final Ticker _pt = createTicker(_ptick)..start();
  Duration _pl = Duration.zero;
  @override
  void initState() { super.initState(); _pt.isActive; }
  void _ptick(Duration d) {
    final dt = ((d - _pl).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble(); _pl = d;
    if (parts.isEmpty) return;
    for (final p in parts) { p.vy += (p.kind == 3 ? 380 : 900) * dt; p.vx *= 0.995; p.x += p.vx * dt; p.y += p.vy * dt; p.rot += p.vr * dt; p.life -= dt * (p.kind == 2 ? 1.6 : 0.6); }
    parts.removeWhere((p) => p.life <= 0);
    if (mounted) setState(() {});
  }
  void burst(Offset o, {int coins = 0, int gems = 0, int sparks = 0, int confetti = 0, double power = 1}) {
    const gc = [Color(0xFF3E8BFF), Color(0xFF3FD46B), Color(0xFFFF6FB5), Color(0xFF8F62F8)];
    const cc = [Color(0xFFFF5A5F), Color(0xFFFFC531), Color(0xFF3E8BFF), Color(0xFF3FD46B), Color(0xFF8F62F8), Color(0xFFFFFFFF)];
    for (var i = 0; i < coins + gems + sparks + confetti; i++) {
      final k = i < coins ? 0 : i < coins + gems ? 1 : i < coins + gems + sparks ? 2 : 3;
      final a = -math.pi / 2 + (rnd.nextDouble() - 0.5) * (k == 2 ? math.pi * 2 : 2.2);
      final sp = (k == 2 ? 120 + rnd.nextDouble() * 260 : 380 + rnd.nextDouble() * 520) * power;
      parts.add(_P(o.dx, o.dy, math.cos(a) * sp, math.sin(a) * sp, 1.6 + rnd.nextDouble() * 0.6, k, k == 1 ? gc[i % 4] : k == 2 ? const Color(0xFFFFF3B0) : cc[i % 6], k == 0 ? 11 + rnd.nextDouble() * 6 : k == 1 ? 10 + rnd.nextDouble() * 5 : k == 2 ? 8 + rnd.nextDouble() * 10 : 10, rnd.nextDouble() * 6, (rnd.nextDouble() - 0.5) * 12));
    }
  }
  @override
  void dispose() { _pt.dispose(); super.dispose(); }
}

/// Raios girando atrás de um objeto.
class _RayPainter extends CustomPainter {
  final Color c;
  final double k;
  _RayPainter(this.c, [this.k = 1]);
  @override
  void paint(Canvas cv, Size z) {
    final o = z.center(Offset.zero), r = z.width / 2;
    final p = Paint()..shader = RadialGradient(colors: [c.withValues(alpha: 0.6 * k), c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r));
    for (var i = 0; i < 14; i++) {
      final a = i * math.pi / 7;
      cv.drawPath(Path()..moveTo(o.dx, o.dy)..lineTo(o.dx + math.cos(a - 0.09) * r, o.dy + math.sin(a - 0.09) * r)..lineTo(o.dx + math.cos(a + 0.09) * r, o.dy + math.sin(a + 0.09) * r)..close(), p);
    }
    cv.drawCircle(o, r * 0.42, Paint()..shader = RadialGradient(colors: [c.withValues(alpha: 0.75 * k), c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r * 0.42)));
  }
  @override
  bool shouldRepaint(covariant _RayPainter o) => o.k != k || o.c != c;
}

const rarCols = [Color(0xFF8A93A6), Color(0xFF3E8BFF), Color(0xFF8F62F8), Color(0xFFFFB020)];

/// Baú: cai na tela, toques vão rachando a tampa, explode em moedas e revela carta por carta.
class ChestModal extends StatefulWidget {
  final String type;
  final Loot Function() open;
  final VoidCallback onDone;
  final int left;
  const ChestModal({super.key, required this.type, required this.open, required this.onDone, this.left = 0});
  @override
  State<ChestModal> createState() => _ChestModalState();
}

class _ChestModalState extends State<ChestModal> with TickerProviderStateMixin, _Particles<ChestModal> {
  late final AnimationController drop = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..forward();
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
  late final AnimationController hit = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  late final AnimationController flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  Loot? loot;
  int taps = 0, shown = 0; // shown: itens revelados (moedas, gemas, milhas, depois cartas)
  final Set<int> flipped = {};
  bool done = false;
  final GlobalKey _chestKey = GlobalKey();
  String get tierName => widget.type == 'chest_epic' ? 'Baú épico' : widget.type == 'chest_gold' ? 'Baú de ouro' : 'Baú de madeira';
  Color get glow => widget.type == 'chest_epic' ? const Color(0xFFB89CFF) : widget.type == 'chest_gold' ? const Color(0xFFFFC531) : const Color(0xFFFFA24A);
  @override
  void dispose() { drop.dispose(); spin.dispose(); hit.dispose(); idle.dispose(); flash.dispose(); super.dispose(); }
  Offset get _center { final b = _chestKey.currentContext?.findRenderObject() as RenderBox?; if (b == null) { final z = MediaQuery.of(context).size; return Offset(z.width / 2, z.height * 0.4); } return b.localToGlobal(b.size.center(Offset.zero)); }
  void _tap() {
    if (loot != null) { _next(); return; }
    taps++; hit.forward(from: 0); Sfx.haptic(12 + taps * 12);
    burst(_center, sparks: 6 + taps * 4, power: 0.8);
    if (taps < 3) { Sfx.play('tick', rate: 1 + taps * 0.25); return; }
    // abre!
    Sfx.play('gift'); Sfx.haptic(60);
    flash.forward(from: 0);
    final l = widget.open();
    setState(() => loot = l);
    final tier = widget.type == 'chest_epic' ? 2 : widget.type == 'chest_gold' ? 1 : 0;
    burst(_center, coins: 18 + tier * 14, gems: 4 + tier * 6, sparks: 16, confetti: 24 + tier * 20, power: 1.1 + tier * 0.15);
    _auto();
  }
  /// Revela sozinho a cada instante; o toque acelera.
  void _auto() async {
    final l = loot!;
    final total = 3 + l.cards.length;
    while (mounted && shown < total) {
      await Future.delayed(Duration(milliseconds: shown < 3 ? 260 : 380));
      if (!mounted) return;
      if (shown < total) _reveal();
      if (shown > 3 && l.cards.length >= shown - 3 && modelById(l.cards[shown - 4]).rarity >= 3) await Future.delayed(const Duration(milliseconds: 650));
    }
  }
  void _reveal() {
    final l = loot!;
    final total = 3 + l.cards.length;
    if (shown >= total) { setState(() => done = true); return; }
    shown++;
    if (shown > 3) {
      final i = shown - 4;
      flipped.add(i);
      final r = modelById(l.cards[i]).rarity;
      Sfx.play(r >= 2 ? 'level' : 'pop', rate: 1 + r * 0.08);
      if (r >= 2) { Sfx.haptic(40); burst(_center + const Offset(0, 120), sparks: 14, confetti: r >= 3 ? 40 : 14, power: 0.9); }
    } else {
      Sfx.play('coin', rate: 1 + shown * 0.1);
    }
    if (shown >= total) Future.delayed(const Duration(milliseconds: 300), () { if (mounted) setState(() => done = true); });
    setState(() {});
  }
  void _next() { if (!done) { while (shown < 3 + loot!.cards.length) { _reveal(); } setState(() => done = true); } }
  @override
  Widget build(BuildContext context) {
    final l = loot;
    final sz = MediaQuery.of(context).size;
    final open = l != null;
    return SizedBox(
      width: sz.width, height: sz.height * 0.9,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          Positioned(top: 8, left: 0, right: 0, child: Column(children: [
            Text(tierName, textAlign: TextAlign.center, style: display(30)),
            const SizedBox(height: 4),
            AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(
              !open ? (taps == 0 ? 'Toque no baú para abrir' : ['', 'Mais 2 toques!', 'Mais 1!'][taps]) : done ? (widget.left > 0 ? 'Ainda tem ${widget.left} baú${widget.left > 1 ? 's' : ''}!' : 'Tudo seu!') : 'Toque para ver mais rápido',
              key: ValueKey('$taps$open$done'), style: body(15, color: Colors.white.withValues(alpha: 0.85)))),
          ])),
          // baú
          Positioned(top: open ? 70 : sz.height * 0.16, left: 0, right: 0, child: AnimatedBuilder(
            animation: Listenable.merge([drop, hit, idle, spin, flash]),
            builder: (_, __) {
              final d = Curves.bounceOut.transform(drop.value);
              final shakeA = !open ? math.sin(idle.value * math.pi * 2 * (1 + taps)) * (0.025 + taps * 0.03) + math.sin(hit.value * math.pi * 6) * (1 - hit.value) * 0.22 : 0.0;
              final sq = 1 + math.sin(hit.value * math.pi) * 0.16;
              final size = open ? 150.0 : 210.0;
              return SizedBox(height: open ? 190 : 300, child: Stack(alignment: Alignment.center, children: [
                Transform.rotate(angle: spin.value * math.pi * 2, child: CustomPaint(size: Size.square(open ? 300 : 340 + taps * 30.0), painter: _RayPainter(glow, open ? 1 : 0.35 + taps * 0.22))),
                Transform.translate(offset: Offset(0, (1 - d) * -sz.height * 0.5), child: Transform.rotate(angle: shakeA, child: Transform.scale(scaleX: 2 - sq, scaleY: sq, child: SizedBox(key: _chestKey, width: size, height: size, child: Ico(open ? '${widget.type}_open' : widget.type, size: size))))),
                if (flash.value > 0 && flash.value < 1) IgnorePointer(child: Container(width: 600, height: 600, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withValues(alpha: (1 - flash.value)), Colors.white.withValues(alpha: 0)])))),
              ]));
            },
          )),
          // prêmios
          if (l != null) Positioned(top: 270, left: 12, right: 12, child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _res(0, 'coin', '\$${fmt(l.coins)}'), const SizedBox(width: 8),
              _res(1, 'gem', '+${l.gems}'), const SizedBox(width: 8),
              _res(2, 'miles', '+${fmt(l.miles)}'),
            ]),
            const SizedBox(height: 14),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 10, children: [for (var i = 0; i < l.cards.length; i++) _card(i, l.cards[i], l.fresh.contains(l.cards[i]))]),
            const SizedBox(height: 18),
            AnimatedOpacity(opacity: done ? 1 : 0, duration: const Duration(milliseconds: 250), child: IgnorePointer(ignoring: !done, child: GBtn(color: K.green, pulse: true, padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 13), onTap: widget.onDone, child: Text(widget.left > 0 ? 'Próximo baú' : 'Pegar tudo', style: display(19))))),
          ])),
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _PPainter(parts)))),
        ]),
      ),
    );
  }
  Widget _res(int i, String icon, String v) {
    final on = shown > i;
    return AnimatedScale(
      scale: on ? 1 : 0, duration: const Duration(milliseconds: 380), curve: Curves.easeOutBack,
      child: Container(
        width: 100, padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: K.shadow),
        child: Column(children: [Ico(icon, size: 34), FittedBox(child: Text(v, style: body(16, w: FontWeight.w900)))]),
      ),
    );
  }
  Widget _card(int i, String id, bool fresh) {
    final m = modelById(id), up = flipped.contains(i);
    final c = rarCols[m.rarity];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: up ? 1 : 0), duration: const Duration(milliseconds: 420), curve: Curves.easeInOutBack,
      builder: (_, v, __) {
        final a = v * math.pi, front = a > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..setEntry(3, 2, 0.0015)..rotateY(front ? a - math.pi : a)..multiply(Matrix4.diagonal3Values(1 + math.sin(a) * 0.12, 1 + math.sin(a) * 0.12, 1)),
          child: front ? _cardFront(m, fresh, c) : _cardBack(),
        );
      },
    );
  }
  Widget _cardBack() => Container(
        width: 86, height: 118,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3D6BFF), Color(0xFF1E3FA8)]), border: Border.all(color: Colors.white, width: 3), boxShadow: K.shadow),
        child: const Center(child: Icon(Icons.flight_rounded, color: Colors.white70, size: 40)),
      );
  Widget _cardFront(PlaneModel m, bool fresh, Color c) => Container(
        width: 86, height: 118, padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: c, width: 3), boxShadow: [BoxShadow(color: c.withValues(alpha: m.rarity >= 2 ? 0.9 : 0.4), blurRadius: m.rarity >= 2 ? 22 : 10, spreadRadius: m.rarity >= 3 ? 3 : 0)]),
        child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: fresh ? K.red : c, borderRadius: BorderRadius.circular(8)), child: Text(fresh ? 'NOVO!' : rarityNames[m.rarity].toUpperCase(), style: body(8.5, color: Colors.white, w: FontWeight.w900))),
          Expanded(child: Container(margin: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), color: c.withValues(alpha: 0.14)), child: Center(child: Ico('pm_${m.tier}_${m.liv}', size: 62)))),
          Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10, w: FontWeight.w900)),
        ]),
      );
}

/// Roleta do dia.
/// Roleta da sorte: 12 setores, aro dourado com lâmpadas, ponteiro que bate nos pinos.
class WheelModal extends StatefulWidget {
  final int Function() spin;
  final String Function(int) apply;
  final List<String> labels;
  final VoidCallback onClose;
  const WheelModal({super.key, required this.spin, required this.apply, required this.onClose, this.labels = const []});
  @override
  State<WheelModal> createState() => _WheelModalState();
}

class _WheelModalState extends State<WheelModal> with TickerProviderStateMixin, _Particles<WheelModal> {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
  late final AnimationController bulbs = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  late final AnimationController kick = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
  late final AnimationController win = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int? target;
  String? result;
  int _lastSeg = 0;
  double _end = 0;
  static int get n => wheelPrizes.length;
  @override
  void dispose() { a.dispose(); bulbs.dispose(); kick.dispose(); win.dispose(); super.dispose(); }
  void _go() {
    if (target != null) return;
    target = widget.spin(); Sfx.play('whoosh'); Sfx.haptic(20);
    final seg = math.pi * 2 / n, jitter = (rnd.nextDouble() - 0.5) * seg * 0.6;
    _end = math.pi * 2 * 6 + (math.pi * 2 - (target! + 0.5) * seg) + jitter;
    a.addListener(() {
      final s0 = ((_angle() + seg / 2) / seg).floor();
      if (s0 != _lastSeg) { _lastSeg = s0; kick.forward(from: 0); final slow = a.value > 0.7; Sfx.play('tick', volume: slow ? 0.55 : 0.25, rate: 0.9 + (1 - a.value) * 0.5); if (slow) Sfx.haptic(6); }
    });
    a.forward().whenComplete(() {
      final r = widget.apply(target!);
      final big = wheelPrizes[target!].$1.startsWith('chest') || wheelPrizes[target!].$1 == 'boost';
      setState(() => result = r);
      win.forward(from: 0);
      Sfx.play(big ? 'level' : 'gift'); Sfx.haptic(50);
      final z = MediaQuery.of(context).size;
      burst(Offset(z.width / 2, z.height * 0.36), coins: big ? 22 : 14, gems: 6, sparks: 14, confetti: big ? 60 : 30);
    });
    setState(() {});
  }
  // desacelera longo no final (suspense)
  double _angle() { final t = a.value; return _end * (1 - math.pow(1 - t, 3.6)).toDouble(); }
  @override
  Widget build(BuildContext context) {
    final z = MediaQuery.of(context).size;
    final w = math.min(z.width - 40, 340.0);
    final p = target != null ? wheelPrizes[target!] : null;
    return SizedBox(
      width: z.width, height: z.height * 0.86,
      child: Stack(alignment: Alignment.topCenter, children: [
        Positioned(top: 4, left: 0, right: 0, child: Column(children: [
          Text('Roleta da Sorte', textAlign: TextAlign.center, style: display(30)),
          Text(result == null ? 'Um giro grátis por dia' : 'Você ganhou!', textAlign: TextAlign.center, style: body(15, color: Colors.white.withValues(alpha: 0.85))),
        ])),
        Positioned(top: 78, child: GestureDetector(
          onTap: _go,
          child: SizedBox(width: w + 30, height: w + 46, child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(animation: Listenable.merge([a, bulbs, win]), builder: (_, __) => CustomPaint(size: Size.square(w + 24), painter: _WheelPainter(_angle(), bulbs.value, widget.labels, result != null ? target : null, win.value))),
            // centro
            GestureDetector(onTap: _go, child: Container(
              width: w * 0.27, height: w * 0.27,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xFFFFE27A), Color(0xFFFFB000)]), border: Border.all(color: const Color(0xFF1E2A47), width: 5), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4))]),
              child: Center(child: target == null ? Text('GIRAR', style: display(w * 0.06)) : const Ico('star', size: 40)),
            )),
            // ponteiro
            Positioned(top: 0, child: AnimatedBuilder(animation: kick, builder: (_, c) => Transform.rotate(angle: -math.sin(kick.value * math.pi) * 0.35, alignment: Alignment.topCenter, child: c), child: CustomPaint(size: const Size(46, 60), painter: _PointerPainter()))),
          ])),
        )),
        if (result != null) Positioned(top: w + 136, left: 20, right: 20, child: ScaleTransition(
          scale: CurvedAnimation(parent: win, curve: Curves.elasticOut),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 20, 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: K.shadow),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Ico(_ico(p!.$1), size: 46), const SizedBox(width: 8), Text(result!, style: body(24, w: FontWeight.w900))]),
            ),
            const SizedBox(height: 14),
            GBtn(color: K.green, pulse: true, padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 13), onTap: widget.onClose, child: Text('Pegar', style: display(20))),
          ]),
        ))
        else if (target == null) Positioned(top: w + 140, child: GBtn(color: K.green, pulse: true, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14), onTap: _go, child: Text('Girar!', style: display(22)))),
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _PPainter(parts)))),
      ]),
    );
  }
}

String _ico(String k) => k == 'coins' ? 'coin' : k == 'gems' ? 'gem' : k == 'boost' ? 'bolt' : k;

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()..moveTo(s.width / 2, s.height)..lineTo(4, 14)..quadraticBezierTo(s.width / 2, -8, s.width - 4, 14)..close();
    c.drawPath(p.shift(const Offset(0, 4)), Paint()..color = const Color(0x55000000));
    c.drawPath(p, Paint()..color = const Color(0xFFFF4D5E));
    c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = const Color(0xFF1E2A47)..strokeJoin = StrokeJoin.round);
    c.drawCircle(Offset(s.width / 2, 18), 7, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class _WheelPainter extends CustomPainter {
  final double angle, blink, winK;
  final List<String> labels;
  final int? win;
  _WheelPainter(this.angle, this.blink, this.labels, this.win, this.winK);
  static const cols = [Color(0xFFFF5A5F), Color(0xFFFFC531), Color(0xFF3E8BFF), Color(0xFF3FD46B), Color(0xFF8F62F8), Color(0xFFFF9F1C), Color(0xFF17B3A3), Color(0xFFFF6FB5)];
  @override
  void paint(Canvas c, Size s) {
    final n = wheelPrizes.length;
    final R = s.width / 2, ctr = Offset(R, R + 14), r = R - 18, seg = math.pi * 2 / n;
    // sombra e aro
    c.drawCircle(ctr + const Offset(0, 8), R, Paint()..color = const Color(0x55000000));
    c.drawCircle(ctr, R, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE27A), Color(0xFFE08A00)]).createShader(Rect.fromCircle(center: ctr, radius: R)));
    c.drawCircle(ctr, R, Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = const Color(0xFF1E2A47));
    // lâmpadas
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi * 2 / 24, o = ctr + Offset(math.cos(a), math.sin(a)) * (R - 9);
      final on = (i + (blink * 2).floor()) % 2 == 0;
      if (on) c.drawCircle(o, 8, Paint()..color = const Color(0x66FFF6C8));
      c.drawCircle(o, 4.5, Paint()..color = on ? Colors.white : const Color(0xFFB36A00));
    }
    c.save(); c.translate(ctr.dx, ctr.dy); c.rotate(angle);
    for (var i = 0; i < n; i++) {
      final a0 = -math.pi / 2 + i * seg - seg / 2;
      final col = wheelPrizes[i].$1 == 'chest_epic' ? const Color(0xFF2B1F5C) : cols[i % cols.length];
      final rect = Rect.fromCircle(center: Offset.zero, radius: r);
      c.drawArc(rect, a0, seg, true, Paint()..shader = RadialGradient(colors: [Color.lerp(col, Colors.white, 0.35)!, col]).createShader(rect));
      c.drawArc(rect, a0, seg, true, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white.withValues(alpha: 0.85));
      if (win == i) c.drawArc(rect, a0, seg, true, Paint()..color = Colors.white.withValues(alpha: 0.45 * (0.5 + 0.5 * math.sin(winK * math.pi * 6))));
      // ícone e texto ao longo do raio
      c.save(); c.rotate(-math.pi / 2 + i * seg); c.translate(r * 0.66, 0); c.rotate(math.pi / 2);
      final img = Art.icons['icon_${_ico(wheelPrizes[i].$1)}'];
      final isz = r * 0.27;
      if (img != null) c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: Offset(0, -isz * 0.15), width: isz, height: isz), Paint()..filterQuality = FilterQuality.medium);
      final t = i < labels.length ? labels[i] : '';
      if (t.isNotEmpty) {
        final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: r * 0.085, color: Colors.white, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1))])), textDirection: TextDirection.ltr)..layout();
        tp.paint(c, Offset(-tp.width / 2, isz * 0.38));
      }
      c.restore();
    }
    // pinos
    for (var i = 0; i < n; i++) { final a = -math.pi / 2 + i * seg - seg / 2; c.drawCircle(Offset(math.cos(a), math.sin(a)) * (r - 3), 4, Paint()..color = const Color(0xFF1E2A47)); }
    c.restore();
    c.drawCircle(ctr, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = const Color(0xFF1E2A47));
  }
  @override
  bool shouldRepaint(covariant _WheelPainter o) => true;
}

/// Calendário de login: 7 dias, o de hoje brilha.
class DailyModal extends StatelessWidget {
  final int day;
  final String Function(int) label;
  final VoidCallback onClaim;
  const DailyModal({super.key, required this.day, required this.label, required this.onClaim});
  @override
  Widget build(BuildContext context) {
    Widget cell(int i, {bool wide = false}) {
      final r = dailyRewards[i], cur = i == day % 7, done = i < day % 7;
      final ic = r.$1 == 'coins' ? 'coin' : r.$1 == 'gems' ? 'gem' : r.$1 == 'boost' ? 'bolt' : 'chest_epic';
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 300 + i * 70), curve: Curves.easeOutBack,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: Container(
          width: wide ? 152 : 72, height: 96,
          decoration: BoxDecoration(
            color: cur ? K.goldL : done ? K.greenL : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cur ? K.gold : done ? K.green.withValues(alpha: 0.5) : K.line, width: cur ? 3 : 1.5),
            boxShadow: cur ? [BoxShadow(color: K.gold.withValues(alpha: 0.6), blurRadius: 16)] : K.shadowS,
          ),
          child: Stack(alignment: Alignment.center, children: [
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Dia ${i + 1}', style: body(11, color: cur ? K.goldD : K.muted, w: FontWeight.w900)),
              Opacity(opacity: done ? 0.45 : 1, child: Ico(ic, size: wide ? 46 : 38)),
              Text(label(i), style: body(11.5, w: FontWeight.w900)),
            ]),
            if (done) const Positioned(right: 4, top: 4, child: Icon(Icons.check_circle_rounded, color: K.green, size: 20)),
          ]),
        ),
      );
    }
    return GameModal(
      title: 'Prêmio do dia', icon: 'gift', color: K.gold,
      actions: [GBtn(color: K.green, pulse: true, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 13), onTap: onClaim, child: Text('Pegar dia ${day % 7 + 1}', style: display(19)))],
      child: Column(children: [
        Text('Entre todo dia: o 7º dia dá um baú épico!', textAlign: TextAlign.center, style: body(14, color: K.muted)),
        const SizedBox(height: 12),
        Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [for (var i = 0; i < 6; i++) cell(i), cell(6, wide: true)]),
      ]),
    );
  }
}

/// Subiu de nível: selo grande e os prêmios.
class LevelUpModal extends StatefulWidget {
  final int level, gems;
  final String chest;
  final VoidCallback onDone;
  const LevelUpModal({super.key, required this.level, required this.gems, required this.chest, required this.onDone});
  @override
  State<LevelUpModal> createState() => _LevelUpModalState();
}

class _LevelUpModalState extends State<LevelUpModal> with TickerProviderStateMixin, _Particles<LevelUpModal> {
  late final AnimationController inA = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { final z = MediaQuery.of(context).size; burst(Offset(z.width / 2, z.height * 0.32), sparks: 20, confetti: 50, power: 1.1); });
  }
  @override
  void dispose() { inA.dispose(); spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final z = MediaQuery.of(context).size;
    return SizedBox(width: z.width, height: z.height * 0.8, child: Stack(alignment: Alignment.topCenter, children: [
      Positioned(top: 30, child: AnimatedBuilder(animation: Listenable.merge([inA, spin]), builder: (_, __) {
        final k = Curves.elasticOut.transform(inA.value);
        return SizedBox(width: 320, height: 300, child: Stack(alignment: Alignment.center, children: [
          Transform.rotate(angle: spin.value * math.pi * 2, child: CustomPaint(size: const Size.square(320), painter: _RayPainter(const Color(0xFFB89CFF)))),
          Transform.scale(scale: k, child: Container(
            width: 170, height: 170,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFA98BFF), Color(0xFF6A45F0)]), border: Border.all(color: Colors.white, width: 6), boxShadow: const [BoxShadow(color: Color(0x667C5CFA), blurRadius: 30, spreadRadius: 4)]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('NÍVEL', style: display(20)), Text('${widget.level}', style: display(66))]),
          )),
        ]));
      })),
      Positioned(top: 330, left: 20, right: 20, child: FadeTransition(opacity: CurvedAnimation(parent: inA, curve: const Interval(0.4, 1)), child: Column(children: [
        Text('Seu aeroporto subiu de nível!', textAlign: TextAlign.center, style: display(22)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _chip('gem', '+${widget.gems}'), const SizedBox(width: 10),
          _chip(widget.chest, widget.chest == 'chest_epic' ? 'Épico' : widget.chest == 'chest_gold' ? 'Ouro' : 'Baú'),
        ]),
        const SizedBox(height: 20),
        GBtn(color: K.green, pulse: true, padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 13), onTap: widget.onDone, child: Text('Coletar', style: display(20))),
      ]))),
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _PPainter(parts)))),
    ]));
  }
  Widget _chip(String ic, String t) => Container(
        width: 110, padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: K.shadow),
        child: Column(children: [Ico(ic, size: 46), Text(t, style: body(16, w: FontWeight.w900))]),
      );
}
