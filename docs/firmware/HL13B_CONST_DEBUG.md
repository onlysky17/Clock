# HL13B CONST DEBUG BASELINE

## Status

HL13B is confirmed working.

## Firmware

Local file:
D:\EINK\GOOD_CONNECT\HL13B_CONST_DEBUG_FULL_256KB.bin

Device name:
EINK-HL13

## Confirmed

- BLE scan OK
- Web Bluetooth connect OK
- Notify OK
- Custom source patch confirmed

## Test command

Send HEX via WRITE:

F0 13

Expected notify:

13 13

## Meaning

This proves the board is running firmware built from:

D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P2_TIMEKEEPING_PASS

## Deprecated failed file

Do not use:

D:\EINK\GOOD_CONNECT\HL13_DEBUG_CMD_FULL_256KB.bin

Reason:
It did not scan after adding a larger new debug branch. Keep it only as failed experiment.
