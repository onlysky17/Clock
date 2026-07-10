# HL22A SESSION-BOUND TRANSFER INTEGRITY VALIDATION — 2026-07-10

## Overall result

Status: PASS END-TO-END

Scope:

- DA14585 HINK213 2.13-inch target only.
- Old damaged-panel test board only.
- New spare board remained untouched.
- E5 remained a metadata/counter/CRC dry-run.
- No framebuffer bytes were stored.
- No panel RAM write and no EPD refresh occurred.

## Source and build

Canonical HL22A source SHA256:

`0C4EA0DD9931FB9FC4D9B6EE12C2203E481A5DEB1E2A31FEB8404040252FFC84`

Keil rebuild:

- Code: 32236
- RO-data: 3240
- RW-data: 4
- ZI-data: 8388
- 0 Error(s)
- 0 Warning(s)

## Runtime validation

### Deterministic transfer

Expected deterministic pattern:

`byte[i] = (i * 17 + 0x5A) & 0xFF`

Expected CRC16-CCITT-FALSE:

`6065`

Observed completion manifest:

- State: `02` COMPLETE
- Chunks: `339`
- Bytes: `4736`
- CRC16: `6065`

Observed log result:

`E5 COMPLETE state=2 chunks=339 bytes=4736 CRC=6065`

Result: PASS

### Status manifest

The E5 status query returned the same deterministic completion manifest.

Result: PASS

### Legacy E3 regression

Legacy E3 metadata and reset still worked while the E4 session was active.

Observed result:

`Legacy E3 regression PASS`

Result: PASS

### HL20A regression

The panel-job kill-switch remained active:

`E2 E0 A1`

Refresh-capable command remained blocked:

`E2 03 F0`

Observed result:

`HL20A A1 + E2 03 F0`

Result: PASS

### Session close and post-close rejection

E4 close completed successfully.

After close, E5 status was rejected with session-required status `01`.

Observed result:

`Post-close E5 rejected`

Result: PASS

### Final web result

`HL22A PASS END-TO-END`

## Final safety state

- One E5 transfer is bound to the active E4 session token.
- Transfer ID, sequence, byte count and CRC16 are validated.
- Deterministic completion manifest is available.
- Session close or expiry resets E5 state.
- Legacy E3 remains available for regression.
- HL20A panel-job kill-switch remains active.
- No framebuffer bytes are stored in firmware.
- No panel RAM write occurs.
- No EPD refresh occurs.
- No firmware `.bin` is pushed to GitHub.
- HMCLOCK/self-flash material remains reference-only and is not integrated.
- New spare board remains untouched.

## Canonical web page

`web/clock-app/hl22a-transfer-integrity.html`

## Next milestone

HL23A — deterministic integrity rejection matrix:

- wrong transfer ID,
- duplicate sequence,
- skipped sequence,
- bad CRC,
- incomplete commit,
- session expiry during transfer,
- verify all status codes without panel access.
