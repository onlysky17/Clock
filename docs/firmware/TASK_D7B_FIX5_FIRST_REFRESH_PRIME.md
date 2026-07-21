# TASK D7B-FIX5 - First Refresh Prime And Recovery

Status: SYSRAM PHYSICAL PASS

## Evidence

The first autonomous D2 refresh after cold boot or SysRAM boot completed at the
protocol level but left the panel white. A later five-minute scheduler refresh
displayed the prepared framebuffer correctly. D7B diagnostics ruled out the
framebuffer content, persistence ordering, five-minute policy gate, immediate
timer race, and minute-timer prelude as sufficient causes.

D7B-FIX5 experiments proved that repeating the full refresh twice, adding a
recovery gap, resetting the controller, bypassing the boot probe, and routing
the request through the exact minute callback do not make the first image
visible. A previously physical-PASS D7A raw image now exhibits the same first
white render, and its executable bytes match the D7B baseline apart from the
embedded build time. Golden, D3D2, D3E, and D7B packed images also have identical
product/config sectors at `0x38000`, `0x39000`, `0x3A000`, and `0x3B000`.

The BUSY-handshake build then supplied decisive physical evidence. The first D2
request ran from `14:35:01` to `14:35:05`, reported a real BUSY-complete cycle,
and left the panel white. A second D2 request at `14:35:29` ran the same path and
displayed the layout at `14:35:33`. Repeating the test after a fresh SysRAM load
gave the same result. No E5 or E6 command was used.

The first physical waveform is therefore a controller-prime cycle. A retry that
reused the existing framebuffer still left the panel white, while a second real
SET_TIME rebuilt the framebuffer and displayed it. The firmware now performs
that complete recovery sequence automatically once per boot instead of requiring
the owner to press SET_TIME twice.

## State Machine

1. The accepted render builds the D7A framebuffer once and emits `RENDERING`.
2. Firmware runs the established open/init/RAM-write/update sequence.
3. The asynchronous wait requires BUSY to assert and later deassert.
4. For the first completed waveform after boot, firmware powers down normally
   and waits 20 seconds for controller recovery.
5. A one-shot app timer rebuilds the D7A layout into the same `fb_bw` allocation,
   then runs the same EPD sequence again.
6. `COMPLETE` is emitted only after the second BUSY-complete cycle.
7. The boot-local prime flag is then cleared; all later D2 and scheduler renders
   use one normal physical cycle.

## Preserved Contracts

- D7A framebuffer, calendar alignment, current-day highlight, and lunar layout.
- D3E five-minute scheduling and same-minute duplicate suppression.
- D3D last-known persistence and stale boot policy.
- E5/E6 protocol IDs and the 4000-byte framebuffer.
- EPD calls remain outside the BLE write handler.
- Only the first accepted autonomous render after boot uses the two-cycle prime
  sequence; subsequent requests use one physical refresh.

## Physical Validation

Owner SysRAM validation passed on 2026-07-21 with:

- Keil DA14585 / ARMCLANG 6.24: 0 errors, 0 warnings.
- Code 42192, RO-data 3592, RW-data 552, ZI-data 22928.
- Raw BIN size 47472 bytes.
- Raw BIN SHA256
  `4965D4880A8FDADA9CBA1931B4AEBCB0927C6DF5F01768A725ECE2FDE18320DF`.
- One SET_TIME command triggered the prime cycle, 20-second recovery, framebuffer
  rebuild, and second cycle; the D7A layout then appeared correctly.
- BLE disconnect/reconnect passed.
- The next five-minute scheduler boundary refreshed exactly once.
- Later SET_TIME and scheduler renders used one normal cycle.
- No duplicate, second-black refresh, or calendar-layout regression was observed.

## Gates

- `node .\scripts\task-d7a-autonomous-flagship-layout-smoke.mjs`
- `git diff --check`
- canonical-to-SDK SHA256 parity
- Keil DA14585 build with zero errors and warnings
- raw BIN below 58000 bytes and the 65528-byte packer limit
- Owner SysRAM physical test before any commit or push

The validated SysRAM artifact remains local under
`_incoming/D7B_AUTO_PRIME_REDRAW_20S_SYSRAM_TEST` and is not tracked by Git.
