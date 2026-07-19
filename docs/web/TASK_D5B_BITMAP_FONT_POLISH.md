# TASK D5B - Bitmap Font Polish

## Scope

- Canonical implementation: `web/clock-app/hl24a-canvas-e5.html`
- Canonical web: `https://onlysky17.github.io/Clock/test.html`
- Smoke: `scripts/task-d5b-bitmap-font-polish-smoke.mjs`
- Applies only to the `Mặt lịch hằng ngày` preset renderer.
- No firmware change.
- No BLE protocol change.
- No scheduler, SPI, SDK, or geometry change.

## Visual Change

D5A used browser canvas fonts for the flagship daily calendar. D5B replaces the flagship preset text drawing with local bitmap rendering:

- `HH:mm` uses custom block/pixel digits.
- Solar date, `AL dd/mm`, month title, weekday labels, and month numbers use a local 5x7 bitmap font.
- Rendering uses integer coordinates and integer scale.
- `ctx.imageSmoothingEnabled = false` is set while rendering the preset.
- The preset no longer depends on `Arial`, `system-ui`, anti-aliased text, color, or grayscale.
- The `Hôm nay` text label is removed; the inverted current-day cell is the highlight.

## Layout Guards

- Logical canvas: `250 x 122`.
- Controller RAM: `122 x 250`.
- Stride: `16`.
- Payload: `4000` bytes.
- Current day is inverted with cell padding.
- E5/E6 flow is unchanged.
- The page does not auto-send BLE and does not auto-refresh the display.

## Validation

Run:

`node .\scripts\task-d5b-bitmap-font-polish-smoke.mjs`

Expected:

`TASK D5B bitmap font polish smoke PASS`

Automated browser evidence must be stored under:

`D:\EINK\Clock\_incoming\D5B_BITMAP_FONT_PROOF`

Owner BLE/e-ink physical validation remains a post-deploy phone test.
