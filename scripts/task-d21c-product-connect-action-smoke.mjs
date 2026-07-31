import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..'
);

const webPath = path.join(
  root,
  'web',
  'clock-app',
  'hl24a-canvas-e5.html'
);

const web = fs.readFileSync(webPath, 'utf8');

const scripts = [...web.matchAll(
  /<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi
)].map(match => match[1]);

const script = scripts.find(value => value.includes("'use strict'"));

assert.ok(script, 'Main application script missing');
new Function(script);

const setupStart = script.indexOf('function setupProductMode(){');
assert.ok(setupStart >= 0, 'setupProductMode missing');

const setupEnd = script.indexOf('\nfunction ', setupStart + 1);
const setup = script.slice(
  setupStart,
  setupEnd >= 0 ? setupEnd : script.length
);

assert.match(setup, /connect:\$\('connect'\)/);
assert.match(setup, /disconnect:\$\('disconnect'\)/);
assert.match(setup, /id="productConnectRow"/);

assert.match(
  setup,
  /const productConnectRow=header\.querySelector\('#productConnectRow'\)/
);

assert.match(
  setup,
  /productConnectRow\.append\(refs\.connect,refs\.disconnect\)/
);

assert.match(
  setup,
  /refs\.connect\.textContent='Kết nối thiết bị'/
);

assert.match(
  setup,
  /refs\.disconnect\.textContent='Ngắt kết nối'/
);

assert.equal(
  (web.match(/id="connect"/g) || []).length,
  1,
  'Exactly one real connect button must remain'
);

assert.equal(
  (web.match(/id="disconnect"/g) || []).length,
  1,
  'Exactly one real disconnect button must remain'
);

assert.match(
  script,
  /\$\('connect'\)\.onclick=/
);

assert.match(
  script,
  /\$\('disconnect'\)\.onclick=/
);

const unifiedStart = script.indexOf(
  'function runUnifiedDailyUpdate'
);

const unifiedEnd = script.indexOf(
  '\nfunction ',
  unifiedStart + 1
);

const unified = unifiedStart >= 0
  ? script.slice(
      unifiedStart,
      unifiedEnd >= 0 ? unifiedEnd : script.length
    )
  : '';

assert.doesNotMatch(
  unified,
  /(?:^|[^\w.])connect\s*\(/,
  'Unified update must not auto-connect BLE'
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
  'scripts/task-d21c-product-connect-action-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
].sort();

assert.deepEqual(
  dirty.filter(file => !allowed.includes(file)),
  [],
  'Only D21C files may be dirty'
);

assert.ok(
  !dirty.some(file =>
    file.startsWith('firmware/') ||
    file === 'test.html'
  ),
  'Firmware and test.html must remain unchanged'
);

console.log('TASK D21C Product Mode connect action smoke PASS');