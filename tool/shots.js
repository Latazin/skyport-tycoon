// Capturas de tela da build web (rodado no GitHub Actions).
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  fs.mkdirSync('shots', { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=angle', '--enable-unsafe-swiftshader', '--lang=pt-BR'] });
  const runs = [
    ['01_titulo', '', [12000]], ['02_aeroclube', '?auto=1&demo=p0&panel=none', [30000, 55000]],
    ['02b_regional', '?auto=1&demo=p1&panel=none', [30000, 50000]], ['02c_hub', '?auto=1&demo=1&star=4&panel=none', [30000]],
    ['03_tutorial', '?auto=1&tut=1&panel=none', [30000]], ['04_cheio', '?auto=1&demo=1&panel=none', [30000, 45000]],
    ['05_checkin', '?auto=1&demo=1&panel=st:checkin', [30000]], ['06_melhorias', '?auto=1&demo=1&panel=upgrades', [30000]],
    ['07_estrelas', '?auto=1&demo=1&panel=stars', [30000]], ['08_missoes', '?auto=1&demo=1&panel=missions', [30000]],
    ['09_frota', '?auto=1&demo=1&panel=fleet', [30000]], ['10_equipe', '?auto=1&demo=1&panel=team', [30000]],
    ['11_loja', '?auto=1&demo=1&panel=shop', [30000]], ['12_bau', '?auto=1&demo=1&chest=1', [30000]],
    ['13_contratos', '?auto=1&demo=p1&panel=fleet', [30000]], ['14_decoracao', '?auto=1&demo=p1&panel=upgrades', [30000]], ['15_jogos', '?auto=1&demo=p1&panel=games', [30000]],
    ['21_roleta', '?auto=1&demo=1&panel=wheel', [24000, 25000, 33000], [[1, 195, 600]]], ['22_bau_epico', '?auto=1&demo=1&panel=chest', [24000, 27000, 34000], [[1, 195, 330], [1, 195, 330], [1, 195, 330]]], ['23_nivel', '?auto=1&demo=1&panel=levelup', [25000]], ['24_diario', '?auto=1&demo=1&panel=daily', [25000]],
    ['16_porto_azul', '?auto=1&demo=p1&city=1&panel=none', [32000]], ['17_serra_alta', '?auto=1&demo=1&city=3&panel=none', [32000]],
    ['18_rio_dourado', '?auto=1&demo=p1&city=4&panel=none', [32000]], ['19_costa', '?auto=1&demo=1&city=5&panel=none', [32000]],
    ['20_rede', '?auto=1&demo=1&city=2&star=5&panel=cities', [30000]],
  ];
  for (const [name, q, waits, clicks] of runs) {
    const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'pt-BR' });
    const logs = []; p.on('console', m => logs.push(m.type() + ': ' + m.text())); p.on('pageerror', e => logs.push('ERR ' + e.message));
    await p.goto('http://localhost:8080/' + q);
    let t0 = 0;
    for (let i = 0; i < waits.length; i++) { await p.waitForTimeout(waits[i] - t0); t0 = waits[i]; for (const c of (clicks || []).filter(c => c[0] === i)) { await p.mouse.click(c[1], c[2]); await p.waitForTimeout(250); } await p.screenshot({ path: `shots/${name}${waits.length > 1 ? '_' + (i + 1) : ''}.png` }); }
    fs.writeFileSync(`shots/${name}.log`, logs.filter(l => !l.includes('AudioContext')).join('\n'));
    await p.close();
  }
  await b.close();
})();
