# TASK D3A - Device Auto-Minute Clock Policy Design

## Purpose

D3A defines the policy for device-side automatic clock refresh after one successful D2 time sync.
It is design-only: no firmware implementation, no automatic panel refresh, no build, and no flash.

Owner-facing goal:
- The web sends time once with `D2 00 SET_TIME`.
- Firmware keeps time from RAM-only D2 state.
- Firmware decides when a panel render is due without requiring the phone to stay connected.
- A later implementation can render on schedule using the D2D render-only framebuffer path and the proven E6-style asynchronous refresh path.

## Current Baseline

- D2B RAM-only time handler: PASS.
- D2C web device time controls: PASS.
- D2D manual device-side render: PASS.
- D2D persistent SPI: PASS.
- D2D final raw canonical build size: `65164` bytes.
- Packer raw limit: `65528` bytes.
- Remaining headroom: `364` bytes.
- D2 time state is RAM-only and is lost after reset or cold boot.
- Canonical web URL remains `https://onlysky17.github.io/Clock/test.html`.

## Time Source Policy

Firmware must use the existing D2 RAM time state:

```text
current_epoch_utc = synced_epoch + (current_uptime_seconds - uptime_at_sync)
```

Rules:
- Do not depend on BLE connection after `D2 00 SET_TIME`.
- Do not increment epoch inside BLE write callbacks.
- Reset or cold boot returns time to `UNSET` until a new SET_TIME arrives.
- `STALE` after 24 hours still continues to run and may render.
- No SPI, flash, or NVDS persistence is part of D3A.

## Minute Boundary Policy

Minute key is derived from local epoch:

```text
minute_key = floor((current_epoch_utc + timezone_offset_minutes * 60) / 60)
```

Rules:
- Schedule render only when `minute_key` changes.
- Never render twice for the same minute key.
- On successful `D2 00 SET_TIME`, allow exactly one immediate render so the owner can see the synced time.
- After that immediate render, wait for the next minute key before scheduling again.
- A new SET_TIME that changes epoch or timezone resets scheduler state in a controlled way.

## Scheduling Policy

Implementation should reuse the existing firmware timer or tick path.

Rules:
- No busy loop.
- No panel refresh in a low-level tick callback.
- Low-level tick logic may only set pending state or schedule application-context work.
- Phone/BLE may disconnect; auto clock stays enabled as long as D2 time remains initialized.
- Application-context work owns the actual render/refresh pipeline.

## Refresh Safety Policy

Auto refresh must reuse the D2D architecture already physically verified:

```text
render-only into fb_bw -> E6-style asynchronous physical refresh -> epd_wait_timer COMPLETE
```

Rules:
- One minute change causes at most one physical refresh.
- Do not run while E5 is active.
- Do not run while E6 is accepted or refreshing.
- Do not run while D2D render is accepted or rendering.
- If a minute changes while busy, keep only the latest pending minute key.
- Do not queue multiple missed minutes.
- Render the latest pending minute as soon as the pipeline is idle.
- Do not add another framebuffer.
- Do not use `fb_rr` or red-plane clearing.
- Do not cause a second black refresh.
- BLE must remain usable during and after refresh.

## Refresh Cadence

D3A defines two modes.

### DAILY_5_MIN Default

- Default after SET_TIME.
- Physical refresh every 5 minutes.
- Internal time still advances every minute.
- Day rollover forces a refresh even if the 5-minute cadence has not elapsed.
- This mode reduces battery use and full-refresh count.

### TEST_1_MIN Mode

- Physical refresh every minute.
- Intended for physical QA only.
- Must be enabled by a compile-time flag or a later explicit command.
- Must not be the cold-boot default.

Partial refresh is not part of D3A.

## Day Rollover Policy

Firmware must detect local day rollover using the stored timezone offset.

Rules:
- If local day changes, force a refresh.
- Day rollover refresh is required even before the next 5-minute boundary.
- This prepares D3C to render weekday, date, lunar calendar, holidays, and jieqi correctly.

## Manual Render Interaction

`D2 02 RENDER_CLOCK_NOW` remains valid.

Rules:
- Manual render updates `last_rendered_minute_key`.
- Auto scheduler must not immediately render again for the same minute key.
- If manual render completes while an auto minute is pending for the same minute, clear that pending minute.
- If SET_TIME changes epoch or timezone, reset `last_seen_minute_key`, `last_rendered_minute_key`, and pending state so the immediate sync render and next-minute behavior remain deterministic.

## Failure Policy

Rules:
- If refresh returns ERROR, do not loop retry continuously.
- Keep one pending retry only.
- Retry at the next scheduler tick if the pipeline is idle, or when the owner sends `D2 02`.
- BLE disconnect does not turn off auto clock.
- Reset or power loss returns time to `UNSET`; auto render stops until SET_TIME.

## Minimal State Model

Required conceptual state:

```text
last_seen_minute_key
last_rendered_minute_key
pending_minute_key
auto_mode: OFF / DAILY_5_MIN / TEST_1_MIN
render_pending flag
```

Size-conscious implementation notes:
- `last_seen_minute_key` and `last_rendered_minute_key` can be `uint32_t`.
- `pending_minute_key` can reuse `last_seen_minute_key` plus a `render_pending` flag if code size is tighter than RAM.
- `auto_mode` can be a `uint8_t`.
- `render_pending flag` can share bit storage with mode/status flags if that reduces code/RAM.
- Do not store duplicate epoch values; derive from D2 state.
- Do not add a framebuffer.

## Sequence Flows

### 1. SET_TIME Successful

```text
D2 00 SET_TIME OK
-> store D2 RAM time
-> reset scheduler state
-> allow one immediate render
-> mark rendered minute key after COMPLETE
-> wait for the next minute key
```

This avoids double render after sync while still giving the owner immediate visual confirmation.

### 2. Minute Changes While Idle

```text
tick detects new minute_key
-> pending_minute_key = minute_key
-> schedule application-context render
-> render-only fb_bw
-> E6-style async refresh
-> COMPLETE
-> last_rendered_minute_key = minute_key
-> clear render_pending
```

### 3. Minute Changes While E5/E6/D2D Busy

```text
tick detects new minute_key
-> store only latest pending_minute_key
-> do not queue older minutes
-> when pipeline is idle, render latest pending minute
```

### 4. Cold Boot UNSET

```text
reset/cold boot
-> D2 time state UNSET
-> auto render disabled/stopped
-> wait for D2 00 SET_TIME
```

### 5. Day Rollover

```text
local day key changes
-> force pending render
-> render even if DAILY_5_MIN cadence is not due
```

## Roadmap

### D3B - Auto-Minute Scheduler Implementation

- Firmware only.
- Use current HH:mm layout.
- DAILY_5_MIN default.
- TEST_1_MIN for physical QA.
- Reuse D2D render-only + E6-style async refresh.
- Audit map before implementation.

### D3C - Date + Weekday + Lunar Renderer

- Add richer calendar display.
- Reuse existing lunar/holiday code only after map audit.
- Avoid new large font/table/string data.

### D3D - Persistence/Resync Policy

- Decide whether to preserve time across reset or resync from web.
- Requires flash wear policy before any SPI/flash persistence.

## D3B Size and Power Guard

- D2D final raw size is approximately `65164` bytes.
- Packer raw limit is `65528` bytes.
- Headroom is approximately `364` bytes.
- D3B must audit map before coding.
- Do not add large strings, font tables, calendar tables, another framebuffer, malloc, or new persistent storage.
