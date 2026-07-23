import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync, spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock';
const WEB = 'web/clock-app/hl24a-canvas-e5.html';
const DOC = 'docs/web/TASK_D13C_AUTO_PHONE_WEATHER.md';
const SMOKE = 'scripts/task-d13c-auto-weather-smoke.mjs';
const PROOF = `${ROOT}/_incoming/D13C_AUTO_WEATHER_PROOF`;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const web = fs.readFileSync(`${ROOT}/${WEB}`, 'utf8');
const script = web.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';
const has = (pattern, message) => assert.match(web, pattern, message);

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');
has(/D13C-AUTO-WEATHER-20260723/, 'D13C build marker missing');
has(/navigator\.geolocation\.getCurrentPosition/, 'phone geolocation missing');
has(/enableHighAccuracy:false,timeout:10000,maximumAge:900000/, 'bounded geolocation options missing');
has(/https:\/\/api\.open-meteo\.com\/v1\/forecast/, 'Open-Meteo endpoint missing');
has(/temperature_2m,weather_code,wind_speed_10m/, 'current weather fields missing');
has(/precipitation_probability_max/, 'precipitation probability missing');
has(/mapOpenMeteoWeatherCode/, 'bounded weather mapping missing');
has(/if\(\$\('dailyAutoWeather'\)\.checked\)await refreshDailyWeatherFromPhone\(\);[\s\S]*await d2SetDailyContext\(\)/, 'weather must refresh before D2 daily SET');
has(/new Uint8Array\(20\)[\s\S]*packet\[1\]=0x08/, 'D2 08 packet contract changed');
has(/Uint8Array\.of\(0xD2,0x09\)/, 'D2 09 packet contract changed');
assert.doesNotMatch(web, /localStorage/, 'location/weather must not be persisted in browser storage');

const changed = execFileSync('git', ['status', '--porcelain', '--untracked-files=all'], { cwd: ROOT, encoding: 'utf8' })
  .trimEnd().split(/\r?\n/).filter(Boolean).map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([WEB, DOC, SMOKE]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.includes('test.html'), 'test.html must remain unchanged');
assert.ok(!changed.some(file => file.startsWith('firmware/')), 'firmware must remain unchanged');

fs.mkdirSync(PROOF, { recursive: true });
assert.ok(fs.existsSync(CHROME), 'Chrome not found');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const pageUrl = pathToFileURL(`${ROOT}/${WEB}`).href;
const checks = [];

async function capture(name, width, height) {
  const port = 10020 + Math.floor(Math.random() * 20);
  const profile = `${PROOF}/chrome-${name}-${Date.now()}`;
  fs.mkdirSync(profile, { recursive: true });
  const chrome = spawn(CHROME, [
    '--headless=new', '--disable-gpu', '--no-sandbox', '--hide-scrollbars',
    `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, 'about:blank'
  ], { stdio: 'ignore' });
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
    let ready = false;
    for (let attempt = 0; attempt < 50; attempt++) {
      const state = await send('Runtime.evaluate', {
        expression: `document.readyState==='complete'&&typeof refreshDailyWeatherFromPhone==='function'`,
        returnByValue: true
      });
      if (state.result.value === true) { ready = true; break; }
      await delay(100);
    }
    assert.ok(ready, `${name} page did not become ready`);
    const evaluated = await send('Runtime.evaluate', {
      expression: `(async()=>{
        navigator.geolocation.getCurrentPosition=success=>success({coords:{latitude:10.7769,longitude:106.7009}});
        globalThis.fetch=async()=>({ok:true,json:async()=>({current:{temperature_2m:32.4,weather_code:61,wind_speed_10m:8},daily:{precipitation_probability_max:[70]}})});
        selectClockProfile(2);
        await refreshDailyWeatherFromPhone();
        const packet=buildD2SetDailyPacket(new Date(2026,6,23,9,2,20));
        return JSON.stringify({width:innerWidth,scroll:document.documentElement.scrollWidth,build:EINK_TEST_IDENTITY.webBuild,panel:!dailyContextPanel.hidden,advanced:advancedPanel.open,weatherCode:dailyWeatherCode.value,temperature:dailyTemperature.value,precipitation:dailyPrecipitation.value,agendaCount:packet[9],packet:[...packet],status:dailyWeatherStatus.textContent,black:blackPixels.textContent});
      })()`,
      awaitPromise: true,
      returnByValue: true
    });
    assert.ok(!evaluated.exceptionDetails, `${name} fixture evaluation failed`);
    const page = JSON.parse(evaluated.result.value);
    assert.ok(page.scroll <= page.width, `${name} horizontal overflow`);
    assert.equal(page.build, 'D13C-AUTO-WEATHER-20260723', `${name} build marker`);
    assert.equal(page.panel, true, `${name} daily panel hidden`);
    assert.equal(page.advanced, false, `${name} Advanced opened`);
    assert.equal(page.weatherCode, '2', `${name} WMO rain mapping`);
    assert.equal(page.temperature, '32', `${name} rounded temperature`);
    assert.equal(page.precipitation, '70', `${name} precipitation probability`);
    assert.equal(page.agendaCount, 0, `${name} empty agenda must remain optional`);
    assert.deepEqual(page.packet.slice(0, 4), [0xD2, 0x08, 0x01, 0x01], `${name} D2 daily header`);
    assert.equal(page.packet.length, 20, `${name} D2 daily length`);
    assert.match(page.status, /32 C.*70%/, `${name} visible weather status`);
    assert.ok(Number(page.black) > 0, `${name} preview blank`);
    const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    fs.writeFileSync(`${PROOF}/${name}.png`, Buffer.from(shot.data, 'base64'));
    socket.close();
    checks.push(`${name}: GPS/API mock -> RAN 32C POP 70, agenda empty, no overflow`);
  } finally {
    chrome.kill();
  }
}

for (const viewport of [['desktop', 1365, 800], ['mobile', 360, 780]]) await capture(...viewport);
fs.writeFileSync(`${PROOF}/browser-check.txt`, [
  'TASK D13C automatic phone weather browser proof PASS',
  'Canonical URL: https://onlysky17.github.io/Clock/test.html',
  ...checks
].join('\n'));

console.log('TASK D13C automatic phone weather smoke PASS');
