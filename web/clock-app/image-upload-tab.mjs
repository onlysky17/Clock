import {
  FRAME_BYTES,
  FRAME_HEIGHT,
  FRAME_WIDTH,
  IMAGE_TOTAL_CHUNKS,
  MANUAL_CROP_MAX_ZOOM,
  MANUAL_CROP_MIN_ZOOM,
  computeImagePlacement,
  computeManualCropPlacement,
  createImageTransferPlan,
  createOrientedCanvas,
  floydSteinbergPixels,
  formatHexDump,
  hasWhitePadding,
  monoToImageData,
  normalizeManualCropState,
  packMonochromeFrame,
  panManualCropByViewportDelta,
  parseImageManifest,
  resolveProcessingPlan,
  rgbaToLuminance,
  thresholdPixels
} from './image-upload.mjs';

const E5_STATUS_NAMES = ['OK', 'INVALID', 'NOT_OPEN', 'WRONG_OWNER', 'BAD_GEOMETRY', 'BAD_ID', 'BAD_SEQUENCE', 'OVERFLOW', 'BAD_COUNT', 'BAD_CRC', 'UNSUPPORTED'];

export function applyMainTabSelection(name, buttons, clockPanels, imagePanel) {
  if (name !== 'clock' && name !== 'image') throw new Error('INVALID_MAIN_TAB');
  for (const button of buttons) {
    const selected = button.dataset.appTab === name;
    button.classList.toggle('selected', selected);
    button.setAttribute('aria-selected', String(selected));
    button.tabIndex = selected ? 0 : -1;
  }
  for (const panel of clockPanels) {
    panel.hidden = name !== 'clock';
    panel.setAttribute?.('aria-hidden', String(name !== 'clock'));
  }
  imagePanel.hidden = name !== 'image';
  imagePanel.setAttribute?.('aria-hidden', String(name !== 'image'));
  return name;
}

