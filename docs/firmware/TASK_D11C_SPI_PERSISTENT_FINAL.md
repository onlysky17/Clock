# TASK D11C - Clock Profiles SPI Persistent Final

## Status

`READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED`

## Lineage

- D11B implementation commit: `a355d5f398e9acd9ca631dd78e69fbe930b6e58d`.
- D11B merge commit: `63d6063a33d7b4905a0114fbaa7f1aa8909001ed`.
- Firmware identity remains `D8A1`, Source ID `D8A00001`.
- Canonical URL: `https://onlysky17.github.io/Clock/test.html`.

## Fresh Build

- Target `DA14585`, compiler `ARMCLANG 6.24`.
- Code `43100`, RO-data `3592`, RW-data `552`, ZI-data `22932`.
- Keil `0 errors`, `0 warnings`.
- Raw BIN `48380` bytes, SHA256 `6ACDE0EED8728C8F16B0D92F7DB14502B36069459D5D99B8FAEE5F93B4EA22CE`.
- AXF `560228` bytes, SHA256 `A13B9A67160BE357780B7C90090A24D74C82B431DA6F9B5EEC97AA3242FC7C42`.
- Canonical-to-SDK source parity PASS.
- Legacy font symbols absent.

## Package

- Path: `D:\EINK\Clock\_incoming\D11C_SPI_FINAL_2026-07-22`.
- Golden SHA256: `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`.
- Packed size: `262144` bytes.
- Packed SHA256: `0A8C78B071FA5F16775F34D3643BE2644EE0274287FA82DFA3D859F113D43197`.
- Raw CRC32: `DAC26CB8`.
- Layout: `7050@00000 7051@04000 PAYLOAD@04040 7052@38000`.
- Package artifacts stay under `_incoming` and are not committed.

## Owner Gate

Burn/Verify and cold boot must pass before closeout. Validate immediate render, Monthly Calendar, Large Time, persisted profile restore, disconnected five-minute refresh, BLE reconnect, and no duplicate/second-black refresh.
