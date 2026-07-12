# HINK213_CLOCK_22_BASE handoff

Final state:
- D:\EINK root was cleaned.
- Active firmware base is SDK 6.0.22.
- Repo project path: firmware/active/HINK213_CLOCK_22_BASE
- SDK work path: D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE

Build verification:
- Keil rebuild PASS.
- Program Size: Code=37980 RO-data=23196 RW-data=1004 ZI-data=25140.
- 0 Error(s), 0 Warning(s).

Runtime verification:
- SmartSnippets Booter / SysRAM Download PASS.
- Screen shows QR / HL27C test HINK213 content again.

Important:
- Do not continue display-driver work on old SDK 6.0.18 Clock path.
- Use SDK 6.0.22 HINK213_CLOCK_22_BASE as active base.
- Old 6.0.18 path is only reference for Clock BLE/web protocol.

Bootstrap on another machine:
- Install/copy SDK 6.0.22.1401 to D:\EINK\DA14585_SDK_6.0.22.1401.
- Run tools\bootstrap-hink213-clock22-base.ps1.
- Run tools\verify-hink213-clock22-base.ps1.
