# NEXT_ACTION

## Current Checkpoint

- Repository: `D:\EINK\Clock`.
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`.
- EINK Harness v0.5 final PR #148 is merged.
- Actual v0.5 main merge commit: `4ff480b1e5ac83018e70cdba0c5d0aa0c04b5c0c`.
- EINK Harness v0.6 branch: `task-d/eink-harness-v0.6-device-validation`.
- Runtime-tested v0.6 head before final docs: `e333dbe371637cbae055c6ba662fc97d9a34bab8`.
- Harness v0.6 device validation is real-device PASS.
- Proven v0.6 evidence:
  - smoke PASS 13/13;
  - prior burn evidence directory `D:\EINK\Clock\_incoming\EINK_HARNESS_SPI_BURN\20260815_091014`;
  - cold boot PASS;
  - phone Web Bluetooth connection/device response PASS;
  - physical e-ink visual PASS by Owner;
  - device evidence directory `D:\EINK\Clock\_incoming\EINK_HARNESS_DEVICE_VALIDATION\20260815_095513`;
  - device evidence file `D:\EINK\Clock\_incoming\EINK_HARNESS_DEVICE_VALIDATION\20260815_095513\device-validation.txt`;
  - `NEXT_STATE: DEVICE_VALIDATION_VERIFIED`.
- Closeout details: `docs/agent/EINK_HARNESS_V0.6_CLOSEOUT.md`.
- `bk-13-08-26/` remained untracked and untouched.

## Current End-to-End Gate State

For the tested Board #1 image:

- Keil build: PASS.
- Full SPI backup: PASS.
- Guarded SPI burn: PASS.
- Full `0x40000` readback SHA verification: PASS.
- Cold boot: PASS.
- BLE connection/device response: PASS.
- Physical e-ink visual: PASS by Owner.

## Next Canonical Action

`EINK HARNESS v0.7 - ONE-COMMAND RELEASE VALIDATION PIPELINE`

Goal: compose the already-proven build, pack/input validation, backup, guarded burn, readback verification, and guided device validation into a single release-oriented Harness flow while preserving every destructive and Owner gate.

Required behavior:

- verify canonical workspace/project/branch/HEAD/status first;
- reuse the proven v0.3-v0.6 actions rather than duplicating hardware logic;
- provide a non-destructive Plan mode showing the exact image, hashes, required gates, and intended evidence locations;
- require explicit Owner selection of the packed image;
- require explicit destructive burn confirmation before any erase/write;
- stop on first failed gate; no automatic retry or alternate programmer path;
- after burn/readback PASS, guide the Owner through cold boot, BLE, and physical visual validation;
- produce one final release evidence summary linking build/burn/device evidence;
- keep `bk-13-08-26/` untouched;
- include implementation, runtime evidence, closeout, and next-action state in one task branch before one final PR.

## Hard Scope Boundary

Do not:

- change firmware behavior merely to build the pipeline;
- weaken or bypass packed SHA, backup, destructive confirmation, readback SHA, cold boot, BLE, or visual gates;
- use SmartSnippets GUI fallback;
- claim physical PASS without Owner approval;
- stage/commit/push unrelated files.

## Workflow Contract

Each Harness milestone is one complete task branch:

- implementation;
- machine validation;
- real hardware/device evidence where applicable;
- closeout docs;
- next-action state;
- one final PR;
- one Owner merge gate.

No separate closeout PR after the task PR is merged.
