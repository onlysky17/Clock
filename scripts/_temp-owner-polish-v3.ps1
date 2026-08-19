[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$expectedBranch = 'task-d/eink-web-premium-ui-v2-clock-card'
$tempScript = Join-Path $repoRoot 'scripts\_temp-owner-polish-v3.ps1'
$renderer = Join-Path $repoRoot 'firmware\active\HINK213_CLOCK_22_BASE\src\hink_profile_v2.inc'
$firmware = Join-Path $repoRoot 'firmware\active\HINK213_CLOCK_22_BASE\src\user_custs1_impl.c'
$panel = Join-Path $repoRoot 'web\clock-app\panel-registry.js'
$week = Join-Path $repoRoot 'web\clock-app\weekly-calendar-preview.js'
$device = Join-Path $repoRoot 'web\clock-app\device-target-preview.js'
$raw = 'D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE\Keil_5\out_DA14585\Objects\ble_app_peripheral_585.bin'
$packed = Join-Path $repoRoot '_incoming\DISPLAY_PROFILES_V2_OWNER_POLISH_TEST.bin'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message" -ForegroundColor Green
}

function Replace-RegexSingle {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Replacement,
        [string]$Label
    )
    $matches = [regex]::Matches($Text, $Pattern)
    if ($matches.Count -ne 1) {
        throw "PATCH GUARD FAILED [$Label]: expected 1 match, found $($matches.Count)"
    }
    return [regex]::Replace($Text, $Pattern, $Replacement, 1)
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

