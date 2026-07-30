# TASK D20B - Simplify Product Mode Daily Controls

## Owner-visible result

Product Mode now keeps one primary action near the top:

`Cập nhật màn hình hôm nay`

That action preserves the existing daily sequence:

1. Read weather when available.
2. Synchronize device time.
3. Apply the daily-summary face and render the panel once.

Weather remains optional. A weather failure does not prevent time sync and
device rendering.

## Visible Product Mode

The main screen keeps:

- BLE connect and disconnect.
- Current device and update status.
- One daily-update action.
- Clock-face selection.
- The daily weather panel when the daily-summary face is selected.

The following remain available under `Kỹ thuật / Nâng cao`:

- Detailed update progress.
- Display preferences.
- Device identity and battery details.
- Framebuffer preview.
- Manual D2, E5, and E6 engineering controls.

The advanced section is closed by default.

## Compatibility

- Canonical URL remains `https://onlysky17.github.io/Clock/test.html`.
- BLE UUIDs, commands, and packet formats are unchanged.
- `test.html` is unchanged.
- Firmware, SDK, BIN, pack, and physical-device behavior are unchanged.
- Google Calendar is not part of the daily update flow.

## Validation

- `node scripts/task-d20b-simplify-product-mode-smoke.mjs`
- `git diff --check`
- Desktop and 360 px mobile browser checks
- EINK AUTO PREFLIGHT

D20B is a web-only usability change and does not require firmware rebuild or
Owner physical-device testing.
