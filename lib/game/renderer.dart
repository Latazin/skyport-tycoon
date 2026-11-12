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

/// Desenha o aeroporto inteiro: fundo, estações, aviões, passageiros, efeitos, clima e dia/noite.
class SceneRenderer extends Component {
  final AirWorld w;
  final GameState s;
  Rect view = Rect.zero;
  double zoom = 1;
  final List<Hit> hits = [];
  String? selected, hint;
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
    if (_tc.length > 600) _tc.clear();
    return _tc['$t|$size|${color.toARGB32()}|${stroke?.toARGB32()}'] ??= _OT(t, size, color, stroke);
  }
  void txt(Canvas c, String t, Offset at, double size, Color color, [Color? stroke]) {
    final tp = _text(t, size, color, stroke); tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }
  void icon(Canvas c, String name, Offset at, double size, [double alpha = 1]) {
    final img = Art.icons['icon_$name']; if (img == null) return;
    c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: at, width: size, height: size), _p..color = Color.fromRGBO(255, 255, 255, alpha));
  }
  Rect plate(Canvas c, String t, Offset at, double size, Color bg, {String? ico}) {
    final tp = _text(t, size, Colors.white, const Color(0x991E2A47));
    final iw = ico != null ? size * 1.5 : 0.0;
    final w0 = tp.width + size * 1.3 + iw, h = size * 1.7;
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: w0, height: h), Radius.circular(h / 2));
    c.drawRRect(r.shift(Offset(0, size * 0.25)), Paint()..color = const Color(0x55141A33));
    c.drawRRect(r.inflate(size * 0.16), Paint()..color = const Color(0xFF1E2A47));
    c.drawRRect(r, Paint()..shader = ui.Gradient.linear(r.outerRect.topCenter, r.outerRect.bottomCenter, [Color.lerp(bg, Colors.white, 0.3)!, bg, Color.lerp(bg, Colors.black, 0.18)!], [0, 0.55, 1]));
    if (ico != null) icon(c, ico, Offset(r.left + size * 0.35 + iw / 2, at.dy), size * 1.45);
    tp.paint(c, Offset(r.left + size * 0.65 + iw - (ico != null ? size * 0.2 : 0), at.dy - tp.height / 2 - size * 0.04));
    return r.outerRect;
  }
  void bar(Canvas c, Offset at, double w0, double h, double v, Color col) {
    final o = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: w0 + 4, height: h + 4), Radius.circular(h));
    c.drawRRect(o, Paint()..color = const Color(0xFF1E2A47));
    if (v > 0) c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(at.dx - w0 / 2, at.dy - h / 2, math.max(h, w0 * v.clamp(0.0, 1.0)), h), Radius.circular(h / 2)), Paint()..color = col);
  }
  double _bounce(String id) {
    final b = w.bump[id]; if (b == null) return 1;
    final k = (w.t - b) / 0.55; if (k < 0 || k > 1) return 1;
    return 1 + math.sin(k * math.pi) * 0.14 * (1 - k);
  }

  // ---------- dia/noite e clima ----------
  double night = 0, rain = 0;
  void _dayNight() {
    final ph = (w.t / 300 + 0.05) % 1;
    double n = 0;
    if (ph < 0.62) { n = 0; } else if (ph < 0.7) { n = (ph - 0.62) / 0.08; } else if (ph < 0.9) { n = 1; } else { n = 1 - (ph - 0.9) / 0.1; }
    night = n * 0.85;
    final rp = (w.t / 420 + 0.3) % 1;
    rain = rp > 0.82 ? math.sin((rp - 0.82) / 0.18 * math.pi) : 0;
  }

  void _add(int layer, double depth, void Function(Canvas) f) => _ds.add(_D(layer, depth, f));

  @override
  void render(Canvas c) {
    if (!Art.ready) return;
    hits.clear(); _ds.clear();
    _dayNight();
    final bgi = cityAt(s.city).bg;
    for (final t in (Art.bg[bgi] ?? Art.bg[0] ?? const <BgTile>[])) { if (t.dst.overlaps(view)) c.drawImageRect(t.img, t.src, t.dst, _bgP); }
    final fy = Lay.floorY;

    // ---------- pista ----------
    _add(0, -1e6, (c) => spr(c, 'aids${aidsTier(s.lvl('pista'))}', Lay.runwayX0, Lay.runwayZ, scale: _bounce('pista')));
    _hitWorld('pista', -60, -40, Lay.runwayZ - 4, Lay.runwayZ + 4);
    // ---------- check-in ----------
    final bc = _bounce('checkin');
    for (var d = 0; d < w.desks; d++) {
      final p = w.deskPos(d);
      _add(4, p.$1 + p.$2, (c) {
        spr(c, 'checkin', p.$1, p.$2, y: fy, scale: bc);
        final pr = w.deskProgress(d);
        if (pr > 0 && zoom > 0.32) bar(c, iso(p.$1, p.$2, 3.4), 30, 5, pr, const Color(0xFF3FD46B));
      });
    }
    _hitWorld('checkin', Lay.checkinX0 - 1.5, Lay.checkinX0 + 7 * Lay.checkinDx + 1.5, Lay.checkinZ - 1.5, Lay.checkinZ + 4);
    // ---------- raio-x ----------
    final bs = _bounce('seguranca');
    final scan = s.lvl('seguranca') >= 20;
    for (var l = 0; l < w.lanes; l++) {
      final p = w.lanePos(l);
      _add(4, p.$1 + p.$2, (c) {
        spr(c, 'security', p.$1, p.$2, y: fy, scale: bs);
        if (scan) spr(c, 'bodyscan', p.$1 + 0.75, p.$2 - 0.2, y: fy, scale: bs);
        final pr = w.laneProgress(l);
        if (pr > 0 && zoom > 0.32) bar(c, iso(p.$1 + 0.5, p.$2, 3.4), 30, 5, pr, const Color(0xFF8F62F8));
      });
    }
    _hitWorld('seguranca', Lay.secX0 - 1.5, Lay.secX0 + 5 * Lay.secDx + 2, Lay.secZ - 2.5, Lay.secZ + 3);
    // ---------- lojas ----------
    if (s.built('lojas')) {
      final bl = _bounce('lojas');
      for (var i = 0; i < shopsFor(s.lvl('lojas')); i++) { final p = Lay.shops[i]; _add(4, p.$1 + p.$2, (c) => spr(c, 'shop$i', p.$1, p.$2, y: fy, scale: bl)); }
    } else if (s.starOk(stationById('lojas'))) { _add(4, 15.5, (c) => spr(c, 'obra_m', 7.5, 8, y: fy)); }
    _hitWorld('lojas', -4, 19, 5.5, 11.5);
    // ---------- enfeites por nível ----------
    for (final pr in props) {
      if (s.lvl(pr.st) < pr.lvl) continue;
      final b = _bounce(pr.st);
      _add(4, pr.x + pr.z, (c) => spr(c, pr.sprite, pr.x, pr.z, y: fy, scale: b));
    }
    // ---------- VIP ----------
    if (s.built('vip')) { _add(4, Lay.vip.$1 + Lay.vip.$2, (c) => spr(c, 'vip${vipTier(s.lvl('vip'))}', Lay.vip.$1, Lay.vip.$2, y: fy, scale: _bounce('vip'))); }
    else if (s.starOk(stationById('vip'))) { _add(4, Lay.vip.$1 + Lay.vip.$2, (c) => spr(c, 'obra_m', Lay.vip.$1, Lay.vip.$2, y: fy)); }
    _hitWorld('vip', Lay.vip.$1 - 4.5, Lay.vip.$1 + 4.5, Lay.vip.$2 - 3, Lay.vip.$2 + 3.5);
    // ---------- portões ----------
    for (var g = 0; g < 6; g++) {
      final gx = Lay.gates[g], id = 'g$g';
      if (s.built(id)) {
        final gt = gateVis(s.lvl(id));
        final b = _bounce(id);
        _add(4, gx - 2.6, (c) => spr(c, 'gate${g + 1}_$gt', gx, -2.6, y: fy, scale: b));
        final pt = s.gates[g].phase == Ph.empty ? s.tierFor(g) : s.gates[g].tier;
        if (pt >= 1) _add(1, gx - 5, (c) => spr(c, 'bridge$pt', gx, -5));
        if (s.lvl(id) >= 5) _add(4, gx + 1.4, (c) => spr(c, 'plant', gx - 3.4, 1.4, y: fy));
        if (s.lvl(id) >= 20) _add(4, gx + 4.2, (c) => spr(c, 'vending', gx + 4.4, -0.2, y: fy));
        // pilha de dinheiro
        if (s.pile[g] > 0) {
          final pp = w.pilePos(g), n = s.pile[g] > s.rate * 40 ? 3 : s.pile[g] > s.rate * 10 ? 2 : 1;
          _add(4, pp.$1 + pp.$2 + 0.5, (c) {
            final r = spr(c, 'cash$n', pp.$1, pp.$2, y: fy, scale: 1 + math.sin(w.t * 6 + g) * 0.04);
            if (r != null) hits.add(Hit(r.inflate(14), 'pile:$g'));
          });
        }
      } else if (s.starOk(stationById(id))) {
        _add(4, gx - 1.5, (c) => spr(c, 'obra_s', gx + 0.5, -1.2, y: fy));
      }
      _hitWorld(id, gx - 4, gx + 4, -4.5, 1.8);
      final pose = w.planePose(g);
      if (pose != null) _plane(g, pose);
    }
    if (s.shopPile > 0) {
      final pp = AirWorld.shopPilePos, n = s.shopPile > s.rate * 30 ? 3 : s.shopPile > s.rate * 8 ? 2 : 1;
      _add(4, pp.$1 + pp.$2 + 0.5, (c) { final r = spr(c, 'cash$n', pp.$1, pp.$2, y: fy); if (r != null) hits.add(Hit(r.inflate(14), 'pile:shop')); });
    }
    _add(2, 0, (c) => spr(c, 'wall', (Lay.termX0 + Lay.termX1) / 2, -5));
    // ---------- exterior ----------
    final be = _bounce('entrada');
    _add(3, Lay.parking.$1 + Lay.parking.$2 - 9, (c) => spr(c, 'parking${parkTier(s.lvl('entrada'))}', Lay.parking.$1, Lay.parking.$2, scale: be));
    final nCars = parkCars(s.lvl('entrada'));
    for (var i = 0; i < nCars; i++) {
      final sl = AirWorld.parkSlots[i];
      _add(3, sl.$1 + sl.$2, (c) => spr(c, 'car${sl.$4}_${sl.$3}', sl.$1, sl.$2, scale: be));
    }
    _add(3, Lay.busStop.$1 + Lay.busStop.$2, (c) => spr(c, 'busstop', Lay.busStop.$1, Lay.busStop.$2));
    _hitWorld('entrada', Lay.parking.$1 - 14, Lay.parking.$1 + 14, Lay.parking.$2 - 7, Lay.parking.$2 + 7);
    _add(3, Lay.tower.$1 + Lay.tower.$2, (c) => spr(c, 'tower${towerTier(s.lvl('torre'))}', Lay.tower.$1, Lay.tower.$2, scale: _bounce('torre')));
    _hitWorld('torre', Lay.tower.$1 - 3, Lay.tower.$1 + 3, Lay.tower.$2 - 3, Lay.tower.$2 + 3, h: 18);
    if (s.built('hangar') || s.starOk(stationById('hangar'))) _add(3, Lay.hangar.$1 + Lay.hangar.$2, (c) => spr(c, s.built('hangar') ? 'hangar' : 'obra_l', Lay.hangar.$1, Lay.hangar.$2, scale: _bounce('hangar')));
    _hitWorld('hangar', Lay.hangar.$1 - 7, Lay.hangar.$1 + 7, Lay.hangar.$2 - 6, Lay.hangar.$2 + 6, h: 5);
    if (s.built('combustivel') || s.starOk(stationById('combustivel'))) _add(3, Lay.fuel.$1 + Lay.fuel.$2, (c) => spr(c, s.built('combustivel') ? 'fuel' : 'obra_m', Lay.fuel.$1, Lay.fuel.$2, scale: _bounce('combustivel')));
    _hitWorld('combustivel', Lay.fuel.$1 - 5, Lay.fuel.$1 + 5, Lay.fuel.$2 - 4, Lay.fuel.$2 + 4, h: 3);
    // ---------- passageiros ----------
    for (final a in w.agents) {
      final down = a.hx + a.hz >= 0, flip = a.hx - a.hz < 0;
      final f = a.moving ? '${(a.anim.floor()) % 4}' : 'i';
      final name = 'p${a.c}_${down ? 'd' : 'u'}_$f${a.bag ? 'b' : ''}';
      final y = a.z > 16.2 ? 0.0 : fy;
      _add(4, a.x + a.z + 0.3, (c) {
        spr(c, name, a.x, a.z, y: y, flip: flip, alpha: a.fade);
        if (a.emoT > 0) txt(c, a.emo, iso(a.x, a.z, y + 2.1 + (2 - a.emoT) * 0.3), 15, Colors.white, const Color(0x00000000));
      });
    }
    for (final cl in w.cleaners) {
      final down = cl.hx + cl.hz >= 0, flip = cl.hx - cl.hz < 0;
      final name = 'cl_${down ? 'd' : 'u'}_${cl.moving ? (cl.anim.floor() % 4) : 0}';
      _add(4, cl.x + cl.z + 0.3, (c) => spr(c, name, cl.x, cl.z, y: fy, flip: flip));
    }
    // ---------- veículos ----------
    for (final v in w.vehicles) {
      final h = math.atan2(v.hx, v.hz);
      final i = ((h / (math.pi / 2)).round() % 4 + 4) % 4;
      final name = v.kind.startsWith('car') ? '${v.kind}_$i' : 'v_${v.kind}_$i';
      _add(v.z > 10 ? 3 : 0, v.x + v.z, (c) => spr(c, name, v.x, v.z));
    }
    // ---------- poeira das obras ----------
    for (final p in w.puffs) {
      _add(5, 1e5, (c) {
        final k = p.t / 0.9;
        c.drawCircle(iso(p.x, p.z, 0.6 + k * 1.5), (8 + k * 22) * p.s, Paint()..color = Color.fromRGBO(240, 232, 214, (1 - k) * 0.75));
      });
    }
    _ds.sort((a, b) => a.layer != b.layer ? a.layer.compareTo(b.layer) : a.depth.compareTo(b.depth));
    for (final d in _ds) { d.f(c); }
    if (night > 0.01) _nightPass(c);
    if (rain > 0.02 || s.fogOn) _weather(c);
    _overlays(c);
  }

  void _plane(int g, Pose pose) {
    final G = s.gates[g];
    final idx = (((pose.heading / (math.pi / 4)).round()) % 8 + 8) % 8;
    final name = 'pl${G.tier}_${G.liv}_$idx';
    final p = pose.p;
    final air = p.y > 0.3;
    final len = planeTypes[G.tier].len;
    _add(0, p.x + p.z - 0.5, (c) {
      final o = iso(p.x + 0.4 + p.y * 0.25, p.z - 0.4 - p.y * 0.25);
      final k = (1 - p.y / 70).clamp(0.2, 1.0);
      c.drawOval(Rect.fromCenter(center: o, width: len * S * 0.75 * k, height: len * S * 0.36 * k), Paint()..color = Color.fromRGBO(20, 30, 50, 0.22 * k));
    });
    final scale = air ? (1 + p.y / 80) : 1.0;
    _add(air ? 5 : 0, p.x + p.z, (c) {
      final r = spr(c, name, p.x, p.z, y: p.y, scale: scale);
      if (r != null) hits.add(Hit(r.deflate(r.width * 0.15), G.vip && !G.vipTapped && G.phase == Ph.boarding ? 'vip:$g' : 'plane:$g'));
      if (G.vip) {
        for (var i = 0; i < 3; i++) {
          final a = w.t * 3 + i * 2.1;
          c.drawCircle(iso(p.x + math.cos(a) * len * 0.35, p.z + math.sin(a) * len * 0.35, p.y + 1.5 + math.sin(a * 2) * 0.5), 4, Paint()..color = const Color(0xFFFFF1A8));
        }
      }
      if (G.phase == Ph.boarding && zoom > 0.3) {
        final o = iso(p.x, p.z, 3.4 + len * 0.12);
        final k = (1 / zoom).clamp(0.8, 2.2).toDouble();
        final full = G.boarded / G.seats;
        bar(c, o, 46 * k, 7 * k, full, full > 0.9 ? const Color(0xFF3FD46B) : const Color(0xFFFFC531));
        txt(c, '${G.boarded.floor()}/${G.seats}', o - Offset(0, 12 * k), 10 * k, Colors.white);
      }
    });
  }

  void _hitWorld(String id, double x0, double x1, double z0, double z1, {double h = 3}) {
    final pts = [iso(x0, z0), iso(x1, z0), iso(x0, z1), iso(x1, z1), iso(x0, z0, h), iso(x1, z1, h)];
    var l = pts[0].dx, r = pts[0].dx, t = pts[0].dy, b = pts[0].dy;
    for (final p in pts) { l = math.min(l, p.dx); r = math.max(r, p.dx); t = math.min(t, p.dy); b = math.max(b, p.dy); }
    hits.add(Hit(Rect.fromLTRB(l, t, r, b), id));
  }

  void _weather(Canvas c) {
    final k = math.max(rain, s.fogOn ? 1.0 : 0.0);
    if (s.fogOn) c.drawRect(view, Paint()..color = const Color(0x88E8EEF5));
    final p = Paint()..color = Color.fromRGBO(200, 220, 255, 0.45 * k)..strokeWidth = 2.2 / zoom;
    final rr = math.Random(7);
    final h = view.height, wd = view.width;
    for (var i = 0; i < 90; i++) {
      final x = view.left + rr.nextDouble() * wd, sp = 0.6 + rr.nextDouble() * 0.6;
      final y = view.top + ((rr.nextDouble() * h + w.t * 900 * sp) % h);
      c.drawLine(Offset(x, y), Offset(x - 6 / zoom, y + 22 / zoom), p);
    }
  }

  void _nightPass(Canvas c) {
    c.drawRect(view, Paint()..color = Color.fromRGBO(18, 28, 70, night * 0.62));
    final glow = Paint()..blendMode = BlendMode.plus;
    final a = night;
    for (var x = Lay.runwayX0; x <= Lay.runwayX1; x += 4) {
      for (final z in [Lay.runwayZ - 4.2, Lay.runwayZ + 4.2]) { final o = iso(x, z); if (!view.contains(o)) continue; glow.color = Color.fromRGBO(255, 240, 200, 0.55 * a); c.drawCircle(o, 4, glow); glow.color = Color.fromRGBO(255, 230, 170, 0.18 * a); c.drawCircle(o, 11, glow); }
    }
    for (var x = Lay.connL; x <= Lay.connR; x += 4) { final o = iso(x, Lay.laneZ); glow.color = Color.fromRGBO(80, 160, 255, 0.5 * a); c.drawCircle(o, 3.5, glow); }
    for (var z = Lay.runwayZ; z <= Lay.laneZ; z += 3) { for (final x in [Lay.connL, Lay.connR]) { final o = iso(x, z); glow.color = Color.fromRGBO(80, 220, 120, 0.5 * a); c.drawCircle(o, 3.5, glow); } }
    for (var x = Lay.termX0 + 3; x < Lay.termX1; x += 7) {
      for (final z in [-2.0, 6.0, 13.0]) { final o = iso(x, z, 0.5); glow.color = Color.fromRGBO(255, 214, 140, 0.16 * a); c.drawCircle(o, 70, glow); }
    }
    for (var x = -86.0; x < 80; x += 12) { final o = iso(x, Lay.roadZ + 3.4, 2.6); glow.color = Color.fromRGBO(255, 230, 160, 0.35 * a); c.drawCircle(o, 16, glow); glow.color = Color.fromRGBO(255, 240, 200, 0.7 * a); c.drawCircle(o, 3, glow); }
    final tt = iso(Lay.tower.$1, Lay.tower.$2, [9.5, 13.5, 17.5][towerTier(s.lvl('torre')) - 1]);
    glow.color = Color.fromRGBO(120, 210, 255, 0.4 * a); c.drawCircle(tt, 26, glow);
    final blink = (w.t * 1.5) % 1 < 0.2;
    for (var g = 0; g < 6; g++) {
      final pose = w.planePose(g); if (pose == null) continue;
      final o = iso(pose.p.x, pose.p.z, pose.p.y + 1.5);
      glow.color = Color.fromRGBO(255, 255, 255, (blink ? 0.9 : 0.25) * a); c.drawCircle(o, blink ? 6 : 3, glow);
      if (pose.p.y > 0.2 || s.gates[g].phase == Ph.landing) {
        glow.color = Color.fromRGBO(255, 250, 220, 0.35 * a); c.drawCircle(iso(pose.p.x + math.sin(pose.heading) * 4, pose.p.z + math.cos(pose.heading) * 4, pose.p.y), 18, glow);
      }
    }
  }

  void _overlays(Canvas c) {
    final k = ((1 / zoom).clamp(0.8, 2.6) * 10).roundToDouble() / 10;
    final t = w.t;
    for (final sp in w.sparks) {
      final o = iso(sp.x, sp.z, sp.y);
      c.drawCircle(o, 5 * (1 - sp.t / 1.1) * k * 0.7, Paint()..color = sp.c.withValues(alpha: (1 - sp.t / 1.1).clamp(0.0, 1.0)));
    }
    // nuvens sobre áreas que pedem estrelas
    for (final st in stations) {
      if (s.built(st.id) || s.starOk(st)) continue;
      final cc = w.stationCenter(st.id);
      final o = iso(cc.$1, cc.$2, 1.5);
      if (!view.inflate(120).contains(o)) continue;
      for (var i = 0; i < 4; i++) { icon(c, 'cloud', o + Offset(math.cos(i * 1.7 + t * 0.2) * 34 * k, math.sin(i * 2.3) * 12 * k - 10 * k), (64 + i * 10) * k, 0.92); }
      final r = plate(c, '${st.star}', o + Offset(0, -6 * k), 12 * k, const Color(0xFF8F62F8), ico: 'star');
      hits.add(Hit(r.inflate(24), st.id));
    }
    // emblemas
    final best = s.bestBuy();
    for (final st in stations) {
      if (!s.built(st.id) && !s.unlockOk(st)) continue;
      final cc = w.stationCenter(st.id);
      final o = iso(cc.$1, cc.$2, cc.$3);
      final bb = _bounce(st.id);
      final at = o - Offset(0, (bb - 1) * 90 * k);
      if (!view.inflate(80).contains(at)) continue;
      final isBest = best != null && best.$1 == st.id;
      if (!s.built(st.id)) {
        final can = s.canUnlock(st);
        final r = plate(c, fmt(st.unlock), at, 13 * k, can ? const Color(0xFF3FD46B) : const Color(0xFF8A93A6), ico: can ? 'coin' : 'lock');
        hits.add(Hit(r.inflate(10), st.id));
        if (can) icon(c, 'up', at - Offset(0, 26 * k + math.sin(t * 5) * 4 * k), 26 * k);
        continue;
      }
      if (st.oneTime) continue;
      final up = s.canUp(st);
      final sel = selected == st.id;
      final r = plate(c, 'Nv ${s.lvl(st.id)}', at, 11.5 * k, sel ? const Color(0xFFFFB020) : isBest ? const Color(0xFF2FB35A) : const Color(0xFF3E6BD6));
      hits.add(Hit(r.inflate(12), st.id));
      if (up) icon(c, 'up', Offset(r.right + 4 * k, r.top + 2 * k - math.sin(t * 5 + cc.$1) * 3 * k), 22 * k);
      if (isBest && hint == null) {
        final hb = math.sin(t * 6) * 6 * k;
        final p0 = Offset(r.center.dx, r.top - 26 * k + hb);
        c.save(); c.translate(p0.dx, p0.dy); c.rotate(math.pi); icon(c, 'up', Offset.zero, 30 * k); c.restore();
      }
      final bott = s.bottleneck == st.id || (s.bottleneck == 'gates' && st.kind == Kind.gate && st.gate == 0);
      if (bott && s.rate > 0) {
        final bo = Offset(r.left - 4 * k, r.top - 2 * k);
        final pulse = 1 + 0.12 * math.sin(t * 6);
        c.drawCircle(bo, 11 * k * pulse, Paint()..color = const Color(0xFF1E2A47));
        c.drawCircle(bo, 9 * k * pulse, Paint()..color = const Color(0xFFFF5A5F));
        txt(c, '!', bo, 13 * k, Colors.white, const Color(0x00000000));
      }
    }
    // dica do tutorial
    if (hint != null) {
      final cc = hint == 'pile' ? (w.pilePos(0).$1, w.pilePos(0).$2, 1.5) : w.stationCenter(hint!);
      final o = iso(cc.$1, cc.$2, cc.$3) - Offset(0, 34 * k + math.sin(t * 6) * 8 * k);
      c.save(); c.translate(o.dx, o.dy); c.rotate(math.pi); icon(c, 'up', Offset.zero, 46 * k); c.restore();
    }
    // evento ativo
    final e = s.ev;
    if (e != null) {
      final o = iso(e.x, e.z, 4) + Offset(0, math.sin(t * 4) * 6 * k);
      final ic = {'celeb': 'celeb', 'bag': 'suitcase', 'tourists': 'rush', 'fog': 'cloud'}[e.type] ?? 'gift';
      final rad = 34 * k * (1 + 0.06 * math.sin(t * 8));
      c.drawCircle(o, rad + 8 * k, Paint()..color = const Color(0x66FFE27A));
      c.drawCircle(o, rad, Paint()..color = const Color(0xFFFFF6E4));
      c.drawCircle(o, rad, Paint()..style = PaintingStyle.stroke..strokeWidth = 4 * k..color = const Color(0xFFFFB020));
      icon(c, ic, o, 46 * k);
      if (e.type == 'fog') plate(c, 'TOQUE ${5 - e.taps}x', o + Offset(0, rad + 14 * k), 11 * k, const Color(0xFFFF5A5F));
      final left = (e.until - s.clock).clamp(0.0, 99.0).toDouble();
      bar(c, o + Offset(0, -rad - 10 * k), 50 * k, 6 * k, left / (e.type == 'fog' ? 45 : 30), const Color(0xFFFFB020));
      hits.add(Hit(Rect.fromCenter(center: o, width: 100 * k, height: 100 * k), 'ev'));
    }
    // VIP: brilho para tocar
    for (var g = 0; g < 6; g++) {
      final G = s.gates[g];
      if (!G.vip || G.vipTapped || G.phase != Ph.boarding) continue;
      final o = iso(Lay.gates[g], Routes.parkZ(G.tier), 6) + Offset(0, math.sin(t * 5) * 6 * k);
      c.drawCircle(o, 26 * k, Paint()..color = const Color(0xCCFFE27A));
      icon(c, 'gem', o, 34 * k);
      hits.add(Hit(Rect.fromCenter(center: o, width: 80 * k, height: 80 * k), 'vip:$g'));
    }
    for (final f in w.floaters) {
      final o = iso(f.x, f.z, f.y0 + f.t * 4);
      final a = (1 - (f.t - 1.2).clamp(0.0, 0.6) / 0.6).toDouble();
      if (a <= 0) continue;
      final sc = f.t < 0.2 ? 0.6 + f.t * 2 : 1.0;
      final tp = _text(f.text, (16 * f.big * k * sc).roundToDouble(), f.color);
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
      c.restore();
    }
  }
}
