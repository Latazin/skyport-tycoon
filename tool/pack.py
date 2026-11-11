"""Empacota a arte renderizada em atlas para o jogo.
Saída: assets/images/art/{atlas_N.png, bg/*.jpg, icons/*.png, meta.json} e assets/images/{icon,icon_fg,keyart,feature}."""
import json, os, glob, shutil
from PIL import Image

T = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(T, 'out')
ART = os.path.join(T, '..', 'assets', 'images', 'art')
IMG = os.path.join(T, '..', 'assets', 'images')
PAGE = 2048
raw = json.load(open(os.path.join(OUT, 'raw.json')))
shutil.rmtree(ART, ignore_errors=True)
os.makedirs(os.path.join(ART, 'bg'), exist_ok=True)
os.makedirs(os.path.join(ART, 'icons'), exist_ok=True)

# ---------- atlas (prateleiras, maiores primeiro) ----------
items = []
for name, m in raw['sprites'].items():
    f = os.path.join(OUT, 'sprites', name + '.png')
    if os.path.exists(f): items.append((name, Image.open(f).convert('RGBA'), m))
items.sort(key=lambda t: (-t[1].height, -t[1].width))
pages, placed = [], {}
def new_page(): pages.append({'img': Image.new('RGBA', (PAGE, PAGE), (0, 0, 0, 0)), 'x': 0, 'y': 0, 'rowh': 0})
new_page()
for name, im, m in items:
    if im.width > PAGE or im.height > PAGE:
        s = min(PAGE / im.width, PAGE / im.height) * 0.999
        im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
        m = dict(m, ax=m['ax'] * s, ay=m['ay'] * s, k=m['k'] * s)
    ok = False
    for pi, p in enumerate(pages):
        x, y, rh = p['x'], p['y'], p['rowh']
        if x + im.width > PAGE: x, y, rh = 0, y + rh + 2, 0
        if y + im.height <= PAGE:
            p['img'].paste(im, (x, y)); p['x'], p['y'], p['rowh'] = x + im.width + 2, y, max(rh, im.height)
            placed[name] = [pi, x, y, im.width, im.height, round(m['ax'], 2), round(m['ay'], 2), round(m['k'], 4)]
            ok = True; break
    if not ok:
        new_page(); p = pages[-1]
        p['img'].paste(im, (0, 0)); p['x'], p['y'], p['rowh'] = im.width + 2, 0, im.height
        placed[name] = [len(pages) - 1, 0, 0, im.width, im.height, round(m['ax'], 2), round(m['ay'], 2), round(m['k'], 4)]
page_files = []
for i, p in enumerate(pages):
    used_h = min(PAGE, p['y'] + p['rowh'] + 2)
    img = p['img'].crop((0, 0, PAGE, used_h))
    fn = 'atlas_%d.png' % i; img.save(os.path.join(ART, fn), optimize=True); page_files.append(fn)

# ---------- fundos em blocos ----------
bg = {}
for key, m in raw['bg'].items():
    im = Image.open(os.path.join(OUT, 'bg', key + '.jpg')).convert('RGB')
    k = m['k']; tiles = []
    tw, th = (im.width + 1) // 2, (im.height + 1) // 2
    for j in range(2):
        for i in range(2):
            box = (i * tw, j * th, min(im.width, (i + 1) * tw + 2), min(im.height, (j + 1) * th + 2))
            fn = '%s_%d%d.jpg' % (key, i, j)
            im.crop(box).save(os.path.join(ART, 'bg', fn), quality=86, optimize=True)
            # retângulo em pixels do mundo (S=24, k=1)
            tiles.append({'file': fn, 'x': round((box[0] - m['ax']) / k, 2), 'y': round((box[1] - m['ay']) / k, 2), 'w': round((box[2] - box[0]) / k, 2), 'h': round((box[3] - box[1]) / k, 2)})
    bg[key] = tiles

icons = []
for f in sorted(glob.glob(os.path.join(OUT, 'icons', '*.png'))):
    im = Image.open(f).convert('RGBA'); bb = im.getbbox()
    if bb: im = im.crop(bb)
    s = 128 / max(im.size); im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    c = Image.new('RGBA', (136, 136)); c.paste(im, ((136 - im.width) // 2, (136 - im.height) // 2))
    n = os.path.basename(f)[:-4]; c.save(os.path.join(ART, 'icons', n + '.png'), optimize=True); icons.append(n)

meta = {'S': 24, 'pages': page_files, 'sprites': placed, 'bg': bg, 'icons': icons, 'layout': raw['layout'], 'planes': raw['planes']}
json.dump(meta, open(os.path.join(ART, 'meta.json'), 'w'), separators=(',', ':'))

ic = Image.open(os.path.join(OUT, 'misc', 'icon.png')).convert('RGB')
ic.save(os.path.join(IMG, 'icon.png'))
fg = Image.open(os.path.join(OUT, 'misc', 'icon_fg.png')).convert('RGBA')
# primeiro plano do ícone adaptativo: miolo seguro (66%)
pad = Image.new('RGBA', (1024, 1024)); f2 = fg.resize((676, 676), Image.LANCZOS); pad.paste(f2, (174, 174), f2); pad.save(os.path.join(IMG, 'icon_fg.png'))
splash = fg.resize((512, 512), Image.LANCZOS); splash.save(os.path.join(IMG, 'splash.png'))
Image.open(os.path.join(OUT, 'misc', 'keyart.jpg')).save(os.path.join(IMG, 'keyart.jpg'), quality=85)
Image.open(os.path.join(OUT, 'misc', 'feature.jpg')).save(os.path.join(IMG, 'feature_graphic.jpg'), quality=90)
print('páginas', len(pages), 'sprites', len(placed), 'ícones', len(icons))
