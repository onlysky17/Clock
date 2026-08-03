# NEXT_ACTION

## Canonical Current State

- Repository: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- D21B Product Mode recovery is implemented and merged.
- PRs #116 through #123 restored the Product Mode controls after browser-side
  regressions.
- PR #123 merge commit:
  `7c9795465f14734ccd75d2b47561231027cfd0a9`.
- Connect/disconnect, identity and battery, profile selection and apply,
  primary daily update, and the independent Advanced section are present.
- Advanced remains closed by default.
- Post-merge D21B smoke: PASS.

## Next Canonical Action

`TASK D22A - PRODUCT MODE BROWSER RUNTIME REGRESSION GATE`

Owner-visible goal:

- Add deterministic desktop and mobile browser checks for the canonical
  Product Mode page.
- Verify the connect action remains visible and starts Web Bluetooth directly
  from the Owner's click.
- After a mocked BLE connection, verify identity, battery, profiles, apply,
  primary daily update, and Advanced controls are rendered and usable.
- Verify Advanced opens independently and remains closed by default.
- Preserve D21B weather, disconnect, BUSY, one-render, and recovery behavior.

D22A is an automated web regression task. It must not change firmware, BLE
protocol, `test.html`, BIN, Keil output, pack, flash, or physical-device state.
