# HL23A DETERMINISTIC INTEGRITY REJECTION MATRIX — 2026-07-10

## Overall result

Status: PASS END-TO-END

Scope:

- DA14585 HINK213 2.13-inch target only.
- Existing HL22A firmware; web-only validation.
- Old damaged-panel test board only.
- New spare board remained untouched.
- No firmware source change.
- No Keil build or flash.
- No panel RAM write and no EPD refresh.

## Rejection matrix

| Test | Expected | Observed | Result |
|---|---:|---:|---|
| Pre-session E5 | `01` | `01` | PASS |
| Wrong transfer ID | `03` | `03` | PASS |
| Duplicate sequence | `04` | `04`, next sequence remained `1` | PASS |
| Skipped sequence | `04` | `04`, next sequence remained `1` | PASS |
| Incomplete commit | `07` | `07`, state `1`, chunks `2`, bytes `28` | PASS |
| Wrong CRC after full transfer | `06` | `06`, state `1`, CRC remained `6065` | PASS |
| Correct completion manifest | `00` | state `2`, chunks `339`, bytes `4736`, CRC `6065` | PASS |
| Session expiry mid-transfer | `01` | `01` | PASS |
| Old transfer after reopen | `08` | state `0`, chunks `0`, bytes `0` | PASS |
| Legacy E3 regression | `00` | metadata `00`, reset `00` | PASS |
| HL20A kill-switch regression | `A1` + `F0` | `E2 E0 A1`, `E2 03 F0` | PASS |
| Post-close E5 | `01` | `01` | PASS |

## Happy-path checkpoint

Observed completion:

- State: `02` COMPLETE
- Chunks: `339`
- Bytes: `4736`
- CRC16-CCITT-FALSE: `6065`

Displayed result:

`COMPLETE: state=2, chunks=339, bytes=4736, CRC=6065`

## Final runtime result

`HL23A REJECTION MATRIX PASS END-TO-END`

## Safety conclusions

- E5 requires an active E4 session.
- Transfer ID mismatch is rejected.
- Duplicate and skipped sequence numbers are rejected without advancing state.
- Incomplete commit is rejected.
- Wrong CRC is rejected while preserving the active transfer for a correct commit.
- Correct commit produces a deterministic completion manifest.
- Session expiry clears the active transfer.
- A transfer cannot continue after reopening a new session.
- Post-close E5 is rejected.
- Legacy E3 remains functional.
- HL20A panel-job kill-switch remains active.
- No framebuffer bytes are stored in firmware.
- No panel RAM write occurs.
- No EPD refresh occurs.
- No firmware `.bin` is pushed.
- HMCLOCK/self-flash remains reference-only and is not integrated.

## Canonical page

`web/clock-app/hl23a-rejection-matrix.html`

## Next milestone

HL24A — canvas-to-E5 dry-run bridge:

- reuse the 128x296 / 4736-byte canvas packer,
- calculate CRC16 over the actual packed canvas,
- send the actual packed payload through E4 + E5,
- verify the returned completion manifest,
- still no framebuffer storage, panel RAM write or EPD refresh.
