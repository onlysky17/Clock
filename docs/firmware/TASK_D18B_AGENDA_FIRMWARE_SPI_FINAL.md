# TASK D18B - Agenda Firmware SPI Final

## Status

`READY FOR OWNER SPI PHYSICAL GATE - NOT YET BURNED`

D18B rebuilt the merged agenda firmware from the canonical source and prepared
a verified 256 KB SPI package. No firmware, web, BLE protocol, packer, or
canonical URL behavior changed in this task.

## Baseline

- D18A merge/main commit:
  `5f037aee90d539c146c8bc7f6db85af003d8a029`.
- Agenda-on-device implementation lineage: `91e86be`.
- Branch: `task-d/d18b-agenda-firmware-spi-final`.
- Canonical source:
  `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`.
- SDK project:
  `D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE`.
- Canonical URL:
  `https://onlysky17.github.io/Clock/test.html`.

## Canonical To SDK Parity

The existing bootstrap tool copied canonical source into the SDK project.

- Canonical files: `32`.
- SDK files: `32`.
- Differences: `0`.
- Canonical `user_custs1_impl.c` SHA256:
  `808B5CFA92A0CDF2F4D0B3C72FDF65FFCE4841CED14A03E66CF6EFDC30EEDE01`.
- SDK `user_custs1_impl.c` SHA256:
  `808B5CFA92A0CDF2F4D0B3C72FDF65FFCE4841CED14A03E66CF6EFDC30EEDE01`.

## Fresh Keil Build

- Target: `DA14585`.
- Compiler: `ARMCLANG 6.24`.
- Build timestamp: `2026-07-28 16:11:53` local time.
- Code: `45232`.
- RO-data: `3632`.
- RW-data: `552`.
- ZI-data: `22956`.
- Result: `0 errors`, `0 warnings`.
- Raw BIN size: `50552` bytes.
- Packer limit: `65528` bytes.
- Headroom: `14976` bytes.
- Raw BIN SHA256:
  `586DB6FFFAD3B5121982B291E9A32032C73C1878DF199872C414E69C7C434063`.
- AXF size: `572784` bytes.
- AXF SHA256:
  `38F0A74BBDE610F6FCB45A6BBA04C49A68890970693C0D93E32DB40DD51BA5FA`.
- Legacy font symbols: absent from fresh map/symbol evidence.

## SPI Package

Package:

`D:\EINK\Clock\_incoming\D18B_AGENDA_SPI_FINAL_20260728_161153`

Packed image:

`D18B_FINAL_PACKED_256KB.bin`

- Packed size: `262144` bytes.
- Packed SHA256:
  `5790AA976BBC7A57DF63873DCE192F57C606B63A10EDBBD4FFCEE52F9D15F44A`.
- Raw CRC32: `C7ADE738`.
- Golden size: `262144` bytes.
- Golden SHA256:
  `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`.
- Layout:
  `7050@00000 7051@04000 PAYLOAD@04040 7052@38000`.
- Package verify: `PASS`.
- Package smoke: `PASS`.

The package contains the fresh raw BIN and AXF, the verified packed image,
the canonical golden base, a SHA256 manifest, a package verifier, and the
Owner SPI Burn checklist. None of these artifacts are tracked by Git.

## Owner Gate

D18B stops before SPI Burn. The Owner gate is:

1. Burn the packed 256 KB image.
2. Require SPI Verify PASS.
3. Require cold-boot BLE scan/connect PASS.
4. Run the unified daily update at the canonical URL.
5. Confirm time, optional weather, and up to two agenda rows on the Summary
   profile.
6. Confirm disconnected five-minute refresh, BLE reconnect, no duplicate
   refresh, and no second black refresh.

Only after that physical gate passes may D18B be closed.
