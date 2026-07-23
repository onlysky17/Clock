import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync, spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock';
const PROOF_DIR = `${ROOT}/_incoming/D13B_DAILY_BRIEFING_PROOF`;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const firmwarePath = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const webPath = 'web/clock-app/hl24a-canvas-e5.html';
const docPath = 'docs/firmware/TASK_D13B_DAILY_BRIEFING_PROFILE.md';
const smokePath = 'scripts/task-d13b-daily-briefing-profile-smoke.mjs';
const firmware = fs.readFileSync(`${ROOT}/${firmwarePath}`, 'utf8');
const web = fs.readFileSync(`${ROOT}/${webPath}`, 'utf8');
const script = web.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';
const has = (text, pattern, message) => assert.match(text, pattern, message);

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');

has(firmware, /HINK_D2_SET_DAILY_LEN\s+20U/, 'SET daily length must be 20');
has(firmware, /HINK_D2_GET_DAILY_LEN\s+2U/, 'GET daily length must be 2');
has(firmware, /HINK_D2_DAILY_STATUS_LEN\s+20U/, 'daily status length must be 20');
has(firmware, /HINK_D2_RESULT_INVALID_DAILY\s+0x09U/, 'daily validation result missing');
has(firmware, /subcmd == 0x08U.*subcmd == 0x09U/s, 'D2 08/09 routing missing');
has(firmware, /msg\[1\] = 0x88/, 'D2 88 notification missing');
has(firmware, /msg\[3\] \|= \(uint8_t\)\(hink_daily_flags << 2\)/, 'status validity bits missing');

has(firmware, /param->value\[2\] != HINK_DAILY_SCHEMA/, 'schema validation missing');
has(firmware, /flags & \(uint8_t\)~HINK_DAILY_FLAGS_MASK/, 'reserved flag validation missing');
has(firmware, /day_key != hink_daily_current_day_key\(\)/, 'local day validation missing');
has(firmware, /temperature < -40.*temperature > 80/s, 'temperature range missing');
has(firmware, /param->value\[8\] > 100U/, 'precipitation range missing');
has(firmware, /count > 2U/, 'agenda bound missing');
has(firmware, /minute1 <= minute0/, 'agenda ordering/duplicate guard missing');
has(firmware, /hink_daily_label_valid/, 'ASCII label validation missing');
has(firmware, /hink_daily_set = 1U;[\s\S]*hink_d2_daily_notify\(HINK_D2_RESULT_OK\)/, 'atomic successful store missing');

has(firmware, /HINK_DAILY_STATE_UNSET[\s\S]*HINK_DAILY_STATE_EXPIRED[\s\S]*HINK_DAILY_STATE_FRESH/, 'freshness states missing');
has(firmware, /hink_daily_day_key != hink_daily_current_day_key/, 'day rollover expiry missing');
has(firmware, /static uint16_t hink_daily_day_key[\s\S]*static char hink_daily_agenda_label\[2\]\[3\]/, 'bounded RAM state missing');
assert.doesNotMatch(firmware.match(/static void hink_d3d_build_record[\s\S]*?\n}\n/)?.[0] ?? '', /hink_daily_/, 'daily payload must not enter SPI journal');

