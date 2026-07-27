# TASK D14A - Automatic Weather Refresh Policy Design

## Status

`DESIGN COMPLETE - IMPLEMENTATION NOT STARTED`

D14A defines a bounded Product Mode policy for refreshing phone weather while
the canonical web page is open and BLE is connected. It does not change
firmware, web runtime, BLE packets, panel rendering, or persistence.

Canonical URL:

`https://onlysky17.github.io/Clock/test.html`

## Owner Model

- Automatic weather is opt-in and defaults OFF.
- Enabling it is an explicit owner action and may request location permission.
- Opening or reloading the page must not request location automatically.
- The setting is page-session only for the MVP; coordinates are never stored.
- The web must not auto-connect or auto-reconnect BLE.
- Automatic refresh stops when the page closes, suspends, or BLE disconnects.
- Firmware keeps the last valid RAM context across disconnect as it does today.

Browser background execution is not guaranteed. D14B must describe the feature
as connected-page automation, not as an always-running device weather service.

## Refresh Policy

The minimum successful weather-fetch interval is 30 minutes.

An automatic check is eligible only when all conditions are true:

1. Automatic weather is enabled for the current page session.
2. BLE is connected and D8 device compatibility has passed.
3. D2 time is initialized.
4. Profile `02` daily briefing is active or is being applied.
5. No D2 SET, render, E5, or E6 operation is busy.

Eligible triggers:

- immediately after the owner enables automatic weather;
- after a compatible BLE reconnect when the last success is at least 30 minutes
  old, belongs to another local day, or daily status is not `FRESH`;
- every 30 minutes while the page remains open and connected;
- local-day rollover, even when the previous success was less than 30 minutes
  ago;
- an explicit `Lay thoi tiet ngay` action, which remains available regardless of
  the automatic interval.

The existing high-accuracy location request and fresh-position contract remain:

- `enableHighAccuracy: true`;
- `maximumAge: 0`;
- bounded location timeout;
- no cached coordinates in local storage.

## Fetch, Send, And Render

1. Obtain a fresh phone position after the eligible trigger.
2. Fetch current Open-Meteo data over HTTPS.
3. Apply the existing D13D weather mapping, including rain at
   `precipitationNow >= 0.20 mm`; `0.10 mm` remains `MAY`.
4. Build the unchanged 20-byte `D2 08` daily-context packet.
5. Compare the complete payload with the last successfully acknowledged payload
   for the current local day.
6. If the payload is unchanged and device status is already `FRESH`, skip both
   SET and physical render.
7. Otherwise send `D2 08`, wait for `OK/FRESH`, then request the existing
   `D2 02` render.
8. Treat the update as complete only after `D2 82 OK/COMPLETE`.

The five-minute firmware clock scheduler remains independent. Automatic weather
must not send E5/E6, redraw the web framebuffer, or create a second panel
refresh.

## Reconnect And Day Rollover

- Disconnect cancels any pending web retry and leaves firmware RAM data intact.
- Reconnect never starts without an owner BLE action.
- After reconnect, query `D2 09` before deciding whether a fetch/send is needed.
- A `FRESH` unchanged context less than 30 minutes old is not resent.
- `UNSET`, `EXPIRED`, a new local day, or a success age of at least 30 minutes
  makes one automatic update eligible.
- Day rollover forces one update attempt because D13 daily context is keyed to
  one local day.

## Failure And Retry Policy

- Permission denial, location timeout, malformed API data, or network failure
  sends no invented weather and preserves the current device context.
- One automatic retry is allowed after 60 seconds while the page remains
  visible, connected, and enabled.
- After that retry fails, wait for the next 30-minute eligibility window or an
  explicit owner action.
- D2 `BUSY` waits for the active operation to finish and retries once.
- BLE transport loss performs no retry until the owner reconnects.
- Protocol rejection or malformed D2 status stops the cycle and shows a real
  error.
- A later successful weather/render cycle clears the prior transient error.
- No failure path may loop, auto-connect, or repeatedly refresh the panel.

## Battery And Privacy Bounds

- No weather polling while disconnected or while the page is hidden.
- At most one successful automatic API fetch per 30 minutes, except local-day
  rollover.
- At most one D2 SET plus one D2 render per changed payload.
- No per-minute location request and no coupling to the firmware five-minute
  clock tick.
- Coordinates remain transient in browser memory and are not sent to firmware.
- Daily weather remains RAM-only on the device and is lost after reset/cold boot.

## Preserved Contracts

- `D2 08` SET remains exactly 20 bytes.
- `D2 09` GET remains exactly 2 bytes.
- `D2 88` STATUS remains exactly 20 bytes.
- `D2 02` remains the existing render request.
- Firmware, BLE services, weather mapping, profiles, persistence, scheduler,
  framebuffer, EPD flow, and canonical URL remain unchanged in D14A.
- `Dong bo gio` alone still does not populate or display the weather row.

## D14B Implementation Gate

D14B may modify only the canonical Product Mode page, a new smoke test, and its
current web documentation. It must prove:

1. Auto weather defaults OFF and requires explicit owner enablement.
2. No location prompt occurs on load.
3. Connected-page 30-minute and day-rollover triggers are deterministic.
4. Hidden/disconnected/busy states do not fetch or send.
5. Unchanged `FRESH` payloads cause no D2 SET or render.
6. Changed data sends one `D2 08` and one `D2 02`.
7. Retry is bounded to one attempt and stops on disconnect.
8. Desktop/mobile browser automation passes without protocol changes.
9. Firmware, `test.html`, SDK, and build artifacts remain unchanged.

## Next Action

`TASK D14B - IMPLEMENT CONNECTED AUTO WEATHER REFRESH`
