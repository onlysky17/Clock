import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const htmlPath = join(root, 'web', 'clock-app', 'hl24a-canvas-e5.html');
const testPath = join(root, 'test.html');
const html = readFileSync(htmlPath, 'utf8');
readFileSync(testPath, 'utf8');

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function constantValue(name) {
  const match = html.match(new RegExp(`const\\s+${name}\\s*=\\s*(\\d+)\\s*;`));
  assert(match, `Missing const ${name}`);
  return Number(match[1]);
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

assert(html.includes('<canvas id="canvas" width="250" height="122"></canvas>'), 'Canvas must be 250x122');
assert(constantValue('WIDTH') === 250, 'WIDTH must be 250');
assert(constantValue('HEIGHT') === 122, 'HEIGHT must be 122');
assert(constantValue('RAM_WIDTH') === 122, 'RAM_WIDTH must be 122');
assert(constantValue('RAM_HEIGHT') === 250, 'RAM_HEIGHT must be 250');
assert(constantValue('STRIDE') === 16, 'STRIDE must be 16');
assert(constantValue('TOTAL') === 4000, 'Payload TOTAL must be 4000');
assert(constantValue('EXPECTED_CHUNKS') === 286, 'Expected chunks must be 286');
assert(html.includes('id="updateClock"') && html.includes('Cập nhật giờ hiện tại'), 'Missing update clock button');
assert(html.includes('new Date()'), 'Clock preview must use current Date');
assert(!html.includes('setInterval'), 'D1A must not use setInterval');
assert(html.includes("$('updateClock').onclick=drawCurrentClock;"), 'Update button must redraw preview only');

const updateBody = functionBody('drawCurrentClock');
for (const forbidden of ['sendFramebuffer', 'refreshPanel', 'openE4', 'tx(', 'request(', '0xE5', '0xE6']) {
  assert(!updateBody.includes(forbidden), `drawCurrentClock must not call BLE path: ${forbidden}`);
}

const script = html.match(/<script>([\s\S]*)<\/script>/);
assert(script, 'Missing inline script');
new Function(script[1]);

const testDiff = execFileSync('git', ['diff', '--name-only', '--', 'test.html'], {
  cwd: root,
  encoding: 'utf8'
}).trim();
assert(testDiff === '', 'test.html must not be modified');

console.log('TASK D1A smoke PASS');
