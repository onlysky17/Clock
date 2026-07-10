# HL23A DETERMINISTIC INTEGRITY REJECTION MATRIX

## Purpose

Validate the negative paths already implemented by HL22A firmware.

HL23A is web-only:

- no firmware source change,
- no Keil build,
- no flash,
- no panel RAM write,
- no EPD refresh.

## Required firmware

Canonical HL22A source SHA256:

`0C4EA0DD9931FB9FC4D9B6EE12C2203E481A5DEB1E2A31FEB8404040252FFC84`

## Matrix

| Case | Expected status |
|---|---:|
| E5 before E4 session | `01` session required |
| Wrong transfer ID | `03` ID mismatch |
| Duplicate sequence | `04` sequence error |
| Skipped sequence | `04` sequence error |
| Incomplete commit | `07` incomplete |
| Full transfer with wrong CRC | `06` CRC mismatch |
| Correct completion manifest | `00`, state `02` |
| Session expires mid-transfer | next E5 returns `01` |
| Old transfer after reopening | `08` no transfer |
| Post-close E5 | `01` session required |

The page also rechecks:

- legacy E3 metadata/reset,
- HL20A `E2 E0 A1`,
- HL20A blocked refresh command `E2 03 F0`.

## Deterministic payload

```text
byte[i] = (i * 17 + 0x5A) & 0xFF
```

Expected full transfer:

- 339 chunks,
- 4736 bytes,
- CRC16-CCITT-FALSE `6065`.

## Canonical page

`web/clock-app/hl23a-rejection-matrix.html`
