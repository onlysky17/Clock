# NEXT_ACTION

## Canonical Current State

- Repository: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- TASK D17A unified daily update policy: CLOSED / MERGED.
- TASK D17B unified daily update implementation: CLOSED / MERGED / OWNER WEB+BLE PASS.
- D17B feature commit: `692f76cedc90545e4b7e6f6bacdf8b7c03ddb1da`.
- PR #100 merge commit: `cad429364f72589bf2ace07a6223ad3700112e2a`.
- Product Mode now provides one guarded `Cập nhật màn hình hôm nay` flow.
- Google Calendar is optional and is skipped without forcing login when authorization is absent.
- D17B changed only the web and its smoke; firmware, protocol, `test.html`, BIN, build, pack, flash, and SPI state were unchanged.

## Next Canonical Action

`TASK D18A - AGENDA FIRMWARE SPI FINAL AUDIT`

Owner-visible goal:

- Confirm the merged agenda-capable firmware source is the exact canonical baseline.
- Produce fresh build and size evidence before any persistent SPI package is prepared.
- Preserve the validated daily layout, weather row, Google agenda rows, D2 time flow, scheduler, and first-refresh recovery.
- Keep the canonical web URL unchanged.

Audit gates:

1. Start from clean `main` with `HEAD == origin/main`.
2. Confirm all required agenda renderer and protocol commits are in history.
3. Bootstrap canonical source to the SDK and verify source parity.
4. Run existing firmware and agenda smoke checks.
5. Rebuild Keil only after source and size audit passes.
6. Require 0 errors, 0 warnings, and raw BIN below the packer limit.
7. Do not pack or Burn SPI before Owner approves the measured build.
8. Do not commit BIN, AXF, MAP, SDK output, or `_incoming` artifacts.

## Expected Scope

- Audit and evidence first.
- No feature implementation is authorized by this closeout.
- Exact D18A tracked files must be defined when that task starts.
