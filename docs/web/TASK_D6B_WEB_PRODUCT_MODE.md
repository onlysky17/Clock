# TASK D6B - Web Product Mode Cleanup

## Scope

- Canonical implementation: `web/clock-app/hl24a-canvas-e5.html`
- Canonical web: `https://onlysky17.github.io/Clock/test.html`
- Smoke: `scripts/task-d6b-web-product-mode-smoke.mjs`
- Web UI cleanup only.
- No firmware change.
- No BLE protocol change.
- No SDK, scheduler, SPI, or geometry change.

## Product Mode

The default page is now organized for Owner day-to-day use:

- Connect and disconnect are visible at the top.
- A simple state panel shows `Đang chạy`, `Cần đồng bộ giờ`, `Chưa kết nối`, or `Có lỗi`.
- `Đồng bộ giờ` is visible for explicit user-triggered D2 time sync.
- `Mặt lịch hằng ngày` remains the highlighted preset.
- The 250 x 122 preview is visible without opening technical sections.
- `Gửi lên màn` is visible for the existing user-triggered E5/E6 send flow.
- Progress and user-facing errors remain visible through the existing status fields.

## Advanced Mode

The page keeps the technical tools but moves them under a closed-by-default disclosure:

`Kỹ thuật / Nâng cao`

This section remains keyboard-accessible and contains the existing low-level controls and debug output:

- E4/E5/E6 controls.
- D2 raw result, state, flags, local time, timezone, and uptime.
- Payload geometry, CRC, chunk count, first bytes, transfer status, and log.
- Canvas debug tools.
- Auto-minute/debug actions.

## Guards

- Existing element IDs are preserved.
- Existing D2/E5/E6 packet builders and BLE UUIDs are unchanged.
- The page does not auto SET_TIME.
- The page does not auto-send E5/E6.
- The page does not auto-refresh the panel.
- `test.html` is not changed.
- Firmware and protocol are not changed.

## Validation

Run:

`node .\scripts\task-d6b-web-product-mode-smoke.mjs`

Expected:

`TASK D6B web product mode smoke PASS`

Automated browser evidence should be stored under:

`D:\EINK\Clock\_incoming\D6B_WEB_PRODUCT_MODE_PROOF`
