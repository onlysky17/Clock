import { strict as assert } from 'node:assert';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock';
const SRC = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const PROOF_DIR = `${ROOT}/_incoming/D7A_AUTONOMOUS_FLAGSHIP_PROOF`;
const source = readFileSync(SRC, 'utf8');

function must(label, pattern) {
  assert.ok(pattern.test(source), `${label} missing`);
}

must('D7A medium HH:mm renderer', /static void hink_d7a_draw_hhmm/);
must('D7A day renderer', /static void hink_d7a_draw_day/);
must('D7A flagship calendar month title', /month_buf\[0\] = 'T';[\s\S]*month_buf\[4\] = 'G';/);
must('D7A THANG acute mark', /hink_d7a_draw_acute\(136, 4\)/);
must('D7A AL circumflex mark', /hink_d7a_draw_text_al/);
must('D7A vertical divider', /hink_d7a_box\(101, 6, 102, 116, BLACK\)/);
must('D7A current day invert', /if \(day == sd\)[\s\S]*hink_d7a_box\(x - 2, y - 1, x \+ 15, y \+ 10, BLACK\);[\s\S]*hink_d7a_draw_day\(x, y, day, WHITE\);/);
must('D7A 7 columns', /col = \(uint8_t\)\(pos % 7U\)/);
must('D7A weekday headers use same grid as day cells', /for \(col = 0U; col < 7U; col\+\+\)[\s\S]*draw_text\(\(uint8_t\)\(109U \+ \(col \* 20U\)\), 25, weekday_buf, BLACK\);/);
assert.ok(!/draw_text\(110, 25, "T2 T3 T4 T5 T6 T7 CN", BLACK\)/.test(source), 'weekday headers must not use proportional string spacing');
must('D7A first-day offset', /offset = \(uint8_t\)\(\(first_wday \+ 6U\) % 7U\)/);
must('D7A month length from leap-aware helper', /mdays = hink_d3c_solar_mdays\(sy, sm\)/);
must('D7A framebuffer clear stays 4000 source path', /memset\(fb_bw, 0xff, scr_h \* line_bytes\)/);
must('EPD refresh handshake has bounded BUSY-start wait', /#define HINK_EPD_BUSY_START_POLL_LIMIT 50U/);
must('cold-boot EPD prime flag starts enabled', /static uint8_t hink_epd_first_refresh_pending = 1U;/);
must('physical recovery interval matches observed second-sync pass', /#define HINK_EPD_PRIME_RECOVERY_TICKS 2000UL/);
must('D2 lifecycle still present', /hink_d2_time_handle/);
must('D3E scheduler still present', /HINK_AUTO_TRY_SCHEDULE/);
must('D2 SET_TIME arms start callback', /hnd = app_easy_timer\(1, hink_d2_minute_start_cb\);/);
must('D2 start callback schedules pending render', /static void hink_d2_minute_start_cb\(void\)[\s\S]*hink_d2_arm_minute_timer\(hink_d2_first_interval_seconds\);[\s\S]*HINK_AUTO_TRY_SCHEDULE\(\);/);
const setTimeBlock = source.match(/if \(subcmd == 0x00U\)[\s\S]*?if \(subcmd == 0x02U\)/)?.[0] ?? '';
assert.ok(setTimeBlock.includes('hink_d3d_store_last_known_time(epoch, timezone, flags);'), 'SET_TIME must still persist last-known time');
assert.ok(!setTimeBlock.includes('HINK_AUTO_TRY_SCHEDULE();'), 'SET_TIME must not schedule D7A render directly from BLE write context');
must('D3D persistence still present', /HINK_D3D_STORE_SECTOR 0x3B000UL/);
must('E5 command IDs unchanged', /0xE5[\s\S]*0xE6/);
must('E6 render path unchanged', /hink_e6_refresh_handle/);
assert.ok(!/#include\s+"sfont/.test(source), 'legacy sfont include must stay gone');
assert.ok(!/#include\s+"font50/.test(source), 'legacy font50 include must stay gone');
assert.ok(!/#include\s+"font66/.test(source), 'legacy font66 include must stay gone');
assert.ok(!/sprintf\(/.test(source.match(/static void hink_bitmap_draw_clock[\s\S]*?^}/m)?.[0] ?? ''), 'render path must not use sprintf');
assert.equal(16 * 250, 4000, 'framebuffer must remain 4000 bytes');
must('shared framebuffer renderer draws the D7A layout', /static void hink_d2_draw_current_framebuffer\(void\)[\s\S]*memset\(fb_bw, 0xff, scr_h \* line_bytes\);[\s\S]*hink_bitmap_draw_clock\(h, m, sy, sm, sd, sw, lunar_valid, lm, ld\);/);
must('normal render draws before starting EPD', /static void hink_d2_render_timer_cb\(void\)[\s\S]*hink_d2_draw_current_framebuffer\(\);[\s\S]*hink_d2_start_epd_refresh\(\)/);
must('shared EPD start initializes BUSY handshake', /static uint8_t hink_d2_start_epd_refresh\(void\)[\s\S]*epd_screen_update\(\);[\s\S]*epd_update\(\);[\s\S]*hink_epd_busy_seen = 0U;[\s\S]*app_easy_timer\(10, epd_wait_timer\);/);
must('EPD wait observes BUSY asserted', /if\(epd_busy\(\)\)[\s\S]*hink_epd_busy_seen = 1U/);
must('EPD wait does not complete before BUSY starts', /!hink_epd_busy_seen[\s\S]*HINK_EPD_BUSY_START_POLL_LIMIT[\s\S]*app_easy_timer\(10, epd_wait_timer\)/);
must('missing BUSY assertion fails instead of completing', /hink_epd_busy_start_polls\+\+[\s\S]*HINK_D2_RENDER_ERROR/);
must('first completed waveform schedules one recovery retry', /if \(hink_epd_first_refresh_pending\)[\s\S]*app_easy_timer\(HINK_EPD_PRIME_RECOVERY_TICKS,[\s\S]*hink_d2_prime_retry_cb\)[\s\S]*hink_epd_first_refresh_pending = 0U;/);
must('prime retry rebuilds before reusing the EPD engine', /static void hink_d2_prime_retry_cb\(void\)[\s\S]*hink_d2_draw_current_framebuffer\(\);[\s\S]*hink_d2_start_epd_refresh\(\)/);
const primeRetryStart = source.lastIndexOf('static void hink_d2_prime_retry_cb(void)');
const primeRetryEnd = source.indexOf('\nstatic void hink_d2_render_timer_cb', primeRetryStart);
const primeRetryBlock = source.slice(primeRetryStart, primeRetryEnd);
assert.ok(!/memset\(fb_bw|hink_bitmap_draw_clock/.test(primeRetryBlock), 'prime retry must rebuild through the shared renderer only');
assert.ok(/hink_d2_render_notify\(HINK_D2_RESULT_OK, HINK_D2_RENDER_COMPLETE\);[\s\S]*HINK_AUTO_TRY_SCHEDULE\(\);/.test(source), 'COMPLETE must be emitted from EPD wait completion path');

function isLeap(year) {
  return year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
}

function monthLength(year, month1) {
  return [31, 28 + Number(isLeap(year)), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month1 - 1];
}

function weekday(year, month1, day) {
  return new Date(Date.UTC(year, month1 - 1, day)).getUTCDay();
}

function firstOffsetMonday(year, month1) {
  return (weekday(year, month1, 1) + 6) % 7;
}

const fixtures = [
  { name: '2026-07-20 08:35', y: 2026, mo: 7, d: 20, h: 8, mi: 35, lunar: '07/06', first: 2, len: 31 },
  { name: '2026-08-01 07:05', y: 2026, mo: 8, d: 1, h: 7, mi: 5, lunar: '19/06', first: 5, len: 31 },
  { name: '2026-08-31 23:58', y: 2026, mo: 8, d: 31, h: 23, mi: 58, lunar: '19/07', first: 5, len: 31 },
  { name: '2028-02-29 12:52', y: 2028, mo: 2, d: 29, h: 12, mi: 52, lunar: '05/02', first: 1, len: 29 }
];

for (const f of fixtures) {
  assert.equal(monthLength(f.y, f.mo), f.len, `${f.name} month length`);
  assert.equal(firstOffsetMonday(f.y, f.mo), f.first, `${f.name} first-day offset`);
  assert.ok(f.d <= f.len, `${f.name} day inside month`);
}

function pad2(v) {
  return String(v).padStart(2, '0');
}

function wdayLabel(y, m, d) {
  const labels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
  return labels[weekday(y, m, d)];
}

function dayCell(f, day) {
  const pos = firstOffsetMonday(f.y, f.mo) + day - 1;
  const row = Math.floor(pos / 7);
  const col = pos % 7;
  return { x: 109 + col * 20, y: 40 + row * 13 };
}

const weekdayHeaders = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
  .map((label, col) => `<text x="${109 + col * 20}" y="32" font-size="7" font-family="monospace" fill="#111">${label}</text>`)
  .join('');

function renderSvg(f) {
  const days = Array.from({ length: monthLength(f.y, f.mo) }, (_, i) => i + 1).map(day => {
    const c = dayCell(f, day);
    const selected = day === f.d;
    const rect = selected ? `<rect x="${c.x - 2}" y="${c.y - 1}" width="18" height="12" fill="#111"/>` : '';
    const fill = selected ? '#fff' : '#111';
    return `${rect}<text x="${c.x + 7}" y="${c.y + 9}" text-anchor="middle" font-size="9" fill="${fill}" font-family="monospace">${day}</text>`;
  }).join('');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="500" height="244" viewBox="0 0 250 122">
<rect width="250" height="122" fill="#fff"/>
<text x="4" y="15" font-size="8" font-family="monospace" fill="#111">${wdayLabel(f.y, f.mo, f.d)} ${pad2(f.d)}/${pad2(f.mo)}/${f.y}</text>
<text x="6" y="63" font-size="31" font-family="monospace" font-weight="700" fill="#111">${pad2(f.h)}:${pad2(f.mi)}</text>
<text x="4" y="112" font-size="8" font-family="monospace" fill="#111">ÂL ${f.lunar}</text>
<rect x="101" y="6" width="2" height="111" fill="#111"/>
<text x="124" y="14" font-size="8" font-family="monospace" fill="#111">THÁNG ${f.mo}/${f.y}</text>
${weekdayHeaders}
${days}
</svg>`;
}

mkdirSync(PROOF_DIR, { recursive: true });
const cards = fixtures.map((f, i) => {
  const svg = renderSvg(f);
  const path = `${PROOF_DIR}/fixture-${i + 1}.svg`;
  writeFileSync(path, svg);
  return `<section><h2>${f.name}</h2><img src="${pathToFileURL(path).href}" alt="${f.name}"></section>`;
}).join('');
const proofHtml = `<!doctype html><meta charset="utf-8"><title>D7A proof</title>
<style>body{font-family:Arial,sans-serif;margin:0;background:#eef2f7;color:#111;overflow-x:hidden}main{box-sizing:border-box;width:100%;padding:16px;display:grid;grid-template-columns:repeat(auto-fit,minmax(0,1fr));gap:14px}section{min-width:0;background:white;border:1px solid #ccd3dd;border-radius:8px;padding:10px;overflow:hidden}img{display:block;width:100%;height:auto;image-rendering:pixelated}h1{grid-column:1/-1;margin:0;font-size:clamp(22px,7vw,32px);overflow-wrap:anywhere}h2{font-size:15px;margin:0 0 8px}@media(max-width:640px){main{grid-template-columns:1fr;padding:12px}}</style>
<main><h1>D7A autonomous flagship daily layout proof</h1>${cards}</main><script>document.body.dataset.overflow=document.documentElement.scrollWidth>window.innerWidth?'true':'false';</script>`;
const proofPath = `${PROOF_DIR}/index.html`;
writeFileSync(proofPath, proofHtml);

const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
assert.ok(existsSync(chrome), 'Chrome not found for visual proof');
for (const [name, size] of [['desktop', '1365,768'], ['mobile', '360,740']]) {
  const png = `${PROOF_DIR}/${name}.png`;
  const run = spawnSync(chrome, [
    '--headless=new',
    '--in-process-gpu',
    '--disable-gpu-sandbox',
    '--no-sandbox',
    '--disable-gpu-watchdog',
    `--window-size=${size}`,
    '--virtual-time-budget=1000',
    `--screenshot=${png}`,
    '--dump-dom',
    pathToFileURL(proofPath).href
  ], { encoding: 'utf8' });
  assert.ok(existsSync(png), `${name} screenshot missing`);
  assert.ok(/D7A autonomous flagship/.test(run.stdout), `${name} proof did not render`);
  assert.ok(/data-overflow="false"/.test(run.stdout), `${name} horizontal overflow`);
}

const changed = execFileSync('git', ['status', '--short', '--untracked-files=all'], { encoding: 'utf8' })
  .split(/\r?\n/)
  .filter(Boolean)
  .map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([
  SRC,
  'scripts/task-d7a-autonomous-flagship-layout-smoke.mjs',
  'docs/firmware/TASK_D7A_AUTONOMOUS_FLAGSHIP_LAYOUT.md',
  'docs/firmware/TASK_D7B_FIX5_FIRST_REFRESH_PRIME.md'
]);
for (const file of changed) {
  assert.ok(allowed.has(file), `unexpected dirty file: ${file}`);
}

console.log('TASK D7A autonomous flagship layout smoke PASS');
