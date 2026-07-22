import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync, spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock';
const PROOF_DIR = `${ROOT}/_incoming/D11B_CLOCK_PROFILE_PROOF`;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const firmwarePath = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const webPath = 'web/clock-app/hl24a-canvas-e5.html';
const firmware = fs.readFileSync(firmwarePath, 'utf8');
const web = fs.readFileSync(webPath, 'utf8');
const script = web.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';

const has = (text, pattern, message) => assert.match(text, pattern, message);

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');

has(firmware, /HINK_D2_SET_PROFILE_LEN\s+3U/, 'SET_CLOCK_PROFILE must be 3 bytes');
has(firmware, /HINK_D2_GET_PROFILE_LEN\s+2U/, 'GET_CLOCK_PROFILE must be 2 bytes');
has(firmware, /HINK_D2_PROFILE_STATUS_LEN\s+6U/, 'D2 84 status must be 6 bytes');
has(firmware, /subcmd == 0x04U.*subcmd == 0x05U/s, 'D2 04/05 routing must exist');
has(firmware, /msg\[1\] = 0x84/, 'profile status must notify D2 84');
has(firmware, /HINK_D2_RESULT_INVALID_PROFILE\s+0x07U/, 'profile 2 must be rejected');
has(firmware, /profile > HINK_CLOCK_PROFILE_LARGE_TIME/, 'only profiles 0 and 1 may be accepted');
has(firmware, /hink_d2_synced_epoch == 0UL[\s\S]*HINK_D2_RESULT_NOT_INIT/, 'SET profile must require initialized time');
has(firmware, /!HINK_AUTO_IDLE\(\)[\s\S]*HINK_D2_RESULT_BUSY/, 'SET profile must keep render busy guard');