function installStyles() {
  if (document.getElementById('einkImageTabStyles')) return;
  const style = document.createElement('style');
  style.id = 'einkImageTabStyles';
  style.textContent = `
    [data-app-view="clock"][hidden]{display:none!important}
    .einkAppTabs{grid-column:1/-1;grid-row:2;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;padding:5px;border:1px solid var(--line);border-radius:14px;background:#091522}
    .einkAppTabs button{min-height:46px;border-color:transparent;background:transparent;color:var(--muted);font-size:.95rem}
    .einkAppTabs button.selected{border-color:#52d8ff;background:#12364a;color:#fff;box-shadow:inset 0 0 0 1px #52d8ff}
    .einkAppTabs button:focus-visible{outline:2px solid #b8f1ff;outline-offset:2px}
    main.productModeV2.hasAppTabs .productModeV2Preview,main.productModeV2.hasAppTabs .productModeV2Actions{grid-row:3}
    main.productModeV2.hasAppTabs .productModeV2Profiles{grid-row:4}
    .einkImageView{grid-column:1/-1;grid-row:3;min-width:0}
    .imageFlow{display:grid;grid-template-columns:minmax(330px,43fr) minmax(0,57fr);gap:14px;align-items:stretch;min-width:0}
    .imageControls,.imagePreviewArea,.imageSendCard{margin:0}
    .imageControls{display:grid;gap:14px;align-content:start;height:100%}
    .imagePreviewArea{display:flex;flex-direction:column;height:100%;min-width:0}
    .imageStep{display:grid;gap:8px}
    .imageStep h2,.imagePreviewArea h2,.imageSendCard h2{margin:0;font-size:1.05rem}
    .imageStep p,.imagePreviewArea p,.imageSendCard p{margin:0;font-size:.86rem}
    .imageFileInput{width:100%;min-width:0;max-width:100%;padding:12px;border:1px dashed #52708e;border-radius:12px;background:#091522}
    .imageSegmented{display:grid;grid-template-columns:repeat(auto-fit,minmax(74px,1fr));gap:7px}
    .imageSegmented label{position:relative;min-width:0;width:100%;cursor:pointer}
    .imageSegmented input{position:absolute;opacity:0;pointer-events:none}
    .imageSegmented span{display:grid;place-items:center;min-width:0;width:100%;min-height:44px;padding:8px;border:1px solid #415c78;border-radius:10px;background:#0b1827;color:var(--muted);font-weight:800;text-align:center}
    .imageSegmented input:checked+span{border-color:#52d8ff;background:#12364a;color:#fff}
    .imageSegmented input:focus-visible+span{outline:2px solid #b8f1ff;outline-offset:2px}
    .imageRange{display:grid;grid-template-columns:minmax(0,1fr) 48px;gap:9px;align-items:center}
    .imageRange output{font-weight:900;text-align:center}
    .imageTransformState{padding:9px 11px;border-radius:10px;background:#0b1421;color:var(--muted);font-size:.84rem}
    .imageManualCrop[hidden]{display:none!important}
    .imageManualCrop{display:grid;grid-template-columns:minmax(138px,.75fr) minmax(150px,1fr);gap:12px;align-items:center;padding:12px;border:1px solid #304b65;border-radius:13px;background:#07111d}
    .imageManualViewport{position:relative;display:grid;place-items:center;width:min(100%,146px);aspect-ratio:122/250;justify-self:center;overflow:hidden;border:2px solid #52d8ff;border-radius:8px;background:#fff;box-shadow:0 10px 24px rgba(0,0,0,.28);cursor:grab;touch-action:none;user-select:none}
    .imageManualViewport[data-dragging="true"]{cursor:grabbing;border-color:#8ce9ff}
    .imageManualViewport canvas{display:block;width:100%;height:100%;background:#fff;image-rendering:auto;pointer-events:none}
    .imageManualTools{display:grid;gap:10px;min-width:0}
    .imageManualTools label{display:flex;justify-content:space-between;gap:8px;color:var(--muted);font-size:.84rem;font-weight:800}
    .imageManualTools input[type="range"]{width:100%;min-height:44px;touch-action:pan-x}
    .imageManualTools button{width:100%;min-width:0}
    .imageManualHint{font-size:.78rem!important;line-height:1.45}
    .imagePreviewGrid{display:grid;grid-template-columns:repeat(3,minmax(132px,1fr));gap:10px;align-items:stretch;margin-top:12px;padding:2px}
    .imagePreviewCard{display:flex;flex-direction:column;min-width:0;height:100%;padding:11px;border:1px solid var(--line);border-radius:13px;background:#0b1421;text-align:center}
    .imagePreviewCard[data-selectable="true"]{cursor:pointer}
    .imagePreviewCard[data-selectable="true"]:hover{border-color:#6687a8;background:#102238}
    .imagePreviewCard[data-selectable="true"]:focus-visible{outline:2px solid #b8f1ff;outline-offset:2px}
    .imagePreviewCard[data-selected="true"]{border-color:#52d8ff;background:#12364a;box-shadow:inset 0 0 0 1px #52d8ff}
    .imagePreviewLabel{display:flex;justify-content:center;gap:6px;align-items:center;margin-bottom:8px;font-weight:850}
    .imagePreviewCard[data-selected="true"] .imagePreviewLabel::after{content:'✓';color:var(--ok)}
    .imagePanelBezel{display:grid;place-items:center;flex:1;padding:7px;border-radius:9px;background:#050910}
    .imagePanelBezel canvas{width:122px;height:250px;max-width:none;border:1px solid #62708a;background:#fff;image-rendering:pixelated;touch-action:auto}
    .imageSendCard{grid-column:1/-1;width:100%;display:grid;grid-template-columns:minmax(0,1fr) auto auto;gap:12px;align-items:center}
    .imageSendStatus{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
    .imageBleState{display:inline-flex;padding:6px 10px;border:1px solid #415c78;border-radius:999px;color:var(--warn);font-weight:900}
    .imageBleState[data-connected="true"]{border-color:#2f755d;color:var(--ok)}
    .imageSendAction{min-width:180px;background:#066047}
    .imageSendProgress{grid-column:1/-1;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:10px;align-items:center}
    .imageSendProgress progress{margin:0;height:12px}
    .imageUserStatus{grid-column:1/-1;margin:0;color:var(--muted)}
    .imageUserStatus[data-state="error"]{color:var(--bad)}
    .imageUserStatus[data-state="success"]{color:var(--ok)}
    .imageTechnical{grid-column:1/-1;border-top:1px solid var(--line);padding-top:10px}
    .imageTechnical summary{cursor:pointer;color:var(--muted);font-weight:800}
    .imageTechnicalActions{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}
    .imageTechnicalActions button{flex:1 1 160px}
    @media(min-width:761px) and (max-width:1100px){
      .imageFlow{grid-template-columns:minmax(0,1fr);gap:14px}
      .imageControls,.imagePreviewArea,.imageSendCard{width:100%;height:auto;min-width:0;min-height:0}
      .imagePreviewGrid{grid-template-columns:repeat(2,minmax(0,1fr));overflow:visible}
      .imagePreviewCard:first-child{grid-column:1/-1;width:min(100%,360px);justify-self:center}
      .imageSendCard{grid-column:1;width:100%}
    }
    @media(max-width:760px){
      .einkAppTabs,.einkImageView{grid-column:1;grid-row:auto}
      .einkImageView{max-width:100%;overflow:hidden}
      .imageFlow{grid-template-columns:minmax(0,1fr);gap:12px}
      .imageControls,.imagePreviewArea,.imageSendCard{width:100%;min-width:0}
      .imageStep,.imageSegmented{min-width:0;max-width:100%}
      .imageFrameOptions{grid-template-columns:repeat(2,minmax(0,1fr))}
      .imageRotationOptions{grid-template-columns:repeat(3,minmax(0,1fr))}
      .imageOutputOptions{grid-template-columns:repeat(2,minmax(0,1fr))}
      .imageManualCrop{grid-template-columns:minmax(0,1fr)}
      .imagePreviewGrid{grid-template-columns:minmax(0,1fr);overflow:visible}
      .imagePreviewCard{width:100%;min-width:0}
      .imageSendCard{grid-template-columns:minmax(0,1fr)}
      .imageSendAction{width:100%}
      .imageSendProgress,.imageUserStatus,.imageTechnical{grid-column:1}
    }
  `;
  document.head.append(style);
}

