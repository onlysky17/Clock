# TASK D13B - Daily Briefing Profile

## Status

`IMPLEMENTED - KEIL PASS - AWAITING OWNER PHYSICAL GATE`

D13B implements the D13A daily-context protocol and adds clock profile `02`.
The feature is bounded, RAM-only, and reuses the existing autonomous render and
EPD completion pipeline.

## Protocol

- SET daily context: `D2 08`, exact 20 bytes.
- GET daily context: `D2 09`, exact 2 bytes.
- Status: `D2 88`, exact 20 bytes.
- Result `09`: `INVALID_DAILY_DATA`.
- State values: `UNSET`, `FRESH`, and `EXPIRED` in status byte 3 bits 0..1.
- Status byte 3 bit 2 reports weather validity and bit 3 reports agenda validity.

Firmware validates schema, reserved flags, local day key, weather range,
temperature, precipitation, agenda count, ordering, and the three-byte ASCII
labels before changing RAM state. Malformed requests preserve the prior context.

## RAM And Freshness

Daily context stores one weather summary and at most two agenda entries in less
than 32 bytes of retention RAM. It is not written to SPI or NVDS.

- Cold boot: `UNSET`.
- BLE disconnect: context remains available in RAM.
- Local day rollover or a SET_TIME day/timezone change: `EXPIRED` when the stored
  day key no longer matches.
- Expired data remains queryable but is hidden from the renderer.
- A valid SET atomically replaces the complete context and returns `FRESH`.

The existing D3D A/B journal, sector `0x3B000`, and bytes 19..29 remain
unchanged.

## Profile 02 Layout

`DAILY_BRIEFING` uses the existing 4000-byte framebuffer:

- left pane: local solar date, compact `HH:mm`, lunar date, optional AM/PM;
- right pane: compact weather token and temperature, precipitation (`POP`), and
  up to two `HH:mm XXX` agenda rows;
- invalid, unset, or expired sections are not drawn.

The renderer reuses the linked 5x7 glyphs, D7A seven-segment digits, lunar
conversion, framebuffer clear, autonomous scheduler, full EPD update, wait, and
completion paths. No font, icon, framebuffer, timer, allocation, or EPD sequence
is added.

Profiles `00` (monthly) and `01` (large time) are unchanged. Profile `02` uses
the existing CRC-covered profile byte 16 for persistence; the daily payload
itself remains RAM-only.

## Product Mode

Product Mode adds a third face and bounded manual controls for:

- optional weather code, temperature `-40..80 C`, precipitation `0..100`;
- zero, one, or two agenda entries;
- agenda labels restricted to one to three uppercase ASCII letters/digits.

Apply sends daily context first, then uses the existing profile SET and D2 render
flow. `BUSY` waits for physical render completion and retries once. The web does
not auto-connect, call an external weather API, invent values, or treat browser
storage as device truth.

## Gates

- Canonical URL remains `https://onlysky17.github.io/Clock/test.html`.
- Geometry remains logical `250 x 122`, RAM `122 x 250`, stride `16`, payload
  `4000` bytes.
- Raw BIN must be at most `51500` bytes and below packer limit `65528`.
- Keil must report zero errors and zero warnings.
- Owner SysRAM test must cover immediate render, daily context, day expiry,
  profile persistence, five-minute scheduler, BLE reconnect, and no blank,
  duplicate, or second-black refresh.

## Build Evidence

- Target: `DA14585`, ARMCLANG `6.24`.
- Code `44960`, RO-data `3612`, RW-data `552`, ZI-data `22956`.
- Raw BIN `50260` bytes; packer headroom `15268` bytes.
- Raw BIN SHA256:
  `8426901920A63EDB4BEEE02E2824B33AF06998C5FB6AA7991E7F8C7B2A429896`.
- Keil: `0 Error(s), 0 Warning(s)`.
- Legacy font symbols remain absent.
