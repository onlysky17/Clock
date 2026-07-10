# HL24A CANVAS-TO-E5 DRY-RUN VALIDATION — 2026-07-10

## Overall result

Status: PASS END-TO-END

Scope:

- DA14585 HINK213 2.13-inch target only.
- Existing HL22A firmware.
- Web-only validation.
- Old test board only.
- No firmware source change.
- No Keil build or flash.
- No framebuffer storage in firmware.
- No panel RAM write and no EPD refresh.

## Canvas and packing

Visible canvas:

- 296 x 128 pixels, landscape.

Raw panel geometry:

- 128 x 296 pixels.
- 16 bytes per raw row.
- 4736 packed bytes total.
- 339 BLE chunks at 14-byte maximum payload.

Mapping:

`displayX = rawY`

`displayY = 127 - rawX`

Packing:

- raw row-major,
- MSB-first,
- black pixel = bit 1,
- white pixel = bit 0.

## Runtime validation

The current canvas was:

1. packed into exactly 4736 bytes,
2. assigned a dynamic CRC16-CCITT-FALSE,
3. transferred through the E4 session and E5 integrity protocol,
4. committed and verified against the returned completion manifest.

Observed final requirements:

- Manifest state: `02` COMPLETE
- Manifest chunks: `339`
- Manifest bytes: `4736`
- Manifest CRC: matched the dynamic CRC calculated from the canvas payload
- Final result: `PASS END-TO-END`

## Safety regression

HL20A remained active:

`E2 E0 A1`

Refresh-capable command remained blocked:

`E2 03 F0`

Result: PASS

## Final safety state

- The web page now transmits actual packed canvas bytes.
- Firmware still stores only transfer metadata, counters and CRC.
- Firmware does not retain the 4736-byte framebuffer.
- No panel RAM write occurs.
- No EPD refresh occurs.
- No `.bin` is pushed.
- HMCLOCK/self-flash remains reference-only.
- New spare board remains untouched.

## Canonical page

`web/clock-app/hl24a-canvas-e5.html`

Stable URL:

`https://onlysky17.github.io/Clock/test.html`

## Next milestone

HL25A — one-shot panel liveness test on the white-screen board:

- establish reliable SWD contact at home,
- keep HL20A blocking all legacy refresh commands,
- add one narrowly scoped arm-and-fire liveness command,
- draw a fixed black/white test pattern,
- perform exactly one refresh,
- auto-lock again immediately,
- do not enable arbitrary framebuffer refresh yet.
