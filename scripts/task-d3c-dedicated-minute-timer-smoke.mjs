import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = 'D:/EINK/Clock';
const firmwarePath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`;
const peripheralPath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c`;
const webPath = `${root}/web/clock-app/hl24a-canvas-e5.html`;
const firmware = readFileSync(firmwarePath, 'utf8');
const peripheral = readFileSync(peripheralPath, 'utf8');
const web = readFileSync(webPath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function stripDisabled(source) {
  return source
    .split(/\r?\n/)
    .reduce((state, line) => {
      if (/^\s*#if\s+0\b/.test(line)) state.depth += 1;
      if (state.depth === 0) state.lines.push(line);
      if (/^\s*#endif\b/.test(line) && state.depth > 0) state.depth -= 1;
      return state;
    }, { depth: 0, lines: [] })
    .lines.join('\n');
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
        if (source[i] === '{') depth++;
        if (source[i] === '}') depth--;
        if (depth === 0) return source.slice(brace, i + 1);
      }
    }
  }
  throw new Error(`missing function ${name}`);
}

const active = stripDisabled(firmware);
const setTime = functionBody(active, 'hink_d2_time_handle');
const clockUpdate = functionBody(active, 'clock_update');
const noteMinute = functionBody(active, 'hink_auto_note_minute');
const cancelMinute = functionBody(active, 'hink_d2_minute_cancel');
const startCb = functionBody(active, 'hink_d2_minute_start_cb');
const minuteCb = functionBody(active, 'hink_d2_minute_timer_cb');
const dedicatedActive = functionBody(active, 'hink_d2_dedicated_clock_active');
const renderTimer = functionBody(active, 'hink_d2_render_timer_cb');
const clockTimerCb = functionBody(peripheral, 'app_clock_timer_cb');
const clockStop = functionBody(peripheral, 'app_clock_timer_stop');
const advRestartCb = functionBody(peripheral, 'hink_d2_adv_restart_timer_cb');
const disconnectCb = functionBody(peripheral, 'user_app_disconnect');

const branch = execSync('git branch --show-current', { cwd: root, encoding: 'utf8' }).trim();
assert(branch === 'task-d/d3c-minute-boundary-race', `wrong branch: ${branch}`);

