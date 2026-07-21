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

The default page is organized for Owner day-to-day use:

- A visible `D7A TEST BASELINE` marker appears near the top of Product Mode, before technical/advanced controls.
- The marker states expected firmware `D7A final / 32fa562d`, expected BIN marker `14CF053B`, and web build `D7A-WEB1-20260720`.
- The marker is a cache/test identity hint only. It does not claim the firmware running in the chip has been verified, because the current BLE protocol has no firmware version command.
- Connect and disconnect are visible at the top.
- A simple state panel shows `Dang chay`, `Can dong bo gio`, `Chua ket noi`, or `Co loi`.
- `Dong bo gio` is visible for explicit user-triggered D2 time sync.
- `Mat lich hang ngay` remains the highlighted preset.
- The 250 x 122 preview is visible without opening technical sections.
- `Gui len man` is visible for the existing user-triggered E5/E6 send flow.
- Progress and user-facing errors remain visible through the existing status fields.

## TASK D6B-FIX1 - Device-State Mapping

Status: implemented for web-only validation.

Root cause:

- Product Mode previously derived the user-facing device state from low-level DOM text/class fields such as E5 result, E6 result, and D2 status class.
- That made technical fields that were unused, stale, or not yet run look like an overall product error.
- `E5/E6 NOT RUN`, `-`, and D2 `RENDERING` are not product errors.

Fixed user-facing mapping:

- BLE disconnected: `Chua ket noi`.
- BLE connected without valid device time: `Can dong bo gio`.
- D2 result `OK` with state `SYNCED`, `ACCEPTED`, `RENDERING`, or `COMPLETE`: `Dang chay`.
- `Co loi` is reserved for real failures:
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

## TASK D7A-WEB1 - Visible Test Identity

Status: implemented for web-only validation.

Canonical web remains:

`https://onlysky17.github.io/Clock/test.html`

Canonical implementation remains:

`web/clock-app/hl24a-canvas-e5.html`

Visible identity values:

- Label: `D7A TEST BASELINE`.
- Expected firmware: `D7A final / 32fa562d`.
- Expected BIN: `14CF053B`.
- Web build: `D7A-WEB1-20260720`.
- Disclaimer: `Thông tin trên là baseline dự kiến, không phải xác minh firmware trong thiết bị.`

Stable DOM markers:

- `data-eink-web-build="D7A-WEB1-20260720"`.
- `data-expected-firmware="32fa562d"`.
- `data-expected-bin="14CF053B"`.
- `window.EINK_TEST_IDENTITY`.

Guards:

- No BLE protocol, command ID, UUID, D2/E5/E6 packet, firmware, SDK, or scheduler change.
- No query parameter is required for the canonical URL.
- Marker is rendered from current source and is not loaded from `localStorage`.
- Reloading the page keeps the same visible marker.
- The marker does not overwrite BLE, D2, E5, E6, or Product Mode status state.
- Browser proof path: `D:\EINK\Clock\_incoming\D7A_WEB1_IDENTITY_PROOF`.

## Advanced Mode

The page keeps the technical tools but moves them under a closed-by-default disclosure:

`Ky thuat / Nang cao`

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

For D7A-WEB1 visible identity, run:

`node .\scripts\task-d7a-web1-visible-test-identity-smoke.mjs`

Expected:

`TASK D6B web product mode smoke PASS`

Automated browser evidence should be stored under:

`D:\EINK\Clock\_incoming\D6B_WEB_PRODUCT_MODE_PROOF`

FIX1 browser evidence is stored under:

`D:\EINK\Clock\_incoming\D6B_FIX1_STATE_MAPPING_PROOF`

D7A-WEB1 browser evidence is stored under:

`D:\EINK\Clock\_incoming\D7A_WEB1_IDENTITY_PROOF`
