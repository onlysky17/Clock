# HINK213_CLOCK_P3_EPD_SMOKE canonical source

Canonical file:

`firmware/active/HINK213_CLOCK_P3_EPD_SMOKE/src/user_custs1_impl.c`

SDK build mirror:

`D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE\src\user_custs1_impl.c`

HL18B patched source SHA256:

`8F3673B452478C64B55BCF7DD59D8D83EFB2CF6F976199690F87C5E8EFDA274C`

Rules:

- Git canonical source is the source of truth.
- Run `tools/sync-hink213-source.ps1 -ToSdk` before a Keil build.
- Use `-FromSdk -ConfirmImport` only when a Keil-side edit must be imported, then review `git diff`.
- Never commit or push `.bin` firmware images.
- HL18B E3 is counter/ACK-only and does not write or refresh the panel.
