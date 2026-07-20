# TASK D6C - Compact Bitmap Renderer Replacement Proof

## Final Status

- Status: PHYSICAL PASS, merged, and CLOSED.
- Merge commit: `2ad9dc6b228f8406741fb9046c33b2554fa6e179`.
- Implementation commit: `14d72b9f169bf7ef2e3ccbea721e638c7d073ee3`.
- PR: `#37`.
- Owner physical evidence on `20/07/2026`:
  - SysRAM load PASS.
  - D2 immediate render PASS.
  - HH:mm bitmap, colon, and clipping PASS.
  - BLE disconnect PASS.
  - Five-minute autonomous refresh PASS.
  - No duplicate refresh and no second black refresh PASS.
  - E-ink panel displayed `08:35` on `20/07/2026`.
- Post-merge gate PASS:
  - `HEAD == origin/main == 2ad9dc6b228f8406741fb9046c33b2554fa6e179`.
  - Working tree clean.
  - `tools/eink-auto-preflight.ps1` PASS.
- Legacy font symbols are gone from the active D6C renderer link path.

## Separate Finding

- Web Product Mode can show `Có lỗi` even when the D2 log reports OK/SYNCED/COMPLETE.
- This is a web status rendering/state issue and does not block D6C firmware merge or physical PASS.

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

Build evidence from the D6C company physical package:

- Keil `0 errors`.
- Keil `0 warnings`.
- Code `40804`.
- RO-data `3592`.
- RW-data `552`.
- ZI-data `22928`.
- Raw BIN `46084` bytes.
- Raw headroom `19444` bytes against the `65528` byte limit.
- SysRAM executable was used for the Owner physical gate.

The previous pre-physical blocker is closed:

`D6C PHYSICAL PASS / MERGED`
