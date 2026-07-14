import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const sourcePath = join(root, 'firmware', 'active', 'HINK213_CLOCK_22_BASE', 'src', 'user_custs1_impl.c');
const source = readFileSync(sourcePath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function bodyOf(name) {
  const start = source.indexOf(name);
  assert(start >= 0, `Missing ${name}`);
  const open = source.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < source.length; i += 1) {
    if (source[i] === '{') depth += 1;
    if (source[i] === '}') depth -= 1;
    if (depth === 0) return source.slice(open + 1, i);
  }
  throw new Error(`Unclosed ${name}`);
}

for (const required of [
  '#define HINK_D2_SET_TIME_LEN        9U',
  '#define HINK_D2_GET_STATUS_LEN      2U',
  '#define HINK_D2_STATUS_LEN          15U',
  '#define HINK_D2_EPOCH_MIN           1704067200UL',
  '#define HINK_D2_EPOCH_MAX           4102444799UL',
  '#define HINK_D2_STALE_SECONDS       86400UL',
  '#define HINK_D2_FLAGS_RESERVED_MASK 0xFCU',
  'HINK_D2_STATE_UNSET',
  'HINK_D2_STATE_RUNNING',
  'HINK_D2_STATE_STALE',
  'hink_d2_synced_epoch',
  'hink_d2_timezone_minutes',
  'hink_d2_uptime_at_sync',
  'hink_d2_uptime_seconds'
]) {
  assert(source.includes(required), `Missing required D2 source token: ${required}`);
}

const handler = bodyOf('hink_d2_time_handle');
assert(handler.includes('param->value[0] != 0xD2'), 'D2 opcode guard missing');
assert(handler.includes('subcmd == 0x00U'), 'D2 00 handler missing');
assert(handler.includes('subcmd == 0x01U'), 'D2 01 handler missing');
assert(handler.includes('param->length != HINK_D2_SET_TIME_LEN'), 'SET_TIME exact length check missing');
assert(handler.includes('param->length != HINK_D2_GET_STATUS_LEN'), 'GET_TIME_STATUS exact length check missing');
assert(handler.includes('flags & HINK_D2_FLAGS_RESERVED_MASK'), 'Reserved flags mask missing');
assert(handler.includes('epoch < HINK_D2_EPOCH_MIN'), 'Epoch minimum validation missing');
assert(handler.includes('epoch > HINK_D2_EPOCH_MAX'), 'Epoch maximum validation missing');
assert(handler.includes('timezone < -720'), 'Timezone min validation missing');
assert(handler.includes('timezone > 840'), 'Timezone max validation missing');
assert(handler.includes('hink_u32_le(&param->value[2])'), 'Epoch little-endian decode missing');
assert(handler.includes('(int16_t)hink_u16_le(&param->value[6])'), 'Timezone little-endian decode missing');
assert(handler.includes('hink_d2_notify(HINK_D2_RESULT_OK, HINK_D2_STATE_SYNCED)'), 'SET_TIME success notify missing');
assert(handler.includes('HINK_D2_RESULT_NOT_INIT'), 'NOT_INITIALIZED response missing');

const notify = bodyOf('hink_d2_notify');
assert(notify.includes('uint8_t msg[HINK_D2_STATUS_LEN]'), 'Status buffer length must be 15');
assert(notify.includes('msg[0] = 0xD2'), 'Status opcode missing');
assert(notify.includes('msg[1] = 0x81'), 'Status response byte missing');
assert(notify.includes('hink_put_u32_le(&msg[4]'), 'Epoch little-endian encode missing');
assert(notify.includes('hink_put_u16_le(&msg[8]'), 'Timezone little-endian encode missing');
assert(notify.includes('hink_put_u32_le(&msg[11]'), 'Uptime little-endian encode missing');

const clockUpdate = bodyOf('clock_update');
assert(clockUpdate.includes('hink_d2_uptime_seconds += (uint32_t)inc;'), 'Existing clock tick must advance D2 uptime');

const runtimeState = bodyOf('hink_d2_runtime_state');
assert(runtimeState.includes('HINK_D2_STALE_SECONDS'), 'STALE threshold missing');

assert(source.includes('hink_d2_time_handle(param)'), 'D2 handler must be routed in write path');
assert(!handler.includes('epd_screen_update'), 'D2 handler must not refresh panel');
assert(!handler.includes('app_easy_timer('), 'D2 handler must not create timers');
assert(!handler.includes('spi_flash'), 'D2 handler must not write flash');

for (const path of ['web', 'test.html']) {
  const diff = execFileSync('git', ['diff', '--name-only', '--', path], {
    cwd: root,
    encoding: 'utf8'
  }).trim();
  assert(diff === '', `${path} must not be modified`);
}

console.log('TASK D2B firmware time handler smoke PASS');
