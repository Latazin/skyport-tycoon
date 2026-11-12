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
  final void Function(bool triple) onClaim;
  const OfflineModal({super.key, required this.secs, required this.amount, required this.gems, required this.onClaim});
  @override
  Widget build(BuildContext context) => GameModal(
        title: 'Bem-vindo de volta!', icon: 'cash', color: K.green,
        actions: [
          GBtn(color: K.blue, onTap: () => onClaim(false), child: Text('Pegar', style: display(18))),
          GBtn(color: K.purple, enabled: gems >= 15, onTap: () => onClaim(true), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('Pegar x3  ', style: display(18)), const Price('15', icon: 'gem', size: 16)])),
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
  late final AnimationController shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  late final AnimationController reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  Loot? loot;
  @override
  void dispose() { shake.dispose(); reveal.dispose(); super.dispose(); }
  void _open() { if (loot != null) return; Sfx.play('gift'); Sfx.haptic(40); setState(() => loot = widget.open()); reveal.forward(); }
  @override
  Widget build(BuildContext context) {
    final gold = widget.type == 'chest_gold';
    final l = loot;
    return GameModal(
      title: gold ? 'Baú de ouro!' : 'Baú!', color: gold ? K.goldD : K.orange,
      actions: [if (l != null) GBtn(color: K.green, onTap: widget.onDone, child: Text(widget.left > 0 ? 'Próximo (${widget.left})' : 'Pegar', style: display(19)))],
      child: l == null
          ? GestureDetector(onTap: _open, child: Column(children: [
              AnimatedBuilder(animation: shake, builder: (_, c) => Transform.rotate(angle: math.sin(shake.value * math.pi * 2) * 0.08, child: Transform.scale(scale: 1 + shake.value * 0.06, child: c)), child: Ico(widget.type, size: 140)),
              const SizedBox(height: 6),
              Text('Toque para abrir', style: body(18, color: K.muted, w: FontWeight.w900)),
            ]))
          : AnimatedBuilder(animation: reveal, builder: (_, __) {
              double k(int i) => Curves.elasticOut.transform(((reveal.value - i * 0.08) / 0.5).clamp(0.0, 1.0));
              return Column(children: [
                Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 6, children: [
                  Transform.scale(scale: k(0), child: Price('\$${fmt(l.coins)}', size: 18)),
                  Transform.scale(scale: k(1), child: Price('${l.gems}', icon: 'gem', size: 18)),
                  Transform.scale(scale: k(2), child: Price(fmt(l.miles), icon: 'miles', size: 18)),
                ]),
                const SizedBox(height: 10),
                Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i < l.cards.length; i++) Transform.scale(scale: k(3 + i), child: _card(l.cards[i], l.fresh.contains(l.cards[i]))),
                ]),
              ]);
            }),
    );
  }
  Widget _card(String id, bool fresh) {
    final m = modelById(id);
    const cols = [Color(0xFF8A93A6), Color(0xFF3E8BFF), Color(0xFF8F62F8), Color(0xFFFFB020)];
    return Container(
      width: 74, padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: cols[m.rarity].withValues(alpha: 0.6), width: 2), boxShadow: K.shadowS),
      child: Column(children: [
        Text(fresh ? 'NOVO!' : rarityNames[m.rarity], style: body(9, color: fresh ? K.red : cols[m.rarity], w: FontWeight.w900)),
        Container(width: 62, height: 46, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: cols[m.rarity].withValues(alpha: 0.12)), child: Ico('pm_${m.tier}_${m.liv}', size: 46)),
        Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(9, w: FontWeight.w900)),
      ]),
    );
  }
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
