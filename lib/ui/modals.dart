import 'dart:math' as math;

import 'package:flutter/material.dart';

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
class ChestModal extends StatefulWidget {
  final String type;
  final Loot Function() open;
  final VoidCallback onDone;
  final int left;
  const ChestModal({super.key, required this.type, required this.open, required this.onDone, this.left = 0});
  @override
  State<ChestModal> createState() => _ChestModalState();
}

class _ChestModalState extends State<ChestModal> with TickerProviderStateMixin {
  late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  late final AnimationController reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final AnimationController pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  Loot? loot;
  int taps = 0;
  @override
  void dispose() { shake.dispose(); spin.dispose(); reveal.dispose(); pop.dispose(); super.dispose(); }
  void _tap() {
    if (loot != null) return;
    taps++; pop.forward(from: 0); Sfx.haptic(15 + taps * 10);
    if (taps < 3) { Sfx.play('tick', rate: 1 + taps * 0.2); setState(() {}); return; }
    Sfx.play('gift'); Sfx.haptic(50);
    setState(() => loot = widget.open());
    reveal.forward();
  }
  static const rar = [Color(0xFF8A93A6), Color(0xFF3E8BFF), Color(0xFF8F62F8), Color(0xFFFFB020)];
  @override
  Widget build(BuildContext context) {
    final gold = widget.type == 'chest_gold';
    final glow = gold ? const Color(0xFFFFC531) : const Color(0xFFFF9F1C);
    final l = loot;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: Colors.transparent,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(gold ? 'Baú de ouro' : 'Baú de cartas', style: display(30)),
          const SizedBox(height: 2),
          Text(l == null ? (taps == 0 ? 'Toque 3 vezes para abrir' : 'Mais ${3 - taps}!') : 'Você ganhou', style: body(15, color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _tap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: l == null ? 250 : 150,
              child: Stack(alignment: Alignment.center, children: [
                RotationTransition(turns: spin, child: CustomPaint(size: Size.square(l == null ? 300 : 220), painter: _RayPainter(glow))),
                Container(width: l == null ? 170 : 110, height: l == null ? 170 : 110, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [glow.withValues(alpha: 0.55), glow.withValues(alpha: 0)]))),
                AnimatedBuilder(
                  animation: Listenable.merge([shake, pop]),
                  builder: (_, c) {
                    final w0 = l == null ? math.sin(shake.value * math.pi * 2) * (0.04 + taps * 0.035) : 0.0;
                    final p0 = 1 + math.sin(pop.value * math.pi) * 0.22;
                    return Transform.rotate(angle: w0, child: Transform.scale(scale: p0, child: c));
                  },
                  child: Ico(widget.type, size: l == null ? 170 : 96),
                ),
              ]),
            ),
          ),
          if (l != null) AnimatedBuilder(animation: reveal, builder: (_, __) {
            double k(int i) => Curves.easeOutBack.transform(((reveal.value - i * 0.09) / 0.3).clamp(0.0, 1.0));
            Widget res(int i, String icon, String v, String label) => Transform.scale(scale: k(i), child: Container(
                  width: 112, padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: K.shadow),
                  child: Column(children: [Ico(icon, size: 38), Text(v, style: body(16, w: FontWeight.w900)), Text(label, style: body(10.5, color: K.muted))]),
                ));
            return Column(children: [
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                res(0, 'coin', '\$${fmt(l.coins)}', 'moedas'),
                res(1, 'gem', '${l.gems}', 'gemas'),
                res(2, 'miles', fmt(l.miles), 'milhas'),
              ]),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < l.cards.length; i++) Transform.scale(scale: k(3 + i), child: _card(l.cards[i], l.fresh.contains(l.cards[i]))),
              ]),
              const SizedBox(height: 16),
              Opacity(opacity: ((reveal.value - 0.6) / 0.3).clamp(0.0, 1.0), child: GBtn(color: K.green, pulse: true, padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 13), onTap: widget.onDone, child: Text(widget.left > 0 ? 'Próximo baú (${widget.left})' : 'Pegar tudo', style: display(19)))),
            ]);
          }),
        ]),
      ),
    );
  }
  Widget _card(String id, bool fresh) {
    final m = modelById(id);
    return Container(
      width: 92, padding: const EdgeInsets.fromLTRB(5, 5, 5, 7),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: rar[m.rarity], width: 2.5), boxShadow: [BoxShadow(color: rar[m.rarity].withValues(alpha: 0.55), blurRadius: 14)]),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1), decoration: BoxDecoration(color: fresh ? K.red : rar[m.rarity], borderRadius: BorderRadius.circular(8)), child: Text(fresh ? 'NOVO!' : rarityNames[m.rarity].toUpperCase(), style: body(9, color: Colors.white, w: FontWeight.w900))),
        const SizedBox(height: 3),
        Container(width: 80, height: 56, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: rar[m.rarity].withValues(alpha: 0.13)), child: Ico('pm_${m.tier}_${m.liv}', size: 56)),
        const SizedBox(height: 3),
        Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(10.5, w: FontWeight.w900)),
      ]),
    );
  }
}

