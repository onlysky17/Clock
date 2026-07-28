import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const policyPath =
  'docs/web/TASK_D17A_UNIFIED_DAILY_UPDATE_FLOW_POLICY.md';
const nextPath = 'docs/agent/NEXT_ACTION.md';

const policy = fs.readFileSync(policyPath, 'utf8');
const next = fs.readFileSync(nextPath, 'utf8');

function need(text, pattern, label) {
  assert.match(text, pattern, label);
}

need(
  policy,
  /Cập nhật màn hình hôm nay/,
  'primary owner action missing'
);
need(
  policy,
  /The web must never auto-connect BLE/,
  'no-auto-connect contract missing'
);
need(
  policy,
  /Canonical Execution Order/,
  'execution order missing'
);
need(
  policy,
  /Weather Failure Policy/,
  'weather failure policy missing'
);
need(
  policy,
  /Google Calendar Failure Policy/,
  'calendar failure policy missing'
);
need(
  policy,
  /exactly one final visible panel render/i,
  'single visible render contract missing'
);
need(
  policy,
  /Previous-day agenda rows must be cleared immediately/,
  'previous-day agenda guard missing'
);
need(
  policy,
  /Existing technical controls remain available under Advanced/,
  'advanced-controls preservation missing'
);
need(
  policy,
  /TASK D17B - IMPLEMENT UNIFIED DAILY UPDATE FLOW/,
  'D17B next task missing'
);
need(
  policy,
  /D17B must not modify firmware, BLE protocol, `test\.html`/,
  'D17B scope guard missing'
);

need(
  next,
  /TASK D17B - IMPLEMENT UNIFIED DAILY UPDATE FLOW/,
  'NEXT_ACTION does not point to D17B'
);
need(
  next,
  /Do not modify firmware, BLE protocol, `test\.html`/,
  'NEXT_ACTION runtime guard missing'
);

const allowed = new Set([
  policyPath,
  'scripts/task-d17a-unified-daily-update-flow-policy-smoke.mjs',
  nextPath
]);

const status = execFileSync(
  'git',
  ['status', '--porcelain=v1', '--untracked-files=all'],
  { encoding: 'utf8' }
)
  .trimEnd()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.slice(3).replaceAll('\\', '/'));

assert.deepEqual(
  [...status].sort(),
  [...allowed].sort(),
  'D17A changed-file scope mismatch'
);

console.log(
  'TASK D17A unified daily update flow policy smoke PASS'
);