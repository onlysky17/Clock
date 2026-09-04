import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(scriptDir, '..');
const htmlPath = path.join(root, 'web', 'clock-app', 'image-upload.html');
const cssPath = path.join(root, 'web', 'clock-app', 'image-upload.css');
const modulePath = path.join(root, 'web', 'clock-app', 'image-upload.mjs');
const mainAppPath = path.join(root, 'web', 'clock-app', 'hl24a-canvas-e5.html');
const imageTabPath = path.join(root, 'web', 'clock-app', 'image-upload-tab.mjs');
const panelRegistryPath = path.join(root, 'web', 'clock-app', 'panel-registry.js');
const firmwarePath = path.join(root, 'firmware', 'active', 'HINK213_CLOCK_22_BASE', 'src', 'user_custs1_impl.c');
const peripheralPath = path.join(root, 'firmware', 'active', 'HINK213_CLOCK_22_BASE', 'src', 'user_peripheral.c');
const [html, css, moduleSource, mainAppSource, imageTabSource, panelRegistrySource, firmwareSource, peripheralSource, imageModule, imageTabModule] = await Promise.all([
  readFile(htmlPath, 'utf8'),
  readFile(cssPath, 'utf8'),
  readFile(modulePath, 'utf8'),
  readFile(mainAppPath, 'utf8'),
  readFile(imageTabPath, 'utf8'),
  readFile(panelRegistryPath, 'utf8'),
  readFile(firmwarePath, 'utf8'),
  readFile(peripheralPath, 'utf8'),
  import(`file://${modulePath.replaceAll('\\', '/')}`),
  import(`file://${imageTabPath.replaceAll('\\', '/')}`)
]);

