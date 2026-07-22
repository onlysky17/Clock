# TASK D11B - Large-Time Clock Profile

## Goal

Implement the first selectable firmware-rendered clock face without duplicating the framebuffer, calendar conversion, EPD worker, first-refresh prime recovery, or five-minute scheduler.

## Protocol

- `D2 04 <profile>` sets and persists a profile. Exact length: 3 bytes.
- `D2 05` reads the active/persisted profile. Exact length: 2 bytes.
- `D2 84 result active persisted flags` is the exact 6-byte response.
- Profile `0` is the unchanged monthly-calendar face.
- Profile `1` is LARGE_TIME.
- Profile `2` and unknown values return `INVALID_PROFILE (07)`.
- SET requires initialized D2 time and idle E5/E6/D2/EPD state.
- Applying a profile does not claim a panel refresh. Product Mode sends the existing `D2 02` and waits for `D2 82 COMPLETE`.

## Persistence

The existing 32-byte D3D journal remains version 1 and keeps the same sector and slots. Byte 16 now stores the profile and remains covered by the existing CRC over bytes 0..29.

- Old `FF` records load profile 0 with DEFAULTED status.
- Values 0 and 1 restore that profile.
- Unsupported values fall back safely to profile 0 without invalidating time metadata.
- Writes happen only on explicit profile SET and later SET_TIME journal updates.

## Rendering

Calendar/time/lunar values are derived once and the existing 4000-byte `fb_bw` is cleared once. A small dispatcher selects:

- Profile 0: existing `hink_bitmap_draw_clock()` unchanged.
- Profile 1: optically centered large `HH:mm`, compact weekday/solar date, and regular-weight `AL dd/MM`.

Both profiles return to the same physical-PASS prime recovery, asynchronous EPD wait/cleanup, and disconnected five-minute scheduler.

## Gates

- Keil 0 errors and 0 warnings.
- Raw BIN at most 50000 bytes.
- RAM increase at most 8 bytes.
- Profile 0 remains physically unchanged.
- Profile 1 passes immediate render, disconnected five-minute refresh, reboot restore, and BLE reconnect tests.
- No blank first render, duplicate refresh, or second black refresh.
