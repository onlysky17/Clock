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
const renderTimer = functionBody(active, 'hink_d2_render_timer_cb');
const waitTimer = functionBody(active, 'epd_wait_timer');
const lunarDerive = functionBody(active, 'hink_d3c_lunar_from_solar');

assert(!/hday_info|jieqi_info|jieqi_name|holiday_str|jieqi_str|set_holiday\s*\(|get_holiday\s*\(|\bjieqi\s*\(/.test(active), 'holiday/jieqi path must be inactive');
assert(/lunar_year_info\[32\]/.test(active), 'must keep existing lunar year table');
assert(/lunar_year_info2/.test(active), 'must keep existing leap-month size bits');
assert(!/lunar_month_days|solar_1_1|LUNAR_SolarToLunar/.test(active), 'must not add large 2099 lunar tables');
assert(/HINK_D3C_LUNAR_ANCHOR_DAY\s+40L/.test(active), 'must use 2024-02-10 anchor day');
assert(/HINK_D3C_LUNAR_ANCHOR_YEAR\s+4U/.test(active), 'must use lunar 2024 anchor index');
assert(/HINK_D3C_LUNAR_MIN_YEAR\s+2024U/.test(active), 'must bound lunar min year');
assert(/HINK_D3C_LUNAR_MAX_YEAR\s+2051U/.test(active), 'must bound lunar max year');
assert(/while\s*\(\s*delta\s*>\s*0\s*\)/.test(lunarDerive), 'lunar derive must advance forward');
assert(/while\s*\(\s*delta\s*<\s*0\s*\)/.test(lunarDerive), 'lunar derive must step backward');
assert(!/l_year|l_month|l_date|ldate_inc\s*\(/.test(lunarDerive), 'lunar derive must not use unseeded global lunar state');

assert(!/clock_draw\s*\(/.test(renderTimer), 'D2D timer must not call clock_draw');
assert(/hink_d2_current_epoch\s*\(\s*\)/.test(renderTimer), 'D2D render must use D2 epoch');
assert(/hink_d2_timezone_minutes/.test(renderTimer), 'D2D render must use timezone');
assert(/hink_d3c_solar_from_day/.test(renderTimer), 'D2D render must derive solar date');
assert(/hink_d3c_lunar_from_solar/.test(renderTimer), 'D2D render must derive bounded lunar date');
assert(/sprintf\s*\(\s*tbuf\s*,\s*"%02d:%02d"/.test(renderTimer), 'D2D render must keep HH:mm');
assert(/case\s+1U:\s*tbuf\[0\]\s*=\s*'T';\s*tbuf\[1\]\s*=\s*'2'/.test(renderTimer), 'weekday T2 label missing');
assert(/default:\s*tbuf\[0\]\s*=\s*'C';\s*tbuf\[1\]\s*=\s*'N'/.test(renderTimer), 'weekday CN label missing');
assert(/sprintf\s*\(&tbuf\[2\],\s*" %02d\/%02d"/.test(renderTimer), 'solar dd/MM render missing');
assert(/sprintf\s*\(\s*tbuf\s*,\s*"AM %02d\/%02d"/.test(renderTimer), 'lunar AM dd/MM render missing');
assert(/sprintf\s*\(\s*tbuf\s*,\s*"AM --\/--"/.test(renderTimer), 'out-of-range lunar fallback missing');
assert(/memset\s*\(\s*fb_bw\s*,\s*0xff/i.test(renderTimer), 'D2D render must clear fb_bw');
assert(!/memset\s*\(\s*fb_rr/.test(renderTimer), 'D2D render must not clear fb_rr');
assert(/epd_hw_open\s*\(/.test(renderTimer) && /epd_screen_update\s*\(/.test(renderTimer), 'D2D async refresh path missing');
assert(/hink_d2_render_notify\s*\(\s*HINK_D2_RESULT_OK\s*,\s*HINK_D2_RENDER_COMPLETE\s*\)/.test(waitTimer), 'D2D COMPLETE notify missing');
assert(/HINK_AUTO_TRY_SCHEDULE\s*\(\s*\)/.test(waitTimer), 'D3B scheduler completion chaining missing');
assert(!/malloc\s*\(/.test(active), 'must not use malloc');
assert(!/static[^;]*4000|fb_[a-z]+2|framebuffer2/.test(active), 'must not add framebuffer');

const lunarInfo = [
  0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260,
  0x0ea65, 0x0d530, 0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0,
  0x0d0b6, 0x0d250, 0x0d520, 0x0dd45, 0x0b5a0, 0x056d0, 0x055b2, 0x049b0,
  0x0a577, 0x0a4b0, 0x0aa50, 0x0b255, 0x06d20, 0x0ada0, 0x04b63, 0x09370,
];
const lunarInfo2 = 0x48010000;

function yinfo(yidx) {
  let v = lunarInfo[yidx];
  if (lunarInfo2 & (1 << yidx)) v |= 0x10000;
  return v;
}

function lunarMdays(yidx, mon, leap) {
  const yi = yinfo(yidx);
  if (leap) return (yi & 0x10000) ? 30 : 29;
  return (yi & (0x8000 >> mon)) ? 30 : 29;
}

function lunarNext(state) {
  state.day++;
  if (state.day <= lunarMdays(state.yidx, state.mon, state.leap)) return;
  state.day = 1;
  const yi = yinfo(state.yidx);
  if (!state.leap && state.mon + 1 === (yi & 0x0f)) {
    state.leap = 1;
  } else {
    state.leap = 0;
    state.mon++;
    if (state.mon >= 12) {
      state.mon = 0;
      state.yidx++;
    }
  }
}

function lunarPrev(state) {
  state.day--;
  if (state.day >= 1) return;
  if (state.leap) {
    state.leap = 0;
  } else {
    if (state.mon === 0) {
      state.yidx--;
      state.mon = 11;
    } else {
      state.mon--;
    }
    if ((yinfo(state.yidx) & 0x0f) === state.mon + 1) state.leap = 1;
  }
  state.day = lunarMdays(state.yidx, state.mon, state.leap);
}

function daysBetween(a, b) {
  return Math.round((Date.UTC(b[0], b[1] - 1, b[2]) - Date.UTC(a[0], a[1] - 1, a[2])) / 86400000);
}

function solarToLunar(y, m, d) {
  if (y < 2024 || y > 2051) return null;
  let delta = daysBetween([2024, 2, 10], [y, m, d]);
  const state = { yidx: 4, mon: 0, day: 1, leap: 0 };
  while (delta > 0) {
    lunarNext(state);
    delta--;
  }
  while (delta < 0) {
    lunarPrev(state);
    delta++;
  }
  return { month: state.mon + 1, day: state.day, leap: state.leap };
}

const vectors = [
  [[2024, 2, 10], { month: 1, day: 1, leap: 0 }],
  [[2025, 1, 29], { month: 1, day: 1, leap: 0 }],
  [[2026, 2, 17], { month: 1, day: 1, leap: 0 }],
  [[2025, 7, 25], { month: 6, day: 1, leap: 1 }],
  [[2026, 2, 16], { month: 12, day: 29, leap: 0 }],
  [[2024, 1, 1], { month: 11, day: 20, leap: 0 }],
  [[2051, 12, 31], { month: 11, day: 29, leap: 0 }],
];

for (const [solar, expected] of vectors) {
  const got = solarToLunar(...solar);
  assert(got && got.month === expected.month && got.day === expected.day && got.leap === expected.leap,
    `${solar.join('-')} lunar vector mismatch: ${JSON.stringify(got)}`);
}
assert(solarToLunar(2052, 1, 1) === null, '2052-01-01 must be out of range');

const changed = execSync('git status --short', { cwd: root, encoding: 'utf8' })
  .trim()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.replace(/^..?\s+/, ''))
  .sort();
assert(JSON.stringify(changed) === JSON.stringify([
  'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c',
  'scripts/task-d3c-date-lunar-renderer-smoke.mjs',
]), `unexpected dirty files: ${changed.join(', ')}`);

const forbidden = execSync('git diff --name-only -- web test.html firmware/active/HINK213_CLOCK_22_BASE/src/epd', { cwd: root, encoding: 'utf8' }).trim();
assert(forbidden === '', `unexpected web/test/EPD changes: ${forbidden}`);

console.log('TASK D3C date + lunar renderer smoke PASS');