Push-Location $repoRoot
try {
    Write-Host "=== OWNER POLISH V3 PREFLIGHT ===" -ForegroundColor Cyan
    $top = (& git rev-parse --show-toplevel).Trim()
    Assert-True ([IO.Path]::GetFullPath($top) -eq [IO.Path]::GetFullPath($repoRoot)) 'workspace is D:\EINK\Clock Git root'
    $branch = (& git branch --show-current).Trim()
    Assert-True ($branch -eq $expectedBranch) "branch is $expectedBranch"
    $dirty = @(& git status --short --untracked-files=no)
    Assert-True ($dirty.Count -eq 0) 'tracked working tree is clean before polish'

    foreach ($path in @($renderer,$firmware,$panel,$week,$device)) {
        Assert-True (Test-Path -LiteralPath $path) "exists: $path"
    }

    Write-Host "`n=== PATCH FIRMWARE RENDERERS ===" -ForegroundColor Cyan
    $r = (Get-Content -LiteralPath $renderer -Raw) -replace "`r`n","`n"

    $r = Replace-RegexSingle $r '(?ms)\n    for \(minute = cadence; minute < 60U; minute = \(uint8_t\)\(minute \+ cadence\)\)\n    \{\n        idx = minute;\n        hink_v2_small_uint_center\(\n            cx \+ hink_v2_scale\(hink_v2_x60\[idx\], 21U\),\n            cy \+ hink_v2_scale\(hink_v2_y60\[idx\], 21U\),\n            minute,\n            BLACK\n        \);\n    \}\n\n    /\* Hands:' "`n    /* Inner cadence is represented by ticks only; omit minute numerals on 250x122 to prevent collisions. */`n`n    /* Hands:" 'classic minute labels'

    $newWeekly = @'
static void hink_v2_draw_weekly(uint32_t local_day, uint8_t h, uint8_t m,
                                uint16_t sy, uint8_t sm, uint8_t sd,
                                uint8_t sw, uint8_t lunar_valid,
                                uint8_t lm, uint8_t ld)
{
    char header[18];
    char footer[10];
    char wbuf[3];
    uint8_t iso_wday = (sw == 0U) ? 7U : sw;
    uint8_t week = hink_v2_iso_week(sy, sm, sd, sw);
    uint32_t monday = local_day - (uint32_t)(iso_wday - 1U);
    uint8_t col;
    uint16_t wy;
    uint8_t wm;
    uint8_t wd;
    uint8_t ww;
    uint8_t wlm;
    uint8_t wld;
    uint8_t wlv;
    uint8_t active;
    uint8_t x;
    uint8_t day_color;
    uint8_t clock_idx;
    int x1;
    int x2;
    int cx = 235;
    int cy = 9;

    /* Vietnamese header: THĂNG mm Â· TUáº¦N ww. The compact firmware font is ASCII,
       so the accent marks and middle dot are drawn explicitly. */
    header[0] = 'T'; header[1] = 'H'; header[2] = 'A'; header[3] = 'N'; header[4] = 'G';
    header[5] = ' ';
    hink_put_2(&header[6], (uint8_t)(sm + 1U));
    header[8] = ' '; header[9] = ' ';
    header[10] = 'T'; header[11] = 'U'; header[12] = 'A'; header[13] = 'N'; header[14] = ' ';
    hink_put_2(&header[15], week);
    header[17] = 0;
    draw_text(6, 8, header, BLACK);
    /* acute over A in THĂNG */
    hink_d7a_pixel(21, 4, BLACK); hink_d7a_pixel(22, 3, BLACK);
    /* middle dot */
    hink_d7a_box(61, 10, 62, 11, BLACK);
    /* circumflex + grave over A in TUáº¦N */
    hink_d7a_pixel(79, 6, BLACK); hink_d7a_pixel(80, 5, BLACK); hink_d7a_pixel(81, 6, BLACK);
    hink_d7a_pixel(78, 3, BLACK); hink_d7a_pixel(79, 4, BLACK);

    /* Mini analog clock in the top-right header gap. */
    hink_v2_circle(cx, cy, 8, BLACK);
    for (clock_idx = 0U; clock_idx < 60U; clock_idx = (uint8_t)(clock_idx + 15U))
    {
        hink_v2_line(
            cx + hink_v2_scale(hink_v2_x60[clock_idx], 6U),
            cy + hink_v2_scale(hink_v2_y60[clock_idx], 6U),
            cx + hink_v2_scale(hink_v2_x60[clock_idx], 7U),
            cy + hink_v2_scale(hink_v2_y60[clock_idx], 7U),
            BLACK
        );
    }
    clock_idx = (uint8_t)((((h % 12U) * 5U) + (m / 12U)) % 60U);
    hink_v2_line(cx, cy,
                 cx + hink_v2_scale(hink_v2_x60[clock_idx], 4U),
                 cy + hink_v2_scale(hink_v2_y60[clock_idx], 4U), BLACK);
    clock_idx = m;
    hink_v2_line(cx, cy,
                 cx + hink_v2_scale(hink_v2_x60[clock_idx], 6U),
                 cy + hink_v2_scale(hink_v2_y60[clock_idx], 6U), BLACK);
    hink_d7a_box(cx - 1, cy - 1, cx + 1, cy + 1, BLACK);

    wbuf[2] = 0;
    for (col = 0U; col < 7U; col++)
    {
        uint32_t day_key = monday + col;
        hink_d3c_solar_from_day(day_key, &wy, &wm, &wd, &ww);
        wlv = hink_d3c_lunar_from_solar(wy, wm, wd, &wlm, &wld);
        active = (uint8_t)(day_key == local_day);
        x1 = 3 + ((int)col * 35);
        x2 = x1 + 33;

        /* Keep every column white/readable. Today gets a compact black date badge only. */
        hink_v2_line(x1, 18, x2, 18, BLACK);
        hink_v2_line(x2, 18, x2, 99, BLACK);
        hink_v2_line(x2, 99, x1, 99, BLACK);
        hink_v2_line(x1, 99, x1, 18, BLACK);
        day_color = BLACK;
        if (active)
        {
            hink_d7a_box(x1 + 5, 40, x2 - 5, 62, BLACK);
            day_color = WHITE;
        }

        wbuf[0] = (col == 6U) ? 'C' : 'T';
        wbuf[1] = (col == 6U) ? 'N' : (char)('2' + col);
        draw_text((uint8_t)(x1 + 11), 23, wbuf, BLACK);

        x = (uint8_t)(x1 + ((wd >= 10U) ? 10U : 14U));
        hink_d7a_draw_day(x, 45, wd, day_color);

        if (wlv)
        {
            hink_v2_week_small_day(x1 + 17, 70, wld, BLACK);
        }
        else
        {
            draw_text((uint8_t)(x1 + 11), 70, "--", BLACK);
        }
        draw_text((uint8_t)(x1 + 11), 87, "AM", BLACK);
        hink_d7a_draw_circumflex((uint8_t)(x1 + 11), 84U);
    }

    hink_weekday(footer, sw);
    footer[2] = ' ';
    hink_put_2(&footer[3], sd);
    footer[5] = '/';
    hink_put_2(&footer[6], (uint8_t)(sm + 1U));
    footer[8] = 0;
    draw_text(6, 108, footer, BLACK);
    hink_d9a_draw_lunar(184, 108, lunar_valid, lm, ld);
}
'@
    $r = Replace-RegexSingle $r '(?ms)static void hink_v2_draw_weekly\(uint32_t local_day,.*?\n\}\s*$' ($newWeekly.TrimEnd() + "`n") 'weekly renderer'
    Write-Utf8NoBom $renderer $r

    $fw = (Get-Content -LiteralPath $firmware -Raw) -replace "`r`n","`n"
    $fw = Replace-RegexSingle $fw '(?ms)hink_v2_draw_weekly\(local_day, sy, sm, sd, sw,\s*\n\s*lunar_valid, lm, ld\);' "hink_v2_draw_weekly(local_day, h, m, sy, sm, sd, sw,`n`t                    lunar_valid, lm, ld);" 'weekly call passes time'
    Write-Utf8NoBom $firmware $fw

    Write-Host "`n=== PATCH WEB PREVIEWS / UX ===" -ForegroundColor Cyan
    $p = (Get-Content -LiteralPath $panel -Raw) -replace "`r`n","`n"
    $p = Replace-RegexSingle $p '(?m)(      \.productClockCadence\{[^\n]+\}\r?\n)' ('$1' + "      .productProfileClock .productClockCopy,.productProfileClock .productAnalogClock{display:none!important}`n      .productProfileClock{display:block!important;margin:0!important;padding:0!important;border:0!important;background:transparent!important;box-shadow:none!important}`n      .productProfileClock[hidden]{display:none!important}`n") 'compact classic controls'
    $p = Replace-RegexSingle $p '(?ms)\n    for\(const minute of minuteLabelsForCadence\(cadence\)\)\{.*?\n    \}\n\n    const hourAngle=' "`n    /* Cadence is communicated by ticks only on the 250x122 target. */`n`n    const hourAngle=" 'web classic minute labels'

    $newClassicApply = @'
  function syncClassicApply(active){
    const apply=document.getElementById('profileApply');
    if(!apply)return;
    if(window.__einkCustomDeviceApplyReady){
      delete apply.dataset.classicPreview;
      if(apply.textContent==='Preview web â€” chÆ°a Ă¡p dá»¥ng')apply.textContent='Ăp dá»¥ng lĂªn mĂ n';
      return;
    }
    if(active){
      if(!apply.dataset.classicOriginalLabel)apply.dataset.classicOriginalLabel=apply.textContent||'Ăp dá»¥ng lĂªn mĂ n';
      apply.dataset.classicPreview='true';
      apply.textContent='Preview web â€” chÆ°a Ă¡p dá»¥ng';
      apply.disabled=true;
      apply.setAttribute('aria-disabled','true');
    }else if(apply.dataset.classicPreview==='true'){
      apply.textContent=apply.dataset.classicOriginalLabel||'Ăp dá»¥ng lĂªn mĂ n';
      apply.disabled=false;
      apply.removeAttribute('aria-disabled');
      delete apply.dataset.classicPreview;
    }
  }
'@
    $p = Replace-RegexSingle $p '(?ms)  function syncClassicApply\(active\)\{.*?\n  \}\n\n  function setClassicUi' ($newClassicApply.TrimEnd() + "`n`n  function setClassicUi") 'classic apply ownership'
    $p = Replace-RegexSingle $p '(?ms)(  function renderClassicState\(active\)\{.*?\n  \}\n)(\n  function mountPremiumClock)' ('$1' + "`n  window.EINK_CLASSIC_PREVIEW={`n    activate:()=>renderClassicState(true),`n    deactivate:()=>renderClassicState(false),`n    isActive:()=>document.querySelector('.productModeV2Profiles')?.dataset.webProfile===CLASSIC_VALUE`n  };`n" + '$2') 'classic preview API'
    Write-Utf8NoBom $panel $p

    $w = (Get-Content -LiteralPath $week -Raw) -replace "`r`n","`n"
    $newDrawWeek = @'
  function drawWeek(){
    const canvas=ensureCanvas();
    const ctx=canvas?.getContext?.('2d');
    if(!canvas||!ctx)return;

    const now=currentDate();
    const data=weekData(now);
    const currentKey=`${now.getFullYear()}-${now.getMonth()}-${now.getDate()}`;
    const monthName=`THĂNG ${pad(now.getMonth()+1)}`;
    const weekdays=['T2','T3','T4','T5','T6','T7','CN'];

    ctx.save();
    ctx.setTransform(canvas.width/250,0,0,canvas.height/122,0,0);
    ctx.imageSmoothingEnabled=true;
    ctx.fillStyle='#fff';
    ctx.fillRect(0,0,250,122);
    ctx.fillStyle='#050505';
    ctx.strokeStyle='#050505';
    ctx.textBaseline='middle';

    ctx.font='900 8px Arial, sans-serif';
    ctx.textAlign='left';
    ctx.fillText(`${monthName} Â· TUáº¦N ${data.week}`,7,10);

    /* Mini analog clock mirrors the firmware header. */
    const clockX=236,clockY=10,clockR=8;
    ctx.lineWidth=.8;
    ctx.beginPath();
    ctx.arc(clockX,clockY,clockR,0,Math.PI*2);
    ctx.stroke();
    for(const minute of [0,15,30,45]){
      const angle=(minute*Math.PI/30)-Math.PI/2;
      ctx.beginPath();
      ctx.moveTo(clockX+Math.cos(angle)*6,clockY+Math.sin(angle)*6);
      ctx.lineTo(clockX+Math.cos(angle)*7,clockY+Math.sin(angle)*7);
      ctx.stroke();
    }
    const hourAngle=(((now.getHours()%12)+(now.getMinutes()/60))*Math.PI/6)-Math.PI/2;
    const minuteAngle=(now.getMinutes()*Math.PI/30)-Math.PI/2;
    ctx.lineWidth=1.4;
    ctx.beginPath();ctx.moveTo(clockX,clockY);ctx.lineTo(clockX+Math.cos(hourAngle)*4,clockY+Math.sin(hourAngle)*4);ctx.stroke();
    ctx.lineWidth=.8;
    ctx.beginPath();ctx.moveTo(clockX,clockY);ctx.lineTo(clockX+Math.cos(minuteAngle)*6,clockY+Math.sin(minuteAngle)*6);ctx.stroke();
    ctx.fillRect(clockX-1,clockY-1,2,2);

    const left=6;
    const top=20;
    const gap=2;
    const totalWidth=238;
    const colWidth=(totalWidth-gap*6)/7;
    const colHeight=76;

    data.days.forEach((item,index)=>{
      const x=left+index*(colWidth+gap);
      const key=`${item.date.getFullYear()}-${item.date.getMonth()}-${item.date.getDate()}`;
      const active=key===currentKey;

      ctx.fillStyle='#fff';
      ctx.fillRect(x,top,colWidth,colHeight);
      ctx.strokeStyle='#111';
      ctx.lineWidth=.7;
      ctx.strokeRect(x+.35,top+.35,colWidth-.7,colHeight-.7);

      ctx.fillStyle='#050505';
      ctx.textAlign='center';
      ctx.font='900 6px Arial, sans-serif';
      ctx.fillText(weekdays[index],x+colWidth/2,top+9);

      if(active){
        ctx.fillStyle='#050505';
        ctx.fillRect(x+5,top+20,colWidth-10,26);
        ctx.fillStyle='#fff';
      }
      ctx.font='900 16px Arial, sans-serif';
      ctx.fillText(item.date.getDate(),x+colWidth/2,top+32);

      ctx.fillStyle='#050505';
      const lunarLabel=item.lunar.day===1
        ?`1/${item.lunar.month}${item.lunar.leap?'N':''}`
        :String(item.lunar.day);
      ctx.font='800 5.8px Arial, sans-serif';
      ctx.fillText(lunarLabel,x+colWidth/2,top+54);
      ctx.font='700 4.6px Arial, sans-serif';
      ctx.fillText('Ă‚M',x+colWidth/2,top+68);
    });

    const currentLunar=solarToLunar(now);
    ctx.fillStyle='#050505';
    ctx.textAlign='left';
    ctx.font='800 6px Arial, sans-serif';
    ctx.fillText(`${weekdays[(now.getDay()+6)%7]} ${pad(now.getDate())}/${pad(now.getMonth()+1)}`,7,108);
    ctx.textAlign='right';
    ctx.font='800 5.6px Arial, sans-serif';
    ctx.fillText(`Ă‚M ${currentLunar.day}/${currentLunar.month}${currentLunar.leap?'N':''}`,243,108);

    ctx.restore();
    syncWeekCard(now,data);
  }
'@
    $w = Replace-RegexSingle $w '(?ms)  function drawWeek\(\)\{.*?\n  \}\n\n  function ensureWeekChoice' ($newDrawWeek.TrimEnd() + "`n`n  function ensureWeekChoice") 'week web renderer'

    $newWeekApply = @'
  function setApplyPreview(active){
    const apply=document.getElementById('profileApply');
    if(!apply)return;
    if(window.__einkCustomDeviceApplyReady){
      delete apply.dataset.weekPreview;
      if(apply.textContent==='Preview web â€” chÆ°a Ă¡p dá»¥ng')apply.textContent='Ăp dá»¥ng lĂªn mĂ n';
      return;
    }
    if(active){
      if(!apply.dataset.weekOriginalLabel)apply.dataset.weekOriginalLabel=apply.textContent||'Ăp dá»¥ng lĂªn mĂ n';
      apply.dataset.weekPreview='true';
      apply.textContent='Preview web â€” chÆ°a Ă¡p dá»¥ng';
      apply.disabled=true;
      apply.setAttribute('aria-disabled','true');
    }else if(apply.dataset.weekPreview==='true'){
      apply.textContent=apply.dataset.weekOriginalLabel||'Ăp dá»¥ng lĂªn mĂ n';
      apply.disabled=false;
      apply.removeAttribute('aria-disabled');
      delete apply.dataset.weekPreview;
    }
  }
'@
    $w = Replace-RegexSingle $w '(?ms)  function setApplyPreview\(active\)\{.*?\n  \}\n\n  function setWeekActive' ($newWeekApply.TrimEnd() + "`n`n  function setWeekActive") 'week apply ownership'

    $w = Replace-RegexSingle $w '(?ms)  function setWeekActive\(active\)\{\n    weekActive=active;\n    const select=document.getElementById\(''productLayoutSelect''\);\n    const card=document.querySelector\(`\.\$\{WEEK_CARD_CLASS\}`\);\n    const button=document.querySelector\(''\[data-eink-week-profile\]''\);\n    if\(card\)card.hidden=!active;' "  function setWeekActive(active){`n    if(active)window.EINK_CLASSIC_PREVIEW?.deactivate?.();`n    weekActive=active;`n    const select=document.getElementById('productLayoutSelect');`n    const card=document.querySelector(`.${WEEK_CARD_CLASS}`);`n    const button=document.querySelector('[data-eink-week-profile]');`n    const profile=document.querySelector('.productModeV2Profiles');`n    if(card)card.hidden=true;`n    if(profile){`n      if(active)profile.dataset.webProfile=WEEK_VALUE;`n      else if(profile.dataset.webProfile===WEEK_VALUE)profile.dataset.webProfile='device';`n    }" 'week compact profile state'

    $w = Replace-RegexSingle $w 'window\.EINK_WEEK_PREVIEW=\{deactivate,isActive:\(\)=>weekActive\};' 'window.EINK_WEEK_PREVIEW={activate:()=>setWeekActive(true),deactivate,isActive:()=>weekActive};' 'week preview API'
    Write-Utf8NoBom $week $w

    $d = (Get-Content -LiteralPath $device -Raw) -replace "`r`n","`n"
    $d = Replace-RegexSingle $d '  let applyObserverBusy=false;' "  let applyObserverBusy=false;`n  let lastSyncedDeviceProfile=null;" 'device profile sync state'

    $syncDeviceProfile = @'
  function syncCustomSelectionFromDevice(){
    try{
      if(!server?.connected){
        lastSyncedDeviceProfile=null;
        return;
      }
      const profile=Number(activeClockProfile);
      if(!Number.isFinite(profile)||profile===lastSyncedDeviceProfile)return;
      lastSyncedDeviceProfile=profile;
      if(profile===WEEK_PROFILE_ID){
        window.EINK_CLASSIC_PREVIEW?.deactivate?.();
        window.EINK_WEEK_PREVIEW?.activate?.();
      }else if(profile===CLASSIC_PROFILE_ID){
        window.EINK_WEEK_PREVIEW?.deactivate?.();
        window.EINK_CLASSIC_PREVIEW?.activate?.();
      }
      syncUi();
      syncDeviceApplyButton();
    }catch(_error){}
  }

'@
    $d = Replace-RegexSingle $d '(?m)^  function selectedClassicCadence\(\)\{' ($syncDeviceProfile + '  function selectedClassicCadence(){') 'device profile sync function'
    $d = Replace-RegexSingle $d '(?ms)      window.__einkDeviceTargetPreviewTimer=setInterval\(\(\)=>\{\n        if\(mode===''device''\)syncUi\(\);\n      \},1000\);' "      window.__einkDeviceTargetPreviewTimer=setInterval(()=>{`n        syncCustomSelectionFromDevice();`n        if(mode==='device')syncUi();`n      },1000);" 'device reconnect profile sync timer'
    Write-Utf8NoBom $device $d

    Write-Host "`n=== SOURCE GUARDS ===" -ForegroundColor Cyan
    $rCheck = Get-Content -LiteralPath $renderer -Raw
    $fwCheck = Get-Content -LiteralPath $firmware -Raw
    $pCheck = Get-Content -LiteralPath $panel -Raw
    $wCheck = Get-Content -LiteralPath $week -Raw
    $dCheck = Get-Content -LiteralPath $device -Raw

    Assert-True ($rCheck.Contains('omit minute numerals on 250x122')) 'Classic firmware minute numerals removed'
    Assert-True ($rCheck.Contains('Mini analog clock in the top-right header gap')) 'Weekly firmware mini clock exists'
    Assert-True ($rCheck.Contains('Today gets a compact black date badge only')) 'Weekly today highlight is compact'
    Assert-True ($fwCheck.Contains('hink_v2_draw_weekly(local_day, h, m')) 'Weekly firmware receives hour/minute'
    Assert-True ($pCheck.Contains('window.EINK_CLASSIC_PREVIEW')) 'Classic preview exports state API'
    Assert-True ($wCheck.Contains('window.EINK_WEEK_PREVIEW={activate:')) 'Weekly preview exports activate API'
    Assert-True ($wCheck.Contains("ctx.fillText('Ă‚M'")) 'Weekly web preview keeps lunar label visible'
    Assert-True ($dCheck.Contains('syncCustomSelectionFromDevice')) 'Web reconnect syncs custom device profile'

    Write-Host "`n=== JS SYNTAX ===" -ForegroundColor Cyan
    foreach ($js in @($panel,$week,$device)) {
        & node --check $js
        if ($LASTEXITCODE -ne 0) { throw "FAIL: node --check $js" }
    }
    Write-Host 'PASS: JS syntax' -ForegroundColor Green

    Write-Host "`n=== DIFF CHECK ===" -ForegroundColor Cyan
    & git diff --check
    if ($LASTEXITCODE -ne 0) { throw 'FAIL: git diff --check' }

    Write-Host "`n=== CANONICAL FIRMWARE BUILD ===" -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\eink.ps1') build
    if ($LASTEXITCODE -ne 0) { throw "FAIL: firmware build exited $LASTEXITCODE" }
    Assert-True (Test-Path -LiteralPath $raw) 'raw firmware exists after build'
    $rawHash = (Get-FileHash -LiteralPath $raw -Algorithm SHA256).Hash
    $rawSize = (Get-Item -LiteralPath $raw).Length
    Assert-True ($rawSize -gt 0 -and $rawSize -le 65528) "raw firmware packable ($rawSize bytes)"

    Write-Host "`n=== EXACT STAGE / COMMIT / PUSH ===" -ForegroundColor Cyan
    Remove-Item -LiteralPath $tempScript -Force
    & git add -- `
        'firmware/active/HINK213_CLOCK_22_BASE/src/hink_profile_v2.inc' `
        'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c' `
        'web/clock-app/panel-registry.js' `
        'web/clock-app/weekly-calendar-preview.js' `
        'web/clock-app/device-target-preview.js' `
        'scripts/_temp-owner-polish-v3.ps1'
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'FAIL: staged diff check' }
    & git commit -m 'polish: finalize classic and weekly profiles'
    if ($LASTEXITCODE -ne 0) { throw 'FAIL: commit' }
    & git push origin $expectedBranch
    if ($LASTEXITCODE -ne 0) { throw 'FAIL: push' }
    $head = (& git rev-parse HEAD).Trim()
    $after = @(& git status --short --untracked-files=no)
    Assert-True ($after.Count -eq 0) 'tracked tree clean after commit'

    Write-Host "`n=== PACK NEW TEST ARTIFACT ===" -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tools\pack-hink.ps1') `
        -Raw $raw `
        -Out $packed `
        -Name 'HINK213-CLOCK'
    if ($LASTEXITCODE -ne 0) { throw 'FAIL: pack-hink' }
    $packedHash = (Get-FileHash -LiteralPath $packed -Algorithm SHA256).Hash
    $packedSize = (Get-Item -LiteralPath $packed).Length
    Assert-True ($packedSize -eq 262144) 'packed test artifact is 262144 bytes'

    Write-Host "`n=== SPI BURN PLAN (NON-DESTRUCTIVE) ===" -ForegroundColor Cyan
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'scripts\eink-spi-burn.ps1') `
        -PackedBin $packed `
        -Mode Plan
    if ($LASTEXITCODE -ne 0) { throw 'FAIL: SPI burn plan' }

    Write-Host "`n=== OWNER POLISH V3 READY ===" -ForegroundColor Green
    Write-Host "HEAD: $head"
    Write-Host "RAW_SIZE: $rawSize"
    Write-Host "RAW_SHA256: $rawHash"
    Write-Host "PACKED_BIN: $packed"
    Write-Host "PACKED_SIZE: $packedSize"
    Write-Host "PACKED_SHA256: $packedHash"
    Write-Host 'NEXT_STATE: OWNER_BURN_CONFIRMATION_REQUIRED'
}
finally {
    Pop-Location
}