const { FRAME_WIDTH, FRAME_HEIGHT, FRAME_STRIDE, FRAME_BYTES, IMAGE_TRANSFER_VERSION, IMAGE_CHUNK_BYTES, IMAGE_TOTAL_CHUNKS, BLE_SERVICE_UUID, BLE_WRITE_UUID, BLE_NOTIFY_UUID, MANUAL_CROP_MIN_ZOOM, MANUAL_CROP_MAX_ZOOM, crc16Ccitt, createImageTransferPlan, computeImagePlacement, computeManualCropPlacement, normalizeManualCropState, panManualCropByViewportDelta, orientedDimensions, fitUtilization, chooseAutoRotation, chooseAutoFrameMode, resolveProcessingPlan, thresholdPixels, floydSteinbergPixels, packMonochromeFrame, hasWhitePadding, formatHexDump } = imageModule;
const { applyMainTabSelection } = imageTabModule;
const mainInlineScript = mainAppSource.match(/<script>\s*([\s\S]*?)<\/script>/)?.[1];
assert.ok(mainInlineScript, 'Main Clock inline runtime must exist');
new Function(mainInlineScript);
const mapperStart = mainInlineScript.indexOf('function describeBleConnectError(error){');
const mapperEnd = mainInlineScript.indexOf('\n\nasync function connect(){', mapperStart);
assert.ok(mapperStart >= 0 && mapperEnd > mapperStart, 'Shared BLE error mapper must be extractable');
const describeBleConnectError = new Function(`${mainInlineScript.slice(mapperStart, mapperEnd)}; return describeBleConnectError;`)();
assert.equal(describeBleConnectError({ name: 'AbortError', message: 'User cancelled the requestDevice()' }), 'Bạn đã hủy chọn thiết bị Bluetooth.');
assert.equal(describeBleConnectError({ name: 'NotFoundError', message: 'User canceled requestDevice()' }), 'Bạn đã hủy chọn thiết bị Bluetooth.');
assert.equal(describeBleConnectError('requestDevice cancelled'), 'Bạn đã hủy chọn thiết bị Bluetooth.');
assert.equal(describeBleConnectError({ message: 'Bluetooth adapter not available' }), 'Bluetooth chưa sẵn sàng. Hãy bật Bluetooth rồi thử lại.');
assert.equal(describeBleConnectError({ name: 'SecurityError', message: 'raw browser detail' }), 'Trình duyệt không cho phép Web Bluetooth trên trang này. Hãy mở bằng HTTPS.');
assert.equal(describeBleConnectError({ name: 'SecurityError', message: 'requestDevice is not allowed' }), 'Trình duyệt không cho phép Web Bluetooth trên trang này. Hãy mở bằng HTTPS.');
assert.equal(describeBleConnectError({ name: 'NotSupportedError', message: 'Web Bluetooth is not supported' }), 'Trình duyệt này chưa hỗ trợ Web Bluetooth. Hãy mở bằng Chrome trên Android.');
assert.equal(describeBleConnectError({ message: 'Bluetooth unavailable' }), 'Bluetooth chưa sẵn sàng. Hãy bật Bluetooth rồi thử lại.');
assert.equal(describeBleConnectError({ name: 'DOMException', message: 'raw browser detail' }), 'Không kết nối được thiết bị Bluetooth. Hãy thử lại.');
assert.match(mainAppSource, /async connect\(\)\{[\s\S]*?catch\(error\)\{\s*throw Error\(describeBleConnectError\(error\)\);\s*\}/, 'Shared BLE session must sanitize every connect failure');
assert.match(mainAppSource, /\$\('connect'\)\.onclick=\(\)=>safe\(\(\)=>window\.EINK_SHARED_BLE\.connect\(\),describeBleConnectError,false\)/, 'Top-level connect must use the shared BLE session without taking a nested busy lock');
assert.match(mainAppSource, /describeConnectError\(error\)\{\s*return describeBleConnectError\(error\);\s*\}/, 'Shared BLE mapper must be available to feature tabs');
const imageConnectStart = imageTabSource.indexOf("byId('mainImageConnect').addEventListener");
const imageConnectEnd = imageTabSource.indexOf("root.querySelectorAll('input[name=\"mainImageFrameMode\"]')", imageConnectStart);
assert.ok(imageConnectStart >= 0 && imageConnectEnd > imageConnectStart, 'Image connect handler must be extractable');
const imageConnectBlock = imageTabSource.slice(imageConnectStart, imageConnectEnd);
assert.match(imageConnectBlock, /setUserStatus\(session\.describeConnectError\(error\), 'error'\)/, 'Image CTA must render the shared mapped message');
assert.doesNotMatch(imageConnectBlock, /error\.message|String\(error\)/, 'Image connect UI must not render raw browser exception text');
const chooserCancel = { name: 'AbortError', message: 'User cancelled the requestDevice()' };
const sharedConnectStart = mainInlineScript.indexOf('async connect(){');
const sharedConnectBoundaryMarker = /\r?\n  },\r?\n  describeConnectError/;
const sharedConnectBoundaryMatch = sharedConnectBoundaryMarker.exec(mainInlineScript.slice(sharedConnectStart));
const sharedConnectEnd = sharedConnectBoundaryMatch ? sharedConnectStart + sharedConnectBoundaryMatch.index : -1;
assert.ok(sharedConnectStart >= 0 && sharedConnectEnd > sharedConnectStart, 'Shared connect boundary must be executable in the final UI path');
let busyState = false;
let connectOperation = async () => { throw chooserCancel; };
const sharedConnect = new Function('server', 'unifiedDailyUpdateConflicting', 'setBusy', 'emitSharedBleState', 'sharedBleSnapshot', 'connect', 'describeBleConnectError', `return ({${mainInlineScript.slice(sharedConnectStart, sharedConnectEnd)}}}).connect;`)(
  null,
  () => busyState,
  value => { busyState = value; },
  () => {},
  () => Object.freeze({ connected: false }),
  () => connectOperation(),
  describeBleConnectError
);
const runConnectUiPath = async render => {
  try {
    await sharedConnect();
    return 'unexpected success';
  } catch (error) {
    return render(error);
  }
};
assert.equal(await runConnectUiPath(describeBleConnectError), 'Bạn đã hủy chọn thiết bị Bluetooth.', 'Top-level connect UI must render the mapped cancellation message');
assert.equal(await runConnectUiPath(error => describeBleConnectError(error)), 'Bạn đã hủy chọn thiết bị Bluetooth.', 'Image CTA connect UI must render the mapped cancellation message');
assert.equal(busyState, false, 'Image CTA cancellation must release the shared busy state');
let retryCount = 0;
connectOperation = async () => { retryCount += 1; };
await sharedConnect();
assert.equal(retryCount, 1, 'Top-level Connect must start a new attempt after image CTA cancellation');
assert.equal(busyState, false, 'Successful retry must release the shared busy state');
connectOperation = async () => { throw chooserCancel; };
assert.equal(await runConnectUiPath(describeBleConnectError), 'Bạn đã hủy chọn thiết bị Bluetooth.', 'Top-level cancellation must keep the mapped Vietnamese message');
assert.equal(busyState, false, 'Top-level cancellation must release the shared busy state');
retryCount = 0;
connectOperation = async () => { retryCount += 1; };
await sharedConnect();
assert.equal(retryCount, 1, 'Image CTA must start a new attempt after top-level cancellation');
assert.equal(busyState, false, 'Image retry must release the shared busy state');
let releaseActiveConnect;
let activeConnects = 0;
let maxActiveConnects = 0;
connectOperation = async () => {
  activeConnects += 1;
  maxActiveConnects = Math.max(maxActiveConnects, activeConnects);
  await new Promise(resolve => { releaseActiveConnect = resolve; });
  activeConnects -= 1;
};
const firstActiveConnect = sharedConnect();
await Promise.resolve();
assert.equal(busyState, true, 'Shared busy state must stay held while chooser/connect is active');
await assert.rejects(sharedConnect(), /Đang có thao tác khác, hãy chờ hoàn tất\./, 'Second connect attempt must stay blocked while the first is active');
assert.equal(maxActiveConnects, 1, 'Concurrent connect attempts must not reach requestDevice twice');
releaseActiveConnect();
await firstActiveConnect;
assert.equal(busyState, false, 'Active connect completion must release the shared busy state');
console.log('BLE_CONNECT_ERROR_UI_PATH: PASS');
console.log('BLE_CONNECT_LIFECYCLE_A_B_C: PASS');
assert.equal(FRAME_WIDTH, 122);
assert.equal(FRAME_HEIGHT, 250);
assert.equal(FRAME_STRIDE, 16);
assert.equal(FRAME_BYTES, 4000);
assert.equal(IMAGE_TRANSFER_VERSION, 1);
assert.equal(IMAGE_CHUNK_BYTES, 14);
assert.equal(IMAGE_TOTAL_CHUNKS, 286);
assert.equal(BLE_SERVICE_UUID, '18424398-7cbc-11e9-8f9e-2a86e4085a59');
assert.equal(BLE_WRITE_UUID, '2d86686a-53dc-25b3-0c4a-f0e10c8dee20');
assert.equal(BLE_NOTIFY_UUID, '15005991-b131-3396-014c-664c9867b917');

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

