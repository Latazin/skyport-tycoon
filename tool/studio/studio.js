/* SkyPort Tycoon — estúdio de arte.
   Modela o aeroporto em 3D low-poly (Three.js) e renderiza sprites isométricos
   com a mesma projeção usada pelo jogo:
     tela.x = (x - z) * 0.7071 * S
     tela.y = ((x + z) * 0.3536 - y * 0.8660) * S        (S = 24 px por unidade)
   Rodado pelo tool/render.js (Playwright). */
'use strict';
const S = 24, ELEV = 30 * Math.PI / 180;
const R = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
R.shadowMap.enabled = true;
R.shadowMap.type = THREE.PCFSoftShadowMap;
R.setPixelRatio(1);
document.body.appendChild(R.domElement);

/* ---------------- materiais (toon) ---------------- */
const GRAD = (() => {
  const d = new Uint8Array([110, 110, 110, 255, 172, 172, 172, 255, 222, 222, 222, 255, 240, 240, 240, 255]);
  const t = new THREE.DataTexture(d, 4, 1, THREE.RGBAFormat);
  t.minFilter = t.magFilter = THREE.NearestFilter; t.needsUpdate = true; return t;
})();
const MC = {};
function M(color, o = {}) {
  const k = color + JSON.stringify(o);
  if (MC[k]) return MC[k];
  let m;
  if (o.basic) m = new THREE.MeshBasicMaterial({ color, transparent: !!o.opacity, opacity: o.opacity ?? 1 });
  else m = new THREE.MeshToonMaterial({ color, gradientMap: GRAD, transparent: o.opacity != null, opacity: o.opacity ?? 1, emissive: o.emissive ?? 0x000000 });
  if (o.opacity != null) m.depthWrite = false;
  return (MC[k] = m);
}
const GC = {};
const G = {
  box: (w, h, d) => GC['b' + w + h + d] ||= new THREE.BoxGeometry(w, h, d),
  cyl: (a, b, h, s = 12) => GC['c' + a + b + h + s] ||= new THREE.CylinderGeometry(a, b, h, s),
  sph: (r, s = 12) => GC['s' + r + s] ||= new THREE.SphereGeometry(r, s, Math.max(6, s >> 1)),
  cone: (r, h, s = 8) => GC['o' + r + h + s] ||= new THREE.ConeGeometry(r, h, s),
  torus: (r, t, a, b) => new THREE.TorusGeometry(r, t, a, b),
};
function mesh(geo, mat, p, x = 0, y = 0, z = 0) {
  const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.castShadow = true; m.receiveShadow = true;
  if (p) p.add(m); return m;
}
/* caixa apoiada no chão: (x, y-base, z) */
function B(p, w, h, d, c, x = 0, y = 0, z = 0, o) { return mesh(G.box(w, h, d), typeof c === 'object' ? c : M(c, o), p, x, y + h / 2, z); }
function C(p, r1, r2, h, c, x = 0, y = 0, z = 0, s = 12) { return mesh(G.cyl(r1, r2, h, s), typeof c === 'object' ? c : M(c), p, x, y + h / 2, z); }
function Sp(p, r, c, x = 0, y = 0, z = 0, s = 12) { return mesh(G.sph(r, s), typeof c === 'object' ? c : M(c), p, x, y, z); }
function grp(p, x = 0, y = 0, z = 0, ry = 0) { const g = new THREE.Group(); g.position.set(x, y, z); g.rotation.y = ry; if (p) p.add(g); return g; }
function flat(p, w, d, c, x, z, y = 0.02, o) { const m = mesh(G.box(w, 0.04, d), typeof c === 'object' ? c : M(c, o), p, x, y, z); m.castShadow = false; return m; }

/* texto em textura (placas, números) */
const TC = {};
function textMat(text, bg, fg, w = 512, h = 128, font = 'bold 84px Arial') {
  const k = text + bg + fg + w + h + font;
  if (TC[k]) return TC[k];
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const x = c.getContext('2d');
  if (bg) { x.fillStyle = bg; x.fillRect(0, 0, w, h); }
  x.fillStyle = fg; x.font = font; x.textAlign = 'center'; x.textBaseline = 'middle';
  x.fillText(text, w / 2, h / 2 + 4);
  const t = new THREE.CanvasTexture(c); t.anisotropy = 4;
  return (TC[k] = new THREE.MeshBasicMaterial({ map: t, transparent: !bg }));
}
/* placa: caixa colorida com texto na face +z e +x */
function sign(p, text, w, h, bg, fg, x, y, z, ry = 0) {
  const g = grp(p, x, y, z, ry);
  B(g, w, h, 0.18, bg, 0, -h / 2, 0);
  const tm = textMat(text, bg, fg, 512, Math.round(512 * h / w), 'bold ' + Math.round(512 * h / w * 0.62) + 'px Arial');
  const f = new THREE.Mesh(new THREE.PlaneGeometry(w * 0.96, h * 0.9), tm); f.position.set(0, 0, 0.1); g.add(f);
  const b = f.clone(); b.rotation.y = Math.PI; b.position.z = -0.1; g.add(b);
  return g;
}

/* ---------------- paleta ---------------- */
const P = {
  grass: 0x86d35e, grass2: 0x74c450, dirt: 0xd9b77a, asph: 0x4c5160, asph2: 0x5c6273, concrete: 0xc5cbd5, conc2: 0xb3bac6,
  white: 0xf7f9fc, yellow: 0xffc928, navy: 0x253154, blue: 0x2f7bff, sky: 0x8fd6ff, glass: 0x9fe0ff, red: 0xff4e4e,
  orange: 0xff8a1f, green: 0x2ec27e, purple: 0x8b5cf6, gold: 0xffc531, brown: 0x8a5a34, wood: 0xc98a52, steel: 0xaab3c2,
  dark: 0x2b3245, skin: [0xffd7b0, 0xe9b48a, 0xc58b5f, 0x8d5a3a], floor: 0xf4efe4, floor2: 0xe9e2d3,
};

/* ---------------- luzes e câmera ---------------- */
function lights(scene, span) {
  scene.add(new THREE.HemisphereLight(0xffffff, 0x9aa8c0, 0.62));
  const d = new THREE.DirectionalLight(0xfff3df, 0.62);
  d.position.set(-14, 40, 22); d.target.position.set(0, 0, 0);
  d.castShadow = true;
  const sz = 2048;
  d.shadow.mapSize.set(sz, sz);
  Object.assign(d.shadow.camera, { left: -span, right: span, top: span, bottom: -span, near: 1, far: 220 });
  d.shadow.bias = -0.0006; d.shadow.radius = 3;
  scene.add(d, d.target);
  return d;
}
function isoCam(W, H, k, oy, target = new THREE.Vector3()) {
  const u = S * k;
  const cam = new THREE.OrthographicCamera(-W / 2 / u, W / 2 / u, H * oy / u, -H * (1 - oy) / u, -400, 600);
  const dir = new THREE.Vector3(Math.cos(ELEV) / Math.SQRT2, Math.sin(ELEV), Math.cos(ELEV) / Math.SQRT2);
  cam.position.copy(target).addScaledVector(dir, 200);
  cam.up.set(0, 1, 0); cam.lookAt(target);
  return cam;
}

/* recorta o quadro pelo alfa e devolve PNG + âncora */
function crop(W, H, ox, oy, fmt = 'png') {
  const c = document.createElement('canvas'); c.width = W; c.height = H;
  const x = c.getContext('2d'); x.drawImage(R.domElement, 0, 0);
  if (fmt === 'jpg') return { png: c.toDataURL('image/jpeg', 0.9), ax: ox, ay: oy, w: W, h: H };
  const d = x.getImageData(0, 0, W, H).data;
  let x0 = W, y0 = H, x1 = -1, y1 = -1;
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) if (d[(j * W + i) * 4 + 3] > 6) { if (i < x0) x0 = i; if (i > x1) x1 = i; if (j < y0) y0 = j; if (j > y1) y1 = j; }
  if (x1 < 0) return null;
  x0 = Math.max(0, x0 - 2); y0 = Math.max(0, y0 - 2); x1 = Math.min(W - 1, x1 + 2); y1 = Math.min(H - 1, y1 + 2);
  const w = x1 - x0 + 1, h = y1 - y0 + 1;
  const o = document.createElement('canvas'); o.width = w; o.height = h;
  o.getContext('2d').drawImage(c, x0, y0, w, h, 0, 0, w, h);
  return { png: o.toDataURL('image/png'), ax: ox - x0, ay: oy - y0, w, h };
}

/* sprite isométrico: origem do modelo (0,0,0) = âncora */
function shot(build, { k = 1.5, W = 512, H = 512, oy = 0.72, shadow = true, catcher = 0.22 } = {}) {
  const scene = new THREE.Scene();
  lights(scene, Math.max(W, H) / (S * k));
  scene.add(build());
  if (shadow) {
    const g = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), new THREE.ShadowMaterial({ opacity: catcher }));
    g.rotation.x = -Math.PI / 2; g.position.y = 0.005; g.receiveShadow = true; scene.add(g);
  }
  const cam = isoCam(W, H, k, oy);
  R.setSize(W, H); R.setClearColor(0x000000, 0); R.render(scene, cam);
  const r = crop(W, H, W / 2, H * oy);
  if (r) r.k = k;
  return r;
}

/* ===================================================================
   LAYOUT DO AEROPORTO (unidades do mundo; y para cima)
   =================================================================== */
const L = {
  map: { x0: -92, x1: 82, z0: -62, z1: 52 },
  runway: { x0: -74, x1: 54, z: -37, w: 8 },
  lane: { x0: -46, x1: 38, z: -23.5 },
  holdZ: -29.5,
  connectors: [-46, 38],
  apron: { x0: -50, x1: 40, z0: -27, z1: -5 },
  term: { x0: -48, x1: 36, z0: -5, z1: 16 },
  gates: [-38, -26, -14, -2, 10, 22],
  standNose: -6.4,
  checkin: { x0: -44, z: 8, dx: 2.6 },        // balcões de check-in
  security: { x0: -21.5, z: 5, dx: 3.0 },     // faixas do raio-X
  shops: [{ x: -1.6, z: 8 }, { x: 3.1, z: 8 }, { x: 7.8, z: 8 }, { x: 12.5, z: 8 }, { x: 17.2, z: 8 }, { x: 21.9, z: 8 }],
  vip: { x: 28, z: 9 },
  door: { x: -35, z: 16 },
  road: { z: 20, x0: -92, x1: 82 },
  parking: { x: -24, z: 30 },
  busStop: { x: -40, z: 18.4 },
  tower: { x: -56, z: 5 },
  cargo: { x: 48, z: 3 },
  special: { x: 38, z: 29 },
  carousel: { x: -45, z: 2.6 },
  fuel: { x: 50, z: -15 },
  hangar: { x: -60, z: -13 },
};
// fases: barracão, terminal pequeno, terminal grande, hub
const PH = [
  { rx1: 10, rw: 6, conn: [-46, 2], tx1: -6, apx1: -18 },
  { rx1: 26, rw: 7, conn: [-46, 14], tx1: 20, apx1: 18 },
  { rx1: 54, rw: 8, conn: [-46, 38], tx1: 36, apx1: 40 },
  { rx1: 54, rw: 8, conn: [-46, 38], tx1: 36, apx1: 40 },
];
const PLANES = [
  { len: 5.6, span: 7.2, r: 0.46, prop: true, door: 0.2 },
  { len: 8.4, span: 8.0, r: 0.62, door: 0.17 },
  { len: 11.2, span: 10.6, r: 0.82, door: 0.15, big: true },
];
const LIVERY = [
  { body: 0xf7f9fc, tail: 0x2f6bff, stripe: 0xffc928, belly: 0xdfe6f0 },
  { body: 0xf7f9fc, tail: 0xff7a1a, stripe: 0xff7a1a, belly: 0x2b3245 },
  { body: 0xf7f9fc, tail: 0x18b48d, stripe: 0x6c4cf5, belly: 0xdfe6f0 },
  { body: 0xffd84a, tail: 0xffffff, stripe: 0xff9f1c, belly: 0xffb300 },
  { body: 0xf7f9fc, tail: 0x8b5cf6, stripe: 0xff7ab6, belly: 0x6c4cf5 },
  { body: 0xf7f9fc, tail: 0xe8343b, stripe: 0x253154, belly: 0xe8343b },
];

/* ===================================================================
   MODELOS
   =================================================================== */
function person({ shirt = 0x2f7bff, pants = 0x2b3245, skin = P.skin[0], hair = 0x3b2a20, frame = -1, bag = false, cap = null, scale = 1 } = {}) {
  const g = new THREE.Group();
  const sw = frame < 0 ? 0 : Math.sin(frame / 4 * Math.PI * 2) * 0.55;
  const bob = frame < 0 ? 0 : Math.abs(Math.cos(frame / 4 * Math.PI * 2)) * 0.03;
  const legs = [-0.11, 0.11].map((x, i) => {
    const l = grp(g, x, 0.42 + bob, 0); l.rotation.x = i ? -sw : sw;
    B(l, 0.16, 0.42, 0.18, pants, 0, -0.42, 0); B(l, 0.17, 0.08, 0.24, 0x2a2a35, 0, -0.42, 0.03);
    return l;
  });
  B(g, 0.44, 0.46, 0.3, shirt, 0, 0.4 + bob, 0);
  [-0.29, 0.29].forEach((x, i) => { const a = grp(g, x, 0.82 + bob, 0); a.rotation.x = i ? sw * 0.8 : -sw * 0.8; B(a, 0.13, 0.4, 0.15, shirt, 0, -0.4, 0); Sp(a, 0.08, skin, 0, -0.44, 0, 8); });
  Sp(g, 0.27, skin, 0, 1.13 + bob, 0, 14);
  const h = Sp(g, 0.285, hair, 0, 1.2 + bob, -0.03, 14); h.scale.set(1, 0.72, 1);
  [-0.09, 0.09].forEach(x => Sp(g, 0.035, 0x1d1d28, x, 1.14 + bob, 0.25, 6));
  if (cap) { C(g, 0.29, 0.29, 0.1, cap, 0, 1.3 + bob, 0, 14); B(g, 0.32, 0.03, 0.2, cap, 0, 1.3 + bob, 0.22); }
  if (bag) {
    const s = grp(g, 0.42, 0, -0.32); s.rotation.x = 0.25;
    B(s, 0.3, 0.46, 0.2, bag === true ? 0xff4e4e : bag, 0, 0.06, 0);
    C(s, 0.015, 0.015, 0.36, 0x333333, 0, 0.5, 0.0, 5);
    C(s, 0.05, 0.05, 0.04, 0x222222, 0.1, 0.0, -0.06, 8).rotation.z = Math.PI / 2;
  }
  g.scale.setScalar(scale);
  return g;
}

/* asa/estabilizador trapezoidal extrudado */
function wingGeo(root, tip, span, sweep, thick) {
  const s = new THREE.Shape();
  s.moveTo(0, 0); s.lineTo(span, -sweep); s.lineTo(span, -sweep - tip); s.lineTo(0, -root); s.lineTo(0, 0);
  const g = new THREE.ExtrudeGeometry(s, { depth: thick, bevelEnabled: false });
  return g;
}
function plane(type, liv) {
  const T = PLANES[type], L0 = LIVERY[liv], g = new THREE.Group();
  const r = T.r, len = T.len, gh = 0.55 + r * 0.25, cy = gh + r;
  const body = M(L0.body), tail = M(L0.tail), stripe = M(L0.stripe), dark = M(0x26324f), belly = M(L0.belly);
  const fl = len * 0.66;
  const f = mesh(G.cyl(r, r, fl, 16), body, g, 0, cy, 0); f.rotation.x = Math.PI / 2;
  const bl = mesh(G.cyl(r * 0.98, r * 0.98, fl * 0.98, 16), belly, g, 0, cy - r * 0.12, 0); bl.rotation.x = Math.PI / 2; bl.scale.set(1, 1, 0.9);
  const nose = mesh(G.sph(r, 16), body, g, 0, cy, fl / 2); nose.scale.set(1, 1, 1.65);
  const tc = mesh(new THREE.CylinderGeometry(r * 0.25, r, len * 0.24, 16), body, g, 0, cy + r * 0.35, -fl / 2 - len * 0.12);
  tc.rotation.x = -Math.PI / 2 + 0.12;
  // faixa e janelas
  [-1, 1].forEach(sd => {
    B(g, 0.02, r * 0.22, fl * 0.9, stripe, sd * r * 0.99, cy - r * 0.05 - r * 0.11, 0);
    B(g, 0.02, r * 0.16, fl * 0.84, dark, sd * r * 0.995, cy + r * 0.32 - r * 0.08, -fl * 0.02);
  });
  const ck = mesh(G.box(r * 1.2, r * 0.32, r * 0.5), dark, g, 0, cy + r * 0.48, fl / 2 + r * 0.55); ck.rotation.x = 0.5;
  // asas
  const wy = T.prop ? cy + r * 0.78 : cy - r * 0.45;
  [-1, 1].forEach(sd => {
    const wg = wingGeo(len * 0.2, len * 0.08, T.span / 2 - r * 0.6, T.prop ? len * 0.02 : len * 0.11, 0.12);
    const w = mesh(wg, body, g, sd * r * 0.6, wy, len * 0.1); w.rotation.x = Math.PI / 2;
    if (sd < 0) { w.scale.x = -1; }
    if (!T.prop) w.rotation.y = 0; // diedro leve
    const wt = mesh(G.box(0.06, 0.4, len * 0.08), tail, g, sd * (T.span / 2 + 0.02), wy + 0.18, len * 0.1 - (T.prop ? len * 0.02 : len * 0.11) - len * 0.04);
    wt.castShadow = false;
    // estabilizador horizontal
    const hs = mesh(wingGeo(len * 0.1, len * 0.05, T.span * 0.18, len * 0.05, 0.08), body, g, sd * r * 0.25, cy + r * 0.45, -fl / 2 - len * 0.12);
    hs.rotation.x = Math.PI / 2; if (sd < 0) hs.scale.x = -1;
  });
  // deriva
  const fin = mesh(wingGeo(len * 0.18, len * 0.07, r * 1.8 + len * 0.06, len * 0.13, 0.12), tail, g, -0.06, cy + r * 0.55, -fl / 2 - len * 0.04);
  fin.quaternion.setFromRotationMatrix(new THREE.Matrix4().makeBasis(new THREE.Vector3(0, 1, 0), new THREE.Vector3(0, 0, 1), new THREE.Vector3(1, 0, 0)));
  // motores
  if (T.prop) {
    [-1, 1].forEach(sd => {
      const x = sd * T.span * 0.24;
      const n = mesh(G.cyl(r * 0.36, r * 0.4, len * 0.26, 10), body, g, x, wy - 0.05, len * 0.13); n.rotation.x = Math.PI / 2;
      Sp(g, r * 0.2, dark, x, wy - 0.05, len * 0.27, 8);
      const pr = grp(g, x, wy - 0.05, len * 0.28);
      B(pr, 0.12, r * 3.2, 0.05, dark, 0, -r * 1.6, 0); const b2 = B(pr, 0.12, r * 3.2, 0.05, dark, 0, -r * 1.6, 0); pr.rotation.z = 0.5; b2.rotation.z = Math.PI / 2; b2.position.set(0, 0, 0);
    });
  } else {
    const xs = T.big ? [-0.5, -0.27, 0.27, 0.5] : [-0.3, 0.3];
    xs.forEach(f0 => {
      const x = f0 * T.span * 0.75, z = len * 0.14 - Math.abs(f0) * len * 0.12;
      const e = mesh(G.cyl(r * 0.42, r * 0.36, len * 0.17, 14), M(0xd7dde8), g, x, wy - r * 0.42, z); e.rotation.x = Math.PI / 2;
      const ring = mesh(G.cyl(r * 0.43, r * 0.43, 0.08, 14), tail, g, x, wy - r * 0.42, z + len * 0.08); ring.rotation.x = Math.PI / 2;
      const in0 = mesh(G.cyl(r * 0.3, r * 0.3, 0.1, 12), dark, g, x, wy - r * 0.42, z + len * 0.085); in0.rotation.x = Math.PI / 2;
      B(g, 0.1, r * 0.4, len * 0.1, M(0xd7dde8), x, wy - r * 0.2, z - len * 0.01);
    });
  }
  // trem de pouso
  [[0, fl / 2 - 0.2], [-r * 1.1, -len * 0.03], [r * 1.1, -len * 0.03]].forEach(([x, z]) => {
    C(g, 0.05, 0.05, gh, 0x667085, x, 0.15, z, 6);
    const w = mesh(G.cyl(0.18, 0.18, 0.16, 10), dark, g, x, 0.18, z); w.rotation.z = Math.PI / 2;
  });
  // luzes de navegação
  [-1, 1].forEach(sd => Sp(g, 0.09, M(sd < 0 ? 0xff3b3b : 0x3bff7a, { emissive: sd < 0 ? 0x661010 : 0x106630 }), sd * T.span / 2, wy + 0.06, len * 0.08, 6));
  return g;
}

