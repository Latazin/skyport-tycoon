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
        tween: Tween(begin: 0.85, end: 1), duration: const Duration(milliseconds: 380), curve: Curves.easeOutBack,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: Container(
          margin: const EdgeInsets.all(24), padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _stars(r.stars, 46),
            const SizedBox(height: 12),
            Text(r.text, textAlign: TextAlign.center, style: body(24, color: r.stars > 0 ? K.ink : K.red, w: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(reward, textAlign: TextAlign.center, style: body(15, color: K.muted)),
            const SizedBox(height: 16),
            GBtn(color: K.green, onTap: onOk, padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 12), child: Text('Pegar', style: display(20))),
          ]),
        ),
      ));
}

/// Cartão "pronto para começar" comum a todos os minijogos.
class _StartCard extends StatelessWidget {
  const _StartCard();
  @override
  Widget build(BuildContext context) => Center(child: IgnorePointer(child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1), duration: const Duration(milliseconds: 420), curve: Curves.easeOutBack,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: Container(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _stars(3, 34),
            const SizedBox(height: 8),
            Text('Valendo até 3 estrelas', style: body(15, color: K.muted)),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11), decoration: BoxDecoration(color: K.green, borderRadius: BorderRadius.circular(16)), child: Text('Toque para começar', style: display(19))),
          ]),
        ),
      )));
}

/// Cabeçalho comum dos minijogos.
Widget _gameHead(EdgeInsets pad, String title, String help, List<Widget> stats) => Positioned(top: pad.top + 12, left: 16, right: 60, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: display(26)),
      const SizedBox(height: 4),
      Text(help, style: body(13.5, color: Colors.white.withValues(alpha: 0.85))),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: stats),
    ]));
Widget _pill(String t, [Color c = Colors.white]) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)), child: Text(t, style: body(15, color: c, w: FontWeight.w900)));

