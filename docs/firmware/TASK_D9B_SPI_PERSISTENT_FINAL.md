# TASK D9B - Balanced Flagship Layout SPI Final

## Status

`READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED`

## Lineage

- Main baseline and D9A merge: `246dab2603e4ff9c407b439dd04da9ef82b007e4`.
- D9A implementation: `63936eb8a9e2324fac9447319f5e789e1fdd85f7`.
- Firmware identity remains `D8A1` with Source ID `D8A00001` because D9A changes layout only.
- Canonical URL: `https://onlysky17.github.io/Clock/test.html`.

## Fresh Build

- Target: `DA14585`.
- Compiler: `ARMCLANG 6.24`.
- Code: `42644`.
- RO-data: `3592`.
- RW-data: `552`.
- ZI-data: `22928`.
- Result: `0 errors`, `0 warnings`.
- Raw BIN: `47924` bytes.
- Raw SHA256: `212911C6C68E8EC2060A63B8ADCE65BD44E055B6822B5B6B236AC694F326F824`.
- AXF: `557012` bytes.
- AXF SHA256: `9CFBE543E1BA3ACD588D6DA721A6021DBC82BD23FF87D9D016FA0AF305FDA402`.
- Legacy font symbols: absent.
- Canonical-to-SDK source parity: PASS.

## Package

Path:

`D:\EINK\Clock\_incoming\D9B_SPI_FINAL_2026-07-22`

Packed image:

`D:\EINK\Clock\_incoming\D9B_SPI_FINAL_2026-07-22\D9B_FINAL_PACKED_256KB.bin`

- Packed size: `262144` bytes.
- Packed SHA256: `51D90603363B9660CC43686E68E93FCAA9668ECB3985FF1CE292A58DB55DD8B2`.
- Golden SHA256: `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`.
- Raw CRC32: `417BD7B3`.
- Payload at `0x4040` matches the fresh raw BIN.
- Package verify: PASS.
- Package smoke: PASS.

## Owner SPI Gate

The package is not yet a persistent physical PASS. The Owner must burn and verify the packed image, cold boot from SPI, sync time, confirm the balanced left pane and bold lunar row, then verify the disconnected five-minute scheduler, BLE reconnect, and absence of duplicate or black refreshes.

Package artifacts remain local under `_incoming` and are not committed.