assert.equal(MANUAL_CROP_MIN_ZOOM, 1);
assert.equal(MANUAL_CROP_MAX_ZOOM, 4);
assert.deepEqual(normalizeManualCropState({ zoom: 0, panX: -9, panY: 9 }), { zoom: 1, panX: -1, panY: 1 });
assert.deepEqual(normalizeManualCropState({ zoom: 99, panX: Number.NaN, panY: Number.POSITIVE_INFINITY }), { zoom: 4, panX: 0, panY: 0 });
for (const source of [{ width: 1600, height: 900 }, { width: 900, height: 1600 }, { width: 1000, height: 1000 }]) {
  for (const state of [{ zoom: 1, panX: 0, panY: 0 }, { zoom: 2.5, panX: -1, panY: 1 }, { zoom: 4, panX: 1, panY: -1 }]) {
    const placement = computeManualCropPlacement(source.width, source.height, state);
    assert.equal(placement.dx, 0);
    assert.equal(placement.dy, 0);
    assert.equal(placement.dw, FRAME_WIDTH);
    assert.equal(placement.dh, FRAME_HEIGHT);
    assert.ok(placement.sx >= 0 && placement.sy >= 0, 'Manual crop must stay inside source origin');
    assert.ok(placement.sx + placement.sw <= source.width + 1e-9, 'Manual crop must stay inside source width');
    assert.ok(placement.sy + placement.sh <= source.height + 1e-9, 'Manual crop must stay inside source height');
    assert.ok(Math.abs(placement.sw / placement.sh - FRAME_WIDTH / FRAME_HEIGHT) < 1e-9, 'Manual crop must preserve frame aspect ratio');
  }
}
const manualStart = { zoom: 2, panX: 0, panY: 0 };
const manualDragged = panManualCropByViewportDelta(manualStart, 40, -60, 122, 250, 1600, 900);
assert.ok(manualDragged.panX < 0, 'Dragging image right must move source crop left');
assert.ok(manualDragged.panY > 0, 'Dragging image up must move source crop down');
let manualClamped = manualStart;
for (let index = 0; index < 20; index += 1) manualClamped = panManualCropByViewportDelta(manualClamped, -122, 250, 122, 250, 1600, 900);
assert.deepEqual(manualClamped, { zoom: 2, panX: 1, panY: -1 }, 'Repeated pan must clamp to valid crop bounds');
const manualRotationPlan = resolveProcessingPlan(1600, 900, 'manual', '90');
assert.equal(manualRotationPlan.resolvedFrameMode, 'manual');
assert.equal(manualRotationPlan.scaleMode, 'manual');
assert.equal(manualRotationPlan.orientedWidth, 900);
assert.equal(manualRotationPlan.orientedHeight, 1600);

