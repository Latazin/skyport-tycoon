// Capturas de tela da build web (rodado no GitHub Actions).
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  fs.mkdirSync('shots', { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=angle', '--enable-unsafe-swiftshader', '--lang=pt-BR'] });
  const runs = [
    ['1_titulo', '', 12000], ['2_inicio', '?auto=1', 22000], ['3_tutorial', '?auto=1&tut=1', 22000],
    ['4_cheio', '?auto=1&demo=1', 30000], ['5_estacao', '?auto=1&demo=1&panel=st:checkin', 30000], ['6_melhorias', '?auto=1&demo=1&panel=upgrades', 28000],
    ['7_portao', '?auto=1&demo=1&panel=st:g0', 28000], ['8_missoes', '?auto=1&demo=1&panel=missions', 26000], ['9_cidades', '?auto=1&demo=1&panel=cities', 26000],
  ];
  for (const [name, q, wait] of runs) {
    const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'pt-BR' });
    const logs = []; p.on('console', m => logs.push(m.type() + ': ' + m.text())); p.on('pageerror', e => logs.push('ERR ' + e.message));
    await p.goto('http://localhost:8080/' + q);
    await p.waitForTimeout(wait);
    await p.screenshot({ path: `shots/${name}.png` });
    fs.writeFileSync(`shots/${name}.log`, logs.join('\n'));
    await p.close();
  }
  await b.close();
})();
