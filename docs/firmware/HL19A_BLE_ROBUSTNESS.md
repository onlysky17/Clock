# HL19A BLE DRY-RUN ROBUSTNESS

## Scope

HL19A is a web-only transport robustness layer on top of the validated HL18B firmware.

It does not require a firmware rebuild or flash.

## Baseline confirmed before HL19A

- Valid metadata is accepted.
- A valid sequence 0 chunk is accepted.
- Sending sequence 0 again returns sequence error.
- Skipping to sequence 2 returns sequence error.
- Duplicate and skipped packets do not increment chunk/byte counters.
- E3 status pages remain consistent.

## New web behavior

Canonical candidate page:

`web/clock-app/hl19a-213-resume.html`

Features:

- Bounded ACK timeout.
- Bounded retry count.
- Status query after timeout.
- Recovery when a chunk was accepted but its ACK was lost.
- Duplicate sequence detection.
- Query and resume from firmware counters.
- Resume guard that checks sequence, accepted bytes and current chunk size.
- Final byte-count and XOR verification.
- Manual HEX safety lock that permits only E3 00 through E3 03.

## Existing HL18B status pages used

- `E3 02 00`: accepted chunk count low.
- `E3 02 01`: accepted chunk count high.
- `E3 02 02`: accepted byte count low.
- `E3 02 03`: accepted byte count high.
- `E3 02 04`: accumulated XOR.
- `E3 02 05`: metadata armed flag.

The accepted chunk count is also the next expected sequence because each accepted packet increments both values exactly once.

## Safety

- Web sends only E3 protocol packets.
- No E2 packet is emitted by the page.
- No panel framebuffer is stored by firmware.
- No panel RAM write occurs.
- No EPD refresh occurs.
- Target remains HINK213 2.13 inch only.
- Do not push firmware `.bin` files to GitHub.

## Validation plan

1. Connect the old test board running HL18B.
2. Start metadata.
3. Send normally and confirm 4736 bytes plus final XOR.
4. Start again, interrupt the browser mid-transfer, reconnect, and use Query + Resume.
5. Confirm counters do not double-count.
6. Test a deliberately small ACK timeout to exercise bounded retry.
7. Restore default timeout after testing.
