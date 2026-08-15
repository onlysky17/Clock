# NEXT_ACTION

## Current Checkpoint

- Repository: `D:\EINK\Clock`.
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`.
- EINK Harness v0.4 PR #146 is merged to `main`.
- Feature head: `42ee0ae388603a983f0059c2d0f108526a68fc8e`.
- Actual main merge commit: `3ff48fb3c56bc4bca60df164358815d433229fcb`.
- Harness v0.4 automated full-SPI backup is engineering + real hardware PASS.
- Proven backup evidence:
  - Harness smoke PASS 12/12.
  - Board #1 full READ1 = `262144` bytes.
  - Board #1 full READ2 = `262144` bytes.
  - READ1 SHA256 `CE2D66AC3B08A7EC761F1C5C786064BA84F5C1FCB96E55E4A6146C3EF01C5E63`.
  - READ2 SHA256 `CE2D66AC3B08A7EC761F1C5C786064BA84F5C1FCB96E55E4A6146C3EF01C5E63`.
  - Hash equality PASS.
  - `NEXT_STATE: SPI_BACKUP_VERIFIED`.
- v0.4 is read-only and does not establish SPI write/burn, post-write verify, cold boot, BLE, or physical e-ink PASS.
- Closeout details: `docs/agent/EINK_HARNESS_V0.4_CLOSEOUT.md`.
- Owner backup folder `bk-13-08-26/` remains outside task scope and must not be staged, cleaned, reset, moved, or deleted by automation.

## Next Canonical Action

`EINK HARNESS v0.5 - GUARDED SPI BURN + FULL READBACK VERIFY`

Goal: automate the already-proven SmartSnippets CLI write path while preserving explicit safety gates and requiring a full 0x40000-byte readback hash match before PASS.

Required behavior:

- verify canonical workspace/project before hardware access;
- require an explicit Owner-provided packed BIN path, never guess the image;
- require the packed BIN to be exactly `262144` bytes;
- calculate and print the input packed SHA256 before any destructive action;
- require a fresh successful v0.4-style full-SPI backup in the same run/session before erase/write;
- require an explicit destructive confirmation token before erase/write;
- use the proven DA14585 SmartSnippets/JTAG programmer and SPI pin mapping;
- perform full SPI erase/write using the proven CLI path only;
- perform an independent full 0x40000-byte readback after write;
- require readback size `262144` and SHA256 == input packed SHA256 before PASS;
- save stdout/stderr, backup, input hash, readback, and final evidence under `D:\EINK\Clock\_incoming`;
- on any failure, stop without retry loops or alternate write methods.

## Hard Scope Boundary

v0.5 may automate SPI erase/write only after all preconditions above pass.

Do not:

- change firmware source or `.uvprojx`;
- change Keil/compiler registration;
- build or repack automatically inside the burn action;
- touch `bk-13-08-26/`;
- claim cold boot, BLE, or visual PASS;
- stage/commit/push unrelated files;
- use SmartSnippets GUI as a fallback if CLI fails.

## Owner Gates

Owner still controls:

- the exact packed BIN selected for burn;
- the explicit destructive confirmation token;
- final GitHub merge;
- cold boot validation;
- BLE validation;
- physical e-ink visual validation.

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
