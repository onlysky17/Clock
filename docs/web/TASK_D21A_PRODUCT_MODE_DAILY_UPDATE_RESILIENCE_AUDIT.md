# TASK D21A - PRODUCT MODE DAILY UPDATE RESILIENCE AUDIT

## Status

Audit/design complete. No web runtime, firmware, BLE protocol, SDK, BIN, build,
pack, flash, or physical-device behavior changed.

## Baseline

- Canonical URL: `https://onlysky17.github.io/Clock/test.html`
- Product Mode has one primary action: `Cập nhật màn hình hôm nay`.
- The current order is optional weather, time sync, then profile apply/render.
- Weather failure is intended to degrade gracefully; time sync and device render
  remain required.
- Detailed controls remain in the closed-by-default advanced section.

## Source Evidence

### Weather or location failure

`runUnifiedDailyUpdate()` catches weather/location errors and continues to time
sync and render, so a weather failure does not currently block the clock update.
However, the catch path also clears `dailyWeatherEnabled`. A temporary GPS,
network, or Open-Meteo failure therefore changes the Owner's selection and can
discard usable same-day weather from the outgoing daily packet.

`refreshDailyWeatherFromPhone()` already uses high-accuracy location with
`maximumAge: 0` and bounds the weather request with a 12-second timeout. No new
location or weather mechanism is needed.

### BLE disconnect

The `gattserverdisconnected` handler resets connection and Product Mode state,
but it does not reject the active `pending` BLE request. A disconnect during an
update can therefore leave the flow waiting for its 2.5, 5, or 35-second ACK
timeout before the existing `finally` block releases the UI lock.

The flow must not reconnect or retry automatically after a disconnect. The
Owner must reconnect and deliberately start the update again.

### Device BUSY

`d2SetDailyContext()` and the preference/profile path each contain a local BUSY
retry. They wait for render completion only when the cached render state is not
already COMPLETE, then retry immediately once. A stale COMPLETE value can skip
the wait even while the device still reports BUSY, and the retry policy is
duplicated rather than shared.

The physical render request itself correctly reports COMPLETE only after the
asynchronous EPD wait path finishes. D21B must preserve that behavior and must
not add a second render request.

## Approved Recovery Policy

| Failure | Product Mode behavior | Automatic retry | Final result |
| --- | --- | --- | --- |
| GPS, network, or weather lookup fails | Keep the Owner's weather choice. Reuse valid same-day weather when available; otherwise continue without weather. | No repeated weather retry in the same run. | Continue time sync and one render; show a nonfatal weather note. |
| BLE disconnects during an update | Reject the pending BLE wait immediately and release all locks through the existing `finally` path. | None. | Show `Mất kết nối - hãy kết nối lại`, never claim COMPLETE. |
| Device returns BUSY | Wait for the active render to finish, then retry the same configuration command once. | Exactly one bounded retry. | Continue to one render on success; otherwise stop with `Thiết bị đang bận - thử lại`. |
| Render is rejected or fails | Stop the flow. | None. | Show a real device error; never claim COMPLETE. |

## Invariants

- Keep exactly one primary Product Mode action.
- Do not add reconnect, retry, E5, E6, or engineering buttons to Product Mode.
- Do not automatically reconnect BLE.
- Do not change command IDs, payloads, response lengths, firmware, or scheduler.
- Do not perform more than one physical render for one successful daily update.
- Do not leave a sticky error after a later successful update.
- Always release the Product Mode lock on success, degradation, disconnect, or
  failure.

## D21B Minimal Patch

Implement `TASK D21B - HARDEN PRODUCT MODE DAILY UPDATE RECOVERY` as a web-only
change:

1. In `web/clock-app/hl24a-canvas-e5.html`, preserve weather preference/cache on
   transient failure, reject the active pending request on disconnect, and use
   one bounded BUSY wait/retry helper for configuration writes.
2. Add `scripts/task-d21b-product-mode-daily-update-resilience-smoke.mjs` with
   deterministic fixtures for weather degradation, disconnect cancellation,
   BUSY recovery, persistent BUSY, one render, lock release, and error recovery.
3. Update this document with implementation and automated validation evidence.

D21B does not require Keil, BIN, BLE, or panel testing because it changes only
browser-side orchestration around the existing protocol.

## D21B Implementation

D21B implementation complete.

- A transient weather or location failure keeps the Owner's weather selection.
  Valid same-day weather is reused; without a valid same-day cache, the update
  continues without weather.
- BLE disconnect immediately rejects the active request with
  `Mất kết nối - hãy kết nối lại`; the existing `finally` path releases the UI
  and operation locks.
- Profile, preference, and daily-context writes share one BUSY recovery helper.
  It waits for a fresh render COMPLETE event and performs exactly one bounded
  retry. Persistent BUSY stops with `Thiết bị đang bận - thử lại`.
- The successful flow still performs one profile apply and one physical render.
  No reconnect, second render, E5/E6 action, firmware, or protocol change was
  added.

Automated validation:

- `node scripts/task-d21b-product-mode-daily-update-resilience-smoke.mjs`
- `git diff --check`
- EINK AUTO PREFLIGHT

This web-only recovery patch does not require Keil, BIN, BLE, or panel testing.
