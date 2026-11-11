import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/audio.dart';
import '../game/art.dart';
import 'kit.dart';

/// Moedas e gemas voando da cena até o contador do HUD.
class FlyItem {
  Offset from, ctrl, to;
  double t, dur;
  final bool gem;
  final double value;
  final int idx;
  FlyItem(this.from, this.ctrl, this.to, this.t, this.dur, this.gem, this.value, this.idx);
}

class FlyController extends ChangeNotifier {
  final List<FlyItem> items = [];
  final _r = math.Random();
  void Function(bool gem, double value)? onArrive;
  void launch(Offset from, Offset to, int n, double total, {bool gem = false}) {
    for (var i = 0; i < n; i++) {
      final f = from + Offset(_r.nextDouble() * 40 - 20, _r.nextDouble() * 30 - 15);
      items.add(FlyItem(f, f + Offset(_r.nextDouble() * 180 - 90, -60 - _r.nextDouble() * 140), to, -i * 0.045, 0.6 + _r.nextDouble() * 0.25, gem, total / n, i));
    }
  }
  void tick(double dt) {
    if (items.isEmpty) return;
    for (final it in [...items]) {
      it.t += dt;
      if (it.t >= it.dur) { items.remove(it); onArrive?.call(it.gem, it.value); Sfx.play('tick', rate: 1 + math.min(it.idx, 16) * 0.06, volume: 0.35); }
    }
    notifyListeners();
  }
}

class FlyLayer extends StatefulWidget {
  final FlyController c;
  const FlyLayer({super.key, required this.c});
  @override
  State<FlyLayer> createState() => _FlyLayerState();
}

class _FlyLayerState extends State<FlyLayer> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  Duration last = Duration.zero;
  @override
  void initState() { super.initState(); tk = createTicker((d) { final dt = (d - last).inMicroseconds / 1e6; last = d; widget.c.tick(dt.clamp(0, 0.1)); })..start(); }
  @override
  void dispose() { tk.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _FlyPainter(widget.c), size: Size.infinite));
}

class _FlyPainter extends CustomPainter {
  final FlyController c;
  _FlyPainter(this.c) : super(repaint: c);
  @override
  void paint(Canvas canvas, Size size) {
    final coin = Art.icons['icon_coin'], gem = Art.icons['icon_gem'];
    for (final it in c.items) {
      if (it.t < 0) continue;
      final k = (it.t / it.dur).clamp(0.0, 1.0), e = k * k;
      final p = Offset.lerp(Offset.lerp(it.from, it.ctrl, e)!, Offset.lerp(it.ctrl, it.to, e)!, e)!;
      final img = it.gem ? gem : coin, s = 34.0 * (1 - k * 0.3);
      if (img != null) canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: p, width: s, height: s), Paint()..filterQuality = FilterQuality.medium);
    }
  }
  @override
  bool shouldRepaint(covariant _FlyPainter old) => true;
}

/// Faixa comemorativa no meio da tela (NÍVEL!, NOVA VAGA!, ...).
class BannerView extends StatefulWidget {
  final String title, sub;
  final VoidCallback onDone;
  const BannerView({super.key, required this.title, required this.sub, required this.onDone});
  @override
  State<BannerView> createState() => _BannerViewState();
}

class _BannerViewState extends State<BannerView> with TickerProviderStateMixin {
  late final AnimationController a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))..forward().whenComplete(widget.onDone);
  late final AnimationController spin = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  @override
  void dispose() { a.dispose(); spin.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: a,
          builder: (_, __) {
            final t = a.value, inK = Curves.elasticOut.transform((t / 0.25).clamp(0.0, 1.0)), out = t > 0.82 ? 1 - (t - 0.82) / 0.18 : 1.0;
            return Opacity(
              opacity: out.clamp(0.0, 1.0),
              child: Center(
                child: Transform.scale(
                  scale: 0.4 + 0.6 * inK,
                  child: Stack(alignment: Alignment.center, children: [
                    RotationTransition(turns: spin, child: CustomPaint(size: const Size(460, 460), painter: _Rays())),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(widget.title, textAlign: TextAlign.center, style: display(46, color: const Color(0xFFFFE27A))),
                      if (widget.sub.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                          decoration: BoxDecoration(color: K.navy, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFE27A), width: 2.5)),
                          child: Text(widget.sub, textAlign: TextAlign.center, style: display(18)),
                        ),
                      ],
                    ]),
                  ]),
                ),
              ),
            );
          },
        ),
      );
}

class _Rays extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2);
    final p = Paint()..shader = ui.Gradient.radial(ctr, s.width / 2, [const Color(0x99FFE27A), const Color(0x00FFE27A)]);
    for (var i = 0; i < 18; i++) {
      final a = i / 18 * math.pi * 2;
      final path = Path()..moveTo(ctr.dx, ctr.dy)..lineTo(ctr.dx + math.cos(a - 0.09) * s.width / 2, ctr.dy + math.sin(a - 0.09) * s.width / 2)..lineTo(ctr.dx + math.cos(a + 0.09) * s.width / 2, ctr.dy + math.sin(a + 0.09) * s.width / 2)..close();
      c.drawPath(path, p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Confete em tela cheia.
class ConfettiController extends ChangeNotifier {
  final List<List<double>> bits = []; // x,y,vx,vy,rot,vr,life,colorIdx,size
  final _r = math.Random();
  void burst(Size s, int n) {
    for (var i = 0; i < n; i++) {
      bits.add([s.width / 2 + (_r.nextDouble() - 0.5) * 120, s.height * 0.32, (_r.nextDouble() - 0.5) * 900, -300 - _r.nextDouble() * 600, _r.nextDouble() * 6, (_r.nextDouble() - 0.5) * 14, 0, _r.nextInt(7).toDouble(), 7 + _r.nextDouble() * 7]);
    }
  }
  void tick(double dt) {
    if (bits.isEmpty) return;
    for (final b in [...bits]) { b[6] += dt; b[3] += 900 * dt; b[2] *= 0.985; b[0] += b[2] * dt; b[1] += b[3] * dt; b[4] += b[5] * dt; if (b[6] > 2.6) bits.remove(b); }
    notifyListeners();
  }
}

class ConfettiLayer extends StatefulWidget {
  final ConfettiController c;
  const ConfettiLayer({super.key, required this.c});
  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  Duration last = Duration.zero;
  @override
  void initState() { super.initState(); tk = createTicker((d) { final dt = (d - last).inMicroseconds / 1e6; last = d; widget.c.tick(dt.clamp(0, 0.1)); })..start(); }
  @override
  void dispose() { tk.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _ConfPainter(widget.c), size: Size.infinite));
}

class _ConfPainter extends CustomPainter {
  final ConfettiController c;
  _ConfPainter(this.c) : super(repaint: c);
  static const cols = [Color(0xFFFF5A5F), Color(0xFFFFC531), Color(0xFF3FD46B), Color(0xFF3E8BFF), Color(0xFF8F62F8), Color(0xFFFF6FB5), Colors.white];
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (final b in c.bits) {
      p.color = cols[b[7].toInt()].withValues(alpha: (1 - (b[6] - 1.8).clamp(0.0, 0.8) / 0.8));
      canvas.save(); canvas.translate(b[0], b[1]); canvas.rotate(b[4]); canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: b[8], height: b[8] * 0.55), p); canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant _ConfPainter old) => true;
}
