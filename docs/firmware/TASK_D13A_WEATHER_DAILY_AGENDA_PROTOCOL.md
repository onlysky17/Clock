# TASK D13A - Weather And Daily Agenda Protocol Design

## Status

`DESIGN COMPLETE - IMPLEMENTATION NOT STARTED`

D13A defines a bounded web-to-device contract for a daily weather summary and at
most two agenda entries. It does not change firmware, Product Mode, the BLE
service, the framebuffer, or the EPD worker.

The canonical web remains:

`https://onlysky17.github.io/Clock/test.html`

## MVP Decision

- Product Mode supplies explicit owner-entered data. D13B must not invent data
  and must not call an external weather service.
- Daily context is RAM-only in D13B. Cold boot starts `UNSET`.
- Disconnect does not clear valid context.
- Context is usable only for the exact local day carried in the payload. At day
  rollover it becomes `EXPIRED` and the renderer hides it.
- A timezone or local-day change caused by `SET_TIME` must recompute freshness.
- D13B adds profile `02` (`DAILY_BRIEFING`). Profiles `00` and `01` keep their
  existing behavior.

## Opcode Audit

Current firmware routes requests `D2 00` through `D2 07` and emits status
notifications `D2 81`, `D2 82`, `D2 83`, `D2 84`, and `D2 86`.

The following values are free in the D12C baseline and are reserved by D13A:

| Packet | Opcode | Exact length |
| --- | --- | ---: |
| `SET_DAILY_CONTEXT` | `D2 08` | 20 bytes |
| `GET_DAILY_CONTEXT` | `D2 09` | 2 bytes |
| `DAILY_CONTEXT_STATUS` | `D2 88` | 20 bytes |

Existing command IDs, characteristic IDs, and notification routing do not
change.

## SET_DAILY_CONTEXT

Exact request length: 20 bytes.

| Offset | Size | Field | Encoding and validation |
| ---: | ---: | --- | --- |
| 0 | 1 | family | `D2` |
| 1 | 1 | command | `08` |
| 2 | 1 | schema | exact value `01` |
| 3 | 1 | flags | bit 0 weather valid; bit 1 agenda valid; bits 2..7 zero |
| 4 | 2 | local day key | uint16 little-endian, days since local `2024-01-01` |
| 6 | 1 | weather code | enum `00..06` |
| 7 | 1 | temperature C | int8, range `-40..80` |
| 8 | 1 | precipitation | uint8 percent, range `0..100` |
| 9 | 1 | agenda count | `0..2` |
| 10 | 2 | entry 0 minute | uint16 little-endian, `0..1439` |
| 12 | 3 | entry 0 label | exactly three ASCII bytes |
| 15 | 2 | entry 1 minute | uint16 little-endian, `0..1439` |
| 17 | 3 | entry 1 label | exactly three ASCII bytes |

Weather codes are deliberately compact:

| Value | Display token | Meaning |
| ---: | --- | --- |
| `00` | `SUN` | clear/sunny |
| `01` | `CLD` | cloudy |
| `02` | `RAN` | rain |
| `03` | `STM` | storm |
| `04` | `FOG` | fog |
| `05` | `WND` | windy |
| `06` | `HOT` | hot |

Agenda labels allow only uppercase ASCII `A-Z`, digits `0-9`, and space. This
keeps the existing 5x7 glyph path sufficient; UTF-8 and runtime strings are not
accepted. Used entries must be sorted by start minute and may not have duplicate
start minutes. Unused entries are deterministic: minute zero and three spaces.

When a valid flag is clear, all fields owned by that section must contain their
deterministic zero/blank values. Agenda count must agree with the agenda-valid
flag. This prevents stale bytes from becoming visible data.

`SET_DAILY_CONTEXT` requires initialized D2 time and a day key equal to the
device's current local day. Old or future payloads, malformed fields, reserved
flag bits, wrong lengths, and unsorted/duplicate entries are rejected without
changing the active RAM context.

The command stores data only. It must not render or touch EPD hardware inside the
BLE write callback. Product Mode may request the existing `D2 02` render only
after an `OK/FRESH` status response.

## GET And Status

`GET_DAILY_CONTEXT` is exactly `D2 09`. It is safe before `SET_TIME`; in that
case status is `UNSET`.

