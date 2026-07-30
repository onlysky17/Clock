# NEXT_ACTION

## Canonical Current State

- Repository: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- D20A removed Google Calendar from Product Mode and the daily update flow.
- D20B keeps one clear `Cập nhật màn hình hôm nay` action near the top.
- D20C canonical desktop and 360 px mobile usability checks passed.
- D21A audited daily-update recovery without changing runtime behavior.
- Weather failure already degrades to clock update, but transient failure
  currently clears the Owner's weather choice.
- BLE disconnect currently leaves an active ACK wait until timeout.
- Device BUSY handling is duplicated and can skip its wait when cached render
  state is already COMPLETE.
- Product status mapping, BLE protocol, firmware, SDK, `test.html`, BIN, build,
  pack, flash, and physical-device behavior remain unchanged.

## Next Canonical Action

`TASK D21B - HARDEN PRODUCT MODE DAILY UPDATE RECOVERY`

Owner-visible goal:

- Preserve the Owner's weather selection and valid same-day weather when a
  transient location or weather lookup fails.
- Reject the pending BLE wait immediately on disconnect, release Product Mode,
  and require the Owner to reconnect.
- Use one bounded BUSY retry after the active device render completes.
- Keep exactly one primary action and exactly one physical render per successful
  update.

D21B is web-only. Do not change firmware, protocol, scheduler, `test.html`, or
add technical controls to Product Mode.
