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
- Solar date, `ÂM dd/mm`, month title, weekday labels, and month numbers use local bitmap glyphs.
- Rendering uses integer coordinates and integer scale.
- `ctx.imageSmoothingEnabled = false` is set while rendering the preset.
- The preset no longer depends on `Arial`, `system-ui`, anti-aliased text, color, or grayscale.
- The `Hôm nay` text label is removed; the inverted current-day cell is the highlight.

## Fix1 - Vietnamese Glyphs And Left Pane Bounds

Owner physical review found that the solar date could overflow into the divider area, and the first bitmap font pass did not support Vietnamese accented labels.

Fix1 keeps the bitmap renderer and changes only the web preset renderer:

- Adds local bitmap glyphs for `Á` and `Â`.
- Keeps a visible `?` fallback glyph for unsupported characters instead of silently dropping or mis-rendering them.
- Restores accented labels: `THÁNG` and `ÂM`.
- Draws the solar date `CN dd/mm/yyyy` at compact bitmap scale so its ink stays fully inside the left pane.
- Records layout bounds for automated checks of the solar date, month title, divider, calendar, and payload.

## Layout Guards

- Logical canvas: `250 x 122`.
- Controller RAM: `122 x 250`.
- Stride: `16`.
- Payload: `4000` bytes.
- Solar date stays before the vertical divider.
- Month title `THÁNG m/yyyy` stays in the right pane.
- Current day is inverted with cell padding.
- E5/E6 flow is unchanged.
- The page does not auto-send BLE and does not auto-refresh the display.

## Validation

Run:

`node .\scripts\task-d5b-bitmap-font-polish-smoke.mjs`

Expected:

`TASK D5B bitmap font polish smoke PASS`

Automated browser evidence for Fix1 must be stored under:

`D:\EINK\Clock\_incoming\D5B_FIX1_VIETNAMESE_LAYOUT_PROOF`

Owner BLE/e-ink physical validation remains a post-deploy phone test.
