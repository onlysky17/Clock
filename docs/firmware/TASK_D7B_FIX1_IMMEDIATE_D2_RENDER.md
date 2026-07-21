# TASK D7B-FIX1/FIX2 - Immediate D2 Render

Status: PRE-PHYSICAL SYSRAM TEST

## Problem

D7B packaged firmware delayed the first visible D7A layout when `D2 SET_TIME`
arrived between minute boundaries. The web observed `SYNCED -> RENDERING ->
COMPLETE`, but the panel stayed white until the next minute tick, where the
autonomous scheduler rendered successfully.

Physical evidence:

- `D2 SET_TIME` at 08:59:09 reported `SYNCED -> RENDERING -> COMPLETE`.
- Panel remained white after the immediate D2 flow.
- At 09:00, the minute scheduler rendered the D7A layout.
- SysRAM and packed SPI behaved the same, so pack/golden/SPI were ruled out.
- D7B-FIX1 armed a one-shot timer, but that callback still used the scheduler
  gate and could become a no-op outside the five-minute policy window.

Root cause:

- The post-SET_TIME flow depended on the minute-start path to retry/schedule the
  autonomous render.
- A SET_TIME in the middle of a minute could leave the visible render dependent
  on the next minute callback instead of starting a render immediately.
- FIX1 moved the retry into a one-shot callback but still called
  `HINK_AUTO_TRY_SCHEDULE()`, so the immediate path remained coupled to the
  autonomous schedule policy instead of the physical render request engine.

## Fix

After a valid `D2 SET_TIME`, firmware now:

1. stores RAM time state and persists the last-known metadata as before;
2. realigns the dedicated minute timer as before;
3. arms a short dedicated one-shot app timer;
4. calls the render request engine directly from that timer context;
5. reports D2 render `COMPLETE` only from the existing EPD wait completion path.

The BLE write handler still does not call EPD functions directly. The
five-minute policy remains limited to autonomous scheduler decisions.

## Preserved Behavior

- D7A layout and calendar weekday column alignment remain unchanged.
- D3E five-minute scheduler remains active after disconnect.
- 09:00 or any later eligible five-minute boundary may still render once.
- No duplicate same-minute refresh.
- No second black refresh.
- E5/E6 protocol IDs and framebuffer geometry remain unchanged.

## Validation Gates

- `node .\scripts\task-d7a-autonomous-flagship-layout-smoke.mjs`
- `git diff --check`
- canonical source to SDK SHA256 parity
- Keil GUI build: 0 errors, 0 warnings
- raw BIN must remain below 58000 bytes and below the 65528 packer limit

## SysRAM Artifact

Pending D7B-FIX2 build output will be copied to:

`D:\EINK\Clock\_incoming\D7B_FIX2_SYSRAM_TEST\D7B_FIX2_SYSRAM_ble_app_peripheral_585.bin`

Do not pack SPI or treat D7B as final until Owner SysRAM physical retest passes.
