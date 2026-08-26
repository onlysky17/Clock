export const FRAME_WIDTH = 122;
export const FRAME_HEIGHT = 250;
export const FRAME_STRIDE = 16;
export const FRAME_BYTES = FRAME_HEIGHT * FRAME_STRIDE;
export const BLE_SERVICE_UUID = '18424398-7cbc-11e9-8f9e-2a86e4085a59';
export const BLE_WRITE_UUID = '2d86686a-53dc-25b3-0c4a-f0e10c8dee20';
export const BLE_NOTIFY_UUID = '15005991-b131-3396-014c-664c9867b917';
export const IMAGE_TRANSFER_VERSION = 1;
export const IMAGE_CHUNK_BYTES = 14;
export const IMAGE_TOTAL_CHUNKS = Math.ceil(FRAME_BYTES / IMAGE_CHUNK_BYTES);
export const MANUAL_CROP_MIN_ZOOM = 1;
export const MANUAL_CROP_MAX_ZOOM = 4;

export function crc16Ccitt(data, seed = 0xFFFF) {
  let crc = seed;
  for (const value of data) {
    crc ^= value << 8;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc;
}

export function createImageStartPacket(transferId, crc) {
  return Uint8Array.of(
    0xE5, 0x00, transferId, IMAGE_TRANSFER_VERSION,
    FRAME_WIDTH & 0xFF, FRAME_WIDTH >> 8,
    FRAME_HEIGHT & 0xFF, FRAME_HEIGHT >> 8,
    0x01, FRAME_STRIDE,
    FRAME_BYTES & 0xFF, FRAME_BYTES >> 8,
    crc & 0xFF, crc >> 8
  );
}

export function createImageDataPacket(transferId, sequence, data) {
  if (!(data instanceof Uint8Array) || data.length < 1 || data.length > IMAGE_CHUNK_BYTES) throw new Error('INVALID_IMAGE_CHUNK');
  return Uint8Array.of(0xE5, 0x01, transferId, sequence & 0xFF, sequence >> 8, data.length, ...data);
}

export function createImageCommitPacket(transferId, chunks, bytes, crc) {
  return Uint8Array.of(0xE5, 0x02, transferId, chunks & 0xFF, chunks >> 8, bytes & 0xFF, bytes >> 8, crc & 0xFF, crc >> 8);
}

export function createImageTransferPlan(frame, transferId) {
  if (!(frame instanceof Uint8Array) || frame.length !== FRAME_BYTES) throw new Error('INVALID_IMAGE_FRAME');
  if (!hasWhitePadding(frame)) throw new Error('INVALID_IMAGE_PADDING');
  const crc = crc16Ccitt(frame);
  const chunks = [];
  for (let offset = 0, sequence = 0; offset < frame.length; sequence += 1) {
    const data = frame.slice(offset, Math.min(offset + IMAGE_CHUNK_BYTES, frame.length));
    chunks.push({ sequence, offset, data, packet: createImageDataPacket(transferId, sequence, data) });
    offset += data.length;
  }
  return {
    transferId,
    crc,
    bytes: frame.length,
    start: createImageStartPacket(transferId, crc),
    chunks,
    commit: createImageCommitPacket(transferId, chunks.length, frame.length, crc),
    status: Uint8Array.of(0xE5, 0x03, transferId)
  };
}

export function parseImageManifest(packet) {
  if (!(packet instanceof Uint8Array) || packet.length < 11 || packet[0] !== 0xE5) throw new Error('INVALID_IMAGE_MANIFEST');
  return {
    response: packet[1], status: packet[2], transferId: packet[3], state: packet[4],
    chunks: packet[5] | (packet[6] << 8), bytes: packet[7] | (packet[8] << 8),
    crc: packet[9] | (packet[10] << 8)
  };
}

export function computeImagePlacement(sourceWidth, sourceHeight, mode = 'cover') {
  if (!(sourceWidth > 0) || !(sourceHeight > 0)) throw new Error('INVALID_IMAGE_DIMENSIONS');
  if (mode !== 'cover' && mode !== 'contain') throw new Error('INVALID_FIT_MODE');

  const sourceRatio = sourceWidth / sourceHeight;
  const targetRatio = FRAME_WIDTH / FRAME_HEIGHT;
  if (mode === 'cover') {
    if (sourceRatio > targetRatio) {
      const sourceCropWidth = sourceHeight * targetRatio;
      return { sx: (sourceWidth - sourceCropWidth) / 2, sy: 0, sw: sourceCropWidth, sh: sourceHeight, dx: 0, dy: 0, dw: FRAME_WIDTH, dh: FRAME_HEIGHT };
    }
    const sourceCropHeight = sourceWidth / targetRatio;
    return { sx: 0, sy: (sourceHeight - sourceCropHeight) / 2, sw: sourceWidth, sh: sourceCropHeight, dx: 0, dy: 0, dw: FRAME_WIDTH, dh: FRAME_HEIGHT };
  }

  const scale = Math.min(FRAME_WIDTH / sourceWidth, FRAME_HEIGHT / sourceHeight);
  const width = sourceWidth * scale;
  const height = sourceHeight * scale;
  return { sx: 0, sy: 0, sw: sourceWidth, sh: sourceHeight, dx: (FRAME_WIDTH - width) / 2, dy: (FRAME_HEIGHT - height) / 2, dw: width, dh: height };
}

function clampFinite(value, minimum, maximum, fallback) {
  const numeric = Number(value);
  return Number.isFinite(numeric) ? Math.max(minimum, Math.min(maximum, numeric)) : fallback;
}

export function normalizeManualCropState(state = {}) {
  return {
    zoom: clampFinite(state.zoom, MANUAL_CROP_MIN_ZOOM, MANUAL_CROP_MAX_ZOOM, MANUAL_CROP_MIN_ZOOM),
    panX: clampFinite(state.panX, -1, 1, 0),
    panY: clampFinite(state.panY, -1, 1, 0)
  };
}

export function computeManualCropPlacement(sourceWidth, sourceHeight, state = {}) {
  if (!(sourceWidth > 0) || !(sourceHeight > 0)) throw new Error('INVALID_IMAGE_DIMENSIONS');
  const normalized = normalizeManualCropState(state);
  const minimumCover = computeImagePlacement(sourceWidth, sourceHeight, 'cover');
  const sw = minimumCover.sw / normalized.zoom;
  const sh = minimumCover.sh / normalized.zoom;
  const maxSx = Math.max(0, sourceWidth - sw);
  const maxSy = Math.max(0, sourceHeight - sh);
  return {
    sx: maxSx * (normalized.panX + 1) / 2,
    sy: maxSy * (normalized.panY + 1) / 2,
    sw,
    sh,
    dx: 0,
    dy: 0,
    dw: FRAME_WIDTH,
    dh: FRAME_HEIGHT,
    maxSx,
    maxSy,
    ...normalized
  };
}

export function panManualCropByViewportDelta(state, deltaX, deltaY, viewportWidth, viewportHeight, sourceWidth, sourceHeight) {
  if (!(viewportWidth > 0) || !(viewportHeight > 0)) throw new Error('INVALID_CROP_VIEWPORT');
  const normalized = normalizeManualCropState(state);
  const placement = computeManualCropPlacement(sourceWidth, sourceHeight, normalized);
  const sourceDeltaX = -clampFinite(deltaX, -viewportWidth, viewportWidth, 0) * placement.sw / viewportWidth;
  const sourceDeltaY = -clampFinite(deltaY, -viewportHeight, viewportHeight, 0) * placement.sh / viewportHeight;
  return normalizeManualCropState({
    zoom: normalized.zoom,
    panX: placement.maxSx > 0 ? normalized.panX + sourceDeltaX * 2 / placement.maxSx : 0,
    panY: placement.maxSy > 0 ? normalized.panY + sourceDeltaY * 2 / placement.maxSy : 0
  });
}

export function normalizeRotation(rotation) {
  const value = Number(rotation);
  if (![0, 90, 180, 270].includes(value)) throw new Error('INVALID_ROTATION');
  return value;
}

export function orientedDimensions(sourceWidth, sourceHeight, rotation) {
  const angle = normalizeRotation(rotation);
  return angle === 90 || angle === 270
    ? { width: sourceHeight, height: sourceWidth }
    : { width: sourceWidth, height: sourceHeight };
}

export function fitUtilization(sourceWidth, sourceHeight) {
  if (!(sourceWidth > 0) || !(sourceHeight > 0)) throw new Error('INVALID_IMAGE_DIMENSIONS');
  const scale = Math.min(FRAME_WIDTH / sourceWidth, FRAME_HEIGHT / sourceHeight);
  return (sourceWidth * scale * sourceHeight * scale) / (FRAME_WIDTH * FRAME_HEIGHT);
}

export function chooseAutoRotation(sourceWidth, sourceHeight) {
  const originalScore = fitUtilization(sourceWidth, sourceHeight);
  const rotatedScore = fitUtilization(sourceHeight, sourceWidth);
  return rotatedScore > originalScore + Number.EPSILON ? 90 : 0;
}

export function chooseAutoFrameMode(sourceWidth, sourceHeight) {
  const fitAreaUtilization = fitUtilization(sourceWidth, sourceHeight);
  return fitAreaUtilization >= 0.72 ? 'fit' : 'fill';
}

export function resolveProcessingPlan(sourceWidth, sourceHeight, frameMode = 'auto', rotationMode = 'auto') {
  if (!['auto', 'fit', 'fill', 'manual'].includes(frameMode)) throw new Error('INVALID_FRAME_MODE');
  const rotation = rotationMode === 'auto' ? chooseAutoRotation(sourceWidth, sourceHeight) : normalizeRotation(rotationMode);
  const dimensions = orientedDimensions(sourceWidth, sourceHeight, rotation);
  const resolvedFrameMode = frameMode === 'auto' ? chooseAutoFrameMode(dimensions.width, dimensions.height) : frameMode;
  return {
    frameMode,
    resolvedFrameMode,
    scaleMode: resolvedFrameMode === 'manual' ? 'manual' : (resolvedFrameMode === 'fill' ? 'cover' : 'contain'),
    rotationMode,
    rotation,
    autoRotated: rotationMode === 'auto' && rotation !== 0,
    orientedWidth: dimensions.width,
    orientedHeight: dimensions.height,
    utilization: fitUtilization(dimensions.width, dimensions.height)
  };
}

export function rgbaToLuminance(rgba) {
  if (!(rgba instanceof Uint8ClampedArray) || rgba.length !== FRAME_WIDTH * FRAME_HEIGHT * 4) throw new Error('INVALID_RGBA_FRAME');
  const result = new Float32Array(FRAME_WIDTH * FRAME_HEIGHT);
  for (let pixel = 0, offset = 0; pixel < result.length; pixel += 1, offset += 4) {
    const alpha = rgba[offset + 3] / 255;
    const red = rgba[offset] * alpha + 255 * (1 - alpha);
    const green = rgba[offset + 1] * alpha + 255 * (1 - alpha);
    const blue = rgba[offset + 2] * alpha + 255 * (1 - alpha);
    result[pixel] = 0.2126 * red + 0.7152 * green + 0.0722 * blue;
  }
  return result;
}

export function thresholdPixels(luminance, threshold) {
  if (luminance.length !== FRAME_WIDTH * FRAME_HEIGHT) throw new Error('INVALID_LUMINANCE_FRAME');
  const boundary = Math.max(0, Math.min(255, Number(threshold)));
  return Uint8Array.from(luminance, value => value < boundary ? 0 : 255);
}

export function floydSteinbergPixels(luminance, threshold) {
  if (luminance.length !== FRAME_WIDTH * FRAME_HEIGHT) throw new Error('INVALID_LUMINANCE_FRAME');
  const boundary = Math.max(0, Math.min(255, Number(threshold)));
  const work = Float32Array.from(luminance);
  const output = new Uint8Array(work.length);
  for (let y = 0; y < FRAME_HEIGHT; y += 1) {
    for (let x = 0; x < FRAME_WIDTH; x += 1) {
      const index = y * FRAME_WIDTH + x;
      const value = work[index] < boundary ? 0 : 255;
      output[index] = value;
      const error = work[index] - value;
      if (x + 1 < FRAME_WIDTH) work[index + 1] += error * 7 / 16;
      if (y + 1 < FRAME_HEIGHT) {
        if (x > 0) work[index + FRAME_WIDTH - 1] += error * 3 / 16;
        work[index + FRAME_WIDTH] += error * 5 / 16;
        if (x + 1 < FRAME_WIDTH) work[index + FRAME_WIDTH + 1] += error / 16;
      }
    }
  }
  return output;
}

export function packMonochromeFrame(pixels) {
  if (!(pixels instanceof Uint8Array) || pixels.length !== FRAME_WIDTH * FRAME_HEIGHT) throw new Error('INVALID_MONO_FRAME');
  const packed = new Uint8Array(FRAME_BYTES).fill(0xFF);
  for (let y = 0; y < FRAME_HEIGHT; y += 1) {
    for (let x = 0; x < FRAME_WIDTH; x += 1) {
      if (pixels[y * FRAME_WIDTH + x] === 0) {
        const offset = y * FRAME_STRIDE + (x >> 3);
        packed[offset] &= ~(1 << (7 - (x & 7)));
      }
    }
  }
  return packed;
}

export function hasWhitePadding(packed) {
  if (!(packed instanceof Uint8Array) || packed.length !== FRAME_BYTES) return false;
  for (let y = 0; y < FRAME_HEIGHT; y += 1) {
    if ((packed[y * FRAME_STRIDE + 15] & 0x3F) !== 0x3F) return false;
  }
  return true;
}

export function formatHexDump(packed) {
  if (!(packed instanceof Uint8Array) || packed.length !== FRAME_BYTES) throw new Error('INVALID_PACKED_FRAME');
  const lines = [];
  for (let y = 0; y < FRAME_HEIGHT; y += 1) {
    const offset = y * FRAME_STRIDE;
    const bytes = Array.from(packed.subarray(offset, offset + FRAME_STRIDE), value => value.toString(16).padStart(2, '0').toUpperCase()).join(' ');
    lines.push(`${offset.toString(16).padStart(4, '0').toUpperCase()}  ${bytes}`);
  }
  return lines.join('\n');
}

export function monoToImageData(pixels) {
  const image = new ImageData(FRAME_WIDTH, FRAME_HEIGHT);
  for (let pixel = 0, offset = 0; pixel < pixels.length; pixel += 1, offset += 4) {
    image.data[offset] = pixels[pixel];
    image.data[offset + 1] = pixels[pixel];
    image.data[offset + 2] = pixels[pixel];
    image.data[offset + 3] = 255;
  }
  return image;
}

export function createOrientedCanvas(image, rotation) {
  const dimensions = orientedDimensions(image.width, image.height, rotation);
  const canvas = document.createElement('canvas');
  canvas.width = dimensions.width;
  canvas.height = dimensions.height;
  const context = canvas.getContext('2d');
  context.save();
  if (rotation === 90) {
    context.translate(canvas.width, 0);
    context.rotate(Math.PI / 2);
  } else if (rotation === 180) {
    context.translate(canvas.width, canvas.height);
    context.rotate(Math.PI);
  } else if (rotation === 270) {
    context.translate(0, canvas.height);
    context.rotate(-Math.PI / 2);
  }
  context.drawImage(image, 0, 0);
  context.restore();
  return canvas;
}

function bootstrap() {
  const elements = {
    input: document.getElementById('imageFile'),
    dropZone: document.getElementById('dropZone'),
    fileMeta: document.getElementById('fileMeta'),
    threshold: document.getElementById('threshold'),
    thresholdValue: document.getElementById('thresholdValue'),
    original: document.getElementById('originalCanvas'),
    thresholdCanvas: document.getElementById('thresholdCanvas'),
    ditherCanvas: document.getElementById('ditherCanvas'),
    thresholdCard: document.getElementById('thresholdCard'),
    ditherCard: document.getElementById('ditherCard'),
    download: document.getElementById('downloadBin'),
    copy: document.getElementById('copyHex'),
    status: document.getElementById('status'),
    frameModeState: document.getElementById('frameModeState'),
    rotationState: document.getElementById('rotationState'),
    autoNotice: document.getElementById('autoNotice'),
    outputLabel: document.getElementById('outputLabel'),
    blackCount: document.getElementById('blackCount'),
    paddingState: document.getElementById('paddingState'),
    hexDump: document.getElementById('hexDump'),
    connectBle: document.getElementById('connectBle'),
    sendBle: document.getElementById('sendBle'),
    bleState: document.getElementById('bleState'),
    bleProgress: document.getElementById('bleProgress'),
    bleProgressText: document.getElementById('bleProgressText'),
    bleDevice: document.getElementById('bleDevice'),
    bleChunks: document.getElementById('bleChunks'),
    bleCrc: document.getElementById('bleCrc'),
    bleRefresh: document.getElementById('bleRefresh'),
    bleMessage: document.getElementById('bleMessage')
  };
  const originalContext = elements.original.getContext('2d', { willReadFrequently: true });
  const thresholdContext = elements.thresholdCanvas.getContext('2d');
  const ditherContext = elements.ditherCanvas.getContext('2d');
  let sourceImage = null;
  let sourceName = '';
  let thresholdFrame = null;
  let ditherFrame = null;
  let packedFrame = null;
  let currentPlan = null;
  let bleDevice = null;
  let bleServer = null;
  let bleWrite = null;
  let bleNotify = null;
  let pendingBle = null;
  let transferActive = false;
  let sessionToken = 0;
  let nextTransferId = 1;

  function frameMode() { return document.querySelector('input[name="frameMode"]:checked').value; }
  function rotationMode() { return document.querySelector('input[name="rotationMode"]:checked').value; }
  function outputMode() { return document.querySelector('input[name="outputMode"]:checked').value; }
  function setStatus(message, state = 'idle') { elements.status.textContent = message; elements.status.dataset.state = state; }

  function setBleState(state, message, error = false) {
    elements.bleState.textContent = state;
    elements.bleState.dataset.state = state.toLowerCase();
    elements.bleMessage.textContent = message;
    elements.bleMessage.dataset.error = String(error);
  }

  function updateBleControls() {
    const connected = Boolean(bleServer?.connected);
    const frameReady = packedFrame instanceof Uint8Array && packedFrame.length === FRAME_BYTES && hasWhitePadding(packedFrame);
    elements.connectBle.disabled = transferActive || elements.bleState.dataset.state === 'connecting';
    elements.connectBle.textContent = connected ? 'DISCONNECT BLE' : 'CONNECT BLE';
    elements.sendBle.disabled = !connected || !frameReady || transferActive;
  }

  function rejectPendingBle(error) {
    if (!pendingBle) return;
    const current = pendingBle;
    pendingBle = null;
    clearTimeout(current.timer);
    current.reject(error);
  }

  function waitForBle(predicate, timeoutMs = 5000) {
    if (pendingBle) throw new Error('BLE_REQUEST_ALREADY_PENDING');
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pendingBle = null;
        reject(new Error('BLE_ACK_TIMEOUT'));
      }, timeoutMs);
      pendingBle = { predicate, resolve, reject, timer };
    });
  }

  function onBleNotification(event) {
    const view = event.target.value;
    const bytes = new Uint8Array(view.buffer.slice(view.byteOffset, view.byteOffset + view.byteLength));
    if (pendingBle && pendingBle.predicate(bytes)) {
      const current = pendingBle;
      pendingBle = null;
      clearTimeout(current.timer);
      current.resolve(bytes);
    }
  }

  async function writeBle(packet) {
    if (!bleWrite || !bleServer?.connected) throw new Error('BLE_DISCONNECTED');
    if (typeof bleWrite.writeValueWithResponse === 'function') await bleWrite.writeValueWithResponse(packet);
    else await bleWrite.writeValue(packet);
  }

  async function requestBle(packet, predicate, timeoutMs = 5000) {
    const response = waitForBle(predicate, timeoutMs);
    try { await writeBle(packet); }
    catch (error) { rejectPendingBle(error); throw error; }
    return response;
  }

  function handleBleDisconnect() {
    rejectPendingBle(new Error('BLE_DISCONNECTED'));
    const interrupted = transferActive;
    bleServer = null;
    bleWrite = null;
    bleNotify = null;
    sessionToken = 0;
    elements.bleDevice.textContent = 'Chưa kết nối';
    if (interrupted) setBleState('FAILED', 'BLE đã ngắt trong lúc truyền. Firmware đã hủy frame chưa hoàn tất.', true);
    else setBleState('DISCONNECTED', 'Thiết bị đã ngắt kết nối.');
    updateBleControls();
  }

  async function connectBle() {
    if (!('bluetooth' in navigator)) throw new Error('WEB_BLUETOOTH_NOT_SUPPORTED');
    setBleState('CONNECTING', 'Đang tìm EINK/HINK qua Web Bluetooth...');
    updateBleControls();
    try {
      bleDevice = await navigator.bluetooth.requestDevice({
        filters: [{ namePrefix: 'EINK' }, { namePrefix: 'HINK' }],
        optionalServices: [BLE_SERVICE_UUID]
      });
      bleDevice.addEventListener('gattserverdisconnected', handleBleDisconnect, { once: true });
      bleServer = await bleDevice.gatt.connect();
      const service = await bleServer.getPrimaryService(BLE_SERVICE_UUID);
      bleWrite = await service.getCharacteristic(BLE_WRITE_UUID);
      bleNotify = await service.getCharacteristic(BLE_NOTIFY_UUID);
      await bleNotify.startNotifications();
      bleNotify.addEventListener('characteristicvaluechanged', onBleNotification);
      elements.bleDevice.textContent = bleDevice.name || 'EINK/HINK';
      setBleState('READY', packedFrame ? 'Đã kết nối. Sẵn sàng gửi frame hiện tại.' : 'Đã kết nối. Upload ảnh để tạo frame 4,000 byte.');
    } catch (error) {
      bleServer = null;
      setBleState('FAILED', `Kết nối BLE thất bại: ${error.message}`, true);
      throw error;
    } finally {
      updateBleControls();
    }
  }

  async function openImageSession() {
    const response = await requestBle(
      Uint8Array.of(0xE4, 0x00, 0x48, 0x4C, 0x32, 0x31),
      packet => packet[0] === 0xE4 && packet[1] === 0x80
    );
    if (response[2] !== 0) throw new Error(`E4_SESSION_REJECTED_${response[2]}`);
    sessionToken = response[3];
  }

  async function keepImageSession() {
    const response = await requestBle(
      Uint8Array.of(0xE4, 0x01, sessionToken),
      packet => packet[0] === 0xE4 && packet[1] === 0x81
    );
    if (response[2] !== 0) throw new Error(`E4_KEEPALIVE_REJECTED_${response[2]}`);
  }

  async function closeImageSession() {
    if (!sessionToken || !bleServer?.connected) return;
    const token = sessionToken;
    const response = await requestBle(
      Uint8Array.of(0xE4, 0x02, token),
      packet => packet[0] === 0xE4 && packet[1] === 0x82
    );
    if (response[2] !== 0) throw new Error(`E4_CLOSE_REJECTED_${response[2]}`);
    sessionToken = 0;
  }

  const e5StatusName = status => ['OK', 'INVALID', 'NOT_OPEN', 'WRONG_OWNER', 'BAD_GEOMETRY', 'BAD_ID', 'BAD_SEQUENCE', 'OVERFLOW', 'BAD_COUNT', 'BAD_CRC', 'UNSUPPORTED'][status] || `CODE_${status}`;
  const e6StateName = state => ['IDLE', 'ACCEPTED_PENDING', 'REFRESHING', 'COMPLETE', 'ERROR'][state] || `STATE_${state}`;

  async function displayTransferredImage(transferId) {
    setBleState('DISPLAYING', 'Frame đã verify. Đang chạy một FULL EINK refresh...');
    elements.bleRefresh.textContent = 'ACCEPTED_PENDING';
    let response = await requestBle(
      Uint8Array.of(0xE6, 0x00, transferId),
      packet => packet[0] === 0xE6 && packet[1] === 0x80 && packet[3] === transferId
    );
    if (response[2] !== 0) throw new Error(`E6_REQUEST_REJECTED_${response[2]}`);
    let state = response[4];
    const deadline = Date.now() + 45000;
    while (state !== 0x03 && state !== 0x04) {
      if (Date.now() >= deadline) throw new Error('E6_DISPLAY_TIMEOUT');
      await new Promise(resolve => setTimeout(resolve, 500));
      await keepImageSession();
      response = await requestBle(
        Uint8Array.of(0xE6, 0x01, transferId),
        packet => packet[0] === 0xE6 && packet[1] === 0x81 && packet[3] === transferId
      );
      if (response[2] !== 0) throw new Error(`E6_STATUS_REJECTED_${response[2]}`);
      state = response[4];
      elements.bleRefresh.textContent = e6StateName(state);
    }
    if (state !== 0x03) throw new Error('E6_DISPLAY_FAILED');
  }

  async function sendCurrentFrame() {
    if (transferActive) return;
    if (!bleServer?.connected) throw new Error('BLE_DISCONNECTED');
    if (!(packedFrame instanceof Uint8Array) || packedFrame.length !== FRAME_BYTES) throw new Error('INVALID_IMAGE_FRAME');
    const frame = packedFrame.slice();
    const transferId = nextTransferId;
    nextTransferId = nextTransferId >= 255 ? 1 : nextTransferId + 1;
    const plan = createImageTransferPlan(frame, transferId);
    transferActive = true;
    elements.bleProgress.value = 0;
    elements.bleProgressText.textContent = `0 / ${FRAME_BYTES.toLocaleString('en-US')} bytes`;
    elements.bleChunks.textContent = `0 / ${IMAGE_TOTAL_CHUNKS}`;
    elements.bleCrc.textContent = plan.crc.toString(16).padStart(4, '0').toUpperCase();
    elements.bleRefresh.textContent = 'Chưa chạy';
    setBleState('SENDING', 'Đang mở session và gửi dữ liệu thật theo ACK từ firmware...');
    updateBleControls();
    try {
      await openImageSession();
      let response = await requestBle(
        plan.start,
        packet => packet[0] === 0xE5 && packet[1] === 0x80 && packet[3] === transferId
      );
      if (response[2] !== 0) throw new Error(`E5_START_${e5StatusName(response[2])}`);

      for (const chunk of plan.chunks) {
        response = await requestBle(
          chunk.packet,
          packet => packet[0] === 0xE5 && packet[1] === 0x81 && packet[3] === transferId
        );
        if (response[2] !== 0) throw new Error(`E5_DATA_${chunk.sequence}_${e5StatusName(response[2])}`);
        const nextSequence = response[4] | (response[5] << 8);
        const acknowledgedBytes = response[6] | (response[7] << 8);
        if (nextSequence !== chunk.sequence + 1 || acknowledgedBytes !== chunk.offset + chunk.data.length) throw new Error('E5_ACK_MISMATCH');
        elements.bleProgress.value = acknowledgedBytes;
        elements.bleProgressText.textContent = `${acknowledgedBytes.toLocaleString('en-US')} / ${FRAME_BYTES.toLocaleString('en-US')} bytes`;
        elements.bleChunks.textContent = `${nextSequence} / ${IMAGE_TOTAL_CHUNKS}`;
      }

      setBleState('VERIFYING', 'Đủ 4,000 byte. Đang COMMIT và đối chiếu CRC/status firmware...');
      response = await requestBle(
        plan.commit,
        packet => packet[0] === 0xE5 && packet[1] === 0x82 && packet[3] === transferId
      );
      let manifest = parseImageManifest(response);
      if (manifest.status !== 0) throw new Error(`E5_COMMIT_${e5StatusName(manifest.status)}`);
      response = await requestBle(
        plan.status,
        packet => packet[0] === 0xE5 && packet[1] === 0x83 && packet[3] === transferId
      );
      manifest = parseImageManifest(response);
      if (manifest.status !== 0 || manifest.state !== 2 || manifest.chunks !== IMAGE_TOTAL_CHUNKS || manifest.bytes !== FRAME_BYTES || manifest.crc !== plan.crc) throw new Error('E5_FINAL_MANIFEST_MISMATCH');

      await displayTransferredImage(transferId);
      setBleState('SUCCESS', 'Ảnh đã hiển thị. Clock EINK updates tạm dừng tới khi khởi động lại hoặc gửi ảnh mới.');
      elements.bleRefresh.textContent = 'FULL PASS';
      try { await closeImageSession(); } catch { sessionToken = 0; }
    } catch (error) {
      setBleState('FAILED', `Gửi ảnh thất bại: ${error.message}`, true);
      throw error;
    } finally {
      transferActive = false;
      updateBleControls();
    }
  }

  function updateTransformSummary(plan) {
    elements.frameModeState.textContent = plan.frameMode === 'auto'
      ? `AUTO → ${plan.resolvedFrameMode.toUpperCase()}`
      : plan.resolvedFrameMode.toUpperCase();
    elements.rotationState.textContent = plan.rotationMode === 'auto'
      ? `AUTO → ${plan.rotation}°`
      : `${plan.rotation}° MANUAL`;
    if (plan.autoRotated) {
      elements.autoNotice.textContent = 'Auto đã xoay ảnh ngang 90° để phù hợp hơn với màn hình dọc.';
    } else if (plan.rotationMode === 'auto') {
      elements.autoNotice.textContent = 'Auto giữ nguyên hướng ảnh vì hướng gốc phù hợp hơn với màn hình dọc.';
    } else {
      elements.autoNotice.textContent = `Đang dùng xoay thủ công ${plan.rotation}°; Auto orientation tạm ngưng.`;
    }
  }

  function drawSource() {
    if (!sourceImage) return;
    currentPlan = resolveProcessingPlan(sourceImage.width, sourceImage.height, frameMode(), rotationMode());
    const orientedSource = createOrientedCanvas(sourceImage, currentPlan.rotation);
    const placement = computeImagePlacement(orientedSource.width, orientedSource.height, currentPlan.scaleMode);
    originalContext.save();
    originalContext.fillStyle = '#fff';
    originalContext.fillRect(0, 0, FRAME_WIDTH, FRAME_HEIGHT);
    originalContext.imageSmoothingEnabled = true;
    originalContext.imageSmoothingQuality = 'high';
    originalContext.drawImage(orientedSource, placement.sx, placement.sy, placement.sw, placement.sh, placement.dx, placement.dy, placement.dw, placement.dh);
    originalContext.restore();
    updateTransformSummary(currentPlan);
    processFrame();
  }

  function processFrame() {
    const rgba = originalContext.getImageData(0, 0, FRAME_WIDTH, FRAME_HEIGHT).data;
    const luminance = rgbaToLuminance(rgba);
    const boundary = Number(elements.threshold.value);
    thresholdFrame = thresholdPixels(luminance, boundary);
    ditherFrame = floydSteinbergPixels(luminance, boundary);
    thresholdContext.putImageData(monoToImageData(thresholdFrame), 0, 0);
    ditherContext.putImageData(monoToImageData(ditherFrame), 0, 0);
    updateOutput();
  }

  function updateOutput() {
    if (!thresholdFrame || !ditherFrame) return;
    const mode = outputMode();
    const pixels = mode === 'dither' ? ditherFrame : thresholdFrame;
    packedFrame = packMonochromeFrame(pixels);
    const dump = formatHexDump(packedFrame);
    const black = pixels.reduce((total, value) => total + (value === 0 ? 1 : 0), 0);
    elements.hexDump.textContent = dump;
    elements.blackCount.textContent = black.toLocaleString('vi-VN');
    elements.outputLabel.textContent = mode === 'dither' ? 'Floyd–Steinberg output' : 'Threshold output';
    elements.thresholdCard.dataset.selected = String(mode === 'threshold');
    elements.ditherCard.dataset.selected = String(mode === 'dither');
    elements.paddingState.textContent = hasWhitePadding(packedFrame) ? 'PADDING: PASS' : 'PADDING: FAIL';
    elements.paddingState.dataset.pass = String(hasWhitePadding(packedFrame));
    elements.download.disabled = false;
    elements.copy.disabled = false;
    const transform = currentPlan ? `${currentPlan.resolvedFrameMode.toUpperCase()} · ${currentPlan.rotation}°` : '122×250';
    setStatus(`Frame sẵn sàng: ${mode === 'dither' ? 'Dithered' : 'Threshold'} · ${transform} · 4,000 bytes.`, 'ready');
    if (bleServer?.connected && !transferActive) setBleState('READY', 'Frame hiện tại sẵn sàng gửi; BLE dùng đúng bytes đang preview/export.');
    updateBleControls();
  }

  async function loadFile(file) {
    if (!file || !['image/jpeg', 'image/png'].includes(file.type)) {
      setStatus('Chỉ chấp nhận file JPG hoặc PNG.', 'error');
      return;
    }
    try {
      const bitmap = await createImageBitmap(file);
      if (sourceImage && typeof sourceImage.close === 'function') sourceImage.close();
      sourceImage = bitmap;
      sourceName = file.name.replace(/\.[^.]+$/, '') || 'eink-frame';
      elements.fileMeta.textContent = `${file.name} · ${bitmap.width}×${bitmap.height}`;
      drawSource();
    } catch (error) {
      setStatus(`Không đọc được ảnh: ${error.message}`, 'error');
    }
  }

  elements.input.addEventListener('change', () => loadFile(elements.input.files[0]));
  for (const eventName of ['dragenter', 'dragover']) elements.dropZone.addEventListener(eventName, event => { event.preventDefault(); elements.dropZone.dataset.drag = 'true'; });
  for (const eventName of ['dragleave', 'drop']) elements.dropZone.addEventListener(eventName, event => { event.preventDefault(); elements.dropZone.dataset.drag = 'false'; });
  elements.dropZone.addEventListener('drop', event => loadFile(event.dataTransfer.files[0]));
  elements.threshold.addEventListener('input', () => { elements.thresholdValue.value = elements.threshold.value; if (sourceImage) processFrame(); });
  document.querySelectorAll('input[name="frameMode"]').forEach(input => input.addEventListener('change', drawSource));
  document.querySelectorAll('input[name="rotationMode"]').forEach(input => input.addEventListener('change', drawSource));
  document.querySelectorAll('input[name="outputMode"]').forEach(input => input.addEventListener('change', updateOutput));
  elements.download.addEventListener('click', () => {
    if (!packedFrame) return;
    const url = URL.createObjectURL(new Blob([packedFrame], { type: 'application/octet-stream' }));
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = `${sourceName}-${outputMode()}-${currentPlan?.rotation ?? 0}deg-122x250-1bit.bin`;
    anchor.click();
    URL.revokeObjectURL(url);
  });
  elements.copy.addEventListener('click', async () => {
    if (!packedFrame) return;
    try { await navigator.clipboard.writeText(formatHexDump(packedFrame)); setStatus('Đã copy toàn bộ 4,000 byte dạng hex.', 'ready'); }
    catch { setStatus('Trình duyệt không cho phép copy tự động.', 'error'); }
  });
  elements.connectBle.addEventListener('click', async () => {
    try {
      if (bleServer?.connected) bleDevice.gatt.disconnect();
      else await connectBle();
    } catch { /* Error is already reflected in the BLE status card. */ }
  });
  elements.sendBle.addEventListener('click', async () => {
    try { await sendCurrentFrame(); }
    catch { /* Error is already reflected in the BLE status card. */ }
  });
  updateBleControls();
}

if (typeof document !== 'undefined' && document.getElementById('imageFile')) bootstrap();
