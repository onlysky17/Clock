import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync, spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock';
const WEB = 'web/clock-app/hl24a-canvas-e5.html';
const DOC = 'docs/web/TASK_D14B_CONNECTED_AUTO_WEATHER_REFRESH.md';
const SMOKE = 'scripts/task-d14b-connected-auto-weather-refresh-smoke.mjs';
const PROOF = `${ROOT}/_incoming/D14B_AUTO_WEATHER_PROOF`;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const web = fs.readFileSync(`${ROOT}/${WEB}`, 'utf8');
const doc = fs.readFileSync(`${ROOT}/${DOC}`, 'utf8');
const script = web.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';
const toggleBlock = script.match(/function toggleAutomaticWeather\(\)\{[\s\S]*?\n\}/)?.[0] ?? '';

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');
assert.match(web, /D14B-AUTO-WEATHER-20260727/, 'D14B marker missing');
assert.match(web, /id="dailyAutoWeather" type="checkbox">/, 'auto weather must default OFF');
assert.match(web, /T\\u1ef1 c\\u1eadp nh\\u1eadt m\\u1ed7i 30 ph\\u00fat/, '30-minute UI label missing');
assert.match(script, /const AUTO_WEATHER_INTERVAL_MS=30\*60\*1000/);
assert.match(script, /const AUTO_WEATHER_RETRY_MS=60\*1000/);
assert.match(script, /document\.visibilityState==='visible'/);
assert.match(script, /!!server\?\.connected/);
assert.match(script, /identityCompatibility==='compatible'/);
assert.match(script, /activeClockProfile===2/);
assert.match(script, /maximumAge:0/);
assert.match(script, /precipitationNow>=0\.2/);
assert.match(script, /dailyStatusMatchesPacket\(lastDailyStatus,packet\)/);
assert.match(script, /Thời tiết không đổi, không refresh màn/);
assert.match(script, /const status=await d2SetDailyContext\(packet\)[\s\S]*await d2RenderClockFromDevice\(\)/);
assert.match(script, /if\(status\.state!==1\)/);
assert.match(doc, /D2 82 OK\/COMPLETE/, 'completion contract missing from docs');
assert.match(script, /autoWeatherRetryUsed=true[\s\S]*AUTO_WEATHER_RETRY_MS/);
assert.match(script, /clearAutomaticWeatherTimers\(\)[\s\S]*resetD2UiDisconnected\(\)/);
assert.match(script, /document\.addEventListener\('visibilitychange'/);
assert.doesNotMatch(script, /localStorage/);
assert.ok(toggleBlock, 'automatic toggle handler missing');
assert.doesNotMatch(toggleBlock, /navigator\.bluetooth|requestDevice|connect\(/,
  'automatic mode must not initiate BLE connection');
assert.match(script, /new Uint8Array\(20\)[\s\S]*packet\[1\]=0x08/);
assert.match(script, /Uint8Array\.of\(0xD2,0x09\)/);
assert.match(script, /buildD2RenderClockPacket/);

const changed = execFileSync(
  'git',
  ['status', '--porcelain', '--untracked-files=all'],
  { cwd: ROOT, encoding: 'utf8' },
).trimEnd().split(/\r?\n/).filter(Boolean)
  .map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([WEB, DOC, SMOKE]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.some(file => file.startsWith('firmware/')), 'firmware changed');
assert.ok(!changed.includes('test.html'), 'test.html changed');

fs.mkdirSync(PROOF, { recursive: true });
assert.ok(fs.existsSync(CHROME), 'Chrome not found');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const pageUrl = pathToFileURL(`${ROOT}/${WEB}`).href;

async function capture(name, width, height) {
  const port = 10120 + Math.floor(Math.random() * 20);
  const profile = `${PROOF}/chrome-${name}-${Date.now()}`;
  fs.mkdirSync(profile, { recursive: true });
  const chrome = spawn(CHROME, [
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--hide-scrollbars',
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`,
    'about:blank',
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
    await new Promise((resolve, reject) => {
      socket.onopen = resolve;
      socket.onerror = reject;
    });
    let id = 0;
    const pendingCalls = new Map();
    socket.onmessage = event => {
      const message = JSON.parse(event.data);
      if (!message.id || !pendingCalls.has(message.id)) return;
      const call = pendingCalls.get(message.id);
      pendingCalls.delete(message.id);
      message.error ? call.reject(new Error(message.error.message)) : call.resolve(message.result);
    };
    const send = (method, params = {}) => new Promise((resolve, reject) => {
      const requestId = ++id;
      pendingCalls.set(requestId, { resolve, reject });
      socket.send(JSON.stringify({ id: requestId, method, params }));
    });

    await send('Page.enable');
    await send('Runtime.enable');
    await send('Emulation.setDeviceMetricsOverride', {
      width,
      height,
      deviceScaleFactor: 1,
      mobile: width <= 420,
    });
    await send('Page.navigate', { url: pageUrl });
    for (let attempt = 0; attempt < 50; attempt++) {
      const ready = await send('Runtime.evaluate', {
        expression: `document.readyState==='complete'&&typeof scheduleAutomaticWeatherCheck==='function'`,
        returnByValue: true,
      });
      if (ready.result.value === true) break;
      await delay(100);
    }

    const evaluated = await send('Runtime.evaluate', {
      expression: `(()=>{selectClockProfile(2);const initialOff=!dailyAutoWeather.checked;dailyAutoWeather.checked=true;toggleAutomaticWeather();const disconnected=dailyAutoWeatherStatus.textContent;dailyWeatherEnabled.checked=true;dailyWeatherCode.value='1';dailyTemperature.value='30';dailyPrecipitation.value='88';const packet=buildD2SetDailyPacket(new Date(2026,6,27,10,0));const status={result:0,state:1,weatherValid:true,agendaValid:false,dayKey:u16(packet[4],packet[5]),weather:1,temperature:30,precipitation:88,agendaCount:0,entries:[{minute:0,label:''},{minute:0,label:''}]};autoWeatherLastSuccessAt=Date.now();const nextDelay=automaticWeatherNextDelay();dailyContextPanel.scrollIntoView({block:'start'});return JSON.stringify({width:innerWidth,scroll:document.documentElement.scrollWidth,build:EINK_TEST_IDENTITY.webBuild,initialOff,disconnected,match:dailyStatusMatchesPacket(status,packet),nextDelay,advanced:advancedPanel.open,label:dailyAutoWeather.parentElement.textContent.trim()})})()`,
      returnByValue: true,
    });
    assert.ok(!evaluated.exceptionDetails, `${name} fixture failed`);
    const page = JSON.parse(evaluated.result.value);
    assert.ok(page.scroll <= page.width, `${name} horizontal overflow`);
    assert.equal(page.build, 'D14B-AUTO-WEATHER-20260727', `${name} build marker`);
    assert.equal(page.initialOff, true, `${name} automatic mode default`);
    assert.match(page.disconnected, /chờ kết nối BLE/i, `${name} disconnected state`);
    assert.equal(page.match, true, `${name} unchanged payload match`);
    assert.ok(page.nextDelay > 29 * 60 * 1000, `${name} interval too short`);
    assert.ok(page.nextDelay <= 30 * 60 * 1000, `${name} interval too long`);
    assert.equal(page.advanced, false, `${name} advanced panel`);
    assert.match(page.label, /30 phút/, `${name} visible label`);

    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: false,
    });
    fs.writeFileSync(`${PROOF}/${name}.png`, Buffer.from(shot.data, 'base64'));
    socket.close();
  } finally {
    chrome.kill();
  }
}

await capture('desktop', 1365, 800);
await capture('mobile', 360, 780);
fs.writeFileSync(
  `${PROOF}/browser-check.txt`,
  'TASK D14B connected automatic weather browser proof PASS\nCanonical URL: https://onlysky17.github.io/Clock/test.html\n',
);
console.log('TASK D14B connected automatic weather refresh smoke PASS');