/* veículos (frente para +z) */
function vehicle(kind, color = 0xff4e4e) {
  const g = new THREE.Group(), dark = 0x2b3245, wheel = (x, z, r = 0.22) => { const w = mesh(G.cyl(r, r, 0.16, 10), M(0x1e2230), g, x, r, z); w.rotation.z = Math.PI / 2; };
  if (kind === 'car') {
    B(g, 1.0, 0.45, 2.0, color, 0, 0.22, 0); B(g, 0.86, 0.42, 1.05, color, 0, 0.66, -0.12);
    B(g, 0.88, 0.3, 0.9, M(0x8fd6ff), 0, 0.72, -0.12);
    [[-0.5, 0.62], [0.5, 0.62], [-0.5, -0.62], [0.5, -0.62]].forEach(([x, z]) => wheel(x, z, 0.2));
    B(g, 0.2, 0.1, 0.04, M(0xfff6b0, { emissive: 0x777040 }), -0.3, 0.42, 1.0); B(g, 0.2, 0.1, 0.04, M(0xfff6b0, { emissive: 0x777040 }), 0.3, 0.42, 1.0);
  } else if (kind === 'taxi') {
    return vehicle('car', 0xffc928);
  } else if (kind === 'bus') {
    B(g, 1.3, 1.2, 4.6, 0xffffff, 0, 0.3, 0); B(g, 1.32, 0.35, 4.62, 0x2f7bff, 0, 0.3, 0); B(g, 1.32, 0.45, 4.2, 0x8fd6ff, 0, 0.95, -0.1);
    B(g, 1.32, 0.12, 4.62, 0xffc928, 0, 1.45, 0); B(g, 1.1, 0.5, 0.05, 0x8fd6ff, 0, 0.85, 2.3);
    [[-0.66, 1.5], [0.66, 1.5], [-0.66, -1.4], [0.66, -1.4]].forEach(([x, z]) => wheel(x, z, 0.28));
  } else if (kind === 'fuel') {
    B(g, 1.2, 0.9, 1.3, 0xff4e4e, 0, 0.3, 1.4); B(g, 1.0, 0.4, 0.6, 0x8fd6ff, 0, 0.8, 1.6);
    const t = mesh(G.cyl(0.62, 0.62, 2.6, 14), M(0xf2f4f8), g, 0, 1.0, -0.6); t.rotation.x = Math.PI / 2;
    B(g, 1.26, 0.12, 2.6, 0xff4e4e, 0, 0.98, -0.6);
    [[-0.6, 1.4], [0.6, 1.4], [-0.6, -1.2], [0.6, -1.2], [-0.6, -0.4], [0.6, -0.4]].forEach(([x, z]) => wheel(x, z, 0.26));
  } else if (kind === 'tug') {
    B(g, 0.9, 0.5, 1.0, 0xffc928, 0, 0.2, 0.9); B(g, 0.7, 0.5, 0.06, 0x8fd6ff, 0, 0.7, 0.75);
    C(g, 0.03, 0.03, 0.5, 0x333333, -0.3, 0.7, 0.5, 5); C(g, 0.03, 0.03, 0.5, 0x333333, 0.3, 0.7, 0.5, 5); B(g, 0.8, 0.05, 0.6, 0xffc928, 0, 1.2, 0.75);
    wheel(-0.45, 1.2, 0.18); wheel(0.45, 1.2, 0.18); wheel(-0.45, 0.6, 0.18); wheel(0.45, 0.6, 0.18);
    for (let i = 0; i < 2; i++) {
      const z = -0.6 - i * 1.4;
      B(g, 0.9, 0.12, 1.1, 0x8a93a6, 0, 0.3, z); C(g, 0.02, 0.02, 0.6, 0x666666, -0.4, 0.4, z + 0.5, 4); C(g, 0.02, 0.02, 0.6, 0x666666, 0.4, 0.4, z + 0.5, 4);
      const bags = [0xff4e4e, 0x2f7bff, 0x2ec27e, 0xffc928, 0x8b5cf6, 0xff8a1f];
      for (let b = 0; b < 4; b++) B(g, 0.36, 0.3, 0.42, bags[(b + i * 2) % 6], (b % 2 ? 0.2 : -0.2), 0.42 + (b > 1 ? 0.3 : 0), z + (b % 2 ? 0.1 : -0.1));
      wheel(-0.45, z + 0.4, 0.14); wheel(0.45, z + 0.4, 0.14); wheel(-0.45, z - 0.4, 0.14); wheel(0.45, z - 0.4, 0.14);
    }
  } else if (kind === 'stairs') {
    B(g, 1.0, 0.5, 2.4, 0xffffff, 0, 0.2, 0); B(g, 1.02, 0.12, 2.42, 0x2f7bff, 0, 0.5, 0);
    for (let i = 0; i < 8; i++) B(g, 0.8, 0.12, 0.3, 0xd0d6e0, 0, 0.7 + i * 0.18, 0.6 - i * 0.22);
    wheel(-0.5, 0.8, 0.2); wheel(0.5, 0.8, 0.2); wheel(-0.5, -0.8, 0.2); wheel(0.5, -0.8, 0.2);
  }
  return g;
}

/* árvores e enfeites */
function tree(p, x, z, s = 1, kind = 0) {
  const g = grp(p, x, 0, z); g.scale.setScalar(s);
  if (kind === 1) { // pinheiro
    C(g, 0.12, 0.16, 0.6, P.brown, 0, 0, 0, 6);
    mesh(G.cone(0.9, 1.4, 7), M(0x3fae5a), g, 0, 1.2, 0); mesh(G.cone(0.7, 1.1, 7), M(0x4cc067), g, 0, 1.8, 0);
  } else if (kind === 3) { // pinheiro nevado
    C(g, 0.12, 0.16, 0.6, P.brown, 0, 0, 0, 6);
    mesh(G.cone(0.9, 1.4, 7), M(0x3f8f6a), g, 0, 1.2, 0); mesh(G.cone(0.7, 1.1, 7), M(0xffffff), g, 0, 1.85, 0); mesh(G.cone(0.93, 0.35, 7), M(0xffffff), g, 0, 0.75, 0);
  } else if (kind === 4) { // ipê dourado
    C(g, 0.12, 0.16, 0.9, P.brown, 0, 0, 0, 6);
    const cc = [0xffc531, 0xff9f1c, 0xf2d024][Math.abs(Math.round(x * 3 + z)) % 3];
    Sp(g, 0.8, cc, 0, 1.5, 0, 7); Sp(g, 0.55, 0xffe27a, 0.3, 1.9, 0.2, 7); Sp(g, 0.5, cc, -0.4, 1.3, -0.2, 7);
  } else if (kind === 2) { // palmeira
    const t = C(g, 0.1, 0.16, 2.6, 0xb58450, 0, 0, 0, 6); t.rotation.z = 0.12;
    for (let i = 0; i < 6; i++) { const l = B(g, 0.32, 0.06, 1.6, 0x2fb35a, 0, 2.55, 0.6); l.position.set(Math.sin(i) * 0.6, 2.55, Math.cos(i) * 0.6); l.rotation.y = i * 1.05; l.rotation.x = 0.35; }
  } else {
    C(g, 0.12, 0.16, 0.7, P.brown, 0, 0, 0, 6);
    Sp(g, 0.75, 0x52c463, 0, 1.25, 0, 7); Sp(g, 0.5, 0x63d474, 0.3, 1.6, 0.2, 7);
  }
  return g;
}
function lamp(p, x, z, h = 2.6) { C(p, 0.05, 0.07, h, 0x7a8395, x, 0, z, 6); B(p, 0.5, 0.08, 0.18, 0x7a8395, x, h, z); B(p, 0.3, 0.06, 0.14, M(0xfff6c0, { emissive: 0x8a8460 }), x, h - 0.05, z); }

/* ===================================================================
   ESTAÇÕES (cada unidade é um sprite separado para ordenar com os NPCs)
   =================================================================== */
