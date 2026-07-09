<#
HL18A local helper.

What it does:
- Copies/keeps the web/docs files from this package when extracted inside D:\EINK\Clock.
- Optionally patches the local firmware source with an E3 dry-run handler only.
- It creates a .hl18a.bak backup before editing firmware source.

What it does NOT do:
- It does not build firmware.
- It does not flash firmware.
- It does not create or push .bin files.
- It does not enable EPD refresh.
#>

param(
  [string]$RepoRoot = "D:\EINK\Clock",
  [string]$SourcePath = "D:\EINK\6.0.18.1182.1\projects\target_apps\ble_examples\HINK213_CLOCK_P3_EPD_SMOKE\src\user_custs1_impl.c",
  [switch]$PatchFirmware
)

$ErrorActionPreference = "Stop"

Write-Host "HL18A apply helper" -ForegroundColor Cyan
Write-Host "RepoRoot: $RepoRoot"
Write-Host "PatchFirmware: $PatchFirmware"

if (-not (Test-Path $RepoRoot)) {
  throw "RepoRoot not found: $RepoRoot"
}

Push-Location $RepoRoot
try {
  Write-Host "\nGit status before:" -ForegroundColor Cyan
  git status --short

  if ($PatchFirmware) {
    if (-not (Test-Path $SourcePath)) {
      $fallback = Join-Path $RepoRoot "firmware\FWV2\eink_viet_custom_fw\projects\target_apps\ble_examples\ble_app_ota\src\user_custs1_impl.c"
      if (Test-Path $fallback) {
        $SourcePath = $fallback
      } else {
        throw "Firmware source not found. Pass -SourcePath manually. Tried: $SourcePath and $fallback"
      }
    }

    Write-Host "\nPatching firmware source:" -ForegroundColor Cyan
    Write-Host $SourcePath

    $src = Get-Content -Raw -Encoding UTF8 $SourcePath
    if ($src -match "HL18A_FRAMEBUFFER_DRYRUN") {
      Write-Host "HL18A firmware block already present; skipping firmware patch." -ForegroundColor Yellow
    } else {
      $backup = "$SourcePath.hl18a.bak"
      Copy-Item $SourcePath $backup -Force
      Write-Host "Backup created: $backup"

      if ($src -match "hink_notify_bytes\s*\(") {
        $notify = @'
static void hl18a_notify3(uint8_t a, uint8_t b, uint8_t c)
{
    uint8_t out[3] = {a, b, c};
    hink_notify_bytes(out, 3);
}
'@
      } elseif ($src -match "bls_att_pushNotifyData\s*\(") {
        $notify = @'
static void hl18a_notify3(uint8_t a, uint8_t b, uint8_t c)
{
    uint8_t out[3] = {a, b, c};
    bls_att_pushNotifyData(SVC1_IDX_LED_STATE_VAL, out, 3);
}
'@
      } else {
        throw "No known notify helper found. Expected hink_notify_bytes() or bls_att_pushNotifyData()."
      }

      $helper = @"

/* HL18A_FRAMEBUFFER_DRYRUN_BEGIN
 * Safe BLE framebuffer dry-run parser for HINK213 2.13 only.
 * This block updates metadata/chunk counters and sends 3-byte ACKs only.
 * It MUST NOT call display(), EPD refresh, framebuffer-to-panel, or any E2 refresh command.
 */
#define HL18A_DRY_W             128
#define HL18A_DRY_H             296
#define HL18A_DRY_XBYTES        16
#define HL18A_DRY_TOTAL         4736
#define HL18A_DRY_CHUNK_MAX     14
#define HL18A_STATUS_OK         0x00
#define HL18A_STATUS_BAD_SIZE   0x01
#define HL18A_STATUS_BAD_XOR    0x02
#define HL18A_STATUS_BAD_SEQ    0x03
#define HL18A_STATUS_LOCKED     0x04
#define HL18A_STATUS_UNSUP      0x05

static uint16_t hl18a_dry_chunks __SECTION_ZERO("retention_mem_area0");
static uint16_t hl18a_dry_bytes __SECTION_ZERO("retention_mem_area0");
static uint16_t hl18a_dry_expected_seq __SECTION_ZERO("retention_mem_area0");
static uint8_t hl18a_dry_xor __SECTION_ZERO("retention_mem_area0");
static uint8_t hl18a_dry_meta_ok __SECTION_ZERO("retention_mem_area0");

$notify
static void hl18a_dry_reset(void)
{
    hl18a_dry_chunks = 0;
    hl18a_dry_bytes = 0;
    hl18a_dry_expected_seq = 0;
    hl18a_dry_xor = 0;
    hl18a_dry_meta_ok = 0;
}

static uint8_t hl18a_dry_xor_bytes(const uint8_t *p, uint8_t len)
{
    uint8_t x = 0;
    uint8_t i;
    for (i = 0; i < len; i++) {
        x ^= p[i];
    }
    return x;
}

static uint8_t hl18a_dry_handle(const uint8_t *p, uint16_t len)
{
    uint8_t status = HL18A_STATUS_UNSUP;
    if ((len < 2) || (p[0] != 0xE3)) {
        return 0;
    }

    switch (p[1]) {
    case 0x00: {
        uint16_t w;
        uint16_t h;
        uint16_t total;
        if (len < 9) {
            hl18a_notify3(0xE3, 0x80, HL18A_STATUS_BAD_SIZE);
            return 1;
        }
        w = ((uint16_t)p[3] << 8) | p[2];
        h = ((uint16_t)p[5] << 8) | p[4];
        total = ((uint16_t)p[8] << 8) | p[7];
        if ((w == HL18A_DRY_W) && (h == HL18A_DRY_H) && (p[6] == HL18A_DRY_XBYTES) && (total == HL18A_DRY_TOTAL)) {
            hl18a_dry_reset();
            hl18a_dry_meta_ok = 1;
            status = HL18A_STATUS_OK;
        } else {
            status = HL18A_STATUS_BAD_SIZE;
        }
        hl18a_notify3(0xE3, 0x80, status);
        return 1;
    }

    case 0x01: {
        uint16_t seq;
        uint8_t dlen;
        uint8_t x;
        if (!hl18a_dry_meta_ok) {
            hl18a_notify3(0xE3, 0x81, HL18A_STATUS_LOCKED);
            return 1;
        }
        if (len < 6) {
            hl18a_notify3(0xE3, 0x81, HL18A_STATUS_BAD_SIZE);
            return 1;
        }
        seq = ((uint16_t)p[3] << 8) | p[2];
        dlen = p[4];
        if ((dlen > HL18A_DRY_CHUNK_MAX) || (len != (uint16_t)(6 + dlen))) {
            hl18a_notify3(0xE3, 0x81, HL18A_STATUS_BAD_SIZE);
            return 1;
        }
        x = hl18a_dry_xor_bytes(&p[6], dlen);
        if (x != p[5]) {
            hl18a_notify3(0xE3, 0x81, HL18A_STATUS_BAD_XOR);
            return 1;
        }
        if (seq != hl18a_dry_expected_seq) {
            hl18a_notify3(0xE3, 0x81, HL18A_STATUS_BAD_SEQ);
            return 1;
        }
        hl18a_dry_expected_seq++;
        hl18a_dry_chunks++;
        hl18a_dry_bytes += dlen;
        hl18a_dry_xor ^= x;
        hl18a_notify3(0xE3, 0x81, HL18A_STATUS_OK);
        return 1;
    }

    case 0x02: {
        uint8_t page = (len >= 3) ? p[2] : 0;
        uint8_t value = 0;
        switch (page) {
        case 0x00: value = (uint8_t)(hl18a_dry_chunks & 0xFF); break;
        case 0x01: value = (uint8_t)(hl18a_dry_chunks >> 8); break;
        case 0x02: value = (uint8_t)(hl18a_dry_bytes & 0xFF); break;
        case 0x03: value = (uint8_t)(hl18a_dry_bytes >> 8); break;
        case 0x04: value = hl18a_dry_xor; break;
        case 0x05: value = hl18a_dry_meta_ok; break;
        default: value = HL18A_STATUS_UNSUP; break;
        }
        hl18a_notify3(0xE3, 0x82, value);
        return 1;
    }

    case 0x03:
        hl18a_dry_reset();
        hl18a_notify3(0xE3, 0x83, HL18A_STATUS_OK);
        return 1;

    default:
        hl18a_notify3(0xE3, 0x8F, HL18A_STATUS_UNSUP);
        return 1;
    }
}
/* HL18A_FRAMEBUFFER_DRYRUN_END */

"@

      $pattern = "void\s+user_svc2_wr_ind_handler\s*\("
      if ($src -notmatch $pattern) {
        throw "Could not find user_svc2_wr_ind_handler() insertion point."
      }
      $src = [regex]::Replace($src, $pattern, ($helper + "void user_svc2_wr_ind_handler("), 1)

      $call = @'
    if (hl18a_dry_handle(param->value, param->length)) {
        return;
    }
'@
      $src = [regex]::Replace(
        $src,
        "(void\s+user_svc2_wr_ind_handler\s*\([^\{]*\)\s*\{)",
        "`$1`r`n$call",
        1
      )

      Set-Content -Encoding UTF8 $SourcePath $src
      Write-Host "Firmware source patched. Review diff before build/flash." -ForegroundColor Green
    }
  } else {
    Write-Host "\nFirmware patch not applied. Re-run with -PatchFirmware to patch E3 dry-run handler." -ForegroundColor Yellow
  }

  Write-Host "\nGit status after:" -ForegroundColor Cyan
  git status --short

  Write-Host "\nSuggested next commands after review:" -ForegroundColor Cyan
  Write-Host "git add web/clock-app/hl18a-213-dryrun.html docs/handoff/EINK_HANDOFF_2026-07-09.md docs/firmware/CURRENT_STATE.md docs/firmware/HL18A_DRYRUN_PROTOCOL.md tools/apply-hl18a.ps1"
  Write-Host "git commit -m \"web: add HL18A dry-run page\""
  Write-Host "git push"
}
finally {
  Pop-Location
}
