# EINK Automation Mode

This mode lets Codex handle the repeatable local developer work for EINK Clock while keeping Owner approval for product and hardware risk.

## Roles

- ChatGPT = Architect/Reviewer. Defines task intent, reviews risk, checks outputs, and helps decide whether evidence is enough.
- Codex = Local Developer. Works in `D:\EINK\Clock`, edits scoped files, runs safe validation, prepares handoff notes, and reports exact evidence.
- Owner = Product + Hardware approval. Approves product behavior, runs phone Web Bluetooth checks, controls Keil GUI/build approval when needed, flashes hardware, resets boards, and confirms physical panel results.

## Codex May Do Automatically

- Run workspace and preflight gates.
- Create a task branch after the gate passes.
- Read only `docs/agent/CURRENT_STATE.md`, `docs/agent/NEXT_ACTION.md`, and directly relevant task files.
- Implement scoped firmware, web, docs, script, or smoke-test changes.
- Run lightweight local validation and at most one heavy validation requested by the task.
- Sync canonical source to the SDK only when the task explicitly requires it.
- Inspect build logs and report Code, RO-data, RW-data, ZI-data, raw size, and headroom when an approved build exists.
- Prepare commit, push, PR, and closeout steps after Owner review when the task asks for Git completion.

## Codex Must Wait For Owner

- Keil GUI build when CLI build is not available or not already approved.
- Flash, Burn SPI, board reset, power cycle, or any other physical device operation.
- Web Bluetooth testing, because the PC has no BLE and phone testing is required.
- Any claim of hardware PASS or physical display PASS.
- Committing after a task that requires Owner evidence, unless Owner has provided that PASS.
- Product behavior decisions that are not already specified by the task.

## Standard Flow

1. Open `D:\EINK\Clock`.
2. Run the workspace gate and `tools\eink-auto-preflight.ps1`.
3. Confirm exact scope, usually 3-5 files.
4. Create the task branch.
5. Implement only the scoped files.
6. Validate with task-requested commands; do not run Keil build unless requested or approved.
7. Report branch, changed files, validation output, Git status, and Owner review points.
8. Owner reviews and performs any required phone, flash, Burn SPI, reset, or panel test.
9. After Owner PASS, Codex may stage named files only, commit, push, and create a PR if the task requests it.
10. Owner merges the PR.
11. Codex syncs `main`, verifies clean state, writes closeout only if requested, and stops.

## Dirty Tree Exception

The normal workflow must not use `-AllowDirty`; preflight should fail on a dirty working tree. `tools\eink-auto-preflight.ps1 -AllowDirty` is allowed only while creating/reviewing this foundation set or when Owner explicitly approves a dirty-tree exception for a specific situation.

## Current Historical Note

D3E is not an open task. It was closed at commit `08447bf3d142cd9aa1c1314a5beb58559f46659c`.
