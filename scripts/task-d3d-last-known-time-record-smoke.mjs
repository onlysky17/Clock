import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = 'D:/EINK/Clock';
const implPath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`;
const peripheralPath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c`;
const impl = readFileSync(implPath, 'utf8');
const peripheral = readFileSync(peripheralPath, 'utf8');
const d3dHelpersStart = impl.indexOf('static uint8_t hink_d3d_slot_blank');
const bootStart = impl.indexOf('void hink_d3d_boot_load_last_known_time(void)', d3dHelpersStart);
const bootBlock = impl.slice(
  bootStart,
  impl.indexOf('static void hink_d3d_store_last_known_time', bootStart),
);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function mustInclude(source, text) {
  assert(source.includes(text), `missing required text: ${text}`);
}

function mustMatch(source, pattern, message) {
  assert(pattern.test(source), message);
}

mustInclude(impl, '#define HINK_D3D_STORE_SECTOR 0x3B000UL');
mustInclude(impl, '#define HINK_D3D_STORE_SLOT_A 0x3B000UL');
mustInclude(impl, '#define HINK_D3D_STORE_SLOT_B 0x3B020UL');
mustInclude(impl, '#define HINK_D3D_STORE_SIZE   32U');
mustInclude(impl, '#define HINK_D3D_CRC_OFFSET   30U');
mustInclude(impl, '#define HINK_D2_STATUS_LEN          15U');
mustInclude(impl, '#define HINK_D2_FLAG_STALE_PRESENT  0x80U');
mustInclude(impl, '#define HINK_D2_FLAGS_RESERVED_MASK 0xFCU');

mustInclude(impl, 'static uint32_t hink_d3d_stale_epoch');
mustInclude(impl, 'static int16_t hink_d3d_stale_timezone');
mustInclude(impl, 'static uint8_t hink_d3d_stale_flags');
mustInclude(impl, 'static uint8_t hink_d3d_stale_valid');
mustInclude(impl, 'extern int sf_erase(int addr, int size, int wait);');
mustInclude(impl, 'extern int fspi_exit(void);');
mustInclude(impl, 'extern int sf_wait(void);');

mustMatch(
  bootBlock,
  /fspi_init\(\);[\s\S]*?sf_read\(HINK_D3D_STORE_SLOT_A, HINK_D3D_STORE_SIZE, a\);[\s\S]*?sf_read\(HINK_D3D_STORE_SLOT_B, HINK_D3D_STORE_SIZE, b\);[\s\S]*?fspi_exit\(\);/,
  'boot stale-record read must bracket flash access with fspi_init/fspi_exit',
);
mustInclude(impl, 'sf_read(HINK_D3D_STORE_SLOT_A, HINK_D3D_STORE_SIZE, a);');
mustInclude(impl, 'sf_read(HINK_D3D_STORE_SLOT_B, HINK_D3D_STORE_SIZE, b);');
mustInclude(impl, 'sf_erase(HINK_D3D_STORE_SECTOR, 0x1000, 1);');
mustInclude(impl, 'sf_page_write(target_a ? HINK_D3D_STORE_SLOT_A : HINK_D3D_STORE_SLOT_B,');
mustInclude(impl, 'sf_wait();');
mustInclude(impl, 'hink_e5_crc16_ccitt_update(0xFFFFU, rec, HINK_D3D_CRC_OFFSET)');
mustInclude(impl, 'hink_d3d_store_last_known_time(epoch, timezone, flags);');
mustInclude(impl, 'hink_d3d_stale_valid = 0U;');

mustMatch(
  impl,
  /msg\[3\] = \(hink_d2_synced_epoch == 0UL\) \? HINK_D2_STATE_UNSET :[\s\S]*?if \(\(hink_d2_synced_epoch == 0UL\) && hink_d3d_stale_valid\)/,
  'stale record must keep status state UNSET instead of RUNNING',
);
mustMatch(
  impl,
  /flags = hink_d3d_stale_flags \| HINK_D2_FLAG_STALE_PRESENT;/,
  'stale-present flag must be added only to status flags',
);
assert(bootBlock.includes('hink_d3d_stale_valid = 1U;'), 'boot loader must mark valid stale metadata');
assert(!/hink_d2_synced_epoch\s*=/.test(bootBlock), 'boot load must not set synced epoch');
assert(!/HINK_AUTO_TRY_SCHEDULE/.test(bootBlock), 'boot load must not schedule render');
assert(!/hink_d2_timer_flags\s*=/.test(bootBlock), 'boot load must not enable dedicated timer');
assert(!/sf_erase\s*\(\s*0\s*,/.test(impl), 'must not erase full chip');
assert(!/0x38000|0x39000|0x3A000/i.test(impl), 'D3D implementation must not touch reserved config sectors');

mustInclude(peripheral, 'extern void hink_d3d_boot_load_last_known_time(void);');
mustMatch(
  peripheral,
  /fspi_config\(0x00030605\);[\s\S]*?selflash\(otp_boot\);[\s\S]*?hink_d3d_boot_load_last_known_time\(\);/,
  'boot load must run only after SPI/selflash setup',
);

const changed = execSync('git status --short --untracked-files=all', { cwd: root, encoding: 'utf8' })
  .trim()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.replace(/^[ MADRCU?!]{1,2}\s+/, ''))
  .sort();

assert(JSON.stringify(changed) === JSON.stringify([
  'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c',
  'firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c',
  'scripts/task-d3d-last-known-time-record-smoke.mjs',
]), `unexpected dirty files: ${changed.join(', ')}`);

const forbidden = execSync('git diff --name-only -- web test.html firmware/active/HINK213_CLOCK_22_BASE/src/epd docs tools MEMORY.md', {
  cwd: root,
  encoding: 'utf8',
}).trim();
assert(forbidden === '', `unexpected out-of-scope changes: ${forbidden}`);

console.log('TASK D3D last-known time record smoke PASS');