`DAILY_CONTEXT_STATUS` is exactly 20 bytes:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 1 | family `D2` |
| 1 | 1 | status opcode `88` |
| 2 | 1 | result |
| 3 | 1 | state/valid flags |
| 4..19 | 16 | exact mirror of request bytes 4..19 |

Status byte 3 keeps the packet at 20 bytes while preserving section validity:

- bits 0..1: context state;
- bit 2: weather valid;
- bit 3: agenda valid;
- bits 4..7: zero.

Context-state values in bits 0..1:

- `00 UNSET`
- `01 FRESH`
- `02 EXPIRED`

Existing result values are reused:

- `00 OK`
- `01 INVALID_LENGTH`
- `02 INVALID_FLAGS`
- `04 NOT_INITIALIZED`
- `06 BUSY`

D13A reserves result `09 INVALID_DAILY_DATA` for schema, day-key, weather,
temperature, precipitation, agenda-count, ordering, or label validation errors.
An error response reports the current context state and never mutates it.

## Freshness And Reconnect

- Successful SET for today's local day produces `FRESH`.
- Day rollover produces `EXPIRED`; expired data remains queryable for diagnosis
  but is not rendered as current information.
- A later valid SET replaces the whole context atomically and returns `FRESH`.
- BLE disconnect/reconnect preserves RAM context and GET reports its current
  freshness.
- Cold boot, reset, or power loss produces `UNSET`; no weather or agenda is
  inferred from last-known time metadata.
- The autonomous clock and its five-minute/day-rollover policy continue even
  when daily context is unset or expired.

## Persistence Audit

The D3D journal remains a 32-byte record in the proven sector `0x3B000`:

- byte 16: profile;
- byte 17: hour mode;
- byte 18: refresh cadence;
- bytes 19..29: reserved;
- bytes 30..31: CRC16.

The A/B slots share one erase sector. A second independent daily-data journal in
that sector could erase the current time/preferences record. Daily weather and
agenda also expire quickly and do not justify flash wear. Therefore D13B must not
write this payload to SPI/NVDS and must not consume bytes 19..29.

Any future persistence is a separate D13C storage audit. It may proceed only
after proving another erase-safe location and a bounded wear policy.

## D13B Renderer And Web Contract

Profile `02 DAILY_BRIEFING` is the only new layout planned for D13B:

- retain the current date and large time;
- show one compact weather token, temperature, and precipitation value;
- show at most two agenda rows using the three-byte labels and `HH:mm` times;
- hide weather/agenda sections when invalid, unset, or expired;
- reuse the linked 5x7 glyphs and D7A large digits.

D13B must add no font, icon table, framebuffer, allocation, or timer. Geometry
remains logical `250 x 122`, controller RAM `122 x 250`, stride `16`, payload
`4000` bytes, polarity 1 white / 0 black.

Product Mode will provide bounded manual fields and one explicit Apply action.
It must not auto-connect, treat localStorage as device truth, or fetch/fabricate
weather. Apply sends SET, waits for status, and then uses existing `D2 02`.
`BUSY` may use the existing bounded wait-and-retry-once behavior.

## Size And RAM Gate

- D12C raw baseline: `48848` bytes.
- Packer limit: `65528` bytes.
- D13B target raw: at most `51500` bytes.
- Conservative D13B code/RO increase: at most `2652` bytes.
- Required remaining packer headroom: at least `14028` bytes.
- Daily-context RAM increase: at most `32` bytes.

D13B must stop before implementation if its map-backed estimate cannot meet
these gates.

## D13B Validation Gate

Implementation must prove:

1. Exact 20-byte SET, 2-byte GET, and 20-byte STATUS packets.
2. Malformed input preserves the prior context.
3. Cold boot is `UNSET`; reconnect preserves RAM data.
4. Day rollover is `EXPIRED` and hides stale content.
5. Profile 02 renders valid context without new fonts or framebuffer.
6. SET does not render in the BLE callback; existing D2 render completion remains
   tied to physical EPD completion.
7. Existing profiles, preferences, persistence, scheduler, identity, battery,
   E5/E6, and canonical web behavior remain intact.
8. Keil reports zero errors/warnings and raw BIN remains at most 51500 bytes.

## Next Action

`TASK D13B - IMPLEMENT DAILY BRIEFING PROFILE`