function checkinDesk() {
  const g = new THREE.Group();
  // balcão (frente para +z), esteira para trás
  B(g, 2.0, 0.95, 0.75, 0x2f7bff, 0, 0, 0); B(g, 2.1, 0.08, 0.85, 0xf7f9fc, 0, 0.95, 0);
  B(g, 0.6, 0.22, 0.7, 0x404858, 0.65, 0, 0.8); B(g, 0.55, 0.03, 0.6, 0x1e2230, 0.65, 0.22, 0.8); // balança
  B(g, 0.6, 0.35, 1.6, 0x404858, 0.65, 0, -1.0); B(g, 0.55, 0.03, 1.6, 0x1e2230, 0.65, 0.35, -1.0);
  B(g, 0.5, 0.36, 0.06, 0x1e2230, -0.4, 1.0, -0.05); B(g, 0.46, 0.3, 0.02, M(0x7fd8ff, { emissive: 0x204060 }), -0.4, 1.03, -0.02);
  const a = person({ shirt: 0x1e5adc, pants: 0x253154, skin: P.skin[1], hair: 0x2a1a12 }); a.position.set(-0.4, 0, -0.75); g.add(a);
  // pedestal com número
  C(g, 0.05, 0.05, 2.6, 0x9aa3b4, -1.0, 0, -0.35, 6); C(g, 0.05, 0.05, 2.6, 0x9aa3b4, 1.0, 0, -0.35, 6);
  B(g, 2.1, 0.5, 0.12, 0x253154, 0, 2.55, -0.35); B(g, 2.1, 0.08, 0.14, 0xffc928, 0, 2.5, -0.35);
  // fila com faixas
  for (let i = 0; i < 3; i++) {
    const z = 1.5 + i * 0.9;
    [-0.9, 0.9].forEach(x => { C(g, 0.05, 0.08, 0.85, 0xc0c8d6, x, 0, z, 8); Sp(g, 0.07, 0xc0c8d6, x, 0.9, z, 8); });
    B(g, 1.7, 0.08, 0.03, 0x2f7bff, 0, 0.78, z);
  }
  return g;
}
function securityLane() {
  const g = new THREE.Group();
  // esteira do raio-X ao longo de z (passageiro anda em -z)
  B(g, 0.9, 0.75, 4.4, 0x9aa3b4, -0.75, 0, 0); B(g, 0.8, 0.04, 4.4, 0x1e2230, -0.75, 0.75, 0);
  B(g, 1.1, 1.3, 1.6, 0x8b5cf6, -0.75, 0.6, 0); B(g, 0.8, 0.6, 1.62, 0x1e2230, -0.75, 0.78, 0);
  B(g, 1.12, 0.12, 1.62, 0xffc928, -0.75, 1.9, 0);
  [[0.15, 1.6], [0.1, 2.0]].forEach(([y, z]) => B(g, 0.5, 0.12, 0.4, 0x6c7488, -0.75, 0.79, z));
  // pórtico detector
  B(g, 0.14, 2.2, 0.3, 0xdfe5ee, 0.25, 0, -0.2); B(g, 0.14, 2.2, 0.3, 0xdfe5ee, 1.25, 0, -0.2); B(g, 1.14, 0.25, 0.32, 0xdfe5ee, 0.75, 2.2, -0.2);
  Sp(g, 0.08, M(0x3bff7a, { emissive: 0x20a050 }), 0.75, 2.35, -0.05, 8);
  const gd = person({ shirt: 0x253154, pants: 0x1a2038, skin: P.skin[2], hair: 0x1a1210, cap: 0x253154 }); gd.position.set(1.6, 0, -0.8); gd.rotation.y = -Math.PI / 2; g.add(gd);
  return g;
}
const SHOPS = [
  { name: 'CAFÉ', c: 0x8a5a34, aw: [0xffffff, 0xd94b3a] },
  { name: 'LANCHES', c: 0xff8a1f, aw: [0xffffff, 0xff8a1f] },
  { name: 'REVISTAS', c: 0x2f7bff, aw: [0xffffff, 0x2f7bff] },
  { name: 'SORVETES', c: 0xff7ab6, aw: [0xffffff, 0xff7ab6] },
  { name: 'PRESENTES', c: 0x18b48d, aw: [0xffffff, 0x18b48d] },
  { name: 'DUTY FREE', c: 0x8b5cf6, aw: [0xffc928, 0x8b5cf6] },
];
/* troca cores de um modelo pronto (para as evoluções visuais) */
function reskin(g, map) { g.traverse(o => { if (o.isMesh && o.material && o.material.color) { const h = o.material.color.getHex(); if (map[h] != null && !o.material.transparent) o.material = M(map[h]); } }); return g; }
/* evolução visual: t=1 básico, t=2 moderno, t=3 luxo */
function shopT(i, t) {
  const g = shop(i), s = SHOPS[i];
  if (t >= 2) {
    B(g, 3.8, 0.1, 3.4, 0xffffff, 0, -0.02, -0.1); B(g, 3.5, 0.5, 0.16, 0x1e2a47, 0, 3.5, -0.9); B(g, 3.3, 0.08, 0.18, M(0xfff1a8, { emissive: 0x8a7a20 }), 0, 3.42, -0.88);
    [-1.9, 1.9].forEach(x => { C(g, 0.22, 0.18, 0.4, 0xf7f9fc, x, 0, 1.3, 8); Sp(g, 0.32, 0x3fae5a, x, 0.65, 1.3, 7); });
    for (let k = 0; k < 5; k++) Sp(g, 0.09, M(0xfff1a8, { emissive: 0xa08a30 }), -1.5 + k * 0.75, 2.0, 0.25, 6);
  }
  if (t >= 3) {
    B(g, 3.4, 1.9, 0.3, s.c, 0, 1.9, -1.6); B(g, 0.3, 3.8, 0.3, 0xf7f9fc, -1.7, 0, -1.6); B(g, 0.3, 3.8, 0.3, 0xf7f9fc, 1.7, 0, -1.6);
    B(g, 3.6, 1.5, 0.3, s.c, 0, 3.8, -1.6); for (let k = 0; k < 3; k++) B(g, 0.8, 0.9, 0.08, M(0x8fd6ff), -1.1 + k * 1.1, 4.1, -1.42);
    B(g, 3.8, 0.16, 0.5, 0xffc531, 0, 5.3, -1.6); B(g, 3.8, 0.12, 3.2, 0xffc531, 0, 0.0, -0.1);
    [[-1.5, 0xff4e4e], [1.5, 0x2f7bff], [0, 0xffc531]].forEach(([x, c]) => { C(g, 0.015, 0.015, 1.2, 0xffffff, x, 5.4, -1.6, 4); Sp(g, 0.3, c, x, 6.8, -1.6, 10); });
    const st = mesh(G.cone(0.34, 0.5, 5), M(0xffc531), g, 0, 5.75, -1.3); st.rotation.x = Math.PI / 2;
  }
  return g;
}
function checkinT(t) {
  const g = checkinDesk();
  if (t === 2) { reskin(g, { 0x2f7bff: 0x14b8a6, 0x253154: 0x0f766e }); B(g, 2.3, 0.04, 3.9, 0x14b8a6, 0, 0.0, 1.6); B(g, 2.1, 0.5, 0.06, M(0x7fd8ff, { emissive: 0x2a6a90 }), 0, 2.55, -0.27); B(g, 0.35, 1.3, 0.3, 0xf7f9fc, 1.35, 0, 1.2); B(g, 0.28, 0.4, 0.04, M(0x7fd8ff, { emissive: 0x2a6a90 }), 1.35, 0.8, 1.36); }
  if (t === 3) { reskin(g, { 0x2f7bff: 0x1e2a47, 0xf7f9fc: 0xffe9b0, 0x253154: 0x1e2a47, 0xc0c8d6: 0xffc531 }); B(g, 2.3, 0.05, 3.9, 0xb3261e, 0, 0.0, 1.6); B(g, 2.3, 0.03, 0.2, 0xffc531, 0, 0.03, 3.4); B(g, 2.14, 0.1, 0.9, 0xffc531, 0, 0.9, 0); B(g, 2.1, 0.5, 0.06, M(0xffe27a, { emissive: 0x907020 }), 0, 2.55, -0.27); B(g, 0.35, 1.3, 0.3, 0x1e2a47, 1.35, 0, 1.2); B(g, 0.28, 0.4, 0.04, M(0xffe27a, { emissive: 0x907020 }), 1.35, 0.8, 1.36); mesh(G.cone(0.3, 0.45, 5), M(0xffc531), g, 0, 3.15, -0.35).rotation.x = Math.PI / 2; }
  return g;
}
function securityT(t) {
  const g = securityLane();
  if (t === 2) { reskin(g, { 0x8b5cf6: 0x14b8a6, 0xdfe5ee: 0xf7f9fc }); B(g, 2.6, 0.04, 4.6, 0xbff0e8, 0.3, 0.0, 0); B(g, 1.3, 0.4, 0.06, M(0x7fd8ff, { emissive: 0x2a6a90 }), 0.75, 2.5, -0.2); B(g, 0.5, 0.5, 0.06, M(0x7fd8ff, { emissive: 0x2a6a90 }), -0.75, 2.2, 0.82); }
  if (t === 3) { reskin(g, { 0x8b5cf6: 0x1e2a47, 0xdfe5ee: 0xffc531, 0x9aa3b4: 0x4a5670, 0xffc928: 0xffc531 }); B(g, 2.6, 0.04, 4.6, 0xffe9b0, 0.3, 0.0, 0); B(g, 1.3, 0.4, 0.06, M(0xffe27a, { emissive: 0x907020 }), 0.75, 2.5, -0.2); B(g, 0.5, 0.5, 0.06, M(0xffe27a, { emissive: 0x907020 }), -0.75, 2.2, 0.82); Sp(g, 0.14, M(0x3bff7a, { emissive: 0x20a050 }), 0.25, 2.5, -0.05, 8); Sp(g, 0.14, M(0x3bff7a, { emissive: 0x20a050 }), 1.25, 2.5, -0.05, 8); }
  return g;
}
function shop(i) {
  const s = SHOPS[i], g = new THREE.Group();
  B(g, 3.6, 0.15, 3.0, 0xefe6d6, 0, 0, -0.2);
  B(g, 3.4, 1.9, 0.3, s.c, 0, 0, -1.6); // fundo
  for (let r = 0; r < 3; r++) for (let k = 0; k < 6; k++) B(g, 0.38, 0.32, 0.22, [0xffc928, 0xff4e4e, 0x2ec27e, 0x2f7bff, 0xffffff, 0xff8a1f][(k + r + i) % 6], -1.3 + k * 0.52, 0.5 + r * 0.45, -1.35);
  B(g, 2.6, 0.95, 0.7, 0xf7f9fc, 0, 0, 0.3); B(g, 2.7, 0.08, 0.8, s.c, 0, 0.95, 0.3);
  const v = person({ shirt: s.c, pants: 0x253154, skin: P.skin[i % 4], hair: [0x3b2a20, 0xe0a040, 0x1a1210, 0x6b3a20][i % 4] }); v.position.set(0.6, 0, -0.5); g.add(v);
  // toldo listrado
  for (let k = 0; k < 7; k++) { const a = B(g, 0.52, 0.08, 1.2, s.aw[k % 2], -1.56 + k * 0.52, 2.15, -0.6); a.rotation.x = 0.3; }
  C(g, 0.05, 0.05, 2.2, 0x7a8395, -1.7, 0, 0.2, 6); C(g, 0.05, 0.05, 2.2, 0x7a8395, 1.7, 0, 0.2, 6);
  sign(g, s.name, 2.6, 0.55, '#' + s.c.toString(16).padStart(6, '0'), '#ffffff', 0, 3.05, -0.9);
  if (i === 0 || i === 1) { // mesinhas
    [[-1.0, 1.6], [1.0, 1.6]].forEach(([x, z]) => { C(g, 0.05, 0.05, 0.7, 0x7a8395, x, 0, z, 6); C(g, 0.38, 0.38, 0.05, 0xf7f9fc, x, 0.7, z, 12); });
  }
  if (i === 1) { B(g, 0.3, 0.25, 0.3, 0xffc928, -0.6, 1.03, 0.3); }
  if (i === 3) { [-0.7, 0, 0.7].forEach((x, k) => { mesh(G.cone(0.16, 0.4, 8), M(0xe8c48a), g, x, 1.2, 0.3).rotation.x = Math.PI; Sp(g, 0.2, [0xff7ab6, 0xfff1a8, 0x8a5a34][k], x, 1.5, 0.3, 8); }); }
  if (i === 4) { [[-0.8, 0xff4e4e], [0, 0x2f7bff], [0.8, 0xffc928]].forEach(([x, c]) => { B(g, 0.45, 0.4, 0.45, c, x, 1.03, 0.3); B(g, 0.47, 0.08, 0.1, 0xffffff, x, 1.2, 0.3); B(g, 0.1, 0.42, 0.47, 0xffffff, x, 1.03, 0.3); }); }
  return g;
}
function vip(t) {
  const g = new THREE.Group();
  B(g, 8.4, 0.08, 6.0, 0x5b3fb3, 0, 0, 0);
  B(g, 8.0, 0.02, 5.6, 0xffc531, 0, 0.08, 0);
  const glass = M(0xbfe8ff, { opacity: 0.45 });
  B(g, 8.4, 1.3, 0.08, glass, 0, 0, 3.0); B(g, 0.08, 1.3, 6.0, glass, -4.2, 0, 0);
  B(g, 8.4, 0.08, 0.12, 0xd7dde8, 0, 1.3, 3.0);
  sign(g, 'SALA VIP', 3.2, 0.7, '#5b3fb3', '#ffc531', -1.5, 2.6, 3.0);
  const sofa = (x, z, ry) => { const s = grp(g, x, 0, z, ry); B(s, 1.8, 0.45, 0.8, 0x7c4dff, 0, 0, 0); B(s, 1.8, 0.5, 0.25, 0x6a3df0, 0, 0.4, -0.3); B(s, 0.2, 0.3, 0.8, 0x6a3df0, -0.9, 0.4, 0); B(s, 0.2, 0.3, 0.8, 0x6a3df0, 0.9, 0.4, 0); };
  sofa(-2.6, -1.6, 0); sofa(-2.6, 1.2, Math.PI);
  C(g, 0.4, 0.4, 0.4, 0xf7f9fc, -2.6, 0, -0.2, 14);
  if (t >= 2) { sofa(0.5, -1.6, 0); sofa(0.5, 1.2, Math.PI); C(g, 0.4, 0.4, 0.4, 0xf7f9fc, 0.5, 0, -0.2, 14); tree(g, -3.6, -2.3, 0.7); }
  if (t >= 3) {
    B(g, 2.2, 1.0, 0.7, 0x2b3245, 3.0, 0, -1.9); B(g, 2.3, 0.08, 0.8, 0xffc531, 3.0, 1.0, -1.9);
    for (let k = 0; k < 4; k++) C(g, 0.06, 0.06, 0.3, [0xff4e4e, 0x2ec27e, 0xffc928, 0x8fd6ff][k], 2.3 + k * 0.45, 1.08, -1.9, 6);
    const bt = person({ shirt: 0x2b3245, pants: 0x1a2038, skin: P.skin[3], hair: 0x1a1210 }); bt.position.set(3.0, 0, -2.6); g.add(bt);
    tree(g, 3.8, 2.3, 0.7); C(g, 0.3, 0.3, 0.6, 0x2b3245, 3.2, 0, 1.5, 12); Sp(g, 0.35, 0xffc531, 3.2, 0.9, 1.5, 10);
  }
  return g;
}
/* interior do portão (assentos + balcão + painel) */
function gateInterior(n, t) {
  const g = new THREE.Group();
  B(g, 1.4, 0.95, 0.6, 0xffc928, -2.6, 0, -0.6); B(g, 1.5, 0.06, 0.7, 0xf7f9fc, -2.6, 0.95, -0.6);
  C(g, 0.05, 0.05, 2.5, 0x9aa3b4, -2.6, 0, -1.2, 6);
  sign(g, 'PORTÃO ' + n, 2.2, 0.6, '#ffc928', '#253154', -2.6, 3.0, -1.2);
  const rows = t >= 3 ? 3 : t >= 2 ? 2 : 1;
  for (let r = 0; r < rows; r++) {
    const z = 0.6 + r * 1.3;
    B(g, 4.2, 0.08, 0.5, 0x9aa3b4, 0.8, 0.38, z);
    for (let k = 0; k < 6; k++) { B(g, 0.6, 0.12, 0.5, 0x2f7bff, -1.0 + k * 0.7, 0.42, z); B(g, 0.6, 0.5, 0.1, 0x2f7bff, -1.0 + k * 0.7, 0.5, z - 0.25); }
    B(g, 0.1, 0.4, 0.3, 0x9aa3b4, -1.2, 0, z); B(g, 0.1, 0.4, 0.3, 0x9aa3b4, 2.8, 0, z);
  }
  if (t >= 3) { B(g, 0.12, 1.0, 1.7, 0x2b3245, 3.6, 1.0, 0.8); B(g, 0.02, 0.85, 1.55, M(0x7fd8ff, { emissive: 0x204870 }), 3.53, 1.08, 0.8); tree(g, 3.4, 2.6, 0.6); }
  return g;
}
/* ponte de embarque: sai da parede (z=-5 local -> 0) até a porta do avião */
function jetBridge(type) {
  const T = PLANES[type], g = new THREE.Group();
  const zc = (L.standNose + 5) - T.len * T.door;   // porta do avião, relativo à parede (z=-5)
  const doorX = T.r + 0.15, rx = 3.2, y0 = 1.75, h = 1.25;
  const skin = M(0xe3e8f0), roof = M(0x9aa3b4), win = M(0x5fb4ff);
  // trecho fixo saindo da parede
  B(g, 1.3, h, Math.abs(zc) + 0.6, skin, rx, y0, zc / 2 - 0.3 + 0.3);
  B(g, 1.34, 0.12, Math.abs(zc) + 0.64, roof, rx, y0 + h, zc / 2);
  B(g, 0.02, 0.28, Math.abs(zc) * 0.8, win, rx + 0.66, y0 + h * 0.55, zc / 2);
  C(g, 0.16, 0.2, y0, 0x7a8395, rx, 0, zc + 0.2, 8);
  C(g, 0.85, 0.85, h + 0.2, skin, rx, y0 - 0.1, zc, 14); C(g, 0.88, 0.88, 0.12, roof, rx, y0 + h + 0.1, zc, 14);
  // túnel telescópico até a porta (ao longo de -x)
  const len = rx - doorX - 0.9;
  const s1 = len * 0.55, s2 = len * 0.5;
  B(g, s1, h, 1.2, skin, rx - 0.7 - s1 / 2, y0 - 0.05, zc); B(g, s1, 0.1, 1.24, roof, rx - 0.7 - s1 / 2, y0 + h - 0.05, zc);
  B(g, s2, h - 0.12, 1.08, skin, doorX + 0.6 + s2 / 2, y0, zc); B(g, s2, 0.1, 1.12, roof, doorX + 0.6 + s2 / 2, y0 + h - 0.12, zc);
  B(g, len * 0.95, 0.24, 0.02, win, rx - 0.7 - len / 2, y0 + h * 0.55, zc + 0.6);
  // cabine na porta
  B(g, 0.7, h + 0.1, 1.4, 0x5c6273, doorX + 0.35, y0 - 0.1, zc);
  // trem de rodas
  const wx = doorX + 0.6 + s2 * 0.6;
  C(g, 0.1, 0.12, y0, 0x7a8395, wx, 0, zc, 8); B(g, 0.9, 0.35, 0.6, 0x4c5160, wx, 0, zc);
  return g;
}
/* estacionamento: carros conforme o nível */
function parking(t) {
  const g = new THREE.Group();
  const n = 0;
  const colors = [0xff4e4e, 0x2f7bff, 0xffffff, 0x2b3245, 0x2ec27e, 0xffc928, 0x8b5cf6, 0xff8a1f];
  let k = 0;
  for (let row = 0; row < 3 && k < n; row++) for (let c = 0; c < 8 && k < n; c++, k++) {
    const car = vehicle('car', colors[(c * 3 + row * 5) % colors.length]);
    car.position.set(-10.5 + c * 3.0, 0, -4 + row * 4.2 + (row === 1 ? -0.4 : 0)); car.rotation.y = row % 2 ? 0 : Math.PI; g.add(car);
  }
  if (t >= 3) { sign(g, 'P', 1.2, 1.2, '#2f7bff', '#ffffff', 13.5, 3.2, -6); C(g, 0.07, 0.07, 2.4, 0x7a8395, 13.5, 0, -6, 6); }
  if (t >= 2) { for (let k = 0; k < 6; k++) C(g, 0.06, 0.06, 2.4, 0x7a8395, -12 + k * 5, 0, 7.6, 6); }
  if (t >= 4) {
    // prédio-garagem
    const gg = grp(g, 0, 0, 0); B(gg, 6, 0.4, 11, 0x9aa3b4, 18.5, 0, 0);
    for (let f = 1; f < 4; f++) { B(gg, 6, 0.3, 11, 0xc5cbd5, 18.5, f * 2.2, 0); B(gg, 0.1, 0.8, 11, 0x2f7bff, 21.5, f * 2.2 - 0.6, 0); for (let k = 0; k < 5; k++) C(gg, 0.2, 0.2, 2.2, 0x8a93a6, 15.7, (f - 1) * 2.2, -4.5 + k * 2.25, 6); }
    for (let k = 0; k < 6; k++) { const car = vehicle('car', [0xff4e4e, 0x2f7bff, 0xffffff, 0x2ec27e, 0xffc928, 0x2b3245][k]); car.position.set(17.5 + (k % 2) * 2.2, 2.5 + Math.floor(k / 2) * 2.2, -3 + (k % 3) * 2.6); g.add(car); }
    sign(g, 'GARAGEM', 4, 0.8, '#2f7bff', '#ffffff', 21.6, 8.4, 0, Math.PI / 2);
    // abrigo de táxis
    B(g, 4, 0.12, 1.6, 0xffc928, -9, 2.4, -7.2); C(g, 0.06, 0.06, 2.4, 0x7a8395, -10.8, 0, -7.6, 6); C(g, 0.06, 0.06, 2.4, 0x7a8395, -7.2, 0, -7.6, 6);
  }
  return g;
}
function busStop() {
  const g = new THREE.Group();
  B(g, 4.2, 0.12, 1.6, 0x2f7bff, 0, 2.4, 0); B(g, 4.2, 2.3, 0.06, M(0xbfe8ff, { opacity: 0.5 }), 0, 0, -0.75);
  [-2, 2].forEach(x => C(g, 0.06, 0.06, 2.4, 0x7a8395, x, 0, 0.6, 6));
  B(g, 2.6, 0.12, 0.45, 0x8a5a34, 0, 0.45, -0.4);
  sign(g, 'ÔNIBUS', 1.6, 0.4, '#253154', '#ffffff', 1.4, 2.95, 0.5);
  return g;
}
function tower(t) {
  const g = new THREE.Group();
  const h = [7, 11, 15][t - 1];
  B(g, 4, 1.6, 4, 0xe6eaf1, 0, 0, 0); B(g, 4.1, 0.2, 4.1, 0x2f7bff, 0, 1.6, 0);
  C(g, t >= 3 ? 1.0 : 0.8, t >= 3 ? 1.3 : 1.0, h, 0xf2f4f8, 0, 1.6, 0, 12);
  if (t >= 2) for (let i = 1; i < h / 2.2; i++) C(g, 1.05, 1.05, 0.12, 0x2f7bff, 0, 1.6 + i * 2.2, 0, 12);
  const top = 1.6 + h;
  C(g, 1.4, 1.1, 0.5, 0xd7dde8, 0, top, 0, 10);
  C(g, 2.1, 1.5, 1.6, M(0x5fc8ff, { emissive: 0x103050 }), 0, top + 0.5, 0, 10);
  C(g, 2.3, 2.3, 0.35, 0x253154, 0, top + 2.1, 0, 10);
  C(g, 0.05, 0.05, 1.8, 0x7a8395, 0, top + 2.4, 0, 5); Sp(g, 0.16, M(0xff3b3b, { emissive: 0xaa1010 }), 0, top + 4.3, 0, 8);
  if (t >= 3) { const r = grp(g, 1.2, top + 2.5, 0.6); B(r, 1.2, 0.1, 0.3, 0x7a8395, 0, 0, 0); B(r, 0.1, 0.5, 0.1, 0x7a8395, 0, -0.5, 0); }
  return g;
}
function hangar() {
  const g = new THREE.Group();
  B(g, 13, 0.1, 11, 0xb3bac6, 0, 0, 0);
  const arc = mesh(new THREE.CylinderGeometry(5.2, 5.2, 10, 20, 1, false, 0, Math.PI), M(0xdfe5ee), g, 0, 0.1, 0);
  arc.rotation.set(0, 0, 0); arc.rotation.z = Math.PI / 2; arc.rotation.y = Math.PI / 2;
  arc.rotation.set(Math.PI / 2, Math.PI / 2, 0, 'YXZ');
  arc.rotation.set(0, 0, 0); arc.rotateZ(Math.PI / 2); arc.rotateX(-Math.PI / 2);
  arc.position.set(0, 0.1, 0);
  // fachada com porta aberta (+x)
  B(g, 0.3, 4.4, 9.6, 0x2f7bff, 5.1, 0.1, 0); B(g, 0.32, 3.6, 7.4, 0x2b3245, 5.15, 0.1, 0);
  sign(g, 'HANGAR', 3.4, 0.8, '#ffffff', '#2f7bff', 5.3, 4.9, 0, Math.PI / 2);
  return g;
}
function fuelFarm() {
  const g = new THREE.Group();
  B(g, 9, 0.1, 7, 0xb3bac6, 0, 0, 0);
  [[-2.2, -1.2], [2.2, -1.2]].forEach(([x, z]) => { C(g, 1.8, 1.8, 3.2, 0xf2f4f8, x, 0.1, z, 18); C(g, 1.82, 1.82, 0.4, 0xff4e4e, x, 2.3, z, 18); mesh(G.cone(1.85, 0.5, 18), M(0xdfe5ee), g, x, 3.55, z); });
  B(g, 6, 0.5, 0.3, 0xd0d6e0, 0, 0, 2.3); [-3, -1, 1, 3].forEach(x => C(g, 0.05, 0.05, 1.2, 0xffc928, x, 0, 3.2, 6));
  const tr = vehicle('fuel'); tr.position.set(0, 0, 2.2); tr.rotation.y = Math.PI / 2; g.add(tr);
  return g;
}
/* canteiro de obra (vaga bloqueada) */
function obra(w, d) {
  const g = new THREE.Group();
  flat(g, w, d, 0xd9b77a, 0, 0, 0.03);
  for (let i = 0; i <= Math.round(w / 1.2); i++) { const x = -w / 2 + i * w / Math.round(w / 1.2); [d / 2, -d / 2].forEach(z => { B(g, 0.08, 0.8, 0.08, 0xffc928, x, 0, z); }); }
  for (let i = 0; i <= Math.round(d / 1.2); i++) { const z = -d / 2 + i * d / Math.round(d / 1.2); [w / 2, -w / 2].forEach(x => { B(g, 0.08, 0.8, 0.08, 0xffc928, x, 0, z); }); }
  [[d / 2, 0], [-d / 2, 0]].forEach(([z]) => { B(g, w, 0.18, 0.04, 0xff8a1f, 0, 0.55, z); });
  [[w / 2], [-w / 2]].forEach(([x]) => { B(g, 0.04, 0.18, d, 0xff8a1f, x, 0.55, 0); });
  for (let i = 0; i < 4; i++) { const c = mesh(G.cone(0.2, 0.5, 8), M(0xff8a1f), g, -w / 3 + i * w / 4.5, 0.25, d / 3 - (i % 2) * d / 3); B(g, 0.4, 0.05, 0.4, 0xff8a1f, c.position.x, 0, c.position.z); }
  B(g, 1.2, 0.6, 0.8, 0x8a93a6, w * 0.2, 0, -d * 0.15); B(g, 0.9, 0.5, 0.6, 0xc98a52, -w * 0.2, 0, d * 0.1);
  return g;
}
/* luzes de aproximação e auxílios por nível da pista (âncora na cabeceira esquerda) */
function runwayAids(t) {
  const g = new THREE.Group();
  const bars = [4, 7, 10][t - 1];
  for (let i = 1; i <= bars; i++) {
    const x = -i * 2.2;
    B(g, 0.12, 0.5, 0.12, 0x7a8395, x, 0, 0); B(g, 0.12, 0.08, 3.0 - (i % 3 === 0 ? 0 : 1.2), 0x7a8395, x, 0.5, 0);
    for (let k = -2; k <= 2; k++) if (Math.abs(k) < 2 || i % 3 === 0) Sp(g, 0.12, M(0xfff6c0, { emissive: 0x99905a }), x, 0.6, k * 0.6, 6);
  }
  if (t >= 2) for (let k = 0; k < 4; k++) B(g, 0.5, 0.4, 0.4, M(0xffffff, { emissive: 0x666666 }), 6 + k * 0.7, 0, -5.5);
  if (t >= 3) { B(g, 0.8, 1.2, 4.0, 0xff4e4e, 132, 0, 0); for (let i = 0; i < 6; i++) B(g, 0.1, 1.0, 0.1, 0xffffff, 132.4, 1.2, -1.8 + i * 0.7); }
  return g;
}

/* ===================================================================
   FUNDO (terreno + pista + terminal) — 3 cidades
   =================================================================== */
