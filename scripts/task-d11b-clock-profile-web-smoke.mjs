import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync, spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock/_incoming/D11B_WEB_PUBLISH_WORKTREE';
const WEB = 'web/clock-app/hl24a-canvas-e5.html';
const SMOKE = 'scripts/task-d11b-clock-profile-web-smoke.mjs';
const PROOF = 'D:/EINK/Clock/_incoming/D11B_WEB_PROFILE_PROOF';
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const html = fs.readFileSync(`${ROOT}/${WEB}`, 'utf8');
const testHtml = fs.readFileSync(`${ROOT}/test.html`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';
const includes = (value, message) => assert.ok(html.includes(value), message);

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');
includes('<title>TASK D11B - Clock Face Profiles</title>', 'D11B title missing');
includes("webBuild:'D11B-PROFILES-20260722'", 'D11B build marker missing');
includes('Uint8Array.of(0xD2,0x04,profile)', 'D2 04 SET profile packet missing');
includes('Uint8Array.of(0xD2,0x05)', 'D2 05 GET profile packet missing');
includes('bytes.length!==6||bytes[0]!==0xD2||bytes[1]!==0x84', 'D2 84 parser missing');
includes('await d2RenderClockFromDevice()', 'Apply must wait for existing D2 render flow');
includes("$('profileApply').onclick=()=>runD2Flow(d2ApplyClockProfile)", 'guarded Apply action missing');
includes('renderInProgress=productD2RenderState===0x01||productD2RenderState===0x02', 'render busy lock missing');
assert.match(html, /status\.result===0x06[\s\S]*waitFor\([\s\S]*a\[3\]===0x03[\s\S]*buildD2SetProfilePacket\(selectedClockProfile\)/, 'BUSY must wait for COMPLETE and retry');
includes("advanced.id='advancedPanel'", 'Advanced section missing');
includes("identityCompatibility!=='compatible'", 'device compatibility guard missing');
assert.ok(testHtml.includes('./web/clock-app/hl24a-canvas-e5.html'), 'canonical test.html target changed');
assert.ok(!/<details[^>]*id="advancedPanel"[^>]*open/.test(html), 'Advanced must remain closed');

fs.mkdirSync(PROOF, { recursive: true });
const pageUrl = pathToFileURL(`${ROOT}/${WEB}`).href;
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const checks = [];

async function capture(name, width, height) {
  const port = 9980 + Math.floor(Math.random() * 15);
  const profile = `${PROOF}/chrome-${name}-${Date.now()}`;
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
      if (message.error) item.reject(new Error(message.error.message)); else item.resolve(message.result);
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
    await delay(900);
    const evaluated = await send('Runtime.evaluate', {
      expression: `JSON.stringify({innerWidth,scrollWidth:document.documentElement.scrollWidth,build:document.querySelector('[data-eink-web-build]')?.dataset.einkWebBuild,monthly:document.getElementById('dailyCalendar')?.textContent,large:document.getElementById('updateClock')?.textContent,apply:document.getElementById('profileApply')?.textContent,advanced:document.getElementById('advancedPanel')?.open})`,
      returnByValue: true
    });
    const page = JSON.parse(evaluated.result.value);
    assert.equal(page.build, 'D11B-PROFILES-20260722', `${name} build marker`);
    assert.ok(page.monthly && page.large && page.apply, `${name} controls missing`);
    assert.ok(page.scrollWidth <= width, `${name} horizontal overflow`);
    assert.equal(page.advanced, false, `${name} Advanced opened`);
    const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    fs.writeFileSync(`${PROOF}/${name}.png`, Buffer.from(shot.data, 'base64'));
    socket.close();
    checks.push(`${name}: ${width}x${height} PASS`);
  } finally {
    chrome.kill();
  }
}

for (const viewport of [['desktop', 1365, 768], ['mobile', 360, 740]]) await capture(...viewport);
fs.writeFileSync(`${PROOF}/browser-check.txt`, [
  'TASK D11B web profile controls PASS',
  'Canonical URL: https://onlysky17.github.io/Clock/test.html',
  ...checks
].join('\n'));

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], { cwd: ROOT, encoding: 'utf8' })
  .split(/\r?\n/).filter(Boolean).map(line => line.slice(3).replaceAll('\\', '/'));
assert.deepEqual(dirty.sort(), [WEB, SMOKE].sort(), `unexpected dirty scope: ${dirty.join(', ')}`);
console.log('TASK D11B clock profile web smoke PASS');
