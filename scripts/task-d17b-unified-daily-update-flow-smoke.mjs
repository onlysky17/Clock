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

assert.match(web,/id="unifiedDailyUpdate"[^>]*>Cập nhật màn hình hôm nay<\/button>/);
assert.ok(
  web.indexOf('id="unifiedDailyUpdate"')<web.indexOf("advanced.id='advancedPanel'"),
  'unified action must stay outside advanced controls'
);
for(const [id,label] of [
  ['unifiedWeatherStep','Thời tiết'],
  ['unifiedCalendarStep','Lịch hôm nay'],
  ['unifiedTimeStep','Đồng bộ giờ'],
  ['unifiedApplyStep','Áp dụng lên màn']
]){
  assert.match(web,new RegExp(`id="${id}"[\\s\\S]*?<span>${label}<\\/span>`));
}
assert.match(web,/unifiedDailySteps" role="status" aria-live="polite"/);
assert.match(web,/id="unifiedDailyResult"[^>]*role="status" aria-live="polite"/);

assert.match(script,/let unifiedDailyUpdateRunning=false,unifiedDailyUpdatePromise=null/);
const unifiedBlock=script.slice(
  script.indexOf('async function runUnifiedDailyUpdate'),
  script.indexOf('async function runD2Flow')
);
assert.ok(unifiedBlock,'unified flow missing');
assert.match(unifiedBlock,/if\(unifiedDailyUpdatePromise\)return unifiedDailyUpdatePromise/);
assert.match(unifiedBlock,/if\(!server\?\.connected\)/);
assert.match(unifiedBlock,/identityCompatibility!=='compatible'/);
assert.match(unifiedBlock,/if\(unifiedDailyUpdateConflicting\(\)\)/);
assert.ok(!/\bconnect\s*\(/.test(unifiedBlock),'unified flow must not auto-connect');
assert.ok(!unifiedBlock.includes('alert('),'optional failures must not alert');

const controlsBlock=script.slice(
  script.indexOf('function controls()'),
  script.indexOf('function updateProductState')
);
assert.match(controlsBlock,/const locked=conflictingLocked\|\|unifiedDailyUpdateRunning/);
assert.match(controlsBlock,/\$\('unifiedDailyUpdate'\)\.disabled=!connected\|\|[\s\S]*identityCompatibility!=='compatible'[\s\S]*conflictingLocked\|\|[\s\S]*unifiedDailyUpdateRunning/);
const autoBlocked=script.slice(
  script.indexOf('function automaticWeatherBlocked()'),
  script.indexOf('function automaticWeatherEligible()')
);
assert.match(autoBlocked,/unifiedDailyUpdateRunning/);

const weatherIndex=unifiedBlock.indexOf('await refreshDailyWeatherFromPhone()');
const calendarIndex=unifiedBlock.indexOf('prepareUnifiedGoogleAgenda(new Date())');
const timeIndex=unifiedBlock.indexOf('await d2SetCurrentTime()');
const applyIndex=unifiedBlock.indexOf("await d2ApplyClockProfile({refreshWeather:false})");
assert.ok(
  weatherIndex>=0&&weatherIndex<calendarIndex&&calendarIndex<timeIndex&&timeIndex<applyIndex,
  'unified order must be weather, calendar, time, apply'
);
assert.match(unifiedBlock,/\$\('dailyWeatherEnabled'\)\.checked=false/);
assert.match(unifiedBlock,/degraded\.push\('thời tiết'\)/);
assert.match(unifiedBlock,/if\(googleCalendarToken\)/);
assert.match(unifiedBlock,/fetchGoogleCalendarToday\(\{background:false,throwOnError:true\}\)/);
assert.match(unifiedBlock,/agendaState\.hasCurrentDayCache\?'Dùng lịch đã lưu hôm nay':'Bỏ qua \(không dùng lịch\)'/);
assert.ok(!unifiedBlock.includes('requestGoogleCalendarAccess'),'unified flow must not request Google login');
assert.ok(
  !/else\{\s*degraded\.push\('lịch'\);\s*setUnifiedDailyStep\(\s*'unifiedCalendarStep'/.test(unifiedBlock),
  'missing Google connection must be an optional skip, not degraded'
);
assert.match(unifiedBlock,/degraded\.push\('lịch'\)/);

const agendaPrep=script.slice(
  script.indexOf('function prepareUnifiedGoogleAgenda'),
  script.indexOf('async function runUnifiedDailyUpdate')
);
assert.match(agendaPrep,/googleAgendaFetchedDayKey===currentDayKey/);
assert.match(agendaPrep,/googleCalendarItems=\[\]/);
assert.match(agendaPrep,/googleAgendaUiSignature=''/);
assert.match(agendaPrep,/googleAgendaDeviceSignature=''/);
assert.match(agendaPrep,/applyGoogleAgendaEvents\(\[\]\)/);

assert.match(unifiedBlock,/if\(timeStatus\.result!==0x00\)/);
assert.match(unifiedBlock,/selectClockProfile\(2\)/);
assert.equal(
  (unifiedBlock.match(/d2RenderClockFromDevice\(/g)||[]).length,
  0,
  'unified flow must not directly render'
);
const applyBlock=script.slice(
  script.indexOf('async function d2ApplyClockProfile'),
  script.indexOf('async function d2GetClockPreferences')
);
assert.match(applyBlock,/\{refreshWeather=true\}=\{\}/);
assert.match(applyBlock,/if\(refreshWeather&&\$\('dailyAutoWeather'\)\.checked\)/);
assert.equal(
  (applyBlock.match(/d2RenderClockFromDevice\(/g)||[]).length,
  1,
  'profile apply must perform exactly one physical render request'
);

assert.match(script,/async function fetchGoogleCalendarToday\(\{background=false,throwOnError=false\}=\{\}\)/);
assert.match(script,/if\(throwOnError\)throw error/);
assert.match(script,/packet=new Uint8Array\(20\)/);
assert.match(script,/function buildD2GetDailyPacket\(\)\{\s*return Uint8Array\.of\(0xD2,0x09\)/);
assert.match(script,/bytes\.length!==20\|\|bytes\[0\]!==0xD2\|\|bytes\[1\]!==0x88/);
assert.match(script,/precipitationNow>=0\.2/);
assert.match(script,/function googleAgendaNeedsDayRollover/);
assert.match(testHtml,/web\/clock-app\/hl24a-canvas-e5\.html/);

const changed=execFileSync(
  'git',
  ['status','--porcelain','--untracked-files=all'],
  {cwd:root,encoding:'utf8'}
).trimEnd().split(/\r?\n/).filter(Boolean)
  .map(line=>line.slice(3).replace(/\\/g,'/'));
const allowed=new Set([
  'scripts/task-d17b-unified-daily-update-flow-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
]);
assert.ok(changed.every(file=>allowed.has(file)),`unexpected dirty file: ${changed.join(', ')}`);
assert.ok(!changed.some(file=>file.startsWith('firmware/')),'firmware changed');
assert.ok(!changed.includes('test.html'),'test.html changed');
assert.ok(!changed.some(file=>file.startsWith('docs/')),'docs changed');

console.log('TASK D17B unified daily update flow smoke PASS');