function stateName(status) {
  return E5_STATUS_NAMES[status] || `CODE_${status}`;
}

export function mountImageUploadTab(root, session) {
  if (!root || !session) throw new Error('IMAGE_TAB_MOUNT_FAILED');
  installStyles();
  root.innerHTML = `
    <div class="imageFlow">
      <section class="card imageControls" aria-label="Chuẩn bị ảnh EINK">
        <div class="imageStep">
          <h2>1. Chọn ảnh</h2>
          <input id="mainImageFile" class="imageFileInput" type="file" accept="image/jpeg,image/png,.jpg,.jpeg,.png">
          <p id="mainImageFileMeta">Chọn ảnh JPG hoặc PNG.</p>
        </div>
        <div class="imageStep">
          <h2>2. Căn ảnh</h2>
          <div class="imageSegmented imageFrameOptions">
            <label><input type="radio" name="mainImageFrameMode" value="auto" checked><span>Auto</span></label>
            <label><input type="radio" name="mainImageFrameMode" value="fit"><span>Fit</span></label>
            <label><input type="radio" name="mainImageFrameMode" value="fill"><span>Fill / Crop</span></label>
            <label><input type="radio" name="mainImageFrameMode" value="manual"><span>Crop tay</span></label>
          </div>
          <p>Auto ưu tiên lấp đầy khi Fit để lại nhiều khoảng trắng. Ảnh luôn giữ đúng tỉ lệ.</p>
          <div id="mainImageManualCrop" class="imageManualCrop" hidden>
            <div id="mainImageManualViewport" class="imageManualViewport" data-dragging="false" aria-label="Khung Crop tay 122 × 250; kéo 1 ngón để chọn vùng, chụm hoặc mở 2 ngón để zoom" role="application">
              <canvas id="mainImageCropCanvas" width="122" height="250"></canvas>
            </div>
            <div class="imageManualTools">
              <label for="mainImageCropZoom"><span>Zoom</span><output id="mainImageCropZoomValue">100%</output></label>
              <input id="mainImageCropZoom" type="range" min="100" max="400" step="1" value="100" aria-label="Zoom Crop tay">
              <button id="mainImageCropReset" type="button">Đặt lại crop</button>
              <p class="imageManualHint">Kéo 1 ngón để chọn vùng, chụm hoặc mở 2 ngón để zoom. Thanh Zoom luôn đồng bộ. Crop được giữ khi đổi mode; ảnh mới hoặc đổi xoay sẽ đặt lại ở giữa.</p>
            </div>
          </div>
        </div>
        <div class="imageStep">
          <h2>3. Xoay</h2>
          <div class="imageSegmented imageRotationOptions">
            <label><input type="radio" name="mainImageRotation" value="auto" checked><span>Auto</span></label>
            <label><input type="radio" name="mainImageRotation" value="0"><span>0°</span></label>
            <label><input type="radio" name="mainImageRotation" value="90"><span>90°</span></label>
            <label><input type="radio" name="mainImageRotation" value="180"><span>180°</span></label>
            <label><input type="radio" name="mainImageRotation" value="270"><span>270°</span></label>
          </div>
          <div id="mainImageTransform" class="imageTransformState" aria-live="polite">Auto sẽ chọn hướng và cách căn sau khi tải ảnh.</div>
        </div>
        <div class="imageStep">
          <h2>4. Kiểu hiển thị</h2>
          <div class="imageSegmented imageOutputOptions">
            <label><input type="radio" name="mainImageOutput" value="threshold" checked><span>Threshold</span></label>
            <label><input type="radio" name="mainImageOutput" value="dither"><span>Floyd–Steinberg</span></label>
          </div>
          <div class="imageRange">
            <input id="mainImageThreshold" type="range" min="0" max="255" value="128" aria-label="Ngưỡng trắng đen">
            <output id="mainImageThresholdValue">128</output>
          </div>
        </div>
      </section>

      <section class="card imagePreviewArea">
        <h2>Xem trước</h2>
        <p>Chạm Threshold hoặc Floyd–Steinberg để chọn ảnh sẽ gửi.</p>
        <div class="imagePreviewGrid">
          <article class="imagePreviewCard" id="mainImageOriginalCard" data-selectable="false">
            <div class="imagePreviewLabel">Original</div>
            <div class="imagePanelBezel"><canvas id="mainImageOriginal" width="122" height="250" aria-label="Ảnh gốc đã căn"></canvas></div>
          </article>
          <article class="imagePreviewCard" id="mainImageThresholdCard" data-selectable="true" data-mode="threshold" role="button" tabindex="0" aria-pressed="true">
            <div class="imagePreviewLabel">Threshold</div>
            <div class="imagePanelBezel"><canvas id="mainImageThresholdCanvas" width="122" height="250" aria-label="Ảnh Threshold"></canvas></div>
          </article>
          <article class="imagePreviewCard" id="mainImageDitherCard" data-selectable="true" data-mode="dither" role="button" tabindex="0" aria-pressed="false">
            <div class="imagePreviewLabel">Floyd–Steinberg</div>
            <div class="imagePanelBezel"><canvas id="mainImageDitherCanvas" width="122" height="250" aria-label="Ảnh Floyd-Steinberg"></canvas></div>
          </article>
        </div>
      </section>

      <section class="card imageSendCard">
        <div>
          <h2>5. Gửi lên E-ink</h2>
          <div class="imageSendStatus"><strong id="mainImageBleState" class="imageBleState" data-connected="false">Chưa kết nối</strong><span id="mainImageDevice">Kết nối để gửi ảnh.</span></div>
        </div>
        <button id="mainImageConnect" class="imageConnectAction" type="button">KẾT NỐI THIẾT BỊ</button>
        <button id="mainImageSend" class="imageSendAction" type="button" disabled>GỬI LÊN E-INK</button>
        <div class="imageSendProgress"><progress id="mainImageProgress" max="100" value="0"></progress><strong id="mainImageProgressText">0%</strong></div>
        <p id="mainImageStatus" class="imageUserStatus" data-state="idle" role="status" aria-live="polite">Chọn ảnh để bắt đầu.</p>
        <details class="imageTechnical">
          <summary>Chi tiết kỹ thuật</summary>
          <div class="imageTechnicalActions"><button id="mainImageDownload" type="button" disabled>Tải frame .bin</button><button id="mainImageCopy" type="button" disabled>Copy dữ liệu hex</button></div>
        </details>
      </section>
    </div>
  `;

  const byId = id => root.querySelector(`#${id}`);
  const originalCanvas = byId('mainImageOriginal');
  const thresholdCanvas = byId('mainImageThresholdCanvas');
  const ditherCanvas = byId('mainImageDitherCanvas');
  const cropCanvas = byId('mainImageCropCanvas');
  const originalContext = originalCanvas.getContext('2d', { willReadFrequently: true });
  const thresholdContext = thresholdCanvas.getContext('2d');
  const ditherContext = ditherCanvas.getContext('2d');
  const cropContext = cropCanvas.getContext('2d');
  const cards = [byId('mainImageThresholdCard'), byId('mainImageDitherCard')];
  let sourceImage = null;
  let sourceName = 'eink-image';
  let thresholdFrame = null;
  let ditherFrame = null;
  let packedFrame = null;
  let currentPlan = null;
  let transferActive = false;
  let nextTransferId = 1;
  let imageSessionToken = 0;
  let connected = false;
  let connectActive = false;
  let manualCrop = normalizeManualCropState();
  const cropPointers = new Map();
  let cropPinch = null;

  const selectedValue = name => root.querySelector(`input[name="${name}"]:checked`).value;
  const setUserStatus = (text, state = 'idle') => {
    byId('mainImageStatus').textContent = text;
    byId('mainImageStatus').dataset.state = state;
  };

  function updateControls() {
    const ready = packedFrame instanceof Uint8Array && packedFrame.length === FRAME_BYTES && hasWhitePadding(packedFrame);
    const connectButton = byId('mainImageConnect');
    connectButton.hidden = connected;
    connectButton.disabled = connected || connectActive || transferActive;
    byId('mainImageSend').disabled = !connected || !ready || transferActive;
    byId('mainImageDownload').disabled = !ready || transferActive;
    byId('mainImageCopy').disabled = !ready || transferActive;
  }

  function renderSession(snapshot) {
    connected = Boolean(snapshot?.connected);
    const state = byId('mainImageBleState');
    state.textContent = connected ? 'Đã kết nối' : 'Chưa kết nối';
    state.dataset.connected = String(connected);
    byId('mainImageDevice').textContent = connected ? (snapshot.deviceName || 'EINK/HINK') : 'Kết nối để gửi ảnh.';
    if (!connected && transferActive) setUserStatus('Lỗi kết nối. Hãy kết nối lại rồi thử gửi.', 'error');
    updateControls();
  }

  function updateSelectedCards() {
    const mode = selectedValue('mainImageOutput');
    for (const card of cards) {
      const selected = card.dataset.mode === mode;
      card.dataset.selected = String(selected);
      card.setAttribute('aria-pressed', String(selected));
    }
  }

  function updateOutput() {
    updateSelectedCards();
    if (!thresholdFrame || !ditherFrame) return;
    const pixels = selectedValue('mainImageOutput') === 'dither' ? ditherFrame : thresholdFrame;
    packedFrame = packMonochromeFrame(pixels);
    setUserStatus('Ảnh đã sẵn sàng để gửi.', 'ready');
    updateControls();
  }

  function processFrame() {
    const luminance = rgbaToLuminance(originalContext.getImageData(0, 0, FRAME_WIDTH, FRAME_HEIGHT).data);
    const boundary = Number(byId('mainImageThreshold').value);
    thresholdFrame = thresholdPixels(luminance, boundary);
    ditherFrame = floydSteinbergPixels(luminance, boundary);
    thresholdContext.putImageData(monoToImageData(thresholdFrame), 0, 0);
    ditherContext.putImageData(monoToImageData(ditherFrame), 0, 0);
    updateOutput();
  }

  function syncManualCropControls() {
    byId('mainImageCropZoom').value = String(Math.round(manualCrop.zoom * 100));
    byId('mainImageCropZoomValue').textContent = `${Math.round(manualCrop.zoom * 100)}%`;
  }

  function updateManualCropVisibility() {
    const active = selectedValue('mainImageFrameMode') === 'manual';
    byId('mainImageManualCrop').hidden = !active;
    return active;
  }

  function resetManualCrop(redraw = true) {
    manualCrop = normalizeManualCropState();
    syncManualCropControls();
    if (redraw && sourceImage) drawSource();
  }

  function drawSource() {
    if (!sourceImage) return;
    currentPlan = resolveProcessingPlan(
      sourceImage.width,
      sourceImage.height,
      selectedValue('mainImageFrameMode'),
      selectedValue('mainImageRotation')
    );
    const oriented = createOrientedCanvas(sourceImage, currentPlan.rotation);
    const placement = currentPlan.frameMode === 'manual'
      ? computeManualCropPlacement(oriented.width, oriented.height, manualCrop)
      : computeImagePlacement(oriented.width, oriented.height, currentPlan.scaleMode);
    originalContext.fillStyle = '#fff';
    originalContext.fillRect(0, 0, FRAME_WIDTH, FRAME_HEIGHT);
    originalContext.imageSmoothingEnabled = true;
    originalContext.imageSmoothingQuality = 'high';
    originalContext.drawImage(oriented, placement.sx, placement.sy, placement.sw, placement.sh, placement.dx, placement.dy, placement.dw, placement.dh);
    cropContext.clearRect(0, 0, FRAME_WIDTH, FRAME_HEIGHT);
    cropContext.drawImage(originalCanvas, 0, 0);
    const frameLabel = currentPlan.frameMode === 'manual'
      ? `Crop tay · zoom ${Math.round(manualCrop.zoom * 100)}%`
      : (currentPlan.frameMode === 'auto' ? `Auto → ${currentPlan.resolvedFrameMode === 'fill' ? 'Fill / Crop' : 'Fit'}` : (currentPlan.resolvedFrameMode === 'fill' ? 'Fill / Crop' : 'Fit'));
    const rotationLabel = currentPlan.rotationMode === 'auto' ? `Auto → ${currentPlan.rotation}°` : `${currentPlan.rotation}°`;
    const panLabel = currentPlan.frameMode === 'manual' ? ` · pan ${manualCrop.panX.toFixed(2)}, ${manualCrop.panY.toFixed(2)}` : '';
    byId('mainImageTransform').textContent = `${frameLabel}${panLabel} · ${rotationLabel} · giữ đúng tỉ lệ`;
    processFrame();
  }

  async function request(packet, predicate, options = {}) {
    return session.request(packet, predicate, options);
  }

  async function openSession() {
    const response = await request(Uint8Array.of(0xE4, 0x00, 0x48, 0x4C, 0x32, 0x31), packet => packet[0] === 0xE4 && packet[1] === 0x80, { timeout: 5000 });
    if (response[2] !== 0) throw new Error('Không thể mở phiên gửi ảnh.');
    imageSessionToken = response[3];
  }

  async function keepSession() {
    const response = await request(Uint8Array.of(0xE4, 0x01, imageSessionToken), packet => packet[0] === 0xE4 && packet[1] === 0x81, { timeout: 5000, quiet: true });
    if (response[2] !== 0) throw new Error('Phiên gửi ảnh đã hết hạn.');
  }

  async function closeSession() {
    if (!imageSessionToken || !session.getSnapshot().connected) return;
    const token = imageSessionToken;
    const response = await request(Uint8Array.of(0xE4, 0x02, token), packet => packet[0] === 0xE4 && packet[1] === 0x82, { timeout: 5000, quiet: true });
    if (response[2] === 0) imageSessionToken = 0;
  }

  async function displayImage(transferId) {
    setUserStatus('Đang hiển thị ảnh trên E-ink...');
    let response = await request(Uint8Array.of(0xE6, 0x00, transferId), packet => packet[0] === 0xE6 && packet[1] === 0x80 && packet[3] === transferId, { timeout: 5000 });
    if (response[2] !== 0) throw new Error('Thiết bị từ chối hiển thị ảnh.');
    let state = response[4];
    const deadline = Date.now() + 45000;
    while (state !== 0x03 && state !== 0x04) {
      if (Date.now() >= deadline) throw new Error('Hiển thị ảnh quá thời gian chờ.');
      await new Promise(resolve => setTimeout(resolve, 500));
      await keepSession();
      response = await request(Uint8Array.of(0xE6, 0x01, transferId), packet => packet[0] === 0xE6 && packet[1] === 0x81 && packet[3] === transferId, { timeout: 5000, quiet: true });
      if (response[2] !== 0) throw new Error('Không đọc được trạng thái hiển thị.');
      state = response[4];
    }
    if (state !== 0x03) throw new Error('Thiết bị báo lỗi hiển thị ảnh.');
  }

  async function sendCurrentFrame() {
    if (transferActive) return;
    if (!session.getSnapshot().connected) throw new Error('Chưa kết nối thiết bị.');
    if (!(packedFrame instanceof Uint8Array) || packedFrame.length !== FRAME_BYTES) throw new Error('Chưa có ảnh sẵn sàng.');
    const frame = packedFrame.slice();
    const transferId = nextTransferId;
    nextTransferId = nextTransferId >= 255 ? 1 : nextTransferId + 1;
    const plan = createImageTransferPlan(frame, transferId);
    transferActive = true;
    byId('mainImageProgress').value = 0;
    byId('mainImageProgressText').textContent = '0%';
    setUserStatus('Đang gửi ảnh...');
    updateControls();
    try {
      await session.runExclusive(async () => {
        await openSession();
        let response = await request(plan.start, packet => packet[0] === 0xE5 && packet[1] === 0x80 && packet[3] === transferId, { timeout: 5000 });
        if (response[2] !== 0) throw new Error(`Không thể bắt đầu gửi ảnh (${stateName(response[2])}).`);
        for (const chunk of plan.chunks) {
          response = await request(chunk.packet, packet => packet[0] === 0xE5 && packet[1] === 0x81 && packet[3] === transferId, { timeout: 5000, quiet: true });
          if (response[2] !== 0) throw new Error(`Gửi ảnh bị từ chối (${stateName(response[2])}).`);
          const nextSequence = response[4] | (response[5] << 8);
          const acknowledgedBytes = response[6] | (response[7] << 8);
          if (nextSequence !== chunk.sequence + 1 || acknowledgedBytes !== chunk.offset + chunk.data.length) throw new Error('Thiết bị xác nhận sai vị trí dữ liệu.');
          const percent = Math.floor(acknowledgedBytes * 100 / FRAME_BYTES);
          byId('mainImageProgress').value = percent;
          byId('mainImageProgressText').textContent = `${percent}%`;
          if (nextSequence % 40 === 0) await keepSession();
        }
        setUserStatus('Đang kiểm tra ảnh...');
        response = await request(plan.commit, packet => packet[0] === 0xE5 && packet[1] === 0x82 && packet[3] === transferId, { timeout: 5000 });
        let manifest = parseImageManifest(response);
        if (manifest.status !== 0) throw new Error(`Kiểm tra ảnh thất bại (${stateName(manifest.status)}).`);
        response = await request(plan.status, packet => packet[0] === 0xE5 && packet[1] === 0x83 && packet[3] === transferId, { timeout: 5000 });
        manifest = parseImageManifest(response);
        if (manifest.status !== 0 || manifest.state !== 2 || manifest.chunks !== IMAGE_TOTAL_CHUNKS || manifest.bytes !== FRAME_BYTES || manifest.crc !== plan.crc) throw new Error('Thiết bị chưa xác nhận đủ ảnh.');
        await displayImage(transferId);
        byId('mainImageProgress').value = 100;
        byId('mainImageProgressText').textContent = '100%';
        setUserStatus('Hoàn tất. Ảnh đã hiển thị trên E-ink.', 'success');
        try { await closeSession(); } catch { imageSessionToken = 0; }
      });
    } catch (error) {
      setUserStatus(error.message || 'Gửi ảnh thất bại.', 'error');
      throw error;
    } finally {
      transferActive = false;
      updateControls();
    }
  }

  byId('mainImageFile').addEventListener('change', async event => {
    const [file] = event.currentTarget.files;
    if (!file || !['image/jpeg', 'image/png'].includes(file.type)) {
      setUserStatus('Vui lòng chọn ảnh JPG hoặc PNG.', 'error');
      return;
    }
    try {
      const bitmap = await createImageBitmap(file);
      if (sourceImage && typeof sourceImage.close === 'function') sourceImage.close();
      sourceImage = bitmap;
      sourceName = file.name.replace(/\.[^.]+$/, '') || 'eink-image';
      byId('mainImageFileMeta').textContent = file.name;
      resetManualCrop(false);
      drawSource();
    } catch (error) {
      setUserStatus(`Không đọc được ảnh: ${error.message}`, 'error');
    }
  });
  byId('mainImageConnect').addEventListener('click', async () => {
    if (connectActive || connected || transferActive) return;
    connectActive = true;
    setUserStatus('Đang chờ chọn thiết bị BLE...');
    updateControls();
    try {
      await session.connect();
      setUserStatus('Đã kết nối. Chọn ảnh rồi bấm gửi.', 'ready');
    } catch (error) {
      setUserStatus(`Không kết nối được: ${error.message}`, 'error');
    } finally {
      connectActive = false;
      updateControls();
    }
  });
  root.querySelectorAll('input[name="mainImageFrameMode"]').forEach(input => input.addEventListener('change', () => {
    updateManualCropVisibility();
    drawSource();
  }));
  root.querySelectorAll('input[name="mainImageRotation"]').forEach(input => input.addEventListener('change', () => {
    resetManualCrop(false);
    drawSource();
  }));
  byId('mainImageCropZoom').addEventListener('input', event => {
    manualCrop = normalizeManualCropState({ ...manualCrop, zoom: Number(event.currentTarget.value) / 100 });
    syncManualCropControls();
    if (sourceImage) drawSource();
  });
  byId('mainImageCropReset').addEventListener('click', () => resetManualCrop());
  const cropViewport = byId('mainImageManualViewport');
  const clampUnit = value => Math.max(0, Math.min(1, value));

  function cropPointPair() {
    const points = [...cropPointers.values()];
    return points.length >= 2 ? points.slice(0, 2) : null;
  }

  function cropMidpoint(first, second) {
    return {
      x: (first.x + second.x) / 2,
      y: (first.y + second.y) / 2
    };
  }

  function cropDistance(first, second) {
    return Math.hypot(second.x - first.x, second.y - first.y);
  }

  function beginCropPinch() {
    const pair = cropPointPair();
    if (!pair || !sourceImage || !currentPlan) {
      cropPinch = null;
      return;
    }

    const [first, second] = pair;
    const distance = cropDistance(first, second);
    if (!(distance > 0)) {
      cropPinch = null;
      return;
    }

    cropPinch = {
      ids: [first.id, second.id],
      startDistance: distance,
      startState: { ...manualCrop },
      startMidpoint: cropMidpoint(first, second)
    };
  }

  function applyCropPinch(currentMidpoint, currentDistance) {
    if (!cropPinch || !sourceImage || !currentPlan || !(currentDistance > 0)) return;

    const bounds = cropViewport.getBoundingClientRect();
    if (!(bounds.width > 0) || !(bounds.height > 0)) return;

    const startState = normalizeManualCropState(cropPinch.startState);
    const startPlacement = computeManualCropPlacement(
      currentPlan.orientedWidth,
      currentPlan.orientedHeight,
      startState
    );

    const startU = clampUnit((cropPinch.startMidpoint.x - bounds.left) / bounds.width);
    const startV = clampUnit((cropPinch.startMidpoint.y - bounds.top) / bounds.height);
    const anchorSourceX = startPlacement.sx + startPlacement.sw * startU;
    const anchorSourceY = startPlacement.sy + startPlacement.sh * startV;

    const zoomedState = normalizeManualCropState({
      ...startState,
      zoom: startState.zoom * currentDistance / cropPinch.startDistance
    });

    const nextPlacement = computeManualCropPlacement(
      currentPlan.orientedWidth,
      currentPlan.orientedHeight,
      zoomedState
    );

    const currentU = clampUnit((currentMidpoint.x - bounds.left) / bounds.width);
    const currentV = clampUnit((currentMidpoint.y - bounds.top) / bounds.height);
    const wantedSx = anchorSourceX - nextPlacement.sw * currentU;
    const wantedSy = anchorSourceY - nextPlacement.sh * currentV;
    const clampedSx = Math.max(0, Math.min(nextPlacement.maxSx, wantedSx));
    const clampedSy = Math.max(0, Math.min(nextPlacement.maxSy, wantedSy));

    manualCrop = normalizeManualCropState({
      zoom: zoomedState.zoom,
      panX: nextPlacement.maxSx > 0 ? clampedSx * 2 / nextPlacement.maxSx - 1 : 0,
      panY: nextPlacement.maxSy > 0 ? clampedSy * 2 / nextPlacement.maxSy - 1 : 0
    });

    syncManualCropControls();
    drawSource();
  }

  cropViewport.addEventListener('pointerdown', event => {
    if (!sourceImage || selectedValue('mainImageFrameMode') !== 'manual') return;
    if (!cropPointers.has(event.pointerId) && cropPointers.size >= 2) return;

    event.preventDefault();
    cropPointers.set(event.pointerId, {
      id: event.pointerId,
      x: event.clientX,
      y: event.clientY
    });
    cropViewport.dataset.dragging = 'true';
    cropViewport.setPointerCapture?.(event.pointerId);

    if (cropPointers.size === 2) beginCropPinch();
  });

  cropViewport.addEventListener('pointermove', event => {
    const previous = cropPointers.get(event.pointerId);
    if (!previous || !sourceImage || !currentPlan) return;

    event.preventDefault();
    cropPointers.set(event.pointerId, {
      id: event.pointerId,
      x: event.clientX,
      y: event.clientY
    });

    if (cropPointers.size >= 2) {
      if (!cropPinch) beginCropPinch();
      const first = cropPointers.get(cropPinch?.ids?.[0]);
      const second = cropPointers.get(cropPinch?.ids?.[1]);
      if (first && second) {
        applyCropPinch(cropMidpoint(first, second), cropDistance(first, second));
      }
      return;
    }

    cropPinch = null;
    const bounds = cropViewport.getBoundingClientRect();
    manualCrop = panManualCropByViewportDelta(
      manualCrop,
      event.clientX - previous.x,
      event.clientY - previous.y,
      bounds.width,
      bounds.height,
      currentPlan.orientedWidth,
      currentPlan.orientedHeight
    );
    drawSource();
  });

  const finishCropPointer = event => {
    if (!cropPointers.has(event.pointerId)) return;
    cropPointers.delete(event.pointerId);
    cropPinch = null;

    if (cropViewport.hasPointerCapture?.(event.pointerId)) {
      cropViewport.releasePointerCapture(event.pointerId);
    }

    cropViewport.dataset.dragging = cropPointers.size > 0 ? 'true' : 'false';
  };

  cropViewport.addEventListener('pointerup', finishCropPointer);
  cropViewport.addEventListener('pointercancel', finishCropPointer);
  cropViewport.addEventListener('lostpointercapture', event => {
    if (!cropPointers.has(event.pointerId)) return;
    cropPointers.delete(event.pointerId);
    cropPinch = null;
    cropViewport.dataset.dragging = cropPointers.size > 0 ? 'true' : 'false';
  });
  root.querySelectorAll('input[name="mainImageOutput"]').forEach(input => input.addEventListener('change', updateOutput));
  byId('mainImageThreshold').addEventListener('input', event => {
    byId('mainImageThresholdValue').textContent = event.currentTarget.value;
    if (sourceImage) processFrame();
  });
  for (const card of cards) {
    const select = () => {
      const radio = root.querySelector(`input[name="mainImageOutput"][value="${card.dataset.mode}"]`);
      radio.checked = true;
      updateOutput();
    };
    card.addEventListener('click', select);
    card.addEventListener('keydown', event => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        select();
      }
    });
  }
  byId('mainImageSend').addEventListener('click', () => sendCurrentFrame().catch(() => {}));
  byId('mainImageDownload').addEventListener('click', () => {
    if (!packedFrame) return;
    const url = URL.createObjectURL(new Blob([packedFrame], { type: 'application/octet-stream' }));
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = `${sourceName}-${selectedValue('mainImageOutput')}-${currentPlan?.rotation ?? 0}deg-122x250-1bit.bin`;
    anchor.click();
    URL.revokeObjectURL(url);
  });
  byId('mainImageCopy').addEventListener('click', async () => {
    if (!packedFrame) return;
    try {
      await navigator.clipboard.writeText(formatHexDump(packedFrame));
      setUserStatus('Đã copy dữ liệu ảnh.', 'success');
    } catch {
      setUserStatus('Trình duyệt không cho phép copy tự động.', 'error');
    }
  });
  session.subscribeState(renderSession);
  cropContext.fillStyle = '#fff';
  cropContext.fillRect(0, 0, FRAME_WIDTH, FRAME_HEIGHT);
  syncManualCropControls();
  updateManualCropVisibility();
  updateSelectedCards();
  renderSession(session.getSnapshot());
  updateControls();
}

function bootstrapMainImageTab() {
  const root = document.getElementById('imageEinkView');
  const nav = document.getElementById('mainAppTabs');
  const session = window.EINK_SHARED_BLE;
  if (!root || !nav || !session) return;
  const buttons = [...nav.querySelectorAll('[data-app-tab]')];
  const getClockPanels = () => [...document.querySelectorAll('[data-app-view="clock"]')];
  const select = name => {
    const selected = applyMainTabSelection(name, buttons, getClockPanels(), root);
    requestAnimationFrame(() => {
      document.documentElement.dataset.einkNoOverflow = String(document.documentElement.scrollWidth <= window.innerWidth);
    });
    return selected;
  };
  for (const button of buttons) button.addEventListener('click', () => select(button.dataset.appTab));
  mountImageUploadTab(root, session);
  select(new URLSearchParams(location.search).get('tab') === 'image' ? 'image' : 'clock');
  window.__EINK_MAIN_TABS = Object.freeze({
    select,
    buttons,
    get clockPanels() { return getClockPanels(); },
    imagePanel: root
  });
}

if (typeof document !== 'undefined') bootstrapMainImageTab();
