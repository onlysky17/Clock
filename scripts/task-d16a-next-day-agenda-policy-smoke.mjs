import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const ROOT = 'D:/EINK/Clock';
const DOC = 'docs/web/TASK_D16A_NEXT_DAY_AGENDA_AUTONOMY_POLICY.md';
const SMOKE = 'scripts/task-d16a-next-day-agenda-policy-smoke.mjs';
const policy = fs.readFileSync(`${ROOT}/${DOC}`, 'utf8');

assert.match(policy, /DESIGN COMPLETE - IMPLEMENTATION NOT STARTED/);
assert.match(policy, /fail-closed expiry with connected current-day refill/);
assert.match(policy, /previous daily `day_key` becomes expired/);
assert.match(policy, /forced day-rollover render omits both old agenda rows/);
assert.match(policy, /must never relabel yesterday's rows as today's agenda/);
assert.match(policy, /at most two timed events that are still running or upcoming/);
assert.match(policy, /No browser or firmware path may automatically initiate a BLE connection/);
assert.match(policy, /Detect a local-day-key change independently from the 15-minute fetch age/);
assert.match(policy, /Clear yesterday's agenda rows from the review model immediately/);
assert.match(policy, /Google polling remains paused/);
assert.match(policy, /If the day changed, discard cached rows and fetch today/);
assert.match(policy, /D2 epoch plus the D2 timezone[\s\S]*offset/);
assert.match(policy, /If browser and device day keys disagree, do not send agenda data/);
assert.match(policy, /A busy rejection does not create a retry loop/);
assert.match(policy, /Never send two identical daily payloads for the same local day/);
assert.match(policy, /Tokens remain in `sessionStorage`/);
assert.match(policy, /event data and titles remain page RAM-only/);
assert.match(policy, /`D2 08` SET remains exactly 20 bytes/);
assert.match(policy, /`D2 09` GET remains exactly 2 bytes/);
assert.match(policy, /`D2 88` STATUS remains exactly 20 bytes/);
assert.match(policy, /TASK D16B - IMPLEMENT NEXT-DAY AGENDA ROLLOVER/);
assert.match(policy, /No firmware build, pack, flash, or owner physical test is required for D16A/);

const changed = execFileSync(
  'git',
  ['status', '--porcelain', '--untracked-files=all'],
  { cwd: ROOT, encoding: 'utf8' },
).trimEnd().split(/\r?\n/).filter(Boolean)
  .map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([DOC, SMOKE]);

assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.some(file => file.startsWith('firmware/')), 'firmware must remain unchanged');
assert.ok(!changed.some(file => file.startsWith('web/clock-app/')), 'web runtime must remain unchanged');
assert.ok(!changed.includes('test.html'), 'test.html must remain unchanged');

console.log('TASK D16A next-day agenda autonomy policy smoke PASS');
