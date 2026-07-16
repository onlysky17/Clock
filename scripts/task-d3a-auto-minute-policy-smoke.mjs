import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const root = 'D:/EINK/Clock';
const policyPath = `${root}/docs/firmware/TASK_D3A_AUTO_MINUTE_POLICY.md`;
const currentStatePath = `${root}/docs/agent/CURRENT_STATE.md`;
const nextActionPath = `${root}/docs/agent/NEXT_ACTION.md`;

const policy = readFileSync(policyPath, 'utf8');
const currentState = readFileSync(currentStatePath, 'utf8');
const nextAction = readFileSync(nextActionPath, 'utf8');
const combined = `${policy}\n${currentState}\n${nextAction}`;

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

assert(policy.includes('minute_key = floor((current_epoch_utc + timezone_offset_minutes * 60) / 60)'), 'minute key formula missing');
assert(/Never render twice for the same minute key|No duplicate same-minute render/.test(combined), 'no duplicate same-minute render policy missing');
assert(policy.includes('DAILY_5_MIN Default'), 'DAILY 5-minute default missing');
assert(/Physical refresh every 5 minutes/.test(policy), '5-minute cadence missing');
assert(policy.includes('TEST_1_MIN Mode'), 'TEST 1-minute mode missing');
assert(/Physical refresh every minute/.test(policy), '1-minute test cadence missing');
assert(/Day rollover.*force/i.test(policy) || /day rollover forces a refresh/i.test(combined), 'day rollover force refresh missing');
assert(/keep only the latest pending minute key|latest pending minute/.test(policy), 'busy coalescing policy missing');
assert(/Cold Boot UNSET|cold boot.*UNSET/i.test(policy), 'cold boot UNSET policy missing');
assert(/BLE disconnect does not turn off auto clock|disconnect BLE does not turn off auto clock/i.test(policy), 'disconnect behavior missing');
assert(/D2 02 RENDER_CLOCK_NOW/.test(policy) && /Manual render updates `last_rendered_minute_key`/.test(policy), 'manual D2 02 interaction missing');
assert(/364/.test(policy) && /headroom/i.test(policy), 'size headroom 364 bytes missing');
assert(/D3B - Auto-Minute Scheduler Implementation/.test(policy), 'D3B roadmap missing');
assert(/D3C - Date \+ Weekday \+ Lunar Renderer/.test(policy), 'D3C roadmap missing');
assert(/D3D - Persistence\/Resync Policy/.test(policy), 'D3D roadmap missing');

const changedFirmware = execSync('git diff --name-only -- firmware', { cwd: root, encoding: 'utf8' }).trim();
assert(changedFirmware === '', 'firmware must not be modified');

const changedWeb = execSync('git diff --name-only -- web test.html', { cwd: root, encoding: 'utf8' }).trim();
assert(changedWeb === '', 'web/test.html must not be modified');

console.log('TASK D3A auto-minute policy smoke PASS');
