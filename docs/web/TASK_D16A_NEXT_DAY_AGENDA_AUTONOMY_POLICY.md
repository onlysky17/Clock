# TASK D16A - Next-Day Agenda Autonomy Policy

## Status

`DESIGN COMPLETE - IMPLEMENTATION NOT STARTED`

Canonical URL:

`https://onlysky17.github.io/Clock/test.html`

D16A defines what happens to the two Google Calendar agenda rows when the
local day changes while the browser is hidden, closed, or disconnected from
BLE. It changes no firmware, web runtime, BLE protocol, OAuth scope, panel
renderer, or persisted device data.

## Current-System Evidence

The current device and web already provide most of the safety boundary:

- The device stores a bounded `day_key` with the daily weather and agenda
  context.
- Device daily state becomes `EXPIRED` when that key differs from the current
  local day derived from D2 epoch plus timezone.
- The five-minute scheduler forces a render on local-day rollover even when
  the regular refresh interval is not due.
- The renderer displays daily weather and agenda rows only while daily state is
  `FRESH`.
- Google Calendar queries are bounded to the browser's current local day.
- Google access is read-only and page-session scoped.
- The web never auto-connects BLE.

Therefore a device left running without the phone can remove yesterday's
agenda autonomously. It cannot fetch tomorrow's events because the firmware
has no network or Google credentials.

## Approved MVP Policy

Choose **fail-closed expiry with connected current-day refill**.

At local midnight:

1. The device keeps its clock, solar date, lunar date, calendar, and autonomous
   scheduler running.
2. The previous daily `day_key` becomes expired.
3. The next forced day-rollover render omits both old agenda rows.
4. The device must never relabel yesterday's rows as today's agenda.
5. Empty agenda rows remain visible until fresh current-day data is received.

When the browser is available again:

1. It obtains or restores an explicit read-only Google Calendar token.
2. It fetches the current local day, never yesterday's cached query window.
3. It selects at most two timed events that are still running or upcoming.
4. It updates the review controls before any device write.
5. It sends the unchanged D2 daily-context packet only when BLE is already
   connected, the device is compatible, the daily profile is active, and the
   existing busy guards accept the operation.
6. It requests one normal render only when the bounded daily payload changed.

No browser or firmware path may automatically initiate a BLE connection.

## Browser-Open Rollover

While the page remains open and visible:

- Detect a local-day-key change independently from the 15-minute fetch age.
- Clear yesterday's agenda rows from the review model immediately.
- Fetch the new local day once when a valid Google token exists.
- Coalesce the rollover fetch with any in-flight Google refresh.
- If BLE is disconnected, keep the fresh rows only in page RAM; do not
  auto-connect.
- When BLE later reconnects, re-check current time, profile, compatibility,
  device daily state, and payload equality before sending.

The ordinary 15-minute Google refresh cadence remains unchanged after the
single rollover fetch.

## Browser Hidden Or Closed

When the page is hidden:

- Google polling remains paused.
- No BLE write or panel refresh is attempted.
- On visibility return, compare the current local day with the last fetched
  day before using cached events.
- If the day changed, discard cached rows and fetch today before considering a
  device update.

When the tab is closed:

- Access token and event data follow the existing page-session lifetime.
- The device independently expires the old daily context.
- Reopening the page may restore same-tab access only when the existing token
  rules permit it; otherwise the owner reconnects Google Calendar.
- Closing the page never leaves old agenda rows valid on the next local day.

## Timezone Boundary

The authoritative device day is derived from D2 epoch plus the D2 timezone
offset. The browser query day uses the browser local timezone that supplied the
same D2 sync.

- After a new SET_TIME or timezone change, discard the previous browser day
  key and refetch the new current local day.
- Do not shift cached agenda rows from one timezone into another.
- If browser and device day keys disagree, do not send agenda data; show a
  visible resync requirement instead.
- Day-key comparison must not depend on UTC midnight.

## Busy, Retry, And Duplicate Rules

- D2, E5, or E6 busy state coalesces to the latest current-day payload.
- A busy rejection does not create a retry loop.
- Retry is allowed only on the next existing eligible web refresh, visibility
  return, BLE reconnect, or explicit owner action.
- Never send two identical daily payloads for the same local day.
- Never request a render when no daily packet was accepted.
- A failed fetch clears no valid current-day device data, but expired
  previous-day rows remain hidden by firmware.

## Privacy And Persistence

- Google scope remains `calendar.readonly`.
- OAuth remains an explicit owner action.
- Tokens remain in `sessionStorage`; event data and titles remain page RAM-only.
- No Google token, event title, agenda row, or location is written to SPI or
  NVDS.
- The device receives only the existing bounded day key, two minute values,
  and two three-character labels.
- Daily agenda data is not restored as current after a cold boot without fresh
  D2 time and a matching day key.

## Preserved Contracts

- `D2 08` SET remains exactly 20 bytes.
- `D2 09` GET remains exactly 2 bytes.
- `D2 88` STATUS remains exactly 20 bytes.
- Two agenda rows remain the maximum.
- Weather, clock profiles, D2 time, E5/E6, persistence, scheduler cadence, and
  panel layout remain unchanged.
- No firmware build, pack, flash, or owner physical test is required for D16A.

## D16B Exact Scope

`TASK D16B - IMPLEMENT NEXT-DAY AGENDA ROLLOVER`

Expected maximum tracked files:

1. `web/clock-app/hl24a-canvas-e5.html`
2. `scripts/task-d16b-next-day-agenda-rollover-smoke.mjs`
3. this policy document only if implementation evidence must be appended

D16B should add browser-open day-change detection, immediate stale preview
clearing, one coalesced current-day Google fetch, guarded connected-device
refill, and desktop/mobile browser fixtures. It must preserve the existing
firmware expiry and forced day-rollover render rather than duplicate them.
