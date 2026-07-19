# TASK D5A - Flagship Daily Calendar Layout

## Scope

- Canonical implementation: `web/clock-app/hl24a-canvas-e5.html`
- Canonical web: `https://onlysky17.github.io/Clock/test.html`
- Smoke: `scripts/task-d5a-flagship-daily-layout-smoke.mjs`
- Web-rendered framebuffer through the existing E5/E6 flow.
- No firmware change.
- No BLE protocol change.
- No scheduler, SPI, or SDK change.

## User-Facing Layout

Preset label:

`Mặt lịch hằng ngày`

The preset renders a black-and-white daily calendar face for the HINK213 `250 x 122` canvas:

- Left block, about 58% width:
  - Vietnamese weekday and `dd/mm/yyyy`.
  - Large `HH:mm` as the strongest visual element.
  - Lunar date `Âm dd/mm`.
- Right block, about 42% width:
  - Month/year title.
  - 7-column mini month calendar.
  - Current day inverted/highlighted.
  - Short Vietnamese weekday labels.

The layout does not show fake temperature, fake battery, or unavailable device data.

## Geometry Contract

- Logical canvas: `250 x 122`.
- Controller RAM: `122 x 250`.
- Stride: `16`.
- Payload: `4000` bytes.
- Pure black/white rendering; no required information depends on color or grayscale.

## Behavior

- Preview uses the current phone/browser time when the preset runs.
- One-tap clock sync now draws the daily calendar preset before using the existing E5/E6 flow.
- The page does not auto-send BLE.
- The page does not auto-refresh the display.
- E5/E6 transfer and refresh commands are unchanged.
- Owner BLE/e-ink physical validation remains a post-deploy phone test.

## Lunar Fixture

The web lunar conversion is validated by the fixture:

`18/07/2026` solar -> `05/06` lunar.

## Validation

Run:

`node .\scripts\task-d5a-flagship-daily-layout-smoke.mjs`

Expected:

`TASK D5A flagship daily layout smoke PASS`

Automated browser validation must render desktop and mobile screenshots under:

`D:\EINK\Clock\_incoming\D5A_FLAGSHIP_LAYOUT_PROOF`
