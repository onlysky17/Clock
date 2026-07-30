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

assert.match(html, /TASK D20B - Product Mode gọn cho cập nhật hằng ngày/);
assert.match(html, /D20B-SIMPLE-PRODUCT-20260730/);
assert.match(html, /D20B PRODUCT MODE GỌN/);
assert.equal((html.match(/id="unifiedDailyUpdate"/g) || []).length, 1,
  'Product Mode must expose exactly one unified daily-update action');
assert.match(html, /id="unifiedDailyUpdate"[^>]*>Cập nhật màn hình hôm nay</);
assert.match(script, /main\.append\(header,statusCard,presetCard,advanced,privacyLink\)/);
assert.doesNotMatch(script, /productActionRow/);

const setupStart = script.indexOf('function setupProductMode()');
const setupEnd = script.indexOf('function markLayoutHealth()', setupStart);
assert.ok(setupStart >= 0 && setupEnd > setupStart, 'Product Mode setup must exist');
const setup = script.slice(setupStart, setupEnd);

assert.match(setup, /const advanced=document\.createElement\('details'\)/);
assert.doesNotMatch(setup, /advanced\.open\s*=/);
assert.match(setup,
  /advancedBody\.append\(advancedDailyProgress,preferencePanel,identityCard,previewCard\)/);
assert.doesNotMatch(setup, /presetCard\.append\(preferencePanel\)/,
  'Display preferences must stay inside the closed advanced section');
assert.match(setup, /for\(const section of originalSections\)\{\s*advancedBody\.append\(section\)/);
assert.match(setup, /id="unifiedWeatherStep"/);
assert.match(setup, /id="unifiedTimeStep"/);
assert.match(setup, /id="unifiedApplyStep"/);
assert.match(setup, /\$\('productPresetRow'\)\.append\(refs\.dailyCalendar,refs\.updateClock,dailyBriefing,profileApply\)/);
assert.match(setup, /presetCard\.append\(dailyContextPanel\)/);
assert.doesNotMatch(setup, /\$\('productActionRow'\)\.append\(refs\.d2SetTime,refs\.syncClock\)/);

const unifiedStart = script.indexOf('async function runUnifiedDailyUpdate()');
const unifiedEnd = script.indexOf('async function runD2Flow', unifiedStart);
assert.ok(unifiedStart >= 0 && unifiedEnd > unifiedStart, 'Unified daily flow must exist');
const unifiedFlow = script.slice(unifiedStart, unifiedEnd);
const weatherAt = unifiedFlow.indexOf('refreshDailyWeatherFromPhone');
const timeAt = unifiedFlow.indexOf('d2SetCurrentTime');
const applyAt = unifiedFlow.indexOf('d2ApplyClockProfile');
assert.ok(weatherAt >= 0 && timeAt > weatherAt && applyAt > timeAt,
  'Unified flow must preserve weather, time sync, then apply/render');
assert.doesNotMatch(unifiedFlow, /googleCalendar|googleAgenda|prepareUnifiedGoogleAgenda/);

assert.match(html, /const SERVICE='18424398-7cbc-11e9-8f9e-2a86e4085a59'/);
assert.match(html, /const WRITE='2d86686a-53dc-25b3-0c4a-f0e10c8dee20'/);
assert.match(html, /const NOTIFY='15005991-b131-3396-014c-664c9867b917'/);
assert.match(testHtml, /web\/clock-app\/hl24a-canvas-e5\.html/);

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], {
  cwd: root,
  encoding: 'utf8'
}).split(/\r?\n/).filter(line => line.trim()).map(line => line.slice(3).replace(/\\/g, '/')).sort();
const allowed = [
  'docs/agent/NEXT_ACTION.md',
  'docs/web/TASK_D20B_SIMPLIFY_PRODUCT_MODE.md',
  'scripts/task-d20b-simplify-product-mode-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
].sort();
assert.deepEqual(dirty, allowed, 'Only D20B files may be dirty');
assert.ok(!dirty.some(path => path.startsWith('firmware/') || path === 'test.html'),
  'Firmware and test.html must remain unchanged');

console.log('TASK D20B simplified Product Mode smoke PASS');