// =====================================================================
// POUSO PERFEITO
// =====================================================================
class LandingGame extends StatefulWidget {
  final String Function(int stars) rewardText;
  final int level;
  const LandingGame({super.key, required this.rewardText, this.level = 0});
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
    gust = (math.sin(t * 1.3) * 3 + math.sin(t * 3.7) * 1.5) * (1 + widget.level * 0.6);
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
            Text(widget.level == 0 ? 'Pouso Perfeito' : 'Pouso Perfeito · nível ${widget.level + 1}', style: display(widget.level == 0 ? 30 : 24)),
            if (widget.level > 0) Text(widget.level >= 2 ? 'Noite e vento forte!' : 'Vento lateral!', style: display(16, color: K.gold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xCC1E2A47), borderRadius: BorderRadius.circular(16)),
              child: Text(started ? 'Velocidade vertical: ${(vy * 60).round()} pés/min' : 'Segure o dedo na tela para levantar o nariz. Solte para descer. Encoste devagar na faixa verde da pista!', textAlign: TextAlign.center, style: body(15, color: Colors.white)),
            ),
          ])),
          if (!started) const _StartCard(),
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
    final night = g.widget.level >= 2;
    c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, groundY), night ? [const Color(0xFF0E1A40), const Color(0xFF3A4C8A)] : [const Color(0xFF5FB7FF), const Color(0xFFCDEBFF)]));
    c.drawCircle(Offset(s.width * 0.8, s.height * 0.16), 40, Paint()..color = night ? const Color(0xFFF4F1D0) : const Color(0xFFFFF1A8));
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
  int score = 0, miss = 0, lives = 3, combo = 0;
  bool started = false;
  GameResult? res;
  static const dur = 35.0;
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
      final isBad = r.nextDouble() < 0.4;
      final n = 2 + r.nextInt(2);
      final items = [for (var i = 0; i < n; i++) safe[r.nextInt(safe.length)]];
      if (isBad) items[r.nextInt(n)] = bad[r.nextInt(bad.length)];
      bags.add(_Bag(-120.0, r.nextBool() ? 0.0 : 1.0, items, isBad, colors[r.nextInt(colors.length)]));
    }
    for (final b in [...bags]) {
      b.x += speed * dt;
      if (b.hit > 0) b.hit += dt;
      if (b.hit > 0.5) bags.remove(b);
      if (b.x > w + 40 && !b.done) { b.done = true; if (b.bad) { miss++; _hurt(); Sfx.play('alert'); } bags.remove(b); }
    }
    if (t >= dur || lives <= 0) _end();
  }
  void _hurt() { lives--; combo = 0; Sfx.haptic(60); }
  void _end() {
    if (res != null) return;
    final st = lives <= 0 ? (score >= 8 ? 1 : 0) : score >= 15 ? 3 : score >= 9 ? 2 : score >= 4 ? 1 : 0;
    res = GameResult(st, lives <= 0 ? 'Itens perigosos passaram!' : st == 3 ? 'SEGURANÇA MÁXIMA!' : st > 0 ? '$score itens apreendidos' : 'Muitos itens passaram...');
    Sfx.play(st >= 2 ? 'level' : 'pop');
  }
  void _tap(Offset p, double laneY0, double laneH) {
    if (!started || res != null) return;
    for (final b in bags.reversed) {
      if (b.done) continue;
      final rect = Rect.fromLTWH(b.x, laneY0 + b.y * laneH + 6, 116, laneH - 12);
      if (rect.inflate(8).contains(p)) {
        b.done = true; b.hit = 0.01;
        if (b.bad) { b.ok = true; score++; combo++; Sfx.play('coin', rate: 1 + math.min(combo, 12) * 0.04); Sfx.haptic(); }
        else { b.ok = false; _hurt(); Sfx.play('nope'); }
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
                if (b.hit > 0 || (b.x + 58 > sz.width * 0.32 && b.x + 58 < sz.width * 0.68)) Wrap(alignment: WrapAlignment.center, spacing: 2, children: [for (final it in b.items) Text(it, style: const TextStyle(fontSize: 30))])
                else Icon(Icons.luggage_rounded, color: b.color, size: 54),
                if (b.hit > 0) Text(b.ok ? 'APREENDIDO!' : 'ERRADO', style: display(16, color: b.ok ? K.green : K.red)),
              ]),
            ))),
          ),
          Positioned(top: pad.top + 12, left: 16, right: 16, child: Column(children: [
            Text('Raio-X', style: display(28)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xCC1E2A47), borderRadius: BorderRadius.circular(16)),
              child: Text('O conteúdo só aparece dentro do raio-X! Toque nas malas com itens proibidos (🔪 ✂️ 🧨 🔫). Errou ou deixou passar: perde uma vida.', textAlign: TextAlign.center, style: body(14.5, color: Colors.white)),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _pill('Apreendidos: $score'), const SizedBox(width: 10),
              _pill('${math.max(0, dur - t).ceil()}s', t > dur - 6 ? const Color(0xFFFFC9CE) : Colors.white), const SizedBox(width: 10),
              _lives(lives, 3),
            ]),
          ])),
          if (!started) Positioned(left: 0, right: 0, bottom: sz.height * 0.22, child: const _StartCard()),
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


// =====================================================================
// ESTEIRA DE BAGAGEM: várias malas na esteira; arraste cada uma para o
// avião da mesma cor antes que ela caia no fim da esteira.
// =====================================================================
class _Mala {
  double x;
  final int c;
  final bool gold;
  _Mala(this.x, this.c, this.gold);
}

class BagGame extends StatefulWidget {
  final String Function(int stars) rewardText;
  const BagGame({super.key, required this.rewardText});
  @override
  State<BagGame> createState() => _BagGameState();
}

