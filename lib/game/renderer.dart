import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../core/state.dart';
import 'art.dart';
import 'world.dart';

class _D {
  final int layer;
  final double depth;
  final void Function(Canvas) f;
  _D(this.layer, this.depth, this.f);
}

class Hit {
  final Rect r;
  final String id;
  const Hit(this.r, this.id);
}

/// Texto com contorno (cacheado).
class _OT {
  final TextPainter fill, stroke;
  _OT(String t, double size, Color c, Color? s)
      : fill = TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: size, color: c)), textDirection: TextDirection.ltr)..layout(),
        stroke = TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: size, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = size * 0.22..strokeJoin = StrokeJoin.round..color = s ?? const Color(0xFF1E2A47))), textDirection: TextDirection.ltr)..layout();
  double get width => fill.width;
  double get height => fill.height;
  void paint(Canvas c, Offset o) { stroke.paint(c, o); fill.paint(c, o); }
}

/// Desenha o aeroporto inteiro: fundo, estações, aviões, passageiros, efeitos e dia/noite.
class SceneRenderer extends Component {
  final AirWorld w;
  final GameState s;
  Rect view = Rect.zero;
  double zoom = 1;
  final List<Hit> hits = [];
  String? selected;
  SceneRenderer(this.w, this.s);

  final Paint _p = Paint()..filterQuality = FilterQuality.medium..isAntiAlias = true;
  final Paint _bgP = Paint()..filterQuality = FilterQuality.low;
  static final Map<String, _OT> _tc = {};
  final List<_D> _ds = [];

