# TASK D11A - Clock Face Profile Design

## Goal

Define a small, persistent clock-face selector so the product can support multiple layouts without duplicating the calendar engine, framebuffer, EPD worker, fonts, or refresh scheduler.

D11A is design-only. It does not change firmware, web behavior, BLE packets, SPI contents, or the physical display.

## Fixed Foundation

- Canonical geometry remains logical `250 x 122`, controller RAM `122 x 250`, stride `16`, framebuffer `4000` bytes.
- Profile `0` is the current D9/D10 monthly-calendar face and is always the fallback.
- D2 immediate render, first-refresh prime recovery, EPD async wait/cleanup, and the disconnected five-minute scheduler remain unchanged.
- D10B battery telemetry remains independent on `FF00 / FF02`.
- E4, E5, and E6 command families remain unchanged.
- No second framebuffer, dynamic allocation, new font, new lunar table, or new EPD worker.
- The rejected D11A-1 legacy visual trim must not be reintroduced.

## Opcode Audit

Current D2 requests are:

- `D2 00`: SET_TIME.
- `D2 01`: GET_TIME_STATUS.
- `D2 02`: RENDER_CLOCK_NOW.
- `D2 03`: GET_IDENTITY.

Current D2 notifications are `D2 81`, `D2 82`, and `D2 83`. Requests `D2 04` and `D2 05`, plus notification `D2 84`, have no active D2 conflict. E5 response byte `84` is on a different command family and characteristic path, so it is not a conflict.

## Proposed Protocol

### SET_CLOCK_PROFILE

Exact request, 3 bytes:

| Offset | Value |
| --- | --- |
| 0 | `D2` |
| 1 | `04` |
| 2 | profile ID |

Accepted profile IDs:

- `00`: monthly calendar, current physical-PASS face.
- `01`: large time with compact solar/lunar rows.
- `02`: reserved for the later balanced alternate face; D11B must reject it until implemented.

SET does not call EPD directly and does not automatically claim render COMPLETE. After a successful profile status, Product Mode sends the existing `D2 02` render request. This keeps selection and physical refresh as separate, observable operations.

SET requirements:

- BLE connected.
- D2 time initialized; otherwise result is NOT_INITIALIZED.
- E5, E6, D2 render, and EPD wait are idle; otherwise result is BUSY.
- Unknown or not-yet-implemented profile returns INVALID_PROFILE and does not change RAM or SPI.

### GET_CLOCK_PROFILE

Exact request, 2 bytes:

| Offset | Value |
| --- | --- |
| 0 | `D2` |
| 1 | `05` |

GET is allowed before SET_TIME so Product Mode can display the boot-selected profile.

### PROFILE_STATUS

Both SET and GET notify the same exact 6-byte status:

| Offset | Field |
| --- | --- |
| 0 | `D2` |
| 1 | `84` |
| 2 | result |
| 3 | active profile ID |
| 4 | persisted profile ID, or `FF` when not persisted |
| 5 | status flags |

Result values reuse existing D2 results:

- `00`: OK.
- `01`: INVALID_LENGTH.
- `04`: NOT_INITIALIZED.
- `05`: INTERNAL_ERROR.
- `06`: BUSY.
- `07`: INVALID_PROFILE, new only for the D2 profile handler.

Status flags:

- bit 0 `PERSISTED`: byte 4 is valid.
- bit 1 `DEFAULTED`: stored value was absent, `FF`, unsupported, or invalid and profile `0` is active.
- bits 2..7 reserved and zero.

Malformed SET must not change the active or persisted profile. Unknown D2 responses are logged by web without affecting D2 time, identity, E5, or E6 parsing.

## Persistence Compatibility

The existing D3D journal record is 32 bytes with CRC over bytes `0..29` and CRC at `30..31`.

Current used bytes:

