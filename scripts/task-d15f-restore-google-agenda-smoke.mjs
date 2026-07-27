import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const ROOT='D:/EINK/Clock';
const WEB='web/clock-app/hl24a-canvas-e5.html';
const DOC='docs/web/TASK_D15B_GOOGLE_CALENDAR_AGENDA.md';
const SMOKE='scripts/task-d15f-restore-google-agenda-smoke.mjs';
const web=fs.readFileSync(`${ROOT}/${WEB}`,'utf8');
const doc=fs.readFileSync(`${ROOT}/${DOC}`,'utf8');
const script=web.match(/<script>([\s\S]*?)<\/script>/)?.[1]??'';

assert.ok(script,'web script missing');
assert.doesNotThrow(()=>new Function(script),'web JavaScript must parse');
assert.match(web,/D15F-RESTORE-AGENDA-20260727/);
assert.match(script,/else if\(restoreGoogleCalendarSession\(\)\)\{\s*setGoogleCalendarStatus\([\s\S]*?setTimeout\(fetchGoogleCalendarToday,0\)/);
assert.match(script,/async function fetchGoogleCalendarToday\(\)/);
assert.match(script,/calendar\/v3\/calendars\/primary\/events/);
assert.match(script,/applyGoogleAgendaEvents\(events\)/);
assert.match(script,/googleAgendaAutoArmed=false/);
assert.match(script,/if\(response\.status===401\)clearGoogleCalendarSession\(\)/);

const restoreBlock=script.match(
  /else if\(restoreGoogleCalendarSession\(\)\)\{([\s\S]*?)\n\}/
)?.[1]??'';
assert.ok(restoreBlock,'same-tab restore block missing');
assert.doesNotMatch(restoreBlock,/send|writeChar|requestD2Render|applyDailyProfile/i);
assert.match(doc,/never sends BLE\s+data or refreshes the panel/);
assert.match(doc,/Event titles remain RAM-only/);

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

console.log('TASK D15F restore Google agenda smoke PASS');
