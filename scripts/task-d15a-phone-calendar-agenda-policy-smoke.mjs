import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const policyPath = resolve(
  root,
  'docs/web/TASK_D15A_PHONE_CALENDAR_AGENDA_POLICY.md'
);
const policy = readFileSync(policyPath, 'utf8');

const required = [
  'DESIGN COMPLETE - NO RUNTIME CHANGE',
  'local iCalendar file import',
  'Chọn lịch .ics',
  '<input type="file">',
  'Maximum selected file size: `1 MiB`',
  '`DTSTART`',
  '`DTEND`',
  '`SUMMARY`',
  '`STATUS:CANCELLED`',
  'Exclude all-day entries',
  'Send at most two rows',
  'three-character `A-Z` / `0-9` label',
  'owner reviews and applies it',
  '`RRULE` expansion is not expanded in the MVP',
  'No `localStorage`, IndexedDB, cookie, SPI, or NVDS persistence',
  'Reloading or closing the page clears imported calendar data',
  'Google Calendar OAuth',
  'TASK D15B - IMPLEMENT LOCAL ICS AGENDA IMPORT',
  'https://onlysky17.github.io/Clock/test.html',
];

for (const text of required) {
  assert.ok(policy.includes(text), `missing policy contract: ${text}`);
}

assert.match(
  policy,
  /cannot directly read every calendar stored by Android or\s+iOS/,
  'policy must state the browser calendar-access limitation'
);
assert.match(
  policy,
  /Calendar content is not uploaded/,
  'policy must keep imported calendar content local'
);
assert.match(
  policy,
  /Existing D2 daily SET\/GET\/status packet lengths and command IDs remain exact/,
  'policy must preserve the D2 contract'
);
assert.match(
  policy,
  /No firmware build, pack, flash, or physical panel test is required/,
  'D15A must remain design-only'
);

const status = execFileSync(
  'git',
  ['status', '--porcelain', '--untracked-files=all'],
  { cwd: root, encoding: 'utf8' }
)
  .trimEnd()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.slice(3).replaceAll('\\', '/'))
  .sort();

const allowed = [
  'docs/web/TASK_D15A_PHONE_CALENDAR_AGENDA_POLICY.md',
  'scripts/task-d15a-phone-calendar-agenda-policy-smoke.mjs',
].sort();

assert.ok(
  status.every((path) => allowed.includes(path)),
  `unexpected dirty scope: ${status.join(', ')}`
);

console.log('TASK D15A phone calendar agenda policy smoke PASS');