- `0..3`: magic.
- `4`: version.
- `5`: time flags.
- `6..7`: timezone.
- `8..11`: sequence.
- `12..15`: epoch.
- `16..29`: currently written as `FF` and covered by CRC.
- `30..31`: CRC16.

D11B may allocate byte `16` as profile ID while keeping record size, slots, sector, and version unchanged:

- Old valid record with byte `16 = FF`: profile `0`, DEFAULTED.
- New record with byte `16 = 00` or `01`: restore that profile.
- Other values: profile `0`, DEFAULTED; time metadata remains valid.

The profile is written only on a successful explicit SET_CLOCK_PROFILE and on later SET_TIME journal writes. It is never written per minute or per refresh.

To avoid creating a time-less persistence record, SET_CLOCK_PROFILE requires initialized D2 time. A cold device without valid time may GET the default profile but must SET_TIME before changing and persisting a profile.

## Renderer Architecture

D11B adds one retained byte `hink_clock_profile` and a dispatcher inside the existing framebuffer build path:

1. Derive current local time, solar date, weekday, and lunar date once.
2. Clear the existing `fb_bw` once.
3. Dispatch to profile `0` or profile `1` drawing code.
4. Return to the unchanged first-refresh prime and D2/E6 asynchronous EPD worker.
5. COMPLETE remains emitted only by the existing EPD wait completion path.

Profile renderers may reuse:

- `hink_d7a_pixel`.
- `hink_d7a_box`.
- `hink_d7a_digit`.
- `hink_d7a_draw_hhmm` or a parameterized variant.
- `hink_d7a_draw_day`.
- existing `draw_text` glyphs.
- existing solar/lunar conversion.

They must not call `epd_hw_open`, `epd_init`, `epd_screen_update`, `epd_update`, `epd_wait_timer`, or any BLE notify function.

## D11B First Face

Profile `1`, LARGE_TIME:

- Large centered `HH:mm` as the first visual signal.
- Compact Vietnamese weekday plus solar `dd/MM/yyyy`.
- Compact bold `AL dd/MM` using existing primitives.
- No monthly grid.
- White background and black content.
- Same first-refresh and five-minute policy as profile `0`.

Profile `0` must remain pixel-for-pixel unchanged.

## Web Flow

Product Mode adds a compact clock-face selector outside Advanced:

1. Connect and GET profile.
2. If time is not initialized, keep the selector readable but require time sync before Apply.
3. Apply sends SET_CLOCK_PROFILE.
4. After `D2 84 OK`, send existing `D2 02` once.
5. Show success only after existing `D2 82 COMPLETE`.
6. On error, keep the previous profile selected and show the real error.

No auto-connect, no E5 transfer, and no hidden render on page load.

## Size And RAM Gate

- Baseline raw BIN: `48012` bytes.
- D11B profile protocol, persistence byte, web-independent firmware state, and LARGE_TIME renderer: conservative net increase at most `1600` raw bytes.
- D11B target raw BIN: at most `50000` bytes.
- D11 after two implemented faces: at most `52000` bytes.
- Packer limit: `65528` bytes.
- RAM increase: at most `8` bytes.
- Required permanent headroom after D11B: at least `15528` bytes.

## Validation Gates For D11B

- Profile `0` physical rendering remains unchanged.
- Profile `1` immediate D2 render appears after the existing prime behavior.
- Five-minute disconnected refresh works for both profiles.
- Power cycle restores the selected profile but time remains STALE/UNSET until SET_TIME.
- Invalid profile and malformed packets do not change state.
- BLE identity, battery telemetry, reconnect, E5, and E6 remain functional.
- No white first render, duplicate refresh, or second black refresh.
- Keil `0 errors`, `0 warnings`, raw BIN at most `50000` bytes.

## Next Action

`TASK D11B - IMPLEMENT LARGE-TIME CLOCK PROFILE`

Implement only profile `1`, the profile command/status, backward-compatible byte-16 persistence, and the Product Mode selector. Profile `2` remains rejected until a later task.
