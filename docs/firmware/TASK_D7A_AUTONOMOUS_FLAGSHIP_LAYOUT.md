# TASK D7A - Autonomous Flagship Daily Layout

## Scope

- Port the web-approved daily calendar face into the autonomous firmware renderer.
- Firmware renders directly from D2 RAM time after SET_TIME and from the existing five-minute scheduler.
- No E5/E6 framebuffer upload is required for the autonomous clock face.
- Web, `test.html`, BLE protocol, SPI persistence sector, scheduler policy, geometry, and framebuffer size are unchanged.

## Final Status

`TASK D7A` is CLOSED, MERGED, and PHYSICAL PASS.

- D7A implementation commit: `2308fce61388ef99126cc80a6c81fd9b353baed4`.
- Calendar alignment FIX1 commit: `68a47e5c4ce90c874f9c3c21bdb34754e4444600`.
- Immediate D2 render FIX2 commit: `32fa562d0d36127a3ded4b46bd35148ff3ccc172`.
- Main merge commit after FIX1/FIX2: `b4e8002774231f197821308d49c11327bda3e550`.
- Owner Physical PASS date: `2026-07-20`.

## Layout MVP

- Left pane:
  - Solar date: `T2 20/07/2026`.
  - Large HH:mm.
  - Lunar date: `AL 07/06`.
- Right pane:
  - Month title: `THANG 7/2026`.
  - Seven-column month calendar.
  - Current day highlighted with an inverted cell.
- A vertical divider separates the panes.
- The renderer uses compact bitmap primitives only.
- Legacy font headers/symbols are not restored.

## Calendar Logic

- Month length is derived by `hink_d3c_solar_mdays()`.
- Leap years use the existing D3C solar leap helper.
- The first-day offset is derived from the current weekday and day-of-month.
- Calendar columns are Monday-first: `T2 T3 T4 T5 T6 T7 CN`.
- FIX1 draws each weekday label on the same grid as its date column: `x = 109 + col * 20`.
- Days outside the month are not drawn.
- The current day is rendered as a black cell with white digits.

## Immediate Render

- FIX2 keeps the D2 SET_TIME path owner-visible:
  - Store the new time.
  - Queue the D7A render in timer/application context.
  - Draw the D7A framebuffer before physical refresh.
  - Report D2 COMPLETE only after the physical refresh completion path.
- This fixes the blank-panel case where D2 reported COMPLETE but the panel stayed white until the next five-minute scheduler tick.

## Final Build Evidence

- Keil target: `DA14585`.
- Project: `D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\ble_app_peripheral.uvprojx`.
- Result: `0 Error(s), 0 Warning(s)`.
- Code `41968`.
- RO-data `3592`.
- RW-data `552`.
- ZI-data `22928`.
- Raw BIN `47248` bytes.
- Final raw BIN SHA256: `14CF053BC1EF88B7CCB7733F8372F6484AD635FE6012613D7024FA07F69CE986`.
- Raw BIN is below the D7A `58000` byte guard and below the `65528` packer limit.
- Legacy font map/symdef scan confirms legacy font symbols remain absent from the active renderer path.

## Owner Physical Evidence

- D2 `SYNCED -> RENDERING -> COMPLETE`: PASS.
- Layout appears immediately after `Dong bo gio`: PASS.
- No blank panel after D2 COMPLETE: PASS.
- Header `T2..CN` aligns with date columns: PASS.
- Current-day invert highlight: PASS.
- Solar date / large HH:mm / lunar: PASS.
- Divider / clipping / overlap: PASS.
- BLE-disconnected five-minute scheduler: PASS.
- No duplicate refresh / second black refresh: PASS.
- E6 NOT RUN during the autonomous test.

## Guards

- D2 SET_TIME/status lifecycle remains unchanged.
- D3E/D3D scheduler and persistence remain present.
- E5/E6 command IDs and validation remain unchanged.
- Framebuffer remains `4000` bytes.
- Panel geometry and polarity remain unchanged.
- No dynamic allocation.
- No floating point.
- No `sprintf()` in the D7A render path.
- Do not commit `.bin`, `.axf`, map, build logs, screenshots, or `_incoming` artifacts.

## Next Canonical Action

`TASK D7A-WEB1 - add visible test identity and cache marker`.

Requirements for the next task:

- Canonical URL remains `https://onlysky17.github.io/Clock/test.html`.
- Product Mode shows the web build/test identity visibly.
- Expected Firmware: `D7A`.
- Firmware commit marker: `32fa562d`.
- Short BIN hash marker: `14CF053B`.
- Helps Owner distinguish stale cached web builds.
- Does not change BLE protocol.
- Does not claim firmware in chip has been automatically verified.

D7B must not start before D7A-WEB1 is closed out.