has(firmware, /rec\[16\] = hink_clock_profile/, 'profile must use CRC-covered record byte 16');
has(firmware, /a\[16\] <= HINK_CLOCK_PROFILE_LARGE_TIME/, 'slot A must restore a supported profile');
has(firmware, /b\[16\] <= HINK_CLOCK_PROFILE_LARGE_TIME/, 'slot B must restore a supported profile');
has(firmware, /hink_clock_profile_persisted = HINK_CLOCK_PROFILE_NONE/, 'old FF record must default to profile 0');
has(firmware, /hink_d3d_store_last_known_time\(hink_d2_current_epoch\(\)/, 'explicit profile SET must persist through the existing journal');

has(firmware, /if \(hink_clock_profile == HINK_CLOCK_PROFILE_LARGE_TIME\)[\s\S]*hink_d11b_draw_large_time[\s\S]*else[\s\S]*hink_bitmap_draw_clock/, 'one framebuffer dispatcher must preserve profile 0');
has(firmware, /widths\[i\] = \(digits\[i\] == 1U\) \? 10U : 30U[\s\S]*x = \(uint8_t\)\(\(250U - total\) \/ 2U\)/, 'large-time face must optically center narrow digit one');
has(firmware, /draw_text\(86, 5, date_buf, BLACK\)[\s\S]*hink_d9a_draw_lunar\(101, 102/, 'large-time date and lunar rows must share the centered layout');
has(firmware, /lunar_buf\[0\] = 'A'[\s\S]*draw_text\(x, y, lunar_buf, BLACK\)/, 'lunar row must use the regular compact font');
has(firmware, /hink_d9a_draw_lunar\(26, 91/, 'monthly lunar row must be centered in the left pane');
assert.equal((firmware.match(/static\s+uint8_t\s+fb_bw/g) || []).length, 0, 'D11B must not add a second framebuffer');
assert.doesNotMatch(firmware, /malloc\s*\(/, 'D11B must not allocate dynamically');

has(web, /Uint8Array\.of\(0xD2,0x04,profile\)/, 'web SET profile packet must be exact');
has(web, /Uint8Array\.of\(0xD2,0x05\)/, 'web GET profile packet must be exact');
has(web, /bytes\.length!==6\|\|bytes\[0\]!==0xD2\|\|bytes\[1\]!==0x84/, 'web must parse exact D2 84 status');
has(web, /await d2RenderClockFromDevice\(\)/, 'Apply must reuse existing D2 render flow');
has(web, /profileApply.*runD2Flow\(d2ApplyClockProfile\)/s, 'profile Apply must use guarded D2 flow');
has(web, /renderInProgress=productD2RenderState===0x01\|\|productD2RenderState===0x02/, 'profile Apply must lock during render');
has(web, /status\.result===0x06[\s\S]*waitFor\([\s\S]*a\[3\]===0x03[\s\S]*buildD2SetProfilePacket\(selectedClockProfile\)/, 'BUSY profile Apply must wait for COMPLETE and retry once');
has(web, /D11B-PROFILES-20260722/, 'visible web build marker must identify D11B');
has(web, /advanced\.id='advancedPanel'/, 'Advanced section must remain available');
has(web, /identityCompatibility!==['"]compatible['"]/, 'device compatibility guard must remain');

const changed = execFileSync('git', ['diff', '--name-only'], { encoding: 'utf8' })
  .trim().split(/\r?\n/).filter(Boolean);
const allowed = new Set([
  firmwarePath,
  webPath,
  'scripts/task-d11b-large-time-profile-smoke.mjs',
  'docs/firmware/TASK_D11B_LARGE_TIME_CLOCK_PROFILE.md'
]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.includes('test.html'), 'canonical test.html must remain unchanged');

fs.mkdirSync(PROOF_DIR, { recursive: true });
assert.ok(fs.existsSync(CHROME), 'Chrome not found for browser proof');
const pageUrl = pathToFileURL(`${ROOT}/${webPath}`).href;
const browserChecks = [];
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function capture(name, width, height) {
  const port = 9900 + Math.floor(Math.random() * 80);
  const profile = `${PROOF_DIR}/chrome-${name}-${Date.now()}`;
  fs.mkdirSync(profile, { recursive: true });
  const chrome = spawn(CHROME, [
    '--headless=new', '--in-process-gpu', '--disable-gpu-sandbox', '--no-sandbox',
    '--disable-gpu-watchdog', '--allow-file-access-from-files', '--hide-scrollbars',
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
    await new Promise((resolve, reject) => {
      socket.onopen = resolve;
      socket.onerror = reject;
    });
    let id = 0;
    const pending = new Map();
    socket.onmessage = event => {
      const message = JSON.parse(event.data);
      if (!message.id || !pending.has(message.id)) return;
      const item = pending.get(message.id);
      pending.delete(message.id);
      if (message.error) item.reject(new Error(message.error.message));
      else item.resolve(message.result);
    };
    const send = (method, params = {}) => new Promise((resolve, reject) => {
      const requestId = ++id;
      pending.set(requestId, { resolve, reject });
      socket.send(JSON.stringify({ id: requestId, method, params }));
    });

    await send('Page.enable');
    await send('Runtime.enable');
    await send('Emulation.setDeviceMetricsOverride', {
      width, height, deviceScaleFactor: 1, mobile: width <= 420
    });
    await send('Page.navigate', { url: pageUrl });
    await delay(900);
    const evaluated = await send('Runtime.evaluate', {
      expression: `JSON.stringify({innerWidth,scrollWidth:document.documentElement.scrollWidth,build:document.querySelector('[data-eink-web-build]')?.dataset.einkWebBuild,monthly:document.getElementById('dailyCalendar')?.textContent,large:document.getElementById('updateClock')?.textContent,apply:document.getElementById('profileApply')?.textContent,status:document.getElementById('profileStatus')?.textContent,advanced:document.getElementById('advancedPanel')?.open})`,
      returnByValue: true
    });
    const page = JSON.parse(evaluated.result.value);
    assert.equal(page.innerWidth, width, `${name} viewport width`);
    assert.ok(page.scrollWidth <= width, `${name} horizontal overflow: ${page.scrollWidth}/${width}`);
    assert.equal(page.build, 'D11B-PROFILES-20260722', `${name} web build marker`);
    assert.ok(page.monthly && page.large && page.apply, `${name} profile controls missing`);
    assert.match(page.status, /Lịch tháng|L\u1ecbch th\u00e1ng|Clock profile/, `${name} profile status missing`);
    assert.equal(page.advanced, false, `${name} advanced panel opened`);
    const screenshot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    const output = `${PROOF_DIR}/${name}.png`;
    fs.writeFileSync(output, Buffer.from(screenshot.data, 'base64'));
    socket.close();
    browserChecks.push(`${name}: ${width}x${height}, no overflow, profile controls visible`);
  } finally {
    chrome.kill();
  }
}

for (const [name, width, height] of [['desktop', 1365, 768], ['mobile', 360, 740]]) {
  await capture(name, width, height);
}

fs.writeFileSync(`${PROOF_DIR}/browser-check.txt`, [
  'TASK D11B clock profile browser proof PASS',
  'Canonical URL: https://onlysky17.github.io/Clock/test.html',
  'No fake BLE or profile status was injected.',
  ...browserChecks
].join('\n'));

console.log('TASK D11B large-time clock profile smoke PASS');