class _BagGameState extends State<BagGame> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  Duration last = Duration.zero;
  final r = math.Random();
  static const cols = [Color(0xFFFF4E4E), Color(0xFF2F7BFF), Color(0xFF3FD46B), Color(0xFFFFB020)];
  static const names = ['VERMELHO', 'AZUL', 'VERDE', 'AMARELO'];
  static const dur = 40.0;
  final List<_Mala> malas = [];
  _Mala? held;
  Offset hp = Offset.zero;
  double t = 0, spawn = 0.3, flashT = 0;
  int score = 0, streak = 0, lives = 3;
  bool started = false;
  String flash = '';
  GameResult? res;
  @override
  void initState() { super.initState(); tk = createTicker((d) { final dt = ((d - last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble(); last = d; if (started && res == null) _step(dt); setState(() {}); })..start(); }
  @override
  void dispose() { tk.dispose(); super.dispose(); }
  int get nCols => t > 14 ? 4 : 3;
  double get speed => 70 + t * 2.6;
  void _step(double dt) {
    t += dt; flashT -= dt; spawn -= dt;
    final w = MediaQuery.of(context).size.width;
    if (spawn <= 0 && t < dur - 2) {
      spawn = math.max(0.75, 1.9 - t * 0.03) + r.nextDouble() * 0.4;
      malas.add(_Mala(-90, r.nextInt(nCols), r.nextDouble() < 0.08));
    }
    for (final m in [...malas]) {
      if (identical(m, held)) continue;
      m.x += speed * dt;
      if (m.x > w + 10) { malas.remove(m); _hurt('Mala caiu da esteira!'); }
    }
    if (t >= dur || lives <= 0) _end();
  }
  void _hurt(String why) { lives--; streak = 0; flash = why; flashT = 0.9; Sfx.play('nope'); Sfx.haptic(40); }
  void _end() {
    if (res != null) return;
    final st = lives <= 0 ? (score >= 12 ? 1 : 0) : score >= 26 ? 3 : score >= 16 ? 2 : score >= 7 ? 1 : 0;
    res = GameResult(st, lives <= 0 ? 'Muitas malas perdidas!' : st == 3 ? 'BAGAGEM PERFEITA!' : '$score malas no lugar certo');
    Sfx.play(st >= 2 ? 'level' : 'pop');
  }
  double beltY(Size sz) => sz.height * 0.34;
  void _drop(Size sz) {
    final m = held; held = null;
    if (m == null) return;
    final n = nCols;
    if (hp.dy > sz.height * 0.6) {
      final lane = (hp.dx / sz.width * n).floor().clamp(0, n - 1);
      malas.remove(m);
      if (m.gold || lane == m.c) {
        final pts = m.gold ? 3 : 1;
        score += pts; streak++;
        flash = m.gold ? 'MALA DOURADA +3!' : streak >= 4 ? 'COMBO x$streak!' : 'Certo!'; flashT = 0.7;
        Sfx.play(m.gold ? 'gift' : 'coin', rate: 1 + math.min(streak, 10) * 0.05); Sfx.haptic();
      } else {
        _hurt('Avião errado!');
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding, sz = MediaQuery.of(context).size;
    final by = beltY(sz), n = nCols;
    return Scaffold(
      backgroundColor: const Color(0xFF2B3245),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) { if (!started) started = true; },
        onPanStart: (d) {
          if (!started) { started = true; return; }
          if (res != null) return;
          for (final m in malas.reversed) { if ((d.localPosition - Offset(m.x + 40, by)).distance < 62) { held = m; hp = d.localPosition; Sfx.play('tick'); break; } }
        },
        onPanUpdate: (d) { if (held != null) hp = d.localPosition; },
        onPanEnd: (_) => _drop(sz),
        child: Stack(children: [
          // esteira
          Positioned(left: 0, right: 0, top: by - 46, height: 92, child: CustomPaint(painter: _BeltPainter(t * speed))),
          // aviões (destinos)
          for (var i = 0; i < n; i++) Positioned(left: i * sz.width / n + 6, width: sz.width / n - 12, bottom: pad.bottom + 24, height: sz.height * 0.3, child: Container(
            decoration: BoxDecoration(color: cols[i].withValues(alpha: 0.22), borderRadius: BorderRadius.circular(22), border: Border.all(color: cols[i], width: 5)),
            alignment: Alignment.bottomCenter, padding: const EdgeInsets.only(bottom: 10),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [const Ico('plane', size: 48), FittedBox(child: Text(names[i], style: display(13)))]),
          )),
          for (final m in malas) () {
            final h = identical(m, held);
            final o = h ? hp - const Offset(40, 36) : Offset(m.x, by - 36);
            return Positioned(left: o.dx, top: o.dy, child: IgnorePointer(child: Transform.scale(scale: h ? 1.15 : 1, child: Container(
              width: 80, height: 72,
              decoration: BoxDecoration(
                gradient: m.gold ? const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFFFB020)]) : null,
                color: m.gold ? null : cols[m.c],
                borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1E2A47), width: 4),
                boxShadow: [BoxShadow(color: const Color(0x66000000), offset: Offset(0, h ? 12 : 5), blurRadius: h ? 12 : 4)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 30, height: 8, decoration: BoxDecoration(color: const Color(0xFF1E2A47), borderRadius: BorderRadius.circular(4))), const SizedBox(height: 6), Text(m.gold ? '★' : 'MALA', style: display(m.gold ? 22 : 14))]),
            ))));
          }(),
          Positioned(top: pad.top + 12, left: 16, right: 16, child: Column(children: [
            Text('Esteira de Bagagem', style: display(26)),
            const SizedBox(height: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: const Color(0xCC1E2A47), borderRadius: BorderRadius.circular(16)), child: Text('Arraste cada mala para o avião da mesma cor antes que ela caia. Mala dourada vale 3 em qualquer avião!', textAlign: TextAlign.center, style: body(14.5, color: Colors.white))),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [_pill('Malas: $score'), const SizedBox(width: 8), _pill('${math.max(0, dur - t).ceil()}s', t > dur - 6 ? const Color(0xFFFFC9CE) : Colors.white), const SizedBox(width: 8), _lives(lives, 3)]),
          ])),
          if (flashT > 0) Positioned(top: by + 56, left: 0, right: 0, child: Center(child: Text(flash, style: display(24, color: flash.startsWith('Certo') ? K.green : flash.contains('+3') || flash.startsWith('COMBO') ? K.gold : const Color(0xFFFF8A95))))),
          if (!started) const _StartCard(),
          if (res != null) Positioned.fill(child: Container(color: const Color(0x88000000), child: _ResultCard(r: res!, reward: widget.rewardText(res!.stars), onOk: () => Navigator.of(context).pop(res)))),
          Positioned(top: pad.top + 6, right: 8, child: CloseBtn(onTap: () => Navigator.of(context).pop(const GameResult(0, '')))),
        ]),
      ),
    );
  }
}

