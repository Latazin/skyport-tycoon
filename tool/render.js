// Renderiza a arte do SkyPort: node tool/render.js [filtro]
// Saída: tool/out/{sprites,bg,icons}/ + tool/out/raw.json (âncoras)
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, 'out');
const only = process.argv[2] || '';
(async () => {
  for (const d of ['sprites', 'bg', 'icons', 'misc']) fs.mkdirSync(path.join(OUT, d), { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const p = await b.newPage();
  p.on('pageerror', e => console.log('ERR', e.message));
  p.on('console', m => { if (m.type() === 'error') console.log('console', m.text()); });
  await p.goto('file://' + path.join(__dirname, 'studio/studio.html'));
  const rawPath = path.join(OUT, 'raw.json');
  const raw = fs.existsSync(rawPath) ? JSON.parse(fs.readFileSync(rawPath)) : { sprites: {}, bg: {} };
  const save = (file, dataUrl) => fs.writeFileSync(file, Buffer.from(dataUrl.split(',')[1], 'base64'));
  const want = n => !only || only.split(',').some(o => n.startsWith(o));
  const names = await p.evaluate(() => STUDIO.spriteNames());
  let n = 0;
  for (const name of names) {
    if (!want(name)) continue;
    const r = await p.evaluate(nm => STUDIO.sprite(nm), name);
    if (!r) { console.log('vazio', name); continue; }
    save(path.join(OUT, 'sprites', name + '.png'), r.png);
    raw.sprites[name] = { ax: r.ax, ay: r.ay, w: r.w, h: r.h, k: r.k };
    if (++n % 40 === 0) console.log(n, name);
  }
  for (let c = 0; c < 3; c++) {
    if (!want('bg' + c)) continue;
    const r = await p.evaluate(ci => STUDIO.bg(ci), c);
    save(path.join(OUT, 'bg', `bg${c}.jpg`), r.png);
    raw.bg['bg' + c] = { ax: r.ax, ay: r.ay, w: r.w, h: r.h, k: r.k };
    console.log('bg', c, r.w, r.h);
  }
  if (want('icon')) {
    for (const ic of await p.evaluate(() => STUDIO.iconNames())) { const r = await p.evaluate(nm => STUDIO.icon(nm), ic); save(path.join(OUT, 'icons', 'icon_' + ic + '.png'), r.png); }
    console.log('icons ok');
  }
  if (want('misc')) {
    save(path.join(OUT, 'misc', 'keyart.jpg'), (await p.evaluate(() => STUDIO.keyart(1080, 1920))).png);
    save(path.join(OUT, 'misc', 'feature.jpg'), (await p.evaluate(() => STUDIO.keyart(1024, 500))).png);
    save(path.join(OUT, 'misc', 'icon.png'), (await p.evaluate(() => STUDIO.appIcon(1024))).png);
    save(path.join(OUT, 'misc', 'icon_fg.png'), (await p.evaluate(() => STUDIO.appIcon(1024, true))).png);
    console.log('misc ok');
  }
  raw.layout = await p.evaluate(() => STUDIO.L);
  raw.planes = await p.evaluate(() => STUDIO.PLANES);
  fs.writeFileSync(rawPath, JSON.stringify(raw));
  await b.close();
})();
