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

## Fix2 - Fixed Cell Metrics And Baselines

Owner visual review found that accented bitmap glyphs could appear vertically misaligned because `Á` and `Â` were taller than ASCII glyphs while the renderer still positioned text from a top-left origin.

Fix2 keeps the bitmap renderer and normalizes small-text metrics:

- Small glyph cell: `5 x 9`.
- Advance: `6`.
- Baseline row: `8`.
- ASCII, `Á`, `Â`, and fallback `?` all use the same cell height, advance, and baseline.
- Shorter glyphs are padded inside the fixed cell instead of changing the vertical origin.
- `drawBitmapText` now takes a baseline coordinate and returns a precise bounding box with `baselineY`, `advance`, `cellWidth`, and `cellHeight`.
- `CN dd/mm/yyyy`, `THÁNG m/yyyy`, `ÂM dd/mm`, weekday labels, and month numbers each render on a single stable baseline.
- The weekday underline sits below the weekday glyph boxes and does not cross text.

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

Automated browser evidence for Fix2 must be stored under:

`D:\EINK\Clock\_incoming\D5B_FIX2_BASELINE_PROOF`

Owner BLE/e-ink physical validation remains a post-deploy phone test.
