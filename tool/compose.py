"""Prévia da cena montada a partir dos sprites (mesma projeção do jogo).
uso: python3 tool/compose.py saida.png [cidade] [cx cz zoom w h]"""
import json, math, sys, os
from PIL import Image
D = os.path.join(os.path.dirname(__file__), 'out')
raw = json.load(open(os.path.join(D, 'raw.json')))
L = raw['layout']; PL = raw['planes']
S = 24
def iso(x, y, z): return ((x - z) * 0.70710678 * S, ((x + z) * 0.35355339 - y * 0.8660254) * S)

city = int(sys.argv[2]) if len(sys.argv) > 2 else 0
cx, cz, zoom, W, H = (float(v) for v in (sys.argv[3:8] if len(sys.argv) > 7 else (-8, 2, 0.5, 780, 1688)))
W, H = int(W), int(H)
items = []  # (camada, profundidade, nome, x, y, z)
def add(name, x, z, y=0.0, layer=1, depth=None): items.append((layer, x + z if depth is None else depth, name, x, y, z))
FLOOR = 0.35
for i in range(6): add('checkin', L['checkin']['x0'] + i * L['checkin']['dx'], L['checkin']['z'], FLOOR, 2)
for i in range(4): add('security', L['security']['x0'] + i * L['security']['dx'], L['security']['z'], FLOOR, 2)
for i, s in enumerate(L['shops']): add('shop%d' % i, s['x'], s['z'], FLOOR, 2)
add('vip3', L['vip']['x'], L['vip']['z'], FLOOR, 2)
for i, gx in enumerate(L['gates']):
    t = [3, 3, 2, 2, 1, 1][i]
    add('gate%d_%d' % (i + 1, t), gx, -2.6, FLOOR, 2)
    if t >= 2:
        pt = t - 1
        add('pl%d_%d_0' % (pt, i % 3), gx, L['standNose'] - PL[pt]['len'] / 2, 0, 0)
        add('bridge%d' % pt, gx, -5, 0, 1)
    else:
        add('obra_m', gx, -12, 0, 0)
add('wall', (L['term']['x0'] + L['term']['x1']) / 2, -5, 0, 1)
add('parking4', L['parking']['x'], L['parking']['z'], 0, 1)
add('busstop', L['busStop']['x'], L['busStop']['z'], 0, 1)
add('tower3', L['tower']['x'], L['tower']['z'], 0, 1)
add('fuel', L['fuel']['x'], L['fuel']['z'], 0, 1)
add('hangar', L['hangar']['x'], L['hangar']['z'], 0, 1)
add('aids3', L['runway']['x0'], L['runway']['z'], 0, 0)
add('pl1_1_2', 10, -37, 0, 0)
add('pa2_0_2', -20, -37, 14, 3)
add('v_bus_1', -12, 19, 0, 1)
add('v_tug_1', -30, -15, 0, 0)
import random
random.seed(3)
for k in range(60):
    x = random.uniform(-44, 30); z = random.uniform(-4, 14)
    add('p%d_%s_%s%s' % (k % 8, random.choice('du'), random.choice('0123i'), random.choice(['', 'b'])), x, z, FLOOR, 2)

bgm = raw['bg']['bg%d' % city]
bg = Image.open(os.path.join(D, 'bg', 'bg%d.jpg' % city)).convert('RGBA')
# mundo -> tela
ox, oy = iso(cx, 0, cz)
def to_screen(px, py): return ((px - ox) * zoom + W / 2, (py - oy) * zoom + H / 2)
out = Image.new('RGBA', (W, H), (124, 198, 90, 255))
kb = bgm['k']
bx, by = to_screen(-bgm['ax'] / kb, -bgm['ay'] / kb)
bgs = bg.resize((int(bg.width / kb * zoom), int(bg.height / kb * zoom)))
out.alpha_composite(bgs, (int(bx), int(by))) if bx >= 0 and by >= 0 else out.paste(bgs, (int(bx), int(by)), bgs)
cache = {}
for layer, dep, name, x, y, z in sorted(items):
    m = raw['sprites'].get(name)
    if not m: print('falta', name); continue
    im = cache.get(name) or Image.open(os.path.join(D, 'sprites', name + '.png')).convert('RGBA')
    cache[name] = im
    k = m['k']; px, py = iso(x, y, z)
    sx, sy = to_screen(px - m['ax'] / k, py - m['ay'] / k)
    w, h = int(im.width / k * zoom), int(im.height / k * zoom)
    if w < 1 or h < 1: continue
    imr = im.resize((w, h), Image.LANCZOS)
    out.paste(imr, (int(sx), int(sy)), imr)
out.convert('RGB').save(sys.argv[1])
