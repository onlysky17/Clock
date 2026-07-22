import { strict as assert } from 'node:assert';
import { execFileSync, spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import vm from 'node:vm';

const ROOT = 'D:/EINK/Clock';
const WEB_PATH = 'web/clock-app/hl24a-canvas-e5.html';
const DOC_PATH = 'docs/web/TASK_D8B_DEVICE_COMPATIBILITY_GUARD.md';
const TEST_PATH = 'test.html';
const PROOF_DIR = `${ROOT}/_incoming/D8B_COMPATIBILITY_GUARD_PROOF`;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const html = readFileSync(`${ROOT}/${WEB_PATH}`, 'utf8');
const doc = readFileSync(`${ROOT}/${DOC_PATH}`, 'utf8');
const testHtml = readFileSync(`${ROOT}/${TEST_PATH}`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';

const includes = (text, value, message) => assert.ok(text.includes(value), message);
const matches = (text, pattern, message) => assert.ok(pattern.test(text), message);

assert.ok(script, 'web script block missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');
includes(html, '<title>TASK D8B - Device Compatibility Guard</title>', 'D8B document title missing');
includes(html, "expectedRuntime:'D8A1'", 'expected runtime firmware missing');
includes(html, "expectedSourceId:'D8A00001'", 'expected source ID missing');
includes(html, "webBuild:'D8B-COMPAT-20260722'", 'D8B web build missing');
includes(html, 'id="identityCompatibility"', 'visible compatibility state missing');
includes(html, 'id="identityCompatibilityDetail"', 'visible compatibility detail missing');
includes(html, 'identityCard.dataset.expectedRuntime=EINK_TEST_IDENTITY.expectedRuntime', 'runtime DOM marker missing');
includes(html, 'identityCard.dataset.expectedSourceId=EINK_TEST_IDENTITY.expectedSourceId', 'source DOM marker missing');
includes(html, "const identityBlocked=connected&&identityCompatibility!=='compatible';", 'compatibility action guard missing');
includes(html, "$\('syncClock'\).disabled=!connected||locked||identityBlocked;".replaceAll('\\',''), 'Product sync must be guarded');
includes(html, "$\('d2SetTime'\).disabled=!connected||locked||identityBlocked;".replaceAll('\\',''), 'D2 SET_TIME must be guarded');
includes(html, "$\('d2RenderClock'\).disabled=!connected||locked||d2StalePresent||identityBlocked;".replaceAll('\\',''), 'D2 render must be guarded');
includes(html, "$('d2GetIdentity').disabled=!connected||locked;", 'manual identity query must remain available');
includes(html, "renderDeviceCompatibility(null,false);", 'disconnect must reset compatibility');
includes(html, "renderDeviceCompatibility(null,true);", 'connect must enter checking state');
includes(html, 'compatibilityMismatch:identityCompatibility===', 'Product Mode mismatch mapping missing');

matches(html, /const SERVICE='18424398-7cbc-11e9-8f9e-2a86e4085a59'/, 'service UUID changed');
matches(html, /const WRITE='2d86686a-53dc-25b3-0c4a-f0e10c8dee20'/, 'write UUID changed');
matches(html, /const NOTIFY='15005991-b131-3396-014c-664c9867b917'/, 'notify UUID changed');
includes(html, 'Uint8Array.of(0xD2,0x03)', 'D2 identity command changed');
includes(html, 'bytes.length!==16||bytes[0]!==0xD2||bytes[1]!==0x83', 'D2 identity packet changed');
includes(html, 'function resolveProductState(input)', 'D6B state mapping missing');
includes(html, "advanced.className='advanced';", 'advanced section must remain');
assert.ok(!/<details[^>]*id="advancedPanel"[^>]*open/.test(html), 'advanced section must stay closed');
includes(testHtml, './web/clock-app/hl24a-canvas-e5.html', 'canonical redirect changed');
includes(doc, 'https://onlysky17.github.io/Clock/test.html', 'canonical URL missing from doc');

const resolverStart = html.indexOf('function resolveDeviceCompatibility');
const resolverEnd = html.indexOf('window.__resolveEinkDeviceCompatibility=resolveDeviceCompatibility;', resolverStart);
assert.ok(resolverStart >= 0 && resolverEnd > resolverStart, 'compatibility resolver block missing');
const context = {
  EINK_TEST_IDENTITY: {
    expectedRuntime: 'D8A1',
    expectedSourceId: 'D8A00001'
  }
};
vm.createContext(context);
vm.runInContext(`${html.slice(resolverStart, resolverEnd)}\nglobalThis.resolveDeviceCompatibility=resolveDeviceCompatibility;`, context);

const fixtures = [
  { name: 'disconnected', connected: false, identity: null, state: 'disconnected', text: 'Chưa kết nối' },
  { name: 'checking', connected: true, identity: null, state: 'checking', text: 'Đang kiểm tra' },
  { name: 'compatible', connected: true, identity: { result: 0, firmware: 'D8A1', sourceId: 0xD8A00001 }, state: 'compatible', text: 'Tương thích' },
  { name: 'wrong runtime', connected: true, identity: { result: 0, firmware: 'D7B1', sourceId: 0xD8A00001 }, state: 'mismatch', text: 'Sai firmware' },
  { name: 'wrong source', connected: true, identity: { result: 0, firmware: 'D8A1', sourceId: 0xD8A00002 }, state: 'mismatch', text: 'Sai firmware' },
  { name: 'unsupported', connected: true, identity: { result: 1, firmware: '----', sourceId: 0 }, state: 'unsupported', text: 'Không hỗ trợ' }
];

for (const fixture of fixtures) {
  const actual = context.resolveDeviceCompatibility(fixture.identity, fixture.connected);
  assert.equal(actual.state, fixture.state, `${fixture.name} state`);
  assert.equal(actual.text, fixture.text, `${fixture.name} label`);
}

mkdirSync(PROOF_DIR, { recursive: true });
assert.ok(existsSync(CHROME), 'Chrome not found for browser proof');
const testUrl = pathToFileURL(`${ROOT}/${TEST_PATH}`).href;
const checks = [];

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function captureViewport(name, width, height) {
  const port = 9300 + Math.floor(Math.random() * 400);
  const profile = `${PROOF_DIR}/chrome-${name}-${Date.now()}`;
  mkdirSync(profile, { recursive: true });
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
    assert.ok(target?.webSocketDebuggerUrl, `${name} Chrome DevTools target missing`);

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
    await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: width <= 420 });
    await send('Page.navigate', { url: testUrl });
    await delay(1500);
    const state = await send('Runtime.evaluate', {
      expression: `JSON.stringify({innerWidth,scrollWidth:document.documentElement.scrollWidth,build:document.querySelector('[data-eink-web-build]')?.dataset.einkWebBuild,runtime:document.querySelector('[data-expected-runtime]')?.dataset.expectedRuntime,source:document.querySelector('[data-expected-source-id]')?.dataset.expectedSourceId,advanced:document.getElementById('advancedPanel')?.open,compatibility:document.getElementById('identityCompatibility')?.textContent})`,
      returnByValue: true
    });
    const page = JSON.parse(state.result.value);
    assert.equal(page.innerWidth, width, `${name} viewport width`);
    assert.ok(page.scrollWidth <= width, `${name} horizontal overflow: ${page.scrollWidth}/${width}`);
    assert.equal(page.build, 'D8B-COMPAT-20260722', `${name} build marker`);
    assert.equal(page.runtime, 'D8A1', `${name} runtime marker`);
    assert.equal(page.source, 'D8A00001', `${name} source marker`);
    assert.equal(page.advanced, false, `${name} advanced panel opened`);
    assert.equal(page.compatibility, 'Chưa kết nối', `${name} initial compatibility`);

    const screenshot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    const png = `${PROOF_DIR}/${name}.png`;
    writeFileSync(png, Buffer.from(screenshot.data, 'base64'));
    socket.close();
    checks.push(`${name}: ${width}x${height}, no overflow, advanced closed, screenshot=${png}`);
  } finally {
    chrome.kill();
  }
}

for (const [name, width, height] of [['desktop', 1365, 768], ['mobile', 360, 740]]) {
  await captureViewport(name, width, height);
}

writeFileSync(`${PROOF_DIR}/browser-check.txt`, [
  'TASK D8B compatibility guard browser proof PASS',
  `Local canonical entry: ${testUrl}`,
  'Public canonical URL: https://onlysky17.github.io/Clock/test.html',
  ...fixtures.map(fixture => `${fixture.name}: ${fixture.state}`),
  ...checks
].join('\n'));

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], { cwd: ROOT, encoding: 'utf8' })
  .split(/\r?\n/).filter(Boolean).map(line => line.slice(3).replaceAll('\\', '/'))
  .filter(file => !file.startsWith('_incoming/'));
const allowed = new Set([WEB_PATH, DOC_PATH, 'scripts/task-d8b-device-compatibility-guard-smoke.mjs']);
assert.ok(dirty.every(file => allowed.has(file)), `out-of-scope dirty file: ${dirty.join(', ')}`);
assert.ok(!dirty.includes(TEST_PATH), 'test.html must not be modified');
assert.ok(!dirty.some(file => file.startsWith('firmware/')), 'firmware must not be modified');

console.log('TASK D8B device compatibility guard smoke PASS');
