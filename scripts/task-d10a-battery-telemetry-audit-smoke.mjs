import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = 'D:/EINK/Clock';
const docPath = `${root}/docs/firmware/TASK_D10A_BATTERY_TELEMETRY_AUDIT.md`;
const sourcePath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`;
const peripheralPath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c`;
const gattPath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/custom_profile/user_custs1_def.c`;
const modulesPath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/config/user_modules_config.h`;
const webPath = `${root}/web/clock-app/hl24a-canvas-e5.html`;

const doc = readFileSync(docPath, 'utf8');
const source = readFileSync(sourcePath, 'utf8');
const peripheral = readFileSync(peripheralPath, 'utf8');
const gatt = readFileSync(gattPath, 'utf8');
const modules = readFileSync(modulesPath, 'utf8');
const web = readFileSync(webPath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function mustInclude(text) {
  assert(doc.includes(text), `missing required audit text: ${text}`);
}

mustInclude('Chosen MVP: **reuse `FF00 / FF02` as an on-demand read and keep D2 unchanged.**');
mustInclude('Service: `0xFF00`');
mustInclude('Battery/ADC characteristic: `0xFF02`');
mustInclude('unsigned millivolts, little-endian');
mustInclude('adc_get_vbat_sample(false)');
mustInclude('millivolts = (adcval * 225) >> 7');
mustInclude('D2 81` status is exactly 15 bytes');
mustInclude('D2 83` identity is exactly 16 bytes');
mustInclude('Do not add `D2 04`');
mustInclude('Do not sample every minute');
mustInclude('no e-ink battery icon is authorized');
mustInclude('Firmware code increase: conservatively `<=350` bytes.');
mustInclude('RAM increase: `<=4` bytes.');
mustInclude('one Owner comparison against a known supply or multimeter');

assert(
  /int\s+adc1_update\s*\(void\)\s*\{\s*return\s+0\s*;\s*\}/s.test(source),
  'current adc1_update must be documented from the real stub',
);
assert(source.includes('static uint8_t batt_cal(uint16_t adc_sample)'), 'existing CR2032 curve missing');
for (const anchor of ['1705', '1584', '1360', '1136']) {
  assert(source.includes(anchor), `missing CR2032 ADC anchor ${anchor}`);
}

assert(gatt.includes('svc1_adc_val1   = 0xff02'), 'legacy FF02 characteristic missing');
assert(gatt.includes('[SVC1_IDX_ADC_VAL_1_VAL]'), 'FF02 value entry missing');
assert(gatt.includes('PERM(RD, ENABLE)'), 'FF02 must remain readable');
assert(modules.includes('#define EXCLUDE_DLG_BASS            (1)'), 'standard Battery Service exclusion changed');
assert(peripheral.includes('case CUSTS1_VALUE_REQ_IND:'), 'application-context read path missing');

assert(web.includes("const SERVICE='18424398-7cbc-11e9-8f9e-2a86e4085a59'"), 'canonical HINK service changed');
assert(web.includes('bytes.length!==15'), 'D2 status parser is no longer exact 15 bytes');
assert(web.includes('bytes.length!==16'), 'D2 identity parser is no longer exact 16 bytes');
assert(doc.includes('https://onlysky17.github.io/Clock/test.html') === false, 'audit must not invent another web URL');

const changed = execSync('git status --short --untracked-files=all', { cwd: root, encoding: 'utf8' })
  .trim()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.replace(/^..\s+/, ''))
  .sort();

const expected = [
  'docs/firmware/TASK_D10A_BATTERY_TELEMETRY_AUDIT.md',
  'scripts/task-d10a-battery-telemetry-audit-smoke.mjs',
].sort();
assert(JSON.stringify(changed) === JSON.stringify(expected), `unexpected dirty files: ${changed.join(', ')}`);

const runtimeDiff = execSync(
  'git diff --name-only -- firmware web test.html MEMORY.md docs/agent',
  { cwd: root, encoding: 'utf8' },
).trim();
assert(runtimeDiff === '', `audit changed runtime/state files: ${runtimeDiff}`);

console.log('TASK D10A battery telemetry audit smoke PASS');
