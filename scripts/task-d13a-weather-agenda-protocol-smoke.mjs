import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const ROOT = 'D:/EINK/Clock';
const docPath = 'docs/firmware/TASK_D13A_WEATHER_DAILY_AGENDA_PROTOCOL.md';
const smokePath = 'scripts/task-d13a-weather-agenda-protocol-smoke.mjs';
const firmwarePath = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const webPath = 'web/clock-app/hl24a-canvas-e5.html';
const testPath = 'test.html';

const doc = fs.readFileSync(docPath, 'utf8');
const firmware = fs.readFileSync(firmwarePath, 'utf8');
const web = fs.readFileSync(webPath, 'utf8');
const test = fs.readFileSync(testPath, 'utf8');
const has = (text, pattern, message) => assert.match(text, pattern, message);

has(doc, /D2 08.*20 bytes/, 'SET opcode/length missing');
has(doc, /D2 09.*2 bytes/, 'GET opcode/length missing');
has(doc, /D2 88.*20 bytes/, 'STATUS opcode/length missing');
has(doc, /schema.*exact value `01`/, 'schema version missing');
has(doc, /bit 0 weather valid; bit 1 agenda valid; bits 2\.\.7 zero/, 'flag contract missing');
has(doc, /days since local `2024-01-01`/, 'local day-key epoch missing');
has(doc, /uint16 little-endian, `0\.\.1439`/, 'agenda minute encoding missing');
has(doc, /temperature C.*int8.*`-40\.\.80`/, 'temperature validation missing');
has(doc, /precipitation.*range `0\.\.100`/, 'precipitation validation missing');
has(doc, /agenda count.*`0\.\.2`/, 'agenda count validation missing');
has(doc, /uppercase ASCII `A-Z`, digits `0-9`, and space/, 'label character policy missing');
has(doc, /sorted by start minute.*may not have duplicate/s, 'agenda ordering contract missing');
has(doc, /Unused entries are deterministic: minute zero and three spaces/, 'unused-entry encoding missing');
has(doc, /result `09 INVALID_DAILY_DATA`/, 'new result code missing');
has(doc, /`00 UNSET`[\s\S]*`01 FRESH`[\s\S]*`02 EXPIRED`/, 'context states missing');
has(doc, /Cold boot starts `UNSET`/, 'cold-boot state missing');
has(doc, /Disconnect does not clear valid context/, 'disconnect behavior missing');
has(doc, /Day rollover produces `EXPIRED`/, 'day-rollover expiry missing');
has(doc, /timezone or local-day change caused by `SET_TIME` must recompute freshness/, 'SET_TIME freshness behavior missing');
has(doc, /rejected without\s+changing the active RAM context/, 'malformed-request safety missing');
has(doc, /must not render or touch EPD hardware inside the\s+BLE write callback/, 'BLE callback render guard missing');
has(doc, /bits 0\.\.1: context state;[\s\S]*bit 2: weather valid;[\s\S]*bit 3: agenda valid;[\s\S]*bits 4\.\.7: zero/, 'status state/valid flag map missing');

has(doc, /RAM-only in D13B/, 'RAM-only MVP missing');
has(doc, /must not\s+write this payload to SPI\/NVDS/, 'SPI write prohibition missing');
has(doc, /must not consume bytes 19\.\.29/, 'journal reserved-byte guard missing');
has(doc, /sector `0x3B000`/, 'audited sector missing');
has(doc, /byte 16: profile;[\s\S]*byte 17: hour mode;[\s\S]*byte 18: refresh cadence;/, 'existing journal ownership missing');

has(doc, /Profile `02 DAILY_BRIEFING`/, 'new profile ID missing');
has(doc, /at most two agenda rows/, 'bounded layout missing');
has(doc, /add no font, icon table, framebuffer, allocation, or timer/, 'renderer resource guard missing');
has(doc, /logical `250 x 122`.*controller RAM `122 x 250`.*stride `16`.*`4000` bytes/s, 'geometry contract missing');
has(doc, /D12C raw baseline: `48848` bytes/, 'size baseline missing');
has(doc, /D13B target raw: at most `51500` bytes/, 'target raw size missing');
has(doc, /at most `2652` bytes/, 'code/RO budget missing');
has(doc, /at least `14028` bytes/, 'headroom gate missing');
has(doc, /RAM increase: at most `32` bytes/, 'RAM budget missing');
has(doc, /TASK D13B - IMPLEMENT DAILY BRIEFING PROFILE/, 'next action missing');

assert.doesNotMatch(firmware, /subcmd\s*==\s*0x0[89]U/, 'D2 08/09 unexpectedly conflict in current firmware');
assert.doesNotMatch(firmware, /msg\[1\]\s*=\s*0x88/, 'D2 88 unexpectedly conflicts in current firmware');
has(firmware, /subcmd == 0x00U[\s\S]*subcmd == 0x07U/, 'current D2 00..07 routing audit anchor missing');
has(firmware, /rec\[16\] = hink_clock_profile/, 'journal byte 16 ownership changed');
has(firmware, /rec\[17\] = hink_hour_mode/, 'journal byte 17 ownership changed');
has(firmware, /rec\[18\] = hink_refresh_minutes/, 'journal byte 18 ownership changed');

assert.doesNotMatch(web, /Uint8Array\.of\(0xD2,\s*0x0[89]/, 'D13 opcodes unexpectedly implemented in web');
assert.ok(test.includes('clock-app/hl24a-canvas-e5.html'), 'canonical test.html target changed');

const porcelain = execFileSync('git', ['status', '--porcelain', '--untracked-files=all'], {
  cwd: ROOT,
  encoding: 'utf8'
}).trim().split(/\r?\n/).filter(Boolean);
const changed = porcelain.map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([docPath, smokePath]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.includes(firmwarePath), 'firmware must remain unchanged');
assert.ok(!changed.includes(webPath), 'web must remain unchanged');
assert.ok(!changed.includes(testPath), 'test.html must remain unchanged');

console.log('TASK D13A weather and daily agenda protocol smoke PASS');
