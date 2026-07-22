import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync, spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock';
const PROOF_DIR = `${ROOT}/_incoming/D12B_CLOCK_PREFERENCES_PROOF`;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const firmwarePath = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const webPath = 'web/clock-app/hl24a-canvas-e5.html';
const docPath = 'docs/firmware/TASK_D12B_CLOCK_PREFERENCES.md';
const smokePath = 'scripts/task-d12b-clock-preferences-smoke.mjs';
const firmware = fs.readFileSync(firmwarePath, 'utf8');
const web = fs.readFileSync(webPath, 'utf8');
const script = web.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';
const has = (text, pattern, message) => assert.match(text, pattern, message);

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');

has(firmware, /HINK_D2_SET_PREF_LEN\s+4U/, 'SET preferences must be 4 bytes');
has(firmware, /HINK_D2_GET_PREF_LEN\s+2U/, 'GET preferences must be 2 bytes');
has(firmware, /HINK_D2_PREF_STATUS_LEN\s+8U/, 'D2 86 status must be 8 bytes');
has(firmware, /HINK_D2_RESULT_INVALID_PREF\s+0x08U/, 'invalid preference result missing');
has(firmware, /subcmd == 0x06U.*subcmd == 0x07U/s, 'D2 06/07 routing missing');
has(firmware, /msg\[1\] = 0x86/, 'D2 preference status opcode missing');
has(firmware, /hour_mode > HINK_HOUR_MODE_12/, 'hour-mode validation missing');
has(firmware, /value == 1U.*value == 5U.*value == 10U/s, 'cadence validation missing');
has(firmware, /!HINK_AUTO_IDLE\(\)[\s\S]*HINK_D2_RESULT_BUSY/, 'busy guard missing');
has(firmware, /previous_hour[\s\S]*previous_refresh[\s\S]*HINK_D2_RESULT_INTERNAL/s, 'failed persistence must restore active preferences');

has(firmware, /rec\[17\] = hink_hour_mode/, 'hour mode must use journal byte 17');
has(firmware, /rec\[18\] = hink_refresh_minutes/, 'cadence must use journal byte 18');
has(firmware, /hink_hour_mode = HINK_HOUR_MODE_24/, 'old records must default to 24-hour');
has(firmware, /hink_refresh_minutes = HINK_REFRESH_DEFAULT_MINUTES/, 'old records must default to five minutes');
has(firmware, /a\[17\] <= HINK_HOUR_MODE_12[\s\S]*hink_refresh_value_valid\(a\[18\]\)/, 'slot A preferences must restore independently');
has(firmware, /b\[17\] <= HINK_HOUR_MODE_12[\s\S]*hink_refresh_value_valid\(b\[18\]\)/, 'slot B preferences must restore independently');

has(firmware, /auto_minute % \(uint32_t\)hink_refresh_minutes/, 'scheduler must use selected cadence');
has(firmware, /auto_minute \/ 1440UL.*hink_auto_last_rendered_minute \/ 1440UL/s, 'day rollover force render missing');
has(firmware, /draw_hour = \(uint8_t\)\(h % 12U\)[\s\S]*draw_hour = 12U/, '12-hour midnight/noon conversion missing');
has(firmware, /ampm = \(h >= 12U\) \? 2U : 1U/, 'AM/PM selection missing');
has(firmware, /hink_d11b_draw_large_time\(draw_hour[\s\S]*hink_bitmap_draw_clock\(draw_hour/s, 'both profiles must receive converted hour');
assert.equal((firmware.match(/static\s+uint8_t\s+fb_bw/g) || []).length, 0, 'no second framebuffer allowed');
assert.doesNotMatch(firmware, /malloc\s*\(/, 'dynamic allocation is forbidden');

has(web, /Uint8Array\.of\(0xD2,0x06,hourMode,refreshMinutes\)/, 'web SET preference bytes wrong');
has(web, /Uint8Array\.of\(0xD2,0x07\)/, 'web GET preference bytes wrong');
has(web, /bytes\.length!==8\|\|bytes\[0\]!==0xD2\|\|bytes\[1\]!==0x86/, 'web D2 86 parser must be exact');
has(web, /D12B-PREFERENCES-20260722/, 'D12B web build marker missing');
has(web, /24 gi\\u1edd.*12 gi\\u1edd/, '24/12-hour controls missing');
has(web, /5 ph\\u00fat.*10 ph\\u00fat.*1 ph\\u00fat/, '1/5/10-minute controls missing');
has(web, /status\.result===0x06[\s\S]*waitFor\([\s\S]*buildD2SetPreferencePacket/s, 'preference BUSY retry missing');
has(web, /await d2RenderClockFromDevice\(\)/, 'preference Apply must request existing D2 render');
has(web, /await d2GetClockPreferences\(\)/, 'connect must read restored preferences');
has(web, /advanced\.id='advancedPanel'/, 'Advanced must stay closed by default');

const changed = execFileSync('git', ['diff', '--name-only'], { encoding: 'utf8' })
  .trim().split(/\r?\n/).filter(Boolean);
const allowed = new Set([firmwarePath, webPath, smokePath, docPath]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.includes('test.html'), 'canonical test.html must remain unchanged');

fs.mkdirSync(PROOF_DIR, { recursive: true });
assert.ok(fs.existsSync(CHROME), 'Chrome not found for browser proof');
const pageUrl = pathToFileURL(`${ROOT}/${webPath}`).href;
const checks = [];
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function capture(name, width, height) {
  const port = 9970 + Math.floor(Math.random() * 20);
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
    assert.ok(target?.webSocketDebuggerUrl, `${name} Chrome target missing`);
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
    await delay(800);
    const evaluated = await send('Runtime.evaluate', {
      expression: `JSON.stringify({width:innerWidth,scroll:document.documentElement.scrollWidth,build:document.querySelector('[data-eink-web-build]')?.dataset.einkWebBuild,h24:hour24?.textContent,h12:hour12?.textContent,c1:cadence1?.textContent,c5:cadence5?.textContent,c10:cadence10?.textContent,advanced:advancedPanel?.open})`,
      returnByValue: true
    });
    const page = JSON.parse(evaluated.result.value);
    assert.ok(page.scroll <= page.width, `${name} horizontal overflow`);
    assert.equal(page.build, 'D12B-PREFERENCES-20260722', `${name} build marker`);
    assert.ok(page.h24 && page.h12 && page.c1 && page.c5 && page.c10, `${name} controls missing`);
    assert.equal(page.advanced, false, `${name} Advanced opened`);
    const screenshot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    fs.writeFileSync(`${PROOF_DIR}/${name}.png`, Buffer.from(screenshot.data, 'base64'));
    socket.close();
    checks.push(`${name}: ${width}x${height}, controls visible, no overflow`);
  } finally {
    chrome.kill();
  }
}

for (const viewport of [['desktop', 1365, 768], ['mobile', 360, 740]]) {
  await capture(...viewport);
}
fs.writeFileSync(`${PROOF_DIR}/browser-check.txt`, [
  'TASK D12B browser proof PASS',
  'Canonical URL: https://onlysky17.github.io/Clock/test.html',
  ...checks
].join('\n'));

console.log('TASK D12B clock preferences smoke PASS');
