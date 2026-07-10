# HL21A BLE COMMAND-SESSION VALIDATION — 2026-07-10

## Overall result

Status: PASS END-TO-END

Scope:

- DA14585 HINK213 2.13-inch target only.
- Old damaged-panel test board only.
- New spare board remained untouched.
- E3 remained a dry-run transport.
- No panel RAM write and no EPD refresh occurred.

## Source and build

Canonical HL21A source SHA256:

`406B197D3207685A2E2CE483220B230630C4D220D2BB10DD9C2FEE6369926A34`

Keil rebuild:

- Code: 31260
- RO-data: 3240
- RW-data: 4
- ZI-data: 8372
- 0 Error(s)
- 0 Warning(s)

## Runtime validation

### Pre-open gate

E3 metadata sent before opening a session was rejected:

`E3 80 06`

Status `06` means session required.

Result: PASS

### Session open

Open request:

`E4 00 48 4C 32 31`

Observed response form:

`E4 80 00 <token> 14`

`14` hexadecimal equals the configured 20-second timeout.

Result: PASS

### Status and timeout

Session status reported active while valid:

`E4 83 01 <token> 14`

After more than 20 seconds without valid E3 traffic or keepalive, status became
inactive and keepalive was rejected as not open.

Result: PASS

### Full E3 dry-run regression

Observed final result:

- Sequence: 339
- Bytes accepted: 4736
- XOR: 00

Log result:

`PASS COMPLETE 339 chunks 4736 bytes XOR 00`

The full-run web path performed periodic keepalives during transfer.

Result: PASS

### Explicit close and post-close gate

Close response:

`E4 82 00 <token> 14`

After close, E3 metadata was rejected:

`E3 80 06`

Result: PASS

### HL20A regression

Lock signature remained active:

`E2 E0 A1`

Refresh-capable command remained blocked:

`E2 03 F0`

Result: PASS

## Final safety state

- E3 dry-run requires a valid E4 session.
- Session is RAM-only and expires after 20 seconds.
- Valid E3 traffic and keepalive refresh the timeout.
- Close or expiry resets dry-run state.
- HL20A panel-job kill-switch remains active.
- Descriptor and lock-proof commands remain available.
- No panel framebuffer was stored.
- No panel refresh was executed.
- No firmware `.bin` was pushed to GitHub.
- HMCLOCK/self-flash material remains reference-only and is not integrated.

## Canonical web page

`web/clock-app/hl21a-command-session.html`

## Next milestone

HL22A — session-bound dry-run transfer integrity:

- transfer identifier,
- stronger end-to-end checksum than XOR,
- deterministic completion manifest,
- still no panel RAM write or EPD refresh.
