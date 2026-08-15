# EINK Harness v0.3 Closeout

## Status

EINK Harness v0.3 automated Keil build is CLOSED / MERGED / ENGINEERING PASS.

- Feature PR: #144
- Feature commit: `9c662195eee8c1552918d2c84e9b5c7ef00d3726`
- Main merge commit: `bbdc2f89c8746bcfc5186352e08f2beebd424b31`
- Merged scope: exactly 4 files, 242 insertions, 9 deletions.

## Merged Files

- `scripts/eink.ps1`
- `scripts/task-eink-harness-v0.3-smoke.ps1`
- `tools/harness/eink-profile.json`
- `tools/harness/workspace-guard.ps1`

## Proven Build Contract

Canonical command:

```powershell
Set-Location "D:\EINK\Clock"
.\scripts\eink.ps1 build
```

Canonical Keil CLI:

`D:\Keil_v5_AC6\UV4\UV4.exe`

Canonical project:

`D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\ble_app_peripheral.uvprojx`

Target: `DA14585`

Compiler evidence:

- `Using Compiler 'V6.24'`
- `0 Error(s), 0 Warning(s)`

Final v0.3 validation evidence:

- Harness v0.3 smoke: PASS 12/12
- `git diff --check`: PASS
- Raw BIN size: 50552 bytes
- Raw BIN maximum: 65528 bytes
- Raw SHA256: `547D6D3949E36A88843D62DC34FF656199EFD03ECE0442A06733B7296908E012`
- Next state: `RAW_FIRMWARE_VERIFIED`
- Final build log: `D:\EINK\Clock\_incoming\EINK_HARNESS_BUILD\20260814_135633\keil-build.log`

## Important Implementation Lessons

- The proven Keil invocation must preserve the literal alias path `D:\Keil_v5_AC6`; do not normalize it back to the original `C:\Users\...` install path.
- Build development may opt into `AllowDirtyTrackedTree`, while the default workspace guard remains strict.
- Wrong workspace remains a hard stop; the harness must not silently `cd` into the canonical workspace.
- Raw size policy is read from `artifactPolicy.rawBinMaxBytes`.
- SHA256 calculation uses .NET and does not depend on `Get-FileHash`, preserving Windows PowerShell 5.1 compatibility.
- Build truth requires compiler/log/artifact evidence, not process exit code alone.

## Scope Boundary

v0.3 does not establish pack, SPI burn, SPI verify, cold boot, BLE, or physical e-ink PASS.

No firmware source, `.uvprojx`, SPI image, or `bk-13-08-26/` backup file was committed by v0.3.

## Next Harness Milestone

Recommended next narrow task: EINK Harness v0.4 automated full-SPI backup.

Target behavior:

- read-only SmartSnippets CLI backup of the complete 0x40000-byte SPI image;
- two independent reads;
- require both files to be exactly 262144 bytes;
- require both SHA256 values to match;
- preserve evidence under `_incoming`;
- no erase, write, burn, pack, cold boot, BLE, or physical-device mutation in this task.

Owner merge remains the final Git gate.
