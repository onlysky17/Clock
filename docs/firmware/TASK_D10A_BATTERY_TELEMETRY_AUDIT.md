# TASK D10A - Battery Telemetry Audit

## Scope

- Workspace: `D:\EINK\Clock`.
- Audit only: no firmware, web, BLE database, build, pack, or flash changes.
- Current persistent baseline: `TASK D9B`.
- Baseline raw BIN: `47924` bytes.
- Packer raw limit: `65528` bytes.
- Available headroom: `17604` bytes.

## Owner Goal

Expose a real device battery reading in Product Mode without inventing a percentage, changing the D2 protocol, or adding periodic flash/EPD work.

The first implementation should report measured millivolts and an explicitly estimated CR2032 percentage. A battery icon on the e-ink panel is deferred until the measurement is physically calibrated.

## Existing Hardware And SDK Path

The DA14585 build already contains the supported internal VBAT ADC path:

- `adc_offset_calibrate(ADC_INPUT_MODE_SINGLE_ENDED)` performs offset calibration.
- `adc_get_vbat_sample(false)` selects the DA14585 VBAT3V measurement path.
- `adc_disable()` is called by the SDK helper before returning.
- The project already compiles `adc_58x.c` and `battery.c`.

The latest Keil map proves these ADC symbols are already linked:

- `adc_init`: 96 bytes.
- `adc_get_sample`: 32 bytes.
- `adc_get_vbat_sample`: 88 bytes.
- `adc_offset_calibrate`: 152 bytes.
- `adc_disable`: 8 bytes.

This means D10B does not need a new ADC driver, timer, task, or hardware pin.

## Current Product State

Battery telemetry is not live today.

- `adc1_update()` in `user_custs1_impl.c` is a four-byte stub that returns `0`.
- Global `adcval` therefore does not receive a fresh VBAT sample from that function.
- The old `batt_cal()` CR2032 curve remains in source, with anchors `1136`, `1360`, `1584`, and `1705`, but it belongs to the legacy drawing path.
- The old battery icon is not part of the current D9 flagship renderer and must not be presented as live telemetry.
- Standard Dialog Battery Service support is disabled by `EXCLUDE_DLG_BASS (1)`.

The original project implementation, removed during the D2B size trim, used:

```text
adc_offset_calibrate(ADC_INPUT_MODE_SINGLE_ENDED)
adcval = adc_get_vbat_sample(false)
millivolts = (adcval * 225) >> 7
```

That conversion maps the existing CR2032 full-scale anchor `1705` to approximately `2997 mV` and matches the historical web contract.

## Existing BLE Surface

The legacy custom service already exposes a suitable read-only characteristic:

- Service: `0xFF00`.
- Battery/ADC characteristic: `0xFF02`.
- Length: 2 bytes.
- Historical value format: unsigned millivolts, little-endian.

The characteristic exists in the active GATT database, but the current firmware does not populate it with a fresh sample. The current Product Mode requests only the HINK 128-bit service and does not read `0xFF02`.

The D2 packets have fixed live contracts:

- `D2 81` status is exactly 15 bytes.
- `D2 83` identity is exactly 16 bytes.

Extending either packet would break strict existing parsers. D10B must not append battery bytes to D2 status or identity.

## MVP Decision

Chosen MVP: **reuse `FF00 / FF02` as an on-demand read and keep D2 unchanged.**

Firmware behavior:

1. Mark `FF02` as an application-provided read value.
2. Route its `CUSTS1_VALUE_REQ_IND` in application context.
3. Calibrate and sample VBAT only for that read request.
4. Return exactly 2-byte little-endian millivolts.
5. Disable the ADC through the existing SDK helper before responding.

Web behavior:

1. Add `0xFF00` to `optionalServices` without changing the canonical URL.
2. Read `0xFF02` after BLE connection and from one explicit refresh control.
3. Display measured voltage, for example `2.97 V`.
4. Display battery percentage as `uoc tinh` using the existing CR2032 curve, never as a laboratory-accurate state of charge.
5. Treat missing `FF00/FF02` as `Khong ho tro`, not as a Product Mode error.

Rejected MVP paths:

- Do not enable the full standard Battery Service; it adds profile/database behavior that is unnecessary for this product page.
- Do not add `D2 04` or another command while a compatible read characteristic already exists.
- Do not extend `D2 81` or `D2 83`.
- Do not sample every minute or every five-minute render.
- Do not add a battery icon to the e-ink layout before calibration.

## Concurrency And Power Guards

- Sampling occurs only on an explicit GATT read in application context.
- No ADC work runs inside the EPD wait callback or the five-minute scheduler.
- No new periodic timer is added.
- No SPI/NVDS write is added.
- No framebuffer or layout change is added.
- A read failure returns an error/unsupported UI state and must not affect D2, EPD, BLE reconnect, or scheduler state.

## Calibration Gate

The SDK path and historical conversion prove how to obtain a real reading, but they do not prove board-level accuracy.

D10B physical validation must compare the reported millivolts against a known supply or multimeter at least once. Until that passes:

- voltage is a measured candidate;
- percentage is only an estimate;
- no low-battery shutdown policy is authorized;
- no e-ink battery icon is authorized.

## D10B Exact Proposed Scope

Maximum five files:

1. `firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`
2. `firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c`
3. `firmware/active/HINK213_CLOCK_22_BASE/src/custom_profile/user_custs1_def.c`
4. `web/clock-app/hl24a-canvas-e5.html`
5. `scripts/task-d10b-battery-telemetry-smoke.mjs`

Implementation budget:

- Firmware code increase: conservatively `<=350` bytes.
- RAM increase: `<=4` bytes.
- Raw BIN target: `<58000` bytes and `<65528` bytes.
- No new dependency, service, command, timer, table, font, framebuffer, malloc, or debug string.

Required D10B gates:

- automated source/web smoke;
- desktop and mobile Product Mode browser proof;
- Keil `0 errors`, `0 warnings`;
- SysRAM BLE read and voltage sanity check;
- one Owner comparison against a known supply or multimeter;
- no SPI pack/Burn until physical PASS.
