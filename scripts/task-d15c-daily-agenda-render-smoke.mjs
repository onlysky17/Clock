import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const ROOT = 'D:/EINK/Clock';
const FW = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const WEB = 'web/clock-app/hl24a-canvas-e5.html';
const DOC = 'docs/web/TASK_D15B_GOOGLE_CALENDAR_AGENDA.md';
const SMOKE = 'scripts/task-d15c-daily-agenda-render-smoke.mjs';
const firmware = fs.readFileSync(`${ROOT}/${FW}`, 'utf8');
const web = fs.readFileSync(`${ROOT}/${WEB}`, 'utf8');
const renderer = firmware.match(/static void hink_d13b_draw_daily_briefing[\s\S]*?\n}\n/)?.[0] ?? '';

assert.ok(renderer, 'daily briefing renderer missing');
assert.match(renderer, /hink_bitmap_draw_clock\(h, m, sy, sm, sd, sw, lunar_valid, lm, ld, ampm\)/,
  'monthly calendar must remain the base layout');
assert.match(renderer, /hink_daily_flags & HINK_DAILY_AGENDA_VALID/,
  'agenda validity guard missing');
assert.match(renderer, /i < hink_daily_agenda_count/,
  'bounded agenda loop missing');
assert.match(renderer, /hink_daily_agenda_minute\[i\] \/ 60U/,
  'agenda hour conversion missing');
assert.match(renderer, /hink_daily_agenda_minute\[i\] % 60U/,
  'agenda minute conversion missing');
assert.match(renderer, /hink_daily_agenda_label\[i\]\[0\]/,
  'agenda label rendering missing');
assert.match(renderer, /88U \+ \(i \* 16U\)/,
  'two-row agenda placement missing');
assert.match(renderer, /hink_daily_agenda_count == 1U[\s\S]*?105U/,
  'single agenda row placement missing');
assert.match(renderer, /HINK_DAILY_WEATHER_VALID\)[\s\S]*?hink_daily_agenda_count > 1U/,
  'two agenda rows must take priority over the weather line');
assert.doesNotMatch(renderer, /goto /, 'agenda rendering must not add a goto path');
assert.match(renderer, /hink_d7a_box\(3, 20, 99, 120, WHITE\)/,
  'agenda layout must clear the old clock and lower-left rows');
assert.match(renderer, /hink_d7a_draw_hhmm\(\(\(h \/ 10U\) == 1U\) \? 4U : 10U, 24, h, m, BLACK\)/,
  'agenda layout must optically center the large clock');
assert.match(renderer, /hink_d9a_draw_lunar\(26, 68, lunar_valid, lm, ld\)/,
  'agenda layout must evenly place the lunar row');
assert.match(renderer, /row_x = \(uint8_t\)\(\(101U - \(pos \* 6U\)\) \/ 2U\)/,
  'single-event weather row must be centered');
assert.match(renderer, /draw_text\(23, row_y, buf, BLACK\)/,
  'agenda must be centered inside the left pane');
assert.match(renderer, /buf\[6\] == 'H'[\s\S]*?buf\[7\] == 'O'[\s\S]*?buf\[8\] == 'P'/,
  'HOP agenda code must receive its Vietnamese dot-below mark');
assert.match(renderer, /hink_d7a_pixel\(67, \(int\)row_y \+ 8, BLACK\)/,
  'HỌP dot-below placement missing');
assert.match(renderer, /hink_d13d_draw_weather_marks/,
  'Vietnamese weather row must remain');
assert.match(firmware, /109U \+ \(col \* 20U\)/,
  'monthly calendar grid changed');
assert.match(web, /new Uint8Array\(20\)[\s\S]*packet\[1\]=0x08/,
  'D2 daily packet changed');
assert.match(web, /rows\.forEach\(\(row,index\)=>/,
  'web agenda encoding missing');
assert.match(web, /Google Calendar loaded \$\{events\.length\} bounded agenda row\(s\)/,
  'Google Calendar import missing');

const changed = execFileSync('git', ['status', '--porcelain', '--untracked-files=all'], {
  cwd: ROOT,
  encoding: 'utf8'
}).trimEnd().split(/\r?\n/).filter(Boolean).map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([FW, DOC, SMOKE]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.includes('test.html'), 'test.html must remain unchanged');

console.log('TASK D15C daily agenda render smoke PASS');
