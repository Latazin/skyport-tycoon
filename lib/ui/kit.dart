import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../game/art.dart';

/// Identidade visual: limpa e moderna (painéis brancos, cantos redondos, sombras suaves).
class K {
  static const ink = Color(0xFF1F2A44);
  static const navy = ink;
  static const navy2 = Color(0xFF3B4A6B);
  static const muted = Color(0xFF8590A6);
  static const line = Color(0xFFE7EBF3);
  static const surface = Color(0xFFF4F6FB);
  static const track = Color(0xFFE6EAF2);
  static const cream = surface;
  static const cream2 = line;
  static const green = Color(0xFF1DB66E);
  static const greenD = Color(0xFF128A52);
  static const greenL = Color(0xFFE5F8EE);
  static const gold = Color(0xFFFFB627);
  static const goldD = Color(0xFFD98E00);
  static const goldL = Color(0xFFFFF5DD);
  static const blue = Color(0xFF2F6BFF);
  static const blueL = Color(0xFFE8EFFF);
  static const purple = Color(0xFF7C5CFA);
  static const purpleL = Color(0xFFF0ECFF);
  static const red = Color(0xFFFF4D5E);
  static const redL = Color(0xFFFFECEE);
  static const orange = Color(0xFFFF8A1F);
  static const teal = Color(0xFF14B8A6);
  static const grey = Color(0xFFB8C0D0);
  static const shadow = [BoxShadow(color: Color(0x1A1F2A44), blurRadius: 14, offset: Offset(0, 4))];
  static const shadowS = [BoxShadow(color: Color(0x161F2A44), blurRadius: 6, offset: Offset(0, 2))];
}

/// Texto de destaque (branco com sombra leve) para botões e faixas coloridas.
TextStyle display(double size, {Color color = Colors.white, bool outline = true}) => TextStyle(
      fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: size, color: color, height: 1.1, letterSpacing: 0.2,
      shadows: outline && color == Colors.white ? [Shadow(color: const Color(0x40000000), offset: Offset(0, size * 0.06), blurRadius: size * 0.1)] : null,
    );
/// Texto de leitura.
TextStyle body(double size, {Color color = K.ink, FontWeight w = FontWeight.w800}) =>
    TextStyle(fontFamily: 'Fredoka', fontSize: size, color: color, fontWeight: w == FontWeight.w900 ? FontWeight.w700 : w == FontWeight.w800 ? FontWeight.w600 : FontWeight.w500, height: 1.22);

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

/// Botão plano e redondo: cor sólida, leve borda inferior e mola ao apertar.
class GBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final bool enabled, pulse;
  /// Segurar o botão repete o toque cada vez mais rápido (até não dar mais).
  final bool repeat;
  final double radius;
  final EdgeInsets padding;
  const GBtn({super.key, required this.child, this.onTap, this.color = K.green, this.enabled = true, this.radius = 16, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10), this.pulse = false, this.repeat = false});
  @override
  State<GBtn> createState() => _GBtnState();
}

class _GBtnState extends State<GBtn> with SingleTickerProviderStateMixin {
  bool down = false;
  late final AnimationController pc = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  @override
  void initState() { super.initState(); if (widget.pulse) pc.repeat(); }
  @override
  void didUpdateWidget(covariant GBtn old) { super.didUpdateWidget(old); if (widget.pulse && !pc.isAnimating) { pc.repeat(); } else if (!widget.pulse && pc.isAnimating) { pc.stop(); pc.value = 0; } }
  Timer? _rep;
  int _reps = 0;
  void _holdStart() {
    if (!widget.repeat) return;
    _reps = 0;
    void fire() {
      if (!mounted || !widget.enabled || widget.onTap == null) { _holdEnd(); return; }
      widget.onTap!(); _reps++;
      if (_reps % 3 == 0) Sfx.haptic(8);
      _rep = Timer(Duration(milliseconds: _reps < 4 ? 170 : _reps < 12 ? 100 : _reps < 30 ? 60 : 35), fire);
    }
    setState(() => down = true);
    fire();
  }
  void _holdEnd() { _rep?.cancel(); _rep = null; if (mounted && down) setState(() => down = false); }
  @override
  void dispose() { _rep?.cancel(); pc.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final on = widget.enabled && widget.onTap != null;
    final base = on ? widget.color : const Color(0xFFC9D0DD);
    final edge = Color.lerp(base, Colors.black, 0.18)!;
    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border(bottom: BorderSide(color: edge, width: down ? 1.5 : 3.5)),
        boxShadow: on && !down ? [BoxShadow(color: base.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))] : null,
      ),
      child: DefaultTextStyle.merge(style: display(17), child: IconTheme(data: const IconThemeData(color: Colors.white), child: Center(widthFactor: 1, heightFactor: 1, child: widget.child))),
    );
    Widget btn = AnimatedScale(scale: down ? 0.96 : 1, duration: const Duration(milliseconds: 90), child: face);
    if (widget.pulse && on) {
      // brilho suave em volta em vez de pulsar o tamanho
      btn = AnimatedBuilder(
        animation: pc,
        builder: (_, c) {
          final k = (1 - (pc.value * 2 - 1).abs());
          return DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.radius + 4), boxShadow: [BoxShadow(color: base.withValues(alpha: 0.45 * k), blurRadius: 4 + 14 * k, spreadRadius: 1 + 3 * k)]), child: c);
        },
        child: btn,
      );
    }
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) => setState(() => down = false),
      onTap: () { if (on) { Sfx.click(); widget.onTap!(); } else { Sfx.play('nope'); Sfx.haptic(); } },
      onLongPressStart: widget.repeat ? (_) => _holdStart() : null,
      onLongPressEnd: widget.repeat ? (_) => _holdEnd() : null,
      onLongPressCancel: widget.repeat ? _holdEnd : null,
      child: btn,
    );
  }
}

