# FW-AUTONOMOUS-CLOCK-001 Closeout

## Status

`FW-AUTONOMOUS-CLOCK-001` is implementation-complete and real-device hardware PASS on Board #1.

Goal: BLE is used for sync/config/data transfer only. After time and cadence are configured, disconnecting BLE must not stop the device-side periodic clock refresh.

## Scope

Firmware-only behavior change:

- `firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c`

No web runtime, BLE command format, panel geometry, packer format, or persistent SPI layout was changed.

## Implementation

When the D2 dedicated clock is active, `user_app_adv_start()` now starts continuous connectable advertising with `app_easy_gap_undirected_advertise_start()` instead of timed advertising with `app_easy_gap_undirected_advertise_with_timeout_start(...)`.

The non-D2 path keeps the existing timed-advertising behavior.

The source-level failure mechanism addressed is timer-resource interaction after BLE disconnect: timed advertising consumes an `app_easy_timer` while the D2 clock already owns a periodic minute timer. The exact historical root cause was not independently instrumented, so this remains the source-based failure hypothesis; the required product behavior is proven by real-device validation below.

## Build Evidence

Canonical Keil build after the fix:

- Build: PASS
- Raw BIN size: `50568` bytes
- Raw SHA256: `C044F1182ECDBE9BE37437025886A63D9B1DB9110CBF9B0354BBA496E9DBD9DE`

Packed test image:

- Local path: `D:\EINK\Clock\_incoming\FW_AUTONOMOUS_CLOCK_001.bin`
- Packed size: `262144` bytes
- Raw CRC32: `ED349E54`
- Packed SHA256: `010DEBE2949F035F1D59A01EF365EF28E25737C0700DFEFEEE2CCC40A4C7052B`
- Header/layout verification: PASS
- No BIN is committed to Git.

## SPI Burn And Readback Evidence

Owner explicitly approved destructive burn for the exact packed SHA above.

Final burn evidence:

- Evidence directory: `D:\EINK\Clock\_incoming\EINK_HARNESS_SPI_BURN\20260817_140410`
- Written size: `262144` bytes
- Full SPI readback size: `262144` bytes
- Full SPI readback SHA256: `010DEBE2949F035F1D59A01EF365EF28E25737C0700DFEFEEE2CCC40A4C7052B`
- Result: `SPI_BURN_VERIFIED`

## Real-Device Acceptance

Owner performed the hardware gate on Board #1 on 2026-08-17:

1. Powered the board fully OFF, waited at least five seconds, then powered it ON.
2. Reconnected from the phone using Web Bluetooth: PASS.
3. Synced current device time: PASS.
4. Set the periodic refresh cadence to one minute: PASS.
5. While BLE remained connected, the e-ink panel autonomously refreshed to `14:29`: baseline PASS.
6. BLE was then explicitly disconnected while the board remained powered.
7. Without reconnecting BLE or triggering a web render, the device continued autonomous periodic refreshes through `14:36`.
8. This exceeds the acceptance requirement of at least three consecutive post-disconnect refresh intervals.

Result:

`FW-AUTONOMOUS-CLOCK-001: HARDWARE PASS`

The proven product behavior is now: disconnecting BLE does not stop the configured device-side periodic clock refresh.

## Final Task State

- Firmware implementation: PASS
- Keil build: PASS
- Pack/header/layout verification: PASS
- Guarded SPI burn: PASS
- Full readback SHA verification: PASS
- Full power-cycle: PASS
- BLE reconnect after power-cycle: PASS
- Connected one-minute baseline refresh: PASS
- BLE disconnect: PASS
- Three-or-more autonomous post-disconnect refresh intervals: PASS
- Owner hardware gate: PASS
- Final PR: pending Owner merge gate
