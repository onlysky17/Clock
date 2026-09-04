# NEXT_ACTION

## Current Checkpoint — 2026-09-04 10:39 (+07)

`EINK-BW-RETAIN-MODE-CONNECT-REFRESH-001` has passed smoke, Keil build/pack,
SmartSnippets burn/verify, and Owner physical validation on
`task-d/eink-bw-retain-mode-connect-refresh`.

Validated product behavior:

- cold reboot keeps the retained uploaded image/mode;
- first BLE connection after cold boot settles for about two seconds;
- the panel then performs exactly one FULL refresh of that retained image;
- BLE remains connected through the refresh and stays stable;
- same-boot reconnect does not repeat the forced refresh;
- disconnect still preserves the image.

Harness remains FROZEN. Do not start new Harness work for this closeout.

## Next Canonical Action

1. Open/complete the closeout PR for
   `EINK-BW-RETAIN-MODE-CONNECT-REFRESH-001`.
2. Owner performs the final merge gate.
3. After merge, sync `main` and verify local `HEAD == origin/main`.
4. Then start the next product milestone: **B/W Web user-ready**.
5. EINK 3-color follows after the B/W Web milestone.

No additional firmware burn or physical test is required for this task unless
the branch changes before merge or a merge regression is introduced.

---

## Current Checkpoint â€” 2026-08-21

Portrait Analog v2 and Harness SHA compatibility are merged into `main`.

Current main:

`0a8387ccc75456da37f60f79561e1f403b00af42`

PR #157:

`feat: add EINK portrait analog calendar`

Actual main commit:

`30c9efc4d2ad5e95f28147e99fc6b501358c93c5`

Owner physical Portrait Analog v2 test: PASS.

PR #158:

`fix: make EINK SHA verification PowerShell-compatible`

Actual main commit:

`0a8387ccc75456da37f60f79561e1f403b00af42`

Harness prepare-test smoke and real prepare-test: PASS.

The canonical Clock Classic product baseline is now:

- portrait `122 x 250`
- `ROTATE_0`
- analog clock
- solar date
- lunar date
- 36 deterministic daily sayings
- no large digital HH:MM
- no title
- no ordinary-minute display refresh
- FULL refresh at local wall-clock `00/05/10/15/20/25/30/35/40/45/50/55`

Weekly remains unchanged with `ROTATE_3 + UPDATE_FLY`.

## Next Canonical Action

UNRESOLVED - waiting for the Owner to select the next product/firmware feature.
Possible future product work is not canonical until explicitly selected by the
Owner.

In particular:

- weather on the portrait lower area would require a separate
  web/phone -> BLE -> firmware data pipeline;
- one-minute analog hand movement would require a separately scoped refresh
  experiment;
- rejected V1-V6 local/partial refresh approaches must not be silently reused.

For the next firmware/layout implementation, use:

`.\scripts\eink.ps1 prepare-test`

after source validation.

The Harness must automatically build, pack, validate, lock the candidate
artifact, and stop before destructive burn.

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
- cold boot/device interaction where required;
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
- weaken fresh backup, packed SHA, readback SHA, cold-boot, BLE, or physical
  visual gates.