class _RayPainter extends CustomPainter {
  final Color c;
  _RayPainter(this.c);
  @override
  void paint(Canvas cv, Size z) {
    final o = z.center(Offset.zero), r = z.width / 2;
    final p = Paint()..shader = RadialGradient(colors: [c.withValues(alpha: 0.5), c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      cv.drawPath(Path()..moveTo(o.dx, o.dy)..lineTo(o.dx + math.cos(a - 0.11) * r, o.dy + math.sin(a - 0.11) * r)..lineTo(o.dx + math.cos(a + 0.11) * r, o.dy + math.sin(a + 0.11) * r)..close(), p);
    }
  }
  @override
  bool shouldRepaint(covariant _RayPainter o) => false;
}

/// Roleta do dia.
class WheelModal extends StatefulWidget {
  final int Function() spin;
  final String Function(int) apply;
  final VoidCallback onClose;
  const WheelModal({super.key, required this.spin, required this.apply, required this.onClose});
  @override
  State<WheelModal> createState() => _WheelModalState();
}

class _WheelModalState extends State<WheelModal> with SingleTickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  int? target;
  String? result;
  double _lastTick = 0;
  @override
  void dispose() { a.dispose(); super.dispose(); }
  void _go() {
    if (target != null) return;
    target = widget.spin(); Sfx.play('whoosh');
    a.addListener(() { final seg = (_angle() / (math.pi * 2 / 8)).floor().toDouble(); if (seg != _lastTick) { _lastTick = seg; Sfx.play('tick', volume: 0.3); } });
    a.forward().whenComplete(() { setState(() => result = widget.apply(target!)); Sfx.play('level'); Sfx.haptic(40); });
    setState(() {});
  }
  double _angle() {
    if (target == null) return 0;
    final end = math.pi * 2 * 5 + (math.pi * 2) - (target! + 0.5) * (math.pi * 2 / 8);
    return Curves.easeOutCubic.transform(a.value) * end;
  }
  @override
  Widget build(BuildContext context) => GameModal(
        title: 'Roleta do dia', color: K.purple,
        actions: [result == null ? GBtn(color: K.green, enabled: target == null, pulse: target == null, onTap: _go, child: Text('Girar!', style: display(20))) : GBtn(color: K.green, onTap: widget.onClose, child: Text('Pegar', style: display(19)))],
        child: Column(children: [
          SizedBox(width: 250, height: 260, child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(animation: a, builder: (_, __) => Transform.rotate(angle: _angle(), child: CustomPaint(size: const Size(240, 240), painter: _WheelPainter()))),
            Positioned(top: 0, child: Transform.rotate(angle: math.pi, child: const Ico('up', size: 40))),
            Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: K.navy, width: 3))),
          ])),
          if (result != null) Text(result!, textAlign: TextAlign.center, style: body(22, color: K.goldD, w: FontWeight.w900)),
        ]),
      );
}

class _WheelPainter extends CustomPainter {
  static const cols = [Color(0xFFFF5A5F), Color(0xFFFFC531), Color(0xFF3E8BFF), Color(0xFF3FD46B), Color(0xFF8F62F8), Color(0xFFFF9F1C), Color(0xFF17B3A3), Color(0xFFFF6FB5)];
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2, ctr = Offset(r, r), seg = math.pi * 2 / 8;
    for (var i = 0; i < 8; i++) {
      c.drawArc(Rect.fromCircle(center: ctr, radius: r), -math.pi / 2 + i * seg, seg, true, Paint()..color = cols[i]);
      final p = wheelPrizes[i];
      final ic = p.$1 == 'coins' ? 'coin' : p.$1 == 'gems' ? 'gem' : p.$1 == 'boost' ? 'bolt' : p.$1;
      final img = Art.icons['icon_$ic'];
      final a = -math.pi / 2 + (i + 0.5) * seg, at = ctr + Offset(math.cos(a), math.sin(a)) * r * 0.66;
      if (img != null) c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: at, width: 46, height: 46), Paint()..filterQuality = FilterQuality.medium);
    }
    c.drawCircle(ctr, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = K.navy);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
