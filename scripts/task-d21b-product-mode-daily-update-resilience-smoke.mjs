import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const root = new URL('..', import.meta.url);
const htmlPath = new URL('../web/clock-app/hl24a-canvas-e5.html', import.meta.url);
const auditPath = new URL('../docs/web/TASK_D21A_PRODUCT_MODE_DAILY_UPDATE_RESILIENCE_AUDIT.md', import.meta.url);
const testPath = new URL('../test.html', import.meta.url);
const html = fs.readFileSync(htmlPath, 'utf8');
const audit = fs.readFileSync(auditPath, 'utf8');
const testHtml = fs.readFileSync(testPath, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];

assert.ok(script, 'Product Mode script must exist');
new Function(script);

function block(startText, endText) {
  const start = script.indexOf(startText);
  const end = script.indexOf(endText, start);
  assert.ok(start >= 0 && end > start, `Missing block: ${startText}`);
  return script.slice(start, end);
}

assert.equal((html.match(/id="unifiedDailyUpdate"/g) || []).length, 1,
  'Product Mode must keep one primary daily-update action');
assert.match(html, /id="unifiedDailyUpdate"[^>]*>Cập nhật màn hình hôm nay</);

const unified = block(
  'async function runUnifiedDailyUpdate()',
  'async function runD2Flow'
);
assert.match(unified, /weatherValidForRun=reuseSameDayWeatherCache\(now\)/);
assert.match(unified, /buildD2SetDailyPacket\(new Date\(\),weatherValidForRun\)/);
assert.doesNotMatch(unified, /dailyWeatherEnabled'\)\.checked=false/,
  'Transient weather failure must not clear the Owner choice');
assert.equal((unified.match(/d2ApplyClockProfile/g) || []).length, 1,
  'One successful daily update must apply and render exactly once');
assert.match(unified, /finally\{[\s\S]*d2Running=false;[\s\S]*unifiedDailyUpdateRunning=false;/);
assert.match(script, /finally\{[\s\S]*unifiedDailyUpdatePromise=null;/);

const cache = block(
  'function reuseSameDayWeatherCache',
  'function automaticWeatherNextDelay'
);
assert.match(cache, /\(autoWeatherLastPacket\[3\]&0x01\)===0/);
assert.match(cache, /autoWeatherLastDayKey!==dailyDayKey\(date\)/);
assert.match(cache, /dailyWeatherEnabled'\)\.checked=true/);

const disconnect = block(
  "device.addEventListener('gattserverdisconnected'",
  'log(`Connected'
);
assert.match(disconnect, /rejectPendingBleWait\(\)/);
assert.ok(
  disconnect.indexOf('rejectPendingBleWait()') < disconnect.indexOf('resetD2UiDisconnected()'),
  'Disconnect must reject the pending BLE wait before resetting state'
);
assert.match(script, /function rejectPendingBleWait\(message='Mất kết nối - hãy kết nối lại'\)/);
assert.match(script, /const item=pending;\s*pending=null;\s*clearTimeout\(item\.timer\);\s*item\.reject\(Error\(message\)\)/);

const busy = block(
  'async function d2RequestWithOneBusyRetry',
  'async function d2ApplyClockProfile'
);
assert.match(busy, /const completionSerial=d2RenderCompletionSerial/);
assert.match(busy, /waitFor\([\s\S]*a\[1\]===0x82&&a\[3\]===0x03/);
assert.equal((busy.match(/status=await send\(\)/g) || []).length, 2,
  'BUSY recovery must make at most one retry');
assert.match(busy, /if\(status\.result===0x06\)throw Error\('Thiết bị đang bận - thử lại'\)/);
assert.match(script, /d2RenderCompletionSerial\+=1/);
assert.ok((script.match(/d2RequestWithOneBusyRetry\(/g) || []).length >= 4,
  'Profile, preference, and daily configuration writes must share one BUSY policy');

assert.match(audit, /D21B implementation complete/);
assert.match(audit, /same-day weather/);
assert.match(audit, /Mất kết nối - hãy kết nối lại/);
assert.match(audit, /exactly one bounded\s+retry/);

assert.match(html, /const SERVICE='18424398-7cbc-11e9-8f9e-2a86e4085a59'/);
assert.match(html, /const WRITE='2d86686a-53dc-25b3-0c4a-f0e10c8dee20'/);
assert.match(html, /const NOTIFY='15005991-b131-3396-014c-664c9867b917'/);
assert.match(testHtml, /web\/clock-app\/hl24a-canvas-e5\.html/);

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], {
  cwd: root,
  encoding: 'utf8'
}).split(/\r?\n/).filter(line => line.trim())
  .map(line => line.slice(3).replace(/\\/g, '/')).sort();
const allowed = [
  'docs/web/TASK_D21A_PRODUCT_MODE_DAILY_UPDATE_RESILIENCE_AUDIT.md',
  'scripts/task-d21b-product-mode-daily-update-resilience-smoke.mjs',
  'web/clock-app/hl24a-canvas-e5.html'
].sort();
assert.deepEqual(dirty, allowed, 'Only D21B files may be dirty');
assert.ok(!dirty.some(path => path.startsWith('firmware/') || path === 'test.html'),
  'Firmware and test.html must remain unchanged');

console.log('TASK D21B Product Mode daily-update resilience smoke PASS');
