import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDir, '..');
const htmlPath = path.join(root, 'web', 'clock-app', 'image-upload.html');
const cssPath = path.join(root, 'web', 'clock-app', 'image-upload.css');
const modulePath = path.join(root, 'web', 'clock-app', 'image-upload.mjs');
const [html, css, moduleSource, imageModule] = await Promise.all([
  readFile(htmlPath, 'utf8'),
  readFile(cssPath, 'utf8'),
  readFile(modulePath, 'utf8'),
  import(`file://${modulePath.replaceAll('\\', '/')}`)
]);

const { FRAME_WIDTH, FRAME_HEIGHT, FRAME_STRIDE, FRAME_BYTES, computeImagePlacement, orientedDimensions, fitUtilization, chooseAutoRotation, chooseAutoFrameMode, resolveProcessingPlan, thresholdPixels, floydSteinbergPixels, packMonochromeFrame, hasWhitePadding, formatHexDump } = imageModule;
assert.equal(FRAME_WIDTH, 122);
assert.equal(FRAME_HEIGHT, 250);
assert.equal(FRAME_STRIDE, 16);
assert.equal(FRAME_BYTES, 4000);

const pixels = FRAME_WIDTH * FRAME_HEIGHT;
const white = new Uint8Array(pixels).fill(255);
const whitePacked = packMonochromeFrame(white);
assert.equal(whitePacked.length, 4000);
assert.ok(whitePacked.every(value => value === 0xFF));
assert.equal(hasWhitePadding(whitePacked), true);

const black = new Uint8Array(pixels);
const blackPacked = packMonochromeFrame(black);
for (let row = 0; row < FRAME_HEIGHT; row += 1) {
  assert.ok(blackPacked.subarray(row * 16, row * 16 + 15).every(value => value === 0x00));
  assert.equal(blackPacked[row * 16 + 15], 0x3F);
}
assert.equal(hasWhitePadding(blackPacked), true);

const orientation = new Uint8Array(pixels).fill(255);
orientation[0] = 0;
orientation[249 * FRAME_WIDTH + 121] = 0;
const orientedPacked = packMonochromeFrame(orientation);
assert.equal(orientedPacked[0], 0x7F, 'x=0,y=0 must clear MSB of first byte');
assert.equal(orientedPacked[3999], 0xBF, 'x=121,y=249 must clear bit 6 of final byte');
assert.equal(hasWhitePadding(orientedPacked), true);

const gradient = Float32Array.from({ length: pixels }, (_, index) => index % FRAME_WIDTH / (FRAME_WIDTH - 1) * 255);
const threshold = thresholdPixels(gradient, 128);
const ditherA = floydSteinbergPixels(gradient, 128);
const ditherB = floydSteinbergPixels(gradient, 128);
assert.equal(threshold.length, pixels);
assert.ok(threshold.every(value => value === 0 || value === 255));
assert.deepEqual(ditherA, ditherB, 'Floyd-Steinberg output must be deterministic');
assert.ok(ditherA.every(value => value === 0 || value === 255));
assert.notDeepEqual(ditherA, threshold, 'Dither mode must differ from direct threshold on a gradient');

const cover = computeImagePlacement(1000, 500, 'cover');
assert.equal(cover.dw, 122);
assert.equal(cover.dh, 250);
assert.ok(cover.sw < 1000 && cover.sh === 500);
const contain = computeImagePlacement(1000, 500, 'contain');
assert.equal(contain.dw, 122);
assert.ok(contain.dh < 250 && contain.dy > 0);
assert.ok(Math.abs(contain.dw / contain.dh - 2) < 1e-9, 'Fit must preserve source aspect ratio');
assert.ok(Math.abs(cover.sw / cover.sh - FRAME_WIDTH / FRAME_HEIGHT) < 1e-9, 'Fill crop must match target ratio without stretch');

