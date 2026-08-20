# NEXT_ACTION

## Current Checkpoint — 2026-08-20

EINK Harness v0.7 is MERGED and post-merge proven on canonical `main`.

- Main commit:
  `4bbc64f0c5d6d7697b2bc6d17a10ecf1d04124bd`
- PR #153: merged
- `prepare-test`: smoke PASS
- real Keil build: PASS
- full SPI pack validation: PASS
- raw payload byte match: PASS
- destructive burn during harness proof: NOT PERFORMED

Display Profiles v2 is also merged and Owner-approved.

- PR #152 merge:
  `4ac1d0d120a5486861a867adcd0f28c2fbab8882`
- Clock Classic physical visual: PASS
- Weekly 7-day profile: PASS
- Mobile Preview Studio: PASS
- Fixed Preview URL:
  `https://onlysky17.github.io/Clock/preview/test.html`

Fixed Pages preview infrastructure is merged through PR #151.

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