import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = 'D:/EINK/Clock';
const docPath = `${root}/docs/firmware/TASK_D3D_TIME_PERSISTENCE_AUDIT.md`;
const doc = readFileSync(docPath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function mustInclude(text) {
  assert(doc.includes(text), `missing required text: ${text}`);
}

mustInclude('Chosen MVP: **A. Restore last-known time metadata and require resync after full power loss.**');
mustInclude('Rejected for MVP: **B. SPI 2-slot persistence with elapsed-time restore.**');
mustInclude('The current clock is a software clock, not a backed RTC.');
mustInclude('Full power loss: no clock source remains to add elapsed seconds accurately.');
mustInclude('Firmware must not pretend persisted time is current after a full power loss.');
mustInclude('`D2 00 SET_TIME` must remain the authoritative override');
mustInclude('D3B/D3C scheduler may run only when time is actively synced or otherwise proven valid.');
mustInclude('Do not write SPI every minute.');
mustInclude('Write only on successful SET_TIME.');
mustInclude('0x38000');
mustInclude('0x39000');
mustInclude('0x3A000');
mustInclude('magic: `uint32`');
mustInclude('sequence: `uint32`');
mustInclude('epoch_utc: `uint32`');
mustInclude('timezone_minutes: `int16`');
mustInclude('crc16: `uint16`');
mustInclude('Code increase `<=700` bytes.');
mustInclude('RAM increase `<=32` bytes.');
mustInclude('Choose and verify an exact safe SPI sector');

assert(/SET_TIME[\s\S]*write a compact last-known record/.test(doc), 'SET_TIME persistence behavior must be documented');
assert(/On cold boot[\s\S]*Do not mark D2 time RUNNING/.test(doc), 'cold boot stale behavior must be documented');
assert(/Do not start D3B\/D3C auto scheduler from persisted data/.test(doc), 'scheduler guard must be documented');
assert(/No safe persistence address is finalized in this audit/.test(doc), 'audit must not invent a flash address');
assert(!/Chosen MVP:\s*\*\*B\./.test(doc), 'MVP B must not be selected');

const changed = execSync('git status --short --untracked-files=all', { cwd: root, encoding: 'utf8' })
  .trim()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.replace(/^..\s+/, ''))
  .sort();

assert(JSON.stringify(changed) === JSON.stringify([
  'docs/firmware/TASK_D3D_TIME_PERSISTENCE_AUDIT.md',
  'scripts/task-d3d-time-persistence-audit-smoke.mjs',
]), `unexpected dirty files: ${changed.join(', ')}`);

const forbidden = execSync(
  'git diff --name-only -- firmware web test.html MEMORY.md docs/agent',
  { cwd: root, encoding: 'utf8' },
).trim();
assert(forbidden === '', `unexpected runtime/doc-state changes: ${forbidden}`);

console.log('TASK D3D time persistence audit smoke PASS');
