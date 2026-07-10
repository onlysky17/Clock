# HL19B DETERMINISTIC ACK-LOSS SIMULATION

## Why this task exists

HL19A real-board evidence confirms:

- Metadata guard works.
- Chunk-size mismatch guard works.
- Normal 4736-byte transfer completes.
- Disconnect/reconnect resume completes.
- Final state reaches 339 chunks, 4736 bytes and matching XOR.

The captured run showed `Retries = 0` and `Recovered ACK loss = 0`, so the specific branch for a lost ACK was not yet exercised.

## Implementation

Canonical candidate page:

`web/clock-app/hl19b-213-ackloss.html`

The page adds one test control:

`Arm: drop next chunk ACK`

When armed:

1. The next valid `E3 81` chunk ACK is received from the board.
2. JavaScript logs it but deliberately does not resolve the pending request.
3. The normal ACK timeout occurs.
4. The page queries firmware status pages.
5. Firmware reports that `nextSeq` already advanced.
6. Web counts one recovered ACK loss and continues without double-counting or resending accepted data indefinitely.

This is a local browser simulation only. Firmware is unchanged.

## Expected validation

Starting from a reset dry-run:

1. Start metadata.
2. Arm the simulated ACK loss.
3. Send with retry.
4. Log must contain `SIM-LOSS`.
5. Log must contain a recovery message similar to:
   `ACK timeout, but status confirms accepted`.
6. `Recovered ACK loss` must become `1`.
7. Final state must be:
   - next sequence: 339
   - bytes accepted: 4736
   - final XOR equals local XOR
8. No panel refresh occurs.

## Safety

- E3 only.
- No E2 packet emitted.
- No firmware rebuild or flash required.
- No panel RAM write.
- No EPD refresh.
- No `.bin` file created or pushed.
- Board under test remains the old damaged-panel board.
