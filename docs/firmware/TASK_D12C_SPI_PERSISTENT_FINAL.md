# TASK D12C - Clock Preferences SPI Persistent Final

## Status

`READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED`

## Lineage

- D12B implementation commit: `6a69ee2b24a8c0f77d59e490a19db5dbef49d4e2`.
- D12B merge commit: `1bbf42d22c108556ac9fbea4cd7558d895364a77`.
- D12B physical closeout merge: `84f1d6749e6ec64182d1b7b19455013d7dbea635`.
- Canonical URL: `https://onlysky17.github.io/Clock/test.html`.

## Fresh Build

- DA14585 / ARMCLANG 6.24: Code `43568`, RO `3592`, RW `552`, ZI `22936`.
- Keil: `0 errors`, `0 warnings`.
- Raw BIN: `48848` bytes, SHA256 `845ABEEED290B361C58C86CC0B4394A2F1FBAC2B62F9AF6AE92935B11C93B188`.
- AXF: `563044` bytes, SHA256 `D666C873C07E3F93FED66883691E7D40C8BFD187446FF138068A0CF6529082DB`.
- Canonical-to-SDK source parity PASS; legacy font symbols absent.

## Package

- Path: `D:\EINK\Clock\_incoming\D12C_SPI_FINAL_2026-07-22`.
- Golden SHA256: `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`.
- Packed size: `262144` bytes.
- Packed SHA256: `9519751A5875F58DE16EC0F0273AABB1F1F6C50A6941E65017DDCAE587412251`.
- Raw CRC32: `9BEB7AD4`.
- Package and build artifacts remain untracked under `_incoming`/SDK output.

## Owner Gate

Burn only `D12C_FINAL_PACKED_256KB.bin`, run SmartSnippets Verify, then test cold boot, SET_TIME/immediate render, both profiles, 24/12-hour modes, AM/PM, cadence 1/5/10, preference restore, disconnected scheduling, BLE reconnect, and absence of blank/duplicate/second-black refresh.

D11C remains the rollback package until every D12C physical gate passes.
