# GOLDEN HINK213 CLOCK CONNECT

## Kết luận

Bản connect tốt hiện tại là:

D:\EINK\GOOD_CONNECT\HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin

SHA256:
C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452

## BLE

Device name:
HINK213-CLOCK

MAC:
18:BC:5A:7D:5A:83

Status:
- Advertise OK
- nRF Connect connect OK
- GATT services visible OK

## Flash layout

0x00000 boot/header 70 50
0x04000 app/header 70 51
0x38000 product/header 70 52

## Main BLE service

18424398-7cbc-11e9-8f9e-2a86e4085a59

Write:
2d86686a-53dc-25b3-0c4a-f0e10c8dee20

Write No Response:
5a87b4ef-3bfa-76a8-e642-92933c31434f

Indicate / Read:
9e1547ba-c365-57b5-2947-c5e1c1e1d528

Other services:
1842467c-7cbc-11e9-8f9e-2a86e4085a59
184247d0-7cbc-11e9-089e-2a86e4085a59

## Không dùng nữa

Các nhánh test HL03-HL10 không dùng làm nền nữa.
Hướng mới: lấy HINK213-CLOCK connect-good làm golden BLE base.
