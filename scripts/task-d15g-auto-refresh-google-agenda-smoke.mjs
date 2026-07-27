import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const ROOT='D:/EINK/Clock';
const WEB='web/clock-app/hl24a-canvas-e5.html';
const DOC='docs/web/TASK_D15B_GOOGLE_CALENDAR_AGENDA.md';
const SMOKE='scripts/task-d15g-auto-refresh-google-agenda-smoke.mjs';
const web=fs.readFileSync(`${ROOT}/${WEB}`,'utf8');
const doc=fs.readFileSync(`${ROOT}/${DOC}`,'utf8');
const script=web.match(/<script>([\s\S]*?)<\/script>/)?.[1]??'';

assert.ok(script,'web script missing');
assert.doesNotThrow(()=>new Function(script),'web JavaScript must parse');
assert.match(web,/D15G-AUTO-AGENDA-20260727/);
assert.match(script,/GOOGLE_CALENDAR_REFRESH_INTERVAL_MS=15\*60\*1000/);
assert.match(script,/Date\.now\(\)-googleCalendarLastFetchAt>=GOOGLE_CALENDAR_REFRESH_INTERVAL_MS/);
assert.match(script,/fetchGoogleCalendarToday\(\{background:true\}\)/);
assert.match(script,/if\(background&&\(!googleCalendarToken\|\|document\.visibilityState!=='visible'\)\)return/);
assert.match(script,/if\(background\)return;\s*await requestGoogleCalendarToken\(\)/);
assert.match(script,/googleAgendaAutoArmed=background\?keepAutoArmed:false/);
assert.match(script,/if\(background&&googleAgendaAutoArmed\)\{\s*setTimeout\(refreshGoogleAgendaForCurrentTime,0\)/);
assert.match(script,/document\.visibilityState==='visible'/);
assert.match(doc,/at most once every 15 minutes/);
assert.match(doc,/never opens OAuth, never auto-connects BLE/);

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

console.log('TASK D15G auto-refresh Google agenda smoke PASS');
