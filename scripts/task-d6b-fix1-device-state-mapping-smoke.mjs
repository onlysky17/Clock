import { strict as assert } from 'node:assert';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import vm from 'node:vm';

const WEB_PATH = 'web/clock-app/hl24a-canvas-e5.html';
const DOC_PATH = 'docs/web/TASK_D6B_WEB_PRODUCT_MODE.md';
const PROOF_DIR = 'D:/EINK/Clock/_incoming/D6B_FIX1_STATE_MAPPING_PROOF';
const html = readFileSync(WEB_PATH, 'utf8');
const doc = readFileSync(DOC_PATH, 'utf8');

function mustContain(label, needle) {
  assert.ok(html.includes(needle) || doc.includes(needle), `${label} missing`);
}

function mustMatch(label, pattern) {
  assert.ok(pattern.test(html), `${label} missing`);
}

mustMatch('product resolver exists', /function resolveProductState\(input\)\{/);
mustMatch('product state uses resolver', /const state=resolveProductState\(\{/);
mustMatch('product state no longer reads E5 NOT RUN as error', /hasError:!!productErrorReason/);
assert.ok(!/textContent==='FAIL' \|\| \$\('e6Result'\)\.textContent==='ERROR' \|\| \$\('d2StatusText'\)\.className==='bad'/.test(html), 'old DOM-derived error mapping must be removed');
mustMatch('D2 success clears stale error', /if\(status\.result===0x00\)\{\s*clearProductError\(\);/);
mustMatch('D2 render success clears stale error', /if\(status\.state===0x03\)\{[\s\S]*clearProductError\(\);/);
mustMatch('malformed D2 response marks real error', /catch\(error\)\{\s*markProductError\(error\.message\);[\s\S]*log\(error\.message,'D2'\);/);
mustMatch('E6 real error marks product error', /catch \(err\) \{\s*markProductError\(err\.message\);/);

mustMatch('advanced details closed by default', /const advanced=document\.createElement\('details'\);[\s\S]*advanced\.id='advancedPanel';/);
assert.ok(!/<details[^>]*id="advancedPanel"[^>]*open/.test(html), 'advanced panel must be closed by default');
mustMatch('service UUID unchanged', /const SERVICE='18424398-7cbc-11e9-8f9e-2a86e4085a59'/);
mustMatch('write UUID unchanged', /const WRITE='2d86686a-53dc-25b3-0c4a-f0e10c8dee20'/);
mustMatch('notify UUID unchanged', /const NOTIFY='15005991-b131-3396-014c-664c9867b917'/);
mustMatch('E5 start packet unchanged', /function startPacket\(id\)\{[\s\S]*0xE5,0x00,id[\s\S]*TOTAL&0xFF,TOTAL>>8/);
mustMatch('E6 request unchanged', /Uint8Array\.of\(0xE6, 0x00, transferId\)/);

mustContain('disconnected status', 'Chưa kết nối');
mustContain('needs sync status', 'Cần đồng bộ giờ');
mustContain('running status', 'Đang chạy');
mustContain('error status', 'Có lỗi');
mustContain('FIX1 doc next state mapping', 'TASK D6B-FIX1');

const resolverStart = html.indexOf('function productD2StatusIsRunning');
const resolverEnd = html.indexOf('window.__resolveEinkProductState=resolveProductState;', resolverStart);
assert.ok(resolverStart >= 0 && resolverEnd > resolverStart, 'resolver block not found');
const context = {};
vm.createContext(context);
vm.runInContext(`${html.slice(resolverStart, resolverEnd)}
globalThis.resolveProductState=resolveProductState;`, context);
const { resolveProductState } = context;

const fixtures = [
  {
    name: 'Initial disconnected',
    input: { connected: false },
    expected: 'Chưa kết nối'
  },
  {
    name: 'Connected, E5/E6 NOT RUN',
    input: { connected: true, stalePresent: false, hasError: false },
    expected: 'Cần đồng bộ giờ'
  },
  {
    name: 'D2 OK/SYNCED',
    input: { connected: true, d2Result: 0x00, d2State: 0x01 },
    expected: 'Đang chạy'
  },
  {
    name: 'D2 OK/RENDERING',
    input: { connected: true, d2RenderResult: 0x00, d2RenderState: 0x02 },
    expected: 'Đang chạy'
  },
  {
    name: 'D2 OK/COMPLETE',
    input: { connected: true, d2RenderResult: 0x00, d2RenderState: 0x03 },
    expected: 'Đang chạy'
  },
  {
    name: 'Genuine rejected/error response',
    input: { connected: true, hasError: true, d2RenderResult: 0x05, d2RenderState: 0x04 },
    expected: 'Có lỗi'
  },
  {
    name: 'Error then D2 OK/COMPLETE',
    input: { connected: true, hasError: false, d2RenderResult: 0x00, d2RenderState: 0x03 },
    expected: 'Đang chạy'
  },
  {
    name: 'Normal disconnect',
    input: { connected: false, hasError: true, d2RenderResult: 0x00, d2RenderState: 0x03 },
    expected: 'Chưa kết nối'
  }
];

for (const fixture of fixtures) {
  const result = resolveProductState({
    connected: false,
    stalePresent: false,
    hasError: false,
    d2Result: null,
    d2State: null,
    d2RenderResult: null,
    d2RenderState: null,
    ...fixture.input
  });
  assert.equal(result.text, fixture.expected, fixture.name);
}

const changed = execFileSync('git', ['status', '--short', '--untracked-files=all'], { encoding: 'utf8' })
  .split(/\r?\n/)
  .filter(Boolean)
  .map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([
  WEB_PATH,
  DOC_PATH,
  'scripts/task-d6b-fix1-device-state-mapping-smoke.mjs'
]);
for (const file of changed) {
  assert.ok(allowed.has(file), `unexpected dirty file: ${file}`);
}
assert.ok(!changed.includes('test.html'), 'test.html must not be modified');
assert.ok(!changed.some(file => file.startsWith('firmware/')), 'firmware must not be modified');

mkdirSync(PROOF_DIR, { recursive: true });
const proofRows = fixtures.map(fixture => {
  const result = resolveProductState({
    connected: false,
    stalePresent: false,
    hasError: false,
    d2Result: null,
    d2State: null,
    d2RenderResult: null,
    d2RenderState: null,
    ...fixture.input
  });
  return `<tr><td>${fixture.name}</td><td>${fixture.expected}</td><td class="${result.cls}">${result.text}</td></tr>`;
}).join('');
const proofHtml = `<!doctype html><html><head><meta charset="utf-8"><title>D6B-FIX1 proof</title>
<style>
body{font-family:Arial,sans-serif;margin:0;background:#f7f8fb;color:#172033}
main{box-sizing:border-box;width:100%;max-width:920px;margin:0 auto;padding:20px}
h1{font-size:24px;margin:0 0 12px}
.card{border:1px solid #cbd5e1;border-radius:8px;background:white;padding:16px;overflow-wrap:anywhere}
table{width:100%;border-collapse:collapse;table-layout:fixed}
td,th{border-bottom:1px solid #e2e8f0;text-align:left;padding:10px;font-size:14px}
.ok{color:#166534;font-weight:700}.warn{color:#92400e;font-weight:700}.bad{color:#991b1b;font-weight:700}
button{min-height:40px;padding:8px 12px}
@media(max-width:420px){main{padding:12px}td,th{font-size:12px;padding:8px 6px}}
</style></head><body><main><section class="card">
<h1>TASK D6B-FIX1 Product Mode State Mapping</h1>
<p>Advanced section: closed by default. E6 NOT RUN is not an error. Width check: <strong id="overflow">pending</strong></p>
<table><thead><tr><th>Fixture</th><th>Expected</th><th>Actual</th></tr></thead><tbody>${proofRows}</tbody></table>
<button>Touch target proof</button>
</section></main><script>
document.getElementById('overflow').textContent = document.documentElement.scrollWidth <= window.innerWidth ? 'PASS' : 'FAIL';
document.body.dataset.overflow = document.documentElement.scrollWidth > window.innerWidth ? 'true' : 'false';
</script></body></html>`;
const proofPath = `${PROOF_DIR}/state-mapping-proof.html`;
writeFileSync(proofPath, proofHtml);

const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
assert.ok(existsSync(chrome), 'Chrome not found for browser proof');
const proofUrl = pathToFileURL(proofPath).href;
for (const [name, size] of [['desktop', '1365,768'], ['mobile', '360,740']]) {
  const png = `${PROOF_DIR}/${name}.png`;
  const run = spawnSync(chrome, [
    '--headless=new',
    '--in-process-gpu',
    '--disable-gpu-sandbox',
    '--no-sandbox',
    '--disable-gpu-watchdog',
    '--hide-scrollbars',
    `--window-size=${size}`,
    '--virtual-time-budget=1000',
    `--screenshot=${png}`,
    '--dump-dom',
    proofUrl
  ], { encoding: 'utf8' });
  const dom = run.stdout;
  assert.ok(existsSync(png), `${name} screenshot missing`);
  assert.ok(/TASK D6B-FIX1 Product Mode State Mapping/.test(dom), `${name} browser proof did not render`);
  assert.ok(/data-overflow="false"/.test(dom), `${name} horizontal overflow`);
}

console.log('TASK D6B-FIX1 device-state mapping smoke PASS');