assert(/#define\s+HINK_D2_STATUS_LEN\s+15U/.test(active), 'D2 status length must remain canonical 15 bytes');
assert(!/hink_diag_(tick|boundary|accept|callback)_count/.test(active), 'old diagnostic counters must not remain');
assert(!/bytes\.length\s*<\s*15/.test(web), 'web diagnostic parser change must not be present');
assert(/bytes\.length\s*!==\s*15/.test(web), 'web parser must remain canonical 15-byte parser');

assert(/static\s+timer_hnd\s+hink_d2_minute_timer_hnd\s+__SECTION_ZERO\("retention_mem_area0"\)/.test(active), 'dedicated minute timer handle missing');
assert(/static\s+timer_hnd\s+hink_d2_start_timer_hnd\s+__SECTION_ZERO\("retention_mem_area0"\)/.test(active), 'deferred start timer handle missing');
assert(/static\s+uint8_t\s+hink_d2_first_interval_seconds\s+__SECTION_ZERO\("retention_mem_area0"\)/.test(active), 'first interval state missing');
assert(/static\s+uint8_t\s+hink_d2_timer_flags\s+__SECTION_ZERO\("retention_mem_area0"\)/.test(active), 'dedicated active flag state missing');
assert(/#define\s+HINK_D2_TIMER_ACTIVE\s+0x01U/.test(active), 'dedicated active flag missing');
assert(/#define\s+HINK_D2_TIMER_FIRST\s+0x02U/.test(active), 'dedicated first tick flag missing');
assert(/static\s+timer_hnd\s+hink_d2_adv_restart_timer_hnd\s+__SECTION_ZERO\("retention_mem_area0"\)/.test(peripheral), 'deferred D2 advertising timer handle missing');
assert(/static\s+uint32_t\s+hink_auto_rendering_minute\s+__SECTION_ZERO\("retention_mem_area0"\)/.test(active), 'rendering minute snapshot must be a single uint32 RAM field');
assert(/hink_auto_rendering_minute\s*=\s*hink_auto_pending_minute[\s\S]*hink_d2_render_state\s*=\s*HINK_D2_RENDER_ACCEPTED/.test(active), 'auto schedule must snapshot pending minute before ACCEPTED');
assert(/app_easy_timer\s*\(\s*5\s*,\s*hink_d2_render_timer_cb\s*\)\s*==\s*EASY_TIMER_INVALID_TIMER[\s\S]*hink_auto_rendering_minute\s*=\s*HINK_AUTO_SENTINEL/.test(active), 'auto schedule error must clear rendering snapshot');

assert(/extern\s+void\s+app_clock_timer_stop\s*\(\s*void\s*\);/.test(active), 'narrow legacy timer stop extern missing');
assert(/uint8_t\s+hink_d2_dedicated_clock_active\s*\(\s*void\s*\)/.test(active), 'dedicated clock active helper missing');
assert(/hink_d2_synced_epoch\s*!=\s*0UL/.test(dedicatedActive), 'dedicated helper must require synced D2 time');
assert(/hink_d2_timer_flags\s*&\s*HINK_D2_TIMER_ACTIVE/.test(dedicatedActive), 'dedicated helper must check dedicated timer active flag');
assert(/extern\s+uint8_t\s+hink_d2_dedicated_clock_active\s*\(\s*void\s*\);/.test(peripheral), 'peripheral must use narrow dedicated active helper');
assert(/if\s*\(\s*app_clock_timer_used\s*!=\s*EASY_TIMER_INVALID_TIMER\s*\)[\s\S]*app_easy_timer_cancel\s*\(\s*app_clock_timer_used\s*\)[\s\S]*app_clock_timer_used\s*=\s*EASY_TIMER_INVALID_TIMER/.test(clockStop), 'app_clock_timer_stop must guard invalid handle');
assert(!/app_easy_timer\s*\(/.test(clockStop), 'app_clock_timer_stop must not create timers');
assert(!/user_app_adv_start|clock_draw|QR_draw/.test(clockStop), 'app_clock_timer_stop must not advertise or draw');
assert(/hink_d2_adv_restart_timer_hnd\s*=\s*EASY_TIMER_INVALID_TIMER/.test(functionBody(peripheral, 'user_app_init')), 'deferred advertising handle must be initialized');

const setBranch = setTime.match(/if\s*\(\s*subcmd\s*==\s*0x00U\s*\)([\s\S]*?)if\s*\(\s*subcmd\s*==\s*0x02U\s*\)/);
assert(setBranch, 'D2 SET_TIME branch missing');
const setBlock = setBranch[1];
assert(!/app_clock_timer_restart\s*\(/.test(setBlock), 'SET_TIME must not call legacy app_clock_timer_restart');
assert(/hink_d2_minute_cancel\s*\(\s*\)/.test(setBlock), 'SET_TIME must cancel existing dedicated timers safely');
assert(/hnd\s*=\s*app_easy_timer\s*\(\s*1\s*,\s*hink_d2_minute_start_cb\s*\)/.test(setBlock), 'SET_TIME must schedule only the deferred D2 start callback');
assert(/if\s*\(\s*hnd\s*!=\s*EASY_TIMER_INVALID_TIMER\s*\)[\s\S]*hink_d2_start_timer_hnd\s*=\s*hnd/.test(setBlock), 'SET_TIME must validate deferred start timer handle');
assert(/HINK_AUTO_TRY_SCHEDULE\s*\(\s*\)/.test(setBlock), 'initial D2D render schedule must remain');
assert(/hink_auto_rendering_minute\s*=\s*HINK_AUTO_SENTINEL/.test(setBlock), 'SET_TIME must reset render snapshot before initial schedule');

assert(/if\s*\(\s*hink_d2_minute_timer_hnd\s*!=\s*EASY_TIMER_INVALID_TIMER\s*\)[\s\S]*app_easy_timer_cancel\s*\(\s*hink_d2_minute_timer_hnd\s*\)/.test(cancelMinute), 'minute cancel must guard minute handle');
assert(/if\s*\(\s*hink_d2_start_timer_hnd\s*!=\s*EASY_TIMER_INVALID_TIMER\s*\)[\s\S]*app_easy_timer_cancel\s*\(\s*hink_d2_start_timer_hnd\s*\)/.test(cancelMinute), 'minute cancel must guard deferred start handle');

assert(/hink_d2_start_timer_hnd\s*=\s*EASY_TIMER_INVALID_TIMER/.test(startCb), 'deferred start must invalidate its own handle');
assert(/app_clock_timer_stop\s*\(\s*\)/.test(startCb), 'deferred start must stop the legacy timer');
assert(/second_now\s*=\s*\(uint8_t\)\(local_seconds\s*%\s*60UL\)/.test(startCb), 'deferred start must derive current second from local epoch');
assert(/hink_d2_first_interval_seconds\s*=\s*\(second_now\s*==\s*0U\)\s*\?\s*60U\s*:\s*\(uint8_t\)\(60U\s*-\s*second_now\)/.test(startCb), 'first interval must handle second == 0 as 60 seconds');
assert(/hink_d2_timer_flags\s*=\s*HINK_D2_TIMER_ACTIVE\s*\|\s*HINK_D2_TIMER_FIRST/.test(startCb), 'deferred start must mark dedicated timer active and first tick pending');
assert(/hink_d2_arm_minute_timer\s*\(\s*hink_d2_first_interval_seconds\s*\)/.test(startCb), 'deferred start must arm first minute timer');

assert(/hink_d2_minute_timer_hnd\s*=\s*EASY_TIMER_INVALID_TIMER/.test(minuteCb), 'minute callback must invalidate current handle on entry');
assert(/elapsed\s*=\s*hink_d2_first_interval_seconds/.test(minuteCb), 'first callback must use stored first interval');
assert(/elapsed\s*=\s*60U/.test(minuteCb), 'later callbacks must advance exactly 60 seconds');
assert(/hink_d2_uptime_seconds\s*\+=\s*\(uint32_t\)elapsed/.test(minuteCb), 'dedicated callback must advance D2 uptime');
assert(/hink_auto_note_minute\s*\(\s*auto_minute\s*\)/.test(minuteCb), 'dedicated callback must reuse auto policy helper');
assert(minuteCb.indexOf('hink_d2_arm_minute_timer(60U);') < minuteCb.indexOf('HINK_AUTO_TRY_SCHEDULE();'), 'dedicated callback must rearm before scheduling render');
assert(/HINK_AUTO_TRY_SCHEDULE\s*\(\s*\)/.test(minuteCb), 'dedicated callback must use existing async scheduler');
assert(!/clock_update\s*\(|clock_draw\s*\(|QR_draw\s*\(|user_app_adv_start\s*\(|epd_screen_update\s*\(|epd_update\s*\(|memset\s*\(\s*fb_rr|0xE5/.test(minuteCb), 'dedicated callback must not call legacy draw, advertising, E5, or EPD refresh directly');

const epdWait = functionBody(active, 'epd_wait_timer');
assert(/auto_minute\s*=\s*hink_auto_rendering_minute/.test(epdWait), 'D2D COMPLETE must use the accepted render snapshot');
assert(/if\s*\(\s*auto_minute\s*==\s*HINK_AUTO_SENTINEL\s*\)[\s\S]*auto_minute\s*=\s*hink_auto_local_minute_key/.test(epdWait), 'manual D2D render must keep current-minute fallback');
assert(/hink_auto_pending_minute\s*==\s*auto_minute[\s\S]*hink_auto_flags\s*&=\s*\(uint8_t\)~HINK_AUTO_FLAG_PENDING/.test(epdWait), 'COMPLETE must clear only the pending minute that was rendered');
assert(/hink_auto_rendering_minute\s*=\s*HINK_AUTO_SENTINEL[\s\S]*hink_d2_render_notify\(HINK_D2_RESULT_OK,\s*HINK_D2_RENDER_COMPLETE\)/.test(epdWait), 'COMPLETE must clear render snapshot before notify/scheduling next pending');
assert(/hink_d2_render_state\s*=\s*HINK_D2_RENDER_ERROR[\s\S]*hink_auto_rendering_minute\s*=\s*HINK_AUTO_SENTINEL/.test(renderTimer), 'D2D render error must clear render snapshot');

assert(/hink_d2_adv_restart_timer_hnd\s*=\s*EASY_TIMER_INVALID_TIMER/.test(advRestartCb), 'deferred advertising callback must invalidate its own handle');
assert(/app_connection_idx\s*==\s*-1/.test(advRestartCb), 'deferred advertising callback must verify the link is still disconnected');
assert(/adv_state\s*==\s*0/.test(advRestartCb), 'deferred advertising callback must guard against double advertising');
assert((advRestartCb.match(/user_app_adv_start\s*\(/g) || []).length === 1, 'deferred advertising callback must start advertising exactly once');
assert(!/QR_draw\s*\(|clock_draw\s*\(|app_easy_timer_cancel\s*\(/.test(advRestartCb), 'deferred advertising callback must not draw or cancel timers');

const d2DisconnectStart = disconnectCb.indexOf('hink_d2_dedicated_clock_active()');
const legacyDisconnectStart = disconnectCb.indexOf('if(param->reason', d2DisconnectStart);
assert(d2DisconnectStart >= 0 && legacyDisconnectStart > d2DisconnectStart, 'dedicated disconnect guard must run before legacy disconnect flow');
const d2DisconnectBlock = disconnectCb.slice(d2DisconnectStart, legacyDisconnectStart);
assert(/hink_d2_adv_restart_timer_hnd\s*==\s*EASY_TIMER_INVALID_TIMER/.test(d2DisconnectBlock), 'dedicated disconnect must guard deferred advertising timer handle');
assert(/hnd\s*=\s*app_easy_timer\s*\(\s*1\s*,\s*hink_d2_adv_restart_timer_cb\s*\)/.test(d2DisconnectBlock), 'dedicated disconnect must defer advertising restart with one-shot app timer');
assert(/if\s*\(\s*hnd\s*!=\s*EASY_TIMER_INVALID_TIMER\s*\)[\s\S]*hink_d2_adv_restart_timer_hnd\s*=\s*hnd/.test(d2DisconnectBlock), 'dedicated disconnect must validate deferred advertising handle before storing');
assert(/return\s*;/.test(d2DisconnectBlock), 'dedicated disconnect must skip legacy visual flow');
assert(!/QR_draw\s*\(|clock_draw\s*\(|user_app_adv_start\s*\(|app_easy_timer_cancel\s*\(\s*hink_d2_(minute|start)/.test(d2DisconnectBlock), 'dedicated disconnect must not draw, start advertising directly, or cancel the dedicated timer');
assert(/if\(param->reason!=CO_ERROR_REMOTE_USER_TERM_CON\)[\s\S]*user_app_adv_start\s*\(\s*\)[\s\S]*QR_draw\s*\(\s*\)[\s\S]*clock_draw\s*\(\s*UPDATE_FLY\s*\)/.test(disconnectCb), 'legacy disconnect behavior must remain for inactive D2 mode');

assert(/if\s*\(\s*\(hink_d2_timer_flags\s*&\s*HINK_D2_TIMER_ACTIVE\)\s*==\s*0U\s*\)[\s\S]*hink_d2_uptime_seconds\s*\+=\s*\(uint32_t\)inc/.test(clockUpdate), 'clock_update must not advance D2 uptime while dedicated timer is active');
assert(/hink_auto_note_minute\s*\(\s*auto_minute\s*\)/.test(clockUpdate), 'legacy clock_update must reuse auto policy before dedicated mode');
assert(/auto_minute\s*%\s*5UL/.test(noteMinute), 'minute % 5 policy must remain');
assert(/auto_minute\s*\/\s*1440UL/.test(noteMinute), 'day rollover policy must remain');
assert(/hink_auto_pending_minute\s*=\s*auto_minute/.test(noteMinute), 'pending minute assignment must remain');
assert(/hink_auto_flags\s*\|=\s*HINK_AUTO_FLAG_PENDING/.test(noteMinute), 'pending flag assignment must remain');

assert(/clock_update\s*\(\s*update_seconds\s*\)/.test(clockTimerCb), 'legacy app_clock_timer_cb must not be deleted');
assert(/hink_d3c_lunar_from_solar/.test(active), 'D3C lunar renderer must remain');
assert(/HINK_D3C_LUNAR_MIN_YEAR\s+2024U/.test(active) && /HINK_D3C_LUNAR_MAX_YEAR\s+2051U/.test(active), 'bounded lunar range must remain 2024..2051');
assert(/AL --\/--/.test(active), 'out-of-range lunar fallback must remain');
assert(!/"AM /.test(active), 'lunar display label must be AL, not AM');
assert(/hink_d2_render_timer_cb/.test(active) && /epd_wait_timer/.test(active), 'D2D render-only and E6 async wait path must remain');
assert(!/malloc\s*\(|printk\s*\(\s*\".*D2|flash_write|fspi_write/.test(active), 'no malloc, D2 printk, or flash writes allowed');

function simulateBoundaryRace(startMinute, boundaryMinute) {
  const sentinel = 0xFFFFFFFF;
  let lastRendered = sentinel;
  let pending = startMinute;
  let rendering = pending;
  let pendingFlag = true;
  const noteMinute = (minute) => {
    if (minute !== lastRendered && (!pendingFlag || minute !== pending)) {
      if ((minute % 5) === 0 || (lastRendered !== sentinel && Math.floor(minute / 1440) !== Math.floor(lastRendered / 1440))) {
        pending = minute;
        pendingFlag = true;
      }
    }
  };
  noteMinute(boundaryMinute);
  lastRendered = rendering;
  if (pendingFlag && pending === rendering) pendingFlag = false;
  rendering = sentinel;
  return { lastRendered, pending, pendingFlag };
}

let race = simulateBoundaryRace(53, 54);
assert(race.lastRendered === 53 && race.pendingFlag === false, '53:57 -> 54 must clear stale initial pending without retrigger');
race = simulateBoundaryRace(54, 55);
assert(race.lastRendered === 54 && race.pendingFlag === true && race.pending === 55, '54:57 -> 55 must keep one valid 5-minute pending render');

const changed = execSync('git status --short', { cwd: root, encoding: 'utf8' })
  .trim()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.replace(/^..?\s+/, ''))
  .sort();
assert(JSON.stringify(changed) === JSON.stringify([
  'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c',
  'scripts/task-d3c-dedicated-minute-timer-smoke.mjs',
]), `unexpected dirty files: ${changed.join(', ')}`);

const forbidden = execSync('git diff --name-only -- web test.html firmware/active/HINK213_CLOCK_22_BASE/src/epd firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c docs scripts/task-d3c-date-lunar-renderer-smoke.mjs', { cwd: root, encoding: 'utf8' }).trim();
assert(forbidden === '', `unexpected out-of-scope changes: ${forbidden}`);

console.log('TASK D3C dedicated minute timer smoke PASS');
