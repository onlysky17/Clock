# HL22A SESSION-BOUND TRANSFER INTEGRITY

## Goal

Strengthen the dry-run transport without enabling any panel access.

HL22A adds transfer ID, session-token binding, strict sequence/byte validation,
CRC16-CCITT-FALSE, and a deterministic completion manifest.

Firmware still stores no framebuffer bytes.

## E5 protocol

- Start: `E5 00 id widthLo widthHi heightLo heightHi xBytes totalLo totalHi crcLo crcHi`
- Chunk: `E5 01 id seqLo seqHi len data...`
- Commit: `E5 02 id chunksLo chunksHi bytesLo bytesHi crcLo crcHi`
- Status: `E5 03 id`
- Reset: `E5 04 id`

Commit/status manifest:

`E5 82/83 status id state chunksLo chunksHi bytesLo bytesHi crcLo crcHi`

States: `00 none`, `01 active`, `02 complete`.

## CRC

CRC16-CCITT-FALSE, polynomial `0x1021`, initial `0xFFFF`, no final XOR.

Deterministic test pattern:

`byte[i] = (i * 17 + 0x5A) & 0xFF`

Expected final result:

- 339 chunks
- 4736 bytes
- CRC `6065`
- state `02`

## Safety

- E5 requires a valid E4 session.
- Start snapshots the active session token.
- Session close/expiry resets transfer state.
- HL20A kill-switch remains active.
- Legacy E3 remains available for regression.
- No panel RAM write or EPD refresh.
- Old board only; new spare board untouched.
- HMCLOCK/self-flash remains reference-only.

## Source

HL21A: `406B197D3207685A2E2CE483220B230630C4D220D2BB10DD9C2FEE6369926A34`

HL22A: `0C4EA0DD9931FB9FC4D9B6EE12C2203E481A5DEB1E2A31FEB8404040252FFC84`
