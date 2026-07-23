# TASK D13C - Automatic Phone Weather

## Status

`IMPLEMENTED - AUTOMATED WEB GATES PASS`

D13C keeps the D13B daily briefing protocol and firmware unchanged. Product
Mode can obtain the phone's current location, request current weather from
Open-Meteo, populate the existing bounded D2 daily payload, and then apply the
selected profile through the existing BLE flow.

## Owner Flow

1. Select `Tom tat trong ngay`.
2. Leave `Tu lay theo vi tri dien thoai` enabled.
3. Press `Ap dung len man`.
4. Grant browser location permission when prompted.

The web fetches current temperature, WMO weather code, wind speed, and today's
maximum precipitation probability. It maps those values into the existing
D13A weather codes `0..6`, then sends the unchanged `D2 08` 20-byte request.

The two agenda rows remain optional. They are not read from the phone calendar
and can be left empty. The original monthly calendar profile remains unchanged.

## Privacy And Failure Behavior

- Location is requested only after an explicit button/apply action.
- Coordinates are sent to Open-Meteo over HTTPS and are not stored in browser
  storage or persisted by firmware.
- A denied permission, location timeout, network failure, or malformed weather
  response stops apply and shows a clear status. No invented weather is sent.
- The owner can disable automatic weather and use the existing manual fields.

References:

- Open-Meteo forecast API: <https://open-meteo.com/en/docs>
- Browser geolocation: <https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/getCurrentPosition>

## Preserved Contracts

- Firmware source and D2 protocol are unchanged.
- `D2 08` SET remains exactly 20 bytes.
- `D2 09` GET remains exactly 2 bytes.
- `D2 88` status remains exactly 20 bytes.
- Existing profile persistence, scheduler, EPD flow, monthly calendar, and
  optional agenda behavior remain unchanged.
- Canonical URL remains `https://onlysky17.github.io/Clock/test.html`.

## Validation Evidence

- Source smoke and JavaScript parse: PASS.
- Desktop and 360 px mobile browser automation: PASS.
- Mocked GPS/API mapping to the exact 20-byte D2 packet: PASS.
- Live Open-Meteo endpoint response with current temperature, WMO code, wind,
  and daily precipitation probability: PASS.
- No firmware, protocol, `test.html`, or build artifact changes.
