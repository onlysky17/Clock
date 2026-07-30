import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const root = new URL('..', import.meta.url);
const auditPath = new URL('../docs/web/TASK_D21A_PRODUCT_MODE_DAILY_UPDATE_RESILIENCE_AUDIT.md', import.meta.url);
const nextPath = new URL('../docs/agent/NEXT_ACTION.md', import.meta.url);
const htmlPath = new URL('../web/clock-app/hl24a-canvas-e5.html', import.meta.url);
const audit = fs.readFileSync(auditPath, 'utf8');
const next = fs.readFileSync(nextPath, 'utf8');
const html = fs.readFileSync(htmlPath, 'utf8');

assert.match(audit, /Audit\/design complete/);
assert.match(audit, /clears `dailyWeatherEnabled`/);
assert.match(audit, /temporary GPS/);
assert.match(audit, /does not reject the active `pending` BLE request/);
assert.match(audit, /stale COMPLETE value can skip\s+the wait/);

assert.match(audit, /Keep the Owner's weather choice/);
assert.match(audit, /Reuse valid same-day weather/);
assert.match(audit, /Reject the pending BLE wait immediately/);
assert.match(audit, /must not reconnect or retry automatically/);
assert.match(audit, /Exactly one bounded retry/);
assert.match(audit, /must\s+not add a second render request/);
assert.match(audit, /Do not perform more than one physical render/);
assert.match(audit, /Always release the Product Mode lock/);

assert.match(audit, /TASK D21B - HARDEN PRODUCT MODE DAILY UPDATE RECOVERY/);
assert.match(audit, /web\/clock-app\/hl24a-canvas-e5\.html/);
assert.match(audit, /task-d21b-product-mode-daily-update-resilience-smoke\.mjs/);
assert.match(audit, /does not require Keil, BIN, BLE, or panel testing/);

assert.match(next, /TASK D21B - HARDEN PRODUCT MODE DAILY UPDATE RECOVERY/);
assert.match(next, /preserve[\s\S]*valid same-day weather/i);
assert.match(next, /reject the pending BLE wait immediately/i);
assert.match(next, /one bounded BUSY retry/i);
assert.doesNotMatch(next, /TASK D21A - PRODUCT MODE DAILY UPDATE RESILIENCE AUDIT/);

assert.equal((html.match(/id="unifiedDailyUpdate"/g) || []).length, 1,
  'Product Mode must retain exactly one primary daily action');
assert.match(html, /id="unifiedDailyUpdate"[^>]*>Cập nhật màn hình hôm nay</);
assert.match(html, /const SERVICE='18424398-7cbc-11e9-8f9e-2a86e4085a59'/);
assert.match(html, /const WRITE='2d86686a-53dc-25b3-0c4a-f0e10c8dee20'/);
assert.match(html, /const NOTIFY='15005991-b131-3396-014c-664c9867b917'/);

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], {
  cwd: root,
  encoding: 'utf8'
}).split(/\r?\n/).filter(line => line.trim()).map(line => line.slice(3).replace(/\\/g, '/')).sort();
const allowed = [
  'docs/agent/NEXT_ACTION.md',
  'docs/web/TASK_D21A_PRODUCT_MODE_DAILY_UPDATE_RESILIENCE_AUDIT.md',
  'scripts/task-d21a-product-mode-daily-update-resilience-smoke.mjs'
].sort();
assert.deepEqual(dirty, allowed, 'Only D21A audit files may be dirty');
assert.ok(!dirty.some(path => path.startsWith('firmware/') ||
  path.startsWith('web/') || path === 'test.html'),
  'D21A must not change firmware, web runtime, or test.html');

console.log('TASK D21A Product Mode daily update resilience audit smoke PASS');
