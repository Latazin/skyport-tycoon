// Capturas de tela da build web (rodado no GitHub Actions).
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  fs.mkdirSync('shots', { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=angle', '--enable-unsafe-swiftshader', '--lang=pt-BR'] });
  const runs = [
    ['01_titulo', '', [12000]], ['02_fila_inicio', '?auto=1&tut=7&panel=none', [30000, 55000]],
    ['03_tutorial', '?auto=1&tut=1&panel=none', [30000]], ['04_cheio', '?auto=1&demo=1&panel=none', [30000, 45000]],
    ['05_checkin', '?auto=1&demo=1&panel=st:checkin', [30000]], ['06_melhorias', '?auto=1&demo=1&panel=upgrades', [30000]],
    ['07_estrelas', '?auto=1&demo=1&panel=stars', [30000]], ['08_missoes', '?auto=1&demo=1&panel=missions', [30000]],
    ['09_frota', '?auto=1&demo=1&panel=fleet', [30000]], ['10_equipe', '?auto=1&demo=1&panel=team', [30000]],
    ['11_loja', '?auto=1&demo=1&panel=shop', [30000]], ['12_bau', '?auto=1&demo=1&chest=1', [30000]],
  ];
  for (const [name, q, waits] of runs) {
    const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'pt-BR' });
    const logs = []; p.on('console', m => logs.push(m.type() + ': ' + m.text())); p.on('pageerror', e => logs.push('ERR ' + e.message));
    await p.goto('http://localhost:8080/' + q);
    let t0 = 0;
    for (let i = 0; i < waits.length; i++) { await p.waitForTimeout(waits[i] - t0); t0 = waits[i]; await p.screenshot({ path: `shots/${name}${waits.length > 1 ? '_' + (i + 1) : ''}.png` }); }
    fs.writeFileSync(`shots/${name}.log`, logs.filter(l => !l.includes('AudioContext')).join('\n'));
    await p.close();
  }
  await b.close();
})();
