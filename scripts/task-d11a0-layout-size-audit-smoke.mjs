import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const root = process.cwd();
const docPath = path.join(root, 'docs/firmware/TASK_D11A0_LAYOUT_SIZE_AUDIT.md');
const sourcePath = path.join(root, 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c');
const peripheralPath = path.join(root, 'firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c');

const doc = fs.readFileSync(docPath, 'utf8');
const source = fs.readFileSync(sourcePath, 'utf8');
const peripheral = fs.readFileSync(peripheralPath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

for (const marker of [
  '48012',
  '65528',
  '17516',
  '46209FF3944F3E3CDC91BA20F01EB68C444D7A5ABFB7C39D5F6597469E8706AE',
  '`hink_bitmap_draw_clock` | 1088',
  '`hink_d2_draw_current_framebuffer` | 552',
  '`clock_draw` | 416',
  '`clock_update` | 204',
  '`app_clock_timer_cb` | 152',
  'conservative recovery target of at least `800`',
  'at most `1200` raw bytes per face',
  'at most `56000` bytes',
  'at least `9000` bytes',
  'TASK D11A - CLOCK FACE PROFILE DESIGN',
]) {
  assert(doc.includes(marker), `Missing audit marker: ${marker}`);
}

assert(source.includes('static void hink_d2_draw_current_framebuffer(void)'), 'Shared framebuffer renderer missing');
assert(source.includes('static void hink_bitmap_draw_clock('), 'Current bitmap face missing');
assert(source.includes('static void hink_d7a_draw_hhmm('), 'Shared large-time primitive missing');
assert(source.includes('static void hink_d7a_draw_day('), 'Shared calendar-day primitive missing');
assert(source.includes('static uint8_t hink_d3c_lunar_from_solar('), 'Lunar derivation missing');
assert(source.includes('static uint8_t fb_bw') === false, 'A second framebuffer declaration was introduced');
assert(peripheral.includes('int stat = clock_update(update_seconds);'), 'Legacy timer audit call site changed');

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], {
  cwd: root,
  encoding: 'utf8',
}).trim().split(/\r?\n/).filter(Boolean);

const allowed = new Set([
  'docs/firmware/TASK_D11A0_LAYOUT_SIZE_AUDIT.md',
  'scripts/task-d11a0-layout-size-audit-smoke.mjs',
]);
for (const line of dirty) {
  const file = line.replace(/^[ MADRCU?!]{1,2}\s+/, '').replaceAll('\\', '/');
  assert(allowed.has(file), `Out-of-scope dirty file: ${line}`);
}

console.log('TASK D11A-0 layout size audit smoke PASS');
