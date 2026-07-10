# HINK213_CLOCK_P3_EPD_SMOKE canonical source

Canonical source:
`firmware/active/HINK213_CLOCK_P3_EPD_SMOKE/src/user_custs1_impl.c`

SDK mirror:
`D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE\src\user_custs1_impl.c`

HL22A SHA256:
`0C4EA0DD9931FB9FC4D9B6EE12C2203E481A5DEB1E2A31FEB8404040252FFC84`

Previous validated HL21A SHA256:
`406B197D3207685A2E2CE483220B230630C4D220D2BB10DD9C2FEE6369926A34`

Safety:
- HL20A panel-job kill-switch remains active.
- HL21A E4 RAM-only session remains active.
- HL22A E5 transfer is bound to the active session token.
- E5 stores counters and CRC16 only; no framebuffer bytes.
- Session close/expiry resets E3 and E5 state.
- No E3/E4/E5 path calls EPD, GPIO or SPI.
- Never push `.bin`.
