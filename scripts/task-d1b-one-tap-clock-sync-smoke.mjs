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

assert(html.includes('id="syncClock"') && html.includes('Đồng bộ giờ lên màn'), 'Missing one-tap sync button');
assert(html.includes('id="syncStatus"'), 'Missing one-tap status element');
assert(html.includes('let oneTapRunning=false;'), 'Missing one-tap re-entry guard state');
assert(html.includes("$('syncClock').disabled=!connected||locked;"), 'One-tap button must be disabled while locked');
assert(!html.includes('setInterval'), 'D1B must not use setInterval');

const syncBody = functionBody('syncClockToPanel');
assert(syncBody.includes('if(oneTapRunning||e6Running)return;'), 'Missing re-entry guard');
assert(syncBody.includes("if(!server?.connected)throw Error"), 'One-tap must require existing BLE connection');
assert(syncBody.includes('oneTapRunning=true;'), 'One-tap must mark running');
assert(syncBody.includes('oneTapRunning=false;'), 'One-tap must clear running');

const redrawIndex = syncBody.indexOf('drawCurrentClock();');
const e5Index = syncBody.indexOf('await sendFramebuffer();');
const e5CheckIndex = syncBody.indexOf('e5Success && latestFwCrc === browserCrc');
const e6Index = syncBody.indexOf('await refreshPanel();');
assert(redrawIndex >= 0, 'One-tap must redraw current local time');
assert(e5Index > redrawIndex, 'Redraw must occur before E5');
assert(e5CheckIndex > e5Index, 'E5 COMPLETE/CRC check must happen after E5');
assert(e6Index > e5CheckIndex, 'E6 must run only after E5 COMPLETE/CRC check');

const initBlock = html.slice(html.indexOf("$('clearWhite').onclick"), html.indexOf('</script>'));
assert(initBlock.includes('drawCurrentClock();'), 'Page load should render current clock preview once');
assert(!initBlock.includes('sendFramebuffer();'), 'Page load must not auto send E5');
assert(!initBlock.includes('refreshPanel();'), 'Page load must not auto send E6');
assert(initBlock.includes("$('syncClock').onclick=()=>safe(syncClockToPanel);"), 'One-tap click handler missing');

const script = html.match(/<script>([\s\S]*)<\/script>/);
assert(script, 'Missing inline script');
new Function(script[1]);

const testDiff = execFileSync('git', ['diff', '--name-only', '--', 'test.html'], {
  cwd: root,
  encoding: 'utf8'
}).trim();
assert(testDiff === '', 'test.html must not be modified');

console.log('TASK D1B smoke PASS');