/// Painel que sobe do rodapé: branco, alça no topo, cabeçalho limpo.
class Sheet extends StatelessWidget {
  final String title;
  final String icon;
  final Color color;
  final Widget child;
  final VoidCallback onClose;
  final String? subtitle;
  const Sheet({super.key, required this.title, required this.icon, required this.color, required this.child, required this.onClose, this.subtitle});
  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      constraints: BoxConstraints(maxHeight: h * 0.62, maxWidth: 560),
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
      decoration: BoxDecoration(color: K.surface, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x331F2A44), blurRadius: 30, offset: Offset(0, -6))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: K.surface,
          child: DefaultTextStyle(
            style: body(14),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 12),
                child: Column(children: [
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.all(5), child: Ico(icon, size: 36)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: body(21, w: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (subtitle != null) Text(subtitle!, style: body(12.5, color: K.muted, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    CloseBtn(onTap: onClose),
                  ]),
                ]),
              ),
              Container(height: 1, color: K.line),
              Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 16), child: child)),
            ]),
          ),
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
          width: 38, height: 38,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: K.surface),
          child: const Icon(Icons.close_rounded, color: K.muted, size: 22),
        ),
      );
}

/// Cartão branco dos painéis.
class GCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final Color? border;
  const GCard({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(12), this.border});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: padding,
        decoration: BoxDecoration(color: color ?? Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: border ?? K.line, width: border != null ? 1.6 : 1), boxShadow: K.shadowS),
        child: child,
      );
}

/// Barra de progresso fina e arredondada.
class GBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  final String? label;
  final Color track;
  const GBar({super.key, required this.value, this.color = K.green, this.height = 10, this.label, this.track = K.track});
  @override
  Widget build(BuildContext context) {
    final bar = Container(
      height: height,
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
      child: Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(
        widthFactor: value.isNaN ? 0 : value.clamp(0.0, 1.0).toDouble(),
        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
      )),
    );
    if (label == null) return bar;
    return Row(children: [
      Expanded(child: bar),
      const SizedBox(width: 8),
      Text(label!, style: body(12, color: K.muted, w: FontWeight.w900)),
    ]);
  }
}

/// Linha de informação (rótulo à esquerda, valor à direita).
class InfoRow extends StatelessWidget {
  final String label, value;
  final String? next;
  const InfoRow(this.label, this.value, {super.key, this.next});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: body(14, color: K.muted, w: FontWeight.w700))),
          Text(value, style: body(15, w: FontWeight.w900)),
          if (next != null) ...[
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: K.greenL, borderRadius: BorderRadius.circular(8)), child: Text(next!, style: body(13, color: K.greenD, w: FontWeight.w900))),
          ],
        ]),
      );
}

/// Preço com ícone (a cor do texto vem do contexto: branco em botões, escuro em cartões).
class Price extends StatelessWidget {
  final String text;
  final String icon;
  final double size;
  final Color? color;
  const Price(this.text, {super.key, this.icon = 'coin', this.size = 16, this.color});
  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final c = color ?? base.color ?? K.ink;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Ico(icon, size: size + 6),
      const SizedBox(width: 2),
      Text(text, style: c == Colors.white ? display(size) : body(size, color: c, w: FontWeight.w900)),
    ]);
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text(text.toUpperCase(), style: body(11.5, color: K.muted, w: FontWeight.w900).copyWith(letterSpacing: 1.2)));
}

/// Etiqueta pequena colorida.
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: body(10.5, color: color, w: FontWeight.w900)),
      );
}

/// Quadradinho com ícone sobre fundo tingido.
class IcoBox extends StatelessWidget {
  final String icon;
  final Color color;
  final double size;
  final double opacity;
  const IcoBox(this.icon, {super.key, this.color = K.blue, this.size = 48, this.opacity = 1});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(size * 0.3)),
        padding: EdgeInsets.all(size * 0.1),
        child: Opacity(opacity: opacity, child: Ico(icon, size: size * 0.8)),
      );
}
