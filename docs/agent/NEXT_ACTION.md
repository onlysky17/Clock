# NEXT_ACTION

## Current Checkpoint

- Repository: `D:\EINK\Clock`.
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`.
- EINK Harness v0.5 task branch: `task-d/eink-harness-v0.5-spi-burn`.
- Runtime-tested head before final docs: `a2b5f4465f2d454134bc3800ba302f0d4f82ec03`.
- Base main after v0.4 closeout: `b7ba809fc2a4cda94c2c3ece5461aa6965c7c899`.
- Harness v0.5 guarded SPI burn + full readback verify is real-hardware PASS.
- Proven validation evidence:
  - smoke PASS 15/15;
  - Owner-selected packed BIN `D:\EINK\Clock\_incoming\HINK213_CLOCK_BOARD1_20260813.bin`;
  - packed size `262144` bytes;
  - packed SHA256 `871DD538DDD2749274C582223FC082DAE3D19C92F7F504197EB7086F3E06945F`;
  - fresh pre-burn backup PASS with two matching `262144`-byte reads;
  - fresh backup SHA256 `CE2D66AC3B08A7EC761F1C5C786064BA84F5C1FCB96E55E4A6146C3EF01C5E63`;
  - real burn process exit code `0`;
  - readback size `262144` bytes;
  - readback SHA256 `871DD538DDD2749274C582223FC082DAE3D19C92F7F504197EB7086F3E06945F`;
  - packed/readback SHA256 equality PASS;
  - `NEXT_STATE: SPI_BURN_VERIFIED`.
- Burn evidence directory: `D:\EINK\Clock\_incoming\EINK_HARNESS_SPI_BURN\20260815_091014`.
- Closeout details: `docs/agent/EINK_HARNESS_V0.5_CLOSEOUT.md`.
- `bk-13-08-26/` remained untracked and untouched.
- v0.5 does not establish cold boot, BLE, or physical e-ink visual PASS.

## Next Canonical Action

`EINK HARNESS v0.6 - COLD-BOOT + DEVICE VALIDATION ORCHESTRATION`

Goal: reduce the remaining post-flash Owner workflow to the smallest safe set by orchestrating cold-boot, BLE, and physical/device evidence without falsely automating gates that require the real board/phone/Owner judgement.

Required behavior:

- verify canonical workspace/project/branch/HEAD/status before device work;
- require a prior `SPI_BURN_VERIFIED` evidence directory as input/reference;
- clearly separate automatic machine-checkable gates from Owner/device gates;
- provide one guided run that records cold-boot evidence, BLE connection evidence, and physical e-ink visual evidence into one task evidence directory;
- never claim cold boot, BLE, or visual PASS without corresponding runtime/device/Owner evidence;
- preserve the existing canonical web URL and phone-based Web Bluetooth workflow;
- keep `bk-13-08-26/` untouched;
- include closeout/state updates in the same task branch before the one final PR.

## Hard Scope Boundary

Do not:

- change firmware source unless a separate task explicitly requires it;
- rebuild/repack/reburn as part of v0.6 unless validation proves the flashed image is bad and Owner starts a separate corrective task;
- use SmartSnippets GUI as an automatic fallback;
- claim visual PASS from logs/screenshots alone without Owner approval;
- stage/commit/push unrelated files.

## Owner Gates

Owner still controls:

- actual power-cycle/cold-boot observation when physical intervention is required;
- phone/Web Bluetooth connection where PC BLE is unavailable;
- physical e-ink visual PASS;
- final GitHub merge.

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
