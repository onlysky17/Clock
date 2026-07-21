# TASK D8A - Device Identity And Health SPI Final

## Status

`READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED`

## Lineage

- Main baseline: `fd4d1bf6a0ea3ba7bf6b3757e6e4deccb71a094e`.
- D8A implementation: `bb9ddb67012462c349bb64bf8b57674b802bc2df`.
- D8A Product Mode null fix: `f84d94e8b331c2816ed0507ba485be637f60c33b`.
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

## Owner SPI Gate

1. Burn and Verify the full packed image.
2. Cold boot from SPI.
3. Connect through the canonical web page.
4. Confirm actual firmware `D8A1` and Source ID `D8A00001`.
5. Before SET_TIME, `STALE / PRIME / STORE` is valid.
6. Sync time and wait for render COMPLETE.
7. Read identity again and require `TIME / TIMER / STORE`.
8. Confirm the five-minute scheduler and BLE reconnect.
9. Confirm no blank panel, duplicate refresh, or second black refresh.

Do not commit package artifacts or mark physical PASS before Owner completes this gate.