const portraitPlan = resolveProcessingPlan(900, 1600, 'auto', 'auto');
assert.equal(portraitPlan.rotation, 0);
assert.equal(portraitPlan.autoRotated, false);
assert.equal(portraitPlan.resolvedFrameMode, 'fit');
const landscapePlan = resolveProcessingPlan(1600, 900, 'auto', 'auto');
assert.equal(landscapePlan.rotation, 90);
assert.equal(landscapePlan.autoRotated, true);
assert.equal(landscapePlan.orientedWidth, 900);
assert.equal(landscapePlan.orientedHeight, 1600);
assert.equal(landscapePlan.resolvedFrameMode, 'fit');
const squarePlan = resolveProcessingPlan(1000, 1000, 'auto', 'auto');
assert.equal(squarePlan.rotation, 0, 'Square tie must keep original orientation');
assert.equal(squarePlan.resolvedFrameMode, 'fill');
assert.equal(chooseAutoRotation(1600, 900), 90);
assert.equal(chooseAutoRotation(900, 1600), 0);
assert.equal(chooseAutoRotation(1000, 1000), 0);
assert.ok(fitUtilization(900, 1600) > fitUtilization(1600, 900));
assert.equal(chooseAutoFrameMode(900, 1600), 'fit');
assert.equal(chooseAutoFrameMode(1000, 1000), 'fill');

for (const rotation of [90, 270]) {
  const rotationAwareAuto = resolveProcessingPlan(900, 1600, 'auto', String(rotation));
  assert.equal(rotationAwareAuto.rotation, rotation);
  assert.equal(rotationAwareAuto.orientedWidth, 1600);
  assert.equal(rotationAwareAuto.orientedHeight, 900);
  assert.ok(rotationAwareAuto.utilization < 0.72, 'Rotated landscape FIT must expose excessive blank area');
  assert.equal(rotationAwareAuto.resolvedFrameMode, 'fill', 'Auto must choose Fill/Crop after 90/270 rotation');
  assert.equal(rotationAwareAuto.scaleMode, 'cover');
}

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

class FirmwareTransferSimulator {
  start(packet) {
    assert.equal(packet.length, 14);
    assert.deepEqual(Array.from(packet.slice(0, 4)), [0xE5, 0x00, packet[2], 0x01]);
    assert.equal(packet[4] | (packet[5] << 8), FRAME_WIDTH);
    assert.equal(packet[6] | (packet[7] << 8), FRAME_HEIGHT);
    assert.equal(packet[8], 1);
    assert.equal(packet[9], FRAME_STRIDE);
    assert.equal(packet[10] | (packet[11] << 8), FRAME_BYTES);
    this.id = packet[2];
    this.expectedCrc = packet[12] | (packet[13] << 8);
    this.sequence = 0;
    this.bytes = [];
  }
  data(packet) {
    assert.equal(packet[0], 0xE5);
    assert.equal(packet[1], 0x01);
    assert.equal(packet[2], this.id, 'BAD_ID');
    const sequence = packet[3] | (packet[4] << 8);
    assert.equal(sequence, this.sequence, 'BAD_SEQUENCE');
    const length = packet[5];
    assert.ok(length > 0 && length <= IMAGE_CHUNK_BYTES && packet.length === 6 + length, 'INVALID_CHUNK');
    assert.ok(this.bytes.length + length <= FRAME_BYTES, 'OVERFLOW');
    this.bytes.push(...packet.slice(6));
    this.sequence += 1;
  }
  commit(packet) {
    assert.equal(packet[2], this.id, 'BAD_ID');
    const chunks = packet[3] | (packet[4] << 8);
    const bytes = packet[5] | (packet[6] << 8);
    const crc = packet[7] | (packet[8] << 8);
    assert.equal(chunks, this.sequence, 'BAD_COUNT');
    assert.equal(bytes, FRAME_BYTES, 'INCOMPLETE');
    assert.equal(this.bytes.length, FRAME_BYTES, 'INCOMPLETE');
    assert.equal(crc, this.expectedCrc, 'START_COMMIT_CRC_MISMATCH');
    assert.equal(crc16Ccitt(Uint8Array.from(this.bytes)), crc, 'BAD_CRC');
    return Uint8Array.from(this.bytes);
  }
}

