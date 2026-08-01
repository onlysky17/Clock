import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..'
);

const recoveryPath = path.join(
  root,
  'web',
  'clock-app',
  'd21i-old-web-recovery.html'
);

const html = fs.readFileSync(recoveryPath, 'utf8');

const scripts = [...html.matchAll(
  /<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi
)].map(match => match[1]);

for (const script of scripts) {
  if (script.trim()) new Function(script);
}

assert.match(
  html,
  /<button id="connect"[^>]*>[\s\S]*?Connect/i,
  'Real Connect button missing'
);

assert.match(
  html,
  /<button id="disconnect"/,
  'Real Disconnect button missing'
);

assert.match(
  html,
  /\$\('connect'\)\.onclick=/,
  'Connect click handler missing'
);

assert.match(
  html,
  /navigator\.bluetooth\.requestDevice\s*\(/,
  'Web Bluetooth requestDevice call missing'
);

assert.doesNotMatch(
  html,
  /setupProductMode/,
  'Recovery page must remain pre-Product-Mode'
);

assert.doesNotMatch(
  html,
  /id="productConnectRow"/,
  'Recovery page must not use the broken Product Mode connect row'
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
  'scripts/task-d21i-old-web-recovery-smoke.mjs',
  'web/clock-app/d21i-old-web-recovery.html'
].sort();

assert.deepEqual(
  dirty,
  allowed,
  'Only the two D21I recovery files may be dirty'
);

assert.ok(
  !dirty.includes('test.html'),
  'Default URL must remain unchanged'
);

assert.ok(
  !dirty.includes('web/clock-app/hl24a-canvas-e5.html'),
  'Current canonical implementation must remain unchanged'
);

assert.ok(
  !dirty.some(file => file.startsWith('firmware/')),
  'Firmware must remain unchanged'
);

console.log('TASK D21I old web recovery smoke PASS');