import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';

const root=path.resolve(import.meta.dirname,'..');
const webPath=path.join(root,'web','clock-app','hl24a-canvas-e5.html');
const web=fs.readFileSync(webPath,'utf8');
const testHtml=fs.readFileSync(path.join(root,'test.html'),'utf8');
const script=web.match(/<script>([\s\S]*?)<\/script>/)?.[1]??'';

assert.ok(script,'web script missing');
assert.doesNotThrow(()=>new Function(script),'web JavaScript must parse');
assert.match(web,/D16B-DAY-ROLLOVER-20260728/);
assert.match(script,/googleAgendaFetchedDayKey=-1,googleAgendaUiDayKey=-1/);
assert.match(script,/function googleAgendaNeedsDayRollover\(fetchedDayKey,date=new Date\(\)\)/);
assert.match(script,/fetchedDayKey>=0&&fetchedDayKey!==dailyDayKey\(date\)/);
assert.match(script,/async function refreshGoogleAgendaForCurrentTime\(\{forceRolloverRetry=false\}=\{\}\)/);

const fixtureDayKey=date=>Math.floor(
  (Date.UTC(date.getFullYear(),date.getMonth(),date.getDate())-Date.UTC(2024,0,1))/86400000
);
const beforeMidnight=new Date(2026,6,27,23,59,59);
const afterMidnight=new Date(2026,6,28,0,0,1);
assert.equal(fixtureDayKey(afterMidnight),fixtureDayKey(beforeMidnight)+1);
assert.notEqual(
  `${fixtureDayKey(beforeMidnight)}:`,
  `${fixtureDayKey(afterMidnight)}:`,
  'empty agendas on consecutive days still need distinct device keys'
);

const refreshBlock=script.slice(
  script.indexOf('async function refreshGoogleAgendaForCurrentTime'),
  script.indexOf('async function waitForGoogleIdentity')
);
assert.ok(
  refreshBlock.indexOf('googleAgendaNeedsDayRollover')<
  refreshBlock.indexOf('Date.now()-googleCalendarLastFetchAt'),
  'day rollover must be checked independently before the 15-minute age gate'
);
assert.match(refreshBlock,/googleCalendarItems=\[\];\s*applyGoogleAgendaEvents\(\[\]\)/);
assert.match(refreshBlock,/googleAgendaUiDayKey=currentDayKey/);
assert.match(refreshBlock,/if\(!googleCalendarToken\|\|document\.visibilityState!=='visible'\)return/);
assert.match(refreshBlock,/googleAgendaRolloverAttemptDayKey===currentDayKey/);
assert.match(refreshBlock,/Date\.now\(\)-googleAgendaRolloverAttemptAt<GOOGLE_CALENDAR_REFRESH_INTERVAL_MS/);
assert.match(refreshBlock,/if\(rolloverRecentlyAttempted&&!forceRolloverRetry\)return/);
assert.match(refreshBlock,/await fetchGoogleCalendarToday\(\{background:true\}\);\s*return/);
assert.ok(!refreshBlock.includes('connectDevice('),'rollover must never auto-connect BLE');

assert.match(script,/function googleAgendaDeviceKey\(events,date=new Date\(\)\)\{\s*return `\$\{dailyDayKey\(date\)\}:\$\{googleAgendaSignature\(events\)\}`/);
assert.match(refreshBlock,/const deviceKey=googleAgendaDeviceKey\(events,now\)/);
assert.match(refreshBlock,/if\(!googleAgendaAutoArmed\|\|deviceKey===googleAgendaDeviceSignature\)return/);
assert.match(refreshBlock,/googleAgendaDeviceSignature=deviceKey/);

const fetchBlock=script.slice(
  script.indexOf('async function fetchGoogleCalendarToday'),
  script.indexOf('async function disconnectGoogleCalendar')
);
assert.match(fetchBlock,/const queryNow=new Date\(\);\s*const queryDayKey=dailyDayKey\(queryNow\)/);
assert.match(fetchBlock,/googleCalendarDayBounds\(queryNow\)/);
assert.match(fetchBlock,/if\(dailyDayKey\(responseNow\)!==queryDayKey\)/);
assert.match(fetchBlock,/setTimeout\(\(\)=>fetchGoogleCalendarToday\(\{background:true\}\),0\)/);
assert.match(fetchBlock,/googleAgendaFetchedDayKey=queryDayKey/);
assert.match(fetchBlock,/googleAgendaUiDayKey=queryDayKey/);

assert.match(
  script,
  /visibilitychange[\s\S]*refreshGoogleAgendaForCurrentTime\(\{forceRolloverRetry:true\}\)/
);
assert.match(script,/packet=new Uint8Array\(20\)/);
assert.match(script,/packet\[0\]=0xD2;\s*packet\[1\]=0x08/);
assert.match(script,/bytes\.length!==20\|\|bytes\[0\]!==0xD2\|\|bytes\[1\]!==0x88/);
assert.match(testHtml,/web\/clock-app\/hl24a-canvas-e5\.html/);

const changed=execFileSync(
  'git',
  ['status','--porcelain','--untracked-files=all'],
  {cwd:root,encoding:'utf8'}
).trimEnd().split(/\r?\n/).filter(Boolean)
  .map(line=>line.slice(3).replace(/\\/g,'/'));
const allowed=new Set([
  'scripts/task-d16b-next-day-agenda-rollover-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
]);
assert.ok(changed.every(file=>allowed.has(file)),`unexpected dirty file: ${changed.join(', ')}`);
assert.ok(!changed.some(file=>file.startsWith('firmware/')),'firmware changed');
assert.ok(!changed.includes('test.html'),'test.html changed');

console.log('TASK D16B next-day agenda rollover smoke PASS');