const CITY = [
  { name: 'vale', grass: 0x6fb352, grass2: 0x68aa4d },
  { name: 'porto', grass: 0x6cae58, grass2: 0x65a552 },
  { name: 'intl', grass: 0x74b85a, grass2: 0x6daf54 },
  { name: 'serra', grass: 0xbccbdc, grass2: 0xb0c1d4, tree: 3, bush: 0xc3d0de, shoulder: 0xc9d6e4 },
  { name: 'rio', grass: 0x7aad50, grass2: 0x73a54a, tree: 4, bush: 0x659a40 },
  { name: 'costa', grass: 0x66b86e, grass2: 0x5fb067, tree: 2, bush: 0x4aa05c },
];
function rnd(seed) { let s = seed; return () => (s = (s * 16807) % 2147483647) / 2147483647; }
function dashedX(p, x0, x1, z, len, gap, w, c, y = 0.06) { for (let x = x0; x < x1 - len; x += len + gap) flat(p, len, w, c, x + len / 2, z, y); }
function dashedZ(p, z0, z1, x, len, gap, w, c, y = 0.06) { for (let z = z0; z < z1 - len; z += len + gap) flat(p, w, len, c, x, z + len / 2, y); }
function runwayNumber(p, txt, x, z, ry) {
  const m = textMat(txt, null, '#ffffff', 256, 256, 'bold 190px Arial');
  const f = new THREE.Mesh(new THREE.PlaneGeometry(3.6, 3.6), m); f.rotation.x = -Math.PI / 2; f.rotation.z = ry; f.position.set(x, 0.07, z); p.add(f);
}
function background(city, phase = 2) {
  const g = new THREE.Group(), cfg = CITY[city], r = rnd(1234 + city * 77);
  const m = L.map;
  flat(g, 400, 400, cfg.grass, 0, 0, -0.1);
  // faixas de grama mais escura (corte)
  for (let i = 0; i < 26; i++) flat(g, 6, 160, i % 2 ? cfg.grass : cfg.grass2, -80 + i * 6.4, -6, -0.06).castShadow = false;
  // ===== cenário por cidade =====
  if (city === 0) {
    // plantações e lago
    const crops = [0xe8c75a, 0x9bd65a, 0xd9a54a, 0x7ec850];
    for (let i = 0; i < 10; i++) for (let j = 0; j < 3; j++) flat(g, 9, 7, crops[(i + j) % 4], -88 + i * 10, 40 + j * 8, -0.04);
    flat(g, 18, 12, 0x4fb8f0, 70, 36, -0.03); flat(g, 19.5, 13.5, 0xd9c48a, 70, 36, -0.05);
    for (let i = 0; i < 120; i++) { const x = -100 + r() * 200, z = -70 + r() * 140; if (x > m.x0 - 2 && x < m.x1 + 2 && z > -46 && z < 24) continue; if (x > 29 && x < 47 && z > 22 && z < 37) continue; if (z > 34 && z < 62 && x < 10) continue; tree(g, x, z, 0.8 + r() * 0.9, r() < 0.4 ? 1 : 0); }
    // celeiro
    const bn = grp(g, 30, 0, 44); B(bn, 5, 3, 4, 0xd94b3a, 0, 0, 0); const rf = mesh(G.cone(3.8, 2, 4), M(0x8a3a2a), bn, 0, 4, 0); rf.rotation.y = Math.PI / 4; B(bn, 1.6, 2, 0.1, 0xffffff, 0, 0, 2.05);
  } else if (city === 1) {
    // cidade: quadras de prédios coloridos e rio
    flat(g, 300, 10, 0x4fa8e8, 0, 58, -0.03); flat(g, 300, 12, 0xcfc39a, 0, 58, -0.05);
    const cols = [0xf6f1e7, 0xffd38a, 0x9fd3ff, 0xffb3a7, 0xc9b8ff, 0xd8e2ef, 0xa8e6cf];
    for (let i = 0; i < 160; i++) {
      const x = -110 + r() * 220, z = -72 + r() * 150;
      if (x > m.x0 - 4 && x < m.x1 + 4 && z > -48 && z < 26) continue;
      if (z > 50 && z < 66) continue;
      if (x > 29 && x < 47 && z > 22 && z < 37) continue; if (z > 22 && z < 40 && x > -40 && x < -6) continue;
      const h = 2 + r() * (Math.abs(z) > 55 || Math.abs(x) > 95 ? 14 : 6), w = 3 + r() * 3, d = 3 + r() * 3;
      B(g, w, h, d, cols[Math.floor(r() * cols.length)], x, 0, z);
      B(g, w * 0.9, 0.2, d * 0.9, 0x8a93a6, x, h, z);
      for (let k = 1; k < h - 0.6; k += 1.2) { B(g, w + 0.02, 0.35, d * 0.8, 0x6a8fbf, x, k, z); }
    }
    for (let i = 0; i < 40; i++) { const x = -100 + r() * 200, z = 26 + r() * 22; if (x > 29 && x < 47 && z > 22 && z < 37) continue; if (x > -40 && x < -6) continue; tree(g, x, z, 0.8 + r() * 0.5); }
  } else if (city === 3) {
    // serra nevada: montanhas ao fundo, lago congelado, chalés e pinheiros
    for (let i = 0; i < 16; i++) { const x = -120 + i * 16 + r() * 6, z = -70 - r() * 30, h = 14 + r() * 16, R0 = 11 + r() * 5; const mt = mesh(G.cone(R0, h, 5), M(0x7f8da6), g, x, h / 2, z); mt.rotation.y = r() * 3; const cap = mesh(G.cone(R0 * 0.47, h * 0.45, 5), M(0xffffff), g, x, h * 0.785, z); cap.rotation.y = mt.rotation.y; }
    flat(g, 26, 16, 0xbfe6ff, 66, 40, -0.03); flat(g, 28, 18, 0xffffff, 66, 40, -0.05); for (let i = 0; i < 6; i++) flat(g, 4 + r() * 5, 0.2, 0xffffff, 58 + r() * 16, 34 + r() * 12, -0.02);
    for (let i = 0; i < 170; i++) { const x = -105 + r() * 210, z = -62 + r() * 130; if (x > m.x0 - 2 && x < m.x1 + 2 && z > -46 && z < 24) continue; if (x > 50 && z > 30 && z < 50) continue; if (x > 29 && x < 47 && z > 22 && z < 37) continue; if (z > 22 && z < 40 && x > -40 && x < -6) continue; tree(g, x, z, 0.8 + r() * 1.0, 3); }
    const ch = [0xb5653a, 0x8a4a2a, 0xc98a52];
    for (let i = 0; i < 14; i++) { const x = -100 + i * 13 + r() * 4, z = 44 + r() * 16; const c = grp(g, x, 0, z); B(c, 3.6, 2.2, 3, ch[i % 3], 0, 0, 0); const rf = mesh(G.cone(3.1, 1.8, 4), M(0xffffff), c, 0, 3.1, 0); rf.rotation.y = Math.PI / 4; B(c, 0.5, 1.4, 0.5, 0x6b7280, 1, 2.6, -0.6); B(c, 0.9, 0.8, 0.08, M(0xffe9a0, { emissive: 0x806a20 }), 0, 0.9, 1.52); }
    for (let i = 0; i < 40; i++) Sp(g, 0.5 + r() * 0.7, 0xffffff, -100 + r() * 200, 0.1, 26 + r() * 40, 7);
  } else if (city === 4) {
    // metrópole do rio dourado: rio largo com barcos, arranha-céus espelhados e ipês
    flat(g, 400, 22, 0xcfa23c, 0, -62, -0.03); flat(g, 400, 26, 0xcfc39a, 0, -62, -0.05);
    for (let i = 0; i < 24; i++) flat(g, 4 + r() * 6, 0.25, 0xe8c66a, -110 + r() * 220, -70 + r() * 16, -0.02);
    for (let i = 0; i < 6; i++) { const b = grp(g, -90 + i * 34 + r() * 8, 0, -66 + r() * 8); B(b, 4, 0.7, 1.5, 0xffffff, 0, 0, 0); B(b, 1.6, 0.8, 1.1, [0xe8343b, 0x2f7bff, 0x2ec27e][i % 3], -0.4, 0.7, 0); }
    B(g, 3, 0.5, 30, 0x8a93a6, 20, 1.2, -62); for (let z = -74; z <= -50; z += 8) B(g, 1, 1.4, 1, 0x6b7280, 20, 0, z);
    const cols = [0x5b8cff, 0x3fb6f0, 0xffc531, 0x9aa3b4, 0x7c5cfa, 0x18b48d];
    for (let i = 0; i < 120; i++) {
      const x = -110 + r() * 220, z = 26 + r() * 46;
      if (z < 42 && x > -42 && x < -4) continue; if (x > 28 && x < 48 && z < 36) continue;
      const h = 4 + r() * (z > 50 ? 22 : 9), w = 3 + r() * 2.5;
      B(g, w, h, w, cols[Math.floor(r() * cols.length)], x, 0, z); B(g, w * 0.5, 1.2, w * 0.5, 0x6b7280, x, h, z);
      for (let k = 1; k < h - 0.5; k += 1.1) B(g, w + 0.03, 0.3, w + 0.03, 0xdff1ff, x, k, z);
    }
    for (let i = 0; i < 90; i++) { const x = -105 + r() * 210, z = -52 + r() * 76; if (x > m.x0 - 2 && x < m.x1 + 2 && z > -46 && z < 24) continue; tree(g, x, z, 0.8 + r() * 0.7, 4); }
  } else if (city === 5) {
    // costa esmeralda: mar dos dois lados, ilhas, recifes, bangalôs e coqueiros
    flat(g, 400, 120, 0x2aa9a0, 0, -110, -0.02); flat(g, 400, 7, 0xf7e7b0, 0, -49, -0.04); flat(g, 400, 12, 0x66cfc0, 0, -56, -0.015);
    flat(g, 400, 90, 0x2aa9a0, 0, 104, -0.02); flat(g, 400, 7, 0xf7e7b0, 0, 57, -0.04); flat(g, 400, 10, 0x66cfc0, 0, 63, -0.015);
    for (let i = 0; i < 40; i++) flat(g, 3 + r() * 6, 0.25, 0xd8fff5, -110 + r() * 220, r() < 0.5 ? -60 - r() * 30 : 66 + r() * 20, 0.0);
    for (let i = 0; i < 5; i++) { const x = -90 + i * 42 + r() * 10, z = -72 - r() * 14; flat(g, 9, 6, 0xf7e7b0, x, z, -0.01); flat(g, 6, 3.6, 0x62c27a, x, z, 0.0); tree(g, x - 1, z, 1.1, 2); tree(g, x + 1.4, z + 0.6, 0.9, 2); }
    for (let i = 0; i < 12; i++) { const x = -100 + i * 17 + r() * 4, z = 60 + r() * 2; B(g, 0.4, 0.5, 8, 0xb58450, x, 0, z + 5); const b = grp(g, x, 0, z + 9); C(b, 1.5, 1.5, 1.5, 0xf7f9fc, 0, 0.5, 0, 8); mesh(G.cone(2.1, 1.5, 8), M(0xc98a52), b, 0, 2.75, 0); }
    const hc = [0xffffff, 0xffe0b0, 0xbff5e6, 0xffc9d6];
    for (let i = 0; i < 16; i++) { const x = -100 + i * 13.5 + r() * 3, z = 42 + r() * 8; if (x > -44 && x < -2) continue; if (x > 28 && x < 48) continue; const h = 3 + r() * 6; B(g, 5, h, 4, hc[i % 4], x, 0, z); B(g, 5.3, 0.3, 4.3, 0x14b8a6, x, h, z); for (let k = 1; k < h - 0.6; k += 1.3) B(g, 5.02, 0.4, 3.2, 0x7fe3d0, x, k, z); }
    for (let i = 0; i < 130; i++) { const x = -105 + r() * 210, z = r() < 0.4 ? -50 + r() * 4 : 24 + r() * 32; if (x > m.x0 && x < m.x1 && z < -45) continue; if (x > -40 && x < -6 && z < 40 && z > 0) continue; if (x > 30 && x < 46 && z > 22 && z < 36) continue; tree(g, x, z, 0.9 + r() * 0.5, 2); }
  } else {
    // litoral: mar atrás da pista, praia e hotéis
    flat(g, 400, 120, 0x3fb6f0, 0, -110, -0.02); flat(g, 400, 6, 0xf2dc9e, 0, -48, -0.04);
    for (let i = 0; i < 30; i++) flat(g, 3 + r() * 6, 0.25, 0xbfe9ff, -110 + r() * 220, -54 - r() * 40, 0.0);
    for (let i = 0; i < 60; i++) { const x = -100 + r() * 200, z = -49 + r() * 4; if (x > m.x0 && x < m.x1 && z > -46) continue; tree(g, x, z, 0.8 + r() * 0.4, 2); }
    const hc = [0xffffff, 0xffe0b0, 0xbfe9ff, 0xffc9d6];
    for (let i = 0; i < 26; i++) { const x = -105 + i * 8.5 + r() * 2, z = 40 + r() * 20; if (x > 29 && x < 47 && z > 22 && z < 37) continue; if (x > -40 && x < -6 && z < 42) continue; const h = 4 + r() * 12; B(g, 5, h, 4, hc[i % 4], x, 0, z); for (let k = 1; k < h - 0.6; k += 1.3) B(g, 5.02, 0.4, 3.2, 0x6ac0ff, x, k, z); }
    for (let i = 0; i < 70; i++) { const x = -100 + r() * 200, z = 22 + r() * 40; if (x > 29 && x < 47 && z > 22 && z < 37) continue; if (x > -40 && x < -6 && z < 40) continue; tree(g, x, z, 0.9 + r() * 0.4, 2); }
  }
  // ===== detalhes do terreno: flores, pedras e moitas =====
  { const r3 = rnd(555 + city * 13); const fc = city === 3 ? [0xffffff, 0xcfe0f0] : [0xffffff, 0xffe27a, 0xff9ac4, 0xff7a6a];
    for (let i = 0; i < 260; i++) { const x = -105 + r3() * 210, z = -60 + r3() * 122; if (x > m.x0 + 4 && x < m.x1 - 4 && z > -47 && z < 23) continue; if (city !== 3 && city !== 5 && z > 38) continue; const k = r3();
      if (k < 0.55) { for (let j = 0; j < 4; j++) Sp(g, 0.13, fc[(i + j) % fc.length], x + r3() * 1.6, 0.08, z + r3() * 1.6, 5).castShadow = false; }
      else if (k < 0.8) { const b = Sp(g, 0.45 + r3() * 0.3, cfg.bush ?? 0x4fae4c, x, 0.2, z, 7); b.scale.y = 0.7; }
      else { const st = Sp(g, 0.3 + r3() * 0.35, city === 3 ? 0xc5d0de : 0xa9b1bf, x, 0.1, z, 6); st.scale.y = 0.6; } } }
  // lote do prédio exclusivo (ao lado da estrada)
  if (phase >= 1) { flat(g, 11, 8.5, city === 3 ? 0xdfe6ee : 0xd9dde6, L.special.x, L.special.z, 0.01); flat(g, 3, 4, P.asph2, L.special.x - 4, L.special.z - 6, 0.005); }
  // ===== fase do aeroporto =====
  const ph = PH[phase], tx1 = ph.tx1, rx1 = ph.rx1;
  const wild = (x, z) => (x > tx1 + 4 && x < 80 && z > -29 && z < 16.5 && !(x > 40 && x < 56 && z > -20 && z < -9 && phase >= 3)) || (x > rx1 + 6 && x < 80 && z > -45 && z <= -29);
  // mato onde o aeroporto ainda vai crescer
  if (phase < 2) { const r2 = rnd(99 + phase); for (let i = 0; i < (phase === 0 ? 150 : 70); i++) { const x = -20 + r2() * 100, z = -46 + r2() * 62; if (!wild(x, z)) continue; if (Math.abs(x - L.tower.x) < 4 && Math.abs(z - L.tower.z) < 4) continue; tree(g, x, z, 0.7 + r2() * 0.8, cfg.tree ?? (city === 2 ? 2 : r2() < 0.4 ? 1 : 0)); } for (let i = 0; i < 40; i++) { const x = -20 + r2() * 100, z = -46 + r2() * 62; if (wild(x, z)) flat(g, 1.5 + r2() * 2, 1 + r2() * 1.5, cfg.bush ?? (city === 1 ? 0x5e9e4a : 0x5fa244), x, z, -0.03); } }
  // ===== cerca do sítio =====
  const fx1 = phase < 2 ? rx1 + 12 : m.x1 - 6;
  const fence = (x0, z0, x1, z1) => { const len = Math.hypot(x1 - x0, z1 - z0); const f = B(g, x0 === x1 ? 0.06 : len, 0.7, x0 === x1 ? len : 0.06, phase === 0 ? 0xa8875a : 0xc0c8d6, (x0 + x1) / 2, 0, (z0 + z1) / 2); f.castShadow = false; };
  fence(m.x0 + 6, -46, fx1, -46); fence(m.x0 + 6, -46, m.x0 + 6, 18); fence(fx1, -46, fx1, 18);
  if (phase === 0) for (let x = m.x0 + 6; x < fx1; x += 3) B(g, 0.16, 0.9, 0.16, 0x8a6a40, x, 0, -46);
  // ===== pista =====
  const rw = L.runway, rl = rx1 - rw.x0, rc = (rw.x0 + rx1) / 2, rwW = ph.rw;
  if (phase === 0) {
    flat(g, rl + 4, rwW + 2, 0x9cc472, rc, rw.z, -0.02);
    flat(g, rl, rwW, 0xc9a46a, rc, rw.z, 0.0);
    for (const dz of [-1.4, 1.4]) flat(g, rl - 6, 0.7, 0xb08c58, rc, rw.z + dz, 0.02);
    for (let x = rw.x0 + 1; x < rx1; x += 4) for (const sd of [-1, 1]) B(g, 0.35, 0.18, 0.35, 0xffffff, x, 0, rw.z + sd * (rwW / 2 + 0.3));
  } else {
    flat(g, rl + 6, rwW + 4, cfg.shoulder ?? 0xa9d48e, rc, rw.z, -0.02);
    flat(g, rl, rwW, P.asph, rc, rw.z, 0.0);
    dashedX(g, rw.x0 + 10, rx1 - 10, rw.z, 3, 2.4, 0.3, 0xffffff);
    flat(g, rl, 0.18, 0xffffff, rc, rw.z - rwW / 2 + 0.3, 0.05); flat(g, rl, 0.18, 0xffffff, rc, rw.z + rwW / 2 - 0.3, 0.05);
    for (const [x0, sg] of [[rw.x0 + 0.8, 1], [rx1 - 0.8, -1]]) {
      for (let k = 0; k < 8; k++) flat(g, 3, 0.35, 0xffffff, x0 + sg * 1.5, rw.z - rwW / 2 + 0.9 + k * (rwW - 1.8) / 7, 0.05);
      for (let k = 0; k < (phase >= 2 ? 3 : 2); k++) { flat(g, 2.2, 0.4, 0xffffff, x0 + sg * (12 + k * 6), rw.z - 1.6, 0.05); flat(g, 2.2, 0.4, 0xffffff, x0 + sg * (12 + k * 6), rw.z + 1.6, 0.05); }
    }
    runwayNumber(g, '09', rw.x0 + 7, rw.z, Math.PI / 2); runwayNumber(g, '27', rx1 - 7, rw.z, -Math.PI / 2);
  }
  // ===== taxiways e pátio =====
  const ap = L.apron, apx1 = ph.apx1, laneX1 = ph.conn[1];
  const pave = phase === 0 ? 0xc9a46a : P.asph2, line = phase === 0 ? null : 0xffc928;
  for (const x of ph.conn) { flat(g, 3.6, Math.abs(rw.z - L.lane.z) + 1.5, pave, x, (rw.z + L.lane.z) / 2, 0.01); if (line) flat(g, 0.14, Math.abs(rw.z - L.lane.z), line, x, (rw.z + L.lane.z) / 2, 0.05); }
  if (phase >= 3) { // taxiway paralela do hub com luzes
    flat(g, 100, 3.4, P.asph2, -4, -29.5, 0.008); flat(g, 100, 0.14, 0xffc928, -4, -29.5, 0.05);
    for (let x = -52; x < 46; x += 4) Sp(g, 0.12, M(0x3f8bff, { emissive: 0x2050a0 }), x, 0.1, -27.6, 6);
  }
  if (phase === 0) {
    flat(g, apx1 - ap.x0, ap.z1 - L.lane.z + 2, 0xd2b47e, (ap.x0 + apx1) / 2, (L.lane.z - 2 + ap.z1) / 2, 0.012);
    flat(g, laneX1 - ap.x0 + 2, 3.6, 0xc9a46a, (ap.x0 + laneX1) / 2, L.lane.z, 0.014);
    for (const gx of L.gates.slice(0, 2)) { for (let z = L.standNose - 1; z > L.lane.z + 2; z -= 2) B(g, 0.3, 0.12, 0.3, 0xffffff, gx, 0, z); }
  } else {
    flat(g, apx1 - ap.x0, ap.z1 - ap.z0, P.concrete, (ap.x0 + apx1) / 2, (ap.z0 + ap.z1) / 2, 0.012);
    for (let x = ap.x0; x < apx1; x += 6) flat(g, 0.05, ap.z1 - ap.z0, P.conc2, x, (ap.z0 + ap.z1) / 2, 0.03);
    for (let z = ap.z0; z < ap.z1; z += 6) flat(g, apx1 - ap.x0, 0.05, P.conc2, (ap.x0 + apx1) / 2, z, 0.03);
    flat(g, laneX1 - L.lane.x0, 0.16, 0xffc928, (L.lane.x0 + laneX1) / 2, L.lane.z, 0.05);
    for (const gx of L.gates.slice(0, [2, 3, 6, 6][phase])) {
      flat(g, 0.16, Math.abs(L.lane.z - L.standNose) + 0.5, 0xffc928, gx, (L.lane.z + L.standNose) / 2, 0.05);
      flat(g, 2.8, 0.16, 0xffc928, gx, L.standNose - 0.5, 0.05);
      flat(g, 11, 0.12, 0xff4e4e, gx, ap.z0 + 4.2, 0.05);
      flat(g, 0.12, 13, 0xffffff, gx - 6, -12, 0.05);
      if (phase < 2) { flat(g, 2.4, 3.2, 0xffffff, gx + 3.2, -7.6, 0.04); flat(g, 2.2, 3.0, P.concrete, gx + 3.2, -7.6, 0.045); for (let k = 0; k < 4; k++) flat(g, 2.2, 0.25, 0x2f7bff, gx + 3.2, -6.5 - k * 0.7, 0.05); }
    }
    if (phase >= 3) { flat(g, 16, 18, P.concrete, 48, 2, 0.012); flat(g, 15.6, 0.16, 0xffc928, 48, -6.5, 0.05); }
  }
  // ===== estradas =====
  const rd = L.road, dirt = phase === 0;
  flat(g, rd.x1 - rd.x0 + 40, dirt ? 5 : 6, dirt ? 0xc9a46a : P.asph, (rd.x0 + rd.x1) / 2, rd.z, 0.0);
  if (!dirt) { dashedX(g, rd.x0 - 20, rd.x1 + 20, rd.z, 2, 2, 0.18, 0xffffff); flat(g, rd.x1 - rd.x0 + 40, 0.5, 0xdfe3ea, (rd.x0 + rd.x1) / 2, rd.z - 3.2, 0.03); }
  else for (const dz of [-1.2, 1.2]) flat(g, rd.x1 - rd.x0 + 40, 0.6, 0xb08c58, (rd.x0 + rd.x1) / 2, rd.z + dz, 0.02);
  flat(g, dirt ? 6 : 8, 70, dirt ? 0xc9a46a : P.asph, 64, 52, 0.0);
  flat(g, tx1 - L.term.x0 + 6, 3.2, dirt ? 0xd8c08f : 0xdfe3ea, (L.term.x0 + tx1) / 2, 17.5, 0.04);
  const pk = L.parking;
  flat(g, 28, 14, dirt ? 0xd2b47e : P.asph2, pk.x, pk.z, 0.01);
  if (!dirt) for (let row = 0; row < 3; row++) for (let c = 0; c <= 8; c++) flat(g, 0.1, 2.2, 0xffffff, pk.x - 12 + c * 3.0, pk.z - 4 + row * 4.2, 0.05);
  flat(g, 3, 70, dirt ? 0xc9a46a : P.asph2, pk.x + 15.5, pk.z + 20, 0.0);
  if (!dirt) for (let x = -86; x < (phase >= 2 ? 80 : tx1 + 20); x += 12) lamp(g, x, rd.z + 3.4);
  else for (let x = -80; x < 10; x += 10) { C(g, 0.09, 0.11, 3.2, 0x8a6a40, x, 0, rd.z + 3.4, 6); B(g, 0.8, 0.06, 0.06, 0x8a6a40, x, 3.0, rd.z + 3.4); }
  // ===== terminal (corte "casa de bonecas") =====
  const tm = { x0: L.term.x0, x1: tx1, z0: L.term.z0, z1: L.term.z1 };
  const tw0 = tm.x1 - tm.x0, td = tm.z1 - tm.z0, tcx = (tm.x0 + tm.x1) / 2, tcz = (tm.z0 + tm.z1) / 2;
  if (phase === 0) {
    // barracão de madeira
    B(g, tw0 + 1, 0.3, td + 1, 0x9a7448, tcx, 0, tcz).castShadow = false;
    B(g, tw0, 0.05, td, 0xd9b483, tcx, 0.3, tcz).castShadow = false;
    for (let x = tm.x0 + 1; x < tm.x1; x += 1.2) flat(g, 0.06, td, 0xbf9563, x, tcz, 0.36);
    flat(g, 19, 11, 0xe8d3a8, -36.5, 9.5, 0.37);  // tapete do check-in
    flat(g, 14, 10, 0xd8c7e8, -15, 6.8, 0.37);     // tapete do raio-X
    flat(g, tw0 - 2, 3.0, 0xc8a06e, tcx, -2.6, 0.375);
    // parede do fundo de tábuas com janelas
    B(g, 0.4, 3.4, td, 0xb88a56, tm.x0 + 0.2, 0.3, tcz);
    for (let y = 0.6; y < 3.6; y += 0.5) B(g, 0.42, 0.05, td, 0x9a7448, tm.x0 + 0.2, y, tcz);
    for (let z = tm.z0 + 2.5; z < tm.z1 - 1; z += 5) { B(g, 0.08, 1.2, 1.8, M(0x8fd6ff), tm.x0 + 0.44, 1.5, z); B(g, 0.1, 0.12, 2.0, 0xffffff, tm.x0 + 0.46, 2.7, z); }
    B(g, 0.6, 0.25, td + 0.6, 0xe8343b, tm.x0 + 0.2, 3.7, tcz);
    sign(g, 'AEROCLUBE', 6, 1.1, '#e8343b', '#ffffff', tm.x0 + 0.5, 5.4, tcz, Math.PI / 2);
    // frente: guarda-corpo e porta
    for (let x = tm.x0 + 0.5; x < tm.x1; x += 2) { if (Math.abs(x - L.door.x) < 2.5) continue; B(g, 0.14, 0.9, 0.14, 0x8a6a40, x, 0.3, tm.z1 - 0.1); }
    B(g, tw0, 0.1, 0.12, 0x8a6a40, tcx, 1.1, tm.z1 - 0.1);
    for (const x of [L.door.x - 2.4, L.door.x + 2.4]) B(g, 0.22, 3.2, 0.22, 0x8a6a40, x, 0.3, tm.z1);
    B(g, 5.4, 0.18, 1.6, 0xe8343b, L.door.x, 3.4, tm.z1 + 0.4);
    B(g, 0.12, 0.9, td, 0x8a6a40, tm.x1 - 0.06, 0.3, tcz); B(g, 0.12, 0.1, td, 0x8a6a40, tm.x1 - 0.06, 1.15, tcz);
    // biruta e barris
    for (let i = 0; i < 3; i++) C(g, 0.4, 0.4, 0.9, [0xe8343b, 0x2f7bff, 0x6b7280][i], -50 + i * 0.9, 0, -8 + (i % 2) * 0.8, 10);
  } else {
    B(g, tw0 + 1, 0.3, td + 1, 0xd7dde8, tcx, 0, tcz).castShadow = false;
    B(g, tw0, 0.05, td, P.floor, tcx, 0.3, tcz).castShadow = false;
    for (let x = tm.x0 + 2; x < tm.x1; x += 2) for (let z = tm.z0 + 2; z < tm.z1; z += 2) if (Math.abs(Math.round((x + z) / 2)) % 2 === 0) flat(g, 2, 2, P.floor2, x - 1, z - 1, 0.36);
    flat(g, 23, 13, 0xcfe2ff, -35, 9, 0.375);
    flat(g, 19, 12, 0xe4dcff, -13.5, 6.5, 0.375);
    flat(g, Math.min(23, tm.x1 - 0.5 + 4), 9, 0xffe9c7, Math.min(7.5, (tm.x1 - 4) / 2 + 2), 7, 0.375);
    flat(g, tw0 - 2, 3.2, 0x5b8cff, tcx, -2.6, 0.38);
    flat(g, tw0 - 2, 0.2, 0xffc928, tcx, -1.0, 0.4);
    for (let x = -26; x < tm.x1 - 4; x += 8) { const a = mesh(G.cone(0.5, 1.1, 3), M(0xffffff), g, x, 0.41, -2.6); a.rotation.set(-Math.PI / 2, 0, -Math.PI / 2); a.scale.y = 0.1; a.castShadow = false; }
    for (let x = tm.x0 + 6; x < tm.x1; x += 12) for (const z of [3, 12]) { C(g, 0.3, 0.3, 4.2, 0xe6eaf1, x, 0.3, z, 10); }
    B(g, 0.5, 4.5, td, 0xe6eaf1, tm.x0 + 0.25, 0.3, tcz);
    for (let z = tm.z0 + 1.5; z < tm.z1 - 1; z += 3) B(g, 0.08, 2.6, 2.2, M(0x8fd6ff), tm.x0 + 0.52, 1.3, z);
    B(g, 0.6, 0.4, td + 0.4, phase >= 3 ? 0x1e2a47 : 0x2f7bff, tm.x0 + 0.25, 4.8, tcz);
    if (phase >= 3) sign(g, 'SKYPORT HUB', 9, 1.2, '#1e2a47', '#ffc928', tm.x0 + 0.6, 6.6, tcz, Math.PI / 2);
    B(g, tw0, 0.5, 0.3, 0xe6eaf1, tcx, 0.3, tm.z1 - 0.15);
    B(g, 6, 0.08, 1.6, 0x2f7bff, L.door.x, 3.2, tm.z1 + 0.6);
    for (const x of [L.door.x - 3, L.door.x + 3]) C(g, 0.1, 0.1, 3.0, 0x9aa3b4, x, 0.3, tm.z1 + 1.2, 6);
    B(g, 0.3, 0.5, td, 0xe6eaf1, tm.x1 - 0.15, 0.3, tcz);
  }
  // ===== lado terra =====
  for (let x = -86; x < 80; x += 7) { if (x > -42 && x < -4) continue; if (phase >= 3 && x > -4 && x < 30) continue; if (x > 30 && x < 47) continue; tree(g, x, 24 + (x % 2), 0.9, cfg.tree ?? (city === 2 ? 2 : 0)); }
  if (phase >= 3) {
    // praça do hub: canteiros, palmeiras e letreiro
    for (let x = -2; x < 30; x += 4) { flat(g, 3, 1.2, 0x3fae5a, x, 23.6, 0.06); Sp(g, 0.5, 0xff7ab6, x - 0.8, 0.3, 23.6, 8); Sp(g, 0.5, 0xffc928, x + 0.8, 0.3, 23.6, 8); }
    for (let x = 0; x < 30; x += 8) tree(g, x, 27, 1.1, 2);
    const lt = 'SKYPORT'; for (let i = 0; i < lt.length; i++) sign(g, lt[i], 1.6, 1.8, '#2f7bff', '#ffffff', 4 + i * 2.2, 2.2, 26, 0);
  }
  // biruta
  C(g, 0.06, 0.06, 3, 0xffffff, rx1 - 6, 0, rw.z + 7, 6); const ws = mesh(G.cone(0.35, 1.6, 8), M(0xff8a1f), g, rx1 - 5.3, 2.8, rw.z + 7); ws.rotation.z = Math.PI / 2;
  return g;
}
/* parede airside: sobreposição desenhada depois dos aviões estacionados */
function airsideWall(x1 = L.term.x1, kind = 2) {
  const g = new THREE.Group(), x0 = L.term.x0, tw0 = x1 - x0, tcx = (x0 + x1) / 2;
  const gs = L.gates.slice(0, kind === 0 ? 2 : 3);
  const door = x => kind < 2 && gs.some(gx => Math.abs(x - (gx + 3.2)) < 1.3);
  if (kind === 0) {
    // cerca de madeira com portinholas
    B(g, tw0, 0.15, 0.3, 0x8a6a40, 0, 0.3, 0);
    for (let x = x0 + 0.5; x < x1; x += 1.5) { if (door(x)) continue; B(g, 0.16, 1.3, 0.16, 0x8a6a40, x - tcx, 0.3, 0); }
    for (const y of [0.8, 1.4]) { let s0 = x0; for (let x = x0; x <= x1; x += 0.25) { const d = door(x) || x >= x1; if (d && x > s0 + 0.3) { B(g, x - s0, 0.1, 0.08, 0xb88a56, (s0 + x) / 2 - tcx, y, 0); } if (d) s0 = x + 0.25; } }
    for (const gx of gs) { sign(g, 'EMBARQUE', 2.4, 0.5, '#e8343b', '#ffffff', gx + 3.2 - tcx, 2.6, 0); [gx + 2.0, gx + 4.4].forEach(x => B(g, 0.14, 2.6, 0.14, 0x8a6a40, x - tcx, 0.3, 0)); }
    return g;
  }
  B(g, tw0, 0.6, 0.4, 0xe6eaf1, 0, 0.3, 0);
  for (let x = x0 + 1; x < x1 - 0.5; x += 2) { if (door(x + 0.5)) continue; B(g, 1.85, 1.6, 0.12, M(0x9fdcff, { opacity: 0.55 }), x - tcx + 0.5, 0.9, 0); C(g, 0.06, 0.06, 1.6, 0xb8c0cf, x - tcx - 0.45, 0.9, 0, 6); }
  if (kind < 2) for (const gx of gs) { B(g, 0.2, 2.4, 0.4, 0x2f7bff, gx + 2.0 - tcx, 0.3, 0); B(g, 0.2, 2.4, 0.4, 0x2f7bff, gx + 4.4 - tcx, 0.3, 0); sign(g, 'SAÍDA ' + (L.gates.indexOf(gx) + 1), 2.6, 0.5, '#2f7bff', '#ffffff', gx + 3.2 - tcx, 3.1, 0); }
  B(g, tw0, 0.18, 0.44, 0x2f7bff, 0, 2.5, 0);
  return g;
}
/* ===== prédio exclusivo de cada aeroporto ===== */
function espFeira() { // Vale Verde: feira da roça
  const g = new THREE.Group();
  B(g, 8, 0.1, 6, 0xd2b47e, 0, 0, 0).castShadow = false;
  const cs = [0xe8343b, 0x2f7bff, 0xffc928];
  for (let i = 0; i < 3; i++) { const x = -2.6 + i * 2.6; B(g, 2.0, 0.9, 1.2, 0xb88a56, x, 0, 0.6); [-0.9, 0.9].forEach(dx => C(g, 0.06, 0.06, 2.2, 0x8a6a40, x + dx, 0, 0.1, 6)); for (let k = 0; k < 4; k++) B(g, 0.55, 0.08, 1.7, k % 2 ? 0xffffff : cs[i], x - 0.83 + k * 0.55, 2.2, 0.5); for (let k = 0; k < 3; k++) Sp(g, 0.2, [0xff4e4e, 0xffc928, 0x3fae5a][(k + i) % 3], x - 0.5 + k * 0.5, 1.05, 0.7, 8); }
  B(g, 4.4, 2.6, 2.6, 0xc0392b, 0, 0, -1.9); const rf = mesh(G.cone(2.9, 1.6, 4), M(0x8a3324), g, 0, 3.4, -1.9); rf.rotation.y = Math.PI / 4; rf.scale.set(1.1, 1, 0.7);
  B(g, 1.3, 1.7, 0.08, 0xf7f9fc, 0, 0, -0.58);
  sign(g, 'FEIRA DA ROÇA', 4.2, 0.6, '#3fae5a', '#ffffff', 0, 3.9, 1.3);
  [-3.4, 3.4].forEach(x => C(g, 0.07, 0.07, 3.6, 0x8a6a40, x, 0, 1.3, 6));
  return g;
}
function espHotel() { // Porto Azul: hotel do aeroporto
  const g = new THREE.Group();
  B(g, 7, 0.4, 5.4, 0xdfe3ea, 0, 0, 0);
  B(g, 5.6, 9, 4, 0xf7f9fc, 0, 0.4, -0.3);
  for (let f = 0; f < 5; f++) { for (let i = 0; i < 4; i++) B(g, 0.9, 1.0, 0.08, M(0x8fd6ff), -1.95 + i * 1.3, 1.5 + f * 1.6, 1.72); for (let i = 0; i < 3; i++) B(g, 0.08, 1.0, 0.9, M(0x8fd6ff), 2.82, 1.5 + f * 1.6, -1.5 + i * 1.3); B(g, 5.7, 0.12, 4.1, 0x2f7bff, 0, 2.75 + f * 1.6, -0.3); }
  B(g, 5.8, 0.5, 4.2, 0x1e2a47, 0, 9.4, -0.3);
  sign(g, 'HOTEL', 3.2, 0.9, '#1e2a47', '#ffc928', 0, 10.4, 1.8);
  B(g, 3, 0.15, 1.6, 0xe8343b, 0, 1.9, 2.4); [-1.3, 1.3].forEach(x => C(g, 0.07, 0.07, 1.6, 0xb8c0cf, x, 0.4, 3.0, 6));
  B(g, 1.4, 1.5, 0.08, M(0x5b8cff), 0, 0.4, 1.72);
  return g;
}
function espAlfandega() { // SkyPort Internacional: terminal internacional
  const g = new THREE.Group();
  B(g, 8, 0.3, 6, 0xdfe3ea, 0, 0, 0);
  B(g, 7, 3.2, 4.6, 0xf7f9fc, 0, 0.3, -0.3); B(g, 7.2, 0.35, 4.8, 0x7c5cfa, 0, 3.5, -0.3);
  for (let i = 0; i < 5; i++) B(g, 1.0, 2.0, 0.08, M(0x8fd6ff), -2.8 + i * 1.4, 0.8, 2.02);
  const gl = Sp(g, 1.5, 0x2f7bff, 0, 5.6, -0.3, 16); for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; Sp(g, 0.5, 0x3fae5a, Math.cos(a) * 1.15, 5.6 + Math.sin(a * 2) * 0.6, -0.3 + Math.sin(a) * 1.15, 8); }
  C(g, 0.12, 0.12, 0.6, 0x9aa3b4, 0, 3.85, -0.3, 8);
  const fl = [0xe8343b, 0x2ec27e, 0xffc928, 0x2f7bff, 0xff8a1f]; for (let i = 0; i < 5; i++) { C(g, 0.05, 0.05, 3.4, 0xffffff, -3.4 + i * 1.7, 0.3, 2.7, 5); B(g, 0.8, 0.5, 0.04, fl[i], -3.0 + i * 1.7, 3.1, 2.7); }
  sign(g, 'INTERNACIONAL', 5.2, 0.6, '#7c5cfa', '#ffffff', 0, 3.0, 2.08);
  return g;
}
function espDegelo() { // Serra Alta: estação de degelo
  const g = new THREE.Group();
  B(g, 8, 0.2, 6, 0xeef3fa, 0, 0, 0);
  for (let i = 0; i < 2; i++) { C(g, 1.2, 1.2, 3.6, 0x8fd6ff, -2.2 + i * 2.8, 0.2, -1.2, 14); mesh(G.cone(1.2, 0.8, 14), M(0xffffff), g, -2.2 + i * 2.8, 4.2, -1.2); B(g, 0.2, 3.4, 0.2, 0x6b7280, -0.9 + i * 2.8, 0.2, -1.2); }
  B(g, 2.6, 2.4, 2.2, 0xff8a1f, 2.6, 0.2, 1.2); B(g, 2.7, 0.3, 2.3, 0xffffff, 2.6, 2.6, 1.2); B(g, 1.2, 1.0, 0.08, M(0x8fd6ff), 2.6, 1.2, 2.32);
  // caminhão de degelo com braço
  B(g, 2.6, 0.9, 1.3, 0xffc928, -1.6, 0.5, 1.6); B(g, 0.9, 0.9, 1.2, 0xf7f9fc, -0.2, 0.9, 1.6); [-2.5, -0.7].forEach(x => [1.0, 2.2].forEach(z => { const w = C(g, 0.32, 0.32, 0.25, 0x2b3245, x, 0.52, z, 10); w.rotation.x = Math.PI / 2; }));
  const arm = B(g, 0.18, 3.2, 0.18, 0x6b7280, -1.9, 1.4, 1.6); arm.rotation.z = 0.5; B(g, 0.7, 0.5, 0.7, 0xf7f9fc, -3.3, 4.0, 1.6);
  for (let i = 0; i < 7; i++) Sp(g, 0.35 + (i % 3) * 0.12, 0xffffff, -3.6 + i * 1.2, 0.3, -2.7 + (i % 2) * 5.2, 8);
  sign(g, 'DEGELO', 2.6, 0.6, '#2f7bff', '#ffffff', 2.6, 3.4, 2.36);
  return g;
}
function helicopter(col = 0xe8343b) {
  const g = new THREE.Group();
  const b = Sp(g, 0.9, col, 0, 1.2, 0, 14); b.scale.set(1, 0.85, 1.4);
  const w = Sp(g, 0.62, M(0x8fd6ff), 0, 1.3, 0.75, 12); w.scale.set(1, 0.8, 0.9);
  const t = B(g, 0.25, 0.25, 2.2, col, 0, 1.25, -1.9); B(g, 0.08, 0.8, 0.4, 0xffffff, 0, 1.3, -2.9);
  C(g, 0.08, 0.08, 0.5, 0x6b7280, 0, 1.9, 0, 6); B(g, 4.6, 0.05, 0.3, 0x2b3245, 0, 2.4, 0); B(g, 0.3, 0.05, 4.6, 0x2b3245, 0, 2.42, 0);
  [-0.6, 0.6].forEach(x => { B(g, 0.1, 0.1, 2.2, 0x6b7280, x, 0.15, 0); B(g, 0.06, 0.5, 0.06, 0x6b7280, x, 0.2, 0.5); B(g, 0.06, 0.5, 0.06, 0x6b7280, x, 0.2, -0.5); });
  return g;
}
function espHeli() { // Rio Dourado: heliponto executivo
  const g = new THREE.Group();
  C(g, 3.6, 3.8, 0.5, 0x6b7280, 0, 0, 0, 24); C(g, 3.3, 3.3, 0.06, 0x3b4558, 0, 0.5, 0, 24);
  const ring = mesh(G.torus(2.5, 0.12, 6, 28), M(0xffc928), g, 0, 0.58, 0); ring.rotation.x = Math.PI / 2;
  B(g, 0.35, 0.05, 2.2, 0xffffff, -0.8, 0.56, 0); B(g, 0.35, 0.05, 2.2, 0xffffff, 0.8, 0.56, 0); B(g, 1.6, 0.05, 0.35, 0xffffff, 0, 0.56, 0);
  for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; Sp(g, 0.14, M(0x3fd46b, { emissive: 0x208040 }), Math.cos(a) * 3.3, 0.6, Math.sin(a) * 3.3, 6); }
  B(g, 2.2, 2.2, 1.8, 0xf7f9fc, -4.6, 0, -1.5); B(g, 2.3, 0.3, 1.9, 0xffb627, -4.6, 2.2, -1.5); B(g, 1.0, 0.9, 0.08, M(0x8fd6ff), -4.6, 0.9, -0.58);
  C(g, 0.05, 0.05, 3, 0xffffff, -4.6, 2.5, -1.5, 5); const ws = mesh(G.cone(0.25, 1.0, 8), M(0xff8a1f), g, -4.1, 5.3, -1.5); ws.rotation.z = Math.PI / 2;
  return g;
}
function espResort() { // Costa Esmeralda: resort de praia
  const g = new THREE.Group();
  B(g, 9, 0.2, 6.4, 0xf3e2b0, 0, 0, 0);
  B(g, 4.2, 0.12, 2.4, 0x49c5f5, 1.8, 0.2, 1.6); B(g, 4.5, 0.2, 2.7, 0xffffff, 1.8, 0.1, 1.6);
  for (let i = 0; i < 2; i++) { const x = -2.6 + i * 3.2; C(g, 1.3, 1.3, 1.9, 0xf7f9fc, x, 0.2, -1.6, 10); mesh(G.cone(1.9, 1.5, 10), M(0xc98a52), g, x, 2.85, -1.6); B(g, 0.6, 1.1, 0.08, 0x8a5a34, x, 0.2, -0.3); }
  for (const [x, z] of [[-3.8, 1.8], [3.9, -1.9], [-0.9, 2.6]]) { C(g, 0.1, 0.14, 2.6, 0x8a5a34, x, 0.2, z, 6); for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; const l = B(g, 1.4, 0.05, 0.36, 0x3fae5a, x + Math.cos(a) * 0.6, 2.8, z + Math.sin(a) * 0.6); l.rotation.y = -a; } }
  for (let i = 0; i < 3; i++) { C(g, 0.04, 0.04, 1.4, 0xffffff, -1.6 + i * 1.1, 0.2, 0.6, 5); mesh(G.cone(0.6, 0.35, 8), M([0xe8343b, 0xffc928, 0x2f7bff][i]), g, -1.6 + i * 1.1, 1.75, 0.6); }
  sign(g, 'RESORT', 2.8, 0.6, '#14b8a6', '#ffffff', -1.0, 4.3, -1.6);
  return g;
}
const ESP = [espFeira, espHotel, espAlfandega, espDegelo, espHeli, espResort];
/* ===== fase barracão e extras ===== */
function checkinWood() {
  const g = new THREE.Group();
  B(g, 2.0, 0.9, 0.7, 0xb88a56, 0, 0, 0); B(g, 2.1, 0.08, 0.8, 0x8a6a40, 0, 0.9, 0);
  for (let x = -0.9; x < 1; x += 0.3) B(g, 0.03, 0.8, 0.72, 0x9a7448, x, 0.05, 0);
  B(g, 0.6, 0.2, 0.6, 0x6b7280, 0.65, 0, 0.75); B(g, 0.5, 0.03, 0.5, 0x2b3245, 0.65, 0.2, 0.75);
  B(g, 0.5, 0.3, 0.4, 0xf2f2f2, -0.4, 0.98, 0); // livro de registro
  const a = person({ shirt: 0xe8343b, pants: 0x253154, skin: P.skin[1], hair: 0x2a1a12 }); a.position.set(-0.4, 0, -0.75); g.add(a);
  B(g, 1.6, 0.6, 0.08, 0x2b3245, 0, 2.0, -0.4); C(g, 0.05, 0.05, 2.0, 0x8a6a40, -0.7, 0, -0.4, 6); C(g, 0.05, 0.05, 2.0, 0x8a6a40, 0.7, 0, -0.4, 6);
  sign(g, 'CHECK-IN', 1.5, 0.45, '#2b3245', '#ffffff', 0, 2.5, -0.35);
  for (let i = 0; i < 2; i++) { const z = 1.5 + i * 1.2; [-0.9, 0.9].forEach(x => C(g, 0.06, 0.06, 0.8, 0x8a6a40, x, 0, z, 6)); B(g, 1.8, 0.05, 0.05, 0xc0392b, 0, 0.7, z); }
  return g;
}
function securityWood() {
  const g = new THREE.Group();
  B(g, 0.9, 0.75, 3.0, 0xb88a56, -0.75, 0, 0); B(g, 0.8, 0.04, 3.0, 0x8a6a40, -0.75, 0.75, 0);
  B(g, 0.5, 0.35, 0.45, 0xff8a1f, -0.75, 0.79, 0.6); B(g, 0.45, 0.3, 0.4, 0x2f7bff, -0.75, 0.79, -0.5);
  B(g, 0.12, 2.1, 0.25, 0x9aa3b4, 0.25, 0, -0.2); B(g, 0.12, 2.1, 0.25, 0x9aa3b4, 1.25, 0, -0.2); B(g, 1.12, 0.2, 0.27, 0x9aa3b4, 0.75, 2.1, -0.2);
  Sp(g, 0.08, M(0xff3b3b, { emissive: 0xa02020 }), 0.75, 2.25, -0.05, 8);
  const gd = person({ shirt: 0x6b7f5a, pants: 0x3a4430, skin: P.skin[2], hair: 0x1a1210, cap: 0x3a4430 }); gd.position.set(1.6, 0, -0.8); gd.rotation.y = -Math.PI / 2; g.add(gd);
  return g;
}
function gateWood(n) {
  const g = new THREE.Group();
  B(g, 1.3, 0.9, 0.6, 0xb88a56, -2.6, 0, -0.6); B(g, 1.4, 0.06, 0.7, 0x8a6a40, -2.6, 0.9, -0.6);
  C(g, 0.06, 0.06, 2.6, 0x8a6a40, -2.6, 0, -1.2, 6); sign(g, 'PORTÃO ' + n, 2.0, 0.55, '#2b3245', '#ffffff', -2.6, 3.0, -1.2);
  for (let r = 0; r < 2; r++) { const z = 0.6 + r * 1.4; B(g, 3.6, 0.12, 0.5, 0xc98a52, 0.8, 0.42, z); B(g, 3.6, 0.5, 0.08, 0xc98a52, 0.8, 0.5, z - 0.25); [-0.9, 2.5].forEach(x => B(g, 0.1, 0.42, 0.4, 0x8a6a40, x, 0, z)); }
  return g;
}
function tower0() {
  const g = new THREE.Group();
  [[-1, -1], [1, -1], [-1, 1], [1, 1]].forEach(([x, z]) => C(g, 0.1, 0.13, 5, 0x8a6a40, x, 0, z, 6));
  for (let y = 1.2; y < 5; y += 1.6) { B(g, 2.1, 0.08, 0.08, 0x8a6a40, 0, y, 1); B(g, 2.1, 0.08, 0.08, 0x8a6a40, 0, y, -1); B(g, 0.08, 0.08, 2.1, 0x8a6a40, 1, y, 0); B(g, 0.08, 0.08, 2.1, 0x8a6a40, -1, y, 0); }
  B(g, 2.8, 0.15, 2.8, 0xb88a56, 0, 5, 0);
  B(g, 2.2, 1.4, 2.2, 0xd9b483, 0, 5.15, 0); B(g, 2.24, 0.6, 2.24, M(0x8fd6ff), 0, 5.8, 0);
  const rf = mesh(G.cone(2.1, 1.0, 4), M(0xe8343b), g, 0, 7.05, 0); rf.rotation.y = Math.PI / 4;
  C(g, 0.04, 0.04, 2, 0xffffff, 1.2, 7.0, 1.2, 5); const ws = mesh(G.cone(0.25, 1.1, 8), M(0xff8a1f), g, 1.7, 8.7, 1.2); ws.rotation.z = Math.PI / 2;
  for (let i = 0; i < 6; i++) B(g, 0.6, 0.06, 0.25, 0x8a6a40, 1.25, 0.4 + i * 0.8, -0.2 + i * 0.12);
  return g;
}
function parking0() {
  const g = new THREE.Group();
  for (let k = 0; k < 9; k++) B(g, 0.18, 0.7, 0.18, 0x8a6a40, -12 + k * 3, 0, 7);
  B(g, 24, 0.1, 0.08, 0xb88a56, 0, 0.55, 7);
  C(g, 0.07, 0.07, 2.2, 0x8a6a40, 13, 0, -6, 6); sign(g, 'P', 1.1, 1.0, '#8a6a40', '#ffffff', 13, 3.0, -6);
  return g;
}
function carousel() {
  const g = new THREE.Group();
  B(g, 3.6, 0.5, 2.2, 0x9aa3b4, 0, 0, 0); B(g, 3.3, 0.06, 1.9, 0x2b3245, 0, 0.5, 0); B(g, 2.4, 0.3, 1.0, 0xd7dde8, 0, 0.5, 0);
  const bags = [0xff4e4e, 0x2f7bff, 0x2ec27e, 0xffc928, 0x8b5cf6];
  for (let i = 0; i < 7; i++) { const a = i / 7 * Math.PI * 2; B(g, 0.38, 0.28, 0.3, bags[i % 5], Math.cos(a) * 1.45, 0.56, Math.sin(a) * 0.78); }
  C(g, 0.05, 0.05, 2.6, 0x9aa3b4, 1.9, 0, -1.0, 6); sign(g, 'BAGAGEM', 2.0, 0.45, '#ffc928', '#253154', 1.9, 2.9, -1.0);
  return g;
}
function cargoTerminal() {
  const g = new THREE.Group();
  B(g, 11, 4.2, 9, 0xe6eaf1, 0, 0, 0); B(g, 11.2, 0.4, 9.2, 0xff8a1f, 0, 4.2, 0);
  for (let i = 0; i < 3; i++) B(g, 2.4, 2.8, 0.1, 0x8a93a6, -3.4 + i * 3.4, 0, 4.55);
  for (let i = 0; i < 3; i++) for (let y = 0.3; y < 2.8; y += 0.35) B(g, 2.3, 0.04, 0.12, 0x6b7280, -3.4 + i * 3.4, y, 4.56);
  B(g, 11.05, 0.35, 9.05, 0x2f7bff, 0, 3.3, 0);
  for (let z = -3; z <= 3; z += 2) B(g, 0.08, 0.8, 1.4, M(0x8fd6ff), 5.52, 2.0, z);
  sign(g, 'CARGAS', 4.5, 0.9, '#ff8a1f', '#ffffff', 0, 5.6, 4.3);
  const cols = [0x2f7bff, 0xff4e4e, 0x2ec27e, 0xffc928];
  for (let i = 0; i < 5; i++) B(g, 1.1, 1.1, 1.1, cols[i % 4], -4.5 + i * 2.1, 0, 6.4 + (i % 2) * 0.6);
  for (let i = 0; i < 3; i++) B(g, 1.0, 0.9, 1.0, 0xc98a52, 6.3, i * 0.9, 2);
  return g;
}
function statue() { const g = new THREE.Group(); B(g, 1.6, 0.8, 1.6, 0xd7dde8, 0, 0, 0); B(g, 1.3, 0.15, 1.3, 0xffc928, 0, 0.8, 0); const p = plane(0, 3); p.scale.setScalar(0.32); p.position.set(0, 1.6, 0); p.rotation.set(-0.5, Math.PI * 0.75, 0); g.add(p); C(g, 0.08, 0.08, 1.0, 0xffc928, 0, 0.95, 0, 6); return g; }
function flowerbed() { const g = new THREE.Group(); B(g, 3.2, 0.45, 1.2, 0xc98a52, 0, 0, 0); B(g, 3.0, 0.08, 1.0, 0x5a3a20, 0, 0.42, 0); const fc = [0xff4e4e, 0xffc928, 0xff7ab6, 0xffffff, 0x8b5cf6]; for (let i = 0; i < 10; i++) { Sp(g, 0.18, 0x3fae5a, -1.3 + i * 0.29, 0.6, (i % 2) * 0.35 - 0.17, 6); Sp(g, 0.13, fc[i % 5], -1.3 + i * 0.29, 0.78, (i % 2) * 0.35 - 0.17, 6); } return g; }
function palmPot() { const g = new THREE.Group(); C(g, 0.45, 0.35, 0.6, 0xf7f9fc, 0, 0, 0, 12); C(g, 0.08, 0.12, 2.2, 0x8a5a34, 0, 0.6, 0, 6); for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; const l = B(g, 1.3, 0.05, 0.35, 0x3fae5a, Math.cos(a) * 0.55, 2.7, Math.sin(a) * 0.55); l.rotation.y = -a; l.rotation.z = -0.4 * Math.sign(Math.cos(a) || 1); } return g; }
function artwall() { const g = new THREE.Group(); B(g, 3.6, 2.6, 0.25, 0xf7f9fc, 0, 0, 0); const cs = [0x2f7bff, 0xff8a1f, 0xffc928, 0x2ec27e, 0xff7ab6, 0x8b5cf6]; for (let i = 0; i < 6; i++) B(g, 1.0, 0.7, 0.06, cs[i], -1.15 + (i % 3) * 1.15, 0.5 + Math.floor(i / 3) * 0.95, 0.15); return g; }

