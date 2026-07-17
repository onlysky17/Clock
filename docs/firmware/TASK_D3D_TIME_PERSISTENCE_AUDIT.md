# TASK D3D Time Persistence Audit

## Scope

- Workspace: `D:\EINK\Clock`
- Firmware base: `firmware/active/HINK213_CLOCK_22_BASE`
- Audit only: no firmware, web, build, pack, or flash changes.
- Baseline raw BIN: `64128` bytes
- Packer raw limit: `65528` bytes
- Available headroom: `1400` bytes
- Future implementation budget: code `<=700` bytes, RAM `<=32` bytes.

## Hardware Limitation

The current clock is a software clock, not a backed RTC.

Evidence in the active firmware:

- D2 time state is RAM-only in retention RAM:
  - `hink_d2_uptime_seconds`
  - `hink_d2_synced_epoch`
  - `hink_d2_uptime_at_sync`
  - `hink_d2_timezone_minutes`
  - `hink_d2_flags`
- Current epoch is derived as:
  - `hink_d2_synced_epoch + (hink_d2_uptime_seconds - hink_d2_uptime_at_sync)`
- `hink_d2_uptime_seconds` is advanced by software timer paths:
  - legacy `clock_update(inc)`
  - dedicated D2 minute timer callback
- Sleep mode is `ARCH_EXT_SLEEP_ON`, and timers can continue only while the SoC is powered and the application/runtime can wake.
- `SW_RESET` exists in the SPI/OTA path, but there is no audited backed RTC or battery-backed time domain that continues through full power loss.

Conclusion:

- Extended sleep: software time can continue while powered.
- Soft reset: no exact elapsed-time guarantee is proven from current source alone.
- Full power loss: no clock source remains to add elapsed seconds accurately.
- Firmware must not pretend persisted time is current after a full power loss.

## Where Current D2 Time Is Lost

Current D2 time is not written to SPI/NVDS.

Active state is stored in RAM only:

- `hink_d2_synced_epoch`
- `hink_d2_uptime_seconds`
- `hink_d2_uptime_at_sync`
- `hink_d2_timezone_minutes`
- auto scheduler state

After cold boot or power loss, the system must treat time as not trusted until a new `D2 00 SET_TIME` arrives.

`D2 00 SET_TIME` must remain the authoritative override for all persisted or restored values.

## SPI / NVDS Layout Evidence

Observed SPI addresses in active source:

- `0x38000`: product/image table
- `0x39000`: screen pin configuration
- `0x3A000`: panel profile / resolution information
- image slots are read from the product table and may occupy the firmware storage ranges.

Flash helpers already exist:

- `sf_read(addr, len, buf)`
- `sf_page_write(addr, buf, size)`
- `sf_erase(addr, size, wait)`

Erase granularity includes 4 KiB sectors and 32 KiB blocks.

No safe persistence address is finalized in this audit. D3D-2 must first verify the packed 256 KiB image map and any free/erased sector before choosing an address. It must not use:

- `0x38000`
- `0x39000`
- `0x3A000`
- active/inactive firmware image data
- panel configuration data
- boot/product headers

## Candidate 2-Slot Journal Record

If persistence is implemented later, use a small two-slot journal inside one verified safe 4 KiB sector.

Proposed record:

- magic: `uint32`
- version: `uint8`
- flags: `uint8`
- length: `uint8`
- reserved: `uint8`
- sequence: `uint32`
- epoch_utc: `uint32`
- timezone_minutes: `int16`
- d2_flags: `uint8`
- validity_state: `uint8`
- crc16: `uint16`

Approximate record size: 24 bytes.

Write rule:

- Write the inactive slot with incremented sequence.
- Validate by magic/version/length/CRC.
- On boot, choose the valid slot with highest sequence.
- Never erase/write both slots as part of the same logical update.

CRC may reuse the existing bitwise CRC16 style if available, or add a small bitwise CRC with no lookup table.

## Wear Policy

Do not write SPI every minute.

Allowed writes:

- On successful `D2 00 SET_TIME`.
- Optionally on rare policy checkpoints, capped to a few writes per day.

Not allowed:

- Every minute tick.
- Every five-minute render.
- Every D2D render.
- Every disconnect/reconnect.

Preferred MVP write cadence:

- Write only on successful SET_TIME.

This keeps wear tied to user/browser resync events, not the clock scheduler.

## Restore Policy

`D2 00 SET_TIME` always wins.

Malformed SET_TIME must not update RAM time or persisted time.

A valid persisted record may be used only as last-known metadata unless an audited powered timebase can prove elapsed seconds.

Scheduler rule:

- D3B/D3C scheduler may run only when time is actively synced or otherwise proven valid.
- A restored last-known record after full power loss must not start the scheduler.
- A restored last-known record after full power loss must not render as if current.

## MVP Decision

Chosen MVP: **A. Restore last-known time metadata and require resync after full power loss.**

Rationale:

- Current hardware/source audit does not prove a backed RTC through full power loss.
- Persisting epoch alone cannot tell how much real time elapsed while unpowered.
- Showing or scheduling based on that epoch would fake accuracy.
- The correct user behavior after cold boot remains: connect and send SET_TIME once.

MVP behavior:

- On successful SET_TIME, write a compact last-known record.
- On cold boot, read and validate the record.
- If valid, expose/report it only as last-known stale metadata.
- Do not mark D2 time RUNNING from persisted data.
- Do not start D3B/D3C auto scheduler from persisted data.
- Require a fresh SET_TIME to resume accurate device-side clock operation.

Rejected for MVP: **B. SPI 2-slot persistence with elapsed-time restore.**

Reason:

- It requires a reliable timebase across reset/power loss.
- That timebase is not proven in this audit.
- It risks displaying inaccurate time.

## D3D-2 Exact Proposed Scope

Implementation files:

- `firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`
- optionally one SPI helper file only if existing `sf_read/sf_page_write/sf_erase` cannot be referenced cleanly
- `scripts/task-d3d-time-persistence-smoke.mjs`

D3D-2 behavior:

- Add small last-known-time record encode/decode.
- Write record only after valid SET_TIME.
- Read record at startup/init path.
- Keep D2 runtime state UNSET/STALE-needs-sync after full power loss.
- Do not start dedicated minute scheduler from persisted last-known metadata.
- Preserve D2 SET_TIME override.
- Preserve D3C renderer, dedicated timer, safe disconnect, EPD, web, and protocol unless a small status flag is explicitly designed first.

Size/RAM target:

- Code increase `<=700` bytes.
- RAM increase `<=32` bytes.
- No new framebuffer, font, table, malloc, or debug strings.

Open decision before D3D-2:

- Choose and verify an exact safe SPI sector from the final packed image map before any write support is implemented.
