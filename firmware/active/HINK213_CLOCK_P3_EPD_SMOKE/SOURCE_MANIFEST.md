# HINK213_CLOCK_P3_EPD_SMOKE canonical source

Canonical source:
`firmware/active/HINK213_CLOCK_P3_EPD_SMOKE/src/user_custs1_impl.c`

SDK mirror:
`D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE\src\user_custs1_impl.c`

HL20A SHA256:
`F76A308B86FDC2E2BA2EECA7F3845CAE56AC953307C07E8BCC24F69B8B37E334`

Previous validated HL18B SHA256:
`8F3673B452478C64B55BCF7DD59D8D83EFB2CF6F976199690F87C5E8EFDA274C`

Safety:
- HL18B E3 dry-run remains unchanged.
- HL20A blocks E2 `02`, `03`, `04`, `30`–`37`, `50`–`54`.
- Lock query `E2 E0 00 00 00 00 00` returns `E2 E0 A1`.
- Blocked commands return `E2 <subcmd> F0`.
- Never push `.bin`.