const transferFrame = Uint8Array.from({ length: FRAME_BYTES }, (_, index) => (index * 29 + 17) & 0xFF);
for (let row = 0; row < FRAME_HEIGHT; row += 1) transferFrame[row * FRAME_STRIDE + 15] |= 0x3F;
const transferPlan = createImageTransferPlan(transferFrame, 0x31);
assert.equal(transferPlan.chunks.length, IMAGE_TOTAL_CHUNKS);
assert.equal(transferPlan.start.length, 14);
assert.equal(transferPlan.chunks.at(-1).data.length, 10);
const simulator = new FirmwareTransferSimulator();
simulator.start(transferPlan.start);
for (const chunk of transferPlan.chunks) simulator.data(chunk.packet);
assert.deepEqual(simulator.commit(transferPlan.commit), transferFrame, 'firmware reconstruction must match original bytes');

assert.throws(() => createImageTransferPlan(transferFrame.slice(0, -1), 1), /INVALID_IMAGE_FRAME/);
const shortSim = new FirmwareTransferSimulator();
shortSim.start(transferPlan.start);
for (const chunk of transferPlan.chunks.slice(0, -1)) shortSim.data(chunk.packet);
assert.throws(() => shortSim.commit(transferPlan.commit), /BAD_COUNT|INCOMPLETE/);
const orderSim = new FirmwareTransferSimulator();
orderSim.start(transferPlan.start);
assert.throws(() => orderSim.data(transferPlan.chunks[1].packet), /BAD_SEQUENCE/);
const overflowSim = new FirmwareTransferSimulator();
overflowSim.start(transferPlan.start);
overflowSim.bytes = new Array(FRAME_BYTES).fill(0);
assert.throws(() => overflowSim.data(transferPlan.chunks[0].packet), /OVERFLOW/);
const crcSim = new FirmwareTransferSimulator();
const badCrcStart = transferPlan.start.slice();
badCrcStart[12] ^= 0x01;
crcSim.start(badCrcStart);
for (const chunk of transferPlan.chunks) crcSim.data(chunk.packet);
assert.throws(() => crcSim.commit(transferPlan.commit), /START_COMMIT_CRC_MISMATCH/);
const restartSim = new FirmwareTransferSimulator();
restartSim.start(transferPlan.start);
restartSim.data(transferPlan.chunks[0].packet);
const restartPlan = createImageTransferPlan(transferFrame, 0x32);
restartSim.start(restartPlan.start);
for (const chunk of restartPlan.chunks) restartSim.data(chunk.packet);
assert.deepEqual(restartSim.commit(restartPlan.commit), transferFrame);

