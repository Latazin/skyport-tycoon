import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../game/art.dart';

/// Identidade visual da interface: cores, fontes e componentes de jogo.
class K {
  static const navy = Color(0xFF1E2A47);
  static const navy2 = Color(0xFF2C3F6E);
  static const cream = Color(0xFFFFF6E4);
  static const cream2 = Color(0xFFF3E3C2);
  static const ink = Color(0xFF26324F);
  static const muted = Color(0xFF7A7F95);
  static const green = Color(0xFF3FD46B);
  static const greenD = Color(0xFF1F9B48);
  static const gold = Color(0xFFFFC531);
  static const goldD = Color(0xFFE09400);
  static const blue = Color(0xFF3E8BFF);
  static const purple = Color(0xFF8F62F8);
  static const red = Color(0xFFFF5A5F);
  static const orange = Color(0xFFFF9F1C);
  static const teal = Color(0xFF17B3A3);
  static const grey = Color(0xFFA9B2C6);
}

/// Contorno (8 direções, sem desfoque para não pesar) + sombra projetada, como nos jogos casuais.
List<Shadow> outlineShadows(double size, {Color color = K.navy}) {
  final r = (size * 0.075).clamp(1.4, 4.0).toDouble();
  return [
    for (var i = 0; i < 8; i++) Shadow(color: color, offset: Offset(r * math.cos(i * math.pi / 4), r * math.sin(i * math.pi / 4))),
    Shadow(color: color, offset: Offset(0, r * 1.8)),
  ];
}
TextStyle display(double size, {Color color = Colors.white, bool outline = true}) => TextStyle(
      fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: size, color: color, height: 1.08, letterSpacing: 0.2,
      shadows: outline ? outlineShadows(size) : null,
    );
TextStyle body(double size, {Color color = K.ink, FontWeight w = FontWeight.w800}) =>
    TextStyle(fontFamily: 'Fredoka', fontSize: size, color: color, fontWeight: w == FontWeight.w900 ? FontWeight.w700 : w == FontWeight.w800 ? FontWeight.w600 : FontWeight.w500, height: 1.2);

/// Ícone 3D renderizado.
class Ico extends StatelessWidget {
  final String name;
  final double size;
  const Ico(this.name, {super.key, this.size = 32});
  @override
  Widget build(BuildContext context) {
    final img = Art.icons['icon_$name'];
    if (img == null) return SizedBox(width: size, height: size);
    return SizedBox(width: size, height: size, child: RawImage(image: img, fit: BoxFit.contain, filterQuality: FilterQuality.medium));
  }
}

/// Botão com volume: base escura, face com gradiente, brilho e mola ao apertar.
class GBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final bool enabled, pulse;
  final double radius;
  final EdgeInsets padding;
  const GBtn({super.key, required this.child, this.onTap, this.color = K.green, this.enabled = true, this.radius = 18, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10), this.pulse = false});
  @override
  State<GBtn> createState() => _GBtnState();
}

class _GBtnState extends State<GBtn> with SingleTickerProviderStateMixin {
  bool down = false;
  late final AnimationController pc = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() { pc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && widget.onTap != null;
    final base = on ? widget.color : K.grey;
    final dark = Color.lerp(base, Colors.black, 0.35)!, light = Color.lerp(base, Colors.white, 0.32)!;
    Widget btn = AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      margin: EdgeInsets.only(top: down ? 4 : 0),
      decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(widget.radius), border: Border.all(color: K.navy, width: 3), boxShadow: [if (!down) const BoxShadow(color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 4)]),
      padding: EdgeInsets.only(bottom: down ? 1 : 5),
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [light, base, Color.lerp(base, Colors.black, 0.08)!], stops: const [0, 0.55, 1]), borderRadius: BorderRadius.circular(widget.radius - 3)),
        child: Stack(alignment: Alignment.center, children: [
          Positioned(top: 0, left: 6, right: 6, child: Container(height: 6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(6)))),
          DefaultTextStyle(style: display(17), child: widget.child),
        ]),
      ),
    );
    if (widget.pulse && on) {
      btn = AnimatedBuilder(animation: pc, builder: (_, c) => Transform.scale(scale: 1 + pc.value * 0.06, child: c), child: btn);
    }
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: () { if (on) { Sfx.click(); widget.onTap!(); } else { Sfx.play('nope'); Sfx.haptic(); } },
      child: btn,
    );
  }
}

