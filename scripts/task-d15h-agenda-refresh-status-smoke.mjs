import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';

const root=path.resolve(import.meta.dirname,'..');
const webPath=path.join(root,'web','clock-app','hl24a-canvas-e5.html');
const docsPath=path.join(root,'docs','web','TASK_D15B_GOOGLE_CALENDAR_AGENDA.md');
const web=fs.readFileSync(webPath,'utf8');
const docs=fs.readFileSync(docsPath,'utf8');
const script=web.match(/<script>([\s\S]*?)<\/script>/)?.[1]??'';

const assert=(condition,message)=>{
  if(!condition)throw new Error(message);
};

assert(web.includes('D15H-AGENDA-STATUS-20260727'),'D15H web identity missing');
assert(script,'web script missing');
try{
  new Function(script);
}catch(error){
  throw new Error(`web JavaScript must parse: ${error.message}`);
}
assert(web.includes('id="googleCalendarRefreshStatus"'),'visible refresh status missing');
assert(web.includes('function updateGoogleCalendarRefreshStatus'),'refresh status helper missing');
assert(web.includes('C\\u1eadp nh\\u1eadt g\\u1ea7n nh\\u1ea5t ${time}'),'last refresh time missing');
assert(web.includes('T\\u1ef1 l\\u00e0m m\\u1edbi t\\u1ed1i \\u0111a m\\u1ed7i 15 ph\\u00fat'),'15-minute status missing');
assert(web.includes("document.visibilityState!=='visible'"),'hidden-page state missing');
assert(
  /document\.addEventListener\('visibilitychange',\(\)=>\{\r?\n\s+updateGoogleCalendarRefreshStatus\(\);/.test(web),
  'visibility refresh missing'
);
assert(web.includes("if(background&&(!googleCalendarToken||document.visibilityState!=='visible'))return;"),'background safety guard missing');
assert(/if\(background\)return;\r?\n\s+await requestGoogleCalendarToken\(\);/.test(web),'background OAuth guard missing');
assert(docs.includes('D15H shows the automatic-refresh state'),'D15H docs missing');
assert(docs.includes('last successful fetch time'),'last-fetch docs missing');
assert(!web.includes('t\\u1ea3i l\\u1ea1i trang s\\u1ebd x\\u00f3a'),'obsolete reload privacy text remains');

const status=execFileSync(
  'git',
  ['status','--porcelain','--untracked-files=all'],
  {cwd:root,encoding:'utf8'}
).trimEnd().split(/\r?\n/).filter(Boolean)
  .map(line=>line.slice(3).replace(/\\/g,'/'));
const allowed=new Set([
  'docs/web/TASK_D15B_GOOGLE_CALENDAR_AGENDA.md',
  'scripts/task-d15h-agenda-refresh-status-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
]);
assert(status.every(file=>allowed.has(file)),`unexpected dirty file: ${status.join(', ')}`);
assert(!status.some(file=>file.startsWith('firmware/')),'firmware changed');
assert(!status.includes('test.html'),'test.html changed');

console.log('TASK D15H agenda refresh status smoke PASS');
