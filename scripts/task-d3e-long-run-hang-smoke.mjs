import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = 'D:/EINK/Clock';
const implPath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`;
const peripheralPath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c`;
const impl = readFileSync(implPath, 'utf8');
const peripheral = readFileSync(peripheralPath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(source, name) {
  const re = new RegExp(`(?:static\\s+)?[\\w\\s\\*]+\\b${name}\\s*\\(`, 'g');
  let match;
  while ((match = re.exec(source))) {
    const close = source.indexOf(')', match.index);
    const semi = source.indexOf(';', close);
    const brace = source.indexOf('{', close);
    if (brace >= 0 && (semi < 0 || brace < semi)) {
      let depth = 0;
      for (let i = brace; i < source.length; i++) {
        if (source[i] === '{') depth += 1;
        if (source[i] === '}') depth -= 1;
        if (depth === 0) return source.slice(brace, i + 1);
      }
    }
  }
  throw new Error(`missing function ${name}`);
}

const branch = execSync('git branch --show-current', { cwd: root, encoding: 'utf8' }).trim();
assert(branch === 'task-d/d3e-long-run-hang', `wrong branch: ${branch}`);

const epdWait = functionBody(impl, 'epd_wait_timer');
const advRestart = functionBody(peripheral, 'hink_d2_adv_restart_timer_cb');
const scheduleAdv = functionBody(peripheral, 'hink_d2_schedule_adv_restart');
const advComplete = functionBody(peripheral, 'user_app_adv_undirect_complete');
const disconnect = functionBody(peripheral, 'user_app_disconnect');

assert(/timer_hnd\s+hnd/.test(epdWait), 'epd_wait_timer must store re-arm handle');
assert(/hnd\s*=\s*app_easy_timer\s*\(\s*40\s*,\s*epd_wait_timer\s*\)/.test(epdWait), 'EPD busy path must re-arm through a checked handle');
assert(/if\s*\(\s*hnd\s*!=\s*EASY_TIMER_INVALID_TIMER\s*\)[\s\S]*epd_wait_hnd\s*=\s*hnd[\s\S]*return\s*;/.test(epdWait), 'valid EPD wait re-arm must preserve existing flow and return');
assert(/epd_wait_hnd\s*=\s*EASY_TIMER_INVALID_TIMER/.test(epdWait), 'EPD wait fail-safe must clear wait handle');
assert(/hink_e6_state\s*==\s*HINK_E6_STATE_REFRESHING[\s\S]*hink_e6_state\s*=\s*HINK_E6_STATE_ERROR/.test(epdWait), 'EPD wait fail-safe must mark active E6 refresh as ERROR');
assert(/hink_d2_render_state\s*==\s*HINK_D2_RENDER_RENDERING[\s\S]*hink_d2_render_state\s*=\s*HINK_D2_RENDER_ERROR/.test(epdWait), 'EPD wait fail-safe must mark active D2D render as ERROR');
assert(/hink_auto_flags\s*&=\s*\(uint8_t\)~HINK_AUTO_FLAG_PENDING/.test(epdWait), 'EPD wait fail-safe must clear stuck auto pending flag');
assert(/hink_auto_rendering_minute\s*=\s*HINK_AUTO_SENTINEL/.test(epdWait), 'EPD wait fail-safe must clear rendering minute snapshot');
assert(/hink_d2_render_notify\s*\(\s*HINK_D2_RESULT_INTERNAL\s*,\s*HINK_D2_RENDER_ERROR\s*\)/.test(epdWait), 'D2D EPD wait fail-safe must notify ERROR');
assert(/epd_cmd1\s*\(\s*0x10\s*,\s*0x01\s*\)[\s\S]*epd_power\s*\(\s*0\s*\)[\s\S]*epd_hw_close\s*\(\s*\)[\s\S]*arch_set_sleep_mode\s*\(\s*ARCH_EXT_SLEEP_ON\s*\)/.test(epdWait), 'EPD wait fail-safe must sleep/power off/close hardware and restore EXT sleep');

assert(/hink_d2_adv_restart_timer_hnd\s*=\s*EASY_TIMER_INVALID_TIMER/.test(advRestart), 'deferred advertising callback must invalidate its handle first');
assert(/app_connection_idx\s*==\s*-1/.test(advRestart), 'deferred advertising callback must verify disconnected state');
assert(/adv_state\s*==\s*0/.test(advRestart), 'deferred advertising callback must avoid double advertising');
assert((advRestart.match(/user_app_adv_start\s*\(/g) || []).length === 1, 'deferred advertising callback must start advertising exactly once');

assert(/hink_d2_adv_restart_timer_hnd\s*==\s*EASY_TIMER_INVALID_TIMER/.test(scheduleAdv), 'advertising restart helper must arm only when no timer is active');
assert(/hnd\s*=\s*app_easy_timer\s*\(\s*1\s*,\s*hink_d2_adv_restart_timer_cb\s*\)/.test(scheduleAdv), 'advertising restart helper must use existing deferred restart callback');
assert(/if\s*\(\s*hnd\s*!=\s*EASY_TIMER_INVALID_TIMER\s*\)[\s\S]*hink_d2_adv_restart_timer_hnd\s*=\s*hnd/.test(scheduleAdv), 'advertising restart helper must store only a valid handle');
assert(!/QR_draw\s*\(|clock_draw\s*\(|user_app_adv_start\s*\(/.test(scheduleAdv), 'advertising restart helper must not draw or start advertising directly');

const dedicatedAdvBlockStart = advComplete.indexOf('hink_d2_dedicated_clock_active()');
const legacyDrawStart = advComplete.indexOf('QR_draw', dedicatedAdvBlockStart);
assert(dedicatedAdvBlockStart >= 0 && legacyDrawStart > dedicatedAdvBlockStart, 'advertising timeout must check dedicated mode before legacy draw');
const dedicatedAdvBlock = advComplete.slice(dedicatedAdvBlockStart, legacyDrawStart);
assert(/app_connection_idx\s*==\s*-1[\s\S]*hink_d2_dedicated_clock_active\s*\(\s*\)/.test(advComplete), 'advertising timeout restart must require disconnected state');
assert(/hink_d2_schedule_adv_restart\s*\(\s*\)/.test(dedicatedAdvBlock), 'advertising timeout must reuse deferred restart path');
assert(/return\s*;/.test(dedicatedAdvBlock), 'dedicated advertising timeout must skip legacy visual flow');
assert(!/QR_draw\s*\(|clock_draw\s*\(|user_app_adv_start\s*\(/.test(dedicatedAdvBlock), 'dedicated advertising timeout must not draw or start advertising directly');

assert(/hink_d2_schedule_adv_restart\s*\(\s*\)/.test(disconnect), 'dedicated disconnect must reuse the same advertising restart helper');
assert(/hink_d2_dedicated_clock_active\s*\(\s*\)[\s\S]*hink_d2_schedule_adv_restart\s*\(\s*\)[\s\S]*return\s*;/.test(disconnect), 'dedicated disconnect must skip legacy visual flow');
assert(/if\(param->reason!=CO_ERROR_REMOTE_USER_TERM_CON\)[\s\S]*user_app_adv_start\s*\(\s*\)[\s\S]*QR_draw\s*\(\s*\)[\s\S]*clock_draw\s*\(\s*UPDATE_FLY\s*\)/.test(disconnect), 'legacy disconnect flow must remain for non-dedicated mode');

assert(!/hink_diag|D3E|debug|malloc\s*\(/.test(impl), 'D3E firmware patch must not add diagnostics, debug strings, or malloc');
assert(!/hink_diag|D3E|debug/.test(peripheral), 'D3E peripheral patch must not add diagnostics or debug strings');

const changed = execSync('git status --short --untracked-files=all', { cwd: root, encoding: 'utf8' })
  .trim()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.replace(/^[ MADRCU?!]{1,2}\s+/, ''))
  .sort();

assert(JSON.stringify(changed) === JSON.stringify([
  'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c',
  'firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c',
  'scripts/task-d3e-long-run-hang-smoke.mjs',
]), `unexpected dirty files: ${changed.join(', ')}`);

const forbidden = execSync('git diff --name-only -- web test.html firmware/active/HINK213_CLOCK_22_BASE/src/epd docs tools MEMORY.md', {
  cwd: root,
  encoding: 'utf8',
}).trim();
assert(forbidden === '', `unexpected out-of-scope changes: ${forbidden}`);

console.log('TASK D3E long-run hang smoke PASS');
