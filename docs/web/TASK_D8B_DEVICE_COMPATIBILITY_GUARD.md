# TASK D8B - Device Compatibility Guard

## Goal

Use the D8A identity response to prevent Product Mode from syncing or rendering through an unexpected firmware build.

Canonical URL remains:

`https://onlysky17.github.io/Clock/test.html`

## Expected Identity

- Runtime firmware: `D8A1`
- Source ID: `D8A00001`
- Web build: `D8B-COMPAT-20260722`

The web reads these values from the existing D2 `03` / D2 `83` identity exchange. No BLE command, UUID, packet length, firmware, scheduler, or panel behavior changes.

## Product Behavior

- Disconnected: `Chưa kết nối`.
- Connected before identity arrives: `Đang kiểm tra`.
- Exact runtime and source match: `Tương thích`.
- Runtime or source mismatch: `Sai firmware`.
- Identity command unsupported or rejected: `Không hỗ trợ`.

Product sync, time sync, stale recovery, and device render actions remain disabled until identity is compatible. The manual identity query and advanced technical controls remain available for diagnosis and recovery.

## Guards

- D6B Product Mode state mapping remains active.
- D8A health display remains active.
- A normal disconnect resets compatibility to `Chưa kết nối`.
- A successful re-read of the expected identity clears the compatibility block.
- `test.html` and the canonical URL are unchanged.
- No firmware or protocol file is modified.

## Validation

Run:

`node .\scripts\task-d8b-device-compatibility-guard-smoke.mjs`

Browser proof is written only under:

`D:\EINK\Clock\_incoming\D8B_COMPATIBILITY_GUARD_PROOF`
