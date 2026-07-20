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

## TASK D6B-FIX1 - Device-State Mapping

Status: implemented for web-only validation.

Root cause:

- Product Mode previously derived the user-facing device state from low-level DOM text/class fields such as E5 result, E6 result, and D2 status class.
- That made technical fields that were unused, stale, or not yet run look like an overall product error.
- `E5/E6 NOT RUN`, `-`, and D2 `RENDERING` are not product errors.

Fixed user-facing mapping:

- BLE disconnected: `Chưa kết nối`.
- BLE connected without valid device time: `Cần đồng bộ giờ`.
- D2 result `OK` with state `SYNCED`, `ACCEPTED`, `RENDERING`, or `COMPLETE`: `Đang chạy`.
- `Có lỗi` is reserved for real failures:
  - BLE transport exception.
  - Protocol rejection.
  - Malformed response.
  - Explicit D2 error result/state.
  - E5/E6 operation that actually ran and returned an error.

Non-errors:

- E5/E6 `NOT RUN`.
- Code/state `-`.
- Advanced operation not used yet.
- Technical fields without data.
- Normal BLE disconnect.
- D2 `RENDERING`.

Recovery:

- A successful D2 sync/render clears previous Product Mode error state.
- A stale sticky error must not remain after `OK/SYNCED/COMPLETE`.

Automated proof path:

`D:\EINK\Clock\_incoming\D6B_FIX1_STATE_MAPPING_PROOF`

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

For FIX1 state mapping, run:

`node .\scripts\task-d6b-fix1-device-state-mapping-smoke.mjs`

Expected:

`TASK D6B web product mode smoke PASS`

Automated browser evidence should be stored under:

`D:\EINK\Clock\_incoming\D6B_WEB_PRODUCT_MODE_PROOF`

FIX1 browser evidence is stored under:

`D:\EINK\Clock\_incoming\D6B_FIX1_STATE_MAPPING_PROOF`
