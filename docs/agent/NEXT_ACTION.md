# NEXT_ACTION

## Current Checkpoint

- Repository: `D:\EINK\Clock`.
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`.
- EINK Harness v0.3 PR #144 is merged to `main`.
- Feature commit: `9c662195eee8c1552918d2c84e9b5c7ef00d3726`.
- Actual main merge commit: `bbdc2f89c8746bcfc5186352e08f2beebd424b31`.
- Harness v0.3 automated Keil build is engineering PASS.
- Proven build evidence:
  - Harness smoke PASS 12/12.
  - Keil ARMCLANG `V6.24`.
  - `0 Error(s), 0 Warning(s)`.
  - raw BIN `50552` bytes, below the `65528` byte limit.
  - raw SHA256 `547D6D3949E36A88843D62DC34FF656199EFD03ECE0442A06733B7296908E012`.
  - `NEXT_STATE: RAW_FIRMWARE_VERIFIED`.
- Closeout details: `docs/agent/EINK_HARNESS_V0.3_CLOSEOUT.md`.
- v0.3 does not establish pack, SPI burn, SPI verify, cold boot, BLE, or physical e-ink PASS.
- Owner backup folder `bk-13-08-26/` remains outside task scope and must not be staged, cleaned, reset, moved, or deleted by automation.

## Next Canonical Action

`EINK HARNESS v0.4 - AUTOMATED FULL-SPI BACKUP`

Goal: make a read-only Harness action that backs up the complete 0x40000-byte SPI image through the already proven SmartSnippets CLI path.

Required behavior:

- verify canonical workspace/project before hardware access;
- auto-detect or safely resolve the connected J-Link without hardcoding a fragile serial when avoidable;
- use the proven DA14585 SmartSnippets/JTAG programmer and SPI pin mapping;
- perform two independent full reads of `0x40000` bytes;
- require each backup to be exactly `262144` bytes;
- calculate SHA256 for both reads;
- require both hashes to match before PASS;
- save immutable/read-only evidence under `D:\EINK\Clock\_incoming`;
- report exact output paths, sizes, hashes, tool paths, and command evidence.

## Hard Scope Boundary

v0.4 backup is READ ONLY.

Do not:

- erase SPI;
- write/burn SPI;
- pack firmware;
- change firmware source or `.uvprojx`;
- alter Keil/compiler registration;
- cold boot the board as part of the automated backup task;
- run BLE or visual physical validation;
- touch `bk-13-08-26/`;
- stage/commit/push unrelated files.

## Execution Contract

Before any edit or hardware action, verify:

- workspace `D:\EINK\Clock`;
- Git root;
- branch;
- HEAD;
- git status;
- task-project match.

Wrong workspace/project => exactly `SAI PROJECT/WORKSPACE`.

Keep the task narrow. After implementation and validation, automation may exact-stage reviewed task files, commit, push the feature branch, and create a complete PR with evidence. Owner retains the final merge gate.
