import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../core/data.dart';
import '../core/format.dart';
import '../core/paths.dart';
import '../core/state.dart';
import 'art.dart';
import 'world.dart';
import '../core/cine.dart';

class _D {
  final int layer;
  final double depth;
  final void Function(Canvas) f;
  _D(this.layer, this.depth, this.f);
}

/// Área tocável. Menor prioridade ganha; empate: a menor área.
class Hit {
  final Rect r;
  final String id;
  final int prio;
  const Hit(this.r, this.id, [this.prio = 1]);
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

  final Paint _p = Paint()..filterQuality = kIsWeb ? FilterQuality.low : FilterQuality.medium..isAntiAlias = !kIsWeb;
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
  /// Etiqueta limpa: pílula branca com sombra suave e texto colorido (ou pílula colorida com texto branco).
  Rect plate(Canvas c, String t, Offset at, double size, Color bg, {String? ico, bool solid = false}) {
    final tp = _plain(t, size, solid ? Colors.white : bg);
    final iw = ico != null ? size * 1.45 : 0.0;
    final w0 = tp.width + size * 1.2 + iw, h = size * 1.75;
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: w0, height: h), Radius.circular(h / 2));
    c.drawRRect(r.shift(Offset(0, size * 0.22)), Paint()..color = const Color(0x33141A33));
    c.drawRRect(r, Paint()..color = solid ? bg : Colors.white);
    if (ico != null) icon(c, ico, Offset(r.left + size * 0.3 + iw / 2, at.dy), size * 1.4);
    tp.paint(c, Offset(r.left + size * 0.6 + iw - (ico != null ? size * 0.15 : 0), at.dy - tp.height / 2));
    return r.outerRect;
  }
  static final Map<String, TextPainter> _pc = {};
  TextPainter _plain(String t, double size, Color color) {
    if (_pc.length > 400) _pc.clear();
    return _pc['$t|$size|${color.toARGB32()}'] ??= (TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w600, fontSize: size, color: color)), textDirection: TextDirection.ltr)..layout());
  }
  void bar(Canvas c, Offset at, double w0, double h, double v, Color col) {
    final o = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: w0 + 4, height: h + 4), Radius.circular(h));
    c.drawRRect(o.shift(Offset(0, h * 0.3)), Paint()..color = const Color(0x33141A33));
    c.drawRRect(o, Paint()..color = Colors.white);
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
    final tiles = Art.bg[Art.bgKey(cityAt(s.city).bg, s.phase)] ?? Art.anyBg;
    for (final t in tiles) { if (t.dst.overlaps(view)) c.drawImageRect(t.img, t.src, t.dst, _bgP); }
    final fy = Lay.floorY;
    final ph = s.ph, wood = ph.wood;

    // ---------- pista ----------
    _add(0, -1e6, (c) => spr(c, 'aids${aidsTier(s.lvl('pista'))}', Lay.runwayX0, Lay.runwayZ, scale: _bounce('pista')));
    _hitWorld('pista', -60, -40, Lay.runwayZ - 4, Lay.runwayZ + 4);
    // ---------- check-in ----------
    final bc = _bounce('checkin');
    for (var d = 0; d < w.desks; d++) {
      final p = w.deskPos(d);
      _add(4, p.$1 + p.$2, (c) {
        spr(c, wood ? 'checkin_w' : const ['checkin', 'checkin', 'checkin_2', 'checkin_3'][visTier('checkin', s.lvl('checkin'))], p.$1, p.$2, y: fy, scale: bc);
        final pr = w.deskProgress(d);
        if (pr > 0 && zoom > 0.32) bar(c, iso(p.$1, p.$2, 3.4), 30, 5, pr, const Color(0xFF3FD46B));
      });
    }
    _hitWorld('checkin', Lay.checkinX0 - 1.2, Lay.checkinX0 + (math.max(w.desks, 2) - 1) * Lay.checkinDx + 1.2, Lay.checkinZ - 1.2, Lay.checkinZ + 1.4);
    // ---------- raio-x ----------
    final bs = _bounce('seguranca');
    final scan = s.lvl('seguranca') >= 20 && !wood;
    for (var l = 0; l < w.lanes; l++) {
      final p = w.lanePos(l);
      _add(4, p.$1 + p.$2, (c) {
        spr(c, wood ? 'security_w' : const ['security', 'security', 'security_2', 'security_3'][visTier('seguranca', s.lvl('seguranca'))], p.$1, p.$2, y: fy, scale: bs);
        if (scan) spr(c, 'bodyscan', p.$1 + 0.75, p.$2 - 0.2, y: fy, scale: bs);
        final pr = w.laneProgress(l);
        if (pr > 0 && zoom > 0.32) bar(c, iso(p.$1 + 0.5, p.$2, 3.4), 30, 5, pr, const Color(0xFF8F62F8));
      });
    }
    _hitWorld('seguranca', Lay.secX0 - 1.4, Lay.secX0 + (math.max(w.lanes, 2) - 1) * Lay.secDx + 2, Lay.secZ - 2.4, Lay.secZ + 2.4);
    // ---------- lojas (cada uma é construída e evolui sozinha) ----------
    for (var i = 0; i < shopIds.length; i++) {
      final id = shopIds[i], st = stationById(id), p = Lay.shops[i];
      if (p.$1 > ph.termX1 - 1.5) continue;
      if (s.built(id)) {
        final b = _bounce(id), t = visTier(id, s.lvl(id));
        _add(4, p.$1 + p.$2, (c) => spr(c, 'shop${i}_$t', p.$1, p.$2, y: fy, scale: b));
        _hitWorld(id, p.$1 - 1.9, p.$1 + 1.9, p.$2 - 1.8, p.$2 + 2.0, h: 2.5);
      } else if (s.unlockOk(st)) {
        _add(4, p.$1 + p.$2, (c) => spr(c, 'obra_s', p.$1, p.$2, y: fy));
        _hitWorld(id, p.$1 - 1.9, p.$1 + 1.9, p.$2 - 1.8, p.$2 + 2.0, h: 2);
      }
    }
    // ---------- enfeites por nível ----------
    for (final pr in props) {
      if (s.lvl(pr.st) < pr.lvl || pr.x > ph.termX1 - 0.8) continue;
      if (wood && (pr.sprite == 'ledboard' || pr.sprite == 'infodesk' || pr.sprite == 'atm' || pr.sprite == 'dog')) continue;
      final b = _bounce(pr.st);
      _add(4, pr.x + pr.z, (c) => spr(c, pr.sprite, pr.x, pr.z, y: fy, scale: b));
    }
    // ---------- VIP ----------
    if (s.built('vip')) { _add(4, Lay.vip.$1 + Lay.vip.$2, (c) => spr(c, 'vip${vipTier(s.lvl('vip'))}', Lay.vip.$1, Lay.vip.$2, y: fy, scale: _bounce('vip'))); }
    else if (s.starOk(stationById('vip'))) { _add(4, Lay.vip.$1 + Lay.vip.$2, (c) => spr(c, 'obra_m', Lay.vip.$1, Lay.vip.$2, y: fy)); }
    if (s.built('vip') || s.starOk(stationById('vip'))) _hitWorld('vip', Lay.vip.$1 - 4, Lay.vip.$1 + 4, Lay.vip.$2 - 3, Lay.vip.$2 + 3);
    // ---------- portões ----------
    for (var g = 0; g < 6; g++) {
      final gx = Lay.gates[g], id = 'g$g';
      if (s.built(id)) {
        final gt = gateVis(s.lvl(id));
        final b = _bounce(id);
        _add(4, gx - 2.6, (c) => spr(c, wood ? 'gatew${g + 1}' : 'gate${g + 1}_$gt', gx, -2.6, y: fy, scale: b));
        final G = s.gates[g];
        final pt = G.phase == Ph.empty ? s.tierFor(g) : G.tier;
        if (pt >= 1 && ph.bridges) {
          _add(1, gx - 5, (c) => spr(c, 'bridge$pt', gx, -5));
        } else if (G.phase == Ph.boarding) {
          final d = w.planeDoor(g, G.tier);
          _add(0, d.$1 + 1.4 + d.$2 + 0.6, (c) => spr(c, 'v_stairs_1', d.$1 + 1.4, d.$2));
        }
        if (s.lvl(id) >= 5 && !wood) _add(4, gx + 1.4, (c) => spr(c, 'plant', gx - 3.4, 1.4, y: fy));
        if (s.lvl(id) >= 20 && !wood) _add(4, gx + 4.2, (c) => spr(c, 'vending', gx + 4.4, -0.2, y: fy));
        // pilha de dinheiro
        if (s.pile[g] > 0) {
          final pp = w.pilePos(g), n = s.pile[g] > s.rate * 40 ? 3 : s.pile[g] > s.rate * 10 ? 2 : 1;
          _add(4, pp.$1 + pp.$2 + 0.5, (c) {
            final r = spr(c, 'cash$n', pp.$1, pp.$2, y: fy, scale: 1 + math.sin(w.t * 6 + g) * 0.04);
            if (r != null) hits.add(Hit(r.inflate(16), 'pile:$g', 0));
          });
        }
      } else if (s.starOk(stationById(id))) {
        _add(4, gx - 1.5, (c) => spr(c, 'obra_s', gx + 0.5, -1.2, y: fy));
      }
      if (s.built(id) || s.starOk(stationById(id))) _hitWorld(id, gx - 3.4, gx + 3, -3.8, 1.4);
      final pose = w.planePose(g);
      if (pose != null) _plane(g, pose);
    }
    if (s.shopPile > 0) {
      final pp = AirWorld.shopPilePos, n = s.shopPile > s.rate * 30 ? 3 : s.shopPile > s.rate * 8 ? 2 : 1;
      _add(4, pp.$1 + pp.$2 + 0.5, (c) { final r = spr(c, 'cash$n', pp.$1, pp.$2, y: fy); if (r != null) hits.add(Hit(r.inflate(16), 'pile:shop', 0)); });
    }
    _add(2, 0, (c) => spr(c, ['wall0', 'wall1', 'wall', 'wall'][s.phase], (Lay.termX0 + ph.termX1) / 2, -5));
    if (s.phase >= 1) _add(4, Lay.carousel.$1 + Lay.carousel.$2, (c) => spr(c, 'carousel', Lay.carousel.$1, Lay.carousel.$2, y: fy));
    // ---------- decoração ----------
    for (final d in decors) {
      if (!s.decor.contains(d.id)) continue;
      _add(3, d.x + d.z, (c) => spr(c, d.sprite, d.x, d.z, scale: _bounce(d.id)));
    }
    // ---------- prédio exclusivo da cidade ----------
    final esp = specialFor(s.city);
    if (s.phase >= 1 && (s.built(esp.id) || s.starOk(esp))) {
      final sx = Lay.special.$1, sz = Lay.special.$2, on = s.built(esp.id);
      _add(3, sx + sz, (c) => spr(c, on ? esp.icon : 'obra_m', sx, sz, scale: _bounce(esp.id)));
      _hitWorld(esp.id, sx - 4, sx + 4, sz - 3, sz + 3, h: 4);
      if (on && s.kind6 == 1 && s.hotelPile > s.hotelRate * 20) {
        final n = s.hotelPile > s.hotelRate * 300 ? 3 : s.hotelPile > s.hotelRate * 90 ? 2 : 1;
        _add(3, sx + sz + 6, (c) { final r = spr(c, 'cash$n', sx - 1.5, sz + 4.6); if (r != null) hits.add(Hit(r.inflate(18), 'pile:hotel', 0)); });
      }
      if (on && s.heliOn) {
        final hy = 1.2 + math.sin(w.t * 3) * 0.25;
        _add(5, sx + sz, (c) { c.drawOval(Rect.fromCenter(center: iso(sx, sz, 0.6), width: 60, height: 22), Paint()..color = const Color(0x33000000)); final r = spr(c, 'heli', sx, sz, y: hy); if (r != null) hits.add(Hit(r.inflate(26), 'heli', 0)); });
      }
    }
    // ---------- terminal de cargas ----------
    if (s.built('cargas') || s.starOk(stationById('cargas'))) {
      _add(3, Lay.cargo.$1 + Lay.cargo.$2, (c) => spr(c, s.built('cargas') ? 'cargo' : 'obra_l', Lay.cargo.$1, Lay.cargo.$2, scale: _bounce('cargas')));
      _hitWorld('cargas', Lay.cargo.$1 - 6, Lay.cargo.$1 + 6, Lay.cargo.$2 - 5, Lay.cargo.$2 + 5, h: 5);
    }
    // ---------- exterior ----------
    final be = _bounce('entrada');
    _add(3, Lay.parking.$1 + Lay.parking.$2 - 9, (c) => spr(c, wood ? 'parking0' : 'parking${parkTier(s.lvl('entrada'))}', Lay.parking.$1, Lay.parking.$2, scale: be));
    final nCars = parkCars(s.lvl('entrada'));
    for (var i = 0; i < nCars; i++) {
      final sl = AirWorld.parkSlots[i];
      _add(3, sl.$1 + sl.$2, (c) => spr(c, 'car${sl.$4}_${sl.$3}', sl.$1, sl.$2, scale: be));
    }
    _add(3, Lay.busStop.$1 + Lay.busStop.$2, (c) => spr(c, 'busstop', Lay.busStop.$1, Lay.busStop.$2));
    _hitWorld('entrada', Lay.parking.$1 - 13, Lay.parking.$1 + 13, Lay.parking.$2 - 6, Lay.parking.$2 + 6, h: 1);
    _add(3, Lay.tower.$1 + Lay.tower.$2, (c) => spr(c, wood ? 'tower0' : 'tower${towerTier(s.lvl('torre'))}', Lay.tower.$1, Lay.tower.$2, scale: _bounce('torre')));
    _hitWorld('torre', Lay.tower.$1 - 2.2, Lay.tower.$1 + 2.2, Lay.tower.$2 - 2.2, Lay.tower.$2 + 2.2, h: wood ? 9 : 16);
    if (s.built('hangar') || s.starOk(stationById('hangar'))) {
      _add(3, Lay.hangar.$1 + Lay.hangar.$2, (c) => spr(c, s.built('hangar') ? 'hangar' : 'obra_l', Lay.hangar.$1, Lay.hangar.$2, scale: _bounce('hangar')));
      _hitWorld('hangar', Lay.hangar.$1 - 6, Lay.hangar.$1 + 6, Lay.hangar.$2 - 5, Lay.hangar.$2 + 5, h: 5);
    }
    if (s.built('combustivel') || s.starOk(stationById('combustivel'))) {
      _add(3, Lay.fuel.$1 + Lay.fuel.$2, (c) => spr(c, s.built('combustivel') ? 'fuel' : 'obra_m', Lay.fuel.$1, Lay.fuel.$2, scale: _bounce('combustivel')));
      _hitWorld('combustivel', Lay.fuel.$1 - 4.5, Lay.fuel.$1 + 4.5, Lay.fuel.$2 - 3.5, Lay.fuel.$2 + 3.5, h: 3);
    }
    // ---------- construções extras ----------
    void extra(String id, (double, double) p, String obra, double hw, double hd, double h, void Function(Canvas) draw) {
      if (!s.built(id) && !s.starOk(stationById(id))) return;
      _add(3, p.$1 + p.$2, s.built(id) ? draw : (c) => spr(c, obra, p.$1, p.$2));
      _hitWorld(id, p.$1 - hw, p.$1 + hw, p.$2 - hd, p.$2 + hd, h: h);
    }
    extra('bombeiros', Lay.fire, 'obra_m', 5.5, 4.5, 5, (c) {
      spr(c, 'bombeiros', Lay.fire.$1, Lay.fire.$2, scale: _bounce('bombeiros'));
      if ((w.t * 1.6) % 1 < 0.5) { final o = iso(Lay.fire.$1 + 4.3, Lay.fire.$2 - 2.6, 7.1); c.drawCircle(o, 7, Paint()..color = const Color(0x66FF4E4E)); c.drawCircle(o, 3, Paint()..color = const Color(0xFFFF6B6B)); }
    });
    extra('radar', Lay.radar, 'obra_s', 3.5, 3.5, 6, (c) => spr(c, 'radar_${(w.t * 5).floor() % 8}', Lay.radar.$1, Lay.radar.$2, scale: _bounce('radar')));
    extra('catering', Lay.catering, 'obra_m', 5.5, 4.5, 4, (c) => spr(c, 'catering', Lay.catering.$1, Lay.catering.$2, scale: _bounce('catering')));
    extra('trem', Lay.trainSt, 'obra_m', 9, 4, 3.5, (c) => spr(c, 'trem', Lay.trainSt.$1, Lay.trainSt.$2, scale: _bounce('trem')));
    if (w.trainX > -900) {
      final tx = w.trainX, a = ((tx + 134) / 18).clamp(0.0, 1.0).toDouble();
      _add(3, tx + Lay.trainZ, (c) => spr(c, 'train', tx, Lay.trainZ, alpha: a));
    }
    extra('solar', Lay.solar, 'obra_l', 7, 5, 2, (c) {
      spr(c, 'solar', Lay.solar.$1, Lay.solar.$2, scale: _bounce('solar'));
      final g = (w.t * 0.25) % 1;
      if (g < 0.3) { final o = iso(Lay.solar.$1 - 6 + g / 0.3 * 12, Lay.solar.$2 - 1, 1.2); c.drawCircle(o, 10, Paint()..color = const Color(0x33FFFFFF)); c.drawCircle(o, 4, Paint()..color = const Color(0x88FFFFFF)); }
    });
    // ---------- passageiros ----------
    for (final a in w.agents) {
      final down = a.hx + a.hz >= 0, flip = a.hx - a.hz < 0;
      final f = a.moving ? '${(a.anim.floor()) % 4}' : 'i';
      final name = 'p${a.c}_${down ? 'd' : 'u'}_$f${a.bag ? 'b' : ''}';
      final y = a.y >= 0 ? a.y : (a.z > 16.2 || a.z < -5.0) ? 0.0 : fy;
      _add(a.outside ? 0 : 4, a.x + a.z + 0.3 + (a.y > 0 ? 1.6 : 0), (c) {
        if (a.gold) {
          final o = iso(a.x, a.z, y + 0.9), k = 1 + math.sin(w.t * 6) * 0.15;
          c.drawCircle(o, 26 * k, Paint()..color = const Color(0x55FFD54A));
          c.drawCircle(o, 15 * k, Paint()..color = const Color(0x88FFE27A));
          icon(c, 'coin', iso(a.x, a.z, y + 3.2 + math.sin(w.t * 4) * 0.15), 26);
          hits.add(Hit(Rect.fromCenter(center: o, width: 76, height: 86), 'gold:${a.hashCode}', 0));
        }
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
    _ambient(c);
    if (night > 0.01) _nightPass(c);
    if (s.snow) { _snow(c); } else if (rain > 0.02 || s.fogOn) { _weather(c); }
    if (s.snow && s.fogOn) c.drawRect(view, Paint()..color = const Color(0x88E8EEF5));
    if (!Cine.clean) _overlays(c);
  }

  /// Sombras de nuvens passando e bandos de pássaros (baratos: poucos desenhos por quadro).
  void _ambient(Canvas c) {
    final day = (1 - night * 1.2).clamp(0.0, 1.0).toDouble();
    if (day <= 0.02) return;
    // sombras de nuvens: gradiente grande cobrindo a tela é caro no navegador do celular
    if (!kIsWeb) for (var i = 0; i < 4; i++) {
      const span = 5200.0;
      final x = -2600 + ((w.t * (16 + i * 5) + i * 1370) % span);
      final y = -1100 + i * 520 + math.sin(w.t * 0.05 + i) * 80;
      final rect = Rect.fromCenter(center: Offset(x, y), width: 1000 + i * 140, height: 420 + i * 50);
      if (!rect.overlaps(view)) continue;
      c.drawOval(rect, Paint()..shader = RadialGradient(colors: [Color.fromRGBO(16, 34, 64, 0.11 * day), Color.fromRGBO(16, 34, 64, 0.06 * day), const Color(0x00102240)], stops: const [0, 0.55, 1]).createShader(rect));
    }
    final cyc = w.t % 45;
    if (cyc < 18 && !s.snow) {
      final k = cyc / 18, x0 = -2800 + k * 5600, y0 = -1500 + k * 1100 + math.sin(k * 6) * 40;
      final p = Paint()..color = Color.fromRGBO(43, 50, 69, 0.75 * day)..strokeWidth = 2.6..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final o = Offset(x0 - i * 38, y0 + (i.isEven ? i * 16 : -i * 13));
        if (!view.inflate(40).contains(o)) continue;
        final f = math.sin(w.t * 9 + i * 1.3) * 6;
        c.drawPath(Path()..moveTo(o.dx - 11, o.dy - f)..quadraticBezierTo(o.dx - 5, o.dy - 4, o.dx, o.dy)..quadraticBezierTo(o.dx + 5, o.dy - 4, o.dx + 11, o.dy - f), p);
      }
    }
  }

  void _plane(int g, Pose pose) {
    final G = s.gates[g];
    var idx = (((pose.heading / (math.pi / 8)).round()) % 16 + 16) % 16;
    var flip = false;
    if (idx < 2 || idx > 10) { idx = ((4 - idx) % 16 + 16) % 16; flip = true; }
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
      final r = spr(c, name, p.x, p.z, y: p.y, scale: scale, flip: flip);
      if (r != null) hits.add(Hit(r.deflate(r.width * 0.18), G.vip && !G.vipTapped && G.phase == Ph.boarding ? 'vip:$g' : 'plane:$g', 2));
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
    hits.add(Hit(Rect.fromLTRB(l, t, r, b), id, 3));
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

  /// Neve caindo (Serra Alta).
  void _snow(Canvas c) {
    final p = Paint()..color = const Color(0xDDFFFFFF);
    final rr = math.Random(11);
    final h = view.height, wd = view.width;
    for (var i = 0; i < 110; i++) {
      final sp = 0.5 + rr.nextDouble() * 0.7, ph0 = rr.nextDouble() * 6.28;
      final x = view.left + ((rr.nextDouble() * wd + math.sin(w.t * 0.8 + ph0) * 26 / zoom) % wd);
      final y = view.top + ((rr.nextDouble() * h + w.t * 120 * sp / zoom) % h);
      c.drawCircle(Offset(x, y), (1.6 + sp * 1.6) / zoom, p);
    }
  }

  void _nightPass(Canvas c) {
    c.drawRect(view, Paint()..color = Color.fromRGBO(18, 28, 70, night * 0.62));
    final glow = Paint()..blendMode = BlendMode.plus;
    final a = night;
    final ph = s.ph;
    for (var x = Lay.runwayX0; x <= ph.rx1; x += 4) {
      for (final z in [Lay.runwayZ - 4.2, Lay.runwayZ + 4.2]) { final o = iso(x, z); if (!view.contains(o)) continue; glow.color = Color.fromRGBO(255, 240, 200, 0.55 * a); c.drawCircle(o, 4, glow); glow.color = Color.fromRGBO(255, 230, 170, 0.18 * a); c.drawCircle(o, 11, glow); }
    }
    for (var x = Lay.connL; x <= ph.connR; x += 4) { final o = iso(x, Lay.laneZ); glow.color = Color.fromRGBO(80, 160, 255, 0.5 * a); c.drawCircle(o, 3.5, glow); }
    for (var z = Lay.runwayZ; z <= Lay.laneZ; z += 3) { for (final x in [Lay.connL, ph.connR]) { final o = iso(x, z); glow.color = Color.fromRGBO(80, 220, 120, 0.5 * a); c.drawCircle(o, 3.5, glow); } }
    for (var x = Lay.termX0 + 3; x < ph.termX1; x += 7) {
      for (final z in [-2.0, 6.0, 13.0]) { final o = iso(x, z, 0.5); glow.color = Color.fromRGBO(255, 214, 140, 0.16 * a); c.drawCircle(o, 70, glow); }
    }
    for (var x = -86.0; x < (ph.wood ? 10.0 : ph.termX1 + 20); x += ph.wood ? 10 : 12) { final o = iso(ph.wood ? x + 6 : x, Lay.roadZ + 3.4, ph.wood ? 3.0 : 2.6); glow.color = Color.fromRGBO(255, 230, 160, 0.35 * a); c.drawCircle(o, 16, glow); glow.color = Color.fromRGBO(255, 240, 200, 0.7 * a); c.drawCircle(o, 3, glow); }
    final tt = iso(Lay.tower.$1, Lay.tower.$2, ph.wood ? 5.8 : [9.5, 13.5, 17.5][towerTier(s.lvl('torre')) - 1]);
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
    // próxima estrela: nuvem + selo nas áreas que ela libera
    for (final st in stations) {
      if (!s.here(st) || s.built(st.id) || s.starOk(st) || st.star != s.star + 1) continue;
      if (st.only >= 0 && phaseFor(s.city, st.star) < 1) continue;
      final cc = w.stationCenter(st.id);
      final o = iso(cc.$1, cc.$2, 1.5);
      if (!view.inflate(120).contains(o)) continue;
      for (var i = 0; i < 3; i++) { icon(c, 'cloud', o + Offset(math.cos(i * 2.1 + t * 0.15) * 30 * k, math.sin(i * 2.3) * 10 * k - 8 * k), (60 + i * 10) * k, 0.85); }
      final r = plate(c, '${st.star}', o + Offset(0, -4 * k), 12 * k, const Color(0xFF7C5CFA), ico: 'star');
      hits.add(Hit(r.inflate(20), st.id, 1));
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
      final near = zoom >= 0.6;
      if (!s.built(st.id)) {
        final can = s.canUnlock(st);
        if (!can && !near && !isBest) continue;
        final r = plate(c, '\$${fmt(st.unlock)}', at, 13 * k, can ? const Color(0xFF22B573) : const Color(0xFF7A8499), ico: can ? 'coin' : 'lock', solid: can);
        hits.add(Hit(r.inflate(12), st.id, 1));
        if (can) { final bob = math.sin(t * 4) * 3 * k; _arrow(c, Offset(at.dx, r.top - 14 * k + bob), 11 * k, const Color(0xFF22B573)); }
        continue;
      }
      if (st.oneTime) continue;
      final up = s.canUp(st);
      final sel = selected == st.id;
      final bott = s.bottleneck == st.id || (s.bottleneck == 'gates' && st.kind == Kind.gate && st.gate == 0);
      // longe: só o essencial (selecionado, melhor compra e gargalo); o resto vira um selo pequeno de "dá pra melhorar"
      if (!near && !sel && !isBest && !(bott && s.rate > 0)) {
        if (up) {
          c.drawCircle(at + Offset(0, 1.5 * k), 10 * k, Paint()..color = const Color(0x33141A33));
          c.drawCircle(at, 10 * k, Paint()..color = Colors.white);
          c.drawCircle(at, 7.8 * k, Paint()..color = const Color(0xFF22B573));
          _arrow(c, at, 5 * k, Colors.white);
          hits.add(Hit(Rect.fromCircle(center: at, radius: 22 * k), st.id, 1));
        }
        continue;
      }
      final r = plate(c, 'Nv ${s.lvl(st.id)}', at, 11.5 * k, sel ? const Color(0xFFFF9F1C) : isBest ? const Color(0xFF22B573) : const Color(0xFF2F6BFF), solid: sel || isBest);
      hits.add(Hit(r.inflate(14), st.id, 1));
      // quanto falta para o próximo marco (x2 e evolução visual)
      final nm = nextMilestone(s.lvl(st.id));
      if (nm != null && zoom > 0.3) {
        final pm = milestones.lastWhere((m) => m <= s.lvl(st.id), orElse: () => 0);
        final v = (s.lvl(st.id) - pm) / (nm - pm);
        final br = RRect.fromRectAndRadius(Rect.fromLTWH(r.left + 3 * k, r.bottom + 2 * k, r.width - 6 * k, 3.5 * k), Radius.circular(2 * k));
        c.drawRRect(br, Paint()..color = const Color(0xCCFFFFFF));
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(br.left, br.top, br.width * v.clamp(0.04, 1.0), br.height), Radius.circular(2 * k)), Paint()..color = const Color(0xFFFFB627));
      }
      if (up) {
        final uo = Offset(r.right + 2 * k, r.top + 1 * k);
        c.drawCircle(uo, 8.5 * k, Paint()..color = const Color(0xFF22B573));
        _arrow(c, uo, 5.5 * k, Colors.white);
      }
      if (isBest && hint == null) { final bob = math.sin(t * 4) * 4 * k; _arrow(c, Offset(r.center.dx, r.top - 16 * k + bob), 12 * k, const Color(0xFF22B573), down: true); }
      if (bott && s.rate > 0) {
        final bo = Offset(r.left - 1 * k, r.top + 1 * k);
        c.drawCircle(bo, 8 * k, Paint()..color = Colors.white);
        c.drawCircle(bo, 6.5 * k, Paint()..color = const Color(0xFFFF4D5E));
        final tp = _plain('!', 9 * k, Colors.white); tp.paint(c, bo - Offset(tp.width / 2, tp.height / 2));
      }
    }
    // dica do tutorial
    if (hint != null) {
      final cc = hint == 'pile' ? (w.pilePos(0).$1, w.pilePos(0).$2, 1.5) : w.stationCenter(hint!);
      final o = iso(cc.$1, cc.$2, cc.$3) - Offset(0, 34 * k + math.sin(t * 5) * 7 * k);
      c.drawCircle(o, 22 * k, Paint()..color = const Color(0x33141A33));
      c.drawCircle(o - Offset(0, 2 * k), 21 * k, Paint()..color = const Color(0xFFFF9F1C));
      _arrow(c, o - Offset(0, 2 * k), 12 * k, Colors.white, down: true);
    }
    // evento ativo
    final e = s.ev;
    if (e != null) {
      final o = iso(e.x, e.z, 4) + Offset(0, math.sin(t * 3) * 5 * k);
      final ic = {'celeb': 'celeb', 'bag': 'suitcase', 'tourists': 'rush', 'fog': 'cloud'}[e.type] ?? 'gift';
      final rad = 30 * k;
      c.drawCircle(o + Offset(0, 4 * k), rad, Paint()..color = const Color(0x33141A33));
      c.drawCircle(o, rad, Paint()..color = Colors.white);
      final left = (e.until - s.clock).clamp(0.0, 99.0).toDouble() / (e.type == 'fog' ? 45 : 30);
      c.drawArc(Rect.fromCircle(center: o, radius: rad - 2.5 * k), -math.pi / 2, math.pi * 2 * left, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 4 * k..strokeCap = StrokeCap.round..color = const Color(0xFFFF9F1C));
      icon(c, ic, o, 40 * k);
      if (e.type == 'fog') plate(c, 'TOQUE ${5 - e.taps}x', o + Offset(0, rad + 14 * k), 11 * k, const Color(0xFFFF4D5E), solid: true);
      hits.add(Hit(Rect.fromCenter(center: o, width: 90 * k, height: 90 * k), 'ev', 0));
    }
    // VIP: brilho para tocar
    for (var g = 0; g < 6; g++) {
      final G = s.gates[g];
      if (!G.vip || G.vipTapped || G.phase != Ph.boarding) continue;
      final o = iso(Lay.gates[g], Routes.parkZ(G.tier), 6) + Offset(0, math.sin(t * 4) * 5 * k);
      c.drawCircle(o + Offset(0, 3 * k), 24 * k, Paint()..color = const Color(0x33141A33));
      c.drawCircle(o, 24 * k, Paint()..color = Colors.white);
      icon(c, 'gem', o, 32 * k);
      hits.add(Hit(Rect.fromCenter(center: o, width: 80 * k, height: 80 * k), 'vip:$g', 0));
    }
    for (final f in w.floaters) {
      final o = iso(f.x, f.z, f.y0 + f.t * 3.2);
      final a = (1 - (f.t - 1.2).clamp(0.0, 0.6) / 0.6).toDouble();
      if (a <= 0) continue;
      final sc = f.t < 0.18 ? Curves.easeOutBack.transform(f.t / 0.18) : 1.0;
      final tp = _text(f.text, (15 * f.big * k).roundToDouble(), f.color, const Color(0xCC1E2A47));
      c.save();
      c.translate(o.dx, o.dy); c.scale(sc);
      c.saveLayer(Rect.fromLTWH(-tp.width / 2 - 4, -tp.height / 2 - 4, tp.width + 8, tp.height + 8), Paint()..color = Color.fromRGBO(0, 0, 0, a));
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore(); c.restore();
    }
  }

  /// Seta simples (para cima ou para baixo) desenhada com caminho.
  void _arrow(Canvas c, Offset at, double s0, Color col, {bool down = false}) {
    final d = down ? -1.0 : 1.0;
    final p = Path()
      ..moveTo(at.dx, at.dy - s0 * d)
      ..lineTo(at.dx + s0 * 0.9, at.dy)
      ..lineTo(at.dx + s0 * 0.35, at.dy)
      ..lineTo(at.dx + s0 * 0.35, at.dy + s0 * 0.85 * d)
      ..lineTo(at.dx - s0 * 0.35, at.dy + s0 * 0.85 * d)
      ..lineTo(at.dx - s0 * 0.35, at.dy)
      ..lineTo(at.dx - s0 * 0.9, at.dy)
      ..close();
    c.drawPath(p, Paint()..color = col..isAntiAlias = true);
  }
}
