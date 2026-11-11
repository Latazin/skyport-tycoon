import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flutter/services.dart';

/// Sprite pré-renderizado: imagem do atlas, recorte, âncora e escala (k pixels por pixel do mundo).
class Spr {
  final ui.Image img;
  final ui.Rect src;
  final double ax, ay, k;
  const Spr(this.img, this.src, this.ax, this.ay, this.k);
  double get w => src.width / k;
  double get h => src.height / k;
}

class BgTile {
  final ui.Image img;
  final ui.Rect dst;
  const BgTile(this.img, this.dst);
  ui.Rect get src => ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
}

/// Banco de arte: sprites renderizados em 3D pelo estúdio (tool/studio).
class Art {
  static final Map<String, Spr> spr = {};
  static final Map<int, List<BgTile>> bg = {};
  static final Map<String, ui.Image> icons = {};
  static bool ready = false;

  static Future<void> load(void Function(double) progress) async {
    final meta = jsonDecode(await rootBundle.loadString('assets/images/art/meta.json')) as Map<String, dynamic>;
    final pages = (meta['pages'] as List).cast<String>();
    final sprites = meta['sprites'] as Map<String, dynamic>;
    final bgs = meta['bg'] as Map<String, dynamic>;
    final iconNames = (meta['icons'] as List).cast<String>();
    final total = pages.length + iconNames.length + 4;
    var done = 0;
    void tick() => progress(++done / total);
    final imgs = <ui.Image>[];
    for (final p in pages) { imgs.add(await Flame.images.load('art/$p')); tick(); }
    for (final e in sprites.entries) {
      final a = (e.value as List).map((v) => (v as num).toDouble()).toList();
      spr[e.key] = Spr(imgs[a[0].toInt()], ui.Rect.fromLTWH(a[1], a[2], a[3], a[4]), a[5], a[6], a[7]);
    }
    await Future.wait([for (final n in iconNames) Flame.images.load('art/icons/$n.png').then((img) { icons[n] = img; tick(); })]);
    // só o fundo da primeira cidade agora; os outros sob demanda
    await loadBg(0, bgs);
    _bgMeta = bgs;
    tick();
    ready = true;
    progress(1);
  }

  static Map<String, dynamic> _bgMeta = {};
  static Future<void> loadBg(int i, [Map<String, dynamic>? m]) async {
    if (bg.containsKey(i)) return;
    final tiles = ((m ?? _bgMeta)['bg$i'] as List?) ?? [];
    final list = <BgTile>[];
    for (final t in tiles) {
      final img = await Flame.images.load('art/bg/${t['file']}');
      list.add(BgTile(img, ui.Rect.fromLTWH((t['x'] as num).toDouble(), (t['y'] as num).toDouble(), (t['w'] as num).toDouble(), (t['h'] as num).toDouble())));
    }
    bg[i] = list;
  }
}
