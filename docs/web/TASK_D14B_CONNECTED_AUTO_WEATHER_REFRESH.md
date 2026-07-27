# TASK D14B - Connected Automatic Weather Refresh

## Status

`IMPLEMENTED - AUTOMATED WEB GATES PASS`

D14B implements the D14A policy in canonical Product Mode without changing
firmware or BLE protocol.

Canonical URL:

`https://onlysky17.github.io/Clock/test.html`

## Owner Behavior

- `Tu cap nhat moi 30 phut khi dang ket noi` defaults OFF.
- The owner enables it explicitly from the daily briefing panel.
- Enabling while BLE is disconnected waits without requesting location.
- When the page is visible, BLE is connected, time is initialized, the device
  is compatible, and profile `02` is active, the web obtains fresh phone
  weather and applies it to the device.
- The page pauses automatic work while hidden or disconnected.
- The web never auto-connects or auto-reconnects BLE.
- `Lay thoi tiet ngay` remains available as an explicit fetch action.

## Refresh And Duplicate Rules

- Minimum successful automatic interval: 30 minutes.
- Local-day rollover can make an update eligible before that interval.
- Location remains high accuracy with `maximumAge: 0`.
- The existing D13D rain mapping remains unchanged:
  `precipitationNow >= 0.20 mm` maps rain and `0.10 mm` maps cloud.
- The complete 20-byte daily payload is compared with the current `D2 88`
  `FRESH` status and the last acknowledged page-session payload.
- An unchanged fresh payload skips both `D2 08` and physical render.
- Changed data sends one `D2 08`, waits for `OK/FRESH`, then sends one `D2 02`.
- Success is reported only after `D2 82 OK/COMPLETE`.

## Failure Bounds

- One location/weather retry is allowed after 60 seconds.
- A second failure waits for the next 30-minute window or owner action.
- Existing D2 `BUSY` handling waits and retries once.
- Disconnect cancels pending automatic and retry timers.
- Protocol errors do not loop or fabricate weather.
- Coordinates and the automatic switch remain page-session only.

## Preserved Contracts

- `D2 08` remains 20 bytes.
- `D2 09` remains 2 bytes.
- `D2 88` remains 20 bytes.
- `D2 02` render completion remains tied to physical EPD completion.
- Firmware, SDK, `test.html`, profiles, persistence, scheduler, E5/E6, and panel
  layout are unchanged.

## Validation

- JavaScript parse and source contract smoke: PASS.
- Default-OFF, disconnected wait, 30-minute timer, and unchanged-payload
  fixtures: PASS.
- Desktop and 360 px mobile browser checks: PASS.
- Advanced panel remains closed and no horizontal overflow is present.
- Proof is local-only under:
  `D:\EINK\Clock\_incoming\D14B_AUTO_WEATHER_PROOF`.

## Owner Gate

No firmware build or panel test is required. After the web PR is merged, test
from the canonical URL by connecting BLE, selecting `Tom tat trong ngay`,
enabling automatic weather, and applying the profile once.
