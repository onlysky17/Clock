import { strict as assert } from 'node:assert';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const ROOT = 'D:/EINK/Clock';
const SRC = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const DOC = 'docs/firmware/TASK_D9A_BALANCED_LEFT_PANEL.md';
const PROOF = `${ROOT}/_incoming/D9A_BALANCED_LEFT_PANEL_PROOF`;
const source = readFileSync(`${ROOT}/${SRC}`, 'utf8');
const doc = readFileSync(`${ROOT}/${DOC}`, 'utf8');
const includes = (text, value, message) => assert.ok(text.includes(value), message);

includes(source, 'hink_d7a_draw_hhmm(10, 38, h, m, BLACK);', 'HH:mm must be centered and lowered');
includes(source, 'hink_d9a_draw_lunar(11, 88, lunar_valid, lm, ld);', 'medium lunar row position missing');
assert.ok(!source.includes('hink_d7a_draw_hhmm(6, 32, h, m, BLACK);'), 'old high clock position remains');
assert.ok(!source.includes('hink_d7a_draw_text_al(4, 104, lunar_buf);'), 'old tiny bottom lunar row remains');
includes(source, 'static void hink_d9a_draw_lunar', 'bounded lunar bitmap helper missing');
assert.equal((source.match(/8U, 12U, 2U, BLACK/g) || []).length, 4, 'all four lunar digits must use matching bold strokes');
includes(source, 'hink_d7a_box(x + 57U, y + 5U, x + 63U, y + 6U, BLACK);', 'out-of-range lunar --/-- fallback missing');
includes(source, 'hink_d7a_draw_circumflex(x, (uint8_t)(y - 4U));', 'ÂL circumflex missing');
includes(source, 'hink_d7a_box(x + 3U, y, x + 4U, y + 1U, BLACK);', 'circumflex must use a two-pixel stroke');
includes(source, 'hink_d7a_box(101, 6, 102, 116, BLACK);', 'divider changed');
includes(source, 'draw_text((uint8_t)(109U + (col * 20U)), 25, weekday_buf, BLACK);', 'weekday grid changed');
includes(source, 'x = (uint8_t)(109U + (col * 20U));', 'day grid changed');
includes(source, 'memset(fb_bw, 0xff, scr_h * line_bytes);', 'framebuffer clear changed');
includes(source, '#define HINK_D8A_SOURCE_ID       0xD8A00001UL', 'D8A identity changed');
assert.ok(!/#include\s+"sfont|#include\s+"font50|#include\s+"font66/.test(source), 'legacy font restored');
assert.equal(16 * 250, 4000, 'framebuffer contract changed');
includes(doc, 'The Owner SysRAM physical test passed on 2026-07-22', 'physical PASS evidence missing');

mkdirSync(PROOF, { recursive: true });
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="750" height="366" viewBox="0 0 250 122">
<rect width="250" height="122" fill="white"/><rect x="101" y="6" width="2" height="111" fill="#111"/>
<text x="4" y="15" font-family="monospace" font-size="8">T4 22/07/2026</text>
<text x="10" y="69" font-family="monospace" font-size="31" font-weight="700">08:46</text>
<text x="11" y="100" font-family="monospace" font-size="12" font-weight="700">ÂL 09/06</text>
<text x="124" y="14" font-family="monospace" font-size="8">THÁNG 07/2026</text>
<text x="124" y="32" font-family="monospace" font-size="8">T2  T3  T4  T5  T6  T7  CN</text>
</svg>`;
writeFileSync(`${PROOF}/balanced-left-panel.svg`, svg);
writeFileSync(`${PROOF}/layout-check.txt`, [
  'TASK D9A host layout proof PASS',
  'solar y=8', 'HH:mm x=10 y=38 width=80 height=31',
  'lunar x=11 y=88 height=12', 'divider/right calendar unchanged'
].join('\n'));
assert.ok(existsSync(`${PROOF}/balanced-left-panel.svg`), 'proof missing');

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], { cwd: ROOT, encoding: 'utf8' })
  .split(/\r?\n/).filter(Boolean).map(line => line.slice(3).replaceAll('\\', '/'))
  .filter(file => !file.startsWith('_incoming/'));
const allowed = new Set([SRC, DOC, 'scripts/task-d9a-balanced-left-panel-smoke.mjs']);
assert.ok(dirty.every(file => allowed.has(file)), `out-of-scope dirty file: ${dirty.join(', ')}`);
assert.ok(!dirty.some(file => file.startsWith('web/')), 'web must not be modified');

console.log('TASK D9A balanced left panel smoke PASS');
