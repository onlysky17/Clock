# TASK D7B - Flagship Layout SPI Persistent Final

## Scope

- Rebuild the merged D7A final firmware from clean `main`.
- Pack the fresh raw firmware into a full 256 KB SPI image.
- Create a self-contained Owner handoff package for SmartSnippets Burn/Verify.
- Stop at the Owner SPI physical gate.

No firmware logic, web UI, BLE protocol, scheduler, layout, packer, or SDK source was changed.

## Status

`READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED`

This task is not a physical PASS until Owner completes:

- SmartSnippets SPI Burn.
- SmartSnippets Verify.
- Full power-cycle/cold boot.
- Canonical web D7A badge check.
- D2 time sync.
- FIX5 first-boot prime cycle, 20-second recovery, redraw cycle, and visible D7A layout.
- BLE-disconnected five-minute scheduler refresh.
- No blank panel, duplicate refresh, or second black refresh.

Do not merge this task before Owner SPI Burn/Verify + cold-boot PASS.

## Lineage

- Main HEAD used for this final package: `b861a8d3283ede751ffeae1de63cedcd561c653b`.
- D7B FIX5 implementation: `e9a32950a7093ff31d0a06720fb74d9f9c5cff82`.
- Firmware marker commit: `e9a32950`.
- D7A implementation: `2308fce61388ef99126cc80a6c81fd9b353baed4`.
- D7A calendar alignment FIX1: `68a47e5c4ce90c874f9c3c21bdb34754e4444600`.
- D7A immediate render FIX2: `32fa562d0d36127a3ded4b46bd35148ff3ccc172`.
- D7A final closeout: `151bc2c1c694044b08793e0205253dc669af2698`.
- D7A-WEB1 identity marker: `0970d47e9de8a1af8e5f679204a2f10716597192`.
- FIX5 first-refresh behavior: one prime EPD cycle, a 20-second recovery, then redraw and a second EPD cycle using the same `fb_bw`.

## Canonical Source And SDK

Canonical source:

`D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`

SDK project:

`D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE`

Keil project:

`D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\ble_app_peripheral.uvprojx`

Canonical to SDK sync used:

`D:\EINK\Clock\tools\bootstrap-hink213-clock22-base.ps1`

Parity evidence:

- Active `src` canonical to SDK parity PASS.
- Checked source files: `32`.
- Representative D7A renderer source SHA256 parity for `src\user_custs1_impl.c`: PASS.

Note: `tools\sync-hink213-source.ps1 -Check` still points at a legacy P3 project, so D7B used explicit HINK213_CLOCK_22_BASE parity after bootstrap.

## Fresh Keil Build Evidence

- Target: `DA14585`.
- Compiler: `ARMCLANG 6.24`.
- Code: `42192`.
- RO-data: `3592`.
- RW-data: `552`.
- ZI-data: `22928`.
- Result: `0 errors`, `0 warnings`.
- Raw BIN size: `47472` bytes.
- Raw BIN gate: PASS, below `65528` bytes.
- Legacy font symbols: absent from map/symdef scan (`sfont`, `sfont16`, `font50`, `font66`).

Fresh AXF:

- Path: `D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\D7B_ble_app_peripheral_585.axf`.
- Source build path: `D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects\ble_app_peripheral_585.axf`.
- Timestamp: `2026-07-21 15:29:24.233 +07:00`.
- Size: `555816` bytes.
- SHA256: `CCF954BEDCCA89F1D987C56C0FBB62F251AD69FBF0006245F6EC815EA7ECE5AF`.

Fresh raw BIN:

- Path: `D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\D7B_RAW_ble_app_peripheral_585.bin`.
- Source build path: `D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects\ble_app_peripheral_585.bin`.
- Timestamp: `2026-07-21 15:29:24.451 +07:00`.
- Size: `47472` bytes.
- SHA256: `5F58D1DA19CAF657A4629894FCBED8AE4C94B4A4FFC2F8153954DA2FB78093A9`.

The fresh raw SHA256 differs from the prior D7A SysRAM artifact hash, but canonical to SDK source parity PASS and this package uses the fresh D7B Keil GUI rebuild output.

## Golden Base

Canonical golden source:

`D:\EINK\Clock\tools\packages\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin`

Packaged copy:

`D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\D7B_GOLDEN_BASE_256KB.bin`

Evidence:

- Size: `262144` bytes.
- SHA256: `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`.
- This is the canonical golden template used by `tools\pack-hink.ps1`.

## Pack Evidence

Packer:

`D:\EINK\Clock\tools\pack-hink.ps1`

Command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "D:\EINK\Clock\tools\pack-hink.ps1" `
  -Raw "D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\D7B_RAW_ble_app_peripheral_585.bin" `
  -Out "D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\D7B_FINAL_PACKED_256KB.bin" `
  -Name "HINK213-CLOCK" `
  -Template "D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\D7B_GOLDEN_BASE_256KB.bin"
```

Packer output:

- Status: `READY TO FLASH`.
- Raw CRC32: `ADFE9EFD`.
- Layout: `7050@00000 7051@04000 PAYLOAD@04040 7052@38000`.

Packed final image:

- Path: `D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\D7B_FINAL_PACKED_256KB.bin`.
- Size: `262144` bytes.
- SHA256: `048D916521B6B0A54D2192409340D1D2EB270C8A72CD98147C66ADE9928843FF`.
- Packed image differs from golden base.
- Packed image is not all `FF`.
- Packed payload at `0x4040` matches the fresh raw BIN.

## Package

Package path:

`D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21`

Package contents:

- `D7B_RAW_ble_app_peripheral_585.bin`
- `D7B_ble_app_peripheral_585.axf`
- `D7B_FINAL_PACKED_256KB.bin`
- `D7B_GOLDEN_BASE_256KB.bin`
- `D7B_MANIFEST_SHA256.txt`
- `verify-d7b-package.ps1`
- `README_D7B_SPI_BURN.txt`

Manifest:

`D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\D7B_MANIFEST_SHA256.txt`

Manifest records:

- Repo HEAD.
- Firmware commit marker.
- D7A final lineage.
- Keil target/compiler.
- Code/RO/RW/ZI.
- Raw BIN size/SHA256.
- AXF size/SHA256.
- Golden size/SHA256.
- Packed size/SHA256.
- Pack command.
- Package creation timestamp.
- Status: `READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED`.

## Automated Verify

Package verify script:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File "D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\verify-d7b-package.ps1" `
  -PackagePath "D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21"
```

Result:

`D7B package verify PASS`

D7B package smoke:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File ".\scripts\task-d7b-spi-final-smoke.ps1" `
  -PackagePath "D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21"
```

Result:

`TASK D7B SPI final smoke PASS`

Smoke checks:

- Package contains all seven required files.
- Raw BIN and AXF match the fresh SDK build output.
- Golden is exactly `262144` bytes with the canonical SHA256.
- Packed image is exactly `262144` bytes.
- Manifest contains required metadata and SHA256 rows.
- Package verify script PASS.
- Raw firmware is inserted into the packed image at `0x4040`.
- Packed image is not all `FF`.
- Packed image differs from golden base.
- D7B artifacts are not tracked by Git.
- Firmware and web source are not modified.
- Canonical URL remains `https://onlysky17.github.io/Clock/test.html`.

## Owner SPI Burn Checklist

1. Open SmartSnippets Toolbox.
2. Select DA14585.
3. Open SPI Flash Programmer.
4. Select:
   `D:\EINK\Clock\_incoming\D7B_FIX5_SPI_FINAL_2026-07-21\D7B_FINAL_PACKED_256KB.bin`
5. Burn the full image.
6. Verify must PASS.
7. Fully power off the board.
8. Remove J-Link/SWD if the existing workflow requires it.
9. Power the board again using normal operating power.
10. Open canonical web:
    `https://onlysky17.github.io/Clock/test.html`
11. Check the D7A baseline badge.
12. Connect BLE and press `Dong bo gio`.
13. On the first render after boot, allow the prime cycle, 20-second recovery, and redraw cycle.
14. The D7A layout must appear after the redraw cycle.
15. Disconnect BLE and wait for the next five-minute boundary.
16. Scheduler must refresh exactly once with one normal EPD cycle.
17. BLE reconnect must PASS with no duplicate refresh or second black refresh.

## Git Guards

- Do not commit `.bin`, `.axf`, `.map`, `.hex`, `.htm`, build logs, or package artifacts.
- Tracked D7B scope is limited to:
  - `docs/firmware/TASK_D7B_SPI_PERSISTENT_FINAL.md`
  - `scripts/task-d7b-spi-final-smoke.ps1`
- Do not merge before Owner SPI Burn/Verify + cold-boot PASS.