/* ===================================================================
   ÍCONES 3D (câmera em perspectiva)
   =================================================================== */
function iconShot(build, size = 192, rot = { x: 0.35, y: -0.6 }) {
  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight(0xffffff, 0xb0b8d0, 0.75));
  const d = new THREE.DirectionalLight(0xffffff, 0.55); d.position.set(-3, 5, 6); scene.add(d);
  const obj = build(); const wrap = new THREE.Group(); wrap.add(obj); wrap.rotation.x = rot.x; wrap.rotation.y = rot.y; scene.add(wrap);
  const box = new THREE.Box3().setFromObject(wrap), c = box.getCenter(new THREE.Vector3()), sz = box.getSize(new THREE.Vector3());
  wrap.position.sub(c);
  const r = Math.max(sz.x, sz.y) * 0.62 + 0.05;
  const cam = new THREE.OrthographicCamera(-r, r, r, -r, -50, 50); cam.position.set(0, 0, 10); cam.lookAt(0, 0, 0);
  R.setSize(size, size); R.setClearColor(0, 0); R.render(scene, cam);
  const cnv = document.createElement('canvas'); cnv.width = size; cnv.height = size; cnv.getContext('2d').drawImage(R.domElement, 0, 0);
  return { png: cnv.toDataURL('image/png') };
}
const ICONS = {
  esp0: () => espFeira(), esp1: () => espHotel(), esp2: () => espAlfandega(), esp3: () => espDegelo(), esp4: () => espHeli(), esp5: () => espResort(), heli: () => helicopter(),
  network: () => { const g = new THREE.Group(); Sp(g, 1.1, 0x2f7bff, 0, 0, 0, 16); for (let i = 0; i < 5; i++) { const a = i / 5 * Math.PI * 2; Sp(g, 0.28, 0xffc928, Math.cos(a) * 1.1, Math.sin(a) * 1.1, 0.3, 8); } return g; },
  cargo: () => { const g = new THREE.Group(); B(g, 1.6, 1.2, 1.2, 0xff8a1f, 0, -0.8, 0); for (let i = 0; i < 4; i++) B(g, 0.06, 1.1, 1.22, 0xd86a10, -0.6 + i * 0.4, -0.75, 0); B(g, 1.0, 0.8, 0.9, 0x2f7bff, 0.2, 0.4, 0); return g; },
  decor: () => palmPot(),
  contract: () => { const g = new THREE.Group(); B(g, 1.5, 1.9, 0.1, 0xf7f9fc, 0, -0.95, 0); for (let i = 0; i < 4; i++) B(g, 1.0, 0.08, 0.12, 0x9aa3b4, -0.1, 0.5 - i * 0.3 - 0.95 + 1.0, 0.02); C(g, 0.32, 0.32, 0.12, 0xff4e4e, 0.45, -0.85, 0.08, 16).rotation.x = Math.PI / 2; return g; },
  coin: () => { const g = new THREE.Group(); const c = mesh(G.cyl(1, 1, 0.3, 28), M(0xffc531), g); c.rotation.x = Math.PI / 2; const i = mesh(G.cyl(0.74, 0.74, 0.34, 28), M(0xffdc6a), g); i.rotation.x = Math.PI / 2; const s = sign(g, '$', 0.9, 0.9, null, '#e08a00', 0, 0.45, 0.2); s.children[0].visible = false; return g; },
  gem: () => { const g = new THREE.Group(); const m = mesh(new THREE.OctahedronGeometry(1, 0), M(0x3fd6ff), g); m.scale.set(1, 1.25, 1); const t = mesh(new THREE.CylinderGeometry(0.6, 1, 0.5, 6), M(0x8ff0ff), g, 0, 0.55, 0); return g; },
  cash: () => { const g = new THREE.Group(); for (let i = 0; i < 4; i++) { const b = B(g, 2, 0.22, 1, 0x3fbf6b, 0, i * 0.23, 0); b.rotation.y = i * 0.12; B(g, 0.5, 0.24, 1.02, 0xe8f7d6, 0, i * 0.23, 0).rotation.y = i * 0.12; } return g; },
  plane: () => { const p = plane(1, 0); p.rotation.y = Math.PI * 0.75; p.rotation.x = -0.2; const g = new THREE.Group(); g.add(p); return g; },
  pax: () => { const g = new THREE.Group(); const p = person({ shirt: 0xffc928, pants: 0x2f7bff, bag: true }); p.rotation.y = 0.4; g.add(p); return g; },
  star: () => { const s = new THREE.Shape(); for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2 + Math.PI / 2, r = i % 2 ? 0.45 : 1; s[i ? 'lineTo' : 'moveTo'](Math.cos(a) * r, Math.sin(a) * r); } const g = new THREE.Group(); mesh(new THREE.ExtrudeGeometry(s, { depth: 0.3, bevelEnabled: true, bevelSize: 0.08, bevelThickness: 0.08 }), M(0xffc531), g); return g; },
  clock: () => { const g = new THREE.Group(); const c = mesh(G.cyl(1, 1, 0.3, 28), M(0x2f7bff), g); c.rotation.x = Math.PI / 2; const f = mesh(G.cyl(0.8, 0.8, 0.32, 28), M(0xffffff), g); f.rotation.x = Math.PI / 2; B(g, 0.1, 0.6, 0.1, 0x253154, 0, 0, 0.2); const h = B(g, 0.1, 0.45, 0.1, 0x253154, 0, 0, 0.2); h.rotation.z = -1.4; h.position.set(0.22, 0.04, 0.2); return g; },
  lock: () => { const g = new THREE.Group(); B(g, 1.4, 1.1, 0.6, 0xffc531, 0, -0.8, 0); const sh = mesh(new THREE.TorusGeometry(0.45, 0.13, 8, 16, Math.PI), M(0xaab3c2), g, 0, 0.3, 0); C(g, 0.12, 0.12, 0.3, 0x8a5a00, 0, -0.45, 0.31, 8).rotation.x = Math.PI / 2; return g; },
  gift: () => { const g = new THREE.Group(); B(g, 1.6, 1.2, 1.6, 0xff4e4e, 0, -0.7, 0); B(g, 1.8, 0.35, 1.8, 0xff6b6b, 0, 0.45, 0); B(g, 0.3, 1.6, 1.82, 0xffc531, 0, -0.7, 0); B(g, 1.82, 1.6, 0.3, 0xffc531, 0, -0.7, 0); [-1, 1].forEach(s => { const b = mesh(new THREE.TorusGeometry(0.3, 0.1, 6, 12), M(0xffc531), g, s * 0.3, 1.05, 0); b.rotation.y = s * 0.5; }); return g; },
  trophy: () => { const g = new THREE.Group(); C(g, 0.6, 0.7, 0.3, 0x8a5a34, 0, -1.2, 0); C(g, 0.15, 0.25, 0.6, 0xffc531, 0, -0.9, 0); C(g, 0.75, 0.3, 1.0, 0xffc531, 0, -0.3, 0, 18); [-1, 1].forEach(s => { const t = mesh(new THREE.TorusGeometry(0.3, 0.08, 6, 12), M(0xffc531), g, s * 0.75, 0.25, 0); }); return g; },
  gear: () => { const g = new THREE.Group(); const c = mesh(G.cyl(0.8, 0.8, 0.4, 20), M(0x8a93a6), g); c.rotation.x = Math.PI / 2; for (let i = 0; i < 8; i++) { const t = B(g, 0.35, 0.45, 0.4, 0x8a93a6, Math.cos(i * Math.PI / 4) * 0.95, Math.sin(i * Math.PI / 4) * 0.95 - 0.22, 0); t.rotation.z = i * Math.PI / 4 - Math.PI / 2; } const h = mesh(G.cyl(0.3, 0.3, 0.45, 16), M(0x4c5160), g); h.rotation.x = Math.PI / 2; return g; },
  bolt: () => { const s = new THREE.Shape(); [[0.2, 1], [-0.6, -0.1], [-0.05, -0.1], [-0.3, -1], [0.6, 0.15], [0.05, 0.15], [0.2, 1]].forEach(([x, y], i) => s[i ? 'lineTo' : 'moveTo'](x, y)); const g = new THREE.Group(); mesh(new THREE.ExtrudeGeometry(s, { depth: 0.3, bevelEnabled: true, bevelSize: 0.05, bevelThickness: 0.05 }), M(0xffc531), g); return g; },
  cap: () => { const g = new THREE.Group(); C(g, 0.9, 0.95, 0.6, 0x253154, 0, 0, 0, 20); C(g, 1.0, 0.9, 0.12, 0x253154, 0, 0.6, 0, 20); B(g, 1.4, 0.08, 0.7, 0x1a2038, 0, 0, 0.75); C(g, 0.92, 0.92, 0.12, 0xffc531, 0, 0.2, 0, 20); Sp(g, 0.18, 0xffc531, 0, 0.45, 0.85, 10); return g; },
  globe: () => { const g = new THREE.Group(); Sp(g, 1, 0x3fa8ff, 0, 0, 0, 20); for (let i = 0; i < 5; i++) { const c = Sp(g, 0.35 + (i % 2) * 0.15, 0x48c76a, Math.cos(i * 1.3) * 0.75, Math.sin(i * 2.1) * 0.6, Math.sin(i * 1.3) * 0.5 + 0.4, 8); } return g; },
  ticket: () => { const g = new THREE.Group(); B(g, 2.2, 1.1, 0.12, 0xffffff, 0, -0.55, 0); B(g, 0.7, 1.1, 0.14, 0x2f7bff, -0.75, -0.55, 0); for (let i = 0; i < 3; i++) B(g, 0.9, 0.12, 0.14, 0xaab3c2, 0.35, -0.25 - i * 0.28, 0); return g; },
  suitcase: () => { const g = new THREE.Group(); B(g, 1.4, 1.7, 0.7, 0xff4e4e, 0, -0.9, 0); B(g, 1.42, 0.2, 0.72, 0xffc531, 0, -0.3, 0); const h = mesh(new THREE.TorusGeometry(0.3, 0.07, 6, 12, Math.PI), M(0x253154), g, 0, 0.8, 0); return g; },
  bag: () => { const g = new THREE.Group(); B(g, 1.5, 1.6, 0.7, 0xff8a1f, 0, -0.9, 0); B(g, 1.52, 0.25, 0.72, 0xffc531, 0, 0.45, 0); mesh(new THREE.TorusGeometry(0.4, 0.07, 6, 12, Math.PI), M(0x8a5a34), g, 0, 0.7, 0); return g; },
  shield: () => { const s = new THREE.Shape(); s.moveTo(0, 1.1); s.quadraticCurveTo(0.6, 0.95, 0.95, 1.0); s.quadraticCurveTo(1.0, -0.4, 0, -1.1); s.quadraticCurveTo(-1.0, -0.4, -0.95, 1.0); s.quadraticCurveTo(-0.6, 0.95, 0, 1.1); const g = new THREE.Group(); mesh(new THREE.ExtrudeGeometry(s, { depth: 0.3, bevelEnabled: true, bevelSize: 0.06, bevelThickness: 0.06 }), M(0x8b5cf6), g); B(g, 0.25, 1.2, 0.1, 0xffffff, 0, -0.65, 0.35); B(g, 0.9, 0.25, 0.1, 0xffffff, 0, -0.2, 0.35); return g; },
  tower: () => tower(2),
  desk: () => { const g = checkinDesk(); return g; },
  hangar: () => hangar(),
  fuel: () => { const g = new THREE.Group(); B(g, 1.3, 1.9, 0.8, 0xff4e4e, 0, -1, 0); B(g, 0.9, 0.6, 0.82, 0xffffff, 0, -0.4, 0); C(g, 0.08, 0.08, 1.0, 0x253154, 0.85, -0.5, 0, 6); return g; },
  crown: () => { const g = new THREE.Group(); C(g, 1, 1, 0.6, 0xffc531, 0, -0.4, 0, 20); for (let i = 0; i < 5; i++) { const a = i / 5 * Math.PI * 2; mesh(G.cone(0.28, 0.7, 6), M(0xffc531), g, Math.cos(a) * 0.85, 0.5, Math.sin(a) * 0.85); Sp(g, 0.12, 0xff4e4e, Math.cos(a) * 0.85, 0.9, Math.sin(a) * 0.85, 8); } return g; },
  up: () => { const s = new THREE.Shape(); [[0, 1], [0.9, 0], [0.35, 0], [0.35, -1], [-0.35, -1], [-0.35, 0], [-0.9, 0], [0, 1]].forEach(([x, y], i) => s[i ? 'lineTo' : 'moveTo'](x, y)); const g = new THREE.Group(); mesh(new THREE.ExtrudeGeometry(s, { depth: 0.3, bevelEnabled: true, bevelSize: 0.06, bevelThickness: 0.06 }), M(0x3fd46b), g); return g; },
  runway: () => { const g = new THREE.Group(); B(g, 1.2, 0.15, 3.4, 0x4c5160, 0, 0, 0); for (let i = 0; i < 4; i++) B(g, 0.1, 0.16, 0.45, 0xffffff, 0, 0.01, -1.3 + i * 0.8); const p = plane(0, 0); p.scale.setScalar(0.25); p.position.set(0, 0.6, 0.5); g.add(p); return g; },
  xray: () => { const g = new THREE.Group(); B(g, 1.6, 1.4, 1.6, 0x8b5cf6, 0, 0, 0); B(g, 1.2, 0.7, 1.62, 0x1e2230, 0, 0.2, 0); B(g, 0.7, 0.12, 3.0, 0x4c5160, 0, 0.25, 0); return g; },
  shop: () => shop(0),
  checkin: () => checkinDesk(),
  security: () => securityLane(),
  bus: () => vehicle('bus'),
  map: () => { const g = new THREE.Group(); B(g, 2.2, 0.1, 1.6, 0x9fdc7a, 0, 0, 0); B(g, 1.8, 0.12, 0.25, 0x4c5160, 0, 0.01, -0.3); Sp(g, 0.25, 0xff4e4e, 0.4, 0.6, 0.2, 10); mesh(G.cone(0.2, 0.4, 10), M(0xff4e4e), g, 0.4, 0.3, 0.2).rotation.x = Math.PI; return g; },
  mission: () => { const g = new THREE.Group(); B(g, 1.6, 2.0, 0.15, 0xf7f9fc, 0, -1, 0); B(g, 0.8, 0.3, 0.17, 0x8a5a34, 0, 0.9, 0); for (let i = 0; i < 3; i++) { B(g, 0.25, 0.25, 0.17, i < 2 ? 0x3fd46b : 0xd0d6e0, -0.45, 0.4 - i * 0.55, 0.02); B(g, 0.75, 0.12, 0.17, 0xaab3c2, 0.2, 0.47 - i * 0.55, 0.02); } return g; },

  chest: () => { const g = new THREE.Group(); B(g, 2, 1.1, 1.3, 0x8a5a34, 0, -0.9, 0); const lid = mesh(new THREE.CylinderGeometry(0.65, 0.65, 2, 14, 1, false, 0, Math.PI), M(0xa86a3c), g, 0, 0.2, 0); lid.rotation.z = Math.PI / 2; lid.rotation.y = Math.PI / 2; lid.rotation.set(0, 0, Math.PI / 2); B(g, 2.05, 0.18, 1.35, 0xffc531, 0, -0.25, 0); B(g, 0.25, 1.9, 1.36, 0xffc531, -0.7, -0.9, 0); B(g, 0.25, 1.9, 1.36, 0xffc531, 0.7, -0.9, 0); B(g, 0.35, 0.45, 0.1, 0xffe27a, 0, -0.55, 0.68); return g; },
  chest_gold: () => { const g = ICONS.chest(); g.traverse(o => { if (o.isMesh && o.material.color && o.material.color.getHex() === 0x8a5a34) o.material = M(0xffb300); if (o.isMesh && o.material.color && o.material.color.getHex() === 0xa86a3c) o.material = M(0xffd84a); }); return g; },
  card: () => { const g = new THREE.Group(); B(g, 1.6, 2.2, 0.12, 0x2f7bff, 0, -1.1, 0); B(g, 1.4, 2.0, 0.14, 0xf7f9fc, 0, -1.0, 0); const p = plane(1, 0); p.scale.setScalar(0.17); p.rotation.set(0.6, Math.PI * 0.75, 0); p.position.set(0, 0.1, 0.3); g.add(p); return g; },
  medal: () => { const g = new THREE.Group(); B(g, 0.4, 1.2, 0.08, 0xe8343b, -0.25, 0.1, 0).rotation.z = 0.3; B(g, 0.4, 1.2, 0.08, 0x2f7bff, 0.25, 0.1, 0).rotation.z = -0.3; const c = mesh(G.cyl(0.75, 0.75, 0.2, 24), M(0xffc531), g, 0, -0.5, 0.1); c.rotation.x = Math.PI / 2; const st = mesh(G.cyl(0.5, 0.5, 0.22, 5), M(0xffe27a), g, 0, -0.5, 0.12); st.rotation.x = Math.PI / 2; return g; },
  wheel: () => { const g = new THREE.Group(); const cols = [0xff4e4e, 0xffc928, 0x2f7bff, 0x3fd46b, 0x8b5cf6, 0xff8a1f]; for (let i = 0; i < 6; i++) { const m = mesh(new THREE.CylinderGeometry(1.2, 1.2, 0.2, 8, 1, false, i * Math.PI / 3, Math.PI / 3), M(cols[i]), g); m.rotation.x = Math.PI / 2; } const c = mesh(G.cyl(0.25, 0.25, 0.3, 12), M(0xffffff), g); c.rotation.x = Math.PI / 2; mesh(G.cone(0.2, 0.4, 3), M(0x253154), g, 0, 1.35, 0.15).rotation.z = Math.PI; return g; },
  research: () => { const g = new THREE.Group(); const b = mesh(new THREE.SphereGeometry(0.75, 16, 12), M(0x9fe0ff, { opacity: 0.85 }), g, 0, -0.5, 0); C(g, 0.25, 0.25, 0.9, 0x9fe0ff, 0, 0, 0, 10); Sp(g, 0.55, 0x3fd46b, 0, -0.65, 0, 12); C(g, 0.3, 0.3, 0.2, 0x8a5a34, 0, 0.9, 0, 10); return g; },
  route: () => { const g = new THREE.Group(); Sp(g, 1, 0x3fa8ff, 0, 0, 0, 20); for (let i = 0; i < 4; i++) Sp(g, 0.35, 0x48c76a, Math.cos(i * 1.6) * 0.75, Math.sin(i * 2.3) * 0.5, Math.sin(i * 1.6) * 0.5 + 0.45, 8); const t = mesh(new THREE.TorusGeometry(1.25, 0.05, 6, 30, Math.PI * 1.3), M(0xffc928), g); t.rotation.x = 1.2; const p = plane(1, 0); p.scale.setScalar(0.12); p.position.set(1.0, 0.4, 0.6); p.rotation.y = 2.4; g.add(p); return g; },
  miles: () => { const g = new THREE.Group(); const c = mesh(G.cyl(1, 1, 0.3, 28), M(0x2f7bff), g); c.rotation.x = Math.PI / 2; const i = mesh(G.cyl(0.78, 0.78, 0.34, 28), M(0x6fb4ff), g); i.rotation.x = Math.PI / 2; const p = plane(0, 0); p.scale.setScalar(0.15); p.rotation.set(Math.PI / 2, 0, -0.6); p.position.z = 0.25; g.add(p); return g; },
  pass: () => { const g = new THREE.Group(); B(g, 2.2, 1.4, 0.12, 0x8b5cf6, 0, -0.7, 0); B(g, 2.0, 0.3, 0.14, 0xffc531, 0, -0.1, 0); for (let i = 0; i < 4; i++) { const s = mesh(G.cyl(0.18, 0.18, 0.16, 5), M(0xffffff), g, -0.6 + i * 0.4, -0.75, 0.05); s.rotation.x = Math.PI / 2; } return g; },
  stats: () => { const g = new THREE.Group(); B(g, 2.2, 0.1, 0.4, 0x8a93a6, 0, -1, 0); [0.6, 1.0, 0.8, 1.5].forEach((h, i) => B(g, 0.38, h, 0.4, [0x2f7bff, 0x3fd46b, 0xffc928, 0xff4e4e][i], -0.75 + i * 0.5, -0.95, 0)); return g; },
  cloud: () => { const g = new THREE.Group(); [[0, 0, 0.7], [0.7, -0.1, 0.55], [-0.7, -0.15, 0.5], [0.3, 0.35, 0.5]].forEach(([x, y, r]) => Sp(g, r, 0xffffff, x, y, 0, 12)); return g; },
  rain: () => { const g = ICONS.cloud(); for (let i = 0; i < 4; i++) { const d = mesh(G.cone(0.1, 0.35, 6), M(0x3fa8ff), g, -0.6 + i * 0.4, -0.85, 0.2); d.rotation.z = Math.PI; } return g; },
  fire: () => { const g = new THREE.Group(); const a = mesh(G.cone(0.7, 1.8, 10), M(0xff8a1f), g, 0, 0, 0); const b = mesh(G.cone(0.4, 1.1, 10), M(0xffc928), g, 0, -0.3, 0.2); return g; },
  auto: () => { const g = ICONS.gear(); const u = ICONS.up(); u.scale.setScalar(0.55); u.position.set(0.55, 0.35, 0.4); g.add(u); return g; },
  celeb: () => { const g = new THREE.Group(); const p = person({ shirt: 0xff7ab6, pants: 0x253154, skin: P.skin[0], hair: 0xe0a040 }); p.rotation.y = 0.3; g.add(p); B(g, 0.5, 0.1, 0.05, 0x111111, 0, 1.15, 0.27); return g; },
  rush: () => { const g = new THREE.Group(); for (let i = 0; i < 3; i++) { const p = person({ shirt: [0xff4e4e, 0x2f7bff, 0xffc928][i], bag: true }); p.position.set(-0.6 + i * 0.6, 0, -i * 0.3); p.rotation.y = 0.5; g.add(p); } return g; },
  turbo: () => { const g = new THREE.Group(); const p = plane(1, 3); p.rotation.y = Math.PI / 2; p.rotation.z = 0.2; g.add(p); for (let i = 0; i < 3; i++) B(g, 2.5, 0.1, 0.1, 0xffc928, -6 - i * 0.5, 1.2 + i * 0.5, 0); return g; },
  bags: () => { const g = new THREE.Group(); [[0xff4e4e, -0.8], [0x2f7bff, 0], [0x3fd46b, 0.8]].forEach(([c, x], i) => { B(g, 0.7, 1.0, 0.4, c, x, -0.6 + (i % 2) * 0.3, 0); }); return g; },
  vip: () => { const p = plane(1, 3); p.rotation.y = Math.PI * 0.75; p.rotation.x = -0.2; const g = new THREE.Group(); g.add(p); return g; },
  landing: () => { const g = new THREE.Group(); const p = plane(1, 1); p.rotation.y = Math.PI / 2; p.rotation.z = 0.15; g.add(p); B(g, 9, 0.2, 2, 0x4c5160, 0, -0.5, 0); return g; },
};