class _BeltPainter extends CustomPainter {
  final double off;
  _BeltPainter(this.off);
  @override
  void paint(Canvas c, Size s) {
    c.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(12)), Paint()..color = const Color(0xFF1B2333));
    final p = Paint()..color = const Color(0xFF39445C)..strokeWidth = 4;
    for (var x = -(off % 36); x < s.width; x += 36) { c.drawLine(Offset(x, 8), Offset(x, s.height - 8), p); }
    c.drawRect(Rect.fromLTWH(0, 0, s.width, 6), Paint()..color = const Color(0xFFFFC928));
    c.drawRect(Rect.fromLTWH(0, s.height - 6, s.width, 6), Paint()..color = const Color(0xFFFFC928));
  }
  @override
  bool shouldRepaint(covariant _BeltPainter o) => o.off != off;
}

// =====================================================================
// TORRE DE CONTROLE: os aviões vêm de todos os lados até a pista.
// Toque para segurar (espera em círculo) ou liberar. Um pouso por vez,
// não deixe dois aviões se encostarem e cuide do combustível.
// =====================================================================
class _Arr {
  Offset p;
  double speed, fuel, land = -1, hold = 0, holdA = 0;
  bool holding = false;
  final int c;
  _Arr(this.p, this.speed, this.fuel, this.c);
}

Widget _lives(int n, int max) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < max; i++) Icon(i < n ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: i < n ? const Color(0xFFFF5A6E) : Colors.white38, size: 18)]),
    );

class AtcGame extends StatefulWidget {
  final String Function(int stars) rewardText;
  const AtcGame({super.key, required this.rewardText});
  @override
  State<AtcGame> createState() => _AtcGameState();
}

