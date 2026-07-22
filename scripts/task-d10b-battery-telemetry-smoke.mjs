import { strict as assert } from 'node:assert';
import { execFileSync, spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock';
const SOURCE_PATH = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const PERIPHERAL_PATH = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c';
const GATT_PATH = 'firmware/active/HINK213_CLOCK_22_BASE/src/custom_profile/user_custs1_def.c';
const WEB_PATH = 'web/clock-app/hl24a-canvas-e5.html';
const SMOKE_PATH = 'scripts/task-d10b-battery-telemetry-smoke.mjs';
const TEST_PATH = 'test.html';
const PROOF_DIR = `${ROOT}/_incoming/D10B_BATTERY_TELEMETRY_PROOF`;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';

const source = readFileSync(`${ROOT}/${SOURCE_PATH}`, 'utf8');
const peripheral = readFileSync(`${ROOT}/${PERIPHERAL_PATH}`, 'utf8');
const gatt = readFileSync(`${ROOT}/${GATT_PATH}`, 'utf8');
const html = readFileSync(`${ROOT}/${WEB_PATH}`, 'utf8');
const testHtml = readFileSync(`${ROOT}/${TEST_PATH}`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';

const includes = (text, value, message) => assert.ok(text.includes(value), message);

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');

includes(source, 'adc_offset_calibrate(ADC_INPUT_MODE_SINGLE_ENDED);', 'ADC calibration missing');
includes(source, 'adc_get_vbat_sample(false)', 'DA14585 VBAT3V sample missing');
includes(source, 'return (adcval * 225) >> 7;', 'historical millivolt conversion missing');
assert.ok(!/int\s+adc1_update\s*\(void\)\s*\{\s*return\s+0\s*;\s*\}/s.test(source), 'ADC stub remains');

includes(gatt, 'svc1_adc_val1   = 0xff02', 'FF02 UUID missing');
includes(gatt, 'PERM(RI, ENABLE) | DEF_SVC1_ADC_VAL_1_CHAR_LEN', 'FF02 read indication missing');
includes(peripheral, 'case SVC1_IDX_ADC_VAL_1_VAL:', 'FF02 read routing missing');
includes(peripheral, 'int millivolts = adc1_update();', 'FF02 must sample on demand');
includes(peripheral, 'rsp->length = DEF_SVC1_ADC_VAL_1_CHAR_LEN;', 'FF02 response length changed');
includes(peripheral, 'rsp->value[0] = (uint8_t)(millivolts & 0xFF);', 'millivolt LE low byte missing');
includes(peripheral, 'rsp->value[1] = (uint8_t)((millivolts >> 8) & 0xFF);', 'millivolt LE high byte missing');

includes(html, '<title>TASK D10B - Battery Telemetry</title>', 'D10B title missing');
includes(html, "webBuild:'D10B-BATTERY-20260722'", 'D10B build marker missing');
includes(html, 'const BATTERY_SERVICE=0xFF00;', 'FF00 service missing');
includes(html, 'const BATTERY_CHARACTERISTIC=0xFF02;', 'FF02 characteristic missing');
includes(html, 'optionalServices:[SERVICE,BATTERY_SERVICE]', 'battery optional service missing');
includes(html, 'id="batteryVoltage"', 'visible battery voltage missing');
includes(html, 'id="batteryLevel"', 'visible estimated level missing');
includes(html, 'id="batteryRefresh"', 'battery refresh control missing');
includes(html, 'value.getUint16(0,true)', 'battery LE parse missing');
includes(html, 'function estimateBatteryPercent(millivolts)', 'CR2032 estimate missing');
includes(html, 'Phần trăm chỉ là ước tính', 'estimate disclaimer missing');
includes(html, "$('batteryVoltage').textContent='Không hỗ trợ';", 'unsupported state must be nonfatal');
includes(html, "expectedRuntime:'D8A1'", 'D8A identity baseline changed');
includes(html, "expectedSourceId:'D8A00001'", 'D8A source baseline changed');
includes(html, 'function resolveProductState(input)', 'D6B state mapping missing');
includes(html, 'bytes.length!==15||bytes[0]!==0xD2||bytes[1]!==0x81', 'D2 status contract changed');
includes(html, 'bytes.length!==16||bytes[0]!==0xD2||bytes[1]!==0x83', 'D2 identity contract changed');
includes(testHtml, './web/clock-app/hl24a-canvas-e5.html', 'canonical test.html target changed');
assert.ok(!/<details[^>]*id="advancedPanel"[^>]*open/.test(html), 'advanced panel must remain closed');

mkdirSync(PROOF_DIR, { recursive: true });
assert.ok(existsSync(CHROME), 'Chrome not found for browser proof');
const pageUrl = pathToFileURL(`${ROOT}/${WEB_PATH}`).href;
const checks = [];
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function captureViewport(name, width, height) {
  const port = 9700 + Math.floor(Math.random() * 200);
  const profile = `${PROOF_DIR}/chrome-${name}-${Date.now()}`;
  mkdirSync(profile, { recursive: true });
  const chrome = spawn(CHROME, [
    '--headless=new', '--in-process-gpu', '--disable-gpu-sandbox', '--no-sandbox',
    '--disable-gpu-watchdog', '--allow-file-access-from-files', '--hide-scrollbars',
    `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, 'about:blank',
  ], { stdio: 'ignore' });

  try {
    let targets;
    for (let attempt = 0; attempt < 50; attempt++) {
      try {
        targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
        if (targets.some((target) => target.type === 'page')) break;
      } catch {}
      await delay(100);
    }
    const target = targets?.find((item) => item.type === 'page');
    assert.ok(target?.webSocketDebuggerUrl, `${name} Chrome target missing`);

    const socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      socket.onopen = resolve;
      socket.onerror = reject;
    });
    let id = 0;
    const pending = new Map();
    socket.onmessage = (event) => {
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
      width, height, deviceScaleFactor: 1, mobile: width <= 420,
    });
    await send('Page.navigate', { url: pageUrl });
    await delay(1200);
    const evaluated = await send('Runtime.evaluate', {
      expression: `JSON.stringify({innerWidth,scrollWidth:document.documentElement.scrollWidth,build:document.querySelector('[data-eink-web-build]')?.dataset.einkWebBuild,battery:document.getElementById('batteryVoltage')?.textContent,button:document.getElementById('batteryRefresh')?.textContent,advanced:document.getElementById('advancedPanel')?.open})`,
      returnByValue: true,
    });
    const page = JSON.parse(evaluated.result.value);
    assert.equal(page.innerWidth, width, `${name} viewport width`);
    assert.ok(page.scrollWidth <= width, `${name} horizontal overflow: ${page.scrollWidth}/${width}`);
    assert.equal(page.build, 'D10B-BATTERY-20260722', `${name} build marker`);
    assert.equal(page.battery, 'Chưa đọc', `${name} battery placeholder`);
    assert.equal(page.button, 'Đọc pin', `${name} battery action`);
    assert.equal(page.advanced, false, `${name} advanced panel opened`);

    const screenshot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    const png = `${PROOF_DIR}/${name}.png`;
    writeFileSync(png, Buffer.from(screenshot.data, 'base64'));
    socket.close();
    checks.push(`${name}: ${width}x${height}, no overflow, battery card visible, screenshot=${png}`);
  } finally {
    chrome.kill();
  }
}

for (const [name, width, height] of [['desktop', 1365, 768], ['mobile', 360, 740]]) {
  await captureViewport(name, width, height);
}

writeFileSync(`${PROOF_DIR}/browser-check.txt`, [
  'TASK D10B battery telemetry browser proof PASS',
  'Canonical URL: https://onlysky17.github.io/Clock/test.html',
  'Battery values remain disconnected placeholders in host proof; no fake BLE data is injected.',
  ...checks,
].join('\n'));

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], { cwd: ROOT, encoding: 'utf8' })
  .split(/\r?\n/).filter(Boolean).map(line => line.slice(3).replaceAll('\\', '/'))
  .filter(file => !file.startsWith('_incoming/'));
const allowed = new Set([SOURCE_PATH, PERIPHERAL_PATH, GATT_PATH, WEB_PATH, SMOKE_PATH]);
assert.ok(dirty.every(file => allowed.has(file)), `out-of-scope dirty file: ${dirty.join(', ')}`);
assert.equal(dirty.length, allowed.size, `expected exactly five dirty files, got: ${dirty.join(', ')}`);
assert.ok(!dirty.includes(TEST_PATH), 'test.html must not be modified');

console.log('TASK D10B battery telemetry smoke PASS');