/* ===================================================================
   CENAS EM PERSPECTIVA (keyart, ícone do app)
   =================================================================== */
function fullAirport(city, maxed = true) {
  const g = new THREE.Group();
  g.add(background(city));
  const add = (o, x, z, ry = 0) => { o.position.set(x, 0.3 * (z > -5 && z < 16 && x > L.term.x0 && x < L.term.x1 ? 1 : 0), z); o.rotation.y = ry; g.add(o); return o; };
  for (let i = 0; i < 6; i++) add(checkinDesk(), L.checkin.x0 + i * L.checkin.dx, L.checkin.z);
  for (let i = 0; i < 4; i++) add(securityLane(), L.security.x0 + i * L.security.dx, L.security.z);
  for (let i = 0; i < 4; i++) add(shop(i), L.shops[i].x, L.shops[i].z);
  add(vip(3), L.vip.x, L.vip.z);
  L.gates.forEach((gx, i) => { add(gateInterior(i + 1, 3), gx, -2.6); const jb = jetBridge(i % 3 === 0 ? 1 : 2); jb.position.set(gx, 0, -5); g.add(jb); const pl = plane(i % 3 === 0 ? 1 : 2, i % 3); pl.position.set(gx, 0, L.standNose - PLANES[i % 3 === 0 ? 1 : 2].len * 0.5); g.add(pl); });
  const wall = airsideWall(); wall.position.set((L.term.x0 + L.term.x1) / 2, 0, -5); g.add(wall);
  add(parking(4), L.parking.x, L.parking.z); add(busStop(), L.busStop.x, L.busStop.z);
  add(tower(3), L.tower.x, L.tower.z); add(fuelFarm(), L.fuel.x, L.fuel.z); add(hangar(), L.hangar.x, L.hangar.z);
  const ra = runwayAids(3); ra.position.set(L.runway.x0, 0, L.runway.z); g.add(ra);
  const crowd = [0xff4e4e, 0x2f7bff, 0xffc928, 0x2ec27e, 0x8b5cf6, 0xff8a1f];
  for (let i = 0; i < 70; i++) { const p = person({ shirt: crowd[i % 6], skin: P.skin[i % 4], hair: [0x3b2a20, 0xe0a040, 0x1a1210][i % 3], bag: i % 3 === 0 ? crowd[(i + 2) % 6] : false, frame: i % 4 }); const x = -44 + (i * 7.3) % 76, z = -3.5 + (i * 3.7) % 18; p.position.set(x, 0.3, z); p.rotation.y = (i % 4) * Math.PI / 2; g.add(p); }
  const bus = vehicle('bus'); bus.position.set(-12, 0, 19); bus.rotation.y = Math.PI / 2; g.add(bus);
  const tug = vehicle('tug'); tug.position.set(-30, 0, -14); tug.rotation.y = Math.PI / 2; g.add(tug);
  return g;
}
function keyart(W, H, city = 2) {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x8fd0ff);
  scene.fog = new THREE.Fog(0xbfe4ff, 120, 330);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x8899bb, 0.65));
  const d = new THREE.DirectionalLight(0xffe6c4, 0.75); d.position.set(-40, 70, 50); d.castShadow = true; d.shadow.mapSize.set(4096, 4096);
  Object.assign(d.shadow.camera, { left: -120, right: 120, top: 120, bottom: -120, near: 1, far: 300 }); d.shadow.bias = -0.0005; scene.add(d);
  scene.add(fullAirport(city));
  // avião decolando em primeiro plano
  const p = plane(2, 0); if (W > H) p.position.set(22, 19, 26); else p.position.set(16, 30, 34); p.rotation.set(-0.25, -Math.PI / 2 - 0.5, 0.22, 'YXZ'); p.traverse(o => { if (o.isMesh) o.castShadow = false; }); scene.add(p);
  const p2 = plane(1, 1); p2.position.set(-50, 32, -60); p2.rotation.set(0.05, -Math.PI / 2 + 0.3, 0.2, 'YXZ'); p2.scale.setScalar(0.9); scene.add(p2);
  // nuvens
  const cl = M(0xffffff);
  for (let i = 0; i < 18; i++) { const c = grp(scene, -120 + i * 15, 40 + (i % 3) * 8, -90 - (i % 4) * 20); for (let k = 0; k < 4; k++) Sp(c, 3 + (k % 2) * 1.5, cl, k * 3, (k % 2) * 1.2, 0, 8); }
  const cam = new THREE.PerspectiveCamera(W > H ? 38 : 50, W / H, 1, 1000);
  if (W > H) { cam.position.set(46, 30, 62); cam.lookAt(-6, 4, -10); }
  else { cam.position.set(38, 46, 70); cam.lookAt(-8, 6, -8); }
  R.setSize(W, H); R.setClearColor(0x8fd0ff, 1); R.render(scene, cam);
  const c = document.createElement('canvas'); c.width = W; c.height = H; c.getContext('2d').drawImage(R.domElement, 0, 0);
  return { png: c.toDataURL('image/jpeg', 0.9) };
}
function appIcon(size, fg = false) {
  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight(0xffffff, 0xa0b0d0, 0.75));
  const d = new THREE.DirectionalLight(0xffffff, 0.6); d.position.set(-4, 6, 8); scene.add(d);
  const p = plane(1, 0); p.rotation.set(0.35, -0.75, -0.25, 'YXZ'); p.position.set(0, -1.2, 0); scene.add(p);
  const cam = new THREE.PerspectiveCamera(32, 1, 0.1, 100); cam.position.set(0, 2, 22); cam.lookAt(0, 0, 0);
  R.setSize(size, size); R.setClearColor(0, 0); R.render(scene, cam);
  const c = document.createElement('canvas'); c.width = size; c.height = size; const x = c.getContext('2d');
  if (!fg) {
    const gr = x.createLinearGradient(0, 0, 0, size); gr.addColorStop(0, '#5fc6ff'); gr.addColorStop(1, '#1e6dff');
    x.fillStyle = gr; x.fillRect(0, 0, size, size);
    x.fillStyle = 'rgba(255,255,255,0.9)';
    [[0.18, 0.78, 0.13], [0.3, 0.8, 0.1], [0.78, 0.25, 0.1], [0.88, 0.27, 0.07]].forEach(([cx, cy, r]) => { x.beginPath(); x.arc(cx * size, cy * size, r * size, 0, 7); x.fill(); });
    x.fillStyle = '#ffc928'; x.beginPath(); x.arc(size * 0.78, size * 0.78, size * 0.13, 0, 7); x.fill();
    x.fillStyle = '#e08a00'; x.font = `bold ${size * 0.17}px Arial`; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText('$', size * 0.78, size * 0.79);
  }
  x.drawImage(R.domElement, 0, 0);
  return { png: c.toDataURL('image/png') };
}


