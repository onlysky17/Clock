# EINK Clock Agent Rules

## Canonical Workspace

- Workspace canonical: `D:\EINK\Clock`
- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- SDK: `D:\EINK\DA14585_SDK_6.0.22.1401`
- SDK project: `D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE`
- Canonical web duy nhat: `https://onlysky17.github.io/Clock/test.html`

## Hardware And Web Gates

- PC khong co BLE; Web Bluetooth test bang dien thoai.
- Khong duoc tu Burn SPI, flash, reset board, hoac ket luan hardware PASS.
- Khong claim PASS neu khong co command output hoac Owner evidence.
- Hardware test, flash, Burn SPI, reset board, and physical display verification must stop for Owner action.

## Change Discipline

- Khong commit BIN/build output.
- Khong dung `git add .`.
- Moi task uu tien 3-5 file va toi da mot validation nang.
- Khong sua smoke lich su tru khi test that su fail vi code hien tai.
- Khong doc lai toan bo `MEMORY.md` hoac docs dai; chi doc `docs/agent/CURRENT_STATE.md`, `docs/agent/NEXT_ACTION.md`, va tai lieu truc tiep lien quan.

## Git Lifecycle

Required flow:

1. Workspace gate.
2. Branch.
3. Implement.
4. Validate.
5. Owner review.
6. Commit.
7. Push.
8. PR.
9. Owner merge.
10. Sync main.
11. Closeout.
