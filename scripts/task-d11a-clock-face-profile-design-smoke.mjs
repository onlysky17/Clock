import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const root = process.cwd();
const designPath = path.join(root, 'docs/firmware/TASK_D11A_CLOCK_FACE_PROFILE_DESIGN.md');
const auditPath = path.join(root, 'docs/firmware/TASK_D11A0_LAYOUT_SIZE_AUDIT.md');
const sourcePath = path.join(root, 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c');
const design = fs.readFileSync(designPath, 'utf8');
const audit = fs.readFileSync(auditPath, 'utf8');
const source = fs.readFileSync(sourcePath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

for (const marker of [
  'D2 00',
  'D2 01',
  'D2 02',
  'D2 03',
  'D2 04',
  'D2 05',
  'D2 84',
  'INVALID_PROFILE',
  'byte `16` as profile ID',
  'Old valid record with byte `16 = FF`',
  'Profile `0` must remain pixel-for-pixel unchanged',
  'TASK D11B - IMPLEMENT LARGE-TIME CLOCK PROFILE',
  'at most `50000` bytes',
  'at most `8` bytes',
]) {
  assert(design.includes(marker), `Missing design marker: ${marker}`);
}

assert(audit.includes('REJECTED BY PHYSICAL TEST'), 'Failed legacy trim is not recorded');
assert(audit.includes('only the later five-minute scheduler refresh made the layout visible'), 'Physical regression evidence missing');
assert(source.includes('#define HINK_D2_SET_TIME_LEN        9U'), 'D2 SET_TIME contract changed');
assert(source.includes('#define HINK_D2_RENDER_LEN          2U'), 'D2 render contract changed');
assert(source.includes('#define HINK_D2_IDENTITY_LEN        2U'), 'D2 identity contract changed');
assert(source.includes('#define HINK_D3D_STORE_SIZE   32U'), 'D3D record size changed');
assert(source.includes('#define HINK_D3D_CRC_OFFSET   30U'), 'D3D CRC offset changed');
assert(source.includes('static uint8_t hink_d2_start_epd_refresh(void)'), 'Shared EPD worker missing');
assert(source.includes('static void hink_d2_draw_current_framebuffer(void)'), 'Shared framebuffer entry missing');

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], {
  cwd: root,
  encoding: 'utf8',
}).trim().split(/\r?\n/).filter(Boolean);
const allowed = new Set([
  'docs/firmware/TASK_D11A0_LAYOUT_SIZE_AUDIT.md',
  'docs/firmware/TASK_D11A_CLOCK_FACE_PROFILE_DESIGN.md',
  'scripts/task-d11a-clock-face-profile-design-smoke.mjs',
]);
for (const line of dirty) {
  const file = line.replace(/^[ MADRCU?!]{1,2}\s+/, '').replaceAll('\\', '/');
  assert(allowed.has(file), `Out-of-scope dirty file: ${line}`);
}

console.log('TASK D11A clock face profile design smoke PASS');
