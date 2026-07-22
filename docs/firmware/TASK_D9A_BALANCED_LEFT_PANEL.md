# TASK D9A - Balanced Left Clock Panel

## Goal

Balance the left side of the 250 x 122 flagship layout without changing the monthly calendar pane.

Owner evidence showed that the large `HH:mm` block was visually high while the small `ÂL dd/MM` row sat at the bottom with a large empty gap between them.

## Layout Change

- Solar weekday/date remains at `y=8`.
- `HH:mm` moves from `(6,32)` to `(10,38)` so its 80-pixel bitmap is centered in the 101-pixel left pane.
- Lunar row moves from small text at `(4,104)` to a medium bitmap row at `(11,88)`.
- `ÂL` uses a 17 x 12 bitmap label.
- The circumflex uses the same two-pixel visual weight as the label.
- Lunar `dd/MM` uses the already-linked seven-segment primitive at 8 x 12 pixels with a two-pixel stroke matching the label and slash.
- Divider and the complete right monthly-calendar pane are unchanged.

## Preserved Behavior

- Same 250 x 122 logical framebuffer and 4000-byte payload.
- Same solar/lunar calculations.
- Same D2D render, EPD prime recovery, five-minute scheduler, persistence, BLE reconnect, and D8A identity protocol.
- No font table, framebuffer, malloc, web, or protocol change.

## Gate

The Owner SysRAM physical test passed on 2026-07-22:

- The left pane is vertically balanced.
- `HH:mm` remains clear and centered.
- The complete `ÂL dd/MM` row uses a consistent two-pixel visual weight, including the circumflex and slash.
- The right calendar pane remains unchanged.

Final build evidence: Code 42644, RO-data 3592, RW-data 552, ZI-data 22928, raw BIN 47924 bytes, 0 errors, and 0 warnings. The tested raw BIN SHA256 is `287A7AC5D4CEE94172F17084FED56935801CBB91E67F3B011834D9E5DFAF43AF`.
