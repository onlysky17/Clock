#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const html = readFileSync(
  resolve(process.cwd(), 'tools/harness/control-center/index.html'),
  'utf8'
);
const startMarker = '// BURN_PROGRESS_LOGIC_START';
const endMarker = '// BURN_PROGRESS_LOGIC_END';
const start = html.indexOf(startMarker);
const end = html.indexOf(endMarker);
assert.ok(start >= 0 && end > start, 'burn progress logic markers missing');
const source = html.slice(start + startMarker.length, end);
assert.doesNotMatch(source, /set(?:Interval|Timeout)|requestAnimationFrame/, 'progress must not use fake animation timers');
const { resolveBurnProgressView } = Function(
  source + '\nreturn { resolveBurnProgressView };'
)();

const phases = [
  'HARDWARE_PREFLIGHT',
  'SPI_BACKUP',
  'ERASE',
  'WRITE',
  'READBACK',
  'SHA_VERIFY'
];
const expected = new Map([
  ['HARDWARE_PREFLIGHT', 10],
  ['SPI_BACKUP', 25],
  ['ERASE', 40],
  ['WRITE', 65],
  ['READBACK', 85],
  ['SHA_VERIFY', 100]
]);
const runtime = (phase, phaseStatus = 'RUNNING', workerStatus = 'RUNNING') => ({
  phases,
  phase,
  phaseStatus,
  workerStatus,
  reason: ''
});

let view = resolveBurnProgressView({ state: 'IDLE' });
assert.equal(view.percentage, 0);
assert.equal(view.mode, 'idle');

for (const phase of phases) {
  view = resolveBurnProgressView({ state: 'RUNNING', burnProgress: runtime(phase) });
  assert.equal(view.percentage, expected.get(phase), phase + ' percentage mismatch');
  assert.equal(view.phase, phase);
  assert.equal(view.mode, 'active');
}

view = resolveBurnProgressView({ state: 'SPI_BURN_VERIFIED', burnProgress: runtime('SHA_VERIFY', 'PASS', 'SPI_BURN_VERIFIED') });
assert.equal(view.percentage, 100);
assert.equal(view.status, 'PASS');
assert.equal(view.mode, 'complete');

view = resolveBurnProgressView({
  state: 'BLOCKED',
  burnProgress: { ...runtime('WRITE', 'FAIL', 'RECOVERY_REQUIRED'), reason: 'WRITE_FAILED' }
});
assert.equal(view.percentage, 65);
assert.equal(view.phase, 'WRITE');
assert.equal(view.mode, 'failed');
assert.equal(view.reason, 'WRITE_FAILED');

view = resolveBurnProgressView({
  state: 'RUNNING',
  burnProgress: { ...runtime('READBACK', 'FAIL'), reason: 'READBACK_FAILED' }
});
assert.equal(view.percentage, 85);
assert.equal(view.phase, 'READBACK');
assert.equal(view.mode, 'failed', 'a live FAIL phase must never retain active/success styling');

view = resolveBurnProgressView({
  state: 'RECOVERY_REQUIRED',
  burnProgress: { ...runtime('ERASE', 'FAIL', 'RECOVERY_REQUIRED'), reason: 'ERASE_FAILED' }
});
assert.equal(view.percentage, 40);
assert.equal(view.mode, 'failed');

const staleCompleted = runtime('SHA_VERIFY', 'PASS', 'SPI_BURN_VERIFIED');
view = resolveBurnProgressView({ state: 'READY_TO_BURN', burnProgress: staleCompleted });
assert.equal(view.percentage, 0, 'READY_TO_BURN must reset stale completed progress');
assert.equal(view.phase, 'IDLE');
assert.equal(view.mode, 'idle');

view = resolveBurnProgressView({
  state: 'RUNNING',
  busy: true,
  lastAction: 'PREPARE_TEST',
  burnProgress: staleCompleted
});
assert.equal(view.percentage, 0, 'PREPARE TEST must reset stale completed progress');
assert.equal(view.status, 'PREPARE TEST');
assert.equal(view.mode, 'idle');

for (const marker of [
  'burnProgressSummary',
  'burnProgressPercent',
  'burnProgressPhase',
  'burnProgressReason',
  'burnProgressTrack',
  'burnProgressFill',
  'burnPhaseGrid',
  'aria-valuenow'
]) {
  assert.ok(html.includes(marker), 'UI marker missing: ' + marker);
}
assert.ok(html.includes('burn-progress-heading'), 'single-row progress heading missing');
assert.ok(html.includes('progressView.mode === "complete"\n        ? "PASS"'), 'verified burn header must render 100% · PASS');
assert.ok(!html.includes('id="burnProgressStatus"'), 'duplicate progress status element must be removed');
assert.ok(!html.includes('id="burnPhaseDetail"'), 'duplicate phase detail line must be removed');

console.log('EINK BURN PROGRESS UI V1 ACCEPTANCE: PASS');
console.log('IDLE_AND_READY_RESET: PASS');
console.log('PHASE_PERCENTAGES: 10/25/40/65/85/100 PASS');
console.log('FAIL_BLOCKED_ATTAINED_PERCENT: PASS');
console.log('LIVE_PHASE_FAILURE_STYLING: PASS');
console.log('SPI_BURN_VERIFIED_100_PASS: PASS');
console.log('PREPARE_TEST_STALE_PROGRESS_RESET: PASS');
console.log('DUPLICATE_STATUS_LINES: REMOVED');
console.log('FAKE_ANIMATION_TIMER: ABSENT');
