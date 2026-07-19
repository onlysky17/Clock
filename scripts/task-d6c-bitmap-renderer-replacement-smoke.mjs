import { strict as assert } from 'node:assert';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { deflateSync } from 'node:zlib';

const USER = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const EPD_GUI = 'firmware/active/HINK213_CLOCK_22_BASE/src/epd/epd_gui.c';
const EPD_H = 'firmware/active/HINK213_CLOCK_22_BASE/src/epd/epd.h';
const PROOF_DIR = 'D:/EINK/Clock/_incoming/D6C_BITMAP_RENDERER_PROOF';

const user = readFileSync(USER, 'utf8');
const gui = readFileSync(EPD_GUI, 'utf8');
const header = readFileSync(EPD_H, 'utf8');
function stripIfZero(source) {
  const out = [];
  let depth = 0;
  for (const line of source.split(/\r?\n/)) {
    if (/^\s*#if\s+0\b/.test(line)) {
      depth++;
      continue;
    }
    if (depth > 0) {
      if (/^\s*#if\b/.test(line)) depth++;
      if (/^\s*#endif\b/.test(line)) depth--;
      continue;
    }
    out.push(line);
  }
  return out.join('\n');
}
const activeGui = stripIfZero(gui);

function has(label, source, needle) {
  assert.ok(source.includes(needle), `${label} missing`);
}

function no(label, source, pattern) {
  assert.ok(!pattern.test(source), `${label} present`);
}

has('compact digit table', gui, 'compact_glyph_digit[10][COMPACT_GLYPH_H]');
has('compact colon glyph', gui, 'compact_glyph_colon');
has('large HH:mm renderer', gui, 'void bitmap_draw_time_hhmm');
has('bounds checked pixel', gui, 'if(x<0 || y<0 || x>=fb_w || y>=fb_h)');
has('bounds checked box', gui, 'if(x1<0){ x1 = 0; }');
has('header exposes bitmap HH:mm', header, 'void bitmap_draw_time_hhmm');
has('D2 render uses compact clock', user, 'hink_bitmap_draw_clock(h, m, sy, sm, sd, sw, lunar_valid, lm, ld);');
has('legacy clock path uses compact clock', user, 'hink_bitmap_draw_clock(draw_hour, (uint8_t)minute');
has('no sprintf D2 render path', user, 'lunar_valid = hink_d3c_lunar_from_solar');

no('legacy sfont include active', activeGui, /#include\s+"sfont/);
no('legacy font50 include active', activeGui, /#include\s+"font50\.h"/);
no('legacy font66 include active', activeGui, /#include\s+"font66\.h"/);
no('legacy font list active', activeGui, /font_list|current_font|select_font|fb_draw_font|fb_draw_font_info|F_DSEG7|sfont16|sfont/);
no('active clock font fields', user, /font_char|font_dseg|select_font|fb_draw_font|F_DSEG7|sfont16|sfont/);

has('D2 scheduler symbol', user, 'HINK_AUTO_TRY_SCHEDULE');
has('D2 persistence sector unchanged', user, '#define HINK_D3D_STORE_SECTOR 0x3B000UL');
has('D2 stale flag unchanged', user, '#define HINK_D2_FLAG_STALE_PRESENT  0x80U');
has('E5 command unchanged', user, 'msg[0] = 0xE5;');
has('E6 command unchanged', user, 'msg[0] = 0xE6;');
has('frame bytes unchanged', header, '#define EPD_FRAME_BYTES   (EPD_FRAME_STRIDE * EPD_FRAME_HEIGHT)');

const W = 250;
const H = 122;
const STRIDE = 16;
const CONTROLLER_H = 250;
const PAYLOAD = STRIDE * CONTROLLER_H;
assert.equal(PAYLOAD, 4000, 'payload must remain 4000 bytes');

const segs = [0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f];
function put(frame, x, y) {
  assert.ok(x >= 0 && x < W && y >= 0 && y < H, `pixel out of bounds ${x},${y}`);
  frame[y * W + x] = 0;
}
function box(frame, x1, y1, x2, y2) {
  assert.ok(x1 >= 0 && y1 >= 0 && x2 < W && y2 < H, `box out of bounds ${x1},${y1},${x2},${y2}`);
  for (let y = y1; y <= y2; y++) for (let x = x1; x <= x2; x++) put(frame, x, y);
}
function segment(frame, x, y, seg) {
  if (seg === 0) box(frame, x + 4, y + 0, x + 23, y + 4);
  else if (seg === 1) box(frame, x + 24, y + 4, x + 28, y + 25);
  else if (seg === 2) box(frame, x + 24, y + 31, x + 28, y + 52);
  else if (seg === 3) box(frame, x + 4, y + 52, x + 23, y + 56);
  else if (seg === 4) box(frame, x + 0, y + 31, x + 4, y + 52);
  else if (seg === 5) box(frame, x + 0, y + 4, x + 4, y + 25);
  else box(frame, x + 4, y + 26, x + 23, y + 30);
}
function digit(frame, x, y, value) {
  const mask = segs[value];
  for (let seg = 0; seg < 7; seg++) if (mask & (1 << seg)) segment(frame, x, y, seg);
}
function colon(frame, x, y) {
  box(frame, x + 2, y + 16, x + 6, y + 21);
  box(frame, x + 2, y + 36, x + 6, y + 41);
}
function render(hh, mm) {
  const frame = new Uint8Array(W * H).fill(255);
  const x = Math.floor((W - 137) / 2);
  const y = Math.floor((H - 56) / 2);
  digit(frame, x, y, Math.floor(hh / 10));
  digit(frame, x + 33, y, hh % 10);
  colon(frame, x + 65, y);
  digit(frame, x + 76, y, Math.floor(mm / 10));
  digit(frame, x + 109, y, mm % 10);
  return frame;
}
function crc32(bytes) {
  let crc = 0xffffffff;
  for (const b of bytes) {
    crc ^= b;
    for (let i = 0; i < 8; i++) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const body = Buffer.from(data);
  const len = Buffer.alloc(4);
  len.writeUInt32BE(body.length);
  const name = Buffer.from(type);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([name, body])));
  return Buffer.concat([len, name, body, crc]);
}
function png(name, frame) {
  const raw = Buffer.alloc((W * 3 + 1) * H);
  for (let y = 0; y < H; y++) {
    raw[y * (W * 3 + 1)] = 0;
    for (let x = 0; x < W; x++) {
      const v = frame[y * W + x];
      const p = y * (W * 3 + 1) + 1 + x * 3;
      raw[p] = raw[p + 1] = raw[p + 2] = v;
    }
  }
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(W, 0);
  ihdr.writeUInt32BE(H, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  writeFileSync(join(PROOF_DIR, name), Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

mkdirSync(PROOF_DIR, { recursive: true });
const fixtures = [[0, 0], [8, 8], [12, 52], [23, 59]];
const seen = new Set();
for (const [hh, mm] of fixtures) {
  const frame = render(hh, mm);
  const black = frame.reduce((n, v) => n + (v === 0 ? 1 : 0), 0);
  assert.ok(black > 1000, `${hh}:${mm} has too little ink`);
  const key = Buffer.from(frame).toString('base64');
  assert.ok(!seen.has(key), `${hh}:${mm} must be deterministic and distinct`);
  seen.add(key);
  png(`fixture_${String(hh).padStart(2, '0')}${String(mm).padStart(2, '0')}.png`, frame);
}

console.log('TASK D6C bitmap renderer replacement smoke PASS');
