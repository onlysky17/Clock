import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const webPath = 'web/clock-app/hl24a-canvas-e5.html';
const smokePath = 'scripts/task-d12b-web-publish-smoke.mjs';
const web = fs.readFileSync(webPath, 'utf8');
const script = web.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');
assert.match(web, /D12B-PREFERENCES-20260722/, 'D12B build marker missing');
assert.match(web, /Uint8Array\.of\(0xD2,0x06,hourMode,refreshMinutes\)/, 'SET preference packet must be exact');
assert.match(web, /Uint8Array\.of\(0xD2,0x07\)/, 'GET preference packet must be exact');
assert.match(web, /bytes\.length!==8\|\|bytes\[0\]!==0xD2\|\|bytes\[1\]!==0x86/, 'D2 86 parser must be exact');
assert.match(web, /24 gi\\u1edd.*12 gi\\u1edd/, 'hour-mode controls missing');
assert.match(web, /5 ph\\u00fat.*10 ph\\u00fat.*1 ph\\u00fat/, 'cadence controls missing');
assert.match(web, /status\.result===0x06[\s\S]*waitFor\([\s\S]*buildD2SetPreferencePacket/s, 'BUSY retry missing');
assert.match(web, /await d2RenderClockFromDevice\(\)/, 'Apply must render through D2');
assert.match(web, /advanced\.id='advancedPanel'/, 'Advanced section missing');
assert.match(web, /identityCompatibility!==['"]compatible['"]/, 'compatibility guard missing');

const changed = execFileSync('git', ['diff', '--name-only', 'HEAD'], { encoding: 'utf8' })
  .trim().split(/\r?\n/).filter(Boolean);
const allowed = new Set([webPath, smokePath]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope change: ${changed.join(', ')}`);
assert.ok(!changed.includes('test.html'), 'test.html must remain unchanged');

console.log('TASK D12B web publish smoke PASS');
