import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const root = 'D:/EINK/Clock';
const firmwarePath = path.join(root, 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c');
const webPath = path.join(root, 'web/clock-app/hl24a-canvas-e5.html');
const firmware = readFileSync(firmwarePath, 'utf8');
const web = readFileSync(webPath, 'utf8');
const webScript = web.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';

const includes = (text, value, message) => assert.ok(text.includes(value), message);
assert.ok(webScript, 'web script block missing');
assert.doesNotThrow(() => new Function(webScript), 'web JavaScript must parse');

includes(firmware, '#define HINK_D2_IDENTITY_LEN        2U', 'D2 03 request length must be 2');
includes(firmware, '#define HINK_D2_IDENTITY_STATUS_LEN 16U', 'D2 83 response length must be 16');
includes(firmware, '#define HINK_D8A_SOURCE_ID       0xD8A00001UL', 'stable D8A source ID missing');
includes(firmware, "msg[4] = 'D';", 'firmware identity prefix missing');
includes(firmware, "msg[7] = '1';", 'firmware identity revision missing');
includes(firmware, 'msg[12] = health;', 'health flags missing');
includes(firmware, 'msg[13] = (hink_d2_synced_epoch == 0UL)', 'time state missing');
includes(firmware, 'msg[14] = hink_d2_render_state;', 'render state missing');
includes(firmware, 'msg[15] = hink_e6_state;', 'refresh state missing');

const identityHandler = firmware.match(/if \(subcmd == 0x03U\)[\s\S]*?return 1U;\s*}/)?.[0] ?? '';
assert.ok(identityHandler, 'D2 03 handler missing');
includes(identityHandler, 'param->length == HINK_D2_IDENTITY_LEN', 'D2 03 exact length guard missing');
includes(identityHandler, 'hink_d2_identity_notify', 'D2 03 must notify identity');

const identityNotify = firmware.match(/static void hink_d2_identity_notify\(uint8_t result\)\s*\n\{[\s\S]*?\n}/)?.[0] ?? '';
assert.ok(identityNotify, 'D2 identity notify function missing');
includes(identityNotify, 'msg[1] = 0x83;', 'D2 83 opcode missing');
includes(identityNotify, 'hink_e4_notify_bytes(msg, HINK_D2_IDENTITY_STATUS_LEN);', 'identity notify path missing');
assert.ok(!/epd_\w+\s*\(|hink_e5_\w+\s*\(|hink_e6_refresh_handle\s*\(/.test(identityNotify), 'identity query must not call EPD/E5/E6 flow');

includes(web, 'Uint8Array.of(0xD2,0x03)', 'web D2 03 request missing');
includes(web, 'bytes.length!==16||bytes[0]!==0xD2||bytes[1]!==0x83', 'web must parse exact D2 83 packet');
includes(web, "expectedFirmware:'D8A00001'", 'expected D8A identity marker missing');
includes(web, 'id="actualFirmware"', 'visible actual firmware field missing');
includes(web, 'id="actualSourceId"', 'visible source ID field missing');
includes(web, 'id="actualHealth"', 'visible health field missing');
includes(web, 'await d2GetDeviceIdentity();', 'identity must be queried after BLE connect');
includes(web, "$('d2GetIdentity').onclick=()=>runD2Flow(d2GetDeviceIdentity);", 'manual identity query control missing');
includes(web, "a[1]===0x81&&a[2]===0x01", 'legacy firmware unsupported fallback missing');
includes(web, "$('actualFirmware').textContent='Không hỗ trợ';", 'legacy firmware must not become a false product error');
includes(web, 'function resolveProductState(', 'D6B Product Mode state mapping must remain');
includes(web, "advanced.className='advanced';", 'advanced section must remain closed by default');

const changed = execFileSync('git', ['diff', '--name-only'], { cwd: root, encoding: 'utf8' })
  .trim().split(/\r?\n/).filter(Boolean).map(value => value.replaceAll('\\', '/'));
const allowed = new Set([
  'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c',
  'web/clock-app/hl24a-canvas-e5.html',
  'scripts/task-d8a-device-identity-health-smoke.mjs'
]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope tracked change: ${changed.join(', ')}`);
assert.ok(!changed.includes('test.html'), 'canonical redirect must remain unchanged');

console.log('TASK D8A device identity and health smoke PASS');
