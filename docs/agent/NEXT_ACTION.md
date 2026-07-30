# NEXT_ACTION

## Canonical Current State

- Repository: `D:\EINK\Clock`
- Canonical web URL: `https://onlysky17.github.io/Clock/test.html`
- D20A removed Google Calendar from Product Mode and the daily update flow.
- D20B keeps one clear `Cập nhật màn hình hôm nay` action near the top.
- D20C canonical desktop and 360 px mobile usability checks passed.
- Clock-face selection and optional weather remain directly reachable.
- Detailed progress, preferences, identity, preview, and engineering controls
  remain available in the closed-by-default advanced section.
- Product status mapping, BLE protocol, firmware, SDK, `test.html`, BIN, build,
  pack, flash, and physical-device behavior are unchanged.

## Next Canonical Action

`TASK D21A - PRODUCT MODE DAILY UPDATE RESILIENCE AUDIT`

Owner-visible goal:

- Audit recovery when weather or location lookup fails.
- Audit recovery when BLE disconnects or the device reports busy during the
  daily update.
- Keep one primary daily action without adding technical buttons to Product
  Mode.
- Define the smallest follow-up patch before changing web or firmware.

D21A is audit/design only. Do not change firmware or protocol until its failure
and retry policy is approved.
