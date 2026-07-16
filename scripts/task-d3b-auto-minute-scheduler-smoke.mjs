import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = 'D:/EINK/Clock';
const firmwarePath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`;
const firmware = readFileSync(firmwarePath, 'utf8');

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function functionBody(source, name) {
  const re = new RegExp(`(?:static\\s+)?[\\w\\s\\*]+\\b${name}\\s*\\(`, 'g');
  let marker = -1;
  let match;
  while ((match = re.exec(source))) {
    const close = source.indexOf(')', match.index);
    const semi = source.indexOf(';', close);
    const brace = source.indexOf('{', close);
    if (brace >= 0 && (semi < 0 || brace < semi)) {
      marker = match.index;
      break;
    }
  }
  assert(marker >= 0, `missing function ${name}`);
  const open = source.indexOf('{', marker);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}') depth--;
    if (depth === 0) return source.slice(open, i + 1);
  }
  throw new Error(`unterminated function ${name}`);
}

const setTimeHandler = functionBody(firmware, 'hink_d2_time_handle');
const clockUpdate = functionBody(firmware, 'clock_update');
const renderTimer = functionBody(firmware, 'hink_d2_render_timer_cb');
const waitTimer = functionBody(firmware, 'epd_wait_timer');
const localMinute = functionBody(firmware, 'hink_auto_local_minute_key');

assert(/#ifndef\s+HINK_AUTO_TEST_1_MIN[\s\S]*#define\s+HINK_AUTO_TEST_1_MIN\s+0/.test(firmware), 'TEST_1_MIN compile-time flag must default OFF');
assert(/#define\s+HINK_AUTO_FLAG_ENABLED\s+0x01U/.test(firmware), 'auto enabled flag missing');
assert(/#define\s+HINK_AUTO_FLAG_PENDING\s+0x02U/.test(firmware), 'auto pending flag missing');
assert(/#define\s+HINK_AUTO_FLAG_TEST\s+0x04U/.test(firmware), 'auto test flag missing');
assert(/hink_auto_last_rendered_minute\s+__SECTION_ZERO\("retention_mem_area0"\)/.test(firmware), 'last_rendered minute state missing');
assert(/hink_auto_pending_minute\s+__SECTION_ZERO\("retention_mem_area0"\)/.test(firmware), 'pending minute state missing');
assert(/hink_auto_flags\s+__SECTION_ZERO\("retention_mem_area0"\)/.test(firmware), 'auto flags state missing');
assert(!/hink_auto_last_seen/.test(firmware), 'must not add separate last_seen state');

assert(/hink_d2_current_epoch\s*\(\s*\)/.test(localMinute), 'minute key must use D2 current epoch');
assert(/hink_d2_timezone_minutes/.test(localMinute), 'minute key must use timezone offset');
assert(/return\s+local_seconds\s*\/\s*60UL/.test(localMinute), 'minute key must divide local seconds by 60');

assert(/hink_auto_last_rendered_minute\s*=\s*HINK_AUTO_SENTINEL/.test(setTimeHandler), 'SET_TIME must reset last_rendered sentinel');
assert(/hink_auto_pending_minute\s*=\s*hink_auto_local_minute_key\s*\(\s*\)/.test(setTimeHandler), 'SET_TIME must seed pending minute');
assert(/hink_auto_flags\s*=\s*HINK_AUTO_FLAG_ENABLED\s*\|\s*HINK_AUTO_FLAG_PENDING/.test(setTimeHandler), 'SET_TIME must enable auto DAILY_5_MIN and pending');
assert(/HINK_AUTO_TRY_SCHEDULE\s*\(\s*\)/.test(setTimeHandler), 'SET_TIME must schedule one render');
assert(!/epd_screen_update|epd_update|clock_draw/.test(setTimeHandler), 'SET_TIME BLE callback must not render directly');

assert(/hink_d2_uptime_seconds\s*\+=\s*\(uint32_t\)inc/.test(clockUpdate), 'clock_update must advance D2 uptime');
assert(/hink_d2_synced_epoch\s*!=\s*0UL/.test(clockUpdate), 'clock_update must guard cold boot UNSET');
assert(/hink_auto_flags\s*&\s*HINK_AUTO_FLAG_ENABLED/.test(clockUpdate), 'clock_update must require auto enabled');
assert(/auto_minute\s*=\s*hink_auto_local_minute_key\s*\(\s*\)/.test(clockUpdate), 'clock_update must compute current minute key');
assert(/auto_minute\s*!=\s*hink_auto_last_rendered_minute/.test(clockUpdate), 'clock_update must avoid duplicate same-minute render');
assert(/auto_minute\s*!=\s*hink_auto_pending_minute/.test(clockUpdate), 'clock_update must avoid duplicate pending render');
assert(/auto_minute\s*%\s*5UL/.test(clockUpdate), 'DAILY_5_MIN cadence missing');
assert(/HINK_AUTO_FLAG_TEST/.test(clockUpdate), 'TEST_1_MIN path missing');
assert(/auto_minute\s*\/\s*1440UL/.test(clockUpdate), 'day rollover force check missing');
assert(/hink_auto_pending_minute\s*=\s*auto_minute/.test(clockUpdate), 'scheduler must overwrite pending with latest minute');
assert(/HINK_AUTO_TRY_SCHEDULE\s*\(\s*\)/.test(clockUpdate), 'clock_update must try to schedule when idle');

assert(/HINK_E5_STATE_ACTIVE/.test(firmware), 'busy guard must include E5 active');
assert(/HINK_E6_STATE_ACCEPTED_PENDING/.test(firmware) && /HINK_E6_STATE_REFRESHING/.test(firmware), 'busy guard must include E6 accepted/refreshing');
assert(/HINK_D2_RENDER_ACCEPTED/.test(firmware) && /HINK_D2_RENDER_RENDERING/.test(firmware), 'busy guard must include D2D accepted/rendering');
assert(/epd_wait_hnd\s*==\s*EASY_TIMER_INVALID_TIMER/.test(firmware), 'busy guard must include EPD wait timer');
assert(/app_easy_timer\s*\(\s*5\s*,\s*hink_d2_render_timer_cb\s*\)/.test(firmware), 'auto scheduler must reuse D2D render timer');

assert(!/clock_draw\s*\(/.test(renderTimer), 'D2D timer must not use legacy clock_draw');
assert(/memset\s*\(\s*fb_bw\s*,\s*0xff/i.test(renderTimer), 'D2D timer must render into existing fb_bw');
assert(!/memset\s*\(\s*fb_rr/.test(renderTimer), 'D2D path must not touch fb_rr');
assert(!/malloc\s*\(/.test(firmware), 'firmware must not use malloc');
assert(!/static[^;\n]*4000|hink_auto[^;\n]*\[/.test(firmware), 'must not add framebuffer or auto arrays');
assert(!/printk\s*\([^\r\n)]*(auto|AUTO|D3B)/.test(firmware), 'must not add auto scheduler printk strings');

assert(/hink_auto_last_rendered_minute\s*=\s*auto_minute/.test(waitTimer), 'COMPLETE must update last_rendered minute');
assert(/hink_auto_pending_minute\s*==\s*auto_minute/.test(waitTimer), 'COMPLETE must compare pending minute');
assert(/hink_auto_flags\s*&=\s*\(uint8_t\)~HINK_AUTO_FLAG_PENDING/.test(waitTimer), 'COMPLETE must clear matching pending flag');
assert(/HINK_AUTO_TRY_SCHEDULE\s*\(\s*\)/.test(waitTimer), 'COMPLETE must schedule newer pending minute');
assert(!/HINK_AUTO_TRY_SCHEDULE\s*\(\s*\)[\s\S]{0,120}HINK_D2_RENDER_ERROR/.test(renderTimer), 'ERROR path must not immediate retry loop');

const changedWeb = execSync('git diff --name-only -- web test.html firmware/active/HINK213_CLOCK_22_BASE/src/epd', { cwd: root, encoding: 'utf8' })
  .trim()
  .split(/\r?\n/)
  .filter(Boolean)
  .filter((name) => name !== 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c');
assert(changedWeb.length === 0, `unexpected web/test/EPD changes: ${changedWeb.join(', ')}`);

console.log('TASK D3B auto-minute scheduler smoke PASS');
