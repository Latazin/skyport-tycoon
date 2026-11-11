import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../core/data.dart';
import '../core/state.dart';
import 'renderer.dart';
import 'world.dart';

/// Jogo Flame: câmera isométrica, simulação e desenho do aeroporto.
class SkyGame extends FlameGame {
  final GameState s;
  late final AirWorld w;
  late final SceneRenderer scene;
  SkyGame(this.s) { w = AirWorld(s); scene = SceneRenderer(w, s); }

  Vector2? _camTarget;
  double? _zoomTarget;
  Vector2 vel = Vector2.zero();
  bool dragging = false;
  void Function(String id)? onTap;
  void Function()? onAutosave;
  static const minZoom = 0.2, maxZoom = 1.25;

  @override
  Color backgroundColor() => const Color(0xFF6FB352);

  @override
  Future<void> onLoad() async {
    world.add(scene);
    camera.viewfinder.anchor = Anchor.center;
    final first = s.tut < 2;
    camera.viewfinder.zoom = (size.x / (first ? 760 : 980)).clamp(0.3, 0.9);
    final o = first ? iso(-33, 9, 2) : iso(-14, 2);
    camera.viewfinder.position = Vector2(o.dx, o.dy);
    for (var i = 0; i < 6; i++) { Future.delayed(Duration(milliseconds: 400 * i), () => w.spawnAt(Lay.door.$1 + i * 0.5, 17)); }
  }

  double get zoom => camera.viewfinder.zoom;
  set zoom(double z) { camera.viewfinder.zoom = z.clamp(minZoom, maxZoom).toDouble(); _clamp(); }

  Vector2 screenToWorld(Offset o) {
    final vf = camera.viewfinder;
    return Vector2((o.dx - size.x / 2) / vf.zoom + vf.position.x, (o.dy - size.y / 2) / vf.zoom + vf.position.y);
  }
  Offset worldToScreen(Offset p) {
    final vf = camera.viewfinder;
    return Offset((p.dx - vf.position.x) * vf.zoom + size.x / 2, (p.dy - vf.position.y) * vf.zoom + size.y / 2);
  }
  void panBy(Offset d) { _camTarget = null; final vf = camera.viewfinder; vf.position = vf.position - Vector2(d.dx, d.dy) / vf.zoom; _clamp(); }
  void zoomAt(Offset focal, double factor) {
    final before = screenToWorld(focal);
    zoom = zoom * factor; _zoomTarget = null;
    final after = screenToWorld(focal);
    camera.viewfinder.position = camera.viewfinder.position + (before - after); _camTarget = null; _clamp();
  }
  void _clamp() { final p = camera.viewfinder.position; camera.viewfinder.position = Vector2(p.x.clamp(-1900.0, 1900.0), p.y.clamp(-900.0, 900.0)); }
  /// Centraliza uma estação (com espaço para o painel de baixo).
  void focusStation(String id, {bool sheet = false}) {
    final c = w.stationCenter(id);
    final o = iso(c.$1, c.$2, c.$3 * 0.5);
    final z = math.max(zoom, 0.55);
    _zoomTarget = z;
    _camTarget = Vector2(o.dx, o.dy + (sheet ? size.y * 0.2 / z : 0));
  }
  void focusWorld(double x, double z, {double? zoomTo}) { final o = iso(x, z); _camTarget = Vector2(o.dx, o.dy); _zoomTarget = zoomTo; }

  /// Toque no mundo: presentes, aviões, estações.
  void tapAt(Offset screen) {
    final p = screenToWorld(screen), o = Offset(p.x, p.y);
    for (final h in scene.hits.reversed) {
      if (!h.r.contains(o)) continue;
      onTap?.call(h.id);
      return;
    }
    onTap?.call('none');
  }

  double _saveT = 0;

  @override
  void update(double dt) {
    final step = math.min(dt, 0.1);
    super.update(step);
    s.tick(step);
    w.update(step);
    final vf = camera.viewfinder;
    if (_zoomTarget != null) {
      final dz = _zoomTarget! - vf.zoom;
      if (dz.abs() < 0.005) { _zoomTarget = null; } else { vf.zoom = vf.zoom + dz * math.min(1.0, step * 5); }
    }
    if (_camTarget != null) {
      final d = _camTarget! - vf.position;
      if (d.length < 2) { _camTarget = null; } else { vf.position = vf.position + d * math.min(1.0, step * 5); }
    } else if (!dragging && vel.length > 5) {
      vf.position = vf.position - vel * step / vf.zoom; vel.scale(math.pow(0.03, step).toDouble()); _clamp();
    }
    final a = screenToWorld(Offset.zero), b = screenToWorld(Offset(size.x, size.y));
    scene.view = Rect.fromLTRB(a.x, a.y, b.x, b.y).inflate(160);
    scene.zoom = zoom;
    _saveT += step;
    if (_saveT > 10) { _saveT = 0; onAutosave?.call(); }
  }
}
