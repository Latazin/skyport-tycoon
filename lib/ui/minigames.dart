import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/audio.dart';
import 'kit.dart';

/// Resultado de um minijogo: estrelas (0..3) e texto.
class GameResult {
  final int stars;
  final String text;
  const GameResult(this.stars, this.text);
}

Widget _stars(int n, double size) => Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 3; i++)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Opacity(opacity: i < n ? 1 : 0.25, child: Ico('star', size: i == 1 ? size * 1.25 : size))),
    ]);

/// Tela de resultado comum.
class _ResultCard extends StatelessWidget {
  final GameResult r;
  final String reward;
  final VoidCallback onOk;
  const _ResultCard({required this.r, required this.reward, required this.onOk});
  @override
  Widget build(BuildContext context) => Center(child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.5, end: 1), duration: const Duration(milliseconds: 500), curve: Curves.elasticOut,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: Container(
          margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: K.cream, borderRadius: BorderRadius.circular(28), border: Border.all(color: K.navy, width: 4)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _stars(r.stars, 46),
            const SizedBox(height: 10),
            Text(r.text, textAlign: TextAlign.center, style: display(26, color: r.stars > 0 ? K.gold : K.red)),
            const SizedBox(height: 8),
            Text(reward, textAlign: TextAlign.center, style: body(16)),
            const SizedBox(height: 14),
            GBtn(color: K.green, onTap: onOk, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12), child: Text('PEGAR', style: display(22))),
          ]),
        ),
      ));
}

// =====================================================================
// POUSO PERFEITO
// =====================================================================
class LandingGame extends StatefulWidget {
  final String Function(int stars) rewardText;
  const LandingGame({super.key, required this.rewardText});
  @override
  State<LandingGame> createState() => _LandingGameState();
}

class _LandingGameState extends State<LandingGame> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  Duration last = Duration.zero;
  double x = 0, y = 230, vy = -2, t = 0, gust = 0;
  bool hold = false, started = false;
  GameResult? res;
  static const rwStart = 1500.0, rwEnd = 2150.0, tzEnd = 1760.0, vx = 165.0;
  final r = math.Random();

  @override
  void initState() {
    super.initState();
    tk = createTicker((d) {
      final dt = ((d - last).inMicroseconds / 1e6).clamp(0.0, 0.05); last = d;
      if (!started || res != null) { setState(() {}); return; }
      _step(dt); setState(() {});
    })..start();
  }
  @override
  void dispose() { tk.dispose(); super.dispose(); }

  void _step(double dt) {
    t += dt;
    gust = math.sin(t * 1.3) * 3 + math.sin(t * 3.7) * 1.5;
    vy += (hold ? 26 : -16) * dt + gust * dt;
    vy = vy.clamp(-28.0, 10.0).toDouble();
    x += vx * dt; y += vy * dt * 3;
    if (y > 320) { y = 320; vy = math.min(vy, 0.0); }
    if (y <= 0) {
      y = 0;
      final speed = vy;
      if (x < rwStart) { _end(const GameResult(0, 'Pousou antes da pista!')); }
      else if (x > rwEnd - 120) { _end(const GameResult(0, 'Passou da pista!')); }
      else if (speed < -15) { _end(const GameResult(1, 'Pouso duro...')); }
      else if (speed < -8 || x > tzEnd) { _end(const GameResult(2, 'Bom pouso!')); }
      else { _end(const GameResult(3, 'POUSO PERFEITO!')); }
    }
    if (x > rwEnd) _end(const GameResult(0, 'Arremeteu: passou da pista!'));
  }
  void _end(GameResult g) { res = g; Sfx.play(g.stars >= 2 ? 'level' : g.stars == 1 ? 'pop' : 'nope'); Sfx.haptic(40); }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    return Scaffold(
      body: Listener(
        onPointerDown: (_) { if (!started) { started = true; Sfx.play('jet', volume: 0.4); } hold = true; },
        onPointerUp: (_) => hold = false,
        onPointerCancel: (_) => hold = false,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _LandPainter(this))),
          Positioned(top: pad.top + 12, left: 16, right: 16, child: Column(children: [
            Text('POUSO PERFEITO', style: display(30)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xCC1E2A47), borderRadius: BorderRadius.circular(16)),
              child: Text(started ? 'Velocidade vertical: ${(vy * 60).round()} pés/min' : 'Segure o dedo na tela para levantar o nariz. Solte para descer. Encoste devagar na faixa verde da pista!', textAlign: TextAlign.center, style: body(15, color: Colors.white)),
            ),
          ])),
          if (!started) Center(child: Text('TOQUE PARA COMEÇAR', style: display(28))),
          if (res != null) Positioned.fill(child: Container(color: const Color(0x88000000), child: _ResultCard(r: res!, reward: widget.rewardText(res!.stars), onOk: () => Navigator.of(context).pop(res)))),
          Positioned(top: pad.top + 6, right: 8, child: CloseBtn(onTap: () => Navigator.of(context).pop(const GameResult(0, '')))),
        ]),
      ),
    );
  }
}

