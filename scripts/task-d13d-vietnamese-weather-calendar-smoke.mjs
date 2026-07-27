import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync, spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock';
const FW = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const WEB = 'web/clock-app/hl24a-canvas-e5.html';
const DOC = 'docs/firmware/TASK_D13D_VIETNAMESE_WEATHER_CALENDAR.md';
const SMOKE = 'scripts/task-d13d-vietnamese-weather-calendar-smoke.mjs';
const PROOF = `${ROOT}/_incoming/D13D_VIETNAMESE_WEATHER_PROOF`;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const firmware = fs.readFileSync(`${ROOT}/${FW}`, 'utf8');
const web = fs.readFileSync(`${ROOT}/${WEB}`, 'utf8');
const script = web.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');
assert.match(firmware, /"NANG", "MAY", "MUA", "GIONG", "SUONG", "GIO", "NONG"/, 'Vietnamese firmware weather words missing');
assert.doesNotMatch(firmware.match(/static void hink_d13b_draw_daily_briefing[\s\S]*?\n}\n/)?.[0] ?? '', /CLD|POP|TODAY|HOP|GYM/, 'English or sample agenda text remains in renderer');
assert.match(firmware, /hink_d13b_draw_daily_briefing[\s\S]*?hink_bitmap_draw_clock\(h, m, sy, sm, sd, sw, lunar_valid, lm, ld, ampm\)/, 'profile 02 must reuse monthly calendar');
assert.match(firmware, /109U \+ \(col \* 20U\)/, 'monthly weekday/day grid changed');
assert.match(firmware, /if \(day == sd\)[\s\S]*?hink_d7a_box/, 'current-day highlight missing');
assert.match(web, /D13D-VI-WEATHER-20260723/, 'D13D build marker missing');
assert.match(web, /Th\\u1eddi ti\\u1ebft t\\u1ef1 \\u0111\\u1ed9ng v\\u00e0 l\\u1ecbch th\\u00e1ng/, 'Vietnamese weather/calendar heading missing');
assert.doesNotMatch(web, /placeholder="HOP"|placeholder="GYM"/, 'sample agenda remains visible');
assert.match(web, /id="dailyAgendaTime0" type="hidden"/, 'compatibility agenda fields missing');
assert.match(web, /new Uint8Array\(20\)[\s\S]*packet\[1\]=0x08/, 'D2 08 packet changed');
assert.match(web, /Uint8Array\.of\(0xD2,0x09\)/, 'D2 09 packet changed');
assert.match(web, /\['N\\u1eafng','Nhi\\u1ec1u m\\u00e2y','M\\u01b0a','Gi\\u00f4ng'/, 'Vietnamese status mapping missing');

const changed = execFileSync('git', ['status', '--porcelain', '--untracked-files=all'], { cwd: ROOT, encoding: 'utf8' })
  .trimEnd().split(/\r?\n/).filter(Boolean).map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([FW, WEB, DOC, SMOKE]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.includes('test.html'), 'test.html must remain unchanged');

fs.mkdirSync(PROOF, { recursive: true });
assert.ok(fs.existsSync(CHROME), 'Chrome not found');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const pageUrl = pathToFileURL(`${ROOT}/${WEB}`).href;

async function capture(name, width, height) {
  const port = 10050 + Math.floor(Math.random() * 20);
  const profile = `${PROOF}/chrome-${name}-${Date.now()}`;
  fs.mkdirSync(profile, { recursive: true });
  const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--no-sandbox', '--hide-scrollbars',
    `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, 'about:blank'], { stdio: 'ignore' });
  try {
    let targets;
    for (let attempt = 0; attempt < 50; attempt++) {
      try {
        targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
        if (targets.some(target => target.type === 'page')) break;
      } catch {}
      await delay(100);
    }
    const target = targets?.find(item => item.type === 'page');
    assert.ok(target?.webSocketDebuggerUrl, `${name} target missing`);
    const socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { socket.onopen = resolve; socket.onerror = reject; });
    let id = 0;
    const pending = new Map();
    socket.onmessage = event => {
      const message = JSON.parse(event.data);
      if (!message.id || !pending.has(message.id)) return;
      const item = pending.get(message.id);
      pending.delete(message.id);
      message.error ? item.reject(new Error(message.error.message)) : item.resolve(message.result);
    };
    const send = (method, params = {}) => new Promise((resolve, reject) => {
      const requestId = ++id;
      pending.set(requestId, { resolve, reject });
      socket.send(JSON.stringify({ id: requestId, method, params }));
    });
    await send('Page.enable');
    await send('Runtime.enable');
    await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: width <= 420 });
    await send('Page.navigate', { url: pageUrl });
    for (let attempt = 0; attempt < 50; attempt++) {
      const ready = await send('Runtime.evaluate', { expression: `document.readyState==='complete'&&typeof drawDailyBriefingPreview==='function'`, returnByValue: true });
      if (ready.result.value === true) break;
      await delay(100);
    }
    const evaluated = await send('Runtime.evaluate', {
      expression: `(()=>{selectClockProfile(2);dailyWeatherEnabled.checked=true;dailyWeatherCode.value='1';dailyTemperature.value='30';dailyPrecipitation.value='88';drawDailyBriefingPreview();const p=buildD2SetDailyPacket(new Date(2026,6,23,8,46));return JSON.stringify({width:innerWidth,scroll:document.documentElement.scrollWidth,build:EINK_TEST_IDENTITY.webBuild,panel:!dailyContextPanel.hidden,agendaVisible:[dailyAgendaTime0,dailyAgendaLabel0,dailyAgendaTime1,dailyAgendaLabel1].some(x=>x.type!=='hidden'),agendaCount:p[9],packet:[...p],black:blackPixels.textContent,status:dailyContextPanel.textContent})})()`,
      returnByValue: true
    });
    assert.ok(!evaluated.exceptionDetails, `${name} fixture failed`);
    const page = JSON.parse(evaluated.result.value);
    assert.ok(page.scroll <= page.width, `${name} horizontal overflow`);
    assert.equal(page.build, 'D13D-VI-WEATHER-20260723', `${name} build marker`);
    assert.equal(page.panel, true, `${name} panel hidden`);
    assert.equal(page.agendaVisible, false, `${name} agenda controls visible`);
    assert.equal(page.agendaCount, 0, `${name} agenda bytes not empty`);
    assert.deepEqual(page.packet.slice(0, 4), [0xD2, 0x08, 0x01, 0x01], `${name} D2 header`);
    assert.match(page.status, /Thời tiết tự động và lịch tháng/, `${name} Vietnamese heading`);
    assert.ok(Number(page.black) > 0, `${name} preview blank`);
    const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    fs.writeFileSync(`${PROOF}/${name}.png`, Buffer.from(shot.data, 'base64'));
    socket.close();
  } finally {
    chrome.kill();
  }
}

await capture('desktop', 1365, 800);
await capture('mobile', 360, 780);
fs.writeFileSync(`${PROOF}/browser-check.txt`, 'TASK D13D Vietnamese weather calendar browser proof PASS\nCanonical URL: https://onlysky17.github.io/Clock/test.html\n');
console.log('TASK D13D Vietnamese weather calendar smoke PASS');
