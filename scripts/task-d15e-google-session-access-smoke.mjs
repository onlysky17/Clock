import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const ROOT='D:/EINK/Clock';
const WEB='web/clock-app/hl24a-canvas-e5.html';
const DOC='docs/web/TASK_D15B_GOOGLE_CALENDAR_AGENDA.md';
const SMOKE='scripts/task-d15e-google-session-access-smoke.mjs';
const web=fs.readFileSync(`${ROOT}/${WEB}`,'utf8');
const doc=fs.readFileSync(`${ROOT}/${DOC}`,'utf8');
const script=web.match(/<script>([\s\S]*?)<\/script>/)?.[1]??'';

assert.ok(script,'web script missing');
assert.doesNotThrow(()=>new Function(script),'web JavaScript must parse');
assert.match(web,/D15E-GOOGLE-SESSION-20260727/);
assert.match(script,/GOOGLE_CALENDAR_SESSION_KEY='eink\.google-calendar\.token\.v1'/);
assert.match(script,/sessionStorage\.setItem\(GOOGLE_CALENDAR_SESSION_KEY/);
assert.match(script,/sessionStorage\.getItem\(GOOGLE_CALENDAR_SESSION_KEY\)/);
assert.match(script,/sessionStorage\.removeItem\(GOOGLE_CALENDAR_SESSION_KEY\)/);
assert.doesNotMatch(script,/localStorage/);
assert.match(script,/response\.expires_in/);
assert.match(script,/lifetime-60000/,'expiry safety margin missing');
assert.match(script,/if\(response\.status===401\)clearGoogleCalendarSession\(\)/);
assert.match(script,/const accessToken=googleCalendarToken;\s*clearGoogleCalendarSession\(\)/);
assert.match(script,/else if\(restoreGoogleCalendarSession\(\)\)/);
assert.match(doc,/Calendar events and titles remain RAM-only/);
assert.match(doc,/does not bypass Google's OAuth/);

const changed=execFileSync(
  'git',
  ['status','--porcelain','--untracked-files=all'],
  {cwd:ROOT,encoding:'utf8'}
).trimEnd().split(/\r?\n/).filter(Boolean)
  .map(line=>line.slice(3).replace(/\\/g,'/'));
const allowed=new Set([WEB,DOC,SMOKE]);
assert.ok(changed.every(file=>allowed.has(file)),`out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.some(file=>file.startsWith('firmware/')),'firmware changed');
assert.ok(!changed.includes('test.html'),'test.html changed');

console.log('TASK D15E Google session access smoke PASS');