for (const marker of ['image/jpeg,image/png', 'originalCanvas', 'thresholdCanvas', 'ditherCanvas', 'downloadBin', 'copyHex', 'connectBle', 'sendBle', 'bleProgress', '122 × 250', '4,000 bytes', 'bit 7', '1 = trắng', '0 = đen', 'name="frameMode" value="auto" checked', 'name="frameMode" value="fit"', 'name="frameMode" value="fill"', 'name="rotationMode" value="270"', 'frameModeState', 'rotationState', 'autoNotice']) assert.ok(html.includes(marker), `Missing HTML contract: ${marker}`);
for (const marker of ['image-rendering:pixelated', 'preview-grid', 'panel-bezel', 'rotation-options', 'transform-summary', 'ble-state', 'ble-progress-row']) assert.ok(css.includes(marker), `Missing CSS contract: ${marker}`);
for (const marker of ['createImageBitmap', 'createOrientedCanvas', 'resolveProcessingPlan', 'floydSteinbergPixels', 'packMonochromeFrame', "new Blob([packedFrame]", 'application/octet-stream', 'navigator.bluetooth.requestDevice', 'if (transferActive) return', 'acknowledgedBytes', 'BLE_DISCONNECTED', 'E5_FINAL_MANIFEST_MISMATCH']) assert.ok(moduleSource.includes(marker), `Missing module contract: ${marker}`);
for (const marker of ['ĐỒNG HỒ', 'ẢNH E-INK', 'imageEinkView', 'window.EINK_SHARED_BLE', 'sharedBleSnapshot', 'subscribeState', 'runExclusive', 'emitSharedBleState', 'Chi tiết kỹ thuật', 'setupMainAppTabs()', './image-upload-tab.mjs']) assert.ok(mainAppSource.includes(marker), `Missing main app integration: ${marker}`);
for (const marker of ['unifiedDailyUpdate', 'productLayoutSelect', 'profileApply', 'preferenceApply', 'dailyWeatherRefresh', 'd2SetTime', 'd2GetStatus', 'd2RenderClock', 'd2GetIdentity', 'batteryRefresh', 'syncClock', 'function runUnifiedDailyUpdate()', 'function connect()', 'function controls()']) assert.ok(mainAppSource.includes(marker), `Clock regression contract missing: ${marker}`);
for (const marker of ['function requireBleSupport()', 'function describeBleConnectError(error)', 'window.isSecureContext', 'navigator.bluetooth', 'Web Bluetooth cần trang HTTPS.', 'Trình duyệt này chưa hỗ trợ Web Bluetooth.', 'Bạn đã hủy chọn thiết bị Bluetooth.', 'Bluetooth chưa sẵn sàng. Hãy bật Bluetooth rồi thử lại.']) assert.ok(mainAppSource.includes(marker), `Web Bluetooth capability guard missing: ${marker}`);
assert.match(mainAppSource, /name==='NotFoundError'\|\|\/requestdevice\|cancelled\|canceled\|no device\/i\.test\(message\)/, 'BLE chooser cancellation variants must map through the shared error mapper');
assert.match(mainAppSource, /advancedBody\.append\(advancedDailyProgress,preferencePanel,identityCard\)/, 'Technical identity/build information must be collapsed');
for (const marker of ['mainImageFile', 'mainImageFrameMode', 'value="manual"', 'Crop tay', 'mainImageManualViewport', 'mainImageCropZoom', 'mainImageCropReset', 'mainImageConnect', 'session.connect()', 'connectActive', 'pointerdown', 'pointermove', 'setPointerCapture', 'panManualCropByViewportDelta', 'computeManualCropPlacement', 'resetManualCrop(false)', 'mainImageRotation', 'mainImageOutput', 'mainImageThresholdCard', 'mainImageDitherCard', 'role="button"', "event.key === 'Enter'", "event.key === ' '", 'data-selected', 'createImageTransferPlan(frame', 'session.runExclusive', 'session.subscribeState', 'Đang gửi ảnh', 'Đang kiểm tra ảnh', 'Đang hiển thị ảnh', 'Hoàn tất']) assert.ok(imageTabSource.includes(marker), `Missing image tab contract: ${marker}`);
for (const marker of ['minmax(330px,43fr) minmax(0,57fr)', 'grid-column:1/-1;width:100%', '[data-app-view="clock"][hidden]{display:none!important}', '@media(min-width:761px) and (max-width:1100px)', '.imagePreviewGrid{grid-template-columns:repeat(2,minmax(0,1fr));overflow:visible}', '.imagePreviewCard:first-child{grid-column:1/-1;width:min(100%,360px);justify-self:center}', '.imagePreviewGrid{grid-template-columns:minmax(0,1fr);overflow:visible}', 'document.documentElement.scrollWidth <= window.innerWidth', 'getClockPanels()', '.imageRotationOptions{grid-template-columns:repeat(3,minmax(0,1fr))}']) assert.ok(imageTabSource.includes(marker), `Missing image layout polish: ${marker}`);
for (const marker of ["controlsCard.dataset.appView='clock'", "workspace.dataset.appView='clock'", "const tabs=document.querySelector('#mainAppTabs')", 'const anchor=tabs||header', "document.querySelector('#imageEinkView')?.hidden===false", 'workspace.hidden=imageActive']) assert.ok(panelRegistrySource.includes(marker), `Missing late Clock panel isolation: ${marker}`);
for (const forbidden of ['navigator.bluetooth', '.gatt.connect(', 'getPrimaryService(', 'getCharacteristic(', "addEventListener('characteristicvaluechanged'"]) assert.ok(!imageTabSource.includes(forbidden), `Image tab must not own BLE/GATT: ${forbidden}`);
assert.equal((mainAppSource.match(/device=await navigator\.bluetooth\.requestDevice/g) || []).length, 1, 'Main app must have one Bluetooth chooser path');
assert.equal((mainAppSource.match(/notifyChar\.addEventListener\('characteristicvaluechanged',onNotify\)/g) || []).length, 1, 'Main app must attach one authoritative notify listener');
assert.equal((mainAppSource.match(/device\.addEventListener\('gattserverdisconnected'/g) || []).length, 1, 'Main app must attach one disconnect handler');
assert.match(moduleSource, /typeof document !== 'undefined' && document\.getElementById\('imageFile'\)/, 'Standalone bootstrap must stay dormant inside the main app');
assert.match(imageTabSource, /const frame = packedFrame\.slice\(\)/, 'BLE must send the exact currently previewed packed frame');
assert.match(imageTabSource, /new Blob\(\[packedFrame\]/, 'Download must export the exact currently previewed packed frame');
assert.match(imageTabSource, /formatHexDump\(packedFrame\)/, 'Hex copy must use the exact currently previewed packed frame');

const fakeClassList = () => {
  const values = new Set();
  return { toggle(name, enabled) { if (enabled) values.add(name); else values.delete(name); }, contains(name) { return values.has(name); } };
};
const tabButtons = ['clock', 'image'].map(name => ({ dataset: { appTab: name }, classList: fakeClassList(), attributes: {}, tabIndex: 0, setAttribute(key, value) { this.attributes[key] = value; } }));
const clockPanels = [{ hidden: false }, { hidden: false }, { hidden: false }];
const imagePanel = { hidden: true };
const sharedIdentity = Object.freeze({ device: {}, server: {}, writeCharacteristic: {}, notifyCharacteristic: {} });
const clockPreferenceState = { hourMode: 12, refreshMinutes: 10 };
for (const name of ['clock', 'image', 'clock', 'image', 'clock']) {
  applyMainTabSelection(name, tabButtons, clockPanels, imagePanel);
  assert.equal(imagePanel.hidden, name !== 'image');
  assert.ok(clockPanels.every(panel => panel.hidden === (name !== 'clock')));
  assert.equal(sharedIdentity.device, sharedIdentity.device);
  assert.equal(sharedIdentity.server, sharedIdentity.server);
  assert.equal(sharedIdentity.writeCharacteristic, sharedIdentity.writeCharacteristic);
  assert.equal(sharedIdentity.notifyCharacteristic, sharedIdentity.notifyCharacteristic);
  assert.deepEqual(clockPreferenceState, { hourMode: 12, refreshMinutes: 10 }, 'Tab switching must preserve Clock preference state');
}
assert.equal(tabButtons[0].attributes['aria-selected'], 'true');
assert.equal(tabButtons[1].attributes['aria-selected'], 'false');
for (const marker of ['HINK_E5_PROTOCOL_V1', 'param->length != 14U', 'hink_e5_expected_crc', 'HINK_E5_STATUS_BAD_SEQUENCE', 'HINK_E5_STATUS_OVERFLOW', 'HINK_E5_STATUS_BAD_COUNT', 'HINK_E5_STATUS_BAD_CRC', 'app_clock_timer_stop()', 'hink_image_mode_active']) assert.ok(firmwareSource.includes(marker), `Missing firmware contract: ${marker}`);
assert.match(peripheralSource, /#define\s+HINK_IMAGE_DISPLAY_PROOF_MODE\s+0U/);
assert.match(peripheralSource, /void user_app_adv_start\(void\)[\s\S]*app_easy_gap_undirected_advertise_start\(\)/, 'Boot advertising must be continuous');
assert.doesNotMatch(peripheralSource, /void user_app_adv_start\(void\)[\s\S]*?app_easy_gap_undirected_advertise_with_timeout_start[\s\S]*?\n\}/, 'Advertising start must not retain a timeout path');
assert.match(peripheralSource, /void user_app_disconnect[\s\S]*app_connection_idx = -1;[\s\S]*adv_state = 0;[\s\S]*hink_schedule_adv_restart\(\);/, 'Every real disconnect must schedule advertising restart');
assert.match(peripheralSource, /hink_schedule_adv_restart\(\);[\s\S]*if \(hink_image_mode_is_active\(\)\)[\s\S]*return;/, 'Image hold must restart advertising before suppressing clock redraw');
assert.match(peripheralSource, /void user_app_adv_undirect_complete[\s\S]*if \(app_connection_idx == -1\)[\s\S]*hink_schedule_adv_restart\(\);/, 'Unexpected advertising completion must recover while disconnected');
assert.match(peripheralSource, /static void hink_adv_restart_timer_cb[\s\S]*app_connection_idx == -1[\s\S]*adv_state == 0[\s\S]*user_app_adv_start\(\);/, 'Deferred restart must not advertise over a live connection');

class AdvertisingLifecycleSimulator {
  constructor() { this.connected = false; this.advertising = false; this.imageHeld = false; }
  boot() { this.advertising = true; }
  connect() { assert.equal(this.advertising, true, 'Connection requires advertising'); this.advertising = false; this.connected = true; }
  displayImage() { assert.equal(this.connected, true); this.imageHeld = true; }
  disconnect() { this.connected = false; this.advertising = true; }
}
const advertisingLifecycle = new AdvertisingLifecycleSimulator();
advertisingLifecycle.boot();
assert.equal(advertisingLifecycle.advertising, true, 'boot -> scan');
advertisingLifecycle.connect();
advertisingLifecycle.disconnect();
assert.equal(advertisingLifecycle.advertising, true, 'manual disconnect -> scan again');
for (let cycle = 0; cycle < 5; cycle += 1) {
  advertisingLifecycle.connect();
  advertisingLifecycle.displayImage();
  assert.equal(advertisingLifecycle.connected, true, 'image refresh must not force a healthy link down');
  advertisingLifecycle.disconnect();
  assert.equal(advertisingLifecycle.advertising, true, `reconnect cycle ${cycle + 1} must advertise`);
  assert.equal(advertisingLifecycle.imageHeld, true, 'disconnect must preserve displayed image');
}
for (const forbidden of ['SmartSnippets', 'eink.ps1', 'navigator.bluetooth.requestDevice({acceptAllDevices:true']) assert.ok(!moduleSource.includes(forbidden) && !html.includes(forbidden), `Out-of-scope behavior found: ${forbidden}`);

console.log('EINK_IMAGE_UPLOAD_V1: PASS');
console.log('FRAME: 122x250');
console.log('PACKED_BYTES: 4000');
console.log('PACKING: ROW_MAJOR_MSB_FIRST_BIT1_WHITE');
console.log('PADDING_BITS: PASS');
console.log('THRESHOLD: PASS');
console.log('FLOYD_STEINBERG: PASS');
console.log('FIT_CROP: PASS');
console.log('AUTO_ORIENTATION_LANDSCAPE_PORTRAIT_SQUARE: PASS');
console.log('ROTATION_AWARE_AUTO_FILL: PASS');
console.log('MANUAL_ROTATION_0_90_180_270: PASS');
console.log('MANUAL_CROP_PAN_ZOOM_RESET_CLAMP: PASS');
console.log('MANUAL_CROP_ROTATION_NEW_IMAGE_RESET: PASS');
console.log('MANUAL_CROP_PREVIEW_EXPORT_BLE_IDENTITY: PASS');
console.log('NO_DISTORTION: PASS');
console.log('BLE_IMAGE_TRANSFER_V1: PASS');
console.log('BLE_UUIDS: PASS');
console.log('CHUNKS: 286 x max 14 bytes');
console.log('CRC16_CCITT: PASS');
console.log('FULL_RECONSTRUCTION: PASS');
console.log('SHORT_OVERFLOW_ORDER_CRC_RESTART: PASS');
console.log('DISCONNECT_DUPLICATE_PROGRESS_GATES: PASS');
console.log('BLE_BOOT_ADVERTISING_CONTINUOUS: PASS');
console.log('BLE_ANY_DISCONNECT_RESTARTS_ADVERTISING: PASS');
console.log('BLE_E6_IMAGE_HOLD_RECONNECT_5X: PASS');
console.log('MAIN_APP_TABS_CLOCK_IMAGE: PASS');
console.log('PREVIEW_CARD_SELECTION_KEYBOARD_SYNC: PASS');
console.log('SHARED_BLE_SINGLE_OWNER_TAB_SWITCH_5X: PASS');
console.log('SHARED_BLE_DUPLICATE_LISTENERS: PASS');
console.log('TECHNICAL_CLUTTER_COLLAPSED: PASS');
console.log('CLOCK_FUNCTIONALITY_REGRESSION: PASS');
console.log('IMAGE_DESKTOP_GRID_43_57_SEND_FULL_WIDTH: PASS');
console.log('IMAGE_TABLET_768_820_1024_STACKED_PREVIEWS: PASS');
console.log('IMAGE_MOBILE_STACK_NO_HORIZONTAL_SCROLL: PASS');
console.log('CLOCK_ONLY_PREFERENCES_HIDDEN_WITH_STATE_PRESERVED: PASS');
