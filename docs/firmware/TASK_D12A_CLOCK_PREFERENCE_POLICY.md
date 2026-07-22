# TASK D12A - Clock Preference Policy Design

## Status

`DESIGN COMPLETE - NO RUNTIME CHANGE`

D12A defines clock display and refresh preferences without changing firmware, web behavior, BLE packets, SPI contents, or the physical panel. D11C remains the rollback baseline.

## Fixed Foundation

- Logical panel `250 x 122`, controller RAM `122 x 250`, stride `16`, framebuffer `4000` bytes.
- Profiles remain `0` Monthly Calendar and `1` Large Time.
- D2 immediate render, first-refresh prime recovery, asynchronous EPD wait/cleanup, persistence journal, stale recovery, BLE reconnect, E5, and E6 remain unchanged.
- Default behavior remains 24-hour display and five-minute autonomous refresh.
- No new framebuffer, font, calendar table, timer, allocation, or EPD worker.

## Preference Values

### Hour mode

- `00`: 24-hour display, default.
- `01`: 12-hour display.
- Other values are invalid and must not change active or persisted preferences.

In 12-hour mode, midnight renders as `12:xx AM`, noon as `12:xx PM`, and hours 13..23 render as 1..11 PM. Both profiles show a compact `AM` or `PM` marker using the existing 5x7 glyphs. D12B must prove that the marker does not overlap the solar date, lunar row, divider, or calendar.

### Autonomous refresh cadence

- `01`: every minute.
- `05`: every five minutes, default and recommended.
- `0A`: every ten minutes.
- Other values, including zero, are invalid.

The one-minute option is an explicit high-refresh setting and Product Mode must label it as higher battery/panel activity. It is still persisted when explicitly applied. A preference write occurs once; firmware never writes SPI on each refresh.

Immediate D2 render after SET_TIME and manual D2 render are independent of cadence. Day rollover remains a forced render. Scheduled refresh is eligible when `local_minute % cadence == 0`, with the existing same-minute duplicate latch and busy coalescing preserved.

## Opcode Audit

Current D2 requests are `00` SET_TIME, `01` GET_TIME_STATUS, `02` RENDER_CLOCK_NOW, `03` GET_IDENTITY, `04` SET_CLOCK_PROFILE, and `05` GET_CLOCK_PROFILE. Current D2 notifications are `81`, `82`, `83`, and `84`.

Requests `06` and `07`, plus notification `86`, have no active D2 conflict. E6 values on a separate command family do not conflict.

## Protocol

### SET_CLOCK_PREFERENCES

Exact request, 4 bytes:

| Offset | Field |
| --- | --- |
| 0 | `D2` |
| 1 | `06` |
| 2 | hour mode (`00` or `01`) |
| 3 | refresh minutes (`01`, `05`, or `0A`) |

SET requirements:

- BLE connected.
- D2 time initialized; otherwise NOT_INITIALIZED.
- E5, E6, D2 render, and EPD wait idle; otherwise BUSY.
- Validate both fields before changing RAM or SPI.
- Persist once through the existing D3D journal and read-back verification.
- Do not render inside the BLE handler. Product Mode sends existing `D2 02` after preference status OK.

### GET_CLOCK_PREFERENCES

Exact request: `D2 07`.

GET is allowed before SET_TIME so Product Mode can show the boot-restored preference.

### PREFERENCE_STATUS

Exact 8-byte notify:

| Offset | Field |
| --- | --- |
| 0 | `D2` |
| 1 | `86` |
| 2 | result |
| 3 | active hour mode |
| 4 | active refresh minutes |
| 5 | persisted hour mode, or `FF` |
| 6 | persisted refresh minutes, or `FF` |
| 7 | flags |

Results reuse `00` OK, `01` INVALID_LENGTH, `04` NOT_INITIALIZED, `05` INTERNAL_ERROR, and `06` BUSY. New result `08` means INVALID_PREFERENCE. Flags use bit 0 PERSISTED and bit 1 DEFAULTED; bits 2..7 are zero.

Malformed or rejected requests return status but preserve all active scheduler, renderer, and persistence state.

## Persistence Compatibility

The D3D record remains 32 bytes with CRC over bytes `0..29` and CRC at `30..31`:

- `0..15`: existing time metadata.
- `16`: existing clock profile.
- `17`: hour mode.
- `18`: refresh minutes.
- `19..29`: reserved `FF`.
- `30..31`: existing CRC16.

Backward compatibility is field-by-field:

- Old `FF` hour mode defaults to `00` (24-hour).
- Old `FF` cadence defaults to `05` (five minutes).
- Invalid stored preference fields default independently without invalidating valid time/profile metadata.
- A successful SET_TIME preserves the active restored preferences in subsequent journal records.
- No record-size, slot, sector, magic, version, erase, CRC, or wear-policy change.

## Scheduler Transition

After successful SET_CLOCK_PREFERENCES:

1. Store active values and verify the journal write.
2. Keep the current minute as seen; clear no valid render already in progress.
3. Product Mode requests one manual D2 render, which updates the existing last-rendered minute latch.
4. The next new minute is evaluated using the new cadence.
5. Busy minutes continue to coalesce to only the latest eligible minute.

Changing cadence must not create an immediate duplicate, cancel the dedicated minute timer, or disable scheduling after BLE disconnect.

## Web Policy

Product Mode adds compact controls near the profile selector:

- 24 giờ / 12 giờ segmented control.
- 5 phút / 10 phút / 1 phút refresh selector, with 5 minutes first and recommended.
- One Apply action sends SET preferences, waits for `D2 86 OK`, then sends existing D2 render and waits for COMPLETE.
- BUSY uses the same wait-and-retry-once guard as profile Apply.
- GET preferences runs on connect; no auto-connect and no hidden write on page load.

The UI must not claim persistence until status bit PERSISTED is present.

## Size And RAM Gate

- D11C raw baseline: `48380` bytes.
- D12B target raw: at most `50000` bytes.
- Packer limit: `65528` bytes.
- Required headroom after D12B: at least `15528` bytes.
- Conservative firmware increase: at most `1200` raw bytes.
- RAM increase: at most `8` bytes.
- No new strings in firmware beyond existing compact glyph usage.

## D12B Validation Gate

- 24-hour default is unchanged for old records.
- 12-hour midnight/noon/afternoon vectors pass in both profiles.
- Cadence 1/5/10 each schedules exactly once at eligible minutes.
- Immediate render and day rollover remain independent of cadence.
- Preference survives power-cycle while time remains stale until SET_TIME.
- Invalid/malformed/BUSY requests do not change preferences.
- Five-minute disconnected default, BLE reconnect, profile persistence, E5/E6, identity, and battery telemetry remain intact.
- No blank first render, duplicate refresh, or second black refresh.
- Keil 0 errors/0 warnings and raw BIN at most `50000` bytes.

## Next Action

`TASK D12B - IMPLEMENT CLOCK PREFERENCES`

Implement only the audited bytes `17..18`, D2 `06/07/86`, 12/24 rendering, runtime cadence, and Product Mode controls.