has(firmware, /HINK_CLOCK_PROFILE_DAILY\s+0x02U/, 'profile 02 missing');
has(firmware, /profile > HINK_CLOCK_PROFILE_DAILY/, 'profile validation must accept 02');
has(firmware, /a\[16\] <= HINK_CLOCK_PROFILE_DAILY[\s\S]*b\[16\] <= HINK_CLOCK_PROFILE_DAILY/, 'profile 02 restore missing');
has(firmware, /hink_clock_profile == HINK_CLOCK_PROFILE_DAILY[\s\S]*hink_d13b_draw_daily_briefing/, 'profile dispatcher missing');
has(firmware, /hink_d7a_draw_hhmm[\s\S]*hink_d9a_draw_lunar[\s\S]*weather_tokens[\s\S]*hink_daily_agenda_count/, 'daily layout fields missing');
assert.equal((firmware.match(/u8 fb_bw\[EPD_FRAME_BYTES\]/g) || []).length, 0, 'framebuffer must remain owned by epd_gui.c');
assert.doesNotMatch(firmware, /malloc\s*\(/, 'dynamic allocation forbidden');

has(web, /D13B-DAILY-20260722/, 'web build marker missing');
has(web, /dailyBriefing\.textContent='T\\u00f3m t\\u1eaft trong ng\\u00e0y'/, 'daily profile control missing');
has(web, /packet\[0\]=0xD2;[\s\S]*packet\[1\]=0x08;[\s\S]*packet\[2\]=0x01;/, 'web SET daily header wrong');
has(web, /new Uint8Array\(20\)/, 'web SET daily must be 20 bytes');
has(web, /Number\.isInteger\(temperature\)[\s\S]*Number\.isInteger\(precipitation\)/, 'web integer weather validation missing');
has(web, /Uint8Array\.of\(0xD2,0x09\)/, 'web GET daily must be exact');
has(web, /bytes\.length!==20\|\|bytes\[0\]!==0xD2\|\|bytes\[1\]!==0x88/, 'web D2 88 parser wrong');
has(web, /selectedClockProfile===2\)await d2SetDailyContext\(\)/, 'daily context must apply before profile/render');
has(web, /await d2RenderClockFromDevice\(\)/, 'existing D2 renderer must be reused');
has(web, /status\.result===0x06[\s\S]*waitFor\([\s\S]*a\[3\]===0x03[\s\S]*packet/s, 'daily BUSY retry missing');
has(web, /await d2GetDailyContext\(\)/, 'reconnect daily status read missing');
assert.doesNotMatch(web, /localStorage/, 'daily context must not use localStorage');

const changed = execFileSync('git', ['status', '--porcelain', '--untracked-files=all'], { cwd: ROOT, encoding: 'utf8' })
  .trimEnd().split(/\r?\n/).filter(Boolean).map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([firmwarePath, webPath, docPath, smokePath]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.includes('test.html'), 'test.html must remain unchanged');

fs.mkdirSync(PROOF_DIR, { recursive: true });
assert.ok(fs.existsSync(CHROME), 'Chrome not found');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const pageUrl = pathToFileURL(`${ROOT}/${webPath}`).href;
const checks = [];

async function capture(name, width, height) {
  const port = 9980 + Math.floor(Math.random() * 15);
  const profile = `${PROOF_DIR}/chrome-${name}-${Date.now()}`;
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
        expression: `document.readyState==='complete'&&typeof selectClockProfile==='function'&&typeof buildD2SetDailyPacket==='function'`,
        returnByValue: true
      });
      if (state.result.value === true) { ready = true; break; }
      await delay(100);
    }
    assert.ok(ready, `${name} page did not become ready`);
    const evaluated = await send('Runtime.evaluate', {
      expression: `(()=>{selectClockProfile(2);dailyWeatherEnabled.checked=true;dailyWeatherCode.value='2';dailyTemperature.value='27';dailyPrecipitation.value='40';dailyAgendaTime0.value='08:30';dailyAgendaLabel0.value='HOP';dailyAgendaTime1.value='18:00';dailyAgendaLabel1.value='GYM';drawDailyBriefingPreview();const p=buildD2SetDailyPacket(new Date(2026,6,22,9,2,20));return JSON.stringify({width:innerWidth,scroll:document.documentElement.scrollWidth,build:EINK_TEST_IDENTITY.webBuild,panel:!dailyContextPanel.hidden,advanced:advancedPanel.open,packet:[...p],black:document.getElementById('blackPixels').textContent})})()`,
      returnByValue: true
    });
    assert.ok(!evaluated.exceptionDetails, `${name} fixture evaluation failed`);
    const page = JSON.parse(evaluated.result.value);
    assert.ok(page.scroll <= page.width, `${name} horizontal overflow`);
    assert.equal(page.build, 'D13B-DAILY-20260722', `${name} build marker`);
    assert.equal(page.panel, true, `${name} daily panel hidden`);
    assert.equal(page.advanced, false, `${name} Advanced opened`);
    assert.equal(page.packet.length, 20, `${name} packet length`);
    assert.deepEqual(page.packet.slice(0, 4), [0xD2, 0x08, 0x01, 0x03], `${name} packet header`);
    assert.ok(Number(page.black) > 0, `${name} preview is blank`);
    const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    fs.writeFileSync(`${PROOF_DIR}/${name}.png`, Buffer.from(shot.data, 'base64'));
    socket.close();
    checks.push(`${name}: ${width}x${height}, packet 20 bytes, preview nonblank, no overflow`);
  } finally {
    chrome.kill();
  }
}

for (const viewport of [['desktop', 1365, 768], ['mobile', 360, 740]]) await capture(...viewport);
fs.writeFileSync(`${PROOF_DIR}/browser-check.txt`, [
  'TASK D13B browser proof PASS',
  'Canonical URL: https://onlysky17.github.io/Clock/test.html',
  'Fixture: RAN 27C, POP 40, 08:30 HOP, 18:00 GYM',
  ...checks
].join('\n'));

console.log('TASK D13B daily briefing profile smoke PASS');
