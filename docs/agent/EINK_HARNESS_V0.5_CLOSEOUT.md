# EINK Harness v0.5 Closeout

## Status

CLOSED / REAL HARDWARE SPI BURN + FULL READBACK VERIFY PASS.

## Branch

- Feature branch: `task-d/eink-harness-v0.5-spi-burn`
- Runtime-tested head before final docs: `a2b5f4465f2d454134bc3800ba302f0d4f82ec03`
- Base main after v0.4 closeout: `b7ba809fc2a4cda94c2c3ece5461aa6965c7c899`

## Scope

Harness v0.5 adds guarded SPI burn automation with full readback verification:

- `scripts/eink-spi-burn.ps1`
- `scripts/task-eink-harness-v0.5-smoke.ps1`
- `tools/harness/eink-profile.json`

The final task branch also includes this closeout document and the next-action update so the Owner needs only one final merge for v0.5.

## Static Validation

- Harness v0.5 smoke: PASS 15/15.
- Plan mode: PASS / non-destructive.
- Packed image required size: `262144` bytes.
- Explicit packed SHA256 required before Burn.
- Explicit destructive confirmation token required before Burn.
- Fresh full-SPI backup required before erase/write.
- SPI erase uses verify.
- SPI write uses verify.
- Independent full `0x40000` readback required.
- Readback SHA256 must equal packed SHA256 before PASS.
- No GUI fallback or retry loop.

## Packed Image Selected by Owner

- Path: `D:\EINK\Clock\_incoming\HINK213_CLOCK_BOARD1_20260813.bin`
- Size: `262144` bytes.
- SHA256: `871DD538DDD2749274C582223FC082DAE3D19C92F7F504197EB7086F3E06945F`.
- Confirmation token: `BURN-BOARD1-SPI`.

## Fresh Backup Evidence

Fresh read-only backup immediately before final burn validation:

- Evidence directory: `D:\EINK\Clock\_incoming\EINK_HARNESS_SPI_BACKUP\20260815_085357`.
- READ1 size: `262144` bytes.
- READ2 size: `262144` bytes.
- READ1 SHA256: `CE2D66AC3B08A7EC761F1C5C786064BA84F5C1FCB96E55E4A6146C3EF01C5E63`.
- READ2 SHA256: `CE2D66AC3B08A7EC761F1C5C786064BA84F5C1FCB96E55E4A6146C3EF01C5E63`.
- Hash equality: PASS.
- `NEXT_STATE: SPI_BACKUP_VERIFIED`.

## Real Burn + Readback Evidence

Board #1 real hardware run:

- SmartSnippets/JTAG selection: `-1` auto-select.
- Packed size: `262144` bytes.
- Packed SHA256: `871DD538DDD2749274C582223FC082DAE3D19C92F7F504197EB7086F3E06945F`.
- Readback path: `D:\EINK\Clock\_incoming\EINK_HARNESS_SPI_BURN\20260815_091014\SPI_READBACK.bin`.
- Readback size: `262144` bytes.
- Readback SHA256: `871DD538DDD2749274C582223FC082DAE3D19C92F7F504197EB7086F3E06945F`.
- Packed/readback SHA256 equality: PASS.
- Process exit code: `0`.
- Evidence directory: `D:\EINK\Clock\_incoming\EINK_HARNESS_SPI_BURN\20260815_091014`.
- `NEXT_STATE: SPI_BURN_VERIFIED`.

## Safety / Remaining Owner Gates

This establishes SPI burn + full readback verification only.

It does not establish:

- cold-boot PASS;
- BLE PASS;
- physical e-ink visual PASS.

Those remain separate device/Owner gates.

## Owner Data

`bk-13-08-26/` remained untracked and untouched throughout the task.

## Workflow Rule

For future Harness milestones, implementation, validation, closeout docs, and next-action state must be completed on the same task branch before creating the final PR. The Owner should receive one final merge gate per completed task, not a second closeout PR.
