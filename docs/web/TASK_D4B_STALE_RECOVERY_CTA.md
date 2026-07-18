# TASK D4B - Stale Recovery CTA

## Scope

- Canonical URL: `https://onlysky17.github.io/Clock/test.html`
- Canonical implementation: `web/clock-app/hl24a-canvas-e5.html`
- Smoke: `scripts/task-d4b-stale-recovery-cta-smoke.mjs`
- No firmware change.
- No protocol or BLE command change.
- No historical smoke script changes.

## Implemented UX

When D2 status has `flags & 0x80`, the web treats it as `STALE_PRESENT`.

The web shows this warning:

`Thiết bị đang giữ giờ cũ. Hãy đồng bộ giờ hiện tại để tiếp tục chạy đồng hồ.`

The web shows this CTA:

`Đồng bộ giờ hiện tại`

The web does not automatically send `SET_TIME`. The user must press the CTA.

While stale is present, the web disables:

`Vẽ giờ từ thiết bị lên màn`

The CTA uses the existing D2 `SET_TIME` flow. After `SET_TIME` succeeds, the web reads D2 status again. It hides the warning and re-enables render only after confirming `flags & 0x80` is clear.

If `SET_TIME` or the follow-up status read fails, the stale warning remains visible, render remains disabled, and the D2 status area shows the error.

## Recovery Notify Race Guard

The implementation keeps an explicit `d2StaleRecoveryPending` state while the recovery CTA is running.

During recovery pending, any D2 `SET_TIME` notify/status update is allowed to refresh the visible status fields, but it cannot clear the stale warning or re-enable render. Recovery only completes after the follow-up `GET_STATUS` response is processed with recovery confirmation and `flags & 0x80` is clear.

If `SET_TIME`, follow-up `GET_STATUS`, timeout, or a still-stale follow-up status fails recovery, the pending state is cleared but `STALE_PRESENT` remains visible and render remains disabled.

## Validation

Run:

`node .\scripts\task-d4b-stale-recovery-cta-smoke.mjs`

Expected result:

`TASK D4B stale recovery CTA smoke PASS`

## Owner Phone Test

BLE physical validation remains an Owner phone test at:

`https://onlysky17.github.io/Clock/test.html`
