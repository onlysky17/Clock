# TASK D17A - Unified Daily Update Flow Policy

## Purpose

D17A defines one owner-facing Product Mode action named `Cập nhật màn hình hôm nay`.

The action combines the existing weather, Google Calendar, device-time, daily-context, and visible-render flows without changing firmware or the BLE protocol.

D17A is design-only. It does not modify web runtime, firmware, BLE commands, `test.html`, build artifacts, or the physical device.

## Owner-Visible Goal

The normal daily flow becomes:

1. Connect BLE manually.
2. Press `Cập nhật màn hình hôm nay`.
3. Observe progress for weather, agenda, device time, daily context, and display.
4. Receive one final COMPLETE or a precise degraded/error result.

The web must never auto-connect BLE.

## Canonical Execution Order

D17B must reuse the existing proven commands and functions in this order:

1. Confirm that a compatible device is already connected and idle.
2. Request fresh phone location and current weather.
3. Request the current-day Google Calendar agenda when access is available.
4. Send the current device time through the existing D2 time-sync path.
5. Build the current-day weather and agenda context.
6. Apply the context through the existing `Áp dụng lên màn` product path.
7. Produce exactly one final visible panel render.
8. Refresh identity/health status only after the visible render completes.

D17B must inspect and reuse the existing implementation. It must not invent a new BLE command or duplicate an existing panel-refresh path.

## Single-Run And Coalescing Rules

- Only one unified update may run at a time.
- Repeated taps while a run is active must join or ignore the active run; they must not start parallel weather, agenda, BLE, or render operations.
- Product controls must remain locked while the unified update owns the command session.
- The flow must produce no duplicate EPD refresh.
- The flow must not trigger the removed PRIME browser redraw workaround.
- A failed render must be reported; the web must not blindly issue a second render.

## Weather Failure Policy

- Fresh weather is preferred on every unified update.
- When weather refresh succeeds, use the newly returned condition, temperature, and precipitation values.
- When weather refresh fails, a previously successful same-day value may be reused only when the UI clearly labels it as cached or stale.
- Previous-day weather must not be silently reused as current.
- When no acceptable weather value exists, continue without weather rather than inventing a fallback condition.
- Weather failure alone must not block device-time sync or a valid agenda update.

## Google Calendar Failure Policy

- Google Calendar remains read-only and owner-authorized.
- When Calendar access is unavailable, the unified flow continues with weather and device time.
- A previous successful same-day agenda may be retained with a visible cached/stale label.
- Previous-day agenda rows must be cleared immediately and must never be sent as current-day data.
- At most two upcoming timed events remain supported.
- The web must not open an authorization prompt unexpectedly during the unified run.

## Device And Render Failure Policy

- No BLE connection means the run stops before sending device commands and reports `Chưa kết nối thiết bị`.
- A device-time sync failure stops context apply and render because the device day key may be unsafe.
- A daily-context apply failure stops the visible render.
- A visible-render failure reports the exact failed step and does not claim COMPLETE.
- Disconnect during the run cancels the remaining BLE steps and releases Product Mode controls.

## Data Preservation Rules

- New valid data replaces older data only after the corresponding fetch succeeds.
- A transient API failure must not erase a valid same-day value unless the value is explicitly expired.
- Previous-day agenda is always invalid after rollover.
- Cached data must be owner-visible as cached or stale.
- No location coordinates, Calendar event bodies, or tokens are persisted beyond the existing approved storage behavior.

## Product Mode Status Model

The unified action exposes these owner-readable steps:

1. `Thời tiết`
2. `Lịch Google`
3. `Giờ thiết bị`
4. `Dữ liệu hôm nay`
5. `Màn hình`

Each step must show one of:

- waiting
- running
- complete
- skipped
- cached
- failed

The final result must distinguish full success, degraded success, and failure.

## Advanced Controls

- Existing technical controls remain available under Advanced.
- `Lấy thời tiết ngay`, Calendar refresh, `Đồng bộ giờ`, and `Áp dụng lên màn` remain usable for diagnostics.
- Product Mode presents `Cập nhật màn hình hôm nay` as the primary normal-user action.
- D17B must not delete proven diagnostic controls.

## Preserved Contracts

- Canonical URL remains `https://onlysky17.github.io/Clock/test.html`.
- Logical panel geometry remains `250 x 122`.
- Controller RAM remains `122 x 250`.
- Stride remains `16` bytes.
- Framebuffer payload remains `4000` bytes.
- Existing D2, E5, and E6 packet formats remain unchanged.
- Existing weather threshold remains current rain `>= 0.20 mm`.
- Existing D16B next-day agenda rollover remains active.
- The web never auto-connects BLE.
- No BIN, build, pack, flash, SPI Burn, or physical-device action belongs to D17A.

## D17B Exact Scope

`TASK D17B - IMPLEMENT UNIFIED DAILY UPDATE FLOW`

Expected maximum tracked files:

1. `web/clock-app/hl24a-canvas-e5.html`
2. `scripts/task-d17b-unified-daily-update-flow-smoke.mjs`
3. this policy document only when implementation evidence must be appended

D17B is web-only and must implement the primary Product Mode button, step status, run coalescing, controlled degraded results, and exactly one final visible render.

D17B must not modify firmware, BLE protocol, `test.html`, OAuth scopes, BIN files, build output, or the SPI package.

## D17B Acceptance Criteria

- One manual BLE connection is sufficient.
- One press runs the complete owner-facing daily update.
- Weather and agenda failures degrade independently.
- Previous-day agenda is never reused.
- Device time is synchronized before current-day context is applied.
- Context uses the existing `Áp dụng lên màn` flow.
- Exactly one final visible render occurs.
- No overlapping unified runs occur.
- No browser auto-connect occurs.
- Technical controls remain available under Advanced.
- Desktop and mobile Product Mode show clear per-step status.
