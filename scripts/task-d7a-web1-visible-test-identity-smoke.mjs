import { strict as assert } from 'node:assert';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const WEB_PATH = 'web/clock-app/hl24a-canvas-e5.html';
const DOC_PATH = 'docs/web/TASK_D6B_WEB_PRODUCT_MODE.md';
const TEST_PATH = 'test.html';
const PROOF_DIR = 'D:/EINK/Clock/_incoming/D7A_WEB1_IDENTITY_PROOF';
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const html = readFileSync(WEB_PATH, 'utf8');
const doc = readFileSync(DOC_PATH, 'utf8');
const testHtml = readFileSync(TEST_PATH, 'utf8');

function mustContain(label, haystack, needle) {
  assert.ok(haystack.includes(needle), `${label} missing: ${needle}`);
}

function mustMatch(label, haystack, pattern) {
  assert.ok(pattern.test(haystack), `${label} missing`);
}

mustContain('visible label', html, 'D7A TEST BASELINE');
mustContain('expected firmware', html, '32fa562d');
mustContain('expected bin', html, '14CF053B');
mustContain('web build', html, 'D7A-WEB1-20260720');
mustContain('disclaimer', html, 'Thông tin trên là baseline dự kiến, không phải xác minh firmware trong thiết bị.');
mustContain('data web build marker', html, "identityCard.dataset.einkWebBuild=EINK_TEST_IDENTITY.webBuild");
mustContain('data firmware marker', html, "identityCard.dataset.expectedFirmware=EINK_TEST_IDENTITY.expectedFirmware");
mustContain('data bin marker', html, "identityCard.dataset.expectedBin=EINK_TEST_IDENTITY.expectedBin");
mustContain('window identity marker', html, 'window.EINK_TEST_IDENTITY=EINK_TEST_IDENTITY');

mustContain('doc identity', doc, 'TASK D7A-WEB1 - Visible Test Identity');
mustContain('doc canonical URL', doc, 'https://onlysky17.github.io/Clock/test.html');
mustContain('doc expected firmware', doc, 'D7A final / 32fa562d');
mustContain('doc expected bin', doc, '14CF053B');

mustContain('canonical redirect target', testHtml, './web/clock-app/hl24a-canvas-e5.html');
assert.ok(!/D7A-WEB1/.test(testHtml), 'test.html must not be modified for D7A-WEB1 identity');

