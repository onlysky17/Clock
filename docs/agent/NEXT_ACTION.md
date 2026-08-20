# NEXT_ACTION

## Current Checkpoint — 2026-08-20

PR #155 `fix: align EINK full refresh to 5-minute wall clock` is MERGED and
Owner physical PASS.

- Actual main merge commit:
  `fbcc8562f678f7f6cf651c9f77e591e6b60b7be0`
- Feature commit:
  `d9d08c3354d0e5125afa36a580a6d0420928ae4c`
- Full refresh cadence:
  `00/05/10/15/20/25/30/35/40/45/50/55` local wall-clock minutes
- Classic / Weekly FLY refresh between maintenance boundaries: PASS
- Harness v0.7 `prepare-test`: PASS
- Packed size: `262144`
- Packed SHA256:
  `6B9FB8C6E7EE6D073350E99CBFE4C68CBC278D5A800A1083C39B80D968410D3E`
- Full SPI readback size: `262144`
- Full SPI readback SHA256:
  `6B9FB8C6E7EE6D073350E99CBFE4C68CBC278D5A800A1083C39B80D968410D3E`
- fresh SPI backup / erase / write / readback verification: PASS
- cold boot / runtime test: PASS
- Owner physical e-ink test: PASS

Harness v0.7 remains merged and operational as the canonical build / pack /
verify pipeline.

Display Profiles v2, Clock Classic, Weekly 7-day, Mobile Preview Studio, and
the fixed Pages preview infrastructure remain merged / approved.
## Next Canonical Action

UNRESOLVED — waiting for the Owner to select the next product/firmware feature.

The Harness itself is no longer the blocker.

For the next firmware/layout implementation, use:

`.\scripts\eink.ps1 prepare-test`

after source validation.

The Harness must automatically build, pack, validate, and lock the candidate artifact before requesting the Owner burn/test gate.

## Standing Execution Contract

Automatic:

- workspace verification;
- context loading;
- source implementation;
- static/machine validation;
- Keil build;
- SPI image packing;
- header / CRC / layout verification;
- raw payload byte verification;
- SHA256 locking;
- evidence/manifest generation;
- backup of validated PASS state;
- commit / push / PR preparation after PASS.

Owner gates:

- destructive SPI burn;
- cold boot;
- BLE/device interaction where required;
- physical e-ink visual approval;
- final merge.

Do not require repetitive Owner confirmation between normal PASS stages.

## Hard Safety Boundary

Do not:

- auto-burn hardware;
- claim physical PASS without Owner evidence;
- commit BIN/build output;
- touch `bk-13-08-26/`;
- use `git add .`, `git add -A`, or `git commit -a`;
- force-push;
- use SmartSnippets GUI fallback;
- weaken fresh backup, packed SHA, readback SHA, cold-boot, BLE, or physical visual gates.