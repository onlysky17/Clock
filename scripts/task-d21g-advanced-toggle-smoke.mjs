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

assert.match(
  script,
  /const advanced=document\.createElement\('section'\)/
);

assert.doesNotMatch(
  script,
  /const advanced=document\.createElement\('details'\)/
);

assert.match(
  script,
  /id="advancedToggle"/
);

assert.match(
  script,
  /aria-expanded="false"/
);

assert.match(
  script,
  /id="advancedBody" class="advancedBody" hidden/
);

assert.match(
  script,
  /advancedToggle\.addEventListener\('click'/
);

assert.match(
  script,
  /advancedBody\.hidden=!nextOpen/
);

const controlsStart = script.indexOf('function controls(){');
const controlsEnd = script.indexOf(
  '\nfunction ',
  controlsStart + 1
);

const controls = script.slice(controlsStart, controlsEnd);

assert.doesNotMatch(
  controls,
  /advancedToggle.*disabled/,
  'Advanced toggle must never be disabled by BLE busy state'
);

assert.match(
  web,
  /\.advancedToggle\{display:block;width:100%/
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
  'scripts/task-d21g-advanced-toggle-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
].sort();

assert.deepEqual(
  dirty.filter(file => !allowed.includes(file)),
  [],
  'Only D21G files may be dirty'
);

assert.ok(
  !dirty.some(file =>
    file.startsWith('firmware/') ||
    file === 'test.html'
  ),
  'Firmware and test.html must remain unchanged'
);

console.log('TASK D21G advanced toggle smoke PASS');