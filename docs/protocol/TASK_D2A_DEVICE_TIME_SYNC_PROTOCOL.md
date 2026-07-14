# TASK D2A Device Time Sync Protocol

## Scope

D2A defines the BLE protocol contract for sending current time from the web page to the DA14585 firmware.

This task is design-only:

- Do not implement firmware.
- Do not change web runtime.
- Do not refresh the panel automatically.
- Do not write or pack firmware.
- Do not change E4/E5/E6.

Owner benefit in later tasks:

- D2B can implement device RAM time state without guessing packet bytes.
- D2C can add web controls that send time to firmware without changing framebuffer flow.
- D2D can build device-side minute rendering on a stable time source.

## Existing Opcode Audit

Current protocol families observed in the active firmware and web page:

- `E4`: command/session bridge.
- `E5`: framebuffer transfer.
- `E6`: one-shot panel refresh.

No active `0xD2` command family was found in the current firmware or web control page, so D2 is available for device time sync.

## Command Family

D2 introduces a new command family and does not modify E4/E5/E6.

Commands:

- `D2 00`: `SET_TIME`
- `D2 01`: `GET_TIME_STATUS`

Transport:

- Use the same current write characteristic/path as E4/E5/E6.
- Use write with response when available, matching the current web implementation fallback behavior.
- Return status through the existing notify characteristic/path.
- Maximum payload is 15 bytes, safely below the ATT payload used by the current transfer path.
- No chunking is required.
- This protocol does not affect E5 framebuffer transfer.

## SET_TIME Request

Purpose: set firmware RAM time state from browser local device time.

Length: `9` bytes.

Byte layout, little-endian:

| Byte | Field | Type | Notes |
| --- | --- | --- | --- |
| 0 | Opcode | uint8 | `0xD2` |
| 1 | Subcommand | uint8 | `0x00` |
| 2..5 | Unix epoch UTC | uint32 LE | `floor(Date.now() / 1000)` |
| 6..7 | Timezone offset minutes | int16 LE | protocol offset = `-Date.getTimezoneOffset()` |
| 8 | Flags | uint8 | bit 0 DST active, bit 1 request immediate status notify |

Flag rules:

- bit 0: DST active.
- bit 1: request immediate status notify.
- bits 2..7: reserved and must be zero.

Do not send date/time strings.
Do not send separate year/month/day fields.
Do not hard-code GMT+7.
Epoch is always UTC.
Timezone offset is used to render local time.

Example timezone:

- Vietnam UTC+7: `420` minutes = `0x0194`, encoded little-endian as `94 01`.

## GET_TIME_STATUS Request

Purpose: read firmware time state without changing it.

Length: `2` bytes.

Byte layout:

| Byte | Field | Type | Notes |
| --- | --- | --- | --- |
| 0 | Opcode | uint8 | `0xD2` |
| 1 | Subcommand | uint8 | `0x01` |

## Status Response

Length: `15` bytes.

Byte layout, little-endian:

| Byte | Field | Type | Notes |
| --- | --- | --- | --- |
| 0 | Opcode | uint8 | `0xD2` |
| 1 | Response | uint8 | `0x81` |
| 2 | Result code | uint8 | See result table |
| 3 | State | uint8 | See state table |
| 4..7 | Current epoch UTC | uint32 LE | Computed current firmware epoch |
| 8..9 | Timezone offset minutes | int16 LE | Last accepted offset |
| 10 | Flags | uint8 | Current accepted flags |
| 11..14 | Uptime seconds | uint32 LE | Firmware uptime seconds |

Result codes:

| Code | Name |
| --- | --- |
| `0x00` | `OK` |
| `0x01` | `INVALID_LENGTH` |
| `0x02` | `INVALID_FLAGS` |
| `0x03` | `INVALID_TIME_RANGE` |
| `0x04` | `NOT_INITIALIZED` |
| `0x05` | `INTERNAL_ERROR` |

States:

| Code | Name | Meaning |
| --- | --- | --- |
| `0x00` | `UNSET` | No valid time has been synced since boot/reset |
| `0x01` | `SYNCED` | Time was accepted recently |
| `0x02` | `RUNNING` | Time is advancing from RAM state |
| `0x03` | `STALE` | Time is still running, but should be resynced |

## Validation Rules

Firmware must reject malformed requests without changing current time state.

Epoch valid range:

- Minimum: `2024-01-01 00:00:00 UTC`
- Maximum: `2099-12-31 23:59:59 UTC`

Timezone offset valid range:

- Minimum: `-720` minutes
- Maximum: `+840` minutes
- Must be encoded as whole minutes in int16 little-endian.

Flags:

- Reserved bits 2..7 must be zero.
- Non-zero reserved bits return `INVALID_FLAGS`.

Length:

- `SET_TIME` must be exactly 9 bytes.
- `GET_TIME_STATUS` must be exactly 2 bytes.
- Invalid lengths return `INVALID_LENGTH`.

## Runtime Model

Web behavior:

1. Read browser time using `Date.now()`.
2. Compute `epoch = floor(Date.now() / 1000)`.
3. Compute protocol timezone offset as `-new Date().getTimezoneOffset()`.
4. Send `D2 00 SET_TIME` only when owner explicitly requests a sync flow.
5. Optionally send `D2 01 GET_TIME_STATUS` to display firmware state.

Firmware behavior:

1. Validate length, flags, epoch range, and timezone offset range.
2. Store in RAM:
   - accepted sync epoch UTC,
   - accepted timezone offset minutes,
   - accepted flags,
   - uptime/tick at sync moment.
3. Compute current epoch as:
   - `synced_epoch + elapsed_seconds`
4. Continue timekeeping without requiring the phone to remain connected.
5. Do not overwrite time on reconnect unless owner or a later web flow explicitly requests `SET_TIME`.
6. `GET_TIME_STATUS` only reports state; it never changes time.

## Persistence Design

Initial D2B/D2C behavior:

- Time is RAM-only.
- Time is lost on power cycle/reset.
- Do not write SPI every minute.
- Do not write flash in D2A.
- D2A does not change the persistent firmware image.

Current SPI firmware remains unchanged:

- Firmware still runs persistently from SPI after cold boot.
- Cold boot currently returns device time to `UNSET` until a new sync is accepted.

Long-term persistence:

- Leave persistent time storage to a later dedicated task.
- If implemented later, store only when a new sync is accepted.
- Define a wear policy before writing flash.

## Drift And STALE State

Initial design:

- Firmware uses a software seconds tick.
- D2A does not claim RTC-grade accuracy.
- If uptime since the last sync exceeds a threshold, firmware may report `STALE`.
- Proposed initial stale threshold: `24 hours`.
- `STALE` does not stop the clock.
- `STALE` only means the device should be resynced.
- No deep calibration is designed in D2A.

## Sequence Diagrams

### 1. Set Time Success

```text
Web
  -> D2 00 SET_TIME
Firmware
  -> validate length, flags, epoch, timezone
  -> store RAM state
  -> notify D2 81 OK SYNCED/RUNNING current_epoch timezone flags uptime
```

### 2. Query Status

```text
Web
  -> D2 01 GET_TIME_STATUS
Firmware
  -> compute current_epoch from RAM sync state and elapsed seconds
  -> notify D2 81 OK state current_epoch timezone flags uptime
```

### 3. Malformed Payload

```text
Web
  -> malformed D2 00 SET_TIME
Firmware
  -> reject request
  -> keep previous time state unchanged
  -> notify D2 81 INVALID_LENGTH / INVALID_FLAGS / INVALID_TIME_RANGE
```

## Next Tasks

### D2B — Firmware Time State + D2 Command Handler

- Implement `SET_TIME` and `GET_TIME_STATUS`.
- RAM-only.
- Do not refresh panel.

### D2C — Web Time Sync Controls

- Add a web control to send time down to firmware.
- Display firmware time status.
- Do not add device-side auto panel clock yet.

### D2D — Device-Side Minute Renderer

- Firmware renders the clock each minute from device-held time.
- Requires refresh policy and battery impact review.
