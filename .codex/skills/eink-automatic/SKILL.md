# EINK Automatic Workflow

Use this skill for EINK Clock firmware, web, or docs tasks in `D:\EINK\Clock`.

## Start Every Task With The Gate

1. Run the workspace/preflight gate before editing:
   - `git rev-parse --show-toplevel`
   - `git branch --show-current`
   - `git rev-parse HEAD`
   - `git rev-parse origin/main`
   - `git status --short --untracked-files=all`
   - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\eink-auto-preflight.ps1`
2. Stop immediately if the repo is not `D:\EINK\Clock`, the Git state is unsafe, the canonical source/SDK paths are missing, or the tree is dirty.
3. Confirm exact scope before modifying files. Keep each task to the requested files only.

`-AllowDirty` is only for creating/reviewing this foundation set or for an explicit Owner-approved exception. Normal firmware, web, docs, and smoke tasks must not use `-AllowDirty`.

## Implementation Rules

- Prefer the canonical source at `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`.
- Sync to the SDK project only when the task requires it:
  `D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE`.
- For web work, keep the canonical URL as `https://onlysky17.github.io/Clock/test.html`.
- Do not rewrite smoke history unless a smoke test fails because of the current code.
- Do not commit `.bin`, raw build output, packed images, Keil output, or generated firmware artifacts.
- Never use `git add .`; stage named files only.

## Firmware Build And Size Rules

- Use Keil GUI when CLI build is not available or not already proven in the local environment.
- Do not run a GUI build unless the task asks for it or Owner approves it.
- Firmware raw BIN must be less than or equal to `65528` bytes.
- After any firmware build, report:
  - Code
  - RO-data
  - RW-data
  - ZI-data
  - raw BIN size
  - raw headroom against `65528`

## Owner Gates

- Always stop for Owner before hardware test, flash, Burn SPI, board reset, or physical panel PASS.
- Do not claim hardware PASS from inference. PASS requires command output, a real test artifact, or explicit Owner evidence.
- After Owner PASS, closeout and commit are allowed only if the task requested them and the Git gate is clean for the intended files.

## Handoff Between Machines

Every handoff must include both:

- Git state: repo path, branch, HEAD SHA, upstream/base SHA, changed files, commit/PR status.
- Local dependencies not in Git: SDK path, SDK project path, Keil/tool availability, local firmware images under `_incoming`, generated raw/packed BIN paths and SHA256 values, and any local evidence files.
