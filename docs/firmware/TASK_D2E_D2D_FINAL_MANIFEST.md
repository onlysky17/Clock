# TASK D2E - D2D Final Persistent Firmware Manifest

## Canonical State

- Repo: `D:\EINK\Clock`
- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- Canonical web: `https://onlysky17.github.io/Clock/test.html`
- Required tools:
  - `tools\bootstrap-hink213-clock22-base.ps1`
  - `tools\sync-hink213-source.ps1`
  - `tools\pack-hink.ps1`

## Final Packed Image

- Filename: `TASK_D2D_FINAL_PACKED_256KB.bin`
- Local path: `D:\EINK\Clock\_incoming\TASK_D2D_FINAL_PACKED_256KB.bin`
- Size: `262144` bytes
- SHA256: `F9C08469C1267C291EA722818E6A7451773D86C5AA271741BEF113AB2537142B`
- Raw canonical build size: `65164` bytes
- Packer raw limit: `65528` bytes

## Golden Image

- Filename: `HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin`
- Local path: `D:\EINK\Clock\tools\packages\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin`
- Size: `262144` bytes
- SHA256: `C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452`

## Physical Validation

- D2B RAM-only firmware time handler: PASS
- D2C web device time controls: PASS
- D2D device-side render command: PASS
- SPI Burn/Verify: PASS
- Cold boot from SPI: PASS
- `D2 00 SET_TIME`: PASS
- `D2 01 GET_TIME_STATUS`: PASS
- `D2 02 RENDER_CLOCK_NOW`: PASS
- `D2 82`: ACCEPTED -> RENDERING -> COMPLETE
- BLE remained connected.
- Firmware rendered `HH:mm` directly on the panel.
- D2D did not use E5 transfer.
- No unintended second black refresh.

## Runtime Notes

- D2 time state is RAM-only.
- Reset or cold boot returns device time to UNSET until the web sends time again.
- After cold boot, use: Connect -> Gửi giờ xuống thiết bị -> Vẽ giờ từ thiết bị lên màn.
- QR and low-battery legacy visual redraw paths are disabled as an accepted firmware-size tradeoff.
- Current HINK213 clock-panel flow is unaffected by that tradeoff.

## Next Milestone

- `TASK D3A — device auto-minute clock policy/design`
- Design policy before implementation.
- Do not start automatic device-side minute refresh without a separate D3A task.
