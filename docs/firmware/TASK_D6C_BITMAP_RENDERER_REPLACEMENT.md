# TASK D6C - Compact Bitmap Renderer Replacement Proof

## Scope

- Replace the active device-side clock render path with a compact bitmap renderer.
- Prove only the autonomous HH:mm clock face can render through firmware bitmap primitives.
- Do not port the mini calendar, lunar calendar layout, or full flagship web layout in D6C.
- Do not add a second runtime renderer path.
- Do not change BLE protocol, SPI persistence sector, scheduler policy, E5/E6 flow, or EPD geometry.

## Baseline

- Firmware baseline commit: `08447bf3d142cd9aa1c1314a5beb58559f46659c`
- Code: `41628`
- RO: `21624`
- RW: `608`
- ZI: `22928`
- Raw BIN: `64996`
- Raw limit: `65528`
- Headroom: `532`

## Implementation Notes

- `epd_gui.c` now provides compact fixed bitmap primitives:
  - 5x7 glyph table for digits, colon, slash, dash, letters, and fallback.
  - Bounds-checked glyph/text drawing.
  - Seven-segment-style large HH:mm digits.
  - Integer-only coordinates and dimensions.
- Active D2/D3E render now calls `hink_bitmap_draw_clock()`.
- The D2/D3E render path no longer uses `select_font()`, `draw_text()` with the legacy selected font, or `sprintf()` for HH:mm/date/AL strings.
- Legacy font headers `sfont.h`, `sfont16.h`, `font50.h`, and `font66.h` are no longer included by the active EPD GUI link path.

## Preserved Behavior

- D2 SET_TIME/status lifecycle preserved.
- D3E auto scheduler and 5-minute policy preserved.
- D3D2 persistence/stale policy preserved.
- E5/E6 framebuffer transfer and refresh flow preserved.
- EPD frame geometry preserved:
  - logical/controller framebuffer bytes: `4000`
  - `EPD_FRAME_WIDTH 122`
  - `EPD_FRAME_HEIGHT 250`
  - `EPD_FRAME_STRIDE 16`
- No BLE command or protocol change.
- No SPI sector change.

## Automated Static/Host Proof

Smoke:

`node .\scripts\task-d6c-bitmap-renderer-replacement-smoke.mjs`

Expected:

`TASK D6C bitmap renderer replacement smoke PASS`

Evidence generated under:

`D:\EINK\Clock\_incoming\D6C_BITMAP_RENDERER_PROOF`

Fixtures:

- `00:00`
- `08:08`
- `12:52`
- `23:59`

The smoke checks compact glyph primitives, framebuffer bounds, deterministic output, 4000-byte payload geometry, D2/D3E scheduler/persistence symbols, unchanged E5/E6 command IDs, and no active legacy font link references.

## Build Gate

Keil CLI is not used for D6C.

Before commit, Keil GUI build evidence must prove:

- 0 errors.
- 0 warnings.
- Code/RO/RW/ZI captured.
- Raw BIN size captured.
- Raw BIN `<= 63480` bytes.
- Headroom `>= 2048` bytes.
- Map/font-link audit confirms legacy font symbols are gone or reduced from the active link path.

If Keil GUI cannot be automated, D6C must stop before commit with:

`BLOCKED: KEIL GUI BUILD REQUIRED`
