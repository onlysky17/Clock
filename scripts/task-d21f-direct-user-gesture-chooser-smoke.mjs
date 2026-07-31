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

assert.equal(
  (script.match(/navigator\.bluetooth\.requestDevice\s*\(/g) || []).length,
  1,
  'requestDevice call must exist exactly once'
);

const handlerStart = script.indexOf(
  'async function connectFromProductMode(){'
);

const connectStart = script.indexOf(
  'async function connect(selectedDevice){'
);

assert.ok(handlerStart >= 0, 'Product connect handler missing');
assert.ok(connectStart > handlerStart, 'GATT connect function missing');

const handler = script.slice(handlerStart, connectStart);

assert.match(
  handler,
  /const chooser=navigator\.bluetooth\.requestDevice\(\{\s*acceptAllDevices:true,\s*optionalServices:\[SERVICE,BATTERY_SERVICE\]\s*\}\)/
);

assert.match(
  handler,
  /const selectedDevice=await chooser/
);

assert.match(
  handler,
  /await connect\(selectedDevice\)/
);

const chooserIndex = handler.indexOf(
  'navigator.bluetooth.requestDevice'
);

const selectedIndex = handler.indexOf(
  'const selectedDevice=await chooser'
);

const busyIndex = handler.indexOf(
  'setBusy(true)'
);

assert.ok(chooserIndex >= 0, 'Chooser call missing');
assert.ok(selectedIndex > chooserIndex, 'Selection must follow chooser');
assert.ok(
  busyIndex > selectedIndex,
  'Busy mode must start only after device selection'
);

const connectEnd = script.indexOf(
  '\nfunction ',
  connectStart + 1
);

const connect = script.slice(
  connectStart,
  connectEnd >= 0 ? connectEnd : script.length
);

assert.doesNotMatch(
  connect,
  /navigator\.bluetooth\.requestDevice/,
  'GATT connect function must not open chooser'
);

assert.match(
  connect,
  /device=selectedDevice/
);

assert.match(
  connect,
  /Hãy chọn HINK213-CLOCK/
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
  'scripts/task-d21f-direct-user-gesture-chooser-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
].sort();

assert.deepEqual(
  dirty.filter(file => !allowed.includes(file)),
  [],
  'Only D21F files may be dirty'
);

assert.ok(
  !dirty.some(file =>
    file.startsWith('firmware/') ||
    file === 'test.html'
  ),
  'Firmware and test.html must remain unchanged'
);

console.log('TASK D21F direct user-gesture BLE chooser smoke PASS');