import sys, glob, os
from PIL import Image
files = sorted(sum([glob.glob(a) for a in sys.argv[2:]], []))
ims = [Image.open(f).convert('RGBA') for f in files]
W = 1400; x = y = rowh = 0; pos = []
for im in ims:
    s = min(1, 340 / max(im.width, im.height)) if len(ims) > 6 else min(1, 700/max(im.width, im.height))
    im2 = im.resize((max(1,int(im.width*s)), max(1,int(im.height*s))))
    if x + im2.width > W: x = 0; y += rowh + 6; rowh = 0
    pos.append((im2, x, y)); x += im2.width + 6; rowh = max(rowh, im2.height)
out = Image.new('RGBA', (W, y + rowh + 4), (200, 215, 190, 255))
for im, x, y in pos: out.alpha_composite(im, (x, y))
out.convert('RGB').save(sys.argv[1])
