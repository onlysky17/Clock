# HINK213_CLOCK_P3_EPD_SMOKE canonical source

Canonical source:

`firmware/active/HINK213_CLOCK_P3_EPD_SMOKE/src/user_custs1_impl.c`

SDK mirror:

`D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE\src\user_custs1_impl.c`

HL25A source SHA256:

`5AC693AA560AC1ED0A594B00CB459FBE5C3247FD624EA6DFC965773C38DA08CB`

Previous validated HL22A/HL24A source SHA256:

`0C4EA0DD9931FB9FC4D9B6EE12C2203E481A5DEB1E2A31FEB8404040252FFC84`

Safety:

- HL20A still blocks all legacy refresh-capable E2 commands.
- HL21A E4 session remains active.
- HL22A E5 dry-run remains active.
- HL25A adds one fixed-pattern refresh per cold boot.
- Arm requires ASCII `HL25`, expires after 10 seconds, and is session-bound.
- Fire requires the returned arm ID plus `A5 5A`.
- The gate auto-locks before the panel job starts.
- Direct E2 subcommand `25` remains unavailable.
- Arbitrary framebuffer refresh is not enabled.
- Never push firmware `.bin` files.
