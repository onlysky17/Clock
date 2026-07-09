# CURRENT EINK FW STATE

## Golden firmware

File local:
D:\EINK\GOOD_CONNECT\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin

SHA256:
C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452

Device:
HINK213-CLOCK

MAC:
18:BC:5A:7D:5A:83

## Confirmed

- BLE advertise OK
- nRF Connect connect OK
- GitHub Pages Web Bluetooth connect OK
- WRITE OK
- WRITE NO RESPONSE OK
- Notify OK
- Time command 7 byte OK

## Time packet

Format:
YY MM DD DOW HH MM SS

Example:
1A 07 09 04 0B 08 17

Meaning:
2026-07-09, DOW 04, 11:08:23

Notify ACK:
0B 08

Meaning:
HH MM = 11:08

## Main BLE UUID

Service:
18424398-7cbc-11e9-8f9e-2a86e4085a59

Write:
2d86686a-53dc-25b3-0c4a-f0e10c8dee20

Write No Response:
5a87b4ef-3bfa-76a8-e642-92933c31434f

Notify:
15005991-b131-3396-014c-664c9867b917

Indicate/Read:
9e1547ba-c365-57b5-2947-c5e1c1e1d528

## Deprecated

Do not continue HL03-HL10 as firmware base.

New direction:
Use HINK213-CLOCK connect-good as BLE golden baseline.
Find matching source/project for HINK213-CLOCK or P2_TIMEKEEPING_PASS, then customize from that base.
