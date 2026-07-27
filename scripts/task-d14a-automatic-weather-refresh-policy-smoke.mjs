import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const ROOT = 'D:/EINK/Clock';
const DOC = 'docs/web/TASK_D14A_AUTOMATIC_WEATHER_REFRESH_POLICY.md';
const CURRENT = 'docs/agent/CURRENT_STATE.md';
const NEXT = 'docs/agent/NEXT_ACTION.md';
const SMOKE = 'scripts/task-d14a-automatic-weather-refresh-policy-smoke.mjs';
const policy = fs.readFileSync(`${ROOT}/${DOC}`, 'utf8');
const current = fs.readFileSync(`${ROOT}/${CURRENT}`, 'utf8');
const next = fs.readFileSync(`${ROOT}/${NEXT}`, 'utf8');

assert.match(policy, /DESIGN COMPLETE - IMPLEMENTATION NOT STARTED/);
assert.match(policy, /Automatic weather is opt-in and defaults OFF/);
assert.match(policy, /must not request location automatically/);
assert.match(policy, /minimum successful weather-fetch interval is 30 minutes/);
assert.match(policy, /page remains open and connected/);
assert.match(policy, /local-day rollover/);
assert.match(policy, /enableHighAccuracy: true/);
assert.match(policy, /maximumAge: 0/);
assert.match(policy, /precipitationNow >= 0\.20 mm/);
assert.match(policy, /payload is unchanged and device status is already `FRESH`, skip both/);
assert.match(policy, /send `D2 08`[\s\S]*request the existing[\s\S]*`D2 02` render/);
assert.match(policy, /only after `D2 82 OK\/COMPLETE`/);
assert.match(policy, /One automatic retry is allowed after 60 seconds/);
assert.match(policy, /D2 `BUSY`[\s\S]*retries once/);
assert.match(policy, /No weather polling while disconnected or while the page is hidden/);
assert.match(policy, /Coordinates remain transient/);
assert.match(policy, /Daily weather remains RAM-only/);
assert.match(policy, /`D2 08` SET remains exactly 20 bytes/);
assert.match(policy, /`D2 09` GET remains exactly 2 bytes/);
assert.match(policy, /`D2 88` STATUS remains exactly 20 bytes/);
assert.match(policy, /TASK D14B - IMPLEMENT CONNECTED AUTO WEATHER REFRESH/);
assert.match(current, /TASK D14A[\s\S]*DESIGN COMPLETE/);
assert.match(next, /TASK D14B - IMPLEMENT CONNECTED AUTO WEATHER REFRESH/);

const changed = execFileSync(
  'git',
  ['status', '--porcelain', '--untracked-files=all'],
  { cwd: ROOT, encoding: 'utf8' },
).trimEnd().split(/\r?\n/).filter(Boolean)
  .map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([DOC, CURRENT, NEXT, SMOKE]);

assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.some(file => file.startsWith('firmware/')), 'firmware must remain unchanged');
assert.ok(!changed.some(file => file.startsWith('web/')), 'web runtime must remain unchanged');
assert.ok(!changed.includes('test.html'), 'test.html must remain unchanged');

console.log('TASK D14A automatic weather refresh policy smoke PASS');
