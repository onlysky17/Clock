# TASK D3C Final Closeout

## Summary

- Repo: `D:\EINK\Clock`
- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- Canonical web: `https://onlysky17.github.io/Clock/test.html`
- Final raw image: `D:\EINK\Clock\_incoming\TASK_D3C_FINAL_RAW.bin`
- Final packed image: `D:\EINK\Clock\_incoming\TASK_D3C_FINAL_PACKED_256KB.bin`
- Do not commit `.bin` firmware images.

## Final Build

- Code: `40760`
- RO-data: `21624`
- RW-data: `608`
- ZI-data: `22920`
- Raw BIN size: `64128` bytes
- Packer raw limit: `65528` bytes
- Raw headroom: `1400` bytes
- Packed size: `262144` bytes
- Raw SHA256: `3A360340C943F1EAD0E9EA5AC14EF584767EF57B2AC6229A221F5CA84BCC6EBC`
- Packed SHA256: `648123BE0CC83291D9CD0DC6E5B8D3B2AD68373698954BA7F6C189C1260F44F1`

## Verified Hardware State

- SPI Burn/Verify PASS.
- Cold boot PASS.
- Dedicated minute timer PASS.
- Safe disconnect/re-advertise PASS.
- BLE scan/connect after disconnect PASS.
- Two disconnected five-minute refresh boundaries PASS.
- Minute-boundary pending race fixed.
- No duplicate same-minute refresh.
- No second black refresh.
- Clock render shows time, solar date, and lunar date.
- Lunar date label is `AL`.

## Runtime Contract

- Time state is still RAM-only.
- Power cycle/cold boot clears time state.
- After power cycle/cold boot, connect and send SET_TIME once before relying on device-side auto clock.
- Default physical auto-refresh cadence remains five minutes.
- Device-side scheduler must not depend on BLE staying connected.

## Handoff

The local handoff package is under:

`D:\EINK\Clock\_incoming\D3C_FINAL_HOME_HANDOFF`

The ZIP archive is:

`D:\EINK\Clock\_incoming\D3C_FINAL_HOME_HANDOFF.zip`

Package contents include:

- Canonical source snapshot.
- `tools\bootstrap-hink213-clock22-base.ps1`
- `tools\sync-hink213-source.ps1`
- `tools\pack-hink.ps1`
- `TASK_D3C_FINAL_RAW.bin`
- `TASK_D3C_FINAL_PACKED_256KB.bin`
- SHA256 manifest.
- Local verification script.
- Home-machine README.
