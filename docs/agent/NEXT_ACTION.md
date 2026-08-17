# NEXT_ACTION

## Current Checkpoint — 2026-08-17

`FW-AUTONOMOUS-CLOCK-001` is implementation-complete and real-device HARDWARE PASS on Board #1.

Proven firmware artifact:

- Branch: `task-d/fw-autonomous-clock-ble-disconnect-001`
- Firmware source change: `firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c`
- Raw build size: `50568` bytes
- Raw SHA256: `C044F1182ECDBE9BE37437025886A63D9B1DB9110CBF9B0354BBA496E9DBD9DE`
- Packed local image: `D:\EINK\Clock\_incoming\FW_AUTONOMOUS_CLOCK_001.bin`
- Packed size: `262144` bytes
- Packed SHA256: `010DEBE2949F035F1D59A01EF365EF28E25737C0700DFEFEEE2CCC40A4C7052B`
- Full SPI readback SHA256: same exact packed SHA
- Burn evidence: `D:\EINK\Clock\_incoming\EINK_HARNESS_SPI_BURN\20260817_140410`
- Full power-cycle: PASS
- BLE reconnect after power-cycle: PASS
- Connected one-minute baseline refresh: PASS
- BLE explicit disconnect: PASS
- Autonomous post-disconnect refresh continued from `14:29` through `14:36`, exceeding the required three consecutive intervals
- Owner hardware gate: PASS
- Detailed closeout: `docs/agent/FW_AUTONOMOUS_CLOCK_001_CLOSEOUT.md`

## Immediate Action

Finish this firmware milestone with exactly one final PR and one Owner merge gate. Do not mix the premium web UI work or Harness v0.7 changes into this PR.

After Owner merges the firmware PR:

1. Sync local `main` and verify local `HEAD == origin/main` using the actual merge commit.
2. Resume `EINK HARNESS v0.7 - ONE-COMMAND RELEASE VALIDATION PIPELINE` on its own branch.
3. Keep the separate premium web UI branch `task-d/eink-web-premium-ui-v1` isolated for Owner visual review. Its planned clock card may use a dark rounded card with a large digital time on the left and an analog clock on the right, but it must not alter the already-proven firmware behavior.

## Remaining Harness v0.7 Work

- Fix the two false smoke failures around the non-destructive build reproducibility checker.
- Run/retrieve the build reproducibility checker and diagnose the observed build nondeterminism.
- Strengthen direct SPI-burn input-path guards: require workspace `_incoming`, reject `bk-13-08-26`, reject Git-tracked packed BINs, and enforce robust full-path boundaries.
- Reconcile the interrupted formal release evidence for the already-proven F5E artifact without re-burning or repeating valid hardware tests.
- Keep one complete milestone branch and one final PR only.

## Hard Scope Boundary

Do not:

- re-burn or repeat hardware validation for the already-proven autonomous-clock artifact unless the firmware/BIN changes;
- commit BIN/build output;
- mix firmware, Harness v0.7, and premium web UI into one PR;
- use SmartSnippets GUI fallback;
- weaken packed SHA, backup, destructive confirmation, full readback SHA, power-cycle, BLE, or physical validation gates;
- auto-merge any PR.

## Workflow Contract

Each milestone remains:

- implementation;
- machine validation;
- real hardware/device evidence where applicable;
- closeout docs and next-action state in the same branch;
- one final PR;
- one Owner merge gate.
