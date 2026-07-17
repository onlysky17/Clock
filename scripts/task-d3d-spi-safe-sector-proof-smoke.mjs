import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const root = 'D:/EINK/Clock';
const docPath = `${root}/docs/firmware/TASK_D3D_SPI_SAFE_SECTOR_PROOF.md`;
const binPath = `${root}/_incoming/TASK_D3C_FINAL_PACKED_256KB.bin`;
const doc = readFileSync(docPath, 'utf8');
const bin = readFileSync(binPath);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function u32le(offset) {
  return bin.readUInt32LE(offset);
}

function isAllFF(start, endInclusive) {
  for (let i = start; i <= endInclusive; i += 1) {
    if (bin[i] !== 0xff) return false;
  }
  return true;
}

function mustInclude(text) {
  assert(doc.includes(text), `missing required text: ${text}`);
}

const sha = createHash('sha256').update(bin).digest('hex').toUpperCase();
assert(bin.length === 0x40000, `packed size mismatch: ${bin.length}`);
assert(sha === '648123BE0CC83291D9CD0DC6E5B8D3B2AD68373698954BA7F6C189C1260F44F1', 'packed SHA256 mismatch');

assert(bin[0x00000] === 0x70 && bin[0x00001] === 0x50, 'missing 7050 boot header');
assert(bin[0x04000] === 0x70 && bin[0x04001] === 0x51 && bin[0x04002] === 0xaa, 'missing 7051 image header');
assert(bin[0x38000] === 0x70 && bin[0x38001] === 0x52, 'missing 7052 product header');
assert(u32le(0x38004) === 0x4000, 'image0 start mismatch');
assert(u32le(0x38008) === 0x1f000, 'image1 start mismatch');
assert(u32le(0x04004) === 64128, 'active image payload size mismatch');
assert((0x04040 + u32le(0x04004) - 1) === 0x13abf, 'active image end mismatch');
assert(isAllFF(0x1f000, 0x1f01f), 'inactive image header should be erased in final packed image');
assert(isAllFF(0x3b000, 0x3bfff), 'candidate persistence sector must be erased');
assert(!isAllFF(0x38000, 0x38fff), 'product table sector must not be considered free');
assert(!isAllFF(0x39000, 0x39fff), 'pin config sector must not be considered free');
assert(!isAllFF(0x3a000, 0x3afff), 'panel profile sector must not be considered free');

mustInclude('Chosen sector:');
mustInclude('start: `0x3B000`');
mustInclude('end: `0x3BFFF`');
mustInclude('Sector `0x3B000..0x3BFFF` is entirely `0xFF`.');
mustInclude('image0 start: `0x00004000`');
mustInclude('image1 start: `0x0001F000`');
mustInclude('image0 payload: `0x04040..0x13ABF`');
mustInclude('worst-case inactive image range ending below `0x30000`');
mustInclude('Erase only `0x3B000..0x3BFFF`.');
mustInclude('slot A: `0x3B000`');
mustInclude('slot B: `0x3B020`');
mustInclude('Cold boot must not mark D2 time RUNNING from persisted data.');
mustInclude('Cold boot must not start the D3B/D3C scheduler from persisted data.');
mustInclude('Write only on successful `D2 00 SET_TIME`.');
mustInclude('Never erase the full chip.');

assert(!/0x3B000..0x3BFFF` is rejected/.test(doc), 'candidate sector must not be rejected');

const changed = execSync('git status --short --untracked-files=all', { cwd: root, encoding: 'utf8' })
  .trim()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.replace(/^..\s+/, ''))
  .sort();

assert(JSON.stringify(changed) === JSON.stringify([
  'docs/firmware/TASK_D3D_SPI_SAFE_SECTOR_PROOF.md',
  'scripts/task-d3d-spi-safe-sector-proof-smoke.mjs',
]), `unexpected dirty files: ${changed.join(', ')}`);

const forbidden = execSync(
  'git diff --name-only -- firmware web test.html tools MEMORY.md docs/agent docs/firmware/TASK_D3D_TIME_PERSISTENCE_AUDIT.md',
  { cwd: root, encoding: 'utf8' },
).trim();
assert(forbidden === '', `unexpected out-of-scope changes: ${forbidden}`);

console.log('TASK D3D SPI safe sector proof smoke PASS');