class _AtcGameState extends State<AtcGame> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  Duration last = Duration.zero;
  final r = math.Random();
  static const dur = 50.0;
  static const cols = [Color(0xFF2F6BFF), Color(0xFFFF7A1A), Color(0xFF18B48D), Color(0xFF8B5CF6), Color(0xFFE8A31B)];
  final List<_Arr> planes = [];
  final List<(Offset, double)> booms = [];
  double t = 0, spawn = 0.6, flashT = 0, busyT = 0, shake = 0;
  int landed = 0, lives = 3, combo = 0;
  bool started = false;
  String flash = '';
  GameResult? res;
  Size sz = Size.zero;
  @override
  void initState() { super.initState(); tk = createTicker((d) { final dt = ((d - last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble(); last = d; if (started && res == null) _step(dt); setState(() {}); })..start(); }
  @override
  void dispose() { tk.dispose(); super.dispose(); }

  Offset get rwA => Offset(sz.width * 0.2, sz.height * 0.62);
  Offset get rwB => Offset(sz.width * 0.8, sz.height * 0.62);
  Offset get gate => rwA - const Offset(34, 0);

  void _lose(String why) {
    lives--; combo = 0; flash = why; flashT = 1.2; shake = 0.35; Sfx.play('nope'); Sfx.haptic(60);
    if (lives <= 0) _finish();
  }
  void _finish() {
    if (res != null) return;
    final st = landed >= 16 && lives >= 2 ? 3 : landed >= 10 ? 2 : landed >= 5 ? 1 : 0;
    res = GameResult(st, st == 3 ? 'Torre impecável!' : lives <= 0 ? 'Torre fechada! $landed pousos' : '$landed pousos seguros');
    Sfx.play(st >= 2 ? 'level' : 'pop');
  }
  void _spawn() {
    // nasce numa borda (nunca na pista) e voa até a cabeceira
    final side = r.nextInt(3);
    final p = switch (side) {
      0 => Offset(r.nextDouble() * sz.width, sz.height * 0.2),
      1 => Offset(sz.width + 20, sz.height * (0.25 + r.nextDouble() * 0.6)),
      _ => Offset(r.nextDouble() * sz.width, sz.height + 20),
    };
    final sp = 46 + math.min(40.0, t * 0.9) + r.nextDouble() * 14;
    planes.add(_Arr(p, sp, 16 + r.nextDouble() * 8, r.nextInt(cols.length)));
  }
  void _step(double dt) {
    t += dt; flashT -= dt; spawn -= dt; busyT = math.max(0, busyT - dt); shake = math.max(0, shake - dt);
    for (final b in [...booms]) { booms[booms.indexOf(b)] = (b.$1, b.$2 + dt); }
    booms.removeWhere((b) => b.$2 > 0.7);
    if (spawn <= 0 && t < dur - 3) { spawn = math.max(1.1, 3.0 - t * 0.04) + r.nextDouble() * 0.8; _spawn(); }
    for (final p in [...planes]) {
      if (p.land >= 0) { p.land += dt / 1.6; if (p.land >= 1) planes.remove(p); continue; }
      p.fuel -= dt * (p.holding ? 1.6 : 1);
      if (p.fuel <= 0) { planes.remove(p); booms.add((p.p, 0)); _lose('Sem combustível!'); continue; }
      if (p.holding) {
        p.holdA += dt * 2.4;
        p.p += Offset(math.cos(p.holdA), math.sin(p.holdA)) * 38 * dt;
        continue;
      }
      final d = gate - p.p;
      final dist = d.distance;
      if (dist < 10) {
        if (busyT > 0) { planes.remove(p); _lose('Pista ocupada: arremeteu!'); continue; }
        p.land = 0; busyT = 1.6; landed++; combo++;
        Sfx.play('coin', rate: 1 + math.min(combo, 10) * 0.05); Sfx.haptic();
        if (combo >= 3) { flash = 'Sequência x$combo!'; flashT = 0.7; }
        continue;
      }
      p.p += d / dist * p.speed * dt;
    }
    // quase-colisão: dois aviões voando muito perto
    final fly = planes.where((p) => p.land < 0).toList();
    for (var i = 0; i < fly.length; i++) {
      for (var j = i + 1; j < fly.length; j++) {
        if ((fly[i].p - fly[j].p).distance < 30) {
          planes.remove(fly[i]); planes.remove(fly[j]);
          booms.add(((fly[i].p + fly[j].p) / 2, 0));
          _lose('Quase colisão!');
          return;
        }
      }
    }
    if (t >= dur) _finish();
  }
  void _tap(Offset at) {
    _Arr? best; var bd = 48.0;
    for (final p in planes) { if (p.land >= 0) continue; final dd = (p.p - at).distance; if (dd < bd) { bd = dd; best = p; } }
    if (best == null) return;
    best.holding = !best.holding;
    best.holdA = math.atan2(best.p.dy - gate.dy, best.p.dx - gate.dx) + math.pi / 2;
    Sfx.play(best.holding ? 'tick' : 'ding'); Sfx.haptic();
  }
  Offset _posOf(_Arr p) {
    if (p.land < 0) return p.p;
    return Offset.lerp(rwA, rwB, Curves.easeOut.transform(p.land))!;
  }
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    sz = MediaQuery.of(context).size;
    final sx = shake > 0 ? math.sin(t * 90) * 8 * shake / 0.35 : 0.0;
    return Scaffold(
      backgroundColor: const Color(0xFF15304F),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) { if (!started) { started = true; return; } if (res != null) return; _tap(d.localPosition); },
        child: Stack(children: [
          Positioned.fill(child: Transform.translate(offset: Offset(sx, 0), child: CustomPaint(painter: _RadarPainter(rwA, rwB, gate, busyT > 0, t, [for (final p in planes) if (p.land < 0 && !p.holding) p.p])))),
          for (final b in booms) Positioned(left: b.$1.dx - 40, top: b.$1.dy - 40, child: IgnorePointer(child: Opacity(opacity: (1 - b.$2 / 0.7).clamp(0.0, 1.0), child: Transform.scale(scale: 0.6 + b.$2 * 2, child: Container(width: 80, height: 80, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFFFE27A), Color(0xFFFF5A3C), Color(0x00FF5A3C)]))))))),
          for (final p in planes) () {
            final o = _posOf(p);
            final ang = p.land >= 0 ? math.pi / 2 : p.holding ? p.holdA + math.pi / 2 : math.atan2(gate.dy - o.dy, gate.dx - o.dx) + math.pi / 2;
            final low = p.fuel < 5 && p.land < 0;
            return Positioned(left: o.dx - 26, top: o.dy - 26, child: IgnorePointer(child: SizedBox(width: 52, height: 52, child: Stack(alignment: Alignment.center, children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: (low ? K.red : cols[p.c]).withValues(alpha: p.holding ? 0.12 : 0.28), border: Border.all(color: low && (t * 4).floor().isEven ? Colors.white : (low ? K.red : cols[p.c]), width: p.holding ? 2 : 3))),
              Transform.rotate(angle: ang, child: Icon(Icons.flight_rounded, color: Colors.white, size: p.land >= 0 ? 26 : 30)),
              if (p.holding) Positioned(top: -2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(color: const Color(0xFFFFC928), borderRadius: BorderRadius.circular(6)), child: Text('ESPERA', style: body(9, color: K.ink, w: FontWeight.w900)))),
              if (p.land < 0) Positioned(bottom: 0, left: 8, right: 8, child: Container(height: 5, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(3)), alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: (p.fuel / 22).clamp(0.0, 1.0), child: Container(decoration: BoxDecoration(color: low ? K.red : K.green, borderRadius: BorderRadius.circular(3)))))),
            ]))));
          }(),
          _gameHead(pad, 'Torre de Controle', 'Os aviões vêm direto para a pista. Toque para SEGURAR (círculo) e toque de novo para LIBERAR. Um pouso por vez e nada de aviões encostando!', [_pill('Pousos: $landed'), _pill('${math.max(0, dur - t).ceil()}s', t > dur - 8 ? const Color(0xFFFFC9CE) : Colors.white), _lives(lives, 3)]),
          if (flashT > 0) Positioned(top: sz.height * 0.8, left: 0, right: 0, child: Center(child: _pill(flash, flash.startsWith('Seq') ? const Color(0xFFFFE27A) : const Color(0xFFFFC9CE)))),
          if (!started) const _StartCard(),
          if (res != null) Positioned.fill(child: Container(color: const Color(0x88000000), child: _ResultCard(r: res!, reward: widget.rewardText(res!.stars), onOk: () => Navigator.of(context).pop(res)))),
          Positioned(top: pad.top + 6, right: 8, child: CloseBtn(onTap: () => Navigator.of(context).pop(const GameResult(0, '')))),
        ]),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Offset a, b, gate;
  final bool busy;
  final double t;
  final List<Offset> flying;
  _RadarPainter(this.a, this.b, this.gate, this.busy, this.t, this.flying);
  @override
  void paint(Canvas cv, Size z) {
    final c = Offset(z.width / 2, z.height * 0.55);
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = const Color(0x2284C5FF);
    for (var k = 1; k <= 5; k++) { cv.drawCircle(c, z.width * 0.15 * k, ring); }
    // varredura do radar
    final sweep = t * 1.6;
    cv.drawArc(Rect.fromCircle(center: c, radius: z.width * 0.9), sweep, 0.5, true, Paint()..shader = SweepGradient(startAngle: sweep, endAngle: sweep + 0.5, colors: const [Color(0x0044FF99), Color(0x2244FF99)]).createShader(Rect.fromCircle(center: c, radius: z.width * 0.9)));
    // rotas até a cabeceira
    for (final p in flying) {
      final path = Path()..moveTo(p.dx, p.dy)..lineTo(gate.dx, gate.dy);
      cv.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0x55FFFFFF));
    }
    final rw = RRect.fromRectAndRadius(Rect.fromPoints(a - const Offset(0, 16), b + const Offset(0, 16)), const Radius.circular(6));
    cv.drawRRect(rw, Paint()..color = const Color(0xFF3B4558));
    for (var x = a.dx + 10; x < b.dx - 10; x += 24) { cv.drawLine(Offset(x, a.dy), Offset(x + 12, a.dy), Paint()..color = Colors.white70..strokeWidth = 2.5); }
    cv.drawRRect(rw, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = busy ? const Color(0xFFFF4D5E) : const Color(0xFF1DB66E));
    cv.drawCircle(gate, 9, Paint()..color = busy ? const Color(0xFFFF4D5E) : const Color(0xFF1DB66E));
  }
  @override
  bool shouldRepaint(covariant _RadarPainter o) => true;
}

