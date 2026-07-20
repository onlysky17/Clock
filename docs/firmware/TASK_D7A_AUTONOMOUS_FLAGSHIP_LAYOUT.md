# TASK D7A - Autonomous Flagship Daily Layout

## Scope

- Port the web-approved `Mặt lịch hằng ngày` concept into the autonomous firmware renderer.
- Firmware renders directly from D2 RAM time after SET_TIME and from the existing five-minute scheduler.
- No E5/E6 framebuffer upload is required for the autonomous clock face.
- Web, `test.html`, BLE protocol, SPI persistence sector, scheduler policy, geometry, and framebuffer size are unchanged.

## Layout MVP

- Left pane:
  - Solar date: `T2 20/07/2026`.
  - Large HH:mm.
  - Lunar date: `ÂL 07/06`.
- Right pane:
  - Month title: `THÁNG 7/2026`.
  - Seven-column month calendar.
  - Current day highlighted with an inverted cell.
- A vertical divider separates the panes.
- The renderer uses compact bitmap primitives only.
- Legacy font headers/symbols are not restored.

## Calendar Logic

- Month length is derived by `hink_d3c_solar_mdays()`.
- Leap years use the existing D3C solar leap helper.
- The first-day offset is derived from the current weekday and day-of-month.
- Calendar columns are Monday-first: `T2 T3 T4 T5 T6 T7 CN`.
- Days outside the month are not drawn.
- The current day is rendered as a black cell with white digits.

## Required Fixtures

- `20/07/2026 08:35`, lunar `07/06`.
- `01/08/2026 07:05`.
- `31/08/2026 23:58`.
- `29/02/2028 12:52`.

## Guards

- D2 SET_TIME/status lifecycle remains unchanged.
- D3E/D3D scheduler and persistence remain present.
- E5/E6 command IDs and validation remain unchanged.
- Framebuffer remains `4000` bytes.
- Panel geometry and polarity remain unchanged.
- No dynamic allocation.
- No floating point.
- No `sprintf()` in the D7A render path.

## Validation

Run:

`node .\scripts\task-d7a-autonomous-flagship-layout-smoke.mjs`

Expected:

`TASK D7A autonomous flagship layout smoke PASS`

Visual proof is generated under:

`D:\EINK\Clock\_incoming\D7A_AUTONOMOUS_FLAGSHIP_PROOF`

Keil gate before commit:

- `0 errors`.
- `0 warnings`.
- Code/RO/RW/ZI captured.
- Raw BIN captured.
- Raw BIN `<= 58000` bytes.
- Headroom `>= 7528` bytes.
- Map/font audit confirms legacy fonts remain gone from the active renderer path.

## Build Evidence

- Keil target: `DA14585`.
- Project: `D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\ble_app_peripheral.uvprojx`.
- Result: `0 Error(s), 0 Warning(s)`.
- Code `41932`.
- RO-data `3592`.
- RW-data `552`.
- ZI-data `22928`.
- Raw BIN `47212` bytes.
- D7A size headroom `10788` bytes against the `58000` byte limit.
- Packer headroom `18316` bytes against the `65528` byte limit.
- Legacy font map/symdef scan for `sfont`, `sfont16`, `font50`, and `font66`: no active symbols found.
