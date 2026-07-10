# HL20A PANEL-JOB / REFRESH KILL-SWITCH

Old HINK213 2.13 test board only. New spare board remains untouched.

The firmware guard runs before E2 dispatch and blocks every command that can
call `hink_epd_start_job()`:

- `02`, `03`, `04`
- `30` through `37`
- `50` through `54`

Blocked response: `E2 <subcommand> F0`

Safe proof command: `E2 E0 00 00 00 00 00`

Expected proof: `E2 E0 A1`

Descriptor `D0`–`D5`, bounded diagnostics `40`–`46`, BLE/time, and the full
HL18B/HL19 E3 dry-run remain available.

Previous SHA256: `8F3673B452478C64B55BCF7DD59D8D83EFB2CF6F976199690F87C5E8EFDA274C`

HL20A SHA256: `F76A308B86FDC2E2BA2EECA7F3845CAE56AC953307C07E8BCC24F69B8B37E334`

The HL18B E3 block is unchanged byte-for-byte.

Validation order:

1. Apply canonical source and sync to SDK.
2. Keil Rebuild; require 0 errors.
3. Pack and flash locally; never push `.bin`.
4. Open `hl20a-refresh-lock.html`.
5. Query E2 E0 and continue only after E2 E0 A1.
6. Verify all blocked commands return F0.
7. Recheck descriptor and E3 dry-run.
