export const FRAME_WIDTH = 122;
export const FRAME_HEIGHT = 250;
export const FRAME_STRIDE = 16;
export const FRAME_BYTES = FRAME_HEIGHT * FRAME_STRIDE;

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
  const sourceRatio = sourceWidth / sourceHeight;
  const targetRatio = FRAME_WIDTH / FRAME_HEIGHT;
  const retainedFraction = Math.min(sourceRatio / targetRatio, targetRatio / sourceRatio);
  return retainedFraction >= 0.72 ? 'fill' : 'fit';
}

export function resolveProcessingPlan(sourceWidth, sourceHeight, frameMode = 'auto', rotationMode = 'auto') {
  if (!['auto', 'fit', 'fill'].includes(frameMode)) throw new Error('INVALID_FRAME_MODE');
  const rotation = rotationMode === 'auto' ? chooseAutoRotation(sourceWidth, sourceHeight) : normalizeRotation(rotationMode);
  const dimensions = orientedDimensions(sourceWidth, sourceHeight, rotation);
  const resolvedFrameMode = frameMode === 'auto' ? chooseAutoFrameMode(dimensions.width, dimensions.height) : frameMode;
  return {
    frameMode,
    resolvedFrameMode,
    scaleMode: resolvedFrameMode === 'fill' ? 'cover' : 'contain',
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

function monoToImageData(pixels) {
  const image = new ImageData(FRAME_WIDTH, FRAME_HEIGHT);
  for (let pixel = 0, offset = 0; pixel < pixels.length; pixel += 1, offset += 4) {
    image.data[offset] = pixels[pixel];
    image.data[offset + 1] = pixels[pixel];
    image.data[offset + 2] = pixels[pixel];
    image.data[offset + 3] = 255;
  }
  return image;
}

function createOrientedCanvas(image, rotation) {
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
    hexDump: document.getElementById('hexDump')
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

  function frameMode() { return document.querySelector('input[name="frameMode"]:checked').value; }
  function rotationMode() { return document.querySelector('input[name="rotationMode"]:checked').value; }
  function outputMode() { return document.querySelector('input[name="outputMode"]:checked').value; }
  function setStatus(message, state = 'idle') { elements.status.textContent = message; elements.status.dataset.state = state; }

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
}

if (typeof document !== 'undefined') bootstrap();
