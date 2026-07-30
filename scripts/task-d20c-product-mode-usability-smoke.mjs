import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const root = new URL('..', import.meta.url);
const htmlPath = new URL('../web/clock-app/hl24a-canvas-e5.html', import.meta.url);
const testPath = new URL('../test.html', import.meta.url);
const html = fs.readFileSync(htmlPath, 'utf8');
const testHtml = fs.readFileSync(testPath, 'utf8');
const script = html.match(/<script>([\s\S]*)<\/script>/)?.[1];

assert.ok(script, 'Product Mode script must exist');
new Function(script);

assert.match(testHtml, /web\/clock-app\/hl24a-canvas-e5\.html/,
  'Canonical test.html must still open the Product Mode page');
assert.match(html, /TASK D20B - Product Mode gọn cho cập nhật hằng ngày/);
assert.match(html, /D20B-SIMPLE-PRODUCT-20260730/);
assert.equal((html.match(/id="unifiedDailyUpdate"/g) || []).length, 1,
  'Product Mode must have exactly one primary daily-update action');
assert.match(html,
  /id="unifiedDailyUpdate"[^>]*>Cập nhật màn hình hôm nay</);

const setupStart = script.indexOf('function setupProductMode()');
const setupEnd = script.indexOf('function markLayoutHealth()', setupStart);
assert.ok(setupStart >= 0 && setupEnd > setupStart,
  'Product Mode setup must exist');
const setup = script.slice(setupStart, setupEnd);

assert.match(setup,
  /main\.append\(header,statusCard,presetCard,advanced,privacyLink\)/,
  'Daily action and face selection must precede Advanced');
assert.match(setup,
  /\$\('productPresetRow'\)\.append\(refs\.dailyCalendar,refs\.updateClock,dailyBriefing,profileApply\)/,
  'All three clock faces must remain directly reachable');
assert.match(setup, /dailyBriefing\.textContent='T\\u00f3m t\\u1eaft trong ng\\u00e0y'/);
assert.match(setup, /presetCard\.append\(dailyContextPanel\)/,
  'Optional daily weather context must remain reachable');
assert.match(setup, /const advanced=document\.createElement\('details'\)/);
assert.match(setup, /advanced\.id='advancedPanel'/);
assert.match(setup, /advanced\.innerHTML='<summary>Kỹ thuật \/ Nâng cao<\/summary>/);
assert.doesNotMatch(setup, /advanced\.open\s*=/,
  'Advanced must remain closed by default');
assert.match(setup,
  /advancedBody\.append\(advancedDailyProgress,preferencePanel,identityCard,previewCard\)/);
assert.match(setup,
  /for\(const section of originalSections\)\{\s*advancedBody\.append\(section\)/,
  'Engineering sections must remain under Advanced');
assert.doesNotMatch(setup, /googleCalendar|googleAgenda/,
  'Google Calendar must not be part of Product Mode setup');

const unifiedStart = script.indexOf('async function runUnifiedDailyUpdate()');
const unifiedEnd = script.indexOf('async function runD2Flow', unifiedStart);
assert.ok(unifiedStart >= 0 && unifiedEnd > unifiedStart,
  'Unified daily flow must exist');
const unifiedFlow = script.slice(unifiedStart, unifiedEnd);
assert.doesNotMatch(unifiedFlow, /googleCalendar|googleAgenda/,
  'Daily update must not require Google Calendar');

assert.match(script, /return\{text:'Chưa kết nối',cls:'warn'\}/);
assert.match(script, /return\{text:'Cần đồng bộ giờ',cls:'warn'\}/);
assert.match(script, /return\{text:'Đang chạy',cls:'ok'\}/);
assert.match(script, /return\{text:'Có lỗi',cls:'bad'\}/);
assert.match(script, /document\.documentElement\.dataset\.einkNoOverflow/);

assert.match(html, /const SERVICE='18424398-7cbc-11e9-8f9e-2a86e4085a59'/);
assert.match(html, /const WRITE='2d86686a-53dc-25b3-0c4a-f0e10c8dee20'/);
assert.match(html, /const NOTIFY='15005991-b131-3396-014c-664c9867b917'/);

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], {
  cwd: root,
  encoding: 'utf8'
}).split(/\r?\n/).filter(line => line.trim())
  .map(line => line.slice(3).replace(/\\/g, '/')).sort();
const allowed = [
  'docs/agent/CURRENT_STATE.md',
  'docs/agent/NEXT_ACTION.md',
  'docs/web/TASK_D20C_PRODUCT_MODE_USABILITY_VALIDATION.md',
  'scripts/task-d20c-product-mode-usability-smoke.mjs'
].sort();
assert.deepEqual(dirty, allowed, 'Only D20C closeout files may be dirty');
assert.ok(!dirty.some(path =>
  path.startsWith('firmware/') ||
  path.startsWith('web/') ||
  path === 'test.html'
), 'D20C must not modify firmware, web source, or test.html');

console.log('TASK D20C Product Mode usability smoke PASS');
