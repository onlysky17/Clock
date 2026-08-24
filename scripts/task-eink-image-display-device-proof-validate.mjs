#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = process.cwd();
const rel = {
  frame: 'firmware/active/HINK213_CLOCK_22_BASE/src/hink_image_display_proof_frame.inc',
  app: 'firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c',
  impl: 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c',
  header: 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.h',
  epd: 'firmware/active/HINK213_CLOCK_22_BASE/src/epd/epd.c',
  gui: 'firmware/active/HINK213_CLOCK_22_BASE/src/epd/epd_gui.c',
  epdHeader: 'firmware/active/HINK213_CLOCK_22_BASE/src/epd/epd.h',
  uploader: 'web/clock-app/image-upload.mjs'
};
const read = (name) => readFileSync(resolve(root, rel[name]), 'utf8');
const options = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  options.set(process.argv[index], process.argv[index + 1]);
}
const ownerFramePath = options.get('--owner-frame');
assert.ok(ownerFramePath, 'Owner Photo Device Proof v2 requires --owner-frame');

const frameText = read('frame');
const body = frameText.slice(frameText.indexOf('{') + 1, frameText.lastIndexOf('}'));
const frame = Uint8Array.from([...body.matchAll(/0x([0-9A-Fa-f]{2})/g)], match => Number.parseInt(match[1], 16));
const ownerFrame = readFileSync(resolve(ownerFramePath));

assert.equal(frame.length, 4000, 'packed frame must be exactly 4000 bytes');
assert.equal(ownerFrame.length, 4000, 'Owner source frame must be exactly 4000 bytes');
assert.deepEqual(Buffer.from(frame), ownerFrame, 'embedded frame must match Owner source byte-for-byte');
const height = 250;
const stride = 16;
for (let y = 0; y < height; y += 1) {
  assert.equal(frame[y * stride + 15] & 0x3F, 0x3F, 'row ' + y + ' padding must be white');
}

