# TASK D13D - Vietnamese Weather Calendar

## Owner outcome

Profile `02` keeps the complete monthly calendar and adds a compact weather
summary. The physical panel no longer shows English tokens such as `CLD`,
`POP`, or `TODAY`.

The firmware uses short Vietnamese words supported by the existing ASCII
bitmap font: `NANG`, `MAY`, `MUA`, `GIONG`, `SUONG`, `GIO`, and `NONG`.
The web UI uses fully accented Vietnamese labels.

## Compatibility

- D2 `08`, `09`, and `88` packet layouts are unchanged.
- Existing agenda bytes remain accepted for protocol compatibility, but the
  Product Mode no longer asks for or renders the old `HOP` and `GYM` examples.
- The proven monthly grid, weekday columns, current-day highlight, clock,
  solar date, lunar date, scheduler, persistence, and EPD flow are unchanged.
- No new font, framebuffer, allocation, or EPD code is added.

## Physical gate

After a Keil build, load the fresh raw BIN to SysRAM, sync time, select
`Tom tat trong ngay`, and verify the monthly calendar plus Vietnamese weather
line. Firmware physical PASS remains an Owner action.

## D13D FIX1 final physical gate

Date: 2026-07-23

Result: **PASS**

Final persistent artifact:

- Package: D:\EINK\Clock\_incoming\D13D_FIX1_FINAL_SPI_20260723_160645
- Packed image: firmware\D13D_FIX1_FINAL_PACKED_256KB.bin
- Packed size: 262144 bytes
- Packed SHA256: 4C926E52B38D594BDC7E45CE30EEC51CD09D418E572987AC0B871E36E1065FF9
- Raw SHA256: 7F080CEB77878648A8B39EBF17213B1735BEE56367C3072F5984E5B63BAB8309

Physical gates:

- SPI Burn: PASS
- SPI Verify: PASS
- Full power-off and cold boot from persistent SPI: PASS
- PRIME recovery remains approximately 1 second: PASS
- Weather first letter no longer clipped: PASS
- Vietnamese weather marks aligned with text: PASS
- No redundant third browser redraw: PASS

Confirmed weather-display workflow:

1. Press Lấy thời tiết ngay.
2. Press Áp dụng lên màn.
3. The weather row appears on the e-ink display.

Đồng bộ giờ alone does not display the weather row. This is the confirmed current behavior and is not treated as a physical failure.

Final web behavior:

- Fresh high-accuracy phone location.
- Geolocation cache disabled.
- Current precipitation, rain and showers requested.
- Rain threshold is greater than or equal to 0.20 mm.
- A trace value of 0.10 mm maps to MÂY.
- Canonical URL: https://onlysky17.github.io/Clock/test.html
- Web FIX1 PR: #79
- Rain-threshold PR: #80
