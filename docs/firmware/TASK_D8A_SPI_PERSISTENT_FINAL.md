# TASK D8A - Device Identity And Health SPI Final

## Status

`CLOSED / MERGED / SPI PHYSICAL PASS`

## Lineage

- Main baseline: `fd4d1bf6a0ea3ba7bf6b3757e6e4deccb71a094e`.
- D8A implementation: `bb9ddb67012462c349bb64bf8b57674b802bc2df`.
- D8A Product Mode null fix: `f84d94e8b331c2816ed0507ba485be637f60c33b`.
- D8A package commit: `ea5d7026c5d649b7c45ee342fcee8bc14c667e20`.
- D8A package merge commit: `c4f1657eae836e9b27d327553caf9d6401cbfea4`.
- Firmware identity: `D8A1`.
- Source ID: `D8A00001`.
- Canonical URL: `https://onlysky17.github.io/Clock/test.html`.

## Fresh Build

- Target: `DA14585`.
- Compiler: `ARMCLANG 6.24`.
- Code: `42340`.
- RO-data: `3592`.
- RW-data: `552`.
- ZI-data: `22928`.
- Result: `0 errors`, `0 warnings`.
- Raw BIN: `47620` bytes.
- Raw SHA256: `D0466BA329FFAF81B8278FA25239B8A7ACCF78072E7B688E5F1182438B0CA75F`.
- AXF: `557016` bytes.
- AXF SHA256: `E71FED7B8E4E1978BCAF3676B932A298A478D7F3DD6AC9CE669D21B90764609D`.
- Legacy font symbols: absent.
- Canonical to SDK source parity: PASS.

## Package

Path:

`D:\EINK\Clock\_incoming\D8A_SPI_FINAL_2026-07-21`

Packed image:

`D:\EINK\Clock\_incoming\D8A_SPI_FINAL_2026-07-21\D8A_FINAL_PACKED_256KB.bin`

- Packed size: `262144` bytes.
- Packed SHA256: `CDDB3BFE79B49564119D6936597D0D8CBE70D21E67A4CAF9A3D58DED62125ADE`.
- Golden SHA256: `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`.
- Raw CRC32: `98BAC3D2`.
- Payload at `0x4040` matches the fresh raw BIN.
- Package verify: PASS.
- Package smoke: PASS.

## Owner SPI Physical Evidence

Owner completed the physical gate on `2026-07-22`:

- SmartSnippets SPI Burn: PASS.
- SmartSnippets Verify: PASS.
- Full power-cycle and cold boot from SPI: PASS.
- Canonical web and BLE connection: PASS.
- Actual firmware `D8A1` and Source ID `D8A00001`: PASS.
- Cold-boot health `STALE / PRIME / STORE`: PASS.
- D2 time sync and render COMPLETE: PASS.
- Running health `TIME / TIMER / STORE`: PASS.
- Visible D7A layout and clock output: PASS.
- BLE-disconnected five-minute scheduler: PASS.
- BLE reconnect: PASS.
- No blank panel, duplicate refresh, or second black refresh: PASS.

D8A is now the known-good persistent SPI baseline. Package artifacts remain local under `_incoming` and are not committed.
