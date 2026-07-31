import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..'
);

const web = fs.readFileSync(
  path.join(root, 'web', 'clock-app', 'hl24a-canvas-e5.html'),
  'utf8'
);

const scripts = [...web.matchAll(
  /<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi
)].map(match => match[1]);

const script = scripts.find(value =>
  value.includes("'use strict'")
);

assert.ok(script, 'Main script missing');
new Function(script);

assert.equal(
  (
    script.match(
      /productConnectRow\.append\(refs\.connect,refs\.disconnect\)/g
    ) || []
  ).length,
  1,
  'Product connect controls must be appended exactly once'
);

assert.doesNotMatch(
  script,
  /\$\('productConnectRow'\)\.append/
);

assert.match(
  script,
  /refs\.connect\.onclick=connectFromProductMode/
);

assert.match(
  script,
  /refs\.disconnect\.onclick=\(\)=>device\?\.gatt\?\.disconnect\(\)/
);

assert.match(
  script,
  /async function connectFromProductMode\(\)/
);

assert.match(script, /window\.isSecureContext/);
assert.match(script, /navigator\.bluetooth/);
assert.match(script, /await connect\(\)/);
assert.match(script, /error&&error\.name==="NotFoundError"/);

assert.match(
  script,
  /\$\('connect'\)\.onclick=connectFromProductMode/
);

assert.doesNotMatch(
  script,
  /\$\('connect'\)\.onclick=\(\)=>safe\(connect\)/
);

assert.match(
  script,
  /navigator\.bluetooth\.requestDevice\(\{/
);

const status = execFileSync(
  'git',
  ['status', '--porcelain=v1', '--untracked-files=all'],
  {cwd: root, encoding: 'utf8'}
)
  .trimEnd()
  .split(/\r?\n/)
  .filter(Boolean);

const dirty = status
  .map(line => line.slice(3).trim().replaceAll('\\', '/'))
  .sort();

const allowed = [
  'scripts/task-d21d-product-connect-runtime-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
].sort();

assert.deepEqual(
  dirty.filter(file => !allowed.includes(file)),
  [],
  'Only D21D files may be dirty'
);

assert.ok(
  !dirty.some(file =>
    file.startsWith('firmware/') ||
    file === 'test.html'
  ),
  'Firmware and test.html must remain unchanged'
);

console.log('TASK D21D Product Mode connect runtime smoke PASS');