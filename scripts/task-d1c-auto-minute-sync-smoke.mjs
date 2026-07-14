import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const htmlPath = join(root, 'web', 'clock-app', 'hl24a-canvas-e5.html');
const html = readFileSync(htmlPath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(name) {
  const start = html.indexOf(`function ${name}(`);
  assert(start >= 0, `Missing function ${name}`);
  const open = html.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < html.length; i += 1) {
    if (html[i] === '{') depth += 1;
    if (html[i] === '}') depth -= 1;
    if (depth === 0) return html.slice(open + 1, i);
  }
  throw new Error(`Unclosed function ${name}`);
}

assert(html.includes('id="autoSync" type="checkbox"'), 'Missing Auto sync checkbox');
assert(html.includes('Tự đồng bộ khi phút đổi'), 'Missing Auto sync label');
assert(!html.match(/id="autoSync"[^>]*checked/), 'Auto sync must default OFF');
assert(html.includes('aria-live="polite"'), 'Auto status must use aria-live');
assert(html.includes('Đồng bộ giờ lên màn'), 'D1B one-tap button must remain');
assert(html.includes('async function syncClockToPanel()'), 'D1B one-tap flow must remain');

const minuteBody = functionBody('minuteKey');
for (const required of ['getFullYear()', 'getMonth()+1', 'getDate()', 'getHours()', 'getMinutes()']) {
  assert(minuteBody.includes(required), `minuteKey missing ${required}`);
}

const startBody = functionBody('startAutoSync');
assert(startBody.includes('autoArmedMinuteKey=minuteKey();'), 'First enable must arm current minute');
assert(startBody.includes("setAutoStatus('Đang chờ phút mới'"), 'First enable must wait for next minute');
assert(startBody.includes('setInterval(checkAutoSyncMinute,1000)'), 'Auto sync check interval must be 1000ms');
assert(startBody.includes('if(!autoSyncTimer)'), 'Must not create multiple intervals');
assert(!startBody.includes('syncClockToPanel'), 'First enable must not send immediately');
assert(!startBody.includes('sendFramebuffer'), 'First enable must not send E5 immediately');
assert(!startBody.includes('refreshPanel'), 'First enable must not send E6 immediately');

const checkBody = functionBody('checkAutoSyncMinute');
assert(checkBody.includes('if(!server?.connected)'), 'Auto sync must guard BLE connected');
assert(checkBody.includes('if(busy||e6Running||oneTapRunning)return;'), 'Auto sync must guard busy/re-entry');
assert(checkBody.includes('currentMinuteKey===autoArmedMinuteKey'), 'Auto sync must wait for a new minute');
assert(checkBody.includes('currentMinuteKey===lastAutoSentMinuteKey'), 'Auto sync must not resend same successful minute');
assert(checkBody.includes('await syncClockToPanel();'), 'Auto sync must reuse D1B one-tap flow');
assert(checkBody.indexOf('await syncClockToPanel();') < checkBody.indexOf('lastAutoSentMinuteKey=currentMinuteKey;'), 'Must record sent minute only after sync completes');
assert(checkBody.includes("stopAutoSync('Lỗi, đã tắt Auto sync','bad')"), 'Auto sync must turn off on error');

const stopBody = functionBody('stopAutoSync');
assert(stopBody.includes('autoSyncEnabled=false;'), 'stopAutoSync must disable flag');
assert(stopBody.includes("$('autoSync').checked=false;"), 'stopAutoSync must uncheck control');
assert(stopBody.includes('clearInterval(autoSyncTimer);'), 'stopAutoSync must clear interval');
assert(stopBody.includes('autoSyncTimer=0;'), 'stopAutoSync must reset interval handle');

assert(html.includes("stopAutoSync('Auto sync đang tắt');"), 'Disconnect must turn Auto sync OFF');
assert(html.includes("$('autoSync').onchange=toggleAutoSync;"), 'Auto sync onchange handler missing');
assert(!html.includes('setInterval(') || html.includes('setInterval(checkAutoSyncMinute,1000)'), 'Only minute-check interval is allowed');

const initBlock = html.slice(html.indexOf("$('clearWhite').onclick"), html.indexOf('</script>'));
assert(initBlock.includes('drawCurrentClock();'), 'Page load should draw preview once');
assert(!initBlock.includes('syncClockToPanel();'), 'Page load must not auto sync');
assert(!initBlock.includes('sendFramebuffer();'), 'Page load must not auto send E5');
assert(!initBlock.includes('refreshPanel();'), 'Page load must not auto send E6');

const script = html.match(/<script>([\s\S]*)<\/script>/);
assert(script, 'Missing inline script');
new Function(script[1]);

for (const path of ['test.html', 'firmware', 'docs']) {
  const diff = execFileSync('git', ['diff', '--name-only', '--', path], {
    cwd: root,
    encoding: 'utf8'
  }).trim();
  assert(diff === '', `${path} must not be modified`);
}

console.log('TASK D1C smoke PASS');