const epdHeader = read('epdHeader');
assert.match(epdHeader, /EPD_FRAME_WIDTH\s+122/);
assert.match(epdHeader, /EPD_FRAME_HEIGHT\s+250/);
assert.match(epdHeader, /EPD_FRAME_STRIDE\s+16/);
assert.match(epdHeader, /#define\s+BLACK\s+0/);
assert.match(epdHeader, /#define\s+WHITE\s+1/);
const gui = read('gui');
assert.match(gui, /byte_pos\s*=\s*ny\s*\*\s*line_bytes\s*\+\s*\(nx\s*>>\s*3\)/);
assert.match(gui, /0x80\s*>>\s*\(nx\s*&\s*7\)/);
const epd = read('epd');
assert.match(epd, /offset\s*=\s*row\s*\*\s*line_bytes/);
assert.match(epd, /epd_data\(fb_bw\[offset\+col\]\)/);
assert.match(epd, /write RAM for black\(0\)\/white\(1\)/);

const app = read('app');
assert.match(app, /#define\s+HINK_IMAGE_DISPLAY_PROOF_MODE\s+1U/);
assert.match(app, /#if HINK_IMAGE_DISPLAY_PROOF_MODE[\s\S]*hink_image_display_proof_draw\(\)[\s\S]*#else[\s\S]*QR_draw\(\)[\s\S]*app_clock_timer_restart\(\)[\s\S]*#endif/);
const impl = read('impl');
assert.match(impl, /memcpy\(fb_bw,\s*hink_image_display_proof_frame,\s*EPD_FRAME_BYTES\)/);
assert.match(impl, /epd_update_mode\(UPDATE_FULL\)[\s\S]*epd_init\(\)[\s\S]*epd_screen_update\(\)[\s\S]*epd_update\(\)/);
assert.match(read('header'), /void\s+hink_image_display_proof_draw\(void\)/);

const uploader = read('uploader');
assert.match(uploader, /FRAME_WIDTH\s*=\s*122/);
assert.match(uploader, /FRAME_HEIGHT\s*=\s*250/);
assert.match(uploader, /FRAME_STRIDE\s*=\s*16/);
assert.match(uploader, /1\s*<<\s*\(7\s*-\s*\(x\s*&\s*7\)\)/);

const sha = createHash('sha256').update(frame).digest('hex').toUpperCase();
assert.equal(sha, '9E60ADE332ED6E8F30ED4407580F458C23E253060BFEB69DD4397AE5AE87874D');
console.log('PASS: EINK Owner Photo Device Proof v2');
console.log('FRAME: 122x250, 16 bytes/row, 4000 bytes');
console.log('MAPPING: top-to-bottom rows, left-to-right columns, MSB-first, 1=white, 0=black');
console.log('PADDING: six trailing bits per row are white');
console.log('OWNER_FRAME_BYTE_MATCH: PASS');
console.log('OWNER_FRAME_SHA256: ' + sha);

const buildLogPath = options.get('--build-log');
const rawPath = options.get('--raw');
const packedPath = options.get('--packed');
if (buildLogPath || rawPath || packedPath) {
  assert.ok(buildLogPath && rawPath && packedPath, 'build evidence requires --build-log, --raw and --packed together');
  const buildLog = readFileSync(resolve(buildLogPath), 'utf8');
  assert.match(buildLog, /Using Compiler 'V6\.24'/);
  assert.match(buildLog, /0 Error\(s\), 0 Warning\(s\)\./);

  const raw = readFileSync(resolve(rawPath));
  assert.ok(raw.length > 0 && raw.length <= 65528, 'raw firmware size must be 1..65528 bytes');
  assert.ok(raw.indexOf(frame) >= 0, 'compiled raw firmware must contain the exact 4000-byte Owner frame');

  const packed = readFileSync(resolve(packedPath));
  assert.equal(packed.length, 262144, 'packed SPI artifact must be exactly 262144 bytes');
  assert.equal(packed[0], 0x70, '7050 signature byte 0 missing');
  assert.equal(packed[1], 0x50, '7050 signature byte 1 missing');
  assert.equal(packed[0x4000], 0x70, '7051 signature byte 0 missing');
  assert.equal(packed[0x4001], 0x51, '7051 signature byte 1 missing');
  assert.equal(packed[0x4002], 0xAA, 'packed valid flag must be 0xAA');
  assert.equal(packed[0x38000], 0x70, '7052 signature byte 0 missing');
  assert.equal(packed[0x38001], 0x52, '7052 signature byte 1 missing');
  const payloadSize = packed.readUInt32LE(0x4004);
  const storedCrc = packed.readUInt32LE(0x4008);
  let computedCrc = 0xFFFFFFFF;
  for (const value of packed.subarray(0x4040, 0x4040 + payloadSize)) {
    computedCrc = (computedCrc ^ value) >>> 0;
    for (let bit = 0; bit < 8; bit += 1) {
      computedCrc = ((computedCrc & 1) !== 0
        ? ((computedCrc >>> 1) ^ 0xEDB88320)
        : (computedCrc >>> 1)) >>> 0;
    }
  }
  computedCrc = (computedCrc ^ 0xFFFFFFFF) >>> 0;
  assert.equal(payloadSize, raw.length, 'packed payload size must match raw firmware');
  assert.equal(storedCrc, computedCrc, 'packed payload CRC32 must match');
  assert.deepEqual(packed.subarray(0x4040, 0x4040 + raw.length), raw, 'packed payload must match raw firmware');

  console.log('BUILD: Compiler V6.24, 0 Error(s), 0 Warning(s)');
  console.log('RAW_SIZE: ' + raw.length);
  console.log('RAW_SHA256: ' + createHash('sha256').update(raw).digest('hex').toUpperCase());
  console.log('ARTIFACT_SIZE: ' + packed.length);
  console.log('ARTIFACT_SHA256: ' + createHash('sha256').update(packed).digest('hex').toUpperCase());
  console.log('PACKET_VALIDATION: HEADER_CRC_PAYLOAD_PASS');
}
