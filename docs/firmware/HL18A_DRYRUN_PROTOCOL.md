# HL18A — BLE Framebuffer Dry-run Protocol

Scope: HINK213 2.13 inch only.

HL18A tests BLE transport for the packed 2.13 framebuffer payload without touching the real EPD panel. It is safe for the current broken panel/FPC because the protocol is ACK-only and must not call any refresh path.

## Hard safety rules

- Do not push `.bin` firmware images to public GitHub.
- Do not use `web/clock-app/eink-dev.html`.
- Do not implement 4.2 / 5.83 / 7.5 panel drivers.
- Do not call real EPD refresh from HL18A commands.
- Do not call framebuffer write-to-panel functions from HL18A commands.
- Keep forbidden refresh commands locked: `E2 03`, `E2 04`, `E2 30`, `E2 31`, `E2 50`.

## Framebuffer constants

- Raw width: `128`
- Raw height: `296`
- X bytes: `16`
- Total payload: `4736` bytes
- Packing: MSB-first within each byte, `16` bytes per row, `296` rows.

## Command family

HL18A uses `E3` only.

### Metadata

```text
E3 00 widthLo widthHi heightLo heightHi xBytes totalLo totalHi
```

Expected HINK213 packet:

```text
E3 00 80 00 28 01 10 80 12
```

ACK:

```text
E3 80 status
```

### Chunk

```text
E3 01 seqLo seqHi len xor data...
```

Notes:

- `len` is the number of data bytes in this packet.
- Recommended maximum data bytes per packet: `14`, so the whole BLE write remains <= 20 bytes.
- `xor` is XOR of the data bytes only.
- Firmware updates dry-run counters only.

ACK:

```text
E3 81 status
```

### Status byte

```text
E3 02 page
```

Suggested pages:

- `00`: chunks low byte
- `01`: chunks high byte
- `02`: bytes low byte
- `03`: bytes high byte
- `04`: running XOR byte
- `05`: metadata accepted flag

ACK:

```text
E3 82 value
```

### Reset dry-run counters

```text
E3 03
```

ACK:

```text
E3 83 00
```

## Status codes

- `00` OK
- `01` invalid size
- `02` invalid checksum
- `03` sequence error
- `04` busy/locked
- `05` unsupported

## Firmware implementation note

The E3 handler must return before any legacy E2/display branch. It should only update small counters and notify 3-byte ACKs. It must not touch `epd_buffer`, `display()`, or any `EPD_2IN13_V2_*Display*` / `*TurnOnDisplay*` function.