  // ---------- primitivas ----------
  Rect? spr(Canvas c, String name, double x, double z, {double y = 0, bool flip = false, double alpha = 1, double scale = 1}) {
    final sp = Art.spr[name]; if (sp == null) return null;
    final o = iso(x, z, y);
    final w0 = sp.w * scale, h0 = sp.h * scale;
    final left = flip ? o.dx - (sp.src.width - sp.ax) / sp.k * scale : o.dx - sp.ax / sp.k * scale;
    final dst = Rect.fromLTWH(left, o.dy - sp.ay / sp.k * scale, w0, h0);
    if (!dst.overlaps(view)) return dst;
    _p.color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
    if (flip) {
      c.save(); c.translate(dst.center.dx, 0); c.scale(-1, 1); c.translate(-dst.center.dx, 0);
      c.drawImageRect(sp.img, sp.src, dst, _p); c.restore();
    } else {
      c.drawImageRect(sp.img, sp.src, dst, _p);
    }
    return dst;
  }
  _OT _text(String t, double size, Color color, [Color? stroke]) {
    if (_tc.length > 500) _tc.clear();
    return _tc['$t|$size|${color.toARGB32()}|${stroke?.toARGB32()}'] ??= _OT(t, size, color, stroke);
  }
  void txt(Canvas c, String t, Offset at, double size, Color color, [Color? stroke]) {
    final tp = _text(t, size, color, stroke); tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }
  void icon(Canvas c, String name, Offset at, double size) {
    final img = Art.icons['icon_$name']; if (img == null) return;
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: at, width: size, height: size), _p..color = Colors.white);
  }
  /// Placa estilo jogo (pílula com gradiente e contorno).
  Rect plate(Canvas c, String t, Offset at, double size, Color bg, {String? ico}) {
    final tp = _text(t, size, Colors.white, const Color(0x991E2A47));
    final iw = ico != null ? size * 1.5 : 0.0;
    final w0 = tp.width + size * 1.3 + iw, h = size * 1.7;
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: w0, height: h), Radius.circular(h / 2));
    c.drawRRect(r.shift(Offset(0, size * 0.25)), Paint()..color = const Color(0x55141A33));
    c.drawRRect(r.inflate(size * 0.16), Paint()..color = const Color(0xFF1E2A47));
    c.drawRRect(r, Paint()..shader = ui.Gradient.linear(r.outerRect.topCenter, r.outerRect.bottomCenter, [Color.lerp(bg, Colors.white, 0.3)!, bg, Color.lerp(bg, Colors.black, 0.18)!], [0, 0.55, 1]));
    if (ico != null) icon(c, ico, Offset(r.left + size * 0.55 + iw / 2 - size * 0.2, at.dy), size * 1.45);
    tp.paint(c, Offset(r.left + size * 0.65 + iw - (ico != null ? size * 0.2 : 0), at.dy - tp.height / 2 - size * 0.04));
    return r.outerRect;
  }

  // ---------- dia/noite ----------
  double night = 0;
  void _dayNight() {
    final ph = (w.t / 300 + 0.05) % 1;
    double n = 0;
    if (ph < 0.62) { n = 0; } else if (ph < 0.7) { n = (ph - 0.62) / 0.08; } else if (ph < 0.9) { n = 1; } else { n = 1 - (ph - 0.9) / 0.1; }
    night = n * 0.85;
  }

  void _add(int layer, double depth, void Function(Canvas) f) => _ds.add(_D(layer, depth, f));

  @override
  void render(Canvas c) {
    if (!Art.ready) return;
    hits.clear(); _ds.clear();
    _dayNight();
    // fundo
    final bgi = cityAt(s.city).bg;
    for (final t in (Art.bg[bgi] ?? Art.bg[0] ?? const <BgTile>[])) { if (t.dst.overlaps(view)) c.drawImageRect(t.img, t.src, t.dst, _bgP); }

    final fy = Lay.floorY;
    // ---------- pista: auxílios ----------
    _add(0, -1e6, (c) => spr(c, 'aids${aidsTier(s.lvl('pista'))}', Lay.runwayX0, Lay.runwayZ));
    _hitWorld('pista', -60, -40, Lay.runwayZ - 4, Lay.runwayZ + 4);
    // ---------- estações internas ----------
    for (var d = 0; d < w.desks; d++) { final p = w.deskPos(d); _add(4, p.$1 + p.$2, (c) => spr(c, 'checkin', p.$1, p.$2, y: fy)); }
    _hitWorld('checkin', Lay.checkinX0 - 1.5, Lay.checkinX0 + 5 * Lay.checkinDx + 1.5, Lay.checkinZ - 1.5, Lay.checkinZ + 4);
    for (var l = 0; l < w.lanes; l++) { final p = w.lanePos(l); _add(4, p.$1 + p.$2, (c) => spr(c, 'security', p.$1, p.$2, y: fy)); }
    _hitWorld('seguranca', Lay.secX0 - 1.5, Lay.secX0 + 3 * Lay.secDx + 2, Lay.secZ - 2.5, Lay.secZ + 3);
    if (s.built('lojas')) {
      for (var i = 0; i < shopsFor(s.lvl('lojas')); i++) { final p = Lay.shops[i]; _add(4, p.$1 + p.$2, (c) => spr(c, 'shop$i', p.$1, p.$2, y: fy)); }
    } else { _add(4, 14.5, (c) => spr(c, 'obra_m', 6.5, 8, y: fy)); }
    _hitWorld('lojas', -5.5, 18.5, 5.5, 11.5);
    if (s.built('vip')) { _add(4, Lay.vip.$1 + Lay.vip.$2, (c) => spr(c, 'vip${vipTier(s.lvl('vip'))}', Lay.vip.$1, Lay.vip.$2, y: fy)); }
    else { _add(4, Lay.vip.$1 + Lay.vip.$2, (c) => spr(c, 'obra_m', Lay.vip.$1, Lay.vip.$2, y: fy)); }
    _hitWorld('vip', Lay.vip.$1 - 4.5, Lay.vip.$1 + 4.5, Lay.vip.$2 - 3, Lay.vip.$2 + 3.5);
    // ---------- portões ----------
    for (var g = 0; g < 6; g++) {
      final gx = Lay.gates[g], id = 'g$g';
      if (s.built(id)) {
        final gt = gateTier(s.lvl(id)) + 1;
        _add(4, gx - 2.6, (c) => spr(c, 'gate${g + 1}_$gt', gx, -2.6, y: fy));
        final pt = s.gates[g].phase == Ph.empty ? s.tierFor(g) : s.gates[g].tier;
        if (pt >= 1) _add(1, gx - 5, (c) => spr(c, 'bridge$pt', gx, -5));
      } else {
        _add(4, gx - 1.5, (c) => spr(c, 'obra_s', gx + 0.5, -1.2, y: fy));
      }
      _hitWorld(id, gx - 4, gx + 4, -4.5, 1.8);
      // avião
      final pose = w.planePose(g);
      if (pose != null) _plane(g, pose);
    }
    _add(2, 0, (c) => spr(c, 'wall', (Lay.termX0 + Lay.termX1) / 2, -5));
    // ---------- prédios externos ----------
    _add(3, Lay.parking.$1 + Lay.parking.$2 - 6, (c) => spr(c, 'parking${parkTier(s.lvl('entrada'))}', Lay.parking.$1, Lay.parking.$2));
    _add(3, Lay.busStop.$1 + Lay.busStop.$2, (c) => spr(c, 'busstop', Lay.busStop.$1, Lay.busStop.$2));
    _hitWorld('entrada', Lay.parking.$1 - 14, Lay.parking.$1 + 14, Lay.parking.$2 - 7, Lay.parking.$2 + 7);
    _add(3, Lay.tower.$1 + Lay.tower.$2, (c) => spr(c, 'tower${towerTier(s.lvl('torre'))}', Lay.tower.$1, Lay.tower.$2));
    _hitWorld('torre', Lay.tower.$1 - 3, Lay.tower.$1 + 3, Lay.tower.$2 - 3, Lay.tower.$2 + 3, h: 18);
    _add(3, Lay.hangar.$1 + Lay.hangar.$2, (c) => spr(c, s.built('hangar') ? 'hangar' : 'obra_l', Lay.hangar.$1, Lay.hangar.$2));
    _hitWorld('hangar', Lay.hangar.$1 - 7, Lay.hangar.$1 + 7, Lay.hangar.$2 - 6, Lay.hangar.$2 + 6, h: 5);
    _add(3, Lay.fuel.$1 + Lay.fuel.$2, (c) => spr(c, s.built('combustivel') ? 'fuel' : 'obra_m', Lay.fuel.$1, Lay.fuel.$2));
    _hitWorld('combustivel', Lay.fuel.$1 - 5, Lay.fuel.$1 + 5, Lay.fuel.$2 - 4, Lay.fuel.$2 + 4, h: 3);
    // ---------- passageiros ----------
    for (final a in w.agents) {
      final down = a.hx + a.hz >= 0, flip = a.hx - a.hz < 0;
      final f = a.moving ? '${(a.anim.floor()) % 4}' : 'i';
      final name = 'p${a.c}_${down ? 'd' : 'u'}_$f${a.bag ? 'b' : ''}';
      _add(4, a.x + a.z + 0.3, (c) => spr(c, name, a.x, a.z, y: Lay.floorY + (a.z > 16.2 ? -Lay.floorY : 0), flip: flip, alpha: a.fade));
    }
    // ---------- veículos ----------
    for (final v in w.vehicles) {
      final h = math.atan2(v.hx, v.hz);
      final i = ((h / (math.pi / 2)).round() % 4 + 4) % 4;
      final name = 'v_${v.kind}_$i';
      final layer = v.z > 10 ? 3 : 0;
      _add(layer, v.x + v.z, (c) => spr(c, name, v.x, v.z));
    }
    // ---------- ordena e desenha ----------
    _ds.sort((a, b) => a.layer != b.layer ? a.layer.compareTo(b.layer) : a.depth.compareTo(b.depth));
    for (final d in _ds) {
      if (d.layer == 6) break;
      d.f(c);
    }
    // ---------- noite ----------
    if (night > 0.01) _nightPass(c);
    // ---------- sobreposições ----------
    _overlays(c);
  }

  void _plane(int g, Pose pose) {
    final G = s.gates[g];
    final idx = (((pose.heading / (math.pi / 4)).round()) % 8 + 8) % 8;
    final name = 'pl${G.tier}_${G.liv}_$idx';
    final p = pose.p;
    final air = p.y > 0.3;
    final len = planeTypes[G.tier].len;
    // sombra no chão
    _add(0, p.x + p.z - 0.5, (c) {
      final o = iso(p.x + 0.4 + p.y * 0.25, p.z - 0.4 - p.y * 0.25);
      final k = (1 - p.y / 70).clamp(0.2, 1.0);
      c.drawOval(Rect.fromCenter(center: o, width: len * S * 0.75 * k, height: len * S * 0.36 * k), Paint()..color = Color.fromRGBO(20, 30, 50, 0.22 * k));
    });
    final scale = air ? (1 + p.y / 80) : 1.0;
    _add(air ? 5 : 0, p.x + p.z, (c) {
      final r = spr(c, name, p.x, p.z, y: p.y, scale: scale);
      if (r != null) hits.add(Hit(r.deflate(r.width * 0.15), 'plane:$g'));
    });
  }

  void _hitWorld(String id, double x0, double x1, double z0, double z1, {double h = 3}) {
    final pts = [iso(x0, z0), iso(x1, z0), iso(x0, z1), iso(x1, z1), iso(x0, z0, h), iso(x1, z1, h)];
    var l = pts[0].dx, r = pts[0].dx, t = pts[0].dy, b = pts[0].dy;
    for (final p in pts) { l = math.min(l, p.dx); r = math.max(r, p.dx); t = math.min(t, p.dy); b = math.max(b, p.dy); }
    hits.add(Hit(Rect.fromLTRB(l, t, r, b), id));
  }

  void _nightPass(Canvas c) {
    c.drawRect(view, Paint()..color = Color.fromRGBO(18, 28, 70, night * 0.62));
    final glow = Paint()..blendMode = BlendMode.plus;
    final a = night;
    // luzes de borda da pista
    for (var x = Lay.runwayX0; x <= Lay.runwayX1; x += 4) {
      for (final z in [Lay.runwayZ - 4.2, Lay.runwayZ + 4.2]) { final o = iso(x, z); if (!view.contains(o)) continue; glow.color = Color.fromRGBO(255, 240, 200, 0.55 * a); c.drawCircle(o, 4, glow); glow.color = Color.fromRGBO(255, 230, 170, 0.18 * a); c.drawCircle(o, 11, glow); }
    }
    // taxiway e pátio (azul / amarelo)
    for (var x = Lay.connL; x <= Lay.connR; x += 4) { final o = iso(x, Lay.laneZ); glow.color = Color.fromRGBO(80, 160, 255, 0.5 * a); c.drawCircle(o, 3.5, glow); }
    for (var z = Lay.runwayZ; z <= Lay.laneZ; z += 3) { for (final x in [Lay.connL, Lay.connR]) { final o = iso(x, z); glow.color = Color.fromRGBO(80, 220, 120, 0.5 * a); c.drawCircle(o, 3.5, glow); } }
    // terminal iluminado
    for (var x = Lay.termX0 + 3; x < Lay.termX1; x += 7) {
      for (final z in [-2.0, 6.0, 13.0]) { final o = iso(x, z, 0.5); glow.color = Color.fromRGBO(255, 214, 140, 0.16 * a); c.drawCircle(o, 70, glow); }
    }
    // postes da avenida
    for (var x = -86.0; x < 80; x += 12) { final o = iso(x, Lay.roadZ + 3.4, 2.6); glow.color = Color.fromRGBO(255, 230, 160, 0.35 * a); c.drawCircle(o, 16, glow); glow.color = Color.fromRGBO(255, 240, 200, 0.7 * a); c.drawCircle(o, 3, glow); }
    // torre
    final tt = iso(Lay.tower.$1, Lay.tower.$2, [9.5, 13.5, 17.5][towerTier(s.lvl('torre')) - 1]);
    glow.color = Color.fromRGBO(120, 210, 255, 0.4 * a); c.drawCircle(tt, 26, glow);
    // aviões: luzes de navegação piscando
    final blink = (w.t * 1.5) % 1 < 0.2;
    for (var g = 0; g < 6; g++) {
      final pose = w.planePose(g); if (pose == null) continue;
      final o = iso(pose.p.x, pose.p.z, pose.p.y + 1.5);
      glow.color = Color.fromRGBO(255, 255, 255, (blink ? 0.9 : 0.25) * a); c.drawCircle(o, blink ? 6 : 3, glow);
      if (pose.p.y > 0.2 || s.gates[g].phase == Ph.landing) {
        // farol de pouso
        glow.color = Color.fromRGBO(255, 250, 220, 0.35 * a); c.drawCircle(iso(pose.p.x + math.sin(pose.heading) * 4, pose.p.z + math.cos(pose.heading) * 4, pose.p.y), 18, glow);
      }
    }
  }

  void _overlays(Canvas c) {
    final k = ((1 / zoom).clamp(0.8, 2.6) * 10).roundToDouble() / 10;
    final t = w.t;
    // faíscas
    for (final sp in w.sparks) {
      final o = iso(sp.x, sp.z, sp.y);
      c.drawCircle(o, 5 * (1 - sp.t / 1.1) * k * 0.7, Paint()..color = sp.c.withValues(alpha: (1 - sp.t / 1.1).clamp(0.0, 1.0)));
    }
    // emblemas das estações
    for (final st in stations) {
      if (st.kind == Kind.gate && !s.built(st.id) && !(s.unlockOk(st))) continue;
      final cc = w.stationCenter(st.id);
      final o = iso(cc.$1, cc.$2, cc.$3);
      final b = w.bump[st.id];
      final jump = b != null && t - b < 0.6 ? math.sin((t - b) / 0.6 * math.pi) * 12 * k : 0.0;
      final at = o - Offset(0, jump);
      if (!view.inflate(80).contains(at)) continue;
      if (!s.built(st.id)) {
        final can = s.canUnlock(st);
        final r = plate(c, fmt(st.unlock), at, 13 * k, can ? const Color(0xFF3FD46B) : const Color(0xFF8A93A6), ico: can ? 'coin' : 'lock');
        hits.add(Hit(r.inflate(10), st.id));
        if (can) icon(c, 'up', at - Offset(0, 26 * k + math.sin(t * 5) * 4 * k), 26 * k);
        continue;
      }
      if (st.oneTime) continue;
      final lvl = s.lvl(st.id);
      final up = s.canUp(st);
      final sel = selected == st.id;
      final r = plate(c, 'Nv $lvl', at, 11.5 * k, sel ? const Color(0xFFFFB020) : const Color(0xFF3E6BD6));
      hits.add(Hit(r.inflate(12), st.id));
      if (up) icon(c, 'up', Offset(r.right + 4 * k, r.top + 2 * k - math.sin(t * 5 + cc.$1) * 3 * k), 22 * k);
      final bott = s.bottleneck == st.id || (s.bottleneck == 'gates' && st.kind == Kind.gate && st.gate == 0);
      if (bott && s.rate > 0) {
        final bo = Offset(r.left - 4 * k, r.top - 2 * k);
        final pulse = 1 + 0.12 * math.sin(t * 6);
        c.drawCircle(bo, 11 * k * pulse, Paint()..color = const Color(0xFF1E2A47));
        c.drawCircle(bo, 9 * k * pulse, Paint()..color = const Color(0xFFFF5A5F));
        txt(c, '!', bo, 13 * k, Colors.white, const Color(0x00000000));
      }
    }
    // presente VIP
    if (s.gift != null) {
      final gx = Lay.gates[s.gift!];
      final o = iso(gx + 1, -1, 7) + Offset(0, math.sin(t * 3) * 6 * k);
      c.drawCircle(o, 30 * k, Paint()..color = const Color(0x66FFE27A));
      c.drawCircle(o, 22 * k, Paint()..color = const Color(0xFFFFF6E4));
      icon(c, 'gift', o, 34 * k);
      hits.add(Hit(Rect.fromCenter(center: o, width: 80 * k, height: 80 * k), 'gift'));
    }
    // textos flutuantes
    for (final f in w.floaters) {
      final o = iso(f.x, f.z, f.y0 + f.t * 4);
      final a = (1 - (f.t - 1.0).clamp(0.0, 0.6) / 0.6);
      if (a <= 0) continue;
      final sc = f.t < 0.2 ? 0.6 + f.t * 2 : 1.0;
      final tp = _text(f.text, (16 * f.big * k * sc).roundToDouble(), f.color);
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
      c.restore();
    }
  }
}
