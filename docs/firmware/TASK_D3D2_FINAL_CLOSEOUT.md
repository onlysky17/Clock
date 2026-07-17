# TASK D3D-2 Final Closeout — Last-Known Time Metadata

## Scope

- Repo: `D:\EINK\Clock`
- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- Canonical web: `https://onlysky17.github.io/Clock/test.html`
- Final raw firmware: `D:\EINK\Clock\_incoming\TASK_D3D2_FINAL_RAW.bin`
- Final packed firmware: `D:\EINK\Clock\_incoming\TASK_D3D2_FINAL_PACKED_256KB.bin`
- Do not commit `.bin` firmware images.

## Final Images

| File | Size | SHA256 |
| --- | ---: | --- |
| `TASK_D3D2_FINAL_RAW.bin` | `64884` | `0F79057E2FCC37951F855E2425A20CE08822EB83789929556954D937DFC8A843` |
| `TASK_D3D2_FINAL_PACKED_256KB.bin` | `262144` | `81E19127880D60730F8DC09588A9D15A452AAC69F81EAC5ECE92D3BAD08B1C14` |

Build metrics:

- Code: `41516`
- RO-data: `21624`
- RW-data: `608`
- ZI-data: `22928`
- Raw BIN: `64884` bytes
- Packer limit: `65528` bytes
- Headroom: `644` bytes
- Keil: `0 errors`, `0 warnings`

## Persistence Layout

- Safe SPI sector: `0x3B000..0x3BFFF`
- Sector size: `4096` bytes
- Slot A: `0x3B000`
- Slot B: `0x3B020`
- Record size: `32` bytes

Record contents:

- magic
- version
- sequence
- epoch
- timezone
- flags
- CRC

Write policy:

- Only a valid `D2 00 SET_TIME` writes a record.
- The inactive/older slot is written first.
- When both slots are used, firmware erases only sector `0x3B000..0x3BFFF` and writes slot A.
- Firmware never writes every minute.
- Firmware never writes on each render or refresh.
- Firmware never erases the full chip.
- Firmware does not touch `0x38000`, `0x39000`, `0x3A000`, firmware image slots, config, or NVDS.

## Verified Behavior

- SPI Burn/Verify PASS.
- Cold boot PASS.
- BLE boot/connect PASS.
- BLE reconnect PASS.
- `D2 SET_TIME` writes the last-known metadata record PASS.
- Cold boot with a valid record returns:
  - result: `NOT_INITIALIZED`
  - state: `UNSET`
  - flags: `0x82`
  - `STALE_PRESENT` set
- Stale metadata does not start the dedicated scheduler.
- Stale metadata does not auto-refresh the panel.
- A new `SET_TIME` clears stale behavior, returns to RUNNING, and five-minute refresh PASS.
- D3C renderer, lunar date layout, safe disconnect/re-advertise, and minute-boundary race fix remain PASS.

## Runtime Contract

D3D-2 persists only last-known metadata. It does not claim accurate time after reset or power loss.

After cold boot:

1. Connect through the canonical web URL.
2. Read status if needed; a valid stale record reports `STALE_PRESENT`.
3. Send SET_TIME again.
4. Device returns to RUNNING and the dedicated five-minute scheduler resumes.

## Home Handoff

Local handoff folder:

`D:\EINK\Clock\_incoming\D3D2_FINAL_HOME_HANDOFF`

The ZIP package is:

`D:\EINK\Clock\_incoming\D3D2_FINAL_HOME_HANDOFF.zip`

Run `VERIFY_HOME.ps1` on the home machine before continuing from D3D-2.
