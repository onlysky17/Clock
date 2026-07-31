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

assert.ok(script, 'Main application script missing');
new Function(script);

const connectStart = script.indexOf('async function connect(){');
const connectEnd = script.indexOf(
  '\nfunction ',
  connectStart + 1
);

assert.ok(connectStart >= 0, 'connect() missing');

const connect = script.slice(
  connectStart,
  connectEnd >= 0 ? connectEnd : script.length
);

assert.match(
  connect,
  /navigator\.bluetooth\.requestDevice\(\{\s*acceptAllDevices:true,\s*optionalServices:\[SERVICE,BATTERY_SERVICE\]\s*\}\)/
);

assert.doesNotMatch(
  connect,
  /filters:\[\{namePrefix:'EINK'\},\{namePrefix:'HINK'\}\]/
);

assert.match(
  connect,
  /const selectedName=device\?\.name\|\|""/
);

assert.match(
  connect,
  /\/\^\(\?:EINK\|HINK\)\/i\.test\(selectedName\)/
);

assert.match(
  connect,
  /Hãy chọn HINK213-CLOCK/
);

assert.match(
  script,
  /async function connectFromProductMode\(\)/
);

assert.match(
  script,
  /\$\('connect'\)\.onclick=connectFromProductMode/
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
  'scripts/task-d21e-accept-all-ble-chooser-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
].sort();

assert.deepEqual(
  dirty.filter(file => !allowed.includes(file)),
  [],
  'Only D21E files may be dirty'
);

assert.ok(
  !dirty.some(file =>
    file.startsWith('firmware/') ||
    file === 'test.html'
  ),
  'Firmware and test.html must remain unchanged'
);

console.log('TASK D21E accept-all BLE chooser smoke PASS');