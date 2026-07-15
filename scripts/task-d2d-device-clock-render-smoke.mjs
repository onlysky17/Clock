import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = 'D:/EINK/Clock';
const firmwarePath = `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`;
const webPath = `${root}/web/clock-app/hl24a-canvas-e5.html`;
const testPath = `${root}/test.html`;

const firmware = readFileSync(firmwarePath, 'utf8');
const web = readFileSync(webPath, 'utf8');

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
  assert(open >= 0, `missing function body ${name}`);
  let depth = 0;
  for (let i = open; i < source.length; i++) {
    const ch = source[i];
    if (ch === '{') depth++;
    if (ch === '}') depth--;
    if (depth === 0) return source.slice(open, i + 1);
  }
  throw new Error(`unterminated function ${name}`);
}

const renderHandler = functionBody(firmware, 'hink_d2_render_handle');
const renderTimer = functionBody(firmware, 'hink_d2_render_timer_cb');
const waitTimer = functionBody(firmware, 'epd_wait_timer');
const d2WebFlow = functionBody(web, 'd2RenderClockFromDevice');

assert(/#define\s+HINK_D2_RENDER_LEN\s+2U/.test(firmware), 'D2 02 request length must be 2 bytes');
assert(/#define\s+HINK_D2_RENDER_STATUS_LEN\s+4U/.test(firmware), 'D2 82 response length must be 4 bytes');
assert(/msg\[0\]\s*=\s*0xD2/.test(firmware) && /msg\[1\]\s*=\s*0x82/.test(firmware), 'D2 82 notify bytes missing');
assert(/subcmd\s*==\s*0x02U/.test(firmware), 'D2 02 handler route missing');
assert(!/epd_screen_update|clock_draw|hink_d2_draw_clock_frame/.test(renderHandler), 'BLE write handler must not render directly');
assert(/hink_d2_synced_epoch\s*==\s*0UL/.test(renderHandler), 'D2D initialized guard missing');
assert(/HINK_E5_STATE_ACTIVE/.test(renderHandler), 'D2D E5 busy guard missing');
assert(/HINK_E6_STATE_ACCEPTED_PENDING/.test(renderHandler) && /HINK_E6_STATE_REFRESHING/.test(renderHandler), 'D2D E6 busy guard missing');
assert(/HINK_D2_RENDER_ACCEPTED/.test(renderHandler) && /HINK_D2_RENDER_RENDERING/.test(renderHandler), 'D2D render re-entry guard missing');
assert(/app_easy_timer\s*\(\s*5\s*,\s*hink_d2_render_timer_cb\s*\)/.test(renderHandler), 'D2D must schedule application timer');
assert(!/clock_draw\s*\(/.test(renderTimer), 'D2D timer must not call legacy clock_draw');
assert(/hink_d2_current_epoch\s*\(\s*\)/.test(renderTimer), 'D2D render must use current D2 epoch');
assert(/hink_d2_timezone_minutes/.test(renderTimer), 'D2D render must use timezone offset');
assert(/hink_d2_render_notify\s*\(\s*HINK_D2_RESULT_OK\s*,\s*HINK_D2_RENDER_RENDERING\s*\)/.test(renderTimer), 'D2D timer must notify RENDERING');
assert(/memset\s*\(\s*fb_bw\s*,\s*0xff/i.test(renderTimer), 'D2D render must clear fb_bw white');
assert(!/memset\s*\(\s*fb_rr/.test(renderTimer), 'D2D render must not clear fb_rr');
assert(/select_font\s*\(/.test(renderTimer) && /draw_text\s*\(/.test(renderTimer), 'D2D render must use linked text drawing primitives');
assert(/epd_hw_open\s*\(/.test(renderTimer), 'D2D timer must start EPD hardware open');
assert(/epd_update_mode\s*\(/.test(renderTimer), 'D2D timer must set EPD update mode');
assert(/epd_init\s*\(/.test(renderTimer), 'D2D timer must initialize EPD');
assert(/epd_screen_update\s*\(/.test(renderTimer), 'D2D timer must write framebuffer to EPD RAM');
assert(/epd_update\s*\(/.test(renderTimer), 'D2D timer must trigger EPD update');
assert(/app_easy_timer\s*\(\s*40\s*,\s*epd_wait_timer\s*\)/.test(renderTimer), 'D2D timer must arm EPD wait timer');
assert((renderTimer.match(/epd_screen_update\s*\(/g) || []).length === 1, 'D2D timer must have one physical refresh sequence');
assert(/hink_d2_render_state\s*==\s*HINK_D2_RENDER_RENDERING/.test(waitTimer), 'epd_wait_timer must detect D2D RENDERING');
assert(/hink_d2_render_notify\s*\(\s*HINK_D2_RESULT_OK\s*,\s*HINK_D2_RENDER_COMPLETE\s*\)/.test(waitTimer), 'epd_wait_timer must notify D2D COMPLETE');
assert(!/malloc\s*\(/.test(firmware), 'firmware must not use malloc');
assert(!/hink_d2[^;{]*\[[^\]]*4000|static[^;]*4000/.test(firmware), 'D2D must not add a second framebuffer');
assert(!/hink_e5_framebuffer_handle|sendFramebuffer/.test(renderHandler + renderTimer), 'D2D firmware must not call E5');
assert(!/hink_d2_set_clock_from_epoch|hink_d2_draw_clock_frame|hink_d2_is_leap/.test(firmware), 'D2D must not keep the removed parallel renderer/calendar table');

assert(web.includes('TASK D2D - Device Clock Renderer'), 'document title must be D2D');
assert(web.includes('TASK D2D • DEVICE CLOCK RENDERER • HINK213 BW'), 'badge must be D2D');
assert(web.includes('250×122 Clock → Device-Time Render + E5/E6 Tools'), 'heading must be D2D');
assert(web.includes('Vẽ giờ từ thiết bị lên màn'), 'D2D web button missing');
assert(/Uint8Array\.of\s*\(\s*0xD2\s*,\s*0x02\s*\)/.test(web), 'web D2 02 packet must be exact 2 bytes');
assert(/bytes\.length\s*!==\s*4\|\|bytes\[0\]\s*!==\s*0xD2\|\|bytes\[1\]\s*!==\s*0x82/.test(web), 'web D2 82 parser must require exact 4 bytes');
assert(!/sendFramebuffer|refreshPanel|drawCurrentClock|repack/.test(d2WebFlow), 'D2D button must not call E5/E6 or redraw preview');
assert(/d2Running\|\|busy\|\|e6Running\|\|oneTapRunning/.test(web), 'D2D must use busy guard');

const changedTest = execSync('git diff --name-only -- test.html', { cwd: root, encoding: 'utf8' }).trim();
assert(changedTest === '', `${testPath} must not be modified`);

console.log('TASK D2D device clock render smoke PASS');