/* ===================== ADIÇÕES v2: enfeites por nível, pilhas, faxineiro ===================== */
function totem() { const g = new THREE.Group(); B(g, 0.7, 1.5, 0.45, 0xf7f9fc, 0, 0, 0); B(g, 0.6, 0.55, 0.05, M(0x7fd8ff, { emissive: 0x204870 }), 0, 0.8, 0.24); B(g, 0.72, 0.15, 0.47, 0x2f7bff, 0, 1.5, 0); sign(g, 'AUTO', 0.7, 0.22, '#2f7bff', '#ffffff', 0, 1.9, 0.1); return g; }
function ledboard(w = 4.2) { const g = new THREE.Group(); [-w / 2 + 0.2, w / 2 - 0.2].forEach(x => C(g, 0.07, 0.07, 3.0, 0x7a8395, x, 0, 0, 6)); B(g, w, 1.3, 0.2, 0x1a2038, 0, 2.6, 0); const t = new THREE.Mesh(new THREE.PlaneGeometry(w * 0.94, 1.15), textMat('PARTIDAS  ✈  BOARDING', '#1a2038', '#ffc928', 1024, 280, 'bold 120px Arial')); t.position.set(0, 3.25, 0.11); g.add(t); for (let r = 0; r < 3; r++) B(g, w * 0.86, 0.1, 0.02, r === 1 ? 0x3fd46b : 0xffc928, 0, 2.75 + r * 0.25, 0.12); return g; }
function plant(big = false) { const g = new THREE.Group(); C(g, 0.32, 0.26, 0.5, 0xc98a52, 0, 0, 0, 10); Sp(g, big ? 0.62 : 0.45, 0x3fae5a, 0, big ? 1.0 : 0.85, 0, 8); Sp(g, big ? 0.42 : 0.3, 0x52c463, 0.2, big ? 1.4 : 1.1, 0.1, 8); return g; }
function bench() { const g = new THREE.Group(); for (let k = 0; k < 3; k++) { B(g, 0.6, 0.1, 0.5, 0xff8a1f, -0.65 + k * 0.65, 0.42, 0); B(g, 0.6, 0.45, 0.08, 0xff8a1f, -0.65 + k * 0.65, 0.5, -0.22); } B(g, 2.0, 0.06, 0.3, 0x9aa3b4, 0, 0.36, 0); [-0.9, 0.9].forEach(x => B(g, 0.08, 0.36, 0.4, 0x9aa3b4, x, 0, 0)); return g; }
function bodyscan() { const g = new THREE.Group(); C(g, 0.75, 0.75, 0.1, 0xd7dde8, 0, 0, 0, 16); const s = mesh(new THREE.CylinderGeometry(0.8, 0.8, 2.2, 16, 1, true, 0.6, 2.0), M(0xbfe8ff, { opacity: 0.55 }), g, 0, 1.15, 0); C(g, 0.82, 0.82, 0.2, 0x8b5cf6, 0, 2.2, 0, 16); return g; }
function dogUnit() { const g = new THREE.Group(); const p = person({ shirt: 0x253154, pants: 0x1a2038, skin: P.skin[1], hair: 0x1a1210, cap: 0x253154 }); g.add(p); const d = grp(g, 0.7, 0, 0.4); B(d, 0.3, 0.32, 0.75, 0x8a5a34, 0, 0.22, 0); B(d, 0.24, 0.24, 0.3, 0x8a5a34, 0, 0.5, 0.42); B(d, 0.1, 0.12, 0.12, 0x222222, 0, 0.5, 0.6); B(d, 0.08, 0.16, 0.08, 0x6b4a2b, 0.08, 0.66, 0.36); B(d, 0.08, 0.16, 0.08, 0x6b4a2b, -0.08, 0.66, 0.36); [-0.1, 0.1].forEach(x => [-0.25, 0.25].forEach(z => B(d, 0.07, 0.22, 0.07, 0x6b4a2b, x, 0, z))); return g; }
function vending() { const g = new THREE.Group(); B(g, 0.9, 1.9, 0.7, 0xe8343b, 0, 0, 0); B(g, 0.6, 1.2, 0.05, M(0x9fe0ff, { opacity: 0.8 }), -0.1, 0.5, 0.36); for (let r = 0; r < 4; r++) for (let k = 0; k < 3; k++) B(g, 0.14, 0.18, 0.05, [0xffc928, 0x3fd46b, 0x2f7bff][k], -0.28 + k * 0.18, 0.6 + r * 0.28, 0.33); return g; }
function atm() { const g = new THREE.Group(); B(g, 0.8, 1.6, 0.6, 0x2ec27e, 0, 0, 0); B(g, 0.5, 0.35, 0.05, M(0x7fd8ff, { emissive: 0x204870 }), 0, 1.05, 0.31); B(g, 0.6, 0.06, 0.3, 0x253154, 0, 0.8, 0.35); sign(g, '24H', 0.7, 0.25, '#2ec27e', '#ffffff', 0, 1.95, 0.05); return g; }
function fountain() { const g = new THREE.Group(); C(g, 1.4, 1.5, 0.45, 0xd7dde8, 0, 0, 0, 20); C(g, 1.2, 1.2, 0.05, M(0x5fc8ff), 0, 0.42, 0, 20); C(g, 0.18, 0.25, 1.1, 0xd7dde8, 0, 0.4, 0, 10); C(g, 0.6, 0.5, 0.15, 0xd7dde8, 0, 1.45, 0, 14); Sp(g, 0.3, M(0x9fe0ff, { opacity: 0.7 }), 0, 1.8, 0, 10); return g; }
function infodesk() { const g = new THREE.Group(); C(g, 1.1, 1.1, 0.95, 0x2f7bff, 0, 0, 0, 16); C(g, 1.15, 1.15, 0.08, 0xf7f9fc, 0, 0.95, 0, 16); const a = person({ shirt: 0xffc928, pants: 0x253154, skin: P.skin[0], hair: 0xe0a040 }); a.position.set(0, 0, 0); a.scale.setScalar(0.95); g.add(a); C(g, 0.04, 0.04, 1.8, 0x7a8395, 0.9, 0, -0.6, 6); sign(g, 'INFO', 1.0, 0.4, '#2f7bff', '#ffffff', 0.9, 2.3, -0.6); return g; }
function cashPile(n) {
  const g = new THREE.Group();
  const stacks = [[0, 0], [0.45, 0.1], [-0.4, 0.15], [0.1, -0.4], [0.3, 0.45], [-0.3, -0.35]];
  for (let i = 0; i < Math.min(stacks.length, n * 2); i++) { const h = 3 + ((i * 7) % 4); for (let k = 0; k < h; k++) { const b = B(g, 0.6, 0.09, 0.32, k % 2 ? 0x3fbf6b : 0x46cc75, stacks[i][0], k * 0.09, stacks[i][1]); b.rotation.y = (i * 0.7 + k * 0.05); } }
  for (let i = 0; i < n * 3; i++) { const c = mesh(G.cyl(0.16, 0.16, 0.05, 12), M(0xffc531), g, Math.sin(i * 2.1) * 0.6, 0.03 + (i % 3) * 0.05, Math.cos(i * 1.7) * 0.6); }
  return g;
}
function cleaner(frame) { const g = new THREE.Group(); const p = person({ shirt: 0x18b48d, pants: 0x253154, skin: P.skin[2], hair: 0x1a1210, frame }); g.add(p); const c = grp(g, 0, 0, 0.75); B(c, 0.55, 0.55, 0.45, 0xffc928, 0, 0.12, 0); C(c, 0.15, 0.15, 0.45, 0x2f7bff, 0.12, 0.67, 0, 8); C(c, 0.02, 0.02, 1.0, 0x8a93a6, -0.2, 0.67, -0.1, 4); return g; }
/* ===================================================================
   API para o render.js
   =================================================================== */
