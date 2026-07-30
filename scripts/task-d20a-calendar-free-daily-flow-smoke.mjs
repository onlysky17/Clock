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

assert.match(html, /TASK D20A - Cập nhật hôm nay không cần lịch/);
assert.match(html, /D20A-CALENDAR-FREE-DAILY-20260730/);
assert.match(html, /id="unifiedDailyUpdate"[^>]*>Cập nhật màn hình hôm nay</);
assert.match(html, /id="unifiedWeatherStep"/);
assert.match(html, /id="unifiedTimeStep"/);
assert.match(html, /id="unifiedApplyStep"/);
assert.doesNotMatch(html, /id="unifiedCalendarStep"/);
assert.match(html, /\.unifiedDailySteps\{[^}]*grid-template-columns:repeat\(3,minmax\(0,1fr\)\)/);

assert.doesNotMatch(html, /accounts\.google\.com\/gsi\/client/);
assert.doesNotMatch(html, /meta name="google-calendar-client-id"/);
assert.doesNotMatch(html, /id="googleCalendarConnect"/);
assert.doesNotMatch(html, /id="googleCalendarFetch"/);
assert.doesNotMatch(html, /id="googleCalendarDisconnect"/);
assert.doesNotMatch(html, /window\.EINK_GOOGLE_CALENDAR_TEST/);

const unifiedStart = script.indexOf('async function runUnifiedDailyUpdate()');
const unifiedEnd = script.indexOf('async function runD2Flow', unifiedStart);
assert.ok(unifiedStart >= 0 && unifiedEnd > unifiedStart, 'Unified daily flow must exist');
const unifiedFlow = script.slice(unifiedStart, unifiedEnd);
const weatherAt = unifiedFlow.indexOf('refreshDailyWeatherFromPhone');
const timeAt = unifiedFlow.indexOf('d2SetCurrentTime');
const applyAt = unifiedFlow.indexOf('d2ApplyClockProfile');
assert.ok(weatherAt >= 0 && timeAt > weatherAt && applyAt > timeAt,
  'Unified flow must run weather, time, then apply/render');
assert.doesNotMatch(unifiedFlow, /googleCalendar|googleAgenda|prepareUnifiedGoogleAgenda/);

assert.match(html, /id="dailyAgendaTime0" type="hidden"/);
assert.match(html, /id="dailyAgendaLabel0" type="hidden"/);
assert.match(html, /id="dailyAgendaTime1" type="hidden"/);
assert.match(html, /id="dailyAgendaLabel1" type="hidden"/);
assert.match(script, /new Uint8Array\(20\)/);
assert.match(testHtml, /web\/clock-app\/hl24a-canvas-e5\.html/);

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], {
  cwd: root,
  encoding: 'utf8'
}).split(/\r?\n/).filter(line => line.trim()).map(line => line.slice(3).replace(/\\/g, '/')).sort();
const allowed = [
  'docs/agent/NEXT_ACTION.md',
  'docs/web/TASK_D20A_CALENDAR_FREE_DAILY_FLOW.md',
  'scripts/task-d20a-calendar-free-daily-flow-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
].sort();
assert.deepEqual(dirty, allowed, 'Only D20A files may be dirty');
assert.ok(!dirty.some(path => path.startsWith('firmware/') || path === 'test.html'),
  'Firmware and test.html must remain unchanged');

console.log('TASK D20A calendar-free daily flow smoke PASS');
