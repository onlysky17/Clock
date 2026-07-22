# TASK D11A-0 - Layout Firmware Size Audit

## Decision

D11 may add multiple clock faces, but it must first reuse the current bitmap renderer and recover legacy code instead of copying complete render pipelines.

This task is audit-only. It does not change firmware, web behavior, BLE protocol, EPD behavior, persistence, or the physical layout.

## Canonical Baseline

- Main merge commit after D10B: `b9784cc8f8da23580bcc69fcca67e9b3a2d368ae`.
- Keil target: `DA14585`, ARMCLANG `6.24`.
- Build result: `0 errors`, `0 warnings`.
- Code: `42732` bytes.
- RO-data: `3592` bytes.
- RW-data: `552` bytes.
- ZI-data: `22928` bytes.
- Raw BIN: `48012` bytes.
- Packer limit: `65528` bytes.
- Current headroom: `17516` bytes.
- Raw BIN SHA256: `46209FF3944F3E3CDC91BA20F01EB68C444D7A5ABFB7C39D5F6597469E8706AE`.
- Legacy font symbols remain absent.

Map evidence was taken from the D10B build generated at `2026-07-22 11:20:52`:

- Map SHA256: `38CF676C546ED5EB6384E52A7A0CDCE8EA83EAF8454CE69EAC23ECB77182420B`.
- Symdef SHA256: `1AD8BBAEE3337C648A75CE108ABFCEBCE55C63D1644BE7087AF8D78A906BFFD0`.

## Linked Renderer Cost

Exact map symbols used by the active D9/D10 clock face:

| Symbol | Map size | Role |
| --- | ---: | --- |
| `hink_bitmap_draw_clock` | 1088 | Current flagship face and monthly calendar |
| `hink_d2_draw_current_framebuffer` | 552 | Current time/calendar derivation and framebuffer entry |
| `hink_d7a_digit` | 232 | Shared seven-segment bitmap digits |
| `hink_d7a_pixel` | 160 | Rotation-aware framebuffer pixel primitive |
| `hink_d7a_draw_day` | 110 | Calendar day drawing |
| `hink_d7a_box` | 88 | Shared filled rectangle primitive |
| `hink_put_4` | 84 | Four-digit year formatting |
| `hink_d3c_solar_leap` | 44 | Solar leap-year calculation |
| `hink_d3c_lunar_mdays` | 40 | Bounded lunar month calculation |
| `hink_d3c_solar_mdays` | 24 | Solar month length calculation |
| `lunar_year_info` | 64 RO | Existing bounded lunar data, 2024 through 2051 |
| `hink_d3c_solar_mdays.mdays` | 12 RO | Solar month lengths |
| `fb_bw` | 4000 ZI | The single existing framebuffer |

The active renderer is therefore already structured around reusable primitives. New faces must call these primitives and the existing asynchronous EPD worker. They must not add another framebuffer, font table, calendar converter, EPD worker, or refresh state machine.

## Map-Backed Recovery Candidate

The smallest isolated recovery is the legacy pre-D2 clock visual path. It is separate from the physical-PASS dedicated D2 timer and renderer.

Exact current symbols:

| Symbol/block | Map size | Current call evidence |
| --- | ---: | --- |
| `clock_draw` | 416 | Called only by legacy branches in `app_clock_timer_cb`, advertising timeout, and disconnect fallback |
| `clock_update` | 204 | Called only by legacy `app_clock_timer_cb` |
| `app_clock_timer_cb` | 152 | Created only by legacy `app_clock_timer_restart` |
| `ldate_inc` | 104 | Used by `clock_update` |
| `date_inc` | 104 | Used by `clock_update` |
| `clock_set` | 68 | No live source call site outside its own definition/header |
| `app_clock_timer_restart` | 40 | Legacy DB-init/clock-set path |
| `clock_fixup_set` | 24 | No live source call site outside its own definition/header |
| `app_clock_timer_stop` | 20 | Used when the dedicated D2 minute timer takes ownership |
| `font_bt` | 20 RO | Used only by the legacy Bluetooth icon path folded into `clock_draw` |

The gross mapped opportunity appeared to be `1152` bytes, but map reachability alone did not prove runtime independence.

Physical validation on `2026-07-22` rejected this recovery candidate. A SysRAM build that compile-disabled `clock_draw` reduced raw BIN from `48012` to `47500` bytes, but D2 reported COMPLETE while the panel remained white. The expected prime redraw after about 20 seconds also disappeared; only the later five-minute scheduler refresh made the layout visible. The change was rolled back without commit or push.

Conclusion: the legacy visual path still participates in first-refresh priming. `clock_draw`, the legacy clock timer, and related EPD ownership must remain unchanged throughout D11. This candidate is **REJECTED BY PHYSICAL TEST** and must not be retried as a size trim.

## Additional Dead-Code Observation

`epd_gui.o` still emits these uncalled bitmap helpers because the translation unit is linked as one `.text` section:

- `bitmap_draw_time_hhmm`: `156` bytes.
- `bitmap_large_digit`: `228` bytes.
- `bitmap_box`: `84` bytes.
- Total: `468` bytes.

They are not a preferred D11 trim because removing them would touch shared EPD code. They are recorded as a later fallback only; D11 must not modify `epd.c`, `epd_gui.c`, or linker settings for the first layout implementation.

## D11 Layout Architecture

The implementation should use one small profile selector and one shared render entry:

1. Derive solar/lunar/time once in `hink_d2_draw_current_framebuffer`.
2. Dispatch by a one-byte layout ID.
3. Each face draws with the existing pixel, box, digit, text, and calendar helpers.
4. Every face uses the same D2D asynchronous EPD open/init/update/wait/cleanup pipeline.
5. The selected layout may later be persisted in unused record space only after a separate record-layout audit.

Initial face set:

- `0`: current monthly calendar face, unchanged and the fallback.
- `1`: large-time face with compact solar/lunar rows.
- `2`: balanced face with time/date/lunar emphasis and no duplicated calendar engine.

## Budget Gate

- RAM increase for the selector: at most `4` bytes.
- No second framebuffer or dynamic allocation.
- No new font or lunar table.
- New layout code target: at most `1200` raw bytes per face without legacy recovery.
- D11 raw target after two added faces and profile control: at most `52000` bytes.
- Permanent reserve below the packer limit: at least `13000` bytes.
- No first-refresh, prime, legacy clock timer, or EPD lifecycle trim is allowed.

## Next Canonical Action

`TASK D11A - CLOCK FACE PROFILE DESIGN`

Design the layout ID command, persistence compatibility, web selector, fallback behavior, and exact renderer dispatch. D11A is design-only. The first implementation should be D11B and add only the large-time face.
