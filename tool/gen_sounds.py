"""Gera os efeitos sonoros e a música do SkyPort (síntese simples, 22 kHz mono)."""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=None, curve=4.0):
    x = np.ones(n); na = max(1, int(a * SR)); x[:na] = np.linspace(0, 1, na)
    tail = np.linspace(1, 0, n - na) ** curve if r is None else np.ones(n - na)
    x[na:] *= tail; return x
def note(f, d, kind='sine', vol=0.5, curve=3.0, a=0.004):
    x = t(d); ph = 2 * np.pi * np.cumsum(np.full(len(x), f) if np.isscalar(f) else f) / SR
    if kind == 'sine': w = np.sin(ph)
    elif kind == 'tri': w = 2 / np.pi * np.arcsin(np.sin(ph))
    elif kind == 'square': w = np.sign(np.sin(ph)) * 0.6
    elif kind == 'bell': w = np.sin(ph) + 0.4 * np.sin(2.76 * ph) + 0.2 * np.sin(5.4 * ph)
    else: w = np.sin(ph)
    return w * env(len(x), a, curve=curve) * vol
def noise(d, vol=0.5, lp=0.2, curve=3.0):
    n = rng.standard_normal(int(SR * d)); y = np.zeros_like(n); acc = 0.0
    for i in range(len(n)): acc += lp * (n[i] - acc); y[i] = acc
    y /= (np.abs(y).max() + 1e-9); return y * env(len(y), 0.003, curve=curve) * vol
def mix(*parts):
    n = max(len(p[1]) + int(p[0] * SR) for p in parts); y = np.zeros(n)
    for off, s in parts: o = int(off * SR); y[o:o + len(s)] += s
    return y
def save(name, y, vol=0.9):
    y = np.asarray(y, dtype=float); m = np.abs(y).max() or 1; y = y / m * vol
    f = 8 if len(y) > 400 else 1
    y[-int(SR*0.004):] *= np.linspace(1, 0, int(SR*0.004))
    with wave.open(os.path.join(OUT, name + '.wav'), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((y * 32767).astype(np.int16).tobytes())
N = lambda m: 440 * 2 ** ((m - 69) / 12)

save('click', note(1300, 0.045, 'sine', curve=2), 0.6)
save('tick', note(2100, 0.03, 'sine', curve=2), 0.5)
save('coin', mix((0, note(N(88), 0.08, 'square', curve=1.5)), (0.06, note(N(93), 0.16, 'square', curve=2.5))), 0.55)
save('cash', mix((0, noise(0.08, 0.6, 0.6)), (0.05, note(N(96), 0.35, 'bell', curve=3)), (0.09, note(N(100), 0.32, 'bell', curve=3))), 0.7)
save('build', mix(*[(i * 0.17, noise(0.09, 0.8, 0.12, 5)) for i in range(3)], (0.55, note(N(84), 0.15, 'tri')), (0.62, note(N(88), 0.15, 'tri')), (0.69, note(N(91), 0.25, 'tri'))), 0.8)
save('up', mix(*[(i * 0.045, note(N(76 + s), 0.1, 'tri', curve=2)) for i, s in enumerate([0, 4, 7, 12])]), 0.6)
save('level', mix(*[(i * 0.11, note(N(72 + s), 0.28, 'square', 0.4, curve=2)) for i, s in enumerate([0, 4, 7])], (0.33, note(N(84), 0.6, 'tri', 0.6)), (0.33, note(N(79), 0.6, 'tri', 0.4)), (0.33, note(N(76), 0.6, 'tri', 0.4))), 0.75)
save('nope', mix((0, note(N(52), 0.08, 'square', curve=1)), (0.08, note(N(49), 0.1, 'square', curve=1))), 0.45)
save('gift', mix(*[(i * 0.05, note(N(84 + s), 0.18, 'bell', 0.5)) for i, s in enumerate([0, 3, 7, 10, 12, 15, 19])]), 0.6)
save('pop', note(np.linspace(900, 300, int(SR * 0.12)), 0.12, 'sine', curve=2), 0.6)
save('boost', note(np.linspace(300, 1400, int(SR * 0.3)), 0.3, 'tri', curve=1.2), 0.5)
save('whoosh', noise(0.6, 0.8, 0.08, 2) * np.sin(np.linspace(0, np.pi, int(SR * 0.6))), 0.5)
save('alert', mix((0, note(N(81), 0.12, 'square', curve=1)), (0.18, note(N(81), 0.12, 'square', curve=1))), 0.45)
# "ding-dong" de anúncio do aeroporto
save('ding', mix((0, note(N(79), 0.9, 'bell', 0.6, curve=2.2)), (0.38, note(N(76), 0.9, 'bell', 0.6, curve=2.2)), (0.76, note(N(72), 1.3, 'bell', 0.6, curve=2.4))), 0.6)
# decolagem: ronco grave subindo
d = 2.6; x = t(d); n = noise(d, 1.0, 0.03, 0.6); fm = np.linspace(80, 190, len(x))
jet = n * np.minimum(1, x / 0.6) * np.minimum(1, (d - x) / 1.0) + 0.25 * np.sin(2 * np.pi * np.cumsum(fm) / SR) * np.minimum(1, x / 0.6) * np.minimum(1, (d - x) / 1.0)
save('jet', jet, 0.6)

# ---------- música: loop alegre (112 bpm, 16 compassos) ----------
bpm = 112; beat = 60 / bpm; bars = 16; L = int(SR * beat * 4 * bars)
y = np.zeros(L + SR)
prog = [(60, [0, 4, 7]), (57, [0, 3, 7]), (53, [0, 4, 7]), (55, [0, 4, 7])]  # C Am F G
mel = [12, 14, 16, 19, 16, 14, 12, 7, 9, 12, 14, 12, 9, 7, 9, 12,
       5, 9, 12, 14, 12, 9, 7, 5, 7, 11, 14, 12, 11, 7, 2, 7]
def put(s, at):
    o = int(at * SR); y[o:o + len(s)] += s[:len(y) - o]
for b in range(bars):
    root, ch = prog[b % 4]; t0 = b * 4 * beat
    for k in range(4):  # baixo
        put(note(N(root - 24 + (7 if k % 2 else 0)), beat * 0.9, 'tri', 0.35, curve=1.5), t0 + k * beat)
    for k in range(8):  # acordes em colcheias
        for s in ch: put(note(N(root + s), beat * 0.45, 'sine', 0.07, curve=2), t0 + k * beat / 2)
    for k in range(4):  # bateria leve
        put(noise(0.12, 0.25 if k % 2 == 0 else 0.12, 0.08 if k % 2 == 0 else 0.5, 6), t0 + k * beat)
        put(noise(0.03, 0.05, 0.9, 4), t0 + k * beat + beat / 2)
    if b >= 4 and b < 14:  # melodia
        for k in range(8):
            m = mel[((b - 4) * 8 + k) % len(mel)]
            if (b * 8 + k) % 7 == 3: continue
            put(note(N(root + m - (root - 60)), beat * 0.42, 'square', 0.06, curve=2.2), t0 + k * beat / 2)
y = y[:L]
fade = int(SR * 0.05); y[:fade] *= np.linspace(0, 1, fade); y[-fade:] *= np.linspace(1, 0, fade)
save('music', y, 0.7)
print('sons ok')
