# TASK D12B - Clock Preferences

## Status

`CLOSED - MERGED - OWNER PHYSICAL PASS`

D12B implements the D12A policy without changing the framebuffer geometry, EPD worker, BLE service, or existing D2/E5/E6 command IDs.

## Runtime Controls

- Hour mode `00` keeps 24-hour display; `01` renders 12-hour time with a compact AM/PM marker in both clock profiles.
- Refresh cadence accepts `01`, `05`, or `0A` minutes. Five minutes remains the default.
- Day rollover remains forced, while immediate and manual D2 renders remain independent of cadence.
- Invalid, malformed, busy, or failed-persistence requests preserve active preferences.

## Protocol

- SET preferences: `D2 06 hour_mode cadence`, exact 4 bytes.
- GET preferences: `D2 07`, exact 2 bytes.
- Status: `D2 86 result active_hour active_cadence persisted_hour persisted_cadence flags`, exact 8 bytes.
- Result `08` is `INVALID_PREFERENCE`.

Product Mode reads preferences after connection. Apply uses the existing BUSY wait-and-retry-once guard and requests the existing D2 device render only after preference status is OK.

## Persistence

The existing 32-byte D3D journal remains unchanged in size and CRC coverage:

- byte `16`: clock profile;
- byte `17`: hour mode;
- byte `18`: refresh cadence;
- bytes `19..29`: reserved;
- bytes `30..31`: CRC16.

Old or invalid `FF` fields default independently to 24-hour and five-minute behavior. A preference change writes once through the existing verified journal; scheduled refreshes do not write SPI.

## Guards

- No new framebuffer, font, timer, allocation, SPI sector, or EPD sequence.
- Logical `250 x 122`, RAM `122 x 250`, stride `16`, payload `4000` bytes remain fixed.
- D11C remains the rollback baseline until Owner physical validation passes.
- Physical gate must verify 12-hour AM/PM in both profiles, 1/5/10-minute cadence, persistence after reboot, immediate render, BLE reconnect, and no duplicate or second black refresh.

## Owner Physical Result

- PASS date: `2026-07-22`.
- Implementation commit: `6a69ee2b24a8c0f77d59e490a19db5dbef49d4e2`.
- Firmware merge commit: `1bbf42d22c108556ac9fbea4cd7558d895364a77`.
- 24-hour and 12-hour display, AM/PM in both profiles, and cadence 1/5/10 minutes: PASS.
- Preference persistence, immediate render, autonomous refresh, and BLE reconnect: PASS.
- No blank first render, same-minute duplicate, or second black refresh.
- D12B is ready for D12C SPI persistent-final packaging; D11C remains the rollback baseline until that gate passes.

## Validation

- Keil DA14585 build: Code `43568`, RO-data `3592`, RW-data `552`, ZI-data `22936`.
- Raw BIN: `48848` bytes; SHA256 `C066365A035F8B4AA3C5F1DADB40BF7A16DEB5E693B0AE992A5148B5CBB188A3`.
- Packer-limit headroom: `16680` bytes; D12B target headroom: `1152` bytes.
- Keil result: `0 errors`, `0 warnings`; legacy font symbols absent.
- `node scripts/task-d12b-clock-preferences-smoke.mjs`
- `node scripts/task-d11b-large-time-profile-smoke.mjs`
- `git diff --check`
- canonical-to-SDK SHA256 parity
- Keil DA14585: 0 errors, 0 warnings, raw BIN at most 50000 bytes
