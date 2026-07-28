# TASK D18A - Agenda Firmware SPI Final Audit

## Status

`AUDIT PASS / READY FOR D18B FRESH BUILD`

D18A is audit-only. It does not change firmware, web behavior, BLE protocol,
packer behavior, or physical-device state. No BIN was created, packed, burned,
or committed.

## Merged Baseline

- Audited `main` HEAD: `af6568912d5e4b3e1755bd11b441bae60eec2bee`.
- Agenda-on-device implementation: `91e86be`.
- Canonical source:
  `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`.
- SDK project:
  `D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE`.
- Canonical URL remains:
  `https://onlysky17.github.io/Clock/test.html`.

The merged firmware contains:

- two bounded agenda entries in RAM;
- minute and three-character label storage;
- the D2 daily-data handler;
- the daily briefing renderer used by the Summary profile;
- Vietnamese weather row offset `HINK_D13D_WEATHER_X = 6U`;
- first-refresh recovery `HINK_EPD_PRIME_RECOVERY_TICKS = 100UL`.

## Existing Build Evidence

The latest SDK output is useful as size evidence only. It is not approved as
the final D18B package input.

- Target: `DA14585`.
- Compiler: `ARMCLANG 6.24`.
- Code: `45232`.
- RO-data: `3632`.
- RW-data: `552`.
- ZI-data: `22956`.
- Result: `0 errors`, `0 warnings`.
- Raw BIN size: `50552` bytes.
- Packer gate: `65528` bytes.
- Measured headroom: `14976` bytes.
- Raw BIN SHA256:
  `D3678620B265DA7246964B2AB528609D9EE161CD3FE1146E36FC54DD96FF53B0`.
- AXF size: `572784` bytes.
- AXF SHA256:
  `A11186ABC55173037011CA1D6D29D29BE278CCC1A219B52D09710FFA891FD11B`.
- Build timestamp: `2026-07-27 14:18:39` local time.

Legacy font symbols remain absent from the current map/symbol evidence.

## Canonical To SDK Audit

`src\user_custs1_impl.c` was compared between canonical source and the SDK
copy.

- Canonical SHA256:
  `808B5CFA92A0CDF2F4D0B3C72FDF65FFCE4841CED14A03E66CF6EFDC30EEDE01`.
- SDK SHA256:
  `012B4A465ECCE86CA80F5E575BE30492AC50FB455AEC2F8A0318083CE50A9197`.
- Semantic diff: empty.
- Exact byte parity: not proven, consistent with line-ending/copy-state
  differences.

Therefore the existing SDK BIN must not be promoted to the final SPI package.
D18B must bootstrap canonical source into the SDK, prove exact parity, and
perform a fresh Keil rebuild.

## Golden And Packer Audit

Canonical golden:

`D:\EINK\Clock\tools\packages\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin`

- Size: `262144` bytes.
- SHA256:
  `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`.

`tools\pack-hink.ps1` retains the proven layout:

- flash size: `0x40000`;
- image header: `0x04000`;
- payload: `0x04040`;
- product header: `0x38000`;
- maximum raw payload: `0x10000`;
- golden structural/header/CRC validation remains enabled.

No packed D18 image exists yet.

## Historical Smoke Note

Some older milestone smokes assert task-specific web labels that have since
been superseded by D17. Their failure is stale-label evidence, not proof of an
agenda firmware regression. D18A does not weaken or edit historical smokes.

The D18A smoke instead checks the current firmware agenda blocks, recovery and
weather constants, packer layout, golden hash, audit evidence, and Git scope.

## D18B Gate

Next canonical action:

`TASK D18B - BUILD AND PACKAGE AGENDA FIRMWARE SPI FINAL`

D18B must:

1. bootstrap canonical source with the existing Clock tool;
2. prove exact canonical-to-SDK parity;
3. rebuild the `DA14585` target in Keil with `0 errors` and `0 warnings`;
4. record fresh Code/RO/RW/ZI, AXF and raw BIN hashes;
5. require raw BIN below `65528` bytes;
6. confirm agenda symbols are present and legacy font symbols remain absent;
7. pack with the verified canonical golden into exactly `262144` bytes;
8. create manifest and package verification scripts under `_incoming`;
9. stop for Owner SPI Burn/Verify/cold-boot and physical agenda validation;
10. never commit BIN, AXF, map, build output, or `_incoming`.