class _LandPainter extends CustomPainter {
  final _LandingGameState g;
  _LandPainter(this.g);
  @override
  void paint(Canvas c, Size s) {
    final groundY = s.height * 0.78;
    final camX = g.x - s.width * 0.3;
    // céu e sol
    c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, groundY), [const Color(0xFF5FB7FF), const Color(0xFFCDEBFF)]));
    c.drawCircle(Offset(s.width * 0.8, s.height * 0.16), 40, Paint()..color = const Color(0xFFFFF1A8));
    // nuvens com paralaxe
    final cp = Paint()..color = const Color(0xDDFFFFFF);
    for (var i = 0; i < 9; i++) {
      final cx = ((i * 380.0 - camX * 0.4) % (s.width + 400)) - 200, cy = s.height * (0.18 + (i % 3) * 0.1);
      for (var k = 0; k < 3; k++) { c.drawCircle(Offset(cx + k * 34, cy + (k == 1 ? -14 : 0)), 26 + (k == 1 ? 10 : 0), cp); }
    }
    // morros
    final hp = Paint()..color = const Color(0xFF8CCF6A);
    for (var i = -1; i < 8; i++) { final hx = i * 300.0 - (camX * 0.6) % 300; c.drawOval(Rect.fromCenter(center: Offset(hx, groundY + 10), width: 420, height: 160), hp); }
    // chão
    c.drawRect(Rect.fromLTWH(0, groundY, s.width, s.height - groundY), Paint()..color = const Color(0xFF6FB352));
    // pista
    final rs = LandingRuler.toScreen(_LandingGameState.rwStart, camX), re = LandingRuler.toScreen(_LandingGameState.rwEnd, camX), tz = LandingRuler.toScreen(_LandingGameState.tzEnd, camX);
    c.drawRect(Rect.fromLTRB(rs, groundY - 4, re, groundY + 22), Paint()..color = const Color(0xFF4C5160));
    c.drawRect(Rect.fromLTRB(rs + 40, groundY - 5, tz, groundY + 2), Paint()..color = const Color(0xCC3FD46B));
    for (var x = rs + 10; x < re - 30; x += 60) { c.drawRect(Rect.fromLTWH(x, groundY + 7, 30, 4), Paint()..color = Colors.white); }
    // luzes de aproximação
    for (var i = 1; i < 9; i++) { final lx = rs - i * 40; c.drawCircle(Offset(lx, groundY - 6), 5, Paint()..color = (DateTime.now().millisecondsSinceEpoch ~/ 90) % 9 == 9 - i ? Colors.white : const Color(0xFFFFE27A)); }
    // indicador de rampa (PAPI): branco = alto, vermelho = baixo
    if (g.x < _LandingGameState.rwStart) {
      final dist = (_LandingGameState.rwStart + 80 - g.x).clamp(1.0, 4000.0);
      final ang = math.atan2(g.y, dist) * 180 / math.pi;
      for (var k = 0; k < 4; k++) {
        final th = [5.2, 4.2, 3.2, 2.2][k];
        c.drawCircle(Offset(rs + 60 + k * 16, groundY - 26), 6, Paint()..color = ang > th ? Colors.white : const Color(0xFFFF4E4E));
      }
    }
    // avião (vista lateral)
    final px = s.width * 0.3, py = groundY - 18 - g.y * 1.0;
    final pitch = (g.vy / 40).clamp(-0.25, 0.25) * -1 + (g.hold ? -0.08 : 0.04);
    c.drawOval(Rect.fromCenter(center: Offset(px, groundY + 4), width: 120 * (1 - g.y / 500), height: 10), Paint()..color = const Color(0x33000000));
    c.save(); c.translate(px, py); c.rotate(pitch);
    final body = Paint()..color = Colors.white, blue = Paint()..color = const Color(0xFF2F6BFF), dark = Paint()..color = const Color(0xFF26324F);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-70, -14, 140, 28), const Radius.circular(14)), body);
    c.drawPath(Path()..moveTo(-60, -10)..lineTo(-78, -42)..lineTo(-62, -42)..lineTo(-36, -12)..close(), blue);
    c.drawRect(const Rect.fromLTWH(-60, 0, 120, 4), Paint()..color = const Color(0xFFFFC928));
    for (var i = 0; i < 9; i++) { c.drawCircle(Offset(-40 + i * 11.0, -4), 2.6, dark); }
    c.drawPath(Path()..moveTo(52, -8)..lineTo(66, -8)..lineTo(64, -2)..lineTo(50, -2)..close(), dark);
    c.drawPath(Path()..moveTo(-10, 4)..lineTo(-34, 22)..lineTo(-20, 22)..lineTo(14, 4)..close(), Paint()..color = const Color(0xFFDFE6F0));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-24, 8, 26, 10), const Radius.circular(5)), Paint()..color = const Color(0xFFD7DDE8));
    if (g.y < 90) { c.drawLine(const Offset(-6, 14), const Offset(-6, 26), dark..strokeWidth = 3); c.drawCircle(const Offset(-6, 28), 5, dark); c.drawLine(const Offset(46, 14), const Offset(46, 24), dark); c.drawCircle(const Offset(46, 26), 4, dark); }
    c.restore();
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LandingRuler { static double toScreen(double x, double camX) => x - camX; }

