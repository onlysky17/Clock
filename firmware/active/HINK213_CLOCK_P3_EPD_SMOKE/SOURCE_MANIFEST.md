# HINK213_CLOCK_P3_EPD_SMOKE canonical source

Canonical source:
`firmware/active/HINK213_CLOCK_P3_EPD_SMOKE/src/user_custs1_impl.c`

SDK mirror:
`D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE\src\user_custs1_impl.c`

HL21A SHA256:
`406B197D3207685A2E2CE483220B230630C4D220D2BB10DD9C2FEE6369926A34`

Previous HL20A SHA256:
`F76A308B86FDC2E2BA2EECA7F3845CAE56AC953307C07E8BCC24F69B8B37E334`

Safety:
- HL20A panel-job kill-switch remains active.
- HL21A adds a RAM-only 20-second E4 command session.
- E3 dry-run requires a valid session.
- Close/expiry resets dry-run counters.
- E2 E0 and D0-D5 remain readable without session.
- Not cryptographic authentication.
- Never push `.bin`.
