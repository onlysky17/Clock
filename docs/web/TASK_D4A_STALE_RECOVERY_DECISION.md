# TASK D4A - Stale Recovery UX Decision

## Scope

- Repo: `D:\EINK\Clock`
- Canonical web: `https://onlysky17.github.io/Clock/test.html`
- This is a product decision record only.
- No firmware change.
- No web implementation in D4A.
- No new command or protocol.

## Owner Decision

Owner approved Option B: Web recovery CTA.

When D2 status has `flags & 0x80`, web must interpret it as `STALE_PRESENT`.

The web must show this exact warning:

`Thiết bị đang giữ giờ cũ. Hãy đồng bộ giờ hiện tại để tiếp tục chạy đồng hồ.`

The web must show this exact CTA:

`Đồng bộ giờ hiện tại`

The web must not automatically send `SET_TIME`. The user must explicitly press the CTA.

When stale is present, the web must lock the action:

`Vẽ giờ từ thiết bị lên màn`

After `SET_TIME` succeeds, the web must:

1. Read D2 status again.
2. Confirm the stale flag is cleared.
3. Hide the warning.
4. Re-enable render from device.

## Implementation Boundary

D4A does not implement the decision. The implementation task is:

`TASK D4B - implement web stale recovery CTA`

D4B should use the existing D2 `SET_TIME` flow. It must not change firmware and must not add a command or protocol.

Expected D4B scope:

- Canonical web implementation.
- Web-only smoke/validation.
- Closeout doc.

BLE physical validation remains an Owner phone test at:

`https://onlysky17.github.io/Clock/test.html`
