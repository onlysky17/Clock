# E4 Session Bridge Closeout

- Status: MERGED AND VERIFIED
- Main merge commit: 687033abddc3445bf3815b96867495767cae377c
- Firmware source commit: f498676
- Canonical web: https://onlysky17.github.io/Clock/test.html
- SDK root: D:\EINK\DA14585_SDK_6.0.22.1401
- Active project: projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE

## Firmware result

- Existing FF00 HMCLOCK service preserved.
- Parallel HINK 128-bit write and notify service added.
- E4 open, status, keepalive and close session added.
- EPD source and pin mapping were not modified.

## Validation

- Keil ARMCLANG 6.24 DA14585 rebuild: 0 errors, 0 warnings.
- Program size: Code 38536, RO-data 23368, RW-data 1004, ZI-data 25156.
- SmartSnippets SysRAM test PASS.
- E4 open PASS.
- E4 active status PASS.
- E4 keepalive PASS.
- E4 close PASS.
- E4 post-close inactive status PASS.

## Persistence state

- No SPI flash programming was performed.
- No BIN, AXF, HEX or Keil output files were committed.
