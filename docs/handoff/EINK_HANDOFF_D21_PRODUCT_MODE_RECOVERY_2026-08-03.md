# EINK Clock D21 Product Mode Recovery Handoff

Date: 2026-08-03

This file is the resume contract for the next Codex task. Read it before
changing any source. It exists to preserve the validated Product Mode baseline
when a task is interrupted, compacted, or continued in another chat.

## Authoritative Baseline

- Repository: `D:\EINK\Clock`
- Branch at handoff: `main`
- PR #124 closeout merge:
  `b7dd5d9096afdc7007e790405ae2bf353be04694`
- PR #124 feature commit:
  `cc1bc0d6f04f92ad6211bbf3f640dc2f4225ffe1`
- PR #123 runtime recovery merge:
  `7c9795465f14734ccd75d2b47561231027cfd0a9`
- Canonical URL: `https://onlysky17.github.io/Clock/test.html`

PR #124 is a docs-only closeout. It did not change Product Mode runtime,
firmware, BLE protocol, `test.html`, BIN, build output, pack, flash, or device
state.

## Validated Product Mode Baseline

The following controls and behavior have been restored and must remain:

- Connect and disconnect controls.
- Device identity and battery information.
- Clock-face profile selection and apply controls.
- One primary daily-update action.
- An independent Advanced section that is closed by default.
- Weather failure degrades safely without blocking the rest of the update.
- Disconnect cancels the active operation immediately.
- BUSY recovery is bounded and cannot retry forever.
- A successful request produces one physical render.
- A later successful request clears stale or error state.

Clean-main validation at this handoff:

- `node scripts/task-d21b-product-mode-daily-update-resilience-smoke.mjs`:
  PASS.
- `git diff --check`: PASS.
- `tools/eink-auto-preflight.ps1`: PASS.

## Do Not Regress

- Do not simplify, replace, or rewrite the current Product Mode.
- Do not remove restored device controls.
- Do not merge Advanced controls into the primary daily-update flow.
- Do not alter firmware, SDK, BLE protocol, or `test.html` for D22A.
- Do not edit historical smoke scripts to bypass a dirty-file guard.
- Do not commit BIN, AXF, MAP, SDK output, `_incoming`, or proof screenshots.
- Do not chain another feature automatically after finishing D22A.

## Required Resume Gate

1. Confirm repo root is exactly `D:\EINK\Clock`.
2. Read `AGENTS.md`, this file, `docs/agent/CURRENT_STATE.md`, and
   `docs/agent/NEXT_ACTION.md`.
3. Switch to `main`, fetch, and fast-forward from `origin/main`.
4. Confirm `HEAD == origin/main` and the working tree is clean.
5. Run `tools/eink-auto-preflight.ps1`.
6. Stop immediately if any gate fails. Do not repair by reset, checkout, or
   broad file replacement.

On this Windows machine, normal Git fetch can fail with Schannel error
`SEC_E_NO_CREDENTIALS`. A one-command fallback that was proven for reading the
remote is:

```powershell
git -c http.sslBackend=openssl fetch origin
```

Do not change repository-wide SSL settings for this workaround.

## Next Task Only

`TASK D22A - PRODUCT MODE BROWSER RUNTIME REGRESSION GATE`

Goal: add deterministic automated browser coverage for the already restored
Product Mode. This is a regression gate, not a redesign.

Required coverage:

- Desktop and 360 px mobile viewports.
- Initial Product Mode controls are visible.
- Connect starts Web Bluetooth directly from the Owner click.
- Mocked connected state exposes identity, battery, profiles, apply, primary
  daily update, and Advanced controls.
- Advanced starts closed, opens independently, and does not hide primary
  controls.
- No horizontal overflow.
- D21B weather, disconnect, BUSY, one-render, and recovery behavior remains.
- Browser proof stays under `D:\EINK\Clock\_incoming` and is not committed.

D22A scope is web test/runtime regression only. No firmware build, Keil, pack,
flash, physical test, protocol change, or `test.html` change is required.

## Interruption And Quota Protocol

- Work on one narrow task at a time.
- Never leave `main` dirty.
- Use a task branch and stage exact files; never use `git add .`.
- Run the requested validation before commit and push.
- Update the handoff before quota exhaustion if required work remains.
- Stop after the branch and PR are ready; the Owner performs merge.
- After an Owner merge, sync clean `main` before choosing another task.
- Do not infer or start a new feature merely because the previous PR merged.