// =====================================================================
// PÁTIO: mande cada avião para o portão da cor certa
// =====================================================================
class YardGame extends StatefulWidget {
  final String Function(int stars) rewardText;
  const YardGame({super.key, required this.rewardText});
  @override
  State<YardGame> createState() => _YardGameState();
}

class _YardGameState extends State<YardGame> with SingleTickerProviderStateMixin {
  late final Ticker tk;
  Duration last = Duration.zero;
  final r = math.Random();
  static const dur = 45.0;
  static const cols = [Color(0xFF2F6BFF), Color(0xFFFF7A1A), Color(0xFF18B48D), Color(0xFF8B5CF6)];
  final List<int> queue = [];
  final List<double> busy = [0, 0, 0, 0], ready = [-1, -1, -1, -1];
  double t = 0, spawn = 0.2, flashT = 0, patience = 7;
  int score = 0, miss = 0, lives = 3;
  bool started = false;
  String flash = '';
  GameResult? res;
  @override
  void initState() { super.initState(); tk = createTicker((d) { final dt = ((d - last).inMicroseconds / 1e6).clamp(0.0, 0.05).toDouble(); last = d; if (started && res == null) _step(dt); setState(() {}); })..start(); }
  @override
  void dispose() { tk.dispose(); super.dispose(); }
  void _step(double dt) {
    t += dt; flashT -= dt; spawn -= dt;
    for (var i = 0; i < 4; i++) {
      if (busy[i] > 0) { busy[i] -= dt; if (busy[i] <= 0) { busy[i] = 0; ready[i] = 0; Sfx.play('ding'); } }
      if (ready[i] >= 0) { ready[i] += dt; if (ready[i] > 5) { ready[i] = -1; _hurt('Decolagem atrasada!'); } }
    }
    if (queue.isNotEmpty) { patience -= dt; if (patience <= 0) { queue.removeAt(0); patience = _pat; _hurt('Avião cansou de esperar!'); } }
    if (spawn <= 0) {
      spawn = math.max(1.0, 2.4 - t * 0.03);
      if (queue.length >= 5) { _hurt('Fila cheia: voo desviado!'); } else { if (queue.isEmpty) patience = _pat; queue.add(r.nextInt(4)); }
    }
    if (t >= dur || lives <= 0) {
      final st = lives <= 0 ? (score >= 14 ? 1 : 0) : score >= 30 ? 3 : score >= 20 ? 2 : score >= 10 ? 1 : 0;
      res = GameResult(st, lives <= 0 ? 'Pátio travou!' : st == 3 ? 'Pátio perfeito!' : '$score operações'); Sfx.play(st >= 2 ? 'level' : 'pop');
    }
  }
  double get _pat => math.max(3.2, 7 - t * 0.08);
  void _hurt(String why) { lives--; miss++; flash = why; flashT = 1; Sfx.play('nope'); Sfx.haptic(40); }
  void _gate(int i) {
    if (!started) { started = true; return; }
    if (res != null) return;
    // avião pronto: toque para empurrar e liberar a decolagem
    if (ready[i] >= 0) { ready[i] = -1; score++; flash = 'Decolou!'; flashT = 0.5; Sfx.play('whoosh'); Sfx.haptic(); return; }
    if (queue.isEmpty) return;
    if (busy[i] > 0) { flash = 'Portão ocupado!'; flashT = 0.8; Sfx.play('nope'); Sfx.haptic(20); return; }
    final c = queue.first;
    if (c != i) { queue.removeAt(0); patience = _pat; _hurt('Portão errado!'); return; }
    queue.removeAt(0); patience = _pat; busy[i] = 3.0 + r.nextDouble() * 2.5; score++; Sfx.play('coin', rate: 1 + math.min(score, 20) * 0.03); Sfx.haptic();
  }
  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding, sz = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF3A4A5E),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) { if (!started) started = true; },
        child: Stack(children: [
          // fila de aviões chegando
          Positioned(left: 16, right: 16, top: sz.height * 0.3, child: Container(
            height: 86, padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFF2B3546), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              for (var k = 0; k < queue.length; k++) AnimatedContainer(
                duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 8),
                width: k == 0 ? 70 : 52, height: k == 0 ? 70 : 52,
                decoration: BoxDecoration(shape: BoxShape.circle, color: cols[queue[k]], border: k == 0 ? Border.all(color: Colors.white, width: 3) : null),
                child: Transform.rotate(angle: math.pi / 2, child: Icon(Icons.flight_rounded, color: Colors.white, size: k == 0 ? 40 : 30)),
              ),
              if (queue.isEmpty) Expanded(child: Center(child: Text('Aguardando aviões...', style: body(14, color: Colors.white70)))),
            ]),
          )),
          Positioned(left: 16, right: 16, top: sz.height * 0.3 + 92, child: Row(children: [
            Expanded(child: Text('Próximo avião ↑  ·  toque no portão da mesma cor', style: body(12.5, color: Colors.white70))),
            if (queue.isNotEmpty) SizedBox(width: 70, child: LinearProgressIndicator(value: (patience / _pat).clamp(0.0, 1.0), color: patience < 2 ? K.red : K.gold, backgroundColor: Colors.white24, minHeight: 6)),
          ])),
          // portões
          Positioned(left: 12, right: 12, bottom: pad.bottom + 24, height: sz.height * 0.34, child: Row(children: [
            for (var i = 0; i < 4; i++) Expanded(child: GestureDetector(
              onTap: () => _gate(i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(color: ready[i] >= 0 ? const Color(0x5522C55E) : cols[i].withValues(alpha: busy[i] > 0 ? 0.12 : 0.28), borderRadius: BorderRadius.circular(20), border: Border.all(color: ready[i] >= 0 && (t * 5).floor().isEven ? Colors.white : cols[i], width: 3)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Portão ${i + 1}', style: body(14, color: Colors.white, w: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ready[i] >= 0
                      ? Column(children: [Transform.rotate(angle: -math.pi / 2, child: Icon(Icons.flight_rounded, color: Colors.white, size: 46)), Text('LIBERAR!', style: body(12, color: Colors.white, w: FontWeight.w900)), SizedBox(width: 50, child: LinearProgressIndicator(value: 1 - ready[i] / 5, color: K.red, backgroundColor: Colors.white24, minHeight: 5))])
                      : busy[i] > 0
                      ? Column(children: [Icon(Icons.flight_rounded, color: cols[i], size: 46), const SizedBox(height: 6), SizedBox(width: 50, child: LinearProgressIndicator(value: busy[i] / 4, color: Colors.white, backgroundColor: Colors.white24, minHeight: 5))])
                      : Icon(Icons.local_parking_rounded, color: Colors.white.withValues(alpha: 0.5), size: 46),
                ]),
              ),
            )),
          ])),
          _gameHead(pad, 'Pátio', 'Mande cada avião para o portão da cor dele. Quando o portão piscar, toque para liberar a decolagem!', [_pill('Operações: $score'), _pill('${math.max(0, dur - t).ceil()}s', t > dur - 6 ? const Color(0xFFFFC9CE) : Colors.white), _lives(lives, 3)]),
          if (flashT > 0) Positioned(top: sz.height * 0.24, left: 0, right: 0, child: Center(child: _pill(flash, const Color(0xFFFFC9CE)))),
          if (!started) const _StartCard(),
          if (res != null) Positioned.fill(child: Container(color: const Color(0x88000000), child: _ResultCard(r: res!, reward: widget.rewardText(res!.stars), onOk: () => Navigator.of(context).pop(res)))),
          Positioned(top: pad.top + 6, right: 8, child: CloseBtn(onTap: () => Navigator.of(context).pop(const GameResult(0, '')))),
        ]),
      ),
    );
  }
}
