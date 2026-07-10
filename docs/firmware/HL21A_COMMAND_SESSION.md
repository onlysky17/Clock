# HL21A BLE COMMAND-SESSION SAFETY

## Scope

Old HINK213 2.13 board only. New spare board remains untouched.
This is an accidental-command safety gate, not cryptographic authentication.

## E4 protocol

- Open: `E4 00 48 4C 32 31` -> `E4 80 status token timeoutSec`
- Keepalive: `E4 01 token` -> `E4 81 status token timeoutSec`
- Close: `E4 02 token` -> `E4 82 status token timeoutSec`
- Status: `E4 03` -> `E4 83 active token timeoutSec`

Timeout is 20 seconds. Valid E3 traffic and keepalive refresh it. Close or expiry resets dry-run counters.

Without a session, E3 returns status `06` (session required).

HL20A E2 kill-switch, E2 E0 proof, D0-D5 descriptor and BLE/time remain available. No E4/E3 code calls EPD/GPIO/SPI.

Previous SHA256: `F76A308B86FDC2E2BA2EECA7F3845CAE56AC953307C07E8BCC24F69B8B37E334`

HL21A candidate SHA256: `406B197D3207685A2E2CE483220B230630C4D220D2BB10DD9C2FEE6369926A34`

Validation: pre-open rejection, open, full 4736-byte run, close rejection, timeout rejection, and HL20A A1/F0 regression.