window.STUDIO = {
  L, PLANES, PH,
  sprite(name, opts) { return shot(BUILD[name], opts || OPTS[name] || {}); },
  bg(city, phase = 2) {
    // quadro do mapa inteiro em k=0.75
    const k = 0.75, u = S * k, m = L.map;
    const cs = [[m.x0, m.z0], [m.x1, m.z0], [m.x0, m.z1], [m.x1, m.z1]].map(([x, z]) => [(x - z) / Math.SQRT2, (x + z) / Math.SQRT2 * 0.5]);
    const umax = Math.max(...cs.map(c => Math.abs(c[0])));
    const vmin = Math.min(...cs.map(c => c[1])) - 16, vmax = Math.max(...cs.map(c => c[1])) + 2;
    const W = Math.ceil(umax * 2 * u), H = Math.ceil((vmax - vmin) * u);
    const oy = -vmin / (vmax - vmin);
    const scene = new THREE.Scene();
    scene.add(new THREE.HemisphereLight(0xffffff, 0x9aa8c0, 0.62));
    const d = new THREE.DirectionalLight(0xfff3df, 0.62); d.position.set(-14, 40, 22); d.castShadow = true; d.shadow.mapSize.set(8192, 8192);
    Object.assign(d.shadow.camera, { left: -130, right: 130, top: 130, bottom: -130, near: 1, far: 240 }); d.shadow.bias = -0.0004; scene.add(d, d.target);
    scene.add(background(city, phase));
    const cam = isoCam(W, H, k, oy);
    R.setSize(W, H); R.setClearColor(0x86d35e, 1); R.render(scene, cam);
    const r = crop(W, H, W / 2, H * oy, 'jpg'); r.k = k; return r;
  },
  icon(name) { if (name.startsWith('pm_')) { const [, t, l] = name.split('_'); return iconShot(() => { const p = plane(+t, +l); p.rotation.y = Math.PI * 0.72; p.rotation.x = -0.15; const g = new THREE.Group(); g.add(p); return g; }); } return iconShot(ICONS[name]); },
  iconNames: () => [...Object.keys(ICONS), ...[0, 1, 2].flatMap(t => [0, 1, 2, 3, 4, 5].map(l => `pm_${t}_${l}`))],
  keyart, appIcon,
};
/* catálogo de sprites */
const BUILD = {}, OPTS = {};
function def(name, fn, opts) { BUILD[name] = fn; if (opts) OPTS[name] = opts; }
const SHIRTS = [[0xff4e4e, 0x2b3245], [0x2f7bff, 0x3b4a6b], [0xffc928, 0x2f7bff], [0x2ec27e, 0x253154], [0x8b5cf6, 0x2b3245], [0xff8a1f, 0x5a3a20], [0xffffff, 0x253154], [0xff7ab6, 0x3b4a6b]];
const HAIR = [0x3b2a20, 0xe0a040, 0x1a1210, 0x6b3a20, 0x2a1a12, 0xc0c0c0, 0x8a4a20, 0x1a1210];
const BAGS = [0xff4e4e, 0x2f7bff, 0x2ec27e, 0xffc928, 0x8b5cf6, 0x253154, 0xff8a1f, 0x18b48d];
for (let c = 0; c < SHIRTS.length; c++) for (const dir of ['d', 'u']) for (const f of ['0', '1', '2', '3', 'i']) for (const b of ['', 'b']) {
  def(`p${c}_${dir}_${f}${b}`, () => { const g = new THREE.Group(); const p = person({ shirt: SHIRTS[c][0], pants: SHIRTS[c][1], skin: P.skin[c % 4], hair: HAIR[c], frame: f === 'i' ? -1 : +f, bag: b ? BAGS[c] : false }); p.rotation.y = dir === 'd' ? Math.PI / 2 : Math.PI; g.add(p); return g; }, { k: 2, W: 96, H: 96, oy: 0.8, catcher: 0.18 });
}
// 16 direções; só 2..10 são renderizadas (as outras são o espelho horizontal)
for (let t = 0; t < 3; t++) for (let l = 0; l < LIVERY.length; l++) for (let h = 2; h <= 10; h++) {
  def(`pl${t}_${l}_${h}`, () => { const g = new THREE.Group(); const p = plane(t, l); p.rotation.y = h * Math.PI / 8; g.add(p); return g; }, { k: 1.15, W: 440, H: 330, oy: 0.6, shadow: false });
}
for (const v of ['bus', 'car', 'taxi', 'fuel', 'tug', 'stairs']) for (let h = 0; h < 4; h++) def(`v_${v}_${h}`, () => { const g = new THREE.Group(); const o = vehicle(v, 0x2f7bff); o.rotation.y = h * Math.PI / 2; g.add(o); return g; }, { k: 1.5, W: 300, H: 240, oy: 0.65 });

for (const [n, f, o] of [['totem', totem, { W: 160, H: 220, oy: 0.8 }], ['ledboard', () => ledboard(), { W: 300, H: 300, oy: 0.75 }], ['plant', () => plant(), { W: 120, H: 140, oy: 0.75 }], ['plant_big', () => plant(true), { W: 140, H: 170, oy: 0.75 }], ['bench', bench, { W: 160, H: 140, oy: 0.65 }], ['bodyscan', bodyscan, { W: 180, H: 220, oy: 0.75 }], ['dog', dogUnit, { W: 140, H: 150, oy: 0.75 }], ['vending', vending, { W: 120, H: 180, oy: 0.8 }], ['atm', atm, { W: 120, H: 180, oy: 0.8 }], ['fountain', fountain, { W: 220, H: 200, oy: 0.65 }], ['infodesk', infodesk, { W: 200, H: 220, oy: 0.72 }]]) def(n, f, Object.assign({ k: 1.5 }, o));
for (let n = 1; n <= 3; n++) def('cash' + n, () => cashPile(n), { k: 2, W: 160, H: 140, oy: 0.68 });
for (const dir of ['d', 'u']) for (const f of ['0', '1', '2', '3']) def(`cl_${dir}_${f}`, () => { const g = new THREE.Group(); const p = cleaner(+f); p.rotation.y = dir === 'd' ? Math.PI / 2 : Math.PI; g.add(p); return g; }, { k: 2, W: 120, H: 110, oy: 0.75, catcher: 0.18 });
const CARC = [0xff4e4e, 0x2f7bff, 0xffffff, 0x2b3245, 0x2ec27e, 0xffc928];
for (let c = 0; c < CARC.length; c++) for (let h = 0; h < 4; h++) def(`car${c}_${h}`, () => { const g = new THREE.Group(); const o = vehicle('car', CARC[c]); o.rotation.y = h * Math.PI / 2; g.add(o); return g; }, { k: 1.5, W: 140, H: 120, oy: 0.65 });
def('checkin', checkinDesk, { W: 300, H: 300, oy: 0.68 });
def('security', securityLane, { W: 320, H: 320, oy: 0.62 });
for (let i = 0; i < 6; i++) for (let t = 1; t <= 3; t++) def(`shop${i}_${t}`, () => shopT(i, t), { W: 400, H: 560, oy: 0.76 });
for (let t = 2; t <= 3; t++) { def('checkin_' + t, () => checkinT(t), { W: 320, H: 340, oy: 0.7 }); def('security_' + t, () => securityT(t), { W: 340, H: 340, oy: 0.64 }); }
for (let t = 1; t <= 3; t++) def('vip' + t, () => vip(t), { W: 640, H: 520, oy: 0.55 });
for (let n = 1; n <= 6; n++) for (let t = 1; t <= 3; t++) def(`gate${n}_${t}`, () => gateInterior(n, t), { W: 420, H: 360, oy: 0.6 });
for (let t = 1; t <= 2; t++) def('bridge' + t, () => jetBridge(t), { W: 420, H: 420, oy: 0.4 });
for (let t = 1; t <= 4; t++) def('parking' + t, () => parking(t), { k: 1.2, W: 1100, H: 760, oy: 0.5 });
def('busstop', busStop, { W: 300, H: 260, oy: 0.65 });
for (let t = 1; t <= 3; t++) def('tower' + t, () => tower(t), { W: 300, H: 820, oy: 0.88 });
def('hangar', hangar, { k: 1.2, W: 760, H: 560, oy: 0.62 });
def('fuel', fuelFarm, { k: 1.2, W: 560, H: 420, oy: 0.62 });
def('obra_s', () => obra(4, 4), { W: 360, H: 260, oy: 0.55 });
def('obra_m', () => obra(8, 6), { W: 560, H: 380, oy: 0.55 });
def('obra_l', () => obra(13, 11), { k: 1.2, W: 800, H: 520, oy: 0.5 });
for (let t = 1; t <= 3; t++) def('aids' + t, () => runwayAids(t), { k: 0.6, W: 2600, H: 1100, oy: 0.12, catcher: 0.15 });
def('wall', () => airsideWall(PH[2].tx1, 2), { k: 1, W: 2600, H: 1400, oy: 0.5 });
def('wall1', () => airsideWall(PH[1].tx1, 1), { k: 1, W: 2000, H: 1100, oy: 0.5 });
def('wall0', () => airsideWall(PH[0].tx1, 0), { k: 1, W: 1400, H: 800, oy: 0.5 });
for (let i = 0; i < 6; i++) def('esp' + i, ESP[i], { k: 1.2, W: 700, H: 760, oy: 0.72 });
def('heli', () => helicopter(), { W: 300, H: 260, oy: 0.7, shadow: false });
def('checkin_w', checkinWood, { W: 300, H: 300, oy: 0.68 });
def('security_w', securityWood, { W: 320, H: 320, oy: 0.62 });
for (let n = 1; n <= 2; n++) def('gatew' + n, () => gateWood(n), { W: 420, H: 360, oy: 0.6 });
def('tower0', tower0, { W: 260, H: 420, oy: 0.82 });
def('parking0', parking0, { k: 1.2, W: 1100, H: 760, oy: 0.5 });
def('carousel', carousel, { W: 300, H: 260, oy: 0.65 });
def('cargo', cargoTerminal, { k: 1.2, W: 640, H: 520, oy: 0.62 });
def('statue', statue, { W: 200, H: 260, oy: 0.75 });
def('flowerbed', flowerbed, { W: 260, H: 180, oy: 0.65 });
def('palm_pot', palmPot, { W: 200, H: 260, oy: 0.8 });
def('artwall', artwall, { W: 260, H: 260, oy: 0.75 });
window.STUDIO.spriteNames = () => Object.keys(BUILD);
