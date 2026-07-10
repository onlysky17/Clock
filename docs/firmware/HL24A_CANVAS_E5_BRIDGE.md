# HL24A CANVAS-TO-E5 DRY-RUN BRIDGE

## Purpose

Connect the real 296x128 landscape drawing canvas to the existing HL22A E5
session-bound transfer protocol.

HL24A is web-only:

- no firmware source change,
- no Keil build,
- no flash,
- no framebuffer storage in firmware,
- no panel RAM write,
- no EPD refresh.

## Canvas and packing

Visible canvas:

- 296 x 128 pixels, landscape.

Raw panel layout:

- width: 128 pixels,
- height: 296 pixels,
- bytes per raw row: 16,
- total: 4736 bytes.

Display-to-raw mapping:

```text
displayX = rawY
displayY = 127 - rawX
```

Packing:

- row-major in raw coordinates,
- MSB-first inside each byte,
- black pixel = bit 1,
- white pixel = bit 0.

## Transfer

The page:

1. Converts the current canvas to exactly 4736 packed bytes.
2. Calculates CRC16-CCITT-FALSE over the actual packed bytes.
3. Opens an E4 session.
4. Starts an E5 transfer using the dynamic CRC.
5. Sends 339 chunks with a maximum payload of 14 bytes.
6. Commits the transfer.
7. Verifies the completion manifest against the canvas byte count and CRC.
8. Rechecks HL20A:
   - `E2 E0 A1`
   - `E2 03 F0`
9. Closes the E4 session.

## Required firmware

Canonical HL22A source SHA256:

`0C4EA0DD9931FB9FC4D9B6EE12C2203E481A5DEB1E2A31FEB8404040252FFC84`

## Safety

The firmware only tracks:

- transfer ID,
- sequence,
- byte count,
- CRC16,
- completion state.

It does not store the 4736-byte framebuffer.

## Canonical page

`web/clock-app/hl24a-canvas-e5.html`

Stable URL:

`https://onlysky17.github.io/Clock/test.html`
