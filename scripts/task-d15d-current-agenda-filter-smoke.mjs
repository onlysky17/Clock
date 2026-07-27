import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { execFileSync } from 'node:child_process';

const ROOT='D:/EINK/Clock';
const WEB='web/clock-app/hl24a-canvas-e5.html';
const DOC='docs/web/TASK_D15B_GOOGLE_CALENDAR_AGENDA.md';
const SMOKE='scripts/task-d15d-current-agenda-filter-smoke.mjs';
const web=fs.readFileSync(`${ROOT}/${WEB}`,'utf8');
const script=web.match(/<script>([\s\S]*?)<\/script>/)?.[1]??'';

assert.ok(script,'web script missing');
assert.doesNotThrow(()=>new Function(script),'web JavaScript must parse');
assert.match(web,/D15D-CURRENT-AGENDA-20260727/);
assert.match(script,/const active=candidates\.filter\(event=>event\.end>now\)/);
assert.doesNotMatch(script,/const earlier=candidates/);
assert.match(script,/GOOGLE_AGENDA_CURRENT_INTERVAL_MS=30\*1000/);
assert.match(script,/setInterval\(\s*refreshGoogleAgendaForCurrentTime/);
assert.match(script,/googleAgendaAutoArmed/);
assert.match(script,/activeClockProfile!==2/);
assert.match(script,/automaticWeatherBlocked\(\)/);
assert.match(script,/await d2SetDailyContext\(packet\)/);
assert.match(script,/await d2RenderClockFromDevice\(\)/);
assert.match(script,/signature===googleAgendaDeviceSignature/);
assert.match(script,/googleAgendaAutoArmed=true/);

const pureBlock=script.match(
  /function normalizeGoogleAgendaLabel[\s\S]*?(?=function applyGoogleAgendaEvents)/
)?.[0]??'';
const context={Date,Set};
vm.createContext(context);
vm.runInContext(`${pureBlock};this.selectGoogleAgendaEvents=selectGoogleAgendaEvents;`,context);

const at=value=>({dateTime:value});
const event=(summary,start,end)=>({
  status:'confirmed',
  summary,
  start:at(start),
  end:at(end)
});
const now=new Date('2026-07-27T15:00:00+07:00');
const selected=context.selectGoogleAgendaEvents([
  event('Họp cũ','2026-07-27T13:30:00+07:00','2026-07-27T14:00:00+07:00'),
  event('Đang họp','2026-07-27T14:30:00+07:00','2026-07-27T15:30:00+07:00'),
  event('Khám bệnh','2026-07-27T16:00:00+07:00','2026-07-27T16:30:00+07:00'),
  event('Tập thể dục','2026-07-27T18:00:00+07:00','2026-07-27T19:00:00+07:00')
],now);
assert.equal(
  JSON.stringify(selected.map(item=>item.summary)),
  JSON.stringify(['Đang họp','Khám bệnh']),
  'must keep ongoing and nearest upcoming events only'
);
assert.equal(
  context.selectGoogleAgendaEvents([
    event('Họp cũ','2026-07-27T13:30:00+07:00','2026-07-27T14:00:00+07:00')
  ],now).length,
  0,
  'ended event must not be used as fallback'
);

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

console.log('TASK D15D current agenda filter smoke PASS');