const portraitPlan = resolveProcessingPlan(900, 1600, 'auto', 'auto');
assert.equal(portraitPlan.rotation, 0);
assert.equal(portraitPlan.autoRotated, false);
assert.equal(portraitPlan.resolvedFrameMode, 'fill');
const landscapePlan = resolveProcessingPlan(1600, 900, 'auto', 'auto');
assert.equal(landscapePlan.rotation, 90);
assert.equal(landscapePlan.autoRotated, true);
assert.equal(landscapePlan.orientedWidth, 900);
assert.equal(landscapePlan.orientedHeight, 1600);
assert.equal(landscapePlan.resolvedFrameMode, 'fill');
const squarePlan = resolveProcessingPlan(1000, 1000, 'auto', 'auto');
assert.equal(squarePlan.rotation, 0, 'Square tie must keep original orientation');
assert.equal(squarePlan.resolvedFrameMode, 'fit');
assert.equal(chooseAutoRotation(1600, 900), 90);
assert.equal(chooseAutoRotation(900, 1600), 0);
assert.equal(chooseAutoRotation(1000, 1000), 0);
assert.ok(fitUtilization(900, 1600) > fitUtilization(1600, 900));
assert.equal(chooseAutoFrameMode(900, 1600), 'fill');
assert.equal(chooseAutoFrameMode(1000, 1000), 'fit');

for (const rotation of [0, 90, 180, 270]) {
  const manual = resolveProcessingPlan(1600, 900, 'fit', String(rotation));
  assert.equal(manual.rotation, rotation);
  assert.equal(manual.rotationMode, String(rotation));
  assert.equal(manual.resolvedFrameMode, 'fit');
  const dimensions = orientedDimensions(1600, 900, rotation);
  assert.equal(manual.orientedWidth, dimensions.width);
  assert.equal(manual.orientedHeight, dimensions.height);
}
const forcedFill = resolveProcessingPlan(1000, 1000, 'fill', '270');
assert.equal(forcedFill.resolvedFrameMode, 'fill');
assert.equal(forcedFill.scaleMode, 'cover');
const forcedFit = resolveProcessingPlan(1000, 1000, 'fit', '180');
assert.equal(forcedFit.resolvedFrameMode, 'fit');
assert.equal(forcedFit.scaleMode, 'contain');

const dump = formatHexDump(orientedPacked);
assert.equal(dump.split('\n').length, 250);
assert.match(dump, /^0000  7F/);
assert.match(dump, /0F90  .*BF$/);

for (const marker of ['image/jpeg,image/png', 'originalCanvas', 'thresholdCanvas', 'ditherCanvas', 'downloadBin', 'copyHex', '122 × 250', '4,000 bytes', 'bit 7', '1 = trắng', '0 = đen', 'name="frameMode" value="auto" checked', 'name="frameMode" value="fit"', 'name="frameMode" value="fill"', 'name="rotationMode" value="270"', 'frameModeState', 'rotationState', 'autoNotice']) assert.ok(html.includes(marker), `Missing HTML contract: ${marker}`);
for (const marker of ['image-rendering:pixelated', 'preview-grid', 'panel-bezel', 'rotation-options', 'transform-summary']) assert.ok(css.includes(marker), `Missing CSS contract: ${marker}`);
for (const marker of ['createImageBitmap', 'createOrientedCanvas', 'resolveProcessingPlan', 'floydSteinbergPixels', 'packMonochromeFrame', "new Blob([packedFrame]", 'application/octet-stream']) assert.ok(moduleSource.includes(marker), `Missing module contract: ${marker}`);
for (const forbidden of ['navigator.bluetooth', 'requestDevice(', '0xE5', '0xE6', 'SmartSnippets', 'eink.ps1']) assert.ok(!moduleSource.includes(forbidden) && !html.includes(forbidden), `Out-of-scope behavior found: ${forbidden}`);

console.log('EINK_IMAGE_UPLOAD_V1: PASS');
console.log('FRAME: 122x250');
console.log('PACKED_BYTES: 4000');
console.log('PACKING: ROW_MAJOR_MSB_FIRST_BIT1_WHITE');
console.log('PADDING_BITS: PASS');
console.log('THRESHOLD: PASS');
console.log('FLOYD_STEINBERG: PASS');
console.log('FIT_CROP: PASS');
console.log('AUTO_ORIENTATION_LANDSCAPE_PORTRAIT_SQUARE: PASS');
console.log('MANUAL_ROTATION_0_90_180_270: PASS');
console.log('NO_DISTORTION: PASS');
console.log('BLE_TRANSFER: ABSENT');