mustMatch('service UUID unchanged', html, /const SERVICE='18424398-7cbc-11e9-8f9e-2a86e4085a59'/);
mustMatch('write UUID unchanged', html, /const WRITE='2d86686a-53dc-25b3-0c4a-f0e10c8dee20'/);
mustMatch('notify UUID unchanged', html, /const NOTIFY='15005991-b131-3396-014c-664c9867b917'/);
mustMatch('D2 SET packet unchanged', html, /packet\[0\]=0xD2;\s*packet\[1\]=0x00;/);
mustMatch('D2 GET packet unchanged', html, /return Uint8Array\.of\(0xD2,0x01\);/);
mustMatch('D2 render packet unchanged', html, /return Uint8Array\.of\(0xD2,0x02\);/);
mustMatch('E5 start packet unchanged', html, /function startPacket\(id\)\{[\s\S]*0xE5,0x00,id[\s\S]*TOTAL&0xFF,TOTAL>>8/);
mustMatch('E6 request unchanged', html, /Uint8Array\.of\(0xE6, 0x00, transferId\)/);

mustMatch('D6B-FIX1 resolver exists', html, /function resolveProductState\(input\)\{/);
mustMatch('Product Mode uses resolver', html, /const state=resolveProductState\(\{/);
mustMatch('Product Mode error mapping remains explicit', html, /hasError:!!productErrorReason/);
mustMatch('D2 success clears sticky error', html, /if\(status\.result===0x00\)\{\s*clearProductError\(\);/);
mustMatch('advanced section closed by default', html, /const advanced=document\.createElement\('details'\);[\s\S]*advanced\.id='advancedPanel';/);
assert.ok(!/<details[^>]*id="advancedPanel"[^>]*open/.test(html), 'advanced panel must be closed by default');

const identityPosition = html.indexOf('main.append(header,identityCard,statusCard');
assert.ok(identityPosition >= 0, 'identity card must be directly after Product Mode header');

mkdirSync(PROOF_DIR, { recursive: true });
assert.ok(existsSync(CHROME), 'Chrome not found for browser proof');

const testUrl = pathToFileURL(`${process.cwd()}/${TEST_PATH}`).href;
const checks = [];

for (const [name, size] of [['desktop', '1365,768'], ['mobile', '360,740']]) {
  const png = `${PROOF_DIR}/${name}.png`;
  const run = spawnSync(CHROME, [
    '--headless=new',
    '--in-process-gpu',
    '--disable-gpu-sandbox',
    '--no-sandbox',
    '--disable-gpu-watchdog',
    '--allow-file-access-from-files',
    '--hide-scrollbars',
    `--window-size=${size}`,
    '--virtual-time-budget=1500',
    `--screenshot=${png}`,
    '--dump-dom',
    testUrl
  ], { encoding: 'utf8' });

  assert.equal(run.status, 0, `${name} Chrome run failed: ${run.stderr}`);
  assert.ok(existsSync(png), `${name} screenshot missing`);
  const dom = run.stdout;
  mustContain(`${name} DOM identity`, dom, 'D7A TEST BASELINE');
  mustContain(`${name} DOM firmware`, dom, 'D7A final / 32fa562d');
  mustContain(`${name} DOM bin`, dom, '14CF053B');
  mustContain(`${name} DOM build`, dom, 'D7A-WEB1-20260720');
  mustContain(`${name} DOM disclaimer`, dom, 'baseline dự kiến');
  mustContain(`${name} data web build`, dom, 'data-eink-web-build="D7A-WEB1-20260720"');
  mustContain(`${name} data firmware`, dom, 'data-expected-firmware="32fa562d"');
  mustContain(`${name} data bin`, dom, 'data-expected-bin="14CF053B"');
  mustContain(`${name} no horizontal overflow`, dom, 'data-eink-no-overflow="true"');
  assert.ok(dom.indexOf('D7A TEST BASELINE') < dom.indexOf('Trạng thái'), `${name} marker must be before status card`);
  assert.ok(dom.indexOf('Kết nối') < dom.indexOf('Trạng thái'), `${name} connect button must stay in top Product Mode header`);
  assert.ok(dom.includes('advancedPanel') && !/<details[^>]*id="advancedPanel"[^>]*open/.test(dom), `${name} advanced section must stay closed`);
  checks.push(`${name}: marker visible, no horizontal overflow, advanced closed, screenshot=${png}`);
}

writeFileSync(`${PROOF_DIR}/browser-check.txt`, [
  'TASK D7A-WEB1 browser proof PASS',
  `URL entry: ${testUrl}`,
  'Canonical public URL remains: https://onlysky17.github.io/Clock/test.html',
  ...checks
].join('\n'));

const changed = execFileSync('git', ['status', '--short', '--untracked-files=all'], { encoding: 'utf8' })
  .split(/\r?\n/)
  .filter(Boolean)
  .map(line => line.slice(3).replace(/\\/g, '/'))
  .filter(file => !file.startsWith('_incoming/'));
const allowed = new Set([
  WEB_PATH,
  DOC_PATH,
  'scripts/task-d7a-web1-visible-test-identity-smoke.mjs'
]);
for (const file of changed) {
  assert.ok(allowed.has(file), `unexpected dirty file: ${file}`);
}
assert.ok(!changed.includes(TEST_PATH), 'test.html must not be modified');
assert.ok(!changed.some(file => file.startsWith('firmware/')), 'firmware must not be modified');

console.log('TASK D7A-WEB1 visible test identity smoke PASS');