// =====================================================================
// RAIO-X
// =====================================================================
class _Bag {
  double x;
  final double y;
  final List<String> items;
  final bool bad;
  final Color color;
  double hit = 0; bool done = false, ok = false;
  _Bag(this.x, this.y, this.items, this.bad, this.color);
}

class XrayGame extends StatefulWidget {
  final String Function(int stars) rewardText;
  const XrayGame({super.key, required this.rewardText});
  @override
  State<XrayGame> createState() => _XrayGameState();
}

class _XrayGameState extends State<XrayGame> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  Duration last = Duration.zero;
  final r = math.Random();
  final List<_Bag> bags = [];
  double t = 0, spawn = 0;
  int score = 0, miss = 0;
  bool started = false;
  GameResult? res;
  static const dur = 25.0;
  static const safe = ['👕', '📚', '🎧', '📷', '🧸', '👟', '🍫', '💻', '🕶️', '🧴'];
  static const bad = ['🔪', '✂️', '🧨', '🔫'];
  static const colors = [Color(0xFFFF4E4E), Color(0xFF2F7BFF), Color(0xFF2EC27E), Color(0xFFFFC928), Color(0xFF8B5CF6), Color(0xFFFF8A1F)];

  @override
  void initState() {
    super.initState();
    tk = createTicker((d) {
      final dt = ((d - last).inMicroseconds / 1e6).clamp(0.0, 0.05); last = d;
      if (started && res == null) _step(dt);
      setState(() {});
    })..start();
  }
  @override
  void dispose() { tk.dispose(); super.dispose(); }

  double get speed => 150 + t * 7;
  void _step(double dt) {
    t += dt; spawn -= dt;
    final w = MediaQuery.of(context).size.width;
    if (spawn <= 0 && t < dur - 1.5) {
      spawn = math.max(0.55, 1.15 - t * 0.022);
      final isBad = r.nextDouble() < 0.38;
      final n = 2 + r.nextInt(2);
      final items = [for (var i = 0; i < n; i++) safe[r.nextInt(safe.length)]];
      if (isBad) items[r.nextInt(n)] = bad[r.nextInt(bad.length)];
      bags.add(_Bag(-120.0, r.nextBool() ? 0.0 : 1.0, items, isBad, colors[r.nextInt(colors.length)]));
    }
    for (final b in [...bags]) {
      b.x += speed * dt;
      if (b.hit > 0) b.hit += dt;
      if (b.hit > 0.5) bags.remove(b);
      if (b.x > w + 40 && !b.done) { b.done = true; if (b.bad) { miss++; Sfx.play('alert'); } bags.remove(b); }
    }
    if (t >= dur) {
      final st = score >= 11 ? 3 : score >= 7 ? 2 : score >= 3 ? 1 : 0;
      res = GameResult(st, st == 3 ? 'SEGURANÇA MÁXIMA!' : st > 0 ? '$score itens apreendidos' : 'Muitos itens passaram...');
      Sfx.play(st >= 2 ? 'level' : 'pop');
    }
  }
  void _tap(Offset p, double laneY0, double laneH) {
    if (!started || res != null) return;
    for (final b in bags.reversed) {
      if (b.done) continue;
      final rect = Rect.fromLTWH(b.x, laneY0 + b.y * laneH + 6, 116, laneH - 12);
      if (rect.inflate(8).contains(p)) {
        b.done = true; b.hit = 0.01;
        if (b.bad) { b.ok = true; score++; Sfx.play('coin', rate: 1 + score * 0.04); Sfx.haptic(); }
        else { b.ok = false; score = math.max(0, score - 1); Sfx.play('nope'); Sfx.haptic(30); }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding, sz = MediaQuery.of(context).size;
    final laneH = 120.0, laneY0 = sz.height * 0.5 - laneH;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1A33),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) { if (!started) { started = true; return; } _tap(d.localPosition, laneY0, laneH); },
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _XrayPainter(laneY0, laneH))),
          for (final b in bags) Positioned(
            left: b.x, top: laneY0 + b.y * laneH + 6,
            child: Opacity(opacity: b.hit > 0 ? (1 - b.hit * 2).clamp(0.0, 1.0).toDouble() : 1.0, child: Transform.scale(scale: b.hit > 0 ? 1 + b.hit : 1.0, child: Container(
              width: 116, height: laneH - 12,
              decoration: BoxDecoration(color: const Color(0xFF16305C), borderRadius: BorderRadius.circular(16), border: Border.all(color: b.hit > 0 ? (b.ok ? K.green : K.red) : b.color.withValues(alpha: 0.9), width: 4)),
              child: Stack(alignment: Alignment.center, children: [
                Wrap(alignment: WrapAlignment.center, spacing: 2, children: [for (final it in b.items) Text(it, style: const TextStyle(fontSize: 30))]),
                if (b.hit > 0) Text(b.ok ? 'APREENDIDO!' : 'ERRADO', style: display(16, color: b.ok ? K.green : K.red)),
              ]),
            ))),
          ),
          Positioned(top: pad.top + 12, left: 16, right: 16, child: Column(children: [
            Text('RAIO-X', style: display(32)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xCC1E2A47), borderRadius: BorderRadius.circular(16)),
              child: Text('Toque nas malas com itens proibidos (🔪 ✂️ 🧨 🔫). Não toque nas malas comuns!', textAlign: TextAlign.center, style: body(15, color: Colors.white)),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Apreendidos: $score', style: display(20)), const SizedBox(width: 18),
              Text('Tempo: ${math.max(0, dur - t).ceil()}s', style: display(20, color: t > dur - 6 ? K.red : Colors.white)),
            ]),
          ])),
          if (!started) Positioned(left: 0, right: 0, bottom: sz.height * 0.22, child: Center(child: Text('TOQUE PARA COMEÇAR', style: display(28)))),
          if (res != null) Positioned.fill(child: Container(color: const Color(0x88000000), child: _ResultCard(r: res!, reward: widget.rewardText(res!.stars), onOk: () => Navigator.of(context).pop(res)))),
          Positioned(top: pad.top + 6, right: 8, child: CloseBtn(onTap: () => Navigator.of(context).pop(const GameResult(0, '')))),
        ]),
      ),
    );
  }
}

class _XrayPainter extends CustomPainter {
  final double y0, h;
  _XrayPainter(this.y0, this.h);
  @override
  void paint(Canvas c, Size s) {
    for (var i = 0; i < 2; i++) {
      final r = Rect.fromLTWH(0, y0 + i * h, s.width, h);
      c.drawRect(r, Paint()..color = const Color(0xFF1B2333));
      for (var x = 0.0; x < s.width; x += 22) { c.drawLine(Offset(x, r.top + 2), Offset(x, r.top + 6), Paint()..color = const Color(0xFF2E3A52)..strokeWidth = 2); }
    }
    // máquina de raio-X sobre a esteira
    final m = Rect.fromLTWH(s.width * 0.32, y0 - 30, s.width * 0.36, h * 2 + 60);
    c.drawRRect(RRect.fromRectAndRadius(m, const Radius.circular(18)), Paint()..color = const Color(0x558B5CF6));
    c.drawRRect(RRect.fromRectAndRadius(m, const Radius.circular(18)), Paint()..style = PaintingStyle.stroke..strokeWidth = 5..color = const Color(0xFF8B5CF6));
    c.drawRect(Rect.fromLTWH(m.left, y0 - 30, m.width, 26), Paint()..color = const Color(0xFFFFC928));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
