# HL19A / HL19B BLE ROBUSTNESS VALIDATION — 2026-07-10

## Overall result

Status: PASS END-TO-END

Hardware under test:
- Old HINK213 2.13 test board.
- Existing damaged panel/FPC.
- New spare board was not modified, soldered, flashed, or tested.

Firmware:
- HL18B E3 dry-run firmware.
- No firmware rebuild or reflash was required for HL19A/HL19B.
- No framebuffer was written to panel RAM.
- No EPD refresh was called.
- No `.bin` file was pushed to GitHub.

## HL19A result

Validated:
- Clean 4736-byte transfer completed.
- Disconnect/reconnect flow completed.
- Query + Resume continued from firmware counters.
- Duplicate sequence was rejected without double-counting.
- Skipped sequence was rejected without changing counters.
- Mismatched chunk-size resume guard rejected unsafe continuation.
- Final sequence: 339.
- Final accepted bytes: 4736.
- Final firmware XOR matched local XOR: F0.

Status: PASS

## HL19B result

Purpose:
Exercise the ACK-loss recovery branch deterministically in the browser.

Validated:
- One chunk ACK was deliberately ignored in JavaScript.
- Firmware had already accepted the chunk.
- Web queried status after timeout.
- Web detected that firmware sequence had advanced.
- Transfer continued without duplicating accepted data.
- Simulation state reached CONSUMED.
- Recovered ACK loss counter reached 2 during the captured run.
- Final sequence: 339.
- Final accepted bytes: 4736.
- Final firmware XOR matched local XOR: F0.
- Final log reported:
  PASS COMPLETE: 339 chunks, 4736 bytes, XOR F0.

The recovery count being greater than one is acceptable because final sequence,
byte count and XOR all matched. It indicates that another delayed/lost ACK was
also recovered by the same status-query path.

Status: PASS

## Canonical tested pages

HL19A:
https://onlysky17.github.io/Clock/web/clock-app/hl19a-213-resume.html

HL19B:
https://onlysky17.github.io/Clock/web/clock-app/hl19b-213-ackloss.html

## Safety lock

- Target remains HINK213 2.13 inch only.
- Do not use `web/clock-app/eink-dev.html`.
- Do not push firmware `.bin` files to public GitHub.
- Do not run real framebuffer/refresh while the active test panel/FPC is damaged.
- Continue using the old test board.
- Keep the new spare board untouched until soldering and preflight are planned.

## Next task

HL20A — firmware refresh kill-switch.

Goal:
- Keep safe E2 descriptor/diagnostic commands available.
- Block all refresh-capable E2 commands at firmware dispatch.
- Return an explicit locked status instead of starting an EPD job.
- Keep E3 dry-run unchanged.
- Build and test on the old board only.
