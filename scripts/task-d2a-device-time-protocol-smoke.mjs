import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const docPath = join(root, 'docs', 'protocol', 'TASK_D2A_DEVICE_TIME_SYNC_PROTOCOL.md');
const doc = readFileSync(docPath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

for (const required of [
  'D2 00',
  'D2 01',
  'SET_TIME',
  'GET_TIME_STATUS',
  'Length: `9` bytes',
  'Length: `15` bytes',
  'Unix epoch UTC',
  'uint32 LE',
  'int16 LE',
  'little-endian',
  'Minimum: `-720` minutes',
  'Maximum: `+840` minutes',
  'Reserved bits 2..7 must be zero',
  'RAM-only',
  '24 hours',
  'D2B — Firmware Time State + D2 Command Handler',
  'D2C — Web Time Sync Controls',
  'D2D — Device-Side Minute Renderer'
]) {
  assert(doc.includes(required), `Missing required protocol text: ${required}`);
}

assert(doc.includes('Do not implement firmware'), 'D2A must remain design-only');
assert(doc.includes('No chunking is required'), 'D2 must not require chunking');
assert(doc.includes('This protocol does not affect E5 framebuffer transfer'), 'D2 must not affect E5');
assert(doc.includes('Cold boot currently returns device time to `UNSET`'), 'Cold boot UNSET behavior must be documented');

for (const path of ['firmware', 'web', 'test.html']) {
  const diff = execFileSync('git', ['diff', '--name-only', '--', path], {
    cwd: root,
    encoding: 'utf8'
  }).trim();
  assert(diff === '', `${path} must not be modified`);
}

console.log('TASK D2A protocol smoke PASS');
