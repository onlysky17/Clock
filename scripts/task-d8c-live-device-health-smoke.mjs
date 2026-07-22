import { strict as assert } from 'node:assert';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const ROOT = 'D:/EINK/Clock';
const WEB_PATH = 'web/clock-app/hl24a-canvas-e5.html';
const DOC_PATH = 'docs/web/TASK_D8C_LIVE_DEVICE_HEALTH.md';
const html = readFileSync(`${ROOT}/${WEB_PATH}`, 'utf8');
const doc = readFileSync(`${ROOT}/${DOC_PATH}`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';
const includes = (text, value, message) => assert.ok(text.includes(value), message);

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');
includes(html, '<title>TASK D8C - Live Device Health</title>', 'D8C title missing');
includes(html, "webBuild:'D8C-HEALTH-20260722'", 'D8C build marker missing');
includes(html, 'id="identityUpdatedAt"', 'visible health freshness field missing');
includes(html, 'let identityRefreshPending=false;', 'refresh re-entry guard missing');
includes(html, "scheduleIdentityHealthRefresh('time sync');", 'SET_TIME health refresh missing');
includes(html, "if(complete)scheduleIdentityHealthRefresh('render complete');", 'render COMPLETE health refresh missing');
includes(html, 'function scheduleIdentityHealthRefresh(reason)', 'health refresh scheduler missing');
includes(html, 'if(identityRefreshPending||!server?.connected)return;', 'connected/dedup guard missing');
includes(html, "$('identityUpdatedAt').textContent='Đang cập nhật';", 'refresh progress missing');
includes(html, 'await d2GetDeviceIdentity();', 'refresh must reuse D2 identity flow');
includes(html, "$('identityUpdatedAt').textContent='Không đọc được';", 'nonfatal refresh failure state missing');
includes(html, 'identityRefreshPending=false;', 'refresh guard cleanup missing');
includes(html, '},0);', 'refresh must defer until current notify/request completes');
assert.ok(!/setInterval\([^)]*d2GetDeviceIdentity/.test(html), 'identity must not poll in an interval');

includes(html, "expectedRuntime:'D8A1'", 'D8B runtime compatibility missing');
includes(html, "expectedSourceId:'D8A00001'", 'D8B source compatibility missing');
includes(html, "const identityBlocked=connected&&identityCompatibility!=='compatible';", 'D8B action guard missing');
includes(html, 'function resolveProductState(input)', 'D6B state mapping missing');
includes(html, 'Uint8Array.of(0xD2,0x03)', 'D2 identity request changed');
includes(html, 'bytes.length!==16||bytes[0]!==0xD2||bytes[1]!==0x83', 'D2 identity response changed');
includes(doc, 'https://onlysky17.github.io/Clock/test.html', 'canonical URL missing');

const setTime = html.match(/async function d2SetCurrentTime\(options=\{\}\)\{[\s\S]*?\n\}/)?.[0] ?? '';
assert.ok(setTime.indexOf('renderD2Status(status,options);') < setTime.indexOf("scheduleIdentityHealthRefresh('time sync');"), 'SET_TIME refresh must follow successful status parse');

const notify = html.match(/function handleD2Notify\(bytes\)\{[\s\S]*?\n\}/)?.[0] ?? '';
assert.ok(notify.includes("if(complete)scheduleIdentityHealthRefresh('render complete');"), 'COMPLETE event refresh missing from notify routing');

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], { cwd: ROOT, encoding: 'utf8' })
  .split(/\r?\n/).filter(Boolean).map(line => line.slice(3).replaceAll('\\', '/'))
  .filter(file => !file.startsWith('_incoming/'));
const allowed = new Set([WEB_PATH, DOC_PATH, 'scripts/task-d8c-live-device-health-smoke.mjs']);
assert.ok(dirty.every(file => allowed.has(file)), `out-of-scope dirty file: ${dirty.join(', ')}`);
assert.ok(!dirty.includes('test.html'), 'test.html must not be modified');
assert.ok(!dirty.some(file => file.startsWith('firmware/')), 'firmware must not be modified');

console.log('TASK D8C live device health smoke PASS');