/// Painel inferior (sobe do rodapé e deixa o hospital visível em cima).
class Sheet extends StatelessWidget {
  final String title;
  final String icon;
  final Color color;
  final Widget child;
  final VoidCallback onClose;
  const Sheet({super.key, required this.title, required this.icon, required this.color, required this.child, required this.onClose});
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.6, maxWidth: 560),
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(color: K.navy, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, -4))]),
      padding: const EdgeInsets.all(3.5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [K.cream, Color(0xFFFBEBCB)])),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.25)!, color, Color.lerp(color, Colors.black, 0.15)!]),
                border: const Border(bottom: BorderSide(color: K.navy, width: 3.5)),
              ),
              child: Row(children: [
                Ico(icon, size: 46),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: display(26), maxLines: 1, overflow: TextOverflow.ellipsis)),
                CloseBtn(onTap: onClose),
              ]),
            ),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 16), child: child)),
          ]),
        ),
      ),
    );
  }
}

class CloseBtn extends StatelessWidget {
  final VoidCallback onTap;
  const CloseBtn({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () { Sfx.click(); onTap(); },
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: K.navy, width: 3), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF9EA2), Color(0xFFE8343B)]), boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 3))]),
          child: CustomPaint(painter: _XPainter()),
        ),
      );
}

class _XPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = Colors.white..strokeWidth = 5..strokeCap = StrokeCap.round;
    final o = Paint()..color = K.navy..strokeWidth = 8..strokeCap = StrokeCap.round;
    final a = s.width * 0.32, b = s.width * 0.68;
    for (final paint in [o, p]) { c.drawLine(Offset(a, a), Offset(b, b), paint); c.drawLine(Offset(b, a), Offset(a, b), paint); }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cartão de conteúdo dos painéis.
class GCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  const GCard({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(12)});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: const Color(0xFFD9C79F), borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(color: color ?? Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8D9B8), width: 2)),
          child: child,
        ),
      );
}

/// Barra de progresso com contorno e brilho.
class GBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  final String? label;
  const GBar({super.key, required this.value, this.color = K.green, this.height = 18, this.label});
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(color: const Color(0xFF3B4566), borderRadius: BorderRadius.circular(height), border: Border.all(color: K.navy, width: 2.5)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(children: [
            FractionallySizedBox(widthFactor: value.clamp(0.0, 1.0).toDouble(), child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.4)!, color, Color.lerp(color, Colors.black, 0.12)!])))),
            Positioned(top: 2, left: 6, right: 6, child: Container(height: height * 0.22, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(9)))),
            if (label != null) Center(child: Text(label!, style: display(height * 0.62))),
          ]),
        ),
      );
}

/// Linha de informação (rótulo à esquerda, valor à direita).
class InfoRow extends StatelessWidget {
  final String label, value;
  final String? next;
  const InfoRow(this.label, this.value, {super.key, this.next});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: body(14, color: K.muted, w: FontWeight.w700))),
          Text(value, style: body(15, w: FontWeight.w900)),
          if (next != null) ...[const SizedBox(width: 6), Text(next!, style: body(14, color: K.greenD, w: FontWeight.w900))],
        ]),
      );
}

/// Preço com ícone (moeda ou gema).
class Price extends StatelessWidget {
  final String text;
  final String icon;
  final double size;
  const Price(this.text, {super.key, this.icon = 'coin', this.size = 16});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Ico(icon, size: size + 6), const SizedBox(width: 2), Text(text, style: display(size))]);
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 8), child: Text(text.toUpperCase(), style: body(12, color: const Color(0xFF9C8A62), w: FontWeight.w900).copyWith(letterSpacing: 1.4)));
}
